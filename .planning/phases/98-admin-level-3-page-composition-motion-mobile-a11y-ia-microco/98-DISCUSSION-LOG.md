# Phase 98: Admin Level-3 Page Composition + Motion / Mobile / A11y / IA / Microcopy - Discussion Log (Assumptions Mode + Research)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-17
**Phase:** 98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco
**Mode:** assumptions → maintainer requested deep parallel subagent research before locking
**Areas analyzed:** Plan decomposition · Merge-gate test homes · A11y+IA implementation shape ·
Build-pipeline boundary · Two-pane breakpoint reconciliation · Motion/streams data-loading

## Assumptions Presented (post codebase-analyzer, pre-research)

### Plan decomposition
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| 5 plans: P1 scaffold+migrate, ‖P2 motion+responsive, ‖P3 a11y, P4 IA+routing, P5 microcopy | Likely | six `*_live.ex` hand-roll tables; no `page/1` in `components.ex` |

### Merge-gate test homes
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Static CSS-text → ExUnit brandbook test; computed-style/DOM → admin-polish.js | Confident | ExUnit asserts via `css =~` + node generators; admin-polish.js reads getComputedStyle ×22 states |

### A11y + IA
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| a11y fixes single-touch in components.ex; deep-links + below-md detail reuse existing routes (no new routes) | Likely | shared primitives imported by all six; `handle_params` already parses filters; `:show` routes exist |

### Build-pipeline boundary
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| All CSS generated via admin-css-build.mjs, never hand-edit priv/; no tokens.json change | Confident | generated-file header + sync-admin-css.mjs; DS-01/ADMIN-02 gates; tokens confirmed present |

### Two-pane breakpoint
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Two independent stops: md/760 shell, lg/1024 :aside; 760–1023 = single-col work + route-to-detail | Likely | §A collapses below 1024, §C shell switch at 760; only consistent as separate stops |

### Motion / streams
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Keep full re-render; no streams; §B stream-row choreography N/A | Likely | six surfaces use load/load_list + `:for`, none use phx-update="stream" |

## Deep Research (6 parallel gsd-advisor-researcher passes)

Maintainer directed: research each area for pros/cons/tradeoffs with examples, idiomatic
Elixir/Phoenix/Plug/Ecto, prior-art lessons (right + footguns), DX/UX, least surprise, using
`prompts/` + brandbook + JTBD-MAP/user_flows + sibling repos, with architecture and
UI/UX/creative-direction/user-psychology expert lenses; one coherent cohesive recommendation set.

All six returned **Confident** (plan-decomp Confident after research; others Confident).

## Corrections Made (research refined the assumptions)

### Plan decomposition
- **Original assumption:** 5 plans with parallel motion-CSS ‖ a11y-CSS plans.
- **Refined:** 4 plans. Parallel CSS plans are an illusion — the single generated-CSS file +
  byte-identical drift gate forbids them; a11y *markup* (caption/scope) must ride the per-surface
  scaffold migration; IA+microcopy merge as one atomic content band.
- **Reason:** drift-gate thrash + cross-surface/whole-console gates + Phase-97 wave-chain
  precedent + gov.uk "one template at a time" + LiveDashboard `PageBuilder` idiom.

### Merge-gate test homes
- **Original:** clean static-vs-live split.
- **Refined:** split line is "does proving it need the cascade to resolve?" Composition + Motion
  are PARTIALLY split (unconditional → ExUnit, viewport/theme/interaction-conditional → Playwright).
  Contrast stays ExUnit-only (don't re-derive in browser); theme_picker aria-pressed asserted in
  DEAD markup; bump `toHaveLength(22)` for net-new e2e states; reduced-motion read taken un-frozen.
- **Reason:** a `css =~ "display:block"` substring ships green even inside a broken `@media` block.

### A11y + IA
- **Original:** all a11y single-touch; no new routes anywhere.
- **Refined:** table caption/scope is a 6–7-table SPREAD that rides the scaffold migration;
  theme_picker server-ARIA needs the shell to learn the current theme (real wiring task); ONE route
  gap — `variants-jobs/:id` does not exist (variant detail currently borrows `assets/:id`).
- **Reason:** read all six modules + router + queries; the gap is the only place "no new routes"
  fails.

### Scope correction (not an assumption — a roadmap fact)
- The warn→fail gate flip + admin/Cohort gate generalization is **Phase 102**, NOT Phase 99 (my
  pre-research framing said 99). Phase 98 lands new admin-polish.js checks as already-HARD
  admin-root-only assertions and must not touch Cohort.

### Build-pipeline boundary
- **Confirmed in full.** Added two in-generator guards (add `--rindle-shadow-card` to
  requiredTokenUses — emitted-but-unused, scaffold `:summary` is first consumer; extend
  requiredSelectors fail-closed) + redirect every "L1087" SPEC citation to the generator block.

### Two-pane breakpoint / Motion
- **Both confirmed** with quantitative backing (inspector-min-width math validates lg/1024;
  operational-dashboard prior art validates no row-churn animation; deferral is low-regret).

## Maintainer Decision (escalated — the one genuine scope fork)

- **Processing detail route:** chose **A — add `variants-jobs/:id` route** (new `:show` +
  `Queries.run_detail` + one-run detail render, redaction parity) over B (de-scope to asset
  detail). Truest to the locked §A/§E contract and the 760–1023px band. → D-98-09.

## External Research Sources (selected)

- Phoenix.LiveDashboard.PageBuilder; Phoenix.Component slots — page-grammar idiom.
- GOV.UK Pay design-system migration — "one template at a time via shared base."
- Sparkbox / quixote — CSS unit-testing "compiles ≠ correct" footgun.
- Playwright getComputedStyle + `::before` pseudo-element + viewport responsive patterns.
- web.dev `inert` / a11ysupport.io / MDN / caniuse — `inert`+`aria-hidden` overlay support.
- Style Dictionary / W3C DTCG / gov.uk Sass→CSS committed-and-recompile-no-diff — token pipeline.
- Material list-detail (decoupled shell vs side-by-side breakpoints); MS list/details.
- Phoenix Files Streams / LiveView docs / Oban Web / LiveDashboard — streams "not one-size-fits-all".
