---
phase: 116-versioned-rindle-migration-module
plan: 02
subsystem: testing
tags: [doctor, runtime-status, migrations, oban, red-contract]

requires:
  - phase: 116-01
    provides: "Migration API and host-owned Oban boundary RED contracts"
provides:
  - "MIGRATE-01 RED doctor coverage for fresh Rindle.Migration marker/catalog installs and healthy legacy installs"
  - "MIGRATE-02 RED doctor/runtime coverage for host-owned Oban readiness and missing oban_jobs setup copy"
  - "Runtime status setup-preflight RED coverage for structured setup_incomplete errors"
affects:
  - "Phase 116 doctor/runtime implementation plans must make these RED contracts green"
  - "Rindle.Ops.RuntimeChecks"
  - "Rindle.Ops.RuntimeStatus"
  - "mix rindle.doctor and mix rindle.runtime_status operator copy"

tech-stack:
  added: []
  patterns:
    - "Use focused RED tests to lock doctor and runtime-status compatibility before implementation"
    - "Use injectable readiness fixtures to describe future marker/catalog/legacy/Oban health seams"
    - "Keep host-owned Oban copy explicit in CLI-facing assertions"

key-files:
  created:
    - .planning/phases/116-versioned-rindle-migration-module/116-02-SUMMARY.md
  modified:
    - test/rindle/ops/runtime_checks_test.exs
    - test/rindle/doctor_test.exs
    - test/rindle/ops/runtime_status_test.exs
    - test/rindle/runtime_status_task_test.exs

key-decisions:
  - "Plan 116-02 intentionally adds RED contract tests only; no doctor/runtime production behavior changed in this plan."
  - "Runtime-check tests use injected marker/catalog/legacy/Oban readiness fixtures so later implementation can replace file-history-only health with a hybrid model."
  - "Runtime-status tests use a test-only setup-readiness fixture under Rindle.Ops.RuntimeStatus config to lock structured setup preflight without widening the public filter DSL in this RED plan."

patterns-established:
  - "Doctor hybrid-health tests should assert stable IDs doctor.rindle_schema.ready and doctor.oban_jobs.ready alongside preserved migration history IDs."
  - "Runtime status setup-preflight tests should assert {:setup_incomplete, :rindle_schema} and {:setup_incomplete, :oban_jobs} before normal report queries."

requirements-completed: [MIGRATE-01, MIGRATE-02]

duration: 6 min
completed: 2026-07-01
status: complete
---

# Phase 116 Plan 02: Doctor and Runtime RED Contract Summary

**RED contract tests now lock hybrid doctor migration health and runtime setup-preflight failures for Rindle-owned schema and host-owned Oban readiness.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-07-01T19:44:11Z
- **Completed:** 2026-07-01T19:50:45Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Extended doctor/runtime-check tests with RED coverage for fresh `Rindle.Migration` marker/catalog installs, healthy legacy packaged installs, incomplete Rindle-owned schema, warning-only healthy legacy drift, and missing host-owned `oban_jobs`.
- Locked new doctor IDs `doctor.rindle_schema.ready` and `doctor.oban_jobs.ready` while preserving existing migration-history IDs where the plan requires them.
- Extended doctor CLI tests so warning-only legacy drift does not fail and missing `oban_jobs` points operators to host-owned `Oban.Migration` setup.
- Extended runtime-status service and Mix task tests so missing Rindle schema and missing host-owned Oban setup return bounded `setup_incomplete` errors instead of raw missing-table behavior.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add RED hybrid doctor migration-health tests** - `a9e23b7` (test)
2. **Task 2: Add RED runtime status setup-preflight tests** - `6614ee3` (test)

## Files Created/Modified

- `test/rindle/ops/runtime_checks_test.exs` - Adds RED hybrid doctor health fixtures and assertions for fresh marker/catalog success, healthy legacy success, incomplete Rindle schema, warning-only unresolved legacy history, and missing `oban_jobs`.
- `test/rindle/doctor_test.exs` - Adds CLI-facing RED assertions for warning-only legacy drift and host-owned `Oban.Migration` setup copy when `oban_jobs` is absent.
- `test/rindle/ops/runtime_status_test.exs` - Adds setup-preflight RED assertions for `{:setup_incomplete, :rindle_schema}` and `{:setup_incomplete, :oban_jobs}`, plus healthy report-shape preservation.
- `test/rindle/runtime_status_task_test.exs` - Adds CLI RED assertion that missing host-owned Oban setup exits non-zero and names `mix rindle.doctor`, `Oban.Migration`, and Rindle's non-ownership of `oban_jobs`.

## Decisions Made

- Kept this plan RED-only, matching Wave 1 scope. Production changes to `RuntimeChecks`, `RuntimeStatus`, and Mix tasks remain for later Phase 116 plans.
- Used fixture names that describe the implementation seam directly: `rindle_schema_catalog`, `oban_jobs_catalog`, and `setup_readiness`.
- Changed `test/rindle/runtime_status_task_test.exs` to `async: false` because the new RED case uses global Mix shell and application-env fixtures.

## Verification

- `mix test test/rindle/ops/runtime_checks_test.exs test/rindle/doctor_test.exs --seed 0` - RED as expected: 45 tests, 8 failures, all caused by missing hybrid doctor IDs/semantics or missing host-owned Oban readiness behavior.
- `mix test test/rindle/ops/runtime_status_test.exs test/rindle/runtime_status_task_test.exs --seed 0` - RED as expected: 31 tests, 3 failures, all caused by missing setup-preflight handling.
- Source acceptance checks - PASS: tests contain separate fresh marker/catalog and healthy legacy cases, warning-only legacy drift assertions, host-owned `Oban.Migration` copy, both `setup_incomplete` reasons, non-zero CLI exit assertions, and preserved healthy report-shape assertions.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The plan's bash-style verifier wrapper used a variable named `status`, which is read-only in zsh. The same verifier was rerun under `bash -lc` so the intended RED command semantics were preserved.

## Authentication Gates

None.

## Known Stubs

None. Stub-pattern scan found no placeholder/TODO/FIXME or hardcoded empty UI data in the files modified by this plan.

## User Setup Required

None - no external service configuration required.

## Threat Flags

None - this plan added tests only. No new runtime network endpoints, auth paths, file access paths, schema-changing implementation, or trust-boundary production code were introduced.

## Next Phase Readiness

Plan 03 can implement the hybrid doctor/runtime health model against these RED contracts. The failure modes are precise: missing `doctor.rindle_schema.ready`, missing `doctor.oban_jobs.ready`, unresolved legacy drift still hard-failing, and runtime status ignoring setup-readiness preflight.

## Self-Check: PASSED

- FOUND: `test/rindle/ops/runtime_checks_test.exs`
- FOUND: `test/rindle/doctor_test.exs`
- FOUND: `test/rindle/ops/runtime_status_test.exs`
- FOUND: `test/rindle/runtime_status_task_test.exs`
- FOUND: commit `a9e23b7`
- FOUND: commit `6614ee3`

---
*Phase: 116-versioned-rindle-migration-module*
*Completed: 2026-07-01*
