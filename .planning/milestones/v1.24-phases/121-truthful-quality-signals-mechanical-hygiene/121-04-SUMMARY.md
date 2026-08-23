---
phase: 121-truthful-quality-signals-mechanical-hygiene
plan: 04
subsystem: quality-signals
tags: [credo, migration, subprocess, tus, safety]
requires:
  - 121-01
provides:
  - Warning-free baseline for the four actionable Credo warning findings
affects:
  - lib/rindle/migration/v1.ex
  - test/rindle/av/subprocess_epipe_test.exs
  - test/rindle/upload/tus_s3_integration_test.exs
tech_stack:
  added: []
  patterns:
    - Stacktrace-preserving re-raise
    - Executable-path port fixture with explicit argv
    - Direct non-empty list pattern assertions
key_files:
  created: []
  modified:
    - lib/rindle/migration/v1.ex
    - test/rindle/av/subprocess_epipe_test.exs
    - test/rindle/upload/tus_s3_integration_test.exs
decisions:
  - Preserve the migration's public ArgumentError message while re-raising it with the rescued Postgrex stacktrace.
  - Retain the deterministic EPIPE port fixture while removing shell spawning through spawn_executable and an empty argv list.
metrics:
  duration: 6m
  completed_date: 2026-08-22
  tasks_completed: 2
  files_modified: 3
status: complete
---

# Phase 121 Plan 04: Credo Warning Baseline Summary

Cleared the four actionable Credo warning findings without changing migration error envelopes, subprocess behavior, or tus S3 integration semantics.

## Tasks Completed

1. **Remove security and stacktrace warnings without contract drift** — `8624292`
   - Replaced the EPIPE test fixture's shell spawn with an executable path and explicit empty argv.
   - Re-raised the mapped migration ArgumentError with the rescued stacktrace intact.

2. **Replace expensive empty-list checks in tus proof** — `1706747`
   - Replaced both `length(parts) >= 1` checks with direct non-empty list patterns.

## Verification

- `mix test test/rindle/av/subprocess_epipe_test.exs test/rindle/migration_fast_test.exs --seed 0` — passed (11 tests, 0 failures, 1 canary excluded).
- `mix credo --strict test/rindle/av/subprocess_epipe_test.exs lib/rindle/migration/v1.ex` — targeted `UnsafeExec` and `RaiseInsideRescue` warnings removed; only pre-existing migration complexity findings remain.
- `mix credo --strict test/rindle/upload/tus_s3_integration_test.exs` — passed with no issues.
- `mix test test/rindle/upload/tus_s3_integration_test.exs --seed 0` — compiled; its three MinIO-tagged integration tests were intentionally excluded in the unprepared local environment.
- `bash scripts/maintainer/refactor_contract.sh` — passed (86 tests, 0 failures).
- Full strict Credo output contains no `[W]` warning lines; remaining repository-wide findings are pre-existing refactor/design/complexity categories.

## Decisions Made

- Do not alter migration DDL, transaction boundaries, reversal behavior, exception type, or exception message.
- Do not change tus requests, storage calls, retry behavior, ordering, or error assertions.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- All three planned source/test files exist.
- Both task commits (`8624292`, `1706747`) exist in git history.
