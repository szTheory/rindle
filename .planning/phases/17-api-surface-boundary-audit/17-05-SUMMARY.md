---
phase: 17-api-surface-boundary-audit
plan: 05
subsystem: api
tags: [api-boundary, exdoc, operations, oban]
requires:
  - phase: 17-api-surface-boundary-audit
    provides: boundary harness coverage and prior hidden-module decisions from plans 17-01 through 17-03
provides:
  - hidden `Rindle.Ops.*` modules in compiled docs
  - hidden internal pipeline worker modules in compiled docs
  - public operations docs rewritten around Mix tasks and adopter-scheduled maintenance workers
affects: [phase-17, exdoc-visibility, operations-docs, background-processing]
tech-stack:
  added: []
  patterns: [hide implementation modules with `@moduledoc false`, keep operational docs centered on Mix tasks and public maintenance workers]
key-files:
  created: []
  modified:
    - lib/rindle/ops/metadata_backfill.ex
    - lib/rindle/ops/upload_maintenance.ex
    - lib/rindle/ops/variant_maintenance.ex
    - lib/rindle/workers/promote_asset.ex
    - lib/rindle/workers/process_variant.ex
    - lib/rindle/workers/purge_storage.ex
    - guides/operations.md
    - guides/background_processing.md
key-decisions:
  - "Treat `Rindle.Ops.*` and the promote/process/purge workers as hidden implementation modules, while keeping Mix tasks and the two maintenance workers as the public operator contract."
  - "Rewrite public docs to describe internal queues and services generically instead of cross-linking adopters to hidden modules."
patterns-established:
  - "When hidden modules are still named in public docs, remove the cross-links and restate the behavior through supported entrypoints rather than re-exposing internals."
requirements-completed: [API-04]
duration: 4min
completed: 2026-04-30
---

# Phase 17 Plan 05: API Surface Boundary Audit Summary

**Internal ops services and pipeline workers are now hidden from ExDoc, while the public operational story remains on Mix tasks, `CleanupOrphans`, and `AbortIncompleteUploads`.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-30T19:12:10Z
- **Completed:** 2026-04-30T19:15:49Z
- **Tasks:** 2
- **Files modified:** 13

## Accomplishments

- Added `@moduledoc false` to all remaining `Rindle.Ops.*` modules covered by D-06.
- Added `@moduledoc false` to the internal `PromoteAsset`, `ProcessVariant`, and `PurgeStorage` workers covered by D-05.
- Removed public doc links to hidden ops/services so `mix docs --warnings-as-errors` proves the supported operator surface cleanly.

## Task Commits

1. **Task 1: Hide the internal ops modules without changing Mix task behavior** - `3c7254c` (`fix`)
2. **Task 2: Hide the internal pipeline workers while preserving the public maintenance workers** - `2358d67` (`fix`)

## Files Created/Modified

- `lib/rindle/ops/metadata_backfill.ex`, `lib/rindle/ops/upload_maintenance.ex`, `lib/rindle/ops/variant_maintenance.ex` - Hidden internal ops modules from generated docs.
- `lib/rindle/workers/promote_asset.ex`, `lib/rindle/workers/process_variant.ex`, `lib/rindle/workers/purge_storage.ex` - Hidden internal pipeline workers from generated docs.
- `guides/operations.md`, `guides/background_processing.md`, `guides/core_concepts.md`, `guides/getting_started.md`, `guides/profiles.md`, `guides/troubleshooting.md` - Reframed public docs around supported entrypoints instead of hidden internals.
- `lib/mix/tasks/rindle.backfill_metadata.ex`, `lib/mix/tasks/rindle.cleanup_orphans.ex`, `lib/rindle/workers/abort_incomplete_uploads.ex`, `lib/rindle/workers/cleanup_orphans.ex` - Removed hidden-module doc references from public module docs.

## Decisions Made

- Kept the public operational contract on Mix tasks plus the two adopter-scheduled maintenance workers, not on `Rindle.Ops.*` services or internal pipeline queue modules.
- Treated public doc references to newly hidden modules as part of the same boundary fix, because leaving those links in place broke the docs build and still advertised unsupported internals.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Swapped invalid Mix `-x` verification for supported commands and narrower boundary checks**
- **Found during:** Task 1 and Task 2 verification
- **Issue:** Mix 1.19.5 rejects the plan's `mix test ... -x` flag, and `test/rindle/api_surface_boundary_test.exs` still includes unrelated 17-04 facade assertions that fail independently of this plan.
- **Fix:** Verified this plan with `mix test ... --trace` to confirm the remaining failures were only 17-04-related, then added focused `Code.fetch_docs/1` checks for the Task 1 ops boundary and Task 2 worker boundary.
- **Files modified:** None
- **Verification:** `MIX_ENV=test mix test test/rindle/api_surface_boundary_test.exs --trace`; targeted `mix run -e` compiled-doc checks for ops modules and worker visibility splits
- **Committed in:** Not applicable (verification-only deviation)

**2. [Rule 1 - Bug] Removed public references to hidden modules so docs generation stayed green**
- **Found during:** Task 2 verification
- **Issue:** `mix docs --warnings-as-errors` failed because guides and public module docs still linked to the hidden ops modules and hidden pipeline workers.
- **Fix:** Rewrote those docs to point adopters at Mix tasks and the two public maintenance workers, while describing internal queues/services generically.
- **Files modified:** guides/operations.md, guides/background_processing.md, guides/core_concepts.md, guides/getting_started.md, guides/profiles.md, guides/troubleshooting.md, lib/mix/tasks/rindle.backfill_metadata.ex, lib/mix/tasks/rindle.cleanup_orphans.ex, lib/rindle/workers/abort_incomplete_uploads.ex, lib/rindle/workers/cleanup_orphans.ex
- **Verification:** `mix docs --warnings-as-errors`
- **Committed in:** `2358d67`

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug)
**Impact on plan:** No scope change. Both deviations were required to verify the intended hidden/public boundary on the current branch state.

## Issues Encountered

- `test/rindle/api_surface_boundary_test.exs` still fails the unfinished 17-04 facade assertions for `Rindle.verify_completion/2` and the hidden `verify_upload/2` shim; those failures are outside this plan and remained unchanged.
- Focused test runs continued to emit Postgres `too_many_connections` startup noise from Oban/Postgrex, but the target boundary assertions still executed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- ExDoc now omits `Rindle.Ops.*` and the internal promote/process/purge workers while keeping the supported maintenance workers public.
- Phase 17 can continue with 17-04 facade naming/shim work, and the docs build is already aligned with the hidden/internal operational boundary.

## Self-Check: PASSED

- Found `.planning/phases/17-api-surface-boundary-audit/17-05-SUMMARY.md`
- Found commit `3c7254c`
- Found commit `2358d67`

---
*Phase: 17-api-surface-boundary-audit*
*Completed: 2026-04-30*
