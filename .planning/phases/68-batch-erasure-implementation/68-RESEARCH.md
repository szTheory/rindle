# Phase 68: Batch erasure implementation - Research

**Researched:** 2026-05-27
**Domain:** Batch owner-erasure orchestration on `Rindle` facade (contract → implementation)
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01..D-02:** Sequential loop calling `OwnerErasure.preview/2` or `execute/2`; no outer `Ecto.Multi`; private helpers on `Rindle` after `validate_batch_owners/2`.
- **D-03..D-04:** Dedupe with `Enum.uniq_by(&owner_ref/1)` (first wins); `owners` list preserves deduped input order.
- **D-05..D-06:** Aggregate buckets sum `count` and concatenate `entries`; batch `mode` is `:preview` or `:execute`.
- **D-07..D-09:** Continue after per-owner `{:error, reason}`; return `{:batch_owner_failed, %{owner:, reason:, partial_report:}}` with successful entries only; idempotency inherited from single-owner execute.
- **D-10..D-11:** Replace `:not_implemented` stubs; update boundary tests; do not forward batch `opts` to `OwnerErasure`.

### Claude's Discretion
- `batch_owner_failed_detail/0` type vs inline map; preview failure tagging; helper names; test module naming.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BULK-03 | Batch execute: per-owner transaction isolation; one owner failure does not roll back completed owners | `Enum.reduce_while/3` loop; no wrapping Multi; `MetadataBackfill` continue-on-failure precedent; partial error tuple |
| BULK-04 | Single public batch API reuses `OwnerErasure` with v1.10 report vocabulary per owner | Wire `preview_batch_owner_erasure/2` → `OwnerErasure.preview/2`; `erase_batch_owner_erasure/2` → `execute/2`; nest reports in `owner_erasure_batch_entry/0` |
| BULK-05 | Idempotent batch rerun for already-cleared owners | No batch ledger; rely on `erase_owner/2` zeroed report; test multi-owner batch rerun |
</phase_requirements>

## Summary

Phase 68 replaces the Phase 67 `:not_implemented` stubs with a **sequential reduce loop** on the `Rindle` facade. Boundary validation (`validate_batch_owners/2`, `owner_ref/1`, `resolve_max_batch_owners/1`) already ships; implementation adds **input dedupe**, **per-owner delegation**, **bucket aggregation**, and **partial-failure** reporting.

**Primary recommendation:** Two-plan wave — (1) orchestration + aggregation in `lib/rindle.ex`, (2) `Rindle.Error` branch + `owner_erasure_batch_test.exs` + boundary test updates.

## Standard Patterns

### Sequential batch loop (facade)

```elixir
defp dedupe_batch_owners(owners) do
  owners |> Enum.uniq_by(&owner_ref/1)
end

defp run_batch_owner_erasure(owners, mode, runner) do
  owners
  |> dedupe_batch_owners()
  |> Enum.reduce_while({:ok, []}, fn owner, {:ok, acc} ->
    case runner.(owner) do
      {:ok, report} ->
        entry = %{owner: owner_ref(owner), report: report}
        {:cont, {:ok, [entry | acc]}}

      {:error, reason} ->
        partial_entries = Enum.reverse(acc)
        partial_report = build_batch_report(mode, partial_entries)

        {:halt,
         {:error,
          {:batch_owner_failed,
           %{owner: owner_ref(owner), reason: reason, partial_report: partial_report}}}}
    end
  end)
  |> case do
    {:ok, entries} -> {:ok, build_batch_report(mode, Enum.reverse(entries))}
    error -> error
  end
end
```

### Bucket aggregation (D-05)

```elixir
defp aggregate_bucket(reports, key) do
  buckets = Enum.map(reports, &Map.fetch!(&1, key))

  %{
    count: Enum.sum(Enum.map(buckets, & &1.count)),
    entries: Enum.flat_map(buckets, & &1.entries)
  }
end
```

### Continue-on-failure precedent

`Rindle.Ops.MetadataBackfill` uses `Enum.reduce/3` with per-item `{:error, _}` counting — batch erasure differs by **halting with a tagged partial result** rather than completing a full report.

### Test reuse

`Rindle.OwnerErasureTest` provides `User` struct, `insert_asset/1`, `insert_attachment/3`, `TestProfile`, Mox storage — copy helpers into `owner_erasure_batch_test.exs` (or extract shared helper module only if duplication exceeds ~30 lines; prefer copy for minimal scope).

## Validation Architecture

| Behavior | Requirement | Test Type | Command |
|----------|-------------|-----------|---------|
| Batch preview aggregate + per-owner reports | BULK-04 | integration | `mix test test/rindle/owner_erasure_batch_test.exs` |
| Batch execute detach + purge per owner | BULK-03, BULK-04 | integration | same |
| Partial failure preserves completed owners | BULK-03 | integration | same (injected failure case) |
| Idempotent batch rerun | BULK-05 | integration | same |
| Boundary no longer returns `:not_implemented` | BULK-04 | unit | `mix test test/rindle/owner_erasure_batch_boundary_test.exs` |
| `batch_owner_failed` error message | BULK-03 | unit | `mix test test/rindle/owner_erasure_batch_error_test.exs` |
| Contract types unchanged | BULK-04 | unit | `mix test test/rindle/owner_erasure_batch_contract_test.exs` |

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Double-counting aggregate entries across owners | No cross-owner dedupe by design (D-05); document in moduledoc |
| Accidentally wrapping batch in `Ecto.Multi` | Code review + no `Multi` import in batch helpers |
| Partial failure on first owner returns empty `partial_report.owners` | Expected per D-08; test explicitly |
| Preview failure semantics unclear | Use same `{:batch_owner_failed, _}` for preview and execute (CONTEXT discretion — prefer consistency) |

## RESEARCH COMPLETE
