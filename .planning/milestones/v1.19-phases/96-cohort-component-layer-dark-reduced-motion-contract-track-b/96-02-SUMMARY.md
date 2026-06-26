---
phase: 96-cohort-component-layer-dark-reduced-motion-contract-track-b
plan: 02
subsystem: ui
tags: [cohort, cohort-components, ck-primitives, phoenix-function-components, wai-aria, tabs, form-field, aria-sort, focus-visible, phx-hook, design-system]

# Dependency graph
requires:
  - phase: 96-01
    provides: "cohort.css [data-theme] contract + surface/shadow/space/type tokens the new primitives consume; the .ck reduced-motion / :focus-visible / box-sizing rules every new .ck-* selector inherits"
provides:
  - "Six Level-1 .ck-* primitives as CohortComponents function components: ck_table, ck_stat, ck_detail, ck_toolbar (Task 1); ck_field/ck_input/ck_select form set + ck_tabs (Task 2)"
  - "ck_table with a real <button> sort header carrying aria-sort (net-new in this repo), server-owned sort_by/sort_dir + sort_event, badge reuse, empty + loading-skeleton states"
  - "Form set integrating Phoenix.HTML.FormField with aria-describedby + aria-invalid and a non-color (warning-icon) error per D-96-15"
  - "ck_tabs as full WAI-ARIA APG (role tablist/tab/tabpanel, aria-selected/-controls, roving tabindex), server-owned selection via phx-click, non-color selected cue (underline + weight)"
  - "Net-new phx-hook=\"Tabs\" keyboard handler in app.js (Arrow/Home/End roving tabindex), registered in the hooks map"
  - "Matching .ck-* CSS for all six primitives consuming Plan 01 tokens, token-backed :focus-visible (no bare outline:none), 44px min interactive targets, shared .ck-empty + .ck-skeleton states"
affects: [96-03, 96-04, 99, 100, styleguide_live.ex, cohort-styleguide.spec.js]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Flat function component per primitive with attr ... values: enums + :rest, :global; named slots only for content (:col/:item/:tab/:actions) (D-96-09/14)"
    - "Server-owned sort state: ck_table takes sort_by/sort_dir/sort_event; the sortable header is a real <button> with aria-sort on its <th> cell (D-96-15)"
    - "FormField aria contract via a shared field_meta/2 helper: aria-invalid from field.errors, aria-describedby pointing at the help+error element ids (D-96-15)"
    - "WAI-ARIA APG tabs: click server-owned via phx-click, KEYBOARD owned by one phx-hook=\"Tabs\" (no dep); selected = aria-selected + underline + weight (non-color, D-96-17)"
    - "Roving-tabindex keyboard hook idiom copying the Copy hook object shape; mounted/destroyed listener lifecycle"

key-files:
  created: []
  modified:
    - examples/adoption_demo/lib/adoption_demo_web/components/cohort_components.ex
    - examples/adoption_demo/priv/static/assets/cohort.css
    - examples/adoption_demo/priv/static/assets/js/app.js

key-decisions:
  - "aria-sort placed on the <th> cell (correct ARIA target) while the sortable control is a real <button> nested inside it that owns phx-click + the 44px target; satisfies D-96-15 'real button carrying aria-sort'"
  - "ck_field uses Phoenix.Component.used_input?/1 so pristine fields show no error noise; errors translated by a local translate_ck_error/2 (no gettext dep in the demo's cohort layer)"
  - "Sort/delta/empty glyphs (↑↓↕ / ▲▼• / —) are inline text marks, not color, so state is conveyed non-color per D-96-22"
  - "Dropped the .ck-tabs__panel { outline: none } base reset entirely (rather than pairing it) so both the literal grep gate and the D-96-20 assertNoBareOutlineNone scanner stay clean; panels rely on the inherited .ck :focus-visible rule + an explicit :focus-visible ring"
  - "ck_icon(:warning) added as a dedicated general-purpose private icon clause (separate head from task_icon) so the non-color form error is reusable by later primitives"

requirements-completed: [COHORT-06]

# Metrics
duration: 4min
completed: 2026-06-17
---

# Phase 96 Plan 02: Cohort Level-1 Primitive Layer (table / stat / form / tabs / detail / toolbar) Summary

**The six required Level-1 `.ck-*` primitives shipped as `CohortComponents` function components with matching `.ck`-scoped CSS consuming the Plan 01 tokens — a server-sortable `ck_table` (real `<button>` + `aria-sort`), a `Phoenix.HTML.FormField`-integrated form set with a non-color error, full WAI-ARIA APG `ck_tabs` backed by a net-new keyboard-only `phx-hook="Tabs"`, plus `ck_stat`/`ck_detail`/`ck_toolbar` — every interactive control carrying a token-backed `:focus-visible` ring and a 44px minimum target.**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-06-17T18:38:29Z
- **Completed:** 2026-06-17T18:43Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

### Task 1 — table / stat / detail / toolbar (`617d7be`)
- `ck_table`: `core_components` `:col`/`:rows` model extended with per-column `sort_key`/`num`; sort state is server-owned (`sort_by`/`sort_dir`/`sort_event`); the sortable header is a real `<button>` and the `<th>` carries `aria-sort={ascending|descending|none}`; numeric columns get `tabular-nums`; status cells reuse the existing `badge/1`; renders both an empty state (`Nothing here yet` + the contract body) and a loading skeleton.
- `ck_stat`: `tabular-nums` value, em-dash (`—`) on empty/nil, optional `delta` (with a non-color ▲/▼/• glyph) and a `status` accent border, plus a loading skeleton.
- `ck_detail`: a real `<dl>` of `<dt class="ck-detail__term">`/`<dd class="ck-detail__desc">` rows from an `:item` slot, with an empty state.
- `ck_toolbar`: `role="group"` + `aria-label`, an inner-block content group and a trailing pinned `:actions` group, wraps on narrow viewports, 44px controls.
- CSS: `.ck-table`/`.ck-stat`/`.ck-detail`/`.ck-toolbar` consuming Plan 01 surface/border/space/type tokens; table rows hover = background only (NO layout shift, D-96-22), zebra striping, 44px sort target; shared `.ck-empty` + `.ck-skeleton` shimmer (the shimmer animation is auto-frozen by the Plan 01 `.ck *` reduce block).

### Task 2 — form set / tabs / Tabs hook (`441bef9`)
- `ck_field`/`ck_input`/`ck_select`: integrate `Phoenix.HTML.FormField`, derive `id`/`name`/`errors`, wire `aria-describedby` (help + error element ids) and `aria-invalid` from the field errors via a shared `field_meta/2`; the error renders a non-color warning **icon** + message (`role="alert"`); `disabled` maps to `aria-disabled` + sunken `--ck-surface-2` styling (D-96-15).
- `ck_tabs`: full WAI-ARIA APG structure — `role="tablist"` (carrying `phx-hook="Tabs"`), each `role="tab"` with `aria-selected`/`aria-controls`/roving `tabindex` (0 selected, -1 others), each `role="tabpanel"`; selection is server-owned via `phx-click`; the selected cue is `aria-selected` + underline + weight (non-color, D-96-17).
- `app.js`: net-new `Tabs` hook owning KEYBOARD ONLY — ArrowLeft/Right (+ Up/Down) move focus and roving tabindex across enabled tabs, Home/End jump to first/last; registered in the `hooks: {…}` map alongside `Copy`. `mounted`/`destroyed` manage the listener.
- `ck_icon(:warning)` private clause for the non-color form error.
- CSS: `.ck-field`/`.ck-input`/`.ck-select`/`.ck-label`/`.ck-help`/`.ck-error`/`.ck-tabs`/`.ck-tabs__tab`/`.ck-tabs__panel`, all token-backed, with `:focus-visible` rings (never bare `outline:none`), 44px min targets, and `[aria-invalid]`/`[aria-disabled]` state styling.

## Task Commits

1. **Task 1: ck_table, ck_stat, ck_detail, ck_toolbar + their .ck-* CSS** — `617d7be` (feat)
2. **Task 2: ck_field/ck_input/ck_select form set + ck_tabs + the Tabs WAI-ARIA hook** — `441bef9` (feat)

**Plan metadata:** (final docs commit)

## Files Created/Modified

- `examples/adoption_demo/lib/adoption_demo_web/components/cohort_components.ex` — added 8 function components (the six L1 primitives; the form set is 3 of them), the `field_meta/2` + `translate_ck_error/2` + sort/glyph helpers, and a `ck_icon(:warning)` private icon clause.
- `examples/adoption_demo/priv/static/assets/cohort.css` — added the `.ck-table`/`.ck-stat`/`.ck-detail`/`.ck-toolbar`/`.ck-field`/`.ck-input`/`.ck-select`/`.ck-tabs` selectors + shared `.ck-empty`/`.ck-skeleton`, all `.ck`-scoped and token-only.
- `examples/adoption_demo/priv/static/assets/js/app.js` — added the keyboard-only `Tabs` hook and registered it in the LiveSocket `hooks` map.

## Decisions Made

- **`aria-sort` on the `<th>`, `<button>` as the control.** ARIA puts `aria-sort` on the column header cell; the interactive sort trigger is a real nested `<button>` (owns `phx-click` + the 44px target). This satisfies D-96-15's "real `<button>` carrying `aria-sort`" while staying spec-correct.
- **Pristine-field quiet.** `ck_field`/the form controls gate errors on `Phoenix.Component.used_input?/1` so an untouched form shows no error chrome.
- **Non-color state everywhere (D-96-22).** Sort direction (↑↓↕), stat delta (▲▼•), tab selection (underline + weight), and the form error (warning icon) all carry a non-color cue in addition to color.
- **Removed, not paired, the panel `outline: none`.** To keep both the literal `outline\s*:\s*none` grep and the D-96-20 `assertNoBareOutlineNone` scanner clean, the base reset was dropped entirely; the panel uses an explicit `:focus-visible` ring plus the inherited `.ck :focus-visible` rule.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Default-`:dev`-env `mix compile --warnings-as-errors` fails on pre-existing Mox warnings — used `MIX_ENV=test`.**
- **Found during:** Tasks 1 & 2 verification.
- **Issue:** The plan's acceptance command `cd examples/adoption_demo && mix compile --warnings-as-errors` exits non-zero in the default `:dev` env because `mox` is declared `only: :test` in `mix.exs`; the failing warnings are `Mox.defmock/2`/`Mox.stub/3`/`Mox.set_mox_global/1` is undefined in `AdoptionDemo.MuxCassette` — entirely unrelated to this plan's `cohort_components.ex`/`cohort.css`/`app.js` edits and pre-dating it. This is the identical out-of-scope pre-existing failure that Plan 96-01 documented and logged to `deferred-items.md` (SCOPE BOUNDARY: pre-existing failure in an unrelated file).
- **Fix:** Verified no template/compile breakage from my edits via `MIX_ENV=test mix compile --warnings-as-errors`, which exits **0**. A targeted scan confirmed the `:dev`-env failures contain zero `cohort`-related warnings (only the four `Mox.*` undefined lines).
- **Files modified:** none (verification-only).
- **Commit:** n/a.

## Issues Encountered

None beyond the pre-existing Mox compile-env note above (out of scope, already deferred by Plan 01). No fix-attempt-limit pressure; both tasks landed on first implementation.

## User Setup Required

None — no external service configuration. The primitives are static presentational components; data is wired by the `/styleguide` gallery in Plan 03 and by Phases 99/100.

## Known Stubs

None. The empty-state (`—` / "Nothing here yet") and loading-skeleton branches are **intentional component states** specified by the UI-SPEC Copywriting Contract and Component Inventory, not unwired data. Each primitive renders caller-supplied data through its slots; the gallery (Plan 03) supplies the seeded Cohort fiction (D-96-22). No hardcoded data flows to the UI.

## Threat Flags

None. The new surface is hand-authored Phoenix function components + CSS + a keyboard-only hook. The Tabs hook only reorders focus/tabindex on present DOM nodes (T-96-04 accepted: no network, no unbounded loop). Sort/tab `phx-click` params cross to the server (T-96-03) but the server-side validation of `sort_key`/tab-id against the known set is Plan 03's `StyleguideLive` responsibility (the components emit enum-bounded values from `values:`-constrained slots); no new endpoint, auth path, file access, or schema change is introduced here.

## Verification Results

UI-SPEC acceptance gates owned by this plan pass:

- **Gate 1 (component existence — components side):** all six L1 primitives exist as function components — `def ck_table|ck_stat|ck_field|ck_input|ck_select|ck_tabs|ck_detail|ck_toolbar` = 8 defs; all six `.ck-*` class roots present in `cohort.css` (`.ck-table` 19, `.ck-stat` 11, `.ck-field` 2, `.ck-tabs` 9, `.ck-detail` 7, `.ck-toolbar` 5 occurrences). (Reachability at `/styleguide` is Plan 03.)
- **Gate 7 (focus-visible):** `:focus-visible` rings present for the new controls; `grep -nE 'outline\s*:\s*none'` over `cohort.css` returns **0** (no bare reset; D-96-20 scanner stays clean).
- **D-96-15 (FormField + aria):** `Phoenix.HTML.FormField` referenced 7×; `aria-describedby`/`aria-invalid` 8×; the `.ck-error` branch renders a warning-icon SVG (`ck_icon(:warning)`), not color-only.
- **D-96-15 (sortable header):** `aria-sort` present (2×) on `<th>`; the sort control is a real `<button>`.
- **D-96-17 (APG tabs + hook):** `role="tablist"`/`role="tab"`/`role="tabpanel"`/`aria-selected`/`aria-controls` ≥ 5 (= 7); `phx-hook="Tabs"` present; the `Tabs` hook object + registration present in `app.js` (2 matches) with `ArrowLeft`/`ArrowRight` handling (3 matches); `node --check app.js` passes.
- **D-96-22 (tabular-nums + real dl):** `tabular-nums` 2× (`.ck-stat__value` + `.ck-table__num`); `<dl` present in `ck_detail` (2×).
- **Grep-clean tokens (gate 4 continuity):** zero rule-body color literals introduced at or after the new-primitive CSS (line ≥ 570 scan, excluding `var(`/`currentColor`/`transparent`) — clean.
- **No template breakage:** `MIX_ENV=test mix compile --warnings-as-errors` exits **0**.

## Next Phase Readiness

- The six Level-1 primitives the `/styleguide` gallery (Plan 03) renders and the contrast/polish gates assert against now exist as both function components and `.ck`-scoped CSS. Plan 03's `StyleguideLive` can drop these into gallery sections, supply the seeded Cohort fiction, and own the server-side `sort`/`set_tab` handlers (validating `sort_key`/tab-id against the known set — T-96-03).
- The `phx-hook="Tabs"` keyboard contract and the `Phoenix.HTML.FormField` integration are ready for Phases 99/100 to compose pages from unchanged.
- No blockers.

## Self-Check: PASSED

- FOUND: `examples/adoption_demo/lib/adoption_demo_web/components/cohort_components.ex`
- FOUND: `examples/adoption_demo/priv/static/assets/cohort.css`
- FOUND: `examples/adoption_demo/priv/static/assets/js/app.js`
- FOUND: `.planning/phases/96-cohort-component-layer-dark-reduced-motion-contract-track-b/96-02-SUMMARY.md`
- FOUND commit: `617d7be` (Task 1)
- FOUND commit: `441bef9` (Task 2)

---
*Phase: 96-cohort-component-layer-dark-reduced-motion-contract-track-b*
*Completed: 2026-06-17*
