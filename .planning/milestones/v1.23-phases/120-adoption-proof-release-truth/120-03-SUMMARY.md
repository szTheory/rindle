---
phase: 120
plan: 03
subsystem: adoption-demo
tags: [cohort, migrations, postgres, oban, proof]
requires:
  - 120-01
provides:
  - Cohort-owned Rindle and Oban migrations
  - schema-qualified cold-start ownership proof
affects: [adoption-demo, CI, Docker-compose]
tech-stack:
  added: []
  patterns: [host-owned Ecto migrations, schema-qualified catalog assertions]
key-files:
  created:
    - examples/adoption_demo/priv/repo/migrations/20260809000000_install_rindle.exs
    - examples/adoption_demo/test/rindle_migration_contract_test.exs
  modified:
    - examples/adoption_demo/priv/repo/migrations/20260528120100_add_oban.exs
    - examples/adoption_demo/mix.exs
    - scripts/ci/cohort_demo_smoke.sh
decisions:
  - Cohort invokes pinned Rindle.Migration and Oban.Migration from separate host migrations.
  - All active Cohort setup paths rely on normal ecto.migrate; raw packaged migration replay is retired.
metrics:
  duration: 8m
  completed: 2026-08-10
status: complete
---

# Phase 120 Plan 03: Cohort Host Migration Proof Summary

Cohort now provisions Rindle through its own version-pinned migration, keeps Oban and the Ecto ledger in `public`, and mechanically proves the fixed Rindle catalog belongs only to `rindle`.

## Completed Tasks

1. Added the checked-in `InstallRindle` migration and a database-focused contract test covering all seven fixed relations, public host tables, and a real `MediaAsset` write/read.
2. Normalized Cohort's independent Oban migration to the locked `Oban.Migration.up/0` and `down/0` API, with an Oban snapshot around Rindle persistence.
3. Removed `rindle.migrate` and raw packaged-directory replay from active Cohort, Docker, browser-E2E, and CI setup paths. The Compose smoke now asserts the seven-relation catalog, public host ownership, and both host migration ledger entries.

## Verification

- PASS — Oban API precheck confirmed `Oban.Migration.up/0` and `down/0` are exported by the locked dependency.
- PASS — Fresh isolated database: `MIX_ENV=test MIX_TEST_PARTITION=_phase120b mix ecto.migrate --quiet` followed by `mix test test/rindle_migration_contract_test.exs --seed 0` (2 tests, 0 failures).
- PASS — `bash -n scripts/ci/cohort_demo_smoke.sh`.
- PASS — no active Cohort, CI, Docker, or script reference remains to `mix rindle.migrate`, `priv/rindle_migrate.exs`, or `Application.app_dir(:rindle`.
- BLOCKED (environment) — `bash scripts/ci/cohort_demo_smoke.sh` built the clean image successfully, then Docker failed before Compose boot with: `all predefined address pools have been fully subnetted` while creating `cohort-demo_default`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking verification isolation] Used a fresh disposable test database**
- **Found during:** Tasks 1–3
- **Issue:** The pre-existing local demo test database contained legacy raw-replay Rindle tables in `public`, so it cannot prove a fresh-install ownership contract.
- **Fix:** Verified against a newly created isolated `adoption_demo_test_phase120b` database using only normal host migrations.
- **Files modified:** None
- **Verification:** Focused contract passed with 2 tests and 0 failures.

**Total deviations:** 1 auto-fixed. **Impact:** No production or repository behavior changed; verification accurately models a clean consumer database.

## Deferred Issues

- The authoritative Docker cold-start assertion is unrun because the local Docker daemon has exhausted its predefined network address pools before services can start. Re-run `bash scripts/ci/cohort_demo_smoke.sh` after freeing or extending Docker network pools.

## Self-Check: PASSED

- Created migration and contract-test files exist.
- Task commits exist: `c2bdc59`, `6ae71d3`, and `ae1b5c0`.
