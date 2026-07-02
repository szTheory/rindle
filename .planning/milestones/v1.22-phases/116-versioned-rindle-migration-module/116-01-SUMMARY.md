---
phase: 116-versioned-rindle-migration-module
plan: 01
subsystem: testing
tags: [ecto, migrations, public-api, package-metadata, red-contract]

requires:
  - phase: 115-versioning-readme-positioning
    provides: "Versioned upgrade-guide structure and README positioning that later Phase 116 docs build on"
provides:
  - "MIGRATE-01 RED contract coverage for versioned Rindle.Migration.up/1 and down/1"
  - "MIGRATE-02 RED contract coverage proving Rindle must not own oban_jobs"
  - "Public API docs boundary lock for Rindle.Migration and hidden helper modules"
  - "Package metadata lock preserving the legacy bundled Oban migration filename"
affects:
  - "Phase 116 implementation plans must make these RED contracts green"
  - "Rindle.Migration public API"
  - "Legacy packaged migration compatibility"

tech-stack:
  added: []
  patterns:
    - "Use focused RED tests to lock migration API behavior before implementation"
    - "Use API surface boundary tests to distinguish public migration API from hidden helper modules"
    - "Use unpacked Hex package metadata tests to preserve legacy migration filenames"

key-files:
  created:
    - test/rindle/migration_test.exs
    - .planning/phases/116-versioned-rindle-migration-module/116-01-SUMMARY.md
  modified:
    - test/rindle/api_surface_boundary_test.exs
    - test/install_smoke/package_metadata_test.exs

key-decisions:
  - "Plan 116-01 intentionally adds RED contract tests only; no Rindle.Migration implementation or legacy migration behavior changed in this plan."
  - "The migration API contract exercises Rindle.Migration through a host-style Ecto migration runner harness without teaching the legacy package-path migrator."
  - "The package compatibility contract preserves the exact 20260424205942_create_oban_tables.exs filename for legacy adopters."

patterns-established:
  - "Migration substrate tests should cover public-prefix defaults, marker recording, idempotency, scoped rollback, and host-owned oban_jobs boundaries."
  - "Public docs-boundary tests should list only Rindle.Migration as public while keeping Rindle.Migration.Options and Rindle.Migration.V1 hidden."

requirements-completed: [MIGRATE-01, MIGRATE-02]

duration: 4 min
completed: 2026-07-01
status: complete
---

# Phase 116 Plan 01: Migration RED Contract Summary

**RED contract tests now lock the versioned Rindle.Migration API, host-owned Oban boundary, and legacy packaged migration filename.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-07-01T19:36:50Z
- **Completed:** 2026-07-01T19:41:02Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added `test/rindle/migration_test.exs` with focused RED coverage for `Rindle.Migration.up(version: 1)`, `down(version: 1)`, default `prefix: "public"`, `rindle_migration_versions`, idempotent table creation, explicit UUID primary keys, option validation, and scoped rollback.
- Locked MIGRATE-02 at the contract layer: Rindle-owned migration tests assert `oban_jobs` is never created by Rindle and survives Rindle rollback when host-owned.
- Extended the public API boundary so `Rindle.Migration` must be documented with visible `up/1` and `down/1`, while `Rindle.Migration.Options` and `Rindle.Migration.V1` remain hidden implementation modules.
- Extended package metadata proof so `priv/repo/migrations/20260424205942_create_oban_tables.exs` remains shipped for legacy compatibility.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add RED migration API contract tests** - `aa56a3c` (test)
2. **Task 2: Lock public API and legacy package compatibility contracts** - `89819bb` (test)

## Files Created/Modified

- `test/rindle/migration_test.exs` - New RED migration API contract for version pinning, marker recording, public prefix default, idempotency, scoped rollback, option validation, explicit table ownership, and host-owned `oban_jobs`.
- `test/rindle/api_surface_boundary_test.exs` - Adds `Rindle.Migration` to the public docs allowlist, asserts `up/1` and `down/1` visibility, and keeps `Rindle.Migration.Options` / `Rindle.Migration.V1` hidden.
- `test/install_smoke/package_metadata_test.exs` - Requires the legacy packaged migration directory and exact Oban migration filename to remain present in the unpacked Hex artifact.

## Decisions Made

- Kept this plan RED-only, matching the Wave 1 scope. Implementation modules, docs changes, doctor/runtime changes, and the legacy Oban migration stub remain for later Phase 116 plans.
- Used a host-style Ecto migration runner harness for migration contract tests so future implementation can be exercised as adopters will call it, without asserting or teaching `Ecto.Migrator.run/4` over package migration paths.
- Preserved legacy filename compatibility in package metadata proof without asserting the future compatibility-stub behavior in this plan.

## Verification

- `mix test test/rindle/migration_test.exs --seed 0` - RED as expected: 5 tests, 5 failures, all caused by missing `Rindle.Migration.up/1` / `down/1` or the resulting missing ArgumentError path.
- `mix test test/rindle/api_surface_boundary_test.exs test/install_smoke/package_metadata_test.exs --seed 0` - RED as expected: 36 tests, 3 failures, all caused by missing `Rindle.Migration` / `Rindle.Migration.Options` docs-boundary modules.
- Source acceptance checks - PASS: required references to `Rindle.Migration.up(version: 1)`, `Rindle.Migration.down(version: 1)`, `rindle_migration_versions`, `prefix: "public"`, `oban_jobs`, hidden helper modules, and `20260424205942_create_oban_tables.exs` are present.
- Forbidden source checks - PASS: no new `Ecto.Migrator.run/4`, `Application.app_dir`, installer task, Igniter, or migration generator assertions were added.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The plan's bash-style verifier wrapper used a variable named `status`, which is read-only in zsh. The same verifier was rerun under `bash -lc` so the intended RED command semantics were preserved.
- A source acceptance check showed the migration test needed the literal `prefix: "public"` text in addition to testing the public default. The assertion message was adjusted and the RED command reran successfully.

## Authentication Gates

None.

## Known Stubs

None. Stub-pattern scan only matched pre-existing release-test literals in `test/install_smoke/package_metadata_test.exs` (`dryrun-placeholder` and an empty-string guard), not plan-created stubs.

## User Setup Required

None - no external service configuration required.

## Threat Flags

None - this plan added tests only. No new runtime network endpoints, auth paths, file access paths, schema-changing implementation, or trust-boundary code were introduced.

## Next Phase Readiness

Plan 02 can implement `Rindle.Migration`, validation helpers, and version-1 DDL against these RED contracts. The failure mode is precise: missing public migration modules and functions, not unrelated package or docs drift.

## Self-Check: PASSED

- FOUND: `test/rindle/migration_test.exs`
- FOUND: `test/rindle/api_surface_boundary_test.exs`
- FOUND: `test/install_smoke/package_metadata_test.exs`
- FOUND: commit `aa56a3c`
- FOUND: commit `89819bb`

---
*Phase: 116-versioned-rindle-migration-module*
*Completed: 2026-07-01*
