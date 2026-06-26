---
phase: 99-cohort-page-migrations-the-small-7-track-b
plan: 01
subsystem: cohort-design-system
status: complete
tags: [cohort, design-system, css, hand-authored-css, scaffold, ck-page, e2e, exunit, frozen-contract]
requirements: [COHORT-01, COHORT-03, COHORT-04]
dependency_graph:
  requires:
    - "cohort.css .ck/.ck__wrap/.ck-hero base rules (Phase 96)"
    - "CohortComponents hero/1 idiom + .ck-* primitives (Phase 96 P02)"
    - "e2e/support/admin-polish.js assertAdminPolish({root, interactiveSelectors}) (Phase 94 P02)"
    - "--ck-code-bg/--ck-code-ink tokens (Phase 96 P01)"
  provides:
    - "ck_page/1 scaffold (the per-page .ck shell all 7 migrations compose)"
    - ".ck-output token-only surface for ops/account <pre> debug panels"
    - "e2e/cohort-pages.spec.js shared assertCohortPagePolish harness (warn mode)"
    - "cohort_migration_contract_test.exs shared frozen-contract + daisyUI-retirement helpers"
  affects:
    - "Phase 99 P2-P5 (each composes ck_page, adds one polish case + one contract test)"
tech_stack:
  added: []
  patterns:
    - "ck_page/1 = Cohort analog of Phase 98 page/1; flat-function CohortComponents idiom (D-96-09/14)"
    - "data-ck-root on the per-page .ck div, never <body> (D-96-05)"
    - "server-owned data-theme default light (D-96-07/16)"
    - "hand-authored token-only cohort.css rule, no generator (D-94-05/06, Pitfall 1)"
    - "assertAdminPolish reused UNCHANGED over [data-ck-root] in warn mode (D-96-06 seam)"
    - "daisyUI-retirement scan scoped to [data-ck-root] page-body slice (Pitfall 6)"
key_files:
  created:
    - examples/adoption_demo/e2e/cohort-pages.spec.js
    - examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs
  modified:
    - examples/adoption_demo/lib/adoption_demo_web/components/cohort_components.ex
    - examples/adoption_demo/priv/static/assets/cohort.css
decisions:
  - "ck_page/1 ends this plan UNUSED (no *_live.ex composes it); P2-P5 wire it"
  - ".ck-output padding uses existing --ck-3/--ck-4 space tokens (not the literal padding .ck-cred__value uses), keeping the rule body literal-free for the scanner"
  - "daisyUI-retirement scan scopes to the [data-ck-root] subtree slice so Layouts.app's own space-y-4 wrapper (kept until Phase 101) is not a false positive"
metrics:
  duration_min: 3
  tasks: 2
  files: 4
  completed: "2026-06-18"
---

# Phase 99 Plan 01: Cohort Wave-0 Enablers (ck_page scaffold, .ck-output, polish harness, contract module) Summary

Authored the four Wave-0 enablers all seven Cohort page migrations depend on: the `ck_page/1` `.ck`-shell scaffold (the Cohort analog of Phase 98's `page/1`), the single token-only `.ck-output` CSS rule for the `<pre>` debug panels, the shared `cohort-pages.spec.js` warn-mode polish harness (reusing `assertAdminPolish` UNCHANGED over `[data-ck-root]`), and the ExUnit frozen-contract / daisyUI-retirement contract module — all green against `/styleguide` and ready for P2–P5 to extend.

## What Was Built

### Task 1 — `ck_page/1` scaffold + `.ck-output` rule (commit 36685ef)
- **`ck_page/1`** in `cohort_components.ex` (placed after `hero/1`): renders `<div class="ck" data-ck-root data-theme={@theme} {@rest}>` → `<div class="ck__wrap">` → `<header class="ck-hero">` with optional `.ck-eyebrow`, required `.ck-hero__title`, optional `.ck-hero__lede` → `{render_slot(@inner_block)}`. Attrs: `:title` (required), `:eyebrow`/`:lede`/`:theme` (optional; `theme` defaults `"light"`, `values: ~w(light dark)`), `:rest` global; `slot :inner_block` required. HEEx `{...}`-only interpolation — no `raw/1`. `data-ck-root` is on the `.ck` div, never `<body>` (D-96-05, Pitfall 3). No `cohort_nav`/`cohort_footer` inside (page chrome stays in `Layouts.app`). Ends UNUSED.
- **`.ck-output`** in `cohort.css`: one `.ck`-scoped code/debug-panel surface mirroring the `.ck-cred__value` token set — `font-family: var(--ck-font-mono)`, `font-size: var(--ck-step--1)`, `color: var(--ck-code-ink)`, `background: var(--ck-code-bg)`, `border: 1px solid var(--ck-border)`, `border-radius: var(--ck-radius-sm)`, `padding: var(--ck-3) var(--ck-4)`, `overflow-x: auto`, `white-space: pre`. Zero hex/rgb/named-color or raw measure literals in the rule body. No new `--ck-*` token, no `tokens.json` change, no generator.

### Task 2 — polish harness + ExUnit contract module (commit 5f60ce8)
- **`e2e/cohort-pages.spec.js`**: exports `assertCohortPagePolish(page, {route, surface})` (goto → `waitForLiveSocket` → Pitfall-5 `[data-ck-root]` visibility guard → `assertAdminPolish` reused UNCHANGED over `[data-ck-root]`/`.ck-*` → warn-mode `reportPolish` that re-throws `ReferenceError`/`TypeError` but `console.warn`s the offender aggregate), plus `interactiveSelectors` (`.ck-btn`/`.ck-tab`/`.ck-input`/`.ck-select`) and `reportPolish`. One Wave-0 smoke test over `/styleguide`. `admin-polish.js` not edited (D-96-06).
- **`cohort_migration_contract_test.exs`**: `use AdoptionDemoWeb.ConnCase, async: true`. Shared helpers — `render_route/2` (`live/2` + `render/1`), `page_body/1` (slices to the `data-ck-root` subtree), `assert_frozen_contract/2` (selector survival + `data-ck-root` present + refute `raw(`), `assert_daisyui_retired/1` (refutes the retired daisyUI/Tailwind utility list scoped to the page body). Retired-class list kept as module data, not page-renderable prose. One `/styleguide` smoke test.

## Verification

- `node brandbook/src/cohort-contrast.mjs` → exit 0, 28/28 pairs pass (parity + literal scanner + contrast; no new token/pair).
- `MIX_ENV=test mix compile` → no errors for `cohort_components.ex` (pre-existing test-only Mox warnings filtered, per Phase-96 note).
- `mix test test/adoption_demo_web/live/cohort_migration_contract_test.exs` → 1 test, 0 failures.
- `node --check e2e/cohort-pages.spec.js` → exit 0 (valid JS).
- `grep "<.ck_page" lib/.../live/` → none (ck_page UNUSED).
- `git status --porcelain` empty for `admin-polish.js`, `tokens.json`; `data-ck-root` absent from `root.html.heex` (`<body>` clean).

## Deviations from Plan

None — plan executed exactly as written. (Note: `.ck-output` padding uses `var(--ck-3) var(--ck-4)` rather than copying `.ck-cred__value`'s literal `0.28rem 0.5rem` padding, because the plan requires the `.ck-output` rule body to be literal-free for the scanner — this is the plan's stated intent, not a deviation.)

## Known Stubs

None. `ck_page/1` is intentionally UNUSED and `.ck-output` intentionally has no consumer yet — both are Wave-0 enablers consumed by P2–P5 (ck_page composition) and P3 (`.ck-output` on ops/account `<pre>` panels), as the plan specifies. Not stubs (no empty/placeholder data flows to UI).

## Self-Check: PASSED

- FOUND: examples/adoption_demo/lib/adoption_demo_web/components/cohort_components.ex (ck_page/1)
- FOUND: examples/adoption_demo/priv/static/assets/cohort.css (.ck-output)
- FOUND: examples/adoption_demo/e2e/cohort-pages.spec.js
- FOUND: examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs
- FOUND commit: 36685ef (feat 99-01 ck_page + .ck-output)
- FOUND commit: 5f60ce8 (test 99-01 harness + contract module)
