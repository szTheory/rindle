---
phase: 132-measured-closure
plan: 12
subsystem: ci-evidence-controller
tags: [github-actions, timing, receipt, security, regression-tests]
requires:
  - phase: 132-11
    provides: immutable-PR timing controller baseline
provides:
  - PR-bound canonical Actions population verification
  - live completed-state receipt revalidation
  - identity and retry-boundary evidence in timing manifests
affects: [CI-14, SAFE-02]
tech-stack:
  added: []
  patterns: [fail-closed shell verification, process-level ExUnit regression]
key-files:
  created: []
  modified:
    - scripts/ci/collect_pr_timing_receipt.sh
    - test/install_smoke/ci_timing_automation_test.exs
decisions:
  - Canonical eligible runs are selected by repository, numeric PR, SHA, workflow, first attempt, success, and API PR association.
  - A completed PASS is advisory until the controller lock revalidates it against live API evidence.
metrics:
  duration: 12m
  completed: 2026-08-26
status: complete
---

# Phase 132 Plan 12: Canonical timing-evidence closure Summary

The timing receipt controller now treats the complete PR-associated exact-head Actions population as the sole evidence authority, including when a prior controller state says PASS.

## Tasks Completed

1. Added failing regressions for a shared PR-bound canonical population authority and live completed-PASS validation.
2. Implemented canonical API selection, persisted repository/PR/retry-boundary metadata, and live threshold/statistics revalidation for explicit verify and completed controller state.

## Verification

- `mix test test/install_smoke/ci_timing_automation_test.exs --seed 0` — passed (15 tests).
- `bash -n scripts/ci/collect_pr_timing_receipt.sh` — passed.
- `./scripts/maintainer/automation_first_contract.sh` — passed.

## Decisions Made

- Canonical run equality replaces the prior contiguous-slice check, so extra eligible bound-PR runs cannot be selected around.
- Retries persist their observed run IDs as a sequence boundary; a retry still requires equality with its complete post-boundary population.
- Timing threshold misses remain distinct from malformed or identity-mismatched evidence, which fails closed.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed the controller and process-level regression file exist.
- Confirmed task commits `9e70f4b` and `5a61ab9` exist in git history.
