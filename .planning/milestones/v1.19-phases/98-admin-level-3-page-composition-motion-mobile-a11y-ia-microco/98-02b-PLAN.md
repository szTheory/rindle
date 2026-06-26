---
phase: 98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco
plan: 02b
type: execute
wave: 3
depends_on: ["98-02a"]
files_modified:
  - lib/rindle/admin/live/home_live.ex
  - lib/rindle/admin/live/assets_live.ex
  - lib/rindle/admin/live/upload_sessions_live.ex
  - lib/rindle/admin/live/variants_jobs_live.ex
  - lib/rindle/admin/live/runtime_doctor_live.ex
  - lib/rindle/admin/live/actions_live.ex
autonomous: true
requirements: [UPLIFT-03, UPLIFT-05, UPLIFT-06]
tags: [admin, migration, page-scaffold, table-a11y, caption, scope, data-label, live-view]

must_haves:
  truths:
    - "All six admin surfaces render their content through page/1 (the :work slot holds the primary table/section); no surface declares a page-local grid/measure wrapper (§A, no page-local display:grid outside the scaffold selector)."
    - "Each surface's data <table> gains a <caption> (visually-hidden ok) naming the surface, a <thead> with <th scope=col>, and scope=row on the row-header cell (§D, D-98-08)."
    - "Each data-row <td> carries data-label=\"<column>\" so §C's stacked-card CSS (authored in P1) drives off the SAME markup — no markup fork, no priority-column hiding (D-98-08, §C)."
    - "Every surface preserves its existing id/data-testid/phx-hook behavior contract and its PubSub full re-render (load/load_list + :for, refreshed on {:rindle_event}); NO phx-update=stream is introduced (D-98-16, VIS-02)."
    - "Each surface migration is ONE ATOMIC COMMIT; each surface compiles and its behavior e2e stays green after its own commit (gov.uk never-half-broken, D-98-02, Pitfall 4)."
    - "[NON-INFERABLE / Playwright-backstop, asserted in P4] At <760px each migrated table stacks (display:block + ::before data-label); State/Job columns are never display:none at any breakpoint (§C)."
  artifacts:
    - path: "lib/rindle/admin/live/assets_live.ex"
      provides: "Assets surface migrated onto page/1 with caption/scope/data-label"
      contains: "<.page"
    - path: "lib/rindle/admin/live/home_live.ex"
      provides: "Overview surface rendered through page/1 (triage rebuild is P3; structural migration here)"
      contains: "<.page"
  key_links:
    - from: "lib/rindle/admin/live/*_live.ex"
      to: "lib/rindle/admin/components.ex page/1"
      via: "each surface's render/1 wraps its table/section in <.page> slots (:summary/:filters/:work/:aside/:actions) with :state driving empty/error/loading"
      pattern: "<.page"
    - from: "each surface <td data-label>"
      to: "brandbook generated .rindle-admin-table td::before { content: attr(data-label) }"
      via: "the stacked-card transform (authored in P1) reads the data-label added on each <td> during migration"
      pattern: "data-label="
---

<objective>
Migrate each of the six `*_live.ex` admin surfaces (Overview, Assets, Upload sessions, Processing, Doctor, Maintenance) from hand-rolled `<table>`/`<section>` markup onto the `page/1` scaffold, ONE ATOMIC COMMIT PER SURFACE. The `<caption>`/`<thead>`/`scope` a11y fix and the `data-label` stacked-card markup ride each migration. Implements D-98-02 (P2b half of the relief-valve split) + D-98-08.

Purpose: page/1 (P1) and the §D primitives + overlay (P2a) now exist; this plan composes the surfaces onto them. Atomic-per-surface migration (gov.uk "never half-broken", Pitfall 4) keeps each surface shippable and its behavior e2e green. NO CSS edits (RESEARCH Pitfall 2 — all CSS is P1); NO streams (D-98-16); NO microcopy/IA/routing changes (those are P3) — pure structural migration + table a11y + data-label.

Output: all six surfaces render through page/1 with semantic, stacked-card-ready, accessible tables; behavior contracts (id/data-testid/phx-hook) and PubSub re-render preserved.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-CONTEXT.md
@.planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-UI-SPEC.md
@.planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-PATTERNS.md
@.planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-RESEARCH.md
@.planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-01-SUMMARY.md
@.planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-02a-SUMMARY.md
</context>

<artifacts_this_phase_produces>
This plan (P2b) MODIFIES existing surface render functions; it creates NO new module-level symbols. New per-row markup: `data-label="..."` attrs on each `<td>`, `<caption>` and `scope="row"` per surface table. The Processing `:show` detail render, the new route, the IA triage rebuild, and microcopy are NOT here — they are P3. P2b is structural migration + table a11y + data-label ONLY.
</artifacts_this_phase_produces>

<tasks>

<task type="auto" tdd="false">
  <name>Task 1: Migrate Assets, Upload sessions, and Doctor surfaces onto page/1 (3 atomic commits)</name>
  <read_first>
    - lib/rindle/admin/components.ex (the new page/1 scaffold from P1 — slots/:state API; existing empty_state/error_state/table/status_chip/admin_path)
    - lib/rindle/admin/live/assets_live.ex (READ FULLY — its hand-rolled <table> ~L109-141 with <thead>/<th scope=col>; its handle_params + handle_info({:rindle_event,...}) ~L43-52; the index/detail render clauses)
    - lib/rindle/admin/live/upload_sessions_live.ex (READ FULLY — its table markup + render)
    - lib/rindle/admin/live/runtime_doctor_live.ex (READ FULLY — its section/table markup + render)
    - .planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-UI-SPEC.md §A (slot order) + §D (caption/thead/scope) + §C (data-label stacked card)
    - .planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-PATTERNS.md (six surface migrations pattern: the <table> block moves INTO :work; add caption + scope=row + data-label; preserve PubSub re-render; one atomic commit per surface)
    - .planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-CONTEXT.md (D-98-02, D-98-08, D-98-16)
  </read_first>
  <action>
    For EACH of Assets, Upload sessions, Doctor — as a SEPARATE atomic commit (D-98-02, Pitfall 4):
    Wrap the surface's render in `<.page state={...}>` and move its existing primary `<table>`/`<section>` into the `:work` slot. Put the surface's summary/triage band (if any) into `:summary`, filters into `:filters`, and any footer actions into `:actions`. Drive the scaffold `:state` from the surface's existing model (empty list → `:empty`, load error → `:error`, etc.) so the surface stops re-implementing empty/error markup — delete the surface's own empty/error duplication and rely on page/1's `:state` fallbacks. Remove any page-local wrapper div carrying grid/measure (§A — that is banned page-local styling now living in the scaffold). On the table (D-98-08): add a `<caption>` (visually-hidden is fine) naming the surface (e.g. "Media assets"); ensure `<thead>` with `<th scope="col">` for column headers; add `scope="row"` on the row-header cell (the cell that identifies the row, e.g. the asset id/name); add `data-label="<column header text>"` to EVERY data `<td>` so §C's stacked-card `::before` (authored in P1) reads it. NO markup fork, NO priority-column hiding (§C). PRESERVE every existing `id`/`data-testid`/`phx-hook` (frozen behavior contract, STATE migration discipline) and the PubSub full re-render: keep `load`/`load_list` into assigns + `:for` comprehension refreshed on `handle_info({:rindle_event, _, _}, socket)` — do NOT introduce `phx-update="stream"` (D-98-16). Make NO microcopy/label changes (P3, §F) and NO routing/IA changes (P3) — copy strings stay verbatim. Do NOT edit any CSS (all CSS is P1; if a selector is genuinely missing, that is a P1 defect — file it, do not add CSS here, Pitfall 2).
  </action>
  <verify>
    <automated>mix compile 2>&1 | grep -iv "Mox\|test/support" | grep -i "error" || true ; mix test test/brandbook/admin_design_system_validation_test.exs ; mix test test/rindle/admin 2>/dev/null || true</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "<.page" lib/rindle/admin/live/assets_live.ex lib/rindle/admin/live/upload_sessions_live.ex lib/rindle/admin/live/runtime_doctor_live.ex` shows ≥1 in each.
    - `grep -c "<caption" lib/rindle/admin/live/assets_live.ex` ≥ 1; same for upload_sessions and runtime_doctor.
    - `grep -c 'scope="row"' lib/rindle/admin/live/assets_live.ex` ≥ 1 (and the other two).
    - `grep -c 'data-label=' lib/rindle/admin/live/assets_live.ex` ≥ 1 (and the other two) — every data column labeled.
    - `grep -c 'phx-update="stream"' lib/rindle/admin/live/assets_live.ex lib/rindle/admin/live/upload_sessions_live.ex lib/rindle/admin/live/runtime_doctor_live.ex` returns 0 (no streams introduced).
    - `git -C /Users/jon/projects/rindle log --oneline -3` shows three separate per-surface commits (atomic-per-surface).
    - All modules compile; ExUnit static gate green.
  </acceptance_criteria>
  <done>Assets, Upload sessions, and Doctor render through page/1 with caption/thead/scope/scope=row/data-label, no page-local grid, preserved behavior contracts + PubSub re-render, no streams, no copy/IA changes — three atomic commits.</done>
</task>

<task type="auto" tdd="false">
  <name>Task 2: Migrate Overview, Processing, and Maintenance surfaces onto page/1 (3 atomic commits)</name>
  <read_first>
    - lib/rindle/admin/components.ex (page/1 from P1; modal/confirm_dialog from P2a — for Maintenance's confirm flows, but only structurally; full confirm rewiring is P3)
    - lib/rindle/admin/live/home_live.ex (READ FULLY — note the inspect/1 anti-pattern ~L56; the triage rebuild is P3, here ONLY wrap render in page/1 structurally)
    - lib/rindle/admin/live/variants_jobs_live.ex (READ FULLY — its table + the borrowed assets/:id detail link ~L104-110; the new :show route + run-detail is P3, here ONLY structural migration + table a11y/data-label)
    - lib/rindle/admin/live/actions_live.ex (READ FULLY — its sections + inline confirm panels ~L609-779; the confirm→confirm_dialog rewire + distribution is P3, here ONLY wrap render in page/1 + any table a11y)
    - .planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-UI-SPEC.md §A / §C / §D (same as Task 1)
    - .planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-PATTERNS.md + 98-CONTEXT.md (D-98-02/08/16)
  </read_first>
  <action>
    For EACH of Overview, Processing (variants_jobs_live.ex), Maintenance (actions_live.ex) — as a SEPARATE atomic commit:
    Same structural migration as Task 1: wrap render in `<.page state={...}>`, move the primary table/section into `:work`, summary into `:summary`, filters into `:filters`, footer actions into `:actions`; remove page-local grid/measure wrappers; drive `:state` from the model and delete duplicated empty/error markup. For any data `<table>` on these surfaces add `<caption>`/`<thead>`/`<th scope=col>`/`scope=row`/`data-label` (D-98-08, §C). Preserve id/data-testid/phx-hook contracts + PubSub re-render; introduce NO streams.
    SCOPE GUARD — these three surfaces have P3 work that must NOT be done here:
    - Overview: do NOT rebuild the triage home or replace the `inspect/1` anti-pattern yet (that is P3/D-98-10). Migrate the CURRENT structure onto page/1 structurally so the surface stays green; P3 rebuilds the `:summary`/needs-attention content.
    - Processing: do NOT add the new `variants-jobs/:id` route, the `:show` render clause, or the new Queries run-detail (P3/D-98-09). Keep the current (borrowed) detail link as-is for now; migrate index structure + table a11y/data-label only.
    - Maintenance: do NOT distribute the Actions verb-bucket or rewire the inline confirm panels to `confirm_dialog/1` yet (P3/D-98-10/11). Migrate the current sections onto page/1 structurally.
    Make NO microcopy changes (P3, §F). Do NOT edit any CSS (Pitfall 2).
  </action>
  <verify>
    <automated>mix compile 2>&1 | grep -iv "Mox\|test/support" | grep -i "error" || true ; mix test test/brandbook/admin_design_system_validation_test.exs ; mix test test/rindle/admin 2>/dev/null || true</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "<.page" lib/rindle/admin/live/home_live.ex lib/rindle/admin/live/variants_jobs_live.ex lib/rindle/admin/live/actions_live.ex` shows ≥1 in each.
    - Any data table on these surfaces carries `<caption` + `scope="row"` + `data-label=` (grep ≥1 where a table exists).
    - `grep -c 'phx-update="stream"' lib/rindle/admin/live/home_live.ex lib/rindle/admin/live/variants_jobs_live.ex lib/rindle/admin/live/actions_live.ex` returns 0.
    - Overview still contains the current structure (P3 rebuild not done): `grep -n "inspect" lib/rindle/admin/live/home_live.ex` MAY still match — it is replaced in P3, not here.
    - variants_jobs_live.ex still references the existing detail link (new :show route not added here): `grep -c "/variants-jobs/:id\|:show" lib/rindle/admin/router.ex` is unchanged from pre-plan.
    - `git -C /Users/jon/projects/rindle log --oneline -3` shows three separate per-surface commits.
    - All modules compile; ExUnit static gate green.
  </acceptance_criteria>
  <done>Overview, Processing, and Maintenance render through page/1 with table a11y + data-label, preserved behavior contracts + PubSub, no streams — three atomic commits; P3-owned triage rebuild / new route / confirm-rewire / distribution / microcopy deliberately NOT done here.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| operator (browser) → admin LiveView render | Migrating markup must not drop existing access controls or behavior contracts (phx-hook/data-testid) the auth-gated surfaces rely on |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-98-02b-01 | Tampering | A half-migrated surface ships broken (compile/render failure) exposing a degraded console | mitigate | One atomic commit per surface; each compiles + behavior e2e green before next (D-98-02, Pitfall 4) |
| T-98-02b-02 | Repudiation/Integrity | Dropping a frozen id/data-testid/phx-hook silently breaks a behavior gate | mitigate | Preserve every id/data-testid/phx-hook (STATE migration discipline); behavior e2e per surface |
| T-98-02b-03 | Information Disclosure | Re-rendered table accidentally surfaces a column/value previously redacted | accept | No new data is queried here (structural migration only); redaction lives in Queries, untouched; Processing run-detail redaction is P3's threat |
| T-98-02b-SC | Tampering | npm/node package installs | mitigate | N/A — zero new packages this phase |
</threat_model>

<verification>
- ExUnit static gate green after each surface (CSS untouched → no drift).
- Six atomic commits; each surface compiles + keeps its behavior e2e green.
- No phx-update=stream anywhere; PubSub re-render preserved.
- The <760 stacked-card display flip + never-display:none-columns are NON-INFERABLE Playwright backstops proven in P4 (the data-label markup added here is what they read).
</verification>

<success_criteria>
- All six surfaces render through page/1 with semantic accessible tables (caption/thead/scope/scope=row) and data-label stacked-card markup.
- Behavior contracts + PubSub full re-render preserved; no streams; no CSS edits; no P3-owned IA/route/confirm/microcopy work leaked in.
- ExUnit gate green; migrations are atomic-per-surface.
</success_criteria>

<output>
Create `.planning/phases/98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco/98-02b-SUMMARY.md` when done.
</output>
