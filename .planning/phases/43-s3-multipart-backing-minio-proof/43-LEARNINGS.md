---
phase: 43
phase_name: "s3-multipart-backing-minio-proof"
project: "Rindle"
generated: "2026-05-23"
counts:
  decisions: 13
  lessons: 11
  patterns: 14
  surprises: 8
missing_artifacts: []
---

# Phase 43 Learnings: s3-multipart-backing-minio-proof

Phase 43 made an S3-compatible adapter serve tus by streaming each PATCH into an S3
multipart upload, converging through the unchanged `verify_completion/2` lane, with
abandoned sessions reliably reaped — proven against live MinIO (≥ 1 GiB drop+resume,
zero-leak abort). It ran as 5 build plans (01–05) followed by 7 surgical gap-closure
plans (06–12) driven by re-verification, finishing at 5/5 truths + live MinIO 3/3.

## Decisions

### `complete_part_stream` is arity 4, not arity 3 (locked contract)
Resolved the recurring inline-`/3` vs frontmatter-`/4` contradiction in favor of the
dominant `/4` signal: `complete_part_stream(key, temp_path, state, opts)` where
`temp_path :: String.t() | nil` is the final PATCH's residual handle, symmetric with
`upload_part_stream/5`. The `@optional_callbacks` entry, `key_links`, storage_adapter
test, and the RED tests all required `/4`; implementing `/3` would fail `@impl true`.

**Rationale:** A single locked contract across the behaviour, the S3 impl, the Local
impl, and the Plug dispatch — `/3` would break compilation and polymorphic dispatch.
**Source:** 43-01-SUMMARY.md (origin), reaffirmed in 43-02/43-04/43-05-SUMMARY.md

### Injectable ExAws request seam + offline stub for deterministic unit math
`S3.request/2` resolves its entrypoint through `Application.get_env(:rindle, S3)[:request_module]`
(default `ExAws`); `test/support/s3_multipart_request_stub.ex` fabricates well-formed
multipart responses (server-issued ETag in HEADERS) when no MinIO is configured, and
DELEGATES to real ExAws whenever `RINDLE_MINIO_*` is present.

**Rationale:** The un-tagged `s3_tus_test.exs` slice path runs in every lane and asserts
populated `parts`, which needs a successful `UploadPart` — impossible offline without a
seam. Production resolves the `ExAws` default; the MinIO lane uses real ExAws.
**Source:** 43-02-SUMMARY.md

### `:tus_upload` capability is an observability probe, not a hard gate on the abort
The reaper resolves the adapter from the profile and aborts the S3 multipart
unconditionally; the `:tus_upload` probe only emits a debug log when unadvertised.

**Rationale:** Hard-gating on the capability would (a) raise against the un-stubbed Mock
in the RED tests and (b) skip the abort for a real tus-on-S3 session in the pre-Plan-02
base — re-opening the exact cost leak TUS-09 closes. Failing to act IS the leak.
**Source:** 43-03-SUMMARY.md

### Polymorphic adapter dispatch with no `if adapter == Local` branch (D-12)
`TusPlug` dispatches PATCH → `adapter.upload_part_stream/5` and completion →
`adapter.complete_part_stream/4` purely through the behaviour. DELETE cleanup was
de-hard-wired from `Local.tus_part_path`; the abandoned file is swept by the reaper.

**Rationale:** Any future tus sink works without touching the Plug — the D-12 seam.
**Source:** 43-04-SUMMARY.md

### List-in-`:map`-column persistence: wrap S3 parts under a `"parts"` key
`multipart_parts` is `:map, null: false, default: %{}` (Phase 7). Ecto's `:map` rejects
a bare list (`Ecto.Type.cast(:map, [..]) == :error`). Non-empty parts persist as
`%{"parts" => list}` (the same convention `broker.ex` uses for presigned multipart),
unwrapped on read-back; Local persists the `%{}` default, never `nil`.

**Rationale:** Round-trips S3 parts through the row for resume without a new migration
(D-10 budget honored) and avoids the NOT NULL violation a bare `nil` would cause.
**Source:** 43-04-SUMMARY.md

### `tus_tail_path/2` delegates to the private `tail_path/2` (single encode site)
The public reaper-facing helper threads `session_id` as both key and `:session_id` into
the private function rather than re-deriving `Base.url_encode64`, preserving exactly one
encoding site (`tail_filename/1`).

**Rationale:** Source-of-truth: cleanup code consumes the adapter's own canonical path
computation, ending the raw-UUID-vs-base64url mismatch that left orphaned tail files.
**Source:** 43-06-SUMMARY.md

### Cross-node resume fails loudly with `{:error, :tus_tail_missing}`
When the DB shows a mid-multipart upload but the node-local tail file is absent, the
guard returns a bare tagged atom instead of silently re-slicing from a fresh empty tail.
The S3 moduledoc documents the single-node / sticky-session deployment constraint.

**Rationale:** Loud-fail on a data-integrity risk beats degraded silent success
(silent object corruption). The bare atom carries no path/session_uri (invariant 14).
**Source:** 43-06-SUMMARY.md, 43-12-SUMMARY.md

### Shared `gated_expire/2` FSM gate for ALL expiry branches (WR-01)
Extracted one helper that gates persistence on `UploadSessionFSM.transition`; both the
standard and tus expiry branches route through it.

**Rationale:** A single invariant site means a future query-set expansion can never
silently flip a tus session from an FSM-forbidden state. Chosen over duplicating the gate.
**Source:** 43-08-SUMMARY.md

### Marker + reaper-query compensation over leave-the-row + return 5xx (CR-01)
A DELETE whose backing abort fails stamps a retryable `tus_abort_failed:<reason>` marker
and still returns 204; `fetch_retryable_tus_abort_sessions/0` re-selects the row and the
reaper re-aborts on the next cron.

**Rationale:** Consistent with the existing GCS `resumable_cancel_failed:%` architecture,
keeps DELETE operator-friendly (204), and is TTL-independent (re-selectable immediately,
not gated on `expires_at`). Telemetry/metadata-driven compensation over a wider error surface.
**Source:** 43-11-SUMMARY.md

### WR-03: recovered aborted-tus row settles WITHOUT the FSM gate
`persist_tus_abort_retry_success/2` does a direct repo update to `state: "expired"`
(marker cleared), bypassing `UploadSessionFSM.transition` — keyed on the
`tus_abort_failed:` marker, not bare `state == "aborted"`.

**Rationale:** The FSM declares `aborted => []` terminal; routing a recovered row through
`gated_expire` would attempt the forbidden `aborted -> expired`, log invalid_transition,
increment `abort_errors`, and re-select forever (silent infinite retry). Marker-keying
preserves the WR-01 GCS-marker FSM-gated path.
**Source:** 43-11-SUMMARY.md

### DELETE aborts the backing store BEFORE the state changeset, best-effort
`handle_delete/2` invokes the shared `abort_tus_backing/2` (adapter+root from `opts`,
upload_id from the row) before the `aborted` transition; the abort is logged-not-raised,
so the row still moves to `aborted` even if the remote abort errors.

**Rationale:** Closes the explicit-cancel cost leak while keeping DELETE robust; reuses
the adapter+root already in Plug opts (no DB profile re-resolution on the hot path).
**Source:** 43-09-SUMMARY.md

### Offset-aware cross-node signal: `offset > committed_part_bytes` (CR-04)
The guard fires on `(parts != [] OR offset > committed_part_bytes)` where
`committed_part_bytes = length(parts) * @s3_min_part_size`, threading `base_offset` into
the guard.

**Rationale:** `parts != []` alone missed the pre-first-part window — a sub-5-MiB first
PATCH sets `upload_id` and buffers a tail but commits no part. `offset == 0` keeps the
brand-new first PATCH unguarded (no false positive).
**Source:** 43-12-SUMMARY.md

### MinIO integration assertions compute paths/keys via the adapter's OWN helpers
Tests resolve the tail root EXPLICITLY as `opts[:root] || TempRunDir.root_dir()` and
compute the expected path via `S3.tus_tail_path/2` (never a hardcoded raw-UUID path), so
the write-path and assertion-path roots are provably identical.

**Rationale:** Prevents a false-green where the assertion checks a different path than the
code writes — the exact class of bug CR-02 closed at the source level.
**Source:** 43-10-SUMMARY.md

---

## Lessons

### A stale `/3` arity in plan bodies propagated across three plans
Despite Plan 01 locking `complete_part_stream/4`, the plan bodies for 43-02 and 43-04
(and 43-05's note) still carried the obsolete `/3` signature, forcing the same Rule-3
reconciliation three times.

**Context:** Interface-first phases must lock the contract once AND scrub every
downstream plan body, or each executor re-discovers and re-resolves the same contradiction.
**Source:** 43-01/43-02/43-04/43-05-SUMMARY.md (Deviations)

### The Profile DSL rejects arithmetic `max_bytes` at compile time
`max_bytes: 2 * 1024 * 1024 * 1024` failed `NimbleOptions.validate!` — the DSL requires a
literal positive integer. Use `2_147_483_648` (keep a module attr for runtime use).

**Context:** Compile-time validated DSLs do not evaluate arithmetic; literal-only fields
need literal values.
**Source:** 43-01-SUMMARY.md

### Ecto `:map` columns reject bare lists, and `null: false` rejects `nil`
Persisting S3's bare `parts` list into `multipart_parts` failed the changeset cast;
persisting Local's `nil` violated the NOT NULL `default: %{}` constraint.

**Context:** Wrap lists in a map (`%{"parts" => list}`) and persist the `%{}` default
rather than `nil` for absent values — verify column types before assuming "persist nil gracefully."
**Source:** 43-04-SUMMARY.md

### A literal capability gate would have re-opened the leak it guarded
Implementing `resolve_tus_adapter/1` as a hard `Capabilities.require_upload` gate broke
the RED tests (un-stubbed `capabilities/0` raised, swallowed to `[]`, abort skipped) AND
would skip the abort for a real S3 session before Plan 02 advertised `:tus_upload`.

**Context:** When *failing to act* is the threat, a capability check belongs as
observability, not as a hard precondition on the safety-critical action.
**Source:** 43-03-SUMMARY.md

### A Local-only path must not capability-probe the remote adapter
`resolve_local_root/1` initially called `resolve_tus_adapter/1`, dragging a
`StorageMock.capabilities()` Mox interaction into the Local reaper path and breaking
`verify_on_exit!`. The Local adapter owns its own root resolution (`Local.root([])`).

**Context:** A Local-only abort has no remote backing to probe; resolve roots directly
and keep Mox interactions out of paths that don't touch the remote.
**Source:** 43-08-SUMMARY.md

### `MediaUploadSession.changeset/2` does not enforce the FSM
The changeset only does `validate_inclusion(:state, @states)` — an FSM-illegal-state
trigger (e.g. `completed -> aborted`) would SUCCEED at the update level. Testing the
WR-02 update-failure path required a probe repo forcing `update/1 -> {:error, changeset}`.

**Context:** FSM legality lives in `UploadSessionFSM.transition`, not the changeset;
don't assume a changeset will reject a state the FSM forbids.
**Source:** 43-09-SUMMARY.md

### `mix test -x` (fail-fast) is not a valid flag in this Elixir
Elixir 1.19.5's Mix/ExUnit rejects `-x` (prints usage). Plans/validation that referenced
it ran the full-file `mix test <path>` instead — same verification intent.
**Context:** Verify tool flags against the actual toolchain version before baking them
into plan acceptance criteria.
**Source:** 43-07-SUMMARY.md, 43-09-SUMMARY.md

### Live MinIO surfaced a pre-existing test bug invisible offline
The 43-10 post-reap tail test PATCHed the full `Upload-Length`, which COMPLETED the
upload and flushed/removed the tail (via `complete_part_stream -> File.rm`) BEFORE its own
"tail exists before reaping" assertion. Product behaviour was correct (completed uploads
leave no tail); the test's precondition was wrong. Fixed in 5343e4f by declaring
`Upload-Length > patched bytes` so the session stays abandoned.

**Context:** A `@tag :minio` test excluded from the default suite can harbor a logic bug
that only the live run reveals — the live proof is load-bearing, not ceremonial.
**Source:** 43-VERIFICATION.md (minio_live_run notes)

### ≥ 1 GiB through the pipeline exceeds the default Ecto sandbox ownership window on Mac/Docker
The local live run needed a temporary `ownership_timeout` bump (since reverted) because
pushing ≥ 1 GiB on Docker Desktop exceeds the default 120s window; CI (Linux) completes
under 120s with defaults.

**Context:** Disk-backed (not tmpfs) MinIO + a temporary ownership_timeout bump is the
documented recipe for running the suite locally on Mac. See also the MinIO local-run reference.
**Source:** 43-VERIFICATION.md (minio_live_run notes)

### Gap-closure introduced two latent (currently-benign) risks flagged in code review
The standard-depth review of the CR-01/CR-04 diff found: (WR-01) a Local-backed tus
session stamped with a `tus_abort_failed:%` marker can never be re-selected because the
reaper query requires `not is_nil(multipart_upload_id)` — benign today (Local abort always
returns `:ok`) but a latent silent-orphan if Local abort ever returns `{:error, _}`; and
(WR-02) `guard_local_tail_present/3` dropped the prior `is_list(parts)` defense before
calling `length/1`, which would raise on a malformed persisted map.

**Context:** Closing a gap can quietly narrow a defensive invariant; both findings are
unaddressed warnings worth carrying into Phase 44 hardening.
**Source:** 43-REVIEW.md (WR-01, WR-02)

### Fresh worktrees have no `deps/` — a lockfile fetch, not a package install
Several plans hit `mix compile` errors on a clean worktree and resolved with
`mix deps.get` (or symlinking the main repo's `deps/`) from the existing `mix.lock` — no
version resolution, no new packages, so the package-legitimacy checkpoint did not apply.
**Context:** Distinguish a lockfile cache fetch from a genuine package install when
narrating worktree setup deviations.
**Source:** 43-01/43-02/43-04-SUMMARY.md

---

## Patterns

### OPTIONAL `@callback` gated by a capability atom
Declare `upload_part_stream/5` + `complete_part_stream/4` in `@optional_callbacks` so
adapters that don't advertise `:tus_upload` (GCS) still compile, mirroring the four
existing resumable callbacks.

**When to use:** Adding a capability-specific behaviour callback to a shared adapter
contract without forcing every adapter to implement it.
**Source:** 43-01-SUMMARY.md

### tusd-style S3 tail-buffer (accumulate on disk, slice 5 MiB parts, flush remainder)
Stream each PATCH onto `<root>/tus/<id>.tail` in 1 MiB chunks; while the tail is ≥ 5 MiB
slice exactly one `UploadPart` with a strictly-increasing 1-based `part_number`; flush the
sub-5-MiB remainder as the final part on completion. The body never lands as one heap binary.

**When to use:** Translating an arbitrary-sized resumable byte stream into S3 multipart
parts under the 5 MiB minimum-part-size constraint.
**Source:** 43-02-SUMMARY.md

### Read the ETag from S3 response HEADERS, never the body
`UploadPart` has no body parser; `etag_from_headers/1` lowercase-normalizes headers and
`Map.get("etag")`, returning `{:error, :missing_etag}` when absent.

**When to use:** Any S3 op whose result you need lives in a response header rather than a
parsed XML body.
**Source:** 43-02-SUMMARY.md

### Injectable request seam via `Application.get_env` defaulting to the real client
Route the external call through a configurable module (default = the real SDK) so tests
can substitute a deterministic stub while production and the integration lane use the SDK.

**When to use:** A code path runs in every test lane but needs a live external service to
return a real result offline.
**Source:** 43-02-SUMMARY.md

### Reaper strategy dispatch via `cond` on a discriminator column, most-specific first
`expire_session/2` is a `cond` with `tus_session?/1` first, then the resumable check, then
standard — the tus branch is reaped BEFORE the resumable check (load-bearing order).

**When to use:** A single background job must handle several lifecycle strategies keyed on
a row column, where mis-ordering routes a row down the wrong (leaky) lane.
**Source:** 43-03-SUMMARY.md

### Idempotent backing abort: `{:error, :not_found}` == `:ok`
Treat a not-found remote resource as successful expiry; on a hard error leave the row and
increment `:abort_errors` for the next cron, never aborting the per-session reduce.

**When to use:** Best-effort cleanup of remote resources that may already be gone, where a
single failure must not stall the batch.
**Source:** 43-03-SUMMARY.md

### Polymorphic adapter dispatch via `opts[:adapter].callback`
Dispatch through the behaviour with no `if adapter == X` branch; thread only
non-credential opts (`session_id`, `root`) and let the adapter resolve creds via its own
app-env fallback.

**When to use:** Edge code (a Plug) must work against multiple backends without knowing or
holding backend-specific config.
**Source:** 43-04-SUMMARY.md

### Convergence proof: assert the EFFECTS of a frozen function, never touch it
The MinIO proof asserts `session completed`, `asset validating`, `byte_size`, and
`assert_enqueued(PromoteAsset)` to prove convergence into `verify_completion/2` — proving
the integration without modifying the byte-for-byte-frozen `broker.ex` (D-08).

**When to use:** Proving new code integrates with a frozen/locked function you must not edit.
**Source:** 43-05-SUMMARY.md

### Zero-leak proof: abandon → expire → reap → assert `list_multipart_uploads` empty
Drive a session to abandonment, force it past TTL, run the reaper, then assert the object
store lists no orphaned multipart for the key — on BOTH the timeout and explicit-DELETE
termination paths.

**When to use:** Proving a cost-leak (orphaned remote resource) mitigation end-to-end
against the real store.
**Source:** 43-05-SUMMARY.md, 43-10-SUMMARY.md

### Lazy synthetic byte stream so a ≥ 1 GiB body never materializes
Use `Stream.cycle/take` to generate the upload body; the full size is never a single
binary in the test process.

**When to use:** Integration tests that must push very large payloads without exhausting
memory.
**Source:** 43-05-SUMMARY.md

### Source-of-truth public helper — consumers route through the adapter's own computation
Cleanup/reaper code calls the adapter's public path helper (`S3.tus_tail_path/2`) instead
of re-deriving the encoding, ending divergent path math at the root.

**When to use:** Two subsystems must agree on a computed key/path; one owns the canonical
computation and exposes it.
**Source:** 43-06-SUMMARY.md, 43-08-SUMMARY.md

### Special-case a named subdir for per-file aging where the dir mtime is perpetually fresh
The sweeper recurses into `tus/` and ages individual regular files by their own mtime,
because the shared `tus/` dir mtime is bumped on every write and so whole-dir aging never
fires. Deletion is confined to `type: :regular` files under `<root>/tus/`.

**When to use:** A directory-mtime-based aging sweeper silently skips a shared subdir whose
mtime is continuously refreshed by active writes.
**Source:** 43-07-SUMMARY.md

### Marker + reaper-query compensation for a transient remote-abort failure
On a failed abort, stamp a bounded retryable `failure_reason` marker and add a dedicated
reaper query that re-selects + re-acts on the next cron — TTL-independent, client still
gets 204. Mirror the existing GCS retry pattern rather than inventing a second model.

**When to use:** A termination path's remote cleanup can fail transiently and must be
retried without surfacing the failure to the caller.
**Source:** 43-11-SUMMARY.md

### Prove ordering at RUNTIME with a Mox expectation, not just source order
`Mox.expect` + `verify_on_exit!` proves the backing abort fired even on the update-failure
path (a probe repo forces `update/1 -> {:error, _}`), proving "abort precedes transition"
behaviorally rather than by reading the source top-to-bottom.

**When to use:** Asserting that one side effect provably precedes/occurs regardless of a
later failure, not merely that the lines are in order.
**Source:** 43-09-SUMMARY.md

---

## Surprises

### The whole phase took 12 plans and 3 verification rounds, not the planned 5
After the 5 build plans (01–05), re-verification dropped to 3/5 and spawned 7 surgical
gap-closure plans (06–12) closing CR-01/CR-02/CR-03/CR-04 + WR-01/WR-02/WR-03/IN-03 before
reaching 5/5. Most gap-closure plans were tiny and fast (2–6 min each).

**Impact:** The "real" cost of a cost-leak-mitigation phase was in the long tail of
edge-case closure (cross-node, abort-failure, sweeper backstop), not the headline streaming code.
**Source:** 43-06..43-12-SUMMARY.md, 43-VERIFICATION.md

### Closing the cost leak naively would have re-opened it
Both a literal `:tus_upload` capability gate (43-03) and the original `parts != []`-only
cross-node signal (43-12) looked correct but left the exact orphan/corruption window TUS-09
set out to close.

**Impact:** The mitigations needed a second pass once the failure modes were understood;
"the obvious guard" was the wrong guard twice.
**Source:** 43-03-SUMMARY.md, 43-12-SUMMARY.md

### The post-reap tail test was green offline but tested the wrong precondition
It only failed (correctly) once run against live MinIO, which revealed the upload had
already completed and removed the tail before the test's own "tail exists" assertion.

**Impact:** Confidence from a passing excluded test was misplaced; the live gate caught a
real test-logic bug. Fixed in 5343e4f.
**Source:** 43-VERIFICATION.md (minio_live_run notes)

### CR-01 had a hidden second half: the abort-FAILURE branch
43-09 fixed the happy-path ordering (abort before transition), but `abort_delete_backing/2`
still swallowed `{:error, _}` and no reaper query ever re-selected an `aborted` row — a
transient blip orphaned the multipart forever. 43-11 was needed to make that branch recoverable.

**Impact:** "Abort on DELETE" was not done until the abort's own failure was made
reaper-recoverable — the FSM `aborted => []` terminal state nearly caused a silent infinite retry.
**Source:** 43-11-SUMMARY.md

### A plan said "create a new test file" that already existed with 8 tests
43-07's action instructed creating `sweep_orphaned_temp_files_test.exs`; the file already
existed and a same-named module would have collided. The executor extended it instead.

**Impact:** Plan authoring assumed a greenfield file; reconciling against the real tree was
required (Rule-3 deviation).
**Source:** 43-07-SUMMARY.md

### A FSM-forbidden state was needed to even author the WR-01 RED test
The reaper's query set only surfaces FSM-legal `signed`/`uploading`/`resuming` tus states
(all legal → `expired`), so proving the FSM gate refuses a forbidden transition required an
`aborted` tus session surfaced via the retryable-abort query.

**Impact:** Testing the guard meant manufacturing an out-of-band state the normal query
never yields — the RED was non-obvious to construct.
**Source:** 43-08-SUMMARY.md

### `length/1` quietly replaced a type guard during gap-closure
Strengthening the cross-node guard to compute `length(parts) * @s3_min_part_size` dropped
the prior `is_list(parts)` defense, so a malformed persisted `multipart_parts` would now
crash with an opaque `ArgumentError` instead of falling through safely (review WR-02).

**Impact:** A correctness improvement narrowed a defensive invariant — currently
unreachable but a latent crash, flagged but not yet fixed.
**Source:** 43-REVIEW.md (WR-02)

### Out-of-scope flaky AV/ffmpeg tests surfaced under full-suite parallel load
The final full `mix test` showed 1–4 non-deterministic `Ffmpeg`/`AV` processor failures
(different each run); they pass in isolation. Plan 43-05 only added excluded `@tag :minio`
tests, so this is a pre-existing resource-contention flake, not a regression.

**Impact:** Deferred to AV processor maintenance (candidate fix: serialize the ffmpeg-bound
tests); noise that could mask real failures in future full-suite runs.
**Source:** 43-05-SUMMARY.md, deferred-items.md

---

_Extracted from 12 PLAN + 12 SUMMARY files plus VERIFICATION, HUMAN-UAT, REVIEW,
SECURITY, VALIDATION, deferred-items, and STATE.md. The `capture_thought` MCP tool was
not present in this session; output is file-only (expected graceful degradation)._
