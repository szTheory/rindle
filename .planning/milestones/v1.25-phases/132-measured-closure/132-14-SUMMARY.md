---
phase: 132-measured-closure
plan: 14
subsystem: CI timing receipt controller
tags: [ci, provenance, fail-closed, tdd]
dependency_graph:
  requires: [132-12, 132-13]
  provides: [three-stage transition-manifest validation]
  affects: [132-15 preservation census, 132-16 timing acceptance]
tech_stack:
  added: []
  patterns: [marker-bounded JSON, Git-reproduced deltas, mutation-free preflight]
key_files:
  created: []
  modified:
    - scripts/ci/collect_pr_timing_receipt.sh
    - test/install_smoke/ci_timing_automation_test.exs
decisions:
  - "Transition manifests are schema-v2, marker-bounded, and independently reproduced from Git before any mutable controller path."
  - "The post-subject executable allowlist is removed; only planning changes may follow the preserved subject."
metrics:
  duration: "~20 minutes"
  completed_date: "2026-08-27"
status: complete
---

# Phase 132 Plan 14: Transition Manifest Controller Repair Summary

The CI timing controller now requires and validates a cryptographically reproducible three-stage preservation manifest before publication, state ownership, or receipt mutation.

## Tasks Completed

1. RED: added a process regression proving `preflight` rejects a missing transition manifest before durable controller surfaces can change.
2. GREEN: implemented schema-v2 validation, exact Git-delta and blob checks, strict-ancestor no-publish readiness, and process fixtures covering valid and tampered manifests.

## Verification

- `mix format --check-formatted test/install_smoke/ci_timing_automation_test.exs` — passed
- `mix test test/install_smoke/ci_timing_automation_test.exs --seed 0` — passed (18 tests)
- `bash -n scripts/ci/collect_pr_timing_receipt.sh` — passed
- `./scripts/maintainer/automation_first_contract.sh` — passed
- `git diff --check` — passed

## Decisions Made

- A manifest has exactly three named, contiguous stages: Plan 132-12 controller, Plan 132-13 formatter, and the distinct Plan 132-14 repair.
- Each declared path/status multiset and each non-planning target blob must equal the Git tree delta at the stage boundary.
- Publication-ready strict-ancestor `--no-publish` preflight is read-only; any non-fast-forward topology is rejected.

## Deviations from Plan

None - plan executed exactly as written.

## Requirement Status

CI-14, COV-05, and SAFE-02 remain open pending the post-repair preservation and terminal live-evidence plans.

## Self-Check: PASSED

- Both task commits exist: `07c2d52`, `4b6cd03`.
- The controller and process-regression files exist and the focused verification suite passes.
