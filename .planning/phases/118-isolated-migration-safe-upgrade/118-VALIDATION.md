---
phase: 118
slug: isolated-migration-safe-upgrade
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-09
---

# Phase 118 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Ecto SQL Sandbox + live PostgreSQL |
| **Config file** | `config/test.exs` |
| **Quick run command** | `mix test test/rindle/migration_test.exs --seed 0` |
| **Full suite command** | `mix coveralls.multiple --type local --type json` |
| **Estimated runtime** | ~60 seconds targeted; CI coverage lane for the full suite |

## Sampling Rate

- **After every task commit:** Run `mix test test/rindle/migration_test.exs --seed 0`.
- **After every plan wave:** Run `mix test test/rindle/migration_test.exs test/rindle/schema_prefix_contract_test.exs --seed 0`.
- **Before `$gsd-verify-work`:** `mix coveralls.multiple --type local --type json` must be green.
- **Max feedback latency:** ~60 seconds for targeted migration feedback.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 118-01-01 | 01 | 1 | MIGRATE-01 | T-118-01 | Only `rindle` and `public` prefixes reach quoted DDL; fresh provisioning creates the selected schema and exactly Rindle-owned relations idempotently. | PostgreSQL integration | `mix test test/rindle/migration_test.exs --seed 0` | ✅ | ⬜ pending |
| 118-02-01 | 02 | 2 | MIGRATE-02 | T-118-02 | A preflighted fixed seven-relation move preserves rows, foreign keys, indexes, and marker while leaving host relations untouched. | Serial PostgreSQL integration | `mix test test/rindle/migration_test.exs --seed 0` | ✅ | ⬜ pending |
| 118-02-02 | 02 | 2 | MIGRATE-03 | T-118-03 | Mixed, partial, marker-invalid, privilege-inadequate, injected-failure, and lock-contention states fail before unsafe mutation or roll back atomically. | Unit + serial PostgreSQL integration | `mix test test/rindle/migration_test.exs --seed 0` | ✅ | ⬜ pending |
| 118-03-01 | 03 | 3 | MIGRATE-03 | T-118-04 | Host migration instructions require maintenance, transaction-local timeout, verification, and a guarded reverse move rather than destructive `down/1`. | Documentation parity test | `mix test test/install_smoke/docs_parity_test.exs` | ✅ | ⬜ pending |

## Wave 0 Requirements

- [ ] `test/rindle/migration_test.exs` — reusable qualified catalog, populated-data, index/FK, host-ledger, and `public.oban_jobs` assertions.
- [ ] Default-compiled targeted probe — verify fresh `rindle` provisioning without changing `config/test.exs`, which remains the public compatibility suite.
- [ ] Deterministic injection seam for transaction failure and lock contention; do not rely on timing-only locking tests.
- [ ] CI-compatible privilege-refusal strategy, using a dedicated role only when available and a bounded seam/manual proof otherwise.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Privilege refusal under the production-like database role | MIGRATE-03 | CI may not permit role creation or privilege revocation. | With a non-owner role lacking target-schema `CREATE`, invoke the host migration and confirm the bounded refusal occurs before any `ALTER TABLE` changes relation locations. |
| Operational maintenance-window procedure | MIGRATE-03 | Quiescing deploy traffic and taking a backup are host operations. | Back up, drain Rindle writers/workers, run the documented host migration in a transaction with `SET LOCAL lock_timeout`, deploy the `rindle`-compiled release, then verify all seven Rindle relations and host-owned relations. |

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify.
- [ ] Wave 0 covers all MISSING references.
- [ ] No watch-mode flags.
- [ ] Feedback latency < 60 seconds for targeted checks.
- [ ] `nyquist_compliant: true` set in frontmatter.

**Approval:** pending
