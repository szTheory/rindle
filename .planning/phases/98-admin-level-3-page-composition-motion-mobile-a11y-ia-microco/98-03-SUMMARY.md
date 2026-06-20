---
phase: 98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco
plan: 03
subsystem: ui
tags: [admin, ia, routing, microcopy, triage-home, deep-links, variants-jobs-show, confirm-dialog, gds]

# Dependency graph
requires:
  - phase: 98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco
    plan: "01"
    provides: "page/1 scaffold + generated CSS (the surfaces this plan re-organizes render through page/1)"
  - phase: 98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco
    plan: "02a"
    provides: "confirm_dialog/1 + modal/1 overlay primitive (server-assign-driven inert via shell @dialog_open) — Processing regenerate + Maintenance owner-erasure confirms adopt it here"
  - phase: 98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco
    plan: "02b"
    provides: "all six surfaces migrated onto page/1 (the structural substrate this plan layers IA/microcopy onto)"
provides:
  - "Task-first nav: six relabeled/reordered items (Overview · Assets · Upload sessions · Processing · Doctor · Maintenance) with frozen slugs/suffixes (D-98-03)"
  - "GDS triage Overview off home_status/1: needs-attention deep-link band -> system-health chips -> recent activity -> vanity totals last; inspect/1 anti-pattern removed; affirmative all-clear copy (D-98-10)"
  - "Dedicated variants-jobs/:id :show route + Queries.variant_run_detail/1 (run-id then asset-id fallback) with redaction parity + one-run detail render (D-98-09)"
  - "Distributed Actions verb-bucket: regenerate -> Processing via confirm_dialog/1; reconcile/verify-storage -> Doctor; quarantine review -> asset detail; Maintenance keeps only owner/batch erasure (D-98-10/11)"
  - "All §F off-voice microcopy replaced (error_state, empty_state body, diagnostic sentence); confirm headings match {Verb} this {noun}?; no '!' in destructive bodies"
affects: [98-04, admin-playwright-backstops, admin-ia-microcopy-exunit-gate]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Deep-link IA: needs-attention entries are pure <a href> via admin_path/2 to ALREADY-PARSED handle_params filters (state=/class=) — no new routes/param sinks (D-98-10)"
    - "Distributed verb-bucket: contextual actions live on the surface where the operator already has context (regenerate->Processing, reconcile->Doctor, quarantine->asset detail); confirm flows use the shared confirm_dialog/1 with server-assign-driven inert"
    - "Detail :show route resolution by run-id-then-asset-id fallback so the index finding rows (which carry asset ids, not run ids) can deep-link to a real run detail with redaction parity"

key-files:
  created: []
  modified:
    - lib/rindle/admin/router.ex
    - lib/rindle/admin/queries.ex
    - lib/rindle/admin/components.ex
    - lib/rindle/admin/live/home_live.ex
    - lib/rindle/admin/live/variants_jobs_live.ex
    - lib/rindle/admin/live/actions_live.ex
    - lib/rindle/admin/live/runtime_doctor_live.ex
    - lib/rindle/admin/live/assets_live.ex

key-decisions:
  - "variant_run_detail/1 resolves the :id as a processing-run id first, then falls back to asset-id -> latest run. The index finding samples carry asset_id (not a processing-run id), so the per-row 'View details' link targets variants-jobs/#{asset_id}; the query loads the asset's most recent run. Redaction parity = asset_detail/1's processing_run_rows exposure (worker/state/attempt/error_reason); no new field beyond the existing :show pattern."
  - "Actions verb-bucket distribution is REAL (not additive): the variant_regeneration / lifecycle_repair / quarantine_review handlers + forms were REMOVED from actions_live.ex and Queries.actions_directory/0; regenerate re-homed on Processing with a confirm_dialog/1 flow, reconcile/verify-storage on Doctor, quarantine review on asset detail. Maintenance keeps only owner/batch erasure."
  - "Owner-erasure final confirm rewired to confirm_dialog/1; shell @dialog_open is driven off @action_state == :preview (server-assign source of truth), satisfying the D-98-11 reconnect-safe inert contract."
  - "live_indicator 'Updated just now' transient flip kept verbatim (passes the §F R4/R5 denylist; not one of the six mandated off-voice replacements) to preserve the broad PubSub-refresh ExUnit contract across surfaces."
  - "empty_state generic heading 'No records match this view' kept as the filtered-no-match fallback ONLY (§F-sanctioned); its body 'Runtime/Doctor' literal updated to 'Doctor'."

patterns-established:
  - "Atomic-per-task commits: route+query+detail (Task 1), IA+distribution (Task 2), microcopy (Task 3) — each compiled + green before the next."
  - "Behavior-contract test updates: stale ExUnit assertions encoding the OLD nav labels / old Maintenance directory were updated to the new §E IA contract (not weakened); new distribution homes asserted on Processing/Doctor/asset-detail."

requirements-completed: [UPLIFT-07, UPLIFT-08]

# Metrics
duration: 16min
completed: 2026-06-18
status: complete
---

# Phase 98 Plan 03: Task-First IA + Routing + Microcopy Summary

**Turned the six-surface admin console into a gov.uk task-first system: relabeled/reordered the nav to six task-scent items, rebuilt Overview as a GDS triage home (needs-attention deep-link band → system-health chips → recent activity → vanity totals last, dropping the `inspect/1` anti-pattern), added the dedicated `variants-jobs/:id` `:show` route + a redaction-parity `variant_run_detail/1` query + one-run detail render, distributed the "Actions" junk-drawer verb-bucket to its contextual surfaces (regenerate → Processing via `confirm_dialog/1`, reconcile → Doctor, quarantine review → asset detail; Maintenance keeps only owner/batch erasure), and applied every §F off-voice microcopy replacement — all proven through the admin ExUnit suite + brandbook static gate, no new routes/param sinks, no CSS edits.**

## Performance

- **Duration:** ~16 min
- **Completed:** 2026-06-18T06:26:41Z
- **Tasks:** 3 completed
- **Files modified:** 8 source + 4 test

## Accomplishments

- **Task 1 — dedicated Processing detail (D-98-09):** `variants-jobs/:id` `:show` route added inside the existing `live_session` (auth-gated mount macro byte-unchanged). New `Queries.variant_run_detail/1` resolves the id as a run-id first, then falls back to asset-id → latest run, returning `{:ok, %{generated_at, run, asset}}` / `{:error, :not_found}` with redaction parity to `asset_detail/1`. `variants_jobs_live.ex` gained a `handle_params(%{"id"=>id})` clause, a detail-aware PubSub re-render, and a one-run detail render head; the borrowed `assets/:id` list link became `variants-jobs/#{asset_id}` ("View details" text preserved).
- **Task 2 — task-first IA (D-98-03/10/11):** nav relabeled/reordered to the six task-first items (slugs/suffixes frozen). Overview rebuilt as a GDS triage home off `home_status/1` (no query change) — needs-attention band of non-zero problem counts as pure `<a>` deep-links to already-parsed filters, three system-health chips, recent activity, vanity totals last, affirmative all-clear copy. The Actions verb-bucket was distributed: regenerate → Processing (`confirm_dialog/1`), reconcile/verify-storage → Doctor, quarantine review → asset detail; Maintenance keeps only contextless owner/batch erasure (directory trimmed, distributed handlers/forms removed). Owner-erasure confirm rewired to `confirm_dialog/1` (server-assign-driven inert).
- **Task 3 — §F microcopy:** `error_state` doubled copy → "This surface could not load." + cause+next-action body; "Retry load" → "Retry"; `empty_state` body "Runtime/Doctor" → "Doctor" (generic heading kept as the filtered-no-match fallback only); variants long diagnostic sentence → "This is a diagnostic recommendation. No repair runs on this surface." Confirm headings match `{Verb} this {noun}?` ("Erase this owner?", "Regenerate stale variants?"); no "!" in destructive bodies; no R4 hype / R5 vague labels in admin source.

## Task Commits

1. **Task 1: variants-jobs/:id :show route + run-detail query** — `b6ecf73` (feat)
2. **Task 2: task-first IA — nav relabel, triage Overview, deep-links, distributed actions** — `f8975f3` (feat)
3. **Task 3: apply §F microcopy replacements** — `8d8d8af` (feat)

## Files Created/Modified

- `lib/rindle/admin/router.ex` — new `variants-jobs/:id` `:show` route (auth macro untouched)
- `lib/rindle/admin/queries.ex` — `variant_run_detail/1` (run-id/asset-id fallback + redaction parity), extracted `processing_run_row/1`, trimmed `actions_directory/0` to owner/batch erasure
- `lib/rindle/admin/components.ex` — `@surfaces` task-first labels/order; `error_state`/`empty_state` §F copy
- `lib/rindle/admin/live/home_live.ex` — GDS triage Overview (deep-links, health chips, activity, totals; no `inspect/1`)
- `lib/rindle/admin/live/variants_jobs_live.ex` — `handle_params`/render `:show` detail clause; distributed Regenerate-variants `confirm_dialog/1` flow; diagnostic-sentence microcopy
- `lib/rindle/admin/live/actions_live.ex` — Maintenance = owner/batch erasure only; owner-erasure confirm via `confirm_dialog/1`; distributed action handlers/forms removed
- `lib/rindle/admin/live/runtime_doctor_live.ex` — relabeled cross-links + distributed Reconcile/Verify-storage section
- `lib/rindle/admin/live/assets_live.ex` — distributed Quarantine-review section on quarantined asset detail
- `test/rindle/admin/live/{home_assets_upload,variants_runtime_actions,actions_live}_test.exs`, `test/rindle/admin/queries_test.exs` — updated to the new IA/microcopy contract + new distribution homes asserted

## Decisions Made

See `key-decisions` frontmatter. Highlights: run-id-then-asset-id resolution for the detail route (index samples lack run ids); real (not additive) distribution of the verb-bucket; `confirm_dialog/1` adoption for both the Processing regenerate and the Maintenance owner-erasure confirm; kept "Updated just now" and the generic filtered-no-match heading per §F's allowances.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated stale ExUnit behavior-contract assertions to the new §E/§F IA contract**
- **Found during:** Task 2 (nav relabel + Overview rebuild + Actions distribution)
- **Issue:** `home_assets_upload_test.exs`, `variants_runtime_actions_test.exs`, `actions_live_test.exs`, and `queries_test.exs` encoded the OLD nav labels ("Home/Status"/"Variants/Jobs"/"Runtime/Doctor"/"Actions"), the OLD Overview structure (Runtime summary/Doctor summary/Recommendations/Inspect assets), and the OLD five-action Maintenance directory + per-action workflow tests. The §E IA change deliberately invalidates these; left unchanged they blocked the in-scope work.
- **Fix:** Updated `@surfaces` to the six task-first labels; rewrote the Overview test to assert the triage-home sections; updated the Doctor cross-link assertions; rewrote the Maintenance directory test + `actions_directory/0` test to the trimmed contextless-ops contract; relocated the regenerate/quarantine workflow assertions to their new surfaces (Processing/asset detail). The §E/§F merge-gate ExUnit *clauses* are authored in P4; these edits keep the EXISTING behavior suite green against the new contract (no coverage weakened).
- **Files modified:** the four test files listed above
- **Verification:** `mix test test/rindle/admin` — 54 tests, 0 failures
- **Committed in:** `f8975f3` (Task 2)

**2. [Rule 1 - Bug] Removed now-dead distributed-action code from actions_live.ex**
- **Found during:** Task 2 (Actions distribution)
- **Issue:** After trimming the Maintenance directory to owner/batch erasure, the `variant_regeneration` / `lifecycle_repair` render clauses, `render_*_state` helpers, handlers, and `run_lifecycle_action/1` were unreachable dead code.
- **Fix:** Removed them; regenerate was genuinely re-homed on Processing (`confirm_dialog/1` flow), reconcile on Doctor, quarantine on asset detail. Left a NOTE comment documenting the distribution.
- **Files modified:** `lib/rindle/admin/live/actions_live.ex`
- **Verification:** Clean compile (no unused-fn warnings); admin suite green.
- **Committed in:** `f8975f3` (Task 2)

---

**Total deviations:** 2 auto-fixed (1 blocking test-contract update, 1 dead-code removal).
**Impact on plan:** Both necessary to land the §E IA change on a green suite. No scope creep — the distribution and detail route are exactly the plan's mandated work; the test updates reflect intentional behavior changes (P4 authors the net-new §E/§F gate clauses).

## Issues Encountered

- Local Postgres pool emits `too_many_connections` noise during `mix test` (environment, not a test failure) — all targeted suites report 0 failures.

## Carried-Forward / Out-of-Scope (honored, not fixed)

- **`.rindle-admin-visually-hidden` CSS defect (filed by 98-02b):** this plan's scope does NOT touch the brandbook CSS pipeline (D-98-12 generated-CSS boundary), so per the carryover guidance the missing utility is left for the gate close-out plan (98-04). The existing `<caption class="rindle-admin-visually-hidden">` markup on the four table surfaces is honored unchanged. Still recorded in `deferred-items.md` + the STATE blocker.
- **Playwright e2e backstops (admin-polish.js / admin-screenshots.spec):** P4-owned by design (PATTERNS). §E IA + §F microcopy are proven in ExUnit here; the net-new §E/§F denylist/lexicon/nav-order/triage-DOM-order assertions are authored in 98-04.

## Threat Surface Scan

The new `variants-jobs/:id` route accepts an untrusted `:id` (T-98-03-01/02/03): `variant_run_detail/1` casts via `Ecto.UUID.cast` (non-UUID/unknown → `{:error, :not_found}`, mirroring `asset_detail/1`), exposes only the existing `processing_run_rows`/`asset_detail_row` redaction surface (no new PII / raw provider id / unredacted worker beyond the existing `:show` pattern), and was added INSIDE the existing `live_session`/auth macro scope (byte-unchanged, verified via `git diff`). Deep-links (T-98-03-04) reuse already-parsed `handle_params` filters over the existing allowlists — no raw param interpolation, no new sink. Zero new packages (T-98-03-SC). No threat flags beyond the registered, mitigated set.

## Next Phase Readiness

- 98-04 (gate close-out) authors the net-new §E/§F ExUnit clauses (nav order/labels/hrefs, triage DOM order, deep-link params, affirmative all-clear, microcopy denylist/lexicon/off-voice) and the Playwright backstops — the markup/copy is now correct for them to pass.
- 98-04 also owns the `.rindle-admin-visually-hidden` CSS pipeline fix (generated-CSS boundary).

## Self-Check: PASSED

- All 8 modified source files + SUMMARY.md present on disk.
- All three task commits (`b6ecf73`, `f8975f3`, `8d8d8af`) present in git history.
- `mix test test/rindle/admin test/brandbook/admin_design_system_validation_test.exs --include integration` — 54 tests, 0 failures.

---
*Phase: 98-admin-level-3-page-composition-motion-mobile-a11y-ia-microco*
*Completed: 2026-06-18*
