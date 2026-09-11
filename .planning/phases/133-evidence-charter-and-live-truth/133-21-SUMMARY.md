---
phase: 133-evidence-charter-and-live-truth
plan: 21
subsystem: release-evidence
tags: [package-authority, lifecycle-evidence, reconciliation, tdd]
status: complete
requires:
  - phase: 133-17
    provides: immutable Plans 01-17 validation history
provides:
  - exact-subject package version authority independent of package receipts
  - one attributable combined smoke/lifecycle command result
  - summary-backed Phase 133 reconciliation across 17/22 through 22/22
affects: [133-22, live-truth, package-smoke, phase-reconciliation]
tech-stack:
  added: []
  patterns:
    - independent expected-version authority at package verification boundaries
    - exact command/result key-set attribution
    - immutable validation prefix with append-only pending mappings
key-files:
  created:
    - test/install_smoke/phase_133_completed_validation_test.exs
  modified:
    - test/install_smoke/support/generated_app_helper.ex
    - scripts/maintainer/validate_live_truth.exs
    - test/install_smoke/live_truth_parity_test.exs
    - scripts/maintainer/validate_phase_133_reconciliation.exs
    - .planning/phases/133-evidence-charter-and-live-truth/133-VALIDATION.md
key-decisions:
  - "Package evidence schema v2 represents smoke and lifecycle as one combined smoke_lifecycle command/result instead of duplicated proof slots."
  - "Package receipts must match an independently supplied exact-subject release version; internal package/receipt agreement is insufficient authority."
  - "Plans 01-17 remain byte-identical history while Plans 18-22 use a separate append-only mapping and explicit post-summary completion mode."
requirements-completed: [TRUTH-08]
plan_head_before: 4acf9659ed30dadbe2026c53235b56a21fa8694a
actuals:
  tokens: 18585
  tasks: 3
  commits: 6
metrics:
  duration: 27m
  completed: 2026-09-11
---

# Phase 133 Plan 21: Package Truth and Reconciliation Summary

Package evidence now binds independently to the exact release subject, attributes smoke/lifecycle truth to one real execution, and reconciles every summary-backed Phase 133 state through the post-summary 22/22 gate.

## Performance

- **Duration:** 27 minutes
- **Tasks:** 3
- **Files changed:** 6
- **Commits:** 6 measured from the persisted plan ledger

## Accomplishments

- Replaced duplicated smoke and lifecycle receipt slots with schema-v2 `smoke_lifecycle` command/result evidence and fail-closed key-set validation.
- Required package receipts and unpacked package metadata to match the independent release version derived at the exact repository subject, rejecting self-consistent stale packages.
- Preserved the complete Plans 01-17 validation bytes while appending exact pending mappings for Plans 18-22, including Plan 22's post-summary gate.
- Added mutation coverage for every live 17/22 through 21/22 subset, summary/checkbox disagreement, roadmap drift, early Plan 22 completion, mapping corruption, and final 22/22 completion.

## Task Commits

1. **Task 1: Make lifecycle proof honestly attributable**
   - RED: `8401dd5` — failing duplicate lifecycle evidence regression
   - GREEN: `f1096ab` — combined smoke/lifecycle evidence schema
2. **Task 2: Bind package evidence to independent release authority**
   - RED: `0574371` — failing stale-package and authority mutations
   - GREEN: `ef48d06` — exact-subject version authority enforcement
3. **Task 3: Reconcile every live and post-summary Phase 133 state**
   - RED: `72cef07` — failing Wave 15 reconciliation matrix
   - GREEN: `8500a33` — immutable history plus 17/22–22/22 validation

## Verification

- `mix test test/install_smoke/live_truth_parity_test.exs test/install_smoke/generated_app_smoke_test.exs` — 37 tests, 0 failures.
- `mix test test/install_smoke/live_truth_parity_test.exs --only package_authority` — 9 tests, 0 failures.
- `mix test test/install_smoke/phase_133_reconciliation_test.exs test/install_smoke/phase_133_completed_validation_test.exs` — 26 tests, 0 failures.
- Production reconciliation — 20 completed, 2 pending plans, 21 pending verification pairs.
- Canonical formatting and `automation_first_contract.sh` passed.

## TDD Gate Compliance

All three tasks followed RED then GREEN with intentional failing evidence before implementation. Each RED was committed separately, each GREEN verification passed, and no behavior-neutral refactor commit was needed.

## Decisions Made

- The combined lifecycle claim has one receipt identity: `smoke_lifecycle`; legacy duplicate `smoke` and `lifecycle` slots are rejected.
- Release version enters package verification as required external authority and cannot be inferred solely from the package or receipt under test.
- Normal reconciliation derives completion from exact complete summaries and matching checkboxes; only the dedicated post-summary mode can accept Plan 22 and 22/22.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The repository-pinned Elixir/Erlang versions were unavailable locally, so verification used the installed compatible Elixir 1.19.5 / OTP 28.4.1 toolchain.
- The exact package-authority suite required the repository-owned MinIO bootstrap and passed against that isolated test service.

## Known Stubs

None.

## Self-Check: PASSED

All six changed implementation/test/validation files exist, all six task commits are present, and every required verification command passed in this execution.
