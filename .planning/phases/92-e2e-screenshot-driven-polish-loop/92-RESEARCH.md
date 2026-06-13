# Phase 92: E2E & Screenshot-Driven Polish Loop - Research

**Researched:** 2026-06-13
**Domain:** Phoenix LiveView admin console, adoption demo Playwright harness, CI proof, screenshot polish
**Confidence:** HIGH

## Summary

Phase 92 should extend the existing `examples/adoption_demo` Playwright harness and the merge-blocking `adoption-demo-e2e` CI job. Do not create a standalone console test app. The adoption demo already packages Rindle through `scripts/ci/adoption_demo_e2e.sh`, seeds the Cohort lifecycle matrix, mounts the console at `/admin/rindle`, and runs 12 browser specs against Postgres plus MinIO.

Primary recommendation: add admin-console browser specs and a dedicated screenshot capture spec/script inside `examples/adoption_demo/e2e/`, using `data-rindle-admin-*` selectors and the existing `waitForLiveSocket` helper. Keep the proof lane merge-blocking by updating the existing adoption proof matrix and drift gate when new spec filenames are added. Store screenshot output under ignored Playwright/test-results paths and make the spec assert every expected light/dark screenshot file exists.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| E2E-01 | Deterministic Playwright specs for console happy paths, main error cases, boundary conditions, theme switching, and destructive flows in a merge-blocking CI lane. | `adoption-demo-e2e` already runs `scripts/ci/adoption_demo_e2e.sh` as a merge-blocking job for `szTheory/rindle`. Add console specs to the existing `examples/adoption_demo/e2e` suite so CI picks them up through `npm run e2e`. |
| E2E-02 | Automated all-screens light/dark screenshot capture feeding analyze-to-fix polish iteration passes. | Reuse the screenshot mechanics from `brandbook/src/admin-gallery-check.mjs`, but target the live Phoenix app mounted at `/admin/rindle`. Capture all console routes in light and dark by clicking `[data-rindle-admin-theme]` controls, not only by emulating media. |

## Relevant Existing System

### Current Playwright Harness

- `examples/adoption_demo/playwright.config.js` sets `testDir: "./e2e"`, starts Phoenix with `PORT=${ADOPTION_DEMO_BROWSER_PORT || 4102} PHX_SERVER=true MIX_ENV=test mix phx.server`, uses one Chromium worker, retains traces on failure, and writes to `examples/adoption_demo/test-results/`.
- `examples/adoption_demo/e2e/global-setup.js` creates/migrates the adoption demo DB, runs Rindle migrations, and seeds unless `ADOPTION_DEMO_PRESEEDED=1`.
- `scripts/ci/adoption_demo_e2e.sh` builds a Hex package with `mix hex.build --unpack`, points the demo at that package with `RINDLE_DEMO_RINDLE_PATH`, resets Postgres/Rindle migrations, seeds, vendors JS, installs Chromium, and runs `npm run e2e`.
- `.github/workflows/ci.yml` job `adoption-demo-e2e` is already merge-blocking in the release train and depends on `quality` and `optional-dependencies`.

### Current Admin Console Surface

- `examples/adoption_demo/lib/adoption_demo_web/router.ex` mounts the console under `scope "/admin"` with `rindle_admin "/", allow_unauthenticated?: true`, producing the effective browser base `/admin/rindle`.
- `lib/rindle/admin/components.ex` renders shell, nav, theme picker, status chips, empty/error states, metadata lists, and stable `data-rindle-admin-*` attributes.
- Console surfaces to cover:
  - `/admin/rindle` (`home-status`)
  - `/admin/rindle/assets`
  - `/admin/rindle/assets/:id`
  - `/admin/rindle/upload-sessions`
  - `/admin/rindle/upload-sessions/:id`
  - `/admin/rindle/variants-jobs`
  - `/admin/rindle/runtime-doctor`
  - `/admin/rindle/actions`
- `examples/adoption_demo/priv/repo/seeds.exs` inserts lifecycle edge cases for asset, variant, and upload-session states, including degraded, quarantined, failed, stale, expired, and empty/edge states.
- Phase 91 verification required human checking for admin lifecycle display; Phase 92 can turn that into deterministic screenshot and browser proof.

### Current Screenshot Pattern

- `brandbook/src/admin-gallery-check.mjs` launches Chromium from the adoption demo Playwright install, runs generated-gallery checks, toggles `[data-rindle-admin-theme]`, captures full-page and element screenshots, disables animations, and asserts expected screenshot files exist.
- The live-app screenshot loop should copy that shape but use Playwright test fixtures against `baseURL`, `waitForLiveSocket(page)`, and live routes.

## Recommended Implementation Shape

### Plan Slice 1: Console Spec Foundation

Add stable helper functions before writing many assertions:

- `examples/adoption_demo/e2e/support/admin.js`
  - `ADMIN_BASE = "/admin/rindle"`
  - `adminPath(suffix = "")`
  - `visitAdmin(page, suffix = "")` calls `page.goto(adminPath(suffix))` and `waitForLiveSocket(page)`.
  - `expectAdminShell(page, surface)` asserts `[data-rindle-admin-root]`, `[data-rindle-admin-surface="${surface}"]`, nav, live indicator, and theme controls.
  - `selectAdminTheme(page, theme)` clicks `[data-rindle-admin-theme="${theme}"]`, asserts `data-theme`, and asserts matching `aria-pressed`.
  - `firstAdminRowHref(page, rowSelector)` extracts the first stable detail link without relying on row text.

This keeps later specs concise and prevents duplicated fragile selectors.

### Plan Slice 2: Behavior Specs for E2E-01

Add admin console specs under `examples/adoption_demo/e2e/`, likely split as:

- `admin-console.spec.js`
  - happy path: visit every nav surface and assert shell/surface-specific rows or empty states.
  - boundary conditions: filter assets/upload sessions to known missing states and assert empty state, not error state.
  - detail pages: open first asset and first upload session from seeded rows and assert redaction-safe detail sections.
  - runtime/doctor and variants/jobs: assert stable table/row selectors, recommendations, and no raw secret text.
- `admin-actions.spec.js`
  - destructive preview: owner erasure preview requires collateral preview before execution.
  - confirmation validation: wrong confirmation keeps preview state and shows error feedback.
  - execution receipt: typed confirmation reaches receipt for a deterministic owner that can be erased without breaking later specs.
  - batch erasure: preview, wrong confirmation, and receipt/partial receipt path.
  - non-destructive actions: lifecycle repair and variant regeneration require explicit inputs/confirmation and render receipts.
  - quarantine review: read-only panel asserts no un-quarantine mutation.
- `admin-theme.spec.js`
  - toggle light/dark/auto through `[data-rindle-admin-theme]`.
  - assert `document.documentElement` or `[data-rindle-admin-root]` has the expected `data-theme`.
  - assert visible status chips/buttons remain visible and controls meet target selectors.

Use stable `data-rindle-admin-*` selectors. If a required form control or action tab has no stable selector, add a narrowly scoped `data-rindle-admin-*` attribute to the LiveView source instead of falling back to brittle text-only locators.

### Plan Slice 3: Screenshot Capture and Polish Loop for E2E-02

Add a screenshot spec or script, preferably `examples/adoption_demo/e2e/admin-screenshots.spec.js`, so CI and local Playwright share the same server lifecycle.

Recommended capture matrix:

| Route | Surface | Notes |
|-------|---------|-------|
| `/admin/rindle` | home-status | overview/status summaries |
| `/admin/rindle/assets` | assets | seeded lifecycle rows |
| first `/admin/rindle/assets/:id` | assets detail | attachment, variant, upload session, provider redaction sections |
| `/admin/rindle/upload-sessions` | upload-sessions | expired/failed/signed states |
| first `/admin/rindle/upload-sessions/:id` | upload session detail | redacted session URI and failure guidance |
| `/admin/rindle/variants-jobs` | variants-jobs | problem buckets and recommendations |
| `/admin/rindle/runtime-doctor` | runtime-doctor | doctor checks and runtime status |
| `/admin/rindle/actions` | actions | action directory and default owner erasure input |
| `/admin/rindle/actions` after preview | actions-owner-preview | destructive collateral preview |

For each route, capture `light` and `dark` by clicking the UI theme picker. Use `{ animations: "disabled", fullPage: true }`, a deterministic viewport such as `1480x900`, and an additional mobile viewport for at least shell/nav/actions density if time allows.

Output path should stay ignored, for example:

- `examples/adoption_demo/test-results/admin-screenshots/light/home-status.png`
- `examples/adoption_demo/test-results/admin-screenshots/dark/home-status.png`

The screenshot spec should assert all expected files exist so CI fails if capture silently regresses. CI already uploads `examples/adoption_demo/test-results/` on failure.

### Plan Slice 4: CI and Proof Matrix Truth

Because the existing adoption proof matrix names every E2E spec and `scripts/maintainer/check_adoption_proof_matrix.sh` asserts those filenames, adding specs requires updating:

- `examples/adoption_demo/docs/adoption-proof-matrix.md`
- `scripts/maintainer/check_adoption_proof_matrix.sh`
- Optional README wording in `examples/adoption_demo/README.md` if a new local screenshot command is exposed.

Do not create a new GitHub Actions job unless the screenshot spec becomes too slow for the existing suite. The default path is to keep `adoption-demo-e2e` as the single merge-blocking browser proof lane.

## Design and Accessibility Constraints

- Follow `guides/ui_principles.md` before touching console, Cohort, E2E, or visual-polish surfaces.
- Use `data-rindle-admin-*` selectors for admin console tests; `data-testid` remains acceptable for older Cohort demo surfaces but should not be introduced into the published admin package.
- Do not add Tailwind, daisyUI, shadcn, Radix, or host asset pipeline dependencies to the console.
- Theme tests must exercise the app-level UI theme picker, not just `page.emulateMedia`.
- Destructive flows must assert collateral preview, typed confirmation, disabled/blocked wrong-confirmation behavior, execution result, and receipt.
- Avoid sleeps. Wait for LiveView socket, explicit selectors, DOM state, or Playwright expectations.

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Screenshot output creates noisy repository churn. | Write screenshots under ignored `examples/adoption_demo/test-results/admin-screenshots/`, mirroring Playwright output behavior. |
| E2E specs become order-dependent after destructive actions mutate seeded data. | Use a dedicated owner/member for destructive execution, reset state through the existing CI seed path, and keep preview-only assertions for shared-collateral paths. |
| Text-only locators become brittle during polish changes. | Add stable `data-rindle-admin-*` attributes to tabs, forms, controls, receipts, and surface panels where needed. |
| Full screenshot matrix increases CI time. | Keep one Chromium project, one worker, reuse the existing server, and capture only deterministic route/theme combinations. Add mobile screenshots only for the highest-risk shell/action surfaces if runtime is a concern. |
| Theme state leaks between specs. | Each screenshot/test should call `selectAdminTheme(page, theme)` after navigation and assert the resulting `data-theme`. |
| Existing LiveView unit tests may lag Phase 90 changes. | Treat browser specs as user-flow proof and add selectors without weakening current ExUnit assertions. Run targeted admin LiveView tests plus the adoption demo Playwright lane before completion. |

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Browser framework | Playwright via `@playwright/test` in `examples/adoption_demo` |
| Config file | `examples/adoption_demo/playwright.config.js` |
| Existing CI lane | `.github/workflows/ci.yml` job `adoption-demo-e2e` |
| Existing CI wrapper | `scripts/ci/adoption_demo_e2e.sh` |
| Local full browser command | `bash scripts/ci/adoption_demo_e2e.sh` from repo root |
| Local faster browser command | `cd examples/adoption_demo && npm run e2e` with Postgres/MinIO available |
| Targeted root tests | `mix test test/rindle/admin/live/actions_live_test.exs test/rindle/admin/live/home_assets_upload_test.exs test/rindle/admin/live/variants_runtime_actions_test.exs` |
| Proof matrix drift gate | `bash scripts/maintainer/check_adoption_proof_matrix.sh` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| E2E-01 | Admin console surface navigation, happy paths, error/boundary states, theme switching, destructive flows | Playwright E2E | `bash scripts/ci/adoption_demo_e2e.sh` | Existing harness; new specs needed |
| E2E-01 | Merge-blocking adoption demo E2E lane includes the new admin specs | CI/proof matrix | `bash scripts/maintainer/check_adoption_proof_matrix.sh` plus CI job `adoption-demo-e2e` | Existing lane; matrix update needed |
| E2E-02 | All admin screens captured in light and dark mode | Playwright screenshot proof | `cd examples/adoption_demo && npx playwright test e2e/admin-screenshots.spec.js` | New spec needed |
| E2E-02 | Screenshot capture fails if any expected image is missing | Source assertion + Playwright | Same as above | New expected list needed |

### Sampling Rate

- Per task: run targeted Playwright spec(s) for the file just added or changed.
- Per plan: run targeted admin ExUnit tests when LiveView selectors/actions change, plus relevant Playwright specs.
- Phase gate: run `bash scripts/ci/adoption_demo_e2e.sh` and `bash scripts/maintainer/check_adoption_proof_matrix.sh`.

### Manual / Human Review

The screenshot capture provides artifacts for visual inspection, but the completion claim should not rely only on human eyeballing. Plans should require objective source/CLI assertions:

- expected screenshot count exists for every route/theme pair
- Playwright specs pass without retries or sleeps
- proof matrix lists every new spec
- CI wrapper remains the merge-blocking browser lane

## Sources

- `.planning/ROADMAP.md` Phase 92 section
- `.planning/REQUIREMENTS.md` E2E-01 and E2E-02
- `.planning/phases/92-e2e-screenshot-driven-polish-loop/92-CONTEXT.md`
- `.planning/phases/91-cohort-demo-evolution/91-*-SUMMARY.md`
- `.planning/phases/91-cohort-demo-evolution/91-VERIFICATION.md`
- `RUNNING.md`
- `guides/ui_principles.md`
- `examples/adoption_demo/playwright.config.js`
- `scripts/ci/adoption_demo_e2e.sh`
- `.github/workflows/ci.yml`
- `examples/adoption_demo/e2e/*`
- `examples/adoption_demo/priv/repo/seeds.exs`
- `examples/adoption_demo/lib/adoption_demo_web/router.ex`
- `lib/rindle/admin/components.ex`
- `lib/rindle/admin/live/actions_live.ex`
- `brandbook/src/admin-gallery-check.mjs`

## RESEARCH COMPLETE
