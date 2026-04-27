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

  Worker-level events:

    * `Logger.info("rindle.workers.cleanup_orphans.completed", ...)` — emitted
      after a successful cleanup with `sessions_found`, `sessions_deleted`,
      `objects_deleted`, `storage_skipped`, `storage_errors`, `dry_run`.
    * `Logger.error("rindle.workers.cleanup_orphans.failed", ...)` — emitted
      when the maintenance service returns `{:error, reason}` AND when the
      storage adapter cannot be resolved (`stage: :resolve_storage_adapter`).
      Operators should alert on this event for both pipelines.
    * `Logger.error("rindle.workers.cleanup_orphans.storage_load_failed", ...)`
      and `…storage_not_found` — more specific events emitted by the helper
      before the worker-level `…failed` event fires.
  """

  use Oban.Worker, queue: :rindle_maintenance, max_attempts: 3

  require Logger

  alias Rindle.Ops.UploadMaintenance

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    dry_run? = Map.get(args, "dry_run", true)

    with {:ok, storage_mod} <- resolve_storage_adapter(args) do
      cleanup_opts = build_cleanup_opts(dry_run?, storage_mod)

      handle_cleanup_result(
        UploadMaintenance.cleanup_orphans(cleanup_opts),
        dry_run?,
        storage_mod
      )
    else
      # WR-06: surface adapter-load errors via the documented `…failed` event
      # so operators who alert on it see the failure (the helper already emits
      # the more specific `…storage_load_failed` / `…storage_not_found` events).
      {:error, reason} ->
        Logger.error("rindle.workers.cleanup_orphans.failed",
          reason: inspect(reason),
          stage: :resolve_storage_adapter
        )

        {:error, reason}
    end
  end

  defp build_cleanup_opts(dry_run?, storage_mod) do
    if storage_mod do
      [dry_run: dry_run?, storage: storage_mod]
    else
      [dry_run: dry_run?]
    end
  end

  defp handle_cleanup_result({:ok, report}, dry_run?, storage_mod) do
    Logger.info("rindle.workers.cleanup_orphans.completed",
      sessions_found: report.sessions_found,
      sessions_deleted: report.sessions_deleted,
      objects_deleted: report.objects_deleted,
      storage_skipped: report.storage_skipped,
      storage_errors: report.storage_errors,
      dry_run: dry_run?
    )

    :telemetry.execute(
      [:rindle, :cleanup, :run],
      %{
        sessions_deleted: report.sessions_deleted,
        objects_deleted: report.objects_deleted
      },
      %{
        profile: :unknown,
        adapter: storage_mod || :unknown,
        dry_run: dry_run?,
        worker: __MODULE__
      }
    )

    :ok
  end

  defp handle_cleanup_result({:error, reason}, dry_run?, _storage_mod) do
    Logger.error("rindle.workers.cleanup_orphans.failed",
      reason: inspect(reason),
      dry_run: dry_run?
    )

    {:error, reason}
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
