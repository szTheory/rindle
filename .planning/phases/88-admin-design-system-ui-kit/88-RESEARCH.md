# Phase 88: Admin Design System & UI Kit - Research

**Researched:** 2026-06-11  
**Domain:** Vanilla CSS design-token generation, Phoenix/LiveView-ready admin component markup, Playwright screenshot review, WCAG contrast gates  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
## Implementation Decisions

### CSS And Token Source

- **D-88-01:** Generate a dedicated vanilla `rindle-admin` CSS layer from
  `brandbook/tokens/tokens.json`, using BEM selectors and `--rindle-` CSS custom
  properties.
- **D-88-02:** Treat `brandbook/tokens/tokens.css` as the existing generated
  brand-token artifact, not as the full console component stylesheet.
- **D-88-03:** Do not hand-edit generated CSS artifacts. Follow the existing
  brandbook generator/checker pattern and keep component CSS reproducible.
- **D-88-04:** The shipped console design system must remain independent of host
  Tailwind, daisyUI, esbuild, asset-pipeline integration, shadcn, Radix,
  Tailwind UI, daisyUI registries, or other third-party UI registries.

### Theme And State Semantics

- **D-88-05:** Implement the theme picker as a first-class `rindle-admin`
  component that writes `data-theme="light|dark|auto"`.
- **D-88-06:** `data-theme="auto"` follows `prefers-color-scheme`; do not add a
  parallel theme convention.
- **D-88-07:** Lifecycle and operational status components must include visible
  text labels plus icons or equivalent non-color marks. Never rely on color
  alone.
- **D-88-08:** Status colors and focus states must use token-gated foreground /
  background pairs, including the frozen processing token margin from the brand
  token rules.

### Component Scope And Packaging Boundary

- **D-88-09:** Phase 88 produces reusable component markup/styles for the kit,
  not the full mounted console implementation.
- **D-88-10:** Do not implement the admin router macro, production safe-mount
  check, host auth contract, `Plug.Static` asset-serving route, CSP/socket
  option handling, or `Rindle.Admin.Queries` read surfaces in this phase.
- **D-88-11:** Preserve the optional LiveView dependency boundary. Component-kit
  work may prepare Phoenix/LiveView markup patterns, but Phase 88 must not make
  `phoenix_live_view` required for non-console adopters.

### Component Inventory And IA Alignment

- **D-88-12:** Build the required core components around Rindle's six locked
  operator surfaces: `Home/Status`, `Assets`, `Upload Sessions`,
  `Variants/Jobs`, `Runtime/Doctor`, and `Actions`.
- **D-88-13:** The component kit includes nav shell, tables, lifecycle-state
  chips, buttons, confirm dialog, drawer, toasts, empty states, and skeletons.
- **D-88-14:** Components should support task-first operations workflows, not
  decorative analytics dashboard widgets or marketing-style layouts.
- **D-88-15:** Motion in buttons, drawers, toasts, skeletons, and transitions
  must use the locked motion tokens, respect `prefers-reduced-motion`, and
  remain tied to real operational feedback.

### Gallery, Screenshots, And Gates

- **D-88-16:** Provide a deterministic component-gallery harness that maintainers
  can review before Phase 89/90 rely on the kit.
- **D-88-17:** The gallery must use stable selectors and cover light, dark, and
  system/auto theme behavior.
- **D-88-18:** Extend the existing `brandbook/src/contrast.mjs` style of
  mechanical WCAG AA checks to console-specific token/component pairs.
- **D-88-19:** Screenshot review should include realistic ready, processing,
  warning, danger, quarantine, info, empty, loading, and focus states so later
  console phases inherit accessible component defaults.

### the agent's Discretion

The maintainer confirmed the assumptions as presented. The planner may choose
the exact gallery implementation path - extending the Cohort Playwright harness,
creating a separate admin-gallery harness, or generating static gallery HTML
with a Node/Playwright screenshot script - as long as it stays deterministic,
avoids Cohort Tailwind/daisyUI leakage into the shipped library console, and
supports maintainer screenshot review.

Routine file layout, helper naming, selector naming within the locked BEM
contract, screenshot command names, and exact docs wording can be resolved
during planning unless they affect public API shape, auth semantics, dependency
footprint, destructive operations, security/compliance boundaries, recurring
cost, or milestone scope.

### Deferred Ideas (OUT OF SCOPE)
## Deferred Ideas

None - analysis stayed within Phase 88 scope.

### Reviewed Todos (not folded)

No matching pending todos were found for Phase 88.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DS-01 | `rindle-admin` design system generated from `brandbook/tokens/tokens.json` with BEM and CSS custom properties. | Use a new deterministic Node generator beside `brandbook/src/tokens-build.mjs`; consume token JSON, emit namespaced BEM component CSS, and treat output as generated. [VERIFIED: `.planning/REQUIREMENTS.md`, `brandbook/src/tokens-build.mjs`, `guides/rindle_admin_css.md`] |
| DS-02 | Light/dark/system theme picker as a first-class component using `data-theme` and `prefers-color-scheme`. | Existing token CSS already emits `[data-theme="dark"]` and `[data-theme="auto"]` dark media scopes; implement the component against the same attribute contract. [VERIFIED: `brandbook/src/tokens-build.mjs`, `guides/rindle_admin_css.md`; CITED: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/color-scheme] |
| DS-03 | Mechanical WCAG AA contrast gate over console token pairs. | Extend the existing `contrast.mjs` luminance/ratio script and add console component/status/focus pairs; W3C documents 4.5:1 normal text and 3:1 large text/non-text rationale. [VERIFIED: `brandbook/src/contrast.mjs`; CITED: https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html] |
| ADMIN-02 groundwork | Console ships self-contained precompiled assets with zero host asset-pipeline or Tailwind dependency. | Phase 88 should generate assets intended for later `priv/static/rindle_admin` packaging, but must not implement the Phase 89 Plug.Static route. [VERIFIED: `.planning/REQUIREMENTS.md`, `guides/admin_console_architecture.md`, `88-CONTEXT.md`] |
</phase_requirements>

## Summary

Phase 88 should be planned as a self-contained design-system buildout, not as a mounted admin console implementation. The source of truth is already local: `brandbook/tokens/tokens.json` contains semantic tokens, typography, spacing, radii, focus, motion, and contrast pairs; `brandbook/src/tokens-build.mjs` shows the generated-artifact pattern; `brandbook/src/contrast.mjs` shows the WCAG gate pattern. [VERIFIED: local repo]

The lowest-risk plan is to add a second generated artifact pipeline for `rindle-admin` component CSS and static gallery HTML/JS, then verify it with the existing Node and Playwright ecosystem already present in the repo. [VERIFIED: local repo] No third-party UI framework, registry, Tailwind dependency, Radix dependency, or host asset build should be introduced. [VERIFIED: `88-CONTEXT.md`, `guides/ui_principles.md`]

**Primary recommendation:** Use a dedicated `brandbook/src/admin-*` generator/checker path that emits namespaced vanilla `rindle-admin` CSS plus a static gallery harness, reuses Playwright for maintainer screenshots, and extends `brandbook/src/contrast.mjs`-style checks for console token pairs. [VERIFIED: local repo; CITED: https://playwright.dev/docs/screenshots]

## Project Constraints (from AGENTS.md)

- Follow `guides/release_publish.md` and `RUNNING.md` for CI lanes and release gates. [VERIFIED: `AGENTS.md`]
- Keep edits focused and run the checks named by `RUNNING.md` for the change. [VERIFIED: `AGENTS.md`, `RUNNING.md`]
- Update `.planning/PROJECT.md` only when intentionally changing product scope or shipped claims. [VERIFIED: `AGENTS.md`]
- For UI/admin-console work, follow `guides/ui_principles.md` before changing console, Cohort, E2E, or visual-polish surfaces. [VERIFIED: `AGENTS.md`]
- Keep main green on merge-blocking CI jobs: Quality/coveralls, Integration, Proof, Package Consumer, and Adopter. [VERIFIED: `AGENTS.md`, `RUNNING.md`]
- Prefer PR-first execution for serious milestone or feature-depth work. [VERIFIED: `AGENTS.md`]
- Before release prep, run `./scripts/maintainer/repo_hygiene_check.sh`. [VERIFIED: `AGENTS.md`]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Token-to-CSS generation | Build / Static | Browser / Client | Generated CSS must be reproducible from token JSON before runtime; browser only consumes the emitted variables/classes. [VERIFIED: `brandbook/src/tokens-build.mjs`, `88-CONTEXT.md`] |
| Theme picker | Browser / Client | Build / Static | The component writes `data-theme="light|dark|auto"` and CSS resolves the theme, including `prefers-color-scheme` for auto. [VERIFIED: `brandbook/src/tokens-build.mjs`; CITED: MDN color-scheme docs] |
| Component markup kit | Frontend Server (SSR/LiveView-ready markup) | Browser / Client | Phase 88 prepares reusable Phoenix/LiveView-compatible markup patterns without requiring LiveView for non-console adopters. [VERIFIED: `88-CONTEXT.md`, `mix.exs`, `lib/rindle/live_view.ex`] |
| Gallery screenshot harness | Browser / Client | Build / Static | Playwright drives a rendered static or demo gallery and saves screenshots for maintainer review. [VERIFIED: `examples/adoption_demo/playwright.config.js`; CITED: https://playwright.dev/docs/screenshots] |
| Contrast gate | Build / Static | — | Contrast is a mechanical Node check over token/component pairs and should fail before runtime. [VERIFIED: `brandbook/src/contrast.mjs`; CITED: W3C WCAG contrast docs] |
| Future asset serving | API / Backend | CDN / Static | Phase 88 prepares static assets; Phase 89 owns `Plug.Static` serving from the `:rindle` OTP app. [VERIFIED: `guides/admin_console_architecture.md`, `88-CONTEXT.md`] |

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Node.js | v22.14.0 installed locally | Run token generators, CSS emitters, contrast checks, and gallery scripts. | Existing brandbook scripts are Node modules using `node:fs`, `node:path`, and ESM. [VERIFIED: local command, `brandbook/src/tokens-build.mjs`] |
| `brandbook/tokens/tokens.json` | `$meta.version` 1.0.0 | Design-token source for admin colors, typography, spacing, focus, motion, and contrast pairs. | Locked source of truth for the Rindle brand and admin design system. [VERIFIED: `brandbook/tokens/tokens.json`, `guides/ui_principles.md`] |
| `brandbook/src/tokens-build.mjs` pattern | Existing local script | Generate CSS custom properties from token JSON and verify parity. | It already emits `:root`, `[data-theme="dark"]`, and `[data-theme="auto"]` scopes with `--rindle-` variables. [VERIFIED: `brandbook/src/tokens-build.mjs`] |
| `brandbook/src/contrast.mjs` pattern | Existing local script | Compute WCAG ratios and fail on under-threshold pairs. | Existing gate passes 38/38 token pairs and matches DS-03's required mechanical check style. [VERIFIED: local command, `brandbook/src/contrast.mjs`] |
| `@playwright/test` | 1.60.0 current npm, 1.60.0 installed under `examples/adoption_demo` | Deterministic browser rendering and screenshot capture. | Existing E2E harness uses Playwright; official docs support file, full-page, and element screenshots. [VERIFIED: npm registry, `examples/adoption_demo/package.json`; CITED: https://playwright.dev/docs/screenshots] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| `opentype.js` | 2.0.0 current npm, 2.0.0 installed under `brandbook/src` | Existing brandbook font/logo pipeline dependency. | Reuse only if new generated assets need existing brandbook font measurement behavior; do not add to console runtime. [VERIFIED: npm registry, `brandbook/src/package.json`] |
| Phoenix/LiveView markup conventions | `phoenix_live_view ~> 1.0` optional in `mix.exs` | Future console components will render through Phoenix/LiveView, but Phase 88 must keep it optional. | Use for markup shape research only; no unguarded LiveView compile-time dependency in Phase 88. [VERIFIED: `mix.exs`, `lib/rindle/live_view.ex`] |
| `data-*` attributes | Web platform | Stable selectors and component state hooks such as `data-theme`, `data-rindle-admin-component`, and screenshot selectors. | Use for deterministic gallery/test hooks without text-only assertions. [CITED: https://developer.mozilla.org/en-US/docs/Web/HTML/How_to/Use_data_attributes; VERIFIED: `guides/ui_principles.md`] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Static admin-gallery HTML + Playwright script | Extend `examples/adoption_demo` Playwright harness | Extending Cohort reuses more infrastructure but risks Tailwind/daisyUI leakage; static gallery better isolates the shipped library CSS. [VERIFIED: `88-CONTEXT.md`, `examples/adoption_demo/playwright.config.js`] |
| Vanilla CSS/BEM | Tailwind, daisyUI, shadcn, Radix, Tailwind UI | Alternatives are disallowed by locked decisions because the shipped console must be host-independent and registry-free. [VERIFIED: `88-CONTEXT.md`, `guides/ui_principles.md`] |
| Mechanical token contrast gate | Manual visual review only | Manual review is required for screenshots, but DS-03 requires a mechanical WCAG gate over token pairs. [VERIFIED: `.planning/REQUIREMENTS.md`, `brandbook/src/contrast.mjs`] |

**Installation:**
```bash
# No new runtime UI packages are recommended for Phase 88.
# Reuse existing package roots:
cd brandbook/src && npm install
cd ../../examples/adoption_demo && npm install && npm run e2e:install
```

**Version verification performed:**
```bash
npm view @playwright/test version time.created time.modified repository.url scripts.postinstall --json
npm view opentype.js version time.created time.modified repository.url scripts.postinstall --json
npm view tus-js-client version time.created time.modified repository.url scripts.postinstall --json
```

## Package Legitimacy Audit

> Phase 88 should not add new runtime UI dependencies. This audit covers existing npm packages likely to be reused by the generator/gallery path. [VERIFIED: local repo]

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| `@playwright/test` [VERIFIED: npm registry] | npm | Created 2020-09-24; modified 2026-06-11 | Not fetched by `npm view`; registry metadata verified | `github.com/microsoft/playwright` | OK with `--ecosystem npm` | Approved for existing screenshot harness reuse |
| `opentype.js` [VERIFIED: npm registry] | npm | Created 2013-09-27; modified 2026-05-06 | Not fetched by `npm view`; registry metadata verified | `github.com/opentypejs/opentype.js` | OK with `--ecosystem npm` | Approved for existing brandbook build reuse only |
| `tus-js-client` [VERIFIED: npm registry] | npm | Created 2015-08-20; modified 2026-01-13 | Not fetched by `npm view`; registry metadata verified | `github.com/tus/tus-js-client` | OK with `--ecosystem npm` | Existing adoption-demo dependency; not needed for Phase 88 design-system work |

**Packages removed due to slopcheck [SLOP] verdict:** none after rerunning with `--ecosystem npm`. [VERIFIED: local command]  
**Packages flagged as suspicious [SUS]:** none. [VERIFIED: local command]  
**Audit caveat:** `slopcheck install` defaults to ecosystem detection and initially checked these npm names against PyPI, producing false SLOP results; the meaningful audit is the explicit `slopcheck install --ecosystem npm ...` run. [VERIFIED: local command]

## Architecture Patterns

### System Architecture Diagram

```text
brandbook/tokens/tokens.json
        |
        v
admin CSS generator (Node, deterministic)
        |
        +--> rindle-admin CSS artifact (BEM + --rindle-* variables)
        |         |
        |         v
        |   static component gallery HTML
        |         |
        |         v
        |   Playwright screenshot harness -> maintainer screenshots
        |
        +--> console contrast pair manifest/checks
                  |
                  v
          WCAG contrast gate exits non-zero on failures

Later phases:
rindle-admin CSS artifact -> priv/static/rindle_admin -> Plug.Static route (Phase 89)
component markup patterns -> Rindle.Admin LiveViews (Phase 89/90)
```

### Recommended Project Structure

```text
brandbook/
├── src/
│   ├── admin-css-build.mjs        # generate rindle-admin component CSS from tokens
│   ├── admin-contrast.mjs         # console-specific contrast pairs, same gate style
│   └── admin-gallery.mjs          # generate static gallery HTML/fixtures if chosen
├── tokens/
│   ├── tokens.json                # source of truth
│   ├── tokens.css                 # existing generated brand tokens
│   └── rindle-admin.css           # generated admin component CSS artifact
└── admin-gallery/
    ├── index.html                 # deterministic rendered component gallery
    └── screenshots/               # maintainer review output, if committed by plan

test/
└── rindle/
    └── admin_design_system_test.exs # package/file assertions if assets enter package files
```

Planner note: if the gallery output is not intended for Hex packaging, keep it under `brandbook/admin-gallery/` and keep packaged assets under a later Phase 89 `priv/static/rindle_admin/` path. [VERIFIED: `guides/admin_console_architecture.md`, `mix.exs` package files]

### Pattern 1: Token-Driven CSS Generation

**What:** Read `tokens.json`, resolve raw token references, emit CSS custom properties and BEM component classes into a generated artifact. [VERIFIED: `brandbook/src/tokens-build.mjs`]  
**When to use:** All `rindle-admin` CSS, including components and theme variants. [VERIFIED: `88-CONTEXT.md`]

**Example:**
```javascript
// Source: brandbook/src/tokens-build.mjs
const raw = T.color.raw;
const deref = (v) => v.replace(/\{([a-z0-9-]+)\}/g, (_, k) => {
  if (!(k in raw)) throw new Error(`unknown raw token reference: {${k}}`);
  return raw[k];
});
```

### Pattern 2: Attribute-Scoped Theme Contract

**What:** Use `data-theme="light|dark|auto"` on the gallery/admin root and let CSS variables resolve the actual colors. [VERIFIED: `brandbook/src/tokens-build.mjs`, `guides/rindle_admin_css.md`]  
**When to use:** Theme picker component, screenshot harness, and future mounted console root. [VERIFIED: `88-CONTEXT.md`]

**Example:**
```css
/* Source: brandbook/src/tokens-build.mjs pattern */
[data-theme="dark"] {
  --rindle-surface: #0E1316;
}

@media (prefers-color-scheme: dark) {
  [data-theme="auto"] {
    --rindle-surface: #0E1316;
  }
}
```

### Pattern 3: Deterministic Screenshot Harness

**What:** Render the gallery at stable routes/files, set explicit viewport/theme states, and save screenshots with deterministic names. [VERIFIED: `examples/adoption_demo/playwright.config.js`; CITED: https://playwright.dev/docs/screenshots]  
**When to use:** Maintainer review before Phase 89/90 consume the component kit. [VERIFIED: `88-CONTEXT.md`]

**Example:**
```javascript
// Source: Playwright official screenshots docs
await page.screenshot({ path: 'brandbook/admin-gallery/screenshots/light.png', fullPage: true });
await page.locator('[data-rindle-admin-component="status-chips"]').screenshot({
  path: 'brandbook/admin-gallery/screenshots/status-chips-dark.png'
});
```

### Anti-Patterns to Avoid

- **Hand-editing generated CSS:** Generated artifacts drift from token source and make contrast/parity gates unreliable; edit generator/source data instead. [VERIFIED: `88-CONTEXT.md`, `brandbook/src/tokens-build.mjs`]
- **Adding a UI dependency registry:** shadcn/Radix/Tailwind UI/daisyUI registries violate the locked host-independent library console boundary. [VERIFIED: `88-CONTEXT.md`, `guides/ui_principles.md`]
- **Color-only status semantics:** Fails the project accessibility contract and makes lifecycle state ambiguous; use visible labels plus icons/non-color marks. [VERIFIED: `guides/rindle_admin_css.md`, `guides/ui_principles.md`]
- **Decorative dashboard cards:** The six surfaces are task-first operator surfaces, not analytics decoration. [VERIFIED: `guides/admin_console_ia.md`]
- **Making LiveView required:** Phase 88 can prepare markup patterns but must preserve optional dependency posture for non-console adopters. [VERIFIED: `mix.exs`, `lib/rindle/live_view.ex`, `88-CONTEXT.md`]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Browser automation and screenshots | A custom Puppeteer/raw CDP wrapper | Existing `@playwright/test` harness | Playwright already exists in the repo and official docs support page/full-page/element screenshots. [VERIFIED: `examples/adoption_demo/package.json`; CITED: Playwright docs] |
| WCAG ratio math variations | Ad hoc per-component manual checks | Extend `brandbook/src/contrast.mjs` | Existing script already implements luminance and ratio gates and passes 38/38 pairs. [VERIFIED: local command] |
| Theme conventions | Parallel `class="dark"` or host-framework theme state | `data-theme="light|dark|auto"` + `prefers-color-scheme` | Existing generated token CSS and locked decisions already use this contract. [VERIFIED: `brandbook/src/tokens-build.mjs`, `88-CONTEXT.md`] |
| Component styling system | Tailwind/daisyUI/shadcn/Radix component import | Vanilla BEM + CSS custom properties | Locked host-independent packaging boundary forbids host asset-pipeline or registry dependency. [VERIFIED: `88-CONTEXT.md`] |
| Status icon meaning | Color-only badges or unlabeled icons | Text label plus inline/self-contained mark | Local UI contract requires non-color state communication. [VERIFIED: `guides/ui_principles.md`] |

**Key insight:** The hard part is not inventing components; it is keeping future console work inside a reproducible, packageable, accessible, host-independent CSS contract. [VERIFIED: `88-CONTEXT.md`, `guides/admin_console_architecture.md`]

## Common Pitfalls

### Pitfall 1: Generated CSS Drift
**What goes wrong:** Developers patch `rindle-admin.css` directly and later generator runs overwrite fixes. [VERIFIED: `88-CONTEXT.md`]  
**Why it happens:** The repo already has generated brand assets, but Phase 88 adds a second generated surface. [VERIFIED: local repo]  
**How to avoid:** Put all component CSS in source templates/generator logic and add a parity/check command. [VERIFIED: `brandbook/src/tokens-build.mjs`]  
**Warning signs:** Diff contains only generated CSS changes without matching generator/token changes. [ASSUMED]

### Pitfall 2: Cohort Stack Leakage
**What goes wrong:** The admin kit accidentally depends on Cohort Tailwind/daisyUI or app asset compilation. [VERIFIED: `88-CONTEXT.md`]  
**Why it happens:** The existing E2E harness lives under `examples/adoption_demo`, where frontend tooling differs from the shipped library console. [VERIFIED: `examples/adoption_demo/package.json`, `88-CONTEXT.md`]  
**How to avoid:** Prefer a static gallery or isolated harness that imports only generated `rindle-admin` CSS. [VERIFIED: `88-CONTEXT.md`]  
**Warning signs:** Admin gallery classes include Tailwind utilities, daisyUI classes, or app-specific asset paths. [ASSUMED]

### Pitfall 3: Theme Picker Stores a Parallel Convention
**What goes wrong:** A component uses `class="dark"`, local storage only, or a host-specific convention while CSS listens to `data-theme`. [VERIFIED: `brandbook/src/tokens-build.mjs`, `88-CONTEXT.md`]  
**Why it happens:** Many web stacks default to class-based dark mode. [ASSUMED]  
**How to avoid:** Make the component's only DOM contract `data-theme="light|dark|auto"` on the admin/gallery root; persistence can be added later without changing CSS. [VERIFIED: `88-CONTEXT.md`]  
**Warning signs:** CSS selectors include `.dark`, `.theme-dark`, or Tailwind dark-mode selectors. [ASSUMED]

### Pitfall 4: Contrast Gate Misses Component Pairs
**What goes wrong:** Tokens pass but buttons, chips, focus rings, disabled states, or surfaces fail once combined in components. [ASSUMED]  
**Why it happens:** Current `contrast_pairs` cover brand/token pairs, not every future component role. [VERIFIED: `brandbook/tokens/tokens.json`]  
**How to avoid:** Add an explicit console contrast manifest for primary/secondary/destructive buttons, chips, focus rings, table text, empty states, toasts, dialog/drawer surfaces, and skeleton contrast. [VERIFIED: DS-03; CITED: W3C WCAG contrast docs]  
**Warning signs:** New components introduce raw hex values or untested foreground/background combinations. [VERIFIED: `guides/ui_principles.md`]

### Pitfall 5: Optional LiveView Boundary Regression
**What goes wrong:** Component modules alias Phoenix/LiveView at compile time and make default adopters require LiveView. [VERIFIED: `88-CONTEXT.md`, `mix.exs`]  
**Why it happens:** Future console implementation is LiveView-oriented, but Phase 88 is only groundwork. [VERIFIED: `guides/admin_console_architecture.md`]  
**How to avoid:** Keep Phase 88 assets/generators in Node/static files or guarded Elixir modules; follow `Code.ensure_loaded?/1` when touching LiveView code. [VERIFIED: `lib/rindle/live_view.ex`]  
**Warning signs:** `mix deps.unlock phoenix_live_view` or default compile fails without optional deps. [ASSUMED]

## Code Examples

Verified patterns from official/local sources:

### Contrast Gate Extension Pattern
```javascript
// Source: brandbook/src/contrast.mjs
const ratio = (a, b) => {
  const [l1, l2] = [lum(a), lum(b)].sort((x, y) => y - x);
  return (l1 + 0.05) / (l2 + 0.05);
};
```

### Theme CSS Pattern
```css
/* Source: brandbook/src/tokens-build.mjs */
[data-theme="dark"] {
  --rindle-text: #F1F7F3;
}

@media (prefers-color-scheme: dark) {
  [data-theme="auto"] {
    --rindle-text: #F1F7F3;
  }
}
```

### Status Chip Markup Pattern
```html
<!-- Source: guides/rindle_admin_css.md + Phase 88 context -->
<span class="rindle-admin-status-chip rindle-admin-status-chip--processing" data-state="processing">
  <span class="rindle-admin-status-chip__mark" aria-hidden="true">...</span>
  <span class="rindle-admin-status-chip__label">Processing</span>
</span>
```

### Screenshot Capture Pattern
```javascript
// Source: Playwright official screenshots docs
await page.screenshot({ path: 'brandbook/admin-gallery/screenshots/gallery-light.png', fullPage: true });
await page.locator('.rindle-admin-status-chip--danger').screenshot({
  path: 'brandbook/admin-gallery/screenshots/status-danger.png'
});
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Admin UI out of scope | Mountable Rindle-branded admin console in `rindle` package | v1.18 charter recorded 2026-06-10 | Phase 88 is now required groundwork for console assets and UI kit. [VERIFIED: `.planning/REQUIREMENTS.md`, `.planning/STATE.md`] |
| Manual visual contrast review | Mechanical token and component-pair contrast gates | Brand track and DS-03 | Contrast is build-verifiable before maintainer screenshot review. [VERIFIED: `brandbook/src/contrast.mjs`, `.planning/REQUIREMENTS.md`] |
| Host app styling assumptions | Self-contained generated vanilla CSS | Phase 86/88 locks | Adopters should not need Tailwind, daisyUI, esbuild, or host asset-pipeline integration for console styling. [VERIFIED: `guides/rindle_admin_css.md`] |
| Decorative dashboard IA | Six task-first operator surfaces | Phase 86 IA lock | Components should support operational diagnosis and actions, not analytics decoration. [VERIFIED: `guides/admin_console_ia.md`] |

**Deprecated/outdated:**
- Treating `brandbook/tokens/tokens.css` as complete console CSS: it is only the existing generated token artifact, not component CSS. [VERIFIED: `88-CONTEXT.md`]
- Any public docs or facade claims that Rindle has no admin UI: v1.18 intentionally reverses that claim; TRUTH-07 will update docs after shipping. [VERIFIED: `.planning/STATE.md`, `.planning/REQUIREMENTS.md`]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Generated CSS drift can be detected by requiring generator/source changes with generated CSS diffs. | Common Pitfalls | Planner may need to add a stricter check task if repo policy wants exact artifact diff verification. |
| A2 | Cohort stack leakage can be detected by scanning admin gallery/classes for Tailwind/daisyUI markers. | Common Pitfalls | A static scan may miss indirect CSS imports; screenshot harness should also render in isolation. |
| A3 | Many web stacks default to class-based dark mode. | Common Pitfalls | Low risk; the locked project convention still overrides external defaults. |
| A4 | Component contrast gaps may appear even when token pairs pass. | Common Pitfalls | Medium risk; planner should require explicit console component contrast pairs. |
| A5 | Unguarded LiveView aliases can break non-LiveView adopters. | Common Pitfalls | Medium risk; planner should include no-LiveView compile checks when Elixir modules are added. |

## Open Questions (RESOLVED)

1. **Should gallery screenshots be committed or generated on demand?** RESOLVED: Generate screenshots on demand under `brandbook/admin-gallery/screenshots/`; ignore screenshot PNGs by default unless the maintainer intentionally changes the commit policy.
   - What we know: Maintainer review of rendered gallery is required. [VERIFIED: `88-CONTEXT.md`]
   - Resolution: Plan deterministic generation, keep `brandbook/admin-gallery/.gitignore` excluding `screenshots/*.png`, and allow a maintainer policy change if review screenshots should later be committed. [RESOLVED]

2. **Exact output path for generated admin CSS before Phase 89 packaging** RESOLVED: Keep the generated Phase 88 admin CSS at `brandbook/tokens/rindle-admin.css`; Phase 89 owns moving or serving packaged assets from `priv/static/rindle_admin`.
   - What we know: Phase 89 serves assets from `:rindle` static assets; Phase 88 should not implement serving. [VERIFIED: `guides/admin_console_architecture.md`, `88-CONTEXT.md`]
   - Resolution: Phase 88 writes `brandbook/tokens/rindle-admin.css` as the generated design-system artifact and does not create `priv/static/rindle_admin`; Phase 89 handles `priv/static/rindle_admin` packaging and serving work. [RESOLVED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Node.js | Token/CSS/contrast/gallery scripts | yes | v22.14.0 | Use repo CI Node if local differs. [VERIFIED: local command] |
| npm | Existing package roots | yes | 11.1.0 | Use lockfiles in `brandbook/src` and `examples/adoption_demo`. [VERIFIED: local command] |
| Elixir/Mix | ExUnit/package assertions and optional boundary checks | yes | Elixir/Mix 1.19.5 local; project supports `~> 1.15` | CI matrix covers supported versions. [VERIFIED: local command, `mix.exs`, `RUNNING.md`] |
| Playwright CLI | Gallery screenshots | yes | 1.60.0 under `examples/adoption_demo` | `npm run e2e:install` installs Chromium for the adoption demo root. [VERIFIED: local command, `examples/adoption_demo/package.json`] |
| Chromium | Local screenshot browser | yes | command present at `/opt/homebrew/bin/chromium` | Playwright-managed Chromium cache is present. [VERIFIED: local command] |
| Docker | Not required for Phase 88; useful for later console preview | yes | 29.5.2 | Static gallery avoids Docker dependency for Phase 88 review. [VERIFIED: local command] |

**Missing dependencies with no fallback:** none found for Phase 88 research/planning. [VERIFIED: local command]  
**Missing dependencies with fallback:** none found. [VERIFIED: local command]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit via `mix test`; Node scripts for token/contrast gates; Playwright 1.60.0 for screenshots. [VERIFIED: `mix.exs`, `examples/adoption_demo/package.json`] |
| Config file | `mix.exs`; `examples/adoption_demo/playwright.config.js`; no root Playwright config. [VERIFIED: local file scan] |
| Quick run command | `node brandbook/src/tokens-build.mjs && node brandbook/src/contrast.mjs` plus new admin generator/check commands after implementation. [VERIFIED: local repo] |
| Full suite command | `mix coveralls` for merge-blocking unit coverage; `bash scripts/ci/adoption_demo_e2e.sh` for existing adoption demo E2E when relevant. [VERIFIED: `RUNNING.md`, `.github/workflows/ci.yml`] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DS-01 | Generated `rindle-admin` CSS is reproducible from `tokens.json`, uses BEM, and contains `--rindle-` variables. | Node unit/smoke + grep assertions | `node brandbook/src/admin-css-build.mjs && rg -F '.rindle-admin-' brandbook/tokens/rindle-admin.css && rg -F -- '--rindle-' brandbook/tokens/rindle-admin.css` | no, Wave 0 |
| DS-02 | Theme picker/gallery supports `light`, `dark`, and `auto` with `data-theme`. | Playwright/browser smoke | `cd examples/adoption_demo && npx playwright test e2e/admin-gallery.spec.js --project=chromium` or separate static harness command | no, Wave 0 |
| DS-03 | Console token/component pairs pass WCAG thresholds. | Node gate | `node brandbook/src/admin-contrast.mjs` | no, Wave 0 |
| ADMIN-02 groundwork | Generated assets are self-contained and do not rely on host Tailwind/daisyUI/esbuild. | Static scan + package assertion | `rg -n 'tailwind|daisy|shadcn|radix|@apply|class="[^"]*(btn|card)' brandbook/tokens/rindle-admin.css brandbook/admin-gallery || true` with planner-defined forbidden-result handling | no, Wave 0 |

### Sampling Rate

- **Per task commit:** Run the relevant generator/check command touched by that task. [VERIFIED: repo practice inferred from brandbook scripts]
- **Per wave merge:** Run all Phase 88 Node gates plus the gallery screenshot command. [ASSUMED]
- **Phase gate:** `mix coveralls`, Node token/admin contrast gates, and maintainer screenshot review before `$gsd-verify-work`. [VERIFIED: `RUNNING.md`, `88-CONTEXT.md`]

### Wave 0 Gaps

- [ ] `brandbook/src/admin-css-build.mjs` - generates DS-01 component CSS. [VERIFIED: absent by file scan]
- [ ] `brandbook/src/admin-contrast.mjs` or an extension to `contrast.mjs` - covers DS-03 console pairs. [VERIFIED: absent by file scan]
- [ ] `brandbook/admin-gallery/index.html` or equivalent - renders all required components/states. [VERIFIED: absent by file scan]
- [ ] `examples/adoption_demo/e2e/admin-gallery.spec.js` or separate gallery screenshot script - captures light/dark/auto screenshots. [VERIFIED: absent by file scan]
- [ ] Optional ExUnit package/file test if generated assets enter `mix.exs` package files in this phase. [ASSUMED]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no for Phase 88 | Do not implement router macro, auth pipeline, or safe mount in this phase; Phase 89 owns host auth. [VERIFIED: `88-CONTEXT.md`, `guides/admin_console_architecture.md`] |
| V3 Session Management | no for Phase 88 | No session behavior beyond static gallery/theme component. [VERIFIED: `88-CONTEXT.md`] |
| V4 Access Control | no for Phase 88 | Do not add admin routes or query/action surfaces. [VERIFIED: `88-CONTEXT.md`] |
| V5 Input Validation | yes, limited | Validate generator inputs, token references, theme values, and component state names against allowlists. [VERIFIED: `brandbook/src/tokens-build.mjs` pattern] |
| V6 Cryptography | no for Phase 88 | Do not implement auth/session/nonce generation; future CSP nonce assignment belongs to Phase 89 host mount options. [VERIFIED: `guides/admin_console_architecture.md`] |

### Known Threat Patterns for Phase 88 Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Host CSS/JS dependency creep | Tampering | Generate self-contained namespaced CSS; statically scan for Tailwind/daisyUI/registry leakage. [VERIFIED: `88-CONTEXT.md`] |
| Unsafe HTML in static gallery examples | XSS / Information Disclosure | Keep gallery data static and escaped; avoid rendering untrusted media metadata in Phase 88. [ASSUMED] |
| Color-only destructive or lifecycle state | Information Disclosure / Safety UX failure | Require labels/icons and token-gated contrast pairs for all status components. [VERIFIED: `guides/ui_principles.md`] |
| Optional dependency regression | Denial of Service | Keep LiveView optional and compile-gated; use `Code.ensure_loaded?/1` if Elixir modules are introduced. [VERIFIED: `mix.exs`, `lib/rindle/live_view.ex`] |

## Sources

### Primary (HIGH confidence)

- `88-CONTEXT.md` - locked Phase 88 decisions, component inventory, gallery/contrast constraints.
- `.planning/REQUIREMENTS.md` - DS-01, DS-02, DS-03, ADMIN-02 groundwork.
- `.planning/STATE.md` - current phase, v1.18 scope reversal, release posture.
- `AGENTS.md` - repo workflow, UI/admin guidance, release-train constraints.
- `guides/ui_principles.md` - PRIN-01 UI/a11y/motion/security constraints.
- `guides/rindle_admin_css.md` - CSS architecture, BEM, theme, status-chip contract.
- `guides/admin_console_ia.md` - six operator surfaces and task-first IA.
- `guides/admin_console_motion.md` - motion token and reduced-motion contract.
- `guides/admin_console_architecture.md` - Phase 89 boundaries and optional dependency posture.
- `brandbook/tokens/tokens.json` - token source and current 38 contrast pairs.
- `brandbook/src/tokens-build.mjs` - token-generated CSS pattern.
- `brandbook/src/contrast.mjs` - WCAG ratio gate pattern.
- `mix.exs` and `lib/rindle/live_view.ex` - optional LiveView dependency pattern.
- `examples/adoption_demo/package.json` and `playwright.config.js` - existing Playwright harness.

### Secondary (MEDIUM confidence)

- https://playwright.dev/docs/screenshots - official screenshot API and full-page/element screenshot guidance.
- https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html - official WCAG 2.1 contrast rationale and thresholds.
- https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/color-scheme - color-scheme and `prefers-color-scheme` guidance.
- https://developer.mozilla.org/en-US/docs/Web/HTML/How_to/Use_data_attributes - data attribute and dataset usage.

### Tertiary (LOW confidence)

- None used as authoritative input. [VERIFIED: research process]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - based on locked local docs, existing scripts, installed packages, npm registry metadata, and slopcheck npm audit. [VERIFIED]
- Architecture: HIGH - Phase 86 and Phase 88 have explicit CSS/theme/package boundaries. [VERIFIED]
- Pitfalls: MEDIUM - core pitfalls are verified from repo constraints; a few warning signs are engineering assumptions logged above. [VERIFIED/ASSUMED]

**Research date:** 2026-06-11  
**Valid until:** 2026-07-11 for local architecture; 2026-06-18 for package versions and Playwright/browser behavior.
