---
phase: 116-versioned-rindle-migration-module
plan: 04
subsystem: database
tags: [ecto, migrations, nimble-options, oban-boundary, package-compatibility]

requires:
  - phase: 116-01
    provides: "RED contracts for Rindle.Migration API, helper visibility, marker behavior, idempotency, and Oban non-ownership"
provides:
  - "Public Rindle.Migration.up/1 and down/1 wrapper with validated version/prefix options"
  - "Hidden Rindle.Migration.Options validator and Rindle.Migration.V1 DDL helper"
  - "Prefix-aware Rindle-owned schema creation, rollback, and rindle_migration_versions marker state"
  - "No-op compatibility stub for the legacy bundled Oban migration filename"
affects:
  - "Phase 116 doctor/runtime implementation plans can consume V1 marker and catalog helper metadata"
  - "Phase 116 docs/generated-app implementation plans can call Rindle.Migration from host migrations"
  - "Legacy packaged migration compatibility"

tech-stack:
  added: []
  patterns:
    - "Oban-style public migration wrapper dispatching to hidden versioned DDL modules"
    - "NimbleOptions validation wrapped as ArgumentError for migration keyword options"
    - "Prefix-aware Ecto.Migration helpers for library-owned schema objects"

key-files:
  created:
    - lib/rindle/migration.ex
    - lib/rindle/migration/options.ex
    - lib/rindle/migration/v1.ex
  modified:
    - priv/repo/migrations/20260424205942_create_oban_tables.exs

key-decisions:
  - "Rindle.Migration accepts only :version and :prefix; omitted :version defaults to 1 while docs/generator plans remain pinned to version: 1."
  - "Rindle.Migration.V1 owns only Rindle tables and marker state; host-owned Oban setup remains outside the DDL helper."
  - "The legacy CreateObanTables module and filename remain packaged as a no-op compatibility stub."

patterns-established:
  - "Each future migration version should live behind Rindle.Migration with hidden version modules and validated keyword options."
  - "Rindle-owned DDL must pass the selected prefix through tables, indexes, references, and marker writes."
  - "Legacy packaged migration filenames remain compatibility artifacts, not fresh-install authority."

requirements-completed: [MIGRATE-01, MIGRATE-02]

duration: 8 min
completed: 2026-07-01
status: complete
---

# Phase 116 Plan 04: Versioned Rindle Migration Substrate Summary

**Versioned Rindle.Migration now creates, marks, and rolls back Rindle-owned schema while leaving host-owned Oban state untouched.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-07-01T20:09:00Z
- **Completed:** 2026-07-01T20:17:01Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments

- Added `Rindle.Migration.up/1` and `down/1` as the documented public migration wrapper.
- Added `Rindle.Migration.Options.validate!/1` with NimbleOptions validation for `version: 1` and `prefix: "public"`.
- Added `Rindle.Migration.V1` with prefix-aware Ecto DDL for all current Rindle-owned tables, indexes, references, and `rindle_migration_versions`.
- Made `Rindle.Migration.down/1` drop only Rindle-owned tables and marker state in dependency-safe order.
- Converted `priv/repo/migrations/20260424205942_create_oban_tables.exs` into a no-op compatibility stub while preserving the filename and module.

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement public API and option validation** - `8b34789` (feat)
2. **Task 2: Implement versioned Rindle-owned DDL and marker behavior** - `c66ddc6` (feat)
3. **Task 3: Neutralize the bundled Oban migration while preserving filename compatibility** - `5d49a66` (fix)

## Files Created/Modified

- `lib/rindle/migration.ex` - Public Oban-style migration API with adopter-owned host migration guidance.
- `lib/rindle/migration/options.ex` - Hidden option validator for supported migration version and schema prefix.
- `lib/rindle/migration/v1.ex` - Hidden version-one DDL helper for Rindle-owned schema and marker state.
- `priv/repo/migrations/20260424205942_create_oban_tables.exs` - Legacy compatibility stub that no longer manages shared job storage.

## Decisions Made

- Allowed omitted `:version` to default to `1` for developer ergonomics, while preserving the plan's pinned generated/docs direction.
- Kept marker state minimal: `rindle_migration_versions(version)` records version `1` under the selected prefix.
- Kept the legacy Oban migration filename and module intact, but made both `up/0` and `down/0` no-ops.

## Verification

- `mix test test/rindle/migration_test.exs --seed 0` - PASS, 5 tests.
- `mix test test/rindle/api_surface_boundary_test.exs test/install_smoke/package_metadata_test.exs --seed 0` - PASS, 36 tests.
- `mix test test/install_smoke/package_metadata_test.exs test/rindle/migration_test.exs --seed 0` - PASS, 22 tests.
- `mix format --check-formatted lib/rindle/migration.ex lib/rindle/migration/options.ex lib/rindle/migration/v1.ex priv/repo/migrations/20260424205942_create_oban_tables.exs test/rindle/migration_test.exs` - PASS.
- Source checks - PASS: `Rindle.Migration.V1` and the legacy compatibility stub contain no `Oban.Migration` or `oban_jobs` text; implementation files add no package-directory runner, public install task, Igniter installer, or generator.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The existing `test/rindle/migration_test.exs` spans both Task 1 wrapper behavior and Task 2 V1 DDL behavior. After Task 1, the remaining failures were the expected missing V1 implementation; the full combined verifier passed after Task 2.
- An intentionally broad source scan matched `Oban.Migration` / `oban_jobs` in the public `Rindle.Migration` documentation, where the host-owned boundary is supposed to be explained. The final source assertion was scoped to executable DDL/stub files.

## Authentication Gates

None.

## Known Stubs

None. Stub-pattern scan found no placeholder/TODO/FIXME or hardcoded empty UI data in files created or modified by this plan. The legacy Oban migration is an intentional compatibility no-op, not incomplete functionality.

## User Setup Required

None - no external service configuration required.

## Threat Flags

None beyond the planned threat model. This plan introduced the expected migration DDL trust boundary and mitigated it with option validation, prefix-aware DDL, scoped rollback, and the no-op legacy Oban migration.

## Next Phase Readiness

Plan 05 can update README, Getting Started, upgrading docs, and generated-app proof against the new public `Rindle.Migration` API. Plan 06 can wire doctor/runtime readiness to the marker/catalog helpers.

## Self-Check: PASSED

- FOUND: `lib/rindle/migration.ex`
- FOUND: `lib/rindle/migration/options.ex`
- FOUND: `lib/rindle/migration/v1.ex`
- FOUND: `priv/repo/migrations/20260424205942_create_oban_tables.exs`
- FOUND: commit `8b34789`
- FOUND: commit `c66ddc6`
- FOUND: commit `5d49a66`

---
*Phase: 116-versioned-rindle-migration-module*
*Completed: 2026-07-01*
