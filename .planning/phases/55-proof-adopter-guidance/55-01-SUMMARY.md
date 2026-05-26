---
phase: 55-proof-adopter-guidance
plan: 01
subsystem: testing
tags: [owner-erasure, adopter-proof, oban, minio]
requires:
  - phase: 54-execute-orphan-safe-purge-wiring
    provides: public preview/execute owner-erasure facade plus orphan-safe purge semantics
provides:
  - Hermetic owner-erasure lifecycle proof through the real purge worker boundary
  - Canonical adopter proof for preview_owner_erasure/2 and erase_owner/2
  - Boundary checks that freeze the public owner-erasure facade wording
affects: [guides, docs-parity, verify-work]
tech-stack:
  added: []
  patterns: [public-facade lifecycle proof, shared-vs-orphan asset assertions]
key-files:
  created: [test/rindle/owner_erasure_test.exs]
  modified: [test/adopter/canonical_app/lifecycle_test.exs, test/rindle/api_surface_boundary_test.exs]
key-decisions:
  - "Extended the existing hermetic proof seam instead of creating a new owner-erasure harness."
  - "Used the canonical adopter repo lane to prove preview/execute semantics directly through the public facade."
patterns-established:
  - "Owner-erasure proof must distinguish detach-time reporting from worker-time purge deletion."
  - "Adopter guidance proof should call preview_owner_erasure/2 and erase_owner/2, not detach loops."
requirements-completed: [PROOF-03, PROOF-04]
duration: 6min
completed: 2026-05-26
---

# Phase 55 Plan 01 Summary

**Hermetic and adopter-shaped proof now close the owner-erasure lifecycle from preview/execute reporting through orphan purge and retained shared-asset survival**

## Performance

- **Duration:** 6 min
- **Started:** 2026-05-26T14:18:03Z
- **Completed:** 2026-05-26T14:24:02Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- Added a merge-blocking hermetic proof that runs `PurgeStorage` after `Rindle.erase_owner/2` and proves orphan deletion versus shared-asset retention.
- Added a canonical adopter test that exercises `Rindle.preview_owner_erasure/2` and `Rindle.erase_owner/2` as the supported account-deletion flow.
- Kept the public-boundary layer aligned with the owner-erasure facade exports and wording.

## Task Commits

Each task was packaged in the plan commit:

1. **Task 1: Extend hermetic owner-erasure proof to cover worker-time purge versus retained shared assets** - `57d3b84` (test)
2. **Task 2: Add canonical adopter proof for the public owner-erasure flow** - `57d3b84` (test)
3. **Task 3: Keep public-boundary proof aligned with the owner-erasure contract wording** - `57d3b84` (test)

**Plan metadata:** `57d3b84` (test: close owner erasure proof lanes)

## Files Created/Modified
- `test/rindle/owner_erasure_test.exs` - Hermetic preview/execute proof including worker-time orphan purge and rerun stability.
- `test/adopter/canonical_app/lifecycle_test.exs` - Canonical adopter owner-erasure chapter using the public facade.
- `test/rindle/api_surface_boundary_test.exs` - Boundary freeze for facade exports and owner-erasure contract wording.

## Decisions Made
- Reused the existing owner-erasure and adopter proof seams rather than adding a bespoke harness.
- Let the adopter proof set up DB state directly, but still exercised only the public owner-erasure API for the destructive flow.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Local MinIO was not running, so the existing adopter lifecycle file failed before reaching the new owner-erasure assertions. Resolved by starting the expected local MinIO endpoint and rerunning the file.

## User Setup Required

None - no external service configuration required beyond the existing local MinIO test lane.

## Next Phase Readiness

Wave 2 can treat the owner-erasure facade as proved in both hermetic and adopter-facing lanes.
Docs parity and planning truth can now freeze the supported wording without referring to future-phase work.

