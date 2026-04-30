---
phase: 17-api-surface-boundary-audit
plan: 02
subsystem: api
tags: [api-boundary, exdoc, internal-modules, docs]
requires:
  - phase: 17-api-surface-boundary-audit
    provides: boundary-harness tests and locked public/internal module decisions
provides:
  - helper-module `@moduledoc false` coverage for the D-05 infrastructure slice
  - explicit ExDoc module groups for the layered public API surface
  - public docs scrubbed of direct references to newly hidden helper modules
affects: [phase-17, exdoc-visibility, docs-onboarding, api-surface]
tech-stack:
  added: []
  patterns: [module-level hiding for internal helpers, explicit ExDoc groups_for_modules contract]
key-files:
  created: []
  modified: [mix.exs, lib/rindle/config.ex, lib/rindle/security/filename.ex, lib/rindle/security/mime.ex, lib/rindle/security/storage_key.ex, lib/rindle/security/upload_validation.ex, lib/rindle/profile/validator.ex, lib/rindle/profile/digest.ex, lib/rindle/storage/capabilities.ex, lib/rindle/storage.ex, lib/rindle/delivery.ex, guides/profiles.md, guides/storage_capabilities.md, guides/secure_delivery.md, test/rindle/api_surface_boundary_test.exs]
key-decisions:
  - "Hide D-05 helper modules with `@moduledoc false` directly instead of relying on ExDoc omission or per-function hiding."
  - "Keep `Rindle.Storage`, `Rindle.Storage.Local`, and `Rindle.Storage.S3` explicitly visible in the Storage Adapters group to honor D-03 over the older generic requirement wording."
  - "Remove public docs links to hidden helpers and inline the public storage capability type instead of re-exposing internal modules to satisfy docs warnings."
patterns-established:
  - "Boundary harness checks should be sliced by plan scope so focused verification can stay green while later boundary work remains pending."
  - "When internal helpers are hidden, public guides and public typespec docs must stop linking to those modules in the same slice."
requirements-completed: [API-03, API-04]
duration: 4min
completed: 2026-04-30
---

# Phase 17 Plan 02: API Surface Boundary Audit Summary

**Helper/security modules are now hidden from ExDoc and the generated API reference is organized into explicit facade-first public tiers without hiding the public storage adapters.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-30T19:02:18Z
- **Completed:** 2026-04-30T19:06:22Z
- **Tasks:** 2
- **Files modified:** 15

## Accomplishments

- Added `@moduledoc false` across the D-05 helper slice: runtime config, security helpers, profile helper modules, and storage capabilities.
- Added `groups_for_modules` in `mix.exs` so the visible API is grouped into facade, upload, delivery, integration, extension, storage, operations, and data-type tiers.
- Removed public guide and public typespec references to newly hidden internals so `mix docs --warnings-as-errors` passes cleanly.

## Task Commits

1. **Task 1: Hide the internal runtime and helper modules from ExDoc per D-05/D-07** - `eaee896` (`fix`)
2. **Task 2: Define ExDoc module groups for the layered public surface** - `ec43d39` (`fix`)

## Files Created/Modified

- `lib/rindle/config.ex`, `lib/rindle/security/*.ex`, `lib/rindle/profile/{validator,digest}.ex`, `lib/rindle/storage/capabilities.ex` - Hidden the implementation-only helper slice with module-level doc suppression.
- `test/rindle/api_surface_boundary_test.exs` - Split hidden-module assertions by helper/domain/ops slices so focused plan verification can target the current boundary work.
- `mix.exs` - Added the ExDoc `groups_for_modules` contract for the intentional public surface.
- `lib/rindle/storage.ex`, `lib/rindle/delivery.ex`, `guides/profiles.md`, `guides/storage_capabilities.md`, `guides/secure_delivery.md` - Removed public references to hidden helpers and kept the public docs build warning-free.

## Decisions Made

- Used module-level hiding for helper modules exactly as D-05/D-07 require instead of trying to hide individual functions.
- Treated the storage adapters as explicit public API and grouped them visibly in ExDoc despite older roadmap/requirements wording that suggested hiding them.
- Kept the public docs contract honest by rewriting hidden-module references instead of backing away from `@moduledoc false`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Split boundary harness hidden-module assertions by plan slice**
- **Found during:** Task 1
- **Issue:** The plan's focused verification file still bundled helper, domain, ops, and facade expectations together, so `17-02` could not verify its own slice without failing on later-plan work.
- **Fix:** Split the hidden-module checks into helper, domain, and ops tests so this plan can target only the relevant helper assertions while preserving later checks.
- **Files modified:** `test/rindle/api_surface_boundary_test.exs`
- **Verification:** `MIX_ENV=test mix test test/rindle/api_surface_boundary_test.exs:61 test/rindle/api_surface_boundary_test.exs:68 --trace`
- **Committed in:** `eaee896`

**2. [Rule 3 - Blocking] Removed public docs links to newly hidden helper modules**
- **Found during:** Task 2
- **Issue:** `mix docs --warnings-as-errors` failed because public guides and public module docs still referenced `Rindle.Config`, `Rindle.Profile.Validator`, and `Rindle.Storage.Capabilities` after they were hidden.
- **Fix:** Reworded the affected docs and inlined the public `Rindle.Storage.capability/0` union so generated docs no longer link to hidden modules.
- **Files modified:** `guides/profiles.md`, `guides/storage_capabilities.md`, `guides/secure_delivery.md`, `lib/rindle/delivery.ex`, `lib/rindle/storage.ex`
- **Verification:** `mix docs --warnings-as-errors`
- **Committed in:** `ec43d39`

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Both fixes were required to make the planned verification commands meaningful after the helper modules became internal. No scope expansion beyond keeping the public docs contract consistent.

## Issues Encountered

- Focused test runs continued to emit unrelated local Postgres `too_many_connections` noise from startup, but the targeted boundary assertions still executed and produced reliable pass/fail results.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The helper-module visibility boundary is now enforced in both code and generated docs.
- Future Phase 17 plans can use the split boundary harness to turn the remaining domain, facade/shim, and ops visibility checks green without reworking this slice.

## Self-Check: PASSED

- Found `.planning/phases/17-api-surface-boundary-audit/17-02-SUMMARY.md`
- Found commit `eaee896`
- Found commit `ec43d39`

---
*Phase: 17-api-surface-boundary-audit*
*Completed: 2026-04-30*
