---
phase: 118
slug: isolated-migration-safe-upgrade
status: approved
nyquist_compliant: true
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
| **Quick run command** | `mix test test/rindle/migration_fast_test.exs --seed 0` |
| **Wave gate command** | `mix test test/rindle/migration_test.exs --seed 0` |
| **Full suite command** | `mix coveralls.multiple --type local --type json --slowest 20` |
| **Estimated runtime** | <30 seconds for the DB-free fast smoke; ~60 seconds for the live PostgreSQL wave gate; CI coverage lane for the full suite |

## Sampling Rate

- **After every implementation task commit:** Run `mix test test/rindle/migration_fast_test.exs --seed 0`. This file is created in Plan 01 before production edits and stays DB-free (`async: true`, no Repo checkout) so the sampled loop remains under 30 seconds.
- **After every plan wave (Waves 1-4):** Run the live PostgreSQL gate `mix test test/rindle/migration_test.exs --seed 0`. A plan may append its focused API/docs/default-build checks, but it may not replace this command.
- **Before `$gsd-verify-work`:** `mix coveralls.multiple --type local --type json --slowest 20` must be green, matching RUNNING.md.
- **Max feedback latency:** <30 seconds for per-task sampling; the ~60-second live PostgreSQL suite is intentionally wave-scoped.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 118-01-01 | 01 | 1 | MIGRATE-01 | T-118-01 | Only `rindle` and `public` prefixes reach quoted DDL; the owned-relation list excludes host infrastructure. | DB-free unit/smoke | `mix test test/rindle/migration_fast_test.exs --seed 0` | ⬜ Wave 0 | ⬜ pending |
| 118-02-01 | 02 | 2 | MIGRATE-02 | T-118-02 | The pinned forward export exists, generic movers remain absent, and the fixed seven-relation authority remains intact. | DB-free unit/smoke | `mix test test/rindle/migration_fast_test.exs --seed 0` | ⬜ Wave 0 | ⬜ pending |
| 118-02-02 | 02 | 2 | MIGRATE-03 | T-118-03 | The fast contract continues to compile and expose only the bounded migration surface after the move implementation. | DB-free smoke | `mix test test/rindle/migration_fast_test.exs --seed 0` | ⬜ Wave 0 | ⬜ pending |
| 118-03-01 | 03 | 3 | MIGRATE-03 | T-118-08, T-118-09 | Failure-path implementation preserves the DB-free bounded contract while exhaustive atomicity stays in the wave gate. | DB-free smoke | `mix test test/rindle/migration_fast_test.exs --seed 0` | ⬜ Wave 0 | ⬜ pending |
| 118-03-02 | 03 | 3 | MIGRATE-02, MIGRATE-03 | T-118-10 | The guarded reverse export exists, generic movers remain absent, and destructive down stays distinct. | DB-free unit/smoke | `mix test test/rindle/migration_fast_test.exs --seed 0` | ⬜ Wave 0 | ⬜ pending |
| 118-04-01 | 04 | 4 | MIGRATE-01, MIGRATE-02, MIGRATE-03 | T-118-12 | Fast file-content assertions sample the required default, directional helpers, timeout, host ownership, and rollback warning across current migration docs. | DB-free documentation smoke | `mix test test/rindle/migration_fast_test.exs --seed 0` | ⬜ Wave 0 | ⬜ pending |

## Wave Gates

| Wave | Required live PostgreSQL command | Additional focused gate |
|------|----------------------------------|-------------------------|
| 1 | `mix test test/rindle/migration_test.exs --seed 0` | `MIX_ENV=dev mix run test/rindle/migration_default_build_probe.exs` and `mix test test/rindle/schema_prefix_contract_test.exs --seed 0` |
| 2 | `mix test test/rindle/migration_test.exs --seed 0` | `mix test test/rindle/api_surface_boundary_test.exs test/rindle/schema_prefix_contract_test.exs --seed 0` |
| 3 | `mix test test/rindle/migration_test.exs --seed 0` | `mix test test/rindle/api_surface_boundary_test.exs --seed 0` |
| 4 | `mix test test/rindle/migration_test.exs --seed 0` | `mix test test/install_smoke/docs_parity_test.exs test/rindle/api_surface_boundary_test.exs test/rindle/schema_prefix_contract_test.exs --seed 0` |

## Wave 0 Requirements

- [ ] `test/rindle/migration_test.exs` — reusable qualified catalog, populated-data, index/FK, host-ledger, and `public.oban_jobs` assertions.
- [ ] `test/rindle/migration_fast_test.exs` — create before production edits as an `async: true`, DB-free contract test for option/default validation, exact owned-relation names, host-relation exclusion, directional export/generic-export boundaries as they are introduced, and Phase 118 documentation symbols when docs change.
- [ ] Default-compiled targeted probe — verify fresh `rindle` provisioning without changing `config/test.exs`, which remains the public compatibility suite.
- [ ] Deterministic injection seam for transaction failure and lock contention; do not rely on timing-only locking tests.
- [ ] CI-compatible privilege-refusal strategy, using a dedicated role only when available and a bounded seam/manual proof otherwise.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Privilege refusal under the production-like database role | MIGRATE-03 | CI may not permit role creation or privilege revocation. | With a non-owner role lacking target-schema `CREATE`, invoke the host migration and confirm the bounded refusal occurs before any `ALTER TABLE` changes relation locations. |
| Operational maintenance-window procedure | MIGRATE-03 | Quiescing deploy traffic and taking a backup are host operations. | Back up, drain Rindle writers/workers, run the documented host migration in a transaction with `SET LOCAL lock_timeout`, deploy the `rindle`-compiled release, then verify all seven Rindle relations and host-owned relations. |

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify.
- [x] Wave 0 covers all MISSING references.
- [x] No watch-mode flags.
- [x] Feedback latency < 30 seconds for the DB-free per-task smoke; live PostgreSQL coverage is wave-scoped.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** Phase 118 plans approved for execution; Wave 0 artifacts remain pending implementation.
