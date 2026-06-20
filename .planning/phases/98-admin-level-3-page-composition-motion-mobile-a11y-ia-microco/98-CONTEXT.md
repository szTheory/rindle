# Phase 98: Admin Level-3 Page Composition + Motion / Mobile / A11y / IA / Microcopy - Context

**Gathered:** 2026-06-17 (assumptions mode + parallel deep research)
**Status:** Ready for planning

<domain>
## Phase Boundary

Track A of milestone v1.19 (SEED-002). Carries **UPLIFT-03 … UPLIFT-08**. Assemble every
mountable LiveView admin surface (Overview · Assets · Upload sessions · Processing · Doctor ·
Maintenance) from Level-1/Level-2 primitives ONLY into award-bar **pages** — adding purposeful
reduced-motion-aware sub-300ms LiveView-coordinated motion, mobile-first responsive at all
breakpoints, keyboard/focus/ARIA/WCAG-AA-both-themes accessibility, gov.uk/GDS task-first IA,
and operator/SRE-voice microcopy per surface JTBD.

**The visual/interaction contract is already LOCKED** in `98-UI-SPEC.md` (approved 6/6
dimensions, all UPLIFT-03..08 with assertable merge-gates). This CONTEXT adds the
**implementation** decisions on top of that contract — decomposition, gate homes, build
boundary, idiom — validated by six parallel research passes (architecture/SWE + a11y +
gov.uk-IA + design-token-pipeline + responsive-UX + LiveView-motion lenses).

**Out of scope (do NOT touch):** any Cohort/Track-B surface, `cohort.css`, `cohort_components`,
`cohort-screenshots.spec.js`; the warn→fail gate flip and admin+Cohort gate generalization
(those are **Phase 102**, not this phase and not Phase 99); new `tokens.json` token
values/schema; introducing LiveView streams.
</domain>

<decisions>
## Implementation Decisions

### Plan Decomposition (4 plans, strict dependency chain — NOT 5, NOT vertical slices)

The single generated-CSS file + byte-identical drift gate **forbids** parallel "motion CSS" and
"a11y CSS" plans (they edit one generator → drift-gate thrash). The cross-surface/whole-console
nature of the IA, Composition, and Microcopy merge-gates **forbids** per-surface vertical slices.
Decomposition is over-determined; mirrors the proven Phase-97 wave-chain + gov.uk "one template
at a time" + LiveDashboard `PageBuilder` precedent.

- **D-98-01 (P1 — Scaffold + generated-CSS spine, `depends_on: []`):** Author the Level-3
  `page/1` scaffold in `lib/rindle/admin/components.ex` (slots `:summary/:filters/:work(required)/
  :aside/:actions` + `attr :state :ok|:empty|:error|:loading`), AND in the **same plan** land all
  generated-CSS for motion (§B), the mobile-first responsive conversion (§C), the two-pane grid
  (§A), and `:focus-visible`/focus-ring (§D) — all authored through `admin-css-build.mjs` and run
  through the build → contrast → gallery-check → `sync-admin-css.mjs` → byte-identical drift gate.
  Ends green with `page/1` existing but unused; console still renders on old markup.
- **D-98-02 (P2 — A11y primitives + six-surface migration, `depends_on: [P1]`):** Fix the §D
  primitive a11y bugs that live in `components.ex` (centralized — see D-98-07), then migrate each
  of the six `*_live.ex` surfaces from hand-rolled `<table>`/`<section>` markup onto `page/1` as
  **one atomic commit per surface** (gov.uk lesson: never half-broken). The `<table>`
  caption/`<thead>`/`scope` fix rides this migration (see D-98-08). Relief valve: if P2 is too
  heavy, split into P2a (a11y primitives in `components.ex`) → P2b (six migrations) as sequential
  sub-waves, keeping migrations atomic-per-surface.
- **D-98-03 (P3 — IA + routing + microcopy, `depends_on: [P2]`):** Nav relabel/reorder
  (`@surfaces` attr), Overview triage-home rebuild (`home_live.ex`), deep-link query params,
  "Actions"→Maintenance distribution, the new `variants-jobs/:id` route (D-98-09), AND the §F
  microcopy replacements — merged because IA and microcopy are atomic content/label edits to the
  same surfaces now on the scaffold (the IA gate demands all six nav items change together).
- **D-98-04 (P4 — Gate close-out, `depends_on: [P3]`, `autonomous: false`):** Extend both test
  homes to assert all six §A–§F merge-gates over the real surfaces; run the full pipeline green;
  reconcile/assert the §A↔§C 760–1023px two-pane band (checker note 2). Mirrors Phase-97 P4.

### Merge-Gate Test Homes (the split line = "does proving it need the cascade to resolve?")

The split is NOT "static vs live." It is: a static substring / token-presence / regenerate-diff
check that **fully** proves it → ExUnit; proving it requires a media query to actually fire, a
theme to apply, `:focus-visible`-vs-`:focus` to differ, `::before content:attr()` to compute, or
a dialog-open DOM mutation → Playwright. The decisive footgun: `css =~ "display:block"` ships
GREEN even when that rule sits in a broken `@media` block that never resolves.

- **D-98-05 (homes):** Static CSS-text/token/source-scan clauses → extend
  `test/brandbook/admin_design_system_validation_test.exs` (substring + `run_node` generators +
  `assert_generated_clean`). Cascade/viewport/theme/interaction-conditional clauses → extend
  `examples/adoption_demo/e2e/support/admin-polish.js` (reads `getComputedStyle` across the
  surface/theme/viewport states). **Composition and Motion are PARTIALLY split**: their
  unconditional clauses (radius/background token values, `transition-property ⊆ {opacity,
  transform}`, "no `transition:all`", "no page-local `display:grid` outside scaffold") → ExUnit;
  their conditional clauses (two-pane `grid-template-columns` track-count at a viewport;
  reduced-motion `0s` vs token duration under emulated preference) → Playwright.
- **D-98-06 (no-duplication + scope guards):**
  - Contrast stays **ExUnit-only** (`admin-contrast.mjs`, 58/58 over source token hexes — full
    float precision). Do NOT re-derive in the browser (8-bit `rgb()` is weaker + flaky).
    `assertReadableContrast` in admin-polish is a *different* theorem (live effective-background
    compositing) — keep it, it's not a duplicate.
  - `theme_picker aria-pressed` is asserted in **dead/server-rendered markup** (`render_to_string`
    grep in ExUnit) — a live read can't distinguish server-rendered from JS-set, which is the
    whole point of the fix.
  - New Playwright sub-assertions (responsive `display` flip at 759/761 + 1023/1025 safe-inside-
    band literals, `:focus-visible`-vs-pointer negative, dialog-open `inert`, two-pane track
    count, nav order, deep-link hrefs, reduced-motion read taken **un-frozen**) add net-new e2e
    states → the `toHaveLength(22)` literal in `admin-screenshots.spec.js` must be bumped
    **deliberately** (as 97-04 bumped 10→18). Microcopy denylist runs **primary in ExUnit over
    rendered markup**, mirrored in Playwright only if dynamic/interpolated copy exists.
  - All new admin-polish.js checks land as **already-HARD admin-root-only** assertions (the admin
    lane is red-on-fail today). Build them against the default `[data-rindle-admin-root]` seam so
    the Phase-102 `{root, interactiveSelectors}` generalization stays intact. Do NOT generalize
    over Cohort or flip warn→fail here — that is Phase 102.

### Accessibility & IA Implementation Shape

- **D-98-07 (centralized §D primitive fixes — single-touch in `components.ex`):** theme_picker
  server-owned `aria-pressed` (keep `JS.set_attribute` as progressive enhancement only),
  `live_indicator` → drop dead `tabindex="0"`, add `role="status"`/`aria-live="polite"`/
  `aria-atomic`, skip-link as first focusable child + `<main id="rindle-admin-main" tabindex="-1">`,
  persistent ASSERTIVE `role="alert"` region in `shell` (empty at mount), `error_state` →
  `role="alert"`. **Server theme assign:** making `aria-pressed` server-authoritative requires the
  shell to learn the current theme (session/connect param) — a small real wiring task, not a pure
  render tweak; plan for it.
- **D-98-08 (table caption/scope is a SPREAD, rides the scaffold migration):** the `table/1`
  primitive is a bare `<table>` wrapper; all six surfaces hand-roll their own table markup (+
  `assets` `detail_table/1`). `<th scope="col">` exist but NO `<caption>` and no `scope="row"`.
  Land caption/`<thead>`/`scope` **when each table migrates into the `:work` slot** (D-98-02), and
  have §C's responsive stacked-card transform drive off the **same** `scope`/`data-label` markup.
  Do NOT do a standalone caption-only pass.
- **D-98-09 (Processing detail route — option A, LOCKED by maintainer):** Add a dedicated
  `variants-jobs/:id` `:show` route + `handle_params(%{"id"=>id})` + a new `Queries` run-detail
  function + a one-run detail render ("the thing" = one run's `error_reason`/attempt/worker + its
  single primary action), with redaction parity matching the Assets/Upload detail pattern. This
  satisfies §A's "dedicated detail route below md" and §E tier-2 for Processing, and the
  760–1023px band's reliance on a real detail route. (Today the variant "View details" link
  borrows `assets/:id` — replace it.)
- **D-98-10 (deep-links + other detail reuse existing routes):** All §E "needs attention"
  deep-links map to **already-parsed** `handle_params` filters — `variants-jobs?state=failed`,
  `assets?state=quarantined`, `upload-sessions?state=expired`, `?class=stale` (normalized) — pure
  `<a href>` from the triage home, NO new routes/handler changes. Assets + Upload-sessions detail
  reuse existing `:show` routes. Triage-home rebuild is render-only in `home_live.ex` off
  `Queries.home_status/1` (already returns recommendations + counts); replace the
  `inspect/1` anti-pattern. "Actions" verb-bucket distributes onto contextual rows (regenerate→
  Processing stale-row, release/quarantine→asset detail, reconcile→Doctor); Maintenance keeps only
  contextless cross-cutting ops (owner/batch erasure).
- **D-98-11 (overlay confirm contract — shared chrome, per-surface wiring):** Introduce a new
  shared `components.ex` overlay primitive (`modal/1`/`confirm_dialog/1`) using
  `Phoenix.Component.focus_wrap` (NOT a hand-rolled keydown trap) + `role="dialog"`/`alertdialog`
  + `aria-modal` + `aria-labelledby` + ESC via `phx-window-keydown phx-key="escape"` +
  return-focus to stashed trigger id + `inert` AND `aria-hidden` on `main`+`nav` while open. Each
  surface with a confirm/destructive flow wires its trigger id, open/close events, and the inert
  toggle. **Critical:** the inert/aria-hidden toggle must reset on close AND survive LiveView
  reconnect (never leave `main` inert after a dead-render).

### Build-Pipeline Boundary (CONFIRMED — generated-CSS-only, no `tokens.json` change)

- **D-98-12 (authoring + drift gate):** EVERY new selector (scaffold grid, two-pane region,
  motion block, mobile-first conversion of the L1087 `max-width:760px` rule, the four `min-width`
  stops, stacked-table `data-label`/`::before`, disclosure button, `:focus-visible`, skip-link)
  is authored as literal template-string blocks in `brandbook/src/admin-css-build.mjs` (co-located
  with the existing `@media` block), consuming only existing `--rindle-*` tokens; regenerated into
  `brandbook/tokens/rindle-admin.css`; byte-mirrored to `priv/static/rindle_admin/rindle-admin.css`
  by `sync-admin-css.mjs`. **NEVER hand-edit either CSS file.** Singletons stay inline — do NOT
  invent an inventory constant in `admin-design-system-data.mjs` for one-off structural selectors
  (that's only for enumerable sets, per D-97-04). Drift is closed by DS-01 (`git diff --exit-code`
  on the regenerated brandbook copy) + ADMIN-02 (byte-equality brandbook↔shipped). Keep
  byte-equality (the generator is deterministic; Phase 98 adds no `Set`/`Map`/`Date.now()`
  nondeterminism). **No `tokens.json` change is required** — all referenced tokens (motion 4 +
  3 easings, breakpoint sm480/md760/lg1024/xl1280, space_fluid gutter/section, radius card14/
  panel20, focus 2px/2px, contrast_pairs both themes incl frozen `processing` 0.09 margin) exist.
- **D-98-13 (two in-generator guards — fail closed):** (1) Add `var(--rindle-shadow-card)` to the
  generator's `requiredTokenUses` self-check — `--rindle-shadow-card` is emitted but currently
  UNUSED; the scaffold `:summary` 1st-order hierarchy is its first consumer, so the §A hierarchy
  assertion could silently pass on the wrong shadow without this guard. (2) Extend
  `requiredSelectors`/`requiredMetaSelectors` with the new Phase-98 structural selectors so a
  dropped block fails the build.
- **D-98-14 (redirect every "L1087" SPEC citation):** the UI-SPEC cites
  `priv/static/.../rindle-admin.css` by path+line ~6× — these tempt editing the GENERATED file.
  Every plan task saying "L1087" must redirect to "the corresponding template-string block in
  `admin-css-build.mjs` (the `@media (max-width:760px)` block, ~L946)".

### Responsive Two-Pane Breakpoint (CONFIRMED — two independent stops; resolves checker note 2)

- **D-98-15:** `md/760` owns the SHELL sidebar switch; `lg/1024` owns the CONTENT `:work + :aside`
  two-pane collapse. In the **760–1023px band**: sidebar-shell + single-column `:work` + NO side
  `:aside`; detail is reached via the `:show` routes (incl the new `variants-jobs/:id`). Author as
  two distinct, **never-conflated** `@media` blocks — the `:aside` two-pane rule
  (`grid-template-columns: minmax(0,1fr) minmax(320px,380px)`) lives EXCLUSIVELY in the
  `min-width:1024px` block; the shell rule (`minmax(220px,260px) minmax(0,1fr)`) in the
  `min-width:760px` block. Use **media queries, not container queries** (one fixed shell layout;
  `container-type` would break the sticky table header). Inspector-min-width math validates lg:
  at 760px viewport main ≈ 436px (a 320px-min inspector squeezes work to ~116px); at 1024px main
  ≈ 700px (work ≥320 + aside 320–380 fits). The Composition gate ("two tracks ≥1024") and
  Responsive gate ("shell two tracks ≥760") assert on **different selectors at different stops** →
  no contradiction. Add a CSS comment marking 760 as shell-only and 1024 as `:aside`-only.

### Motion / Data-Loading (CONFIRMED — keep full re-render, streams OUT OF SCOPE)

- **D-98-16:** Keep the surfaces' current full-list re-render (`load`/`load_list` into assigns +
  `:for` comprehension, refreshed on PubSub `{:rindle_event}`). Do NOT introduce
  `phx-update="stream"` — the surfaces are bounded/filtered operator lists, not infinite feeds;
  streams would import the exact `transition:all`/`phx-patch` footgun §B warns against for
  cosmetic gain, and operational dashboards (LiveDashboard, Oban Web) do not animate row churn.
  §B's "Stream row insert/remove" catalog row is therefore **N/A** (row churn appears via ordinary
  un-animated assign-diff). ALL other §B rows ship as locked: button press (CSS `:active`
  `translateY(1px)`), popover/menu/theme-picker (`JS.toggle`, node stays mounted), toast
  (`JS.transition` 3-tuple via `phx-mounted`/`phx-remove`), drawer/dialog (`JS.transition`,
  only where §A actually uses an overlay — §A AVOIDS drawers for detail), status-chip content
  cross-fade (CSS, no color tween/pulse), skeleton→content (CSS cross-fade, static skeleton),
  focus-ring/page/live_indicator (instant/static). Deferral is low-regret/reversible (PubSub
  already exists to feed `stream_insert`/`stream_delete` later if a high-churn feed ever appears).

### Claude's Discretion

Helper/function names, exact gallery panel grouping, fixture copy, assertion wording, the precise
viewport literals inside each band (e.g. 759/761 vs other safe-inside values), the exact P2 split
decision (single plan vs P2a/P2b), and the precise structure of new `admin-css-build.mjs` blocks
may be resolved during planning, as long as the decisions above hold and work stays within
UPLIFT-03..08.

### Folded Todos

No matching pending todos were found for Phase 98.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-UI-SPEC.md`
  — the LOCKED visual/interaction contract (§A–§F + six merge-gate assertion blocks + Checker
  Sign-Off notes). This CONTEXT is implementation guidance ON TOP of it.
- `brandbook/tokens/tokens.json` — token source of truth (motion, breakpoint, space_fluid,
  radius, focus, contrast_pairs). No changes this phase.
- `brandbook/src/admin-css-build.mjs`, `brandbook/src/admin-design-system-data.mjs`,
  `brandbook/src/sync-admin-css.mjs` — the generated-CSS authoring + sync pipeline.
- `test/brandbook/admin_design_system_validation_test.exs` (DS-01 ~L40–100, ADMIN-02 ~L254–255),
  `brandbook/src/admin-contrast.mjs` — ExUnit gate home + contrast source of truth.
- `examples/adoption_demo/e2e/support/admin-polish.js`,
  `examples/adoption_demo/e2e/admin-screenshots.spec.js` (`toHaveLength(22)` literal) — Playwright
  computed-style gate home.
- `.planning/phases/94-.../94-CONTEXT.md` (D-94-02/03/10 generated-CSS boundary),
  `.planning/phases/97-.../97-CONTEXT.md` (D-97-04/05 + wave-chain + gate-flip precedent).
- `.planning/ROADMAP.md` (Phase 98 success criteria; Phase 99 = Track-B Cohort; **Phase 102** =
  the gate flip/generalization — NOT this phase).
- `.planning/JTBD-MAP.md`, `guides/user_flows.md` — operator/SRE persona + JTBD + flows for IA
  and microcopy.
- `prompts/rindle-brand-book.md` (§14 microcopy bank, §11 motion, status lexicon, anti-hype),
  `prompts/phoenix-media-uploads-lib-deep-research.md` (operator/admin domain).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/rindle/admin/components.ex` — shared primitives imported by all six surfaces: `shell`
  (nav `@surfaces` attr ~L8–15, `<main>` ~L45), `theme_picker` (~L59–67, `select_theme/1`
  ~L209–213), `live_indicator` (~L71–78), `table/1` (bare wrapper ~L172–178), `empty_state`/
  `error_state` (~L116–143), `status_chip` (non-focusable `<span>`, always renders label text).
  Fix a primitive once → all six inherit. `page/1` does NOT exist yet (file ends at `table/1`).
- `lib/rindle/admin/queries.ex` — `home_status/1` already returns `recommendations` + `counts`
  (no query change needed for triage home). Will need a new run-detail function for D-98-09.
- `lib/rindle/admin/router.ex` — has `:show` routes for `/assets/:id` (~L97) and
  `/upload-sessions/:id` (~L100–104); the mount-validation macro is auth-gated/fragile (~L58–111).
  NO `variants-jobs/:id` route today (~L106) → added in D-98-09.
- `examples/adoption_demo/e2e/support/admin-polish.js` — existing offender-returning sub-assertions
  (`assertFocusVisibleTokens` ~L319, `assertTargetSizes` ~L291, `assertReadableContrast`,
  `assertNoHorizontalScroll`, `freezeMotion` ~L63) — extend, don't rebuild.

### Established Patterns
- Generated-CSS-only: author in `.mjs` → regenerate → byte-sync to `priv/` → DS-01 git-diff +
  ADMIN-02 byte-equality drift gates. Never hand-edit shipped CSS (D-94/D-97).
- Surfaces load bounded lists via `load`/`load_list` into assigns + `:for`, refreshed on PubSub
  `{:rindle_event}` (no streams, no polling). All six hand-roll their own `<table>`/`<section>`
  markup today (the thing P2 migrates onto `page/1`).
- Phase-97 wave-chain: pipeline-stage plans with hard `depends_on`, final plan flips/seals the
  gate (`autonomous: false`).
- `home_live.ex:56` currently renders `inspect(recommendation)` — the §E anti-pattern to replace.

### Integration Points
- `page/1` scaffold (new, P1) is where all six surfaces' tables/sections/empty-error-loading
  states converge; the §C stacked-card transform, §D caption/scope, and §B motion all bind to its
  selectors → why P1 must precede the migrations.
- New admin-polish.js checks attach to the existing `[data-rindle-admin-root]` seam (keep
  Phase-102 `{root, interactiveSelectors}` generalization intact).
- Server theme assign (D-98-07) threads from shell mount into `theme_picker` for server-owned ARIA.

### Two known SPEC↔code reconciliations for planning
1. §E names `home_status_live.ex`; the actual file is `home_live.ex`.
2. §C "drawer side-docks at lg `min(100%,520px)`" (overlay sheet) vs §A `:aside` two-pane
   `minmax(320px,380px)` (static inspector) describe two different things — both share the lg/1024
   gate and switch in lockstep; not a conflict.
</code_context>

<specifics>
## Specific Ideas

- Maintainer locked **option A** for Processing detail: a real dedicated `variants-jobs/:id` route
  (truest to §A/§E + the 760–1023px band), over de-scoping to asset detail.
- Research lenses applied per maintainer request: software-architecture/SWE, accessibility (WCAG
  2.1 AA, `focus_wrap`/`inert`), gov.uk/GDS IA + operator psychology, design-token pipeline
  (Style Dictionary/DTCG norms), responsive master-detail UX (Material decoupled breakpoints),
  and LiveView motion restraint — each grounded in `prompts/`, brandbook, JTBD-MAP, and prior art
  (LiveDashboard `PageBuilder`, Oban Web, gov.uk frontend/Pay migration).
</specifics>

<deferred>
## Deferred Ideas

- **LiveView streams** for admin lists — deferred (D-98-16); revisit only if a surface later needs
  a genuinely unbounded/high-churn live feed (memory, not animation).
- **Gate warn→fail flip + admin/Cohort gate generalization + pixel baselines** — **Phase 102**
  (Re-Converge), explicitly NOT this phase.
- **Cohort inner-page restyle** — Track B (Phases 96/99), out of Track-A scope.

### Reviewed Todos (not folded)
None — no pending todos matched Phase 98.
</deferred>
