---
phase: 119-ownership-boundaries-diagnostics
plan: 03
subsystem: runtime-diagnostics
tags: [elixir, ecto, postgres, oban, runtime-status, diagnostics]
requires:
  - phase: 119-ownership-boundaries-diagnostics
    provides: OwnershipSnapshot classification and validated host Oban binding
provides:
  - Snapshot-first refusal boundary for all runtime-status report queries
  - Independently routed Rindle and host Oban report prefixes
  - Bounded text and JSON runtime-status errors with non-zero CLI exits
affects: [119-04, runtime-status, operations, admin-diagnostics]
tech-stack:
  added: []
  patterns: [snapshot-first report preflight, bounded refusal rendering, report-query tripwire]
key-files:
  created: []
  modified:
    - lib/rindle/ops/runtime_status.ex
    - lib/mix/tasks/rindle.runtime_status.ex
    - test/rindle/ops/runtime_status_test.exs
    - test/rindle/runtime_status_task_test.exs
key-decisions:
  - "Runtime status accepts only a complete shared ownership snapshot before any report helper runs; legacy readiness fixtures are adapted only as a test seam."
  - "Runtime task errors use explicit bounded clauses and a constant unknown fallback instead of rendering arbitrary reason terms."
patterns-established:
  - "Route Rindle reads through Rindle.Schema and Oban reads through the validated snapshot prefix."
requirements-completed: [BOUNDARY-02, OPS-01]
coverage:
  - id: D1
    description: Snapshot refusal prevents every runtime report query and preserves legacy setup-incomplete tuples.
    requirement: BOUNDARY-02
    verification:
      - kind: unit
        ref: mix test test/rindle/ops/runtime_status_test.exs:48 test/rindle/ops/runtime_status_test.exs:79 --seed 0
        status: pass
    human_judgment: false
  - id: D2
    description: CLI failures have bounded text/JSON representations and a non-zero exit path without raw adapter leakage.
    requirement: OPS-01
    verification:
      - kind: unit
        ref: mix test test/rindle/runtime_status_task_test.exs:64 test/rindle/runtime_status_task_test.exs:88 test/rindle/runtime_status_task_test.exs:120 test/rindle/runtime_status_task_test.exs:135 --seed 0
        status: pass
    human_judgment: false
duration: 22min
completed: 2026-08-09
status: complete
---

# Phase 119 Plan 03: Runtime Status Ownership Boundary Summary

**Runtime status now refuses unsafe ownership snapshots before report queries and returns deterministic, redacted text or JSON guidance.**

## Performance

- **Tasks:** 2/2
- **Files modified:** 4
- **Focused verification:** 6 tests passed; compile and formatting passed.

## Accomplishments

- Added a shared `OwnershipSnapshot.inspect/0` preflight before every runtime-status report helper, retaining both established setup-incomplete tuples.
- Routed Rindle reads through `Rindle.Schema.prefix/0` and Oban report reads through the snapshot's validated host prefix.
- Added explicit bounded text/JSON refusal rendering, safe unknown fallback, and JSON-mode non-zero task exits.

## Task Commits

1. **Task 1: Gate every runtime report query with the shared snapshot** — `998df6a` (test), `201f2ec` (feat)
2. **Task 2: Render bounded runtime failures in text, JSON, and process exit** — `5fc7f3e` (test), `ea5268b` (feat), `d26a741` (test)
3. **Follow-up correction:** `148b7ad` (fix) preserves bounded `invalid_format` guidance.

## Files Created/Modified

- `lib/rindle/ops/runtime_status.ex` — snapshot-first preflight, bounded refusal mapping, and snapshot-resolved Oban routing.
- `lib/mix/tasks/rindle.runtime_status.ex` — deterministic text/JSON errors and safe fallback rendering.
- `test/rindle/ops/runtime_status_test.exs` — refusal tripwire and report-prefix seam coverage.
- `test/rindle/runtime_status_task_test.exs` — text/JSON redaction and non-zero JSON exit coverage.

## Decisions Made

- Kept the older `setup_readiness` injection as a test-only compatibility adapter; public callers cannot pass partial readiness maps to bypass the snapshot boundary.
- Used constant unknown-error copy so SQL, Postgrex, credential, or adapter terms cannot cross the CLI boundary.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Preserved safe `invalid_format` task guidance**
- **Found during:** Task 2 verification
- **Issue:** Replacing the unsafe generic formatter also removed the established `invalid_format` classification from CLI output.
- **Fix:** Added an explicit bounded `:invalid_format` text and JSON clause.
- **Files modified:** `lib/mix/tasks/rindle.runtime_status.ex`
- **Verification:** `mix test test/rindle/runtime_status_task_test.exs:64 --seed 0`
- **Committed in:** `148b7ad`

**Total deviations:** 1 auto-fixed (Rule 1).

## Issues Encountered

The required plan-level test command ran 87 tests with 25 failures because the protected Phase 118 worktree changes leave the active database without `public.media_assets` and related selected-schema tables. The failures occur in pre-existing integration fixtures before Plan 119-03 assertions execute. The protected files were not modified. Focused Plan 119-03 tests pass, as do `mix compile --warnings-as-errors` and formatting.

## Known Stubs

None.

## Next Phase Readiness

Plan 119-04 can consume the bounded runtime-status API and task formatter. Restore the Phase 118 test database fixture before relying on the full combined runtime/doctor suite.

## Self-Check: PASSED

- All four Plan 119-03 source/test files exist.
- All six task commits are present in git history.
- Focused tests, compilation, and formatting passed.
