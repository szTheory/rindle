# Phase 88: Admin Design System & UI Kit - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md - this log preserves the analysis.

**Date:** 2026-06-11
**Phase:** 88-admin-design-system-ui-kit
**Mode:** assumptions
**Areas analyzed:** CSS And Token Source, Theme And State Semantics, Component Scope And Packaging Boundary, Component Inventory And IA Alignment, Gallery Screenshots And Gates

## Assumptions Presented

### CSS And Token Source

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 88 should generate a dedicated vanilla `rindle-admin` CSS layer from `brandbook/tokens/tokens.json`, using BEM selectors and `--rindle-` CSS custom properties, while treating `brandbook/tokens/tokens.css` as the existing brand-token artifact rather than the full console component stylesheet. | Confident | `.planning/ROADMAP.md`; `guides/rindle_admin_css.md`; `brandbook/src/tokens-build.mjs` |

### Theme And State Semantics

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| The theme picker should be a first-class `rindle-admin` component that sets `data-theme="light|dark|auto"` and lets `auto` resolve through `prefers-color-scheme`; lifecycle/status components must include text labels plus icons or equivalent marks, not color alone. | Confident | `.planning/ROADMAP.md`; `guides/rindle_admin_css.md`; `brandbook/src/tokens-build.mjs`; `brandbook/tokens/tokens.json` |

### Component Scope And Packaging Boundary

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Phase 88 should produce reusable component markup/styles for the kit, but should not implement the full mountable admin router, auth contract, asset-serving plug, or `Rindle.Admin.Queries` read surfaces; those remain Phase 89 responsibilities. | Confident | `.planning/ROADMAP.md`; `guides/admin_console_architecture.md`; `mix.exs` |

### Component Inventory And IA Alignment

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| The nav shell, tables, chips, buttons, dialogs, drawers, toasts, empty states, and skeletons should be shaped around the six locked operator surfaces rather than generic dashboard widgets. | Confident | `.planning/ROADMAP.md`; `guides/admin_console_ia.md`; `guides/ui_principles.md`; `guides/admin_console_motion.md` |

### Gallery, Screenshots, And Gates

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| The gallery harness should be deterministic and maintainer-reviewable, using stable selectors and light/dark/system coverage, with a mechanical Node contrast gate extended from the existing `brandbook/src/contrast.mjs` pattern. | Likely | `.planning/ROADMAP.md`; `guides/ui_principles.md`; `brandbook/src/contrast.mjs`; `brandbook/tokens/tokens.json`; `examples/adoption_demo/playwright.config.js` |

Alternatives noted for planning:

- Extend the existing Cohort Playwright harness for gallery review.
- Create a separate admin-gallery harness outside Cohort to avoid Tailwind/daisyUI leakage.
- Generate static gallery HTML and use a Node/Playwright screenshot script without mounting the real console route.

## Corrections Made

No corrections - all assumptions confirmed.
