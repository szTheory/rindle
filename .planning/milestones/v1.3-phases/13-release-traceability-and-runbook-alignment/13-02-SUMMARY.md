---
phase: 13-release-traceability-and-runbook-alignment
plan: "02"
subsystem: testing
tags: [elixir, hex, release, runbook, parity-test, ci]

# Dependency graph
requires:
  - phase: 12-public-verification-and-release-operations
    provides: Live publish workflow with public_verify job and release_publish.md runbook
  - phase: 13-01
    provides: Normalized release traceability metadata across phase summaries
provides:
  - Maintainer release runbook aligned with the live shipped workflow contract
  - Executable parity test locking guide language to live workflow step names and commands
affects:
  - future-release-phases
  - release-doc-maintenance

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Parity test guards guide-to-workflow contract so prose drift is caught by CI
    - Refutation tests assert absence of stale deferred-automation wording in docs

key-files:
  created: []
  modified:
    - guides/release_publish.md
    - test/install_smoke/release_docs_parity_test.exs

key-decisions:
  - "Encode the workflow contract as both positive assertions (step names and commands must appear) and refutation assertions (stale Phase 11 deferred wording must be absent) in the parity test to catch both omission and regression drift."
  - "Extend setup_all fixture to include release.yml so parity tests can cross-check the guide against the live workflow contract, not just the guide in isolation."

patterns-established:
  - "Release runbook parity: the guide must name exact CI step names and repo commands, verified by the executable parity test on every preflight run."
  - "Refutation assertions: stale deferred-automation language is explicitly prohibited by test, not just absent by convention."

requirements-completed: [RELEASE-06, RELEASE-08, RELEASE-09]

# Metrics
duration: 1min
completed: 2026-04-29
---

# Phase 13 Plan 02: Release Traceability and Runbook Alignment Summary

**Release runbook Hex Auth Check section rewritten to current-state language and parity test extended to lock guide to exact workflow step names, shipped commands, and stale-wording refutations**

## Performance

- **Duration:** 1 min
- **Started:** 2026-04-29T02:08:55Z
- **Completed:** 2026-04-29T02:10:31Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Replaced the stale "This phase does not wire live HEX_API_KEY automation / Phase 11 adds write-capable automation" paragraph in `## Hex Auth Check` with current-state language describing the live tag-triggered Release workflow and fresh-runner `public_verify` job
- Added `@release_workflow_path` fixture to `release_docs_parity_test.exs` so tests can compare the guide against the actual shipped `.github/workflows/release.yml`
- Added three new executable parity tests: step-name parity, shipped-command parity, and stale-wording refutation — bringing the test file from 4 to 7 tests, all passing

## Task Commits

Each task was committed atomically:

1. **Task 1: Remove stale deferred-automation language from release runbook** - `3288103` (docs)
2. **Task 2: Extend release-doc parity test to lock guide language to live workflow contract** - `57b0200` (test)

## Files Created/Modified
- `guides/release_publish.md` - Replaced stale Hex Auth Check paragraph with current-state language about HEX_API_KEY in the release environment and the public_verify job
- `test/install_smoke/release_docs_parity_test.exs` - Added @release_workflow_path fixture, step-name parity test, shipped-command parity test, and stale-wording refutation test

## Decisions Made
- Encode the workflow contract as both positive assertions (step names and commands must appear) and refutation assertions (stale Phase 11 deferred wording must be absent) in the parity test to catch both omission and regression drift.
- Extend setup_all fixture to include release.yml so parity tests can cross-check the guide against the live workflow contract, not just the guide in isolation.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 13 plans complete: release traceability metadata normalized (13-01) and runbook aligned with live workflow contract (13-02)
- The release-doc parity test now exercises the live workflow contract on every preflight run, preventing the drift class found in the v1.2 milestone audit from recurring silently
- Ready for milestone v1.2 closure or any subsequent phase

---
*Phase: 13-release-traceability-and-runbook-alignment*
*Completed: 2026-04-29*
