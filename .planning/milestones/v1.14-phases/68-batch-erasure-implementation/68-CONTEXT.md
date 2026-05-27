# Phase 68: Batch erasure implementation - Context

**Gathered:** 2026-05-27 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Wire functional batch preview and execute on the frozen Phase 67 public contract.
Phase 68 delivers planner implementation, aggregation, per-owner isolation on
execute, partial-failure reporting, and idempotent rerun behavior for
**BULK-03**, **BULK-04**, and **BULK-05**.

Out of scope: operator `mix rindle.*` task (Phase 69), hermetic proof matrix and
guide parity (Phase 70), force-delete, admin UI, scheduler jobs, and any change
to single-owner `owner_erasure_report/0` bucket semantics.

</domain>

<decisions>
## Implementation Decisions

### Per-owner isolation & orchestration
- **D-01:** Batch preview and execute loop **sequentially** over deduped owners,
  calling `OwnerErasure.preview/2` or `OwnerErasure.execute/2` once per owner.
  No outer `Ecto.Multi` wraps the batch — isolation is one transaction per
  `execute/2` call (BULK-03).
- **D-02:** Orchestration lives on the **`Rindle` facade** as private helpers
  after `validate_batch_owners/2`, mirroring `preview_owner_erasure/2` /
  `erase_owner/2` delegation. No new public module.

### Input dedupe & ordering
- **D-03:** After validation passes, dedupe with `Enum.uniq_by(&owner_ref/1)`
  using the same `{owner_type, owner_id}` tuple as the boundary limit check;
  **first occurrence wins**.
- **D-04:** The `owners` list in the batch report follows **deduped input
  order** (not sorted by `owner_ref`).

### Aggregate bucket assembly
- **D-05:** Top-level `attachments_to_detach`, `assets_to_purge`, and
  `retained_shared_assets` aggregate by **summing per-owner `count` fields and
  concatenating per-owner `entries` lists** (no cross-owner entry dedupe by
  `asset_id`).
- **D-06:** Batch `mode` is `:preview` or `:execute` matching the calling
  function; per-owner nested reports retain their own `mode` from
  `OwnerErasure` unchanged.

### Partial failure & idempotency
- **D-07:** On execute (and preview unless catastrophic), the loop **continues
  after a per-owner `{:error, reason}`** — completed owners stay committed
  (BULK-03).
- **D-08:** On any owner failure after at least one owner was processed (or
  when the failing owner prevents a complete batch), return
  `{:error, {:batch_owner_failed, %{owner: owner_ref(), reason: term(), partial_report: owner_erasure_batch_report()}}}`.
  The `partial_report.owners` list contains **only successful** entries;
  frozen `owner_erasure_batch_entry/0` stays `%{owner:, report:}` with no error
  field. Fits `{:error, term()}` in the frozen `@spec`.
- **D-09:** **BULK-05 idempotency** is inherited by re-running the batch loop:
  already-cleared owners get the same zeroed per-owner execute report as
  `erase_owner/2` (no batch-specific persistence ledger).

### Boundary & opts
- **D-10:** Replace `{:error, :not_implemented}` stubs with real
  `{:ok, batch_report}`; update `owner_erasure_batch_boundary_test.exs`
  accordingly.
- **D-11:** Do **not** forward batch `opts` (beyond `:max_owners` used in
  validation) to `OwnerErasure` until that module accepts them (`_opts` today).

### Claude's Discretion
- Exact `{:batch_owner_failed, detail}` key names and `@typedoc` for the error
  detail map (add `batch_owner_failed_detail/0` type vs inline map)
- Whether preview failures use the same `{:batch_owner_failed, _}` tag or only
  execute (preview DB errors are unexpected but should not roll back prior
  preview work)
- Private helper naming (`run_batch_owner_erasure/3`, `aggregate_batch_report/2`, etc.)
- Hermetic test file naming and fixture reuse from `owner_erasure_test.exs`

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and requirements
- `.planning/ROADMAP.md` — Phase 68 goal, success criteria, phase boundaries 68–70
- `.planning/REQUIREMENTS.md` — BULK-03, BULK-04, BULK-05
- `.planning/PROJECT.md` — v1.14 locked decisions, contract-before-implementation precedent
- `.planning/phases/67-bulk-erasure-policy-contract/67-CONTEXT.md` — frozen batch types, boundary rules, D-01–D-12

### Shipped contract and implementation targets
- `lib/rindle.ex` — batch types, `preview_batch_owner_erasure/2`,
  `erase_batch_owner_erasure/2`, `validate_batch_owners/2`, `owner_ref/1`
- `lib/rindle/internal/owner_erasure.ex` — `preview/2`, `execute/2`, per-owner
  transaction and report builder
- `test/rindle/owner_erasure_batch_contract_test.exs` — frozen export/docs contract
- `test/rindle/owner_erasure_batch_boundary_test.exs` — empty/over-limit/dedupe boundary
- `test/rindle/owner_erasure_test.exs` — single-owner semantics, idempotent rerun, shared assets

### Partial-failure precedent (ops pattern, not public API)
- `lib/rindle/ops/metadata_backfill.ex` — continue-on-failure reduce loop

### Error vocabulary
- `lib/rindle/error.ex` — add `Rindle.Error.message/1` branch for
  `{:batch_owner_failed, _}` with operator-oriented guidance

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Rindle.Internal.OwnerErasure.preview/2` and `execute/2` — sole planner/executor for each owner
- `validate_batch_owners/2`, `owner_ref/1`, `resolve_max_batch_owners/1` on `Rindle` — boundary already shipped
- `owner_erasure_report/0`, `owner_erasure_bucket/0`, `owner_erasure_batch_report/0` — aggregation targets
- `Rindle.OwnerErasureTest` fixtures (`User` struct, attachment/asset helpers) — reuse for batch tests

### Established Patterns
- Contract-before-implementation: Phase 67 froze types; Phase 68 replaces stubs only
- Per-owner `Ecto.Multi` + `repo.transaction()` in `OwnerErasure.execute/2` — do not nest in batch Multi
- Ops reduce loops that count failures without rolling back prior items (`MetadataBackfill`)

### Integration Points
- `preview_batch_owner_erasure/2` and `erase_batch_owner_erasure/2` bodies in `lib/rindle.ex`
- `Rindle.Error.message/1` for `{:batch_owner_failed, _}`
- New implementation tests (e.g. `test/rindle/owner_erasure_batch_test.exs`) — boundary/contract tests already exist
- Phase 70 adds PROOF-05 matrix; Phase 68 should ship unit/integration tests sufficient for planner verification

</code_context>

<specifics>
## Specific Ideas

- Partial failure uses `{:batch_owner_failed, %{owner:, reason:, partial_report:}}` so adopters get actionable `owner_ref` plus completed owners in one error tuple
- Aggregate buckets are full-fidelity (count + entries) for operator audit, not count-only summaries
- Idempotent batch rerun is proven by composition: if each owner is idempotent, the batch loop is idempotent

</specifics>

<deferred>
## Deferred Ideas

- `mix rindle.*` operator task with dry-run default — Phase 69 (OPS-02)
- Hermetic proof matrix and guide/docs parity — Phase 70 (PROOF-05, TRUTH-03)
- Batch-level `failures` count on `owner_erasure_batch_report/0` (would amend Phase 67 types)
- Forwarding batch opts to `OwnerErasure` planner hooks
- Force-delete policy, admin LiveView erasure UI, scheduler/cron jobs

</deferred>

---

*Phase: 68-batch-erasure-implementation*
*Context gathered: 2026-05-27*
