---
phase: 96-cohort-component-layer-dark-reduced-motion-contract-track-b
plan: 03
subsystem: ui
tags: [cohort, styleguide, liveview, data-ck-root, data-theme, server-theme-toggle, server-owned-sort, gallery, seeded-fiction, test-markers, design-system]

# Dependency graph
requires:
  - phase: 96-02
    provides: "the six Level-1 .ck-* CohortComponents primitives (ck_table/ck_stat/ck_field/ck_input/ck_select/ck_tabs/ck_detail/ck_toolbar) + badge/hero/cohort_nav this gallery renders"
provides:
  - "StyleguideLive: a reachable /styleguide LiveView gallery on a per-LiveView .ck shell carrying the data-ck-root + data-theme polish seam (D-96-05), the VIS-04 audit reference and the route the Plan 05 Playwright spec + the Plan 04 component-existence loop drive"
  - "Server-owned theme toggle (set_theme, enum-guarded light|dark) with data-ck-theme + aria-pressed buttons, no client-side storage (D-96-07/16)"
  - "Server-owned sort state (set_sort, key validated against the known column set) + server-owned tab selection, driving the ck_table aria-sort header (D-96-15)"
  - "10 data-ck-section groups (6 L1 + 4 L2) with full per-primitive state sets on stable data-ck-state markers separate from the .ck-* styling classes (D-96-16)"
  - "Real seeded Cohort fiction (lesson-video processing row, quarantined upload, empty member list) with both a never-populated and a filtered empty-state copy variant for Phases 99/100 (D-96-22)"
affects: [96-04, 96-05, 99, 100, cohort-styleguide.spec.js, admin-polish.js]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Theme + sort + tab as SERVER state (assign + phx-click), no client storage, so the e2e spec drives state deterministically (D-96-07/16)"
    - "Enum-guarded events: set_theme guards t in ~w(light dark); set_sort validates key against @sort_keys; set_tab guards the tab id — invalid/forged params ignored, not reflected (T-96-06)"
    - "Stable data-ck-section / data-ck-state markers emitted SEPARATE from BEM styling classes — the spec asserts on those, never on .ck-* (D-96-16)"
    - "Distinct to_form(as:) names per rendered control instance so FormField-derived DOM ids stay unique under LiveView (duplicate-id is a runtime error, not a compile warning)"
    - "Gallery composes ONLY the Plan 02 primitives + existing hero/nav/footer/panel/grid; no net-new .ck-* CSS this plan"

key-files:
  created:
    - examples/adoption_demo/lib/adoption_demo_web/live/styleguide_live.ex
  modified:
    - examples/adoption_demo/lib/adoption_demo_web/router.ex

key-decisions:
  - "Theme toggle buttons styled as .ck-btn / .ck-btn--primary (active) to reuse the existing 44px-target pill button + token-backed :focus-visible, while carrying the data-ck-theme + aria-pressed test/a11y contract"
  - "Numeric duration column sorts on a backing duration_s integer (not the display string) so server-owned sort is correct for processing/quarantine rows that display an em-dash"
  - "Two distinct empty-state copy variants rendered as separate data-ck-state markers: empty-never-populated (member-join copy) and empty-filtered (adjust-filters copy) per D-96-22, ready for Phases 99/100"
  - "form change/submit are explicit noop handlers — the styleguide is a static reference surface with no data mutation (T-96-05 accept); the forms exist to demo real FormField semantics"

requirements-completed: [COHORT-06]

# Metrics
duration: 5min
completed: 2026-06-17
---

# Phase 96 Plan 03: /styleguide Gallery (StyleguideLive) Summary

**A reachable `/styleguide` LiveView gallery on the per-LiveView `.ck` shell carrying the `data-ck-root` + `data-theme={@theme}` polish seam (D-96-05) — a server-owned theme toggle (`set_theme`, no client storage), server-owned sort + tab state, and 10 `data-ck-section` groups rendering all six Level-1 primitives plus the four Level-2 compositions across their full state sets with stable `data-ck-state` markers and real seeded Cohort fiction (lesson-video processing, quarantined upload, empty member list with both never-populated and filtered empty-state copy).**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-06-17T19:00:43Z
- **Completed:** 2026-06-17
- **Tasks:** 2
- **Files modified:** 2 (1 created, 1 modified)

## Accomplishments

### Task 1 — StyleguideLive shell + seam + server toggle/sort + route (`3ac244d`)
- New `AdoptionDemoWeb.StyleguideLive` (`use AdoptionDemoWeb, :live_view`; `import AdoptionDemoWeb.CohortComponents`). `mount/3` assigns `page_title`, `theme: "light"`, server-owned `sort_by`/`sort_dir`, `selected_tab`, the seeded `lesson_rows`, and the demo forms.
- `render/1` emits `<div class="ck" data-ck-root data-theme={@theme}>` mirroring `launchpad_live.ex:88`, with `<.cohort_nav active={nil} />`, a `<main class="ck__wrap">`, and a `role="group" aria-label="Theme"` toggle of two `.ck-btn` buttons (`phx-click="set_theme"`, `phx-value-theme`, `aria-pressed`, `data-ck-theme`, 44px pill target).
- `handle_event("set_theme", ...)` guards `theme in ~w(light dark)`; `handle_event("set_sort", ...)` validates `key` against `@sort_keys` and toggles `sort_dir`; both ignore invalid params (T-96-06). No client-side storage (D-96-07/16).
- Added `live("/styleguide", StyleguideLive, :index)` to the existing `:browser` scope in `router.ex` (D-96-04) — no harness change (the demo already boots a real Phoenix server with seeds in CI).

### Task 2 — all primitive + L2 sections, seeded fiction, stable markers (`0dbe54d`)
- 10 `data-ck-section` groups: **L1** `table` (sortable/empty-never-populated/empty-filtered/loading), `stat` (default/status/empty `—`/loading), `form` (default/disabled/error via `to_form` + `Phoenix.HTML.FormField`), `tabs` (default + one disabled tab, APG roles), `detail` (multi-row/empty), `toolbar` (primary + quiet); **L2** `data-table-block` (toolbar + table + badges), `stat-row` (`.ck-grid` + N× `ck_stat`), `detail-panel` (`.ck-panel` + `ck_detail` + badge), `tabbed-section` (`ck_tabs` + per-panel `ck_table`).
- Real Cohort fiction (D-96-22): a `Module 2 — Live workshop` lesson row in `processing`, an `Office hours (raw upload)` row `quarantine`d, and an empty member list rendered in both a never-populated and a filtered empty-state copy variant.
- Exact UI-SPEC Copywriting Contract strings: `Nothing here yet`, `No records match this view. Adjust filters or seed demo data.`, `Apply filters`, `Save changes`, and the `{Field} is required.`-shaped error on the error form.
- Stable `data-ck-state` markers on every variation group, separate from the `.ck-*` BEM styling classes (D-96-16) — the spec's assertion surface.

## Task Commits

1. **Task 1: StyleguideLive shell + data-ck-root seam + server toggle/sort + route** — `3ac244d` (feat)
2. **Task 2: all L1 + L2 sections with seeded fiction + stable markers** — `0dbe54d` (feat)

**Plan metadata:** (final docs commit)

## Files Created/Modified

- `examples/adoption_demo/lib/adoption_demo_web/live/styleguide_live.ex` — **created.** The full gallery LiveView: `.ck` shell with the `data-ck-root`/`data-theme` seam, server theme toggle, server-owned sort + tab handlers, seeded fiction, and the 10 marked sections.
- `examples/adoption_demo/lib/adoption_demo_web/router.ex` — **modified (1 line).** Added the `/styleguide` live route to the existing `:browser` scope.

## Decisions Made

- **Toggle reuses `.ck-btn`.** The theme toggle buttons are `.ck-btn` / `.ck-btn--primary` (active) so they inherit the existing 44px target + token-backed `:focus-visible`, while carrying the net-new `data-ck-theme` + `aria-pressed` contract the spec drives.
- **Numeric sort on a backing integer.** The duration column sorts on `duration_s` (seconds), not the display string, so processing/quarantine rows that show `—` sort correctly under server-owned sort.
- **Two empty-state copy variants as separate markers.** `empty-never-populated` and `empty-filtered` are distinct `data-ck-state` groups (D-96-22) for Phases 99/100 to reuse.
- **Static surface, noop form events.** `phx-change`/`phx-submit` are explicit no-ops — no data mutation (T-96-05 accept); the forms exist purely to demo `FormField` semantics.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Duplicate DOM id `member_email` would break LiveView patching**
- **Found during:** Task 2 (caught by a throwaway LiveView render smoke before commit).
- **Issue:** The default email field and the disabled email-field demo both bound `@form[:email]`, so the `FormField`-derived id `member_email` rendered twice. LiveView raises `Duplicate id found` at runtime (DOM patching cannot target the correct element) — invisible to `mix compile`.
- **Fix:** Added a separate `disabled_form` via `to_form(%{...}, as: :member_disabled)` and threaded it through `render/1` → `gallery_sections/1` → the disabled field, giving each rendered control instance a unique id.
- **Files modified:** `examples/adoption_demo/lib/adoption_demo_web/live/styleguide_live.ex`
- **Commit:** `0dbe54d` (folded into Task 2).

**2. [Rule 3 - Blocking] Default-`:dev`-env `mix compile --warnings-as-errors` fails on pre-existing Mox warnings — used `MIX_ENV=test`.**
- **Found during:** Both tasks' verification.
- **Issue:** Identical to the Plan 96-01 / 96-02 documented condition: the default `:dev` env fails `--warnings-as-errors` on pre-existing `Mox.*` undefined warnings in `AdoptionDemo.MuxCassette` (`mox` is `only: :test`), entirely unrelated to this plan's `styleguide_live.ex`/`router.ex` edits (SCOPE BOUNDARY: pre-existing failure in an unrelated file, already logged to the phase `deferred-items.md` by Plan 01).
- **Fix:** Verified no template/compile breakage from this plan's edits via `MIX_ENV=test mix compile --warnings-as-errors`, which exits **0**.
- **Files modified:** none (verification-only).
- **Commit:** n/a.

## Issues Encountered

None beyond the duplicate-id bug (fixed inline, see Deviations) and the pre-existing Mox compile-env note (out of scope, already deferred). No fix-attempt-limit pressure.

## User Setup Required

None — no external service configuration. `/styleguide` is a static developer reference route in the demo app, reachable with no harness change (the existing CI Playwright harness boots the server with seeds).

## Known Stubs

None. The empty-state and loading-skeleton renders are intentional component states from the UI-SPEC Copywriting Contract, not unwired data. The styleguide intentionally renders hand-seeded fiction (D-96-22) — this is the VIS-04 audit reference surface, by design static. The `noop` form handlers are intentional (T-96-05 accept: a static reference page has no data mutation).

## Threat Flags

None. The only net-new surface is the public `/styleguide` route, which is already in the plan's `<threat_model>` (T-96-05 accept: static hand-seeded fiction, no PII/secrets, intentionally public like `/`; T-96-06 mitigate: `set_theme`/`set_sort`/`set_tab` are all enum-guarded so forged params are ignored, not reflected; T-96-07 accept: reuses the existing `:browser` pipeline). No new endpoint beyond the planned one, no auth path, no file access, no schema change.

## Verification Results

- **UI-SPEC gate 1 (reachability — components side):** route reachable (`grep -c 'live("/styleguide", StyleguideLive'` = 1); 10 distinct `data-ck-section` groups (`table`, `stat`, `form`, `tabs`, `detail`, `toolbar` + `data-table-block`, `stat-row`, `detail-panel`, `tabbed-section`) ≥ 10; 26 primitive invocations ≥ 6. (Rendered reachability at `/styleguide` is the Plan 05 spec + Plan 04 existence loop.)
- **D-96-05 seam:** `data-ck-root` present on the `.ck` div, `data-theme={@theme}` = 1; zero `data-ck-root` in `components/layouts/` (not on body/root).
- **D-96-07 server toggle:** `set_theme` ≥ 2 (handler + phx-click), `data-ck-theme` = 2, `aria-pressed` = 2, `localStorage` = 0.
- **D-96-15 server sort:** `set_sort`/`sort_by`/`sort_dir` ≥ 3; `to_form` = 3 (real `FormField` semantics).
- **D-96-16 markers:** `data-ck-state` = 25 ≥ 6, separate from `.ck-*` styling classes.
- **D-96-22 fiction:** `processing`/`quarantine`/`lesson`/`member` matches = 52 ≥ 3; `lorem`/`ipsum` = 0; both never-populated + filtered empty variants present.
- **Exact copy:** `Nothing here yet` = 4, `No records match this view` = 3, `Apply filters`/`Save changes` = 5.
- **Compile:** `MIX_ENV=test mix compile --warnings-as-errors` exits **0**.
- **LiveView render smoke (throwaway probe, removed before commit):** `/styleguide` boots, renders the seam + sections, `set_theme` flips `data-theme="dark"`, and `set_sort` is wired — passed after the duplicate-id fix. The permanent e2e smoke is added in Plan 05.

## Next Phase Readiness

- `/styleguide` is reachable in the `:browser` scope with the `data-ck-root`/`data-theme` seam on the `.ck` div — the Plan 04 contrast gate's component-existence loop and the Plan 05 Playwright spec (`assertAdminPolish` over `[data-ck-root]`, the theme toggle drive, the reduced-motion probe) can target it directly.
- Stable `data-ck-section`/`data-ck-state` markers and the seeded fiction are in place; Phases 99/100 inherit the two empty-state copy variants and the FormField wiring unchanged.
- No blockers.

## Self-Check: PASSED

- FOUND: `examples/adoption_demo/lib/adoption_demo_web/live/styleguide_live.ex`
- FOUND: `examples/adoption_demo/lib/adoption_demo_web/router.ex` (route line present)
- FOUND: `.planning/phases/96-cohort-component-layer-dark-reduced-motion-contract-track-b/96-03-SUMMARY.md`
- FOUND commit: `3ac244d` (Task 1)
- FOUND commit: `0dbe54d` (Task 2)

---
*Phase: 96-cohort-component-layer-dark-reduced-motion-contract-track-b*
*Completed: 2026-06-17*
