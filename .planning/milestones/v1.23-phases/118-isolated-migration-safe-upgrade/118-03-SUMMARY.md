---
phase: 118-isolated-migration-safe-upgrade
plan: "03"
subsystem: database
tags: [elixir, ecto, postgresql, migrations, schema-isolation]
requires:
  - phase: 118-02
    provides: "Pinned transactional public-to-rindle move"
provides:
  - "Process-scoped deterministic failure seam proving host transaction rollback"
  - "Pinned guarded rindle-to-public reverse API"
affects: [118-04-upgrade-documentation, migration-safety]
tech-stack:
  added: []
  patterns:
    - "Capture test-only injected failure points before queuing Ecto migration commands"
    - "Reuse one fixed V1 catalog state model for forward and reverse moves"
key-files:
  created: []
  modified:
    - lib/rindle/migration.ex
    - lib/rindle/migration/v1.ex
    - test/rindle/migration_fast_test.exs
    - test/rindle/migration_test.exs
    - test/rindle/api_surface_boundary_test.exs
key-decisions:
  - "Approved D-118-08: publish move_rindle_to_public(version: 1) only as a quiesced, exactly reversible host migration down path."
  - "The guarded reverse does not drop rindle and never delegates to destructive Rindle.Migration.down/1."
metrics:
  duration: "~15 min"
  tasks_completed: 2
  files_modified: 5
completed: 2026-08-09
status: complete
---

# Phase 118 Plan 03: Refusal and Reverse Safety Summary

**Rindle now exposes a version-pinned, preflight-guarded reverse migration that restores exactly its seven relations to `public` without dropping the `rindle` schema or conflating recovery with destructive teardown.**

## Accomplishments

- Added a process-scoped test failure seam captured before Ecto command execution, proving host transactions roll back both newly provisioned schemas and partially relocated populated relations.
- Added `Rindle.Migration.move_rindle_to_public(version: 1)` with version-only options, reverse catalog checks, ownership/marker/privilege validation, and idempotent already-reversed handling.
- Preserved the exact V1 owned-relation allowlist, host relation exclusion, populated rows, indexes, marker, and foreign-key enforcement in the forward/reverse round trip.
- Kept `Rindle.Migration.down/1` as its existing destructive table-drop API; the reverse path does not invoke it and leaves the empty `rindle` schema in place.

## Task Commits

1. **Task 1 RED: Prove failure rollback** — `597860d` (test)
2. **Task 1 GREEN: Roll back failed schema moves** — `6b30ef3` (feat)
3. **Task 2 RED: Define guarded reverse API boundary** — `a2d4feb` (test)
4. **Task 2 GREEN: Add guarded reverse migration** — `956df10` (feat)

## Decisions Made

- The maintainer approved `proceed-guarded-reverse`: the public reverse is available solely to a quiesced host migration down path while persisted state is exactly reversible.
- Reverse state uses the existing V1 fixed catalog model; it accepts neither generic source/target/prefix options nor a generic move export.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test isolation] Make rollback fixture assertions identity-based**
- **Found during:** Task 1 GREEN
- **Issue:** A rollback loop can retain prior fixture rows in the sandbox transaction, so singleton fixture queries did not isolate the current iteration.
- **Fix:** Assert each generated row by UUID instead of assuming one row per relation.
- **Files modified:** `test/rindle/migration_test.exs`
- **Verification:** `mix test test/rindle/migration_test.exs --seed 0`
- **Commit:** `6b30ef3`

**Total deviations:** 1 auto-fixed (Rule 1). **Impact:** Rollback proof now remains deterministic across both injected failure points.

## Verification

- `mix format --check-formatted lib/rindle/migration.ex lib/rindle/migration/v1.ex test/rindle/migration_fast_test.exs test/rindle/migration_test.exs test/rindle/api_surface_boundary_test.exs` — PASS
- `mix test test/rindle/migration_fast_test.exs --seed 0` — PASS (4 tests)
- `mix test test/rindle/migration_test.exs --seed 0` — PASS (11 tests)
- `mix test test/rindle/api_surface_boundary_test.exs --seed 0` — PASS (19 tests)

## Known Stubs

None.

## Self-Check: PASSED

- Verified all five modified migration and test artifacts exist.
- Verified task commits `597860d`, `6b30ef3`, `a2d4feb`, and `956df10` exist in git history.
- No stubs, skipped tests, or unrun planned automated verification remain.
