---
phase: 89-console-read-surfaces
plan: "07"
subsystem: ci
tags: [elixir, mix, phoenix-liveview, optional-dependencies, github-actions]

requires:
  - phase: 89-console-read-surfaces
    provides: "89-01 through 89-06 added guarded admin router, components, LiveViews, assets, queries, and live-update surfaces"
provides:
  - "ADMIN-06 proof that Rindle Admin compiles away when optional Phoenix/LiveView dependencies are absent"
  - "With-deps smoke coverage for guarded admin router, component, and six LiveView modules"
  - "Merge-blocking CI matrix lane for mix compile --no-optional-deps --warnings-as-errors"
affects: [ci, admin-console, optional-dependencies, branch-protection]

tech-stack:
  added: []
  patterns:
    - "Guarded admin modules are smoke-tested with deps present and compile-tested with optional deps absent."
    - "ADMIN-06 no-optional-deps proof uses a separate dependency/build cache namespace in CI."

key-files:
  created:
    - test/rindle/admin/optional_dependency_test.exs
  modified:
    - .github/workflows/ci.yml
    - RUNNING.md
    - scripts/setup_branch_protection.sh

key-decisions:
  - "89-07 verifies Rindle.Admin.Router.rindle_admin/2 with macro_exported?/3 because the public router surface is a macro, not a function."
  - "89-07 adds ADMIN-06 Optional Dependencies as a dedicated CI matrix job and required branch-protection check name."
  - "89-07 keeps phoenix_live_view optional and adds no runtime UI framework dependency."

patterns-established:
  - "Optional Phoenix/LiveView boundaries require both with-deps module smoke tests and no-optional-deps compile proof."
  - "No-optional-deps CI jobs use deps-no-optional/build-no-optional cache keys to avoid restoring optional packages."

requirements-completed: [ADMIN-06]

duration: 7min
completed: 2026-06-12
---

# Phase 89 Plan 07: Optional LiveView Compile-Away Proof Summary

**ADMIN-06 now has both with-deps admin surface smoke tests and a merge-blocking no-optional-deps compile matrix.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-06-12T16:01:01Z
- **Completed:** 2026-06-12T16:05:48Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added `test/rindle/admin/optional_dependency_test.exs` to prove the guarded admin router, shared components, and all six admin LiveViews load when Phoenix/LiveView deps are present.
- Added an `ADMIN-06 Optional Dependencies` GitHub Actions matrix that runs `MIX_ENV=test mix deps.get --no-optional-deps` and `MIX_ENV=test mix compile --no-optional-deps --warnings-as-errors`.
- Updated `RUNNING.md` and `scripts/setup_branch_protection.sh` so the new ADMIN-06 matrix checks are visible in the release train's required-check model.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add with-deps optional boundary smoke tests** - `12d4cbd` (test)
2. **Task 2: Add CI matrix no-optional-deps proof** - `3183196` (ci)

**Plan metadata:** pending final docs commit

## Files Created/Modified

- `test/rindle/admin/optional_dependency_test.exs` - Smoke tests for loaded admin router macro, components, six LiveViews, and `mix.exs` optional dependency posture.
- `.github/workflows/ci.yml` - Adds `optional-dependencies` matrix and gates merge-blocking downstream jobs on it.
- `RUNNING.md` - Documents the ADMIN-06 CI lane severity and updated required-check list.
- `scripts/setup_branch_protection.sh` - Adds expected required status checks for both ADMIN-06 matrix cells.

## Decisions Made

- Used `macro_exported?/3` for `Rindle.Admin.Router.rindle_admin/2` because host routers consume it as a macro.
- Kept the no-optional-deps proof in a separate CI job rather than folding it into `quality`, making the ADMIN-06 signal independently visible.
- Used separate no-optional cache keys so CI does not restore a dependency tree that contains optional Phoenix/LiveView packages.

## Verification

- `MIX_ENV=test mix test test/rindle/admin/optional_dependency_test.exs` - passed, 3 tests / 0 failures.
- `MIX_ENV=test mix compile --no-optional-deps --warnings-as-errors` - passed.
- `MIX_ENV=test mix test test/rindle/admin/router_test.exs test/rindle/admin/assets_test.exs test/rindle/admin/queries_test.exs test/rindle/admin/live/home_assets_upload_test.exs test/rindle/admin/live/variants_runtime_actions_test.exs test/rindle/admin/live_update_test.exs test/rindle/admin/optional_dependency_test.exs` - passed, 34 tests / 0 failures.
- `mix coveralls` - passed, 3 doctests and 1135 tests / 0 failures / 4 skipped / 56 excluded.
- `.github/workflows/ci.yml` parsed with PyYAML.
- `bash scripts/setup_branch_protection.sh --print-expected` lists both `ADMIN-06 Optional Dependencies` matrix checks.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected router export assertion for macro surface**
- **Found during:** Task 1 (Add with-deps optional boundary smoke tests)
- **Issue:** The plan requested `function_exported?(Rindle.Admin.Router, :rindle_admin, 2)`, but `rindle_admin/2` is implemented and consumed as a router macro.
- **Fix:** Asserted `macro_exported?(Rindle.Admin.Router, :rindle_admin, 2)` instead.
- **Files modified:** `test/rindle/admin/optional_dependency_test.exs`
- **Verification:** Focused optional dependency test passed.
- **Committed in:** `12d4cbd`

**2. [Rule 2 - Missing Critical] Added required-check documentation for ADMIN-06 CI lane**
- **Found during:** Task 2 (Add CI matrix no-optional-deps proof)
- **Issue:** Adding a CI job alone would not keep the repo's branch-protection setup and CI severity docs aligned with the new merge-blocking proof.
- **Fix:** Updated `scripts/setup_branch_protection.sh` and `RUNNING.md` with the new `ADMIN-06 Optional Dependencies` matrix check names.
- **Files modified:** `scripts/setup_branch_protection.sh`, `RUNNING.md`
- **Verification:** `bash scripts/setup_branch_protection.sh --print-expected` lists both ADMIN-06 checks.
- **Committed in:** `3183196`

**3. [Rule 3 - Blocking] Reran Mix verification serially after dependency-state collision**
- **Found during:** Phase-level verification
- **Issue:** Running focused tests concurrently with `mix compile --no-optional-deps` caused the test run to start against the wrong Mix build/dependency state.
- **Fix:** Restored normal deps with `MIX_ENV=test mix deps.get`, reran focused tests serially, then ran no-optional compile and restored normal deps again before `mix coveralls`.
- **Files modified:** None
- **Verification:** Focused admin tests, no-optional compile, and `mix coveralls` all passed.
- **Committed in:** N/A

---

**Total deviations:** 3 auto-fixed (Rule 1: 1, Rule 2: 1, Rule 3: 1)
**Impact on plan:** No scope expansion beyond ADMIN-06 proof integrity; the extra documentation keeps required-check truth synchronized.

## Issues Encountered

- The first focused optional dependency test failed because the plan described a macro surface as a function export. The test was corrected to match the actual router API.
- A parallel Mix verification run collided over dependency/build state. The final verification was rerun serially and passed.

## Known Stubs

- `.github/workflows/ci.yml:549` contains the pre-existing `HEX_API_KEY: dryrun-placeholder` release dry-run value. It is outside the ADMIN-06 changes and remains intentional release-lane scaffolding.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 89 now satisfies ADMIN-06: LiveView remains optional, guarded admin modules load when optional deps are present, and default/no-optional-deps compilation is proven locally and in CI.

## Self-Check: PASSED

- Found created/modified files: `test/rindle/admin/optional_dependency_test.exs`, `.github/workflows/ci.yml`, `RUNNING.md`, `scripts/setup_branch_protection.sh`, `.planning/phases/89-console-read-surfaces/89-07-SUMMARY.md`.
- Found task commits: `12d4cbd`, `3183196`.
- Final verification passed: focused Phase 89 admin tests, no-optional-deps compile, and `mix coveralls`.

---
*Phase: 89-console-read-surfaces*
*Completed: 2026-06-12*
