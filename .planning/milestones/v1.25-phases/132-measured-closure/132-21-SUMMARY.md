---
phase: 132
plan: 21
subsystem: CI timing evidence
tags: [github-actions, ci, timing, verification]
requires: [132-20]
provides: [CI-14 exact-ten terminal receipt]
affects: [CI-14, COV-05, SAFE-02]
tech-stack: [GitHub Actions API, gh, jq, Bash]
key-files:
  created: [.planning/phases/132-measured-closure/132-21-SUMMARY.md]
  modified: [.planning/phases/132-measured-closure/132-CI-TIMING-RECEIPT.md]
decisions:
  - "CI-14 closes from the immutable exact-ten API-backed receipt only."
metrics:
  duration: 2h 38m
  completed: 2026-08-27
status: complete
---

# Phase 132 Plan 21: Fresh Terminal Timing Acceptance Summary

The repaired controller collected and independently revalidated ten sequential successful PR runs on immutable head `869ca9cd7450dd6785aefa1fdb4bba457ce336f0`, passing CI-14 at a 453-second median and 481-second p95.

## Results

- Controller terminal status: `0` / `PASS`; completed state was schema-v2, sequence `2/2`, with the first sequence honestly retained as nonqualifying after run `33108069978`.
- Explicit API verifier status: `0`; completed-state `run --no-publish` status: `0`.
- Exact-ten selected runs: `33108596297`, `33109213864`, `33109785773`, `33110400721`, `33111089118`, `33111678168`, `33112319591`, `33112983558`, `33113664858`, `33114333757`.
- Sorted durations: `404, 418, 436, 446, 453, 453, 473, 479, 479, 481` seconds; median `(453 + 453) / 2 = 453`; nearest-rank p95 `481`.
- API-backed verification and completed-state re-entry preserved the PR head, labels, exact-head run IDs, receipt hash/markers, and state hash. The owned label, lock, PID file, and controller process were absent afterward.

## Verification

- `mix format --check-formatted`
- `mix test test/install_smoke/ci_timing_automation_test.exs --seed 0`
- `mix test test/install_smoke/ci_lane_split_test.exs test/install_smoke/ci_observability_test.exs --seed 0`
- `bash scripts/ci/test_ci_summary_gate.sh`
- `./scripts/maintainer/automation_first_contract.sh`
- Explicit `verify` and completed-state `run --no-publish` both passed against the live receipt.
- Post-subject diff remained planning-only and `git diff --check` passed.

## Deviations from Plan

None - plan executed exactly as written. The first sequence's nonqualifying run was handled by the controller's authorized single complete-sequence restart and retained in durable state.

## Self-Check: PASSED

- Receipt exists and contains exactly one current table/source marker pair.
- Evidence commit `07c2afa` exists.
