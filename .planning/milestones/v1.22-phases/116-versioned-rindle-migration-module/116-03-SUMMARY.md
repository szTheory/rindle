---
phase: 116-versioned-rindle-migration-module
plan: 03
subsystem: testing
tags: [docs-parity, generated-app-smoke, migrations, oban, red-contract]

requires:
  - phase: 116-01
    provides: "Migration API and host-owned Oban boundary RED contracts"
  - phase: 116-02
    provides: "Doctor/runtime setup-readiness RED contracts for Rindle schema and Oban ownership"
  - phase: 115-versioning-readme-positioning
    provides: "Versioned upgrade-guide structure and README onboarding surfaces"
provides:
  - "MIGRATE-01 RED docs parity coverage for pinned Rindle.Migration host migrations"
  - "MIGRATE-02 RED generated-app proof for host-owned Oban.Migration and no Rindle-created oban_jobs"
  - "Fresh-install proof rejection of the old package-directory resolver"
affects:
  - "Phase 116 docs implementation plans must make these RED contracts green"
  - "Generated Phoenix app install smoke"
  - "README/getting-started/upgrading migration copy"

tech-stack:
  added: []
  patterns:
    - "Use docs parity tests to lock migration reader journeys before editing public docs"
    - "Use generated-app report fields to prove host-owned Oban and Rindle migrations separately"
    - "Keep legacy package-path assertions scoped to historical upgrade proof"

key-files:
  created:
    - .planning/phases/116-versioned-rindle-migration-module/116-03-SUMMARY.md
  modified:
    - test/install_smoke/docs_parity_test.exs
    - test/install_smoke/support/generated_app_helper.ex
    - test/install_smoke/generated_app_smoke_test.exs

key-decisions:
  - "Plan 116-03 intentionally adds RED proof only; no README, guide, migration API, doctor, runtime, or legacy migration implementation changed."
  - "Generated-app fresh install proof now expects normal host migrations with separate Oban.Migration and Rindle.Migration files instead of the package-directory resolver."
  - "Legacy package-directory migration history remains intentionally scoped to the upgrade preparer and historical upgrade assertions."

patterns-established:
  - "Docs parity sections should be extracted narrowly so fresh-install docs can reject legacy package-path copy while historical upgrade sections can retain it."
  - "Generated-app migration reports should expose host_oban_migration_ran?, rindle_migration_ran?, and rindle_created_oban_jobs? for MIGRATE-02 proof."

requirements-completed: [MIGRATE-01, MIGRATE-02]

duration: 9 min
completed: 2026-07-01
status: complete
---

# Phase 116 Plan 03: Docs and Generated-App Migration RED Proof Summary

**Docs parity and generated-app smoke tests now fail until public docs teach pinned Rindle.Migration host migrations and fresh installs prove host-owned Oban.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-07-01T19:55:24Z
- **Completed:** 2026-07-01T20:04:22Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Extended docs parity to require `Rindle.Migration.up(version: 1)`, `Rindle.Migration.down(version: 1)`, `Oban.Migration`, `oban_jobs`, default `public`, `mix ecto.migrate`, `mix rindle.doctor`, and rollback backup/destructive copy in README, Getting Started, and the Unreleased upgrade note.
- Added fresh-install refutations so README, Getting Started step 3, and the Unreleased upgrade note reject `Application.app_dir(:rindle, "priv/repo/migrations")` and raw `Ecto.Migrator.run` package-path replay.
- Updated generated-app helper fixtures to write separate host marker, host-owned Oban, and Rindle migration files.
- Updated generated-app report/assertion fields to prove host-owned Oban ran, Rindle migration ran, and Rindle did not create `oban_jobs`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add RED docs parity assertions for migration ownership copy** - `ee6c73d` (test)
2. **Task 2: Add RED generated-app migration proof** - `e27c259` (test)

## Files Created/Modified

- `test/install_smoke/docs_parity_test.exs` - Adds migration-section extraction, pinned `Rindle.Migration` docs assertions, host-owned Oban copy checks, rollback safety checks, and fresh-install legacy package-path refutations.
- `test/install_smoke/support/generated_app_helper.ex` - Writes separate generated host migrations for the install-smoke marker, `Oban.Migration`, and `Rindle.Migration`; changes the fresh migration runner to host migrations and emits new ownership report fields.
- `test/install_smoke/generated_app_smoke_test.exs` - Adds shared host-owned migration assertions and a RED guard requiring the public `Rindle.Migration` API before the tagged generated-app smoke lanes can pass.
- `.planning/phases/116-versioned-rindle-migration-module/116-03-SUMMARY.md` - Records this plan execution.

## Decisions Made

- Kept this plan RED-only. Public docs and runtime implementation remain for later Phase 116 plans.
- Preserved legacy package-path upgrade proof by storing `legacy_rindle_migration_path` from the upgrade preparer while rejecting the same resolver for fresh installs.
- Added an untagged generated-app migration contract guard because the exact plan verifier excludes minio-tagged smoke modules by default.

## Verification

- `mix test test/install_smoke/docs_parity_test.exs --seed 0` - RED as expected: 30 tests, 2 failures. Failures are the missing pinned `Rindle.Migration` docs and the still-present raw package-directory greenfield copy.
- `mix test test/install_smoke/generated_app_smoke_test.exs --seed 0` - RED as expected: 1 test, 1 failure, 13 excluded. Failure is the missing public `Rindle.Migration` API.
- `mix format --check-formatted test/install_smoke/docs_parity_test.exs test/install_smoke/support/generated_app_helper.ex test/install_smoke/generated_app_smoke_test.exs` - PASS.
- Source acceptance checks - PASS: helper writes separate `Oban.Migration` and `Rindle.Migration` host migrations; reports include `host_oban_migration_ran?`, `rindle_migration_ran?`, and `rindle_created_oban_jobs?`; fresh assertions expect `:host_migrations`; legacy package-path proof remains scoped to upgrade.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added untagged generated-app RED guard**
- **Found during:** Task 2 (Add RED generated-app migration proof)
- **Issue:** The exact plan verifier `mix test test/install_smoke/generated_app_smoke_test.exs --seed 0` excluded all generated-app smoke modules because they are `:minio` tagged, returning 0 tests and no RED proof.
- **Fix:** Added `Rindle.InstallSmoke.GeneratedAppMigrationContractTest`, an untagged guard in the same smoke file that fails until `Rindle.Migration.up/1` and `down/1` exist. The full generated-app lanes remain tagged and runnable through `scripts/install_smoke.sh`.
- **Files modified:** `test/install_smoke/generated_app_smoke_test.exs`
- **Verification:** The exact plan verifier now fails with a `Rindle.Migration` contract message.
- **Committed in:** `e27c259`

---

**Total deviations:** 1 auto-fixed (Rule 3).
**Impact on plan:** Test-only adjustment needed to make the named verifier meaningful. No production scope added.

## Issues Encountered

- An initial parallel verification run opened two Mix test processes at once and caused transient Postgres `too_many_connections` noise. Both plan verification commands were rerun sequentially and produced clean, intended RED failures.

## Authentication Gates

None.

## Known Stubs

None. Stub-pattern scan only matched pre-existing generated helper defaults and empty collection literals in embedded JS/test support, not new UI data or incomplete plan-created behavior.

## User Setup Required

None - no external service configuration required.

## Threat Flags

None - this plan added tests and generated-app test fixtures only. No new runtime network endpoints, auth paths, file access paths, schema-changing implementation, or trust-boundary production code were introduced.

## Next Phase Readiness

Plan 04 can make these RED contracts green by updating README, Getting Started, and upgrading docs to the pinned host-migration path and by implementing the `Rindle.Migration` substrate that generated-app proof now expects.

## Self-Check: PASSED

- FOUND: `test/install_smoke/docs_parity_test.exs`
- FOUND: `test/install_smoke/support/generated_app_helper.ex`
- FOUND: `test/install_smoke/generated_app_smoke_test.exs`
- FOUND: commit `ee6c73d`
- FOUND: commit `e27c259`

---
*Phase: 116-versioned-rindle-migration-module*
*Completed: 2026-07-01*
