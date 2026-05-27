---
phase: 75-merge-blocking-proof-lanes
plan: 01
subsystem: infra
tags: [github-actions, ci, elixir, postgres]

requires: []
provides:
  - Merge-blocking proof CI job with docs parity and batch owner erasure tests
affects: [75-02, 75-03, 75-04, 75-05]

tech-stack:
  added: []
  patterns: ["Dedicated proof lane with Postgres-only deps"]

key-files:
  created: []
  modified: [.github/workflows/ci.yml]

key-decisions:
  - "Proof job uses Elixir 1.17/OTP 27 single matrix like contract/adopter (D-02)"

patterns-established:
  - "Proof lane: merge-blocking docs parity + operator proof tests without MinIO/FFmpeg"

requirements-completed: [CI-03]

duration: 5min
completed: 2026-05-27
---

# Phase 75 Plan 01 Summary

**Merge-blocking `proof` CI job runs docs_parity_test and batch_owner_erasure_task_test with Postgres only**

## Performance

- **Duration:** 5 min
- **Started:** 2026-05-27T20:05:00Z
- **Completed:** 2026-05-27T20:10:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Added dedicated `proof` job to ci.yml after contract, before package-consumer
- Configured Postgres service, Elixir 1.17/OTP 27, blocking test steps (no continue-on-error)
- Excluded MinIO/libvips/FFmpeg from proof job per D-02

## Task Commits

1. **Task 1: Add proof job to ci.yml** - `f5cbc15` (feat)

## Files Created/Modified
- `.github/workflows/ci.yml` - New merge-blocking Proof job with two test steps

## Decisions Made
None - followed plan as specified

## Deviations from Plan

None - plan executed exactly as written

## Issues Encountered
None

## Next Phase Readiness
- Proof job in place; 75-02 can remove redundant adopter doc grep
- 75-03 can document proof lane in RUNNING.md

## Self-Check: PASSED

---
*Phase: 75-merge-blocking-proof-lanes*
*Completed: 2026-05-27*
