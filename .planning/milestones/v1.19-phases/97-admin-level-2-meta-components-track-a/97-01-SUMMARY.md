---
phase: 97-admin-level-2-meta-components-track-a
plan: 01
subsystem: ui
tags: [design-system, rindle-admin, css-generator, meta-components, bem, tokens, aria-sort]

# Dependency graph
requires:
  - phase: 95-admin-level-1-component-audit-track-a
    provides: Level-1 rindle-admin primitives (COMPONENTS, LEVEL_1_STATES), token-backed generated CSS, requiredSelectors self-check
  - phase: 94-foundation-token-pipeline
    provides: brandbook-tokens CI gate, motion/elevation/fluid/breakpoint token categories, --rindle-accent/--rindle-surface-sunken semantic tokens
provides:
  - META_COMPONENTS inventory of record (8 Level-2 slugs) in admin-design-system-data.mjs
  - Generated token-backed composition CSS for all 8 meta-components in rindle-admin.css
  - Static (no-JS) data-table sort/sticky/bulk-select state (aria-sort glyph, .rindle-admin-table--sticky, [data-rindle-admin-selected], .rindle-admin-bulk-bar)
  - requiredMetaSelectors build self-check (fails closed on a missing meta selector)
affects: [97-02 gallery meta panels, 97-03 rhythm/no-h-scroll polish gate, 97-04 priv sync + drift gate + OVERLAP_ENFORCED flip]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Parallel Level-2 inventory: META_COMPONENTS lives beside COMPONENTS, never mutating Level-1 literals or their exact() parity guards"
    - "Attribute/BEM-modifier state (no client JS): th[aria-sort] ::after glyph, .rindle-admin-table--sticky, [data-rindle-admin-selected]"
    - "requiredMetaSelectors fail-closed self-check appended to the existing requiredSelectors gate"

key-files:
  created:
    - .planning/phases/97-admin-level-2-meta-components-track-a/deferred-items.md
  modified:
    - brandbook/src/admin-design-system-data.mjs
    - brandbook/src/admin-css-build.mjs
    - brandbook/tokens/rindle-admin.css

key-decisions:
  - "Sort direction conveyed by a visible token-backed ::after glyph (up-down/up/down arrows), active column tinted --rindle-accent — never color-only (status-needs-label)"
  - "Drawer meta-component root named .rindle-admin-drawer-panel to avoid colliding with the Level-1 .rindle-admin-drawer primitive while staying in the rindle-admin-* vocabulary"
  - "priv/static/rindle_admin sync + drift gate deferred to 97-04 by design (plan success criteria + files_modified scope); documented in deferred-items.md"

patterns-established:
  - "Meta-component CSS section: each unit emits a root selector (requiredMetaSelectors-guarded) + composes only Level-1 parts/tokens"
  - "Sticky table opts into an internal scroll region (max-height + overflow:auto) so 97-03's no-horizontal-scroll gate can skip it via an explicit marker"

requirements-completed: [UPLIFT-02]

# Metrics
duration: 5min
completed: 2026-06-17
---

# Phase 97 Plan 01: Level-2 Meta-Component Inventory + Composition CSS Summary

**META_COMPONENTS inventory of record (8 slugs) plus generated token-backed composition CSS for every Level-2 unit — static aria-sort/sticky/bulk-select data-table state with no client JS — guarded by a fail-closed requiredMetaSelectors self-check; contrast holds 58/58.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-06-17T21:08:18Z
- **Completed:** 2026-06-17T21:13:17Z
- **Tasks:** 2
- **Files modified:** 3 (+1 deferred-items.md created)

## Accomplishments
- Added `META_COMPONENTS` (toolbar, data-table, filter-bar, action-panel, detail-drilldown, confirm-panel, drawer, toast-stack) as a parallel inventory beside `COMPONENTS`, with a new `exact(META_COMPONENTS, ...)` parity guard — Level-1 literals byte-unchanged.
- Generated composition CSS for all 8 meta-components, every gap/margin/padding a `--rindle-space-*` token, every color an existing semantic token.
- Expressed data-table behaviors purely as CSS state: `th[aria-sort="ascending|descending|none"]` visible `::after` direction glyph (active column tinted `--rindle-accent`), `.rindle-admin-table--sticky` `position: sticky` head in an internal scroll region, `[data-rindle-admin-selected]` selected surface, and a contextual `.rindle-admin-bulk-bar`.
- Added a `requiredMetaSelectors` (12-selector) self-check that pushes absentees into `missing` so the build exits 1 on any missing meta selector.
- Held contrast at 58/58 (no new `CONSOLE_CONTRAST_PAIRS`), 0 `outline: none`, and 0 `btn`/`card`/`dark` class substrings.

## Task Commits

Each task was committed atomically (TDD: parity guard / self-check added first to drive a RED failure, then the implementation made it GREEN):

1. **Task 1: Add META_COMPONENTS inventory + generator parity guard** - `9888e7d` (feat)
2. **Task 2: Generate Level-2 composition CSS + requiredMetaSelectors self-check** - `4d428fb` (feat)

_RED was proven before each GREEN: Task 1's `exact(META_COMPONENTS,...)` failed with an undefined-export SyntaxError until the constant was added; Task 2's `requiredMetaSelectors` loop exited 1 listing all 11 missing meta selectors until the CSS was emitted._

## Files Created/Modified
- `brandbook/src/admin-design-system-data.mjs` - Added `META_COMPONENTS` inventory of record (8 slugs, spec order), parallel to `COMPONENTS`.
- `brandbook/src/admin-css-build.mjs` - Import + `exact()` parity guard for `META_COMPONENTS`; emit Level-2 composition/state CSS for all 8 units; new `requiredMetaSelectors` fail-closed self-check; terminal log reports meta-selector count.
- `brandbook/tokens/rindle-admin.css` - Regenerated output (generator-written, not hand-edited) now carrying the meta-component rules.
- `.planning/phases/.../deferred-items.md` - Records the priv-sync drift-gate failure deferred to 97-04.

## Decisions Made
- **Sort glyph, not color:** `aria-sort` drives a visible `::after` arrow glyph; the active column adds `--rindle-accent` tint on top of the glyph, satisfying the non-color-only (`status-needs-label`) contract.
- **`.rindle-admin-drawer-panel` naming:** the Level-1 primitive already owns `.rindle-admin-drawer`, so the Level-2 composed unit uses `…-drawer-panel` to compose it without selector collision, staying in the `rindle-admin-*` vocabulary and avoiding `btn`/`card`/`dark` substrings.
- **Sticky scroll region:** `.rindle-admin-table--sticky` becomes its own `overflow:auto` scroll container (`max-height: calc(--rindle-admin-target-min * 8)`) so 97-03's no-horizontal-scroll gate can opt it out via an explicit marker rather than auto-detection.

## Deviations from Plan

None - plan executed exactly as written. (The deferred `priv` drift-gate failure is the plan's own designed deferral to 97-04, not a deviation — see Issues Encountered.)

## Issues Encountered

`mix test test/brandbook/admin_design_system_validation_test.exs --include integration` initially showed 3 failures; resolved/triaged as follows:

1. **DS-01 / DS-02 `assert_generated_clean` (git diff --exit-code on the generated CSS)** — failed only because the regenerated `rindle-admin.css` was uncommitted. **Cleared automatically once Task 2 was committed** (working tree clean). Not a defect.
2. **ADMIN-02 `priv/static/rindle_admin/rindle-admin.css == brandbook/tokens/rindle-admin.css`** — the shipped copy is intentionally NOT synced in this plan. The 97-01 PLAN success criteria state *"Sync to the shipped copy + drift gate is deferred to 97-04 by design"* and the plan's `files_modified` frontmatter excludes `priv/`. Honored the deferral rather than syncing out-of-scope; logged in `deferred-items.md` for the verifier and for 97-04 to close via `node brandbook/src/sync-admin-css.mjs`.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- `META_COMPONENTS` + generated meta-component CSS are in place for 97-02 (gallery meta-panel rendering with `data-rindle-admin-meta`) and 97-03 (rhythm / no-horizontal-scroll polish gate over `[data-rindle-admin-meta]` subtrees).
- One known-deferred merge-blocking failure remains: the `priv` ↔ `brandbook` CSS drift gate, scheduled for 97-04 (sync + empty-diff gate + `OVERLAP_ENFORCED` flip). Tracked in `deferred-items.md`.

## Self-Check: PASSED

- Files verified present: `admin-design-system-data.mjs`, `admin-css-build.mjs`, `rindle-admin.css`, `97-01-SUMMARY.md`, `deferred-items.md`.
- Commits verified in git log: `9888e7d` (Task 1), `4d428fb` (Task 2).

---
*Phase: 97-admin-level-2-meta-components-track-a*
*Completed: 2026-06-17*
