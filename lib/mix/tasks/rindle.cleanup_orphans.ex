defmodule Mix.Tasks.Rindle.CleanupOrphans do
  @shortdoc "Delete expired upload sessions and their staged objects"

  @moduledoc """
  Removes expired upload sessions and the staged objects they reference.

  ## Usage

      mix rindle.cleanup_orphans [--dry-run | --no-dry-run | --live] [--storage MODULE]

  ## Options

    * `--dry-run` — explicitly request preview mode (this is also the default
      when no flag is given).
    * `--no-dry-run` / `--live` — perform destructive deletions. `--live` is
      kept as an alias for clarity in scripts.
    * `--storage MODULE` — fully-qualified module name of the storage adapter
      to use for object deletion. When omitted the adapter is resolved from
      the `:rindle` application configuration under `:default_storage`.

  ## Exit codes

    * `0` — cleanup completed (or dry-run report generated) successfully.
    * `1` — one or more errors were encountered during cleanup.

  ## Examples

      # Preview what would be removed (safe default)
      mix rindle.cleanup_orphans

      # Same, made explicit (matches OPS-02 documented contract)
      mix rindle.cleanup_orphans --dry-run

      # Destructive cleanup using configured default storage
      mix rindle.cleanup_orphans --no-dry-run

      # Destructive cleanup using the `--live` alias against a specific adapter
      mix rindle.cleanup_orphans --live --storage Rindle.Storage.Local

  ## Safety default

  The CLI, the underlying service (`Rindle.Ops.UploadMaintenance.cleanup_orphans/1`),
  and the cron worker (`Rindle.Workers.CleanupOrphans`) all default to dry-run.
  Destructive execution requires an explicit opt-in (`--no-dry-run`/`--live` here,
  `dry_run: false` for the service, `"dry_run" => false` for the worker job args).
  This is the T-04-01 mitigation: dry-run and destructive execution are kept
  separate, with the safer default everywhere.

  ## Notes

  Storage side effects happen outside of database transactions. A storage
  deletion failure for a single object is logged and counted but does not
  abort the rest of the cleanup lane.

  Run `mix rindle.abort_incomplete_uploads` first to transition timed-out
  `signed`/`uploading` sessions to `expired` before calling this task.
  """

  use Mix.Task

  alias Rindle.Ops.UploadMaintenance

  @requirements ["app.start"]

  @impl Mix.Task
  def run(argv) do
    {opts, _args, _invalid} =
      OptionParser.parse(argv,
        strict: [dry_run: :boolean, live: :boolean, storage: :string]
      )

    # Default to safe (non-destructive). Explicit --dry-run / --no-dry-run wins;
    # otherwise --live is honored as a backward-compatible destructive opt-in.
    dry_run? =
      case Keyword.fetch(opts, :dry_run) do
        {:ok, value} -> value
        :error -> not Keyword.get(opts, :live, false)
      end

    storage_mod = resolve_storage_adapter(opts)

    Mix.shell().info("Running upload-session cleanup (dry_run=#{dry_run?})...")

    cleanup_opts =
      [dry_run: dry_run?]
      |> then(fn o -> if storage_mod, do: Keyword.put(o, :storage, storage_mod), else: o end)

    case UploadMaintenance.cleanup_orphans(cleanup_opts) do
      {:ok, report} ->
        print_cleanup_report(report, dry_run?)
        maybe_exit_nonzero(report.storage_errors)

      {:error, reason} ->
        Mix.shell().error("Cleanup failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp resolve_storage_adapter(opts) do
    case Keyword.get(opts, :storage) do
      nil ->
        Application.get_env(:rindle, :default_storage)

      module_str ->
        load_storage_module(module_str)
    end
  end

  # Use String.to_existing_atom/1 + behaviour validation so untrusted operator
  # input cannot exhaust the atom table (T-04-09). Mirrors the pattern in
  # Rindle.Workers.CleanupOrphans.resolve_storage_adapter/1.
  defp load_storage_module(module_str) do
    mod =
      try do
        String.to_existing_atom(module_str)
      rescue
        ArgumentError ->
          Mix.shell().error(
            "Storage adapter #{module_str} is not a known module (atom does not exist)."
          )

          exit({:shutdown, 1})
      end

    case Code.ensure_loaded(mod) do
      {:module, ^mod} ->
        unless function_exported?(mod, :delete, 2) do
          Mix.shell().error(
            "Module #{module_str} is loaded but does not implement the Rindle.Storage behaviour."
          )

          exit({:shutdown, 1})
        end

        mod

      {:error, reason} ->
        Mix.shell().error("Could not load storage adapter #{module_str}: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp print_cleanup_report(report, dry_run?) do
    mode = if dry_run?, do: "[DRY RUN] ", else: ""

    Mix.shell().info("""
    #{mode}Upload-session cleanup complete:
      Sessions found:   #{report.sessions_found}
      Sessions deleted: #{report.sessions_deleted}
      Objects deleted:  #{report.objects_deleted}
      Storage skipped:  #{report.storage_skipped}
      Storage errors:   #{report.storage_errors}
    """)

    if report.storage_skipped > 0 do
      Mix.shell().error(
        "WARNING: storage adapter not configured — #{report.storage_skipped} object(s) " <>
          "left in storage. Pass --storage MODULE or set :rindle :default_storage."
      )
    end
  end

  defp maybe_exit_nonzero(0), do: :ok

  defp maybe_exit_nonzero(error_count) do
    Mix.shell().error("#{error_count} storage error(s) occurred during cleanup.")
    exit({:shutdown, 1})
  end
end
