# Pitfalls Research

**Domain:** Phoenix/Ecto media lifecycle library (file upload, processing, storage, delivery)
**Researched:** 2026-04-24
**Confidence:** HIGH (drawn from Active Storage postmortems, Shrine design docs, Waffle issues, imgproxy lessons, and Elixir/OTP production patterns)

---

## Critical Pitfalls

### Pitfall 1: Storage I/O Inside DB Transactions

**What goes wrong:**
Storage operations (S3 upload, GCS put, disk write) execute inside the same Ecto.Multi or Repo.transaction block that writes DB state. If storage succeeds but the DB commit fails, objects exist in storage with no DB record. If the DB commits but storage fails, the rollback leaves a DB record pointing to a non-existent object. Both are silent corruption.

**Why it happens:**
It feels atomic — wrap everything in a transaction so either all succeeds or none does. But storage providers are not transactional participants; they don't roll back.

**How to avoid:**
Storage writes always happen **outside** DB transactions. Pattern: (1) write to storage, (2) DB transaction records the key, (3) compensating delete if DB fails. For purge: (1) DB transaction detaches record and enqueues an Oban job atomically using `Oban.insert/2` inside the transaction, (2) Oban worker deletes from storage after commit. This is explicitly the Rindle async purge pattern — enforce it in tests.

**Warning signs:**
- Any `Repo.transaction(fn -> Storage.put(...) end)` call
- Storage adapter called inside an `Ecto.Multi` step that isn't just building changeset data

**Phase to address:** M1 (must be correct in the core storage contract from day one)

---

### Pitfall 2: Trusting Client Content-Type and Filename

**What goes wrong:**
An attacker uploads a polyglot file — a JPEG that is also a valid PDF or ZIP or SVG with embedded JS. The server stores it under the client-provided extension and MIME type. The browser serves it with that Content-Type, executing arbitrary scripts (stored XSS via SVG, HTML injection, etc.). ImageMagick/Vix then parse the hostile binary, potentially triggering ImageTragick-class exploits.

**Why it happens:**
"The browser sends the MIME type" feels good enough. It's not — the browser derives it from the extension, which is user-controlled.

**How to avoid:**
Magic-byte detection (via `file` CLI or a library like `ex_magic` / Erlang `:file.read_file_info` + checking header bytes) immediately upon receipt, **before** any processing. Cross-reference detected MIME against the allowed list. Reject mismatches. Generate storage keys from UUIDs — never use the original filename in the storage path.

**Warning signs:**
- Any code path that uses `conn.params["file"].content_type` without re-checking magic bytes
- Storage keys containing any user-supplied string

**Phase to address:** M1 (Scanner behaviour + key generation in core schemas)

---

### Pitfall 3: Race Condition on Concurrent Attachment Replacement

**What goes wrong:**
User uploads file A. Background Oban job starts processing A. User replaces upload with file B. Background job finishes and promotes A, overwriting B. The user sees stale content; B is now orphaned in storage.

**Why it happens:**
The background job holds a reference to the original asset ID and blindly writes on completion, not checking whether the attachment has changed.

**How to avoid:**
Atomic promote pattern (from Shrine): on job completion, reload the attachment record inside a DB transaction, verify `asset_id` still matches what the job was given. If not, abort the promote (the newer upload wins). Log and enqueue cleanup of the stale asset.

**Warning signs:**
- Any Oban worker that calls `Repo.update` on an attachment without a `where: [asset_id: ^original_asset_id]` clause
- Promote logic that doesn't reload state from DB immediately before writing

**Phase to address:** M2 (atomic attach/promote implementation)

---

### Pitfall 4: Variant Explosion via Unsigned Dynamic Transforms

**What goes wrong:**
An endpoint accepts width/height/quality parameters and generates variants on-demand. An attacker (or bot/crawler) requests thousands of unique dimension combinations. Each creates a new Oban job, a new storage object, and a new DB record. Storage costs spike. Worker queues saturate. DB table grows unboundedly.

**Why it happens:**
Dynamic resizing "feels like a feature" — serving any size the client needs. This is how imgproxy works, but imgproxy signs every URL to prevent enumeration. Without signing, it's a DoS vector.

**How to avoid:**
Named presets in the Profile DSL only by default. Dynamic transforms require: (1) request signing with a shared secret, (2) pixel-area bound (e.g. max 4000×4000), (3) rate limiting per asset. Never expose an unsigned dynamic transform endpoint.

**Warning signs:**
- Any controller or LiveView that accepts `width`, `height`, or `quality` query params and passes them to a processor
- Variant generation triggered from URL params rather than profile name lookup

**Phase to address:** M2 (signed lazy variant generation must enforce bounds + signing before any public API is documented)

---

### Pitfall 5: Verifying Direct Upload Completion Without Confirming with Storage

**What goes wrong:**
Direct upload flow: (1) client gets presigned URL, (2) client uploads directly to S3, (3) client calls verify endpoint. If the verify step only checks that the client *says* it completed, without actually HEAD-requesting the object from storage, an attacker can skip the upload step and still trigger processing on a non-existent or wrong object.

**Why it happens:**
The verify step is added as a formality; the logic just transitions the session state to `uploaded` based on the client's word.

**How to avoid:**
On session verification, perform a HEAD request to the storage backend to confirm the object exists and the ETag/size matches what was expected. Only then transition to `verifying → completed`. Reject if object absent or size mismatch.

**Warning signs:**
- `Upload session state → completed` transition without a storage HEAD call
- Verify endpoint that only checks `session.state == :uploaded` without touching storage

**Phase to address:** M2 (direct upload broker verification step)

---

### Pitfall 6: Telemetry Event Names as Implementation Details (Not Public Contracts)

**What goes wrong:**
Team renames `[:rindle, :asset, :promote, :stop]` to `[:rindle, :asset, :attach, :stop]` in a patch release because "attach is more accurate." Every operator who built a Datadog dashboard or LiveDashboard page against the old name silently loses their metrics with zero error — telemetry emits events nobody is listening to anymore.

**Why it happens:**
Telemetry names feel like internal implementation — easy to change when refactoring. They're actually a cross-system API contract.

**How to avoid:**
Lock event names and metadata shapes in the public API surface at M1/M3. Treat them like a REST endpoint — changes require a major version bump. Provide a telemetry contract doc that lists all events, their measurements, and their metadata keys. Add a contract lane CI check that verifies event names haven't changed without a version bump.

**Warning signs:**
- Telemetry event names using internal module/function names (leaking implementation)
- No contract tests asserting that telemetry events emit with the documented shape

**Phase to address:** M3 (telemetry contracts), with naming convention decided in M1

---

### Pitfall 7: Orphaned Objects Accumulating in Storage

**What goes wrong:**
Staged objects that never complete, upload sessions that expire without cleanup, variants from deleted assets, old versions after attachment replacement — all accumulate in S3 silently. Storage costs grow unboundedly. There's no map from storage keys to DB records because keys were generated ad-hoc.

**Why it happens:**
"We'll add cleanup later" — but later never comes because there's no scheduled task and no audit tooling. Key generation that embeds timestamps or random strings makes reconciliation impossible.

**How to avoid:**
Storage keys must be deterministic from DB record UUIDs (e.g., `assets/{asset_id}/{variant_name}`). Cleanup tasks (session expiry, staged object sweep, post-purge storage verify) are v1 scope, not deferred. `mix rindle.verify_storage` must do bidirectional reconciliation: DB records without storage objects, and storage objects without DB records.

**Warning signs:**
- Storage key generation using random UUIDs not stored in the DB
- No scheduled cleanup job in the Oban cron configuration
- Growing S3 usage without a corresponding grow in `media_assets` count

**Phase to address:** M1 (key generation schema), M4 (cleanup tasks)

---

### Pitfall 8: Synchronous Processing in the Request/Response Cycle

**What goes wrong:**
Variant generation runs inline during the upload handler or the first request for a variant. For large images this can take seconds. The Phoenix request process blocks. Under load, the request pool exhausts. LiveView uploads time out. Active Storage's original architecture had this problem — lazy sync variants in templates caused N+1 blocking render paths.

**Why it happens:**
"Generate it when we need it" feels simpler and avoids the complexity of async state tracking.

**How to avoid:**
Eager variants are always Oban jobs — never synchronous in the upload path. Lazy/on-demand variants are also async (job-enqueued), with the response being a placeholder or 202 redirect until ready. Never process in the request cycle. Variant state machine tracks `queued → processing → ready` so callers can render appropriate placeholders.

**Warning signs:**
- Any `Processor.generate/2` call inside a controller action or LiveView callback
- Variant URLs that redirect-loop until the variant is done (sync generation on first request)

**Phase to address:** M2 (Oban worker design for eager variants)

---

### Pitfall 9: S3-Compatible ≠ Identical Across Providers

**What goes wrong:**
Code written and tested against AWS S3 breaks silently on Cloudflare R2 (no presigned POST multipart), Backblaze B2 (different presigned URL param names), or GCS (POST-then-PUT resumable flow). Adopters discover this when they try to switch providers in production.

**Why it happens:**
"S3-compatible" is marketing. Each provider implements a subset of S3's API with quirks and gaps.

**How to avoid:**
Storage adapters expose a capabilities map (`:presigned_put`, `:presigned_post`, `:multipart_upload`, `:resumable_upload`, etc.) rather than assuming all operations are available. The core broker checks capabilities before dispatching. Integration tests run against MinIO (S3) AND LocalStack (at minimum) in CI.

**Warning signs:**
- Storage adapter that doesn't implement a `capabilities/0` or `supports?/1` callback
- Integration tests against only one storage backend
- Presigned URL generation that hardcodes AWS v4 signing semantics

**Phase to address:** M1 (Storage behaviour contract), M5 (CI integration lane)

---

### Pitfall 10: Incomplete Oban Job Error Handling Leading to State Limbo

**What goes wrong:**
An Oban worker fails halfway through variant generation: image downloaded from storage, processing started, then process crashes. The `media_variants` record stays in `processing` state forever. No retry logic transitions it to `failed`. The variant appears "stuck" — missing from the UI, not retried, not alertable.

**Why it happens:**
Oban handles job-level retries, but if the worker doesn't update the variant state on failure (or the crash happens before the update), the DB state is inconsistent with Oban's internal state.

**How to avoid:**
Oban workers must use `handle_event/4` or a wrapper that catches all exits and transitions variant state to `failed` before returning `{:error, reason}`. Use `Oban.Worker` `@max_attempts` with exponential backoff. Final failure (exhausted attempts) must mark the variant as `failed` via a `perform/1` rescue + Oban discard callback. Expose `failed` variants in `mix rindle.regenerate_variants`.

**Warning signs:**
- Oban workers with no explicit state update on the variant record in the error/catch path
- `media_variants` rows stuck in `processing` after a deploy or crash
- No telemetry event for `[:rindle, :variant, :failed]`

**Phase to address:** M2 (Oban worker design), M3 (telemetry for failure events)

---

### Pitfall 11: Multipart Upload Cost Leaks

**What goes wrong:**
S3 multipart uploads that are initiated but never completed or aborted accumulate as incomplete multipart uploads. AWS charges for the stored parts even though they're never assembled into an object. A single interrupted large-file upload can hold gigabytes of parts indefinitely.

**Why it happens:**
The S3 API requires an explicit `AbortMultipartUpload` call. If the client disconnects or the session expires, the parts remain. Most teams don't know about this until they see the billing anomaly.

**How to avoid:**
`mix rindle.abort_incomplete_uploads` in M4. Also, S3 bucket lifecycle policies should be set to abort incomplete multipart uploads after N days (document this in the getting started guide). Upload sessions with `state: :uploading` that exceed their TTL must trigger abort.

**Warning signs:**
- No `AbortMultipartUpload` calls anywhere in the storage adapter
- Upload sessions that expire without a compensating storage abort
- Growing S3 multipart upload section in the AWS console

**Phase to address:** M4 (`abort_incomplete_uploads` task), M1 (upload session expiry model)

---

### Pitfall 12: Public API Surface Locked Too Early (or Too Late)

**What goes wrong:**
Two failure modes: (1) Lock the Profile DSL, storage adapter behaviour, and telemetry contracts before validating them against a real integration — breaking changes become high-cost post-1.0. (2) Keep them unstable too long — adopters build on a moving target and the library gets a reputation for instability.

**Why it happens:**
Library authors want to signal stability too early to attract adopters, or they avoid stabilizing because "we might need to change it."

**How to avoid:**
The CI adopter lane (M5) is the gate. At least one canonical integration must pass against the public API before cutting 1.0. Run the adopter lane on every PR. This creates a forcing function — if changing the public API breaks the adopter lane, the PR fails.

**Warning signs:**
- Cutting a 1.0 release without an external integration test
- No adopter lane in CI
- Public API docs written before the API is tested end-to-end

**Phase to address:** M5 (CI adopter lane requirement)

---

### Pitfall 13: State Machine Gaps — Missing Terminal States

**What goes wrong:**
The asset state machine has `failed` and `quarantined` terminal states, but there's no automated path to get *out* of `degraded` (some variants failed). Ops teams discover assets stuck in `degraded` with no tooling to re-trigger missing variant generation. Same for `stale` variants after a recipe change — they exist in the DB, but nothing enqueues regeneration automatically.

**Why it happens:**
State machines are designed forward (happy path) but the recovery paths from terminal/degraded states are an afterthought.

**How to avoid:**
Every non-happy-path terminal state must have a documented recovery action, ideally a `mix` task or Oban job that can be triggered. `degraded` assets → `mix rindle.regenerate_variants`. `stale` variants (recipe digest changed) → automatic detection + re-queue on next access or via cron. Design recovery into the state machine upfront.

**Warning signs:**
- State machine diagram with terminal states but no arrows out to recovery paths
- No `mix` task that can transition assets from `degraded` back to `processing → ready`

**Phase to address:** M1 (state machine design), M4 (recovery tasks)

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Store variants as JSON array on `media_assets` instead of separate `media_variants` table | Simpler schema, fewer joins | Can't query stale variants, no per-variant state, cleanup jobs become full table scans, Oban retries can't target a specific variant | Never — this is the central architectural decision |
| Skip magic-byte detection, trust client MIME | Simpler upload handler | XSS via polyglot SVG/HTML, ImageTragick-class exploits, content sniffing attacks | Never |
| Generate variants synchronously on first request | No async complexity, no placeholder states | Request process blocking, timeouts under load, exhausted Phoenix pool | Never in production paths; acceptable only in dev-mode local disk adapter with explicit warning |
| Use the original filename as the storage key | Human-readable object names in S3 | Path traversal risk, collisions, leaks original filenames, makes reconciliation ambiguous | Never |
| Use `Repo.update_all` for bulk state transitions without per-row telemetry | Fast batch operations | No per-asset observability, alerts fire on aggregates only, hard to debug individual failures | Acceptable for initial bulk backfill tasks, not for normal processing paths |
| Skip the adopt lane CI requirement for early releases | Faster time to Hex publish | Undiscovered integration bugs ship as first impressions; breaks trust before community forms | Never after beta; acceptable in `0.x` pre-release with explicit disclaimer |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Cloudflare R2 | Using presigned POST multipart form upload (not supported) | Use presigned PUT only; check `:presigned_put` capability; document R2 as a presigned PUT adapter |
| GCS | Treating GCS as a direct S3 PUT equivalent | GCS resumable upload is POST-then-PUT; implement the GCS adapter with its own session initiation flow |
| Oban Pro | Assuming Oban Pro features (batches, workflows) are available in all environments | Use only Oban OSS features in core; Pro-specific features are opt-in adapter extensions |
| AWS S3 presigned URLs | Using path-style URLs (deprecated and not supported on new buckets in many regions) | Use virtual-hosted-style URLs only; verify bucket names are DNS-compatible |
| Vix/Image libvips | Assuming libvips is installed on the host system | Include libvips installation in getting started guide; document NIF compilation requirement; provide Docker example with libvips |
| Oban transactional enqueue | Inserting Oban jobs outside the DB transaction that updates asset state | Always use `Oban.insert(changeset)` inside the same `Ecto.Multi` or `Repo.transaction` so the job only runs if the transaction commits |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| N+1 variant queries in templates | Slow page renders, high DB query count in Telemetry | Preload variants alongside assets using `Repo.preload/2` with named variant scope | First time a list page renders >20 assets each with multiple variants |
| Checking variant `ready` status on every request | High DB load on delivery endpoints | Cache variant URL resolution with short TTL (ETS or Cachex); variant state rarely changes after `ready` | At ~1k requests/minute per asset |
| Synchronous storage HEAD on every signed URL delivery | High latency on delivery endpoints | Cache the storage existence check; sign URLs deterministically so caching is safe | Under concurrent access with many signed URLs generated per second |
| Full `media_variants` table scan for stale detection | Slow `mix rindle.regenerate_variants` and scheduled cleanup | Index on `(profile, recipe_digest, state)` — stale detection queries exactly this | When `media_variants` exceeds ~100k rows |
| Unbounded Oban queue for variant processing | Worker queue grows without bound under bulk upload load | Use separate Oban queue for variant processing with explicit concurrency limit; reject (not enqueue) if queue depth exceeds bound | Under batch import of >1k assets |
| Large image file stored in memory before storage write | OOM on large uploads in proxied path | Stream uploads to storage using chunked transfer; never buffer entire file in process heap | With images >50MB in proxied upload path |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Trusting client Content-Type for MIME validation | Stored XSS via polyglot SVG/HTML; ImageTragick exploits | Magic-byte detection before any processing; allowlist-only MIME check |
| Unsigned dynamic transform URLs | DoS via variant explosion; storage cost attack | Named presets only by default; dynamic transforms require HMAC signing + pixel area cap |
| User-controlled strings in storage keys | Path traversal, key collision, metadata leakage | Generate keys from UUIDs; never include user-supplied filename in storage path |
| Processing unverified direct uploads | Attacker triggers processing on arbitrary objects they didn't upload | HEAD verify against storage before transitioning to `verifying → completed` |
| Public storage bucket for all objects | Assets accessible without authorization | Private storage by default; public access is an explicit per-profile opt-in |
| Signed URL secrets in environment variables without rotation strategy | Secret compromise exposes all signed URLs | Document key rotation procedure; signed URLs should have short TTLs (minutes, not days) |
| Allowing SVG uploads in image profiles without sanitization | Stored XSS — SVG can contain `<script>` tags | Reject SVG in image profiles by default; if allowed, strip script tags via sanitization before storage; serve with `Content-Type: image/svg+xml` and `Content-Disposition: attachment` |
| Pixel bomb / zip bomb detection gap | Decompression/decode attacks exhaust memory | Validate pixel dimensions from metadata before decoding full image; enforce pixel count limits in allowlist config |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No upload progress feedback in proxied path | Users don't know if upload is working; abandon and retry | Use Phoenix LiveView upload progress events; emit `[:rindle, :upload, :progress]` telemetry so adopters can wire UI feedback |
| Variant placeholder is broken image icon | User sees error state for a variant that is still processing | Provide `picture_tag/3` that renders a CSS placeholder (blur, spinner) when variant state is not `ready`; never render a `<img>` with a 404 src |
| No human-readable error on rejected uploads | User uploads a "wrong" file type with no feedback | Return structured validation errors from the Scanner behaviour with error codes that map to user-facing messages; document the error code → message convention |
| Silent failure when variant processing fails permanently | User never sees the asset; no feedback; support tickets | Expose `degraded` state in the profile's helper so adopters can render a warning; document how to surface `failed` variants in admin views |
| Generating srcset with non-existent variants | Missing image at certain breakpoints | `picture_tag/3` must only include variants with `state: :ready` in the srcset; document the progressive enhancement pattern for non-ready variants |

---

## "Looks Done But Isn't" Checklist

- [ ] **Upload validation:** Magic-byte detection implemented but not cross-referenced against extension allowlist — verify both MIME and extension are checked, not just one
- [ ] **Direct upload:** Presigned URL generated and returned, but verify step only checks client claim — verify with storage HEAD before completing session
- [ ] **Async purge:** DB record deleted but storage delete is synchronous in the controller — verify purge path enqueues Oban job and returns before storage delete
- [ ] **Variant state:** Variants generated and stored, but `media_variants` rows never transition beyond `processing` on success — verify state machine transitions on worker completion
- [ ] **Stale detection:** Recipe digest computed but never compared against stored digest on existing variants — verify `mix rindle.regenerate_variants` queries `(profile, recipe_digest) != current_digest`
- [ ] **Telemetry:** Events emitted in tests but metadata shape not asserted — verify telemetry event metadata keys match the documented contract schema
- [ ] **Signed URL expiry:** Signed URLs generated with 1-hour TTL but no delivery endpoint validates the TTL — verify the signature check includes expiry verification
- [ ] **Concurrent replace race:** Atomic promote implemented but the WHERE clause on the UPDATE is missing — verify `Repo.update_all where: [asset_id: ^original]` is used, not a blind `Repo.update`
- [ ] **Orphan cleanup:** `mix rindle.cleanup_orphans` implemented but only deletes DB records — verify it also enqueues storage deletes for the orphaned objects
- [ ] **Upload session expiry:** TTL field added to `media_upload_sessions` but nothing expires sessions — verify a cron Oban job transitions `initialized/signed/uploading` sessions past TTL to `expired`

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Storage I/O in transactions causes split-brain | HIGH | Manual audit: compare storage objects to DB records; `mix rindle.verify_storage` for ongoing reconciliation; no automated recovery — requires per-case triage |
| Variant explosion fills storage | HIGH | Delete variant records + storage objects for unauthorized dimensions; add signing enforcement; cannot automatically recoup storage costs |
| Race condition corrupts active attachment | MEDIUM | Reload asset from DB; re-trigger processing if state is `available` not `ready`; `mix rindle.regenerate_variants` on affected assets |
| Telemetry contract broken in minor release | HIGH | Semver major bump required; provide both old and new event names in a transition release with deprecation warnings |
| Orphaned objects accumulate over months | MEDIUM | `mix rindle.verify_storage` in dry-run mode first; review report; run cleanup with confirmation flag; cost cannot be recovered |
| Oban worker stuck in limbo state | LOW | `mix rindle.regenerate_variants --state=processing --older-than=1h` to reset and re-enqueue stuck processing variants |
| Multipart upload cost leak | MEDIUM | `mix rindle.abort_incomplete_uploads`; add S3 lifecycle policy; review billing anomaly for scope |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Storage I/O inside DB transactions | M1 — Storage behaviour contract | Integration test: force DB commit failure after storage write; verify no orphan in storage |
| Trusting client Content-Type | M1 — Scanner behaviour + allowlist | Test: upload polyglot file with wrong extension; verify rejection |
| Concurrent attachment replacement race | M2 — Atomic promote | Test: simulate concurrent job completion with replaced attachment; verify newer upload wins |
| Unsigned dynamic transforms | M2 — Signed lazy variant gate | Test: request variant with unsigned params; verify 401/403 |
| Unverified direct upload completion | M2 — Broker verify step | Test: call verify without uploading to storage; verify rejection |
| Telemetry contracts | M3 — Telemetry contract doc + CI | CI contract lane: telemetry event shape assertion on every PR |
| Orphaned object accumulation | M1 (key schema) + M4 (cleanup tasks) | `mix rindle.verify_storage` in CI integration lane against test fixtures |
| Sync processing in request cycle | M2 — Oban worker design | Test: no `Processor` calls in controller or LiveView code paths; enforce via Credo custom check |
| S3-compatible ≠ identical | M1 (capabilities) + M5 (CI) | CI integration lane runs against MinIO AND LocalStack |
| Oban job state limbo | M2 — Worker error handling | Test: kill worker process mid-job; verify variant transitions to `failed` |
| Multipart cost leak | M4 — Abort task + session TTL | Test: expire a session in `uploading` state; verify abort is triggered |
| Public API locked too early/late | M5 — CI adopter lane | Adopter lane runs on every PR; gate 1.0 release on green adopter lane |
| State machine recovery gaps | M1 (design) + M4 (recovery tasks) | Test: manually set asset to `degraded`; run `regenerate_variants`; verify transitions to `ready` |

---

## Sources

- Rails Active Storage source code and issue tracker — async purge pattern, sync variant anti-pattern lessons
- Shrine gem design documentation — atomic promote pattern, derivative naming, background processing design
- Spatie Media Library documentation — regeneration commands, responsive image srcset
- imgproxy documentation — signed dynamic transform URL security model
- Waffle (Elixir) GitHub issues — pain points with non-persistent variant state and Ecto coupling
- AWS S3 multipart upload documentation — incomplete multipart cost model, lifecycle policies
- Cloudflare R2 compatibility documentation — presigned POST multipart not supported
- ImageMagick CVE history (ImageTragick 2016) — why libvips is the safer default
- Oban documentation — transactional job insertion, worker error handling patterns
- Phoenix LiveView upload documentation — direct upload flow, completion verification

---
*Pitfalls research for: Rindle — Phoenix/Ecto media lifecycle library*
*Researched: 2026-04-24*
