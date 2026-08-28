---
phase: 132-measured-closure
plan: 06
subsystem: ci-apt-installation
tags: [ci, apt, timing, tdd, safety]
requires:
  - phase: 132-05
    provides: Failed immutable-head ten-run timing receipt and preservation baseline.
provides:
  - Install-first apt acquisition with one bounded refresh fallback.
  - Process-isolated executable contracts for apt command order and failure propagation.
  - Same-head causal census for the repeated libvips setup cost.
affects: [required-ci-jobs, ci-timing-receipt]
tech-stack:
  added: []
  patterns: [PATH-isolated command shims, bounded shell fallback, Actions API timing census]
key-files:
  created: []
  modified:
    - scripts/ci/install_apt_packages.sh
    - test/install_smoke/ci_cache_hygiene_test.exs
    - .planning/phases/132-measured-closure/132-CI-TIMING-RECEIPT.md
decisions:
  - Preserve the two-attempt timeout/retry policy while moving apt-get update into the failed-first-install recovery path.
  - Use the existing ten exact-head Actions runs to identify the repeated 25-second libvips setup cost without altering receipt arithmetic.
metrics:
  duration: 15 minutes
  completed: 2026-08-26
  tasks_completed: 1
  files_modified: 3
status: complete
---

# Phase 132 Plan 06: Bounded Install-First Apt Acquisition Summary

The required CI package installer now uses cached apt indexes first and refreshes only after that bounded install fails, with executable command-order and terminal-failure contracts plus same-head causal timing evidence.

## Tasks Completed

| Task | Description | Commit |
| --- | --- | --- |
| 1 | Prove and apply bounded install-first apt acquisition on the required path | `4b8cc9e`, `9e15780` |

## Implementation

- Retained the persisted apt network configuration, `--configure-only` interface, quoted package forwarding, 240-second command timeout, five-second retry delay, two install attempts, and loud terminal failure.
- Changed the first attempt to install directly from runner indexes; only a failed first install triggers one bounded `apt-get update` before the final install attempt.
- Added PATH-isolated `sudo`, `timeout`, `apt-get`, and `sleep` shims that exercise the real helper without touching host apt state.
- Appended a read-only causal census from the ten recorded exact-head Actions job payloads: `Adopter` was the last workload finisher in 6 runs, `Adoption Demo E2E Smoke` in 4, and `Install libvips` measured 25 seconds median across 80 successful samples.

## Verification

- `mix test test/install_smoke/ci_cache_hygiene_test.exs test/install_smoke/ci_lane_split_test.exs test/install_smoke/ci_observability_test.exs --seed 0` — 49 tests passed.
- `bash -n scripts/ci/install_apt_packages.sh` — passed.
- `bash scripts/ci/test_ci_summary_gate.sh` — 6 checks passed.
- `./scripts/maintainer/automation_first_contract.sh` — passed.
- Name-only diff review confirmed only the three plan-declared files changed for the task.

## TDD Gate Compliance

- RED: `4b8cc9e` added process-level order assertions that failed against the unconditional-refresh helper.
- GREEN: `9e15780` implemented the bounded install-first fallback and made the focused suite pass.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed all three declared task artifacts exist.
- Confirmed commits `4b8cc9e` and `9e15780` exist in git history.
