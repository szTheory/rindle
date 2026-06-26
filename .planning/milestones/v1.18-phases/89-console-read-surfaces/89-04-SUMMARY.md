---
phase: 89-console-read-surfaces
plan: "04"
subsystem: admin-console-ui
tags: [phoenix-liveview, admin-console, read-surfaces, pubsub, redaction, tdd]

requires:
  - phase: 89-console-read-surfaces
    provides: "89-01 guarded Rindle.Admin.Router.rindle_admin/2 mount boundary"
  - phase: 89-console-read-surfaces
    provides: "89-02 packaged rindle-admin static CSS/JS/assets"
  - phase: 89-console-read-surfaces
    provides: "89-03 Rindle.Admin.Queries read models"
provides:
  - "Guarded Rindle.Admin.Components shell and shared console components"
  - "Home/Status, Assets, and Upload Sessions read LiveViews"
  - "Query-backed PubSub invalidation for visible asset and upload-session details"
  - "Focused LiveView tests for selectors, navigation, filters, redaction, and refresh behavior"
affects: [phase-89-console-read-surfaces, phase-90-actions, phase-92-e2e, admin-console]

tech-stack:
  added:
    - "lazy_html >= 0.1.0 as a test-only Phoenix.LiveViewTest parser dependency"
  patterns:
    - "Top-level Code.ensure_loaded?/1 guards around Phoenix.Component and Phoenix.LiveView modules"
    - "Rindle Admin shell/components render namespaced BEM classes and stable data-rindle-admin-* selectors"
    - "LiveView PubSub handlers ignore payload fields and re-query Rindle.Admin.Queries"

key-files:
  created:
    - lib/rindle/admin/components.ex
    - lib/rindle/admin/live/home_live.ex
    - lib/rindle/admin/live/assets_live.ex
    - lib/rindle/admin/live/upload_sessions_live.ex
    - test/rindle/admin/live/home_assets_upload_test.exs
  modified:
    - lib/rindle/admin/router.ex
    - test/rindle/admin/router_test.exs
    - mix.exs
    - mix.lock

key-decisions:
  - "89-04 keeps the first read surfaces guarded behind optional Phoenix dependencies while still proving real LiveView behavior in tests."
  - "89-04 uses exact packaged static asset routes so /assets/:id detail pages do not conflict with /assets/rindle-admin.css style URLs."
  - "89-04 adds lazy_html only for tests because Phoenix.LiveViewTest 1.1 requires it for DOM parsing."

patterns-established:
  - "Read LiveViews call Rindle.Admin.Queries for mount/param loads and again after {:rindle_event, _, _} invalidation."
  - "Detail LiveViews subscribe only to visible asset, variant, and upload-session topics from the query result."
  - "Shared shell exposes the six locked surfaces, active aria-current, theme controls, live-update copy, and stable selectors."

requirements-completed: [ADMIN-03, ADMIN-05]

duration: 16min
completed: 2026-06-12
---

# Phase 89 Plan 04: Shared Shell and First Read Surfaces Summary

**Guarded Phoenix LiveView admin shell with query-backed Home/Status, Assets, and Upload Sessions read surfaces**

## Performance

- **Duration:** 16 min
- **Started:** 2026-06-12T15:15:39Z
- **Completed:** 2026-06-12T15:31:41Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Added `Rindle.Admin.Components` with the shared Rindle Admin shell, navigation, theme picker, status chip, filter, empty/error/loading, metadata, table, and redaction helpers.
- Added guarded `HomeLive`, `AssetsLive`, and `UploadSessionsLive` modules that render through `Rindle.Admin.Queries`.
- Added list/detail flows for assets and upload sessions, including filters, row actions, detail context, redacted session/provider values, and live-update copy.
- Added PubSub invalidation behavior that ignores forged payload fields and refreshes visible data through the query boundary.
- Added LiveView tests covering the shell, six locked nav surfaces, stable selectors, filters, detail routes, redaction, and forged secret payload handling.

## Task Commits

1. **Task 1: Add LiveView tests for shell, Home, Assets, and Upload Sessions** - `d6e5f75` (test)
2. **Task 2: Implement shared components and first three LiveViews** - `0d74283` (feat)

## Files Created/Modified

- `lib/rindle/admin/components.ex` - Guarded shared shell and reusable Rindle Admin UI components.
- `lib/rindle/admin/live/home_live.ex` - Home/Status read LiveView with runtime, doctor, count, recommendation, and primary investigation CTA rendering.
- `lib/rindle/admin/live/assets_live.ex` - Assets list/detail LiveView with filters, row actions, detail sections, and asset/variant/upload-session PubSub refresh.
- `lib/rindle/admin/live/upload_sessions_live.ex` - Upload Sessions list/detail LiveView with filters, redaction, expiration/failure guidance, and scoped PubSub refresh.
- `test/rindle/admin/live/home_assets_upload_test.exs` - TDD LiveView tests for shell, read surfaces, selectors, redaction, and query-refresh behavior.
- `lib/rindle/admin/router.ex` - Replaced broad static forwarding with exact static asset routes to avoid shadowing asset detail routes.
- `test/rindle/admin/router_test.exs` - Updated static route assertions for exact packaged asset routes.
- `mix.exs` / `mix.lock` - Added test-only `lazy_html` dependency required by Phoenix.LiveViewTest.

## Decisions Made

- Kept the first read LiveViews in package-owned modules guarded by `Code.ensure_loaded?(Phoenix.LiveView)` and shared components guarded by `Code.ensure_loaded?(Phoenix.Component)`.
- Used exact static routes for the four packaged admin assets rather than a broad `/assets` forward, because `/assets/:id` detail routes and `/assets/rindle-admin.css` static paths otherwise conflict.
- Added `lazy_html` as a test-only dependency because Phoenix LiveView 1.1 requires it for LiveViewTest DOM parsing.
- Kept Home/Status doctor rendering deterministic by passing explicit empty doctor profiles and a no-op probe.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added LiveViewTest DOM parser dependency**
- **Found during:** Task 2 (focused LiveView test execution)
- **Issue:** Phoenix.LiveViewTest 1.1 refused to run connected LiveView tests without `lazy_html`.
- **Fix:** Added `{:lazy_html, ">= 0.1.0", only: :test}` and resolved the exact package via `mix deps.get`.
- **Files modified:** `mix.exs`, `mix.lock`
- **Verification:** `MIX_ENV=test mix test test/rindle/admin/live/home_assets_upload_test.exs test/rindle/admin/queries_test.exs`
- **Committed in:** `0d74283`

**2. [Rule 1 - Bug] Fixed static asset route overlap with Assets detail**
- **Found during:** Task 2 (LiveView route verification)
- **Issue:** The prior broad `/assets` static forward either shadowed `/assets` list/detail LiveViews or let static filenames be interpreted as asset IDs, depending on route order.
- **Fix:** Replaced the broad static forward with exact routes for `rindle-admin.css`, `rindle-admin.js`, `logo.svg`, and `favicon.svg`, preserving `/assets/:id` for asset detail.
- **Files modified:** `lib/rindle/admin/router.ex`, `test/rindle/admin/router_test.exs`
- **Verification:** `MIX_ENV=test mix test test/rindle/admin/live/home_assets_upload_test.exs test/rindle/admin/queries_test.exs`; `MIX_ENV=test mix test test/rindle/admin/router_test.exs`; `MIX_ENV=test mix test test/rindle/admin/assets_test.exs`
- **Committed in:** `0d74283`

---

**Total deviations:** 2 auto-fixed (1 Rule 3 blocking, 1 Rule 1 bug)
**Impact on plan:** Both fixes were required to execute the planned LiveView tests and preserve packaged static asset serving. No destructive or public lifecycle semantics were added.

## TDD Gate Compliance

- RED commit present: `d6e5f75` (`test(89-04): add failing admin read LiveView tests`)
- GREEN commit present after RED: `0d74283` (`feat(89-04): implement admin read LiveViews`)
- RED gate failed as expected before implementation with missing `Rindle.Admin.Live.*` modules.

## Verification

- `MIX_ENV=test mix test test/rindle/admin/live/home_assets_upload_test.exs` - failed in RED before implementation; passed after Task 2.
- `MIX_ENV=test mix test test/rindle/admin/live/home_assets_upload_test.exs test/rindle/admin/queries_test.exs` - passed, 13 tests.
- `MIX_ENV=test mix test test/rindle/admin/router_test.exs` - passed, 8 tests.
- `MIX_ENV=test mix test test/rindle/admin/assets_test.exs` - passed, 2 tests.
- `MIX_ENV=test mix compile --warnings-as-errors` - passed.
- `MIX_ENV=test mix compile --no-optional-deps --warnings-as-errors` - passed.
- Forbidden dependency scan over `lib/rindle/admin/components.ex` and the three LiveView modules - passed.

## Known Stubs

None.

## Threat Flags

None. The new browser params, query rendering, and PubSub invalidation surfaces were covered by the plan threat model.

## Issues Encountered

- The existing router/static asset tests define placeholder LiveView modules and can conflict when compiled concurrently with other tests that define the same placeholders. They pass when run separately; later plans that implement the remaining surfaces should remove the need for those placeholders.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The shared shell, selector contract, query-refresh pattern, and first three read surfaces are ready for the remaining Phase 89 read surfaces and Phase 92 E2E selectors. Phase 90 can build action flows on the same shell without adding destructive controls to read surfaces.

## Self-Check: PASSED

- Found created files: `lib/rindle/admin/components.ex`, `lib/rindle/admin/live/home_live.ex`, `lib/rindle/admin/live/assets_live.ex`, `lib/rindle/admin/live/upload_sessions_live.ex`, `test/rindle/admin/live/home_assets_upload_test.exs`
- Found modified files: `lib/rindle/admin/router.ex`, `test/rindle/admin/router_test.exs`, `mix.exs`, `mix.lock`
- Found task commits: `d6e5f75`, `0d74283`

---
*Phase: 89-console-read-surfaces*
*Completed: 2026-06-12*
