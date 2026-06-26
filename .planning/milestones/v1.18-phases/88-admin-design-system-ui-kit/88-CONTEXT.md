# Phase 88: Admin Design System & UI Kit - Context

**Gathered:** 2026-06-11 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 88 ships the token-generated `rindle-admin` design system and component kit
that later admin-console implementation phases will use. It delivers DS-01,
DS-02, DS-03, and ADMIN-02 groundwork: generated vanilla CSS from brand tokens,
a first-class light/dark/system theme component, core operator-oriented
components, a deterministic component-gallery screenshot harness, mechanical
WCAG AA contrast coverage for console token pairs, and maintainer review of the
rendered gallery.

This phase does not implement the mountable admin router, production auth
contract, asset-serving plug, `Rindle.Admin.Queries`, read surfaces, or console
action flows. Those remain scoped to phases 89 and 90.
</domain>

<decisions>
## Implementation Decisions

### CSS And Token Source

- **D-88-01:** Generate a dedicated vanilla `rindle-admin` CSS layer from
  `brandbook/tokens/tokens.json`, using BEM selectors and `--rindle-` CSS custom
  properties.
- **D-88-02:** Treat `brandbook/tokens/tokens.css` as the existing generated
  brand-token artifact, not as the full console component stylesheet.
- **D-88-03:** Do not hand-edit generated CSS artifacts. Follow the existing
  brandbook generator/checker pattern and keep component CSS reproducible.
- **D-88-04:** The shipped console design system must remain independent of host
  Tailwind, daisyUI, esbuild, asset-pipeline integration, shadcn, Radix,
  Tailwind UI, daisyUI registries, or other third-party UI registries.

### Theme And State Semantics

- **D-88-05:** Implement the theme picker as a first-class `rindle-admin`
  component that writes `data-theme="light|dark|auto"`.
- **D-88-06:** `data-theme="auto"` follows `prefers-color-scheme`; do not add a
  parallel theme convention.
- **D-88-07:** Lifecycle and operational status components must include visible
  text labels plus icons or equivalent non-color marks. Never rely on color
  alone.
- **D-88-08:** Status colors and focus states must use token-gated foreground /
  background pairs, including the frozen processing token margin from the brand
  token rules.

### Component Scope And Packaging Boundary

- **D-88-09:** Phase 88 produces reusable component markup/styles for the kit,
  not the full mounted console implementation.
- **D-88-10:** Do not implement the admin router macro, production safe-mount
  check, host auth contract, `Plug.Static` asset-serving route, CSP/socket
  option handling, or `Rindle.Admin.Queries` read surfaces in this phase.
- **D-88-11:** Preserve the optional LiveView dependency boundary. Component-kit
  work may prepare Phoenix/LiveView markup patterns, but Phase 88 must not make
  `phoenix_live_view` required for non-console adopters.

### Component Inventory And IA Alignment

- **D-88-12:** Build the required core components around Rindle's six locked
  operator surfaces: `Home/Status`, `Assets`, `Upload Sessions`,
  `Variants/Jobs`, `Runtime/Doctor`, and `Actions`.
- **D-88-13:** The component kit includes nav shell, tables, lifecycle-state
  chips, buttons, confirm dialog, drawer, toasts, empty states, and skeletons.
- **D-88-14:** Components should support task-first operations workflows, not
  decorative analytics dashboard widgets or marketing-style layouts.
- **D-88-15:** Motion in buttons, drawers, toasts, skeletons, and transitions
  must use the locked motion tokens, respect `prefers-reduced-motion`, and
  remain tied to real operational feedback.

### Gallery, Screenshots, And Gates

- **D-88-16:** Provide a deterministic component-gallery harness that maintainers
  can review before Phase 89/90 rely on the kit.
- **D-88-17:** The gallery must use stable selectors and cover light, dark, and
  system/auto theme behavior.
- **D-88-18:** Extend the existing `brandbook/src/contrast.mjs` style of
  mechanical WCAG AA checks to console-specific token/component pairs.
- **D-88-19:** Screenshot review should include realistic ready, processing,
  warning, danger, quarantine, info, empty, loading, and focus states so later
  console phases inherit accessible component defaults.

### the agent's Discretion

The maintainer confirmed the assumptions as presented. The planner may choose
the exact gallery implementation path - extending the Cohort Playwright harness,
creating a separate admin-gallery harness, or generating static gallery HTML
with a Node/Playwright screenshot script - as long as it stays deterministic,
avoids Cohort Tailwind/daisyUI leakage into the shipped library console, and
supports maintainer screenshot review.

Routine file layout, helper naming, selector naming within the locked BEM
contract, screenshot command names, and exact docs wording can be resolved
during planning unless they affect public API shape, auth semantics, dependency
footprint, destructive operations, security/compliance boundaries, recurring
cost, or milestone scope.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope And Prior Decisions

- `.planning/ROADMAP.md` - Phase 88 goal, dependencies, requirements, success
  criteria, and phase boundary.
- `.planning/REQUIREMENTS.md` - DS-01, DS-02, DS-03, ADMIN-02, ADMIN-06, and
  v1.18 out-of-scope boundaries.
- `.planning/PROJECT.md` - v1.18 charter, decision-making contract, support
  truth, and high-blast-radius escalation rules.
- `.planning/STATE.md` - current position: Phase 87 complete and Phase 88 ready
  to plan.
- `.planning/METHODOLOGY.md` - adopter-first, repo-truth, research-first,
  narrow-then-escalate, and least-surprise lenses.
- `.planning/phases/86-research-architecture-lock/86-CONTEXT.md` - D-86-03,
  D-86-11 through D-86-15, and D-86-20 lock the design-system, CSS, theme,
  status, motion, and UI-principles boundaries.
- `.planning/phases/86-research-architecture-lock/86-UI-SPEC.md` - approved UI
  design contract: typography, spacing, colors, motion, registry safety, and
  interaction constraints.
- `.planning/phases/87-docker-demo-dx/87-CONTEXT.md` - stable future admin URL
  target for the Docker preview (`/admin/rindle`) and Phase 87 completion
  context.

### Admin Design And Architecture

- `guides/ui_principles.md` - durable PRIN-01 rules for console, Cohort, E2E,
  screenshot polish, accessibility, and destructive-action UX.
- `guides/rindle_admin_css.md` - locked CSS architecture for generated
  `rindle-admin` CSS, BEM selectors, theme contract, status chips, Cohort
  separation, dependency boundary, and downstream constraints.
- `guides/admin_console_ia.md` - six top-level operator surfaces and
  task-first navigation model the component kit must support.
- `guides/admin_console_motion.md` - motion token contract, allowed/forbidden
  motion, reduced-motion rules, and operational feedback constraints.
- `guides/admin_console_architecture.md` - Phase 89 boundaries for router macro,
  safe mount, static asset serving, CSP/socket options, optional dependency
  matrix, and `Rindle.Admin.Queries`.

### Brand Tokens And Build Patterns

- `brandbook/tokens/tokens.json` - source of truth for color, typography,
  spacing, radius, focus, motion, and contrast pairs.
- `brandbook/src/tokens-build.mjs` - existing generated CSS custom property
  pipeline and `data-theme="dark|auto"` pattern.
- `brandbook/src/contrast.mjs` - mechanical WCAG contrast gate pattern to
  extend for console token pairs.
- `brandbook/tokens/tokens.css` - current generated brand-token output; useful
  precedent, not the complete admin component stylesheet.
- `brandbook/fonts/` - self-contained font assets named by the UI contract.
- `brandbook/assets/logo/` - self-contained Rindle logo assets for later
  console packaging.

### Runtime And Verification Context

- `mix.exs` - optional dependency posture and package-file constraints for
  later self-contained admin assets.
- `lib/rindle/live_view.ex` - existing optional LiveView integration and
  `Code.ensure_loaded?/1` pattern.
- `examples/adoption_demo/playwright.config.js` - existing Playwright harness
  precedent for deterministic browser checks.
- `examples/adoption_demo/e2e/` - existing adoption-proof E2E conventions and
  support utilities, if the planner chooses to reuse the harness.
- `RUNNING.md` - repo verification lanes and local/CI operating model.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `brandbook/tokens/tokens.json` already contains semantic light/dark tokens,
  typography, spacing, radius, focus, motion, and contrast pair declarations
  that should drive the admin design system.
- `brandbook/src/tokens-build.mjs` already resolves token references and emits
  CSS variables for `:root`, `[data-theme="dark"]`, and auto dark-mode scopes.
- `brandbook/src/contrast.mjs` already provides a small Node gate that reads
  token pairs and exits non-zero on contrast failures.
- `brandbook/fonts/` and `brandbook/assets/logo/` give the console a
  self-contained asset base that matches the brand system.
- `guides/rindle_admin_css.md`, `guides/admin_console_ia.md`,
  `guides/admin_console_motion.md`, and `guides/ui_principles.md` already lock
  the design-system constraints Phase 88 should implement.
- `examples/adoption_demo/playwright.config.js` and `examples/adoption_demo/e2e/`
  show the repo already has Playwright infrastructure for browser verification
  and screenshot-oriented review.

### Established Patterns

- Generated artifacts are source-derived and should not be manually edited.
- Optional integrations use `Code.ensure_loaded?/1` and must not leak required
  Phoenix/LiveView aliases into default installs.
- Cohort is allowed to keep Tailwind/daisyUI, but shipped library console
  assets are vanilla, self-contained, and host-independent.
- Rindle planning favors task-first operator surfaces, honest support truth, and
  no decorative dashboard sprawl.
- Status indicators require labels/non-color marks plus token-gated color pairs.
- UI work must satisfy light and dark contrast mechanically, not by visual
  inspection alone.

### Integration Points

- Phase 88 output feeds Phase 89 static asset serving from the `:rindle` OTP app.
- Phase 88 component names/selectors feed Phase 89 read surfaces and Phase 90
  action/destructive-flow screens.
- Phase 88 gallery screenshots provide the maintainer review checkpoint before
  later console phases rely on the kit.
- Phase 92 screenshot polish should consume this design-system contract instead
  of introducing one-off console styles.
- The Docker preview route printed by Phase 87 (`/admin/rindle`) remains the
  future mounted-console target; Phase 88 does not need to mount it.
</code_context>

<specifics>
## Specific Ideas

- Use `Rindle Admin` as the service identity in component examples and
  navigation labels.
- Keep generated class names inspectable and namespaced, such as
  `.rindle-admin-shell`, `.rindle-admin-nav__item`,
  `.rindle-admin-table__row`, and `.rindle-admin-status-chip--ready`.
- Cover status examples for ready, processing, warning, danger, quarantine, and
  info because those token pairs already exist and later console screens need
  them.
- Keep `#6D5DD3` processing unchanged; its AA margin is intentionally narrow.
- Prefer a gallery shape that can be run and reviewed without requiring a real
  mounted admin route, unless planning finds a stronger low-risk path.
</specifics>

<deferred>
## Deferred Ideas

None - analysis stayed within Phase 88 scope.

### Reviewed Todos (not folded)

No matching pending todos were found for Phase 88.
</deferred>

---

*Phase: 88-admin-design-system-ui-kit*
*Context gathered: 2026-06-11*
