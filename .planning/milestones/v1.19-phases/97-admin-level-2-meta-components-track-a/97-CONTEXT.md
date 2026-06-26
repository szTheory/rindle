# Phase 97: admin-level-2-meta-components-track-a - Context

**Gathered:** 2026-06-17 (research-driven, non-interview — adapted from Phase 95 template)
**Status:** Ready for planning
**Source:** Orchestrator-authored from Phase 95 artifacts + codebase analysis (full non-interview path)

<domain>
## Phase Boundary

Phase 97 is Track A's Admin Level-2 Meta-Component pass. It owns **UPLIFT-02 only**:
toolbars, sortable / sticky-header / bulk-select data tables, filter bars, action panels,
detail drill-downs, confirm/destructive panels, drawers, and toasts must read as cohesive
**composed units** with consistent rhythm, alignment, and density — built **only** from the
Level-1 `rindle-admin` primitives that Phase 95 hardened (UPLIFT-01).

This phase composes and proves meta-components and extends the deterministic gate that
proves their rhythm/density. It does **not**: re-audit Level-1 primitives (Phase 95 owns
that — extend, don't re-open), perform per-page composition / IA / mobile / motion / a11y /
microcopy passes (Phase 98, UPLIFT-03..08), restyle Cohort (Track B, Phases 96/99–102),
add new console lifecycle semantics or write paths, or introduce a new visual-regression
service / Storybook / component registry.
</domain>

<decisions>
## Implementation Decisions

### Level-2 Scope

- **D-97-01:** Compose and refine **only** the approved Level-2 meta-component inventory from
  `97-UI-SPEC.md`: toolbar, data table (sortable + sticky-header + bulk-select), filter bar,
  action panel, detail drill-down, confirm/destructive panel, drawer, and toast stack. Each
  is a composed unit, not a new primitive.
- **D-97-02:** Build meta-components **exclusively** from Level-1 primitives and tokens. No
  new color literals, no one-off spacing, no new font roles. Any gap that genuinely needs a
  new primitive is out of scope — flag it, do not invent it in the Level-2 layer.
- **D-97-03:** Data-table behaviors (sort affordance, sticky header, bulk-select) are
  expressed as **CSS/markup state + BEM modifiers + data-attributes** on the existing
  `.rindle-admin-table` primitive. This is a static design-system proof surface; do not add
  client-side sorting/selection JS frameworks. Interactive state is represented in the
  gallery via fixture markup (e.g. `aria-sort`, `[data-rindle-admin-selected]`).

### Generated CSS Boundary (inherited from Phase 95)

- **D-97-04:** Emit all new meta-component styling from `brandbook/src/admin-css-build.mjs`,
  backed by `brandbook/tokens/tokens.json` and shared constants in
  `brandbook/src/admin-design-system-data.mjs`. Add a `META_COMPONENTS` inventory constant
  rather than scattering names.
- **D-97-05:** Do not hand-edit `brandbook/tokens/rindle-admin.css` or
  `priv/static/rindle_admin/rindle-admin.css`. Generated output flows through the existing
  build → contrast → gallery-check → `sync-admin-css.mjs` → empty-diff drift gate.

### Gallery And Proof Surface

- **D-97-06:** Each meta-component appears in the brandbook admin gallery as a **single
  cohesion unit** (a labeled panel rendering the whole composed component), marked with a
  stable `data-rindle-admin-meta` attribute (in addition to the existing
  `data-rindle-admin-component` markers on its Level-1 parts) so the checker can assert unit
  presence mechanically.
- **D-97-07:** `admin-gallery-check.mjs` proves every meta-component unit renders, is
  visible across light/dark/auto, and is composed only of known Level-1 selectors (no
  unknown class leakage).

### Rhythm / Density Gate (the merge-blocking deliverable)

- **D-97-08:** Success criterion 2 requires **rhythm, overlap, and no-horizontal-scroll**
  gates in `examples/adoption_demo/e2e/support/admin-polish.js`. The current gate has
  `assertNoClippedText`, `assertNoInteractiveOverlap` (currently warn-only via
  `OVERLAP_ENFORCED=false`), and `assertStableDimensions` — but **no dedicated rhythm check
  and no dedicated no-horizontal-scroll check**. Phase 97 MUST add both as returning (never
  throwing) sub-assertions aggregated by `assertAdminPolish`.
- **D-97-09:** **Rhythm check:** assert vertical/horizontal spacing between sibling elements
  inside a meta-component resolves to token-backed `--rindle-space-*` multiples (4px grid),
  failing on off-grid gaps/margins. Density must be consistent within a unit.
- **D-97-10:** **No-horizontal-scroll check:** assert the meta-component root's
  `scrollWidth <= clientWidth + CLIP_TOLERANCE` (no page-level horizontal overflow) at the
  captured viewports. Sticky-header table internal scroll regions are the explicit, narrow
  exception and must be opted in by an explicit container marker, not auto-detected.
- **D-97-11:** Flip `OVERLAP_ENFORCED` to `true` (hard failure) for the meta-component
  matrix once a green CI cycle confirms zero spurious overlap warnings — overlap is a
  first-class Level-2 cohesion defect. Keep all sub-assertions offender-returning, single
  aggregated throw per state.

### the agent's Discretion

Routine helper names, exact gallery panel grouping/order, fixture copy, assertion wording,
the precise rhythm-tolerance constant, and which container marker opts a region into the
sticky-scroll exception may be resolved during planning, as long as the decisions above hold
and the work stays within UPLIFT-02.

### Folded Todos

No matching pending todos were found for Phase 97.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap / Requirements / State
- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/STATE.md`

### Track A predecessor (the template — extend, don't re-open)
- `.planning/phases/95-admin-level-1-component-audit-track-a/95-UI-SPEC.md`
- `.planning/phases/95-admin-level-1-component-audit-track-a/95-CONTEXT.md`
- `.planning/phases/95-admin-level-1-component-audit-track-a/95-01-SUMMARY.md`
- `.planning/phases/95-admin-level-1-component-audit-track-a/95-02-SUMMARY.md`
- `.planning/phases/95-admin-level-1-component-audit-track-a/95-03-SUMMARY.md`

### Phase 97 contract
- `.planning/phases/97-admin-level-2-meta-components-track-a/97-UI-SPEC.md`

### Design-system source surfaces (where the work lands)
- `guides/ui_principles.md`
- `brandbook/tokens/tokens.json`
- `brandbook/src/admin-design-system-data.mjs`
- `brandbook/src/admin-css-build.mjs`
- `brandbook/src/admin-gallery.mjs`
- `brandbook/src/admin-gallery-check.mjs`
- `brandbook/src/admin-contrast.mjs`
- `brandbook/src/sync-admin-css.mjs`
- `examples/adoption_demo/e2e/support/admin-polish.js`
- `examples/adoption_demo/e2e/admin-screenshots.spec.js`
- `test/brandbook/admin_design_system_validation_test.exs`
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `brandbook/src/admin-design-system-data.mjs` centralizes `THEMES`, `SURFACES`,
  `STATUS_STATES`, `COMPONENTS`, `LEVEL_1_STATES`, `MOTION_TOKENS`, `MIN_TARGET_PX`, and
  `CONSOLE_CONTRAST_PAIRS`. Phase 97 adds a `META_COMPONENTS` inventory here.
- `brandbook/src/admin-css-build.mjs` already generates the `rindle-admin` stylesheet with
  self-checks for required selectors, theme scopes, focus/motion tokens, and a reduced-motion
  block. Meta-component composition rules are added here.
- `brandbook/src/admin-gallery.mjs` exposes `LEVEL_1_COMPONENT_STATE_MATRIX` and renders the
  shell + gallery panels with `data-rindle-admin-component` / `data-rindle-admin-state`
  markers. Phase 97 adds meta-component unit panels with `data-rindle-admin-meta`.
- `examples/adoption_demo/e2e/support/admin-polish.js` is the deterministic computed-style
  gate. It already has `freezeMotion`, ported WCAG utilities, and offender-returning
  sub-assertions aggregated by `assertAdminPolish` with per-surface/per-check exemptions.

### Established Patterns
- `rindle-admin` CSS is generated vanilla BEM with CSS custom properties from tokens.
- Theme behavior is `data-theme="light|dark|auto"` + `prefers-color-scheme`. No parallel
  theme convention.
- Shipped package CSS at `priv/static/rindle_admin/rindle-admin.css` is mirrored from the
  generated brandbook copy via `sync-admin-css.mjs`; drift is an empty-git-diff gate.
- Mechanical proof over subjective review: regenerate → contrast → gallery-check → sync →
  empty diff. New gate checks RETURN offenders; `assertAdminPolish` throws once per state.

### Integration Points
- Thread `META_COMPONENTS` through `admin-design-system-data.mjs` → `admin-css-build.mjs` →
  `admin-gallery.mjs` → `admin-gallery-check.mjs`.
- Extend `admin-polish.js` with `assertConsistentRhythm` and `assertNoHorizontalScroll`
  (names at planner discretion), wire into `assertAdminPolish`, and flip `OVERLAP_ENFORCED`
  for the meta-component matrix.
- Verification commands:
  - `node brandbook/src/admin-css-build.mjs`
  - `node brandbook/src/admin-contrast.mjs`
  - `node brandbook/src/admin-gallery-check.mjs`
  - `mix test test/brandbook/admin_design_system_validation_test.exs`
  - the existing merge-blocking `adoption-demo-e2e` lane runs `admin-polish.js`.
</code_context>

<specifics>
## Specific Ideas
- Reuse Phase 95's terse operator/SRE copy voice for all meta-component fixture copy.
- Data table is the richest unit: prove sortable header (`aria-sort` + token-backed sort
  glyph/affordance), sticky header (stays pinned under internal scroll), and bulk-select
  (header checkbox + per-row `[data-rindle-admin-selected]` + a contextual bulk-action
  toolbar that appears when rows are selected).
- The toolbar and filter bar are the canonical rhythm test cases — they pack the most
  sibling controls and are where off-grid gaps/overlap appear first.
- Keep the adoption-demo screenshot lane as the page-level proof; the gallery is the unit
  proof. Do not add a SaaS visual-regression dependency.
</specifics>

<deferred>
## Deferred Ideas
None — analysis stayed within Phase 97 / UPLIFT-02 scope. Page composition, motion, mobile,
a11y, and microcopy passes are Phase 98 (UPLIFT-03..08).

### Reviewed Todos (not folded)
No matching pending todos were found for Phase 97.
</deferred>

---

*Phase: 97-admin-level-2-meta-components-track-a*
*Context gathered: 2026-06-17 via full non-interview path (orchestrator-authored design contract)*
