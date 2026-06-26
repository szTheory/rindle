---
phase: 96-cohort-component-layer-dark-reduced-motion-contract-track-b
plan: 01
subsystem: ui
tags: [cohort, cohort-css, dark-theme, data-theme, prefers-reduced-motion, design-tokens, css-custom-properties, wcag, elevation]

# Dependency graph
requires:
  - phase: 94-foundation-token-pipeline-ci-gate-new-token-categories
    provides: admin elevation/shadow + dark token philosophy (PIPE-02) mirrored into Cohort's own vocabulary; admin-polish.js [data-ck-root] seam (D-94-07)
provides:
  - "cohort.css [data-theme=\"dark\"] explicit switchable theme contract, distinct from the prefers-color-scheme auto fallback"
  - "Per-theme color-scheme (light/dark/auto-fallback) so native controls theme correctly"
  - "--ck-surface-overlay elevation step in both themes (lightness ladder bg -> surface-2 -> surface -> overlay)"
  - "Per-theme bare-channel --ck-shadow-ink / --ck-glow-ink base tokens; --ck-shadow-sm/md/lg + --ck-bg-glow derive via one shared rgb(var(--ck-*-ink) / <alpha>) formula"
  - "Net-new @media (prefers-reduced-motion: reduce) block scoped to .ck * (the only !important site in the file)"
  - "Color-literal-free rule bodies — all hex/rgb/rgba literals confined to :root / [data-theme] token blocks"
affects: [96-02, 96-03, 96-04, cohort-contrast.mjs, cohort-design-system-data.mjs, styleguide_live.ex, cohort_components.ex]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Theme contract shape (D-96-11): :root, [data-theme=\"light\"] + [data-theme=\"dark\"] + @media (prefers-color-scheme: dark) { :root:not([data-theme]) }"
    - "Elevation = lightness, shadow = derived ink (D-96-12): per-theme bare-channel ink token feeds one shared rgb(var(--ink) / <alpha>) shadow/glow formula"
    - "Reduced-motion via .001ms not 0 (D-96-13) so transitionend/animationend still fire"

key-files:
  created: []
  modified:
    - examples/adoption_demo/priv/static/assets/cohort.css

key-decisions:
  - "Light --ck-surface-overlay = #f4faf7 (faint emerald tint, separated/elevated above #ffffff since white cannot go lighter)"
  - "Dark --ck-surface-overlay = #16261f (lighter than --ck-surface #111d18: elevation by lightness, not drop shadow)"
  - "Light shadow ink = 15 27 23 (the channel already baked into the light rgba shadows); dark shadow ink = 0 0 0"
  - "Light glow ink = 5 150 105; dark glow ink = 16 185 129 (the channels already baked into --ck-bg-glow per theme)"
  - "Font-literal folding: 0.875/0.78/0.72rem -> --ck-step--1 (0.8125rem nearest); 0.95rem -> --ck-step-0 (1rem nearest)"

patterns-established:
  - "Controlled, comment-bannered dark-token duplication: [data-theme=\"dark\"] and the :root:not([data-theme]) media fallback carry byte-equal dark values; Plan 04's D-96-18 parity check enforces no drift"
  - "Single literal sink: color literals live only inside :root / [data-theme] token blocks; rule bodies stay token-only"

requirements-completed: [COHORT-06]

# Metrics
duration: 3min
completed: 2026-06-17
---

# Phase 96 Plan 01: cohort.css Dark [data-theme] Contract + Reduced-Motion Block Summary

**Net-new explicit/switchable dark `[data-theme]` contract, lightness-based surface-overlay ladder, per-theme shadow/glow ink tokens, per-theme `color-scheme`, and a `prefers-reduced-motion: reduce` block in the hand-authored `cohort.css` — with every color literal moved out of rule bodies into the `:root`/`[data-theme]` token sink.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-06-17T18:31:36Z
- **Completed:** 2026-06-17T18:34:47Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Promoted the light `:root` token block to a combined `:root, [data-theme="light"]` selector with `color-scheme: light`, and authored a distinct, switchable `[data-theme="dark"]` set with `color-scheme: dark`.
- Kept `@media (prefers-color-scheme: dark)` as the auto fallback (re-scoped to `:root:not([data-theme])`, banner-commented as the controlled duplication parity-checked by D-96-18), so explicit theme selection and OS preference no longer collide.
- Added the `--ck-surface-overlay` elevation step to both themes and introduced per-theme bare-channel `--ck-shadow-ink` / `--ck-glow-ink` tokens; `--ck-shadow-sm/md/lg` and `--ck-bg-glow` now use one shared `rgb(var(--ck-*-ink) / <alpha>)` formula per token so only the ink flips per theme.
- Authored the net-new `@media (prefers-reduced-motion: reduce)` block (`.ck *`, `.001ms` durations, `.ck-reveal` settled) — the only `!important` site in the file — while leaving the existing `no-preference` reveal block untouched.
- Removed every rule-body color/font literal: `#fff` -> `var(--ck-on-brand)`, usage-site `rem` font sizes folded onto the nearest `--ck-step-*`; a brace-depth scan confirms color literals now live only in token blocks.
- No existing `--ck-*` palette hex value changed (D-96-23).

## Task Commits

Each task was committed atomically:

1. **Task 1: Promote dark to a [data-theme] contract + surface ladder + shadow-ink tokens + color-scheme** - `9ecc375` (feat)
2. **Task 2: Author the prefers-reduced-motion reduce block + remove rule-body color/font literals** - `aa13cee` (feat)

**Plan metadata:** (this commit) (docs: complete plan)

## Files Created/Modified
- `examples/adoption_demo/priv/static/assets/cohort.css` - Theme-contract restructure (light combined selector, explicit dark attribute set, banner-commented auto-fallback), per-theme `color-scheme`, `--ck-surface-overlay` ladder step, per-theme `--ck-shadow-ink`/`--ck-glow-ink` base tokens with shared shadow/glow formulas, net-new reduced-motion `reduce` block, and rule-body literal removals.

## Decisions Made
- **Light overlay value `#f4faf7`:** `--ck-surface` is `#ffffff` and cannot go lighter, so the overlay step uses a faint emerald tint that is visually separated/elevated above plain white while staying in the light lightness ladder.
- **Dark overlay value `#16261f`:** chosen lighter than `--ck-surface` `#111d18` so elevation reads as lightness, never as a re-used light drop-shadow (D-96-12 anti-inversion guard).
- **Ink channels reuse the values already baked into the prior rgba shadows/glows** (light shadow `15 27 23`, dark shadow `0 0 0`, light glow `5 150 105`, dark glow `16 185 129`), so the structural refactor changes derivation mechanism without changing rendered shadow/glow color.
- **Font-literal folding by nearest step:** `0.875` / `0.78` / `0.72rem` -> `--ck-step--1` (0.8125rem); `0.95rem` -> `--ck-step-0` (1rem).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- **Default-env `mix compile --warnings-as-errors` fails on pre-existing Mox warnings.** The plan's verification step (`cd examples/adoption_demo && mix compile --warnings-as-errors`) exits non-zero in the default `:dev` env because `mox` is declared `only: :test` in `mix.exs`; the failing warnings (`AdoptionDemo.MuxCassette` referencing `Mox.*`) are entirely unrelated to the static `cohort.css` change and pre-date this plan. This is out-of-scope per the SCOPE BOUNDARY (pre-existing failure in an unrelated file) and is logged to `deferred-items.md`. The plan note explicitly states this compile only proves "no template breakage" since the CSS is static; I verified that directly by running `MIX_ENV=test mix compile --warnings-as-errors`, which exits 0 — confirming the `cohort.css` edits introduce no template/compile breakage. The primary CSS gates are the grep checks, all of which pass.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None - this plan authored CSS token structure and selectors only; no data-wired components.

## Verification Results

All UI-SPEC acceptance gates for this plan pass:

- **Gate 2 (theme contract):** `[data-theme="dark"]` present (3 occurrences across explicit set, banner comment, and fallback note); `[data-theme="light"]` combined light selector + `:root:not([data-theme])` auto-fallback both exist; `color-scheme` set 6 times (≥3 required: light, dark, auto-fallback).
- **Gate 3 (reduced motion):** exactly 1 `prefers-reduced-motion: reduce` block; `.001ms` appears in both animation + transition duration; `.ck-reveal` resolves to `opacity: 1` / `transform: none`; the existing `no-preference` block is preserved (1).
- **Gate 4 (grep-clean tokens):** no `#fff` in any rule body (only `#ffffff` token VALUES remain inside the token block); `var(--ck-on-brand)` count = 2; zero `font-size: 0.(72|78|875|95)rem` usage-site literals; a brace-depth literal scan reports CLEAN (no hex/rgb/rgba/hsl outside token blocks).
- **Ink/overlay tokens:** `--ck-shadow-ink` / `--ck-glow-ink` / `--ck-surface-overlay` defined per theme and referenced in the shared `rgb(var(--ck-*-ink) / <alpha>)` formulas.
- **`!important` discipline:** exactly 3 declaration-level `!important`, all inside the `reduce` block (a 4th raw grep hit is the explanatory comment, not a declaration).
- **Palette unchanged (D-96-23):** `--ck-faint: #8a9a92` (1) and `--ck-bg: #f7f8f6` (1) intact.
- **No template breakage:** `MIX_ENV=test mix compile --warnings-as-errors` exits 0.

## Next Phase Readiness
- The foundation tokens and selectors every later Phase-96 plan depends on now exist: the `[data-theme]` contract (consumed by `StyleguideLive`'s theme toggle and `cohort-contrast.mjs` per-theme resolver), the overlay/ink tokens (consumed by the new primitives), and the literal-clean baseline (mechanically enforced by Plan 04's D-96-20 scanner + D-96-18 parity check).
- The dark `[data-theme="dark"]` block and the `:root:not([data-theme])` fallback carry byte-equal values; Plan 04's parity check is the durable guard against future drift.
- No blockers.

## Self-Check: PASSED

- FOUND: `examples/adoption_demo/priv/static/assets/cohort.css`
- FOUND: `.planning/phases/96-cohort-component-layer-dark-reduced-motion-contract-track-b/96-01-SUMMARY.md`
- FOUND commit: `9ecc375` (Task 1)
- FOUND commit: `aa13cee` (Task 2)

---
*Phase: 96-cohort-component-layer-dark-reduced-motion-contract-track-b*
*Completed: 2026-06-17*
