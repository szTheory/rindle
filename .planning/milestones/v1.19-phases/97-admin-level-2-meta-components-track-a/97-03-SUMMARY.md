---
phase: 97-admin-level-2-meta-components-track-a
plan: 03
subsystem: ui
tags: [design-system, rindle-admin, admin-polish, rhythm, no-horizontal-scroll, meta-components, playwright, offender-returning]

# Dependency graph
requires:
  - phase: 97-admin-level-2-meta-components-track-a
    plan: 02
    provides: 8 data-rindle-admin-meta cohesion panels in the brandbook admin gallery + the sticky data-table's data-rindle-admin-scroll-region opt-in marker
  - phase: 94-foundation-token-pipeline
    provides: assertAdminPolish offender-returning sub-assertion contract over { root, interactiveSelectors }; SUBPIXEL_TOLERANCE / CLIP_TOLERANCE constants; OVERLAP_ENFORCED warn-then-tighten convention
provides:
  - assertConsistentRhythm (intra-unit 4px-grid spacing check; offender-returning, never throws) wired into assertAdminPolish + exported
  - assertNoHorizontalScroll (per-meta-unit-root horizontal-overflow check honoring data-rindle-admin-scroll-region; offender-returning, never throws) wired into assertAdminPolish + exported
  - assertMetaCohesion in admin-gallery-check.mjs — runs both checks over the real gallery meta units with a vacuous-pass guard; reports zero offenders
affects: [97-04 OVERLAP_ENFORCED flip + ExUnit 18-screenshot literal bump + priv sync drift gate]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Two new offender-returning sub-assertions follow the assertNoClippedText shape: page.evaluate returns string[] offenders, assertAdminPolish.run() aggregates into a single throw per state"
    - "Rhythm walk is scoped to elements carrying a rindle-admin-* class (design-system-owned box metrics) — native form-control UA internals + bare typographic UA margins are excluded as Pitfall-1 false positives"
    - "Per-meta-unit no-h-scroll skips any unit under [data-rindle-admin-scroll-region] (explicit opt-in, D-94-07, never auto-detected)"
    - "Gallery-check loads the CommonJS polish checks via the SAME adoptionRequire(createRequire over examples/adoption_demo) already used for playwright; assertMetaCohesion guards unit count before trusting a zero-offender result"

key-files:
  created: []
  modified:
    - examples/adoption_demo/e2e/support/admin-polish.js
    - brandbook/src/admin-gallery-check.mjs

key-decisions:
  - "Rhythm check inspects only rindle-admin-*-classed elements: running it over real gallery units surfaced UA-default box metrics (option 1-2px padding, checkbox 3px margin, bare <p>/<h2> 17px/21.165px em-margins) as false positives the generated CSS never sets — Pitfall 1's documented warning sign that the walk is too wide, not the CSS off-grid"
  - "Both new checks feed violations (hard), not warnOnly — the single-aggregated-throw-per-state contract; only OVERLAP_ENFORCED stays warn-only (false) this plan, flipped in 97-04 after a green cycle (D-97-11)"
  - "Checks run over the gallery (the only surface where [data-rindle-admin-meta] exists) under the light theme — meta units render identically across themes; the assertAdminPolish wiring is a deliberate no-op over live LiveView pages lacking meta markers, preserving the future live-page seam"

patterns-established:
  - "assertMetaCohesion vacuous-pass guard: assert the meta-unit count equals META_COMPONENTS.length before trusting a zero-offender pass, so a selector mismatch fails loudly instead of silently passing"

requirements-completed: [UPLIFT-02]

# Metrics
duration: 6min
completed: 2026-06-17
---

# Phase 97 Plan 03: Rhythm + No-Horizontal-Scroll Cohesion Checks Summary

**Two new offender-returning sub-assertions prove Level-2 cohesion — `assertConsistentRhythm` (intra-unit gaps/margins/paddings resolve to the 4px grid ∪ {12,44}, scoped to design-system-styled elements) and `assertNoHorizontalScroll` (per-meta-unit roots never overflow horizontally, sticky table excepted via its explicit marker) — both wired into `assertAdminPolish` as hard checks and run over the real `[data-rindle-admin-meta]` gallery units with zero offenders; `OVERLAP_ENFORCED` stays `false` for the 97-04 flip.**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-06-17T21:21:33Z
- **Completed:** 2026-06-17T21:27:37Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Added `assertConsistentRhythm(page, root)` to `admin-polish.js`: walks each `[data-rindle-admin-meta]` subtree, checks `rowGap`/`columnGap`/`marginTop`/`marginBottom`/`paddingTop`/`paddingBottom`/`paddingLeft`/`paddingRight` against the allowed set `{4,8,16,24,32,48,64}` ∪ documented exceptions `{12,44}` with `±SUBPIXEL_TOLERANCE`; treats `0px` as always valid; excludes sizing/`line-height`; returns offenders `"{slug} {tag} {prop}={px}px off-grid"`; never throws.
- Added `assertNoHorizontalScroll(page, root)`: iterates each `[data-rindle-admin-meta]` unit root, skips any under `[data-rindle-admin-scroll-region]` (explicit opt-in, D-94-07), flags `scrollWidth > clientWidth + CLIP_TOLERANCE`, returns offenders `"{slug} x(sw>cw)"`; never throws. This is the per-unit counterpart to the page-level no-h-scroll helper in `support/admin.js` (NOT duplicated).
- Wired both into `assertAdminPolish` via `run("consistentRhythm", "rhythm", …)` and `run("noHorizontalScroll", "h-scroll", …)` as hard (non-`warnOnly`) checks feeding `violations`; exported both from `module.exports`; `OVERLAP_ENFORCED` left at `false`.
- Added `assertMetaCohesion` to `admin-gallery-check.mjs`: loads both checks via the same `adoptionRequire` used for `playwright`, guards that exactly `META_COMPONENTS.length` meta units exist under the gallery root (no vacuous pass), then asserts each check returns zero offenders. Invoked after `assertMetaUnits` under the light theme.
- `node brandbook/src/admin-gallery-check.mjs` exits 0 — `admin gallery check passed - 18 screenshots written` — with both checks reporting zero offenders over the real gallery meta units.

## Task Commits

1. **Task 1: Add assertConsistentRhythm + assertNoHorizontalScroll, wire into assertAdminPolish** - `0feba56` (feat)
2. **[Rule 1] Scope assertConsistentRhythm to design-system-styled elements** - `7979946` (fix)
3. **Task 2: Run rhythm + no-h-scroll checks over the gallery meta units** - `a6f3c1b` (feat)

## Files Created/Modified
- `examples/adoption_demo/e2e/support/admin-polish.js` - Added the two offender-returning sub-assertions (Check 7 rhythm, Check 8 no-h-scroll), wired both into `assertAdminPolish` as hard checks, exported both; `OVERLAP_ENFORCED` unchanged (`false`).
- `brandbook/src/admin-gallery-check.mjs` - Imported both checks via `adoptionRequire`; added `assertMetaCohesion` (vacuous-pass guard + zero-offender asserts) invoked under the light theme after `assertMetaUnits`.

## Decisions Made
- **Rhythm walk scoped to `rindle-admin-*`-classed elements:** the first real-data run over the gallery surfaced UA-stylesheet box metrics as offenders — an `<option>`'s 1–2px padding, a checkbox `<input>`'s 3px margin, and bare `<p>`/`<h2>` em-margins (17px / 21.165px). The generated `rindle-admin.css` never sets those; they are browser defaults. Per Pitfall 1 ("offenders all at UA-default values mean the walk is too wide, not the CSS off-grid"), the check now inspects only elements the design system actually styles. This keeps the gate meaningful (it still catches any off-grid spacing the generator emits on a `rindle-admin-*` element) while eliminating the false positives.
- **Both checks are hard (non-warnOnly):** they feed `violations`, preserving the single-aggregated-throw-per-state contract. Only overlap stays warn-only this plan; the `OVERLAP_ENFORCED` flip is 97-04's job after a green warn cycle (D-97-11).
- **Run over the gallery, no-op over live pages:** `[data-rindle-admin-meta]` units exist only in the brandbook gallery, so the gallery-check is where the checks find real offenders. The `assertAdminPolish` wiring is a deliberate no-op over the live adoption_demo LiveView pages (no meta markers), preserving the future live-page seam.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Scoped `assertConsistentRhythm` to design-system-styled elements**
- **Found during:** Task 2 (first run of the rhythm check over the real gallery meta units)
- **Issue:** The plan's reference algorithm walks every descendant of a meta unit. Over real markup this surfaced 20 false-positive offenders, all at user-agent-stylesheet default values on elements the generated CSS never spaces: `<option>` UA padding (1–2px), checkbox `<input>` UA margin (3px), and bare `<p>`/`<h2>` UA em-margins (17px, 21.165px). This is exactly the Pitfall 1 warning sign ("offenders all at UA-default values mean the walk is too wide, not the CSS off-grid").
- **Fix:** Added a `styled(el)` predicate that only inspects elements carrying a `rindle-admin-*` class — the surface whose box metrics the generated CSS owns. The offender string format, property list, allowed set, tolerance, `0px`-valid rule, and never-throw contract are all unchanged; the gate still catches any off-grid token spacing the generator emits.
- **Files modified:** `examples/adoption_demo/e2e/support/admin-polish.js`
- **Commit:** `7979946`

## Issues Encountered

The first gallery-check run threw on 20 rhythm offenders (documented above as the Rule 1 deviation). After scoping the walk to design-system-styled elements, the check passed on the next run — zero rhythm offenders, zero no-h-scroll offenders (the sticky data-table correctly opted out via its `data-rindle-admin-scroll-region` marker), 18 screenshots written. The regenerated `index.html` / `rindle-admin.css` are byte-reproducible (this plan touches no CSS — no drift).

## Known Stubs

None. Both checks measure real rendered computed style over real gallery markup; the gallery-check guards against a vacuous pass by asserting the meta-unit count before trusting the zero-offender result.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- `assertConsistentRhythm` + `assertNoHorizontalScroll` are exported and wired into `assertAdminPolish` (hard checks) and proven green over the gallery meta units. SC2 (rhythm + no-horizontal-scroll) is met.
- `OVERLAP_ENFORCED` is still `false` — 97-04 flips it to `true` after this green warn cycle (D-97-11), alongside the ExUnit `18 screenshots` pinned-literal bump and the `priv` ↔ `brandbook` CSS sync + drift gate (both carried, unchanged by this plan).

## Self-Check: PASSED

- Files verified present: `examples/adoption_demo/e2e/support/admin-polish.js`, `brandbook/src/admin-gallery-check.mjs`, `97-03-SUMMARY.md`.
- Commits verified in git log: `0feba56` (Task 1), `7979946` (Rule 1 fix), `a6f3c1b` (Task 2).
- `node -e "require('./examples/adoption_demo/e2e/support/admin-polish.js')"` loads clean and exports both functions with `OVERLAP_ENFORCED === false`; `node brandbook/src/admin-gallery-check.mjs` exits 0 with `admin gallery check passed - 18 screenshots written`.

---
*Phase: 97-admin-level-2-meta-components-track-a*
*Completed: 2026-06-17*
