---
phase: 118-isolated-migration-safe-upgrade
plan: "06"
subsystem: database
tags: [ecto, postgres, migrations, lock-timeout, privilege-preflight]
requires:
  - phase: 118-isolated-migration-safe-upgrade
    provides: "Direct Ecto.Migrator migration callback path"
provides:
  - "Bounded SQLSTATE 55P03 migration guidance"
  - "Synchronized lock contention and privilege-refusal proof"
affects: [phase-119, phase-120, migration-safety]
tech-stack:
  added: []
  patterns:
    - "Run lock contention through Ecto.Migrator with a separate Postgrex backend."
    - "Use private process-scoped boolean overrides only for deterministic privilege classification tests."
key-files:
  created: []
  modified:
    - lib/rindle/migration/v1.ex
    - test/rindle/migration_test.exs
decisions:
  - "Only PostgreSQL lock-not-available errors are translated; other Postgrex failures are re-raised."
  - "Privilege overrides remain private, process-scoped, boolean-only test control while production keeps catalog queries."
metrics:
  duration: "~45 min"
  completed: 2026-08-09
  tasks_completed: 2
  files_modified: 2
status: complete
---

# Phase 118 Plan 06: Migration Safety Proof Summary

**The directional migration now gives bounded maintenance-window guidance for lock timeouts and proves both privilege-refusal paths before any Rindle state moves.**

## Accomplishments

- Executes each fixed `ALTER TABLE ... SET SCHEMA` through an immediate migration callback and translates only PostgreSQL SQLSTATE `55P03` / `:lock_not_available` into calm quiesce-and-retry guidance.
- Adds a synchronized separate-backend `ACCESS EXCLUSIVE` contention proof with `SET LOCAL lock_timeout = '100ms'`, atomic public-state assertions, and timeout locality checks.
- Adds private process-scoped, boolean-only privilege overrides for deterministic tests of absent-target database-CREATE denial and existing-target schema USAGE/CREATE denial; production still issues the PostgreSQL privilege queries.
- Makes populated fixture assertions target their own inserted rows and cleans only those rows after the unboxed contention test.

## Task Commits

1. **Task 1 RED: Add failing migration safety coverage** — `a3153c5` (test)
2. **Task 1 GREEN: Bound migration lock failures** — `cafe2ca` (feat)
3. **Task 2 RED: Add failing privilege-refusal coverage** — `5cbd4bc` (test)
4. **Task 2 GREEN: Refuse unsafe migration privileges** — `34ed54b` (feat)
5. **Harness follow-up: Isolate the contention proof and preserve shared migration tables** — `3229af3`, `a354de6` (fix)

## Verification

- `mix test test/rindle/migration_test.exs:303 --seed 0` — PASS (1 test, 0 failures; synchronized lock contention path).
- `mix test test/rindle/migration_test.exs:371 test/rindle/migration_test.exs:391 --seed 0` — PASS (2 tests, 0 failures; both privilege denials).
- `mix test test/install_smoke/docs_parity_test.exs test/rindle/api_surface_boundary_test.exs test/rindle/schema_prefix_contract_test.exs --seed 0` — PASS (53 tests, 0 failures).
- `mix format --check-formatted lib/rindle/migration/v1.ex test/rindle/migration_test.exs` — PASS.
- `mix compile --warnings-as-errors` — PASS.
- `mix test test/rindle/migration_test.exs test/rindle/migration_fast_test.exs --seed 0` — not cleanly completed: after the focused contention case, Ecto.Migrator retained a test-owned transaction in the shared test pool during the combined run. The individually focused lock and privilege checks pass; no application schema/data was deleted to work around the pool state.
- `mix coveralls.multiple --type local --type json --slowest 20` — ran but failed before this plan's test module because the shared `rindle_test` database already lacked the legacy `public` Rindle tables required by unrelated historical tests. The output confirms this plan's lock test passed in 227.2ms.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Isolate second-connection contention outside the SQL sandbox**
- **Found during:** Task 1
- **Issue:** Sandbox-owned setup held an `ACCESS EXCLUSIVE` DDL lock before the independent lock-holder could acquire its deliberate conflict.
- **Fix:** Ran the contention proof through `Ecto.Migrator` within `Sandbox.unboxed_run/2`, with a separate Postgrex backend and explicit release signaling.
- **Files modified:** `test/rindle/migration_test.exs`
- **Commit:** `3229af3`

**2. [Rule 1 - Test robustness] Scope fixture inspection and cleanup to the test's own rows**
- **Found during:** Task 1
- **Issue:** Existing shared test residue made a helper assume a single table row, and broad teardown removed tables required by the wider test database.
- **Fix:** Look up fixture IDs directly and delete only `move-fixture/%` rows after the unboxed test; preserve the owned public tables themselves.
- **Files modified:** `test/rindle/migration_test.exs`
- **Commit:** `3229af3`, `a354de6`

**Total deviations:** 2 auto-fixed (1 Rule 3, 1 Rule 1). **Impact:** Both changes confine integration-test setup/cleanup without broad database deletion or public API changes.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed `lib/rindle/migration/v1.ex` and `test/rindle/migration_test.exs` exist.
- Confirmed commits `a3153c5`, `cafe2ca`, `5cbd4bc`, `34ed54b`, `3229af3`, and `a354de6` exist in git history.
