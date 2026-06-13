---
phase: 92-e2e-screenshot-driven-polish-loop
plan: "05"
subsystem: testing
tags: [playwright, ci, proof-matrix, admin-console, screenshots]

requires:
  - phase: 92-02
    provides: Admin console and theme Playwright specs.
  - phase: 92-03
    provides: Admin action Playwright spec.
  - phase: 92-04
    provides: Admin screenshot Playwright spec and ignored screenshot output path.
provides:
  - Proof matrix rows and drift checks for admin behavior and screenshot polish specs.
  - Local README commands for targeted admin behavior and screenshot Playwright runs.
  - Updated adoption-demo-e2e CI wording for the existing merge-blocking browser lane.
affects: [phase-92, e2e-01, e2e-02, adoption-demo-e2e, proof]

tech-stack:
  added: []
  patterns:
    - Proof matrix drift gate must list every merge-blocking adoption demo Playwright spec filename.
    - Cohort ops browser surfaces should use public Rindle APIs rather than Mix task lifecycle state.

key-files:
  created:
    - .planning/phases/92-e2e-screenshot-driven-polish-loop/92-05-SUMMARY.md
  modified:
    - examples/adoption_demo/docs/adoption-proof-matrix.md
    - scripts/maintainer/check_adoption_proof_matrix.sh
    - examples/adoption_demo/README.md
    - .github/workflows/ci.yml
    - examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex
    - lib/mix/tasks/rindle.runtime_status.ex
    - mix.exs

key-decisions:
  - "Keep admin screenshot proof inside the existing adoption-demo-e2e job instead of adding a new GitHub Actions job."
  - "Define mix precommit as the local default ExUnit gate because the repo had no pre-existing precommit task."
  - "Leave unrelated pre-existing full-repo formatting drift untouched."

patterns-established:
  - "Admin E2E proof documentation should name behavior, theme, action, screenshot specs, and ignored screenshot artifacts together."
  - "Runtime status text formatting should tolerate runtime-check and variant sample shapes."

requirements-completed: [E2E-01, E2E-02]

duration: 8min
completed: 2026-06-13
---

# Phase 92 Plan 05: Proof Matrix and CI Wiring Summary

**Admin behavior and screenshot specs are now listed, drift-gated, documented locally, and covered by the existing merge-blocking adoption demo E2E lane.**

## Performance

- **Duration:** 8min
- **Started:** 2026-06-13T03:15:39Z
- **Completed:** 2026-06-13T03:23:17Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Added proof matrix rows for admin console behavior and admin screenshot polish.
- Extended the proof matrix drift gate to require all four admin spec filenames plus `test-results/admin-screenshots`.
- Documented targeted local admin behavior and screenshot Playwright commands in the adoption demo README.
- Updated the existing `adoption-demo-e2e` CI job comment without adding a new GitHub Actions job.
- Fixed blocking runtime-status output issues so the full packaged adoption demo E2E lane passes.

## Task Commits

Each task was committed atomically:

1. **Task 1: Update proof matrix, drift gate, and local docs** - `1a0966a` (docs)
2. **Task 2: Verify merge-blocking adoption demo lane truth** - `c816cbe` (fix)

**Plan metadata:** committed separately after summary self-check.

## Files Created/Modified

- `examples/adoption_demo/docs/adoption-proof-matrix.md` - Added admin behavior and screenshot polish proof rows.
- `scripts/maintainer/check_adoption_proof_matrix.sh` - Added hard drift checks for admin specs and screenshot output.
- `examples/adoption_demo/README.md` - Added targeted admin Playwright commands and ignored screenshot output path.
- `.github/workflows/ci.yml` - Replaced stale `12/12` wording with current admin behavior/theme/actions/screenshot lane wording.
- `examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex` - Uses public runtime-status API for deterministic browser output.
- `lib/mix/tasks/rindle.runtime_status.ex` - Handles runtime-check sample maps without `:variant_name`.
- `mix.exs` - Adds `mix precommit` as the default test-suite gate in `MIX_ENV=test`.

## Decisions Made

- Kept the admin screenshot proof inside `adoption-demo-e2e`; no new GitHub Actions job was introduced.
- Used the existing proof matrix drift script as the enforcement point for all admin spec filenames.
- Scoped `mix precommit` to the default test suite because the repo had no existing precommit task and full-repo formatting currently has unrelated pre-existing drift.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added missing `mix precommit` alias**
- **Found during:** Task 2 (Verify merge-blocking adoption demo lane truth)
- **Issue:** The required `mix precommit` command did not exist.
- **Fix:** Added a `precommit` Mix alias and preferred `MIX_ENV=test`.
- **Files modified:** `mix.exs`
- **Verification:** `mix help precommit`; `mix precommit`
- **Committed in:** `c816cbe`

**2. [Rule 3 - Blocking] Made Cohort runtime-status browser output deterministic**
- **Found during:** Task 2 full adoption demo E2E verification
- **Issue:** `e2e/ops-surfaces.spec.js` failed because the `/ops` LiveView did not render runtime-status output after clicking the button.
- **Fix:** Switched the ops surface from Mix task execution to `Rindle.runtime_status/1` plus the existing text formatter.
- **Files modified:** `examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex`
- **Verification:** `cd examples/adoption_demo && npx playwright test e2e/ops-surfaces.spec.js`
- **Committed in:** `c816cbe`

**3. [Rule 1 - Bug] Fixed runtime-status formatter sample-shape assumption**
- **Found during:** Task 2 blocker investigation
- **Issue:** `Mix.Tasks.Rindle.RuntimeStatus.format_text_report/1` assumed every finding sample had `:variant_name`; runtime-check samples have asset-oriented keys and raised `KeyError`.
- **Fix:** Used `Map.get(sample, :variant_name) || Map.get(sample, :asset_id)` when formatting findings.
- **Files modified:** `lib/mix/tasks/rindle.runtime_status.ex`
- **Verification:** `MIX_ENV=test mix test test/rindle/runtime_status_task_test.exs`; direct adoption demo runtime-status formatting check; ops Playwright spec
- **Committed in:** `c816cbe`

---

**Total deviations:** 3 auto-fixed (2 Rule 3 blockers, 1 Rule 1 bug)
**Impact on plan:** Fixes were required for the plan's mandatory full browser and precommit verification gates. No new public API, CI job, dependency, endpoint, auth path, or schema change was introduced.

## Issues Encountered

- The first `bash scripts/ci/adoption_demo_e2e.sh` run failed in pre-existing `e2e/ops-surfaces.spec.js`. The failure exposed runtime-status output and formatter issues fixed in Task 2.
- A full-repo `mix format --check-formatted` attempt showed unrelated pre-existing formatting drift in `test/rindle/admin/assets_test.exs`, `test/brandbook/admin_design_system_validation_test.exs`, and `test/rindle/admin/queries_test.exs`. Those files were not touched.

## Verification

- `bash scripts/maintainer/check_adoption_proof_matrix.sh` - passed.
- `rg -n "e2e/admin-console.spec.js|e2e/admin-theme.spec.js|e2e/admin-actions.spec.js|e2e/admin-screenshots.spec.js|test-results/admin-screenshots" examples/adoption_demo/docs/adoption-proof-matrix.md scripts/maintainer/check_adoption_proof_matrix.sh examples/adoption_demo/README.md` - passed.
- Source assertion for `.github/workflows/ci.yml` job id, `needs`, repo guard, wrapper command, artifact path, and no stale `12/12 Playwright specs` wording - passed.
- Source assertion for no top-level `admin-screenshots` GitHub Actions job - passed.
- `MIX_ENV=test mix test test/rindle/runtime_status_task_test.exs` - passed, 10 tests.
- `cd examples/adoption_demo && npx playwright test e2e/ops-surfaces.spec.js` - passed, 1 test.
- `bash scripts/ci/adoption_demo_e2e.sh` - passed, 23 Playwright tests passed and 1 live GCS test skipped.
- `mix format --check-formatted mix.exs lib/mix/tasks/rindle.runtime_status.ex examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex` - passed.
- `mix precommit` - passed, 3 doctests and 1146 tests with 0 failures, 4 skipped, 56 excluded.

## Known Stubs

None introduced. The existing `optional demo placeholder` wording in the GCS proof-matrix row is documentation for a skipped live-provider path, not a new UI/data stub.

## Threat Flags

None. This plan updated documentation, drift checks, CI comments, and local deterministic verification paths. It did not introduce a new network endpoint, auth path, file-access trust boundary, or schema change.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 92 is ready for verification or Phase 93 truth/docs work with E2E-01 and E2E-02 proof wired into the existing adoption demo lane.

## Self-Check: PASSED

- Found `.planning/phases/92-e2e-screenshot-driven-polish-loop/92-05-SUMMARY.md`.
- Found `examples/adoption_demo/docs/adoption-proof-matrix.md`.
- Found `scripts/maintainer/check_adoption_proof_matrix.sh`.
- Found `examples/adoption_demo/README.md`.
- Found `.github/workflows/ci.yml`.
- Found task commits `1a0966a` and `c816cbe`.

---
*Phase: 92-e2e-screenshot-driven-polish-loop*
*Completed: 2026-06-13*
