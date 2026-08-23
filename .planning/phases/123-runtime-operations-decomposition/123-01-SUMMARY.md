---
phase: 123-runtime-operations-decomposition
plan: "01"
subsystem: runtime diagnostics
tags: [elixir, runtime-checks, telemetry, operations]
requires: []
provides:
  - Cohesive hidden schedules for core, ownership, and optional integration diagnostics
  - Facade-owned runtime check ordering, result aggregation, and telemetry
affects: [runtime doctor, admin runtime doctor]
tech-stack:
  added: []
  patterns: [resolved-input collaborator schedules, facade-owned telemetry]
key-files:
  created:
    - lib/rindle/ops/runtime_checks/core_checks.ex
    - lib/rindle/ops/runtime_checks/ownership_checks.ex
    - lib/rindle/ops/runtime_checks/integration_checks.ex
  modified:
    - lib/rindle/ops/runtime_checks.ex
    - test/rindle/ops/runtime_checks_test.exs
    - test/rindle/api_surface_boundary_test.exs
    - test/rindle/contracts/telemetry_contract_test.exs
decisions:
  - RuntimeChecks.run/2 remains the single result-construction, telemetry, sorting, and report-aggregation boundary.
  - Hidden collaborators receive resolved runtime inputs and return scheduled closures without independently reading configuration or emitting telemetry.
metrics:
  duration: 14 minutes
  completed: 2026-08-22
  tasks_completed: 2
  files_changed: 7
status: complete
---

# Phase 123 Plan 01: Runtime Operations Decomposition Summary

Runtime diagnostics now use three hidden domain schedules while `RuntimeChecks.run/2` retains every observable report, ordering, and telemetry responsibility.

## Tasks Completed

1. **Route core and ownership diagnostics through the retained façade** — `ab82af3` (`chore(123-01)`)
   - Added hidden core and ownership schedules using inputs resolved by the façade.
   - Preserved façade-owned execution, check-map construction, event emission, sorting, and report aggregation.
   - Added compiled-boundary proof that collaborators are hidden and cannot replace the façade `run/2` entrypoint.

2. **Extract optional integrations and close the runtime-check slice** — `4fc2dab` (`chore(123-01)`)
   - Added a hidden optional-integration schedule for GCS, tus, and streaming checks.
   - Kept conditional-row presence, public GCS probe functions, result maps, redaction, and injected seams unchanged.
   - Asserted exactly one façade telemetry stop event for every scheduled result.

## Verification

- `MIX_ENV=test mix test test/rindle/ops/runtime_checks_test.exs test/rindle/api_surface_boundary_test.exs --seed 0` — PASS (58 tests)
- `MIX_ENV=test mix compile --force` — PASS (135 files)
- `MIX_ENV=test mix test test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_checks_streaming_test.exs test/rindle/contracts/telemetry_contract_test.exs --seed 0` — PASS (54 tests, 15 excluded)
- `bash scripts/maintainer/refactor_contract.sh` — PASS (86 tests)
- Final combined behavioral/API/telemetry run: `MIX_ENV=test mix test test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_checks_streaming_test.exs test/rindle/api_surface_boundary_test.exs test/rindle/contracts/telemetry_contract_test.exs --seed 0` — PASS (73 tests, 15 excluded)

## Decisions Made

- The collaborators own only resolved-input schedule composition; `RuntimeChecks` continues to own all configuration resolution, normalized check maps, telemetry, sorted ID ordering, warning/failure accounting, and final report shape.
- `IntegrationChecks` covers GCS, tus, and streaming schedule selection so optional diagnostics stay cohesive without adding public APIs.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- All seven changed source/test files exist; the focused streaming suite was exercised unchanged.
- Task commits `ab82af3` and `4fc2dab` exist in git history.
