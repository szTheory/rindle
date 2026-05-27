# Phase 67: Pattern Map

**Phase:** 67 - Bulk erasure policy & contract
**Generated:** 2026-05-27

## Files to Create/Modify

| File | Role | Closest Analog | Key Pattern |
|------|------|----------------|-------------|
| `lib/rindle.ex` | Public facade — types, @specs, stub entrypoints | `lib/rindle/streaming.ex` (cancel types) | `@type` + `@spec` before body; moduledoc section |
| `lib/rindle/error.ex` | Operator error messages | `not_cancellable` branches | Tagged tuple + detail map + fix-oriented prose |
| `test/rindle/owner_erasure_batch_contract_test.exs` | Contract freeze | `cancel_direct_upload_contract_test.exs` | `Code.fetch_docs/1`, `function_exported?/3` |
| `test/rindle/api_surface_boundary_test.exs` | Facade export/moduledoc freeze | existing owner-erasure assertions | Snippet list in moduledoc test |
| `test/rindle/owner_erasure_batch_boundary_test.exs` | Boundary validation behavior | `cancel_direct_upload_test.exs` (error paths) | Assert empty/over-limit without DB |

## Analog Excerpts

### Type + spec on facade (`lib/rindle/streaming.ex`)

```elixir
@type not_cancellable_detail ::
        %{reason: :state, state: String.t()}
        | %{reason: :ingest_mode, ingest_mode: String.t()}
        | %{reason: :missing_upload_id}

@type cancel_direct_upload_result ::
        :ok
        | {:error, :not_found}
        | {:error, {:not_cancellable, not_cancellable_detail()}}
```

### Contract test (`test/rindle/streaming/cancel_direct_upload_contract_test.exs`)

```elixir
{:docs_v1, _, _, _, _, _, entries} = Code.fetch_docs(Rindle.Streaming)

assert Enum.any?(entries, fn
         {{:type, :cancel_direct_upload_result, 0}, _, _, _, _} -> true
         _ -> false
       end)

assert function_exported?(Rindle.Streaming, :cancel_direct_upload, 1)
```

### Moduledoc freeze (`test/rindle/api_surface_boundary_test.exs`)

```elixir
for snippet <- [
      "preview_owner_erasure/2",
      "attachments_to_detach",
      "bulk orchestration",
      "force-delete"
    ] do
  assert moduledoc =~ snippet
end
```

### Owner ref extraction (`lib/rindle/internal/owner_erasure.ex`)

```elixir
defp owner_info(%{__struct__: module, id: id}), do: {to_string(module), id}
```

## PATTERN MAPPING COMPLETE
