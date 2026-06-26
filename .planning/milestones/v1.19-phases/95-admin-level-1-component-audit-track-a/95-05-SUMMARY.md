---
phase: 95-admin-level-1-component-audit-track-a
plan: 05
subsystem: admin-design-system-gap-closure
tags: [brandbook, admin-gallery, generated-css, mobile, playwright, documentation]

# Dependency graph
requires:
  - phase: 95-04
    provides: Phase 95 UAT gap closure and current gallery/checker validation baseline
provides:
  - Wrapper-aware mobile table CSS that preserves sticky admin gallery tables below 760px
  - Non-empty stacked-table labels for non-sticky lifecycle gallery cells
  - Sub-760 browser assertions for sticky table display and stacked-label coverage
  - Maintainer guide parity with the 18-screenshot gallery review set
  - Synced generated and shipped admin CSS artifacts
affects: [admin-design-system, brandbook, 97-admin-level-2, 98-admin-page-composition, 102-reconvergence-proof]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Sticky admin tables use the wrapper modifier as the mobile stacked-table exception source."
    - "Non-sticky table cells that participate in stacked mobile cards must carry non-empty data-label values."
    - "Gallery documentation must track the checker's expectedScreenshots contract exactly."

key-files:
  created:
    - .planning/phases/95-admin-level-1-component-audit-track-a/95-05-SUMMARY.md
  modified:
    - brandbook/src/admin-css-build.mjs
    - brandbook/src/admin-gallery.mjs
    - brandbook/src/admin-gallery-check.mjs
    - brandbook/admin-gallery/index.html
    - brandbook/tokens/rindle-admin.css
    - priv/static/rindle_admin/rindle-admin.css
    - guides/admin_design_system.md

key-decisions:
  - "Use .rindle-admin-table--sticky as a wrapper-scoped exception, not a table-local modifier."
  - "Keep sticky meta data-table cells native at mobile widths and exempt from the data-label requirement."
  - "Add computed-style and DOM-attribute assertions instead of adding new screenshot artifacts."

patterns-established:
  - "Generated admin CSS artifacts remain produced by admin-css-build.mjs and mirrored by sync-admin-css.mjs only."
  - "The admin guide's review artifact list names every screenshot in admin-gallery-check.mjs."

requirements-completed: [UPLIFT-01]

# Metrics
duration: 12min
completed: 2026-06-19
status: complete
---

# Phase 95 Plan 05: Mobile Table And Screenshot Guide Gap Closure Summary

**Wrapper-aware mobile table behavior with stacked-cell labels, browser proof, and 18-screenshot guide parity**

## Performance

- **Duration:** 12 min
- **Started:** 2026-06-19T21:34:00Z
- **Completed:** 2026-06-19T21:46:33Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- Changed generated mobile table selectors so ordinary tables stack while tables inside `.rindle-admin-table--sticky` keep native table layout below 760px.
- Added non-empty `data-label` attributes to non-sticky lifecycle table cells, including empty and skeleton colspan rows.
- Added a 390px Playwright assertion that proves sticky table/table-body/row/cell display values and fails on missing stacked labels.
- Updated the admin design-system guide to state that the checker writes 18 screenshots and to list all eight meta-component artifacts.
- Regenerated and synced `brandbook/tokens/rindle-admin.css` and `priv/static/rindle_admin/rindle-admin.css` with byte parity.

## Task Commits

Each task was committed atomically:

1. **Task 1: Generate wrapper-aware mobile table CSS and stacked labels** - `2960883` (fix)
2. **Task 2: Add sub-760 browser assertions for sticky and stacked tables** - `57c83a8` (test)
3. **Task 3: Document 18 screenshots and run the Phase 95 validation chain** - `6a9139d` (docs)

**Plan metadata:** this summary commit.

## Files Created/Modified

- `brandbook/src/admin-css-build.mjs` - Uses wrapper-aware mobile selectors and emits explicit sticky table display preservation rules.
- `brandbook/src/admin-gallery.mjs` - Emits non-empty `data-label` values on non-sticky lifecycle table cells.
- `brandbook/src/admin-gallery-check.mjs` - Proves sticky mobile display values and stacked-label coverage at 390px.
- `brandbook/admin-gallery/index.html` - Regenerated gallery markup with stacked labels.
- `brandbook/tokens/rindle-admin.css` - Regenerated canonical admin CSS.
- `priv/static/rindle_admin/rindle-admin.css` - Synced shipped CSS copy.
- `guides/admin_design_system.md` - Documents the full 18-screenshot maintainer review set.

## Decisions Made

- The sticky exception is tied to the existing wrapper marker `.rindle-admin-table--sticky`, because the table itself does not carry that modifier in the gallery fixture.
- Sticky meta data-tables remain native table layouts at mobile widths and do not need `data-label`; only non-sticky stacked tables are label-asserted.
- The regression proof stays deterministic through computed styles and DOM attributes, with no new PNG artifacts or screenshot-count change.

## Deviations from Plan

None - plan executed exactly as written.

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope creep; changes stayed in generated admin CSS, gallery fixtures, checker proof, synced artifacts, guide documentation, and summary documentation.

## Verification

- `node brandbook/src/admin-css-build.mjs` -> `rindle-admin.css written - 53 selectors, 12 meta selectors, 4 theme scopes, parity OK`
- `node brandbook/src/admin-contrast.mjs` -> `admin contrast: 58/58 pairs pass`
- `node brandbook/src/admin-gallery-check.mjs` -> `admin gallery check passed - 18 screenshots written`
- `node brandbook/src/sync-admin-css.mjs` -> synced `rindle-admin.css` to the shipped package copy
- `cmp -s brandbook/tokens/rindle-admin.css priv/static/rindle_admin/rindle-admin.css` -> pass
- `mix test --include integration test/brandbook/admin_design_system_validation_test.exs` -> `24 tests, 0 failures`
- Guide artifact grep for all eight meta screenshots -> pass

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 95 verifier gaps are closed. The mobile table blocker has source, generated artifact, and browser-proof coverage; the stale guide warning is resolved against the current 18-screenshot contract. Phase 95 is ready for verify-work or archival state refresh.

## Self-Check: PASSED

- FOUND: `.planning/phases/95-admin-level-1-component-audit-track-a/95-05-SUMMARY.md`
- FOUND commit: `2960883` (Task 1)
- FOUND commit: `57c83a8` (Task 2)
- FOUND commit: `6a9139d` (Task 3)
- FULL GATE PASSED: `24 tests, 0 failures`

---
*Phase: 95-admin-level-1-component-audit-track-a*
*Completed: 2026-06-19*
