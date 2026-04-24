# Project Research Summary

**Project:** Rindle — Phoenix/Ecto media lifecycle library
**Domain:** Elixir/Phoenix file upload, processing, storage, and delivery library
**Researched:** 2026-04-24
**Confidence:** HIGH

## Executive Summary

Rindle is a production-grade media lifecycle library for Phoenix/Elixir applications, targeting the gap left by Waffle and Arc — both of which lack persistent variant state, upload session tracking, and Day-2 operational tooling. Experts in this domain (Active Storage, Shrine, Spatie Media Library) converge on the same foundational decisions: normalized DB records for every lifecycle entity, async-only processing via a durable job queue, and an explicit state machine that makes asset health queryable rather than inferred.

The recommended approach centers on a behaviour + adapter pattern for all I/O boundaries (storage, processing, analysis, scanning), an Ecto-backed state machine for assets/variants/sessions, and Oban as a hard dependency for durable async processing. The core differentiator over Waffle is queryable state: `media_variants` as a first-class normalized table, full asset/variant/upload-session FSMs, recipe digest-based stale detection, and Day-2 Mix tasks that keep production healthy without manual intervention.

The primary risks are security (trusting client MIME, unsigned dynamic transforms, path traversal via user-controlled storage keys) and correctness (storage I/O inside DB transactions, race conditions on concurrent attachment replacement, orphaned storage objects from incomplete uploads). All three risk categories have well-documented mitigations from reference implementations and can be addressed in v1 with disciplined application of known patterns.

## Key Findings

### Recommended Stack

The stack is anchored by Elixir ~> 1.15, Ecto SQL ~> 3.11, and PostgreSQL as the required database — advisory locks, `FOR UPDATE SKIP LOCKED`, and `RETURNING` clauses are all needed. Oban ~> 2.21 is a hard dependency (not optional) for transactional job enqueueing; its SQL-backed persistence is what makes the async purge and atomic promote patterns work correctly. For image processing, `image` (libvips/Vix, ~> 0.65) is the only acceptable default — 2–3× faster than Mogrify with ~5× less memory, NIF-based with no shell-out risk. Two libraries need to be added to the current `mix.exs`: `ex_aws_s3` + `ex_aws` for S3 storage and `ex_marcel` for magic-byte MIME detection.

**Core technologies:**
- **Elixir ~> 1.15 + Ecto SQL ~> 3.11 + Postgrex ~> 0.18**: Language + DB layer — pattern matching, supervisors, and binary handling are all essential; Ecto changesets enforce state machine transitions safely
- **Oban ~> 2.21**: Background job processing — SQL-backed, persistent, transactional enqueueing; enqueue inside DB transactions so asset state and job commit atomically
- **image ~> 0.65 (libvips/Vix)**: Image processing — NIF-based, multi-threaded, pipelined; avoids shell-out risk; only acceptable default
- **ex_aws_s3 ~> 2.5 + ex_aws ~> 2.5**: S3-compatible storage adapter — presigned PUT URL generation, AWS SigV4
- **ex_marcel ~> 0.2**: Magic-byte MIME detection — port of Rails Marcel; never trust client Content-Type
- **NimbleOptions ~> 1.1**: Profile/DSL compile-time validation — catch misconfigured profiles at compile time, not runtime
- **Telemetry ~> 1.2**: Observability — event names are public API contracts, not implementation details

### Expected Features

The key insight from feature research is that Rindle's value is the lifecycle story — the features themselves (upload, variants, delivery) are table stakes, but the *queryability* and *operability* of those features are the differentiators. Waffle has uploads and variants; it doesn't have state machines, normalized variant records, or Day-2 tooling.

**Must have (table stakes):**
- Local disk + S3-compatible storage adapters — two adapters prove the adapter interface
- Magic-byte MIME detection + allowlist validation — security baseline, non-negotiable
- Ecto schemas + normalized tables for assets, attachments, variants, sessions, processing runs
- Image variants via libvips — named presets only; no dynamic transforms by default
- Phoenix-proxied upload + direct presigned PUT — two paths covering 95%+ of real-world needs
- Background processing via Oban — async always, never synchronous in the request cycle
- Signed URL delivery, private-by-default — correct security posture out of the box
- Telemetry events as public API contract — operators need observability from day one

**Should have (competitive differentiators):**
- Asset + variant + upload session state machines — full lifecycle visibility; queryable `quarantined`, `degraded`, `stale` states
- Normalized `media_variants` table — queryable variant state enables cleanup, retries, stale detection
- Stale variant detection via recipe digest — recipe changes automatically flag variants for regeneration
- Atomic attach/promote pattern — prevents stale background jobs from overwriting newer uploads
- Async idempotent purge — detach in DB transaction, enqueue storage delete after commit
- Day-2 Mix tasks — `cleanup_orphans`, `regenerate_variants`, `verify_storage`, `abort_incomplete_uploads`
- Oban cron workers for scheduled cleanup — automated hygiene without operator cron config
- Responsive image helper (`picture_tag/3`) — reduces frontend boilerplate, drives adoption

**Defer (v1.x / v2+):**
- tus resumable upload, S3 multipart upload — presigned PUT covers 95%+ of cases
- GCS adapter — POST-then-PUT resumable flow differs enough from S3 to defer
- FFmpeg/Membrane video and audio adapters — follow image patterns; add as plugins post-v1
- Admin LiveView UI — too opinionated for v1 core
- AI/ML processor adapters — extension point exists; official adapters follow adoption

### Architecture Approach

The architecture follows a behaviour + adapter pattern at every I/O boundary (storage, processor, analyzer, scanner, authorizer), Ecto-backed FSMs for all lifecycle entities, and Oban workers as the sole async execution path. The public `Rindle` module is a thin facade; domain logic lives in `Rindle.Domain.*` (schemas + FSM transitions), `Rindle.Core.*` (pure functions: MIME, key generation, validation, digest), and `Rindle.Workers.*` (Oban workers). No `Task.async` or `GenServer` process pools are invented — Oban handles all async operations.

**Major components:**
1. **`Rindle` (public facade)** — thin delegating API: `upload/2`, `attach/3`, `url_for/2`, `purge/2`
2. **Domain FSMs** (`asset.ex`, `variant.ex`, `upload_session.ex`) — Ecto-backed state machines; queryable state is the foundation for Day-2 ops
3. **Profile DSL** (`Rindle.Profile`) — `use Rindle.Profile` macro with compile-time validation and recipe digest computation
4. **Behaviour layer** (`Rindle.Storage`, `Rindle.Processor`, `Rindle.Analyzer`, `Rindle.Scanner`, `Rindle.Authorizer`) — contracts; host apps implement custom adapters via these
5. **Adapter layer** (Local, S3, Vix) — concrete I/O implementations; optional deps at library level
6. **Oban workers** (`ProcessVariant`, `PromoteAsset`, `PurgeStorage`, `CleanupOrphans`) — sole async execution path
7. **Telemetry layer** — public contract events at every lifecycle boundary: upload, promote, variant, delivery, cleanup
8. **Mix tasks** — Day-2 operations as scriptable shell commands

### Critical Pitfalls

1. **Storage I/O inside DB transactions** — storage operations can fail or succeed independently of DB commits; pattern: detach in transaction + enqueue `PurgeStorageWorker` via `Oban.insert` inside the same `Ecto.Multi`; storage delete happens only after commit
2. **Trusting client Content-Type** — attackers upload polyglots (JPEG+SVG with `<script>`); always run magic-byte detection before any processing; cross-reference detected MIME against extension allowlist; reject mismatches
3. **Race condition on concurrent attachment replacement** — reload the DB record and verify `attachment_key` hasn't changed before any background worker writes output; if replaced, abort silently (the newer upload wins)
4. **Variant explosion via unsigned dynamic transforms** — named presets only by default; dynamic transforms require HMAC signing + pixel area cap + rate limiting; this is a DoS/cost vector
5. **Orphaned objects accumulating in storage** — storage keys must be deterministic from DB UUIDs; scheduled cleanup via Oban cron; `mix rindle.verify_storage` for bidirectional reconciliation (DB without storage, storage without DB)

## Implications for Roadmap

Based on combined research, the dependency graph is clear: schemas and behaviours come first (everything else builds on them), then upload and processing paths (core functionality), then observability and delivery polish, then Day-2 operations, then the CI integration lane that gates 1.0.

The existing `mix.exs` has milestone markers (M1–M5) that align with this dependency order. Research confirms these are the right groupings.

---

### Phase 1 (M1): Foundation — Schemas, Behaviours, Core Security
**Rationale:** Everything else depends on queryable DB state and correct I/O contracts. State machine design decisions made here are expensive to change post-M2. Security primitives (MIME detection, key generation) must be correct from the first upload — retrofitting is error-prone.
**Delivers:** Normalized DB schema with all FSMs; behaviour contracts for Storage, Processor, Analyzer, Scanner, Authorizer; Profile DSL with compile-time validation and recipe digest; magic-byte MIME detection + allowlist; UUID-based storage key generation; local disk adapter; Ecto migrations.
**Addresses:** Ecto schemas + state machines (P1), Profile/recipe DSL (P1), MIME detection (P1), Local storage (P1)
**Avoids:** Storage I/O in transactions (design the interface correctly); JSON-only variant storage (never start down this path); user-controlled storage keys (key generation is a M1 primitive)
**Research flag:** Standard patterns — Ecto schema design and behaviour contracts are well-documented; no deep research needed during planning

---

### Phase 2 (M2): Upload Paths + Processing Pipeline
**Rationale:** Upload and variant generation are the core value proposition. Atomic promote and async-only processing patterns must be correct here — retrofitting concurrency correctness is high risk. Direct upload broker requires the storage behaviour from M1; Oban workers require the domain FSMs from M1.
**Delivers:** Phoenix-proxied upload path; direct presigned PUT upload with session state machine; MIME + allowlist validation in upload path; Oban workers for eager variant generation (ProcessVariant, PromoteAsset); atomic promote pattern; async idempotent purge (PurgeStorage worker); S3 storage adapter; Vix processor adapter; upload session → asset → variant FSM transitions end-to-end.
**Addresses:** Direct presigned PUT (P1), Phoenix-proxied upload (P1), Eager Oban variants (P1), Atomic attach/promote (P1), Async purge (P1), S3 adapter (P1)
**Avoids:** Sync processing in request cycle; storage I/O inside transactions; concurrent attachment replacement race; unverified direct upload completion (HEAD verify against storage before completing session)
**Research flag:** Standard patterns — Oban transactional enqueueing and atomic promote are well-documented; atomic promote implementation may need review against Shrine's design

---

### Phase 3 (M3): Delivery + Observability
**Rationale:** Signed URL delivery and telemetry are needed before any real integration can be tested. Telemetry event names are a public API contract — they must be locked before the adopter lane. Delivery depends on signed URL generation which depends on the storage adapter from M2.
**Delivers:** Signed URL delivery (private-by-default); public URL opt-in per profile; `Rindle.Delivery.Signer` + `Rindle.Authorizer` behaviour; telemetry events as public contract at all lifecycle boundaries (upload, promote, variant, delivery, cleanup); telemetry event metadata schema documentation; `picture_tag/3` responsive image helper; Phoenix controller + LiveView integration helpers.
**Addresses:** Signed URL delivery (P1), Telemetry public contract (P1), Responsive image helper (P2)
**Avoids:** Telemetry names as implementation details (lock names here; treat as REST endpoint — changes require major version bump); unsigned dynamic transforms (delivery layer is where this gate lives)
**Research flag:** Telemetry contract design may benefit from reviewing AppSignal and Fly.io blog posts on Elixir telemetry naming conventions

---

### Phase 4 (M4): Day-2 Operations
**Rationale:** Day-2 tools are what separate a production-ready library from an upload wrapper — this is a primary differentiator over Waffle. They depend on queryable variant state (M1), the full processing pipeline (M2), and storage access (M2). Oban cron workers depend on the worker infrastructure from M2.
**Delivers:** `mix rindle.cleanup_orphans` (bidirectional storage/DB reconciliation); `mix rindle.regenerate_variants` (stale + missing + failed variant re-queue); `mix rindle.verify_storage` (dry-run + execution modes); `mix rindle.abort_incomplete_uploads` (upload session expiry + S3 multipart abort); `mix rindle.backfill_metadata` (re-analyze assets); Oban cron workers for scheduled session expiry and orphan cleanup; stale variant detection via recipe digest comparison; recovery paths from `degraded` and `stale` states.
**Addresses:** Day-2 Mix tasks (P1), Oban cron cleanup (P1), Stale variant detection (P1)
**Avoids:** Orphaned object accumulation (verify_storage + cleanup_orphans are the resolution); multipart upload cost leak (abort task); state machine recovery gaps (every terminal state has a recovery path)
**Research flag:** Standard patterns — Mix task design is well-documented; S3 AbortMultipartUpload API specifics may need review

---

### Phase 5 (M5): CI Integration Lane + 1.0 Readiness
**Rationale:** The public API (Profile DSL, storage behaviour, telemetry contracts) must be validated against a real integration before 1.0. An adopter lane in CI is the forcing function that prevents premature stabilization of bad API surfaces. This phase gates the 1.0 release.
**Delivers:** CI adopter integration lane (runs on every PR); integration tests against MinIO (S3-compatible) + LocalStack; telemetry contract assertion lane; documentation (getting started guide, telemetry contract doc, storage adapter guide, libvips installation guide); adopter sample app; ex_doc configuration + Hexdocs.
**Addresses:** Public API contract stability; CI integration lane (gates 1.0)
**Avoids:** Public API locked too early/late (adopter lane is the gate); S3-compatible ≠ identical (run against both MinIO and LocalStack); telemetry contracts broken in minor release (CI contract assertion)
**Research flag:** phx_media_library (v0.6.0, March 2026) must be studied before finalizing public API surfaces in M5 — ensure meaningful differentiation and avoid mirroring a weaker design

---

### Phase Ordering Rationale

- **M1 before M2:** Schema and behaviour contracts are the substrate; FSM transitions, Oban workers, and upload paths all depend on them. Changing schema design post-M2 requires migration rewrites.
- **M2 before M3:** Delivery layer needs working upload + storage paths to have URLs to sign. Telemetry needs real operations to instrument.
- **M3 before M5:** Telemetry contract must be locked before the adopter lane validates it. Delivery must work before the adopter integration test can succeed.
- **M4 after M2:** Day-2 ops query variant state; they need variants to exist. Cleanup workers need the PurgeStorage worker pattern from M2.
- **M5 last:** Integration validation gates the release; can't validate before all prior phases deliver.

### Research Flags

Phases needing deeper research during planning:
- **M2 (direct upload broker):** Verify HEAD-check pattern against S3/R2 presigned URL semantics — some providers may have eventual consistency windows
- **M3 (telemetry naming):** Review naming conventions before locking — names are a permanent public contract
- **M5 (competitor API):** Study phx_media_library v0.6.0 API before finalizing public surfaces

Phases with standard/well-documented patterns (skip or minimize research):
- **M1:** Ecto schema design, behaviour contracts, and NimbleOptions DSL are thoroughly documented
- **M4:** Mix task design and Oban cron configuration are standard patterns
- **M2 (Oban workers):** Transactional enqueueing and worker error handling are well-documented in Oban docs

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Verified via hex.pm with current versions; rationale cross-checked against official docs and community consensus |
| Features | HIGH | Derived from PROJECT.md requirements + analysis of Active Storage, Shrine, Spatie, Waffle; competitor gaps are clear |
| Architecture | HIGH | Derived from PROJECT.md decisions + reference implementations; patterns are proven in production at scale |
| Pitfalls | HIGH | Drawn from actual postmortems (Active Storage issues, ImageTragick CVE history, imgproxy design), not speculation |

**Overall confidence:** HIGH

### Gaps to Address

- **phx_media_library v0.6.0 API:** Nearest emerging competitor (March 2026); API must be studied before M5 API finalization to ensure meaningful differentiation. *Action: study before M5 planning.*
- **Cloudflare R2 presigned PUT semantics:** R2's S3 compatibility surface needs integration testing to confirm capability flags are correct. *Action: verify in M5 CI integration lane against real R2 bucket or documented spec.*
- **GCS adapter scope:** Research confirms GCS requires a POST-then-PUT resumable flow; decision to defer to v1.x is correct but the capability negotiation design must accommodate it from M1. *Action: ensure `capabilities/0` on the Storage behaviour is extensible enough for GCS in M1.*
- **libvips system dependency:** CI must install libvips before any image tests pass; Docker example needed in getting started guide. *Action: document in M5, stub in M2 CI config.*
- **mix.exs version updates needed:** `oban: "~> 2.18"` → `~> 2.21`; `image: "~> 0.54"` → `~> 0.65`; add `ex_aws_s3`, `ex_aws`, `ex_marcel`, test infrastructure deps. *Action: update in M1.*

## Sources

### Primary (HIGH confidence)
- PROJECT.md — project requirements, constraints, key decisions, and out-of-scope definitions
- hex.pm package registry — current versions and release dates confirmed for all core dependencies
- Active Storage (Rails) — attachment/blob/variant model; async purge pattern; lazy variant redirection; postmortem lessons
- Shrine (Ruby) — derivatives as DB records; atomic promote pattern; backgrounding/cleanup as first-class
- Oban documentation — transactional job enqueueing, worker error handling, queue configuration

### Secondary (MEDIUM confidence)
- Spatie Media Library (PHP) — conversion regeneration commands, responsive srcset, opinionated DX defaults
- imgproxy — signed dynamic transform URL security model; variant explosion risk documentation
- Waffle (Elixir) — current Phoenix ecosystem baseline; gap analysis defines Rindle's differentiator surface
- AppSignal Blog: Building State Machines in Elixir with Ecto — rationale for explicit Ecto transitions over state machine libraries

### Tertiary (LOW confidence — validate before acting)
- phx_media_library v0.6.0 (March 2026) — nearest competitor; API not yet studied in depth; must review before M5 API finalization
- AWS S3 multipart upload documentation — incomplete multipart cost model; S3 lifecycle policy recommendations

---
*Research completed: 2026-04-24*
*Ready for roadmap: yes*
