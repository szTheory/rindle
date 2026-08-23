---
phase: 125-behavioral-test-support
plan: "09"
subsystem: testing
tags: [elixir, exunit, documentation-parity, ci, proof]
requires:
  - phase: 125-08
    provides: Onboarding and operations docs-parity domain suites
provides:
  - Product and Admin docs-parity domain suite
  - Explicit Proof carrier for all four docs-parity domains
affects: [125-10, proof-ci]
tech-stack:
  added: []
  patterns: [explicit proof argv, domain-owned documentation contracts]
key-files:
  created: [test/install_smoke/docs_parity/product_and_admin_test.exs]
  modified: [.github/workflows/ci.yml, RUNNING.md, test/install_smoke/docs_parity/operations_test.exs]
  deleted: [test/install_smoke/docs_parity_test.exs]
key-decisions:
  - "Retire the aggregate only after the final product/Admin owner runs with the three existing domain suites."
  - "Keep one Proof mix invocation and enumerate the four domain files explicitly before link hygiene."
requirements-completed: [TEST-03, SAFE-01]
duration: 16min
completed: 2026-08-23
status: complete
---

# Phase 125 Plan 09: Complete Docs Parity Domain Split Summary

**The oversized docs-parity aggregate is retired: four focused public-contract suites now run explicitly in the unchanged Proof topology.**

## Accomplishments

- Renamed the final aggregate into `ProductAndAdminTest`, retaining owner-erasure, user-flow, batch-erasure, and Admin truth assertions.
- Updated the existing Proof step’s single `mix test` argv to enumerate install/migrations, onboarding/capabilities, operations, and product/admin suites before unchanged link hygiene.
- Updated the RUNNING Proof carrier description and the operations parity expectation for the explicit domain wording.

## Task Commits

1. **Task 1: Move product, owner-erasure, user-flow, and Admin truth then retire the aggregate** — `2c49b3e` (test)
2. **Task 2: Point Proof at every domain with exact topology preservation** — `7d44089` (test)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Aligned the operations matrix assertion with the retired aggregate carrier**
- **Found during:** Task 2
- **Issue:** The public RUNNING update correctly invalidated the old `docs_parity_test.exs` assertion.
- **Fix:** Assert the new explicit install/migrations carrier wording instead.
- **Files modified:** `test/install_smoke/docs_parity/operations_test.exs`
- **Commit:** `7d44089`

## Verification

- Four domain suites plus separate release parity — pass (59 tests, 0 failures).
- Four Proof-carrier domain suites — pass (35 tests, 0 failures).
- `MIX_ENV=test mix test test/install_smoke/refactor_contract_test.exs --seed 0` — pass (5 tests, 0 failures).
- `bash scripts/maintainer/refactor_contract.sh` — pass (92 tests, 0 failures).

## Self-Check: PASSED

Product/Admin suite exists, retired aggregate is absent, and commits `2c49b3e` and `7d44089` are present.
