---
phase: 94-foundation-token-pipeline-ci-gate-new-token-categories
plan: 03
subsystem: brandbook-design-tokens
tags: [brandbook, design-tokens, css-pipeline, node, generator, wcag-contrast, motion, elevation, fluid-type, parity]

# Dependency graph
requires:
  - phase: 94-01
    provides: drift-free token->CSS baseline + sync-admin-css.mjs single mirror mechanism
provides:
  - Four new token categories in tokens.json (extended motion easings, dark elevation/shadow ladder, fluid type+space + named breakpoints, differentiated dark status surfaces)
  - admin-css-build.mjs emit loops + 3-touchpoint parity registration (exact / requiredMotionUses / requiredTokenUses) for every new category
  - Widened WCAG gate (CONSOLE_CONTRAST_PAIRS + tokens.json contrast_pairs) covering 6 dark-status pairs + 3 elevation dark-text pairs
  - Regenerated + byte-identical rindle-admin.css (both copies)
affects: [94-04, 95, 96, 97, 98, 99, 100, 101, 102, token-pipeline, admin-design-system]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "3-touchpoint category plug-in (D-94-08): tokens.json source object -> admin-css-build emit loop -> parity registration (exact()/requiredMotionUses/requiredTokenUses) so omission OR non-use is a hard generator self-check failure"
    - "Emitted-AND-used enforcement: every new --rindle-* var added to requiredTokenUses is genuinely consumed by a rule (registration without use is itself a parity failure)"
    - "Dark elevation as surface-lightness tint (not inversion / not heavier shadow); shadow ladder reserved for overlay separation"
    - "Fluid display type/space via clamp() interpolating bp-sm..fixed-max so large viewports stay byte-identical to the fixed scale (D-94-09)"

key-files:
  created: []
  modified:
    - brandbook/tokens/tokens.json
    - brandbook/src/admin-css-build.mjs
    - brandbook/src/admin-design-system-data.mjs
    - brandbook/tokens/rindle-admin.css
    - priv/static/rindle_admin/rindle-admin.css
    - test/brandbook/admin_design_system_validation_test.exs

key-decisions:
  - "diagram kept OUT of MOTION_TOKENS (preserve existing emitted-but-unenforced asymmetry); only the 3 new easing presets join MOTION_TOKENS, each consumed by >=1 rule so requiredMotionUses passes"
  - "Elevation hexes added to color.raw (elevation-0..3) so the top-level elevation object derefs them AND contrast pairs resolve directly via resolve() (raw lookup); avoids the Pitfall-3 unknown-token failure for elevation-N"
  - "Differentiated dark status surfaces are a tokens.json value change only; the dark-status .map() in CONSOLE_CONTRAST_PAIRS needs zero structural change (bg token name unchanged)"
  - "admin-only scope held: no tokens-build.mjs change, no cohort.css authored; a --ck-* coherence note is deferred to Phase 96 (documented here, not written as a stylesheet)"

requirements-completed: [PIPE-02, VIS-01]

# Metrics
duration: 5min
completed: 2026-06-15
---

# Phase 94 Plan 03: Wire Four New Token Categories into tokens.json + Admin Generators Summary

**Added the four locked `94-UI-SPEC.md` token categories (3 motion easing presets, a 4-level dark elevation/shadow tint ladder, fluid display type + space with named breakpoints, and 6 differentiated dark status surfaces) to `tokens.json` and the admin `.mjs` generators using the 3-touchpoint plug-in pattern (D-94-08) — every category is emitted, consumed, and registered in the parity arrays so omission or non-use is a hard generator self-check failure; the widened WCAG gate is green (admin 44/44, base 47/47) and both committed CSS copies are byte-identical.**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-06-15T02:56:57Z
- **Completed:** 2026-06-15T03:01:44Z
- **Tasks:** 2
- **Files modified:** 6 (0 created, 6 modified)

## Accomplishments

- **tokens.json source objects (Touchpoint A):** added 6 differentiated dark status-surface raw hexes + 4 elevation raw hexes to `color.raw`; re-pointed the six `color.semantic.dark.status-*-surface` roles off the collapsed `{dark-surface}` onto their per-hue tints (stops the D-94-09 collapse); new top-level `elevation`, `space_fluid`, `breakpoint` objects; extended `shadow` with `raised`/`overlay`; `clamp` field on `hero/h1/h2/h3` display scale only (body/small/code stay fixed-px); 3 new motion easings; 9 new `contrast_pairs`.
- **Generator emit loops (Touchpoint B):** elevation (deref loop), shadow (single-line -> `Object.entries` loop), fluid display type (`--rindle-text-*-fluid`), fluid space (`--rindle-space-fluid-*`), named breakpoints (`--rindle-bp-*`). Motion easings flow through the existing motion loop with no new loop.
- **Parity registration (Touchpoint C):** updated the `exact(MOTION_TOKENS, ...)` literal in lockstep with the export; consumed all three new easings in real rules (`easing-standard` on shell default transition, `easing-decelerate` on drawer/dialog enter, `easing-accelerate` on toast exit) so `requiredMotionUses` passes; applied elevation tints to dark drawer/dialog/toast/nav and `shadow-raised`/`shadow-overlay` to overlays; added fluid display-heading utilities + fluid gutter/section on the shell + `bp-xl` max content measure; registered every new var in `requiredTokenUses`.
- **Regen + sync + gates:** generator parity self-check OK; `sync-admin-css.mjs` mirrored to `priv/`; both CSS copies byte-identical; `admin-contrast.mjs` 44/44 (the 6 dark-status ratios match UI-SPEC exactly: 8.84/6.86/7.79/7.21/8.05/7.28; elevation dark-text 15.54/13.83/11.79); base `contrast.mjs` 47/47; a second regen produces an empty diff (deterministic).
- **Verification:** `admin_design_system_validation_test.exs` green 4/4 (`--include integration`), including the byte-equality assertion between the two CSS copies and the forbidden-host-UI regex (no `tailwind`/`daisy`/`.dark`/etc. introduced).

## Task Commits

Each task was committed atomically:

1. **Task 1: Add four new category objects to tokens.json + extend MOTION_TOKENS and CONSOLE_CONTRAST_PAIRS** — `a7f5b85` (feat)
2. **Task 2: Emit categories from admin-css-build.mjs, register in parity arrays, regenerate + sync** — `50a4ee9` (feat)

## Files Modified

- `brandbook/tokens/tokens.json` — 10 new raw hexes (6 dark status-surface + 4 elevation); re-pointed 6 dark status roles; new `elevation`/`space_fluid`/`breakpoint` objects; extended `shadow` + `motion`; `clamp` on display type; 9 new `contrast_pairs`.
- `brandbook/src/admin-css-build.mjs` — new emit loops (elevation/shadow/fluid type/fluid space/breakpoints); `exact()` literal updated; 3 easings consumed; elevation tints + overlay shadows applied; fluid heading utilities; `requiredTokenUses` widened.
- `brandbook/src/admin-design-system-data.mjs` — `MOTION_TOKENS` gains 3 easings; `CONSOLE_CONTRAST_PAIRS` gains 3 elevation dark-text pairs (dark-status pairs differentiate via tokens.json value change, no structural edit).
- `brandbook/tokens/rindle-admin.css` + `priv/static/rindle_admin/rindle-admin.css` — regenerated, byte-identical.
- `test/brandbook/admin_design_system_validation_test.exs` — pinned contrast-pair counts updated (admin 41->44, base 38->47).

## Decisions Made

- **`diagram` stays out of `MOTION_TOKENS`** (the D-94-08-surfaced asymmetry): `diagram` is an emitted 600ms duration with no enforced consumer; that is the current contract and touching it is out of scope. Only the three new easing presets join `MOTION_TOKENS`, and each is consumed by at least one CSS rule so `requiredMotionUses` does not fail.
- **Elevation hexes live in `color.raw`** (`elevation-0..3`) so (a) the top-level `elevation` object derefs them and (b) the elevation `dark-text` contrast pairs resolve directly via `resolve()`'s raw lookup — sidestepping the Pitfall-3 "unknown token" failure that would occur if `elevation-N` existed only as a top-level object key the WCAG `resolve()` cannot see.
- **Differentiated dark status surfaces are a pure value change** in `tokens.json`; the dark-status `.map()` in `CONSOLE_CONTRAST_PAIRS` keeps its `bg: status-${state}-surface` shape and now resolves to distinct hexes under `theme:dark`.
- **`--ck-*` coherence note (D-94-06):** the parallel Cohort vocabulary (`--ck-elevation-*`, `--ck-motion-easing-*`, fluid `--ck-text-*`) is the Phase-96 hand-authored analog of these admin categories. No `cohort.css`, token file, or build step was authored here — admin generators only, per the scope fence.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Validation test pinned the contrast-pair counts**
- **Found during:** Task 2 (running the integration suite after regen)
- **Issue:** `admin_design_system_validation_test.exs` asserts exact totals `admin contrast: 41/41` and base `38/38`. Adding the new WCAG pairs (3 elevation dark-text in `CONSOLE_CONTRAST_PAIRS`; 9 in tokens.json `contrast_pairs`) moved the totals to 44 and 47, failing the assertion.
- **Fix:** Updated the two pinned counts to `44/44` (admin) and `47/47` (base). These pairs are the new coverage the plan requires, so the new totals are the correct contract.
- **Files modified:** `test/brandbook/admin_design_system_validation_test.exs`
- **Commit:** `50a4ee9`

## Authentication Gates

None — pure Node + file I/O; no secrets read (T-94-09 accept disposition holds).

## Threat Surface

No new threat surface beyond the plan's `<threat_model>`. The 3-touchpoint parity registration mitigates T-94-06 (silent omission), the widened contrast gate mitigates T-94-07 (sub-AA dark surface), and the raw-hex placement keeps both fg/bg resolvable, mitigating T-94-08 (Pitfall-3 unknown token). No network endpoints, auth paths, or schema changes introduced.

## Known Stubs

None — every emitted category is consumed by a real rule and registered in the parity arrays (registration-without-use is itself a hard failure, so no placeholder/unused vars exist).

## Issues Encountered

- The integration tests are `@moduletag :integration` (excluded by default); ran with `--include integration` to execute the byte-equality and contrast-count assertions, consistent with Plan 01's note. No code change required for that — it is the established way to run this suite.

## Next Phase Readiness

- The four token categories are live and parity-locked; Plan 04's `brandbook-tokens` CI gate (regen -> contrast -> gallery-check -> `git diff --exit-code`) can run red->green honestly against this tree — a fresh regen+sync is already an empty diff.
- Uplift phases 95-102 inherit the categories; Phase 96 hand-authors the `--ck-*` Cohort analogs (no shared build step).
- No blockers.

## Self-Check: PASSED

- FOUND: brandbook/tokens/tokens.json
- FOUND: brandbook/src/admin-css-build.mjs
- FOUND: brandbook/src/admin-design-system-data.mjs
- FOUND: brandbook/tokens/rindle-admin.css
- FOUND: priv/static/rindle_admin/rindle-admin.css
- FOUND: test/brandbook/admin_design_system_validation_test.exs
- FOUND: 94-03-SUMMARY.md
- FOUND commit: a7f5b85 (Task 1)
- FOUND commit: 50a4ee9 (Task 2)

---
*Phase: 94-foundation-token-pipeline-ci-gate-new-token-categories*
*Completed: 2026-06-15*
