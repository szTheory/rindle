# Phase 69: Operator mix task - Research

**Researched:** 2026-05-27
**Domain:** Operator Mix CLI for batch owner-erasure preview/execute (OPS-02)
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01..D-02:** Ship `Mix.Tasks.Rindle.BatchOwnerErasure` as `mix rindle.batch_owner_erasure`; thin wrapper over `Rindle.preview_batch_owner_erasure/2` and `Rindle.erase_batch_owner_erasure/2` — no new `Rindle.Ops.*` module.
- **D-03..D-05:** Required `--owners-file PATH` with JSON array of `{"owner_type", "owner_id"}`; resolve modules via `String.to_existing_atom/1`; fail fast on invalid JSON, unknown modules, bad UUIDs, or empty lists.
- **D-06..D-07:** Default preview (dry-run); execute requires `--no-dry-run` or `--execute` alias; explicit `--dry-run` matches default.
- **D-08..D-11:** Text summary with `[DRY RUN]` banner and aggregate buckets; `--format json` emits full batch report; exit 0 on `{:ok, _}`, exit 1 on any `{:error, _}` including partial failure (print partial report first); forward `--max-owners N`.
- **D-12..D-14:** `@moduledoc` is canonical CLI reference with guide cross-links; register in `api_surface_boundary_test.exs`; defer guide body to Phase 70.

### Claude's Discretion
- Text summary field ordering; per-owner lines vs aggregate-only; headline flag in examples (`--execute` vs `--no-dry-run`); test file naming; error message wording.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| OPS-02 | Operator can run batch owner-erasure preview or execute from a `mix rindle.*` task with documented CLI contract | `Mix.Tasks.Rindle.BatchOwnerErasure` delegating to Phase 68 batch API; `@moduledoc` + boundary test registration |
</phase_requirements>

## Summary

Phase 69 is a **thin operator CLI** over the shipped batch facade from Phase 68. All orchestration lives in `Rindle`; the Mix task owns argument parsing, owners-file ingestion, output formatting, exit codes, and `@moduledoc`.

**Primary recommendation:** Two-plan wave — (1) Mix task module with owners-file parser and output helpers, (2) task integration tests + `api_surface_boundary_test.exs` registration.

## Standard Patterns

### Dry-run default (mirror `cleanup_orphans`)

```elixir
dry_run? =
  case Keyword.fetch(opts, :dry_run) do
    {:ok, value} -> value
    :error -> not (Keyword.get(opts, :execute, false) || Keyword.get(opts, :no_dry_run, false))
  end
```

When `dry_run?` is true → `Rindle.preview_batch_owner_erasure/2`; else → `Rindle.erase_batch_owner_erasure/2`.

### Text/json output split (mirror `runtime_status`)

```elixir
case format do
  "json" -> Mix.shell().info(Jason.encode!(report, pretty: true))
  _ -> print_text_report(report, dry_run?)
end
```

### Owners-file → struct list

```elixir
defp parse_owners_file(path) do
  with {:ok, contents} <- File.read(path),
       {:ok, decoded} <- Jason.decode(contents),
       true <- is_list(decoded),
       false <- decoded == [] do
    Enum.map(decoded, &entry_to_owner/1)
  else
    {:error, reason} -> {:error, {:invalid_owners_file, reason}}
    false when is_list(_) -> {:error, :empty_owners_file}
    _ -> {:error, :invalid_owners_file_shape}
  end
end

defp entry_to_owner(%{"owner_type" => type, "owner_id" => id}) when is_binary(type, id) do
  with {:ok, uuid} <- Ecto.UUID.cast(id),
       mod when is_atom(mod) <- resolve_owner_module(type) do
    {:ok, struct(mod, id: uuid)}
  end
end
```

Use `String.to_existing_atom/1` in `resolve_owner_module/1` with rescue → operator error + exit 1.

### Error handling with partial report

```elixir
case Rindle.preview_batch_owner_erasure(owners, batch_opts) do
  {:ok, report} -> print_and_exit_ok(report, dry_run?, format)
  {:error, {:batch_owner_failed, detail}} ->
    print_report(detail.partial_report, dry_run?, format)
    Mix.shell().error(Rindle.Error.message(%{reason: {:batch_owner_failed, detail}}))
    exit({:shutdown, 1})
  {:error, reason} ->
    Mix.shell().error(Rindle.Error.message(%{reason: reason}))
    exit({:shutdown, 1})
end
```

### Mix task test harness (mirror `runtime_status_task_test.exs`)

- `use Rindle.DataCase, async: false`
- `Mix.shell(Mix.Shell.Process)` in setup
- Write temp JSON owners file with `%User{id: uuid}` module string from batch tests
- Assert `{:mix_shell, :info, ...}` for text mode; JSON decode for `--format json`
- `catch_exit` for exit 1 cases

## Validation Architecture

| Behavior | Requirement | Test Type | Command |
|----------|-------------|-----------|---------|
| Default preview (no destructive flag) | OPS-02 | integration | `mix test test/rindle/batch_owner_erasure_task_test.exs` |
| Execute requires `--no-dry-run` or `--execute` | OPS-02 | integration | same |
| Invalid owners file fails before facade | OPS-02 | unit | same |
| JSON output emits batch report | OPS-02 | integration | same |
| Partial failure prints report then exits 1 | OPS-02 | integration | same (if feasible) or facade error path |
| Public boundary registration | OPS-02 | unit | `mix test test/rindle/api_surface_boundary_test.exs` |
| `@moduledoc` contains exit codes and guide links | OPS-02 | unit | grep in test or docs boundary |

## RESEARCH COMPLETE
