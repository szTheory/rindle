---
phase: 89-console-read-surfaces
plan: "03"
subsystem: admin-query-boundary
tags: [elixir, ecto, admin-console, runtime-status, redaction]

requires:
  - phase: 89-console-read-surfaces
    provides: "89-01 mountable admin router boundary"
provides:
  - "Rindle.Admin.Queries read boundary for Phase 89 console surfaces"
  - "Admin query tests for read models, filtering, redaction, and facade isolation"
  - "API boundary guard keeping admin read helpers out of the public Rindle facade"
affects: [phase-89-liveviews, phase-90-actions, admin-console, runtime-ops]

tech-stack:
  added: []
  patterns:
    - "Read-only admin query composition through Rindle.Config.repo/0"
    - "UI-facing redaction copy for upload session URIs and provider identifiers"

key-files:
  created:
    - lib/rindle/admin/queries.ex
    - test/rindle/admin/queries_test.exs
  modified:
    - test/rindle/api_surface_boundary_test.exs

key-decisions:
  - "89-03 keeps admin read composition in Rindle.Admin.Queries with exactly seven /1 query functions plus actions_directory/0."
  - "89-03 returns UI-facing redaction copy instead of shortened provider IDs where provider identifiers would otherwise be exposed."
  - "89-03 keeps actions_directory/0 read-only and disabled for Phase 90-owned operation flows."

patterns-established:
  - "Admin query filters normalize atom/string keys through explicit allowlists and reject unknown keys with {:unknown_filters, keys}."
  - "Console detail read models map domain rows into plain maps before LiveViews render them."

requirements-completed: [ADMIN-03, ADMIN-05]

duration: 7min
completed: 2026-06-12
---

# Phase 89 Plan 03: Admin Query Boundary Summary

**Read-only Rindle.Admin.Queries boundary with redacted console read models for status, assets, uploads, variants/jobs, runtime doctor, and actions metadata**

## Performance

- **Duration:** 7 min
- **Started:** 2026-06-12T15:05:17Z
- **Completed:** 2026-06-12T15:11:30Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added `Rindle.Admin.Queries` with the planned read-only exports: `home_status/1`, `assets/1`, `asset_detail/1`, `upload_sessions/1`, `upload_session_detail/1`, `variants_jobs/1`, `runtime_doctor/1`, and `actions_directory/0`.
- Added focused admin query tests covering filters, detail composition, runtime/doctor composition, read-only action metadata, upload `session_uri` redaction, provider ID redaction, and unknown-filter rejection.
- Extended the API surface boundary test so `Rindle.Admin.Queries` is hidden/internal and no `Rindle.admin_*` facade helpers are exported.

## Task Commits

1. **Task 1: Add admin query tests and boundary assertions** - `00c063e` (test)
2. **Task 2: Implement Rindle.Admin.Queries** - `60a9523` (feat)

## Files Created/Modified

- `lib/rindle/admin/queries.ex` - Internal admin read-model boundary using `Config.repo()`, `RuntimeStatus.runtime_status/1`, and `RuntimeChecks.run/2`.
- `test/rindle/admin/queries_test.exs` - Query, redaction, filter, detail, runtime, and action-directory tests.
- `test/rindle/api_surface_boundary_test.exs` - Hidden-module assertion and facade guard for admin read helpers.

## Decisions Made

- Kept the export surface to exactly the planned functions: seven `/1` functions plus `actions_directory/0`; no default-arity convenience exports were left behind.
- Used UI-facing redaction copy, `Redacted by Rindle Admin` and `Provider identifier redacted`, before returning read models to LiveViews.
- Kept Phase 90 operations represented only as disabled, read-only metadata with no MFA, callback, or executable function reference.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added Mox storage capability stubs to doctor query tests**
- **Found during:** Task 2
- **Issue:** `RuntimeChecks.run/2` correctly invokes profile storage adapter capabilities, and the new tests had not stubbed `Rindle.StorageMock.capabilities/0`.
- **Fix:** Added Mox setup and per-test `capabilities/0` stubs for the two doctor-backed query tests.
- **Files modified:** `test/rindle/admin/queries_test.exs`
- **Verification:** `MIX_ENV=test mix test test/rindle/admin/queries_test.exs test/rindle/api_surface_boundary_test.exs`
- **Committed in:** `60a9523`

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Test setup only; production behavior stayed on the planned runtime/doctor API path.

## Issues Encountered

- The plan's combined grep command against both `lib/rindle.ex` and `lib/rindle/admin/queries.ex` flags pre-existing lifecycle facade lines in `lib/rindle.ex` (`LifecycleRepair`, `Rindle.requeue_variants/2`, and owner-erasure docs). Those lines predate this plan and are intentional public operations. Targeted boundary checks passed: no admin helper defs were added to `lib/rindle.ex`, and `lib/rindle/admin/queries.ex` contains no destructive lifecycle references.

## Verification

- `MIX_ENV=test mix test test/rindle/admin/queries_test.exs test/rindle/api_surface_boundary_test.exs` - passed, 25 tests.
- `MIX_ENV=test mix test test/rindle/ops/runtime_status_test.exs` - passed, 17 tests.
- `MIX_ENV=test mix compile --no-optional-deps --warnings-as-errors` - passed.
- Source assertion: `Rindle.Admin.Queries.__info__(:functions)` returns exactly the eight planned exports.
- Source assertion: `lib/rindle/admin/queries.ex` contains `@moduledoc false`, `Config.repo()`, `RuntimeStatus.runtime_status`, and `RuntimeChecks.run`.
- Source assertion: targeted grep found no `Rindle.erase_`, `Rindle.preview_`, `Rindle.requeue`, `LifecycleRepair`, or `VariantMaintenance` references in `lib/rindle/admin/queries.ex`.

## Known Stubs

None.

## Threat Flags

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 89 LiveViews can now consume stable read models from `Rindle.Admin.Queries`. Phase 90 action flows have a disabled metadata directory to build from without introducing mutation callbacks in Phase 89.

## Self-Check: PASSED

- Found `lib/rindle/admin/queries.ex`
- Found `test/rindle/admin/queries_test.exs`
- Found `test/rindle/api_surface_boundary_test.exs`
- Found `.planning/phases/89-console-read-surfaces/89-03-SUMMARY.md`
- Found task commit `00c063e`
- Found task commit `60a9523`

---
*Phase: 89-console-read-surfaces*
*Completed: 2026-06-12*
