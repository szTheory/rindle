---
phase: 125-behavioral-test-support
plan: "08"
subsystem: testing
tags: [elixir, exunit, documentation-parity, onboarding, operations]
requires:
  - phase: 125-07
    provides: Shared docs-parity mechanics and install/migration domain ownership
provides:
  - Dedicated onboarding and capabilities parity suite
  - Dedicated operations and maintainer-runbook parity suite
affects: [125-09, docs-parity]
tech-stack:
  added: []
  patterns: [domain-specific read-once maps, compiled documentation parity, public contract ownership]
key-files:
  created: [test/install_smoke/docs_parity/onboarding_and_capabilities_test.exs, test/install_smoke/docs_parity/operations_test.exs]
  modified: [test/install_smoke/docs_parity_test.exs]
key-decisions:
  - "Onboarding/capabilities owns adopter lifecycle, AV/storage, profile, and TusPlug public-contract assertions."
  - "Operations owns CI, runbook, support matrix, task, and diagnostics assertions while release truth stays separate."
requirements-completed: [TEST-03, SAFE-01]
duration: 24min
completed: 2026-08-23
status: complete
---

# Phase 125 Plan 08: Onboarding and Operations Docs Parity Summary

**Docs parity now separates adopter onboarding capability truth from maintainer operations truth, leaving only product/admin coverage in the aggregate.**

## Accomplishments

- Moved lifecycle, convenience APIs, introductory concepts, storage/AV onboarding, product boundary, and compiled TusPlug scope assertions into `OnboardingAndCapabilitiesTest`.
- Moved CI/toolchain, maintainer/public runbook boundaries, support matrices, task catalog, troubleshooting, and doctor/runtime diagnostics into `OperationsTest`.
- Retained the dedicated release suite and the aggregate’s product/admin assertions without duplicate registrations.

## Task Commits

1. **Task 1: Move onboarding, profile, AV, storage, and tus parity as one adopter domain** — `c9439ae` (test)
2. **Task 2: Move maintainer CI, runbook, tasks, and diagnostics parity as one operations domain** — `15a6b24` (test)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected the domain-local operations guide path**
- **Found during:** Task 2
- **Issue:** A moved direct file read retained the aggregate directory depth.
- **Fix:** Resolved the path from the domain suite and retained the existing diagnostics assertions.
- **Files modified:** `test/install_smoke/docs_parity/operations_test.exs`
- **Commit:** `15a6b24`

## Verification

- `MIX_ENV=test mix test test/install_smoke/docs_parity_test.exs test/install_smoke/docs_parity/install_and_migrations_test.exs test/install_smoke/docs_parity/onboarding_and_capabilities_test.exs test/install_smoke/docs_parity/operations_test.exs test/install_smoke/release_docs_parity_test.exs --seed 0` — pass (59 tests, 0 failures).
- `bash scripts/maintainer/refactor_contract.sh` — pass (92 tests, 0 failures).
- `mix format` for all Plan 125-08 test files — pass.

## Self-Check: PASSED

Declared artifacts exist and task commits `c9439ae` and `15a6b24` are present.
