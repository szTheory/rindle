---
phase: 118-isolated-migration-safe-upgrade
plan: "01"
subsystem: database
tags: [elixir, ecto, postgresql, migrations, schema-isolation]
requires:
  - phase: 117-prefix-routing-architecture
    provides: "Compile-time rindle/public prefix authority"
provides:
  - "Fresh rindle-schema provisioning through Rindle.Migration.up/1"
  - "Bounded rindle/public migration-prefix contract"
  - "Live and DB-free regression coverage for isolated fresh installs"
affects: [118-02-safe-public-to-rindle-move, migration-documentation, generated-app-proof]
tech-stack:
  added: []
  patterns:
    - "Provision validated schema identifiers through V1's sole quoting boundary before qualified DDL"
    - "Use a DB-free migration contract smoke alongside a transaction-rolled-back default-build probe"
key-files:
  created:
    - test/rindle/migration_fast_test.exs
    - test/rindle/migration_default_build_probe.exs
  modified:
    - lib/rindle/migration.ex
    - lib/rindle/migration/options.ex
    - lib/rindle/migration/v1.ex
    - test/rindle/migration_test.exs
key-decisions:
  - "Approved D-118-01: rindle is the fresh migration default; public is the sole compatibility prefix."
  - "V1 remains the sole authority for owned relation names, selected-schema DDL, and identifier quoting."
patterns-established:
  - "Schema provisioning precedes all Rindle-owned table and marker DDL."
requirements-completed: [MIGRATE-01]
coverage:
  - id: D1
    description: "Fresh Rindle migration provisions the rindle schema and exactly its seven owned relations."
    requirement: MIGRATE-01
    verification:
      - kind: integration
        ref: "mix test test/rindle/migration_test.exs --seed 0"
        status: pass
      - kind: other
        ref: "MIX_ENV=dev mix run test/rindle/migration_default_build_probe.exs"
        status: pass
    human_judgment: false
  - id: D2
    description: "Migration options allow only rindle/public and preserve host-owned relation boundaries."
    requirement: MIGRATE-01
    verification:
      - kind: unit
        ref: "mix test test/rindle/migration_fast_test.exs --seed 0"
        status: pass
    human_judgment: false
duration: 18min
completed: 2026-08-09
status: complete
---

# Phase 118 Plan 01: Fresh Isolated Provisioning Summary

**Fresh `Rindle.Migration.up(version: 1)` installs the exact Rindle relation set into a provisioned `rindle` schema, with `public` retained as the only explicit compatibility pairing.**

## Performance

- **Duration:** 18 min
- **Started:** 2026-08-09T15:44:24Z
- **Completed:** 2026-08-09T16:02:24Z
- **Tasks:** 2/2
- **Files modified:** 6

## Accomplishments

- Locked and implemented D-118-01: migration defaults now agree with `Rindle.Schema.prefix/0` on `rindle`.
- Restricted migration option validation to `rindle | public`, before any migration DDL can be emitted.
- Provisioned the selected schema before V1's idempotent table and marker DDL, while preserving the fixed seven-relation ownership boundary.
- Added a DB-free fast contract test, PostgreSQL integration coverage, and a default-build probe that rolls all provisioned state back.

## Task Commits

1. **Task 1 RED: Provision one fresh default install end to end** — `3659331` (test)
2. **Task 1 GREEN: Provision one fresh default install end to end** — `c0f9f94` (feat)

## Files Created/Modified

- `lib/rindle/migration/options.ex` — defaults to `rindle` and validates the two-prefix public contract.
- `lib/rindle/migration/v1.ex` — derives owned relations and provisions the validated schema before DDL.
- `lib/rindle/migration.ex` — documents the new default and explicit public compatibility pairing.
- `test/rindle/migration_test.exs` — proves default/compatibility provisioning, idempotency, and host relation non-ownership against PostgreSQL.
- `test/rindle/migration_fast_test.exs` — fast, async, DB-free migration-contract smoke.
- `test/rindle/migration_default_build_probe.exs` — default-build fresh-install proof contained by transaction rollback.

## Decisions Made

- The maintainer approved `proceed-locked-contract`: publish `rindle` as the default fresh-install schema and support only `rindle | public` migration pairings.
- `Rindle.Migration.V1` continues to own the sole fixed relation list and identifier quoting boundary; no generic prefix or host-infrastructure migration API was added.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Correctness] Updated public migration API documentation for the flipped default**
- **Found during:** Task 1
- **Issue:** `Rindle.Migration` module and option docs still stated that `public` was the default.
- **Fix:** Documented `rindle` as the default and `public` as the explicit compatibility pairing.
- **Files modified:** `lib/rindle/migration.ex`
- **Verification:** Focused formatting and all migration verification commands passed.
- **Committed in:** `c0f9f94`

**Total deviations:** 1 auto-fixed (Rule 2)

## Issues Encountered

- The default-build probe initially assumed `Rindle.Repo` starts with the application; this library intentionally does not supervise its Repo. The probe now starts the configured Repo explicitly before its rollback-contained check.
- The existing public `oban_jobs` relation has required columns, so the host-boundary test snapshots it instead of inserting an invalid synthetic row.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 02 can build the guarded public-to-`rindle` move on the authoritative seven-relation list and selected-schema provisioning boundary. No blockers remain.

## Verification

- `mix format --check-formatted lib/rindle/migration.ex lib/rindle/migration/options.ex lib/rindle/migration/v1.ex test/rindle/migration_fast_test.exs test/rindle/migration_test.exs test/rindle/migration_default_build_probe.exs` — PASS
- `mix test test/rindle/migration_fast_test.exs --seed 0` — PASS (3 tests)
- `mix test test/rindle/migration_test.exs --seed 0` — PASS (5 tests)
- `MIX_ENV=dev mix run test/rindle/migration_default_build_probe.exs` — PASS
- `mix test test/rindle/schema_prefix_contract_test.exs --seed 0` — PASS (3 tests)

## Self-Check: PASSED

- Verified all six implementation/test artifacts exist.
- Verified RED commit `3659331` and GREEN commit `c0f9f94` exist in git history.

---
*Phase: 118-isolated-migration-safe-upgrade*
*Completed: 2026-08-09*
