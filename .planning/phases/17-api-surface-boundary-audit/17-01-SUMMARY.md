---
phase: 17-api-surface-boundary-audit
plan: 01
subsystem: testing
tags: [api-boundary, exdoc, docs, smoke-tests, tdd]
requires:
  - phase: 17-api-surface-boundary-audit
    provides: locked boundary decisions from 17-CONTEXT.md and wave-0 validation targets
provides:
  - boundary-harness tests for the public allowlist, hidden denylist, and facade shim expectations
  - facade-first docs parity smoke coverage for README and getting_started.md
affects: [phase-17, exdoc-visibility, docs-onboarding, api-surface]
tech-stack:
  added: []
  patterns: [compiled-doc boundary assertions via Code.fetch_docs, facade-first docs parity smoke tests]
key-files:
  created: [test/rindle/api_surface_boundary_test.exs]
  modified: [test/install_smoke/docs_parity_test.exs]
key-decisions:
  - "Keep plan 17-01 as RED-only TDD commits because this plan's output is failing harness coverage, not implementation."
  - "Use mix test --trace for verification because Mix 1.19.5 rejects the plan's legacy -x flag."
patterns-established:
  - "Boundary audits should assert moduledoc visibility directly from compiled docs instead of manual ExDoc review."
  - "Onboarding parity tests should enforce the facade path and reject broker-first introductory guidance."
requirements-completed: [API-01, API-02, API-03, API-04]
duration: 7min
completed: 2026-04-30
---

# Phase 17 Plan 01: API Surface Boundary Audit Summary

**Wave-0 RED harnesses now lock the Phase 17 API boundary in tests through compiled-doc visibility checks and facade-first docs parity assertions.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-04-30T18:54:30Z
- **Completed:** 2026-04-30T19:01:44Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Added `test/rindle/api_surface_boundary_test.exs` to encode the public module allowlist, hidden internal denylist, and facade alias/shim expectations from `17-CONTEXT.md`.
- Recast `test/install_smoke/docs_parity_test.exs` around the facade-first onboarding story so README and getting-started must teach `Rindle` and `Rindle.Profile` first.
- Verified both focused RED commands compile and fail on the intended missing Phase 17 implementation work instead of syntax or harness-shape errors.

## Task Commits

1. **Task 1: Create the API surface audit harness from the locked boundary lists** - `428d6fe` (`test`)
2. **Task 2: Recast docs parity tests around the facade-first onboarding story** - `d04c7ab` (`test`)

## Files Created/Modified

- `test/rindle/api_surface_boundary_test.exs` - Compiled-doc boundary harness for public modules, hidden modules, and facade export/doc expectations.
- `test/install_smoke/docs_parity_test.exs` - Smoke assertions for facade-first onboarding and negative checks against broker-first introductory guidance.

## Decisions Made

- Kept both tasks as RED-only TDD commits because the plan explicitly delivers failing coverage before implementation plans land.
- Treated the plan's `mix test ... -x` verify commands as stale and used `mix test ... --trace` on Mix 1.19.5 to preserve equivalent focused verification.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Swapped invalid Mix `-x` verification flag for `--trace`**
- **Found during:** Task 1 verification
- **Issue:** `mix test` on Mix 1.19.5 rejects `-x`, so the plan's scripted verification command could not run.
- **Fix:** Re-ran both task verifications with `MIX_ENV=test mix test ... --trace`.
- **Files modified:** None
- **Verification:** Focused RED runs executed successfully and produced only the intended contract failures.
- **Committed in:** Not applicable (verification-only deviation)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** No scope change. The deviation only updated the verification invocation to match the installed Mix CLI.

## Issues Encountered

- Focused test runs emitted unrelated Postgres `too_many_connections` startup noise from Oban/Postgrex, but ExUnit still executed the target files and surfaced the expected RED failures.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 17 now has executable Wave 0 coverage for API boundary visibility, naming-shim expectations, and facade-first onboarding parity.
- The next implementation plans can turn these RED harnesses green by hiding internal modules, adding `Rindle.verify_completion/2`, and rewriting the public docs path.

## Self-Check: PASSED

- Found `.planning/phases/17-api-surface-boundary-audit/17-01-SUMMARY.md`
- Found commit `428d6fe`
- Found commit `d04c7ab`

---
*Phase: 17-api-surface-boundary-audit*
*Completed: 2026-04-30*
