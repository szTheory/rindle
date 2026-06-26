---
phase: 98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco
plan: 02b
subsystem: ui
tags: [admin, migration, page-scaffold, table-a11y, caption, scope, data-label, live-view]

# Dependency graph
requires:
  - phase: 98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco
    plan: "01"
    provides: "page/1 Level-3 scaffold + all Phase-98 generated CSS (stacked-table td::before, scaffold grid, :focus-visible) — this plan composes the six surfaces onto page/1 and feeds td data-label into the stacked-card CSS"
  - phase: 98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco
    plan: "02a"
    provides: "§D a11y primitives + modal/confirm_dialog overlay (shell skip-link, server-owned aria-pressed, live regions) — surfaces inherit these via shell/1"
provides:
  - "All six admin surfaces (Overview, Assets, Upload sessions, Processing, Doctor, Maintenance) render their content through page/1 slots (:summary/:filters/:work/:actions) with :state driving the empty/error/loading fallbacks"
  - "Semantic accessible data tables on the four table surfaces: <caption> naming the surface + <thead> <th scope=col> + scope=row on the row-header cell + data-label on every data <td> (D-98-08)"
  - "data-label markup that the §C stacked-card td::before (authored in P1) reads — no markup fork, no priority-column hiding"
affects: [98-03, 98-04, admin-playwright-backstops]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Surface migration onto page/1: move the primary table/section into :work, summary band into :summary, filters into :filters; a per-surface list_state/1 (or inline if @error?) maps the surface model to page/1's :state (:ok|:empty|:error) so the surface stops re-implementing empty/error markup"
    - "td-only stacked-card a11y: row-header cell stays a <td scope=\"row\"> (NOT <th>) because the P1 §C CSS flips only <td> to display:block + td::before reads data-label at <760px — a <th> row-header would not participate in the stacked card"
    - "page/1 :work-or-fallback: follow-up non-table sections (repair recommendation, runtime findings) live inside :work, so they render only in the :ok state and the empty/error fallback fully replaces them (the duplicated surface-local empty/error markup is deleted)"

key-files:
  created: []
  modified:
    - lib/rindle/admin/live/assets_live.ex
    - lib/rindle/admin/live/upload_sessions_live.ex
    - lib/rindle/admin/live/runtime_doctor_live.ex
    - lib/rindle/admin/live/home_live.ex
    - lib/rindle/admin/live/variants_jobs_live.ex
    - lib/rindle/admin/live/actions_live.ex

key-decisions:
  - "Row-header cell kept as <td scope=\"row\"> (not <th scope=\"row\">) so it participates in the P1 §C stacked-card flip (the CSS selector enumerates td only). scope on td is non-standard HTML but is what the P1 CSS contract + plan acceptance grep require, and is the correct trade for a working stacked card."
  - "Caption authored as <caption class=\"rindle-admin-visually-hidden\"> — the semantically intended visually-hidden markup. P1 never authored that utility class (genuine P1 CSS defect, filed to deferred-items.md per Pitfall 2). No CSS added in P2b."
  - "Follow-up non-table sections (Doctor's findings, Processing's repair recommendation) moved into :work, so they no longer render in the empty/error state. The empty/error test for Processing only asserts the fallback copy, so this page/1 work-or-fallback behavior is correct and green."

patterns-established:
  - "Atomic-per-surface migration (gov.uk never-half-broken, D-98-02): each surface compiled + kept its behavior ExUnit green before the next surface's commit — six independent commits, each individually shippable."
  - "P3 scope guard held: no triage rebuild / inspect/1 replacement (Overview), no new variants-jobs/:id route or :show run-detail (Processing), no confirm->confirm_dialog rewire / verb distribution / microcopy (Maintenance) leaked into this structural pass."

requirements-completed: [UPLIFT-03, UPLIFT-05, UPLIFT-06]

# Metrics
duration: 8min
completed: 2026-06-18
status: complete
---

# Phase 98 Plan 02b: Migrate Six Admin Surfaces onto page/1 Summary

**Migrated all six `*_live.ex` admin surfaces (Overview, Assets, Upload sessions, Processing, Doctor, Maintenance) from hand-rolled `<table>`/`<section>` markup onto the `page/1` Level-3 scaffold — one atomic commit per surface — moving each primary table/section into the `:work` slot, summary bands into `:summary`, filters into `:filters`, driving `page/1`'s `:state` from each surface model (deleting the surface-local empty/error duplication), and riding the D-98-08 table-a11y fix (`<caption>` + `<thead>`/`<th scope=col>` + `scope=row` row-header + `data-label` on every data `<td>`) on the four table surfaces so the §C stacked-card `td::before` (authored in P1) drives off the same markup. Behavior contracts (`id`/`data-testid`/`phx-hook`) and PubSub full re-render preserved; no streams introduced; zero CSS edits; no P3-owned IA/route/confirm/microcopy work leaked in.**

## Performance

- **Duration:** ~8 min
- **Tasks:** 2 completed (6 atomic surface commits)
- **Files modified:** 6 (all `lib/rindle/admin/live/*_live.ex`)

## Accomplishments

- **Task 1 — Assets, Upload sessions, Doctor (3 atomic commits):**
  - **Assets** (`b9d53e8`): list render wrapped in `<.page state={list_state} error_surface="Assets">` with `:filters` + `:work` slots; `list_state/1` maps `error? → :error`, empty rows → `:empty`, else `:ok`. Table gains `<caption>Media assets`, `scope="row"` + `data-label` on the asset cell, `data-label` on State/Profile/Kind/Action. Detail render untouched.
  - **Upload sessions** (`966b658`): same pattern; `<caption>Upload sessions`, `scope="row"` on the session cell, `data-label` on all five columns; redacted `session_uri` preserved.
  - **Runtime/Doctor** (`caf0d8e`): Runtime-status band → `:summary`; doctor-checks table + failed-prerequisites + runtime-findings sections → `:work`; `:state={:ok|:error}` from `@error?`. Table gains `<caption>Runtime/Doctor checks`, `scope="row"` on the check cell, `data-label` on Check/Status/Summary/Fix.
- **Task 2 — Overview, Processing, Maintenance (3 atomic commits):**
  - **Overview** (`69cca15`): structural migration only — Runtime + Doctor summary → `:summary`, Recommendations → `:work`, `:state` from `@error?`. No data table, so no caption/scope/data-label. **Scope guard:** the `inspect/1` anti-pattern (1 occurrence) and triage rebuild are left for P3/D-98-10.
  - **Processing (Variants/Jobs)** (`771182f`): variant-state band → `:summary`, filters → `:filters`, buckets table + repair-recommendation section → `:work`; `list_state/1` maps `error? → :error`, empty findings → `:empty`. Table gains `<caption>`, `scope="row"` on the bucket cell, `data-label` on all four columns; redaction preserved. **Scope guard:** no new `variants-jobs/:id` route / `:show` run-detail (0 in router) — the borrowed `assets/:id` detail link is kept verbatim.
  - **Maintenance (Actions)** (`1051b0b`): structural migration only — Actions Directory → `:summary`, action-panel → `:work`, `:state` from `@error?`. **Scope guard:** inline confirm panels NOT rewired to `confirm_dialog/1` (0 occurrences), verb-bucket NOT distributed, microcopy ("Regenerate Variants", "Confirm broad regeneration") kept verbatim — all P3/D-98-10/11/§F.

## Task Commits

1. **Assets migrated onto page/1** — `b9d53e8` (feat)
2. **Upload sessions migrated onto page/1** — `966b658` (feat)
3. **Runtime/Doctor migrated onto page/1** — `caf0d8e` (feat)
4. **Overview migrated onto page/1 (structural)** — `69cca15` (feat)
5. **Processing (Variants/Jobs) migrated onto page/1** — `771182f` (feat)
6. **Maintenance (Actions) migrated onto page/1 (structural)** — `1051b0b` (feat)

## Files Created/Modified

- `lib/rindle/admin/live/assets_live.ex` — list render on `page/1` + caption/scope=row/data-label + `list_state/1`
- `lib/rindle/admin/live/upload_sessions_live.ex` — list render on `page/1` + caption/scope=row/data-label + `list_state/1`
- `lib/rindle/admin/live/runtime_doctor_live.ex` — render on `page/1` (`:summary` + `:work`) + table caption/scope=row/data-label
- `lib/rindle/admin/live/home_live.ex` — render on `page/1` (`:summary` + `:work`), structural only (P3 triage/`inspect` preserved)
- `lib/rindle/admin/live/variants_jobs_live.ex` — render on `page/1` (`:summary`/`:filters`/`:work`) + table caption/scope=row/data-label + `list_state/1`; borrowed detail link preserved
- `lib/rindle/admin/live/actions_live.ex` — render on `page/1` (`:summary` + `:work`), structural only (P3 confirm/microcopy preserved)

## Decisions Made

- **Row-header cell stays `<td scope="row">`, not `<th scope="row">`.** The P1 §C stacked-card CSS (`brandbook/tokens/rindle-admin.css` L1257-1287) flips only `td` to `display:block` and resolves `td::before { content: attr(data-label) }` at <760px. A `<th>` row-header would NOT participate in the stacked card. So the row-identifying cell keeps the `<td>` tag with a non-standard `scope="row"` attribute — exactly what the P1 CSS contract and the plan's `grep -c 'scope="row"'` acceptance require. This is the correct trade for a working gov.uk stacked card with no markup fork.
- **Caption uses `class="rindle-admin-visually-hidden"` (intended markup) despite the class not yet existing in CSS.** See Deviations — the missing utility is a P1 defect filed to `deferred-items.md`, not fixed here (no CSS edits in P2b, Pitfall 2).
- **Follow-up non-table sections live inside `:work`** (Doctor findings, Processing repair-recommendation), so they render only in the `:ok` state and the empty/error fallback fully replaces them. The Processing empty/error ExUnit test only asserts the fallback copy, so this `page/1` work-or-fallback behavior is correct and green.

## Deviations from Plan

### Filed (not fixed — Pitfall 2, CSS is P1)

**1. [Rule 3 boundary - filed, not fixed] Missing `.rindle-admin-visually-hidden` utility class.**
- **Found during:** Task 1 (Assets caption).
- **Issue:** D-98-08 / the plan call for a `<caption>` "visually-hidden ok" on each migrated table, but P1's generator never authored a general `.rindle-admin-visually-hidden` selector (`grep` over `brandbook/tokens/rindle-admin.css` returns 0). The `<thead>` is hidden at <760 via its own dedicated rule, but the caption has no utility, so it currently renders visibly at ≥760px.
- **Why not fixed here:** all CSS is authored in P1's `admin-css-build.mjs` (D-98-12/Pitfall 2). Adding the utility in P2b would hand-edit generated CSS and break the generated-CSS boundary.
- **Action taken:** authored the semantically-intended `<caption class="rindle-admin-visually-hidden">` on all four table surfaces (correct markup + a11y + acceptance grep satisfied) and filed the missing-CSS defect to `.planning/phases/98-.../deferred-items.md` with the exact recipe (clip/clip-path/position-absolute, mirroring the inline stacked `<thead>` rule) and the `requiredSelectors` addition for a P1/P4 fix.
- **Files modified:** the four table surfaces (markup); `deferred-items.md` (defect note). No CSS files touched.

No other deviations — the six migrations were implemented per the §A slot order, D-98-08 table-a11y, §C `data-label` contract, D-98-16 (no streams), and the P3 scope guards exactly as written.

**Total deviations:** 1 filed-not-fixed (P1 CSS defect, correctly escalated per Pitfall 2). 0 architectural changes. 0 CSS edits.

## Threat Surface Scan

No new security-relevant surface introduced. This is a pure structural markup migration: no new data is queried (T-98-02b-03 disposition = accept — redaction lives in Queries, untouched; the redacted `session_uri`/`provider_asset_id` strings remain redacted in the migrated markup, asserted by the `refute html =~ @secret_payload` / `@raw_provider_id` tests). Every existing `id`/`data-testid`/`phx-hook`/`phx-click`/form contract (T-98-02b-02 mitigation) is preserved — the full admin ExUnit suite (which asserts those seams) is green. Each surface compiled + stayed green before the next commit (T-98-02b-01 mitigation). No packages added (T-98-02b-SC).

## Verification Results

- `mix compile` (MIX_ENV=test) — clean after every surface (no errors/warnings).
- `mix test test/rindle/admin test/brandbook/admin_design_system_validation_test.exs --include integration` — **55 tests, 0 failures** (full admin behavior suite + brandbook DS static gate, against committed state).
- Per-surface behavior tests run green before each commit (Assets/Upload: `home_assets_upload_test.exs`; Doctor/Processing/Actions: `variants_runtime_actions_test.exs` + `actions_live_test.exs`).
- Acceptance greps:
  - `<.page` ≥1 in all six surfaces ✓
  - `<caption` = 1 in each of the four table surfaces ✓
  - `scope="row"` = 1 in each of the four table surfaces ✓
  - `data-label=` ≥1 in each table surface (assets 5, upload 5, doctor 4, variants 4) ✓
  - `phx-update="stream"` = 0 in all surfaces ✓ (no streams introduced, D-98-16)
  - six separate per-surface commits in `git log` ✓
- Scope guards: `inspect` still present in `home_live.ex` (P3) ✓; `variants-jobs/:id`/`:show` = 0 in router (P3) ✓; `confirm_dialog`/`modal`/`show_modal` = 0 in `actions_live.ex` (P3) ✓; "Regenerate Variants"/"Confirm broad regeneration"/`data-rindle-admin-confirm-input` kept verbatim ✓.
- `git diff --name-only` over the six commits — only the six `*_live.ex` files; **zero CSS files touched** ✓.

## Non-Inferable Backstops Deferred to P4 (Playwright, by design)

The `data-label` markup added here is what the P4 Playwright backstops READ; the behavior they prove is not provable by this plan's static gate (RESEARCH Pitfall 1/6):
1. At <760px each migrated table stacks (`display:block` + `td::before` resolves `attr(data-label)`); at ≥760px real `<table>` rows return.
2. The State/Job columns are NEVER `display:none` at any breakpoint (no priority-column hiding — the stacked card carries all columns).

## Known Stubs

None. The four table captions reference `.rindle-admin-visually-hidden`, a class P1 must author (filed P1 defect, not a stub — the markup contract is correct and the caption is functional/announced regardless of whether it is visually hidden). The P3-owned work (Overview triage rebuild, Processing `:show` route + run-detail, Maintenance confirm-dialog rewire / verb distribution / microcopy) is a deliberate staging boundary held by the scope guards, not a stub.

## Self-Check: PASSED

- All six modified files present on disk with the `<.page>` migration.
- All six task commits (`b9d53e8`, `966b658`, `caf0d8e`, `69cca15`, `771182f`, `1051b0b`) present in git history.
