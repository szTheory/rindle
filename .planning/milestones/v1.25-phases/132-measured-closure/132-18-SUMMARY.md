---
phase: 132-measured-closure
plan: 18
subsystem: ci-timing-evidence
tags: [github-actions, controller-resume, bounded-sampling, gaps-found]
dependency_graph:
  requires: [132-17]
  provides: [terminal-bounded-controller-record]
  affects: [CI-14]
tech_stack:
  added: []
  patterns: [durable-state-resume, API-backed-run-identity, two-sequence-ceiling]
key_files:
  created:
    - .planning/phases/132-measured-closure/132-18-SUMMARY.md
  modified: []
decisions:
  - "The authorized resume reused the existing PR-96/fc2a8c8 controller state at sequence attempt 2; no state reset, new sequence, manual label action, or rerun occurred."
  - "CI-14 remains open because the second and final sequence exhausted on a non-qualifying CI Summary failure before an exact-ten population could be produced."
metrics:
  duration: "controlled resume through terminal run 33095420536"
  completed_date: "2026-08-27"
status: complete
---

# Phase 132 Plan 18: Controlled terminal timing-resume Summary

The authorized resume preserved the durable controller identity and completed its only remaining bounded path; sequence 2 terminalized without an exact-ten receipt, so CI-14 truthfully remains open.

## Tasks Completed

1. Waited for inherited run `33092059748` to succeed, confirmed PID `12430` was absent and no controller owned the state, then resumed the same state exactly once.
2. The controller retained `sequence_attempt: 2`, accepted runs `33092059748` and `33094820008`, and terminalized when `33095420536` failed.

## Verification

- GitHub API confirmed all recorded controller runs were PR #96-associated, exact-head, first-attempt runs.
- The terminal run `33095420536` failed `Quality (1.17, 27, true)`, therefore its `CI Summary` failed.
- Durable state is `failed` at sequence attempt 2 with the prescribed error; no current receipt markers were written.
- PR #96 remains at `fc2a8c85141d39883749bdfb4278e7215f7f3db7`, and `ci-timing-sample` is absent.
- No `collect_pr_timing_receipt.sh` controller process remains active.

## CI-14 Result

`gaps_found` — a complete canonical exact-ten population was not produced within the two authorized sequences. No median/p95 verdict exists, and CI-14 is not closed.

## Deviations from Plan

### Authorized continuation

**1. [Rule 3 - Blocking external outcome] Resumed the persisted controller after its inherited in-progress sample completed**
- **Found during:** Task 1
- **Issue:** The prior executor had terminated while a durable controller state still owned sample 4.
- **Fix:** Waited for terminal status, reconfirmed process/identity guards, and ran the exact planned command against the same state once.
- **Files modified:** None beyond this execution summary.
- **Verification:** State retained sequence 2 and finished with the documented second-sequence failure.

## Known Stubs

None.

## Threat Flags

None — the controller preserved its existing repository, PR, SHA, label, lock, and sequence boundaries.

## Self-Check: PASSED

- Confirmed terminal failed state and absence of a controller lock/process.
- Confirmed API identity for the final failed run and PR head/label cleanup.
