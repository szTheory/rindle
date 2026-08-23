---
phase: 123-runtime-operations-decomposition
plan: "01"
subsystem: runtime diagnostics
tags: [elixir, runtime-checks, telemetry, operations]
requires: []
provides:
  - Cohesive hidden mechanics for core, ownership, and optional integration diagnostics
  - Facade-owned runtime check ordering, result aggregation, and telemetry
affects: [runtime doctor, admin runtime doctor]
tech-stack:
  added: []
  patterns: [resolved-input domain collaborators, normalized internal outcomes, facade-owned telemetry]
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
  - Hidden collaborators receive resolved runtime inputs/readers and return scheduled internal outcomes without independently reading configuration or emitting telemetry.
metrics:
  duration: 14 minutes
  completed: 2026-08-22
  tasks_completed: 2
  files_changed: 7
status: complete
---

# Phase 123 Plan 01: Runtime Operations Decomposition Summary

Runtime diagnostics now use three hidden domain collaborators while `RuntimeChecks.run/2` retains every observable report, ordering, result-construction, and telemetry responsibility.

## Tasks Completed

1. **Route core and ownership diagnostics through the retained façade** — `ab82af3`, completed in `7551481` (`chore(123)`)
   - Moved core, migration/schema, resumable-session, and Oban diagnostic mechanics into hidden collaborators using inputs resolved by the façade.
   - Preserved façade-owned execution, check-map construction, event emission, sorting, and report aggregation.
   - Added compiled-boundary proof that collaborators are hidden and cannot replace the façade `run/2` entrypoint.

2. **Extract optional integrations and close the runtime-check slice** — `4fc2dab`, completed in `7551481` (`chore(123)`)
   - Moved GCS, tus, and streaming diagnostic mechanics into the hidden integration collaborator while retaining façade probe delegates.
   - Kept conditional-row presence, public GCS probe functions, result maps, redaction, and injected seams unchanged.
   - Asserted exactly one façade telemetry stop event for every scheduled result and locked the established arrival order in `65a7f26`.

## Verification

- `MIX_ENV=test mix test test/rindle/ops/runtime_checks_test.exs test/rindle/api_surface_boundary_test.exs --seed 0` — PASS (58 tests)
- `MIX_ENV=test mix compile --force --warnings-as-errors` — PASS (139 files)
- `MIX_ENV=test mix test test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_checks_streaming_test.exs test/rindle/contracts/telemetry_contract_test.exs --seed 0` — PASS (54 tests, 15 excluded)
- `bash scripts/maintainer/refactor_contract.sh` — PASS (87 tests)
- Final combined behavioral/API/telemetry run: `MIX_ENV=test mix test test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_checks_streaming_test.exs test/rindle/api_surface_boundary_test.exs test/rindle/contracts/telemetry_contract_test.exs --seed 0` — PASS (73 tests, 15 excluded)

## Decisions Made

- The collaborators own resolved-input diagnostic mechanics and return normalized internal outcomes; `RuntimeChecks` owns configuration/catalog resolution, check-map construction, telemetry, chronological execution, sorted report IDs, warning/failure accounting, and final report shape.
- `IntegrationChecks` covers GCS, tus, and streaming mechanics without adding public Rindle APIs; public hidden GCS probes remain façade delegates.

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 1 - Bug] Replaced callback-only shims with real domain ownership**
   - **Found during:** independent goal verification.
   - **Issue:** the initial extraction moved only closure scheduling while leaving all mechanics in the 1,801-line façade.
   - **Fix:** moved the actual diagnostic implementations and helpers into the three collaborators; the façade is now 386 lines.

2. **[Rule 1 - Bug] Restored telemetry delivery order**
   - **Found during:** independent re-review.
   - **Issue:** `doctor.profile_runtime_fit` executed before ownership checks even though the final report remained sorted.
   - **Fix:** composed initial core, ownership, profile-fit, and integration schedules in the established order and added an arrival-order contract assertion.

## Known Stubs

None.

## Self-Check: PASSED

- All seven changed source/test files exist; the focused streaming suite was exercised unchanged.
- Task and repair commits `ab82af3`, `4fc2dab`, `7551481`, `1ce0965`, and `65a7f26` exist in git history.
