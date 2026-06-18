---
phase: 98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco
plan: 04
subsystem: testing
tags: [admin, validation, merge-gate, exunit, playwright, computed-style, a11y, motion, microcopy, phase-seal]

# Dependency graph
requires:
  - phase: 98-03
    provides: "Task-first IA (six-item nav), Overview GDS triage home, confirm_dialog/1 rewiring, §F off-voice microcopy replacements — the real migrated surfaces this plan asserts over"
  - phase: 98-02b
    provides: "Six surfaces migrated onto page/1 with caption/scope table markup — the §D/§A surfaces the new clauses scan"
  - phase: 98-01
    provides: "page/1 Level-3 scaffold + all Phase-98 generated CSS (scaffold §A, two-pane @1024, mobile-first §C stacked-table, motion catalog §B, :focus-visible/skip-link §D)"
  - phase: 97-04
    provides: "OVERLAP_ENFORCED true, ADMIN-02 priv byte-equality gate, the admin-polish.js { root, interactiveSelectors } seam this plan extends without flipping warn->fail"
provides:
  - "ExUnit (admin_design_system_validation_test.exs) asserts all unconditional §A/§B/§D/§E/§F merge-gates over the real migrated admin surfaces (4 -> 24 brandbook tests)"
  - "Five non-inferable computed-style Playwright backstops in admin-polish.js (two-pane band, stacked-card ::before attr resolution, reduced-motion un-frozen, dialog inert reset-on-reconnect, focus-visible-vs-pointer)"
  - "Lockstep screenshot literal bump (toHaveLength(22) -> toHaveLength(24)) + matching expectedScreenshots for the two net-new band/stacked viewport states"
  - ".rindle-admin-visually-hidden utility authored through the brandbook pipeline (carryover from 98-02b resolved)"
  - "Phase-98 sealed: both merge-gate homes now executable assertions over real surfaces"
affects: [phase-99, phase-100, phase-101, phase-102, cohort-restyle, vis-01-merge-gate]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Static/substring/render_to_string-grep gate clauses -> ExUnit; cascade/viewport/theme/focus-visible/::before-attr/dialog-mutation -> Playwright computed-style backstops (D-98-05 split line)"
    - "Offender-returning sub-assertions (return arrays, never throw; assertAdminPolish aggregates and throws once), admin-root-only against [data-rindle-admin-root]/DEFAULT_INTERACTIVE_SELECTORS"
    - "Reduced-motion read kept OUT of the frozen run (hard-fails if freezeMotion style present) so freezeMotion cannot mask a missing prefers-reduced-motion block (Pitfall 6)"
    - "Screenshot literal + expectedScreenshots bumped IN LOCKSTEP in one commit, counting only distinct net-new capture states (Pitfall 9)"

key-files:
  created: []
  modified:
    - "test/brandbook/admin_design_system_validation_test.exs - 20 new §A/§B/§D/§E/§F clauses (4 -> 24 brandbook tests)"
    - "examples/adoption_demo/e2e/support/admin-polish.js - five computed-style backstops + extended DEFAULT_INTERACTIVE_SELECTORS"
    - "examples/adoption_demo/e2e/admin-screenshots.spec.js - toHaveLength(22) -> 24 + expectedScreenshots band/stacked entries + dedicated backstop spec test"
    - "brandbook/src/admin-css-build.mjs - .rindle-admin-visually-hidden utility + requiredSelectors entry (carryover fix)"
    - "brandbook/tokens/rindle-admin.css + priv/static/rindle_admin/rindle-admin.css - regenerated, byte-identical (visually-hidden utility)"
    - ".planning/phases/.../deferred-items.md - carryover resolved + local Postgres constraint recorded"

key-decisions:
  - "N=2 net-new screenshot states (two-pane band @~900px + stacked-card viewport); the focus-visible/dialog-open/reduced-motion backstops RIDE existing captures, so toHaveLength bumped 22->24 not higher"
  - "Live adoption-demo-e2e Playwright lane is CI-enforced (merge-blocking adoption-demo-e2e job), NOT run locally — local Postgres was saturated (too_many_connections); backstop code is committed + statically validated; maintainer approved sealing with the live lane delegated to CI"
  - "No warn->fail flip and no Cohort generalization (Phase 102 boundary held) — new checks are admin-root-only; OVERLAP_ENFORCED unchanged"
  - ".rindle-admin-visually-hidden authored in the generator (not hand-edited generated CSS) per the generated-CSS boundary (D-98-12/Pitfall 2)"

patterns-established:
  - "Pattern 1: ExUnit/Playwright split line for merge-gates — static proofs in ExUnit, computed-style/cascade proofs as offender-returning Playwright backstops"
  - "Pattern 2: reduced-motion computed-style read MUST run un-frozen to avoid vacuous pass under freezeMotion"
  - "Pattern 3: screenshot count literal + expectedScreenshots array bumped together, counting only states needing a new capture"

requirements-completed: [UPLIFT-03, UPLIFT-04, UPLIFT-05, UPLIFT-06, UPLIFT-07, UPLIFT-08]

# Metrics
duration: 15min
completed: 2026-06-18
status: complete
---

# Phase 98 Plan 04: Gate Close-Out & Phase Seal Summary

**Both merge-gate homes now assert all six §A–§F gates over the real migrated admin surfaces: ExUnit grew 4 -> 24 brandbook clauses (static §A/§B/§D/§E/§F + contrast 58/58 + drift + byte-equality) and admin-polish.js gained five non-inferable computed-style Playwright backstops with a lockstep 22 -> 24 screenshot bump; live lane delegated to merge-blocking CI.**

## Performance

- **Duration:** ~15 min (execution ~13 min across the four commits; plus the blocking human-verify checkpoint)
- **Started:** 2026-06-18T02:33:14-04:00 (first commit b637710)
- **Completed:** 2026-06-18 (checkpoint approved; phase sealed)
- **Tasks:** 2 auto tasks + 1 carryover fix + housekeeping + Task 3 (blocking human-verify, approved)
- **Files modified:** 8

## Accomplishments

- **ExUnit gate extended 4 -> 24 brandbook tests** — every unconditional §A/§B/§D/§E/§F clause now executes over the real migrated `lib/rindle/admin/*` surfaces (page/1 slot order, no page-local `display:grid`, `--rindle-shadow-card` consumed; no layout-reflow transitions / no `transition:all`; server-owned `aria-pressed` dead markup, skip-link -> `#rindle-admin-main`, `live_indicator` role=status, table caption/scope, visually-hidden utility; six task-first nav labels in order, Overview triage DOM order, needs-attention deep-links, affirmative all-clear; denylist scan, six off-voice replacements, `{Verb} this {noun}?` confirm headings).
- **Five computed-style Playwright backstops** landed in `admin-polish.js` (offender-returning, admin-root-only): two-pane track count + 760–1023px band reconciliation; stacked-card `<td>::before content:attr(data-label)` resolution + display flip at 759/761 and 1023/1025; reduced-motion `transitionDuration: 0s` read **un-frozen** (Pitfall 6); dialog `inert`+`aria-hidden` open/close + survives-reconnect (D-98-11 landmine); `:focus-visible`-vs-pointer ring differentiation.
- **Lockstep screenshot bump** — `toHaveLength(22) -> toHaveLength(24)` and `expectedScreenshots` updated together for the two net-new band/stacked viewport states (Pitfall 9, D-98-06). N=2 because the focus-visible/dialog-open/reduced-motion backstops ride existing captures.
- **98-02b carryover resolved** — `.rindle-admin-visually-hidden` utility authored through the full brandbook pipeline (`admin-css-build.mjs` -> regen -> contrast 58/58 -> gallery-check -> `sync-admin-css.mjs`, byte-identical priv copy), added to `requiredSelectors`, asserted by a new §D ExUnit clause; the STATE blocker is cleared.
- **Phase 102 boundary held** — no warn->fail flip, no Cohort generalization; `OVERLAP_ENFORCED` unchanged.

## Task Commits

1. **Carryover: author `.rindle-admin-visually-hidden` utility through the brandbook pipeline** - `b637710` (fix)
2. **Task 1: assert all unconditional §A/§B/§D/§E/§F merge-gates over real surfaces (4 -> 24 brandbook tests)** - `6bb5228` (test)
3. **Task 2: add five computed-style backstops to admin-polish.js + lockstep 22 -> 24 bump** - `b8e1c09` (test)
4. **Housekeeping: clear visually-hidden carryover in deferred-items/STATE, note local e2e DB constraint** - `99d772e` (docs)

**Plan metadata:** this commit (docs: complete 98-04 plan — SUMMARY + STATE + ROADMAP + REQUIREMENTS)

## Files Created/Modified

- `test/brandbook/admin_design_system_validation_test.exs` - +20 §A/§B/§D/§E/§F clauses over real surfaces (now 24 brandbook tests)
- `examples/adoption_demo/e2e/support/admin-polish.js` - five computed-style backstops (`assertTwoPaneBand`, `assertStackedCard`, `assertReducedMotion`, `assertDialogInert`, `assertFocusVisibleVsPointer`); extended `DEFAULT_INTERACTIVE_SELECTORS`; all in `module.exports`
- `examples/adoption_demo/e2e/admin-screenshots.spec.js` - `toHaveLength(24)` + `expectedScreenshots` band/stacked entries + dedicated backstop spec test
- `brandbook/src/admin-css-build.mjs` - `.rindle-admin-visually-hidden` utility + `requiredSelectors` entry
- `brandbook/tokens/rindle-admin.css` - regenerated (visually-hidden utility)
- `priv/static/rindle_admin/rindle-admin.css` - synced byte-identical to brandbook
- `.planning/phases/98-.../deferred-items.md` - carryover marked RESOLVED + local Postgres constraint recorded

## Decisions Made

- **Live Playwright lane is CI-enforced, not locally run.** The local `adoption-demo-e2e` lane's `global-setup.js` runs `mix ecto.create`, which failed with `FATAL 53300 too_many_connections` (shared dev DB at ~86/100, idle backends leaked by prior `mix test` runs — the same pre-existing local Postgres noise recorded in the 98-01/98-03 summaries). Per the maintainer's "approved" at the Task 3 checkpoint, the phase is sealed with the live five-backstop run delegated to the merge-blocking CI `adoption-demo-e2e` job (clean DB). The backstop CODE is committed and statically validated (`node --check` clean on both files; lockstep 24==24; no warn->fail flip / no Cohort generalization in `git diff`).
- **N=2 net-new screenshot states.** Only the two-pane band (~900px) and the stacked-card viewport need new captures; the focus-visible/dialog-open/reduced-motion backstops ride existing captures, so `toHaveLength` went 22 -> 24 (not higher).
- **Visually-hidden utility authored in the generator**, not by hand-editing generated CSS — preserves the generated-CSS boundary (D-98-12 / Pitfall 2).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Authored `.rindle-admin-visually-hidden` utility (98-02b carryover)**
- **Found during:** Carryover reconciliation before Task 1 (filed by 98-02b in deferred-items.md)
- **Issue:** Six migrated surfaces ship `<caption class="rindle-admin-visually-hidden">` (D-98-08 / UI-SPEC §D), but P1's generator never authored the `.rindle-admin-visually-hidden` selector, so captions rendered visibly at ≥760px — an a11y/visual defect blocking a green §D clause.
- **Fix:** Added the clip/clip-path recipe to `admin-css-build.mjs`, registered it in `requiredSelectors`, regenerated through the full pipeline (contrast 58/58, gallery-check 18 screenshots, byte-identical priv sync), and added a §D ExUnit clause asserting the utility exists.
- **Files modified:** `brandbook/src/admin-css-build.mjs`, `brandbook/tokens/rindle-admin.css`, `priv/static/rindle_admin/rindle-admin.css`, `test/brandbook/admin_design_system_validation_test.exs`
- **Verification:** Contrast 58/58; brandbook/priv byte-identical; new §D clause green; STATE blocker cleared
- **Committed in:** `b637710`

---

**Total deviations:** 1 auto-fixed (1 missing critical). The fix was a documented carryover from 98-02b and is in-scope for the P4 seal (the deferred item explicitly suggested "P1/P4 fix").
**Impact on plan:** Necessary for a green §D gate and correct a11y. No scope creep — no production code/CSS beyond the generator utility the deferred item called for; P4 otherwise authored assertions only.

## Issues Encountered

- **Local Postgres saturation blocked the live Playwright lane AND a fresh local ExUnit re-run.** During this continuation, `mix test test/brandbook/admin_design_system_validation_test.exs` excluded all 24 tests (`0 tests, 0 failures (24 excluded)`) because the DB connection pool failed at startup (`FATAL 53300 too_many_connections`; ~86/100 connections, mostly idle leaks from prior runs). This is the documented pre-existing environment constraint, not a code regression: the file structurally contains exactly 24 `test` clauses, and the 24/0 green state is recorded in commit `6bb5228`'s body ("24 brandbook tests, 74 admin+brandbook tests, 0 failures"). Terminating the shared DB's idle backends was out of scope (and declined), consistent with the resume guidance to delegate the live lane to CI rather than fight the local DB. The merge-blocking CI `adoption-demo-e2e` + `coveralls` jobs run on a clean DB and are the authoritative gate.

## User Setup Required

None - no external service configuration required.

## CI-Delegated Verification Note

The live five-backstop Playwright run (two-pane band @~900px, stacked-card `::before` @759/761, reduced-motion 0s un-frozen, dialog inert reset-on-reconnect, focus-visible-vs-pointer) and the full `mix test` run are **CI-enforced** via the merge-blocking `adoption-demo-e2e` and `coveralls` jobs (`ci.yml` is the source of truth), not run locally during this seal due to the shared-DB constraint above. The maintainer approved sealing on this basis at the Task 3 blocking human-verify checkpoint.

## Pre-existing Open Items (carried, NOT introduced here)

- The `adoption-demo-e2e` lane remains RED on a pre-existing `assertFocusVisibleTokens` host-cascade defect (adoption_demo daisyUI `.menu{outline:none}`/3px beats the shipped rindle 2px `#123A35` focus token — host-app CSS layering, not the scoped rindle-admin CSS). Deferred per maintainer Option A (97-04) to a dedicated follow-up; logged in 97 deferred-items.md and STATE blockers. This is a host-cascade issue independent of the five new backstops added here.

## Next Phase Readiness

- **Phase 98 sealed.** Both merge-gate homes assert all six §A–§F gates over the real surfaces; UPLIFT-03..08 complete. Track A admin DS uplift (95 L1 -> 97 L2 -> 98 L3) is finished.
- Next per ROADMAP: Track B Cohort inner-page migrations (99 small-7 pages, 100 /upload, 101 daisyUI retirement) compose the Phase-96 `.ck-*` primitives, then re-converge in Phase 102 (VIS-01 single merge-blocking gate generalized over admin + Cohort).
- **Blocker to clear before/at 102:** the pre-existing `assertFocusVisibleTokens` host-cascade red lane (above) keeps `adoption-demo-e2e` red until its dedicated follow-up lands.

---
*Phase: 98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco*
*Completed: 2026-06-18*
