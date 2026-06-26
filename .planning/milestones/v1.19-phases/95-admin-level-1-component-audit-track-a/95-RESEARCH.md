# Phase 95: admin-level-1-component-audit-track-a - Research

**Researched:** 2026-06-15  
**Domain:** Generated admin design-system primitives, CSS state matrix, gallery proof, WCAG contrast gates  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Level-1 Scope

- **D-95-01:** Audit only the approved Level-1 `rindle-admin` primitive inventory from
  `95-UI-SPEC.md`: shell, nav, table, status chip, button, theme picker, form controls,
  confirm dialog, drawer, toast, empty/error state, and skeleton/loading state.
- **D-95-02:** Close inventory gaps inside the Level-1 layer, especially form controls
  and distinct empty/error/loading/skeleton primitives, without expanding into Phase 97
  meta-components or Phase 98 page composition.

### Generated CSS Boundary

- **D-95-03:** Emit all new component-state styling from
  `brandbook/src/admin-css-build.mjs`, backed by `brandbook/tokens/tokens.json` and shared
  constants in `brandbook/src/admin-design-system-data.mjs`.
- **D-95-04:** Do not hand-edit `brandbook/tokens/rindle-admin.css` or
  `priv/static/rindle_admin/rindle-admin.css`. Generated output must flow through the
  existing build/sync/drift gate.

### Gallery And Proof Surface

- **D-95-05:** Treat the static brandbook admin gallery and browser checker as the primary
  Phase 95 proof surface. Extend them to render and assert the Level-1 component x state x
  theme matrix with stable `data-rindle-admin-component` and `data-rindle-admin-state`
  markers.
- **D-95-06:** Keep the adoption-demo screenshot polish gate as downstream page proof. It
  may gain reusable computed-style assertions needed by Phase 95, but it should not replace
  the component-gallery audit.

### Interaction And Contrast Contract

- **D-95-07:** Make active/current state visually distinct from focus-visible on every
  applicable interactive primitive. Active may use pressed/current affordances such as
  `transform: translateY(1px)`, `aria-current`, `aria-pressed`, `.active`, or token-backed
  active fill/border; focus-visible remains a token-backed outline.
- **D-95-08:** Prove every required interactive selector has token-backed `:focus-visible`
  styling and no bare `outline:none`.
- **D-95-09:** Extend contrast coverage only through `CONSOLE_CONTRAST_PAIRS` and token
  vocabulary, including state/theme pairs introduced by the Level-1 matrix. No page-local
  color literals or one-off CSS exceptions.

### the agent's Discretion

The maintainer confirmed the assumptions as presented. Routine helper names, fixture
labels, exact gallery grouping, and assertion wording may be resolved during planning as
long as the decisions above remain intact and the implementation stays within UPLIFT-01.

### Deferred Ideas (OUT OF SCOPE)

None - analysis stayed within Phase 95 scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UPLIFT-01 | Every admin component is on-brand and excellent across the full interaction-state matrix in light, dark, and system themes, with explicit active vs focus-visible distinction and no one-off styles. | Use the existing generated CSS pipeline, shared component constants, gallery/checker, contrast pairs, and ExUnit validation as the implementation and proof path. [VERIFIED: codebase grep] |
</phase_requirements>

## Summary

Phase 95 should be planned as a hardening pass over the existing generated `rindle-admin` primitive layer, not as a new UI framework, Storybook, page-polish effort, or screenshot service. [VERIFIED: codebase grep] The authoritative implementation path is `tokens.json` plus `admin-design-system-data.mjs` plus `admin-css-build.mjs`, with proof in `admin-gallery.mjs`, `admin-gallery-check.mjs`, `admin-contrast.mjs`, and `test/brandbook/admin_design_system_validation_test.exs`. [VERIFIED: codebase grep]

The largest current gap is inventory and marker precision: `COMPONENTS` currently lists 11 primitives and omits explicit `form-controls` and distinct `error-state`, while the gallery/checker currently use plural grouped markers such as `status-chips`, `buttons`, `toasts`, and `skeletons`. [VERIFIED: codebase grep] Planning should normalize one Level-1 matrix vocabulary across data constants, CSS parity checks, gallery fixtures, browser assertions, contrast contexts, and ExUnit assertions. [VERIFIED: codebase grep]

**Primary recommendation:** Plan one vertical slice that first locks the Level-1 inventory/state matrix in shared data, then threads it through generated CSS, gallery fixtures, browser assertions, contrast pairs, and validation tests before syncing shipped CSS. [VERIFIED: codebase grep]

## Project Constraints (from AGENTS.md)

- Follow `guides/release_publish.md` and `RUNNING.md` for CI lanes and release gates. [VERIFIED: codebase grep]
- Keep edits focused and run the checks named by `RUNNING.md` for the change. [VERIFIED: codebase grep]
- Update `.planning/PROJECT.md` only when product scope or shipped claims intentionally change. [VERIFIED: codebase grep]
- For UI/admin-console work, follow `guides/ui_principles.md` before changing console, Cohort, E2E, or visual-polish surfaces. [VERIFIED: codebase grep]
- Preserve green-main release-train posture and merge-blocking lanes including Quality, Integration, Proof, Package Consumer, Adopter, Adoption Demo E2E, Cohort Demo Smoke, and `brandbook-tokens`. [VERIFIED: codebase grep]
- Prefer PR-first execution for serious milestone or feature-depth work. [VERIFIED: codebase grep]
- Avoid speculative milestone reopening during `demand-gated-pause` unless LIFE-06 or STREAM-10 signal exists. [VERIFIED: codebase grep]
- Before release prep, run `./scripts/maintainer/repo_hygiene_check.sh`. [VERIFIED: codebase grep]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Admin primitive state styling | CDN / Static | Browser / Client | CSS is generated into static package assets and applied by the browser through selectors and CSS custom properties. [VERIFIED: codebase grep] |
| Theme behavior | Browser / Client | CDN / Static | Existing contract is `data-theme="light|dark|auto"` plus `prefers-color-scheme`; the theme picker mutates attributes client-side. [VERIFIED: codebase grep] [CITED: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/%40media/prefers-color-scheme] |
| Component gallery proof | Browser / Client | Static file generation | `admin-gallery-check.mjs` generates static HTML, opens it in Playwright Chromium, asserts selectors/styles, and writes review screenshots. [VERIFIED: codebase grep] |
| Contrast gate | Build / Static validation | — | `admin-contrast.mjs` resolves token pairs from `CONSOLE_CONTRAST_PAIRS` and exits non-zero for unknown or below-minimum pairs. [VERIFIED: codebase grep] |
| Live admin component markup | Frontend Server / SSR | Browser / Client | Phoenix components emit `rindle-admin` classes and `data-rindle-admin-*` attributes; Phase 95 should only align primitives and selectors, not alter page semantics. [VERIFIED: codebase grep] |

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Node.js | v22.14.0 local | Runs brandbook `.mjs` generators/checkers. [VERIFIED: command output] | Existing generator and checker scripts are plain Node ES modules. [VERIFIED: codebase grep] |
| Playwright / Chromium | lockfile `1.60.0`; npm latest `1.61.0` modified 2026-06-15 | Browser-checks static gallery and screenshots. [VERIFIED: npm registry] | Existing `admin-gallery-check.mjs` imports Playwright from `examples/adoption_demo/package.json`. [VERIFIED: codebase grep] |
| ExUnit / Mix | Mix 1.19.5 local | Validates generated CSS, gallery, contrast, and dependency-boundary assertions. [VERIFIED: command output] | Existing `test/brandbook/admin_design_system_validation_test.exs` shells out to the Node gates. [VERIFIED: codebase grep] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| `brandbook/src/sync-admin-css.mjs` | repo-local | Mirrors generated admin CSS to `priv/static/rindle_admin/rindle-admin.css`. [VERIFIED: codebase grep] | Use after generator changes so the shipped package copy stays byte-identical. [VERIFIED: codebase grep] |
| `examples/adoption_demo/e2e/support/admin-polish.js` | repo-local | Computed-style assertions for rendered admin pages. [VERIFIED: codebase grep] | Extend only for reusable focus/active/no-outline assertions that complement the gallery proof. [VERIFIED: codebase grep] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Static gallery/checker | Storybook or a SaaS visual-regression tool | Forbidden by phase context and project UI boundary; existing deterministic static gallery already matches the package/no-new-deps posture. [VERIFIED: codebase grep] |
| Generated vanilla BEM CSS | Tailwind, daisyUI, Radix, shadcn, Tailwind UI | Forbidden for the shipped admin console package boundary. [VERIFIED: codebase grep] |
| Token contrast gate | Page-local color fixes | Violates D-95-09 and weakens the no-one-off-styles contract. [VERIFIED: codebase grep] |

**Installation:** No new packages should be installed for Phase 95. [VERIFIED: codebase grep]

## Package Legitimacy Audit

No external packages are recommended for installation in Phase 95. [VERIFIED: codebase grep] `slopcheck 0.6.1` is available locally, but the Package Legitimacy Gate is not applicable because the phase should use existing dependencies only. [VERIFIED: command output]

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| None | — | — | — | — | Not run | No install planned |

**Packages removed due to slopcheck [SLOP] verdict:** none  
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```text
tokens.json + admin-design-system-data.mjs
  -> admin-css-build.mjs exact() parity + required selector/token checks
  -> brandbook/tokens/rindle-admin.css
  -> sync-admin-css.mjs
  -> priv/static/rindle_admin/rindle-admin.css

shared Level-1 inventory/state matrix
  -> admin-gallery.mjs fixtures with data-rindle-admin-component/state markers
  -> admin-gallery-check.mjs Playwright assertions and screenshots
  -> admin-contrast.mjs CONSOLE_CONTRAST_PAIRS token checks
  -> ExUnit brandbook validation and CI brandbook-tokens gate

live Phoenix admin components
  -> emitted rindle-admin classes/data attributes
  -> downstream adoption-demo admin-polish.js page checks
```

### Recommended Project Structure

```text
brandbook/
├── tokens/tokens.json                 # source token vocabulary [VERIFIED: codebase grep]
├── src/admin-design-system-data.mjs    # shared themes/components/states/contrast pairs [VERIFIED: codebase grep]
├── src/admin-css-build.mjs             # generated CSS and parity self-check [VERIFIED: codebase grep]
├── src/admin-gallery.mjs               # static matrix fixture generation [VERIFIED: codebase grep]
├── src/admin-gallery-check.mjs         # browser assertions/screenshots [VERIFIED: codebase grep]
└── src/admin-contrast.mjs              # token-pair WCAG gate [VERIFIED: codebase grep]
priv/static/rindle_admin/
└── rindle-admin.css                    # shipped mirrored CSS copy [VERIFIED: codebase grep]
test/brandbook/
└── admin_design_system_validation_test.exs # ExUnit proof shell [VERIFIED: codebase grep]
```

### Pattern 1: Shared Matrix Constants

**What:** Define the Level-1 component inventory and applicable state names once in `admin-design-system-data.mjs`, then make CSS, gallery, checker, and tests import or exactly mirror that vocabulary. [VERIFIED: codebase grep]  
**When to use:** Use for `COMPONENTS`, state lists, expected screenshots, and contrast context coverage. [VERIFIED: codebase grep]  
**Example:**

```javascript
// Source: brandbook/src/admin-design-system-data.mjs [VERIFIED: codebase grep]
export const COMPONENTS = [
  'shell',
  'nav',
  'table',
  'status-chip',
  'button',
  'theme-picker',
  'confirm-dialog',
  'drawer',
  'toast',
  'empty-state',
  'skeleton',
];
```

### Pattern 2: Token-Backed Focus, Separate Active

**What:** Use `:focus-visible` for focus indication and token-backed `outline`/`outline-offset`; represent active/current state separately through pressed/current selectors such as `:active`, `aria-current`, or `aria-pressed`. [VERIFIED: codebase grep] [CITED: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Selectors/%3Afocus-visible]  
**When to use:** Every interactive primitive in the Phase 95 selector set. [VERIFIED: codebase grep]  
**Example:**

```css
/* Source: brandbook/src/admin-css-build.mjs [VERIFIED: codebase grep] */
.rindle-admin-button:active {
  transform: translateY(1px);
}

.rindle-admin-button:focus-visible {
  outline: var(--rindle-focus-width) solid var(--rindle-focus-ring);
  outline-offset: var(--rindle-focus-offset);
}
```

### Anti-Patterns to Avoid

- **Plural/grouped gallery markers:** `status-chips`, `buttons`, `toasts`, and `skeletons` do not match the singular Level-1 inventory and weaken matrix coverage. [VERIFIED: codebase grep]
- **Bare `outline:none`:** It directly conflicts with D-95-08 and should be rejected in generated admin CSS and gallery-local CSS. [VERIFIED: codebase grep]
- **Page-local color literals:** New state contrast must be represented through tokens and `CONSOLE_CONTRAST_PAIRS`, not one-off CSS. [VERIFIED: codebase grep]
- **Replacing gallery proof with live-page screenshots:** Phase 95 context makes the static gallery/checker primary and live adoption-demo proof downstream. [VERIFIED: codebase grep]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| WCAG contrast math for token pairs | A one-off visual checklist | Existing `admin-contrast.mjs` and `CONSOLE_CONTRAST_PAIRS` | The existing gate resolves semantic tokens and exits non-zero on failures. [VERIFIED: codebase grep] |
| Browser rendering/state proof | A manual screenshot checklist | Existing `admin-gallery-check.mjs` Playwright browser check | It already verifies rendered visibility, theme switching, screenshots, and selected computed styles. [VERIFIED: codebase grep] |
| CSS artifacts | Hand-edited committed CSS | `admin-css-build.mjs` plus `sync-admin-css.mjs` | Generated CSS artifacts are explicitly not hand-edited. [VERIFIED: codebase grep] |
| Focus heuristics | Generic `:focus` or active-as-focus styling | Token-backed `:focus-visible` and distinct active/current selectors | `:focus-visible` is designed for focus indicators under browser focus-visibility heuristics. [CITED: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Selectors/%3Afocus-visible] |

**Key insight:** The hard part is not drawing more component examples; it is proving that one shared Level-1 vocabulary drives styling, gallery states, contrast coverage, and shipped artifacts without drift. [VERIFIED: codebase grep]

## Common Pitfalls

### Pitfall 1: Inventory Drift Between Data, CSS, Gallery, And Tests
**What goes wrong:** A component is styled but not represented in the gallery/checker, or a gallery marker exists without CSS parity coverage. [VERIFIED: codebase grep]  
**Why it happens:** `admin-css-build.mjs`, `admin-gallery.mjs`, `admin-gallery-check.mjs`, and ExUnit currently duplicate expected component lists. [VERIFIED: codebase grep]  
**How to avoid:** Plan a shared-matrix update first, then update every exact/parity assertion in the same task. [VERIFIED: codebase grep]  
**Warning signs:** Singular `COMPONENTS` disagree with plural `data-rindle-admin-component` markers. [VERIFIED: codebase grep]

### Pitfall 2: ExUnit Command Appears Green While Tests Are Excluded
**What goes wrong:** `mix test test/brandbook/admin_design_system_validation_test.exs` can report zero tests because the file is tagged `:integration` and default exclusions apply. [VERIFIED: command output]  
**Why it happens:** The test module has `@moduletag :integration`. [VERIFIED: codebase grep]  
**How to avoid:** Use the Node gates directly for fast feedback, or plan an explicit include-tags command if the ExUnit wrapper must execute. [VERIFIED: command output]  
**Warning signs:** Output says `0 tests, 0 failures (4 excluded)`. [VERIFIED: command output]

### Pitfall 3: Auto/System Theme Under-Tested
**What goes wrong:** Light/dark pass, but `data-theme="auto"` does not follow OS preference. [VERIFIED: codebase grep]  
**Why it happens:** Auto relies on `@media (prefers-color-scheme: dark)` scoped to `[data-theme="auto"]`. [VERIFIED: codebase grep] [CITED: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/%40media/prefers-color-scheme]  
**How to avoid:** Keep `page.emulateMedia({ colorScheme: 'dark' })` coverage and assert computed dark values under auto. [VERIFIED: codebase grep]

### Pitfall 4: Focus And Active Collapse Into One Visual State
**What goes wrong:** A current nav item, pressed button, or selected theme option looks like keyboard focus. [VERIFIED: codebase grep]  
**Why it happens:** Current CSS has some active/current selectors, but gallery/checker does not yet mechanically compare active and focus-visible styles for each applicable primitive. [VERIFIED: codebase grep]  
**How to avoid:** Add computed-style assertions that focus-visible outline values equal focus tokens and active/current affordances differ in at least one non-outline property. [VERIFIED: codebase grep]

## Code Examples

### Browser Check Pattern

```javascript
// Source: brandbook/src/admin-gallery-check.mjs [VERIFIED: codebase grep]
const assertVisible = async (page, selector) => {
  const locator = page.locator(selector);
  assert(await locator.count() > 0, `missing selector: ${selector}`);
  assert(await locator.first().isVisible(), `selector not visible: ${selector}`);
};
```

### Existing Computed-Style Gate Extension Point

```javascript
// Source: examples/adoption_demo/e2e/support/admin-polish.js [VERIFIED: codebase grep]
async function assertAdminPolish(
  page,
  {
    viewport,
    surface,
    root = DEFAULT_ROOT,
    interactiveSelectors = DEFAULT_INTERACTIVE_SELECTORS,
  } = {}
) {
  await freezeMotion(page);
  // existing checks run here
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Human screenshot review as primary proof | Deterministic generated CSS, contrast, gallery browser check, and computed-style assertions | Phase 92/94 context | Planner should add assertions, not a new review service. [VERIFIED: codebase grep] |
| Hand-mirrored shipped CSS | Generated brandbook CSS plus sync script for shipped copy | Phase 94 context | Planner must include sync and empty diff after CSS generation. [VERIFIED: codebase grep] |
| Light/dark only | Light, dark, and `auto` with `prefers-color-scheme` | Phase 88+ context | Matrix coverage must include `auto`, not just explicit themes. [VERIFIED: codebase grep] |

**Deprecated/outdated:**
- Hand-editing `brandbook/tokens/rindle-admin.css` or `priv/static/rindle_admin/rindle-admin.css` is out of contract. [VERIFIED: codebase grep]
- Storybook/SaaS visual-regression tooling is out of contract for this package boundary. [VERIFIED: codebase grep]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| — | No `[ASSUMED]` claims are used; claims are codebase-verified, command-verified, registry-verified, or cited from official docs. | All | — |

## Open Questions (RESOLVED)

1. **Should the ExUnit brandbook validation be made runnable without remembering integration flags?**
   - Resolution: keep the existing `@moduletag :integration` behavior and make the explicit invocation part of the Phase 95 validation contract. Plans use `mix test --include integration test/brandbook/admin_design_system_validation_test.exs` whenever the ExUnit wrapper is required. [VERIFIED: command output]
   - Execution guard: Plan 03's final acceptance rejects the no-op path by requiring nonzero tests executed, not `0 tests, 0 failures`. [VERIFIED: command output]
   - Feedback split: Node gates remain the fast iteration checks; the tagged ExUnit command is the final integration wrapper proof. [VERIFIED: command output]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Node.js | `.mjs` generators/checkers | yes | v22.14.0 | none needed [VERIFIED: command output] |
| npm | package metadata and Playwright install if needed | yes | 11.1.0 | none needed [VERIFIED: command output] |
| Playwright Chromium | `admin-gallery-check.mjs` | yes through existing adoption demo deps | lockfile 1.60.0 | run `npm ci && npm run e2e:install` in `examples/adoption_demo` if missing [VERIFIED: codebase grep] |
| Mix / ExUnit | brandbook validation wrapper | yes | Mix 1.19.5 | use Node gates directly for quick proof [VERIFIED: command output] |
| git | drift checks | yes | 2.41.0 | none [VERIFIED: command output] |
| ripgrep | research/code audit | yes | 15.1.0 | none [VERIFIED: command output] |

**Missing dependencies with no fallback:** none found. [VERIFIED: command output]  
**Missing dependencies with fallback:** none found. [VERIFIED: command output]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Node scripts, Playwright Chromium, ExUnit/Mix [VERIFIED: codebase grep] |
| Config file | `examples/adoption_demo/playwright.config.js`; `mix.exs` [VERIFIED: codebase grep] |
| Quick run command | `node brandbook/src/admin-css-build.mjs && node brandbook/src/admin-contrast.mjs && node brandbook/src/admin-gallery-check.mjs` [VERIFIED: command output] |
| Full suite command | `node brandbook/src/admin-css-build.mjs && node brandbook/src/admin-contrast.mjs && node brandbook/src/admin-gallery-check.mjs && mix test --include integration test/brandbook/admin_design_system_validation_test.exs` [VERIFIED: command output] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| UPLIFT-01 | Generated Level-1 CSS has required selectors, token-backed focus, theme scopes, and reduced-motion block | unit/build | `node brandbook/src/admin-css-build.mjs` | yes [VERIFIED: codebase grep] |
| UPLIFT-01 | Contrast pairs pass in light and dark for new state/theme pairs | unit/build | `node brandbook/src/admin-contrast.mjs` | yes [VERIFIED: command output] |
| UPLIFT-01 | Gallery renders component/state/theme matrix and browser assertions pass | browser/integration | `node brandbook/src/admin-gallery-check.mjs` | yes [VERIFIED: command output] |
| UPLIFT-01 | Generated artifacts remain clean after regeneration | integration | `mix test --include integration test/brandbook/admin_design_system_validation_test.exs` | yes, command needs include tag [VERIFIED: codebase grep] |

### Sampling Rate

- **Per task commit:** `node brandbook/src/admin-css-build.mjs && node brandbook/src/admin-contrast.mjs` [VERIFIED: command output]
- **Per wave merge:** `node brandbook/src/admin-gallery-check.mjs` plus `git diff --exit-code -- brandbook/tokens/rindle-admin.css brandbook/admin-gallery/index.html priv/static/rindle_admin/rindle-admin.css` [VERIFIED: command output]
- **Phase gate:** Full suite command above plus sync shipped CSS and empty working tree for generated artifacts. [VERIFIED: codebase grep]

### Wave 0 Gaps

- [ ] Add/normalize shared Level-1 component and state constants so `form-controls`, `error-state`, `loading-state`, and singular component names are first-class. [VERIFIED: codebase grep]
- [ ] Extend `admin-gallery-check.mjs` to assert focus-visible token values, active-vs-focus distinction, disabled/loading/empty/error/skeleton coverage, and exact state markers. [VERIFIED: codebase grep]
- [ ] Decide whether to document or fix the integration-tagged ExUnit invocation. [VERIFIED: command output]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | No auth semantics change; host auth boundary remains out of scope. [VERIFIED: codebase grep] |
| V3 Session Management | no | No session behavior change. [VERIFIED: codebase grep] |
| V4 Access Control | no | No new admin routes or write paths. [VERIFIED: codebase grep] |
| V5 Input Validation | yes | Keep gallery fixtures deterministic and non-secret; no runtime input handling change. [VERIFIED: codebase grep] |
| V6 Cryptography | no | No cryptographic behavior change. [VERIFIED: codebase grep] |

### Known Threat Patterns for Generated Admin UI

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Shipped CSS drift from brandbook CSS | Tampering | Use generator + sync + `git diff --exit-code`. [VERIFIED: codebase grep] |
| Hidden dependency on host UI framework | Tampering | Keep forbidden dependency/class checks in ExUnit and gallery checker. [VERIFIED: codebase grep] |
| Color-only state communication | Information disclosure / usability failure | Require labels/non-color marks and contrast gate coverage. [VERIFIED: codebase grep] |
| Weak keyboard focus visibility | Denial of service for keyboard users | Token-backed `:focus-visible` and computed-style assertions. [CITED: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Selectors/%3Afocus-visible] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/95-admin-level-1-component-audit-track-a/95-CONTEXT.md` - locked Phase 95 decisions. [VERIFIED: codebase grep]
- `.planning/phases/95-admin-level-1-component-audit-track-a/95-UI-SPEC.md` - Level-1 inventory, interaction contract, copy, proof commands. [VERIFIED: codebase grep]
- `guides/ui_principles.md` and `guides/admin_design_system.md` - project UI constraints and admin DS operating contract. [VERIFIED: codebase grep]
- `brandbook/src/admin-design-system-data.mjs` - themes, components, motion tokens, contrast pairs. [VERIFIED: codebase grep]
- `brandbook/src/admin-css-build.mjs` - generated CSS, focus/active selectors, parity checks. [VERIFIED: codebase grep]
- `brandbook/src/admin-gallery.mjs` and `brandbook/src/admin-gallery-check.mjs` - gallery fixtures and Playwright proof. [VERIFIED: codebase grep]
- `examples/adoption_demo/e2e/support/admin-polish.js` - computed-style page proof. [VERIFIED: codebase grep]
- `test/brandbook/admin_design_system_validation_test.exs` - ExUnit validation wrapper. [VERIFIED: codebase grep]
- `lib/rindle/admin/components.ex` - live Phoenix component selectors and state markers. [VERIFIED: codebase grep]
- MDN `:focus-visible` docs - focus-visible behavior and selector purpose. [CITED: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Selectors/%3Afocus-visible]
- MDN `prefers-color-scheme` docs - system light/dark media feature. [CITED: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/%40media/prefers-color-scheme]
- W3C WCAG 2.2 non-text contrast understanding - 3:1 meaningful visual cue guidance. [CITED: https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html]
- W3C WCAG contrast minimum understanding - 4.5:1 text contrast rationale. [CITED: https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html]
- Playwright screenshot docs - screenshot and animation disabling behavior. [CITED: https://playwright.dev/docs/screenshots] [CITED: https://playwright.dev/docs/api/class-pageassertions]

### Secondary (MEDIUM confidence)

- npm registry metadata for `@playwright/test` and `playwright`, checked 2026-06-15. [VERIFIED: npm registry]

### Tertiary (LOW confidence)

- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - existing repo tools and local versions were inspected; no new dependencies are recommended. [VERIFIED: command output]
- Architecture: HIGH - implementation path is fully present in codebase and locked by context. [VERIFIED: codebase grep]
- Pitfalls: HIGH - gaps are visible in current constants, gallery markers, and test invocation output. [VERIFIED: codebase grep]

**Research date:** 2026-06-15  
**Valid until:** 2026-07-15 for repo-local architecture; re-check npm/Playwright metadata if dependency changes are proposed.
