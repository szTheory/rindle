---
phase: 43-s3-multipart-backing-minio-proof
plan: 09
subsystem: api
tags: [tus, plug, s3-multipart, termination, cost-leak, mox, elixir]

# Dependency graph
requires:
  - phase: 43-s3-multipart-backing-minio-proof (plan 08)
    provides: "PUBLIC Rindle.Ops.UploadMaintenance.abort_tus_backing/2 — arity-2 polymorphic backing abort (S3 multipart abort / Local tmp removal)"
provides:
  - "tus DELETE (Termination) now aborts the backing store BEFORE the state transition — closes the headline CR-01 cost leak (no orphaned S3 multipart on explicit cancel)"
  - "tus DELETE honours the lifecycle update result — returns 5xx on a failed update instead of a misleading 204 (WR-02)"
  - "TusPlug moduledoc documents the single-node / sticky-session deployment constraint for S3 tus backing (CR-04 Plug half)"
  - "Mox regression suite proving the abort fires (even on the update-failure path) and that token auth is provably unchanged"
affects: [43-10, tus-delete, sc4-delete-no-leak, sc5-minio-delete-proof]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "DELETE aborts the backing store BEFORE the state changeset, dispatched through the shared PUBLIC abort_tus_backing/2 with the adapter+root the Plug already holds (no DB profile re-resolution on the hot path)"
    - "Mox expect + verify_on_exit! used to prove the abort precedes the update at RUNTIME (abort expectation satisfied even when the DB update fails) rather than only in source order"
    - "Probe-repo test pattern: a thin module delegating get/* to AdopterRepo while forcing update/1 to return {:error, changeset}, swapped in via Application.put_env(:rindle, :repo, _) to deterministically exercise the {:error, _} update branch"

key-files:
  created: []
  modified:
    - lib/rindle/upload/tus_plug.ex
    - test/rindle/upload/tus_plug_test.exs

key-decisions:
  - "tus DELETE aborts the backing store BEFORE the state changeset via the shared PUBLIC abort_tus_backing/2 (adapter+root from opts, upload_id from the row); abort is best-effort (logged, not raised), the row still moves to aborted (CR-01)"
  - "tus DELETE matches the lifecycle update result and returns 5xx on {:error, _} so the client is never falsely told the upload was terminated (WR-02)"
  - "WR-02 update-failure path is proven with a probe repo forcing update/1 -> {:error, _} (the changeset/FSM is permissive on completed->aborted, so an FSM-illegal-state trigger would NOT have failed the update)"

patterns-established:
  - "Backing abort precedes the state transition on Termination — proven on the failure path by a Mox abort assertion, not just source ordering"
  - "Hot-path adapter dispatch reuses the adapter+root already in Plug opts; no DB profile re-resolution on DELETE"

requirements-completed: [TUS-09]

# Metrics
duration: 4min
completed: 2026-05-23
---

# Phase 43 Plan 09: tus DELETE Backing Abort + Update-Result Honouring Summary

**tus DELETE now aborts the S3 multipart (or removes the Local tmp) BEFORE the `aborted` transition via the shared `abort_tus_backing/2`, returns 5xx on a failed update, and the Plug moduledoc documents the single-node S3 tus constraint — closing CR-01, WR-02, and the CR-04 Plug half.**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-05-23T12:34:14Z
- **Completed:** 2026-05-23T12:37:32Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- **CR-01 (headline cost leak) closed:** `handle_delete/2` now invokes the shared PUBLIC `Rindle.Ops.UploadMaintenance.abort_tus_backing(session, adapter:, root:, upload_id:)` BEFORE the `state: "aborted"` changeset. For S3 this aborts the multipart upload (no permanent orphan / cost leak); for Local it removes the tmp part/tail. The false comment claiming the `Rindle.tmp/` reaper sweeps the remote multipart is removed. SC4 (DELETE no-leak) is now achievable.
- **WR-02 closed:** the lifecycle `Config.repo().update()` result is now matched — `{:ok, _}` → 204, `{:error, _}` → 5xx — so a failed update never falsely tells the client the upload was terminated while the row stays re-PATCHable / mis-reaped.
- **CR-04 (Plug half) documented:** a "Deployment constraint (S3 tus backing)" subsection in the `TusPlug` moduledoc documents the single-node / sticky-session requirement and the loud-fail `{:error, :tus_tail_missing}` cross-node behaviour, mirroring the S3 adapter moduledoc.
- **Provable safety:** token auth order is unchanged (the abort runs only after `verify_token` + `load_active_session` succeed); a tampered-token DELETE returns 404 and never invokes the abort.

## Task Commits

Each task was committed atomically:

1. **Task 1 (RED): failing regression tests for DELETE backing abort + update honouring** - `46ee137` (test)
2. **Task 1 (GREEN): handle_delete/2 aborts backing before the transition + honours update result** - `7308f03` (feat)
3. **Task 2: single-node / sticky-session constraint in the TusPlug moduledoc** - `c337933` (docs)

_TDD task 1 = RED (`46ee137`) → GREEN (`7308f03`); no REFACTOR needed (implementation was clean)._

## Files Created/Modified
- `lib/rindle/upload/tus_plug.ex` - `handle_delete/2` rewritten to abort the backing store (via `abort_tus_backing/2`) BEFORE the state changeset and to match the update result (5xx on failure); new `abort_delete_backing/2` private dispatch with best-effort logging; added `UploadMaintenance` alias + `require Logger`; new "Deployment constraint (S3 tus backing)" moduledoc subsection.
- `test/rindle/upload/tus_plug_test.exs` - updated the existing Local DELETE test to assert the tmp part file is removed by DELETE (with corrected comment); new "Plan 09" describe block with the S3 abort-success test, the WR-02 update-failure-with-abort-fired test (via a `DeleteFailRepo` probe), and the tampered-token-no-abort test; added the `DeleteFailRepo` probe module + `mock_create_s3/2` helper.

## Decisions Made
- **Abort before transition, best-effort:** the backing abort is sequenced before the `aborted` changeset and is best-effort (logged via `rindle.tus.delete_backing_abort_failed`, never raised) — the row still moves to `aborted` even if the remote abort errors, and the reaper compensates on the next cron. This preserves the closed cost leak while keeping DELETE robust.
- **Hot-path dispatch reuses opts:** the abort uses the adapter + root already in the Plug `opts` (set in `init/1`) — no DB profile re-resolution on the DELETE hot path, and no `if adapter == Local` branch (D-12 storage-agnosticism preserved). Call shape is byte-for-byte the reaper's: `abort_tus_backing(session, adapter: opts[:adapter], root: opts[:root], upload_id: session.multipart_upload_id)`.
- **Probe-repo for the WR-02 failure path:** `MediaUploadSession.changeset/2` does NOT enforce the FSM (it only `validate_inclusion(:state, @states)`), so an FSM-illegal-state trigger (e.g. `completed -> aborted`) would have SUCCEEDED at the update level. To deterministically exercise the `{:error, _}` update branch without a contrived DB-constraint hack, the test swaps in a `DeleteFailRepo` probe (delegates `get/*`, forces `update/1 -> {:error, changeset}`) via `Application.put_env(:rindle, :repo, _)`, restoring `AdopterRepo` after.

## Deviations from Plan

The plan's Task 1 `behavior` proposed two interchangeable triggers for the WR-02 update failure: "a probe repo returning {:error, changeset} for the update, OR a session in a state where 'aborted' is illegal so the changeset/FSM fails." During RED I discovered the second option is not viable here — `MediaUploadSession.changeset/2` is permissive (no FSM gate on `state`), so an FSM-illegal-state update would not fail. I selected the plan's first sanctioned option (probe repo). This is using a plan-offered alternative, not a deviation from intent; no auto-fix rule was triggered, and the success criteria (5xx on failed update + abort already fired) are met as specified.

**Total deviations:** 0 auto-fixed.
**Impact on plan:** None — chose the plan's explicitly-offered probe-repo trigger over the non-viable FSM-illegal-state trigger.

## Issues Encountered
- The plan's `verify` command `mix test ... -x` is not a valid flag in this Mix/ExUnit version (`-x` printed usage). Ran the equivalent full-file verification `mix test test/rindle/upload/tus_plug_test.exs` instead — 26 tests, 0 failures.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- SC4 (DELETE no-leak) is now achievable: the DELETE handler aborts the backing store before the transition, proven on both the success and the update-failure path.
- 43-10 (SC5 DELETE MinIO proof) depends on this and is now unblocked — the live MinIO DELETE proof can assert the S3 multipart is aborted on Termination.
- CR-04 is now fully documented across both halves (S3 adapter moduledoc in 43-06, TusPlug moduledoc here).
- No blockers.

## Self-Check: PASSED

- FOUND: `lib/rindle/upload/tus_plug.ex`
- FOUND: `test/rindle/upload/tus_plug_test.exs`
- FOUND: `.planning/phases/43-s3-multipart-backing-minio-proof/43-09-SUMMARY.md`
- FOUND commits: `46ee137` (RED test), `7308f03` (GREEN feat), `c337933` (docs), `b4b94d7` (summary)

## TDD Gate Compliance

Task 1 followed the RED → GREEN cycle: `test(43-09)` commit `46ee137` (failing regression tests) precedes `feat(43-09)` commit `7308f03` (implementation). No REFACTOR commit was needed (implementation was clean on first pass).

---
*Phase: 43-s3-multipart-backing-minio-proof*
*Completed: 2026-05-23*
