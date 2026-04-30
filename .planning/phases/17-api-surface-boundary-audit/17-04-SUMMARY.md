---
phase: 17-api-surface-boundary-audit
plan: 04
subsystem: api
tags: [facade, semver, docs, compatibility]
requires:
  - phase: 17-api-surface-boundary-audit
    provides: hidden helper/domain/ops visibility plus the boundary harness from plans 17-02, 17-03, and 17-05
provides:
  - preferred `Rindle.verify_completion/2` facade alias with `0.1.x` compatibility docs on `verify_upload/2`
  - hidden `Rindle.Internal.VariantFailureLogger` behind an undocumented public shim
  - facade-first onboarding docs centered on `Rindle` and `Rindle.Profile`
  - phase-local semver decision artifact for the `0.1.x` to `v0.2.0` boundary
affects: [phase-17, facade-naming, onboarding-docs, semver-policy, liveview]
tech-stack:
  added: []
  patterns: [facade-first compatibility aliasing, hidden internal helper behind public shim, phase-local semver contract artifact]
key-files:
  created:
    - lib/rindle/internal/variant_failure_logger.ex
    - .planning/phases/17-api-surface-boundary-audit/17-BREAKING-CHANGE-DECISION.md
    - .planning/phases/17-api-surface-boundary-audit/17-04-SUMMARY.md
  modified:
    - lib/rindle.ex
    - lib/rindle/live_view.ex
    - README.md
    - guides/getting_started.md
    - test/rindle/api_surface_boundary_test.exs
    - test/rindle/live_view_test.exs
key-decisions:
  - "Keep `verify_upload/2` documented on `0.1.x` with `@doc deprecated` metadata instead of hiding it, because the locked plan chose additive compatibility over silent removal."
  - "Leave `Rindle.Upload.Broker.sign_url/1` as the transport-specific presign step in docs while still centering onboarding on `Rindle` and `Rindle.Profile`, because the facade does not yet expose signing."
  - "Move variant failure logging into `Rindle.Internal.VariantFailureLogger` and keep the facade entrypoint `@doc false` so telemetry remains the public observability story."
patterns-established:
  - "When shared boundary tests get ahead of the current task, narrow verification to the task-owned assertions rather than treating future-plan expectations as regressions."
  - "Semver-sensitive cleanup on a published `0.1.x` line should favor additive aliases plus explicit decision artifacts over in-place removals."
requirements-completed: [API-01, API-02, API-03, API-05]
duration: 5min
completed: 2026-04-30
---

# Phase 17 Plan 04: API Surface Boundary Audit Summary

**Facade verification now lands on `Rindle.verify_completion/2`, onboarding teaches `Rindle` plus `Rindle.Profile`, and the hidden logging shim/semver contract close the remaining public-surface cleanup.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-30T19:17:00Z
- **Completed:** 2026-04-30T19:22:28Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Added `Rindle.verify_completion/2` as the canonical facade name and kept `verify_upload/2` as a documented `0.1.x` compatibility shim.
- Updated `Rindle.LiveView` and the boundary harness to teach the preferred verification path while keeping multipart naming unchanged.
- Moved variant failure logging behind a hidden internal module, rewrote onboarding docs around `Rindle` and `Rindle.Profile`, and recorded the `0.1.x` to `v0.2.0` breaking-change boundary.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add the preferred facade verification alias and align LiveView/tests** - `ac9a9c7` (`test`), `9cc690f` (`feat`)
2. **Task 2: Hide the logging helper, rewrite onboarding docs, and record the semver decision** - `001407c` (`test`), `1c6e9fa` (`fix`)

## Files Created/Modified

- `lib/rindle.ex` - Added the preferred `verify_completion/2` facade, kept `verify_upload/2` as a deprecated-doc compatibility shim, and hid the logging shim with a thin delegate.
- `lib/rindle/live_view.ex` - Switched the LiveView verification call and docs to `Rindle.verify_completion/2`.
- `lib/rindle/internal/variant_failure_logger.ex` - Added the hidden implementation module that owns the structured error log emission.
- `README.md`, `guides/getting_started.md` - Reframed onboarding around `Rindle` and `Rindle.Profile`, with the broker only called out for the presign transport step.
- `test/rindle/api_surface_boundary_test.exs`, `test/rindle/live_view_test.exs` - Locked the facade alias, compatibility-doc posture, hidden logger module, and LiveView documentation contract.
- `.planning/phases/17-api-surface-boundary-audit/17-BREAKING-CHANGE-DECISION.md` - Recorded the public allowlist, D-03 storage adapter override, additive `0.1.x` posture, and `v0.2.0` deferrals.

## Decisions Made

- Kept `verify_upload/2` visible in docs with explicit deprecation metadata instead of hiding it, because the locked phase context requires additive guidance on the already-published `0.1.x` line.
- Preserved `complete_multipart_upload/3` unchanged and treated `sign_url/1` as an advanced transport step, because forcing symmetry there would blur the direct-upload versus multipart boundary.
- Hid `log_variant_processing_failure/3` from docs by moving the implementation behind a dedicated internal module rather than leaving logging behavior on the public facade.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Replaced the plan's invalid `mix test ... -x` verification with supported focused runs**
- **Found during:** Task 1 and Task 2 verification
- **Issue:** Mix 1.19.5 rejects the legacy `-x` flag used in the plan and validation files.
- **Fix:** Ran supported `--trace` verification, and for Task 1 narrowed the run to the facade-specific assertions so the still-pending Task 2 logging-shim expectation did not block the earlier task.
- **Files modified:** None
- **Verification:** `MIX_ENV=test mix test test/rindle/api_surface_boundary_test.exs:91 test/rindle/api_surface_boundary_test.exs:98 test/rindle/api_surface_boundary_test.exs:103 test/rindle/live_view_test.exs --trace`; `MIX_ENV=test mix test test/rindle/api_surface_boundary_test.exs test/rindle/live_view_test.exs test/install_smoke/docs_parity_test.exs --trace`
- **Committed in:** Not applicable (verification-only deviation)

**2. [Rule 1 - Bug] Corrected the boundary harness to match the locked `0.1.x` compatibility posture**
- **Found during:** Task 1 implementation
- **Issue:** The existing boundary test expected `verify_upload/2` to disappear from docs, but the locked plan explicitly kept it as a documented legacy shim with deprecation guidance.
- **Fix:** Updated the boundary harness to assert public visibility plus deprecation metadata for `verify_upload/2`, leaving only the logging shim hidden.
- **Files modified:** `test/rindle/api_surface_boundary_test.exs`
- **Verification:** `MIX_ENV=test mix test test/rindle/api_surface_boundary_test.exs:91 test/rindle/api_surface_boundary_test.exs:98 test/rindle/api_surface_boundary_test.exs:103 --trace`
- **Committed in:** `9cc690f`

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug)
**Impact on plan:** Both fixes were necessary to keep the TDD contract aligned with the locked semver posture and with the current Mix toolchain. No scope expansion beyond plan intent.

## Issues Encountered

- Targeted test runs continued to emit local Postgres `too_many_connections` noise from Oban/Postgrex startup, but the boundary and docs parity assertions still executed and passed reliably.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 17 is now fully implemented: the facade naming cleanup, hidden helper posture, and breaking-change decision are all recorded and verified.
- Phase 18 can use the new decision artifact and facade-first docs as the stable contract for broad `@doc` and `@spec` coverage work.

## Self-Check: PASSED

- Found `.planning/phases/17-api-surface-boundary-audit/17-04-SUMMARY.md`
- Found `.planning/phases/17-api-surface-boundary-audit/17-BREAKING-CHANGE-DECISION.md`
- Found `lib/rindle/internal/variant_failure_logger.ex`
- Found commit `ac9a9c7`
- Found commit `9cc690f`
- Found commit `001407c`
- Found commit `1c6e9fa`

---
*Phase: 17-api-surface-boundary-audit*
*Completed: 2026-04-30*
