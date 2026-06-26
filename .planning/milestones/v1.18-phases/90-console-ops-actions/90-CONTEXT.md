# Phase 90: Console Ops Actions - Context

**Gathered:** 2026-06-12 (assumptions mode, deepened with subagent research)
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 90 adds operational console actions for existing lifecycle capabilities only.
It turns the existing `Actions` surface into an executable ops hub for owner
erasure, batch erasure, variant regeneration, quarantine review, and lifecycle
repair. It must keep the console inside the v1.18 scope, reuse existing facade
and ops capabilities, and avoid new lifecycle semantics.

This phase does not add new public admin query helpers, new lifecycle
transitions, force-delete semantics, un-quarantine, Cohort demo changes,
deterministic E2E, screenshot polish, or docs/facade parity. Those remain
scoped to phases 91-93.
</domain>

<decisions>
## Implementation Decisions

### Actions Surface Architecture

- **D-90-01:** Keep `lib/rindle/admin/live/actions_live.ex` as the single
  executable action hub for Phase 90. The LiveView owns action state, preview
  orchestration, confirmation gating, receipts, and screen-level UX.
- **D-90-02:** Add a hidden internal command adapter such as
  `Rindle.Admin.Actions` only if needed for input normalization, typed
  confirmation enforcement, dispatch, and receipt shaping. Do not add public
  `Rindle.admin_*` helpers or new admin facade functions.
- **D-90-03:** Keep action reads, collateral preview data, quarantine triage,
  and eligible repair/regeneration targets in `Rindle.Admin.Queries`. The
  public `Rindle` facade remains unchanged apart from using already-shipped
  lifecycle APIs.
- **D-90-04:** Use page-scoped action panels under the existing Actions route.
  Do not use modal-first workflows or add new top-level navigation.

### Owner And Batch Erasure

- **D-90-05:** Owner erasure and batch erasure are preview-first destructive
  flows. The user inputs scope, sees the preview report, enters an exact typed
  confirmation, then executes and receives a durable receipt.
- **D-90-06:** The erasure confirmation phrase for a single owner is
  `ERASE <owner_type>:<owner_id>`. The batch phrase is `ERASE <N> OWNERS`.
- **D-90-07:** Confirmation becomes invalid if the scope input changes after the
  preview. Execution remains disabled until a fresh preview and matching typed
  confirmation exist.
- **D-90-08:** Receipts must render the existing erasure report vocabulary:
  `attachments_to_detach`, `assets_to_purge`, `retained_shared_assets`,
  `purge_enqueued`, and `purge_already_queued`.
- **D-90-09:** Batch partial failure is not a generic error-only path. The UI
  must render a committed partial receipt from `detail.partial_report` and name
  the failing owner safely.
- **D-90-10:** No force-delete, cascade, scheduler, cron, or unguarded purge
  behavior is added in Phase 90. LIFE-06 remains deferred.

### Variant Regeneration And Lifecycle Repair

- **D-90-11:** Keep lifecycle repair and broad regeneration as separate action
  lanes. Do not collapse them into one generic "repair variants" button.
- **D-90-12:** Asset-scoped lifecycle repair uses the public facade only:
  `Rindle.reprobe/1` and `Rindle.requeue_variants/2`. `requeue` targets only
  failed/cancelled variants and may accept `variant_names: [...]`.
- **D-90-13:** Broad stale/missing regeneration uses the existing internal
  maintenance implementation `Rindle.Ops.VariantMaintenance.regenerate_variants/1`
  and remains the broad maintenance lane matching `mix rindle.regenerate_variants`.
- **D-90-14:** Regeneration filters stay limited to the current maintenance
  contract: `profile` and `variant_name`. Do not introduce a new public facade
  wrapper for broad regeneration.
- **D-90-15:** Repair/regeneration receipts must show target scope, counters,
  skipped work, errors, and any queued async work. For regeneration, show that
  processing continues asynchronously through Oban.
- **D-90-16:** Use a normal confirm/submit pattern for scoped repair. Reserve
  the strongest destructive confirmation UX for erasure; broad unfiltered
  regeneration may require an extra deliberate confirmation, but not the erasure
  typed phrase.

### Quarantine Review And Security

- **D-90-17:** Quarantine review remains read-only triage over quarantined
  assets. It may link to supported erasure/deletion escalation paths, but it
  must not add release/restore/un-quarantine, direct row mutation, or scanner
  reclassification.
- **D-90-18:** Quarantine review microcopy must state that quarantined assets
  are blocked from delivery and that Rindle Admin does not release them from
  quarantine.
- **D-90-19:** If the console offers a delete/removal path from quarantine, it
  must route through supported owner-erasure/deletion semantics with preview and
  confirmation. No direct purge shortcut is introduced.

### UI, Microcopy, And Test Shape

- **D-90-20:** Keep the UX as a single page-scoped Actions hub with
  action-specific panels in the existing `rindle-admin` design system.
- **D-90-21:** Receipts are inline and persistent within LiveView state. Toasts
  are supplemental only.
- **D-90-22:** Add stable selectors for action flows so LiveView tests can
  assert state transitions deterministically, including preview, confirmation,
  executing, receipt, and error states.
- **D-90-23:** Use concrete operator microcopy: `Preview owner erasure`,
  `Erase owner`, `Preview batch erasure`, `Erase owners`, `Reprobe asset`,
  `Requeue variants`, `Regenerate variants`, and `Review quarantine`.
- **D-90-24:** The UI must expose what changed and what did not change. Receipts
  should name the operation, scope, counters, queued async work, and a stable
  receipt identifier for tests.
- **D-90-25:** Preserve `data-theme="light|dark|auto"` and the generated
  `rindle-admin` CSS contract from Phase 88. Do not add runtime UI dependencies.

### the agent's Discretion

Routine helper naming, component decomposition, private module boundaries, and
exact selector naming can be decided during planning as long as the locked
public and security boundaries above remain intact.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.planning/ROADMAP.md` - Phase 90 goal, dependencies, and success criteria.
- `.planning/REQUIREMENTS.md` - ADMIN-04 and v1.18 scope boundaries.
- `.planning/PROJECT.md` - v1.18 charter, public API boundary, and escalation rules.
- `.planning/STATE.md` - current milestone position and Phase 90 readiness.
- `.planning/METHODOLOGY.md` - adopter-first, repo-truth, research-first, and least-surprise lenses.
- `.planning/phases/86-research-architecture-lock/86-CONTEXT.md` - mount/auth/query/CSS boundaries that Phase 90 must not reopen.
- `.planning/phases/87-docker-demo-dx/87-CONTEXT.md` - future admin URL target and Docker preview stability.
- `.planning/phases/88-admin-design-system-ui-kit/88-CONTEXT.md` - generated console CSS, theme behavior, and component inventory.
- `.planning/phases/89-console-read-surfaces/89-CONTEXT.md` - read-only Actions surface, hidden query boundary, and optional-dependency proof.
- `guides/admin_console_architecture.md` - router-macro and hidden admin boundary.
- `guides/admin_console_ia.md` - task-first surface map and diagnostics-before-actions ordering.
- `guides/ui_principles.md` - confirmation, receipts, selector, accessibility, and destructive-action rules.
- `guides/admin_design_system.md` - package/runtime UI contract for the console kit.
- `guides/rindle_admin_css.md` - generated CSS and theme contract.
- `guides/admin_console_motion.md` - motion constraints and reduced-motion behavior.
- `guides/operations.md` - canonical task/verb boundaries for repair and regeneration.
- `lib/rindle/admin/live/actions_live.ex` - current read-only Actions placeholder and target for Phase 90.
- `lib/rindle/admin/queries.ex` - current action metadata and query boundary.
- `lib/rindle/admin/components.ex` - existing admin component primitives.
- `lib/rindle/admin/router.ex` - mountable console boundary.
- `lib/rindle.ex` - public erasure/repair facade contract.
- `lib/rindle/internal/owner_erasure.ex` - preview/execute report vocabulary and async purge semantics.
- `lib/rindle/ops/lifecycle_repair.ex` - asset-scoped repair semantics.
- `lib/rindle/ops/variant_maintenance.ex` - broad stale/missing regeneration semantics.
- `lib/rindle/domain/asset_fsm.ex` - quarantine deletion-only lifecycle boundary.
- `lib/rindle/domain/media_asset.ex` - quarantined state meaning.
- `lib/rindle/workers/promote_asset.ex` - quarantine persistence and error_reason behavior.
- `lib/mix/tasks/rindle.batch_owner_erasure.ex` - batch erasure CLI contract.
- `lib/mix/tasks/rindle.regenerate_variants.ex` - broad regeneration CLI contract.
- `test/rindle/admin/queries_test.exs` - read-model contract and action metadata checks.
- `test/rindle/admin/live/variants_runtime_actions_test.exs` - existing Actions surface behavior.
- `test/rindle/ops/lifecycle_repair_test.exs` - repair semantics and error shapes.
- `test/rindle/ops/variant_maintenance_test.exs` - broad regeneration semantics and filters.
- `test/rindle/owner_erasure_test.exs` - single-owner erasure semantics.
- `test/rindle/owner_erasure_batch_test.exs` - batch erasure semantics and partial failures.
- `test/rindle/api_surface_boundary_test.exs` - public API boundary guardrails.
- `prompts/phoenix-media-uploads-lib-deep-research.md` - prior art on repair, quarantine, and day-2 ops.
- `prompts/gsd-rindle-elixir-oss-dna.md` - Elixir OSS decision defaults and footgun ledger.
- `prompts/gsd-rindle-gsd-bootstrap-brief.md` - core operating values for the project.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `ActionsLive` already exists as the routeable placeholder for this phase.
- `Rindle.Admin.Queries.actions_directory/0` already advertises the Phase 90
  operation categories.
- `Rindle.preview_owner_erasure/2`, `Rindle.erase_owner/2`,
  `Rindle.preview_batch_owner_erasure/2`, and `Rindle.erase_batch_owner_erasure/2`
  already provide stable preview/execute vocabulary and async purge semantics.
- `Rindle.reprobe/1`, `Rindle.requeue_variants/2`, and
  `Rindle.Ops.VariantMaintenance.regenerate_variants/1` already encode the
  repair/regeneration lanes.
- The admin component kit already provides status chips, tables, confirm UI,
  toasts, and `rindle-admin` styling.

### Established Patterns

- Public facade expansion is treated as high blast radius.
- Optional integrations stay behind `Code.ensure_loaded?/1` boundaries.
- Admin reads stay in `Rindle.Admin.Queries`; writes go through existing
  operations or facades.
- Operator flows are explicit and task-first, not dashboard sprawl.
- Console receipts should reflect actual queued work and async semantics rather
  than implying synchronous completion.

### Integration Points

- `ActionsLive` connects to the hidden admin command adapter and the existing
  query/ops facades.
- The erasure flow reuses owner and batch erasure report vocabulary.
- The repair flow reuses asset-scoped repair and variant regeneration reports.
- Quarantine review remains a query/view concern unless a later charter adds a
  supported release path.
- LiveView tests should target stable selectors and render receipts from the
  authoritative reports, not ad hoc text snapshots.
</code_context>

<specifics>
## Specific Ideas

- Use one Actions page with distinct panels rather than split routes.
- Keep operation labels concrete and operator-facing: preview, erase, reprobe,
  requeue, regenerate, review.
- Typed confirmation belongs to erasure; repair/regeneration use less severe but
  still deliberate confirmation when scope is broad.
- Batch erasure should show a partial receipt on failure instead of collapsing
  to an all-or-nothing error.
- Quarantine review should say plainly that Rindle Admin does not release
  assets from quarantine.
- Selectors should be stable and namespaced for LiveView and later Playwright
  use, e.g. `data-rindle-admin-action`, `data-rindle-admin-receipt`, and
  `data-rindle-admin-confirm-input`.

External research applied during assumptions analysis:

- Phoenix LiveDashboard router precedent:
  https://hexdocs.pm/phoenix_live_dashboard/Phoenix.LiveDashboard.Router.html
- Oban Web router and operational-console precedent:
  https://hexdocs.pm/oban_web/Oban.Web.Router.html
  https://hexdocs.pm/oban_web/overview.html
- Phoenix LiveView testing and event handling:
  https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html
  https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html
- Django admin bulk-action cautionary precedent:
  https://docs.djangoproject.com/en/6.0/ref/contrib/admin/actions/
- Rails Active Storage async purge and representation guidance:
  https://guides.rubyonrails.org/active_storage_overview.html
- Shrine derivative and upload-security guidance:
  https://shrinerb.com/docs/plugins/derivatives
  https://shrinerb.com/docs/changing-derivatives
  https://shrinerb.com/docs/securing-uploads
- Spatie Media Library regeneration precedent:
  https://spatie.be/docs/laravel-medialibrary/v11/converting-images/regenerating-images
- GOV.UK and Carbon destructive/confirmation guidance:
  https://design-system.service.gov.uk/components/warning-text/
  https://design-system.service.gov.uk/patterns/check-answers/
  https://carbondesignsystem.com/community/patterns/remove-pattern/
  https://carbondesignsystem.com/components/modal/usage/
- OWASP file upload guidance:
  https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html

No additional maintainer-specific ideas were introduced during confirmation.
</specifics>

<deferred>
## Deferred Ideas

- Force-delete and still-shared asset policy remain demand-gated for a later
  milestone.
- Any supported quarantine release/un-quarantine capability would require a new
  charter and FSM/security decision.
- Cohort rebrand, full demo seeds, deterministic E2E, screenshot polish, and
  docs/facade parity remain later phases.

### Reviewed Todos (not folded)

No matching pending todos were found for Phase 90.
</deferred>
