# Phase 68: Pattern Map

**Phase:** 68 - Batch erasure implementation
**Generated:** 2026-05-27

## Files to Create/Modify

| File | Role | Closest Analog | Key Pattern |
|------|------|----------------|-------------|
| `lib/rindle.ex` | Batch orchestration helpers + stub replacement | `preview_owner_erasure/2` delegation | `with` boundary then `run_batch_owner_erasure/3` |
| `lib/rindle/error.ex` | `batch_owner_failed` operator message | `batch_too_large` branches | Tagged tuple + `owner_ref` in prose |
| `test/rindle/owner_erasure_batch_test.exs` | Implementation proof | `owner_erasure_test.exs` | `Rindle.DataCase`, fixtures, Oban.Testing |
| `test/rindle/owner_erasure_batch_boundary_test.exs` | Boundary updates | same file Phase 67 | Replace `:not_implemented` with `{:ok, _}` |
| `test/rindle/owner_erasure_batch_error_test.exs` | Error message for partial failure | existing batch error tests | `Error.message/1` |

## Analog Excerpts

### Facade delegation (`lib/rindle.ex`)

```elixir
def preview_owner_erasure(owner, opts \\ []) do
  OwnerErasure.preview(owner, opts)
end
```

### Per-owner transaction (`lib/rindle/internal/owner_erasure.ex`)

```elixir
def execute(owner, _opts \\ []) do
  Multi.new()
  |> ...
  |> repo.transaction()
end
```

### Continue-on-failure reduce (`lib/rindle/ops/metadata_backfill.ex`)

```elixir
Enum.reduce(assets, base_report, fn asset, acc ->
  backfill_asset(asset, storage_mod, analyzer_mod, acc)
end)
```

### Idempotent single-owner rerun (`test/rindle/owner_erasure_test.exs`)

```elixir
assert {:ok, _first_report} = Rindle.erase_owner(owner)
assert {:ok, report} = Rindle.erase_owner(owner)
assert report.attachments_to_detach == %{count: 0, entries: []}
```

## PATTERN MAPPING COMPLETE
