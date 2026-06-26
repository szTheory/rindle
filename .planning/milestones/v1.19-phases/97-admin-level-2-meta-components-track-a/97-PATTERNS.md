# Phase 97: Admin Level-2 Meta-Components [Track A] - Pattern Map

**Mapped:** 2026-06-17
**Files analyzed:** 7 (6 source + 1 generated/synced pair)
**Analogs found:** 7 / 7 (every file extends an in-repo Phase 95 surface — no new architecture)

> Core rule for this phase (from RESEARCH Pattern 1 + Anti-Patterns): **add a parallel
> `META_COMPONENTS` data path and NEW required-selector/snippet/check lists — never mutate the
> Level-1 `COMPONENTS`/`LEVEL_1_STATES` literals**, which carry `exact()` parity guards and pinned
> ExUnit assertions. Every analog below is the *same file* Phase 97 edits; the excerpts show the
> exact shape the new Level-2 code must mirror.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `brandbook/src/admin-design-system-data.mjs` | config | transform | self — `COMPONENTS`/`LEVEL_1_STATES`/`CONSOLE_CONTRAST_PAIRS` (same file) | exact |
| `brandbook/src/admin-css-build.mjs` | utility | file-I/O transform | self — table CSS + `[data-rindle-admin-*-state]` blocks + `requiredSelectors` self-check | exact |
| `brandbook/src/admin-gallery.mjs` | utility | file-I/O transform | self — `LEVEL_1_COMPONENT_STATE_MATRIX` panels + `data-rindle-admin-component` markers + `requiredSnippets` | exact |
| `brandbook/src/admin-gallery-check.mjs` | test | browser request-response | self — `assertComponentStateMatrix` + `assertVisible` + `forbiddenClassParts` + `expectedScreenshots` | exact |
| `examples/adoption_demo/e2e/support/admin-polish.js` | utility | browser transform | self — `assertNoClippedText`/`assertNoInteractiveOverlap` sub-assertions + `assertAdminPolish` aggregator + `OVERLAP_ENFORCED` | exact |
| `test/brandbook/admin_design_system_validation_test.exs` | test | batch | self — `@screenshots` list + `58/58` / `10 screenshots` pinned literals | exact |
| `brandbook/tokens/rindle-admin.css` + `priv/static/rindle_admin/rindle-admin.css` | generated artifact | file-I/O | `admin-css-build.mjs` (writer) + `sync-admin-css.mjs` (mirror) | generated-by |

## Pattern Assignments

### `brandbook/src/admin-design-system-data.mjs` (config, transform)

**Analog:** same file — add `META_COMPONENTS` next to `COMPONENTS`; do NOT extend `COMPONENTS`.

**Inventory-constant pattern** (`COMPONENTS`, lines 30-45; `LEVEL_1_STATES`, lines 47-57):
```javascript
export const COMPONENTS = [
  'shell', 'nav', 'table', 'status-chip', 'button', 'theme-picker',
  'form-controls', 'confirm-dialog', 'drawer', 'toast',
  'empty-state', 'error-state', 'loading-state', 'skeleton',
];
```
New constant (slugs are fixed by `97-UI-SPEC.md` §"Level-2 Meta-Component Inventory"):
```javascript
export const META_COMPONENTS = [
  'toolbar', 'data-table', 'filter-bar', 'action-panel',
  'detail-drilldown', 'confirm-panel', 'drawer', 'toast-stack',
];
```

**Contrast-pair pattern** (lines 72-150) — derived `.map()` rows over `STATUS_STATES`:
```javascript
export const CONSOLE_CONTRAST_PAIRS = [
  { fg: 'text-on-brand', bg: 'brand', theme: 'light', min: 4.5, context: 'buttons primary text' },
  ...STATUS_STATES.map((state) => ({
    fg: `status-${state}`, bg: `status-${state}-surface`,
    theme: 'light', min: 4.5, context: `status chips ${state} foreground on light surface`,
  })),
];
```
**Copy rule:** **Do NOT add contrast pairs** (RESEARCH Pitfall 2 / A2). Meta-components reuse Level-1
colors only (D-97-02); the 58 pairs already cover them. A genuinely "new pair" signals a forbidden
new color literal — flag it, don't add it. Keep `58/58` unchanged. `THEMES`/`MIN_TARGET_PX` unchanged.

---

### `brandbook/src/admin-css-build.mjs` (utility, file-I/O transform)

**Analog:** same file. Emit Level-2 composition CSS from tokens; add a NEW `requiredMetaSelectors`
block to the existing self-check. Never hand-edit the generated `.css`.

**Imports + parity-guard pattern** (lines 4-42): import `META_COMPONENTS` alongside `COMPONENTS`; add
a NEW `exact(META_COMPONENTS, [...], 'META_COMPONENTS')` line — do **not** edit the existing
`exact(COMPONENTS, [...])` / `exact(LEVEL_1_STATES, [...])` lines (36-41):
```javascript
exact(COMPONENTS, ['shell','nav','table','status-chip','button','theme-picker','form-controls','confirm-dialog','drawer','toast','empty-state','error-state','loading-state','skeleton'], 'COMPONENTS');
exact(LEVEL_1_STATES, ['default','hover','focus-visible','active','disabled','loading','empty','error','skeleton'], 'LEVEL_1_STATES');
```

**Token-backed spacing pattern** (every gap/pad must be a `--rindle-space-*` token — this is what the
new rhythm gate enforces; lines 110-211 sample):
```css
.rindle-admin-shell { gap: var(--rindle-space-6); padding-inline: var(--rindle-space-fluid-gutter); }
.rindle-admin-table__cell { padding: var(--rindle-space-3) var(--rindle-space-4); }
```

**Data-attribute-driven state CSS pattern** (the precedent for sortable / sticky / bulk-select — drive
state from a `[data-*]` attr or BEM modifier, NOT JS; `[data-rindle-admin-error-state]` lines 591-615;
`[data-rindle-admin-loading-state]` 609-615; table-row state at 203-207):
```css
[data-rindle-admin-error-state] {
  padding: var(--rindle-space-6);
  border: 1px solid var(--rindle-status-danger);
  background: var(--rindle-status-danger-surface);
}
.rindle-admin-table__row[aria-busy="true"],
.rindle-admin-table__row[data-rindle-admin-state="loading"] { color: var(--rindle-text-secondary); }
```
Mirror this for D-97-03: style `th[aria-sort="ascending|descending|none"]` (token-backed `::after`
glyph using `--rindle-accent`, never color-only), `.rindle-admin-table--sticky .rindle-admin-table__head`
(`position: sticky; top: 0;`), and `[data-rindle-admin-selected]` (token-backed selected surface, e.g.
`--rindle-surface-sunken`). Table base selectors live at 174-213.

**Write + self-check pattern** (lines 716-781) — add a NEW `requiredMetaSelectors` array, do not edit
the existing `requiredSelectors`:
```javascript
writeFileSync(adminCssPath, css);
const written = readFileSync(adminCssPath, 'utf8');
const requiredSelectors = [ '.rindle-admin-shell', '.rindle-admin-table', /* ...existing... */ ];
const missing = [];
for (const selector of requiredSelectors) if (!written.includes(selector)) missing.push(selector);
// ... requiredScopes, requiredMotionUses, requiredTokenUses ...
if (missing.length) { console.error('admin css parity FAIL, missing:', missing.join(', ')); process.exit(1); }
```
New block to append (RESEARCH Pattern 1):
```javascript
const requiredMetaSelectors = [
  '.rindle-admin-toolbar', '.rindle-admin-data-table', '.rindle-admin-filter-bar',
  '.rindle-admin-action-panel', '.rindle-admin-table--sticky',
  '[aria-sort]', '[data-rindle-admin-selected]', /* ...one per META_COMPONENTS unit + modifier... */
];
for (const s of requiredMetaSelectors) if (!written.includes(s)) missing.push(s);
```
**Copy rules:** (1) class names must come from the `rindle-admin-*` vocabulary and **avoid the
substrings `btn` / `card` / `dark`** (RESEARCH Pitfall 3 — the leakage scan is `includes()`-based; use
`panel`/`surface`/`cell`/`bar`/`group`/`cluster`). (2) No bare `outline: none` (self-check at 778-781).
(3) The terminal log line (783) counts `requiredSelectors.length`; update it if you fold meta selectors
into one combined count, or keep them separate.

---

### `brandbook/src/admin-gallery.mjs` (utility, file-I/O transform)

**Analog:** same file. Render each meta-component as one labeled cohesion panel marked
`data-rindle-admin-meta="{slug}"`; add markers to `requiredSnippets`.

**Matrix-inventory pattern** (`LEVEL_1_COMPONENT_STATE_MATRIX`, lines 48-63) — add a parallel
`META_COMPONENT_PANELS` (or render inline), do not edit this matrix:
```javascript
export const LEVEL_1_COMPONENT_STATE_MATRIX = {
  shell: ['default'],
  table: ['default', 'hover', 'focus-visible', 'empty', 'loading', 'skeleton'],
  // ...
};
```

**Fixture-marker render pattern** (the dual-marker convention — `data-rindle-admin-component` on every
Level-1 part; meta panels additionally get `data-rindle-admin-meta` on the root; table row at line 147,
button at 396-401, confirm-input at 417):
```javascript
`<tr class="rindle-admin-table__row" tabindex="0" data-rindle-admin-component="table" data-rindle-admin-state="..." data-rindle-admin-status="${state}">`
`<button class="rindle-admin-button rindle-admin-button--primary" type="button" data-rindle-admin-component="button" data-rindle-admin-state="default">Review component gallery</button>`
```
New meta-panel root (D-97-06 — `data-rindle-admin-meta` IN ADDITION TO the existing component markers):
```javascript
`<section class="rindle-admin-gallery__panel rindle-admin-toolbar" data-rindle-admin-meta="toolbar">
   <!-- composed only of rindle-admin-* Level-1 parts, each still carrying data-rindle-admin-component -->
 </section>`
```
For the data-table unit, render the *selected/sorted* state statically via fixture markup:
`aria-sort="ascending"` on a `<th>`, `[data-rindle-admin-selected]` on rows, a header select-all
checkbox, and a contextual bulk-action toolbar (`role="toolbar"`) shown in its active state — no JS
toggling (D-97-03; precedent: the confirm-input enabling script is the only inline JS, lines ~528).
Wrap the sticky-table internal scroll viewport in the explicit opt-in marker (e.g.
`data-rindle-admin-scroll-region`) so the no-h-scroll gate skips it (RESEARCH Must-Answer 2 / D-94-07).

**Required-snippet self-check pattern** (lines 539-577) — extend `requiredSnippets` with the meta
markers; do not remove existing entries:
```javascript
const requiredSnippets = [
  '<link rel="stylesheet" href="../tokens/rindle-admin.css">',
  'data-theme="auto"', 'data-rindle-admin-root',
  ...requiredGalleryComponents.map((component) => `data-rindle-admin-component="${component}"`),
  ...LEVEL_1_STATES.map((state) => `data-rindle-admin-state="${state}"`),
];
const missingSnippets = requiredSnippets.filter((needle) => !html.includes(needle));
if (missingSnippets.length) throw new Error(`gallery contract missing: ${missingSnippets.join(', ')}`);
```
Add: `...META_COMPONENTS.map((slug) => \`data-rindle-admin-meta="${slug}"\`)` plus
`'aria-sort='`, `'data-rindle-admin-selected'`, and the sticky/scroll-region marker.

**Copy rule:** Keep `data-rindle-admin-component` + `data-rindle-admin-state` on Level-1 parts as the
mechanical proof markers; add `data-rindle-admin-meta` only on the unit roots. Each unit must render
under light/dark/auto (the checker drives `selectTheme`).

---

### `brandbook/src/admin-gallery-check.mjs` (test, browser request-response)

**Analog:** same file. Add `assertMetaUnits` (mirrors `assertComponentStateMatrix`) + a meta no-leakage
scan (strengthens `forbiddenClassParts`); bump `expectedScreenshots` if meta screenshots are added.

**Assertion-helper pattern** (lines 79-94):
```javascript
const assertVisible = async (page, selector) => {
  const locator = page.locator(selector);
  assert(await locator.count() > 0, `missing selector: ${selector}`);
  assert(await locator.first().isVisible(), `selector not visible: ${selector}`);
};
const assertComponentStateMatrix = async (page) => {
  for (const [component, states] of Object.entries(requiredComponentStateMatrix)) {
    for (const state of states)
      await assertVisible(page, `[data-rindle-admin-component="${component}"][data-rindle-admin-state="${state}"]`);
  }
};
```
New (RESEARCH Must-Answer 4):
```javascript
const assertMetaUnits = async (page) => {
  for (const slug of META_COMPONENTS)
    await assertVisible(page, `[data-rindle-admin-meta="${slug}"]`);
};
```

**Leakage-scan pattern** (`forbiddenClassParts` 52-61; scan at 316-321):
```javascript
const forbiddenClassParts = ['btn', 'card', 'dark', `theme-${'dark'}`, `tail${'wind'}`, `dai${'sy'}`, `shad${'cn'}`, `ra${'dix'}`];
const leakedClasses = await page.evaluate((forbidden) =>
  Array.from(document.querySelectorAll('[class]'))
    .flatMap((el) => Array.from(el.classList))
    .filter((c) => forbidden.some((part) => c.includes(part))), forbiddenClassParts);
assert(leakedClasses.length === 0, `forbidden class names found: ${leakedClasses.join(', ')}`);
```
New "composed only of known Level-1 selectors" scan, scoped to meta subtrees:
```javascript
const unknown = await page.evaluate(() =>
  Array.from(document.querySelectorAll('[data-rindle-admin-meta] [class]'))
    .flatMap((el) => Array.from(el.classList))
    .filter((c) => !c.startsWith('rindle-admin-')));
assert(unknown.length === 0, `meta units leak non-rindle classes: ${unknown.join(', ')}`);
```

**Screenshot-list pattern** (`expectedScreenshots` 62-73; element screenshot helper at 282-295;
terminal count at 380 — `passed - ${expectedScreenshots.length} screenshots written`):
```javascript
const expectedScreenshots = [
  'gallery-light-desktop.png', 'gallery-dark-desktop.png', 'gallery-auto-desktop.png',
  'gallery-light-mobile.png', 'status-chips-dark.png', /* ...10 total... */
];
```
**Copy rule:** Wire `assertMetaUnits` into the browser flow next to `assertComponentStateMatrix` (called
at line 310). If per-unit element screenshots are added (RESEARCH Open Question 1 recommends +8 → 18),
update `expectedScreenshots` AND the Elixir `@screenshots` literal AND the `10 screenshots` pinned string
**in the same change** (Pitfall 2). If no new screenshots, keep 10 everywhere.

---

### `examples/adoption_demo/e2e/support/admin-polish.js` (utility, browser transform)

**Analog:** same file. Add `assertConsistentRhythm` + `assertNoHorizontalScroll` as offender-returning
sub-assertions; wire into `assertAdminPolish`; flip `OVERLAP_ENFORCED` (97-04, after a green warn cycle).

**Constants + selector + exemption pattern** (lines 21-55):
```javascript
const DEFAULT_ROOT = "[data-rindle-admin-root]";
const SUBPIXEL_TOLERANCE = 0.5; // reuse for rhythm tolerance
const CLIP_TOLERANCE = 1;       // reuse for no-h-scroll slack
const OVERLAP_ENFORCED = false; // flip to true in 97-04 after one green warn cycle
const DEFAULT_INTERACTIVE_SELECTORS = [
  "[data-rindle-admin-submit]", "[data-rindle-admin-input]",
  "[data-rindle-admin-nav-item]", ".rindle-admin-actions-tab",
  "[data-rindle-admin-detail-link]", "[data-rindle-admin-action]",
];
const POLISH_EXEMPTIONS = Object.freeze({ /* ship empty; per-surface escape hatch */ });
```

**Offender-returning sub-assertion pattern** (`assertNoClippedText`, lines 111-172 — RETURNS an array,
never throws; reads computed style inside `page.evaluate`, scoped to `DEFAULT_ROOT`):
```javascript
async function assertNoClippedText(page, root = DEFAULT_ROOT) {
  return page.evaluate(({ ROOT, CLIP_TOLERANCE }) => {
    const root = document.querySelector(ROOT);
    if (!root) return [];
    const out = [];
    for (const el of root.querySelectorAll("*")) { /* ...detect... out.push(`...`); */ }
    return out;
  }, { ROOT: root, CLIP_TOLERANCE });
}
```
New `assertConsistentRhythm` (RESEARCH Pattern 3 + Pitfall 1 — walk `[data-rindle-admin-meta]` subtrees
only; check `rowGap`/`columnGap`/`marginTop`/`marginBottom` + 4 paddings; allowed `{4,8,16,24,32,48,64}`
∪ exceptions `{12,44}`; `0` always valid; ±0.5px tolerance; offender = `"{slug} {tag} {prop}={px}px
off-grid"`). New `assertNoHorizontalScroll` (RESEARCH Must-Answer 2 — per-unit root
`scrollWidth <= clientWidth + CLIP_TOLERANCE`, skip elements under the explicit
`data-rindle-admin-scroll-region` marker; the page-level variant already exists as
`expectNoHorizontalScroll` in `support/admin.js:86-96` — do not duplicate it).

**Direct-sibling overlap pattern** (lines 400-444 — only compares `A.group === B.group`, ignores
containment; the toolbar/filter-bar are the canonical false-positive risk):
```javascript
if (A.group !== B.group) continue; // only direct siblings
if (A.el.contains(B.el) || B.el.contains(A.el)) continue;
if (contains(A.r, B.r) || contains(B.r, A.r)) continue;
if (intersect(A.r, B.r)) out.push(`${A.tag} overlaps ${B.tag} ...`);
```

**Aggregator pattern** (lines 484-531 — `run()` calls each check, collects offenders, single throw per
state; `warnOnly: !OVERLAP_ENFORCED` routes overlap to warnings until flipped):
```javascript
const run = async (name, prefix, fn, { warnOnly = false } = {}) => {
  if (isExempt(surface, name)) return;
  const offenders = await fn();
  for (const offender of offenders) {
    const line = `${prefix}: ${offender}`;
    (warnOnly ? warnings : violations).push(line);
  }
};
await run("noClippedText", "clipped-text", () => assertNoClippedText(page, root));
await run("noInteractiveOverlap", "overlap", () => assertNoInteractiveOverlap(page, interactiveSelectors), { warnOnly: !OVERLAP_ENFORCED });
if (violations.length) throw new Error(`Admin polish gate failed for surface="${surface}" ...`);
```
Add: `await run("consistentRhythm", "rhythm", () => assertConsistentRhythm(page, root));` and
`await run("noHorizontalScroll", "h-scroll", () => assertNoHorizontalScroll(page, root));`, and export
both from `module.exports` (lines 533-546). Gate is invoked per surface/viewport via `capture()` in
`examples/adoption_demo/e2e/admin-screenshots.spec.js:69-79`.

**Copy rules:** (1) NEVER throw inside a sub-assertion — return offenders (Anti-Pattern; the documented
`parseColor` historical bug). (2) Add any new meta interactive selectors (bulk-action, sort-toggle) to
`DEFAULT_INTERACTIVE_SELECTORS`. (3) Avoid `btn`/`card`/`dark`/`tailwind` substrings even in
comments/strings — the ExUnit forbidden-dep regex scans this file. (4) Flip `OVERLAP_ENFORCED` only in
97-04 after a green warn-only cycle; if one surface still warns, scope it via
`POLISH_EXEMPTIONS["{surface}"] = new Set(["noInteractiveOverlap"])` rather than reverting.

---

### `test/brandbook/admin_design_system_validation_test.exs` (test, batch)

**Analog:** same file. Update pinned literals atomically with the generators.

**Pinned-count pattern** (`@screenshots` 19-30; contrast/screenshot strings 119, 127):
```elixir
@screenshots ["gallery-light-desktop.png", /* ...10 names... */ "loading-state-auto.png"]
# ...
assert admin_output =~ "admin contrast: 58/58 pairs pass"
assert output =~ "admin gallery check passed - 10 screenshots written"
```
**Marker-loop + drift-gate pattern** (component loop 138-154; drift gate elsewhere):
```elixir
for component <- ["shell", "nav", "table", "status-chip", "button", /* ... */] do
  assert html =~ "data-rindle-admin-component=\"#{component}\""
end
```
**Copy rule:** **Keep `58/58` unchanged** (no new contrast pairs — A2). If the gallery plan adds N meta
screenshots, bump `10 screenshots` → `(10+N)` AND `@screenshots` AND `expectedScreenshots` together
(Pitfall 2). Optionally add a `for meta <- [...] do assert html =~ "data-rindle-admin-meta=\"#{meta}\""`
loop. If a new verification command is introduced, add its string to `guides/admin_design_system.md`
(the ADMIN-02 test asserts command strings live there). Run `sync-admin-css.mjs` after the generator so
`read!(priv...) == read!(brandbook...)` holds.

---

### `brandbook/tokens/rindle-admin.css` + `priv/static/rindle_admin/rindle-admin.css` (generated artifacts)

**Analog:** `admin-css-build.mjs` (writer, line 716 banner+write) → `sync-admin-css.mjs` (byte-for-byte
mirror, D-94-03). **Output only — never hand-edit.** Verify reproducibility with
`node brandbook/src/admin-css-build.mjs && node brandbook/src/sync-admin-css.mjs` then
`git diff --exit-code` / `cmp -s` between the two files.

## Shared Patterns

### Parallel-inventory (NEVER mutate Level-1 literals)
**Source:** `admin-design-system-data.mjs:30-57`, `admin-css-build.mjs:36-41`, `admin-gallery.mjs:48-75`
**Apply to:** data, css-build, gallery, ExUnit
Add `META_COMPONENTS` + new `requiredMetaSelectors`/meta-snippet/meta-screenshot lists alongside the
existing `COMPONENTS`/`LEVEL_1_STATES`/`requiredSelectors`/`requiredSnippets`/`expectedScreenshots`.
Mutating the Level-1 literals breaks `exact()` parity guards and pinned ExUnit assertions.

### Token-backed generated CSS boundary
**Source:** `admin-css-build.mjs:1` banner + `sync-admin-css.mjs`
**Apply to:** all CSS
```javascript
let css = `/* generated by brandbook/src/admin-css-build.mjs from tokens.json - do not edit by hand */`;
```
Every spacing value is a `--rindle-space-*` token (this is exactly what the rhythm gate enforces). Never
hand-edit `brandbook/tokens/rindle-admin.css` or `priv/static/rindle_admin/rindle-admin.css`.

### Data-attribute / BEM-modifier state (no client JS)
**Source:** `admin-css-build.mjs:203-207, 591-615` (`[data-rindle-admin-error-state]`,
`[data-rindle-admin-loading-state]`, row `[data-rindle-admin-state="loading"]`)
**Apply to:** sortable (`th[aria-sort]`), sticky (`.rindle-admin-table--sticky`), bulk-select
(`[data-rindle-admin-selected]`)
Express all data-table behaviors as CSS-state driven by attributes/modifiers + fixture markup (D-97-03).
Direction conveyed by a token-backed visible glyph, never color alone (`status-needs-label`).

### Offender-returning sub-assertion + single aggregated throw
**Source:** `admin-polish.js:111-172` (a check), `:484-531` (`assertAdminPolish`)
**Apply to:** `assertConsistentRhythm`, `assertNoHorizontalScroll`
Each check RETURNS `string[]`; `assertAdminPolish.run()` aggregates and throws once per state. Never
throw inside a check. `warnOnly: !OVERLAP_ENFORCED` is the warn→enforce migration lever.

### Browser visibility proof
**Source:** `admin-gallery-check.mjs:79-94`
**Apply to:** `assertMetaUnits`
```javascript
const assertVisible = async (page, selector) => {
  const locator = page.locator(selector);
  assert(await locator.count() > 0, `missing selector: ${selector}`);
  assert(await locator.first().isVisible(), `selector not visible: ${selector}`);
};
```

### Substring-leakage avoidance (naming guard)
**Source:** `admin-gallery-check.mjs:52-61, 316-321`; ExUnit `@implementation_files` forbidden-dep regex
**Apply to:** all new class names AND comments/strings in `admin-polish.js`/`admin-css-build.mjs`
Avoid the substrings `btn` / `card` / `dark` / `tailwind` / `daisy` / `shadcn` / `radix`. Use
`panel`/`surface`/`cell`/`bar`/`group`/`cluster`. A name like `…__card` fails the `includes()` scan.

### Explicit-marker exception (no auto-detection)
**Source:** D-94-07; page-level `support/admin.js:86-96`
**Apply to:** sticky-table internal scroll region
The sole no-h-scroll exception is an element carrying an explicit `data-rindle-admin-scroll-region`
(name at planner discretion). The check skips `unit.closest('[data-rindle-admin-scroll-region]')`.

## No Analog Found

None. Every Phase 97 file extends an in-repo Phase 95 surface with a direct same-file precedent for the
new shape. No new architectural pattern is required (confirmed by RESEARCH §"Don't Hand-Roll").

## Metadata

**Analog search scope:** `brandbook/src`, `brandbook/tokens`, `priv/static/rindle_admin`,
`examples/adoption_demo/e2e/support`, `examples/adoption_demo/e2e`, `test/brandbook`
**Files scanned:** 7 source/test files + page-level `support/admin.js` + spec invocation +
CONTEXT/UI-SPEC/RESEARCH + the Phase 95 PATTERNS map
**Line numbers verified against current HEAD** (Phase 95 implemented; numbers shifted from the 95-PATTERNS map)
**Pattern extraction date:** 2026-06-17
