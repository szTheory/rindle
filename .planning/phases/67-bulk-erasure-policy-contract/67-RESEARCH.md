# Phase 67: Bulk erasure policy & contract - Research

**Researched:** 2026-05-27
**Domain:** Batch owner-erasure public contract on `Rindle` facade (contract-before-implementation)
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01..D-03:** `owner_erasure_batch_report/0` with `mode`, aggregate buckets, and `owners: [owner_erasure_batch_entry/0]` where each entry nests frozen `owner_erasure_report/0`.
- **D-04..D-06:** `preview_batch_owner_erasure/2` and `erase_batch_owner_erasure/2` on `Rindle`; empty list → `{:error, :empty_batch}`; contract frozen in Phase 67, planner wiring in Phase 68.
- **D-07..D-09:** Batch size enforced at public boundary before `OwnerErasure`; unique-owner dedupe; default `max_owners: 100` with optional app env `:max_batch_erasure_owners`; over-limit → `{:error, {:batch_too_large, detail}}`.
- **D-10..D-12:** Moduledoc pivot to supported batch surface; explicit non-goals; `api_surface_boundary_test.exs` + dedicated contract test module; guides deferred to Phase 70.

### Claude's Discretion
- Exact `@typedoc` prose, app-env key shipping, contract test file naming.

### Deferred (OUT OF SCOPE)
- Batch execute implementation, mix task, guide parity, force-delete, admin UI, scheduler jobs.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BULK-01 | Preview bounded batch → aggregate report with per-owner `owner_erasure_report()` entries and batch totals | Freeze `@type owner_erasure_batch_report/0`, `@type owner_erasure_batch_entry/0`, `@type owner_ref/0`; `@spec` return shapes; contract tests via `Code.fetch_docs/1` and moduledoc freeze — full preview behavior ships Phase 68 |
| BULK-02 | Configurable max owner count with tagged over-limit error | Boundary validation in stub entrypoints; `batch_too_large_detail/0` type; `Rindle.Error.message/1` branch mirroring `not_cancellable_detail/0` pattern |
</phase_requirements>

## Summary

Phase 67 follows the established **contract-before-implementation** pattern used in v1.13 `cancel_direct_upload/1` (Phase 64–66): freeze public types, `@spec`s, moduledoc, and boundary validation on the `Rindle` facade; defer planner wiring to the next phase.

The single-owner vocabulary is already stable in `lib/rindle.ex` (`owner_erasure_report/0`, `owner_erasure_bucket/0`) and implemented in `Rindle.Internal.OwnerErasure`. Batch types nest that report unchanged — no new bucket names.

**Primary recommendation:** Two-plan wave: (1) facade types + stub entrypoints with empty/over-limit boundary checks, (2) error vocabulary + contract/boundary tests. Stub valid batches with `{:error, :not_implemented}` until Phase 68 wires `OwnerErasure`.

## Standard Patterns

### Contract-first (v1.13 cancel precedent)
| Artifact | Location | Pattern |
|----------|----------|---------|
| Public types + `@spec` | `lib/rindle/streaming.ex` | `@type cancel_direct_upload_result`, `@type not_cancellable_detail` |
| Contract test (exports/types) | `test/rindle/streaming/cancel_direct_upload_contract_test.exs` | `Code.fetch_docs/1` + `function_exported?/3` |
| Error detail maps | `lib/rindle/streaming.ex` | `{:not_cancellable, %{reason: atom(), ...}}` |
| Error messages | `lib/rindle/error.ex` | Pattern-matched `message/1` clauses with operator fix steps |
| Facade moduledoc freeze | `test/rindle/api_surface_boundary_test.exs` | Snippet assertions on normalized moduledoc |

### Owner identity extraction
`OwnerErasure.owner_info/1` (private): `defp owner_info(%{__struct__: module, id: id}), do: {to_string(module), id}` — batch dedupe must use the same `{owner_type, owner_id}` tuple.

### Batch size resolution (recommended)
```elixir
defp resolve_max_owners(opts) do
  Keyword.get(
    opts,
    :max_owners,
    Application.get_env(:rindle, :max_batch_erasure_owners, 100)
  )
end
```

## Proposed Type Shapes

```elixir
@type owner_ref :: {owner_type :: String.t(), owner_id :: Ecto.UUID.t()}

@type owner_erasure_batch_entry :: %{
  owner: owner_ref(),
  report: owner_erasure_report()
}

@type owner_erasure_batch_report :: %{
  mode: :preview | :execute,
  attachments_to_detach: owner_erasure_bucket(),
  assets_to_purge: owner_erasure_bucket(),
  retained_shared_assets: owner_erasure_bucket(),
  owners: [owner_erasure_batch_entry()]
}

@type batch_too_large_detail :: %{
  requested: non_neg_integer(),
  max: pos_integer()
}

@type batch_owner_erasure_result ::
  {:ok, owner_erasure_batch_report()}
  | {:error, :empty_batch}
  | {:error, {:batch_too_large, batch_too_large_detail()}}
  | {:error, term()}
```

## Validation Architecture

| Behavior | Requirement | Test Type | Command |
|----------|-------------|-----------|---------|
| Types exported in docs | BULK-01 | unit | `mix test test/rindle/owner_erasure_batch_contract_test.exs` |
| Empty batch rejected | BULK-02 | unit | same |
| Over-limit after dedupe | BULK-02 | unit | same |
| Moduledoc batch surface + non-goals | BULK-01 | unit | `mix test test/rindle/api_surface_boundary_test.exs` |
| Error messages for batch errors | BULK-02 | unit | `mix test test/rindle/error_streaming_freeze_test.exs` pattern → new batch error test |

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Accidentally calling `OwnerErasure` in contract phase | Stub returns `{:error, :not_implemented}` only after boundary checks pass |
| Moduledoc regression on single-owner wording | Extend existing snippet list; replace `"bulk orchestration"` negative with positive batch surface |
| Dialyzer on stub return | Union in `@spec` includes `:not_implemented` via `term()` |

## RESEARCH COMPLETE
