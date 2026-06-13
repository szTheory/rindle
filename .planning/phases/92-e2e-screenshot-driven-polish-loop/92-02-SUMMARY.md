---
phase: 92-e2e-screenshot-driven-polish-loop
plan: "02"
subsystem: testing
tags: [playwright, admin-console, liveview, theme, e2e]

requires:
  - phase: 92-01
    provides: Shared adoption demo admin Playwright helper and stable data-rindle-admin selectors.
provides:
  - Admin console Playwright coverage for navigation, seeded rows, details, redaction, empty states, and error states.
  - Admin theme picker Playwright coverage for light, dark, and auto across core surfaces.
  - Runtime fixes required for deterministic /admin/rindle browser coverage.
affects: [phase-92, admin-e2e, screenshot-polish, proof-matrix]

tech-stack:
  added: []
  patterns:
    - CommonJS Playwright specs using examples/adoption_demo/e2e/support/admin.js.
    - LiveView JS commands for deterministic admin theme picker state.
    - Generated admin CSS table wrapping to prevent screenshot/viewport overflow.

key-files:
  created:
    - examples/adoption_demo/e2e/admin-console.spec.js
    - examples/adoption_demo/e2e/admin-theme.spec.js
  modified:
    - examples/adoption_demo/e2e/support/admin.js
    - examples/adoption_demo/lib/adoption_demo_web/router.ex
    - lib/rindle/admin/components.ex
    - lib/rindle/admin/live/upload_sessions_live.ex
    - lib/rindle/admin/queries.ex
    - brandbook/src/admin-css-build.mjs
    - brandbook/tokens/rindle-admin.css
    - priv/static/rindle_admin/rindle-admin.css

key-decisions:
  - "Keep Phase 92 admin browser coverage on the /admin/rindle route contract established by Plan 92-01."
  - "Use LiveView JS commands for theme picker state so tests exercise app-level controls without page.emulateMedia."
  - "Treat invalid admin detail IDs as stable not-found error states instead of letting UUID casting failures escape."
  - "Fix generated admin table CSS at the brandbook generator source and sync packaged CSS rather than hand-editing generated assets."

patterns-established:
  - "Admin Playwright specs should navigate through the shared helper and assert only data-rindle-admin-* selectors."
  - "Admin UI visual overflow regressions should be caught by expectNoHorizontalScroll and fixed in generated design-system CSS."

requirements-completed: [E2E-01]

duration: 1h 10m
completed: 2026-06-13
---

# Phase 92 Plan 02: Admin Browser Coverage Summary

**Deterministic adoption demo Playwright coverage for admin navigation, details, boundaries, redaction, and theme switching.**

## Performance

- **Duration:** 1h 10m
- **Started:** 2026-06-13T01:30:00Z
- **Completed:** 2026-06-13T02:39:42Z
- **Tasks:** 2 planned tasks plus 1 final-verification fix
- **Files modified:** 10

## Accomplishments

- Added `admin-console.spec.js` covering all top-level admin surfaces, seeded list rows, asset/upload-session detail pages, redaction, empty filters, and missing-detail error states.
- Added `admin-theme.spec.js` covering light, dark, and auto theme picker behavior on home/status, assets, and actions surfaces.
- Fixed runtime issues that blocked the planned `/admin/rindle` browser contract and made theme/overflow assertions deterministic.

## Task Commits

Each production task was committed atomically:

1. **Task 1: Add admin surface and boundary Playwright spec** - `d4e31cc` (`test`)
2. **Task 2: Add theme picker Playwright spec** - `2bd9609` (`test`)
3. **Final verification fix: Prevent admin table overflow** - `c7b7767` (`fix`)

## Files Created/Modified

- `examples/adoption_demo/e2e/admin-console.spec.js` - Admin surface, row, detail, redaction, empty-state, and error-state browser coverage.
- `examples/adoption_demo/e2e/admin-theme.spec.js` - Theme picker browser coverage across three admin surfaces.
- `examples/adoption_demo/e2e/support/admin.js` - Scoped admin-shell root locator for Playwright strict mode.
- `examples/adoption_demo/lib/adoption_demo_web/router.ex` - Mounted the adoption demo admin console at `/admin/rindle`.
- `lib/rindle/admin/components.ex` - Linked packaged admin assets and wired theme buttons to LiveView JS state updates.
- `lib/rindle/admin/live/upload_sessions_live.ex` - Rendered upload-session detail URI through the redacted value component.
- `lib/rindle/admin/queries.ex` - Returned stable not-found errors for invalid asset/upload-session detail IDs.
- `brandbook/src/admin-css-build.mjs` - Added generated table layout/wrapping rules.
- `brandbook/tokens/rindle-admin.css` - Regenerated admin design-system CSS.
- `priv/static/rindle_admin/rindle-admin.css` - Synced packaged admin CSS.

## Decisions Made

- Kept specs inside the existing adoption demo Playwright harness and reused the Plan 92-01 helper for routing, LiveView readiness, redaction, theme, and scroll assertions.
- Used the `/admin/rindle` route contract from Plan 92-01 rather than hardcoding a separate route in specs.
- Exercised actual theme picker controls with LiveView JS updates instead of media emulation.
- Fixed generated admin CSS through the brandbook generator so packaged and brandbook assets remain aligned.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Aligned adoption demo admin mount with /admin/rindle**
- **Found during:** Task 1
- **Issue:** The adoption demo served the admin console at `/admin`, but the Plan 92-01 helper and Plan 92-02 route contract used `/admin/rindle`.
- **Fix:** Mounted `rindle_admin("/rindle", allow_unauthenticated?: true)` under `/admin`.
- **Files modified:** `examples/adoption_demo/lib/adoption_demo_web/router.ex`
- **Verification:** `cd examples/adoption_demo && npx playwright test e2e/admin-console.spec.js`
- **Committed in:** `d4e31cc`

**2. [Rule 1 - Bug] Fixed strict-mode admin root selection**
- **Found during:** Task 1
- **Issue:** `expectAdminShell` matched multiple elements with `data-rindle-admin-surface`, causing Playwright strict-mode failures.
- **Fix:** Scoped the shell assertion to `[data-rindle-admin-root][data-rindle-admin-surface=...]`.
- **Files modified:** `examples/adoption_demo/e2e/support/admin.js`
- **Verification:** `cd examples/adoption_demo && npx playwright test e2e/admin-console.spec.js`
- **Committed in:** `d4e31cc`

**3. [Rule 1 - Bug] Returned stable admin error states for invalid detail IDs**
- **Found during:** Task 1
- **Issue:** Invalid UUID detail routes raised cast errors instead of rendering the planned `[data-rindle-admin-error-state]` boundary.
- **Fix:** Added UUID casting guards that return `{:error, :not_found}` for invalid asset and upload-session IDs.
- **Files modified:** `lib/rindle/admin/queries.ex`
- **Verification:** `cd examples/adoption_demo && npx playwright test e2e/admin-console.spec.js`
- **Committed in:** `d4e31cc`

**4. [Rule 2 - Missing Critical] Exposed redaction selector on upload-session detail**
- **Found during:** Task 1
- **Issue:** Upload-session detail rendered redacted copy without the reusable `[data-rindle-admin-redacted-value]` selector required by the redaction test contract.
- **Fix:** Rendered detail session URI through the existing redacted value component.
- **Files modified:** `lib/rindle/admin/live/upload_sessions_live.ex`
- **Verification:** `cd examples/adoption_demo && npx playwright test e2e/admin-console.spec.js`
- **Committed in:** `d4e31cc`

**5. [Rule 2 - Missing Critical] Made app-level theme picker deterministic**
- **Found during:** Task 2
- **Issue:** The shell exposed theme controls but did not load packaged admin assets or update root `data-theme`/`aria-pressed` deterministically in the LiveView test path.
- **Fix:** Linked packaged admin CSS/JS from the shell and wired theme buttons to LiveView JS attribute updates.
- **Files modified:** `lib/rindle/admin/components.ex`
- **Verification:** `cd examples/adoption_demo && npx playwright test e2e/admin-theme.spec.js`
- **Committed in:** `2bd9609`

**6. [Rule 1 - Bug] Prevented generated admin table overflow**
- **Found during:** Final plan verification
- **Issue:** Loading packaged admin CSS exposed horizontal overflow on the runtime/doctor surface because long table text did not wrap.
- **Fix:** Added fixed table layout and cell `overflow-wrap: anywhere` in the admin CSS generator, then synced generated brandbook and packaged CSS.
- **Files modified:** `brandbook/src/admin-css-build.mjs`, `brandbook/tokens/rindle-admin.css`, `priv/static/rindle_admin/rindle-admin.css`
- **Verification:** `cd examples/adoption_demo && npx playwright test e2e/admin-console.spec.js`; `node brandbook/src/admin-gallery-check.mjs`
- **Committed in:** `c7b7767`

---

**Total deviations:** 6 auto-fixed (3 Rule 1 bugs, 2 Rule 2 missing critical functionality, 1 Rule 3 blocker)
**Impact on plan:** All fixes were required for the planned browser contracts to pass. No new package or architectural changes were introduced.

## Issues Encountered

- Playwright web-server startup continues to print existing optional dependency warnings for `Goth`, `Finch`, and `GcsSignedUrl`, plus the existing `Rindle.Admin.Queries.action/4` optional-argument warning. These warnings did not block the targeted specs.

## Verification

- `cd examples/adoption_demo && npx playwright test e2e/admin-console.spec.js` - passed, 4 tests.
- `cd examples/adoption_demo && npx playwright test e2e/admin-theme.spec.js` - passed, 1 test.
- `rg -n "data-testid|waitForTimeout|emulateMedia" examples/adoption_demo/e2e/admin-console.spec.js examples/adoption_demo/e2e/admin-theme.spec.js && exit 1 || exit 0` - passed, no matches.
- `MIX_ENV=test mix test test/rindle/admin/live/home_assets_upload_test.exs test/rindle/admin/live/variants_runtime_actions_test.exs` - passed, 12 tests.
- `node brandbook/src/admin-gallery-check.mjs` - passed.

## Known Stubs

None.

## Threat Flags

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 92 can continue to action coverage and screenshot polish with stable admin browser specs, a working `/admin/rindle` adoption demo route, deterministic theme picker behavior, and no horizontal overflow on the covered admin surfaces.

## Self-Check: PASSED

- Found `examples/adoption_demo/e2e/admin-console.spec.js`.
- Found `examples/adoption_demo/e2e/admin-theme.spec.js`.
- Found `.planning/phases/92-e2e-screenshot-driven-polish-loop/92-02-SUMMARY.md`.
- Found task commits `d4e31cc`, `2bd9609`, and `c7b7767`.

---
*Phase: 92-e2e-screenshot-driven-polish-loop*
*Completed: 2026-06-13*
