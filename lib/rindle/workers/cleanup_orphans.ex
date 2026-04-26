defmodule Rindle.Workers.CleanupOrphans do
  @moduledoc """
  Oban cron worker for removing expired upload sessions and their staged objects.

  Delegates entirely to `Rindle.Ops.UploadMaintenance.cleanup_orphans/1` — no
  cleanup logic lives here. Adopters can schedule this worker from their Oban
  cron config without requiring Rindle to supervise Oban.

  ## Cron Configuration Example

  In your Oban configuration:

      config :my_app, Oban,
        queues: [rindle_maintenance: 1],
        plugins: [
          {Oban.Plugins.Cron,
           crontab: [
             {"0 2 * * *", Rindle.Workers.CleanupOrphans,
              args: %{"dry_run" => false}},
             {"0 1 * * *", Rindle.Workers.AbortIncompleteUploads}
           ]}
        ]

  ## Job Arguments

    * `"dry_run"` (boolean, default `true`) — when `true`, reports planned
      actions without executing any deletes. Safe for inspection cron runs.
    * `"storage"` (string, optional) — fully-qualified storage adapter module
      name. When omitted, falls back to `:default_storage` from the `:rindle`
      application config.

  ## Return Contract

    * `:ok` — cleanup completed (including dry runs).
    * `{:error, reason}` — cleanup service returned an error; Oban will retry
      according to the worker's `max_attempts` policy so failures are tagged
      and observable in the job queue.

  ## Observability

  Failures appear as Oban job errors with `attempt` and `max_attempts` metadata.
  The underlying `UploadMaintenance` service also emits `Logger.warning` events
  tagged with `rindle.upload_maintenance.*` for storage-level errors.
  """

  use Oban.Worker, queue: :rindle_maintenance, max_attempts: 3

  require Logger

  alias Rindle.Ops.UploadMaintenance

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    dry_run? = Map.get(args, "dry_run", true)

    with {:ok, storage_mod} <- resolve_storage_adapter(args) do
      cleanup_opts =
        [dry_run: dry_run?]
        |> then(fn o ->
          if storage_mod, do: Keyword.put(o, :storage, storage_mod), else: o
        end)

      case UploadMaintenance.cleanup_orphans(cleanup_opts) do
        {:ok, report} ->
          Logger.info("rindle.workers.cleanup_orphans.completed",
            sessions_found: report.sessions_found,
            sessions_deleted: report.sessions_deleted,
            objects_deleted: report.objects_deleted,
            storage_errors: report.storage_errors,
            dry_run: dry_run?
          )

          :ok

        {:error, reason} ->
          Logger.error("rindle.workers.cleanup_orphans.failed",
            reason: inspect(reason),
            dry_run: dry_run?
          )

          {:error, reason}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp resolve_storage_adapter(%{"storage" => module_str}) when is_binary(module_str) do
    case Code.ensure_loaded(String.to_existing_atom(module_str)) do
      {:module, mod} ->
        {:ok, mod}

      {:error, reason} ->
        Logger.error("rindle.workers.cleanup_orphans.storage_load_failed",
          module: module_str,
          reason: inspect(reason)
        )

        {:error, {:storage_load_failed, module_str, reason}}
    end
  rescue
    e in ArgumentError ->
      Logger.error("rindle.workers.cleanup_orphans.storage_not_found",
        module: module_str,
        reason: inspect(e)
      )

      {:error, {:storage_not_found, module_str}}
  end

  defp resolve_storage_adapter(_args) do
    {:ok, Application.get_env(:rindle, :default_storage)}
  end
end
