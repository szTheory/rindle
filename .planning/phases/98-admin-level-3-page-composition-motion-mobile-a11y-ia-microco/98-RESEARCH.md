# Phase 98: Admin Level-3 Page Composition + Motion / Mobile / A11y / IA / Microcopy — Research

**Researched:** 2026-06-18
**Domain:** Phoenix LiveView 1.1 design-system composition + generated-CSS pipeline + dual-home merge-gate validation (ExUnit static + Playwright computed-style)
**Confidence:** HIGH

## Summary

This phase is exceptionally well-specified: `98-UI-SPEC.md` (six assertable merge-gates §A–§F) and `98-CONTEXT.md` (D-98-01…16) lock the visual contract, the 4-plan dependency chain, the gate test homes, the generated-CSS build boundary, the two-stop responsive breakpoints, and the streams-out-of-scope call. Domain re-research is therefore deliberately **out of scope** — this RESEARCH fills the three genuine remaining gaps the planner needs: (1) a concrete **Validation Architecture** mapping each of the six gate clauses to its proving home (ExUnit vs Playwright) grounded in the real assertion idioms in `admin_design_system_validation_test.exs` and `admin-polish.js`; (2) verified **Phoenix/LiveView 1.1.30 API idioms** for `focus_wrap`, `JS.transition`, `JS.push_focus`/`JS.pop_focus`, and the `inert`/`aria-hidden` overlay contract; (3) **execution-order landmines** specific to driving this chain green.

The codebase is grounded: LiveView is pinned at **1.1.30** `[VERIFIED: mix.lock]` (optional dep). The six surface modules live in `lib/rindle/admin/live/*_live.ex` (not `lib/rindle/admin/`); they hand-roll `<table>` markup today (assets_live has full `<thead>`/`<th scope="col">` already but **no `<caption>` and no `scope="row"`**). `components.ex` ends at `table/1` — `page/1` does not exist. The CSS generator's collapse `@media` block is at `admin-css-build.mjs` **~L946** (`@media (max-width: 760px)`), the reduced-motion block at ~L970, and the fail-closed `requiredSelectors`/`requiredMetaSelectors`/`requiredTokenUses` guards at ~L989–1060. `--rindle-shadow-card` is **not** in the current `requiredTokenUses` list (D-98-13 guard-1 confirmed needed). The Playwright spec literal is `toHaveLength(22)` with 22 enumerated screenshot states.

**Primary recommendation:** Treat the six §A–§F merge-gate clauses as the unit of planning. For each clause apply the decisive test from D-98-05 — *does proving it require the cascade to resolve (media query firing / theme applying / `:focus-visible` ≠ `:focus` / `::before content:attr()` computing / dialog-open DOM mutation)?* If yes → Playwright `admin-polish.js` (computed-style); if a static substring/token/regenerate-diff fully proves it → ExUnit `admin_design_system_validation_test.exs`. Composition and Motion split across BOTH homes (unconditional clauses → ExUnit, conditional clauses → Playwright). Bump `toHaveLength(22)` deliberately when net-new e2e states land.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| `page/1` scaffold grammar (slots/state) | Phoenix.Component (`components.ex`) | — | Server-rendered HEEx; single grammar forbids page-local styling (§A) |
| Layout/grid/two-pane/responsive | Generated CSS (`admin-css-build.mjs` → `rindle-admin.css`) | — | All structural selectors authored in `.mjs`, never hand-edited (D-98-12) |
| Motion (`JS.transition`/`:active`) | Generated CSS (durations) + `components.ex` (`JS` wiring) | — | CSS owns the animated properties + reduced-motion; `JS` coordinates enter/leave timing |
| Overlay focus trap / return / inert | `components.ex` `modal/confirm_dialog` + per-surface wiring | LiveView runtime (`focus_wrap`, `JS.push_focus`/`pop_focus`) | Server renders trap container; runtime moves focus + toggles `inert` |
| Server-owned theme `aria-pressed` | Shell mount → `theme_picker` assign | client `JS.set_attribute` (progressive enhancement only) | Server must be source of truth (survives dead-render/reconnect, D-98-07) |
| IA: nav labels/order, deep-links | `components.ex` `shell` (`@surfaces`) + surface `handle_params` | router (one new `variants-jobs/:id` route) | Labels/order are server render; deep-links are `handle_params` filters already parsed (D-98-10) |
| Microcopy strings | `components.ex` defaults + surface modules | — | Static rendered content; primary denylist scan is over rendered markup in ExUnit |
| Static gate clauses (token/selector/source) | ExUnit `admin_design_system_validation_test.exs` | — | Substring/regenerate-diff fully proves them |
| Cascade/viewport/theme/interaction gate clauses | Playwright `admin-polish.js` + `admin-screenshots.spec.js` | — | Only `getComputedStyle` across real states proves them |

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-98-01 (P1):** Author `page/1` scaffold in `components.ex` (slots `:summary/:filters/:work(required)/:aside/:actions` + `attr :state :ok|:empty|:error|:loading`) AND land all generated-CSS for motion §B, mobile-first responsive §C, two-pane grid §A, `:focus-visible`/focus-ring §D in the **same** plan — authored through `admin-css-build.mjs`, run through build → contrast → gallery-check → `sync-admin-css.mjs` → byte-identical drift gate. Ends green with `page/1` existing but unused. `depends_on: []`.
- **D-98-02 (P2):** Fix §D primitive a11y bugs in `components.ex` (centralized), then migrate each of six `*_live.ex` surfaces onto `page/1` as **one atomic commit per surface**. `<table>` caption/`<thead>`/`scope` fix rides this migration (D-98-08). Relief valve: split P2a (a11y primitives) → P2b (migrations) if too heavy, keeping migrations atomic-per-surface. `depends_on: [P1]`.
- **D-98-03 (P3):** Nav relabel/reorder (`@surfaces`), Overview triage-home rebuild (`home_live.ex`), deep-link query params, "Actions"→Maintenance distribution, new `variants-jobs/:id` route (D-98-09), AND §F microcopy replacements. `depends_on: [P2]`.
- **D-98-04 (P4):** Extend both test homes to assert all six §A–§F gates over real surfaces; run full pipeline green; reconcile/assert the §A↔§C 760–1023px band. `depends_on: [P3]`, `autonomous: false`.
- **D-98-05/06 (gate homes + scope guards):** Static CSS-text/token/source-scan → ExUnit (`admin_design_system_validation_test.exs`). Cascade/viewport/theme/interaction-conditional → Playwright (`admin-polish.js`). Composition + Motion PARTIALLY split (unconditional→ExUnit, conditional→Playwright). Contrast stays ExUnit-only (`admin-contrast.mjs`, 58/58). `theme_picker aria-pressed` asserted in dead/server-rendered markup (`render_to_string` grep in ExUnit). New Playwright states bump the `toHaveLength(22)` literal **deliberately**. Microcopy denylist runs **primary in ExUnit** over rendered markup. New admin-polish checks land **already-HARD admin-root-only** against `[data-rindle-admin-root]` (do NOT generalize over Cohort or flip warn→fail — that's Phase 102).
- **D-98-07:** Centralized §D primitive fixes in `components.ex`: theme_picker server-owned `aria-pressed` (keep `JS.set_attribute` as progressive enhancement only); `live_indicator` drop dead `tabindex="0"`, add `role="status"`/`aria-live="polite"`/`aria-atomic`; skip-link as first focusable child + `<main id="rindle-admin-main" tabindex="-1">`; persistent ASSERTIVE `role="alert"` region in `shell` (empty at mount); `error_state` → `role="alert"`. Server must learn current theme (session/connect param) — real wiring task.
- **D-98-08:** Table caption/scope is a SPREAD that rides the scaffold migration (no standalone caption pass); §C stacked-card transform drives off the **same** `scope`/`data-label` markup.
- **D-98-09 (option A, LOCKED):** Add dedicated `variants-jobs/:id` `:show` route + `handle_params(%{"id"=>id})` + new `Queries` run-detail function + one-run detail render with redaction parity.
- **D-98-10:** All §E deep-links map to already-parsed `handle_params` filters (`variants-jobs?state=failed`, `assets?state=quarantined`, `upload-sessions?state=expired`, `?class=stale`) — pure `<a href>`, NO new routes. Triage-home rebuild is render-only off `Queries.home_status/1`; replace the `inspect/1` anti-pattern.
- **D-98-11:** New shared `modal/1`/`confirm_dialog/1` overlay using `Phoenix.Component.focus_wrap` (NOT hand-rolled keydown trap) + `role="dialog"`/`alertdialog` + `aria-modal` + `aria-labelledby` + ESC via `phx-window-keydown phx-key="escape"` + return-focus to stashed trigger + `inert` AND `aria-hidden` on `main`+`nav` while open. **Critical:** inert/aria-hidden toggle must reset on close AND survive LiveView reconnect.
- **D-98-12:** EVERY new selector authored as literal template-string blocks in `admin-css-build.mjs`, consuming only existing `--rindle-*` tokens, regenerated + byte-mirrored by `sync-admin-css.mjs`. **NEVER hand-edit either CSS file.** Singletons stay inline. Drift closed by DS-01 (`git diff --exit-code`) + ADMIN-02 (byte-equality). No `tokens.json` change required.
- **D-98-13:** Two in-generator guards (fail closed): (1) add `var(--rindle-shadow-card)` to `requiredTokenUses`; (2) extend `requiredSelectors`/`requiredMetaSelectors` with new Phase-98 structural selectors.
- **D-98-14:** Redirect every "L1087" SPEC citation to "the corresponding template-string block in `admin-css-build.mjs` (the `@media (max-width:760px)` block, ~L946)".
- **D-98-15:** `md/760` owns SHELL sidebar switch; `lg/1024` owns CONTENT `:work + :aside` two-pane collapse. 760–1023px band = sidebar-shell + single-column `:work` + NO side `:aside`; detail via `:show` routes. Two distinct never-conflated `@media` blocks. Media queries, NOT container queries. Add CSS comment marking 760 shell-only / 1024 :aside-only.
- **D-98-16:** Keep full-list re-render (`load`/`load_list` + `:for`, refreshed on PubSub `{:rindle_event}`). Do NOT introduce `phx-update="stream"`. §B "Stream row insert/remove" is N/A. All other §B rows ship as locked.

### Claude's Discretion
Helper/function names, exact gallery panel grouping, fixture copy, assertion wording, the precise viewport literals inside each band (e.g. 759/761 vs other safe-inside values), the exact P2 split decision (single plan vs P2a/P2b), and the precise structure of new `admin-css-build.mjs` blocks — as long as the decisions above hold and work stays within UPLIFT-03..08.

### Deferred Ideas (OUT OF SCOPE)
- LiveView streams for admin lists (D-98-16; revisit only on unbounded/high-churn feed).
- Gate warn→fail flip + admin/Cohort gate generalization + pixel baselines → **Phase 102**.
- Cohort inner-page restyle → Track B (Phases 96/99).
- Any Cohort/Track-B surface, `cohort.css`, `cohort_components`, `cohort-screenshots.spec.js`; new `tokens.json` token values/schema.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UPLIFT-03 | Per-page composition pass | §A merge-gate → P1 scaffold (`page/1`) + two-pane grid CSS; gate clauses mapped below (Composition split ExUnit+Playwright) |
| UPLIFT-04 | Motion pass (reduced-motion-aware, sub-300ms, LiveView-coordinated) | §B merge-gate → CSS animated selectors + `JS.transition` idiom (verified below); Motion split ExUnit (property ⊆ {opacity,transform}, no `transition:all`) + Playwright (reduced-motion `0s`, duration token) |
| UPLIFT-05 | Mobile-first responsive | §C merge-gate → two-stop breakpoints (D-98-15); stacked-table `::before content:attr(data-label)` → Playwright computed `display`/`content` |
| UPLIFT-06 | Accessibility (keyboard/focus/ARIA/WCAG-AA both themes) | §D merge-gate → `focus_wrap` overlay (verified), `:focus-visible` tokens, live regions; split ExUnit (DOM structure via `render_to_string`, contrast) + Playwright (`:focus-visible`≠`:focus`, dialog inert) |
| UPLIFT-07 | gov.uk task-first IA | §E merge-gate → nav order/labels/hrefs, triage-home DOM order, deep-link params; primary ExUnit (`render_to_string` grep) |
| UPLIFT-08 | Operator/SRE microcopy | §F merge-gate → denylist (R4 hype / R5 vague), frozen lexicon, off-voice replacements; primary ExUnit over rendered markup |

## Validation Architecture

> **HIGHEST-PRIORITY SECTION.** This is the source for VALIDATION.md / the Nyquist strategy. Each of the six §A–§F gates is decomposed into clauses, each clause assigned its proving HOME (ExUnit static vs Playwright computed-style) using the D-98-05 decisive test. "Decisive test" column states WHY. ExUnit home = `test/brandbook/admin_design_system_validation_test.exs`. Playwright home = `examples/adoption_demo/e2e/support/admin-polish.js` (assertion functions) invoked per-state from `admin-screenshots.spec.js`.

### Test Framework
| Property | Value |
|----------|-------|
| Static/source/token framework | ExUnit (`@moduletag :integration`), shells out to `node <script>` via `run_node/1`; drift via `assert_generated_clean/1` (`git diff --exit-code`) |
| Computed-style framework | Playwright (`@playwright/test`), in-browser `page.evaluate` returning offenders, aggregated by `assertAdminPolish` (throws once per state) |
| ExUnit config | `test/brandbook/admin_design_system_validation_test.exs` (existing; 292 lines) |
| Playwright config | `examples/adoption_demo/e2e/` lane (`adoption-demo-e2e`, already merge-blocking) |
| ExUnit quick run | `mix test test/brandbook/admin_design_system_validation_test.exs` |
| Playwright run | the `adoption-demo-e2e` CI lane (existing) |

### §A Composition gate — SPLIT (D-98-05)

| Clause | Home | Decisive test (why) |
|--------|------|---------------------|
| Scaffold exposes canonical slot order in DOM order | ExUnit (`render_to_string` grep / order check) | Static DOM structure; no cascade needed |
| `:work` required (compile error if absent) | ExUnit (compile-time `slot :work, required: true`) | Compiler enforces; assert a missing-slot test raises |
| `:summary` computed `background` = `--rindle-surface-raised`, `border-radius` = 20px, `box-shadow` = card token | **Playwright** | Token must RESOLVE to a value per theme — `getComputedStyle` (and §A hierarchy could silently pass on wrong shadow without D-98-13 guard-1) |
| `:work` table `border-radius` = 14px | **Playwright** | Computed value resolution |
| Two-pane `grid-template-columns` = two tracks ≥1024px, one track below | **Playwright** | Requires the `min-width:1024` media query to actually FIRE (the broken-`@media`-ships-green footgun) |
| No surface declares page-local `display:grid` outside scaffold selector | ExUnit (source scan over the six `*_live.ex` + generated CSS) | Static source/CSS-text substring check |
| `--rindle-shadow-card` is consumed (guard) | ExUnit (`requiredTokenUses` self-check, D-98-13) | Build-time fail-closed; static |

### §B Motion gate — SPLIT (D-98-05)

| Clause | Home | Decisive test (why) |
|--------|------|---------------------|
| Every animated selector `transition-property` ⊆ {opacity, transform} | ExUnit (CSS-text scan; reject width/height/top/left/margin/color/background-color) | Static text — properties are literal in the generated CSS |
| NO `transition: all` anywhere (esp. patch/stream regions) | ExUnit (substring `transition:all` / `transition: all`) | Static text scan (current audit: none present — keep it) |
| Reduced-motion: `transitionDuration === "0s"` under emulated `prefers-reduced-motion: reduce` | **Playwright** | Requires the `@media (prefers-reduced-motion)` to actually fire under emulation |
| No-preference: `transitionDuration` equals token duration (e.g. `0.2s` toast) | **Playwright** | Requires computed resolution of the token var to a concrete `s` value |
| Button press `:active translateY(1px)`, popover/toast/drawer durations | ExUnit (selector + `var(--rindle-motion-*)` presence) for authoring; Playwright for resolved value | Authoring is static; resolved duration is cascade |

### §C Responsive gate — Playwright-dominant (D-98-05)

| Clause | Home | Decisive test (why) |
|--------|------|---------------------|
| `<table>`/`<tr>`/`<td>` computed `display` = `block` at <760, `table`/`table-row`/`table-cell` at ≥760 | **Playwright** (viewport flip at 759/761) | Media query must fire; computed `display` |
| `<td>::before content` resolves to `data-label` at <760, empty at ≥760 | **Playwright** | `::before content:attr(data-label)` must COMPUTE — only the browser resolves `attr()` |
| Shell `grid-template-columns` single track <760, two tracks ≥760 | **Playwright** (759/761) | Distinct stop from §A's 1024; media query must fire |
| Disclosure button computed min-height/min-width ≥ 44px and carries `aria-expanded` | **Playwright** (size) + ExUnit (`aria-expanded` presence) | Size is computed; attribute presence is static |
| `.rindle-admin-table--sticky` retains `overflow-x: auto` at all widths | **Playwright** | Computed at multiple viewports |
| No State/Job column has `display:none` at any breakpoint | **Playwright** (negative across viewports) + ExUnit (no `display:none` on column selectors in CSS source) | Cascade negative; back-stopped by static scan |
| §A↔§C 760–1023px band: shell sidebar + single-col work + NO side `:aside` | **Playwright** (assert at safe-inside literal, e.g. 900px) | Reconciliation requires BOTH media states resolved (checker note 2; D-98-15) — this is the held-out band backstop |

### §D A11y gate — SPLIT (D-98-05, D-98-06)

| Clause | Home | Decisive test (why) |
|--------|------|---------------------|
| Every `contrast_pairs` ratio ≥ min in BOTH themes (text 4.5 / non-text 3.0) | ExUnit **only** (`admin-contrast.mjs`, 58/58, full-float) | Source token hexes; do NOT re-derive in 8-bit browser `rgb()` (weaker/flaky) — D-98-06 |
| `assertReadableContrast` (live effective-background compositing) | **Playwright** (keep — different theorem, NOT a duplicate) | Composites layered/transparent backgrounds at runtime |
| `:focus-visible` outline = `2px solid` + `outline-offset: 2px`, ring color matches `--rindle-focus-ring` per theme | **Playwright** (`assertFocusVisibleTokens` extend) | Keyboard `:focus-visible` ≠ pointer `:focus` — only runtime focus distinguishes |
| Mouse-click focus yields NO ring | **Playwright** (negative; pointer focus) | `:focus-visible` vs `:focus` runtime differentiation |
| skip-link is first focusable child → `#rindle-admin-main`; `<main>` has `id` + `tabindex="-1"` | ExUnit (`render_to_string` grep / DOM order) | Static server markup |
| data `<table>` has `<caption>` + `<th scope>` | ExUnit (`render_to_string` grep) | Static markup |
| `live_indicator` has `role="status"` + NO `tabindex` | ExUnit (`render_to_string` grep + negative) | Static markup |
| `theme_picker` `aria-pressed` present in **server-rendered (dead) markup** | ExUnit **only** (`render_to_string` grep) | A live read can't distinguish server-rendered from JS-set — that's the whole point of the fix (D-98-06) |
| Open dialog sets `inert` + `aria-hidden` on `main`+`nav`; has `role="dialog"`/`alertdialog` + `aria-modal` + `aria-labelledby` | **Playwright** (dialog-open DOM mutation) | Requires the open event + DOM mutation to fire; assert post-open state |
| Dialog `inert` resets on close AND survives reconnect | **Playwright** (open→close, and dead-render simulation) | Runtime lifecycle; the D-98-11 critical landmine |

### §E IA gate — ExUnit-primary (D-98-05)

| Clause | Home | Decisive test (why) |
|--------|------|---------------------|
| Nav renders exactly six items in order [Overview, Assets, Upload sessions, Processing, Doctor, Maintenance] with relabeled text + correct hrefs | ExUnit (`render_to_string` grep, ordered) | Static server markup |
| No item literally named "Actions"/"Home/Status"/"Variants/Jobs"/"Runtime/Doctor" | ExUnit (negative substring scan) | Static |
| Overview DOM order = needs-attention → system-health chips → recent activity → vanity totals last | ExUnit (`render_to_string` order check) | Static server render off `Queries.home_status/1` |
| Each needs-attention entry is `<a href>` carrying documented query param (`state=failed` etc.) | ExUnit (`render_to_string` grep) | Static hrefs (deep-links are pure `<a>`, D-98-10) |
| Overview all-clear renders affirmative copy, not generic filtered-no-match empty state | ExUnit (`render_to_string` grep on a healthy fixture) | Static markup on a fixture state |

### §F Microcopy gate — ExUnit-primary (D-98-06)

| Clause | Home | Decisive test (why) |
|--------|------|---------------------|
| Denylist scan finds ZERO R4 hype words + ZERO R5 vague standalone labels | ExUnit **primary** over rendered admin markup | Static rendered content; Playwright mirror only if dynamic/interpolated copy exists |
| Every status chip label ∈ frozen lexicon for its domain | ExUnit (`render_to_string` over fixture rows) | Static label set |
| Action labels ≤4 words | ExUnit (word-count over rendered labels) | Static |
| No "!" in any confirmation/destructive body | ExUnit (negative substring over confirm copy) | Static |
| Six off-voice strings no longer appear in source; replacements do | ExUnit (negative + positive substring over source) | Static source scan |
| Confirmation headings match `"{Verb} this {noun}?"` shape | ExUnit (regex over rendered headings) | Static |

### Net-new Playwright states (bump `toHaveLength(22)` deliberately)
Per D-98-06, new e2e states must be added explicitly and the literal bumped (as 97-04 bumped 10→18). Anticipated additions: responsive `display` flip at 759/761 + 1023/1025 (safe-inside-band literals), `:focus-visible`-vs-pointer negative, dialog-open `inert`, two-pane track count, nav order, deep-link hrefs, reduced-motion read taken **un-frozen** (note: `freezeMotion` would mask the reduced-motion assertion — that one check must run BEFORE/without the freeze, or read the media-emulated `transitionDuration` directly). The exact new count is planner discretion; whatever states are added, update `expectedScreenshots` and `toHaveLength(N)` in lockstep.

### Held-out / backstop assertions (NOT inferable from static/property tests)
1. **Two-pane track count + 760–1023px band reconciliation** (§A↔§C) — only a real viewport at a safe-inside literal proves the band wires identically in scaffold CSS and the responsive media layer (checker note 2).
2. **`::before content:attr(data-label)`** — `attr()` resolution is browser-only; a CSS-text scan that the rule exists ships green even in a broken `@media`.
3. **Reduced-motion `0s`** — requires emulated preference + computed read.
4. **Dialog-open `inert`/`aria-hidden` + reset-on-reconnect** — requires the open event and a simulated dead-render.
5. **`:focus-visible` ≠ pointer `:focus`** — runtime focus-source differentiation.

### Sampling rate
- **Per task commit (P1–P3):** `mix test test/brandbook/admin_design_system_validation_test.exs` (static gates + drift) — fast, runs the `node` generators + `git diff --exit-code`.
- **Per surface migration (P2):** the per-surface atomic commit must keep ExUnit green; the Playwright lane confirms no computed-style regression for that surface.
- **Phase gate (P4):** full `adoption-demo-e2e` lane green (all 22+ states) + full ExUnit before `/gsd-verify-work`.

### Wave 0 gaps
- None for infrastructure: both test homes exist and are merge-blocking today. The "gaps" are the net-new clauses themselves, owned by P4 (D-98-04) — the planner should enumerate each clause above as a P4 assertion task, and ensure P1–P3 author the markup/CSS each clause reads.

## Implementation Knowledge the Planner Needs

### `Phoenix.Component.focus_wrap/1` (LiveView 1.1.30) — overlay primitive (D-98-11)
`[VERIFIED: phoenix-live-view.hexdocs.pm Phoenix.Component]`
- Requires `id` (`:string`); one required `inner_block` slot; "wraps tab focus around a container" — traps Tab/Shift-Tab, "essential for modals, dialogs, and menus." Canonical example:
  ```heex
  <.focus_wrap id="my-modal" class="bg-white">
    <div id="modal-content">
      Are you sure?
      <button phx-click="cancel">Cancel</button>
      <button phx-click="confirm">OK</button>
    </div>
  </.focus_wrap>
  ```
- **Use the built-in focus stack, not a hand-stashed trigger id.** LiveView 1.1 provides `JS.push_focus/1` ("stores current element focus for later restoration") and `JS.pop_focus/1` ("focuses the last pushed element") `[VERIFIED: Phoenix.LiveView.JS]`. The open command should `JS.push_focus()` then `JS.focus_first(to: "#dialog")`; the close command should `JS.pop_focus()`. This is more robust than threading a trigger id through assigns and satisfies the "return-focus to stashed trigger" requirement idiomatically. (CONTEXT says "stashed trigger id" — `push_focus`/`pop_focus` IS the framework's stashing mechanism; planner may use it.)
- A programmatically-focused dialog container may not trigger `:focus-visible` → §D requires giving the dialog a **permanent visible border / `:focus` ring** (authored in CSS), not relying on `:focus-visible`.

### `JS.transition/2` 3-tuple + `phx-mounted`/`phx-remove` (§B motion)
`[VERIFIED: Phoenix.LiveView.JS]`
- 3-tuple form: `{transition_class, start_class, end_class}`, e.g. `{"ease-out duration-300", "opacity-0", "opacity-100"}`. `:time` option (default 200ms) — **must equal the CSS duration token** ("duration-300 ms matches time: 300 ms"). For Phase 98 the `:time` must be set to the token value (toast 200ms, popover 160ms, transition 300ms) so LiveView holds the node exactly as long as the CSS animates it.
- Enter via `phx-mounted={JS.transition(...)}`, leave via `phx-remove={JS.transition(...)}` — LiveView holds the removing node for `:time` ms so the leave animation completes before DOM removal.
- Menus/popovers/theme-picker use `JS.toggle` (node stays mounted, no round-trip) — `:in`/`:out` 3-tuples + `:time`.
- **Reduced-motion interaction:** the CSS `@media (prefers-reduced-motion: reduce)` block collapses `transition-duration` to `0ms`, but `JS.transition`'s `:time` still holds the node that long server-side. With `:time: 200`, a reduced-motion user still waits 200ms with no visible animation. This is acceptable (instant-looking) and matches D-98-16's "collapse to instant, keep no fade." Do not try to branch `:time` on the media query — keep it simple.

### Server-owned `aria-pressed` theme threading (D-98-07)
- Today `theme_picker/1` hard-codes `aria-pressed="false"`/`"true"` and `select_theme/1` flips them via `JS.set_attribute` (client-only — desyncs on dead-render/reconnect). Fix: the shell must learn the current theme at mount (session value or connect param) and pass it down; `theme_picker` renders `aria-pressed={@theme == "light"}` etc. server-side. Keep `JS.set_attribute` as progressive enhancement only. **This is a real wiring task** (shell mount → assign → component attr), not a render tweak — plan it explicitly in P2 (a11y primitives).
- The ExUnit assertion reads `render_to_string` (dead markup) — proving the server emits the correct `aria-pressed`, which a live browser read cannot distinguish from a JS-set value (D-98-06).

### Stacked-table `::before content:attr(data-label)` transform (§C)
- Today surfaces hand-roll `<thead><th scope="col">…` + `<td class="rindle-admin-table__cell">{value}` (see `assets_live.ex:109-125`). For the stacked-card transform: each `<td>` gains `data-label="State"` (etc.); CSS at <760 flips `table`/`tr`/`td` to `display:block` and emits `td::before { content: attr(data-label); }` so each row reads as a `metadata_list`-shaped card. **No markup fork, no priority-column hiding** — the SAME `scope`/`data-label` markup drives both the desktop table and the stacked card (D-98-08). The `data-label` is authored on the `<td>` in the surface markup (migrated in P2); the `::before` rule is authored in `admin-css-build.mjs` (P1). Exception: `.rindle-admin-table--sticky` keeps `overflow-x:auto` for wide numeric matrices.

### `:focus-visible` token wiring (§D)
- `:focus-visible` selectors already exist in `requiredSelectors` (`.rindle-admin-button:focus-visible`, nav, tab, theme-picker option, inputs, submit, action, detail-link — see ~L1011–1023). The base `:focus-visible` rule emits `outline: var(--rindle-focus-width) solid var(--rindle-focus-ring); outline-offset: var(--rindle-focus-offset)` (~L939-941). Phase 98 must ensure any NEW interactive selectors (disclosure button, sort-th control, stacked-row tap target) get added to this focus-visible set AND to `DEFAULT_INTERACTIVE_SELECTORS` in `admin-polish.js` so `assertFocusVisibleTokens` covers them. `--rindle-focus-ring` resolves per theme (light deep-current 11.34:1, dark rindle-green 9.38:1).

### `inert` + `aria-hidden` reset-on-reconnect (D-98-11 critical)
- `aria-modal` alone does not stop sighted keyboard tabbing into background — both `inert` AND `aria-hidden` are toggled on `main`+`nav` while a dialog is open. **The landmine:** if a LiveView dead-render/reconnect occurs while a dialog is open (or if close fails), `main` can be left `inert` — the entire console becomes non-interactive. Mitigation options for the planner: (a) make the inert state server-owned (assign-driven, so a re-render restores correct state), or (b) add a `phx-mounted`/reconnect hook that clears stale inert. The Playwright gate must assert inert resets on close AND simulate a reconnect with the dialog closed to prove `main` is not left inert.

## Common Pitfalls

### Pitfall 1: Broken `@media` block ships GREEN
**What goes wrong:** `css =~ "display:block"` passes even when the rule sits in a `@media` that never resolves at the asserted viewport. **Why:** static substring tests can't fire a media query. **Avoid:** every viewport-conditional / theme-conditional / interaction-conditional clause MUST be a Playwright computed-style assertion at the real viewport/theme/focus-state (see Validation Architecture). **Warning sign:** a §C/§A/§B conditional clause with only an ExUnit substring test.

### Pitfall 2: Drift-gate thrash from split CSS plans
**What goes wrong:** two plans both editing `admin-css-build.mjs` (e.g. "motion CSS" + "a11y CSS") regenerate the single file and collide on the byte-identical drift gate. **Why:** one generator → one output file → `git diff --exit-code`. **Avoid:** all generated-CSS lands in P1 (D-98-01) — already mitigated; the execution-order trap is if a later plan (P2/P3) sneaks a CSS selector edit. Keep P2/P3 to markup/wiring only; if a selector is genuinely missing, it's a P1 defect to fix in P1's scope, not a new CSS edit downstream.

### Pitfall 3: Hand-editing the generated/shipped CSS
**What goes wrong:** the SPEC cites `priv/static/.../rindle-admin.css` L1087 ~6× — tempting to edit the generated file. **Why:** both `rindle-admin.css` files are generated; hand-edits fail DS-01 (regenerate diff) or ADMIN-02 (byte-equality). **Avoid:** D-98-14 — every "L1087" task redirects to "the `@media (max-width:760px)` template-string block in `admin-css-build.mjs`, ~L946." NEVER edit either CSS file.

### Pitfall 4: Non-atomic surface migration
**What goes wrong:** migrating a surface onto `page/1` half-way leaves it broken (gov.uk "never half-broken" lesson). **Why:** the `:work`-required slot + scaffold state-rendering means a partial migration may not compile or renders wrong. **Avoid:** D-98-02 — one atomic commit per surface; each surface's behavior e2e must stay green (VIS-02). Use the P2a/P2b relief valve if a single plan is too heavy.

### Pitfall 5: `home_status_live.ex` vs `home_live.ex` filename
**What goes wrong:** §E names `home_status_live.ex`; the real file is `lib/rindle/admin/live/home_live.ex`. **Avoid:** every IA/triage-home task targets `home_live.ex`. The `inspect/1` anti-pattern is at `home_live.ex:56` (`{inspect(recommendation)}`) — replace with the structured GDS task-list.

### Pitfall 6: `freezeMotion` masks the reduced-motion assertion
**What goes wrong:** `admin-polish.js`'s `freezeMotion` injects `transition:none !important` — if the reduced-motion `transitionDuration === "0s"` check runs after the freeze, it passes vacuously (everything is `none`). **Avoid:** the reduced-motion + no-preference duration assertions must read computed `transitionDuration` under emulated `prefers-reduced-motion` WITHOUT the freeze applied (or before it), or use Playwright's `emulateMedia({ reducedMotion })` and read directly. Plan this check as separate from the frozen-state polish run.

### Pitfall 7: 8-bit browser contrast re-derivation
**What goes wrong:** re-asserting `contrast_pairs` ratios in Playwright (`rgb()` is 8-bit) is weaker and flakier than the source-hex full-float gate. **Avoid:** D-98-06 — token-pair contrast stays ExUnit-only (`admin-contrast.mjs`, 58/58). `assertReadableContrast` in Playwright is a DIFFERENT theorem (live effective-background compositing) — keep it, it is not a duplicate.

### Pitfall 8: §A↔§C 760–1023px band contradiction (apparent, not real)
**What goes wrong:** §A says `:work + :aside` collapses below 1024; §C says shell switches at 760 — looks contradictory. **Resolution (D-98-15):** different selectors at different stops — shell rule (`minmax(220px,260px) minmax(0,1fr)`) lives ONLY in `min-width:760`; `:aside` two-pane rule (`minmax(0,1fr) minmax(320px,380px)`) lives ONLY in `min-width:1024`. In the 760–1023 band: sidebar-shell + single-column work + NO side `:aside`, detail via `:show` routes (incl new `variants-jobs/:id`). Author as two never-conflated `@media` blocks with a CSS comment marking each. P4 asserts the band at a safe-inside literal (e.g. 900px).

### Pitfall 9: `toHaveLength(22)` drift
**What goes wrong:** adding e2e states without bumping the literal fails the spec; bumping without adding states hides missing coverage. **Avoid:** D-98-06 — bump `expectedScreenshots` and `toHaveLength(N)` in lockstep, deliberately, in P4.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hand-rolled keydown focus trap | `Phoenix.Component.focus_wrap` | LV ≥0.18 | Use the component; do NOT hand-roll (D-98-11) |
| Hand-stash trigger id in assigns for return-focus | `JS.push_focus`/`JS.pop_focus` focus stack | LV 1.x | Framework-native focus restoration |
| `aria-hidden` only for modal background | `inert` + `aria-hidden` | `inert` baseline ~2023 | `aria-modal` alone doesn't block sighted keyboard tabbing |
| LiveView streams for all dynamic lists | Full re-render kept for bounded operator lists | this phase (D-98-16) | Streams import the `transition:all`/`phx-patch` footgun for no gain on bounded lists |

**Deprecated/outdated:** none affecting this phase. LiveView is pinned `~> 1.0` resolving to **1.1.30** `[VERIFIED: mix.lock]`; all cited APIs (`focus_wrap`, `JS.transition` 3-tuple, `JS.push_focus`/`pop_focus`, `JS.focus_first`) are present in 1.1.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `JS.push_focus`/`JS.pop_focus` satisfies the D-98-11 "return-focus to stashed trigger id" requirement idiomatically | Implementation Knowledge | LOW — verified present in LV 1.1; if maintainer prefers explicit id-stashing, both work; planner picks |
| A2 | Setting `JS.transition :time` equal to the token duration is acceptable under reduced-motion (node held 200ms but no visible animation) | Implementation Knowledge | LOW — matches D-98-16 "collapse to instant"; alternative is branching `:time` which CONTEXT discourages |
| A3 | The reduced-motion duration assertion must run un-frozen (D-98-06 already flags "reduced-motion read taken un-frozen") | Validation Architecture / Pitfall 6 | LOW — CONTEXT independently calls this out; this RESEARCH just names the `freezeMotion` mechanism |

**Note:** No `[ASSUMED]` package claims — this phase installs zero new packages (D-98-12: no `tokens.json` change, self-contained CSS, existing LiveView optional dep). Package Legitimacy Audit is therefore N/A.

## Project Constraints (from AGENTS.md / requirements)
- Self-contained admin assets: NO Tailwind, daisyUI, shadcn, Radix, esbuild, `@apply`, `.dark`/`theme-dark` classes, or host asset-pipeline dependency in admin code (enforced by the ADMIN-02 `forbidden` regex over `@implementation_files` in the ExUnit gate).
- Generated CSS is never hand-edited (DS-01 / D-94 / D-97 / D-98-12).
- Status must pair color with label (frozen lexicon) — color-only is banned.
- Motion is purposeful + reduced-motion-aware only; no animate-everything.
- No new console lifecycle semantics / write paths beyond v1.18 surface — v1.19 is DS quality only.

## Open Questions

1. **Exact net-new Playwright state count for the `toHaveLength` bump.**
   - What we know: D-98-06 enumerates the new sub-assertions; the literal must be bumped deliberately.
   - What's unclear: whether each new assertion needs a NEW screenshot state or rides existing surface/theme/viewport captures.
   - Recommendation: planner counts the distinct net-new viewport/theme/interaction states in P4 and bumps `expectedScreenshots` + `toHaveLength(N)` in lockstep; many checks (focus-visible, dialog-open) can ride existing captures rather than adding states.

2. **inert reset-on-reconnect mechanism: server-owned assign vs reconnect hook.**
   - What we know: the inert state must survive a dead-render (D-98-11 critical).
   - What's unclear: whether the maintainer prefers server-assign-driven inert (simplest, re-render restores) or a JS reconnect hook.
   - Recommendation: prefer server-assign-driven (open/close is already a LiveView event; render inert from assign) so reconnect re-renders correct state with no extra JS. Playwright proves it.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| node | `run_node/1` generators (build/contrast/gallery) | ✓ (CI + ExUnit `System.find_executable("node")`) | — | none (gate flunks without it — by design) |
| Playwright / `@playwright/test` | `adoption-demo-e2e` computed-style lane | ✓ (existing lane) | — | none |
| phoenix_live_view | admin surfaces (optional dep) | ✓ | 1.1.30 | console compiles away when absent (ADMIN-06) — but this phase requires it |

**No new external dependencies introduced this phase.**

## Sources

### Primary (HIGH confidence)
- `lib/rindle/admin/components.ex` (read) — `shell`/`theme_picker`/`live_indicator`/`table`/`empty_state`/`error_state`/`select_theme` current state; `page/1` absent.
- `lib/rindle/admin/live/*_live.ex` (grep) — surfaces under `live/`; `home_live.ex:56` `inspect/1`; `assets_live.ex:109-125` table markup (has `scope="col"`, no caption/`scope="row"`); `variants_jobs_live.ex:107` borrows `assets/:id`.
- `test/brandbook/admin_design_system_validation_test.exs` (read, 292 lines) — DS-01/DS-02/DS-03/ADMIN-02; `run_node/1`, `assert_generated_clean/1`, `@implementation_files`, `forbidden` regex, byte-equality assertion.
- `examples/adoption_demo/e2e/support/admin-polish.js` (read, 641 lines) — 8 sub-assertions, `freezeMotion`, `DEFAULT_ROOT`/`DEFAULT_INTERACTIVE_SELECTORS`, `assertFocusVisibleTokens`, `assertReadableContrast`, `OVERLAP_ENFORCED`.
- `examples/adoption_demo/e2e/admin-screenshots.spec.js` (read) — `expectedScreenshots` (22) + `toHaveLength(22)`, 1480×900 desktop / 390×900 mobile, `capture` flow.
- `brandbook/src/admin-css-build.mjs` (grep) — `@media (max-width: 760px)` ~L946, reduced-motion ~L970, `requiredSelectors`/`requiredMetaSelectors`/`requiredTokenUses` ~L989-1060 (`--rindle-shadow-card` absent from token uses — D-98-13 guard-1 confirmed).
- `mix.lock` — `phoenix_live_view` `1.1.30` `[VERIFIED]`.
- `98-CONTEXT.md`, `98-UI-SPEC.md` (read in full) — locked decisions + six merge-gate blocks.

### Secondary (MEDIUM confidence)
- `phoenix-live-view.hexdocs.pm/Phoenix.Component.html` — `focus_wrap/1` signature, slot, example `[CITED]`.
- `phoenix-live-view.hexdocs.pm/Phoenix.LiveView.JS.html` — `JS.transition` 3-tuple + `:time`, `JS.toggle`/`show`/`hide`, `JS.focus`/`focus_first`/`push_focus`/`pop_focus`, `JS.set_attribute`, `JS.add_class` `[CITED]`.

## Metadata

**Confidence breakdown:**
- Validation Architecture: HIGH — grounded in the actual two test homes (read in full); split rule applied per-clause from D-98-05.
- Implementation idioms: HIGH — `focus_wrap`/`JS` API verified against official LV docs at the pinned 1.1 version.
- Pitfalls: HIGH — derived from real code positions (L946, L56, L1046, `freezeMotion`) + locked CONTEXT decisions.

**Research date:** 2026-06-18
**Valid until:** 2026-07-18 (stable; LiveView API and locked artifacts are fixed inputs)
