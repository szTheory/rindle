---
phase: 132-measured-closure
plan: 09
subsystem: ci-topology
tags: [github-actions, ci, topology, regression, timing]
requires:
  - phase: 132-07
    provides: Preserved CI baseline and required-gate evidence.
  - phase: 132-08
    provides: Superseded timing sampler terminal and recovery ordering.
provides:
  - Exact D-08 six-edge scheduling correction with required aggregation preserved.
  - Source-bound D-09 job-body, membership, evaluator, and deterministic projection contract.
affects: [132-10, 132-11, ci-14, cov-05, safe-02]
tech-stack:
  added: []
  patterns: [source-bounded workflow contracts, deterministic topology projection, RED-GREEN workflow correction]
key-files:
  created: [test/fixtures/ci_timing/phase_132_topology_projection.json]
  modified: [.github/workflows/ci.yml, test/install_smoke/ci_lane_split_test.exs]
decisions:
  - D-08 removes only Quality and Optional Dependencies prerequisites from Integration, Contract, and Adoption Demo E2E Smoke.
  - Projection remains causal regression evidence only; 132-11's API-backed receipt is the sole CI-14 acceptance authority.
requirements-completed: []
coverage:
  - id: D1
    description: Exact six-edge topology correction with required summary and evaluator preservation.
    requirement: SAFE-02
    verification:
      - kind: unit
        ref: mix test test/install_smoke/ci_lane_split_test.exs test/install_smoke/ci_observability_test.exs --seed 0
        status: pass
      - kind: other
        ref: bash scripts/ci/test_ci_summary_gate.sh
        status: pass
    human_judgment: false
  - id: D2
    description: Deterministic five-run topology projection distinguishes partial and exact recovery graphs.
    requirement: CI-14
    verification:
      - kind: unit
        ref: test/install_smoke/ci_lane_split_test.exs#phase 132 deterministic topology projection is source-attributed and non-accepting
        status: pass
    human_judgment: false
metrics:
  duration: 18 minutes
  completed: 2026-08-26
  tasks_completed: 2
  files_modified: 3
status: complete
---

# Phase 132 Plan 09: Exact Topology Recovery Summary

The required CI graph now starts Integration, Contract, and Adoption Demo E2E Smoke independently while retaining every required result, CI Summary gate semantic, and affected job authority.

## Tasks Completed

| Task | Description | Commit |
| --- | --- | --- |
| 1 | RED-lock the exact graph delta and deterministic critical-path projection | `e2f2256` |
| 2 | GREEN the exact six-edge workflow correction | `11bfee5` |

## Accomplishments

- Captured an immutable five-run timing fixture and a deterministic, explicitly non-accepting projection.
- Added tagged source-bound tests that freeze D-08's exact graph, D-09 self-containment, summary/observability membership, and evaluator delegation.
- Removed exactly three workflow declarations, representing only the six authorized scheduling edges.

## Verification

- RED observed before the workflow edit: `mix test test/install_smoke/ci_lane_split_test.exs --only phase_132_topology_recovery --seed 0` failed only at `D-08 exact six-edge topology` because `integration` still declared the authorized prerequisites.
- GREEN: `mix test test/install_smoke/ci_lane_split_test.exs test/install_smoke/ci_observability_test.exs --seed 0` — 34 tests passed.
- `bash scripts/ci/test_ci_summary_gate.sh` — 6 checks passed.
- Exact workflow patch assertion and `git diff --check` passed.
- `./scripts/maintainer/automation_first_contract.sh` passed.

## Decisions Made

- Keep `adopter.needs`, `ci-summary.needs`, `ci-observability.needs`, `CI Summary`, `if: always()`, and `eval_ci_summary.sh` unchanged.
- Treat the fixture projection as selection evidence only; no local timing claim closes CI-14.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Next Phase Readiness

132-10 can bind this code-bearing topology correction to a final preservation census and immutable preflight. CI-14 remains open pending 132-11's fresh API-backed ten-run receipt.

## Self-Check: PASSED

- Confirmed all three implementation artifacts exist and both task commits resolve in git history.
