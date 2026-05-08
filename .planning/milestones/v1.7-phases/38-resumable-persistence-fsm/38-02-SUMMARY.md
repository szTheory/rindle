---
phase: 38-resumable-persistence-fsm
plan: 02
subsystem: domain
tags: [ecto, fsm, inspect, resumable-uploads]
requires:
  - phase: 38-01
    provides: resumable upload-session persistence columns in the packaged migration
provides:
  - MediaUploadSession resumable persistence fields and cast support
  - session_uri inspect redaction for upload sessions
  - locked signed -> resuming -> uploading FSM coverage
affects: [phase-39, upload-broker, operator-surfaces]
tech-stack:
  added: []
  patterns: [custom-inspect-redaction, narrow-fsm-transition-lane, test-first-domain-coverage]
key-files:
  created: [test/rindle/domain/media_upload_session_test.exs]
  modified:
    [
      lib/rindle/domain/media_upload_session.ex,
      lib/rindle/domain/upload_session_fsm.ex,
      test/rindle/domain/lifecycle_fsm_test.exs
    ]
key-decisions:
  - "Kept the new resumable fields optional in changeset/2 by preserving the existing validate_required list."
  - "Redacted only session_uri in Inspect so the rest of MediaUploadSession remains inspectable for operators and tests."
  - "Restricted resuming to the exact signed -> resuming -> uploading recovery lane plus terminal exits."
patterns-established:
  - "Domain secrets use centralized helper-backed redaction in defimpl Inspect blocks."
  - "Upload-session FSM changes land with explicit matrix assertions for both nominal and recovery lanes."
requirements-completed: [RESUMABLE-02]
duration: 1 min
completed: 2026-05-07
---

# Phase 38 Plan 02: Resumable upload-session fields, inspect redaction, and locked recovery FSM

**MediaUploadSession now persists resumable session metadata safely, redacts bearer session URIs from inspect output, and exposes a narrow durable `resuming` recovery lane.**

## Performance

- **Duration:** 1 min
- **Started:** 2026-05-07T15:59:22-04:00
- **Completed:** 2026-05-07T16:00:27-04:00
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added `session_uri`, `session_uri_expires_at`, `last_known_offset`, and `region_hint` to `MediaUploadSession` and cast them without widening required-field semantics.
- Added centralized `redact_session_uri/1` plus a custom `Inspect` implementation that prevents raw resumable bearer URIs from appearing in inspect output.
- Extended `UploadSessionFSM` with the exact `signed -> resuming -> uploading` lane and regression coverage blocking `uploading -> resuming`.

## Task Commits

1. **Task 1: Extend MediaUploadSession schema and Inspect redaction per D-14..D-16**
   - `f41d732` `test(38-02): add failing media upload session coverage`
   - `69ee9ee` `feat(38-02): implement resumable session persistence fields`
2. **Task 2: Add the explicit resuming lane to UploadSessionFSM per D-10..D-13**
   - `8628f5f` `test(38-02): add failing resumable fsm coverage`
   - `7551b7c` `feat(38-02): implement resumable fsm recovery lane`

## Files Created/Modified

- `lib/rindle/domain/media_upload_session.ex` - Added resumable persistence fields, cast support, `redact_session_uri/1`, and custom inspect redaction.
- `lib/rindle/domain/upload_session_fsm.ex` - Added the locked `resuming` transition lane.
- `test/rindle/domain/media_upload_session_test.exs` - Added schema cast and inspect redaction coverage.
- `test/rindle/domain/lifecycle_fsm_test.exs` - Added transition-matrix coverage for explicit recovery and invalid backward edges.

## Decisions Made

- Preserved the existing required-field contract in `MediaUploadSession.changeset/2`; the new resumable fields are additive and optional in Phase 38.
- Used a dedicated `redact_session_uri/1` helper so inspect redaction stays centralized and reusable.
- Allowed terminal exits from `resuming` but did not introduce any backward or probe-only edges.

## Verification

- `mix test test/rindle/domain/media_upload_session_test.exs` -> PASS
- `mix test test/rindle/domain/lifecycle_fsm_test.exs test/rindle/domain/media_upload_session_test.exs` -> PASS
- Task 1 acceptance greps for all four schema fields, `def redact_session_uri`, `defimpl Inspect`, and `[REDACTED]` -> PASS
- Task 2 acceptance greps for the `signed` allowlist, `resuming` allowlist, and the three lifecycle assertions -> PASS

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Replaced invalid `mix test ... -x` verification commands with executable file-scoped `mix test` runs**
- **Found during:** Task 1 verification
- **Issue:** The plan's acceptance and verification commands use `-x`, which this Mix version rejects as an unknown option before tests can run.
- **Fix:** Used the equivalent file-scoped `mix test ...` commands for RED/GREEN and acceptance verification, while keeping the same test scope.
- **Files modified:** `.planning/phases/38-resumable-persistence-fsm/38-02-SUMMARY.md`
- **Verification:** `mix test test/rindle/domain/media_upload_session_test.exs`; `mix test test/rindle/domain/lifecycle_fsm_test.exs test/rindle/domain/media_upload_session_test.exs`
- **Committed in:** summary metadata commit

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** No scope change. The implementation matches the planned behavior; only the non-executable verification flag was corrected in execution.

## Issues Encountered

- The worktree contained concurrent planning and Phase 38 edits outside the owned files, including an unrelated resumable migration and test-file modifications. They were left untouched.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The domain layer now accepts persisted resumable session metadata and exposes the durable `resuming` vocabulary that later broker/runtime work can consume.
- Broker/runtime resumable semantics remain deferred as intended; this plan did not introduce any status-probe mutation path.

## Self-Check

PASSED

- Confirmed `.planning/phases/38-resumable-persistence-fsm/38-02-SUMMARY.md` exists.
- Confirmed task commits `f41d732`, `69ee9ee`, `8628f5f`, and `7551b7c` exist in git history.

---
*Phase: 38-resumable-persistence-fsm*
*Completed: 2026-05-07*
