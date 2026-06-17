# Phase 96: Cohort Component Layer + Dark / Reduced-Motion Contract [Track B] - Pattern Map

**Mapped:** 2026-06-17
**Files analyzed:** 9 (5 net-new, 4 modified)
**Analogs found:** 9 / 9 (every file has a strong in-repo analog — this phase is a Cohort-side mirror of the Phase 94/95 admin pattern)

> **Two-DS separation note (D-94-05/06):** Cohort and `rindle-admin` share *vocabulary and structure*, never a file/token/build. Every analog below is a **shape to copy**, not a module to import. The new Cohort files are hand-authored siblings of generated/admin files, hard-coding their own `--ck-*` literals. Do **not** `import` from `admin-*.mjs`, do **not** route `--ck-*` through `tokens.json`, do **not** edit `admin-polish.js`.

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `brandbook/src/cohort-design-system-data.mjs` (new) | config / data-module | transform (static export) | `brandbook/src/admin-design-system-data.mjs` | exact |
| `brandbook/src/cohort-contrast.mjs` (new) | utility / gate script | batch (read→assert→exit) | `brandbook/src/admin-contrast.mjs` | exact |
| `examples/adoption_demo/lib/adoption_demo_web/live/styleguide_live.ex` (new `StyleguideLive`) | LiveView (route) | event-driven (server `assign(:theme)` + `phx-click`) | `launchpad_live.ex` (`.ck` shell) + `admin-gallery.mjs` (IA + theme toggle) | exact (shell) / role-match (gallery IA) |
| `examples/adoption_demo/lib/adoption_demo_web/components/cohort_components.ex` (modified: new primitives) | component | request-response (function components) | same file (existing `ck_button`/`badge`/`cred` idiom) + admin `core_components` table/form shape | exact |
| `examples/adoption_demo/priv/static/assets/cohort.css` (modified) | config / stylesheet | transform (cascade) | same file (existing `:root` + `prefers-color-scheme` block) + admin `[data-theme]`/`reduce`/elevation philosophy | exact (self) / role-match (admin philosophy) |
| `examples/adoption_demo/e2e/cohort-styleguide.spec.js` (new) | test | event-driven (browser drive→assert) | `examples/adoption_demo/e2e/admin-screenshots.spec.js` | exact |
| `phx-hook="Tabs"` in `examples/adoption_demo/priv/static/assets/js/app.js` (modified) | hook | event-driven (keyboard) | `Copy` hook in same `app.js` | exact (hook idiom) / role-match (WAI-ARIA keyboard is net-new) |
| `examples/adoption_demo/lib/adoption_demo_web/router.ex` (modified: 1 line) | route | request-response | existing `live(...)` lines in `:browser` scope | exact |
| `.github/workflows/ci.yml` (modified: node steps in `adoption-demo-e2e`) | config / CI | batch | `adoption-demo-e2e` lane steps + `brandbook-tokens` node-step idiom | exact |

---

## Pattern Assignments

### `brandbook/src/cohort-design-system-data.mjs` (config / data-module)

**Analog:** `brandbook/src/admin-design-system-data.mjs` (read fully)

The hand-maintained literal sink. Copy the exact export shape: a flat array of pair objects, each carrying `{ fg, bg, theme, min, context }`. Cohort hard-codes its own `--ck-*` hex/channel values here (the admin file resolves names against `tokens.json`; **Cohort does not** — see the resolver note in the gate file below).

**Pair-object shape to copy** (`admin-design-system-data.mjs:72-79`):
```javascript
export const CONSOLE_CONTRAST_PAIRS = [
  { fg: 'text-on-brand', bg: 'brand', theme: 'light', min: 4.5, context: 'buttons primary text' },
  { fg: 'text', bg: 'surface-raised', theme: 'light', min: 4.5, context: 'buttons quiet text' },
  { fg: 'border-strong', bg: 'surface-raised', theme: 'light', min: 3, context: 'buttons secondary border non-text' },
  ...
```

**Light + dark twinning pattern** — same pair, two `theme` rows (`admin-design-system-data.mjs:84-96`):
```javascript
  { fg: 'text', bg: 'surface-raised', theme: 'light', min: 4.5, context: 'form controls text' },
  { fg: 'text', bg: 'surface-raised', theme: 'dark',  min: 4.5, context: 'form controls text (dark)' },
```

**Status-state fan-out** with `.map` (`admin-design-system-data.mjs:101-115`) — Cohort mirrors for its four statuses:
```javascript
  ...STATUS_STATES.map((state) => ({
    fg: `status-${state}`, bg: `status-${state}-surface`, theme: 'light', min: 4.5,
    context: `status chips ${state} foreground on light surface`,
  })),
```

**Cohort `COHORT_CONTRAST_PAIRS` must encode (from `96-UI-SPEC.md:165-172`, D-96-23-corrected):**
| fg | bg | theme | min | role |
|----|----|-------|-----|------|
| `--ck-ink` | `--ck-surface` | light+dark | 4.5 | body |
| `--ck-muted` | `--ck-surface` | light+dark | 4.5 | readable secondary (was `--ck-faint`) |
| `--ck-on-brand` | `--ck-btn-bg` | light+dark | 4.5 | button text |
| `--ck-brand-strong` | `--ck-tint` | light+dark | 4.5 | large/icon |
| `--ck-{ready,processing,quarantine,info}` | own surface | light+dark | 4.5 | status |
| `--ck-ink` | `--ck-surface-2` | light+dark | 4.5 | stat/nested |
| `--ck-faint` | `--ck-bg` | light+dark | **3.0** | decorative only |

Also export `MIN_TARGET_PX = 44` (mirrors `admin-design-system-data.mjs:70`) so the spec's `interactiveSelectors` floor stays single-sourced if desired.

> **Literal values are in `cohort.css`** (`:root` light at `cohort.css:33-91`; dark at `cohort.css:93-121`). The pairs here must **byte-equal** those — enforced by D-96-18 parity check in the gate.

---

### `brandbook/src/cohort-contrast.mjs` (utility / gate script)

**Analog:** `brandbook/src/admin-contrast.mjs` (read fully) — copy structure; **replace the resolver**.

**Imports + WCAG math (copy verbatim)** (`admin-contrast.mjs:1-39`):
```javascript
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { COHORT_CONTRAST_PAIRS } from './cohort-design-system-data.mjs';

const lum = (hex) => { /* sRGB linearize — copy admin-contrast.mjs:27-34 */ };
const ratio = (a, b) => {
  const [l1, l2] = [lum(a), lum(b)].sort((x, y) => y - x);
  return (l1 + 0.05) / (l2 + 0.05);
};
```

**REPLACE the resolver** — admin derefs `tokens.json` semantic blocks per theme (`admin-contrast.mjs:11-25`). Cohort is theme-blind in `tokens.json`, so D-96-02/18 require parsing `cohort.css` directly: read the `:root`/`[data-theme="light"]` block for `theme:'light'` pairs and the `[data-theme="dark"]` block for `theme:'dark'` pairs, and resolve `--ck-*` → hex by scanning that block. Reuse the same block extractor for the D-96-20 literal scanner (one shared helper).

**Coverage loop (copy + adapt)** — admin hard-codes a required-context list and fails on a *missing* pair, not only a failing one (`admin-contrast.mjs:43-49`):
```javascript
const contexts = COHORT_CONTRAST_PAIRS.map((p) => p.context).join(' ');
for (const requiredContext of [/* table, stat, form, tabs, detail, toolbar, focus, status... × theme */]) {
  if (!contexts.includes(requiredContext)) { rows.push(`FAIL ... (missing cohort contrast context)`); failures++; }
}
```

**Per-pair assert + exit (copy verbatim)** (`admin-contrast.mjs:51-71`):
```javascript
for (const p of COHORT_CONTRAST_PAIRS) {
  const theme = p.theme || 'light';
  const fg = resolve(p.fg, theme);   // <- cohort.css block resolver
  const bg = resolve(p.bg, theme);
  if (!fg || !bg) { rows.push(`FAIL ... unknown token`); failures++; continue; }
  const r = ratio(fg, bg);
  if (r < p.min) failures++;
  rows.push(`${r >= p.min ? 'PASS' : 'FAIL'} ${r.toFixed(2)} >= ${p.min} ${p.fg} on ${p.bg} (${p.context}; ${theme})`);
}
console.log(`\ncohort contrast: ${COHORT_CONTRAST_PAIRS.length - failures}/${COHORT_CONTRAST_PAIRS.length} pairs pass`);
if (failures) process.exit(1);
```

**D-96-18 parity check** — net-new vs. admin (admin gets this free from generation). After resolving, assert each `--ck-*` referenced in the pairs byte-equals the value scanned from the matching `cohort.css` block; drift = `process.exit(1)`.

**D-96-20 literal scanner** — a separate ~30-line brace-depth pass (may live in this file or a sibling). Pattern to mirror is `assertNoBareOutlineNone` (`admin-gallery-check.mjs:96-102`):
```javascript
const stripCssComments = (text) => text.replace(/\/\*[\s\S]*?\*\//g, '');
assert(!/outline\s*:\s*none\b/.test(stripCssComments(css)), '...');
```
Extend it: strip comments, walk top-level blocks by brace depth, classify each block by selector, allow hex/`rgb`/`rgba`/`hsl` **only** inside `:root`, `[data-theme="light"]`, `[data-theme="dark"]`, and the `:root:not([data-theme])` nested under `@media (prefers-color-scheme: dark)`; allow `currentColor`/`transparent`/`color-mix` anywhere; fail elsewhere.

---

### `examples/adoption_demo/lib/adoption_demo_web/live/styleguide_live.ex` — `StyleguideLive` (LiveView)

**Analog (shell):** `launchpad_live.ex` (read fully). **Analog (gallery IA + theme toggle):** `admin-gallery.mjs` (read fully).

**Module + import skeleton (copy `launchpad_live.ex:1-11`):**
```elixir
defmodule AdoptionDemoWeb.StyleguideLive do
  use AdoptionDemoWeb, :live_view
  import AdoptionDemoWeb.CohortComponents
```

**Theme as server state (D-96-16) — `mount/3` + `phx-click` handler** (no localStorage; deterministic for e2e). Mirror `launchpad_live.ex:72-83` mount shape, add `:theme`:
```elixir
def mount(_params, _session, socket), do: {:ok, assign(socket, page_title: "Cohort styleguide", theme: "light", ...)}

def handle_event("set_theme", %{"theme" => t}, socket) when t in ~w(light dark),
  do: {:noreply, assign(socket, theme: t)}
```

**`.ck` shell with the D-96-05 seam attributes on the per-LiveView div** — `launchpad_live.ex:88` renders `<div class="ck">`; this phase adds `data-ck-root` + `data-theme`:
```elixir
def render(assigns) do
  ~H"""
  <div class="ck" data-ck-root data-theme={@theme}>
    <.cohort_nav active={nil} />
    <main class="ck__wrap">
      <!-- theme toggle: button group; mirrors admin-gallery.mjs:347-350 picker -->
      <div class="ck-toolbar" role="group" aria-label="Theme">
        <button type="button" phx-click="set_theme" phx-value-theme="light"
                aria-pressed={@theme == "light"} data-ck-theme="light">Light</button>
        <button type="button" phx-click="set_theme" phx-value-theme="dark"
                aria-pressed={@theme == "dark"} data-ck-theme="dark">Dark</button>
      </div>
      <!-- one variation-group section per primitive; stable test markers -->
      <section data-ck-section="table" data-ck-state="default"> ... </section>
  """
end
```

**Stable test markers separate from BEM styling (D-96-16)** — admin uses `data-rindle-admin-component`/`data-rindle-admin-state` (`admin-gallery.mjs:356`, `:147`) distinct from `.rindle-admin-*` classes. Cohort mirrors with `data-ck-section` / `data-ck-state`; the spec asserts on these, never on `.ck-*` styling classes.

**Gallery IA + seeded fiction (D-96-22)** — borrow `admin-gallery.mjs` structure: one panel per component, real domain rows (a lesson-video row going `processing`, a quarantined upload, an empty member list). Compare admin's `tableRows` fixture (`admin-gallery.mjs:137-144`). Form fields demo real semantics via `to_form` + `Phoenix.HTML.FormField` (D-96-15).

**Icon convention** — private `defp *_icon(%{name: ...} = assigns)` clauses with inline `stroke="currentColor"` SVG, falling through to a default clause — copy `launchpad_live.ex:159-206` (`cast_icon`) / `cohort_components.ex:219-315` (`task_icon`).

---

### `examples/adoption_demo/lib/adoption_demo_web/components/cohort_components.ex` (component — modified)

**Analog:** the existing functions in this same file (read fully) + admin table/form shape from `admin-gallery.mjs`.

**Function-component idiom to follow exactly (D-96-09/14)** — `attr` with `values:` enums, `:rest, :global`, named slots only for user content, BEM class lists. Copy `ck_button` (`cohort_components.ex:61-80`):
```elixir
@doc "..."
attr :variant, :string, default: "quiet", values: ~w(primary quiet)
attr :rest, :global, include: ~w(target rel)
slot :inner_block, required: true
def ck_button(assigns) do
  ~H"""
  <.link class={["ck-btn", @variant == "primary" && "ck-btn--primary"]} {@rest}>
    {render_slot(@inner_block)}
  </.link>
  """
end
```

**Enum-variant + label idiom for stateful primitives** — copy `badge/1` (`cohort_components.ex:206-214`):
```elixir
attr :variant, :string, default: "info", values: ~w(ready processing quarantine info)
attr :label, :string, required: true
def badge(assigns), do: ~H"""<span class={["ck-badge", "ck-badge--#{@variant}"]}>{@label}</span>"""
```

**Inline SVG icon clauses (copy `cohort_components.ex:216-315`)** — private head with `attr :name, :atom, required: true`, one clause per `%{name: :x}`, `fill="none" stroke="currentColor" stroke-width="2" ... aria-hidden="true"`, default clause last:
```elixir
attr :name, :atom, required: true
defp tabs_icon(%{name: :sort} = assigns), do: ~H"""<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" ...>...</svg>"""
defp tabs_icon(assigns), do: tabs_icon(%{assigns | name: :default})
```

**Six L1 primitives to add** (each: function component + `.ck-*` CSS + a gallery section):
- `.ck-table` (`__head`/`__row`/`__cell`/`__num`) — `:col`/`:rows` slot model like `core_components`, per-column `sort_key`/`num`; sort header is a real `<button>` carrying `aria-sort` (server-owned sort state, D-96-15). Status cells reuse the existing `badge/1`.
- `.ck-stat` (`__label`/`__value`/`__delta`) — `tabular-nums` on `__value`; empty renders `—`.
- form set: `.ck-field`/`.ck-input`/`.ck-select`/`.ck-label`/`.ck-help`/`.ck-error` — integrate `Phoenix.HTML.FormField`, wire `aria-describedby` + `aria-invalid`, error = icon + message (never color-only).
- `.ck-tabs` (`__tab`/`[aria-selected]`/`__panel`) — full APG roles; click via `Phoenix.LiveView.JS`, keyboard via the new `phx-hook="Tabs"` (D-96-17).
- `.ck-detail` (`__term`/`__desc`) — real `<dl><dt><dd>`.
- `.ck-toolbar` (`__group`, slots for buttons/filters).

Plus four L2 compositions (Data-table block, Stat row, Detail panel, Tabbed section) per `96-UI-SPEC.md:200-207`.

---

### `examples/adoption_demo/priv/static/assets/cohort.css` (config / stylesheet — modified)

**Analog (self):** existing token + cascade structure in this file. **Analog (philosophy):** admin's `[data-theme]` / `reduce` / elevation, named in `admin-gallery.mjs:95-98` CSS contract.

**Current state to extend:**
- light `:root` token block: `cohort.css:33-91`
- dark via media query only: `cohort.css:93-121` (`@media (prefers-color-scheme: dark) { :root { ... } }`)
- focus-visible already token-backed (keep, extend): `cohort.css:151-153`
  ```css
  .ck :focus-visible { outline: 2px solid var(--ck-focus); outline-offset: 2px; }
  ```
- only a `no-preference` reveal block exists, **no `reduce` block**: `cohort.css:589-599`

**D-96-11 theme contract to author** — promote the dark media block to an explicit attribute selector, keep media as auto fallback:
```css
:root, [data-theme="light"] { color-scheme: light; /* light --ck-* (move cohort.css:33-91 here) */ }
[data-theme="dark"]         { color-scheme: dark;  /* dark --ck-* (the values at cohort.css:94-119) */ }
@media (prefers-color-scheme: dark) {
  :root:not([data-theme]) { color-scheme: dark; /* same dark set — banner the controlled duplication */ }
}
```

**D-96-12 elevation/shadow** — add `--ck-surface-overlay` step; introduce per-theme bare-channel `--ck-shadow-ink` / `--ck-glow-ink` (e.g. `15 27 23`) so the `--ck-shadow-*` formulas (currently baked rgba at `cohort.css:58-60` light / `:113-115` dark) are written once via `rgb(var(--ck-shadow-ink) / <alpha>)` and only the ink flips per theme. `--ck-bg-glow` (`cohort.css:44`, `:99`) likewise derives from `--ck-glow-ink`.

**D-96-13 reduced-motion block (net-new) — the only legitimate `!important` site:**
```css
@media (prefers-reduced-motion: reduce) {
  .ck *, .ck *::before, .ck *::after {
    animation-duration: .001ms !important; animation-iteration-count: 1 !important;
    transition-duration: .001ms !important;
  }
  .ck-reveal { opacity: 1; transform: none; }
}
```
Use `.001ms` (not `0`) so `transitionend`/`animationend` still fire. Keep the existing `no-preference` block (`cohort.css:589-599`) as-is.

**D-96-10 literal removals (confirmed sites):**
| Line | Current | → |
|------|---------|---|
| `cohort.css:404` | `.ck-copy[data-copied="true"] { color: #fff }` | `var(--ck-on-brand)` |
| `cohort.css:368` | `font-size: 0.875rem` | nearest `--ck-step-*` |
| `cohort.css:470` | `.ck-card__desc { font-size: 0.95rem }` | nearest `--ck-step-*` |
| `cohort.css:503` | `.ck-badge { font-size: 0.72rem }` | nearest `--ck-step-*` |
| `cohort.css:485` | `.ck-card__path { font-size: 0.78rem }` (also a literal) | nearest `--ck-step-*` |
| `cohort.css:58-60,113-115` | baked rgba shadows | derive from `--ck-shadow-ink` |

After this, the D-96-20 scan finds literals only in `:root`/`[data-theme]` blocks.

---

### `examples/adoption_demo/e2e/cohort-styleguide.spec.js` (test — new)

**Analog:** `examples/adoption_demo/e2e/admin-screenshots.spec.js` (read fully) + helpers in `e2e/support/admin.js`.

**Reuse `assertAdminPolish` UNCHANGED with Cohort overrides (D-96-06)** — the function already takes `{ root, interactiveSelectors }` (`admin-polish.js:459-467`); admin calls it at `admin-screenshots.spec.js:77-79`. Cohort calls:
```javascript
const { assertAdminPolish } = require("./support/admin-polish");
const { waitForLiveSocket } = require("./support/liveview");

await assertAdminPolish(page, {
  viewport: "desktop",
  surface: "styleguide",
  root: "[data-ck-root]",
  interactiveSelectors: [".ck-btn", ".ck-tab", ".ck-input", ".ck-select", "[data-ck-theme]"],
});
```
Do **not** edit `admin-polish.js`. The polish gate is **warn/report mode** this phase (warn→fail is Phase 102; `OVERLAP_ENFORCED=false` already shows the warn idiom at `admin-polish.js:30,487-498`).

**`selectAdminTheme` click→assert pattern to mirror for the Cohort toggle (D-96-07)** (`support/admin.js:57-62`):
```javascript
async function selectCohortTheme(page, theme) {
  const control = page.locator(`[data-ck-theme="${theme}"]`);
  await control.click();
  await expect(page.locator("[data-ck-root]")).toHaveAttribute("data-theme", theme);
  await expect(control).toHaveAttribute("aria-pressed", "true");
}
```

**Spec ordering (D-96-21) — `emulateMedia` only AFTER `goto`/`waitForLiveSocket`** (Playwright drops it across nav). Reduced-motion probe must run **before** `assertAdminPolish` injects `freezeMotion` (`admin-polish.js:63-72` freezes all motion, masking gate 3):
```javascript
await page.goto("/styleguide");
await waitForLiveSocket(page);              // helper at e2e/support/liveview.js
await page.emulateMedia({ reducedMotion: "reduce" });
// gate 3 probe: .ck-reveal computed opacity:1 / transform:none / animation-name:none — BEFORE any freeze
await page.emulateMedia({ reducedMotion: "no-preference" });
await selectCohortTheme(page, "light");
await assertAdminPolish(page, { root: "[data-ck-root]", interactiveSelectors, surface: "styleguide-light" });
await selectCohortTheme(page, "dark");
await assertAdminPolish(page, { root: "[data-ck-root]", interactiveSelectors, surface: "styleguide-dark" });
await page.emulateMedia({ colorScheme: "dark" });  // auto-fallback probe, distinct from [data-theme]
```
The `emulateMedia({colorScheme})` precedent is `admin-gallery-check.mjs:346,352`.

**Component-existence assertion (D-96-19, gate 1)** — mirror `admin-gallery-check.mjs:79-94` `assertVisible` loop over the required matrix: each of 6 L1 + 4 L2 primitives is visible at `/styleguide` (via `data-ck-section`) AND its selector substring-exists in `cohort.css`.

---

### `phx-hook="Tabs"` in `examples/adoption_demo/priv/static/assets/js/app.js` (hook — modified)

**Analog:** the `Copy` hook in the same file (`app.js:125-150`) and its registration (`app.js:159`).

**Hook object idiom to copy (`app.js:126-150`):**
```javascript
const Copy = {
  mounted() {
    this.el.addEventListener("click", async () => { ... this.el.dataset.copied = "true"; ... });
  },
};
```

**Registration — add `Tabs` to the existing hooks map (`app.js:156-161`):**
```javascript
const liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {
  ...
  hooks: { PresignedPut, PresignedVideoPut, PresignedMuxPut, MultipartUpload, Copy, Tabs },
  ...
});
```

**Net-new (no in-repo analog for the body):** the WAI-ARIA roving-tabindex keyboard handler (Arrow/Home/End, `aria-selected`, `aria-controls`, `tabindex` management) per D-96-17. Click stays server-side via `Phoenix.LiveView.JS`; the hook owns keyboard only. No JS framework, no new dep. (See `96-UI-SPEC.md:196` and D-96-17 for the contract.)

---

### `examples/adoption_demo/lib/adoption_demo_web/router.ex` (route — modified, 1 line)

**Analog:** the existing `live(...)` lines in the `:browser` scope (`router.ex:20-32`).

**Add one line (D-96-04)** inside `scope "/", AdoptionDemoWeb do ... pipe_through(:browser)`:
```elixir
live("/styleguide", StyleguideLive, :index)
```
The demo already boots a real Phoenix server with seeds in CI (`adoption_demo_e2e.sh:31-44`); no harness change needed.

---

### `.github/workflows/ci.yml` (config / CI — modified)

**Analog:** the `adoption-demo-e2e` lane steps (`ci.yml:649-747`) + the node-step idiom in `brandbook-tokens`.

**D-96-03 — add the two fast node steps to `adoption-demo-e2e` (Node already set up at `ci.yml:702-705`), BEFORE the browser run (`ci.yml:730` `Run adoption demo Playwright suite`).** Per D-96-21 the contrast + literal scan run first:
```yaml
      - name: Cohort contrast + literal gate
        run: |
          node brandbook/src/cohort-contrast.mjs   # token-pair contrast + D-96-18 parity + D-96-20 literal scan

      - name: Run adoption demo Playwright suite   # existing step ci.yml:730-731
        run: bash scripts/ci/adoption_demo_e2e.sh
```
Do **not** add this to `brandbook-tokens` — that lane is fenced to `rindle-admin.css` only and its mechanism is regenerate-then-`git diff --exit-code` (`ci.yml:1156-1157` banner), meaningless for a hand-authored file. The rendered polish + theme + reduced-motion proofs ride inside the new spec via the existing Playwright suite step (no new browser job).

**Alternative (Claude's discretion, D-96-03):** a small dedicated Node step/lane is acceptable provided it does not enter `brandbook-tokens` and runs where Node is already set up.

---

## Shared Patterns

### WCAG contrast math (per-script copy, never import)
**Source:** `admin-contrast.mjs:27-39` (`lum`/`ratio`); also `admin-polish.js:76-87` (`luminance`/`contrastRatio`).
**Apply to:** `cohort-contrast.mjs`.
The repo convention is per-script copies of the sRGB-linearize + ratio functions (stated at `admin-polish.js:12-14`), not a shared module. Copy verbatim.

### Parameterized polish gate (single shared module, override per surface)
**Source:** `examples/adoption_demo/e2e/support/admin-polish.js` — `assertAdminPolish(page, { root, interactiveSelectors, surface, viewport })` (`:459-506`).
**Apply to:** `cohort-styleguide.spec.js`.
This is the **one** file shared across both DSes (the D-94-07 seam, documented at `admin-polish.js:16-21`). Reuse unchanged; pass `root: "[data-ck-root]"`.

### Theme toggle → click → assert `data-theme` + `aria-pressed`
**Source:** `support/admin.js:57-62` (`selectAdminTheme`); button-group markup at `admin-gallery.mjs:347-350`.
**Apply to:** `StyleguideLive.render/1` toggle markup + the `selectCohortTheme` spec helper.

### Stable test markers separate from styling classes
**Source:** `admin-gallery.mjs` `data-rindle-admin-component` / `data-rindle-admin-state` (`:147,:356`), asserted in `admin-gallery-check.mjs:85-94`.
**Apply to:** `StyleguideLive` (`data-ck-section`/`data-ck-state`) and the spec's existence loop. Never assert on `.ck-*` BEM classes.

### Coverage / missing-pair loop (fail on omission, not just failure)
**Source:** `admin-contrast.mjs:43-49` (required-context loop) + `admin-gallery-check.mjs:85-94` (required component-state matrix).
**Apply to:** `cohort-contrast.mjs` coverage loop (D-96-19) and the spec component-existence assertion.

### Comment-stripping literal scan
**Source:** `admin-gallery-check.mjs:96-102` (`assertNoBareOutlineNone` + `stripCssComments`); same regex at `admin-polish.js:316`.
**Apply to:** the D-96-20 brace-depth literal scanner in `cohort-contrast.mjs`.

### Phoenix function-component conventions
**Source:** `cohort_components.ex` — `attr ... values:` (`:63,:207`), `:rest, :global` (`:65`), named slots (`:48,:67`), private `defp *_icon` clauses with `currentColor` SVG (`:216-315`), BEM class lists (`:73,:213`).
**Apply to:** every new primitive in `cohort_components.ex` and the icons in `StyleguideLive`.

### `.ck` shell + reveal/focus inheritance
**Source:** `launchpad_live.ex:88` (`<div class="ck">`); `cohort.css:124-153` (`.ck` box-sizing + `:focus-visible`); `cohort.css:589-599` (reveal).
**Apply to:** `StyleguideLive` shell (add `data-ck-root data-theme={@theme}`); every new selector stays `.ck`-scoped so it inherits the box-sizing / focus / (new) reduced-motion rules and is reachable by the `[data-ck-root]` polish query.

---

## No Analog Found

| File / concern | Role | Reason | Planner guidance |
|------|------|--------|------------------|
| `phx-hook="Tabs"` keyboard handler body | hook | No WAI-ARIA roving-tabindex tabs hook exists in the repo (`Copy` is the only custom hook, and it is click-only). | Author from the APG tabs spec (D-96-17, `96-UI-SPEC.md:196`); copy only the `Copy` hook *object shape* + registration. |
| `.ck-table` `aria-sort` sort header | component | "real `<button>` carrying `aria-sort`" is net-new in this repo (D-96-15). | Borrow `core_components` `:col`/`:rows` model + primer_live `aria-sort` contract per D-96-15; not a copyable in-repo analog. |
| Per-theme `--ck-shadow-ink`/`--ck-glow-ink` bare-channel tokens | config | Admin uses an elevation ladder but its exact channel-token mechanism is not the Cohort one; Cohort authors its own (D-96-12). | Author fresh per D-96-12; admin is philosophy-only, not a literal source. |

---

## Metadata

**Analog search scope:** `brandbook/src/`, `examples/adoption_demo/lib/adoption_demo_web/{live,components}/`, `examples/adoption_demo/e2e/{,support/}`, `examples/adoption_demo/priv/static/assets/{cohort.css,js/app.js}`, `.github/workflows/ci.yml`, `scripts/ci/`.
**Files read in full:** `admin-contrast.mjs`, `admin-design-system-data.mjs`, `admin-polish.js`, `support/admin.js`, `admin-screenshots.spec.js`, `launchpad_live.ex`, `cohort_components.ex`, `router.ex`, `admin-gallery.mjs`, `contrast.mjs`, `app.js`, `adoption_demo_e2e.sh`; targeted reads of `cohort.css` (token/offender/motion ranges), `admin-gallery-check.mjs` (helpers + emulateMedia), `ci.yml` (two lanes), `liveview.js`, `playwright.config.js`.
**Pattern extraction date:** 2026-06-17
