# Phase 101: daisyUI Retirement [Track B] - Research

**Researched:** 2026-06-18  
**Domain:** Phoenix LiveView adoption demo teardown, Cohort `.ck-*` design-system retirement gate  
**Confidence:** HIGH

## User Constraints (from CONTEXT.md)

Source for this section: `.planning/phases/101-daisyui-retirement-track-b/101-CONTEXT.md` [VERIFIED: codebase].

### Locked Decisions

- **D-101-01:** Delete the unrouted Phoenix generator landing code: `page_controller.ex`, `page_html.ex`, and `page_html/home.html.heex`; do not migrate or exclude it from scans [VERIFIED: 101-CONTEXT.md].
- **D-101-02:** Rename the misnamed `page_controller_test.exs` to the Launchpad LiveView test shape if the tidy is included; the test already asserts `/` renders the launchpad [VERIFIED: 101-CONTEXT.md].
- **D-101-03:** Inline the three needed flash/error icons as token-only SVG and do not preserve Heroicon CSS mask/data-url dependencies in `cohort.css` [VERIFIED: 101-CONTEXT.md].
- **D-101-04:** Add one token-only `.ck-flash` / `.ck-alert` family to `cohort.css`; use `.ck-alert` surface plus a 3px left-border accent from existing state tokens, with no `tokens.json` or token value edit [VERIFIED: 101-CONTEXT.md].
- **D-101-05:** Render flash under a `.ck` root, for example `class="ck ck-flash"`, so Cohort focus-visible and reduced-motion rules apply [VERIFIED: 101-CONTEXT.md].
- **D-101-06:** Keep the Phoenix flash contract: `attr :kind`, `:flash`, `:title`, `:rest`, slot fallback through `Phoenix.Flash.get`, and manual dismiss behavior; swap only the class/icon layer [VERIFIED: 101-CONTEXT.md].
- **D-101-07:** Split flash semantics by kind: info uses `role="status"` / polite, error uses `role="alert"` / assertive; no auto-dismiss timer, no focus steal, no color-only state cue, and a 44px close target [VERIFIED: 101-CONTEXT.md].
- **D-101-08:** Keep flash microcopy terse and factual for developer adopters [VERIFIED: 101-CONTEXT.md].
- **D-101-09:** Delete the `Layouts.app` Tailwind wrapper and render the inner slot through a bare `<main>` while keeping footer and flash as app-level children [VERIFIED: 101-CONTEXT.md].
- **D-101-10:** Promote the existing `cohort_migration_contract_test.exs` gate instead of adding new CI tooling: widen render scan demo-wide, add source/file assertions, and anchor banned literals to class boundaries [VERIFIED: 101-CONTEXT.md].
- **D-101-11:** Do destructive teardown last: migrate rendered markup first, promote the gate, remove the `default.css` link, then delete `default.css` only after the source/render grep is clean [VERIFIED: 101-CONTEXT.md].

### the agent's Discretion

Per `minimal_decisive` calibration, the planner may decide exact `--ck-*` token names inside `.ck-flash` / `.ck-alert`, whether to add a visible kind label, exact inline SVG path data, helper layout for source-read assertions, exact polish `surface` strings, and selector consolidation, provided no locked decision above is violated [VERIFIED: 101-CONTEXT.md].

### Deferred Ideas (OUT OF SCOPE)

- Per-state surface tokens such as `--ck-info-surface` / `--ck-quarantine-surface` [VERIFIED: 101-CONTEXT.md].
- Warn-to-fail flip of the Cohort polish gate, VIS re-converge, idempotency, cross-surface visual matrix, and milestone audit; these stay Phase 102 [VERIFIED: 101-CONTEXT.md].
- Higher-value upload UX such as drag-drop, live progress, thumbnails, and richer status copy [VERIFIED: 101-CONTEXT.md].
- Optional non-blocking pixel baselines [VERIFIED: 101-CONTEXT.md].
- Admin-console changes, `tokens.json` edits, and Cohort token value edits are out of scope [VERIFIED: 101-CONTEXT.md].

## Project Constraints (from AGENTS.md)

- Keep edits focused and run the checks named in `RUNNING.md` for the change [VERIFIED: AGENTS.md].
- For UI/admin-console work, follow `guides/ui_principles.md`; this phase does not touch admin-console surfaces [VERIFIED: AGENTS.md].
- Maintain the green-main release train posture and do not invent work when no approved work item exists [VERIFIED: AGENTS.md].
- Before release prep, run `./scripts/maintainer/repo_hygiene_check.sh`; this phase is not release prep [VERIFIED: AGENTS.md].
- Cursor model routing notes are operational only; they do not change implementation scope [VERIFIED: AGENTS.md].

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| COHORT-05 | daisyUI/Tailwind scaffold retired from inner pages, migrated class-by-class, preserving `id` / `data-testid` / `phx-hook`, and removing `default.css` only once grep is clean | Implementation sequence and validation map below make the render/source gate decisive before deleting the committed CSS asset [VERIFIED: .planning/REQUIREMENTS.md] |

## Summary

Phase 101 is a teardown phase, not a new design-system construction phase: the eight Cohort inner pages already render inside `ck_page/1`, and the remaining rendered daisyUI/Tailwind scaffold is the shared layout wrapper, flash markup/icons, the root `default.css` link/file, and dead Phoenix generator landing files [VERIFIED: codebase]. The correct plan is therefore to retire the shared rendered scaffold first, strengthen the existing contract test to scan the full composed render plus source/file state, then remove `default.css` last [VERIFIED: 101-CONTEXT.md].

The only net-new CSS should be the `.ck-flash` / `.ck-alert` primitive in `cohort.css`, backed only by existing `--ck-*` tokens and the existing reduced-motion/focus conventions [VERIFIED: cohort.css]. The icon dependency must move from `default.css` Heroicon mask classes to inline SVG, because `CoreComponents.icon/1` renders only a classed `<span>` and the actual glyphs currently live in `default.css` [VERIFIED: core_components.ex; VERIFIED: default.css].

Primary recommendation: implement Phase 101 as one narrow, forward-only retirement wave: flash + layout + dead generator deletion + test ratchet + `default.css` link/file removal, with no token-value, `tokens.json`, admin-console, or Phase 102 VIS gate work [VERIFIED: 101-CONTEXT.md].

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Flash rendering and semantics | Phoenix component layer (`CoreComponents.flash/1`, `Layouts.flash_group/1`) | Cohort CSS (`.ck-flash`, `.ck-alert`) | Flash is rendered by shared Phoenix components on every inner page; CSS should only style the surface [VERIFIED: core_components.ex; VERIFIED: layouts.ex] |
| Page layout width/padding | Per-page Cohort shell (`ck_page/1` / `.ck__wrap`) | `Layouts.app/1` bare `<main>` | `.ck__wrap` already owns 64rem max width and responsive padding, so the Tailwind layout wrapper is redundant [VERIFIED: cohort_components.ex; VERIFIED: cohort.css] |
| Icon glyphs | Phoenix component markup | SVG paths inline in HEEx | `CoreComponents.icon/1` depends on CSS masks from `default.css`; deleting that file requires replacing the glyph source first [VERIFIED: core_components.ex; VERIFIED: default.css] |
| Retirement proof | ExUnit source/render assertions | Playwright behavior/polish backstop | Static render/source scans prove absence; Playwright proves pages are still styled and behavior flows remain intact [VERIFIED: cohort_migration_contract_test.exs; VERIFIED: cohort-pages.spec.js; VERIFIED: ci.yml] |
| Destructive asset removal | Git/file state | Root layout | `root.html.heex` links the file and `default.css` is a committed static asset; both must be removed and asserted [VERIFIED: root.html.heex; VERIFIED: default.css] |

## Standard Stack

No new packages are required or recommended [VERIFIED: 101-CONTEXT.md].

| Asset | Version / State | Purpose | Why Standard |
|-------|-----------------|---------|--------------|
| Phoenix | 1.8.7 in `examples/adoption_demo/mix.lock` | Router, root layout, flash access | Existing adoption demo framework [VERIFIED: mix.lock] |
| Phoenix LiveView | 1.1.30 in `examples/adoption_demo/mix.lock` | LiveView pages, flash lifecycle, `lv:clear-flash` event support | Existing adoption demo render/runtime layer [VERIFIED: mix.lock; CITED: https://hexdocs.pm/phoenix_live_view/1.1.30/Phoenix.LiveView.html] |
| `cohort.css` | Hand-authored in repo | Cohort token-only CSS and `.ck-*` primitives | Existing Track B design system, no build step [VERIFIED: cohort.css] |
| `CohortComponents` | In repo | `ck_page/1`, inline SVG idioms, Cohort chrome | Existing Track B component layer [VERIFIED: cohort_components.ex] |
| ExUnit | Existing | Source/render retirement assertions | Merge-blocking `adoption-demo-unit` lane runs `mix test` [VERIFIED: ci.yml] |
| Playwright | 1.60.0 installed locally | E2E behavior and warn-mode polish backstop | Existing `adoption-demo-e2e` lane runs Playwright after Cohort contrast/literal gate [VERIFIED: node_modules; VERIFIED: ci.yml] |

## Package Legitimacy Audit

N/A. This phase installs zero external packages and should not run `npm install`, `mix deps.get` for new deps, or add a UI dependency [VERIFIED: 101-CONTEXT.md].

## Current State Evidence

| Evidence | What It Means |
|----------|---------------|
| `root.html.heex` links `/assets/default.css` between `app.css` and `cohort.css` | The root link removal is a required teardown step [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/components/layouts/root.html.heex:8-10] |
| `Layouts.app/1` wraps content in `class="px-4 py-8 sm:px-6 lg:px-8"` and `class="mx-auto max-w-3xl space-y-4"` | This is the remaining Tailwind layout scaffold shared by inner pages [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/components/layouts.ex:36-48] |
| `CoreComponents.flash/1` renders `toast`, `alert`, `alert-info`, `alert-error`, `hero-*`, `font-semibold`, `flex-1`, and close button classes | Flash is the remaining rendered daisyUI notification surface [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/components/core_components.ex:56-86] |
| `CoreComponents.flash/1` currently sets `role="alert"` for both `:info` and `:error` | Info flashes currently interrupt like errors; Phase 101 should split semantics [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/components/core_components.ex:60-65; CITED: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html] |
| The current flash dismiss button has no `phx-click` or `lv:clear-flash` attribute | The context's "preserve JS click-to-dismiss" wording is stale against current source; implementation should add/restore keyed manual dismiss while keeping no auto-dismiss timer [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/components/core_components.ex:80-82; CITED: https://hexdocs.pm/phoenix_live_view/1.1.30/Phoenix.LiveView.html] |
| `CoreComponents.icon/1` returns only `<span class={[@name, @class]} />` | The icon component is glyphless without CSS classes from `default.css` [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/components/core_components.ex:448-451] |
| `default.css` defines Heroicon classes through `url(data:image/svg+xml...)` masks for `hero-exclamation-circle`, `hero-information-circle`, and `hero-x-mark` | Deleting `default.css` before inlining icons would remove flash glyphs [VERIFIED: examples/adoption_demo/priv/static/assets/default.css:1491-1567] |
| `default.css` header says it can be safely removed with all references to `default.css` | The committed asset self-authorizes deletion after references and dependencies are gone [VERIFIED: examples/adoption_demo/priv/static/assets/default.css:1-5] |
| `/` routes to `LaunchpadLive`, not `PageController` | `PageController` / `PageHTML` / `home.html.heex` are dead generator code [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/router.ex:20-33; VERIFIED: rg PageController/PageHTML] |
| `page_html/home.html.heex` is full of Tailwind/daisyUI generator classes | Deleting dead code removes a large source of grep noise without restyling unreachable UI [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/controllers/page_html/home.html.heex:41-201] |
| `cohort_migration_contract_test.exs` currently scopes `assert_daisyui_retired/1` to `page_body/1` after `data-ck-root` | Phase 101 must remove this scoped exclusion and scan the full composed page [VERIFIED: examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs:27-48; VERIFIED: examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs:59-107] |
| `cohort-pages.spec.js` already covers styleguide, 7 small pages, all 6 upload tabs, and one dark upload case in warn mode | Playwright polish backstop exists; Phase 101 should reuse, not fork, it [VERIFIED: examples/adoption_demo/e2e/cohort-pages.spec.js:48-197] |
| `adoption-demo-unit` runs `mix test`; `adoption-demo-e2e` runs `node brandbook/src/cohort-contrast.mjs` then `bash scripts/ci/adoption_demo_e2e.sh` | The deterministic source/render gate belongs in ExUnit; browser/polish proof belongs in the existing E2E lane [VERIFIED: .github/workflows/ci.yml:558-629; VERIFIED: .github/workflows/ci.yml:649-750] |
| `cohort.css` exposes tokens, `.ck__wrap`, `.ck :focus-visible`, `.ck-stat` left-border accent, `.ck-error`, and reduced-motion rules | The flash primitive can be added with existing local patterns and token vocabulary [VERIFIED: examples/adoption_demo/priv/static/assets/cohort.css:43-109; VERIFIED: examples/adoption_demo/priv/static/assets/cohort.css:211-225; VERIFIED: examples/adoption_demo/priv/static/assets/cohort.css:745-760; VERIFIED: examples/adoption_demo/priv/static/assets/cohort.css:898-910; VERIFIED: examples/adoption_demo/priv/static/assets/cohort.css:1024-1055] |

## Recommended Approach

Use a single narrow retirement plan with one CSS addition and no dependency or token pipeline work [VERIFIED: 101-CONTEXT.md].

1. Migrate `CoreComponents.flash/1` to `.ck ck-flash` / `.ck-alert` and inline SVG icons before touching `default.css` [VERIFIED: core_components.ex; VERIFIED: default.css].
2. Add `.ck-flash` / `.ck-alert` rules to `cohort.css` using only existing `--ck-*` values, a local `--_accent`, and the existing `ck-rise` animation under `prefers-reduced-motion: no-preference` [VERIFIED: cohort.css].
3. Split accessibility semantics by flash kind: `:info` -> `role="status"` and `aria-live="polite"`; `:error` -> `role="alert"` and `aria-live="assertive"` [CITED: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html; CITED: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/status_role; CITED: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/alert_role].
4. Add or restore manual close using LiveView's `lv:clear-flash` keyed event plus local hide behavior; do not add auto-dismiss [CITED: https://hexdocs.pm/phoenix_live_view/1.1.30/Phoenix.LiveView.html].
5. Remove the Tailwind wrapper in `Layouts.app/1` and rely on each routed page's existing `ck_page/1` / `.ck__wrap` for width and padding [VERIFIED: layouts.ex; VERIFIED: cohort_components.ex; VERIFIED: cohort.css].
6. Delete dead generator files and rename the launchpad test if desired; do not migrate unreachable `home.html.heex` [VERIFIED: router.ex; VERIFIED: rg PageController/PageHTML].
7. Promote `cohort_migration_contract_test.exs` to a full composed-page/source/file ratchet, then remove the root link and delete `default.css` last [VERIFIED: cohort_migration_contract_test.exs; VERIFIED: root.html.heex; VERIFIED: default.css].

## Implementation Sequence

1. **Preflight source scan:** run targeted `rg` over `examples/adoption_demo/lib`, `examples/adoption_demo/test`, `examples/adoption_demo/e2e`, and `examples/adoption_demo/priv/static/assets` for `default.css`, `toast`, `alert-info`, `alert-error`, `hero-`, wrapper literals, and dead `PageController` references [VERIFIED: rg].
2. **Flash CSS and markup:** add `.ck-flash` / `.ck-alert*` CSS and update `CoreComponents.flash/1` plus the private `error/1` helper to use inline SVG and `.ck-error`-compatible semantics [VERIFIED: core_components.ex; VERIFIED: cohort.css].
3. **Manual dismiss check:** add keyed close behavior using `lv:clear-flash` and a local hide/transition path; current source lacks `phx-click`, so include a deterministic render/source assertion for this behavior [VERIFIED: core_components.ex; CITED: https://hexdocs.pm/phoenix_live_view/1.1.30/Phoenix.LiveView.html].
4. **Layout shell teardown:** replace the Tailwind `<main>`/inner `<div>` wrapper with a bare `<main>` and app-level footer/flash placement, keeping `cohort_nav` and `flash_group` calls [VERIFIED: layouts.ex].
5. **Dead generator deletion:** delete `page_controller.ex`, `page_html.ex`, `page_html/home.html.heex`, and rename or adjust `page_controller_test.exs` to reflect Launchpad coverage [VERIFIED: router.ex; VERIFIED: page_controller_test.exs].
6. **Gate promotion:** extend `cohort_migration_contract_test.exs` so `assert_daisyui_retired/1` scans the full rendered HTML, not `page_body/1`, and add source/file assertions for conditional flash classes and `default.css` state [VERIFIED: cohort_migration_contract_test.exs].
7. **Root link removal:** remove only the `default.css` `<link>` from `root.html.heex`; keep `app.css` and `cohort.css` [VERIFIED: root.html.heex].
8. **Destructive asset deletion last:** delete `examples/adoption_demo/priv/static/assets/default.css` only after the source/render gate is clean, then keep `refute File.exists?` as the ratchet [VERIFIED: default.css; VERIFIED: 101-CONTEXT.md].
9. **Backstop validation:** run ExUnit targeted/full adoption-demo tests, the Cohort contrast/literal gate, `cohort-pages.spec.js`, and behavior specs before marking the phase complete [VERIFIED: ci.yml; VERIFIED: cohort-pages.spec.js].

## Reusable Patterns

### Inline SVG Icons

Mirror the private SVG helpers in `CohortComponents`: inline `<svg>`, `viewBox`, `stroke="currentColor"` or `fill="currentColor"` as appropriate, and `aria-hidden="true"` because text carries the accessible name [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/components/cohort_components.ex:600-726].

### Token-only CSS

Use `.ck-stat` as the local accent precedent: a `--_accent` custom property, `border-left: 3px solid var(--_accent)`, tokenized surface, tokenized border, tokenized radius, and tokenized shadow [VERIFIED: examples/adoption_demo/priv/static/assets/cohort.css:745-760].

### Flash Markup

Keep the existing `attr` / `slot` / `Phoenix.Flash.get(@flash, @kind)` shape; Phoenix documents `Phoenix.Flash.get/2` for shared flash access [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/components/core_components.ex:48-62; CITED: https://hexdocs.pm/phoenix/Phoenix.Flash.html].

### Layout Rendering

Routed pages already render their own `.ck` root through `ck_page/1`, which emits `data-ck-root`, `data-theme`, and `.ck__wrap`; do not add a body-level or layout-level `.ck` root [VERIFIED: examples/adoption_demo/lib/adoption_demo_web/components/cohort_components.ex:61-91; VERIFIED: 96-CONTEXT.md].

### Retirement Tests

Extend `cohort_migration_contract_test.exs`; do not create a parallel scanner. Add class-boundary literals such as `~s(class="btn")` or `~s(class="tab )` rather than bare words, because `.ck-btn`, `.ck-tab`, `.ck-tabs`, and `.ck-grid` are legitimate Cohort classes [VERIFIED: examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs:32-48].

## Do Not Hand-Roll

| Problem | Do Not Build | Use Instead | Why |
|---------|--------------|-------------|-----|
| Icon glyph delivery | CSS mask/data-url Heroicon rules in `cohort.css` | Inline SVG in HEEx | Mask/data-url rules recreate the `default.css` dependency pattern being retired [VERIFIED: default.css; VERIFIED: 101-CONTEXT.md] |
| Retirement scanning | Raw CI shell `rg "btn"` | ExUnit source/render assertions with class-boundary literals | Bare substring scans false-fail on `.ck-btn` / `.ck-tab` [VERIFIED: cohort_migration_contract_test.exs; VERIFIED: 101-CONTEXT.md] |
| Alert surface colors | New token values or tinted state-surface tokens | Existing `--ck-surface`, `--ck-border`, `--ck-info`, `--ck-quarantine`, and left-border accent | Per-state surface tokens are explicitly deferred [VERIFIED: 101-CONTEXT.md] |
| Layout container | New utility-style wrapper | Existing `ck_page/1` / `.ck__wrap` | Width and padding are already owned by the Cohort page shell [VERIFIED: cohort_components.ex; VERIFIED: cohort.css] |
| Visual gate | New screenshot baseline infra | Existing `cohort-pages.spec.js` warn-mode polish + behavior specs | Pixel baselines and warn-to-fail flip are Phase 102/later [VERIFIED: 101-CONTEXT.md; VERIFIED: cohort-pages.spec.js] |

## Runtime State Inventory

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | None found; this phase removes CSS/HEEx/controller scaffold and changes no database keys or stored records [VERIFIED: phase scope; VERIFIED: source scan] | None |
| Live service config | None found; no Cloud/service UI config stores `default.css`, `PageController`, or daisyUI class state [VERIFIED: phase scope] | None |
| OS-registered state | None found; no launchd/systemd/Task Scheduler/pm2 state is part of the adoption demo styling path [VERIFIED: phase scope] | None |
| Secrets/env vars | None found; no secret or env var name changes are required [VERIFIED: phase scope] | None |
| Build artifacts / installed packages | `examples/adoption_demo/priv/static/assets/default.css` is a committed static asset, not regenerated by a Tailwind build in this demo; `app.css` and `cohort.css` stay linked [VERIFIED: default.css; VERIFIED: root.html.heex] | Remove link first, delete file last, assert `refute File.exists?` |

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir/Mix | ExUnit validation | Yes locally | Mix 1.19.5 / OTP 28 | CI uses Elixir 1.17 / OTP 27 [VERIFIED: local command; VERIFIED: ci.yml] |
| Node/npm/npx | Cohort contrast gate and Playwright | Yes locally | Node 22.14.0, npm/npx 11.1.0 | CI uses Node 20 [VERIFIED: local command; VERIFIED: ci.yml] |
| Playwright | E2E polish/behavior | Yes locally | `@playwright/test` 1.60.0 | None; already installed in `examples/adoption_demo` [VERIFIED: local command] |
| PostgreSQL | adoption-demo unit/e2e database | Yes locally | `pg_isready` accepting connections; `psql` 14.17 | CI service is Postgres 16 [VERIFIED: local command; VERIFIED: ci.yml] |
| Docker | MinIO for E2E behavior lane | Yes locally | Docker 29.5.2 | CI starts MinIO container [VERIFIED: local command; VERIFIED: ci.yml] |
| FFmpeg | adoption demo lanes | Yes locally | 8.0.1 | CI installs FFmpeg [VERIFIED: local command; VERIFIED: ci.yml] |

Missing dependencies with no fallback: none found [VERIFIED: local command].  
Missing dependencies with fallback: local versions differ from CI, so CI lane definitions remain the source of truth [VERIFIED: ci.yml].

## Validation Architecture

`workflow.nyquist_validation` is not explicitly set to `false`, so validation architecture is required [VERIFIED: .planning/config.json].

### Test Framework

| Property | Value |
|----------|-------|
| Static/render framework | ExUnit in `examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs` [VERIFIED: codebase] |
| Config file | Standard Phoenix test setup under `examples/adoption_demo/test` [VERIFIED: codebase] |
| Quick source/render command | `cd examples/adoption_demo && mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs` [VERIFIED: ci.yml] |
| Full unit command | `cd examples/adoption_demo && mix test` [VERIFIED: .github/workflows/ci.yml:622-629] |
| Token/literal command | `node brandbook/src/cohort-contrast.mjs` [VERIFIED: .github/workflows/ci.yml:746-747] |
| Quick E2E polish command | `cd examples/adoption_demo && npx playwright test e2e/cohort-pages.spec.js` [VERIFIED: cohort-pages.spec.js] |
| Full E2E command | `bash scripts/ci/adoption_demo_e2e.sh` after the CI service setup [VERIFIED: .github/workflows/ci.yml:749-750] |

### Deterministic Source Assertions

Add a test in `cohort_migration_contract_test.exs` that reads exact files and asserts absence/presence [VERIFIED: 101-CONTEXT.md].

| Assertion | File(s) | Reason |
|-----------|---------|--------|
| `refute File.read!(root_html) =~ "default.css"` | `layouts/root.html.heex` | Proves root link removal [VERIFIED: root.html.heex] |
| `refute File.exists?(default_css)` | `priv/static/assets/default.css` | Proves destructive deletion happened [VERIFIED: default.css] |
| Refute `toast`, `toast-top`, `toast-end`, `alert-info`, `alert-error`, `class="alert` | `core_components.ex` | Conditional flash classes may not appear on a clean page render [VERIFIED: core_components.ex] |
| Refute `hero-information-circle`, `hero-exclamation-circle`, `hero-x-mark` | `core_components.ex` | Proves flash/error path no longer depends on Heroicon CSS classes [VERIFIED: core_components.ex; VERIFIED: default.css] |
| Refute wrapper literals `class="px-4 py-8`, `mx-auto max-w-3xl`, `space-y-4` | `layouts.ex` and full render | Proves shared layout scaffold is gone [VERIFIED: layouts.ex] |
| Refute `btn-primary`, `btn-soft`, `class="btn"` if the planner touches `CoreComponents.button/1` | `core_components.ex` | Avoids leaving the old generator button defaults in the scanned source set [VERIFIED: core_components.ex; VERIFIED: 101-CONTEXT.md] |
| Refute `PageController`, `PageHTML`, and `page_html/home.html.heex` file existence after deletion | controller/template paths | Proves dead generator landing is removed, not excluded [VERIFIED: router.ex; VERIFIED: rg] |

### Render Assertions

Promote `assert_daisyui_retired/1` from `page_body(html)` to full composed rendered HTML after the layout wrapper is retired [VERIFIED: cohort_migration_contract_test.exs]. The widened render scan should include all existing route tests plus `/upload` tabs, because the current test module already renders the 7 small routes and all 6 upload tabs [VERIFIED: cohort_migration_contract_test.exs].

Add targeted flash renders with flash data so conditional markup is not missed [VERIFIED: core_components.ex].

Recommended clauses:

- Info flash render contains `class="ck ck-flash"`, a `.ck-alert--info` marker, `role="status"`, `aria-live="polite"`, and no `toast` / `alert-info` / `hero-information-circle` [VERIFIED: core_components.ex; CITED: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/status_role].
- Error flash render contains `.ck-alert--error`, `role="alert"`, `aria-live="assertive"`, and no `alert-error` / `hero-exclamation-circle` [VERIFIED: core_components.ex; CITED: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/alert_role].
- Dismiss button render contains `type="button"`, `aria-label="Close notification"`, and keyed flash clearing behavior such as `phx-click="lv:clear-flash"` / `phx-value-key` or an equivalent `JS.push("lv:clear-flash", value: %{key: @kind})` path [VERIFIED: current missing source; CITED: https://hexdocs.pm/phoenix_live_view/1.1.30/Phoenix.LiveView.html].
- Full composed page render contains no `default.css` reference and no Tailwind wrapper class [VERIFIED: layouts.ex; VERIFIED: root.html.heex].

### E2E and Backstop Commands

| Requirement | Command | Notes |
|-------------|---------|-------|
| Source/render retirement ratchet | `cd examples/adoption_demo && mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs` | Merge-blocking via `adoption-demo-unit` full `mix test` [VERIFIED: ci.yml] |
| Launchpad test rename/tidy | `cd examples/adoption_demo && mix test test/adoption_demo_web/controllers/*launchpad*_test.exs` or full `mix test` | Exact path depends on rename decision [VERIFIED: page_controller_test.exs] |
| Cohort literal/contrast safety | `node brandbook/src/cohort-contrast.mjs` | Ensures new CSS remains token/literal compliant [VERIFIED: ci.yml] |
| Cohort page polish | `cd examples/adoption_demo && npx playwright test e2e/cohort-pages.spec.js` | Warn-mode backstop remains warn-mode; do not flip in Phase 101 [VERIFIED: cohort-pages.spec.js; VERIFIED: 101-CONTEXT.md] |
| Upload behavior backstop | `cd examples/adoption_demo && npx playwright test e2e/image-upload.spec.js e2e/video-upload.spec.js e2e/multipart-upload.spec.js e2e/liveview-upload.spec.js e2e/mux-streaming.spec.js e2e/tus-resume.spec.js` | Confirms heavy upload flows still work after shared layout/flash changes [VERIFIED: 101-CONTEXT.md] |
| Full browser lane | `bash scripts/ci/adoption_demo_e2e.sh` | CI wraps this with Postgres, MinIO, FFmpeg, libvips, and Node setup [VERIFIED: ci.yml] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| COHORT-05 | Rendered inner pages and shared layout are free of daisyUI/Tailwind scaffold | ExUnit render + source assertions | `cd examples/adoption_demo && mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs` | Exists, needs Phase 101 promotion [VERIFIED: cohort_migration_contract_test.exs] |
| COHORT-05 | `default.css` link is removed and file is deleted only after clean scan | ExUnit source/file assertion | Same targeted ExUnit command | Assertion needs adding [VERIFIED: root.html.heex; VERIFIED: default.css] |
| COHORT-05 | Pages do not regress to unstyled and behavior flows stay green | Playwright polish + behavior specs | `cd examples/adoption_demo && npx playwright test e2e/cohort-pages.spec.js ...` | Exists [VERIFIED: cohort-pages.spec.js] |

### Sampling Rate

- Per implementation commit: targeted ExUnit contract test plus `node brandbook/src/cohort-contrast.mjs` if `cohort.css` changed [VERIFIED: ci.yml].
- Before deleting `default.css`: targeted source/render scan must be green except expected link/file assertions [VERIFIED: 101-CONTEXT.md].
- After deleting `default.css`: targeted ExUnit, full `mix test`, `cohort-pages.spec.js`, and upload behavior specs should be green before verification [VERIFIED: ci.yml].
- Phase gate: `adoption-demo-unit` and `adoption-demo-e2e` lanes green in CI or locally equivalent evidence [VERIFIED: ci.yml].

### Wave 0 Gaps

- Promote `assert_daisyui_retired/1` from `page_body/1` scoped scan to full render scan [VERIFIED: cohort_migration_contract_test.exs].
- Add source/file assertions for `root.html.heex`, `core_components.ex`, `layouts.ex`, dead generator files, and `default.css` existence [VERIFIED: codebase].
- Add explicit flash render assertions for info/error semantics and dismiss behavior [VERIFIED: current source].
- Add `.ck-flash` / `.ck-alert` CSS before the contrast/literal gate is expected to stay green [VERIFIED: cohort.css].

## Security Domain

`security_enforcement` is not explicitly disabled, so this section is included [VERIFIED: .planning/config.json]. This phase is presentational teardown and does not add auth, session, access-control, data persistence, secrets, or cryptography paths [VERIFIED: phase scope].

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | No | No auth changes [VERIFIED: phase scope] |
| V3 Session Management | Minimal | Flash uses existing Phoenix session/LiveView flash mechanisms; do not store sensitive information in flash [CITED: https://hexdocs.pm/phoenix_live_view/1.1.30/Phoenix.LiveView.html] |
| V4 Access Control | No | No routes or permissions added [VERIFIED: phase scope] |
| V5 Input Validation | Minimal | No new user input path; preserve existing upload and LiveView handlers unchanged [VERIFIED: phase scope] |
| V6 Cryptography | No | None [VERIFIED: phase scope] |

Known threat patterns:

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| XSS via raw flash rendering | Tampering / XSS | Keep HEEx escaped interpolation; do not add `raw/1`; existing contract test already refutes `raw(` [VERIFIED: cohort_migration_contract_test.exs] |
| Sensitive data in flash | Information Disclosure | Use flash only for user-facing notifications; LiveView docs warn not to store sensitive information in flash [CITED: https://hexdocs.pm/phoenix_live_view/1.1.30/Phoenix.LiveView.html] |
| Accessibility denial via over-assertive info notices | Denial of Service / UX interruption | Use `role="status"` for info and reserve `role="alert"` for errors needing immediate attention [CITED: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html; CITED: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/alert_role] |

## Risks/Pitfalls

### Pitfall 1: Deleting `default.css` before icons are inlined
**What goes wrong:** Flash/error icons become invisible because `CoreComponents.icon/1` only emits classed spans and the glyph masks live in `default.css` [VERIFIED: core_components.ex; VERIFIED: default.css].  
**Avoidance:** Inline SVG first, then delete `default.css` last [VERIFIED: 101-CONTEXT.md].

### Pitfall 2: Render-only scan false-greens on conditional flash
**What goes wrong:** Clean page renders may not contain flash DOM, so `toast` / `alert-info` / `alert-error` can remain in source unnoticed [VERIFIED: core_components.ex].  
**Avoidance:** Add source-read assertions and explicit flash render cases [VERIFIED: 101-CONTEXT.md].

### Pitfall 3: Over-broad substring scans
**What goes wrong:** Bare `btn`, `tab`, or `grid` scans can match legitimate `.ck-btn`, `.ck-tab`, `.ck-tabs`, or `.ck-grid` [VERIFIED: cohort_migration_contract_test.exs].  
**Avoidance:** Anchor banned literals to class attribute boundaries [VERIFIED: 101-CONTEXT.md].

### Pitfall 4: Keeping flash outside `.ck`
**What goes wrong:** Focus-visible and reduced-motion rules scoped under `.ck` do not apply to the notification surface [VERIFIED: cohort.css; VERIFIED: layouts.ex].  
**Avoidance:** Render flash under `class="ck ck-flash"` [VERIFIED: 101-CONTEXT.md].

### Pitfall 5: Treating current dismiss as already implemented
**What goes wrong:** The close button remains non-functional because current source lacks a `phx-click` or `lv:clear-flash` path [VERIFIED: core_components.ex].  
**Avoidance:** Add deterministic source/render assertions for keyed manual dismiss [CITED: https://hexdocs.pm/phoenix_live_view/1.1.30/Phoenix.LiveView.html].

### Pitfall 6: Expanding into full CoreComponents cleanup
**What goes wrong:** Planner broadens the phase into restyling unused generator helpers (`input`, `table`, `list`, docs) rather than retiring the rendered scaffold and locked source literals [VERIFIED: rg CoreComponents call sites; VERIFIED: 101-CONTEXT.md].  
**Avoidance:** Keep source assertions to the locked banned literals and only touch additional CoreComponents helpers if the chosen grep-clean definition explicitly requires it [VERIFIED: rg; ASSUMED].

### Pitfall 7: Wrong lane as the decisive proof
**What goes wrong:** A shell-only grep or warn-mode Playwright polish case becomes the merge-blocking proof and misses source/file state or conditional flash [VERIFIED: ci.yml; VERIFIED: cohort-pages.spec.js].  
**Avoidance:** Make ExUnit source/render assertions decisive; keep Playwright as behavior/polish backstop [VERIFIED: 101-CONTEXT.md].

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| daisyUI/Tailwind `default.css` kept as a safety scaffold | Cohort pages render from `.ck-*` plus `cohort.css`, with only shared scaffold left to retire | Phase 101 removes the final scaffold once tests prove no dependency remains [VERIFIED: STATE.md; VERIFIED: 101-CONTEXT.md] |
| Page-body-only retirement scan | Full composed render plus source/file assertions | Catches shared layout and conditional flash classes [VERIFIED: cohort_migration_contract_test.exs; VERIFIED: 101-CONTEXT.md] |
| Heroicon CSS masks in `default.css` | Inline SVG in Phoenix components | Makes `default.css` deletion safe [VERIFIED: default.css; VERIFIED: cohort_components.ex] |
| `role="alert"` for every flash | Info as polite status, error as assertive alert | Reduces unnecessary interruption while satisfying WCAG status-message semantics [VERIFIED: core_components.ex; CITED: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html] |

## Open Questions/Assumptions

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The phase should not rewrite every unused generator helper in `CoreComponents`; it should remove/neutralize only the locked source literals plus rendered flash/error paths | Risks/Pitfalls | Medium: if "demo grep-clean" is interpreted as all source text, planner must expand source cleanup or adjust the grep definition [ASSUMED] |
| A2 | Exact inline SVG path data can be copied from the current Heroicon data URLs or from equivalent outline/currentColor paths without adding a library | Reusable Patterns | Low: wrong path choice affects visual fidelity only, not dependency retirement [ASSUMED] |
| A3 | Local validation can use installed tools, but CI versions remain authoritative | Environment Availability | Low: local Node/Mix/Postgres versions differ from CI [VERIFIED: local command; VERIFIED: ci.yml] |

Open questions for planner:

1. Should `CoreComponents.button/1` be removed/restyled if it is unused but source-greppable, or should the source gate assert only the D-101 locked literals? Recommendation: keep the phase narrow and only touch it if source assertions explicitly include `btn-primary` / `btn-soft` [VERIFIED: rg; ASSUMED].
2. Should dismiss use a direct `phx-click="lv:clear-flash" phx-value-key={@kind}` or `JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")`? Recommendation: use the JS path if preserving local hide animation is desired; either is supported by LiveView flash clearing [CITED: https://hexdocs.pm/phoenix_live_view/1.1.30/Phoenix.LiveView.html].
3. Should the renamed controller test path be `launchpad_live_test.exs` under controllers or moved under live tests? Recommendation: move/rename to reflect that `/` is a LiveView route, but keep assertions unchanged unless source layout text changes [VERIFIED: router.ex; VERIFIED: page_controller_test.exs].

## Sources

### Primary (HIGH confidence)

- `.planning/phases/101-daisyui-retirement-track-b/101-CONTEXT.md` - locked decisions, phase boundary, teardown order [VERIFIED: codebase].
- `.planning/phases/101-daisyui-retirement-track-b/101-UI-SPEC.md` - flash visual/accessibility contract and scope lock [VERIFIED: codebase].
- `.planning/REQUIREMENTS.md` - COHORT-05 requirement text [VERIFIED: codebase].
- `.planning/STATE.md` - v1.19 Track B state and Phase 100/101 handoff [VERIFIED: codebase].
- `examples/adoption_demo/lib/adoption_demo_web/components/core_components.ex` - current flash, icon, generator helper state [VERIFIED: codebase].
- `examples/adoption_demo/lib/adoption_demo_web/components/layouts.ex` and `layouts/root.html.heex` - layout wrapper, flash_group, root CSS links [VERIFIED: codebase].
- `examples/adoption_demo/lib/adoption_demo_web/components/cohort_components.ex` and `priv/static/assets/cohort.css` - `ck_page`, inline SVG idioms, token/CSS reuse anchors [VERIFIED: codebase].
- `examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs` - current retirement/frozen-contract gate [VERIFIED: codebase].
- `examples/adoption_demo/e2e/cohort-pages.spec.js` and `.github/workflows/ci.yml` - existing E2E/unit lanes [VERIFIED: codebase].

### Secondary (MEDIUM confidence)

- Phoenix LiveView 1.1.30 HexDocs - `Phoenix.LiveView.JS` commands and `lv:clear-flash` / flash lifecycle [CITED: https://hexdocs.pm/phoenix_live_view/1.1.30/Phoenix.LiveView.JS.html; CITED: https://hexdocs.pm/phoenix_live_view/1.1.30/Phoenix.LiveView.html].
- Phoenix Flash HexDocs - `Phoenix.Flash.get/2` shared flash accessor [CITED: https://hexdocs.pm/phoenix/Phoenix.Flash.html].
- W3C WCAG 2.2 Understanding SC 4.1.3 and ARIA19 - status message and alert/error semantics [CITED: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html; CITED: https://www.w3.org/WAI/WCAG22/Techniques/aria/ARIA19].
- MDN ARIA status and alert role docs - implicit polite/status and assertive/alert behavior [CITED: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/status_role; CITED: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/alert_role].

### Tertiary (LOW confidence)

- GSD research-plan seam selected Context7 and websearch, but Context7 MCP and `ctx7` CLI were unavailable; official HexDocs/W3C/MDN were used directly and cached through `research-store` where possible [VERIFIED: tool output].

## Metadata

**Confidence breakdown:**

- Current state evidence: HIGH - verified by direct source reads and `rg` [VERIFIED: codebase].
- Recommended approach: HIGH - locked by Phase 101 context and confirmed against current source [VERIFIED: 101-CONTEXT.md; VERIFIED: codebase].
- Validation architecture: HIGH - existing ExUnit and Playwright harnesses are present and CI lanes are explicit [VERIFIED: cohort_migration_contract_test.exs; VERIFIED: cohort-pages.spec.js; VERIFIED: ci.yml].
- External accessibility/Phoenix semantics: MEDIUM - official docs verified, but Context7 provider unavailable [CITED: official docs; VERIFIED: tool output].

**Research date:** 2026-06-18  
**Valid until:** 2026-07-18 for local code facts; re-check external docs if Phoenix/LiveView versions change.
