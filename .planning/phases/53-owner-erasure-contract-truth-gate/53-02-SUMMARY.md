---
phase: 53-owner-erasure-contract-truth-gate
plan: 02
subsystem: docs
tags: [guides, parity-test, support-truth, owner-erasure, lifecycle]

# Dependency graph
requires:
  - phase: 53
    provides: owner-erasure contract decisions and support-truth requirements
provides:
  - user-flow guide wording aligned to the owner-erasure facade
  - docs-parity test that prevents drift back to the detach-loop workaround story
affects: [55 adopter proof/docs]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - high-visibility guide notes mirror locked requirement language
    - install-smoke parity tests assert both required wording and removal of stale workaround guidance

key-files:
  created: []
  modified:
    - guides/user_flows.md
    - test/install_smoke/docs_parity_test.exs

key-decisions:
  - "Replace the old detach-loop account deletion recommendation with the standardized `preview_owner_erasure/2` / `erase_owner/2` story."
  - "Normalize quoted Markdown lines in parity tests so support-truth assertions survive formatting wraps."

patterns-established:
  - "User-flow guides can describe future supported surfaces honestly while stating that executable support lands in a later phase."
  - "Parity tests should guard against stale workaround text, not just assert new text exists."

requirements-completed: [TRUTH-02]

# Metrics
duration: 29min
completed: 2026-05-26
---

# Phase 53 Plan 02 Summary

**The main user-flow guide now points adopters at the standardized owner-erasure facade and CI fails if that guide drifts back to the old detach-plus-cleanup workaround.**

## Performance

- **Duration:** 29 min
- **Started:** 2026-05-26T12:20:00Z
- **Completed:** 2026-05-26T12:48:52Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Rewrote the Story 5 account-deletion note in `guides/user_flows.md` to name `Rindle.preview_owner_erasure/2` and `Rindle.erase_owner/2`, retain shared assets when another attachment survives, and keep `cleanup_orphans` maintenance-only.
- Kept the guide honest that the executable facade lands in later `v1.10` work and that admin UI, bulk orchestration, and force-delete semantics remain deferred.
- Added a focused install-smoke parity test that locks the new wording and rejects the previous workaround-first note.

## Task Commits

No task commits were created. The repository was already dirty with unrelated local changes, so the workflow's atomic commit protocol was skipped rather than risk bundling unrelated work.

## Files Created/Modified

- `guides/user_flows.md` - Replaced the account-deletion workaround note with the standardized owner-erasure support-truth note.
- `test/install_smoke/docs_parity_test.exs` - Added `user_flows.md` loading and parity assertions for required owner-erasure wording plus forbidden stale guidance.

## Decisions Made

- Preserved support truth by describing the facade as the `v1.10` standard while explicitly saying the executable lane lands later.
- Normalized quoted Markdown lines in the parity test instead of forcing awkward guide formatting just to satisfy literal-string matching.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Normalized quoted guide lines before parity assertions**
- **Found during:** Task 2 verification
- **Issue:** The new note is in a Markdown blockquote, so literal phrase assertions for wrapped lines like `bulk orchestration` failed even though the guide text was correct.
- **Fix:** Normalized `\n> ` sequences to spaces before lowercased parity assertions.
- **Files modified:** `test/install_smoke/docs_parity_test.exs`
- **Verification:** `mix test test/install_smoke/docs_parity_test.exs`
- **Committed in:** not committed

---

**Total deviations:** 1 auto-fixed (Rule 1 bug)
**Impact on plan:** Verification-only fix. The published wording stayed aligned with the plan.

## Issues Encountered

- None beyond the parity-test normalization fix.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 55 can build adopter-facing proof and guidance on top of a user-flow guide that no longer teaches the manual workaround as the long-term path.

---
*Phase: 53-owner-erasure-contract-truth-gate*
*Completed: 2026-05-26*
