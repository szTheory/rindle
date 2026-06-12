---
phase: 89-console-read-surfaces
plan: "02"
subsystem: ui
tags: [admin-console, static-assets, hex-package, plug-static, tdd]

requires:
  - phase: 88-admin-design-system-ui-kit
    provides: generated rindle-admin CSS and brand assets
  - phase: 89-console-read-surfaces
    provides: guarded Rindle.Admin.Router.rindle_admin/2 mount boundary
provides:
  - packaged Rindle Admin static assets under priv/static/rindle_admin
  - Hex package metadata coverage for admin CSS, JavaScript, logo, and favicon
  - static route proof for allowlisted admin asset serving and denied unlisted paths
affects: [phase-89-console-read-surfaces, phase-90-actions, phase-92-e2e]

tech-stack:
  added: []
  patterns:
    - generated CSS copied byte-for-byte from brandbook/tokens/rindle-admin.css
    - self-contained root-scoped admin theme JavaScript
    - package metadata tests verify real mix hex.build --unpack output

key-files:
  created:
    - priv/static/rindle_admin/rindle-admin.css
    - priv/static/rindle_admin/rindle-admin.js
    - priv/static/rindle_admin/logo.svg
    - priv/static/rindle_admin/favicon.svg
    - test/rindle/admin/assets_test.exs
  modified:
    - mix.exs
    - test/install_smoke/package_metadata_test.exs
    - test/brandbook/admin_design_system_validation_test.exs

key-decisions:
  - "89-02 keeps generated admin CSS byte-identical to brandbook/tokens/rindle-admin.css and treats brandbook generators as source of truth."
  - "89-02 packages only priv/static/rindle_admin, preserving the explicit priv/repo/migrations package boundary instead of broadening to all priv."
  - "89-02 uses a self-contained JavaScript theme controller scoped to data-rindle-admin-root with an exact light/dark/auto allowlist."

patterns-established:
  - "Admin static assets ship from priv/static/rindle_admin with no host asset-pipeline dependency."
  - "Static asset route tests exercise the Rindle.Admin.Router mount boundary with auth_guarded?: true."
  - "Package proof extends install-smoke metadata assertions with exact shipped asset paths."

requirements-completed: [ADMIN-02]

duration: 5min
completed: 2026-06-12
---

# Phase 89 Plan 02: Package Admin Static Assets Summary

**Self-contained Rindle Admin CSS, JavaScript, logo, and favicon now ship from priv/static/rindle_admin and are proven in Hex package output.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-06-12T14:57:15Z
- **Completed:** 2026-06-12T15:01:37Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Packaged `rindle-admin.css`, `rindle-admin.js`, `logo.svg`, and `favicon.svg` under `priv/static/rindle_admin`.
- Kept packaged CSS byte-identical to `brandbook/tokens/rindle-admin.css` after running the Phase 88 generator.
- Added a root-scoped vanilla theme controller that only writes `data-theme="light|dark|auto"` and synchronizes `aria-pressed`.
- Updated `mix.exs` to include `priv/static/rindle_admin` without broadening the package file list to all `priv`.
- Added tests proving allowlisted static serving, denied traversal/unlisted names, package metadata inclusion, and generated CSS parity.

## Task Commits

1. **Task 1: Copy generated assets into package static path** - `f1d8842` (feat)
2. **Task 2 RED: Prove static serving and Hex package inclusion** - `43a3a8a` (test)
3. **Task 2 GREEN: Prove static serving and Hex package inclusion** - `3e0f379` (feat)

## Files Created/Modified

- `priv/static/rindle_admin/rindle-admin.css` - Generated admin CSS copied from the brandbook artifact.
- `priv/static/rindle_admin/rindle-admin.js` - Self-contained admin theme behavior for mounted console roots.
- `priv/static/rindle_admin/logo.svg` - Packaged Rindle logo asset.
- `priv/static/rindle_admin/favicon.svg` - Packaged Rindle favicon asset.
- `mix.exs` - Package file allowlist now includes `priv/static/rindle_admin`.
- `test/rindle/admin/assets_test.exs` - Host router fixture tests static asset serving and denied asset names.
- `test/install_smoke/package_metadata_test.exs` - Required package paths now include all four admin static files.
- `test/brandbook/admin_design_system_validation_test.exs` - ADMIN-02 boundary assertion is now positive and checks packaged CSS parity.

## Decisions Made

- Kept `priv/static/rindle_admin` as the exact package boundary instead of `priv`, so package contents remain explicit.
- Treated the bare router test's unsent `Plug.Static` miss as the host endpoint's final 404 in the test helper; this proves unlisted names are not served while preserving the Plan 01 router boundary.
- Did not add any frontend, registry, build, or host asset dependency.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Adjusted static miss assertion for bare router testing**
- **Found during:** Task 2 (RED test execution)
- **Issue:** A disallowed `Plug.Static` path was not served, but the bare router fixture returned an unsent connection instead of an HTTP 404.
- **Fix:** The test helper now converts an unsent fixture response into `404`, matching the host endpoint final-response behavior while still proving traversal and unlisted files are not served.
- **Files modified:** `test/rindle/admin/assets_test.exs`
- **Verification:** Focused test suite passes and disallowed paths assert `404`.
- **Committed in:** `43a3a8a`

**Total deviations:** 1 auto-fixed (Rule 1)
**Impact on plan:** Test-only fixture correction; production router behavior and package scope stayed as planned.

## TDD Gate Compliance

- RED commit present: `43a3a8a` (`test(89-02): add admin asset package proofs`)
- GREEN commit present after RED: `3e0f379` (`feat(89-02): include admin assets in package metadata`)
- RED gate failed as expected before implementation on missing `priv/static/rindle_admin/rindle-admin.css` package metadata.

## Verification

- `node brandbook/src/admin-css-build.mjs`
- `node brandbook/src/admin-contrast.mjs`
- `cmp brandbook/tokens/rindle-admin.css priv/static/rindle_admin/rindle-admin.css`
- `MIX_ENV=test mix test test/rindle/admin/assets_test.exs test/install_smoke/package_metadata_test.exs test/brandbook/admin_design_system_validation_test.exs`
- `MIX_ENV=test mix test test/brandbook/admin_design_system_validation_test.exs --include integration`
- `MIX_ENV=test mix compile --no-optional-deps --warnings-as-errors`
- `MIX_ENV=dev mix hex.build --unpack --output "$PACKAGE_CHECK_DIR/rindle-package-check"` plus file existence checks for all four admin assets

## Known Stubs

None. Stub scan found only test/package assertion literals, not runtime stubs.

## Threat Flags

None. The plan already covered the new static asset serving, package metadata, and admin DOM mutation surfaces.

## Issues Encountered

- The initial RED fixture used deprecated `use Plug.Test` and an incompatible Phoenix fallback route form; both were corrected inside the RED test commit before implementation.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

ADMIN-02 package and serving proof is complete. Later Phase 89 plans can consume `/assets/rindle-admin.css`, `/assets/rindle-admin.js`, `/assets/logo.svg`, and `/assets/favicon.svg` through the existing `Rindle.Admin.Router.rindle_admin/2` mount boundary.

## Self-Check: PASSED

- Found created files: `priv/static/rindle_admin/rindle-admin.css`, `priv/static/rindle_admin/rindle-admin.js`, `priv/static/rindle_admin/logo.svg`, `priv/static/rindle_admin/favicon.svg`, `test/rindle/admin/assets_test.exs`, `.planning/phases/89-console-read-surfaces/89-02-SUMMARY.md`
- Found task commits: `f1d8842`, `43a3a8a`, `3e0f379`

---
*Phase: 89-console-read-surfaces*
*Completed: 2026-06-12*
