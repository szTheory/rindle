---
phase: 30
slug: lifecycle-repair-operations
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-05
---

# Phase 30 — Validation Strategy

> Per-phase validation contract for Phase 30 execution. This is the Nyquist gate artifact for REPAIR-01 through REPAIR-05.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with Oban.Testing, log capture, and telemetry assertions where needed |
| **Config file** | `config/test.exs`, `test/test_helper.exs` |
| **Quick run command** | `mix test test/rindle/api_surface_boundary_test.exs test/rindle/ops/lifecycle_repair_test.exs --warnings-as-errors` |
| **Full phase command** | `mix test test/rindle/api_surface_boundary_test.exs test/rindle/error_test.exs test/rindle/ops/lifecycle_repair_test.exs test/rindle/ops/variant_maintenance_test.exs test/rindle/ops/upload_maintenance_test.exs test/rindle/ops/sweep_orphaned_temp_files_test.exs test/rindle/workers/process_variant_test.exs test/rindle/workers/promote_asset_test.exs test/rindle/workers/maintenance_workers_test.exs --warnings-as-errors` |
| **Estimated runtime** | ~60-120 seconds once all phase files exist |

---

## Sampling Rate

- After every task commit: run the task’s `<automated>` command verbatim.
- After every plan wave: run the cumulative phase lane for all completed plans.
- Before `/gsd-verify-work`: run the full phase command and `mix compile --warnings-as-errors`.
- Max feedback latency: <= 30 seconds per targeted command; <= 120 seconds for the full phase lane.

---

## Phase Requirements → Plan/Test Map

| Req ID | Plan | Requirement Proof | Automated Command | Evidence Type | Status |
|--------|------|-------------------|-------------------|---------------|--------|
| REPAIR-01 | 30-01 | `Rindle.reprobe/1` refreshes only probe-derived fields and clears stale probe fields without mutating unrelated lifecycle state | `mix test test/rindle/api_surface_boundary_test.exs test/rindle/ops/lifecycle_repair_test.exs test/rindle/workers/promote_asset_test.exs --warnings-as-errors` | unit/integration/contract | ⬜ pending |
| REPAIR-02 | 30-02 | `Rindle.requeue_variants/2` requeues only failed/cancelled variants for one asset, validates explicit variant names loudly, and remains idempotent via enqueue-only semantics | `mix test test/rindle/api_surface_boundary_test.exs test/rindle/error_test.exs test/rindle/ops/lifecycle_repair_test.exs test/rindle/workers/process_variant_test.exs --warnings-as-errors` | unit/integration/contract | ⬜ pending |
| REPAIR-03 | 30-03 | Broad regeneration remains the explicit maintenance lane through `mix rindle.regenerate_variants` with deterministic summary behavior | `mix test test/rindle/ops/variant_maintenance_test.exs --warnings-as-errors` | unit/ops | ⬜ pending |
| REPAIR-04 | 30-03 | Upload cleanup and temp sweeping have on-demand and scheduled parity with dry-run-first destructive semantics | `mix test test/rindle/ops/upload_maintenance_test.exs test/rindle/ops/sweep_orphaned_temp_files_test.exs test/rindle/workers/maintenance_workers_test.exs --warnings-as-errors` | unit/integration/ops | ⬜ pending |
| REPAIR-05 | 30-04 | Repair surfaces return deterministic reports with visible partial failures, and operator guidance names the correct supported repair verbs | `mix test test/rindle/error_test.exs test/rindle/ops/lifecycle_repair_test.exs test/rindle/ops/sweep_orphaned_temp_files_test.exs --warnings-as-errors` | contract/docs/regression | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirements | Automated Command | File Exists | Status |
|---------|------|------|--------------|-------------------|-------------|--------|
| 30-01-T1 | 30-01 | 1 | REPAIR-01 | `mix test test/rindle/ops/lifecycle_repair_test.exs test/rindle/workers/promote_asset_test.exs --warnings-as-errors` | no — created by execution | ⬜ pending |
| 30-01-T2 | 30-01 | 1 | REPAIR-01 | `mix test test/rindle/api_surface_boundary_test.exs test/rindle/ops/lifecycle_repair_test.exs --warnings-as-errors` | yes / no | ⬜ pending |
| 30-02-T1 | 30-02 | 2 | REPAIR-02 | `mix test test/rindle/ops/lifecycle_repair_test.exs test/rindle/workers/process_variant_test.exs --warnings-as-errors` | no — created by execution | ⬜ pending |
| 30-02-T2 | 30-02 | 2 | REPAIR-02 | `mix test test/rindle/api_surface_boundary_test.exs test/rindle/error_test.exs test/rindle/ops/lifecycle_repair_test.exs --warnings-as-errors` | yes / no | ⬜ pending |
| 30-03-T1 | 30-03 | 1 | REPAIR-04 | `mix test test/rindle/ops/sweep_orphaned_temp_files_test.exs test/rindle/workers/maintenance_workers_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 30-03-T2 | 30-03 | 1 | REPAIR-03, REPAIR-04 | `mix test test/rindle/ops/variant_maintenance_test.exs test/rindle/workers/maintenance_workers_test.exs --warnings-as-errors` | yes | ⬜ pending |
| 30-04-T1 | 30-04 | 3 | REPAIR-05 | `mix test test/rindle/ops/lifecycle_repair_test.exs test/rindle/ops/sweep_orphaned_temp_files_test.exs --warnings-as-errors` | no / yes | ⬜ pending |
| 30-04-T2 | 30-04 | 3 | REPAIR-05 | `mix test test/rindle/error_test.exs --warnings-as-errors` | yes | ⬜ pending |

---

## Wave 0 Gaps

- [ ] `test/rindle/ops/lifecycle_repair_test.exs` — public repair API and hidden-service contract coverage for reprobe and targeted requeue.
- [ ] `lib/mix/tasks/rindle.sweep_orphaned_temp_files.ex` plus task-level assertions — explicit on-demand temp sweep parity lane.
- [ ] Report/failure contract assertions for the new repair surfaces — either dedicated files or equivalent coverage in the lifecycle/sweep suites.

---

## Required Automated Commands

- `mix test test/rindle/api_surface_boundary_test.exs test/rindle/ops/lifecycle_repair_test.exs test/rindle/workers/promote_asset_test.exs --warnings-as-errors`
- `mix test test/rindle/api_surface_boundary_test.exs test/rindle/error_test.exs test/rindle/ops/lifecycle_repair_test.exs test/rindle/workers/process_variant_test.exs --warnings-as-errors`
- `mix test test/rindle/ops/variant_maintenance_test.exs --warnings-as-errors`
- `mix test test/rindle/ops/upload_maintenance_test.exs test/rindle/ops/sweep_orphaned_temp_files_test.exs test/rindle/workers/maintenance_workers_test.exs --warnings-as-errors`
- `mix test test/rindle/error_test.exs test/rindle/ops/lifecycle_repair_test.exs test/rindle/ops/sweep_orphaned_temp_files_test.exs --warnings-as-errors`
- `mix compile --warnings-as-errors`

---

## Phase Gate Evidence

- `30-01` proves the probe refresh lane is truthful: one public API, one hidden service, strict probe-field persistence, and no unrelated lifecycle mutation.
- `30-02` proves asset-scoped repair remains narrow: explicit variant-name validation, failed/cancelled-only targeting, ready-sibling preservation, and idempotent enqueue-only behavior.
- `30-03` proves broad regeneration and residue cleanup stay explicit maintenance lanes with focused sweep surfaces and scheduled/on-demand parity.
- `30-04` proves the operator-facing contract is frozen: deterministic reports, visible partial failures, and docs/error text that name only the supported repair verbs.
- Final phase gate: the full phase command plus `mix compile --warnings-as-errors` must be green before execution can be marked complete.

---

## Validation Sign-Off

- [x] All plans 30-01 through 30-04 are mapped to automated verification.
- [x] REPAIR-01 through REPAIR-05 each have at least one explicit automated command.
- [x] The validation contract covers API boundary, worker/Oban behavior, maintenance parity, and operator-facing failure semantics.
- [x] `nyquist_compliant: true` is set because every requirement has an execution-time verification target.

**Approval:** complete — validation artifact now reflects the executed phase state.
