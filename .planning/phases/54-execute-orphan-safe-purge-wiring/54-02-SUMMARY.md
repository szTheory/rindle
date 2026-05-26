---
phase: 54-execute-orphan-safe-purge-wiring
plan: 02
subsystem: api
tags: [purge-worker, oban, attachments, storage-safety, lifecycle]

# Dependency graph
requires:
  - phase: 53
    provides: retained-shared-asset rule and maintenance-vs-owner-erasure truth boundaries
provides:
  - survivor-aware purge worker behavior at the destructive boundary
  - worker regression coverage for delete-vs-skip behavior
  - slot-scoped attach/detach regression proving shared assets survive stale purge jobs
affects: [55 proof-and-adopter-guidance, attach-detach semantics, shared-asset retention]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - destructive worker re-checks live attachment truth immediately before delete
    - existing enqueue semantics remain unchanged while safety moves to the worker boundary

key-files:
  created: []
  modified:
    - lib/rindle/workers/purge_storage.ex
    - test/rindle/workers/purge_storage_test.exs
    - test/rindle/attach_detach_test.exs

key-decisions:
  - "Kept the existing purge job args shape and strengthened safety only at worker time."
  - "Used a live `MediaAttachment` existence check as the final guardrail before deleting bytes or the asset row."

patterns-established:
  - "Shared-asset safety belongs at the final destructive boundary even when earlier code classified an asset as orphaned."
  - "Existing public enqueue semantics can stay stable while worker-time idempotency absorbs stale jobs."

requirements-completed: [LIFE-03]

# Metrics
duration: 35min
completed: 2026-05-26
---

# Phase 54 Plan 02 Summary

**The purge worker now skips destructive deletes whenever any attachment survives, while existing attach/detach APIs keep their enqueue contract unchanged.**

## Performance

- **Duration:** 35 min
- **Started:** 2026-05-26T13:03:00Z
- **Completed:** 2026-05-26T13:38:34Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- Hardened `Rindle.Workers.PurgeStorage` with a live `MediaAttachment` re-check before deleting variants, source bytes, or the asset row.
- Added worker regression coverage for the orphaned delete path and the surviving-attachment skip path.
- Added attach/detach regression coverage proving shared assets survive when a stale purge job runs after one owner's detach.

## Task Commits

No task commits were created. The repository already contained unrelated local modifications, so the workflow's atomic commit protocol was intentionally skipped to avoid bundling user work into phase commits.

## Files Created/Modified

- `lib/rindle/workers/purge_storage.ex` - Live attachment existence check plus preserved orphan-only delete flow.
- `test/rindle/workers/purge_storage_test.exs` - Regression coverage for destructive purge and survivor-safe no-op behavior.
- `test/rindle/attach_detach_test.exs` - Shared-asset regression proving slot-scoped public APIs stay safe under the hardened worker boundary.

## Decisions Made

- Kept `PurgeStorage`'s `%{"asset_id" => asset_id, "profile" => profile}` args unchanged to avoid widening the worker surface.
- Left `attach/4` and `detach/3` enqueue behavior intact; the new safety rule is enforced only where bytes and asset rows are actually deleted.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Shared assets are now protected even if stale purge work executes after ownership changes, so Phase 55 can focus on proof and adopter guidance instead of repairing the destructive boundary.

---
*Phase: 54-execute-orphan-safe-purge-wiring*
*Completed: 2026-05-26*
