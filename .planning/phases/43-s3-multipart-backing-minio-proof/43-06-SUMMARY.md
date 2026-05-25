---
phase: 43-s3-multipart-backing-minio-proof
plan: 06
subsystem: infra
tags: [s3, tus, multipart, storage, exaws, base64url, cross-node, gap-closure]

# Dependency graph
requires:
  - phase: 43-s3-multipart-backing-minio-proof
    provides: "TUS-06 S3 tail-buffer slice/accumulate logic (upload_part_stream/5, complete_part_stream/4, private tail_path/2 + tail_filename/1 canonical encoding)"
provides:
  - "Public Rindle.Storage.S3.tus_tail_path/2 — canonical reaper-facing tail path delegating to private tail_path/2 (single Base.url_encode64 encoding site preserved)"
  - "Cross-node resume guard in upload_part_stream/5 returning {:error, :tus_tail_missing} when the DB shows a mid-multipart upload but the node-local tail file is absent"
  - "S3 @moduledoc single-node / sticky-session deployment constraint documentation"
affects: [43-08-reaper-wiring, 43-07-sweeper, tus-multi-node-deployment]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Adapter owns the one canonical tail-path computation; consumers route through a public helper instead of re-deriving the encoding"
    - "Loud-fail tagged-atom error on data-integrity risk (silent corruption) instead of degraded silent success"
    - "Error surface is the bare atom only — no internal path / session_uri interpolation (security invariant 14 alignment)"

key-files:
  created: []
  modified:
    - lib/rindle/storage/s3.ex
    - test/rindle/storage/s3_tus_test.exs

key-decisions:
  - "tus_tail_path/2 delegates to private tail_path/2 (threads session_id as both key and :session_id) rather than duplicating Base.url_encode64 — keeps exactly one encoding site"
  - "Mid-multipart resume predicate = non-empty upload_id AND non-empty parts; committed parts is the reliable 'a prior node sliced a boundary' signal that avoids false-positives on a fresh first PATCH"
  - ":tus_tail_missing returns the bare atom only (no absolute path / session_uri) to avoid internal-path disclosure (threat T-43-06-02)"

patterns-established:
  - "Source-of-truth public helper: cleanup code consumes the adapter's own path computation, ending the raw-UUID vs base64url mismatch root cause"
  - "Cross-node integrity guard: detect shared-DB-vs-node-local-disk divergence and fail loudly, document the single-node constraint in the moduledoc"

requirements-completed: [TUS-06, TUS-09]

# Metrics
duration: 3min
completed: 2026-05-23
---

# Phase 43 Plan 06: S3 Adapter Gap Closure (CR-02 + CR-04) Summary

**Public `S3.tus_tail_path/2` source-of-truth helper (ends the reaper's raw-UUID vs base64url path mismatch) plus a loud-fail `{:error, :tus_tail_missing}` cross-node resume guard in `upload_part_stream/5` and a documented single-node / sticky-session constraint.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-05-23T12:13:50Z
- **Completed:** 2026-05-23T12:16:58Z
- **Tasks:** 2 (both `tdd="true"`, RED → GREEN)
- **Files modified:** 2

## Accomplishments

- **CR-02 source-of-truth:** Added public `Rindle.Storage.S3.tus_tail_path/2` that delegates to the existing private `tail_path/2`, so the adapter owns the one canonical `Base.url_encode64(id, padding: false) <> ".tail"` computation. Plan 43-08 can now route the reaper's `remove_tus_tail/1` through this helper, ending the raw-UUID-vs-base64url mismatch root cause. The encoding is not duplicated — there is still exactly one code-level encoding site (`tail_filename/1`).
- **CR-04 loud-fail guard:** Added `guard_local_tail_present/2` in the `upload_part_stream/5` `with` pipeline (before `append_to_tail/2`). When the threaded `state` shows a mid-multipart resume (non-empty `upload_id` AND a non-empty committed `parts` list) but the node-local tail file is absent, it returns `{:error, :tus_tail_missing}` instead of silently re-slicing from a fresh empty tail (the integrity failure CR-04 named). The error surface is the bare atom — no absolute path / session_uri leaked.
- **Single-node constraint documented:** Extended the S3 `@moduledoc` with a `## tus single-node constraint` section explaining the node-local-tail vs shared-DB split, the sticky-session routing requirement, and the loud-fail behaviour on a misrouted resume.
- **4 new regression tests** (2 per task), each RED against current code then GREEN after the fix.

## Task Commits

Each task was committed atomically (TDD: test → feat per task):

1. **Task 1 (RED): failing tests for `tus_tail_path/2`** - `81e0b7c` (test)
2. **Task 1 (GREEN): public `tus_tail_path/2`** - `a274db4` (feat)
3. **Task 2 (RED): failing cross-node guard tests** - `37d557a` (test)
4. **Task 2 (GREEN): cross-node guard + moduledoc** - `a6f9804` (feat)

_No REFACTOR commits needed — both implementations were minimal and clean on first GREEN._

## Files Created/Modified

- `lib/rindle/storage/s3.ex` - Added public `tus_tail_path/2` (delegates to private `tail_path/2`), `guard_local_tail_present/2` wired into `upload_part_stream/5`, and the `## tus single-node constraint` moduledoc section.
- `test/rindle/storage/s3_tus_test.exs` - Added two `describe` blocks: `tus_tail_path/2 (CR-02)` (helper matches the adapter-written tail; base64url encoding under `<root>/tus`, never the raw id) and `cross-node resume guard (CR-04)` (missing tail → `{:error, :tus_tail_missing}`; first PATCH → no false positive).

## Decisions Made

- **Delegate, don't duplicate:** `tus_tail_path/2` calls `tail_path/2` with `Keyword.put_new(opts, :session_id, session_id)` so the encoding is identical regardless of caller keying, preserving the single encoding site requirement (AC4).
- **`parts != []` as the mid-multipart signal:** A first PATCH legitimately has no committed parts and (usually) a nil `upload_id`, so requiring at least one committed part to trigger the guard prevents a false positive on the happy first-write path. A committed part is the reliable signal that a prior node already sliced and persisted a tail boundary.
- **Bare-atom error surface:** Per the threat model (T-43-06-02) and security invariant 14, `:tus_tail_missing` is returned alone — the absolute tail path and session_uri are never interpolated into the error term.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The initial first-PATCH negative test used `refute match?({:error, :tus_tail_missing}, {:ok, state})`, which the compiler flagged as a statically always-true clause. Restructured to bind `result` first, `refute match?(..., result)`, then `assert {:ok, state} = result` — a cleaner assertion with no spurious warning. This was a test-quality refinement within the RED phase, not a deviation from plan scope.

## Threat Model Coverage

- **T-43-06-01 (Tampering, cross-node resume):** mitigated — `guard_local_tail_present/2` returns `{:error, :tus_tail_missing}` when the DB shows mid-multipart but the local tail is absent.
- **T-43-06-02 (Information disclosure, error term):** mitigated — error surface is the bare atom; `grep` confirms no path/session_uri interpolation.
- **T-43-06-03 (Tampering, traversal via `tus_tail_path/2`):** accepted as planned — the helper delegates through `tail_filename/1`'s base64url encoding under a fixed `Rindle.tmp/tus/` prefix; it does not widen the surface.

No new threat surface introduced beyond the plan's threat register.

## Verification

- `mix test test/rindle/storage/s3_tus_test.exs` → 9 tests, 0 failures (5 existing TUS-06 + 4 new CR-02/CR-04).
- Full storage suite (`mix test test/rindle/storage/`) → 69 tests, 0 failures, 1 skipped.
- `mix compile --warnings-as-errors` → no warnings on changed files.
- `grep -n "def tus_tail_path"` → public def (line 235), not defp.
- `grep "tus_tail_missing"` → present in `upload_part_stream/5` flow; bare atom only.
- `grep -vn '^[[:space:]]*#'` count of `single-node`/`sticky` in moduledoc ≥ 1 (= 2).

## Next Phase Readiness

- **43-08 (reaper wiring) unblocked:** `S3.tus_tail_path/2` is the public, encoding-correct helper `remove_tus_tail/1` should route through.
- **43-07 (sweeper) clean to run in parallel:** This plan owns all `lib/rindle/storage/s3.ex` changes for the gap-closure set; no file-ownership conflict.
- No change to the tail-buffer slice/accumulate math or the existing TUS-06 contract; WR-03..WR-06 / IN-01/IN-02 untouched.

## Self-Check: PASSED

- Files: `lib/rindle/storage/s3.ex`, `test/rindle/storage/s3_tus_test.exs`, `43-06-SUMMARY.md` all present.
- Commits: `81e0b7c`, `a274db4`, `37d557a`, `a6f9804` all in git history.
