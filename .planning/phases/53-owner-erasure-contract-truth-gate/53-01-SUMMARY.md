---
phase: 53-owner-erasure-contract-truth-gate
plan: 01
subsystem: api
tags: [docs, types, public-api, owner-erasure, lifecycle]

# Dependency graph
requires:
  - phase: 53
    provides: owner-erasure contract decisions and truth boundaries from CONTEXT.md/RESEARCH.md
provides:
  - public facade owner-erasure contract wording in `Rindle` moduledoc
  - stable `owner_erasure_report` type vocabulary for downstream implementation
  - boundary test that freezes owner-erasure contract strings in compiled docs
affects: [54 execute wiring, 55 proof/docs alignment]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - public contract freezes in facade docs before runtime export exists
    - docs-boundary tests use `Code.fetch_docs/1` to lock exact contract wording

key-files:
  created: []
  modified:
    - lib/rindle.ex
    - test/rindle/api_surface_boundary_test.exs

key-decisions:
  - "Document `Rindle.preview_owner_erasure/2` and `Rindle.erase_owner/2` as the recommended v1.10 facade without exporting either function yet."
  - "Freeze report vocabulary as `attachments_to_detach`, `assets_to_purge`, and `retained_shared_assets` via a public type and moduledoc assertions."

patterns-established:
  - "Facade moduledoc carries future-contract truth and explicit deferred non-goals."
  - "Compiled-doc boundary tests normalize docs whitespace but still assert exact contract markers."

requirements-completed: [LIFE-01]

# Metrics
duration: 29min
completed: 2026-05-26
---

# Phase 53 Plan 01 Summary

**The `Rindle` facade now publishes the owner-erasure contract, report buckets, and deferred-scope truth without exposing a premature destructive entrypoint.**

## Performance

- **Duration:** 29 min
- **Started:** 2026-05-26T12:20:00Z
- **Completed:** 2026-05-26T12:48:52Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Added an owner/account erasure section to the `Rindle` moduledoc naming `Rindle.preview_owner_erasure/2` and `Rindle.erase_owner/2` as the recommended `v1.10` surface while keeping `detach/3` slot-scoped and `cleanup_orphans` maintenance-only.
- Introduced public `owner_erasure_bucket()` and `owner_erasure_report()` types with the exact buckets `attachments_to_detach`, `assets_to_purge`, and `retained_shared_assets`, plus honest `purge_enqueued` semantics.
- Extended the API boundary test suite to assert the frozen owner-erasure contract markers in compiled docs, including deferred non-goals.

## Task Commits

No task commits were created. The repository already contained unrelated local modifications, including pre-existing edits in `lib/rindle.ex`, so the workflow's atomic commit protocol was intentionally skipped to avoid bundling user work into phase commits.

## Files Created/Modified

- `lib/rindle.ex` - Added owner-erasure facade contract prose and the typed report vocabulary without adding callable owner-erasure functions.
- `test/rindle/api_surface_boundary_test.exs` - Added a moduledoc-boundary test plus helpers for localized moduledoc extraction and whitespace-normalized assertions.

## Decisions Made

- Kept the owner-erasure API contract entirely in docs/types for Phase 53 rather than exporting placeholders, matching the plan's "no runtime entrypoint yet" rule.
- Put the exact bucket names in both the public type and moduledoc so later implementation and docs work inherit one contract source of truth.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Adjusted docs-boundary helpers for localized Elixir docs output**
- **Found during:** Task 2 verification
- **Issue:** `Code.fetch_docs/1` returned moduledocs as a localized `%{"en" => doc}` map rather than a plain string, causing the new boundary assertion to fail.
- **Fix:** Added a helper branch for localized moduledocs and normalized whitespace before string assertions.
- **Files modified:** `test/rindle/api_surface_boundary_test.exs`
- **Verification:** `mix test test/rindle/api_surface_boundary_test.exs`
- **Committed in:** not committed

---

**Total deviations:** 1 auto-fixed (Rule 1 bug)
**Impact on plan:** Verification-only fix. No scope change and no contract drift.

## Issues Encountered

- Existing unrelated edits were already present in the working tree, including a separate tus upload addition in `lib/rindle.ex`. Changes were applied around those hunks and left uncommitted.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 54 can implement the execute lane against a frozen public vocabulary and deferred-scope boundary.

---
*Phase: 53-owner-erasure-contract-truth-gate*
*Completed: 2026-05-26*
