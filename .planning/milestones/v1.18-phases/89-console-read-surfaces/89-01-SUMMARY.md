---
phase: 89-console-read-surfaces
plan: "01"
subsystem: admin-console
tags: [phoenix-liveview, router, admin-console, optional-deps, security]

requires:
  - phase: 88-admin-design-system-ui-kit
    provides: token-generated admin CSS and console UI package boundary
provides:
  - Guarded `Rindle.Admin.Router.rindle_admin/2` mount macro
  - Production-safe host-auth mount validation
  - Namespaced `Plug.Static` route for Rindle Admin assets
  - Public API boundary proof for the router module
affects: [89-console-read-surfaces, admin-console, optional-dependency-matrix]

tech-stack:
  added: []
  patterns:
    - Top-level `Code.ensure_loaded?/1` guard for optional LiveView admin modules
    - Compile-time router option normalization with production auth refusal
    - Host-owned LiveView `:on_mount` and session config pass-through

key-files:
  created:
    - lib/rindle/admin/router.ex
    - test/rindle/admin/router_test.exs
  modified:
    - test/rindle/api_surface_boundary_test.exs

key-decisions:
  - "Rindle Admin production mounts require non-empty `:on_mount` or explicit `auth_guarded?: true`."
  - "`allow_unauthenticated?: true` is accepted only outside production."
  - "Phoenix/LiveView and `Plug.Static` references stay behind the top-level optional dependency guard."

patterns-established:
  - "Router macro: host apps import `Rindle.Admin.Router` and call `rindle_admin/2` inside their own authenticated scope."
  - "Mount config: `:home_path`, `:live_socket_path`, `:transport`, and `:csp_nonce_assign_key` are preserved in LiveView session data."

requirements-completed: [ADMIN-01, ADMIN-06]

duration: 6min
completed: 2026-06-12
---

# Phase 89 Plan 01: Mount Router Macro and Safe Host-Auth Boundary Summary

**Host-authenticated Rindle Admin router macro with production-safe mount validation and optional LiveView compile-away proof**

## Performance

- **Duration:** 6 min
- **Started:** 2026-06-12T14:46:30Z
- **Completed:** 2026-06-12T14:52:43Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added `Rindle.Admin.Router.rindle_admin/2` as the mountable admin console boundary.
- Enforced production mount safety: host `:on_mount` or `auth_guarded?: true` is required, and `allow_unauthenticated?: true` is rejected in production.
- Expanded the initial console read routes and a namespaced `Plug.Static` route from `{:rindle, "priv/static/rindle_admin"}` with an exact asset allowlist.
- Added router contract tests and public API boundary coverage while keeping `Rindle.Admin.Queries` out of the public allowlist.
- Verified default/no-LiveView compilation with `mix compile --no-optional-deps --warnings-as-errors`.

## Task Commits

1. **Task 1: Define router contract tests and public boundary** - `e528c26` (test)
2. **Task 2: Implement guarded router macro** - `02f0118` (feat)

## Files Created/Modified

- `lib/rindle/admin/router.ex` - Guarded router macro, option normalization, production auth validation, LiveView route expansion, and static asset route.
- `test/rindle/admin/router_test.exs` - TDD contract tests for mount validation, option preservation, route expansion, and static asset allowlist.
- `test/rindle/api_surface_boundary_test.exs` - Adds `Rindle.Admin.Router` as the only new public admin module for this plan.

## Decisions Made

- Used `auth_guarded?: true` as the explicit host-auth acknowledgement when a host does not provide `:on_mount` directly in the macro options.
- Kept `allow_unauthenticated?: true` as a dev/test-only escape hatch and rejected it before route expansion in production.
- Passed host integration options through LiveView session config so later LiveViews can render links/assets without relying on host global state.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Expanded aliases inside macro option values**
- **Found during:** Task 2 (Implement guarded router macro)
- **Issue:** Phoenix LiveView rejected `on_mount: [HostAuth]` because the macro was passing unresolved alias AST to `live_session`.
- **Fix:** Added option AST traversal to expand aliases with the caller environment before validation and route expansion.
- **Files modified:** `lib/rindle/admin/router.ex`
- **Verification:** `MIX_ENV=test mix test test/rindle/admin/router_test.exs test/rindle/api_surface_boundary_test.exs`
- **Committed in:** `02f0118`

**2. [Rule 1 - Bug] Aligned route assertions with Phoenix route metadata**
- **Found during:** Task 2 (Implement guarded router macro)
- **Issue:** Phoenix stores LiveView route target modules in `route.metadata[:phoenix_live_view]` and `Plug.Static` options in `plug_opts`, not in the originally assumed fields.
- **Fix:** Updated router tests to assert against Phoenix's actual route struct shape and added minimal test-only LiveView modules to avoid undefined-module warnings.
- **Files modified:** `test/rindle/admin/router_test.exs`
- **Verification:** `MIX_ENV=test mix test test/rindle/admin/router_test.exs test/rindle/api_surface_boundary_test.exs`
- **Committed in:** `02f0118`

---

**Total deviations:** 2 auto-fixed (2 Rule 1 bugs)
**Impact on plan:** Both fixes were necessary to verify the intended contract against Phoenix's real macro expansion behavior. No scope was added.

## Issues Encountered

None beyond the auto-fixed implementation/test alignment issues above.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None.

## Next Phase Readiness

Ready for Plan 89-02 to package the self-contained admin assets under `priv/static/rindle_admin` and prove Hex/package inclusion.

## Verification

- `MIX_ENV=test mix test test/rindle/admin/router_test.exs test/rindle/api_surface_boundary_test.exs` - passed, 25 tests, 0 failures
- `MIX_ENV=test mix compile --warnings-as-errors` - passed
- `MIX_ENV=test mix compile --no-optional-deps --warnings-as-errors` - passed
- `awk 'BEGIN{guard=0;bad=0} /Code.ensure_loaded\\?\\(Phoenix.LiveView\\)/{guard=1} /Phoenix\\.|LiveView|Plug\\.Static/{if (!guard && $0 !~ /Code.ensure_loaded/) bad=1} END{exit bad}' lib/rindle/admin/router.ex` - passed

## Self-Check: PASSED

- Found created files: `lib/rindle/admin/router.ex`, `test/rindle/admin/router_test.exs`
- Found modified file: `test/rindle/api_surface_boundary_test.exs`
- Found task commits: `e528c26`, `02f0118`

---
*Phase: 89-console-read-surfaces*
*Completed: 2026-06-12*
