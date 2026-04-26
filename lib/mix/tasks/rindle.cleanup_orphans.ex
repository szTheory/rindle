defmodule Mix.Tasks.Rindle.CleanupOrphans do
  @shortdoc "Delete expired upload sessions and their staged objects"

  @moduledoc """
  Removes expired upload sessions and the staged objects they reference.

  ## Usage

      mix rindle.cleanup_orphans [--live] [--storage MODULE]

  ## Options

    * `--live` — perform destructive deletions. Without this flag the task
      runs in dry-run mode and reports what *would* be removed.
    * `--storage MODULE` — fully-qualified module name of the storage adapter
      to use for object deletion. When omitted the adapter is resolved from
      the `:rindle` application configuration under `:default_storage`.

  ## Exit codes

    * `0` — cleanup completed (or dry-run report generated) successfully.
    * `1` — one or more errors were encountered during cleanup.

  ## Examples

      # Preview what would be removed (default; safe)
      mix rindle.cleanup_orphans

      # Live cleanup using configured default storage (destructive)
      mix rindle.cleanup_orphans --live

      # Live cleanup against a specific adapter
      mix rindle.cleanup_orphans --live --storage Rindle.Storage.Local

  ## Safety default

  The CLI, the underlying service (`Rindle.Ops.UploadMaintenance.cleanup_orphans/1`),
  and the cron worker (`Rindle.Workers.CleanupOrphans`) all default to dry-run.
  Destructive execution requires an explicit opt-in (`--live` here, `dry_run: false`
  for the service, `"dry_run" => false` for the worker job args). This is the
  T-04-01 mitigation: dry-run and destructive execution are kept separate, with
  the safer default everywhere.

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
        strict: [live: :boolean, storage: :string]
      )

    # Default to the safe (non-destructive) mode — operators must explicitly
    # opt in with --live to delete anything. See @moduledoc "Safety default".
    dry_run? = not Keyword.get(opts, :live, false)
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
        case Code.ensure_loaded(String.to_atom(module_str)) do
          {:module, mod} ->
            mod

          {:error, reason} ->
            Mix.shell().error(
              "Could not load storage adapter #{module_str}: #{inspect(reason)}"
            )

            exit({:shutdown, 1})
        end
    end
  end

  defp print_cleanup_report(report, dry_run?) do
    mode = if dry_run?, do: "[DRY RUN] ", else: ""

    Mix.shell().info("""
    #{mode}Upload-session cleanup complete:
      Sessions found:   #{report.sessions_found}
      Sessions deleted: #{report.sessions_deleted}
      Objects deleted:  #{report.objects_deleted}
      Storage errors:   #{report.storage_errors}
    """)
  end

  defp maybe_exit_nonzero(0), do: :ok

  defp maybe_exit_nonzero(error_count) do
    Mix.shell().error("#{error_count} storage error(s) occurred during cleanup.")
    exit({:shutdown, 1})
  end
end
