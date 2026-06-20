---
phase: 98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco
plan: 01
subsystem: ui
tags: [admin, design-system, css, generated-css, scaffold, motion, responsive, focus-visible, phoenix-component, brandbook]

# Dependency graph
requires:
  - phase: 97-admin-level-2-meta-component-cohesion
    provides: "Level-2 meta-component generated CSS + admin-css-build.mjs requiredMetaSelectors fail-closed pattern this plan extends"
  - phase: 94-foundation-token-pipeline-ci-gate
    provides: "tokens.json motion/elevation/shadow/breakpoint/fluid categories + brandbook-tokens drift CI gate (regen -> contrast -> gallery -> sync -> empty diff) this plan rides"
provides:
  - "page/1 Level-3 page-composition scaffold (lib/rindle/admin/components.ex) with slots :summary/:filters/:work(required)/:aside/:actions + attr :state, existing-but-UNUSED"
  - "All Phase-98 generated CSS in admin-css-build.mjs: scaffold grid §A, two-pane @1024-only, mobile-first two-stop responsive §C, stacked-table ::before, motion catalog §B, :focus-visible + skip-link + dialog border §D"
  - "First consumer of var(--rindle-shadow-card) + extended fail-closed guards (requiredTokenUses + requiredSelectors)"
affects: [98-02a, 98-02b, 98-03, 98-04, admin-surface-migrations, admin-playwright-backstops]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Level-3 page scaffold: declare slots in canonical DOM order, render via render_slot, :state drives existing empty/error/loading primitives (no markup duplication), zero inline grid/measure"
    - "Mobile-first generated CSS with NEVER-CONFLATED min-width stops (760 = shell sidebar ONLY, 1024 = :aside two-pane ONLY)"
    - "gov.uk stacked label:value table cards driven purely by CSS off scope=col headers via td::before content:attr(data-label) (no markup fork, no column hiding)"

key-files:
  created: []
  modified:
    - lib/rindle/admin/components.ex
    - brandbook/src/admin-css-build.mjs
    - brandbook/tokens/rindle-admin.css
    - priv/static/rindle_admin/rindle-admin.css
    - brandbook/admin-gallery/index.html

key-decisions:
  - "Two-pane class chosen = .rindle-admin-page--two-pane on the scaffold root (added when :aside present) with the grid living on a .rindle-admin-page__panes container; SAME name used in Task 1 markup and Task 2 CSS"
  - "theme-picker option motion animates opacity+transform ONLY (not background-color/color) — GPU-only per §B and to keep the pressed-state computed background deterministic for the gallery-check snapshot"

patterns-established:
  - "Two-stop responsive discipline: each min-width block layers exactly one concern (480 filter 2-up, 760 shell sidebar + real table, 1024 :aside two-pane, 1280 max-width cap); sub-760 nav becomes sticky top bar with a 44px disclosure button"
  - "Fail-closed guard extension: any new structural selector + token use is added to requiredSelectors/requiredTokenUses so a dropped block hard-fails the generator (process.exit 1)"

requirements-completed: [UPLIFT-03, UPLIFT-04, UPLIFT-05, UPLIFT-06]

# Metrics
duration: 14min
completed: 2026-06-18
status: complete
---

# Phase 98 Plan 01: Level-3 Scaffold + All Phase-98 Generated CSS Summary

**Authored the `page/1` Level-3 composition scaffold and landed every Phase-98 generated-CSS block (two-pane grid, motion catalog, mobile-first responsive, stacked-table `::before`, `:focus-visible`/skip-link) through the single `admin-css-build.mjs` generator with byte-identical priv sync and extended fail-closed guards — `page/1` ends existing-but-unused so the six surface migrations and IA/microcopy edits in later plans touch markup/wiring only.**

## Performance

- **Duration:** ~14 min
- **Tasks:** 2 completed
- **Files modified:** 5 (1 Elixir component, 1 generator, 2 generated CSS copies, 1 gallery HTML)

## Accomplishments

- **Task 1 — `page/1` scaffold:** New function component in `lib/rindle/admin/components.ex` (placed after `table/1`) with slots `:summary` → `:filters` → `:work` (required) → `:aside` → `:actions` rendered in canonical DOM order, `attr :state :ok|:empty|:error|:loading` driving the existing `empty_state/1`/`error_state/1`/`loading_skeleton/1` primitives (no markup duplication), a `data-rindle-admin-root`/`-page`/`-state` seam, BEM slot subselectors, and `:work`+`:aside` wrapped in a `.rindle-admin-page__panes` container with a `.rindle-admin-page--two-pane` marker. Zero inline grid/measure (D-98-12). Omitting `:work` is a compile-time error (`slot :work, required: true`). Not referenced by any surface — ends UNUSED (D-98-01).
- **Task 2 — all Phase-98 generated CSS:** Authored as literal template-string blocks inside `admin-css-build.mjs` (the single source of CSS truth): scaffold grid + token-only hierarchy (`:summary` is the first consumer of `--rindle-shadow-card`), two-pane region (`minmax(0,1fr) minmax(320px,380px)` exclusively inside `@media (min-width:1024px)`), mobile-first two-stop responsive (480 filter 2-up, 760 shell-sidebar-switch ONLY + real `<table>`, 1024 `:aside` two-pane ONLY, 1280 max-width cap), gov.uk stacked-table cards (`td::before { content: attr(data-label) }`, sticky table keeps `overflow-x` at all widths), motion catalog with enumerated `opacity`/`transform`-only transitions + extended reduced-motion collapse, `:focus-visible` list + skip-link + permanent dialog border. Extended fail-closed guards: `var(--rindle-shadow-card)` in `requiredTokenUses`; new structural selectors + `content: attr(data-label)` in `requiredSelectors`. Regenerated → contrast 58/58 → gallery-check (18 screenshots) → byte-identical priv sync.

## Task Commits

1. **Task 1: Author the page/1 Level-3 scaffold in components.ex** — `3ebbd85` (feat)
2. **Task 2: Author all Phase-98 generated CSS + fail-closed guards, regenerate, contrast, gallery-check, sync** — `f65f38e` (feat)

## Files Created/Modified

- `lib/rindle/admin/components.ex` — added `page/1` Level-3 scaffold (slots + `:state` + `data-rindle-admin-*` seam, no inline layout)
- `brandbook/src/admin-css-build.mjs` — authored all Phase-98 generated-CSS blocks + extended `requiredSelectors`/`requiredTokenUses` fail-closed guards
- `brandbook/tokens/rindle-admin.css` — regenerated generator output (never hand-edited)
- `priv/static/rindle_admin/rindle-admin.css` — byte-identical shipped copy (sync-admin-css.mjs)
- `brandbook/admin-gallery/index.html` — regenerated gallery (unchanged content, deterministic)

## Decisions Made

- **Two-pane selector:** `.rindle-admin-page--two-pane` is applied to the scaffold root when the `:aside` slot is present, and the actual two-track grid lives on `.rindle-admin-page__panes`. Chosen in Task 1 and reused verbatim in Task 2 CSS so the grid selector is stable for the Playwright backstop in P4.
- **Theme-picker motion property set:** animates `opacity` + `transform` only (see Deviations below).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] theme-picker option motion broke the gallery-check pressed-background assertion**
- **Found during:** Task 2 (motion catalog authoring)
- **Issue:** My first motion block for `.rindle-admin-theme-picker__option` enumerated `background-color`/`color` in addition to `opacity`/`transform`. `admin-gallery-check.mjs` `assertActiveDistinctFromFocus` reads the *computed* `backgroundColor` of the pressed option and requires it to equal `--rindle-brand`; with the background tweening, the snapshot captured a mid-animation value (`rgba(150,169,164,0.91)`) and the check threw.
- **Fix:** Removed `background-color`/`color` from the theme-picker transition, leaving `opacity` + `transform` only. This is also the strictly-correct §B GPU-only rule (only `transform`/`opacity` ever animate) — background/color must not tween.
- **Files modified:** `brandbook/src/admin-css-build.mjs`
- **Verification:** `node admin-css-build.mjs && node admin-gallery-check.mjs` → "admin gallery check passed - 18 screenshots written".
- **Committed in:** `f65f38e` (part of Task 2 commit)

**2. [Rule 1 - Bug] CSS-comment backticks broke the generator template literal**
- **Found during:** Task 2 (first generator run)
- **Issue:** The new CSS blocks live inside a JS backtick template string. Two of my CSS comments contained the literal `` `transition: all` `` with backticks, which terminated the template literal and produced `SyntaxError: Unexpected identifier 'transition'`.
- **Fix:** Reworded both comments to avoid backticks and to avoid the literal substring `transition:all` (which would also trip the plan's `grep -c 'transition: all\|transition:all'` acceptance check as a false positive). Comments now say "the all-properties shorthand".
- **Files modified:** `brandbook/src/admin-css-build.mjs`
- **Verification:** generator exits 0 with "parity OK"; `grep -c 'transition: all\|transition:all' rindle-admin.css` → 0.
- **Committed in:** `f65f38e` (part of Task 2 commit)

---

**Total deviations:** 2 auto-fixed (2 × Rule 1). Both were defects in my own freshly-authored CSS/comments surfaced by the pipeline gates, not pre-existing issues.
**Impact on plan:** None on scope. Both fixes converged the implementation to the plan's own §B GPU-only intent and acceptance criteria. No architectural change.

## Issues Encountered

- **ExUnit drift gate (`assert_generated_clean` = `git diff --exit-code`) reads RED until the regenerated CSS is committed.** This is the gate working as designed: it compares generator output to the git-tracked file, so the working tree must be committed for it to be clean. After committing Task 2 (`f65f38e`), the full suite is green: **4 tests, 0 failures**. (Documented here because a mid-task run will always show 2 failures until commit — not a defect.)
- The `too_many_connections` Postgrex log noise during `mix test` is pre-existing environment noise from other DB-backed test processes; the brandbook validation tests are filesystem/`node`-shell static gates and pass regardless.

## Verification Results

- `mix compile` (MIX_ENV=test) — clean.
- `grep "def page("` / `slot :work, required: true` / `grep -c "rindle-admin-page"` (≥1) — all present in `components.ex`.
- `grep -rn "<.page" lib/rindle/admin/live/` — no matches (page/1 ends UNUSED, D-98-01).
- `node admin-css-build.mjs` — exits 0, "parity OK" (self-check green with new selectors + `var(--rindle-shadow-card)`).
- `node admin-contrast.mjs` — 58/58 pairs pass (no token value changed).
- `node admin-gallery-check.mjs` — 18 screenshots, passed.
- `cmp -s brandbook/tokens/rindle-admin.css priv/static/rindle_admin/rindle-admin.css` — byte-identical (ADMIN-02).
- Generator determinism — two consecutive regenerations produce byte-identical output.
- `grep -c 'transition: all\|transition:all'` on generated CSS — 0.
- Generated CSS contains the `min-width: 1024px` two-pane block and `content: attr(data-label)` stacked-table rule.
- `mix test test/brandbook/admin_design_system_validation_test.exs --include integration` — **4 tests, 0 failures** (against committed state).

## Non-Inferable Backstops Deferred to P4 (Playwright, by design)

These four conditional/cascade clauses are authored here but are NOT provable by this plan's static gate (RESEARCH Pitfall 1/6) — proven later via Playwright in P4:
1. Two-pane region computes two grid tracks at ≥1024px, one track below.
2. Data table/tr/td compute `display:block` + `td::before` resolves `attr(data-label)` at <760px; `table`/`table-row`/`table-cell` + empty `::before` at ≥760px.
3. Under emulated `prefers-reduced-motion:reduce`, every animated selector computes `transition-duration: 0s`; under no-preference it equals the token duration.
4. `:focus-visible` (keyboard) yields the 2px ring + 2px offset in both themes; pointer `:focus` yields no ring.

## Known Stubs

None. `page/1` is intentionally unused this plan (D-98-01) — that is a planned phase-staging boundary, not a stub: the six surface migrations in 98-02b wire it. The `td::before { content: attr(data-label) }` rule consumes `<td data-label>` markup that 98-02b adds; the CSS-only authoring here is the planned split (D-98-08).

## Self-Check: PASSED

- All modified files present on disk.
- Both task commits (`3ebbd85`, `f65f38e`) present in git history.
