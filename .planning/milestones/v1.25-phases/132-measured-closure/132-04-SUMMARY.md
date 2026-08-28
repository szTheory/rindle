---
phase: 132-measured-closure
plan: 04
subsystem: preservation
tags: [ci, coverage, package-consumer, automation, evidence]
requires:
  - phase: 132-03
    provides: Unattended timing controller and automation-first acceptance policy.
provides:
  - Immutable preserved automation candidate SHA for live CI timing.
  - Fresh complete preservation census with exact coverage arithmetic.
  - Deterministic non-interactive Phoenix generation and observable smoke failures.
affects: [132-05-live-timing]
key-files:
  modified:
    - scripts/ci/collect_pr_timing_receipt.sh
    - test/install_smoke/support/generated_app/workspace.ex
    - test/install_smoke/support/generated_app_helper.ex
    - .planning/phases/132-measured-closure/132-PRESERVATION-RECEIPT.md
key-decisions:
  - "Bind Plan 05 to 5001e2a05f378c4fb3b0db9abefc316f8652d3c2 and reject every later non-planning delta."
  - "Use Phoenix --no-install so dependency installation remains explicitly post-patch without an interactive prompt."
  - "Raise at the generated smoke command boundary so command output survives failures."
requirements-completed: [COV-05, SAFE-02]
metrics:
  focused_tests: 40
  coverage_tests: 1393
  package_consumer_tests: 22
  coverage_percent: 82.1343
  completed: 2026-08-25
status: complete
---

# Phase 132 Plan 04: Final Preservation Re-census Summary

The final automation candidate is preserved at
`5001e2a05f378c4fb3b0db9abefc316f8652d3c2`. Every local authority passed after
the final source edit, including CI topology, the summary gate, quality and SAFE-01,
the automation-first policy, repository hygiene, authoritative coverage, and the
full packed image consumer.

The census and first fail-closed live attempt found and fixed unattended-execution hazards: resuming a
discovered CI run could otherwise retrigger it after interruption, and Phoenix 1.8.9
could wait on an install prompt when invoked through `System.cmd`. The live attempt
also exposed jq keyword incompatibility and a publication-trigger race; the controller
now waits for the synchronize run set to quiesce before sampling. A second fail-closed
attempt exposed unbounded historical API pagination; discovery is now a single
branch-filtered page with rate-limit-aware backoff. These paths have executable
regression coverage. Generated isolation smoke failures also raise at the command
boundary with captured output.

## Commit

| Commit | Description |
| --- | --- |
| `9d8e7e3` | Harden unattended preservation and preserve the final code-bearing subject. |
| `b60e3e7` | Stabilize live sampling across CI jq and publication-trigger concurrency. |
| `5001e2a` | Bound API polling and back off without consuming live samples. |

## Verification

- Generator contract: 1 test, 0 failures.
- Controller, policy, and topology: 40 tests, 0 failures.
- Summary gate: 6 scenarios passed.
- Quality/refactor contracts: 93 tests, 0 failures; no cycles; 79 Doctor modules passed.
- Coverage: 5,149 / 6,269 = 82.1343%, above the inclusive 82.13% floor.
- Packed image consumer: 22 tests, 0 failures.
- Hygiene: 9 PASS, 0 WARN, 0 BLOCK.

## Self-Check: PASSED

The preserved subject is a full SHA, all acceptance is executable, and Plan 05 may
add only planning evidence before the controller publishes and measures the head.
