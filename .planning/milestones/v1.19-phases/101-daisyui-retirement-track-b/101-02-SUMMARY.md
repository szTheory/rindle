---
phase: 101-daisyui-retirement-track-b
plan: "02"
subsystem: ui
tags: [cohort, layout, phoenix-liveview, daisyui-retirement, dead-code, tests]

requires:
  - phase: 99-cohort-page-migrations-the-small-7-track-b
    provides: ck_page/1 per-page shell and Cohort migration contract harness
  - phase: 101-daisyui-retirement-track-b
    provides: Plan 01 Cohort flash and alert surface
provides:
  - Bare Layouts.app shell with nav, main slot, footer, and flash as app-level chrome
  - Deleted unreachable Phoenix generator landing controller, HTML module, template, and misnamed controller test
  - LaunchpadLive and Cohort contract assertions for layout and dead-generator retirement
affects: [phase-101, phase-102, cohort-demo, adoption-demo-unit]

tech-stack:
  added: []
  patterns:
    - "Layouts.app stays a bare app shell; routed pages own width and padding through ck_page/1 and .ck__wrap."
    - "Dead Phoenix generator landing code is deleted rather than migrated or scan-excluded."

key-files:
  created:
    - .planning/phases/101-daisyui-retirement-track-b/101-02-SUMMARY.md
  modified:
    - examples/adoption_demo/lib/adoption_demo_web/components/layouts.ex
    - examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs
    - examples/adoption_demo/test/adoption_demo_web/live/launchpad_live_test.exs
  deleted:
    - examples/adoption_demo/lib/adoption_demo_web/controllers/page_controller.ex
    - examples/adoption_demo/lib/adoption_demo_web/controllers/page_html.ex
    - examples/adoption_demo/lib/adoption_demo_web/controllers/page_html/home.html.heex
    - examples/adoption_demo/test/adoption_demo_web/controllers/page_controller_test.exs

key-decisions:
  - "Keep Layouts.app as a bare shell and rely on each routed page's ck_page/1/.ck__wrap for dimensions."
  - "Delete unreachable Phoenix generator landing files outright instead of migrating them or adding scan exclusions."

patterns-established:
  - "Layout retirement is pinned by composed LiveView render assertions, not source-only greps."
  - "LaunchpadLiveTest is the canonical home-page test; dead generator tests are not replaced with a new controller test."

requirements-completed: [COHORT-05]

duration: 6 min
completed: 2026-06-18
status: complete
---

# Phase 101 Plan 02: Layout and Dead Generator Retirement Summary

**Cohort pages now render through a bare app layout while unreachable Phoenix generator landing code is deleted and LaunchpadLive owns `/` coverage.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-06-18T20:13:07Z
- **Completed:** 2026-06-18T20:19:14Z
- **Tasks:** 2
- **Files modified:** 7 task files; planning metadata updated separately

## Accomplishments

- Removed the shared `Layouts.app/1` Tailwind width/padding wrapper so page dimensions come only from each page's `ck_page/1` / `.ck__wrap` shell.
- Kept app chrome intact: one Cohort nav, one bare main, one Cohort footer, and one flash group.
- Deleted the unreachable Phoenix generator landing controller, HTML module, template, and obsolete controller test.
- Added RED/GREEN assertions for both layout retirement and generator scaffold retirement.

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Layout wrapper retirement assertion** - `a7e970f` (test)
2. **Task 1 GREEN: Remove Layouts.app Tailwind wrapper** - `e835b17` (feat)
3. **Task 2 RED: Generator scaffold retirement assertion** - `a289106` (test)
4. **Task 2 GREEN: Delete dead generator landing scaffold** - `421d2e6` (feat)

_Note: Both plan tasks were marked `tdd="true"`, so each produced RED and GREEN commits._

## Files Created/Modified

- `examples/adoption_demo/lib/adoption_demo_web/components/layouts.ex` - Renders nav, bare main slot, footer, and flash as direct app-level chrome.
- `examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs` - Adds composed-render assertions for the bare layout and retired wrapper literals.
- `examples/adoption_demo/test/adoption_demo_web/live/launchpad_live_test.exs` - Adds the missing launchpad brand assertion and a source/file ratchet for generator scaffold deletion.
- `examples/adoption_demo/lib/adoption_demo_web/controllers/page_controller.ex` - Deleted unreachable generator controller.
- `examples/adoption_demo/lib/adoption_demo_web/controllers/page_html.ex` - Deleted unreachable generator HTML module.
- `examples/adoption_demo/lib/adoption_demo_web/controllers/page_html/home.html.heex` - Deleted unreachable generator landing template.
- `examples/adoption_demo/test/adoption_demo_web/controllers/page_controller_test.exs` - Deleted obsolete misnamed controller test.

## Decisions Made

- Kept `Layouts.app/1` deliberately unstyled at the layout layer. The existing per-page Cohort shell remains the single source for width, padding, theme root, and page rhythm.
- Treated the Phoenix generator landing files as dead code. The route table already sends `/` to `LaunchpadLive`, so deleting the generator files is clearer than migrating unreachable markup.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The adoption-demo test commands continue to emit pre-existing Mox warnings from `lib/adoption_demo/mux_cassette.ex`; all test runs passed.
- An initial parallel verification briefly observed an empty `page_html.ex` file state while checking deletions. The file was removed again and the launchpad, contract, and full adoption-demo unit suites were rerun serially and passed.

## Verification

- `cd examples/adoption_demo && mix test test/adoption_demo_web/live/launchpad_live_test.exs` - PASS, 3 tests, 0 failures.
- `cd examples/adoption_demo && mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs` - PASS, 13 tests, 0 failures.
- `cd examples/adoption_demo && mix test` - PASS, 29 tests, 0 failures.
- `rg -n "PageController|PageHTML|page_html/home\\.html" examples/adoption_demo/lib examples/adoption_demo/test` - PASS, no live references.
- `rg -n "px-4 py-8|mx-auto max-w-3xl|space-y-4" examples/adoption_demo/lib/adoption_demo_web/components/layouts.ex` - PASS, no layout wrapper literals.

## TDD Gate Compliance

- Task 1 RED gate present: `a7e970f test(101-02): add failing layout wrapper retirement assertion`.
- Task 1 GREEN gate present after RED: `e835b17 feat(101-02): remove Layouts app Tailwind wrapper`.
- Task 2 RED gate present: `a289106 test(101-02): add failing generator scaffold retirement assertion`.
- Task 2 GREEN gate present after RED: `421d2e6 feat(101-02): delete dead generator landing scaffold`.
- REFACTOR gate: not needed.

## Known Stubs

None.

## Threat Flags

None. This plan removed unreachable UI code and changed no route, auth, storage, persistence, network, or dependency boundary.

## Authentication Gates

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for `101-03-PLAN.md`. The rendered layout and dead generator code no longer depend on Tailwind/daisyUI scaffold. `default.css` remains linked and present by design for the later link/asset deletion plan.

## Self-Check: PASSED

- Summary file exists at `.planning/phases/101-daisyui-retirement-track-b/101-02-SUMMARY.md`.
- Task commits found: `a7e970f`, `e835b17`, `a289106`, `421d2e6`.
- Key modified files are tracked in git, the four deleted generator/test files are absent, and all plan-level verification passed.

---
*Phase: 101-daisyui-retirement-track-b*
*Completed: 2026-06-18*
