---
phase: 132-measured-closure
plan: 17
subsystem: ci-preservation-evidence
tags: [git-provenance, transition-manifest, coverage, no-publish-preflight]
dependency_graph:
  requires: [132-16]
  provides: [15336d4-preservation-census, preserved-tail-attribution, mutation-free-preflight]
  affects: [132-18, CI-14, COV-05, SAFE-02]
tech_stack:
  added: []
  patterns: [Git-reproduced manifests, explicit source-tail attribution, snapshot-equality preflight]
key_files:
  created:
    - .planning/phases/132-measured-closure/132-17-SUMMARY.md
  modified:
    - .planning/phases/132-measured-closure/132-PRESERVATION-RECEIPT.md
decisions:
  - "The active schema-v2 manifest ends at 15336d4; its cumulative third stage is retained for the shipped validator while the strict 73e2c33..15336d4 tail separately attributes the source repair to Plan 132-16."
  - "COV-05 and SAFE-02 are freshly preserved from exact local authorities; CI-14 remains open and only Plan 132-18 may mutate or sample GitHub timing state."
metrics:
  duration: "~8 minutes"
  completed_date: "2026-08-27"
status: complete
---

# Phase 132 Plan 17: Post-controller-fix preservation census Summary

Fresh Git-derived evidence seals `15336d4` as the preserved source subject, separates its Plan 132-16 repair tail from Plan 132-15 planning history, and proves mutation-free terminal-sampler readiness.

## Tasks Completed

1. Re-censused the source subject, replaced the active manifest, and recorded fresh preservation and no-publish preflight authorities.

## Verification

- `mix format --check-formatted` — passed.
- Focused controller proof — passed: `18 tests, 0 failures`.
- Lane-split and observability proof — passed: `34 tests, 0 failures`.
- Summary gate, quality signals, SAFE-01, automation-first, and CI hygiene — passed.
- One `mix coveralls.multiple --type local --type json` authority — passed; structural parsing found 5,149 covered of 6,269 relevant lines (82.1343%), satisfying the inclusive 82.13% floor.
- Packed image consumer — passed.
- `git diff --check` and prohibited-surface/post-subject planning-only censuses — passed.
- `collect_pr_timing_receipt.sh preflight --no-publish` — passed with PR #96 still at `7f025df`; all observed remote/local mutable surfaces were equal before and after.

## Task Commit

1. **Task 1: Re-census and preflight source subject 15336d4** — `ae13415` (docs).

## Decisions Made

- The active manifest's third stage is the required cumulative `214e56c..15336d4` Git delta; the separately recorded strict tail prevents misattributing Plan 132-16 source work to Plan 132-15.
- COV-05 and SAFE-02 are re-closed from fresh exact authorities. CI-14 remains open for Plan 132-18 only.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None — this plan records planning evidence only and introduces no implementation trust surface.

## Next Phase Readiness

Plan 132-18 may use the preserved subject and validated no-publish preflight for its bounded terminal API-backed timing receipt. It remains the sole authority permitted to close CI-14.

## Self-Check: PASSED

- Confirmed the preservation receipt and this summary exist.
- Confirmed task commit `ae13415` exists in Git history.
- Confirmed exactly one active manifest marker pair, the `15336d4` identity, and the no-publish preflight after the final receipt update.
