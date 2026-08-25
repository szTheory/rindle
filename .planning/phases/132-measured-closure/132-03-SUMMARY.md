---
phase: 132-measured-closure
plan: 03
subsystem: ci-automation
tags: [github-actions, bash, exunit, evidence, devops]
requires:
  - phase: 132-02
    provides: Preserved narrow generator correction and original authority receipt.
provides:
  - Unattended fast-forward-only ten-run PR timing controller with bounded restart.
  - Executable zero-human verification/UAT policy for active phases.
affects: [132-04-preservation, 132-05-live-timing, repository-hygiene]
key-files:
  created:
    - scripts/ci/collect_pr_timing_receipt.sh
    - scripts/maintainer/automation_first_contract.sh
    - test/install_smoke/ci_timing_automation_test.exs
    - test/install_smoke/automation_first_contract_test.exs
  modified:
    - scripts/maintainer/repo_hygiene_check.sh
key-decisions:
  - "Use the maintainer's authenticated local gh session because GITHUB_TOKEN label mutations do not recursively trigger pull_request:labeled workflows."
  - "Allow one complete automatic restart, cap runner expenditure at twenty runs, and never claim external-runner exceptions."
  - "Human checkpoints may authorize credentials or irreversible actions but may not satisfy acceptance."
requirements-completed: [SAFE-02]
metrics:
  tests: 6
  completed: 2026-08-25
status: complete
---

# Phase 132 Plan 03: Automation-First Closure Summary

The former manual timing checkpoint is now an autonomous, resumable controller. It publishes only
fast-forward updates, owns and cleans its sampling label, discovers exactly one new same-head PR run,
waits for successful `CI Summary`, enforces non-overlap, restarts the full sequence once, and renders
an atomic machine-verifiable receipt.

The forward policy is executable through repository hygiene and rejects active manual-only
verification/UAT. Fixture-driven ExUnit tests cover success, bounded restart, cleanup, receipt parity,
partial evidence, and policy failures without consuming live runners.

## Commits

| Commit | Description |
| --- | --- |
| `87c1760` | Automate live timing acceptance and the forward planning contract. |

## Deviations

None. The implementation uses no new dependency, secret, workflow, public API, or required-check
topology change.

## Self-Check: PASSED

- `mix test test/install_smoke/automation_first_contract_test.exs test/install_smoke/ci_timing_automation_test.exs --seed 0` — 6 tests, 0 failures.
- `./scripts/maintainer/repo_hygiene_check.sh --ci` — 9 PASS, 0 WARN, 0 BLOCK.
