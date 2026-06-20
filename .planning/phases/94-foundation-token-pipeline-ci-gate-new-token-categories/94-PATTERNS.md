# Phase 94: Foundation — Token Pipeline CI Gate & New Token Categories - Pattern Map

**Mapped:** 2026-06-14
**Files analyzed:** 11 (5 modified generators/data, 1 source-of-truth JSON, 1 NEW sync script, 1 NEW CI job, 1 modified test harness, 1 mirrored CSS copy, 1 brandbook package.json touch)
**Analogs found:** 10 / 11 (the sync script is net-new but copies the generator I/O boilerplate verbatim)

> This is a **wiring phase**. Almost every change is "add another `Object.entries` emit loop / another array literal entry / another proof-lane job" alongside an existing identical one. The analogs below are not loose inspiration — they are the exact lines the new code clones. Line numbers are current as of this mapping.

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `brandbook/tokens/tokens.json` | config (source of truth) | transform | Itself — existing `color.raw` / `color.semantic` / `motion` / `typography.scale` blocks | exact (in-file) |
| `brandbook/src/admin-css-build.mjs` | build/generator | transform (token→CSS) | Itself — existing emit loops (52-75) + parity arrays (574-606) | exact (in-file) |
| `brandbook/src/admin-design-system-data.mjs` | config/data module | transform | Itself — `MOTION_TOKENS` (44-50) + `CONSOLE_CONTRAST_PAIRS` (54-109) | exact (in-file) |
| `brandbook/src/tokens-build.mjs` | build/generator | transform (token→CSS) | `admin-css-build.mjs` emit loops; itself (22-41) | exact (in-file) |
| `brandbook/src/sync-admin-css.mjs` (NEW) | build/utility | file-I/O (copy) | `tokens-build.mjs` / `admin-css-build.mjs` read+write boilerplate (4-10, 59) | role-match (new file, cloned I/O) |
| `.github/workflows/ci.yml` (`brandbook-tokens` job) | config (CI) | batch/request-response | `cohort-demo-smoke` (631-647) + `adoption-demo-e2e` (649-757) proof lanes | exact (sibling job) |
| `examples/adoption_demo/e2e/support/admin-polish.js` | test (harness) | event-driven (computed-style) | Itself — `assertAdminPolish` (383) + `run()` dispatch (389-405) | exact (in-file) |
| `priv/static/rindle_admin/rindle-admin.css` | build artifact (shipped) | file-I/O (mirror) | `brandbook/tokens/rindle-admin.css` (generator output, byte-identical) | exact (mirror target) |
| `brandbook/src/admin-contrast.mjs` | build (WCAG gate) | transform | NO CODE CHANGE — data-driven; new pairs flow through `resolve()` (20-25) | n/a (read-only verify) |
| `brandbook/src/admin-gallery.mjs` / `admin-gallery-check.mjs` | build (browser proof) | event-driven | NO CODE CHANGE expected — selector-based contract, not token-based | n/a |
| `examples/adoption_demo/e2e/admin-screenshots.spec.js` | test (spec) | event-driven | Call site (79) — passes through unchanged; acceptance test for D-94-07 | exact (no edit) |

---

## Pattern Assignments

### `brandbook/tokens/tokens.json` (config, transform) — Touchpoint A

**Analog:** Itself. Add new top-level objects / extend existing blocks with VALUES from `94-UI-SPEC.md`. The `deref()` `{name}` reference syntax is the established convention — any new value can reference a `color.raw` key.

**Existing `color.raw` + collapsed dark surfaces to differentiate** (lines 37, 99-104):
```json
"dark-surface": "#161E23",
...
"status-ready-surface": "{dark-surface}",      // ← these 6 collapse today
"status-processing-surface": "{dark-surface}",
"status-warning-surface": "{dark-surface}",
"status-danger-surface": "{dark-surface}",
"status-quarantine-surface": "{dark-surface}",
"status-info-surface": "{dark-surface}"
```
Per `94-UI-SPEC.md`: add the six new raw hexes (`dark-ready-surface #16241E`, `dark-processing-surface #1C1E2B`, `dark-warning-surface #241F16`, `dark-danger-surface #2A1A1A`, `dark-quarantine-surface #211C2B`, `dark-info-surface #161D2B`) into `color.raw`, then point `color.semantic.dark.status-*-surface` at them (e.g. `"status-ready-surface": "{dark-ready-surface}"`). **No emit-code change** — `emitVariables(T.color.semantic.dark)` already covers them (admin-css-build.mjs:80). This is the lowest-risk category (D-94-08 ✅).

**Existing `motion` block to extend** (lines 155-163):
```json
"motion": {
  "press": "120ms",
  "popover": "160ms",
  "toast": "200ms",
  "transition": "300ms",
  "diagram": "600ms",
  "easing": "cubic-bezier(0.2, 0, 0, 1)",
  "rules": "..."
}
```
Add `easing-standard`, `easing-decelerate`, `easing-accelerate` (UI-SPEC values). The generator loop (admin-css-build.mjs:71-74) emits every key except `rules` automatically. ⚠️ `diagram` is currently emitted but NOT in `MOTION_TOKENS` — confirm whether new easings join `MOTION_TOKENS` parity (UI-SPEC says they must) without breaking the existing `easing`/`diagram` asymmetry.

**Existing `typography.scale` shape (clamp goes here)** (lines 119-127) and `spacing`/`shadow` blocks (134, 146-148): new fluid clamp values and the `shadow-raised`/`shadow-overlay` + `elevation-*` ladder are added as new keys/fields. `shadow` is currently a single `{ "card": "..." }` object — extend to an object loop (see emit pattern below).

---

### `brandbook/src/admin-css-build.mjs` (generator, transform) — Touchpoint B + C

**Analog:** Itself. Every new category clones one of these existing emit loops, then registers in one of these existing parity arrays.

**Emit-loop pattern to clone** — simple key/value (spacing, line 63; radius, 64-65):
```javascript
css += '\n  /* spacing */\n';
for (const [k, v] of Object.entries(T.spacing)) css += `  --rindle-space-${k}: ${v};\n`;
css += '\n  /* radii */\n';
for (const [k, v] of Object.entries(T.radius)) css += `  --rindle-radius-${k}: ${v};\n`;
```
Use this verbatim for `elevation` (NEW: `--rindle-elevation-${k}`), breakpoints (NEW: `--rindle-bp-${k}` or `--bp-${k}` per UI-SPEC), fluid space gutters, and fluid display clamps. Use `deref(v)` (not bare `v`) when a value contains a `{token}` reference (elevation references `{dark-bg}` etc.) — see the `border` loop at line 67 for the `deref` form:
```javascript
for (const [k, v] of Object.entries(T.border)) if (typeof v === 'string') css += `  --rindle-border-rule-${k}: ${deref(v)};\n`;
```

**Single-line → object-loop conversion** — `shadow` (line 68):
```javascript
css += `  --rindle-shadow-card: ${T.shadow.card};\n`;   // ← single key today
```
Extend to a loop over `Object.entries(T.shadow)` to emit `shadow-card`/`shadow-raised`/`shadow-overlay`.

**Motion loop (already covers new easings, no new loop)** (lines 71-74):
```javascript
for (const [k, v] of Object.entries(T.motion)) {
  if (k === 'rules') continue;
  css += `  --rindle-motion-${k}: ${v};\n`;
}
```

**Parity registration — Touchpoint C (the silent-omission guard, D-94-08).**

`exact()` literal for `MOTION_TOKENS` (line 39) — must be kept in lockstep with the export:
```javascript
exact(MOTION_TOKENS, ['press', 'popover', 'toast', 'transition', 'easing'], 'MOTION_TOKENS');
```
Add new easing keys to BOTH this literal AND `admin-design-system-data.mjs:44` or `exact()` throws (Pitfall 5).

`requiredMotionUses` / `requiredTokenUses` — the "emitted-AND-used" enforcement (lines 595-601):
```javascript
const requiredMotionUses = MOTION_TOKENS.map((token) => `var(--rindle-motion-${token})`);
const requiredTokenUses = ['var(--rindle-surface)', 'var(--rindle-text)', 'var(--rindle-focus-width)', 'var(--rindle-focus-offset)', 'var(--rindle-focus-ring)'];
const missing = [];
for (const selector of requiredSelectors) if (!written.includes(selector)) missing.push(selector);
for (const scope of requiredScopes) if (!written.includes(scope)) missing.push(scope);
for (const motion of requiredMotionUses) if (!written.includes(motion)) missing.push(motion);
for (const token of requiredTokenUses) if (!written.includes(token)) missing.push(token);
```
⚠️ `requiredMotionUses` requires each `MOTION_TOKENS` key to be **USED** in a rule, not just emitted (Pitfall 4). New easing presets must be consumed by at least one CSS rule (the existing `transition:` rules at lines 105/145/237/449/468/484 all reference `var(--rindle-motion-easing)` — point one or more at the new presets). Add `var(--rindle-elevation-...)`, fluid-type/space, and breakpoint vars to `requiredTokenUses` so an emitted-but-unused category hard-fails.

**Existing per-state CSS-rule loop** (a model if a new category needs per-item selectors) — lines 212-219:
```javascript
for (const state of STATUS_STATES) {
  css += `
.rindle-admin-status-chip--${state} {
  color: var(--rindle-status-${state});
  background: var(--rindle-status-${state}-surface, var(--rindle-surface-raised));
}
`;
}
```

**Existing media query to map to `--bp-md`** (line 531) — UI-SPEC anchors `bp-md = 760px` so output is unchanged:
```javascript
@media (max-width: 760px) {
```

---

### `brandbook/src/admin-design-system-data.mjs` (data module, transform) — Touchpoint C

**Analog:** Itself.

**`MOTION_TOKENS` export to extend** (lines 44-50):
```javascript
export const MOTION_TOKENS = [
  'press',
  'popover',
  'toast',
  'transition',
  'easing',
];
```
Add the new easing preset keys. Keep in lockstep with `admin-css-build.mjs:39` `exact()` literal.

**`CONSOLE_CONTRAST_PAIRS` — the existing dark-status `.map()` to leave structurally untouched** (lines 84-90):
```javascript
...STATUS_STATES.map((state) => ({
  fg: `status-${state}`,
  bg: `status-${state}-surface`,   // resolves to dark-surface today; differentiating is a tokens.json value change
  theme: 'dark',
  min: 4.5,
  context: `status chips ${state} foreground on dark surface`,
})),
```
Per D-94-08 / Pitfall 3: **no code change to this map** — differentiation is a `tokens.json` value change (the `bg` token name stays `status-${state}-surface`). For the NEW elevation `dark-text` pairs, clone the plain-object entry shape used everywhere in this array, e.g.:
```javascript
{ fg: 'text', bg: 'surface-raised', theme: 'dark', min: 4.5, context: 'drawer text on dark surface-raised' },
```
Add elevation pairs as `{ fg: 'dark-text', bg: 'elevation-N', theme: 'dark', min: 4.5, context: '...' }` (or via raw hex names that `resolve()` finds in `color.raw`).

**Mirror to `tokens.json` `contrast_pairs`** (tokens.json:164-203): the JSON array is the parallel brand-level gate. New dark-status/elevation pairs may also be added there following the `{ "fg": ..., "bg": ..., "min": ..., "context": ... }` shape (lines 188-197 already hold `dark-*` on `dark-bg` pairs).

---

### `brandbook/src/tokens-build.mjs` (generator, transform) — conditional

**Analog:** Its own emit loops (22-41), structurally identical to `admin-css-build.mjs`. Touch ONLY if a new category must appear in the broader `tokens.css` (Open Question 1 / Assumption A2). Default: admin-only categories do NOT touch this file. If they should also be in `tokens.css`, add the analogous `Object.entries` loop here too — the parity self-check (62-66) and the diff gate catch either decision.

```javascript
css += '\n  /* spacing */\n';
for (const [k, v] of Object.entries(T.spacing)) css += `  --rindle-space-${k}: ${v};\n`;
```

---

### `brandbook/src/sync-admin-css.mjs` (NEW utility, file-I/O) — D-94-03

**Analog:** The read/write boilerplate at the top of `tokens-build.mjs` (4-10) and the `writeFileSync` at `admin-css-build.mjs:571`. This is the single committed mechanism that mirrors the generator output to the shipped package copy (replacing today's hand-copy).

**Path-resolution + write boilerplate to clone** (`admin-css-build.mjs` 4-6, 17-20, 571):
```javascript
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const tokensDir = join(here, '..', 'tokens');
const adminCssPath = join(tokensDir, 'rindle-admin.css');
// ...
writeFileSync(adminCssPath, css);
```
The new script reads `brandbook/tokens/rindle-admin.css` and writes `priv/static/rindle_admin/rindle-admin.css` (resolve repo root via `join(here, '..', '..')`, mirroring `admin-gallery-check.mjs:11` `const repoRoot = join(here, '..', '..')`). Discretion on filename (D-94 discretion clause); `sync-admin-css.mjs` recommended. Run it as a job step AND locally so the Elixir equality test (`admin_design_system_validation_test.exs:213`) stays green.

---

### `.github/workflows/ci.yml` — NEW `brandbook-tokens` job (config/CI, batch) — D-94-01/02

**Analog:** `cohort-demo-smoke` (631-647) for the minimal standalone proof-lane skeleton + `adoption-demo-e2e` (649-757) for the Node/Playwright/checkout pieces.

**Proof-lane skeleton to clone** (cohort-demo-smoke, lines 631-647):
```yaml
  cohort-demo-smoke:
    name: Cohort Demo Smoke
    runs-on: ubuntu-22.04
    needs: [quality, optional-dependencies]      # ← the proof-lane convention (D-94-01)
    if: github.repository == 'szTheory/rindle'    # ← mirror this guard
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      - name: Run cohort demo cold-start smoke
        run: bash scripts/ci/cohort_demo_smoke.sh
```

**Node-20 setup block to copy verbatim** (adoption-demo-e2e, lines 696-699 — identical at 467-470):
```yaml
      - name: Set up Node
        uses: actions/setup-node@v4
        with:
          node-version: "20"
```

**Playwright install incantation** — from `scripts/ci/adoption_demo_e2e.sh` (the `npm ci` near line 40) and STACK. `admin-gallery-check.mjs:14-15` resolves `playwright` via `examples/adoption_demo`'s `createRequire`, so install MUST happen there first (D-94-02, Pitfall 2):
```yaml
      - name: Install adoption_demo node deps (playwright resolution anchor)
        working-directory: examples/adoption_demo
        run: npm ci
      - name: Install Playwright chromium
        working-directory: examples/adoption_demo
        run: npx playwright install --with-deps chromium
```

**Failure-artifact upload pattern** (optional, `if: failure()`) — clone from adoption-demo-e2e (749-757):
```yaml
      - name: Upload Playwright report on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: adoption-demo-playwright-report
          path: |
            examples/adoption_demo/playwright-report/
            examples/adoption_demo/test-results/
          if-no-files-found: ignore
```

**Job-specific step sequence (D-94-02 order)** — net-new, but each step is a one-line `node …mjs` / `cp` / `git diff`:
```yaml
      - run: node brandbook/src/tokens-build.mjs
      - run: node brandbook/src/admin-css-build.mjs
      - run: node brandbook/src/admin-contrast.mjs
      - run: node brandbook/src/admin-gallery-check.mjs   # internally re-runs css-build + gallery.mjs
      - run: node brandbook/src/sync-admin-css.mjs          # the sync mechanism
      - name: Fail on any uncommitted generated diff
        run: |
          if ! git diff --exit-code; then
            echo "::error::Generated CSS is out of sync with tokens.json. Run the brandbook generators and commit the result."
            exit 1
          fi
```
Drift-failure copy is LOCKED by `94-UI-SPEC.md` Copywriting Contract (line 206).

---

### `examples/adoption_demo/e2e/support/admin-polish.js` (test harness, event-driven) — D-94-07

**Analog:** Itself. Thread `root` + `interactiveSelectors` through with today's values as defaults; no behavior change for the admin spec.

**Module constants to convert to defaults** (lines 16, 28-38):
```javascript
const ROOT = "[data-rindle-admin-root]";
const INTERACTIVE_SELECTORS = [ /* the existing 9 entries */ ];
```
Rename to `DEFAULT_ROOT` / `DEFAULT_INTERACTIVE_SELECTORS`.

**Entry-point signature to extend** (line 383):
```javascript
async function assertAdminPolish(page, { viewport, surface } = {}) {
```
becomes:
```javascript
async function assertAdminPolish(
  page,
  { viewport, surface, root = DEFAULT_ROOT, interactiveSelectors = DEFAULT_INTERACTIVE_SELECTORS } = {}
) {
```

**Thread `root` into the two consumers that read it** — `assertNoClippedText` (line 92-93, `page.evaluate(({ROOT, ...}) => ...)`) and `assertReadableContrast` (164). Currently they reference the module-level `ROOT` inside the `page.evaluate` closure-arg object; pass `root` in instead.

**Thread `interactiveSelectors` into the two locator consumers** — `assertTargetSizes` (272, `page.locator(INTERACTIVE_SELECTORS.join(","))`) and `assertNoInteractiveOverlap` (300, same).

**Dispatch site to update** (the `run()` calls, 399-405) — each sub-assertion gains the threaded param with the module default. Acceptance test (D-94-07): `admin-screenshots.spec.js:79` calls `assertAdminPolish(page, { viewport, surface })` with no `root`/`interactiveSelectors`, so defaults apply and the existing admin spec passes unchanged. **No auto-detection.**

---

### `examples/adoption_demo/e2e/admin-screenshots.spec.js` (spec) — NO EDIT

**Analog:** Call site (line 79): `await assertAdminPolish(page, { viewport, surface });`. This MUST stay unchanged — it IS the acceptance test that the harness parameterization is backward-compatible (D-94-07).

---

### `priv/static/rindle_admin/rindle-admin.css` (shipped artifact) — NO HAND-EDIT

**Analog:** `brandbook/tokens/rindle-admin.css` (the generator output — byte-identical today). This file is REGENERATED by the sync script, never hand-edited. It is listed in `mix.exs:279` `files:` (`priv/static/rindle_admin`) so it ships in the Hex package. The `git diff --exit-code` step covers it because the sync writes into the working tree before the diff.

---

## Shared Patterns

### Generated-file header (every generated artifact carries it)
**Source:** `admin-css-build.mjs:48`, `tokens-build.mjs:18`
**Apply to:** Any new generated output (including the synced copy if the script regenerates rather than byte-copies)
```javascript
let css = `/* generated by brandbook/src/admin-css-build.mjs from tokens.json - do not edit by hand */
```

### `deref()` token-reference resolution
**Source:** `admin-css-build.mjs:23-27`, `tokens-build.mjs:13-16`, `admin-contrast.mjs:15-18` (three per-script copies — repo convention is copy, not cross-import)
**Apply to:** Any new emit loop whose values contain `{token}` references (elevation, shadows referencing `{dark-bg}` etc.)
```javascript
const raw = T.color.raw;
const deref = (v) => v.replace(/\{([a-z0-9-]+)\}/g, (_, k) => {
  if (!(k in raw)) throw new Error(`unknown raw token reference: {${k}}`);
  return raw[k];
});
```

### `exact()` array-equality parity (the idempotency anchor)
**Source:** `admin-css-build.mjs:29-40`
**Apply to:** Any extended constant list (`MOTION_TOKENS`, and the two-source-of-truth literal at line 39)
```javascript
const exact = (actual, expected, label) => {
  const a = JSON.stringify(actual); const e = JSON.stringify(expected);
  if (a !== e) throw new Error(`${label} mismatch: expected ${e}, got ${a}`);
};
```

### Emitted-AND-used parity registration (silent-omission guard)
**Source:** `admin-css-build.mjs:595-606`
**Apply to:** EVERY new token category — add to `requiredTokenUses` / `requiredMotionUses` or the category can be emitted but silently unused (D-94-08, Pitfalls 4-5).

### WCAG resolve + ratio (data-driven, no code change)
**Source:** `admin-contrast.mjs:20-39`
**Apply to:** New contrast pairs flow through automatically — add data to `CONSOLE_CONTRAST_PAIRS`, not code. `resolve()` looks up `raw` then `color.semantic[theme]`; a new pair referencing a token that exists only under one theme returns `null` → `unknown token` FAIL (Pitfall 3).

### Standalone Node proof-lane convention
**Source:** `ci.yml:640-641` (`needs: [quality, optional-dependencies]` + `if: github.repository == 'szTheory/rindle'`)
**Apply to:** The new `brandbook-tokens` job — same `needs`, same `if`, `ubuntu-22.04`, `setup-node@v4` node-20.

### Locked diagnostic copy (operator/SRE voice)
**Source:** `94-UI-SPEC.md` Copywriting Contract (lines 206-208)
**Apply to:** The CI gate's `::error::` output and any parity/contrast failure messages — exact strings are the contract, not paraphrasable.

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `brandbook/src/sync-admin-css.mjs` | utility | file-I/O | Net-new script; no existing file copies one generated CSS to a second location. BUT its read/write/path boilerplate is cloned verbatim from `admin-css-build.mjs` (4-20, 571) and `admin-gallery-check.mjs:11` repo-root resolution — so this is "no exact analog, full boilerplate analog." Alternative per A1/Open-Q2: a one-line `cp` step in the CI job instead of a script (loses the "single local mechanism" property — recommend the script). |

Everything else has an in-file or sibling-job exact analog. There is no genuinely novel machinery in this phase.

---

## Metadata

**Analog search scope:** `brandbook/src/`, `brandbook/tokens/`, `.github/workflows/ci.yml`, `examples/adoption_demo/e2e/`, `scripts/ci/`, `mix.exs`, `priv/static/rindle_admin/`
**Files scanned (read in full or targeted):** `admin-css-build.mjs`, `admin-design-system-data.mjs`, `tokens-build.mjs`, `tokens.json`, `admin-contrast.mjs`, `admin-gallery-check.mjs`, `admin-polish.js`, `ci.yml` (455-764), `admin-screenshots.spec.js` (call site), `scripts/ci/adoption_demo_e2e.sh`, `mix.exs` (275-285), `brandbook/src/package.json`
**Pattern extraction date:** 2026-06-14
</content>
</invoke>
