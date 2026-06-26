---
phase: 92-e2e-screenshot-driven-polish-loop
plan: "01"
subsystem: testing
tags: [playwright, liveview, admin-console, selectors, e2e]

# Dependency graph
requires:
  - phase: 89-console-read-surfaces
    provides: Mountable Rindle Admin LiveView shell and read surfaces
  - phase: 90-console-ops-actions
    provides: Actions LiveView operation panels and receipts
  - phase: 91-cohort-demo-evolution
    provides: Cohort adoption demo mounts the admin console at /admin/rindle
provides:
  - CommonJS admin Playwright helper for /admin/rindle navigation and assertions
  - Stable data-rindle-admin selectors for admin Actions browser flows
  - Stable admin detail-link selectors for assets and upload sessions
affects: [92-02, 92-03, 92-04, admin-e2e, screenshot-polish]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - CommonJS Playwright helper imports @playwright/test expect and waitForLiveSocket
    - Namespaced data-rindle-admin selectors for shipped admin package browser proof

key-files:
  created:
    - examples/adoption_demo/e2e/support/admin.js
  modified:
    - lib/rindle/admin/live/actions_live.ex
    - lib/rindle/admin/live/assets_live.ex
    - lib/rindle/admin/live/upload_sessions_live.ex
    - test/rindle/admin/live/actions_live_test.exs
    - test/rindle/admin/live/home_assets_upload_test.exs

key-decisions:
  - "Use a shared CommonJS admin helper in the existing adoption_demo Playwright harness."
  - "Expose only semantic data-rindle-admin-* selectors in shipped admin LiveView source; no data-testid selectors were added."

patterns-established:
  - "Admin Playwright specs should call visitAdmin, expectAdminShell, selectAdminTheme, firstAdminDetailHref, expectNoAdminRawSecrets, and expectNoHorizontalScroll from support/admin.js."
  - "Action flow selectors mirror LiveView event names for form and submit attributes while preserving operation semantics."

requirements-completed: [E2E-01]

# Metrics
duration: 5 min
completed: 2026-06-13
---

# Phase 92 Plan 01: Selector and Helper Foundation Summary

**Admin console Playwright helper plus semantic LiveView selectors for deterministic browser proof**

## Performance

- **Duration:** 5 min
- **Started:** 2026-06-13T02:04:17Z
- **Completed:** 2026-06-13T02:09:13Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Added `examples/adoption_demo/e2e/support/admin.js` with route construction, LiveView-ready navigation, shell assertions, theme toggling, first detail-link lookup, raw-secret rejection, and horizontal-scroll assertions.
- Added stable `data-rindle-admin-*` selectors to Actions tabs, panels, forms, inputs, submit controls, preview containers, and asset/upload-session detail links.
- Extended focused LiveView tests to prove those selectors render while preserving existing event names, confirmation copy, and operation behavior.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create shared admin Playwright helper** - `364f076` (feat)
2. **Task 2: Add stable admin selectors for browser flows** - `d05d5da` (feat)

**Plan metadata:** committed after this summary is written.

## Files Created/Modified

- `examples/adoption_demo/e2e/support/admin.js` - Shared CommonJS helper for downstream admin Playwright specs.
- `lib/rindle/admin/live/actions_live.ex` - Semantic selectors for action tabs, panel, forms, controls, submits, and previews.
- `lib/rindle/admin/live/assets_live.ex` - Stable asset list detail-link selector.
- `lib/rindle/admin/live/upload_sessions_live.ex` - Stable upload-session list detail-link selector and asset detail-link selector.
- `test/rindle/admin/live/actions_live_test.exs` - Selector coverage for actions browser-flow contracts.
- `test/rindle/admin/live/home_assets_upload_test.exs` - Selector coverage for asset and upload-session detail links.

## Decisions Made

- Used the existing adoption demo Playwright harness and `waitForLiveSocket` helper instead of introducing a standalone app or new browser-test dependency.
- Kept selector additions semantic and namespaced under `data-rindle-admin-*`, matching D-92-04 and avoiding generic `data-testid` attributes in shipped admin source.

## Verification

- `node -e "const admin = require('./examples/adoption_demo/e2e/support/admin'); ..."` - passed.
- `MIX_ENV=test mix test test/rindle/admin/live/actions_live_test.exs test/rindle/admin/live/home_assets_upload_test.exs` - passed, 13 tests, 0 failures.
- `rg -n "data-testid" lib/rindle/admin && exit 1 || exit 0` - passed with no matches.
- Source checks for required helper exports/selectors and LiveView selector strings passed.

## Deviations from Plan

None - plan executed exactly as written.

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope change.

## Issues Encountered

- `mix format` normalized existing formatting in `lib/rindle/admin/live/actions_live.ex` while formatting the touched file. This did not change behavior, event names, or operation semantics.
- The focused ExUnit command reports a pre-existing compiler warning in `lib/rindle/admin/queries.ex` about unused default arguments for private function `action/4`. It is outside this plan and did not block verification.

## Known Stubs

- `lib/rindle/admin/live/actions_live.ex` contains pre-existing `coming soon` fallback labels for disabled or unknown action definitions. The five Phase 90 action entries covered by this plan render enabled panels, so these fallbacks do not block the selector foundation.

## Threat Flags

None - this plan added test helpers and DOM selectors only; it introduced no new endpoint, auth path, file access, or schema boundary.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for `92-02` and `92-03`. Downstream Playwright specs can import `./support/admin` and use stable `data-rindle-admin-*` selectors instead of text-only locators or `data-testid`.

## Self-Check: PASSED

- Found `examples/adoption_demo/e2e/support/admin.js`.
- Found commits `364f076` and `d05d5da` in git history.
- Required focused verification commands passed after both production commits.

---
*Phase: 92-e2e-screenshot-driven-polish-loop*
*Completed: 2026-06-13*
