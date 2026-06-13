---
phase: 92-e2e-screenshot-driven-polish-loop
plan: "04"
subsystem: testing
tags: [playwright, screenshots, admin-console, css, liveview]

requires:
  - phase: 92-02
    provides: Live admin surface/theme Playwright helpers and runtime stability.
  - phase: 92-03
    provides: Admin action flow Playwright coverage and in-panel action selectors.
provides:
  - Live Phoenix admin screenshot matrix for all core surfaces in light and dark mode.
  - Screenshot-driven polish fixes for mobile Actions layout and admin action controls.
  - Generated CSS parity evidence for brandbook and packaged admin assets.
affects: [phase-92, e2e-02, screenshot-polish, admin-css]

tech-stack:
  added: []
  patterns:
    - CommonJS Playwright screenshot spec writes ignored artifacts under examples/adoption_demo/test-results.
    - Screenshot polish fixes start in brandbook/src/admin-css-build.mjs and sync packaged CSS byte-for-byte.

key-files:
  created:
    - examples/adoption_demo/e2e/admin-screenshots.spec.js
  modified:
    - brandbook/src/admin-css-build.mjs
    - brandbook/tokens/rindle-admin.css
    - priv/static/rindle_admin/rindle-admin.css
    - lib/rindle/admin/live/actions_live.ex

key-decisions:
  - "Use the live /admin/rindle Phoenix app as the screenshot target, not the static gallery."
  - "Keep screenshot artifacts under ignored Playwright test-results paths and assert the exact 22-file output contract."
  - "Fix action layout polish in the generated admin CSS source and keep brandbook/priv CSS byte-identical."

patterns-established:
  - "Screenshot specs should assert artifact existence explicitly, not rely on human review alone."
  - "Admin visual polish fixes that affect packaged CSS should be made in the generator and synced to priv/static."

requirements-completed: [E2E-02]

duration: 25min
completed: 2026-06-13
---

# Phase 92 Plan 04: Live Admin Screenshot Polish Summary

**Live admin screenshot matrix with 22 light/dark artifacts and generated CSS fixes for mobile Actions polish.**

## Performance

- **Duration:** 25min
- **Started:** 2026-06-13T02:47:00Z
- **Completed:** 2026-06-13T03:11:27Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added `examples/adoption_demo/e2e/admin-screenshots.spec.js`, a live-app Playwright screenshot matrix for all admin surfaces in light and dark mode.
- The spec recreates `examples/adoption_demo/test-results/admin-screenshots/`, captures 18 desktop PNGs plus 4 mobile PNGs, and fails with `missing screenshots:` if any expected artifact is absent.
- Performed screenshot review and fixed mobile Actions layout/target-size issues in generated admin CSS while preserving brandbook-to-priv CSS parity.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add live admin screenshot matrix spec** - `1638206` (`test`)
2. **Task 2: Run screenshot analyze-to-fix polish loop** - `906a8fd` (`fix`)

**Plan metadata:** committed separately after summary self-check.

## Files Created/Modified

- `examples/adoption_demo/e2e/admin-screenshots.spec.js` - Live admin screenshot matrix and 22-file artifact assertion.
- `brandbook/src/admin-css-build.mjs` - Source-of-truth CSS polish for action tabs, action forms, target sizing, wrapping, and mobile shell density.
- `brandbook/tokens/rindle-admin.css` - Regenerated admin CSS.
- `priv/static/rindle_admin/rindle-admin.css` - Synced packaged admin CSS.
- `lib/rindle/admin/live/actions_live.ex` - Removed inline action-tab layout so generated CSS controls wrapping responsively.

## Decisions Made

- Kept screenshots inside the existing adoption demo Playwright harness so the web server, seed data, and `/admin/rindle` route contract match prior Phase 92 specs.
- Used app-level theme picker controls for every capture rather than static gallery or media-emulation-only coverage.
- Treated generated CSS as the source of truth for visual fixes and copied the regenerated output to `priv/static/rindle_admin/rindle-admin.css`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed mobile Actions horizontal scroll**
- **Found during:** Task 2 (Run screenshot analyze-to-fix polish loop)
- **Issue:** The first screenshot run produced 19/22 artifacts, then failed on mobile Actions because the action tab row and unstyled controls caused horizontal scroll.
- **Fix:** Added generated CSS for wrapping action tabs, action panels, inputs, submits, confirmation strings, and mobile shell padding; removed the inline flex layout that prevented responsive wrapping.
- **Files modified:** `brandbook/src/admin-css-build.mjs`, `brandbook/tokens/rindle-admin.css`, `priv/static/rindle_admin/rindle-admin.css`, `lib/rindle/admin/live/actions_live.ex`
- **Verification:** `cd examples/adoption_demo && npx playwright test e2e/admin-screenshots.spec.js` passed and wrote all 22 PNGs.
- **Committed in:** `906a8fd`

**2. [Rule 2 - Missing Critical] Made action controls meet screenshot target-size expectations**
- **Found during:** Task 2 (Run screenshot analyze-to-fix polish loop)
- **Issue:** Screenshot review showed action tabs, form inputs, and submit controls lacked generated admin control styling and did not consistently present 44px interactive targets.
- **Fix:** Added generated admin CSS for `.rindle-admin-actions-tab`, `[data-rindle-admin-input]`, `[data-rindle-admin-submit]`, focus states, and readable mono confirmation strings.
- **Files modified:** `brandbook/src/admin-css-build.mjs`, `brandbook/tokens/rindle-admin.css`, `priv/static/rindle_admin/rindle-admin.css`
- **Verification:** Screenshot review of the regenerated mobile Actions PNGs showed wrapped controls with usable target sizing; CSS parity and screenshot spec passed.
- **Committed in:** `906a8fd`

---

**Total deviations:** 2 auto-fixed (1 Rule 1 bug, 1 Rule 2 missing critical functionality)
**Impact on plan:** Both fixes were required by the screenshot polish loop. No new dependencies, endpoints, auth paths, or public API changes were introduced.

## Screenshot Review Outcome

Screenshot-driven fixes made:

- Mobile Actions no longer has accidental horizontal scroll.
- Action tabs wrap into a responsive grid on narrow screens.
- Admin action inputs, textareas, and submit controls now use generated admin styling with 44px minimum target sizing.
- Confirmation strings render in the mono family with wrapping to avoid clipped text.
- Brandbook and packaged CSS remain byte-identical after regeneration.

## Issues Encountered

- Playwright server startup continues to print pre-existing optional dependency warnings for `Goth`, `Finch`, and `GcsSignedUrl`, plus the existing `Rindle.Admin.Queries.action/4` optional-argument warning. These warnings did not block the screenshot spec.
- `MIX_ENV=test mix test test/brandbook/admin_design_system_validation_test.exs test/rindle/admin/live/actions_live_test.exs` exited 0 with the repo's default ExUnit excludes; integration-tagged brandbook tests were excluded by that default configuration.

## Verification

- `rg -n "test-results|admin-screenshots|home-status|asset-detail|upload-session-detail|actions-owner-preview|animations: \"disabled\"|missing screenshots:" examples/adoption_demo/e2e/admin-screenshots.spec.js` - passed.
- Node source assertion for 22 expected PNG paths - passed, 18 desktop and 4 mobile.
- `rg -n "^/test-results/" examples/adoption_demo/.gitignore` - passed.
- `test -f examples/adoption_demo/test-results/admin-screenshots/light/home-status.png && test -f examples/adoption_demo/test-results/admin-screenshots/dark/actions-owner-preview.png && test -f examples/adoption_demo/test-results/admin-screenshots/mobile/light/actions.png` - passed.
- `node brandbook/src/admin-css-build.mjs` - passed, printed `rindle-admin.css written`.
- `cmp -s brandbook/tokens/rindle-admin.css priv/static/rindle_admin/rindle-admin.css` - passed.
- `MIX_ENV=test mix test test/brandbook/admin_design_system_validation_test.exs test/rindle/admin/live/actions_live_test.exs` - passed, 6 tests with 4 integration-tagged tests excluded by default config.
- `cd examples/adoption_demo && npx playwright test e2e/admin-screenshots.spec.js` - passed, 1 test, 22 PNG artifacts.
- Screenshot review contact sheet plus focused mobile Actions review - completed; required fixes listed above.

## Known Stubs

- `lib/rindle/admin/live/actions_live.ex:355`, `:371`, `:387`, `:403`, `:419`, `:439` contain pre-existing `coming soon` fallback chips used when action definitions are unavailable. They were already present before this plan and do not block the enabled screenshot paths.

## Threat Flags

None - this plan added screenshot output under ignored Playwright `test-results`, kept redaction assertions before capture, and preserved generated CSS parity. It did not introduce new network endpoints, auth paths, file-access surfaces beyond ignored PNG artifacts, or schema changes.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 92-05 can update proof-matrix/docs truth with a passing `admin-screenshots.spec.js`, stable 22-artifact screenshot output, and documented screenshot-driven polish fixes.

## Self-Check: PASSED

- Found `examples/adoption_demo/e2e/admin-screenshots.spec.js`.
- Found `.planning/phases/92-e2e-screenshot-driven-polish-loop/92-04-SUMMARY.md`.
- Found `brandbook/src/admin-css-build.mjs`.
- Found production commit `1638206`.
- Found production commit `906a8fd`.
- Found 22 generated screenshot PNG artifacts under `examples/adoption_demo/test-results/admin-screenshots/`.

---
*Phase: 92-e2e-screenshot-driven-polish-loop*
*Completed: 2026-06-13*
