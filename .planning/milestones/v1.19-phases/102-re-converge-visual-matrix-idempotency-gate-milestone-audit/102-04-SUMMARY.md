---
phase: 102-re-converge-visual-matrix-idempotency-gate-milestone-audit
plan: 04
subsystem: testing
tags: [cohort, liveview, route-theme, exunit, visual-matrix]

requires:
  - phase: 102-re-converge-visual-matrix-idempotency-gate-milestone-audit
    provides: shared `AdoptionDemoWeb.CohortTheme.normalize/2` helper and dashboard/ops/account route-theme pattern from Plan 03
  - phase: 99-cohort-page-migrations-the-small-7-track-b
    provides: member, lesson, post, and media pages migrated onto `ck_page/1` with frozen DOM contracts
provides:
  - Rendered `?theme=dark` support for member, lesson, post, and media Cohort detail routes
  - Invalid-theme fallback proof for all four routed detail surfaces
  - Contract-test coverage preserving frozen DOM, media detail, and daisyUI retirement ratchets
affects: [Phase 102, VIS-01, VIS-02, cohort-pages, adoption-demo-e2e]

tech-stack:
  added: []
  patterns:
    - Route params are normalized through the shared string-only Cohort theme helper before reaching `data-theme`.
    - Detail route tests assert `[data-ck-root][data-theme]` before running frozen selector and daisyUI retirement checks.
    - Media detail route tests keep the in-place `<dl>` and variant `<li>` contracts as part of theme coverage.

key-files:
  created:
    - .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-04-SUMMARY.md
  modified:
    - examples/adoption_demo/lib/adoption_demo_web/live/member_live.ex
    - examples/adoption_demo/lib/adoption_demo_web/live/lesson_live.ex
    - examples/adoption_demo/lib/adoption_demo_web/live/post_live.ex
    - examples/adoption_demo/lib/adoption_demo_web/live/media_live.ex
    - examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs

key-decisions:
  - "Member, lesson, post, and media route theme state reuses the Plan 03 shared normalizer instead of adding per-LiveView allowlists."
  - "Detail dark-mode proof is rendered route state (`?theme=dark`) paired with existing frozen DOM and daisyUI-retirement ratchets, not media emulation."

patterns-established:
  - "Cohort detail pages now follow the same route-backed theme-state pattern as dashboard, ops, and account erasure."

requirements-completed: [VIS-01, VIS-02]

duration: 5 min
completed: 2026-06-19
status: complete
---

# Phase 102 Plan 04: Cohort Detail Route Theme State Summary

**Member, lesson, post, and media detail routes now render deterministic Cohort light/dark root state from URL params while preserving their frozen behavior contracts.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-06-19T15:47:15Z
- **Completed:** 2026-06-19T15:53:03Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added route-rendered dark and invalid-theme contract coverage for member, lesson, post, and media detail pages.
- Wired all four detail LiveViews to keep their existing `id` entity loading while assigning `:theme` through `AdoptionDemoWeb.CohortTheme.normalize/2`.
- Preserved member replace/detach handlers, lesson variant selectors, post image selectors, and media `<dl>` plus `variant-thumb` contracts inside the new theme tests.

## Task Commits

Each task followed the required TDD gate:

1. **Task 1 RED: member and lesson theme route contracts** - `fbb6dff` (test)
2. **Task 1 GREEN: member and lesson route theme state** - `2053488` (feat)
3. **Task 2 RED: post and media theme route contracts** - `a45b5d3` (test)
4. **Task 2 GREEN: post and media route theme state** - `eeffa3e` (feat)

**Plan metadata:** recorded in the final docs commit for this SUMMARY.

## Files Created/Modified

- `examples/adoption_demo/lib/adoption_demo_web/live/member_live.ex` - Reads the detail route params and normalizes `params["theme"]` for `ck_page/1`.
- `examples/adoption_demo/lib/adoption_demo_web/live/lesson_live.ex` - Reads the detail route params and normalizes `params["theme"]` while preserving lesson media/variant loading.
- `examples/adoption_demo/lib/adoption_demo_web/live/post_live.ex` - Reads the detail route params and normalizes `params["theme"]` while preserving post image loading.
- `examples/adoption_demo/lib/adoption_demo_web/live/media_live.ex` - Reads the detail route params and normalizes `params["theme"]` while preserving media asset, delivery URL, variant, and member-link loading.
- `examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs` - Adds dark and invalid route variants for all four detail pages.

## Verification

- PASS: RED Task 1: `cd examples/adoption_demo && mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs` failed with 2 expected failures because `/members/:id?theme=dark` and `/lessons/:id?theme=dark` still rendered light.
- PASS: GREEN Task 1: same targeted contract test passed with 23 tests, 0 failures.
- PASS: RED Task 2: same targeted contract test failed with 2 expected failures because `/posts/:id?theme=dark` and `/media/:id?theme=dark` still rendered light.
- PASS: Final targeted contract test passed with 25 tests, 0 failures.
- PASS: `node brandbook/src/cohort-contrast.mjs` passed with 28/28 pairs.
- PASS: `cd examples/adoption_demo && mix precommit` passed with 41 tests, 0 failures. The known Mox warnings still print during compile.

## Decisions Made

- Reused `AdoptionDemoWeb.CohortTheme.normalize/2` exactly rather than duplicating string allowlists in each detail LiveView.
- Kept all detail-route entity loading code in place and changed only the `:theme` assign.
- Kept media's in-place `<dl>` and variant `<li>` assertions inside the new route-theme coverage to preserve the Phase 99 restyle decision.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- `mix format --check-formatted` reports older formatter drift in adoption-demo files touched by earlier phases. The required `mix precommit` alias passed, but its `format` step rewrote unrelated files; those formatter-only edits were reverted by explicit path so this plan's commits stayed scoped to route-state behavior.
- The known test-environment Mox warnings from `AdoptionDemo.MuxCassette` still print during compile/test, but all verification commands exited 0.

## Known Stubs

None. Stub scan over created/modified files found no TODO/FIXME/placeholders or hardcoded empty UI data.

## Authentication Gates

None.

## Threat Flags

None. The URL query to detail LiveView trust boundary was already modeled in the plan and is mitigated by the shared string allowlist plus rendered invalid-theme tests.

## TDD Gate Compliance

PASS. RED commits `fbb6dff` and `a45b5d3` precede GREEN commits `2053488` and `eeffa3e`.

## Next Phase Readiness

Ready for `102-05`: dashboard, ops, account, member, lesson, post, media, and upload now have route-backed dark proof patterns available for the full Cohort hard-fail visual matrix.

## Self-Check: PASSED

- FOUND: `examples/adoption_demo/lib/adoption_demo_web/live/member_live.ex`
- FOUND: `examples/adoption_demo/lib/adoption_demo_web/live/lesson_live.ex`
- FOUND: `examples/adoption_demo/lib/adoption_demo_web/live/post_live.ex`
- FOUND: `examples/adoption_demo/lib/adoption_demo_web/live/media_live.ex`
- FOUND: `examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs`
- FOUND: `.planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-04-SUMMARY.md`
- FOUND commits: `fbb6dff`, `2053488`, `a45b5d3`, `eeffa3e`

---
*Phase: 102-re-converge-visual-matrix-idempotency-gate-milestone-audit*
*Completed: 2026-06-19*
