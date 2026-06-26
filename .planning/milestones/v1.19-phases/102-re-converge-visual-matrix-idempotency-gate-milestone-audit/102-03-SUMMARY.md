---
phase: 102-re-converge-visual-matrix-idempotency-gate-milestone-audit
plan: 03
subsystem: testing
tags: [cohort, liveview, route-theme, exunit, visual-gate]

requires:
  - phase: 102-re-converge-visual-matrix-idempotency-gate-milestone-audit
    provides: surface-aware admin-polish focus contracts and Cohort-compatible backstop options from Plan 02
  - phase: 99-cohort-page-migrations-the-small-7-track-b
    provides: ck_page/1 shell and Cohort migration contract test ratchets
  - phase: 100-cohort-upload-migration-all-tabs-track-b
    provides: route-backed upload theme precedent
provides:
  - Shared string-only `AdoptionDemoWeb.CohortTheme.normalize/2` helper
  - Rendered `?theme=dark` support for dashboard, ops, and account erasure Cohort routes
  - Invalid-theme fallback proof for those routes
  - Contract-test coverage that keeps frozen DOM and daisyUI retirement ratchets active
affects: [Phase 102, VIS-01, VIS-02, cohort-pages, adoption-demo-e2e]

tech-stack:
  added: []
  patterns:
    - String-only URL theme allowlist for Cohort LiveViews
    - Route-rendered dark proof via `[data-ck-root][data-theme="dark"]`
    - ExUnit route contract tests pairing theme assertions with frozen DOM and daisyUI retirement checks

key-files:
  created:
    - examples/adoption_demo/lib/adoption_demo_web/cohort_theme.ex
    - .planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-03-SUMMARY.md
  modified:
    - examples/adoption_demo/lib/adoption_demo_web/live/dashboard_live.ex
    - examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex
    - examples/adoption_demo/lib/adoption_demo_web/live/account_live.ex
    - examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs

key-decisions:
  - "Cohort route theme normalization is centralized in a string-only helper that allowlists only light and dark and never converts user input to atoms."
  - "Dashboard, ops, and account erasure dark coverage is proven through rendered route state (`?theme=dark`) plus the existing Cohort contract ratchets, not Playwright media emulation."

patterns-established:
  - "Static Cohort route tests assert the root theme before running preserved-selector and daisyUI-retirement checks."
  - "Invalid Cohort theme params are tested as route renders, not just helper unit behavior."

requirements-completed: [VIS-01, VIS-02]

duration: 7 min
completed: 2026-06-19
status: complete
---

# Phase 102 Plan 03: Route-Backed Cohort Theme State Summary

**Dashboard, ops, and account erasure now render deterministic light/dark Cohort root state from route params, with invalid values normalized before they reach `data-theme`.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-06-19T15:34:17Z
- **Completed:** 2026-06-19T15:41:43Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added `AdoptionDemoWeb.CohortTheme.normalize/2` as the shared string-only route-theme helper.
- Added TDD coverage for valid, missing, and invalid theme values.
- Wired `/dashboard`, `/ops`, and `/account/:id/delete` mounts to normalize `params["theme"]` into the existing `ck_page theme={@theme}` assign.
- Added rendered route tests for dark and invalid theme variants while preserving frozen DOM selector and daisyUI retirement checks.

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Cohort theme normalization contract** - `60835d9` (test)
2. **Task 1 GREEN: shared Cohort theme helper** - `3036a21` (feat)
3. **Task 2 RED: route theme contracts** - `4612496` (test)
4. **Task 2 GREEN: rendered route theme state** - `e73f95a` (feat)

**Plan metadata:** recorded in the final docs commit for this SUMMARY.

## Files Created/Modified

- `examples/adoption_demo/lib/adoption_demo_web/cohort_theme.ex` - Shared allowlist normalizer for Cohort route theme params.
- `examples/adoption_demo/lib/adoption_demo_web/live/dashboard_live.ex` - Reads `params["theme"]` and assigns normalized theme state.
- `examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex` - Reads `params["theme"]` and assigns normalized theme state.
- `examples/adoption_demo/lib/adoption_demo_web/live/account_live.ex` - Reads `params["theme"]` and assigns normalized theme state.
- `examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs` - Adds helper and route-rendered theme assertions for dark and invalid variants.

## Verification

- PASS: RED Task 1: `mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs` failed because `AdoptionDemoWeb.CohortTheme.normalize/2` was undefined.
- PASS: RED Task 2: same targeted test failed on the three dark route renders because the Cohort root still rendered light.
- PASS: `cd examples/adoption_demo && mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs` (21 tests, 0 failures; known Mox warnings emitted).
- PASS: `node brandbook/src/cohort-contrast.mjs` (28/28 pairs pass).
- PASS: `cd examples/adoption_demo && mix precommit` (37 tests, 0 failures; known Mox warnings emitted).

## Decisions Made

- Kept `CohortTheme.normalize/2` string-only and local to the web namespace; no atom conversion and no dependency changes.
- Used route-rendered assertions for `data-theme="dark"` and invalid fallback to `"light"` so D-102-06 is proven at the server-rendered DOM boundary.
- Left `/upload`'s existing private normalizer untouched because this plan explicitly wires the first non-upload static surfaces; a later cleanup can de-duplicate without changing this proof.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- `mix precommit` autoformatted several pre-existing adoption-demo files as a side effect. Those uncommitted formatter edits were discarded by path after the gate passed, matching the prior Phase 102 closeout pattern.
- The known test-environment Mox warnings from `AdoptionDemo.MuxCassette` still print during compile/test, but all commands exited 0.

## Known Stubs

None. Stub scan over created/modified files found no TODO/FIXME/placeholders or hardcoded empty UI data.

## Authentication Gates

None.

## Threat Flags

None. The URL query -> LiveView assign trust boundary was already in the plan threat model and is mitigated by the new allowlist helper plus rendered invalid-theme tests.

## TDD Gate Compliance

PASS. RED commits `60835d9` and `4612496` precede GREEN commits `3036a21` and `e73f95a` for the two TDD tasks.

## Next Phase Readiness

Ready for `102-04`: the first non-upload Cohort static routes now have deterministic rendered dark URLs and invalid-theme fallback tests for the hard-fail visual matrix.

## Self-Check: PASSED

- FOUND: `examples/adoption_demo/lib/adoption_demo_web/cohort_theme.ex`
- FOUND: `.planning/phases/102-re-converge-visual-matrix-idempotency-gate-milestone-audit/102-03-SUMMARY.md`
- FOUND commits: `60835d9`, `3036a21`, `4612496`, `e73f95a`

---
*Phase: 102-re-converge-visual-matrix-idempotency-gate-milestone-audit*
*Completed: 2026-06-19*
