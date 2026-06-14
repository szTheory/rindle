# Stack Research — v1.19 Design-System Stress-Test

**Domain:** Phoenix LiveView admin console + Phoenix LiveView demo app, design-system uplift
**Researched:** 2026-06-14
**Confidence:** HIGH (token pipeline + Playwright matrix read directly from repo; dep versions verified against Hex/npm; LiveView motion patterns verified against Phoenix docs + Emil Kowalski guidance)

## TL;DR Decision

This is a **near-zero-new-dependency** milestone. The existing `.mjs` token→CSS pipeline,
the WCAG contrast gate, and the Playwright light/dark/mobile matrix are the right tools and
should be *extended*, not replaced. The one genuinely missing capability is **pixel-diff
visual regression** — the current `admin-screenshots.spec.js` only *writes* 22 PNGs
(`page.screenshot({ path })`); it never compares them. Switch those to Playwright's built-in
`toHaveScreenshot()` (already shipped in the pinned `@playwright/test ^1.57`, no new dep).

Everything else — motion, theming, responsive, gallery — is achievable in vanilla
CSS/tokens + Phoenix `JS` commands + a tiny amount of hand-rolled hook JS. **Do not add
Tailwind to `rindle`; do not add a JS animation library to `rindle`; do not adopt
phoenix_storybook for the admin console.** (Storybook is a *maybe* for the Cohort demo only —
see below — but the recommendation is still "extend the hand-rolled gallery.")

## Recommended Stack

### Core Technologies (already in repo — extend, do not replace)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Token→CSS `.mjs` pipeline (`brandbook/src/admin-css-build.mjs`, `tokens-build.mjs`) | repo-local, Node ≥18 | Generate `rindle-admin.css` + `tokens.css` from `tokens.json` | Already the source of truth; self-contained; zero runtime cost; the only sanctioned way to ship CSS into `rindle`. All new motion/responsive tokens go through here. |
| `@playwright/test` | `^1.57` (current line 1.59/1.60) | E2E + visual regression | Already a devDependency of `adoption-demo-e2e`. Has **built-in** `toHaveScreenshot()` pixel diff — no new dep needed to add real visual regression. |
| `contrast.mjs` / `admin-contrast.mjs` (culori-free, repo-local WCAG) | repo-local | AA contrast gate on every token pair | Already gates the palette; extend `contrast_pairs` when new surface/elevation tokens land. |
| Phoenix `JS` commands + `phx-mounted` / `phx-remove` | bundled with `phoenix_live_view ~> 1.x` | Server-orchestrated motion + theme attribute toggles | Zero new dep; already used in `lib/rindle/admin/components.ex` (`JS.set_attribute` theme picker). The correct primitive for LiveView-aware enter/leave animation. |

### Supporting Libraries (NEW — scoped to the Cohort demo only, never `rindle`)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `motion` (Motion / motion.dev, formerly Motion One) | `12.40.0` (npm) — mini `animate()` is **2.3 kb** gzipped, WAAPI-backed, hardware-accelerated | Optional richer scroll/stagger/reveal motion **in the Cohort demo only** | ONLY if the Cohort restyle needs choreography beyond CSS (staggered list reveals, scroll-linked). The demo already vendors JS via `npm`/`priv/static/assets/vendor`. **Never** vendor this into `rindle`. Default to CSS first; reach for this only where CSS genuinely can't express the motion. |
| `phoenix_storybook` | `1.2.0` (Hex, 2026-06-11) | Living component gallery for the **Cohort demo** | MAYBE — see "Gallery decision" below. Configurable `css_path` (no Tailwind/esbuild lock), so it *can* consume `cohort.css`. Recommendation is still to **extend the hand-rolled gallery** unless the team wants interactive variant matrices. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Playwright `toHaveScreenshot()` | Pixel-diff visual regression over the existing 22-shot matrix | Replace `page.screenshot({ path })` with `expect(page).toHaveScreenshot(name)`. Set `animations: "disabled"` (already used), `caret: "hide"`, and a small `maxDiffPixelRatio` (e.g. `0.01`). Baselines commit to repo; CI fails on drift. This is the single highest-leverage addition. |
| Playwright project matrix | Add a mobile viewport project + (optional) `prefers-reduced-motion` project | The config currently has one `chromium` desktop project; the spec hand-rolls mobile by resizing. Promote mobile + reduced-motion to first-class `projects[]` so baselines are organized and reduced-motion is actually proven. |
| `prefers-reduced-motion` Playwright assertion | Prove motion tokens collapse to 0ms | Use `test.use({ reducedMotion: "reduce" })` to snapshot the reduced-motion variant and assert no transforms — closes the loop on the `@media (prefers-reduced-motion: reduce)` block already emitted by `admin-css-build.mjs`. |

## Decisions by Question

### 1. Animation / motion in Phoenix LiveView

**Recommendation: CSS transitions + Phoenix `JS` commands as the default; `phx-mounted` for
enter animations; reduced-motion handled in the generated CSS. No JS animation lib in `rindle`.**

- **Why not a JS lib in `rindle`:** the no-Tailwind / self-contained-assets constraint means
  every byte of JS shipped from `rindle` is a maintenance + supply-chain liability. The admin
  console already animates correctly with CSS transitions keyed off brand motion tokens
  (`--rindle-motion-press|popover|toast|transition`, easing `cubic-bezier(0.2,0,0,1)`). This
  is exactly the Emil Kowalski bar: *materialization, not entertainment* — short, purposeful,
  transform/opacity-only (compositor-friendly), no bounce.
- **LiveView-specific concerns (the real footguns):**
  - **DOM patching kills CSS enter animations.** LiveView's morphdom patch reuses nodes, so a
    `@keyframes` that runs on first paint won't re-run on re-render. Use `phx-mounted={JS...}`
    to apply enter transitions deterministically when a node enters the DOM, and
    `phx-remove={JS...}` for leave (LiveView delays node removal until the JS transition
    completes). This is the idiomatic, dependency-free pattern.
  - **`JS.transition/2` + `JS.show/hide` with `time:`** drive toast/drawer/dialog enter/leave;
    feed the durations from motion tokens so CSS and JS agree (e.g. `time: 200` ↔
    `--rindle-motion-toast: 200ms`). Keep the numbers in `tokens.json` and reference them in
    both the generated CSS and the component `JS` calls — single source of truth.
  - **Avoid layout-animating properties** (height/top/width). Animate `transform`/`opacity`
    only. The skeleton shimmer should use `background-position`, not width.
  - **View Transitions API:** SAME-DOCUMENT view transitions do not compose cleanly with
    LiveView's morphdom patching (LiveView mutates the DOM itself; VT wants to snapshot
    before/after a state change it controls). **Do not adopt the View Transitions API for the
    admin console.** Cross-document VT is irrelevant (LiveView is a SPA-ish single document).
    Revisit only if/when LiveView ships first-class VT integration; today it's a footgun.
  - **`motion-one`/`motion` in the demo:** acceptable for scroll-reveal/stagger on the Cohort
    marketing-ish pages, but gate every effect behind
    `window.matchMedia("(prefers-reduced-motion: reduce)")` and prefer `animate(..., { ... })`
    with WAAPI so it stays compositor-driven. Default remains CSS; only reach for it where CSS
    can't express the choreography.
- **Honoring brand motion tokens + reduced-motion:** the pipeline already emits a
  `@media (prefers-reduced-motion: reduce)` block zeroing durations/transforms. **Extend it to
  cover every new animated selector** (the build script's `requiredSelectors` parity check is
  the enforcement hook — add new motion-bearing selectors there so a missing reduced-motion
  rule fails the build). For the Cohort `cohort.css`, mirror the same reduced-motion block
  (it currently has `.ck-reveal` with `--d` delays — ensure those are disabled under reduce).

### 2. Visual-regression / screenshot diff

**Recommendation: Playwright built-in `toHaveScreenshot()` — in-repo, zero new dependency.
This is the lowest-dependency option and it is already installed.**

- The current `admin-screenshots.spec.js` writes 22 PNGs to `test-results/` and only asserts
  the *files exist* (`missing` check) — it is a screenshot *generator*, not a *regression
  gate*. Drift in pixels is invisible today.
- Convert to `await expect(page).toHaveScreenshot("light/assets.png", { animations: "disabled",
  caret: "hide", fullPage: true, maxDiffPixelRatio: 0.01 })`. Commit baselines under
  `e2e/admin-screenshots.spec.js-snapshots/`. CI fails on visual drift; `--update-snapshots`
  refreshes intentionally (the idempotent / no-regression discipline the seed asks for).
- **Do NOT add** hosted visual tools (Percy, Chromatic, Applitools, Argos) — they add a SaaS
  dependency, secrets, network flakiness, and cost for a library/demo that already runs
  Playwright in merge-blocking CI. The seed explicitly wants in-repo proof.
- **Do NOT add** `pixelmatch`/`jest-image-snapshot` — Playwright bundles the same pixelmatch
  engine behind `toHaveScreenshot`; a second diff lib is redundant.
- Watch-outs: font rendering differs Linux vs macOS — generate/refresh baselines **in CI's
  Linux container** (the matrix already runs there via `adoption_demo_e2e.sh`), and pin fonts
  (they are vendored woff2, good). Mask volatile regions (timestamps, IDs) with `mask:`.

### 3. Component gallery ("Storybook for Phoenix")

**Recommendation: EXTEND the hand-rolled gallery (`brandbook/admin-gallery/index.html`,
generated by `admin-gallery.mjs`) for the admin console. Treat `phoenix_storybook` as an
optional, demo-only experiment — not a milestone dependency.**

- The admin gallery is already a *generated, static, self-contained* artifact with a parity
  check (`admin-gallery-check.mjs`) wired into the build. It renders every component in every
  interaction state and is screenshot-friendly. It costs zero runtime deps and ships nothing
  into `rindle`. For a *fractal audit surface* (component → meta-component → page), the cheapest
  win is to **extend the generator** to emit the missing levels: interaction-state grids
  (hover/focus/active/disabled/loading/empty/error), meta-component compositions (toolbar,
  table+filters, action panel), and a light/dark side-by-side, all driven from
  `admin-design-system-data.mjs`. Playwright then screenshots the gallery pages → instant
  visual-regression coverage of the whole DS in one place.
- `phoenix_storybook 1.2.0` is viable for the **Cohort demo** (it accepts a custom `css_path`,
  so `cohort.css` works without Tailwind), and gives interactive variant playgrounds + a11y
  panels. But it pulls a Hex dep + a mount + its own asset story into the demo, and the demo's
  job is to *prove Rindle*, not to host a DS tool. **Default: extend the gallery.** Adopt
  `phoenix_storybook` only if the team specifically wants live, prop-driven variant exploration
  for the Cohort components and is willing to own the extra surface — and never in `rindle`.

### 4. Theme switching (light / dark / system) for server-rendered LiveView

**Recommendation: keep `data-theme` on the root + `prefers-color-scheme` for `auto` (already
implemented), but add (a) an inline head script to prevent FOUC and (b) `localStorage`
persistence. These are the two real gaps.**

- **Current state (verified):** `components.ex` sets `data-theme="auto"` on the shell and the
  theme picker uses `JS.set_attribute({"data-theme", ...})`. The generated CSS correctly scopes
  `[data-theme="dark"]` and `@media (prefers-color-scheme: dark) [data-theme="auto"]`. Good
  foundation.
- **Gap 1 — FOUC / flash on navigation + reload.** Because the theme is applied by a `JS`
  command *after* mount, a hard reload paints the default (`auto`) first. Fix with a tiny
  **synchronous inline `<script>` in the document `<head>`** (or the admin layout's head) that
  reads the persisted choice and sets `data-theme` *before first paint*. This is the standard,
  framework-agnostic anti-FOUC pattern and ships as a ~10-line inline script (acceptable inside
  the admin layout; it is markup, not a bundled asset). It must run before the stylesheet
  applies, so inline-in-head, not a deferred file.
- **Gap 2 — persistence.** The current picker has no memory. Add `localStorage`
  (`rindle-admin-theme`) write on click (small `phx-hook` or inline handler) and read it in the
  head script. Keep `auto` as the default when unset so `prefers-color-scheme` drives it.
- **Scope to the console root, not `:root` document-wide** — `rindle` mounts inside a host app;
  toggling the host's `<html>` theme would be hostile. Apply `data-theme` to
  `[data-rindle-admin-root]` (already the case). The Cohort demo owns its whole document, so it
  may toggle `<html>` freely.
- **Do NOT** round-trip theme through the server/session for the admin console — it is a
  client preference; server persistence adds a DB/session coupling a mountable library should
  not impose. Client-side `localStorage` + inline head script is correct and dependency-free.

### 5. Mobile-first responsive CSS compatible with generated-BEM-from-tokens

**Recommendation: add three things to the token pipeline — (a) a fluid type/space scale via
`clamp()`, (b) container queries for meta-components, (c) named breakpoint tokens — all
emitted by the existing `.mjs` build. No framework, no Tailwind.**

- **Fluid type & space (`clamp()`):** the scale in `tokens.json` is fixed px (hero 64px, h1
  44px, body 17px, space 4–64px). Add a `fluid` block to `tokens.json` (min/max px + viewport
  range) and have `admin-css-build.mjs`/`tokens-build.mjs` emit
  `--rindle-text-h1-size: clamp(<min>, <preferred-vw>, <max>)`. This gives smooth scaling at
  every width (the seed's "looks good at all breakpoints") without a cascade of media queries.
  Keep the px values as the clamp bounds so contrast/measure rules still hold.
- **Container queries (`@container`):** the audit is *fractal* (component → meta-component →
  page). Meta-components (toolbar, table+filters, action panel) should respond to *their
  container*, not the viewport, so the same component reflows correctly whether it's in the
  narrow nav rail or the wide main. Add `container-type: inline-size` to meta-component wrappers
  in the generator and write `@container` rules. Container queries are broadly supported in 2026
  (all evergreen browsers since 2023) — safe for an operator console. This is *more* correct
  than the current single `@media (max-width: 760px)` shell breakpoint.
- **Named breakpoint tokens:** add `breakpoints` to `tokens.json` (e.g. `sm/md/lg`) so media/
  container queries reference one source of truth instead of magic numbers scattered in CSS.
  Emit them as comments or as a JS-consumable constant in the build (CSS can't yet use custom
  properties inside media-query conditions, so the generator must interpolate the values — this
  is exactly what the `.mjs` build is good at).
- **Logical properties:** prefer `padding-inline`/`margin-block`/`inset` in generated CSS for
  future-proofing and RTL-readiness — a free correctness upgrade with no dep.
- The build's parity check (`requiredSelectors`/`requiredTokenUses`) is the enforcement seam:
  add the new fluid/container tokens to the required-uses list so a regression fails the build.

## Installation

```bash
# rindle package: NOTHING new. The .mjs pipeline + contrast gate are already present.
#   node brandbook/src/admin-css-build.mjs   # regenerates rindle-admin.css from tokens.json

# Cohort demo e2e (already present): no new dep for visual regression —
# toHaveScreenshot ships inside @playwright/test ^1.57 already in package.json.

# OPTIONAL, Cohort demo ONLY, only if CSS motion proves insufficient:
cd examples/adoption_demo && npm install motion@^12.40.0
#   then vendor: cp node_modules/motion/dist/motion.min.js priv/static/assets/vendor/

# OPTIONAL, Cohort demo ONLY, only if interactive variant playground is wanted (NOT recommended
# as default; extend the hand-rolled gallery instead):
#   {:phoenix_storybook, "~> 1.2"}   # in examples/adoption_demo/mix.exs
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Playwright `toHaveScreenshot()` (in-repo) | Percy / Chromatic / Argos / Applitools (hosted) | Never for this milestone — only if the team later wants cloud review UI/PR comments and accepts SaaS + secrets + cost. |
| CSS transitions + Phoenix `JS` commands | `motion@12` (JS) | Cohort demo only, for scroll-linked/stagger choreography CSS can't express. Never in `rindle`. |
| Extend hand-rolled admin gallery | `phoenix_storybook@1.2` | Cohort demo only, if interactive prop-driven variant exploration + a11y panels are wanted and the extra Hex dep/mount is acceptable. |
| `data-theme` + inline head script + `localStorage` | Server/session-persisted theme | Only if the host app already owns a per-user theme preference and wants the console to honor it — but that couples the library to host session/DB; avoid by default. |
| `clamp()` fluid scale + `@container` | Stepwise `@media` breakpoints only | Acceptable for the shell-level layout switch (already used); use clamp/container for component-internal responsiveness. |

## What NOT to Use (anti-dependencies)

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **Tailwind / daisyUI in `rindle`** | Violates self-contained-assets; forces a host build step; the whole DS decision (D-v1.18) is BEM+custom-props-from-tokens precisely to avoid this | Generated BEM CSS from `tokens.json` via `.mjs` |
| **Any JS animation lib in `rindle`** (motion, GSAP, anime.js) | Ships JS + supply-chain surface from a library that promises precompiled, self-contained assets; CSS + `JS` commands already meet the Emil Kowalski bar | CSS transitions keyed to motion tokens + `phx-mounted`/`phx-remove` + `JS.transition` |
| **View Transitions API for the admin console** | Does not compose with LiveView morphdom DOM patching; a footgun today | `phx-mounted`/`phx-remove` + `JS.transition` enter/leave |
| **Hosted visual-regression SaaS** (Percy/Chromatic/Argos/Applitools) | SaaS dep, secrets, network flake, cost; seed wants in-repo proof | Playwright `toHaveScreenshot()` (already installed) |
| **`pixelmatch` / `jest-image-snapshot`** | Redundant — Playwright bundles the same diff engine | `toHaveScreenshot()` |
| **`phoenix_storybook` in `rindle`** | Adds a Hex dep + mount + asset story to a mountable library; the static generated gallery already serves the audit | Extend `brandbook/admin-gallery` generator |
| **A CSS framework / reset lib** (Pico, Open Props, normalize.css) for `rindle` | Pulls external CSS; tokens.json already defines the full system incl. resets via the shell box-sizing rule | Generated tokens + `box-sizing` reset already in `admin-css-build.mjs` |
| **PostCSS/Sass build for `rindle`** | Adds a build toolchain to a precompiled-asset library; the `.mjs` generator already does interpolation (clamp, breakpoint values) | Node `.mjs` string generation (already the pattern) |
| **Server/session-persisted admin theme** | Couples mountable lib to host DB/session | `localStorage` + inline head anti-FOUC script |

## Stack Patterns by Variant

**If the surface is `rindle` (admin console):**
- Vanilla generated CSS only; CSS transitions + Phoenix `JS`; `data-theme` on
  `[data-rindle-admin-root]`; inline head script for FOUC; `localStorage` for persistence.
- Zero new Hex/npm deps. Everything flows through `tokens.json` → `.mjs` → `rindle-admin.css`.

**If the surface is the Cohort demo (`examples/adoption_demo`):**
- May use `motion@12` (vendored) for richer choreography and `phoenix_storybook@1.2` if an
  interactive gallery is wanted; toggles `<html>` theme directly (owns the document).
- Restyle onto `cohort.css` + `CohortComponents`, retiring daisyUI page by page; mirror the
  reduced-motion + clamp/container patterns from the admin pipeline.

## Version Compatibility

| Package | Version | Notes |
|---------|---------|-------|
| `@playwright/test` | `^1.57` (1.59/1.60 current) | `toHaveScreenshot` present since 1.2x; no upgrade needed. Refresh baselines in Linux CI to avoid font-rendering diffs. |
| `phoenix_storybook` | `1.2.0` (2026-06-11) | Tracks `phoenix_live_view ~> 1.x`; configurable `css_path`/`js_path` (no Tailwind/esbuild lock). Demo-only if adopted. |
| `motion` (motion.dev) | `12.40.0` | mini `animate()` 2.3 kb gz, WAAPI/hardware-accelerated; formerly "Motion One"/"Framer Motion". Demo-only if adopted. |
| `phoenix_live_view` | `~> 1.x` (repo) | `JS.transition`, `phx-mounted`, `phx-remove`, `JS.set_attribute` all available — basis for all admin motion + theming. |
| Node | `≥18` | Runs the `.mjs` token/gallery/contrast pipeline (ESM, `node:fs`). |

## Integration Points (for the roadmapper / `/gsd:ui-phase`)

1. **Token pipeline (`brandbook/src/admin-css-build.mjs`, `tokens-build.mjs`):** add `fluid`,
   `breakpoints`, and any new elevation/state tokens to `tokens.json`; emit `clamp()` sizes,
   `@container` rules, logical properties; extend `requiredSelectors`/`requiredTokenUses` parity
   so reduced-motion + new tokens are build-enforced.
2. **Contrast gate (`contrast.mjs`/`admin-contrast.mjs`):** add `contrast_pairs` for every new
   surface/elevation introduced by the fractal audit (hover/active/disabled states).
3. **Playwright matrix (`e2e/admin-screenshots.spec.js`, `playwright.config.js`,
   `scripts/ci/adoption_demo_e2e.sh`):** swap `page.screenshot({path})` → `toHaveScreenshot`;
   add mobile + `reducedMotion: "reduce"` projects; commit baselines; keep generation in Linux
   CI. Add a Cohort-pages screenshot spec mirroring the admin one as the demo restyle lands.
4. **Gallery (`admin-gallery.mjs` + `admin-gallery-check.mjs`):** extend to emit interaction-
   state grids + meta-component compositions + light/dark pairs; point a Playwright spec at the
   gallery pages for whole-DS visual regression.
5. **Theme (`lib/rindle/admin/components.ex` + admin layout):** add inline head FOUC script +
   `localStorage` persistence to the existing `data-theme`/`JS.set_attribute` picker.

## Sources

- Repo (HIGH): `brandbook/tokens/tokens.json`, `brandbook/src/admin-css-build.mjs`,
  `examples/adoption_demo/e2e/admin-screenshots.spec.js` (confirmed PNGs are written, not
  diffed), `admin-theme.spec.js`, `lib/rindle/admin/components.ex` (JS theme picker, no
  persistence), `playwright.config.js`, `examples/adoption_demo/package.json`.
- https://hex.pm/packages/phoenix_storybook — version `1.2.0` (2026-06-11) (HIGH)
- https://phoenix-storybook.hexdocs.pm/PhoenixStorybook.html — configurable `css_path`/`js_path`,
  no Tailwind/esbuild lock (MEDIUM)
- npm `motion` / Bundlephobia — `motion@12.40.0`, mini `animate()` ~2.3 kb, WAAPI-backed (MEDIUM)
- playwright.dev release notes + testdino visual-testing guide — built-in `toHaveScreenshot`,
  pixelmatch engine, Linux-baseline guidance; current line 1.59/1.60 (MEDIUM)
- Phoenix LiveView docs — `JS.transition`, `phx-mounted`/`phx-remove`, morphdom patch behavior;
  basis for the "no View Transitions API, use JS commands" call (HIGH, training + docs)
- Emil Kowalski (emilkowalski.ski) motion principles, restated in `tokens.json` motion.rules —
  purposeful, transform/opacity-only, reduced-motion-aware (MEDIUM)

---
*Stack research for: Phoenix LiveView design-system uplift (admin console + Cohort demo)*
*Researched: 2026-06-14*
