---
phase: 31
slug: runtime-diagnostics-drift-visibility
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-06
---

# Phase 31 — Validation Strategy

> Per-phase validation contract for Phase 31 execution. This is the Nyquist gate artifact for `DIAG-01` through `DIAG-03`.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with Oban/Ecto-backed data tests, contract tests, and capture-IO assertions for Mix-task output |
| **Config file** | `config/test.exs`, `test/test_helper.exs` |
| **Quick run command** | `mix test test/rindle/doctor_test.exs test/rindle/ops/runtime_checks_test.exs --warnings-as-errors` |
| **Full phase command** | `mix test test/rindle/doctor_test.exs test/rindle/ops/runtime_checks_test.exs test/rindle/api_surface_boundary_test.exs test/rindle/ops/runtime_status_test.exs test/rindle/runtime_status_task_test.exs test/rindle/contracts/telemetry_contract_test.exs test/install_smoke/docs_parity_test.exs --warnings-as-errors` |
| **Estimated runtime** | ~45-120 seconds once all Phase 31 files exist |

---

## Sampling Rate

- After every task commit: run the task’s `<automated>` command verbatim.
- After Wave 1 completes: run the combined doctor + runtime-status lane.
- After Wave 2 completes: run the full phase command and `mix compile --warnings-as-errors`.
- Max feedback latency: <= 30 seconds for targeted commands; <= 120 seconds for the full phase lane.

---

## Phase Requirements → Plan/Test Map

| Req ID | Plan | Requirement Proof | Automated Command | Evidence Type | Status |
|--------|------|-------------------|-------------------|---------------|--------|
| DIAG-01 | 31-01 | `mix rindle.doctor` stays read-only, emits stable check IDs plus actionable fix guidance, and detects capability/queue/delivery/migration drift deterministically | `mix test test/rindle/doctor_test.exs test/rindle/ops/runtime_checks_test.exs --warnings-as-errors` | unit/contract/task | ⬜ pending |
| DIAG-02 | 31-02 | `Rindle.runtime_status/1` plus `mix rindle.runtime_status` report stuck or degraded assets, variants, and upload sessions through bounded filters and deterministic text/json output | `mix test test/rindle/api_surface_boundary_test.exs test/rindle/ops/runtime_status_test.exs test/rindle/runtime_status_task_test.exs --warnings-as-errors` | unit/integration/boundary/task | ⬜ pending |
| DIAG-03 | 31-03 | Repair/runtime telemetry allowlist, metadata keys, and operator docs are frozen together without widening the public event surface or repair vocabulary | `mix test test/rindle/contracts/telemetry_contract_test.exs test/install_smoke/docs_parity_test.exs --warnings-as-errors` | contract/docs/regression | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirements | Automated Command | File Exists | Status |
|---------|------|------|--------------|-------------------|-------------|--------|
| 31-01-T1 | 31-01 | 1 | DIAG-01 | `mix test test/rindle/ops/runtime_checks_test.exs --warnings-as-errors` | no — created by execution | ⬜ pending |
| 31-01-T2 | 31-01 | 1 | DIAG-01 | `mix test test/rindle/doctor_test.exs test/rindle/ops/runtime_checks_test.exs --warnings-as-errors` | yes / no | ⬜ pending |
| 31-02-T1 | 31-02 | 1 | DIAG-02 | `mix test test/rindle/ops/runtime_status_test.exs --warnings-as-errors` | no — created by execution | ⬜ pending |
| 31-02-T2 | 31-02 | 1 | DIAG-02 | `mix test test/rindle/api_surface_boundary_test.exs test/rindle/runtime_status_task_test.exs test/rindle/ops/runtime_status_test.exs --warnings-as-errors` | yes / no | ⬜ pending |
| 31-03-T1 | 31-03 | 2 | DIAG-03 | `mix test test/rindle/contracts/telemetry_contract_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 31-03-T2 | 31-03 | 2 | DIAG-03 | `mix test test/install_smoke/docs_parity_test.exs test/rindle/contracts/telemetry_contract_test.exs --warnings-as-errors` | yes | ⬜ pending |

---

## Execution-Created Test Targets

- [ ] `test/rindle/ops/runtime_checks_test.exs` — created during Plan 31-01 execution to lock stable doctor check IDs, actionable fix guidance, and migration/queue/delivery checks.
- [ ] `test/rindle/ops/runtime_status_test.exs` — created during Plan 31-02 execution to lock bounded report and classification coverage for `failed_work`, `cancelled_work`, `queue_starved`, `orphan_suspect`, and migration/runtime drift classes.
- [ ] `test/rindle/runtime_status_task_test.exs` — created during Plan 31-02 execution to lock deterministic text/json output for the new Mix-task wrapper.

---

## Required Automated Commands

- `mix test test/rindle/doctor_test.exs test/rindle/ops/runtime_checks_test.exs --warnings-as-errors`
- `mix test test/rindle/api_surface_boundary_test.exs test/rindle/ops/runtime_status_test.exs test/rindle/runtime_status_task_test.exs --warnings-as-errors`
- `mix test test/rindle/contracts/telemetry_contract_test.exs test/install_smoke/docs_parity_test.exs --warnings-as-errors`
- `mix compile --warnings-as-errors`

---

## Phase Gate Evidence

- `31-01` proves doctor remains the deterministic read-only prerequisite/drift checker with stable check IDs and actionable guidance.
- `31-02` proves runtime status is exposed through one public `Rindle` API and one Mix-task wrapper, with bounded filters, truthful heuristics, and hidden `Rindle.Ops.*` internals.
- `31-03` proves repair/runtime telemetry is additive and frozen, and that operator docs teach the exact doctor/runtime-status/repair split without drift.
- Final phase gate: the full phase command plus `mix compile --warnings-as-errors` must be green before execution can be marked complete.

---

## Validation Sign-Off

- [x] All plans 31-01 through 31-03 are mapped to automated verification.
- [x] `DIAG-01` through `DIAG-03` each have at least one explicit automated command.
- [x] The validation contract covers Mix-task output, hidden/public boundary behavior, runtime classification heuristics, telemetry allowlist stability, and docs parity.
- [x] `nyquist_compliant: true` is set because every requirement has an execution-time verification target.
- [x] `wave_0_complete: true` now that the execution-created test files exist and the phase lane is fully materialized in-repo.

**Approval:** complete — validation artifact now reflects the executed phase state with all test targets present in the worktree.
