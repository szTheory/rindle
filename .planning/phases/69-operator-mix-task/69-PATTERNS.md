# Phase 69: Pattern Map

**Phase:** 69 - Operator mix task
**Generated:** 2026-05-27

## Files to Create/Modify

| File | Role | Closest Analog | Key Pattern |
|------|------|----------------|-------------|
| `lib/mix/tasks/rindle.batch_owner_erasure.ex` | Operator CLI for batch erasure | `Mix.Tasks.Rindle.CleanupOrphans` | dry-run default, exit codes, `@moduledoc` depth |
| `test/rindle/batch_owner_erasure_task_test.exs` | Task integration tests | `runtime_status_task_test.exs` | `Mix.Shell.Process`, temp JSON file |
| `test/rindle/api_surface_boundary_test.exs` | Public module registration | existing mix tasks in `@public_modules` | compiled-docs boundary |

## Analog Excerpts

### Dry-run default (`lib/mix/tasks/rindle.cleanup_orphans.ex`)

```elixir
dry_run? =
  case Keyword.fetch(opts, :dry_run) do
    {:ok, value} -> value
    :error -> not Keyword.get(opts, :live, false)
  end
```

### Text/json format split (`lib/mix/tasks/rindle.runtime_status.ex`)

```elixir
case report.filters.format do
  :json -> Mix.shell().info(Jason.encode!(report, pretty: true))
  :text -> print_text_report(report)
end
```

### Atom-safe module resolution (`lib/mix/tasks/rindle.backfill_metadata.ex`)

```elixir
mod =
  try do
    String.to_existing_atom(module_str)
  rescue
    ArgumentError ->
      Mix.shell().error("Module #{module_str} is not a known atom...")
      exit({:shutdown, 1})
  end
```

### Batch facade delegation (`lib/rindle.ex`)

```elixir
def preview_batch_owner_erasure(owners, opts \\ []) do
  with :ok <- validate_batch_owners(owners, opts) do
    run_batch_owner_erasure(owners, :preview, &OwnerErasure.preview/2)
  end
end
```

### Task test harness (`test/rindle/runtime_status_task_test.exs`)

```elixir
setup do
  previous_shell = Mix.shell()
  Mix.shell(Mix.Shell.Process)
  on_exit(fn -> Mix.shell(previous_shell) end)
  :ok
end
```

### Owner struct fixture (`test/rindle/owner_erasure_batch_test.exs`)

```elixir
defmodule User do
  defstruct [:id]
end

owner = %User{id: Ecto.UUID.generate()}
```

## PATTERN MAPPING COMPLETE
