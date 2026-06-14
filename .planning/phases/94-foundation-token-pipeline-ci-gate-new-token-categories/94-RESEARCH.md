# Phase 94: Foundation — Token Pipeline CI Gate & New Token Categories - Research

**Researched:** 2026-06-14
**Domain:** Build-tooling / CI gating of a deterministic `tokens.json` → CSS generator pipeline (Node `.mjs`), plus additive token-category wiring. No application/runtime code; no new framework.
**Confidence:** HIGH (every claim verified against the live codebase in this session)

## Summary

Phase 94 is a **wiring phase, not a design phase**. All token VALUES are already locked in `94-UI-SPEC.md` (motion presets, the 4-step dark elevation/tint ladder, fluid `clamp()` tuples on display sizes + two fluid space gutters, named breakpoints, and the six differentiated dark status surfaces with their pre-computed AA ratios). The remaining work is mechanical: add those objects to `tokens.json`, emit them from the **admin** `.mjs` generators, register them in the parity arrays so they cannot be silently dropped, widen `CONSOLE_CONTRAST_PAIRS`, generalize one test harness signature, and stand up a single new CI job that regenerates everything and fails on any diff.

The pipeline is **already deterministic** — verified this session by double-running `tokens-build.mjs` and `admin-css-build.mjs` and diffing (byte-identical both times). Every generator iterates `Object.entries` over plain objects; there is no `Set`/`Map`/`Date.now()`/filesystem-glob ordering hazard. This confirms D-94-10: a single `regen; git diff --exit-code` is a sufficient idempotency anchor.

**This research surfaced a live, pre-existing drift bug that proves the phase's premise.** `brandbook/tokens/tokens.css` is committed but **already out of sync** with `tokens.json`: the dark `text-on-brand` was corrected in source to `{ink}` (`#101417`, the cream-on-green AA fix) but the committed `tokens.css` still ships the stale `#F7F4EA`. Re-running `tokens-build.mjs` produces a non-empty `git diff` *today*. **The `brandbook-tokens` gate this phase builds would immediately catch this** — it is the canonical PITFALL #6 failure, present right now, and committing the regenerated artifacts is part of this phase's done-state.

**Primary recommendation:** Add new top-level objects to `tokens.json`; for each, add (1) an emit loop in `admin-css-build.mjs`, (2) a parity entry in the `exact()` / `requiredSelectors` / `requiredTokenUses` / `MOTION_TOKENS` arrays, and (3) where it is a color, a `CONSOLE_CONTRAST_PAIRS` entry. Stand up `brandbook-tokens` as a standalone Node-20 job (`needs: [quality, optional-dependencies]`) that runs `tokens-build → admin-css-build → admin-contrast → admin-gallery-check → sync the shipped CSS copy → git diff --exit-code`. Generalize `assertAdminPolish` by threading `root` + `interactiveSelectors` with today's values as defaults.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Token source of truth | Build / source (`tokens.json`) | — | Single source; every CSS artifact derives from it |
| Admin CSS generation | Build (`admin-css-build.mjs`) | — | Generator is the only writer of `rindle-admin.css` |
| Shipped-package CSS artifact | Build → package (`priv/static/rindle_admin/`) | — | Mirrored copy that adopters consume; must be generator-controlled, not hand-copied |
| WCAG contrast gate | Build (`admin-contrast.mjs` + `CONSOLE_CONTRAST_PAIRS`) | CI | Pure-Node math on token hexes; no browser needed |
| Gallery render + browser proof | Build + headless Chromium (`admin-gallery*.mjs`) | CI | Validates generated CSS actually renders; resolves `playwright` from `examples/adoption_demo` |
| Drift gate (diff) | CI (`brandbook-tokens` job) | — | The merge-blocker; `git diff --exit-code` after regen |
| Computed-style polish harness | E2E test tier (`admin-polish.js`) | runs in `adoption-demo-e2e` | Browser-rendered assertions; generalized here, *consumed* later (Phase 102) |
| Cohort `.ck-*` CSS | Hand-authored (Track B, Phase 96) | — | LOCKED: never generated from `tokens.json` (ARCHITECTURE.md:111) — out of scope here |

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-94-01:** Add a **new standalone top-level job** `brandbook-tokens` to `.github/workflows/ci.yml`, `needs: [quality, optional-dependencies]` like the other proof lanes (`proof`, `contract`, `cohort-demo-smoke`, `adoption-demo-e2e`). Do **not** fold it into an existing lane — the brandbook pipeline is pure Node/Playwright and shares no Elixir/Postgres/MinIO/ffmpeg setup. Reuse the existing Node-20 `setup-node@v4` pattern (`ci.yml:467`, `696`).
- **D-94-02:** The job runs, in order: `tokens-build.mjs` → `admin-css-build.mjs` → `admin-contrast.mjs` → `admin-gallery-check.mjs` → **sync the second CSS copy** → `git diff --exit-code`. Install Playwright chromium / `npm ci` in `examples/adoption_demo` first, because `admin-gallery-check.mjs:14-15` resolves `playwright` via that package's `createRequire` (otherwise the gate red-herrings on "Cannot find module 'playwright'", not drift).
- **D-94-03:** The gate **must regenerate-and-diff BOTH committed CSS copies** — `brandbook/tokens/rindle-admin.css` (written by the generator) **and** the package-shipped `priv/static/rindle_admin/rindle-admin.css`, which is mirrored **by hand today** (no script copies it; it's listed in `mix.exs:279`). Make the copy a committed script/step (e.g. a `sync_admin_css` step or `.mjs` write) so it is the single mechanism, then diff it. Diffing only the brandbook copy would let the shipped package CSS drift silently — the exact failure this phase exists to kill (PITFALL #6).
- **D-94-04:** All three generated artifacts must be regenerated before the diff so the check is honest: `tokens.css` (`tokens-build.mjs:59`), `rindle-admin.css` (`admin-css-build.mjs:571`), and the gallery `index.html` (`admin-gallery.mjs:519`).
- **D-94-05:** Phase 94 emits the new categories into `tokens.json` + the `.mjs` **admin** generators + widened `CONSOLE_CONTRAST_PAIRS` **only**. It does **not** author Cohort's versions. "flowing to both `rindle-admin` and `cohort`" is satisfied by **parallel hand-authoring in Phase 96 (Track B B1)**, never a shared build step. (ARCHITECTURE.md:111 locked "Do NOT generate `cohort.css` from `tokens.json`".)
- **D-94-06:** Phase 94 may at most *seed shape* — document the parallel `--ck-*` token vocabulary so Phase 96 has a coherence/parity reference — but writes **no** `cohort.css`. The two design systems share vocabulary, never a stylesheet, token file, or build step.
- **D-94-07:** Generalize `admin-polish.js` by threading `root` + `interactiveSelectors` as **parameters** through `assertAdminPolish(page, { viewport, surface, root, interactiveSelectors })`, defaulting to today's `[data-rindle-admin-root]` / `.rindle-admin-*` set so the existing admin spec passes unchanged. Cohort later passes `[data-ck-root]` / `.ck-*`. **No auto-detection** of the root. The spec already passes a per-call `{viewport, surface}` options object — adding keys is the established seam (`admin-screenshots.spec.js:79`).
- **D-94-08:** New token categories plug into `tokens.json` as **new top-level objects** (`elevation`, extended `motion`, fluid `typography`/`spacing` steps, `color.semantic.{light,dark}` differentiated status surfaces). Each gets a matching emit loop in `admin-css-build.mjs` **and** a new entry in the `exact()` / `requiredTokenUses` parity arrays (and `MOTION_TOKENS` in `admin-design-system-data.mjs:44` for motion). Emitting a category without adding it to the parity arrays lets the generator self-check pass while the artifact silently omits it.
- **D-94-09:** Token *shape* is locked (values deferred to `/gsd:ui-phase 94`, now delivered in `94-UI-SPEC.md`): fluid `clamp()` on **display sizes only** (hero/h1/h2/h3); `body`/`small`/`code` stay fixed-px for table scannability; dark status surfaces **stop collapsing** to `dark-surface` (`tokens.json:99-104` confirms they collapse today); elevation is a **surface-tint ladder**, not heavier shadow.
- **D-94-10:** `git diff --exit-code` after a single regen is **sufficient** as the idempotency anchor — no separate double-run check required. Generators are deterministic (pure `Object.entries` iteration; `exact()` array-equality parity is the named anchor, STACK.md:33). If a future generator introduces ordering nondeterminism (`Set` / `Date.now()` / `Map`), a cheap `regen; regen; git diff` belt-and-suspenders becomes warranted.

### Claude's Discretion

Routine job-step naming, the exact filename of the CSS-sync script, the parameter object key names beyond `root`/`interactiveSelectors`, and where the `--ck-*` vocabulary reference is documented — provided they do not alter the public package artifact set, the merge-blocking gate semantics, the locked separate-build-step boundary, or the `data-theme` theme contract.

### Deferred Ideas (OUT OF SCOPE)

- **Cohort's `.ck-*` dark `[data-theme]` + `prefers-reduced-motion` + elevation/motion authoring** → Phase 96 (Track B B1). Net-new, hand-authored, no prior art in `cohort.css`.
- **Exact `clamp()` min/preferred/max tuples + named breakpoint set** → delivered by `94-UI-SPEC.md` (values now locked; this phase wires them).
- **Specific differentiated dark-status hex values + the 4-level elevation tint ramp** → delivered by `94-UI-SPEC.md` (values now locked).
- **Optional non-blocking pixel-baseline `toHaveScreenshot()`** → later milestone; never merge-blocking until proven stable.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PIPE-01 | Token→CSS pipeline gated in CI: regenerate from `tokens.json` via `.mjs`, run WCAG contrast gate, fail on uncommitted diff. | The `brandbook-tokens` job shape is fully specified below (Architecture Pattern 1). Existing proof-lane convention (`needs: [quality, optional-dependencies]`, `setup-node@v4`) confirmed at `ci.yml:631-648` (cohort-demo-smoke, the lightest template) and `649-758` (adoption-demo-e2e, the playwright template). Brandbook is **not gated today** (verified: zero grep hits for `admin-css-build`/`tokens-build`/`brandbook` in `.github/workflows/`). The diff target paths and sync mechanism are specified in Pattern 1. PIPE-01 scopes `rindle-admin.css` only in Phase 94; `cohort.css` generation is explicitly excluded (D-94-05). |
| PIPE-02 | Extend `tokens.json` + `.mjs` generators with motion presets, dark elevation/shadow ladder, fluid type+space scales + named breakpoints, semantic dark status surfaces. | The exact 3-touchpoint plug-in pattern (Pattern 2) plus per-category emit-loop and parity-array locations are documented. All VALUES are locked in `94-UI-SPEC.md`. Admin-only in Phase 94; the parallel `--ck-*` vocabulary is documented as a coherence reference, not authored (D-94-06). |
| VIS-01 (groundwork) | Generalize `admin-polish.js` computed-style harness to target any root selector. | `assertAdminPolish` signature and the module-level `ROOT` / `INTERACTIVE_SELECTORS` constants are mapped; threading pattern with safe defaults documented (Pattern 3). VIS-01 is *owned* by Phase 102 — Phase 94 only delivers the parameterized harness so the existing admin spec passes unchanged. |
</phase_requirements>

## Standard Stack

This phase adds **no new runtime dependencies**. Everything already exists in-repo and is verified present.

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Node | 20 in CI (`setup-node@v4`), 22.14 local | Runs the `.mjs` generators | Already the repo convention (`ci.yml:467,696`); local run verified this session |
| `playwright` (chromium) | `@playwright/test ^1.57.0` (resolved transitively for `playwright`) | Headless browser proof in `admin-gallery-check.mjs` | Already a `devDependency` in `examples/adoption_demo/package.json`; binary installed via `npx playwright install --with-deps chromium` |
| `git diff --exit-code` | git (preinstalled on runner) | The drift gate itself | Zero-dependency, exact, byte-level |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| `actions/checkout@v4` | Clone repo so the diff has a committed baseline | First step of the job |
| `actions/setup-node@v4` (node-version 20) | Provide Node | Reuse the exact block at `ci.yml:467-470` / `696-699` |
| `actions/upload-artifact@v4` | Upload gallery screenshots / diff on failure (optional, mirrors `adoption-demo-e2e:749`) | `if: failure()` only |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Standalone `brandbook-tokens` job | Fold into `adoption-demo-e2e` (already has playwright) | LOCKED OUT by D-94-01 — that lane carries Postgres/MinIO/ffmpeg setup the brandbook pipeline does not need; standalone is faster and clearer |
| `git diff --exit-code` drift gate | `regen; regen; git diff` double-run | D-94-10: single-run is sufficient because determinism is verified; double-run is a *future* belt-and-suspenders only if a `Set`/`Date.now()` is introduced |
| New `.mjs` for CSS sync | Reuse existing Elixir test `admin_design_system_validation_test.exs:213` equality assertion | The Elixir test *asserts equality* but does not *produce* the copy; the gate still needs a deterministic writer. See Pattern 1 for the recommended sync step. |

**Installation:** No `npm install` of new packages. CI install incantation (verified against `scripts/ci/adoption_demo_e2e.sh`):
```bash
cd examples/adoption_demo
npm ci
npx playwright install --with-deps chromium
```

## Package Legitimacy Audit

> No external packages are added by this phase. All tooling (`node`, `git`, `playwright`, `@playwright/test`) is already present in the repository and exercised by existing CI lanes. **slopcheck not applicable — zero new installs.**

| Package | Registry | Disposition |
|---------|----------|-------------|
| (none added) | — | N/A — phase adds no dependencies |

`@playwright/test ^1.57.0` is a pre-existing, already-installed devDependency of `examples/adoption_demo` (verified: `examples/adoption_demo/node_modules/playwright/package.json` present locally). Not introduced by this phase.

## Architecture Patterns

### System Architecture Diagram

```
                    brandbook/tokens/tokens.json   ← SINGLE SOURCE OF TRUTH
                    (new top-level objects added here first: elevation,
                     extended motion, fluid type/space, breakpoint,
                     differentiated color.semantic.{light,dark} status surfaces)
                              │
          ┌───────────────────┼───────────────────────────────┐
          ▼                   ▼                                 ▼
   tokens-build.mjs    admin-css-build.mjs              admin-contrast.mjs
   writes tokens.css   writes brandbook/tokens/         reads CONSOLE_CONTRAST_PAIRS
   (parity self-check) rindle-admin.css                 resolves fg/bg per theme,
          │            (exact() + requiredTokenUses     WCAG ratio gate, exit 1 on fail
          │             + MOTION_TOKENS self-check)             │
          │                   │                                 │
          │                   ▼                                 │
          │            admin-gallery.mjs ──► index.html         │
          │                   │                                 │
          │                   ▼                                 │
          │            admin-gallery-check.mjs                  │
          │            (resolves `playwright` via               │
          │             examples/adoption_demo createRequire;   │
          │             headless chromium renders gallery,      │
          │             asserts dark-chip contrast + shots)     │
          │                   │                                 │
          └─────────┬─────────┴────────────────┬────────────────┘
                    ▼                            ▼
        SYNC STEP: copy brandbook/tokens/rindle-admin.css
                 → priv/static/rindle_admin/rindle-admin.css   (NEW: scripted, not hand-copied)
                    │
                    ▼
            git diff --exit-code        ◄── THE MERGE-BLOCKING GATE
            (over tokens.css, rindle-admin.css [both copies],
             admin-gallery/index.html)
            non-empty diff  ⇒  build FAILS  ⇒  "Generated CSS is out of
                                                sync with tokens.json. Run
                                                the brandbook generators and
                                                commit the result."
```

The reader can trace the primary use case: a developer edits `tokens.json` → must run the generators → the regenerated artifacts are committed → CI re-runs the generators → if the committed artifacts match, diff is empty and the build passes; if the developer forgot to regenerate (or hand-edited a generated file), the diff is non-empty and the build fails.

### Component Responsibilities

| File | Role | Touched in Phase 94? |
|------|------|----------------------|
| `brandbook/tokens/tokens.json` | Source of truth | YES — add new top-level objects |
| `brandbook/src/tokens-build.mjs` | Emits `tokens.css` | MAYBE — only if new categories must appear in `tokens.css` (it emits raw + light-semantic + typography + spacing + motion already; see emit loops at lines 22-41) |
| `brandbook/src/admin-css-build.mjs` | Emits `rindle-admin.css`; parity self-check | YES — new emit loops + parity-array entries |
| `brandbook/src/admin-design-system-data.mjs` | `MOTION_TOKENS`, `CONSOLE_CONTRAST_PAIRS`, exact()-checked constant lists | YES — extend `MOTION_TOKENS` (line 44) + add dark-status-surface and elevation contrast pairs (line 54+) |
| `brandbook/src/admin-contrast.mjs` | WCAG gate over `CONSOLE_CONTRAST_PAIRS` | NO code change — it reads the data array; new pairs flow through automatically (but verify the `resolve()` lookup, see Pitfall 3) |
| `brandbook/src/admin-gallery.mjs` / `admin-gallery-check.mjs` | Render gallery + browser proof | LIKELY NO — only if a new category needs a gallery demo cell; gallery contract is selector-based, not token-based |
| `priv/static/rindle_admin/rindle-admin.css` | Shipped package copy | YES — brought under a scripted sync step (D-94-03) |
| `examples/adoption_demo/e2e/support/admin-polish.js` | Computed-style harness | YES — parameterize `assertAdminPolish` |
| `.github/workflows/ci.yml` | CI | YES — add `brandbook-tokens` job |
| `test/brandbook/admin_design_system_validation_test.exs` | Existing Elixir validator (asserts the two CSS copies are byte-identical, line 213) | KEEP — it stays green once the sync step is the single mechanism |

### Pattern 1: The `brandbook-tokens` CI job

**What:** A standalone pure-Node job that regenerates every artifact and fails on any diff.
**When to use:** This is THE deliverable for PIPE-01.

Use `cohort-demo-smoke` (`ci.yml:631-648`) as the structural template for a minimal proof lane, and borrow the playwright install steps from `adoption-demo-e2e` / `scripts/ci/adoption_demo_e2e.sh`. Recommended step sequence (D-94-02 order):

```yaml
# Source: synthesized from ci.yml:631-758 + scripts/ci/adoption_demo_e2e.sh (verified this session)
brandbook-tokens:
  name: Brandbook Tokens
  runs-on: ubuntu-22.04
  needs: [quality, optional-dependencies]      # proof-lane convention, exactly like ci.yml:640
  if: github.repository == 'szTheory/rindle'   # mirrors the other proof lanes
  steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Set up Node
      uses: actions/setup-node@v4
      with:
        node-version: "20"                      # identical to ci.yml:467-470 / 696-699

    # playwright is resolved via examples/adoption_demo (admin-gallery-check.mjs:14-15
    # createRequire). MUST install there or the gallery check red-herrings on
    # "Cannot find module 'playwright'" instead of reporting drift (D-94-02).
    - name: Install adoption_demo node deps (playwright resolution anchor)
      working-directory: examples/adoption_demo
      run: npm ci

    - name: Install Playwright chromium
      working-directory: examples/adoption_demo
      run: npx playwright install --with-deps chromium

    - name: Regenerate tokens.css
      run: node brandbook/src/tokens-build.mjs

    - name: Regenerate rindle-admin.css
      run: node brandbook/src/admin-css-build.mjs

    - name: WCAG contrast gate
      run: node brandbook/src/admin-contrast.mjs

    - name: Gallery browser proof (also re-runs css-build + gallery.mjs internally)
      run: node brandbook/src/admin-gallery-check.mjs

    - name: Sync shipped package CSS copy
      run: <the sync mechanism — see below>     # filename is Claude's discretion (D-94 discretion)

    - name: Fail on any uncommitted generated diff
      run: |
        if ! git diff --exit-code; then
          echo "::error::Generated CSS is out of sync with tokens.json. Run the brandbook generators and commit the result."
          exit 1
        fi
```

**Important sequencing note:** `admin-gallery-check.mjs` (lines 24-25) *itself re-runs* `admin-css-build.mjs` and `admin-gallery.mjs` via `runNode(...)`. So running `admin-css-build.mjs` explicitly first is harmless (idempotent) and keeps the failure attribution clean; the gallery check guarantees `index.html` (D-94-04 third artifact) is regenerated.

**The CSS-sync mechanism (D-94-03) — exact paths.** Verified this session:
- Source (generator output): `brandbook/tokens/rindle-admin.css`
- Dest (shipped, listed in `mix.exs:279` `files:` and `priv/static/rindle_admin`): `priv/static/rindle_admin/rindle-admin.css`
- These are **byte-identical today** (`diff` returned IDENTICAL), but **no script copies them** — the copy is hand-mirrored. The existing Elixir test `admin_design_system_validation_test.exs:213-214` only *asserts* equality; it does not *produce* the copy.

Recommended sync mechanism (Claude's discretion on exact form, two viable options):
1. **A one-line copy step** in the job: `cp brandbook/tokens/rindle-admin.css priv/static/rindle_admin/rindle-admin.css` — simplest, but the "single mechanism" only exists in CI, so a developer locally must remember it.
2. **A committed `.mjs` write** (recommended for "single mechanism" intent): have `admin-css-build.mjs` write *both* destinations, or add a tiny `sync-admin-css.mjs` that reads the generator output and writes the shipped copy. Then both CI and local developers run the same script. This best satisfies D-94-03's "make the copy a committed script/step so it is the single mechanism."

Either way, the `git diff --exit-code` at the end covers the shipped copy because the sync writes into the working tree before the diff.

### Pattern 2: Token category plug-in — the 3-touchpoint pattern (D-94-08)

**What:** Every new top-level token object must touch exactly three places, or it silently vanishes.
**When to use:** For each of: `elevation`, extended `motion`, fluid `typography`/`spacing` steps, `breakpoint`, differentiated `color.semantic.{light,dark}` status surfaces.

**Touchpoint A — `tokens.json` (source object).** Add the object with the VALUES from `94-UI-SPEC.md`.

**Touchpoint B — emit loop in `admin-css-build.mjs`.** The generator emits via `for (const [k,v] of Object.entries(...))` blocks. Current emit blocks and where new ones slot in:

| Category | Current analogous emit block (line) | New emit loop needed |
|----------|------------------------------------|----------------------|
| Differentiated dark status surfaces | `emitVariables(T.color.semantic['dark'])` at line 80 (and line 86 for `auto`) | **None new** — these are already emitted by the existing `emitVariables` over `color.semantic.dark`. Differentiating them is purely a `tokens.json` value change (lines 99-104 stop pointing at `{dark-surface}`). The emit machinery already covers them. ✅ low-risk |
| Extended motion (new easing presets) | motion loop at lines 71-74 (`for ... of Object.entries(T.motion)`) | **None new** — the loop emits every motion key except `rules`. Adding `easing-standard`/`easing-decelerate`/`easing-accelerate` to `tokens.json motion` flows automatically. Parity (Touchpoint C) is the real work. |
| Elevation ladder | spacing/radius loops at lines 62-65 | **NEW** loop: `for (const [k,v] of Object.entries(T.elevation)) css += '  --rindle-elevation-' + k + ': ' + deref(v) + ';\n'` (deref because values may reference `{dark-bg}` etc.) |
| Shadow ladder | single `shadow.card` line at line 68 | **NEW** lines for `shadow-raised`, `shadow-overlay` (extend `T.shadow` from a single key to an object loop) |
| Fluid typography (display clamp) | typography.scale loop at lines 57-61 | **NEW** emit of `--rindle-text-{role}-fluid` clamp values, OR extend the scale entries to carry a `clamp` field. Shape per UI-SPEC: only hero/h1/h2/h3 get clamp. |
| Fluid space gutters | spacing loop at line 63 | **NEW** emit of `--rindle-space-fluid-gutter` / `--rindle-space-fluid-section` clamp values |
| Named breakpoints | (none today; media query is a literal `760px` at line 531) | **NEW** emit of `--bp-sm/md/lg/xl` custom properties. Note UI-SPEC ties `--bp-md` = 760px so the existing `@media (max-width: 760px)` rule at line 531 maps without changing output. |

**Touchpoint C — parity registration.** This is where omissions are caught. Locations (all in `admin-css-build.mjs` unless noted):

| Parity mechanism | Line | What to add |
|------------------|------|-------------|
| `exact(MOTION_TOKENS, [...])` | 39 | Add the three new easing preset keys to BOTH the assertion array (line 39) AND the `MOTION_TOKENS` export (`admin-design-system-data.mjs:44`). They must match exactly or `exact()` throws. |
| `requiredMotionUses` (derived from `MOTION_TOKENS`) | 595 | Auto-derives from `MOTION_TOKENS` (`MOTION_TOKENS.map(t => 'var(--rindle-motion-' + t + ')')`) — so any new motion key is **required to be USED somewhere in the CSS**, not just emitted. ⚠️ This means new easing presets must appear in at least one rule or parity fails. Plan a rule that consumes them. |
| `requiredTokenUses` | 596 | Add `var(--rindle-elevation-...)`, fluid-type/space vars, breakpoint vars as appropriate so the generator self-check fails if a category is emitted-but-unused. |
| `requiredSelectors` | 574-593 | Only if a new category introduces a new selector (most don't — they're custom properties). |

**The trap D-94-08 names:** emitting a category (Touchpoint B) without registering it (Touchpoint C) lets the generator's own `parity OK` self-check pass while the artifact silently omits or under-uses the category. The `requiredMotionUses`/`requiredTokenUses` arrays are the registration that makes omission a hard failure.

### Pattern 3: Generalize `assertAdminPolish` (D-94-07, VIS-01 groundwork)

**What:** Thread `root` + `interactiveSelectors` as parameters with today's values as defaults.
**Current state (verified):** In `examples/adoption_demo/e2e/support/admin-polish.js`:
- `const ROOT = "[data-rindle-admin-root]";` (line 16) — module-level constant
- `const INTERACTIVE_SELECTORS = [...]` (lines 28-38) — module-level constant, 9 `[data-rindle-admin-*]` / `.rindle-admin-*` selectors
- `async function assertAdminPolish(page, { viewport, surface } = {})` (line 383) — the entry point
- `ROOT` is consumed inside `assertNoClippedText` and `assertReadableContrast` (passed into `page.evaluate(..., { ROOT })`); `INTERACTIVE_SELECTORS` is consumed inside `assertTargetSizes` and `assertNoInteractiveOverlap` (`page.locator(INTERACTIVE_SELECTORS.join(","))`).

**Threading pattern (no behavior change for the admin spec):**
```js
// Source: examples/adoption_demo/e2e/support/admin-polish.js (current signature line 383)
const DEFAULT_ROOT = "[data-rindle-admin-root]";
const DEFAULT_INTERACTIVE_SELECTORS = [ /* the existing 9-entry list */ ];

async function assertAdminPolish(
  page,
  { viewport, surface, root = DEFAULT_ROOT, interactiveSelectors = DEFAULT_INTERACTIVE_SELECTORS } = {}
) {
  await freezeMotion(page);
  // thread `root` into assertNoClippedText(page, root) / assertReadableContrast(page, root)
  // thread `interactiveSelectors` into assertTargetSizes(page, interactiveSelectors) /
  //   assertNoInteractiveOverlap(page, interactiveSelectors)
  ...
}
```
Each sub-assertion gains a parameter that defaults to the module constant. Because `admin-screenshots.spec.js:79` calls `assertAdminPolish(page, { viewport, surface })` (no `root`/`interactiveSelectors`), the defaults apply and **the existing spec passes unchanged** — that is the acceptance test for D-94-07. No auto-detection (D-94-07 forbids it: a page mounting both surfaces would match both roots).

**Scope fence:** Phase 94 only *parameterizes* the harness. It does NOT write the Cohort spec that passes `[data-ck-root]` / `.ck-*` — that is Phase 102 (VIS-01 owner). Verification here is "admin spec still green."

### Anti-Patterns to Avoid

- **Hand-editing a generated CSS file.** Every generated file carries `do not edit by hand` in its header (`admin-css-build.mjs:48`, `tokens-build.mjs:18`). The gate exists to catch this. The current `tokens.css` drift (see Pitfall 1) is the live example.
- **Diffing only the brandbook copy.** D-94-03: the shipped `priv/static/rindle_admin/rindle-admin.css` must also be regenerated/synced and diffed, or the package artifact drifts silently.
- **Generating `cohort.css`.** LOCKED OUT (ARCHITECTURE.md:111). Cohort is hand-authored in Phase 96.
- **Auto-detecting the polish root.** D-94-07 forbids it; pass `root` explicitly.
- **Emitting a token category without parity registration.** D-94-08 — the silent-omission trap.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Idempotency / drift detection | A custom checksum or AST comparator | `git diff --exit-code` after regen | Byte-exact, zero-dependency, already the repo's idempotency anchor (STACK.md:33) |
| WCAG contrast math | A new ratio function | Existing `lum()`/`ratio()` in `admin-contrast.mjs` + the `CONSOLE_CONTRAST_PAIRS` data array | Already ported and verified (41/41 pass this session); new pairs flow through by adding data, not code |
| Browser proof of rendered CSS | A new screenshot harness | Existing `admin-gallery-check.mjs` | Already resolves playwright, renders, asserts dark-chip contrast |
| CSS variable emission | A token-transform library (Style Dictionary etc.) | The existing `Object.entries` emit loops | STACK.md: near-zero new deps; the hand-rolled emit is deterministic and already trusted |
| Two-copy equality assertion | A new check | Existing `admin_design_system_validation_test.exs:213` | Already asserts the copies match; keep it green |

**Key insight:** This phase's entire value is *not adding machinery* — it is wiring locked values into the existing deterministic pipeline and gating it. The biggest risk is over-building (e.g., introducing Style Dictionary, a double-run check, or a custom diff tool) where `git diff --exit-code` + `Object.entries` already suffice.

## Runtime State Inventory

> This phase is build-tooling + token-shape only. No databases, no live services, no OS-registered state, no secrets are renamed or migrated. The "state" here is committed generated artifacts.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no datastore keys/collections/user_ids touched. Verified: phase changes are `tokens.json`, `.mjs`, `.css`, `ci.yml`, one test-support `.js`. | None |
| Live service config | None — no n8n/Datadog/Cloudflare/external service config. Verified: no service integrations in scope. | None |
| OS-registered state | None — no Task Scheduler/launchd/systemd/pm2 registrations. | None |
| Secrets/env vars | None renamed. The job reads no secrets (no `HEX_API_KEY`, no MinIO creds — it's pure Node + git). | None |
| Build artifacts / generated-and-committed files | **THREE committed generated artifacts + one mirrored copy:** `brandbook/tokens/tokens.css`, `brandbook/tokens/rindle-admin.css`, `brandbook/admin-gallery/index.html`, and the shipped `priv/static/rindle_admin/rindle-admin.css`. **`tokens.css` is currently DRIFTED (stale `text-on-brand` dark value) — see Pitfall 1.** All must be regenerated and committed as part of this phase's done-state, and thereafter the gate keeps them honest. | Regenerate + commit all four; bring the shipped copy under a scripted sync (D-94-03). |

**Canonical question — what runtime systems still have the old string after every file is updated?** None. This phase mutates source + generated artifacts only; there is no runtime cache or external registration of token values.

## Common Pitfalls

### Pitfall 1: `tokens.css` is already drifted — the gate will fail on first run (this is correct)
**What goes wrong:** When the `brandbook-tokens` gate first runs, `git diff --exit-code` will be **non-empty even with no Phase-94 changes**, because `brandbook/tokens/tokens.css` is committed with a stale dark `--rindle-text-on-brand: #F7F4EA` while `tokens.json` already says `{ink}` (`#101417`). Verified this session: `node brandbook/src/tokens-build.mjs` then `git diff` shows a 2-line change.
**Why it happens:** `tokens.css` was hand-edited or not regenerated after the cream-on-green AA fix landed in `tokens.json`. It is exactly the PITFALL #6 silent drift this phase exists to kill.
**How to avoid:** As part of Phase 94's first task, regenerate ALL artifacts (`tokens-build.mjs`, `admin-css-build.mjs`, gallery, sync the shipped copy) and **commit the corrected output**. The gate then goes green and stays green. Do NOT treat the initial red diff as a phase bug — it is the pre-existing drift the gate is supposed to surface.
**Warning signs:** A non-empty diff in `tokens.css` `text-on-brand` lines on a fresh checkout.

### Pitfall 2: Gallery check red-herrings on "Cannot find module 'playwright'"
**What goes wrong:** If `npm ci` + `playwright install` is not run in `examples/adoption_demo` *before* `admin-gallery-check.mjs`, the script throws a module-resolution error (line 14-15 `createRequire(examples/adoption_demo/package.json)('playwright')`), which masquerades as a pipeline failure rather than drift.
**Why it happens:** `admin-gallery-check.mjs` deliberately resolves `playwright` from the adoption_demo package (the repo's single playwright install), not from `brandbook/`.
**How to avoid:** Job step order: `npm ci` (in `examples/adoption_demo`) → `npx playwright install --with-deps chromium` → only then the generators (D-94-02).
**Warning signs:** CI error mentions `Cannot find module 'playwright'` instead of a diff.

### Pitfall 3: A new contrast pair references a token the `resolve()` lookup can't find
**What goes wrong:** `admin-contrast.mjs:20-25 resolve(name, theme)` looks up `name` in `raw` first, then in `T.color.semantic[theme]`. If a new dark-status-surface pair names a token that only exists under one theme (or is misspelled), `resolve` returns `null` and the gate emits `FAIL ... unknown token` (line 56-58).
**Why it happens:** The differentiated dark surfaces (`dark-ready-surface` etc.) must be added to `color.raw` (raw hexes) AND the `dark` semantic block must point its `status-*-surface` roles at them, so both `fg` and `bg` resolve under `theme: 'dark'`.
**How to avoid:** When widening `CONSOLE_CONTRAST_PAIRS`, add the matching raw hexes to `tokens.json color.raw` and wire `color.semantic.dark.status-*-surface` to them. The existing dark-status pairs (`admin-design-system-data.mjs:84-90`) already have the right *shape* (`fg: status-{state}, bg: status-{state}-surface, theme: dark`) — today they all resolve `bg` to `dark-surface` because the surfaces collapse; differentiating is a `tokens.json` value change, and the pair shapes stay. The UI-SPEC pre-computed all six ratios (8.84/6.86/7.79/7.21/8.05/7.28 vs 4.5 min), so they will pass.
**Warning signs:** `admin contrast: N/M pairs pass` with `unknown token` rows.

### Pitfall 4: Adding a motion easing preset but not USING it fails parity
**What goes wrong:** `requiredMotionUses` (line 595) is derived from `MOTION_TOKENS` and requires each motion token to appear as `var(--rindle-motion-<key>)` somewhere in the generated CSS (line 600 `if (!written.includes(motion)) missing.push(motion)`). A new easing preset that is emitted but never consumed in a rule fails the parity self-check.
**Why it happens:** The parity array enforces *use*, not just *emission*, to prevent dead tokens.
**How to avoid:** When adding `easing-standard/decelerate/accelerate`, also reference them in at least one CSS rule (e.g., apply the standard easing to the existing transitions). Plan the emit AND a consuming rule together.
**Warning signs:** `admin css parity FAIL, missing: var(--rindle-motion-easing-standard)`.

### Pitfall 5: `exact()` arrays drift from `MOTION_TOKENS`
**What goes wrong:** `exact(MOTION_TOKENS, ['press','popover','toast','transition','easing'], 'MOTION_TOKENS')` at line 39 is a *literal* expected array. If you extend the `MOTION_TOKENS` export but forget to update this literal, `exact()` throws `MOTION_TOKENS mismatch`.
**Why it happens:** Two sources of truth for the same list — the export and the assertion literal — must be kept in lockstep.
**How to avoid:** Update both `admin-design-system-data.mjs:44` (the export) and `admin-css-build.mjs:39` (the assertion literal) in the same change.
**Warning signs:** `MOTION_TOKENS mismatch: expected [...], got [...]`.

## Code Examples

### Verifying determinism locally (the idempotency anchor, D-94-10)
```bash
# Source: verified this session — both produced byte-identical output
node brandbook/src/tokens-build.mjs && cp brandbook/tokens/tokens.css /tmp/a
node brandbook/src/tokens-build.mjs && diff /tmp/a brandbook/tokens/tokens.css   # empty = deterministic
node brandbook/src/admin-css-build.mjs && cp brandbook/tokens/rindle-admin.css /tmp/b
node brandbook/src/admin-css-build.mjs && diff /tmp/b brandbook/tokens/rindle-admin.css  # empty
```

### The existing dark-status contrast pair shape (extend, don't restructure)
```js
// Source: brandbook/src/admin-design-system-data.mjs:84-90 (verified)
...STATUS_STATES.map((state) => ({
  fg: `status-${state}`,
  bg: `status-${state}-surface`,   // resolves to dark-surface today; differentiated tokens.json value makes it per-status
  theme: 'dark',
  min: 4.5,
  context: `status chips ${state} foreground on dark surface`,
})),
// → No code change needed here; differentiation is a tokens.json value change.
//   Add the raw hexes (dark-ready-surface etc.) to color.raw and point
//   color.semantic.dark.status-*-surface at them.
```

### The drift gate (the merge-blocking core)
```bash
# Source: D-94-02; git is preinstalled on the runner
git diff --exit-code || {
  echo "::error::Generated CSS is out of sync with tokens.json. Run the brandbook generators and commit the result."
  exit 1
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `tokens.css` / shipped CSS hand-mirrored, brandbook ungated in CI | `brandbook-tokens` job regenerates + diffs; shipped copy under a scripted sync | Phase 94 (this phase) | Generated CSS can no longer drift; the live `tokens.css` drift is fixed and locked |
| Dark status surfaces collapse to one `dark-surface` | Per-status differentiated dark surfaces, AA-validated | Phase 94 (values from `94-UI-SPEC.md`) | Dark status chips regain semantic tint |
| Fixed-px display type | `clamp()` on hero/h1/h2/h3 only; body/small/code stay fixed | Phase 94 | Fluid display, scannable tables preserved |

**Deprecated/outdated:** Hand-mirroring `priv/static/rindle_admin/rindle-admin.css` — replaced by the scripted sync + diff gate.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The recommended sync mechanism (scripted `.mjs` write vs. CI `cp` step) is Claude's discretion per the CONTEXT discretion clause; either satisfies D-94-03. | Pattern 1 | Low — both make the diff cover the shipped copy; planner picks one. |
| A2 | `tokens-build.mjs` may need a new emit block if a new category must appear in `tokens.css` (not just `rindle-admin.css`). UI-SPEC focuses values on the admin surface; whether `tokens.css` must carry elevation/fluid/breakpoint vars is a planner judgment. | Component Responsibilities | Low — if a category is admin-only, `tokens-build.mjs` is untouched; if it should be in the shared `tokens.css` too, add the analogous emit loop. The diff gate catches either way. |

**All other claims in this research are VERIFIED against the live codebase this session** (file reads, double-run determinism, contrast-gate execution, the `tokens.css` drift, playwright-resolution path, CI job conventions).

## Open Questions

1. **Does `tokens.css` need the new categories, or only `rindle-admin.css`?**
   - What we know: `94-UI-SPEC.md` targets the `rindle-admin` surface. `tokens.css` is the broader brand token sheet (`tokens-build.mjs`).
   - What's unclear: whether elevation/fluid/breakpoint custom properties should also be emitted into `tokens.css` (the general brand sheet) for downstream consumers, or stay admin-only.
   - Recommendation: Plan the admin emit loops as the required deliverable (PIPE-02 scopes admin in Phase 94). If `tokens.css` should also carry them, add the parallel emit loop — the diff gate will require it to be committed either way. Default to admin-only unless the planner finds a `tokens.css` consumer.

2. **Exact filename/form of the CSS-sync script.**
   - What we know: D-94-03 wants a single committed mechanism; discretion clause permits the planner to choose the filename.
   - Recommendation: A small `brandbook/src/sync-admin-css.mjs` (read generator output, write shipped copy) run as a job step and locally — best satisfies "single mechanism" and keeps the existing Elixir equality test green.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node | All `.mjs` generators | ✓ (CI node-20; local 22.14) | 20 / 22.14 | — |
| `playwright` + chromium | `admin-gallery-check.mjs` | ✓ | `@playwright/test ^1.57.0` (installed in `examples/adoption_demo`) | — |
| `git` | The drift gate | ✓ (runner preinstalled) | — | — |
| Postgres / MinIO / ffmpeg | NOT needed by this job (that's why it's standalone, D-94-01) | n/a | — | — |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None.

## Validation Architecture

> nyquist_validation is ABSENT in `.planning/config.json` → treated as ENABLED.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Node `.mjs` self-checks (parity + contrast) + `git diff --exit-code` + ExUnit (`@moduletag :integration`) + Playwright (`@playwright/test ^1.57.0`) |
| Config file | `examples/adoption_demo/playwright.config.js` (for the polish harness); no config for the `.mjs` self-checks (they `process.exit(1)`) |
| Quick run command | `node brandbook/src/admin-css-build.mjs && node brandbook/src/admin-contrast.mjs` |
| Full suite command | the full `brandbook-tokens` job sequence (regen → contrast → gallery-check → sync → `git diff --exit-code`) |

### Phase Requirements → Test Map
| Req | Behavior | Test Type | Automated Command | Exists? |
|-----|----------|-----------|-------------------|---------|
| PIPE-01 | Regen produces empty diff when committed artifacts are current | drift gate | `node …tokens-build && node …admin-css-build && <sync> && git diff --exit-code` | ❌ Wave 0 — the gate is the deliverable |
| PIPE-01 | WCAG contrast gate passes for all pairs | unit (`.mjs`) | `node brandbook/src/admin-contrast.mjs` | ✅ exists (41/41 pass today) |
| PIPE-01 | Shipped CSS copy equals generator output | integration (ExUnit) | `mix test test/brandbook/admin_design_system_validation_test.exs` | ✅ exists (line 213) |
| PIPE-01 | Gallery renders + dark-chip contrast holds | browser proof | `node brandbook/src/admin-gallery-check.mjs` | ✅ exists |
| PIPE-02 | New categories emitted AND used (parity) | unit (`.mjs` self-check) | `node brandbook/src/admin-css-build.mjs` (parity block lines 597-606) | ✅ machinery exists; new entries added |
| PIPE-02 | New dark-status-surface pairs pass AA | unit (`.mjs`) | `node brandbook/src/admin-contrast.mjs` | ✅ machinery exists; new pairs added |
| VIS-01 (groundwork) | Existing admin spec passes unchanged after parameterization | e2e (Playwright) | `cd examples/adoption_demo && npm run e2e` (admin-screenshots spec) | ✅ exists (`admin-screenshots.spec.js`) |

### The failing-then-passing shape (the CI gate IS the primary validator)
The drift gate has a natural red→green proof:
1. **RED (proves the gate works):** On a fresh checkout *today*, `node brandbook/src/tokens-build.mjs && git diff --exit-code` **fails** because `tokens.css` is drifted (Pitfall 1). This demonstrates the gate catches real drift.
2. **GREEN (the done-state):** After regenerating all artifacts and committing them, the same command produces an empty diff and passes. Any future hand-edit or missed regen flips it back to RED.

This is the Nyquist proof: the gate fails on the exact defect class it targets (drift) and passes only when source and artifacts are byte-identical.

### Sampling Rate
- **Per task commit:** `node brandbook/src/admin-css-build.mjs && node brandbook/src/admin-contrast.mjs` (fast, no browser)
- **Per wave merge:** full `brandbook-tokens` sequence incl. gallery-check
- **Phase gate:** `brandbook-tokens` job green + `adoption-demo-e2e` admin spec green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `.github/workflows/ci.yml` — new `brandbook-tokens` job (the gate; net-new)
- [ ] CSS-sync mechanism (`brandbook/src/sync-admin-css.mjs` or a CI `cp` step) — net-new
- [ ] No new test *framework* install needed — all frameworks (`.mjs` self-checks, ExUnit, Playwright) already present and exercised.

## Security Domain

> security_enforcement is absent (= enabled by default), but this phase has **no auth, session, access-control, network, secret-handling, or cryptography surface**. It is build-tooling that emits CSS custom properties and runs a headless browser against a local static file.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no | The only input is the repo's own `tokens.json` (trusted, in-tree); `deref()` already throws on unknown token references (`admin-css-build.mjs:24-27`) |
| V6 Cryptography | no | — |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Supply-chain (new npm dep) | Tampering | N/A — phase adds zero dependencies; playwright is pre-existing |
| CI secret exposure | Information Disclosure | The `brandbook-tokens` job reads no secrets (pure Node + git); do not add `HEX_API_KEY`/MinIO creds to it |

The only "destructive" act in scope is failing a build — the intended safety behavior (per `94-UI-SPEC.md` Copywriting Contract).

## Sources

### Primary (HIGH confidence — verified in-session)
- `brandbook/tokens/tokens.json` — full read; confirmed dark status collapse (lines 99-104), motion block (155-163), contrast_pairs (164-203)
- `brandbook/src/admin-css-build.mjs` — full read; emit loops (42-569), `exact()` (35-40), parity arrays (574-606), write (571)
- `brandbook/src/admin-design-system-data.mjs` — `MOTION_TOKENS` (44-50), `CONSOLE_CONTRAST_PAIRS` (54-109)
- `brandbook/src/tokens-build.mjs` — emit loops (22-41), write (59)
- `brandbook/src/admin-contrast.mjs` — `resolve()` (20-25), gate (51-71); ran it: 41/41 pass
- `brandbook/src/admin-gallery-check.mjs` — playwright createRequire (14-15), runNode chain (24-25)
- `examples/adoption_demo/e2e/support/admin-polish.js` — `ROOT` (16), `INTERACTIVE_SELECTORS` (28-38), `assertAdminPolish` (383)
- `examples/adoption_demo/e2e/admin-screenshots.spec.js` — `assertAdminPolish(page, {viewport, surface})` (79)
- `examples/adoption_demo/playwright.config.js`, `examples/adoption_demo/package.json` — playwright present
- `.github/workflows/ci.yml` — job conventions (`cohort-demo-smoke` 631-648, `adoption-demo-e2e` 649-758, `setup-node@v4` 467/696); brandbook NOT gated (zero grep hits)
- `scripts/ci/adoption_demo_e2e.sh` — `npm ci` + `npx playwright install --with-deps chromium` pattern
- `test/brandbook/admin_design_system_validation_test.exs` — two-copy equality assertion (213-214)
- `mix.exs:279` — shipped path in `files:`
- **Double-run determinism + live `tokens.css` drift** — executed this session

### Secondary
- `94-CONTEXT.md`, `94-UI-SPEC.md`, `.planning/REQUIREMENTS.md` — locked decisions and values

### Tertiary
- None — no WebSearch needed; this is an internal-codebase wiring phase.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero new deps; everything verified present and run
- Architecture / CI job shape: HIGH — modeled on two live proof lanes + the verified playwright-install script
- Token plug-in pattern: HIGH — emit loops, parity arrays, and `exact()` literals read directly
- Pitfalls: HIGH — Pitfalls 1-2 reproduced live; 3-5 derived from read source
- Validation: HIGH — the gate's red→green proof demonstrated against the live drift

**Research date:** 2026-06-14
**Valid until:** ~2026-07-14 (stable internal tooling; re-verify only if the `.mjs` generators or `ci.yml` proof-lane convention change)
