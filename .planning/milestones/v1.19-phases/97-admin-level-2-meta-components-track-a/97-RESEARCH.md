# Phase 97: Admin Level-2 Meta-Components [Track A] - Research

**Researched:** 2026-06-17
**Domain:** Generated vanilla CSS design-system composition + deterministic computed-style (Playwright) proof gates. No runtime framework, no new deps.
**Confidence:** HIGH (the entire surface is in-repo code that was read directly; no external library research applies)

## Summary

Phase 97 is a pure in-repo, dependency-free design-system phase. Every "library" question is moot:
the only tools are Node ESM generator scripts (`brandbook/src/admin-*.mjs`), a static HTML gallery,
ported WCAG math, and Playwright (already present in `examples/adoption_demo`). There is nothing to
install, no registry to verify, no API to look up. The work is: (1) add a `META_COMPONENTS` inventory
constant, (2) generate Level-2 composition CSS from tokens + the existing Level-1 primitives, (3)
render each meta-component as one labeled gallery panel marked `data-rindle-admin-meta="{slug}"`, (4)
assert those units in `admin-gallery-check.mjs`, and (5) add two new offender-returning sub-assertions
(`assertConsistentRhythm`, `assertNoHorizontalScroll`) to `admin-polish.js` and flip `OVERLAP_ENFORCED`.

The single most important constraint discovered in the code (not just the contract) is the **exact-count
parity assertions** that will break the moment the data model changes: the Elixir test pins
`admin contrast: 58/58 pairs pass` and `admin gallery check passed - 10 screenshots written`, and three
generators assert `exact(...)` equality on `THEMES/SURFACES/COMPONENTS/LEVEL_1_STATES`. Any new
contrast pair, screenshot, or component-list entry must be reflected in the corresponding pinned literal
in the same change or the merge-blocking gate fails. The clean way to add Level-2 is to thread a *new*
`META_COMPONENTS` constant and *new* required-selector / required-snippet lists rather than mutating the
existing Level-1 literals.

The second key discovery: a page-level no-horizontal-scroll check **already exists** as
`expectNoHorizontalScroll` in `examples/adoption_demo/e2e/support/admin.js` (asserts
`document.documentElement` and `[data-rindle-admin-root]` `scrollWidth <= clientWidth`). Phase 97's
new `assertNoHorizontalScroll` is the *per-meta-unit* version that lives inside `admin-polish.js`,
returns offenders, and honors an explicit sticky-scroll container marker.

**Primary recommendation:** Extend, do not re-open. Add a parallel `META_COMPONENTS` data path and new
required-selector/snippet/check lists; keep all new gate sub-assertions offender-returning (never throw);
flip `OVERLAP_ENFORCED` only after one warn-only green CI cycle; and update the three pinned literals
(`58/58` → new count, `10 screenshots` → new count, generator required-selector lists) atomically.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Meta-component visual composition | Generated CSS (`admin-css-build.mjs`) | tokens.json | All styling is token-backed generated BEM; never hand-authored. |
| Meta-component inventory of record | Shared data (`admin-design-system-data.mjs`) | — | Single source of slugs/markers, like `COMPONENTS`. |
| Unit-level proof markup | Static gallery (`admin-gallery.mjs` → `index.html`) | — | The gallery is the *unit* cohesion proof surface (no live page needed). |
| Unit presence / no-leakage assertion | Gallery checker (`admin-gallery-check.mjs`) | Playwright (Chromium) | Browser-renders the static HTML and asserts selectors. |
| Rhythm / overlap / no-h-scroll gate | Live polish gate (`admin-polish.js`) | adoption-demo-e2e lane | The *page-level* cohesion proof over real LiveView screenshots. |
| Shipped-artifact parity | `sync-admin-css.mjs` + empty-diff + ExUnit | git | D-94-03 single mirror path; drift is a hard failure. |
| Data-table behaviors (sort/sticky/bulk) | Generated CSS + fixture markup | — | Static CSS state + `aria-sort` / modifier class / data-attrs; **no client JS framework** (D-97-03). |

## Standard Stack

There is no external stack. Everything is in-repo and dependency-free.

### Core
| "Library" | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| Node ESM generator scripts | repo Node | Emit `rindle-admin.css`, gallery HTML | Established Track A pattern (Phase 94/95) `[VERIFIED: codebase]` |
| `playwright` (chromium) | resolved via `examples/adoption_demo/package.json` | Browser-render gallery + live screenshots | Already the proof engine `[VERIFIED: codebase admin-gallery-check.mjs:15]` |
| Ported WCAG math (`luminance`/`contrastRatio`/`parseColor`) | in-file copies | Contrast checks | Repo convention is per-script copies, not shared imports `[VERIFIED: admin-polish.js:14, admin-gallery-check.mjs:195-217]` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Static CSS-state data table | Client-side sort/select JS | **FORBIDDEN by D-97-03** — this is a static design-system proof surface |
| Gallery + polish gate | Storybook / SaaS visual-regression | **FORBIDDEN** (no new dep / no Storybook); contract is explicit |

**Installation:** none. No `npm install`, no new package.

## Package Legitimacy Audit

Not applicable — Phase 97 installs **zero** external packages (hard constraint: "no new runtime deps").
slopcheck/registry verification is not required because no package is added, removed, or upgraded.
Playwright is already a resolved dependency of `examples/adoption_demo` and is not modified by this phase.

## Architecture Patterns

### System Architecture Diagram

```
tokens.json ──┐
              ▼
   admin-design-system-data.mjs   (META_COMPONENTS inventory + slugs/markers)
              │  exact() parity literals shared across the next 3 scripts
              ▼
   admin-css-build.mjs ──► brandbook/tokens/rindle-admin.css
              │            (self-check: required meta selectors, sticky/sort/selected
              │             modifiers, theme scopes, reduced-motion block, no outline:none)
              ▼
   admin-gallery.mjs   ──► brandbook/admin-gallery/index.html
              │            (one labeled panel per meta, data-rindle-admin-meta="{slug}",
              │             composed only of Level-1 selectors + fixture aria-sort/selected)
              ▼
   admin-gallery-check.mjs  (Chromium renders HTML)
              │   asserts: each meta unit visible per theme; composed only of known
              │   Level-1 selectors (no forbidden/unknown class leakage); captures screenshots
              ▼
   sync-admin-css.mjs  ──► priv/static/rindle_admin/rindle-admin.css   (byte-for-byte)
              │
              ▼
   git diff --exit-code (empty-diff drift gate)
              │
              ▼
   mix test admin_design_system_validation_test.exs   (pins 58→N contrast, 10→M screenshots,
              │                                          selector sets, byte-identical shipped CSS,
              │                                          forbidden-dependency regex over impl files)
              ▼
   adoption-demo-e2e lane  ──► admin-screenshots.spec.js
                              calls assertAdminPolish() over 22 real LiveView captures:
                              + assertConsistentRhythm  (new, offender-returning)
                              + assertNoHorizontalScroll (new, offender-returning, marker-opt-out)
                              + assertNoInteractiveOverlap (OVERLAP_ENFORCED flipped true)
```

### Recommended Decomposition (file ownership stays identical to Phase 95's 3-plan shape)

```
admin-design-system-data.mjs   # META_COMPONENTS constant (+ any new contrast pairs)
admin-css-build.mjs            # generated Level-2 composition CSS + new self-checks
admin-gallery.mjs              # meta unit panels + data-rindle-admin-meta markers
admin-gallery-check.mjs        # meta unit presence + no-leakage assertions + screenshots
support/admin-polish.js        # assertConsistentRhythm + assertNoHorizontalScroll + OVERLAP flip
test/.../admin_design_system_validation_test.exs  # update pinned counts/selectors
guides/admin_design_system.md  # the ADMIN-02 test asserts command strings live here
```

### Pattern 1: Add a NEW inventory + NEW required lists (never mutate the Level-1 literals)
**What:** `admin-css-build.mjs`, `admin-gallery.mjs`, and the Elixir test each carry `exact()`/required
arrays for `COMPONENTS`/`LEVEL_1_STATES`. Mutating those breaks parity. Add `META_COMPONENTS` as a new
exported constant and new `requiredMetaSelectors` / meta snippet lists alongside the existing ones.
**When to use:** always, in this phase.
**Example:**
```js
// admin-design-system-data.mjs  (new constant — slugs from 97-UI-SPEC.md)
export const META_COMPONENTS = [
  'toolbar', 'data-table', 'filter-bar', 'action-panel',
  'detail-drilldown', 'confirm-panel', 'drawer', 'toast-stack',
];
```
```js
// admin-css-build.mjs  (new required-selector block appended to the existing self-check)
const requiredMetaSelectors = [
  '.rindle-admin-toolbar', '.rindle-admin-data-table',  // or [data-rindle-admin-meta="..."]
  '.rindle-admin-table--sticky',                        // sticky-header modifier
  '[aria-sort]',                                        // sortable affordance hook
  '[data-rindle-admin-selected]',                       // bulk-select row state
  // ...
];
for (const s of requiredMetaSelectors) if (!written.includes(s)) missing.push(s);
```

### Pattern 2: Data-table behaviors as static CSS state (D-97-03)
**What:** Express sortable/sticky/bulk-select purely in generated CSS + fixture markup.
**Sortable:** style `th[aria-sort="ascending"]` / `[aria-sort="descending"]` / `[aria-sort="none"]`
with a token-backed glyph (e.g. a `::after` arrow using `--rindle-accent` for the active column) — the
direction is conveyed by a *visible glyph*, never color alone (token rule `status-needs-label`). The
accessible name is `Sort by {column}` on the header control.
**Sticky-header:** a `.rindle-admin-table--sticky` modifier puts the table in a scroll container and sets
`position: sticky; top: 0;` on `.rindle-admin-table__head` cells. The header stays pinned during internal
vertical scroll without covering the first data row.
**Bulk-select:** a header `<input type="checkbox">` (select-all), per-row `[data-rindle-admin-selected]`
giving a token-backed selected surface (e.g. `--rindle-surface-sunken`), and a contextual bulk-action
toolbar (`role="toolbar"`) shown only when ≥1 row is selected — in the *static* gallery this is shown
in its selected/active state via fixture markup, not toggled by JS.
**Why it fits:** mirrors Phase 96 Cohort, where `ck_table` already carries `aria-sort` on the `<th>` as a
real attribute (D-96 in STATE.md), and matches the existing generator's data-attribute-driven CSS
(`[data-rindle-admin-error-state]`, `[data-rindle-admin-loading-state]`).

### Pattern 3: Offender-returning sub-assertion (the polish-gate contract)
**What:** Every new check RETURNS an array of human-readable offender strings; `assertAdminPolish`
aggregates and throws once per state. Never throw inside a check.
**Example skeleton (matches `assertNoClippedText` shape):**
```js
async function assertConsistentRhythm(page, root = DEFAULT_ROOT) {
  return page.evaluate(({ ROOT, GRID, ALLOWED, EXEMPT_PX, TOL }) => {
    const out = [];
    const onGrid = (px) =>
      EXEMPT_PX.some(v => Math.abs(px - v) <= TOL) ||
      ALLOWED.some(v => Math.abs(px - v) <= TOL);
    for (const unit of document.querySelectorAll(`${ROOT} [data-rindle-admin-meta]`)) {
      for (const el of unit.querySelectorAll('*')) {
        const s = getComputedStyle(el);
        for (const prop of ['rowGap','columnGap','marginTop','marginBottom',
                            'paddingTop','paddingBottom','paddingLeft','paddingRight']) {
          const px = parseFloat(s[prop]); if (!px) continue;     // 0 is always fine
          if (!onGrid(px)) out.push(
            `${unit.getAttribute('data-rindle-admin-meta')} ${el.tagName.toLowerCase()} `+
            `${prop}=${px}px off-grid`);
        }
      }
    }
    return out;
  }, { ROOT: root, ALLOWED:[4,8,16,24,32,48,64], EXEMPT_PX:[12,44], TOL:0.5 });
}
```
See **Pitfall 1** for the algorithm/tolerance rationale.

### Anti-Patterns to Avoid
- **Mutating `COMPONENTS`/`LEVEL_1_STATES` literals** to add meta-components — these have exact() parity
  guards and pinned Elixir assertions; add a parallel constant instead.
- **Hand-editing `rindle-admin.css` or `priv/static/.../rindle-admin.css`** — both are generated/synced;
  the empty-diff gate and `read!(priv...) == read!(brandbook...)` ExUnit assertion fail hard.
- **Auto-detecting the sticky-scroll exception** — D-94-07 forbids auto-detection; require an explicit
  container marker (a `data-*` attribute or modifier class the unit opts into).
- **Throwing inside a sub-assertion** — breaks the single-aggregated-throw contract and hides other
  offenders (this exact bug bit `parseColor` historically; see comment at `admin-polish.js:89-92`).
- **Color-only sort/selection affordances** — violates `status-needs-label` token rule.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Contrast math | New WCAG impl | Copy the in-file `luminance`/`contrastRatio`/`parseColor` | Repo convention; already battle-tested `[VERIFIED]` |
| No-horizontal-scroll (page) | New page check | `expectNoHorizontalScroll` already in `support/admin.js` | Exists; new check is the per-*unit* variant only `[VERIFIED]` |
| Shipped-CSS mirroring | Hand copy | `sync-admin-css.mjs` (D-94-03) | Single committed mirror path; drift gate enforces |
| Theme/scope emission | New theming | Existing `[data-theme]` + `prefers-color-scheme` emit loops | No parallel theme convention allowed |
| Sort/select interactivity | JS framework | Static CSS state + `aria-sort`/`[data-rindle-admin-selected]` | D-97-03 forbids client table JS |

**Key insight:** Almost every "new" capability in this phase has a near-identical Level-1 precedent in the
same files. The phase is composition + two new computed-style checks, not new infrastructure.

## Common Pitfalls

### Pitfall 1: Rhythm check false positives (the hardest design problem in this phase)
**What goes wrong:** A naive "every gap/margin/padding must be a 4px multiple" check fires on
legitimate non-token values: the 12px table-cell padding (`--rindle-space-3`), the 28px status-chip
`min-height`, sub-pixel layout rounding, `line-height`-derived box metrics, fluid gutter/section clamps
(`--rindle-space-fluid-*`), and the 44px target minimum.
**Why it happens:** computed style resolves *everything* to px, including values the design system
intentionally allows off the 4px grid.
**How to avoid (recommended algorithm):**
- Scope the walk to elements **inside `[data-rindle-admin-meta]` units only** (not the whole root) — this
  is the "intra-unit" requirement and dramatically cuts noise.
- Check the **rhythm-bearing properties**: `row-gap`, `column-gap`, top/bottom `margin`, and the four
  `padding` sides. **Do not** check `min-height`/`height`/`width` (those carry 28px chip, 44px target,
  fluid widths) and **do not** check `line-height`.
- Treat **0px as always valid** (collapsed/unset).
- Allowed set = `{4,8,16,24,32,48,64}` (the declared `--rindle-space-*` multiples) **plus the two
  documented exceptions `{12, 44}`** (`--rindle-space-3` table-cell padding, `--rindle-admin-target-min`).
- Tolerance `±0.5px` (reuse the existing `SUBPIXEL_TOLERANCE` constant value) to absorb rounding.
- **Skip fluid-token consumers:** the toolbar/filter-bar live inside the shell whose `padding-inline`
  is `--rindle-space-fluid-gutter`; only check spacing *within* the meta unit, where fluid tokens are not
  used. If a fluid value still leaks in, the explicit-marker exemption pattern (below) is the escape hatch.
- Return offenders as `"{meta-slug} {tag} {prop}={px}px off-grid"` — never throw.
**Warning signs:** a first CI run with dozens of offenders all at 12px/44px/fluid values means the
exemption set or property list is wrong, not the CSS.

### Pitfall 2: Exact-count parity literals break silently-then-loudly
**What goes wrong:** Adding contrast pairs or screenshots without updating the pinned literals
`admin contrast: 58/58 pairs pass` and `admin gallery check passed - 10 screenshots written` in
`admin_design_system_validation_test.exs` (and `admin-contrast.mjs` prints `N/N`) fails the ExUnit gate.
**Why it happens:** the Elixir test asserts these exact strings (`admin_design_system_validation_test.exs:119,127`).
**How to avoid:** if the phase adds new meta screenshots, bump `10 screenshots` to the new count and
`@screenshots`/`expectedScreenshots` lists together. **Prefer NOT adding new contrast pairs** — the
existing 58 already cover every Level-1 token pair that meta-components reuse (meta-components introduce
no new colors per D-97-02), so `58/58` should stay unchanged. If a genuinely new token pair arises, that
is a signal you may be introducing a new color literal, which is forbidden — flag it instead.

### Pitfall 3: forbidden-class-leakage check is substring-based and brittle
**What goes wrong:** `admin-gallery-check.mjs` rejects any class containing `btn`, `card`, `dark`,
`theme-dark`, `tailwind`, `daisy`, `shadcn`, `radix`; the Elixir regex also rejects `class="...btn|card"`
and `.dark`. A new meta helper class like `.rindle-admin-data-table__card` would match `card` and fail.
**Why it happens:** the check is a naive `className.includes(part)` substring scan.
**How to avoid:** name meta-component classes from the existing `rindle-admin-*` vocabulary and avoid the
substrings `btn`/`card`/`dark`. Use `panel`, `surface`, `cell`, `bar`, `group`, `cluster` instead.

### Pitfall 4: OVERLAP_ENFORCED flipped too early
**What goes wrong:** flipping `OVERLAP_ENFORCED=true` before a warn-only green cycle turns spurious
sibling-bbox intersections (e.g. a wrapping toolbar) into hard failures on first run.
**Why it happens:** overlap is "the noisiest check" (comment at `admin-polish.js:28-30`); the warn→enforce
migration is the documented path.
**How to avoid:** land the meta-component matrix first with `OVERLAP_ENFORCED=false`, confirm zero
overlap *warnings* across all 22 captures in one green CI cycle, then flip to `true` in a follow-up
task/plan. See the Overlap section below for scope analysis.

### Pitfall 5: no-horizontal-scroll vs. the legitimate sticky-table internal scroll
**What goes wrong:** the sticky-header data table is *designed* to have an internal horizontal/vertical
scroll region; a blanket `scrollWidth <= clientWidth` over every element flags it.
**How to avoid:** assert at the meta-unit *root* (`[data-rindle-admin-meta]`) level, and skip any element
carrying the explicit sticky-scroll container marker (D-94-07: explicit marker, never auto-detect). See
the No-Horizontal-Scroll section.

## Must-Answer Findings

### 1. Rhythm gate — concrete algorithm + tolerance
Inspect of the current CSS shows spacing is overwhelmingly **`gap`** (grid/flex) plus **`padding`** and a
few **`margin`** (e.g. `margin: 0 0 var(--rindle-space-3)` on panel headings). The robust, low-false-
positive approach:

- **Walk only `[data-rindle-admin-meta]` subtrees**, element-by-element.
- **Properties checked:** `rowGap`, `columnGap`, `marginTop`, `marginBottom`, `paddingTop`,
  `paddingBottom`, `paddingLeft`, `paddingRight`. (Exclude horizontal margins because `margin: 0 auto`
  centering resolves to arbitrary px; exclude all sizing/line-height.)
- **Allowed grid:** `{4, 8, 16, 24, 32, 48, 64}` ∪ **exceptions `{12, 44}`** (12px table cell, 44px
  target). `0` always passes.
- **Tolerance:** `±0.5px` (subpixel rounding).
- **Return offenders**, aggregate in `assertAdminPolish` (offender-returning, single throw).
- This is the algorithm sketched in **Pattern 3** and justified in **Pitfall 1**. The precise tolerance
  constant and helper name are at planner discretion (CONTEXT "the agent's Discretion").
`[VERIFIED: codebase — gaps/margins/paddings inspected in admin-css-build.mjs:128-632, admin-gallery.mjs:181-328]`

### 2. No-horizontal-scroll gate — exact assertion + sticky exception
**Page-level already exists** (`support/admin.js:86-96`): `documentElement.scrollWidth <= clientWidth`
AND `[data-rindle-admin-root].scrollWidth <= clientWidth`. Phase 97's `assertNoHorizontalScroll` is the
**per-meta-unit** variant inside `admin-polish.js`:
```js
async function assertNoHorizontalScroll(page, root = DEFAULT_ROOT) {
  return page.evaluate(({ ROOT, TOL, MARK }) => {
    const out = [];
    for (const unit of document.querySelectorAll(`${ROOT} [data-rindle-admin-meta]`)) {
      // explicit opt-in marker for the sticky/scroll exception (D-94-07: never auto-detect)
      if (unit.closest(`[${MARK}]`)) continue;
      if (unit.scrollWidth > unit.clientWidth + TOL)
        out.push(`${unit.getAttribute('data-rindle-admin-meta')} `+
                 `x(${unit.scrollWidth}>${unit.clientWidth})`);
    }
    return out;
  }, { ROOT: root, TOL: 1 /* reuse CLIP_TOLERANCE */, MARK: 'data-rindle-admin-scroll-region' });
}
```
The sticky-header table opts in by wrapping its scroll viewport in an element carrying an explicit marker
(name at planner discretion, e.g. `data-rindle-admin-scroll-region`). Reuse the existing
`CLIP_TOLERANCE = 1` constant. `[VERIFIED: support/admin.js:86-96, admin-polish.js:24]`

### 3. Overlap enforcement — what must be true to flip, and scope
`OVERLAP_ENFORCED` is a **module-level boolean** (`admin-polish.js:30`) wired via the `warnOnly:
!OVERLAP_ENFORCED` option on the `noInteractiveOverlap` run (line 512-514). It is therefore **global to
the gate**, not per-surface — but the gate is *invoked per surface/viewport*, and per-check opt-out
exists via `POLISH_EXEMPTIONS[surface]`. So the practical migration path:
- **Warn-only cycle:** keep `false`, land the meta matrix, run the full 22-capture lane; confirm the
  `[admin-polish] ... N warning(s)` overlap log is empty across every state.
- **Flip:** set `OVERLAP_ENFORCED = true` once green. If a single surface still warns spuriously, scope it
  out narrowly via `POLISH_EXEMPTIONS["{surface}"] = new Set(["noInteractiveOverlap"])` with a
  justification comment (the file's documented per-surface escape hatch) rather than reverting the flip.
The check only compares **direct siblings** (`A.group !== B.group → continue`, line 429) and ignores
containment, so most false overlaps come from wrapping flex rows — the toolbar/filter-bar are the
canonical risk (CONTEXT specifics). `[VERIFIED: admin-polish.js:28-30,400-444,498-514]`

### 4. Gallery composition — adding META_COMPONENTS units + no-leakage check
- **Add markers:** each meta panel root gets `data-rindle-admin-meta="{slug}"` *in addition to* the
  existing `data-rindle-admin-component` markers on its Level-1 parts.
- **Render per theme:** the gallery uses a single document with a theme-picker; existing checker switches
  themes and screenshots. Each meta unit must be visible under light/dark/auto (the checker already
  drives `selectTheme` for light/dark/auto).
- **Assert presence** in `admin-gallery-check.mjs`, mirroring `assertComponentStateMatrix`:
  ```js
  const assertMetaUnits = async (page) => {
    for (const slug of META_COMPONENTS)
      await assertVisible(page, `[data-rindle-admin-meta="${slug}"]`);
  };
  ```
- **No unknown-class leakage:** the existing `forbiddenClassParts` scan (lines 52-61, 316-321) already
  rejects non-vocabulary substrings. Strengthen it for "composed only of known Level-1 selectors" by
  asserting every class inside a `[data-rindle-admin-meta]` subtree starts with `rindle-admin-` (allowing
  the `rindle-admin-gallery__*` helper prefix used by the panel chrome):
  ```js
  const unknown = await page.evaluate(() =>
    Array.from(document.querySelectorAll('[data-rindle-admin-meta] [class]'))
      .flatMap(el => Array.from(el.classList))
      .filter(c => !c.startsWith('rindle-admin-')));
  assert(unknown.length === 0, `meta units leak non-rindle classes: ${unknown.join(', ')}`);
  ```
- **Update `requiredSnippets`** in `admin-gallery.mjs` to include the meta markers, and **bump the
  screenshot count** + `expectedScreenshots` if new element screenshots are added.
`[VERIFIED: admin-gallery.mjs:539-577, admin-gallery-check.mjs:52-94,316-321]`

### 5. Data-table behaviors as static markup — fits the pattern
Confirmed it fits the existing generator/gallery pattern (Pattern 2 above). Precedent: `ck_table` in
Phase 96 already renders a real `aria-sort` on the `<th>` (STATE.md line 163), and the admin generator
already drives state purely from data-attributes (`[data-rindle-admin-error-state]`,
`[data-rindle-admin-loading-state]`, `[data-rindle-admin-confirm-input]`). The static gallery shows the
*selected* and *sorted* states via fixture markup; the existing gallery already uses a tiny inline script
only for theme-switch and confirm-input enabling, so no table-JS framework is introduced. `[VERIFIED]`

### 6. Drift/sync + Elixir validation — what must run green, gotchas
Full gate (from `95-03-SUMMARY.md:100` and the guide lines 33-39):
```
node brandbook/src/admin-css-build.mjs
node brandbook/src/admin-contrast.mjs
node brandbook/src/admin-gallery-check.mjs
node brandbook/src/sync-admin-css.mjs
cmp -s brandbook/tokens/rindle-admin.css priv/static/rindle_admin/rindle-admin.css
node brandbook/src/contrast.mjs
mix test --include integration test/brandbook/admin_design_system_validation_test.exs
```
**Gotchas:**
- The Elixir test pins `58/58` (contrast) and `10 screenshots` — update both literals if counts change
  (prefer keeping 58/58 unchanged; see Pitfall 2).
- `assert read!(priv...) == read!(brandbook...)` — shipped CSS must be byte-identical; **always run sync
  after the generator**.
- `assert_generated_clean([...])` runs `git diff --exit-code` on the generated CSS + gallery HTML —
  regenerate and commit, or the empty-diff gate fails.
- The forbidden-dependency regex runs over `@implementation_files` (includes `admin-polish.js`); avoid
  `btn`/`card`/`dark`/`tailwind`/etc. substrings even in comments/strings (Pitfall 3).
- The ADMIN-02 test asserts command strings exist in `guides/admin_design_system.md`; if a new command is
  added, add it to the guide too. `[VERIFIED: admin_design_system_validation_test.exs:32-248, guide:33-39]`

### 7. Plan decomposition — recommended split
Mirror Phase 95's clean 3-plan shape (data+CSS / gallery+check / gate+sync+ExUnit), with the overlap-flip
as a final guarded step. Granularity is `fine` (config), so each plan stays small.

| Plan | Owns | Files | Depends on |
|------|------|-------|-----------|
| **97-01 Data model + generated Level-2 CSS** | `META_COMPONENTS` constant; generated toolbar/data-table(sortable/sticky/bulk)/filter-bar/action-panel/detail-drilldown/confirm-panel/drawer/toast-stack composition CSS; new `requiredMetaSelectors` self-checks; regenerate `rindle-admin.css` | `admin-design-system-data.mjs`, `admin-css-build.mjs`, `rindle-admin.css` | Phase 95 |
| **97-02 Gallery units + checker** | meta panels with `data-rindle-admin-meta`; fixture `aria-sort`/`[data-rindle-admin-selected]`/bulk toolbar markup; `assertMetaUnits` + no-leakage; screenshots | `admin-gallery.mjs`, `index.html`, `admin-gallery-check.mjs` | 97-01 |
| **97-03 Polish gate (rhythm + no-h-scroll) [warn-only overlap]** | `assertConsistentRhythm`, `assertNoHorizontalScroll`, wire into `assertAdminPolish`, add any new meta interactive selectors to `DEFAULT_INTERACTIVE_SELECTORS`; keep `OVERLAP_ENFORCED=false` | `support/admin-polish.js`, `admin-screenshots.spec.js` (if marker plumbing needed) | 97-02 |
| **97-04 Overlap enforcement + sync + ExUnit/guide gate** | flip `OVERLAP_ENFORCED=true` after green warn cycle; `sync-admin-css.mjs`; update pinned counts/selectors + guide | `admin-polish.js`, `priv/.../rindle-admin.css`, `admin_design_system_validation_test.exs`, `guides/admin_design_system.md` | 97-03 (green CI) |

**Wave/parallelism:** This is a strict dependency chain (data → gallery → page gate → enforce/seal); the
generator output feeds every downstream check, so plans are **sequential, not parallel**. Within 97-01,
the eight meta-components can be authored in any order but live in one generated file (single writer), so
they are one plan, not eight. (Note: repo config has `parallelization:false` anyway.)

## Runtime State Inventory

Not a rename/refactor/migration phase — greenfield composition within an existing system. The only
"stored state" concerns are the generated artifacts, which are deterministic and regenerated by the gate:
- **Generated CSS** (`brandbook/tokens/rindle-admin.css`): regenerated by `admin-css-build.mjs`; empty-diff gate.
- **Gallery HTML** (`brandbook/admin-gallery/index.html`): regenerated by `admin-gallery.mjs`; empty-diff gate.
- **Shipped CSS** (`priv/static/rindle_admin/rindle-admin.css`): mirrored by `sync-admin-css.mjs`; byte-identical ExUnit assertion.
- **Screenshots** (`brandbook/admin-gallery/screenshots/*`, `examples/.../test-results/*`): regenerated; counts pinned.
**No databases, OS-registered state, secrets, or external service config are touched. Verified by reading every source surface.**

## Code Examples

(See Patterns 1–3 and Must-Answer items 2 & 4 above — all examples are derived from the in-repo code that
was read directly, not from external sources.)

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Human screenshot review (Phase 92) | Deterministic computed-style polish gate | Phase 94 | New checks must be offender-returning, not eyeballed |
| Hand-mirrored shipped CSS | Single `sync-admin-css.mjs` mirror (D-94-03) | Phase 94 | Never hand-edit `priv` CSS |
| Auto-detected gate root | Explicit root/marker only (D-94-07) | Phase 94 | Sticky-scroll exception must use an explicit marker |
| Overlap warn-only | (this phase) flip to enforce for meta matrix | Phase 97 | First-class cohesion defect after green warn cycle |

**Deprecated/outdated:** none relevant — all referenced patterns are current as of Phase 96.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Rhythm allowed set is `{4,8,16,24,32,48,64}` ∪ `{12,44}` and 0 | Must-Answer 1 / Pitfall 1 | If a token like `--rindle-space-2`=8 is used in an unexpected derived value, may need a wider set; tune during 97-03 warm-up run |
| A2 | No new contrast pairs are needed (meta reuses Level-1 colors) → keep `58/58` | Pitfall 2 / Must-Answer 6 | If a meta truly needs a new pair, that implies a new color literal (forbidden) — flag, don't add |
| A3 | Sticky-scroll exception marker name (`data-rindle-admin-scroll-region`) | Must-Answer 2 | Cosmetic; name is at planner discretion per CONTEXT |
| A4 | `OVERLAP_ENFORCED` flip is global; per-surface scoping via `POLISH_EXEMPTIONS` | Must-Answer 3 | Verified in code — low risk |
| A5 | Number of new element screenshots (affects the pinned `10`→M count) | Must-Answer 4,6 | Whatever the gallery plan decides, must update the literal + `@screenshots`/`expectedScreenshots` together |

## Open Questions (RESOLVED)

1. **How many gallery element-screenshots should the meta units add?**
   - Known: each meta must be *visible* per theme; the checker already captures full-page light/dark/auto.
   - Unclear: whether per-unit element screenshots are required (they were for Level-1 components).
   - Recommendation: add one element screenshot per meta-component (8 new) for parity with Level-1, bump
     `10`→`18` in both the JS `expectedScreenshots`/`@screenshots` and the Elixir pinned literal. Decide in 97-02.
   - **RESOLVED:** 8 new element screenshots (10→18). Implemented in 97-02 (JS lists) and sealed in 97-04 (ExUnit pinned literal `18 screenshots written`); `58/58` contrast pairs kept unchanged.

2. **Should `assertConsistentRhythm` also assert *density consistency* (one rhythm step per unit), or only
   on-grid-ness?** D-97-09 mentions "density must be consistent within a unit."
   - Recommendation: start with on-grid-ness (objective, low-false-positive); treat "consistent density"
     as satisfied by token-backed gaps. A stricter "single dominant gap per unit" rule risks false
     positives (title cluster gap ≠ action cluster gap is legitimate). Keep stricter density as a
     discretion-scoped stretch, not a hard gate, unless a warm-up run shows it is clean.
   - **RESOLVED:** on-grid-ness only (allowed set `{4,8,16,24,32,48,64}` ∪ `{12,44}`, ±0.5px). Implemented in 97-03's `assertConsistentRhythm`; strict single-dominant-gap density left as discretion-scoped stretch, not a hard gate.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node | all generators | ✓ (repo standard) | repo Node | — |
| playwright/chromium | gallery-check + e2e lane | ✓ (resolved via `examples/adoption_demo`) | as locked in that package | — |
| Elixir/mix | ExUnit validation gate | ✓ (Phoenix repo) | repo | — |
| git | empty-diff drift gate | ✓ | — | — |

No external service configuration required. No new dependency is installed.

## Validation Architecture

> nyquist_validation key is absent in config → treated as ENABLED.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Node assertion scripts (`admin-css-build`/`admin-contrast`/`admin-gallery-check`), Playwright (`@playwright/test` in adoption_demo), ExUnit (`mix test`) |
| Config file | `examples/adoption_demo/playwright.config.*`; `test/brandbook/admin_design_system_validation_test.exs` |
| Quick run command | `node brandbook/src/admin-css-build.mjs && node brandbook/src/admin-contrast.mjs` |
| Full suite command | the 7-command full gate in Must-Answer 6 (+ the `adoption-demo-e2e` Playwright lane running `admin-screenshots.spec.js`) |

### Success Criterion → Deterministic Merge-Blocking Check
| Success Criterion (ROADMAP) | Behavior | Check / Command | Proof |
|----|----------|-----------------|-------|
| **SC1** — meta-components are composed units built only from Level-1 primitives | each `META_COMPONENTS` slug renders; composed only of `rindle-admin-*` classes; no forbidden/unknown leakage | `node brandbook/src/admin-gallery-check.mjs` (`assertMetaUnits` + no-leakage scan); generator `requiredMetaSelectors` self-check in `admin-css-build.mjs` | gallery check exits 0; css parity OK |
| **SC2** — rhythm/overlap/no-h-scroll consistency | intra-unit gaps on 4px grid (∪12,44); unit root no horizontal overflow (sticky marker excepted); no interactive sibling overlap | `assertConsistentRhythm` + `assertNoHorizontalScroll` + `assertNoInteractiveOverlap` (`OVERLAP_ENFORCED=true`) via `assertAdminPolish` in the `adoption-demo-e2e` lane over 22 captures | lane green; zero offenders aggregated per state |
| **SC3** — each meta-component appears in the gallery as a unit | one labeled `data-rindle-admin-meta="{slug}"` panel per meta, visible per theme, screenshotted | `admin-gallery-check.mjs` visibility + screenshot assertions; ExUnit pins the screenshot count | gallery check `passed - {M} screenshots written`; ExUnit green |
| (seal) shipped artifact parity | generated == shipped, no drift | `sync-admin-css.mjs` + `cmp` + `git diff --exit-code` + `read!(priv)==read!(brandbook)` ExUnit | empty diff; ExUnit `0 failures` |

### Sampling Rate
- **Per task commit:** `node brandbook/src/admin-css-build.mjs && node brandbook/src/admin-contrast.mjs` (sub-second; catches selector/parity/contrast regressions immediately).
- **Per wave/plan merge:** full 7-command gate (adds gallery browser proof + sync + ExUnit).
- **Phase gate:** full gate **plus** the `adoption-demo-e2e` Playwright lane green (this is where the new
  rhythm/no-h-scroll/overlap checks actually run over real LiveView pages).

### Wave 0 Gaps
- [ ] `assertConsistentRhythm` — new sub-assertion in `support/admin-polish.js` (covers SC2 rhythm). Does not exist yet.
- [ ] `assertNoHorizontalScroll` (per-unit) — new sub-assertion in `support/admin-polish.js` (covers SC2 no-h-scroll). Page-level variant exists in `support/admin.js`; per-unit does not.
- [ ] `assertMetaUnits` + meta no-leakage scan — new assertions in `admin-gallery-check.mjs` (covers SC1, SC3).
- [ ] `requiredMetaSelectors` self-check block — new in `admin-css-build.mjs` (covers SC1).
- [ ] Pinned-literal updates — `58/58` (keep) and `10 screenshots`→new count in the Elixir test + JS lists.
- *(No new test framework install needed — all three harnesses already exist.)*

## Security Domain

> `security_enforcement` is not set in config; this phase touches **no** auth, sessions, access control,
> input handling on live data, cryptography, or write paths. It composes static CSS/markup proof fixtures.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no (fixture markup only; no live input handling) | existing form-control patterns inherited from L1 |
| V6 Cryptography | no | — |

**Relevant non-ASVS guard already enforced by the gate:** `expectNoAdminRawSecrets` (in `support/admin.js`)
runs in the same `capture()` path as the polish gate, asserting no raw secrets render. Phase 97 must not
regress it, but adds no new attack surface. The forbidden-dependency regex (ExUnit) is the supply-chain guard.

## Sources

### Primary (HIGH confidence — read directly this session)
- `examples/adoption_demo/e2e/support/admin-polish.js` — the gate, offender-returning contract, OVERLAP_ENFORCED, tolerances
- `examples/adoption_demo/e2e/support/admin.js` — existing page-level `expectNoHorizontalScroll`, secret guard
- `examples/adoption_demo/e2e/admin-screenshots.spec.js` — 22-capture lane, `capture()` invokes the gate
- `brandbook/src/admin-design-system-data.mjs` — COMPONENTS/LEVEL_1_STATES/CONSOLE_CONTRAST_PAIRS/MIN_TARGET_PX
- `brandbook/src/admin-css-build.mjs` — generator, exact() parity, required-selector self-check, status/button/table CSS
- `brandbook/src/admin-gallery.mjs` — gallery render, markers, requiredSnippets, theme script
- `brandbook/src/admin-gallery-check.mjs` — Chromium proof, forbiddenClassParts, matrix/visibility/screenshot asserts
- `brandbook/src/admin-contrast.mjs` — 58-pair WCAG gate, `N/N pairs pass`
- `brandbook/src/sync-admin-css.mjs` — D-94-03 single mirror path
- `test/brandbook/admin_design_system_validation_test.exs` — pinned 58/58 + 10-screenshots, byte-identical CSS, forbidden-dep regex
- `brandbook/tokens/tokens.json` — spacing grid (4–64 + 12px exception), fluid tokens, colors, focus, motion
- `guides/admin_design_system.md` — command chain the ADMIN-02 test asserts
- `97-CONTEXT.md`, `97-UI-SPEC.md`, `95-UI-SPEC.md`, `95-0{1,2,3}-SUMMARY.md`, `ROADMAP.md`, `REQUIREMENTS.md`, `STATE.md`

### Secondary / Tertiary
- None. No external sources were needed; this phase has zero external dependencies.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — there is no external stack; every surface read directly.
- Architecture / decomposition: HIGH — mirrors the verified Phase 95 3-plan shape on the same files.
- Pitfalls: HIGH — derived from exact pinned literals and guard logic in the read source.
- Rhythm-tolerance specifics (A1): MEDIUM — the allowed-set is grounded in tokens.json, but the exact
  property list/tolerance should be confirmed by a warn-only first run in 97-03.

**Research date:** 2026-06-17
**Valid until:** 2026-07-17 (stable; in-repo only — invalidated only if the gate files change before planning)
