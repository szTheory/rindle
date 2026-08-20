---
phase: 118-isolated-migration-safe-upgrade
verified: 2026-08-10T00:43:38Z
status: passed
score: 4/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: human_needed
  previous_score: 2/4
  gaps_closed:
    - "The published migration now calls directional helpers directly at migration-body scope."
    - "V1 translates PostgreSQL lock-not-available errors to bounded quiesce-and-retry guidance."
    - "Dedicated disposable PostgreSQL partitions run the former human checks in merge-blocking CI."
  gaps_remaining: []
  regressions: []
automated_verification:
  - "The Integration job runs disposable PostgreSQL partitions for documented Ecto.Migrator forward/reverse, lock contention, database CREATE denial, and target-schema privilege denial."
  - "Privilege refusals use real restricted PostgreSQL roles, not only process-local simulation."
---

# Phase 118: Isolated Migration & Safe Upgrade Verification Report

**Phase Goal:** Adopters can create a fresh isolated install or move a populated legacy install to `rindle` without losing Rindle data or taking ownership of host infrastructure.
**Verified:** 2026-08-10T00:43:38Z
**Status:** passed
**Re-verification:** Yes — automated migration E2E coverage replaced manual UAT.

## Goal Achievement

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A fresh host migration provisions the selected schema, all six Rindle tables, and marker state idempotently. | ✓ VERIFIED | Fresh provisioning and options/ownership contracts pass. |
| 2 | A host-owned public-to-`rindle` upgrade moves exactly six Rindle tables plus marker while preserving data and integrity. | ✓ VERIFIED | The disposable-database `migration_e2e:documented` test runs the documented Ecto.Migrator forward/reverse path and verifies fixtures, indexes, sequences, FKs, marker, Oban, and the host ledger. |
| 3 | Unsafe database states stop before an unsafe move and provide bounded guidance. | ✓ VERIFIED | Separate disposable-database tests prove lock contention plus real PostgreSQL database-CREATE and target-schema privilege refusals before mutation. |
| 4 | Upgrade instructions state maintenance-window and limited host-controlled rollback truthfully. | ✓ VERIFIED | The guide’s direct-call parity checks pass. |

**Score:** 4/4 truths verified.

## CI Evidence

The merge-blocking `Integration` job runs these explicit commands, each against its own disposable test database:

```sh
MIX_TEST_PARTITION=_migration_e2e_documented mix test test/rindle/migration_test.exs --only migration_e2e:documented --seed 0
MIX_TEST_PARTITION=_migration_e2e_lock mix test test/rindle/migration_test.exs --only migration_e2e:lock_contention --seed 0
MIX_TEST_PARTITION=_migration_e2e_database_privilege mix test test/rindle/migration_test.exs --only migration_e2e:database_privilege --seed 0
MIX_TEST_PARTITION=_migration_e2e_schema_privilege mix test test/rindle/migration_test.exs --only migration_e2e:schema_privilege --seed 0
```

All four commands passed locally on 2026-08-10. The default suite excludes the `migration_e2e` tag, so stateful DDL tests cannot pollute its shared database state.

## Additional Checks

- `mix test test/rindle/migration_test.exs --seed 0` — 16 tests, 0 failures; 4 migration E2E cases excluded.
- `mix test test/rindle/migration_fast_test.exs test/async_safety_guard_test.exs --seed 0` — 8 tests, 0 failures.
- `mix compile --warnings-as-errors` and formatting checks passed.
- Malformed markers now fail closed before querying a missing `version` column.

## Human Verification

None required. The operational runbook still instructs adopters to back up and quiesce production writers; those are deployment procedures, not a remaining library acceptance gate.

---

_Verified: 2026-08-10T00:43:38Z_
_Verifier: the agent (automated E2E re-verification)_
