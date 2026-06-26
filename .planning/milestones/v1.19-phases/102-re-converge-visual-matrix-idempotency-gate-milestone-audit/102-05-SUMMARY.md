---
phase: 102-re-converge-visual-matrix-idempotency-gate-milestone-audit
plan: 05
subsystem: testing
tags: [playwright, cohort, visual-gate, dark-theme, mobile, styleguide]

requires:
  - phase: 102-re-converge-visual-matrix-idempotency-gate-milestone-audit
    provides: strict admin root, surface-aware polish gate, and route-backed Cohort dark theme state from Plans 01-04
  - phase: 98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco
    provides: admin 24-state screenshot matrix and Phase 98 computed-style backstops
  - phase: 100-cohort-upload-migration-all-tabs-track-b
    provides: upload tab route coverage and existing server-backed upload theme state
provides:
  - Hard-fail Cohort page polish helper over the shared `assertAdminPolish` gate
  - Declarative Cohort route x theme x viewport visual matrix covering locked Cohort surfaces
  - Hard-fail Cohort styleguide proof preserving reduced-motion, explicit theme toggle, fallback, and component-existence checks
  - Source-documented boundary that admin/gallery screenshots are audit artifacts, not pixel-diff blockers
affects: [Phase 102, VIS-01, VIS-02, VIS-03, VIS-04, adoption-demo-e2e, cohort-pages, cohort-styleguide, admin-screenshots]

tech-stack:
  added: []
  patterns:
    - Route/theme/viewport Playwright matrix data with explicit rendered-theme assertions
    - Cohort visual checks pass explicit root, selectors, focus contract, and disabled admin backstops into the shared gate
    - Optional PNG/gallery artifacts stay separate from computed-style pass/fail assertions

key-files:
  created:
    - examples/adoption_demo/e2e/cohort-pages.test.js
    - .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-05-SUMMARY.md
  modified:
    - examples/adoption_demo/e2e/cohort-pages.spec.js
    - examples/adoption_demo/e2e/support/admin-polish.js
    - examples/adoption_demo/priv/static/assets/cohort.css
    - examples/adoption_demo/e2e/cohort-styleguide.spec.js
    - examples/adoption_demo/e2e/admin-screenshots.spec.js
    - brandbook/src/admin-gallery-check.mjs

key-decisions:
  - "Cohort visual proof is route/theme/viewport-driven and asserts rendered `[data-ck-root][data-theme]`; `colorScheme` media emulation is not used as Cohort page dark proof."
  - "Cohort styleguide now shares the same hard-fail computed-style gate contract as routed Cohort pages while preserving its reduced-motion and fallback probes."
  - "Admin/gallery PNG screenshots remain audit/reference artifacts; the blocking gate is DOM/computed-style assertions, not pixel diffs."

patterns-established:
  - "Dynamic Cohort routes are resolved through seeded DOM navigation before matrix cases add route-backed theme params."
  - "Hard-fail visual gates keep root-specific focus contracts explicit and do not auto-detect surfaces."
  - "Admin screenshot specs select theme before opening modal preview artifacts so modal evidence can stay visible without blocking theme controls."

requirements-completed: [VIS-01, VIS-02, VIS-03, VIS-04]

duration: 26 min
completed: 2026-06-19
status: complete
---

# Phase 102 Plan 05: Cohort Visual Matrix Hard-Fail Summary

**Cohort routes and styleguide now use the shared hard-fail computed-style gate across light, dark, desktop, and mobile while screenshots remain audit-only evidence.**

## Performance

- **Duration:** 26 min
- **Started:** 2026-06-19T15:57:26Z
- **Completed:** 2026-06-19T16:23:17Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- Converted the Cohort page helper from warning/report mode to direct hard-fail `assertAdminPolish` calls with `[data-ck-root]`, Cohort selectors, the `--ck-focus` contract, and admin-only backstops disabled.
- Added the locked Cohort visual matrix for styleguide, dashboard, ops, account erasure, member, lesson, post, media, and all six upload tabs across light/dark and desktop/mobile.
- Asserted real rendered dark state for every dark Cohort matrix case through route-backed `?theme=dark` or the styleguide theme toggle.
- Promoted the Cohort styleguide proof to hard-fail polish and rendered-contrast assertions while preserving reduced-motion, auto-fallback, and component-existence probes.
- Kept admin 24-state screenshot coverage and Phase 98 backstops intact, with screenshot/gallery comments documenting that PNG artifacts are non-blocking audit evidence.

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Cohort hard-fail helper contract** - `26ad7eb` (test)
2. **Task 1 GREEN: hard-fail Cohort page polish helper** - `a7a254f` (feat)
3. **Task 2 RED: Cohort visual matrix contract** - `3addf74` (test)
4. **Task 2 GREEN: hard-fail Cohort visual matrix** - `8410943` (feat)
5. **Task 3: hard-fail Cohort styleguide proof** - `15898d4` (test)

**Plan metadata:** recorded in the final docs commit for this SUMMARY.

## Files Created/Modified

- `examples/adoption_demo/e2e/cohort-pages.test.js` - Node contract tests for hard-fail helper wiring and locked matrix/source invariants.
- `examples/adoption_demo/e2e/cohort-pages.spec.js` - Hard-fail helper plus route/theme/viewport matrix for all locked Cohort surfaces.
- `examples/adoption_demo/e2e/support/admin-polish.js` - Shared gate robustness fixes exposed by hard-fail verification.
- `examples/adoption_demo/priv/static/assets/cohort.css` - Cohort contrast, focus, shell, and responsive media fixes surfaced by the hard gate.
- `examples/adoption_demo/e2e/cohort-styleguide.spec.js` - Styleguide polish and rendered-contrast checks now fail the spec directly.
- `examples/adoption_demo/e2e/admin-screenshots.spec.js` - Preserves 24 screenshot entries/backstops while clarifying audit-only PNG boundaries and fixing modal/theme ordering.
- `brandbook/src/admin-gallery-check.mjs` - Documents gallery screenshots as non-blocking audit/reference artifacts.

## Verification

- PASS: `node --check examples/adoption_demo/e2e/support/admin-polish.js examples/adoption_demo/e2e/cohort-pages.spec.js examples/adoption_demo/e2e/admin-screenshots.spec.js examples/adoption_demo/e2e/cohort-styleguide.spec.js`
- PASS: `node --test examples/adoption_demo/e2e/support/admin-polish.test.js examples/adoption_demo/e2e/cohort-pages.test.js` (6 tests, 0 failures)
- PASS: `node brandbook/src/cohort-contrast.mjs` (28/28 pairs pass)
- PASS: `ADOPTION_DEMO_REUSE_SERVER=1 npx playwright test e2e/cohort-pages.spec.js` (56 tests, 0 failures)
- PASS: `ADOPTION_DEMO_REUSE_SERVER=1 npx playwright test e2e/cohort-pages.spec.js --grep "lesson renders light mobile" --repeat-each=5` (5 tests, 0 failures)
- PASS: `ADOPTION_DEMO_REUSE_SERVER=1 npx playwright test e2e/admin-screenshots.spec.js e2e/cohort-pages.spec.js e2e/cohort-styleguide.spec.js` (59 tests, 0 failures)
- PASS: Source assertions that Cohort warn downgrades are absent, `COHORT_VISUAL_MATRIX` is present, `cohort-pages.spec.js` does not use `colorScheme`, and `admin-screenshots.spec.js` still contains `toHaveLength(24)`.

## Decisions Made

- Used rendered route state, not media emulation, as the dark proof for routed Cohort pages.
- Kept `/styleguide` distinct because it already owns an explicit server theme toggle and fallback probe.
- Kept the shared computed-style helper as the single gate. Cohort passes surface options; no Cohort-specific fork or root inference was added.
- Kept PNG screenshot and gallery generation in the audit/reference path only. No `toHaveScreenshot()` or pixel baseline became required for VIS-01.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Stabilized focus and raster checks for hard-fail Cohort runs**
- **Found during:** Task 2 (Expand Cohort route/theme/viewport matrix)
- **Issue:** The hard gate exposed stale active focus state and full-page screenshot height jitter that could produce false failures after theme toggles and focus probes.
- **Fix:** Blurred the active element before forced focus probes and before stable-dimension captures; kept screenshot width exact while allowing a 3px Chromium full-page height tolerance.
- **Files modified:** `examples/adoption_demo/e2e/support/admin-polish.js`
- **Verification:** `node --test examples/adoption_demo/e2e/support/admin-polish.test.js examples/adoption_demo/e2e/cohort-pages.test.js`; final 59-test Playwright run passed.
- **Committed in:** `8410943` and `15898d4`

**2. [Rule 2 - Missing Critical] Corrected Cohort readable text, focus, shell, and media sizing**
- **Found during:** Task 2 and Task 3 Playwright verification
- **Issue:** Text-bearing Cohort roles used decorative `--ck-faint`, primary buttons lacked an explicit focus contract rule, the styleguide inherited default body margin on mobile, and the lesson video could overflow mobile viewport width.
- **Fix:** Moved text-bearing utility roles to `--ck-muted`, added `.ck-btn:focus-visible`, reset body margin for Cohort pages, and constrained `.ck img`/`.ck video` to their container.
- **Files modified:** `examples/adoption_demo/priv/static/assets/cohort.css`
- **Verification:** `node brandbook/src/cohort-contrast.mjs`; `ADOPTION_DEMO_REUSE_SERVER=1 npx playwright test e2e/cohort-pages.spec.js --grep "lesson renders light mobile" --repeat-each=5`; final 59-test Playwright run passed.
- **Committed in:** `8410943` and `15898d4`

**3. [Rule 1 - Bug] Removed admin helper false positives exposed by the combined gate**
- **Found during:** Task 3 (Promote styleguide proof and assert optional artifact boundaries)
- **Issue:** The shared admin helper treated screen-reader-only captions as clipped visible text, treated text inputs as pointer-focus violations despite Chromium intentionally matching `:focus-visible` on editable controls, and considered hidden dialogs open by DOM presence alone.
- **Fix:** Ignored `.rindle-admin-visually-hidden` in clipped-text checks, exempted text-editable controls from the pointer-negative part while retaining keyboard focus-token checks, and required dialogs to be visible and laid out before asserting open-state inertness.
- **Files modified:** `examples/adoption_demo/e2e/support/admin-polish.js`
- **Verification:** `ADOPTION_DEMO_REUSE_SERVER=1 npx playwright test e2e/admin-screenshots.spec.js`; final 59-test Playwright run passed.
- **Committed in:** `15898d4`

**4. [Rule 1 - Bug] Fixed admin screenshot artifact ordering**
- **Found during:** Task 3 (Promote styleguide proof and assert optional artifact boundaries)
- **Issue:** The owner-preview screenshot case opened a modal before `capture()` selected the theme, causing the overlay to intercept the theme picker. The first screenshot test also asserted two backstop PNGs that are written by the second test later in the file.
- **Fix:** Selected admin theme before opening owner-preview modal artifacts, made `capture()` verify preselected theme state, split matrix screenshot file assertions from backstop screenshot file assertions, and kept the locked `toHaveLength(24)` source invariant.
- **Files modified:** `examples/adoption_demo/e2e/admin-screenshots.spec.js`
- **Verification:** `ADOPTION_DEMO_REUSE_SERVER=1 npx playwright test e2e/admin-screenshots.spec.js`; final 59-test Playwright run passed.
- **Committed in:** `15898d4`

---

**Total deviations:** 4 auto-fixed (3 Rule 1, 1 Rule 2)
**Impact on plan:** All fixes were required to make the planned hard-fail gate deterministic and truthful. No new feature scope, package dependency, visual lane, or pixel baseline was introduced.

## Issues Encountered

- The planned hard-fail flip uncovered latent helper and CSS defects that warn-mode did not make blocking. They were fixed inline and verified through the target Playwright lane.
- The final targeted Playwright command required a running Phoenix test server. The executor started and reused the local adoption demo test server; no user setup was required.

## Known Stubs

None. Stub scan found only local offender/result arrays, optional-parameter defaults, and non-UI helper defaults; no TODO/FIXME/placeholders or empty UI data sources were introduced.

## Authentication Gates

None.

## Threat Flags

None. The changes do not introduce network endpoints, auth paths, file access patterns, schema changes, or new trust-boundary surfaces beyond the plan's visual-helper and artifact-boundary threat model.

## User Setup Required

None.

## Next Phase Readiness

Ready for `102-06`: VIS-01/VIS-02 visual gate convergence is green for admin and Cohort in the targeted browser lane, and VIS-03/VIS-04 artifact boundaries remain explicit for the milestone audit.

## Self-Check: PASSED

Verified summary file, all created/modified code files, and task commits `26ad7eb`, `a7a254f`, `3addf74`, `8410943`, and `15898d4` exist.

---
*Phase: 102-re-converge-visual-matrix-idempotency-gate-milestone-audit*
*Completed: 2026-06-19*
