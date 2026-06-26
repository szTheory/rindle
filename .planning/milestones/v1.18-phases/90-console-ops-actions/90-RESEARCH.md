# Phase 90: Console Ops Actions - Research

**Researched:** 2026-06-12
**Domain:** Console Ops Actions / LiveView Operational Interfaces
**Confidence:** HIGH

## Summary

This phase transforms the currently read-only `ActionsLive` console surface into an executable operational hub for Rindle. The objective is to expose existing operations—owner erasure, batch erasure, variant regeneration, lifecycle repair, and quarantine triage—without adding new lifecycle semantics or broad new public APIs. 

The console will use page-scoped panels, requiring deliberate "destructive-action UX" (preview steps and typed confirmation) for operations like erasure. All mutations delegate to existing backend facades (`Rindle` and `Rindle.Ops`). LiveView state handles the multi-step orchestration (preview -> confirm -> execute -> receipt).

**Primary recommendation:** Build self-contained action forms in `ActionsLive` using a state machine pattern per form (e.g., `%{state: :input | :preview | :receipt}`). Rely entirely on `Rindle.preview_owner_erasure/2` and `Rindle.erase_owner/2` for erasure, displaying accurate receipts based on returned reports, including queued async jobs.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

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

### Deferred Ideas (OUT OF SCOPE)

- Force-delete and still-shared asset policy remain demand-gated for a later
  milestone.
- Any supported quarantine release/un-quarantine capability would require a new
  charter and FSM/security decision.
- Cohort rebrand, full demo seeds, deterministic E2E, screenshot polish, and
  docs/facade parity remain later phases.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ADMIN-04 | Ops actions — owner erasure preview/execute and batch erasure with deliberate destructive-action UX (typed confirmation, collateral preview), variant regeneration, quarantine review, lifecycle repair. | Verified `Rindle` facade (`preview_owner_erasure`, `erase_owner`, `preview_batch_owner_erasure`, `erase_batch_owner_erasure`, `reprobe`, `requeue_variants`) already support these directly. Validated UI constraints for rendering receipts and blocking destructive UX. |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Form State & Interaction | Frontend Server (SSR) | — | `ActionsLive` tracks `input -> preview -> execute` workflows. |
| Typing Validation | Frontend Server (SSR) | — | LiveView validates `ERASE <id>` phrase match before allowing submit. |
| Command Normalization | API / Backend | — | Optional internal `Rindle.Admin.Actions` prepares shapes for `Rindle` facade. |
| Ops Execution & Async jobs | API / Backend | Database | `Rindle` and `Rindle.Ops` execute mutations and insert Oban jobs. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix LiveView | ^0.20 / ^1.0 | Console Rendering | Locked project standard, handles async receipts dynamically. |
| Rindle Admin CSS | local | Styling (`.rindle-admin-*`) | Enforced by Phase 88 and D-90-25. No runtime Tailwind. |

## Package Legitimacy Audit

No external packages are installed in this phase.

## Architecture Patterns

### System Architecture Diagram

Data flow for destructive operations:
```
[User Action Form] 
       ↓ (Submit preview target)
[ActionsLive] -> [Rindle.Admin.Queries / Rindle facade] (Fetch preview report)
       ↓ (Render preview & Typed input)
[User Confirmation] 
       ↓ (Submit matching phrase: ERASE X)
[ActionsLive] -> [Rindle (e.g. erase_owner/2)] (Execute)
       ↓ (Returns Report & Async enqueue)
[ActionsLive] (Render Inline Receipt)
```

### Pattern 1: Multi-Step LiveView Form
**What:** Encapsulate complex operations in a stateful sub-component or form assign mapping `%{step: :input | :preview | :receipt, report: nil, target: ""}`.
**When to use:** Erasure and Batch Erasure.
**Example:**
```elixir
def handle_event("preview_owner", %{"owner_type" => type, "owner_id" => id}, socket) do
  owner = Rindle.owner_ref(%{type: type, id: id})
  case Rindle.preview_owner_erasure(owner) do
    {:ok, report} -> 
      {:noreply, assign(socket, erasure_state: :preview, preview_report: report, target_owner: owner)}
    {:error, reason} -> 
      {:noreply, assign(socket, error: reason)}
  end
end
```

### Anti-Patterns to Avoid
- **Adding new public functions to `Rindle`:** Do not wrap `Rindle.Ops.VariantMaintenance.regenerate_variants/1` in the public facade. Use the `Rindle.Ops` module directly from `ActionsLive` or an internal `Rindle.Admin.Actions` command handler.
- **Generic Error on Batch Partial Failure:** Do not discard `detail.partial_report` when a batch fails midway. The UI must render the committed portion.
- **Modal Workflows:** Do not put erasure inside a modal dialog. Use in-page `.rindle-admin-confirm-dialog` stacked under actions.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Erasure execution | Custom Ecto deletions | `Rindle.erase_owner/2` | Guarantees proper async purge enqueueing and shared-asset retention logic. |
| Batch execution loop | `Enum.each` calling `erase_owner` | `Rindle.erase_batch_owner_erasure/2` | Handles partial failure, max batch size limits, and `owner_erasure_batch_report` aggregation. |
| Regeneration | Custom loops querying variants | `Rindle.Ops.VariantMaintenance.regenerate_variants/1` | Centralizes filtering by `profile` and `variant_name` logic matching CLI. |

## Common Pitfalls

### Pitfall 1: Bypassing Partial Receipts
**What goes wrong:** Batch erasure fails on the 4th owner, and the UI displays a red error box, hiding the fact that 3 owners were successfully erased.
**Why it happens:** Blindly matching `{:error, reason}` instead of `{:error, {:batch_owner_failed, detail}}`.
**How to avoid:** Explicitly match `{:batch_owner_failed, %{partial_report: report, owner: owner, reason: reason}}`, assign the partial report to the socket as a receipt, and display a warning about the specific failing owner.

### Pitfall 2: Asynchronous Confusion
**What goes wrong:** The receipt implies attachments have been deleted from cloud storage immediately.
**Why it happens:** Failing to distinguish between DB detachment and async storage purge.
**How to avoid:** Render the returned report fields accurately: `purge_enqueued`, `attachments_to_detach`, `assets_to_purge`, matching D-90-08 vocabulary.

### Pitfall 3: Broken Confirmation Invalidation
**What goes wrong:** User previews `user:1`, then changes input to `user:2` but uses the confirmation phrase for `user:2` to execute without previewing `user:2` first.
**Why it happens:** The target input field is not linked to the preview state.
**How to avoid:** Lock the target input after a preview, or reset the `erasure_state` to `:input` whenever the target field changes (via `phx-change`).

## Code Examples

Verified patterns from existing Rindle operations:

### Batch Erasure Partial Failure Match
```elixir
case Rindle.erase_batch_owner_erasure(owners) do
  {:ok, report} ->
    # Success receipt
    {:noreply, assign(socket, receipt: report, mode: :receipt)}

  {:error, {:batch_owner_failed, %{owner: failed_owner, reason: reason, partial_report: partial}}} ->
    # Render partial receipt + error for specific owner
    {:noreply, assign(socket, receipt: partial, error: "Failed at #{failed_owner}: #{inspect(reason)}", mode: :receipt)}
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Ad hoc manual db scripts | Exposing library internals via safe LiveView | v1.18 | End users can trigger complex workflows without raw database access. |

## Assumptions Log

None — All behaviors mapped directly to documented `Rindle` facade and explicitly locked Phase 90 Context decisions.

## Open Questions

None. All constraints are tightly specified by D-90-01 through D-90-25.

## Environment Availability

No external environment dependencies apply here. Elixir/Phoenix is already configured in the workspace.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit + Phoenix.LiveViewTest |
| Config file | `test_helper.exs` |
| Quick run command | `mix test test/rindle/admin/live/` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ADMIN-04 | Renders owner erasure preview and enforces typed confirm | unit | `mix test test/rindle/admin/live/actions_live_test.exs` | ❌ Wave 0 |
| ADMIN-04 | Blocks execution if target changes after preview | unit | `mix test test/rindle/admin/live/actions_live_test.exs` | ❌ Wave 0 |
| ADMIN-04 | Renders partial batch erasure receipts safely | unit | `mix test test/rindle/admin/live/actions_live_test.exs` | ❌ Wave 0 |
| ADMIN-04 | Delegates to variant regeneration appropriately | unit | `mix test test/rindle/admin/live/actions_live_test.exs` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `mix test test/rindle/admin/live/`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/rindle/admin/live/actions_live_test.exs` — covers ADMIN-04 workflows and assertions against `data-rindle-admin-*` stable selectors.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Delegated via router macro / `on_mount` (ADMIN-01) |
| V3 Session Management | no | Delegated |
| V4 Access Control | no | Delegated |
| V5 Input Validation | yes | LiveView `phx-change`, struct validation, `Rindle.owner_ref/1` strict formatting. |
| V6 Cryptography | no | — |

### Known Threat Patterns for Elixir / LiveView

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Action bypass (force submit) | Tampering | LiveView event handlers must re-verify the typed confirmation (e.g. `ERASE ...`) server-side, not just rely on client-side JS disabled state. |
| Cross-owner scope escalation | Spoofing | Discard the client confirmation state if the form scope inputs change. Server must ensure the exact previewed scope is what gets submitted. |

## Sources

### Primary (HIGH confidence)
- `.planning/phases/90-console-ops-actions/90-CONTEXT.md` - Verified locked decisions and architectural boundary.
- `lib/rindle.ex` - Verified erasure execution facade endpoints and batch response shapes (`batch_owner_erasure_result`).
- `lib/rindle/ops/variant_maintenance.ex` - Verified `regenerate_variants/1` entry point for broad jobs.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Phoenix LiveView is explicitly designated as the tool for the Rindle Admin console.
- Architecture: HIGH - Dictated exactly by D-90-01 to D-90-25.
- Pitfalls: HIGH - Batch failures and partial reports are explicitly codified in `rindle.ex` typespecs.

**Research date:** 2026-06-12
**Valid until:** 2026-07-12
