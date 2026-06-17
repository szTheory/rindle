# Phase 96: cohort-component-layer-dark-reduced-motion-contract-track-b - Context

**Gathered:** 2026-06-17 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Track B foundation (COHORT-06). Build Cohort's hand-authored `.ck-*` **Level-1 + Level-2
primitive layer** (table, stat tile, form, tabs, detail block, toolbar) as
`AdoptionDemoWeb.CohortComponents` function components paired with
`examples/adoption_demo/priv/static/assets/cohort.css`, render them in a net-new
`/styleguide` LiveView gallery, author the **net-new dark `[data-theme]` contract** and the
**net-new `prefers-reduced-motion: reduce` block** in `cohort.css` (neither exists today),
replace all color literals at usage sites with `--ck-*` tokens (grep-clean), extend the WCAG
contrast gate to **both** light and dark themes, and add a `data-ck-root` seam so the
generalized `admin-polish.js` can target `[data-ck-root]`/`.ck-*`.

**All visual values are already locked** by the approved `96-UI-SPEC.md` (space/type/color
ladders, exact light+dark hexes, the 6 Level-1 + 4 Level-2 inventory, motion rules, copy, and
the 7 machine-verifiable acceptance gates). This phase decides the **implementation wiring**.

Out of scope: inner-app pages (`/dashboard` → 99, `/upload` → 100, ops/member/lesson/media →
99), daisyUI retirement (101), the VIS-* re-converge + warn→fail polish-gate flip (102). No
data mutation / destructive UX — `/styleguide` is static reference. Cohort and `rindle-admin`
stay **deliberately separate but coherent** — shared vocabulary, never a shared stylesheet,
token file, or build step (D-94-05/06).
</domain>

<decisions>
## Implementation Decisions

### Contrast Gate Wiring

- **D-96-01:** The Cohort WCAG gate is a **net-new sibling script** (e.g.
  `brandbook/src/cohort-contrast.mjs`) backed by a net-new hand-maintained data module (e.g.
  `brandbook/src/cohort-design-system-data.mjs`) exporting a `COHORT_CONTRAST_PAIRS` array
  where **each pair carries a `theme: 'light' | 'dark'` field**. It mirrors the
  `admin-contrast.mjs` + `admin-design-system-data.mjs` pattern exactly. The net-new light +
  dark pairs from `96-UI-SPEC.md` (the 7 pair groups, lines 166–171) are added there.
- **D-96-02:** Do **not** extend `brandbook/src/contrast.mjs` for Cohort and do **not** route
  `--ck-*` values through `tokens.json`. `contrast.mjs` reads `tokens.json` and is theme-blind
  (flat `{fg,bg,min,context}`, no `theme` dimension); folding Cohort into it would violate
  D-94-05/06 (shared token file) and resolve every dark pair against a light value. The
  hand-authored light + dark `--ck-*` hexes are the literal sink, hard-coded in the new data
  module.
- **D-96-03:** The Cohort contrast gate runs as a standalone pass/fail `node` step in the
  **`adoption-demo-e2e` lane** (the Node+browser lane), **not** in `brandbook-tokens`. The
  brandbook-tokens lane is explicitly fenced to `rindle-admin.css` only (`ci.yml:1156-1157`)
  and its mechanism is regenerate-then-`git diff --exit-code`, which is meaningless for a
  hand-authored file that is never generated. (Claude's discretion on exact lane vs. a small
  new dedicated Node step, provided it does not enter `brandbook-tokens` and runs in a lane
  that already sets up Node.)

### `/styleguide` Route + E2E Polish Reach

- **D-96-04:** Add `/styleguide` as one more `live(...)` line in the **existing `:browser`
  scope** of `examples/adoption_demo/lib/adoption_demo_web/router.ex`, backed by a net-new
  `StyleguideLive`. The demo already boots a real Phoenix server with seeds in CI
  (`playwright.config.js` runs `mix phx.server`; `adoption_demo_e2e.sh` migrates+seeds+serves),
  so the route is reachable with no harness change.
- **D-96-05:** `StyleguideLive.render/1` emits the `.ck` shell with the seam attributes on the
  **per-LiveView `.ck` div** — `<div class="ck" data-ck-root data-theme={@theme}>` — following
  `launchpad_live.ex` (the `.ck` shell is rendered per-LiveView, not in `root.html.heex`). Do
  **not** place `data-ck-root` on `<body>` in `root.html.heex` — a body-level root would scoop
  daisyUI inner-app chrome into the single-root polish query and weaken the gate.
- **D-96-06:** The polish gate reaches `/styleguide` via a **net-new Playwright spec** (e.g.
  `e2e/cohort-styleguide.spec.js`) that calls the already-parameterized
  `assertAdminPolish(page, { root: "[data-ck-root]", interactiveSelectors: [".ck-btn",
  ".ck-tab", ".ck-input", ...] })` — reusing the exported function **unchanged** (D-94-07
  seam). Do not edit `admin-polish.js` to special-case Cohort, and do not bolt the gate onto
  the HTTP-only `cohort_demo_smoke.sh` (no browser there). This phase runs the gate in
  **warn/report mode**; the warn→fail flip is Phase 102.

### Theme + Reduced-Motion Rendering In The Gallery

- **D-96-07:** `/styleguide` renders both themes via an **interactive `data-theme` toggle on
  the `.ck` root** (a button group that sets `data-theme="light"|"dark"` on the wrapper,
  mirroring the admin theme picker `admin-gallery.mjs` + `selectAdminTheme` in `support/admin.js`).
  The e2e spec drives explicit themes by **clicking the toggle** and asserting `data-theme`
  flipped.
- **D-96-08:** The `prefers-reduced-motion: reduce` contract and the `prefers-color-scheme`
  auto-fallback are exercised via Playwright **`page.emulateMedia({ reducedMotion, colorScheme })`**,
  not a CSS-only static "reduced-motion" panel. Only `emulateMedia({reducedMotion:'reduce'})`
  triggers the real `@media` block and proves `.ck-reveal` resolves to its final state
  (acceptance gate 3); only `emulateMedia({colorScheme:'dark'})` proves the media fallback
  distinct from the explicit `[data-theme]` contract.

### CohortComponents Conventions

- **D-96-09:** New primitives follow the existing `CohortComponents` conventions exactly:
  `attr`/`slot` function components with `values:` enums, inline stroke-`currentColor` SVG icons
  via private `defp *_icon` clauses, BEM-ish `.ck-root__element--modifier` class names, and
  `--_local` CSS custom-prop variants. Every new selector stays `.ck`-scoped so it inherits the
  `.ck` reduced-motion / `:focus-visible` / box-sizing rules and is visible to the
  `[data-ck-root]`-scoped polish gate.
- **D-96-10:** Color-literal removal targets are confirmed and fixed: `#fff` at
  `.ck-copy[data-copied="true"]` (`cohort.css:404`) → `--ck-on-brand`; baked `rgba(...)`
  shadow/glow values → derive from per-theme `--ck-shadow-ink`/`--ck-glow-ink` base tokens; and
  the legacy usage-site `rem` font literals (`0.875rem`/`0.95rem`/`0.72rem` at lines 368/472/503)
  fold onto the nearest `--ck-step-*` token. After this, a hex/`rgb(`/`rgba(` scan of
  `cohort.css` finds color literals **only** inside `:root` / `[data-theme]` token-definition
  blocks.

### Research-Derived Decisions (2026-06-17 — four parallel expert-lens subagents; all coherent with D-96-01..10)

**CSS architecture / dark / motion / token discipline**

- **D-96-11:** Theme contract shape — author `:root, [data-theme="light"]` (light set) +
  `[data-theme="dark"]` (dark set); media fallback is
  `@media (prefers-color-scheme: dark) { :root:not([data-theme]) { …dark } }` (NOT
  `[data-theme="auto"]`). Set `color-scheme: light|dark` per theme so native `<select>`,
  scrollbars, and inputs theme correctly. One controlled, comment-bannered duplication of the dark
  token block is acceptable (the contrast data module + D-96-18 parity check catch divergence).
  Specificity is clean by construction — no `!important` outside the reduced-motion block. Rejected:
  `light-dark()` (hides the greppable `[data-theme="dark"]` selector gate 2 needs), Tailwind/daisyUI
  class theming (no Tailwind in this layer), `@layer` (no override problem to solve; admin doesn't
  use it either — keep flat source order with section banners).
- **D-96-12:** Elevation = lightness, shadow = derived. Surface ladder
  `--ck-bg → --ck-surface-2 → --ck-surface → --ck-surface-overlay` (add the overlay step) is the
  primary separator. Shadows/glows reference per-theme **base channel tokens** `--ck-shadow-ink` /
  `--ck-glow-ink` in bare-channel form (`15 27 23`), so `--ck-shadow-*` / `--ck-bg-glow` formulas
  are written **once** and only the ink flips per theme via `rgb(var(--ck-shadow-ink) / <alpha>)`.
  In dark, shadows go "barely there" by changing the ink, not re-baking rgba.
- **D-96-13:** Reduced-motion block —
  `@media (prefers-reduced-motion: reduce) { .ck *, .ck *::before, .ck *::after { animation-duration: .001ms !important; animation-iteration-count: 1 !important; transition-duration: .001ms !important } .ck-reveal { opacity:1; transform:none } }`.
  Scoped to `.ck *` (auto-covers every present/future primitive; never touches daisyUI chrome).
  Use `.001ms` not `0` so `transitionend`/`animationend` still fire (LiveView JS won't hang).
  Color/border state changes are KEPT (they convey state). This is the only legitimate `!important`
  site in the file. Keep the existing `prefers-reduced-motion: no-preference` reveal block as-is
  (complementary).

**Phoenix component API & gallery DX**

- **D-96-14:** API shape — one flat function component per primitive; `attr … values:` enums for
  variants/states; `:rest, :global` on every primitive; named slots only for genuine user content
  (`:col`, `:row`, `:actions`). Mirrors Phoenix `core_components` (least surprise). Avoid the
  petal `Field` god-component and salad_ui's React-structural ports / `tw_merge` dep.
- **D-96-15:** Table & form patterns — `.ck-table` uses the `core_components` `:col`/`:rows` model
  extended with per-column `sort_key`/`num`; **sort state is server-owned** (LiveView), the sort
  header is a real `<button>` carrying `aria-sort` (net-new in this repo). `.ck-input` **integrates
  `Phoenix.HTML.FormField`** (so `/styleguide` demos real semantics via `to_form` and Phases 99/100
  drop it into a real `<.form>` unchanged) and wires `aria-describedby` + `aria-invalid` (the gap
  core_components leaves; borrow primer_live's contract). Error = warning icon + message, never
  color-only.
- **D-96-16:** Hand-rolled `StyleguideLive`, **no phoenix_storybook** (validated: it pulls `mdex`
  Rust NIF + a parallel Tailwind/esbuild profile + a `.psb-sandbox` wrapper that muddies the
  real-markup the computed-style gate needs; it's Tailwind-centric — wrong fit). Borrow its
  information architecture only (Level-1/Level-2 tree; one variation-group per state). Theme toggle =
  server `assign(:theme)` + `phx-click` setting `data-theme` on the per-LiveView `.ck` shell
  (deterministic for e2e; no `localStorage` race). Emit stable `data-ck-section` / `data-ck-state`
  test markers **separate** from the BEM styling classes (don't assert on styling classes).
- **D-96-17:** Tabs accessibility — full WAI-ARIA APG tabs pattern (`role=tablist/tab/tabpanel`,
  `aria-selected`, `aria-controls`, roving `tabindex`, Arrow/Home/End). Click handled by
  `Phoenix.LiveView.JS`; keyboard handled by **one new `phx-hook="Tabs"`** added alongside the
  existing `Copy` hook (no JS framework, no dep). Selected tab = `aria-selected` + underline +
  weight (non-color cue).

**Proof harness & CI (harden the locked D-96-01/02/03/06/07/08)**

- **D-96-18:** Contrast data-module **parity check** — the hand-authored-file equivalent of the
  generated lane's `git diff --exit-code`. `cohort-contrast.mjs` asserts every `--ck-*` value in
  `COHORT_CONTRAST_PAIRS` **byte-equals** the value scanned from the matching `:root`/`[data-theme]`
  block in `cohort.css`; drift = hard fail. Gives single-source-of-truth without a CSS-parser dep.
- **D-96-19:** **Coverage loop** — mirror `admin-contrast.mjs`'s required-context loop: hard-code
  the required `{context × theme}` matrix from the UI-SPEC contrast table and fail on a *missing*
  pair, not only a failing one (kills the D-94-08 "self-check green while artifact omits it" trap).
  Add an analogous **component-existence** assertion (each of the 6 L1 + 4 L2 primitives is visible
  at `/styleguide` AND its required selector substring-exists in `cohort.css`) for gate 1.
- **D-96-20:** Literal gate = **hand-rolled brace-depth scanner**, not stylelint (confirmed
  stylelint cannot express "hex allowed only inside `:root`/`[data-theme]`" without a custom plugin,
  and `color-no-hex` misses `rgb()/rgba()`). ~30 lines of Node: strip comments, classify each
  top-level block by selector, allow literals only in the token-sink blocks (`:root`,
  `[data-theme=…]`, and the nested `:root` inside the `prefers-color-scheme` media block), allow
  `currentColor`/`transparent`/`color-mix`, fail on any hex/`rgb`/`rgba`/`hsl` elsewhere. Reuses the
  D-96-18 block extractor. Mirrors the in-repo `assertNoBareOutlineNone` pattern.
- **D-96-21:** Proof split & ordering — token-pair contrast + literal scan run as standalone fast
  `node` steps in the `adoption-demo-e2e` lane **before** the browser run; rendered contrast =
  `assertReadableContrast` over `[data-ck-root]` inside Playwright (catches cascade bugs). Spec
  order: `emulateMedia(reduce)` → **reduced-motion computed probe** (assert `.ck-reveal` →
  `opacity:1`/`transform:none`/`animation-name:none`) **before `freezeMotion` is injected** (freeze
  masks gate 3) → `emulateMedia(no-preference)` → toggle-light → polish → toggle-dark → polish →
  `emulateMedia(colorScheme:dark)` auto-fallback probe. Call `emulateMedia` only **after**
  `goto`/`waitForLiveSocket` (Playwright drops it across nav — issue #31328; Chromium-only suite
  makes this low-risk).

**Creative direction / UX (within locked UI-SPEC intent)**

- **D-96-22:** Interaction-state matrix (both themes, all 6 primitives): `:focus-visible` ring only
  (never `:focus`); hover changes background/border only — table rows = bg only, **no layout shift**;
  `:active` = `translateY(1px)` distinct from focus; disabled = `aria-disabled` + sunken
  `--ck-surface-2` + `--ck-muted` + `cursor:not-allowed` + `transform:none`; selected/current =
  `aria-selected`/`aria-current` + a non-color mark. Mirrors the admin interaction vocabulary in
  Cohort's own stylesheet (shared vocabulary, never a shared file). Numbers use `tabular-nums`;
  detail block is a real `<dl><dt><dd>`. **Seed the `/styleguide` gallery with real Cohort fiction**
  (a lesson-video row going `processing`, a quarantined upload, an empty member list) — it is the
  VIS-04 audit reference and the dev-trust signal, not lorem. Add a second empty-state copy variant
  ("never-populated" vs "filtered") for Phases 99/100. The dark palette is validated as premium
  (near-black not true-black, off-white ink not `#fff`, lightened accents, elevation-by-lightness) —
  no dark-value changes.
- **D-96-23:** **Contrast correction (escalated + maintainer-approved).** `--ck-faint` (`#8a9a92`
  light) is 2.95:1 on white / 2.77:1 on `--ck-bg` — it fails AA body and is hereby a
  **decorative/non-text role asserted at 3:1 only**. Any **readable** table/stat **secondary text
  uses `--ck-muted`** (`#586b63` light = 5.68:1 / `#9db1a8` dark — both pass 4.5). **No `--ck-*`
  color values change in `cohort.css`** — only the role assignment and the gate's pair list. The
  approved `96-UI-SPEC.md` contrast table was updated to match (the `--ck-faint` 4.5 body pair →
  `--ck-muted` 4.5 body pair + `--ck-faint` 3:1 decorative pair).

### Claude's Discretion

Per the maintainer's `minimal_decisive` calibration: exact new file names
(`cohort-contrast.mjs`, `cohort-design-system-data.mjs`, `StyleguideLive`,
`cohort-styleguide.spec.js`), the precise CI lane vs. dedicated Node step for D-96-03, the
toggle markup/labels, gallery grouping, and assertion wording may be resolved during planning —
provided they do not violate the separate-build-step boundary (D-94-05/06), the `[data-theme]`
theme contract, the `data-ck-root` seam, the warn-mode polish gate this phase, or any locked
visual value in `96-UI-SPEC.md`.

### Folded Todos

No matching pending todos were found for Phase 96 (`todo.match-phase 96` → 0 matches).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` — Phase 96 boundary; Track B build order
- `.planning/REQUIREMENTS.md` — COHORT-06 (the sole requirement this phase owns)
- `.planning/STATE.md` — v1.19 position; two-DS separation note
- `.planning/METHODOLOGY.md` — Idiomatic-Elixir / Narrow-Then-Escalate / Research-First lenses
- `.planning/phases/96-cohort-component-layer-dark-reduced-motion-contract-track-b/96-UI-SPEC.md`
  — the approved, machine-verifiable visual contract (all values FIXED; 7 acceptance gates)
- `.planning/phases/94-foundation-token-pipeline-ci-gate-new-token-categories/94-CONTEXT.md`
  — D-94-05/06 (no shared build; hand-authored cohort.css), D-94-07 (`admin-polish.js` seam)
- `.planning/phases/95-admin-level-1-component-audit-track-a/95-CONTEXT.md` — Track A analog
  (per-theme contrast data, gallery proof surface, focus/active contract)
- `examples/adoption_demo/priv/static/assets/cohort.css` — hand-authored `.ck-*` (599 lines);
  `:root` token block, `#fff` @404, `rgba` shadow/glow, `prefers-color-scheme` @93, only
  `prefers-reduced-motion: no-preference` @589 (no `[data-theme]`, no `reduce` block today)
- `examples/adoption_demo/lib/adoption_demo_web/components/cohort_components.ex` — component conventions
- `examples/adoption_demo/lib/adoption_demo_web/live/launchpad_live.ex` — `.ck` shell rendered
  per-LiveView (`:88`) — where `data-ck-root`/`data-theme` belong
- `examples/adoption_demo/lib/adoption_demo_web/router.ex` — `:browser` scope live routes (`:20-32`)
- `brandbook/src/contrast.mjs` — theme-blind, `tokens.json`-driven (the NON-cohort path; do not extend)
- `brandbook/src/admin-contrast.mjs` + `brandbook/src/admin-design-system-data.mjs` — the
  per-theme contrast-pair data-module pattern to copy
- `brandbook/src/admin-gallery.mjs`, `brandbook/src/admin-gallery-check.mjs` — gallery theme
  toggle + `emulateMedia` analog
- `examples/adoption_demo/e2e/support/admin-polish.js` — `{root, interactiveSelectors}`-parameterized gate
- `examples/adoption_demo/e2e/support/admin.js` — `selectAdminTheme` click→`data-theme` assert pattern
- `examples/adoption_demo/e2e/admin-screenshots.spec.js`, `examples/adoption_demo/e2e/playwright.config.js`
- `.github/workflows/ci.yml` — `brandbook-tokens` (`:1156-1157`, excludes cohort.css);
  `adoption-demo-e2e` (`:649-747`, the Node+browser lane); `cohort-demo-smoke` (HTTP-only)
- `scripts/ci/cohort_demo_smoke.sh` — HTTP-200 boot check only (no browser; cannot host polish gate)
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `admin-contrast.mjs` + `admin-design-system-data.mjs` — the exact per-theme,
  hand-maintained contrast-pair pattern to mirror for Cohort (each pair carries `theme`).
- `assertAdminPolish(page, {root, interactiveSelectors})` in `e2e/support/admin-polish.js` —
  already generalized (D-94-07); Cohort reuses it unchanged with `[data-ck-root]` / `.ck-*`.
- `admin-gallery.mjs` + `selectAdminTheme` (`support/admin.js`) — the `data-theme` toggle +
  click-to-assert + `emulateMedia` proof pattern for both themes and the reduced-motion/auto state.
- The adoption-demo Playwright harness boots a real Phoenix server with seeds in CI — a new
  `/styleguide` route needs no harness change.

### Established Patterns
- `cohort.css` is **hand-authored** vanilla CSS scoped under `.ck`; no `.mjs` generator, never
  in `tokens.json` (D-94-05/06). `--_local` custom-prop variants + BEM `.ck-root__el--mod`.
- The `.ck` shell renders **per-LiveView** (in each LiveView's `render/1`), not in the root layout.
- Theme today is `@media (prefers-color-scheme: dark)` only; this phase adds the explicit
  switchable `[data-theme]` contract, keeping `prefers-color-scheme` as auto fallback.
- Mechanical proof preferred: pass/fail contrast script + computed-style polish gate over
  subjective screenshot review.

### Integration Points
- New live route in `router.ex` `:browser` scope + new `StyleguideLive`.
- New `.ck-*` primitives in `cohort_components.ex` + `cohort.css` ( + dark `[data-theme]` block,
  `reduce` block, token-only color).
- New `cohort-contrast.mjs` + `cohort-design-system-data.mjs`, invoked in the
  `adoption-demo-e2e` lane.
- New Playwright spec (e.g. `cohort-styleguide.spec.js`) calling `assertAdminPolish` against
  `[data-ck-root]`, driving the `data-theme` toggle + `emulateMedia` states.
</code_context>

<specifics>
## Specific Ideas

- Dark is **semantic elevation, not color inversion** (`96-UI-SPEC.md`): dark surfaces step
  lighter with elevation; shadows barely read on dark — separation from tint, not drop-shadow.
- Status colors always pair an icon/label, never color-alone (existing `.ck-badge` rule).
- Every interactive `.ck-*` primitive ships a token-backed `:focus-visible` ring (`--ck-focus`),
  never bare `outline:none`.
- Minimum 44px interactive target (`admin-polish.js` `MIN_TARGET_PX`) applies to the Cohort root.
- Preserve the exact `96-UI-SPEC.md` copy contract for empty/error/loading states and button samples.
</specifics>

<deferred>
## Deferred Ideas

- Inner-app page restyles (`/dashboard`, ops, member/lesson/media → Phase 99; `/upload` → 100).
- daisyUI/Tailwind scaffold retirement from inner pages → Phase 101.
- Warn→fail flip of the Cohort polish gate as the single merge-blocking visual gate, plus
  VIS-* re-converge / idempotency / cross-surface audit → Phase 102.
- Optional non-blocking pixel-baseline screenshots → later milestone work.

### Reviewed Todos (not folded)
None — `todo.match-phase 96` returned 0 matches.
</deferred>
