# Phase 95: admin-level-1-component-audit-track-a - Context

**Gathered:** 2026-06-15 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 95 is Track A's Admin Level-1 Component Audit. It owns UPLIFT-01 only: every
`rindle-admin-*` primitive must be on-brand and excellent across the applicable
default, hover, focus-visible, active, disabled, loading, empty, error, and skeleton
states in light, dark, and auto/system themes.

This phase hardens component primitives and their deterministic proof surfaces. It does
not perform Level-2 meta-component work, page composition, IA, mobile/page-level a11y,
new console lifecycle semantics, new write paths, Cohort restyling, or a new visual
regression service.
</domain>

<decisions>
## Implementation Decisions

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

### Folded Todos

No matching pending todos were found for Phase 95.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/STATE.md`
- `.planning/phases/95-admin-level-1-component-audit-track-a/95-UI-SPEC.md`
- `.planning/phases/88-admin-design-system-ui-kit/88-CONTEXT.md`
- `.planning/phases/92-e2e-screenshot-driven-polish-loop/92-CONTEXT.md`
- `.planning/phases/94-foundation-token-pipeline-ci-gate-new-token-categories/94-CONTEXT.md`
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

- `brandbook/src/admin-design-system-data.mjs` already centralizes `THEMES`,
  `STATUS_STATES`, `COMPONENTS`, `MOTION_TOKENS`, `MIN_TARGET_PX`, and
  `CONSOLE_CONTRAST_PAIRS`.
- `brandbook/src/admin-css-build.mjs` is the generator for the `rindle-admin` component
  stylesheet and already contains partial rules for focus-visible, active, disabled,
  hover, status chips, dialogs, drawers, toasts, empty states, skeletons, and responsive /
  reduced-motion behavior.
- `brandbook/src/admin-gallery.mjs` and `brandbook/src/admin-gallery-check.mjs` are the
  existing static component-gallery harness and browser checker.
- `examples/adoption_demo/e2e/support/admin-polish.js` is the deterministic computed-style
  gate used by live console screenshots and now accepts explicit root / interactive selector
  targeting.

### Established Patterns

- `rindle-admin` CSS is generated vanilla BEM with CSS custom properties from
  `brandbook/tokens/tokens.json`.
- Theme behavior is `data-theme="light|dark|auto"` plus `prefers-color-scheme`; do not add
  a parallel theme convention.
- The shipped package CSS under `priv/static/rindle_admin/rindle-admin.css` is mirrored from
  the generated brandbook copy via `brandbook/src/sync-admin-css.mjs`.
- Mechanical proof is preferred over subjective screenshot review: regenerate, contrast
  gate, gallery check, sync, and empty git diff.

### Integration Points

- Planner should thread new Level-1 inventory/state constants through
  `admin-design-system-data.mjs`, `admin-css-build.mjs`, `admin-gallery.mjs`,
  `admin-gallery-check.mjs`, and `admin-contrast.mjs`.
- Planner should extend `admin-polish.js` only where reusable computed-style checks are
  needed for the Phase 95 focus/active/outline contract.
- Verification should include:
  `node brandbook/src/admin-css-build.mjs`,
  `node brandbook/src/admin-contrast.mjs`,
  `node brandbook/src/admin-gallery-check.mjs`, and
  `mix test test/brandbook/admin_design_system_validation_test.exs`.
</code_context>

<specifics>
## Specific Ideas

- Preserve the exact `95-UI-SPEC.md` copywriting contract for Level-1 empty, error, primary
  CTA, and destructive confirmation examples.
- Use `data-rindle-admin-component` and `data-rindle-admin-state` markers in the gallery so
  the checker can prove state coverage mechanically.
- Treat `brandbook/src/admin-design-system-data.mjs` omitting form controls and error as
  first-class `COMPONENTS` as a likely implementation gap to close.
- Keep overlap warnings in `admin-polish.js` unless Phase 95 explicitly stabilizes them.
</specifics>

<deferred>
## Deferred Ideas

None - analysis stayed within Phase 95 scope.

### Reviewed Todos (not folded)

No matching pending todos were found for Phase 95.
</deferred>
