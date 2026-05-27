# Phase 67: Bulk erasure policy & contract - Context

**Gathered:** 2026-05-27 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Freeze the batch owner-erasure public contract before any planner wiring lands.
Phase 67 delivers types, `@spec`s, moduledoc, error vocabulary, non-goals, and
contract/boundary tests — not batch preview/execute implementation (Phase 68),
not the operator mix task (Phase 69), and not guide/docs parity (Phase 70).

Requirements in scope: **BULK-01**, **BULK-02**.

</domain>

<decisions>
## Implementation Decisions

### Batch report shape
- **D-01:** Introduce public `owner_erasure_batch_report/0` on `Rindle` with
  `mode: :preview | :execute`, top-level aggregate `owner_erasure_bucket/0`
  totals for `attachments_to_detach`, `assets_to_purge`, and
  `retained_shared_assets`, plus an `owners` list of batch entries.
- **D-02:** Each batch entry is `owner_erasure_batch_entry/0`: `%{owner: owner_ref(), report: owner_erasure_report()}` where `owner_ref/0` is
  `{owner_type :: String.t(), owner_id :: Ecto.UUID.t()}` (same identity shape
  `OwnerErasure` derives from structs today).
- **D-03:** Per-owner `report` fields reuse the frozen v1.10
  `owner_erasure_report/0` vocabulary unchanged — no new bucket names, no
  per-owner semantic drift.

### Public API naming and contract-first delivery
- **D-04:** Batch facade entrypoints on `Rindle`:
  `preview_batch_owner_erasure(owners, opts \\ [])` and
  `erase_batch_owner_erasure(owners, opts \\ [])`, mirroring single-owner
  `preview_owner_erasure/2` / `erase_owner/2` naming.
- **D-05:** Phase 67 freezes both functions' `@spec`s, `@typedoc`, and
  moduledoc; implementation may stub or delegate minimally, but types and
  contract tests land in this phase (same contract-before-implementation
  pattern as v1.13 `cancel_direct_upload/1`).
- **D-06:** `owners` argument is a non-empty `[struct()]` list (same owner
  struct contract as single-owner erasure). Empty list is `{:error, :empty_batch}`.

### Batch size limit and error vocabulary
- **D-07:** Enforce batch size at the public boundary **before** any
  `OwnerErasure` planner work. Count **unique** owners after deduping duplicate
  structs in the input list.
- **D-08:** Default limit: `max_owners: 100`, overridable per call via opts.
  Optional app env default:
  `Application.get_env(:rindle, :max_batch_erasure_owners, 100)` — opts wins
  when both are present.
- **D-09:** Over-limit returns
  `{:error, {:batch_too_large, %{requested: non_neg_integer(), max: pos_integer()}}}`.
  Add `Rindle.Error.message/1` branch with operator-oriented guidance (match
  `{:not_cancellable, _}` detail-map style from `Rindle.Streaming`).

### Support-truth and non-goals
- **D-10:** Update `Rindle` moduledoc: batch preview/execute is the supported
  multi-owner orchestration surface (replacing "does not promise bulk
  orchestration"). Keep explicit non-goals: force-delete for shared assets,
  admin LiveView UI, scheduler/cron-driven erasure jobs.
- **D-11:** Phase 67 updates `api_surface_boundary_test.exs` and adds a
  dedicated contract test module (pattern:
  `test/rindle/owner_erasure_batch_contract_test.exs`) — do **not** rewrite
  `guides/user_flows.md` or `guides/operations.md` yet (Phase 70 / TRUTH-03).
- **D-12:** Single-owner `preview_owner_erasure/2` / `erase_owner/2` semantics
  remain frozen; batch wraps `Rindle.Internal.OwnerErasure` in Phase 68 without
  changing the v1.10 report vocabulary.

### Claude's Discretion
- Exact `@typedoc` prose and moduledoc section ordering on `Rindle`
- Whether `max_batch_erasure_owners` app-env key ships in Phase 67 or only
  per-call opts (default env is recommended but not locked)
- Contract-test file naming if `owner_erasure_batch_contract_test.exs` collides
  with an existing convention

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and requirements
- `.planning/ROADMAP.md` — Phase 67 goal, success criteria, phase boundaries 67–70
- `.planning/REQUIREMENTS.md` — BULK-01, BULK-02, Out of Scope table
- `.planning/PROJECT.md` — v1.14 locked decisions, contract-before-implementation precedent

### Shipped v1.10 single-owner contract (do not change semantics)
- `lib/rindle.ex` — `owner_erasure_report/0`, `owner_erasure_bucket/0`,
  `preview_owner_erasure/2`, `erase_owner/2`, facade moduledoc
- `lib/rindle/internal/owner_erasure.ex` — planner buckets and report builder
- `test/rindle/owner_erasure_test.exs` — report shape and shared-asset semantics
- `guides/user_flows.md` — canonical owner-erasure support truth (Phase 70 updates batch lane)

### Boundary and contract-test patterns
- `test/rindle/api_surface_boundary_test.exs` — facade export and moduledoc freeze tests
- `test/rindle/streaming/cancel_direct_upload_contract_test.exs` — v1.13 contract-first pattern
- `test/install_smoke/docs_parity_test.exs` — support-truth snippets (Phase 70 batch guide work)

### Error vocabulary precedent
- `lib/rindle/streaming.ex` — `{:not_cancellable, not_cancellable_detail()}` tagged errors
- `lib/rindle/error.ex` — `Rindle.Error.message/1` branches for structured reasons

### Operator patterns (Phase 69 — reference only, not Phase 67 scope)
- `lib/mix/tasks/rindle.cleanup_orphans.ex` — dry-run default, exit codes, explicit destructive opt-in

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `owner_erasure_report/0` and `owner_erasure_bucket/0` types on `Rindle` — extend, do not fork
- `Rindle.Internal.OwnerErasure.preview/2` and `execute/2` — Phase 68 implementation target; hidden from public boundary
- `owner_info/1` in `OwnerErasure` — `{owner_type, owner_id}` extraction from structs

### Established Patterns
- Contract-before-implementation: types + contract test in contract phase, body in implementation phase (v1.13 cancel)
- Tagged tuple errors with detail maps + `Rindle.Error.message/1` branches
- `api_surface_boundary_test.exs` freezes facade moduledoc snippets including deferred capabilities

### Integration Points
- New types and functions live on `Rindle` facade module (not a new public module)
- `api_surface_boundary_test.exs` must gain batch entrypoint export/doc assertions
- Phase 68 wires batch functions to sequential per-owner `OwnerErasure` calls with isolation

</code_context>

<specifics>
## Specific Ideas

- Default batch limit of **100** owners balances GDPR-scale batches with planner query cost
- Per-owner entries must carry `owner_ref` so partial-failure reports in Phase 68 are actionable without re-deriving identity from input order
- Moduledoc pivot: from "does not promise bulk orchestration" to "batch is the supported multi-owner surface" while keeping force-delete and admin UI as explicit non-goals

</specifics>

<deferred>
## Deferred Ideas

- Batch execute implementation and per-owner transaction isolation — Phase 68 (BULK-03–05)
- `mix rindle.*` operator task with dry-run default — Phase 69 (OPS-02)
- Guide/docs parity for batch erasure lane — Phase 70 (TRUTH-03, PROOF-05)
- Force-delete policy for shared assets — v1.15+ separate milestone
- Admin LiveView erasure UI — out of scope
- Scheduler/cron erasure jobs — host-app concern

</deferred>

---

*Phase: 67-bulk-erasure-policy-contract*
*Context gathered: 2026-05-27*
