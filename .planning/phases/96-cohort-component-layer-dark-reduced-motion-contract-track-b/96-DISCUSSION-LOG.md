# Phase 96: cohort-component-layer-dark-reduced-motion-contract-track-b - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-17
**Phase:** 96-cohort-component-layer-dark-reduced-motion-contract-track-b
**Mode:** assumptions (calibration: minimal_decisive)
**Areas analyzed:** Contrast Gate Wiring · `/styleguide` Route + E2E Polish Reach · Theme + Reduced-Motion Rendering · CohortComponents Conventions

## Context note

The phase already had an approved `96-UI-SPEC.md` locking all visual values (ladders, hexes,
inventory, motion rules, copy, 7 acceptance gates). Analysis therefore targeted the
**implementation wiring** seams the planner/researcher need, treating every UI-SPEC value as
fixed. No external research was required — every seam has a working in-repo admin analog.

## Assumptions Presented

### Contrast Gate Wiring
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Net-new sibling `cohort-contrast.mjs` + `cohort-design-system-data.mjs` with per-pair `theme` field (mirrors admin pattern); not an extension of `contrast.mjs`, not via tokens.json | Confident | `contrast.mjs:10,28` theme-blind/tokens.json; `admin-contrast.mjs:9,20-25,51-65` per-theme pattern; D-94-05/06 |
| Gate runs as standalone node step in `adoption-demo-e2e` lane, not `brandbook-tokens` | Likely | `ci.yml:1156-1157` fences brandbook-tokens to rindle-admin.css; its mechanism is regen+`git diff` (meaningless for hand-authored CSS) |

### `/styleguide` Route + E2E Polish Reach
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| One `live(...)` line in existing `:browser` scope + new `StyleguideLive`; demo boots real server with seeds in CI | Confident | `router.ex:20-32`; `playwright.config.js` runs `mix phx.server`; `adoption_demo_e2e.sh` migrates+seeds+serves |
| Seam attrs on per-LiveView `.ck` div (`data-ck-root data-theme`), not `<body>` in root layout | Confident | `.ck` shell rendered per-LiveView (`launchpad_live.ex:88`); body-level root would scoop daisyUI chrome |
| Net-new Playwright spec reuses `assertAdminPolish({root:'[data-ck-root]', interactiveSelectors})` unchanged; warn mode this phase; not on HTTP-only smoke | Confident | `admin-polish.js:16-21` names this exact future use; `cohort_demo_smoke.sh:79-84` is curl-only |

### Theme + Reduced-Motion Rendering
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Both themes via interactive `data-theme` toggle on `.ck` root (e2e clicks it) | Likely | `admin-gallery.mjs:347-348` picker sets `data-theme`; `support/admin.js:57-63` click→assert |
| `reduce` + `prefers-color-scheme` fallback exercised via Playwright `emulateMedia`, not static panels | Likely | `admin-gallery-check.mjs:277-352` clicks for explicit theme, `emulateMedia` for media fallback; only `emulateMedia` triggers real `@media` block (gate 3) |

### CohortComponents Conventions
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| New primitives follow existing conventions exactly (attr/slot, `values:`, inline currentColor SVG `defp *_icon`, BEM, `--_local`); all `.ck`-scoped | Confident | `cohort_components.ex` (attrs 63/207, slots 85/172, icon dispatch 219-315); `cohort.css:136-155` `.ck`-scoped inheritance |
| Net-new claims confirmed: no `[data-theme]`, no `reduce` block today; literals to remove are `#fff`@404, rgba shadow/glow, legacy rem fonts 368/472/503 | Confident | `cohort.css:93,404,589` + grep |

## Corrections Made

No corrections — the maintainer confirmed all assumptions as presented ("Yes, lock them all"),
including the two Likely forks (CI lane placement; theme-toggle + `emulateMedia` rendering).

## External Research

None performed — codebase analysis was sufficient; all seams have working in-repo admin analogs
and the phase introduces no new dependencies.
