# Phase 42: tus Protocol Edge (bare Plug) - Context

**Gathered:** 2026-05-22 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Ship the **tus 1.0 HTTP protocol edge** as a bare `Rindle.Upload.TusPlug`
(`@behaviour Plug`, mounted via `forward`, NO Phoenix/tussle dependency) over the
resumable-session substrate v1.7 already shipped. Scope = tus **Core + Creation +
Expiration + Termination** only, proven against **Local tmp-append backing** as
the first tus sink. An adopter can mount the Plug under their own auth pipeline; a
real tus client (tus-js-client) can create → resume across drops → complete →
delete an upload that promotes through the **unchanged** `verify_completion/2`
lane to a `ready` `MediaAsset`.

**Explicitly NOT in this phase:**
- S3 multipart-per-PATCH backing + the generic `upload_part_stream/5` adapter
  callback (TUS-06..09 → **Phase 43**).
- Optional rebind authorizer enforcement, `Rindle.Error` tus vocabulary, tus
  edge telemetry, `mix rindle.doctor` tus checks, `guides/resumable_uploads.md`,
  generated-app CI proof (TUS-10..14 → **Phase 44**).
- Browser→Mux direct creator upload (MUX-20..23 → **Phase 45**).

Requirements: TUS-01, TUS-02, TUS-03, TUS-04, TUS-05, POLISH-01.
</domain>

<decisions>
## Implementation Decisions

### Storage-sink seam — Local-inline in Phase 42, generic callback in Phase 43
- **D-01:** Phase 42 backs PATCH bytes to Local with a **Local-specific
  tmp-append path** (`File.open(.., [:append])` → atomic `File.rename/2` into the
  final key on completion), reachable from `TusPlug`/a thin Local helper. It does
  **NOT** define the generic `upload_part_stream/5` callback on `Rindle.Storage`
  — that callback is born in **Phase 43** designed against real S3 part semantics
  (5 MiB minimum, ETag accumulation). Rationale: `Rindle.Storage.Local` has no
  multipart machinery (`local.ex` returns `{:error, {:upload_unsupported,
  :multipart_upload}}`); the part-numbered signature fits S3, not file-append.
  Designing the callback against the file-append case first would yield an API
  reshaped once S3 arrives.
- **D-02:** For the **Local** sink, `initiate_tus_upload/2` = create the
  `"resumable"` / `resumable_protocol: "tus"` session row + ensure the
  `Rindle.tmp/tus/<session_id>` path. It does **NOT** initiate any S3 multipart
  upload. The TUS-02 requirement wording ("initiates the S3 multipart upload") is
  **stale S3-centric framing** carried from an earlier draft; it contradicts the
  Phase-42 "Local only" goal and is reconciled here — S3-multipart initiation
  belongs to Phase 43. (Note for the requirements steward: TUS-02 prose should be
  read as backing-agnostic.)

### Auth — HMAC-signed tus URLs + creator-identity capture
- **D-03:** Every tus URL is HMAC-signed via `Plug.Crypto.sign/verify` against
  `secret_key_base` (reusing the `LocalPlug` primitive, `local_plug.ex:66`),
  verified on every `HEAD`/`PATCH`/`DELETE`; missing/tampered/expired signature →
  `404` (tus convention — do not leak existence) or `401`, never `200`. Expiry is
  a manual `exp` check inside the payload, exactly as `local_plug.ex:67-72`. The
  signed URL is stored (already-redacted) in `session_uri` and never appears in
  logs/telemetry/`inspect`.
- **D-04:** The signed token is the **final path segment** of the tus URL
  (`Location: /uploads/tus/<signed_token>`), resolved from `conn.path_info` after
  `forward` strips the mount prefix — **NOT** a `?token=` query param. This is a
  deliberate, justified divergence from `LocalPlug`'s query-param token: tus URLs
  are consumed by third-party clients (tus-js-client / `@uppy/tus`) that treat
  `Location` as an opaque REST resource, and CORS-sensitive proxies can mangle
  query strings on cross-origin `HEAD`/`PATCH`. Same `Plug.Crypto.verify`
  primitive; only the extraction site changes (path_info vs query_params).
- **D-05:** Phase 42 **captures-but-does-not-enforce** creator identity by
  embedding `actor: <subject>` inside the HMAC token payload (alongside
  `session_id`, `exp`). It lives in the signed token (stored in the redacted
  `session_uri`), **NOT a new DB column** — preserving the "one column only"
  budget. This mirrors `LocalPlug`'s `actor_subject` in the signed payload
  (`local_plug.ex:122`). Enforcement (the optional rebind authorizer, TUS-10)
  stays Phase 44, which compares the resuming request's identity against the
  token `actor`. Capturing now is cheap forward-compat; deferring capture would
  leave Phase-42-era sessions permanently unrebindable or force a second
  migration.

### Protocol mechanics & PATCH hot path
- **D-06:** `TusPlug` pattern-matches on `conn.method`
  (`OPTIONS`/`POST`/`HEAD`/`PATCH`/`DELETE`) + the path suffix, mirroring the
  `WebhookPlug` shape (~345 lines). Surface: `POST` (`Upload-Length` + opaque
  `Upload-Metadata` → `201` + `Location`); `HEAD` (`204` + `Upload-Offset` from
  `last_known_offset` + `Cache-Control: no-store`); `PATCH`
  (`application/offset+octet-stream` → `204` + new `Upload-Offset`, **`409`** on
  offset mismatch — the contract tus-js-client auto-retries); `OPTIONS` (`204`
  advertising `Tus-Version`, `Tus-Resumable`, `Tus-Extension` = creation,
  expiration, termination ONLY, `Tus-Max-Size`); `DELETE` (`204`, terminates).
  `Upload-Expires` header + `410 Gone` on expired (driven by `expires_at`).
- **D-07:** PATCH read loop uses `Plug.Conn.read_body` with **`read_length:
  1_048_576` (1 MiB)** and a per-PATCH ceiling derived from the mount's
  `max_size`; a slow-loris PATCH cannot pin memory. These are fixed safety
  constants (per TUS-RESEARCH §2/§10), **not** adopter config — the only
  adopter-facing knob is `max_size` (mount opt). `Upload-Metadata` is treated as
  an untrusted/opaque hint, re-sniffed at `verify_completion` (invariants 1, 10).
- **D-08:** Completion (final PATCH, `offset == length`) atomic-renames the tmp
  file into the final key, then converges into the **unchanged**
  `verify_completion/2` (`broker.ex:418`): head-based re-sniff, size/type
  validation against the profile, `PromoteAsset` enqueued in the same
  `Ecto.Multi`. **Zero new completion vocabulary.**

### Capability, schema, FSM (carry-forward locks)
- **D-09:** Add exactly ONE atom `:tus_upload` to `Capabilities.@known` +
  `Storage.capability` type unions; `Local` advertises it, `GCS` does NOT (keeps
  native Topology-A resumable), `S3` deferred to Phase 43. `init/1` calls
  `Capabilities.require_upload(adapter, :tus_upload)` and **raises
  `ArgumentError`** on `{:error, {:upload_unsupported, :tus_upload}}` — a
  deploy-time failure matching `WebhookPlug.init/1`. **No silent downgrade** to
  presigned/multipart/GCS. (Note: `require_upload/2` returns a tuple, not a
  raise — the Plug wraps it.)
- **D-10:** Exactly ONE additive migration: `add :resumable_protocol, :string`
  (`"gcs_native" | "tus"`; nil for legacy) + covering index
  `[:upload_strategy, :resumable_protocol, :state]`. Reuse `upload_strategy:
  "resumable"` + the existing `"resuming"` FSM lane
  (`upload_session_fsm.ex:8-9`). **No `tus_*` columns, no new table, no new FSM
  states, no new completion vocabulary.** `last_known_offset` IS the tus
  `Upload-Offset`.
- **D-11:** `initiate_tus_upload/2` is a new broker entrypoint, sibling to
  `initiate_resumable_session/2` (`broker.ex:182`), reusing the
  `persist_resumable_session/5`-style persistence + compensation-on-failure
  pattern (`broker.ex:566-640`); it sets `resumable_protocol: "tus"`.
- **D-12:** Architect `TusPlug` as a **thin protocol-versioned edge**: offset
  bookkeeping, HMAC auth, Local backing, and `verify_completion` convergence are
  protocol-agnostic; only header parsing / response shaping is tus-1.0-specific.
  This makes IETF RUFH (tus 2.0) an additive second handler over the same session
  machinery, not a rewrite (TUS-RESEARCH §13) — and the `resumable_protocol`
  column already anticipates it.

### POLISH-01 — selective fix, not blanket --fix
- **D-13:** Do **NOT** run a blanket `/gsd-code-review 34 --fix`. The 4 Blockers
  are already fixed (commits in `34-REVIEW.md` front-matter). Of the 12 remaining
  advisories: **fix** WR-01, WR-02, WR-04, WR-05, WR-06, WR-08, WR-09, IN-02 (real
  correctness / observability / invariant-14-adjacent / test hygiene); **waive
  with one-line rationale** WR-07 (an *explicitly documented* v1.7 deferral —
  blindly fixing reverts a deliberate roadmap decision), IN-01, IN-03
  (defensive-only, no live caller); **WR-03** fix-or-document (planner's call).
  Net ≈ 8 fixes, ≈ 3 waivers, 1 either-way — keeps the POLISH-01 diff small and
  unrelated to tus code paths.
- **Locality note (surfaced, not actionable):** the requirement's "natural
  locality with the Mux files MUX-20..23 touch" rationale is weak — that Mux work
  is **Phase 45**, not 42 — so these fixes stand alone here. Roadmap-locked; not
  relitigated.

### Claude's Discretion
- D-04 token payload encoding details, exact path-segment format, and salt
  string (`"rindle:tus:url"` recommended) — implementer's call within D-03/D-04.
- D-07 read-loop constants tuning within the 1 MiB / `max_size` envelope.
- D-13 WR-03 fix-vs-document decision.

### Folded Todos
None folded via the todo system (no `todo.match-phase` matches). Two pre-existing
notes from STATE.md are already covered: the "thin protocol-versioned edge for
RUFH" design constraint → **D-12**; POLISH-01 fold into Phase 42 → **D-13**.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/research/v1.8/TUS-RESEARCH.md` — **AUTHORITATIVE, LOCKED**
  architecture. §3a bare-Plug/no-tussle, §3c Local backing, §4 protocol surface
  (IN vs DEFER), §5 capability vocabulary, §6 migration shape, §7 unification
  with v1.7, §9 auth/bearer-URL handling, §10 DX, §11 security-invariant check,
  §12 phase plan, §13 RUFH edge. Do not relitigate.
- `.planning/research/v1.8/STRATEGY-SEQUENCING.md` — phase sequencing + budget
  cut order (Phase 45 is the droppable release valve).
- `.planning/milestones/v1.6-phases/34-mux-rest-adapter-server-push-sync/34-REVIEW.md`
  — POLISH-01 source findings (4 Blockers already fixed; 12 advisories triaged in
  D-13).

**In-repo code templates (read before implementing):**
- `lib/rindle/delivery/webhook_plug.ex` — bare-Plug `forward` idiom + `init/1`
  fail-fast (`init/1` raises at `:86-102`; method guard `:105-111`).
- `lib/rindle/delivery/local_plug.ex` — `Plug.Crypto.sign/verify` bearer-token
  pattern (`:66`), manual `exp` check (`:67-72`), payload `actor_subject` (`:122`).
- `lib/rindle/upload/broker.ex` — `initiate_resumable_session/2` (`:182`),
  `persist_resumable_session/5` (`:566`), compensation (`:566-640`),
  `verify_completion/2` (`:418-485`, `Ecto.Multi` + Oban at `:465`).
- `lib/rindle/storage.ex` — behaviour + `@optional_callbacks` (`:282-285`),
  capability type union (`:17-24`).
- `lib/rindle/storage/capabilities.ex` — `@known` (`:20-28`), `require_upload/2`
  returns a tuple (`:49-57`).
- `lib/rindle/storage/local.ex` — current Local adapter (no multipart; first tus
  sink).
- `lib/rindle/domain/media_upload_session.ex` — schema (`:48-60`), redacting
  `Inspect` (`:104-113`), `@states` (`:36`).
- `lib/rindle/domain/upload_session_fsm.ex` — `"resuming"` lane (`:8-9`).
- `lib/rindle/ops/upload_maintenance.ex` — reaper branch points (multipart abort
  `:324-349`; resumable cancel `:413-467`, `:551-555`; query `:143`). Phase 42
  only ADDS the `resumable_protocol` column; teaching the reaper to branch on it
  is Phase 43/44.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **The entire v1.7 resumable substrate** — broker resumable entrypoints, the
  `"resuming"` FSM lane, `media_upload_sessions` (`session_uri`,
  `last_known_offset`, `multipart_*`, `expires_at`), the redacting `Inspect`,
  `ResumableTelemetry` (+ forbidden-metadata allowlist), and the
  `UploadMaintenance`/`AbortIncompleteUploads` reaper — are CONFIRMED present and
  reused verbatim. No drift from the research's cited lines.
- **`WebhookPlug` / `LocalPlug`** are directly-reusable bare-Plug templates: same
  `@behaviour Plug` + `init/1` fail-fast + `forward` mount + `Plug.Crypto`
  signing shape that `TusPlug` adopts.
- **`verify_completion/2`** is the trusted completion lane both topologies
  converge into — unchanged by Phase 42.

### Established Patterns
- Capability honesty is a hard constraint: `require_upload/2` returns
  `{:error, {:upload_unsupported, cap}}`; the Plug must escalate to an
  `init/1` `ArgumentError` (no silent downgrade).
- Bearer creds live in the signed token / redacted `session_uri`, never columns
  or logs (security invariant 14, already enforced).
- Temp files under the sweepable `Rindle.tmp/` root (invariant 13); tus uses
  `Rindle.tmp/tus/<session_id>`.
- Completion side effects (`PromoteAsset`) ride inside the same `Ecto.Multi`
  that marks the session completed — durable, not a best-effort hook (Rindle's
  differentiator vs tusd).

### Integration Points
- `TusPlug.call/2` → `Broker.initiate_tus_upload/2` (POST) and direct
  session/offset reads (HEAD/PATCH/DELETE) → Local tmp-append → atomic rename →
  `Broker.verify_completion/2` → `PromoteAsset`.
- `Capabilities.@known` + `Storage.capability` type + `Local` capabilities gain
  `:tus_upload`.
- One migration on `media_upload_sessions` (`resumable_protocol` + index).
</code_context>

<specifics>
## Specific Ideas

- HMAC salt string `"rindle:tus:url"` (mirrors the `LocalPlug` salt convention).
- Token payload shape: `%{session_id: id, actor: subject, exp: unix_ts}`.
- 409 (offset mismatch) and 410 (expired) are the two status codes tus-js-client
  treats specially — get them exactly right; they are the contract test's spine.
</specifics>

<deferred>
## Deferred Ideas

- Generic `upload_part_stream/5` adapter callback + S3 multipart-per-PATCH
  backing + MinIO proof — **Phase 43** (TUS-06..09).
- Rebind authorizer enforcement, `Rindle.Error` tus vocabulary, tus edge
  telemetry, `mix rindle.doctor` tus checks, `guides/resumable_uploads.md`,
  generated-app CI proof — **Phase 44** (TUS-10..14, POLISH-02).
- tus Checksum / Concatenation / `Upload-Defer-Length`, IETF RUFH (tus 2.0),
  GCS-as-tus-backend, R2-native tus proxy, Rindle-owned tus JS client, LiveView
  tus uploader component — **v1.9+ / out of scope** (TUS-RESEARCH §12).

### Reviewed Todos (not folded)
None — no `todo.match-phase` matches. STATE.md's two relevant notes (RUFH edge,
POLISH-01 fold) are captured as D-12 and D-13.
</deferred>
