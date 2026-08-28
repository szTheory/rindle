---
phase: 132-measured-closure
plan: 05
subsystem: ci-timing
tags: [ci, automation, github-actions, evidence]
requires:
  - phase: 132-04
    provides: Preserved automation candidate and complete local preservation evidence.
provides:
  - Machine-verifiable ten-run exact-head timing receipt.
  - Automated gaps_found verdict with no human verification or UAT.
affects: [ci-14, phase-132-verification]
key-files:
  modified:
    - .planning/phases/132-measured-closure/132-CI-TIMING-RECEIPT.md
key-decisions:
  - "Keep CI-14 open because the 516.5-second median misses its inclusive 480-second target."
  - "Treat the passing 543-second p95 as partial evidence, never as a substitute for the median target."
metrics:
  qualifying_runs: 10
  median_seconds: 516.5
  p95_seconds: 543
  completed: 2026-08-25
status: gaps_found
---

# Phase 132 Plan 05: Automated CI Timing Summary

The unattended controller published and measured immutable PR head
`24c17783bbc080a085e398164450b7c3f475781e`, collected exactly ten sequential successful
first-attempt `pull_request` runs, removed its owned label, rendered the receipt, and independently
verified the receipt's table, source manifest, run identity, chronology, and arithmetic.

## Result

| Metric | Target | Observed | Verdict |
| --- | ---: | ---: | --- |
| Median | <=480s | 516.5s | FAIL (+36.5s) |
| Nearest-rank p95 | <=600s | 543s | PASS (-57s) |
| Sample integrity | 10 exact-head first attempts | 10 | PASS |

Plan 05 is executed, but CI-14 is not complete. The controller correctly returned a failing
acceptance verdict after persisting and self-verifying the full receipt. Phase verification therefore
routes to `gaps_found`, never `human_needed`.

## Verification

- Receipt verification passed against all ten source-manifest and table rows.
- All ten selected runs completed successfully on attempt 1 with `CI Summary` as the required gate.
- PR #96 was left open at the measured immutable head with no `ci-timing-sample` label remaining.

## Self-Check: PASSED

The plan's operational and evidence goals are complete. Its performance requirement remains honestly
open for a new automated remediation slice.
