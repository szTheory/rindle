defmodule Rindle.Workers.AbortIncompleteUploads do
  @moduledoc """
  Oban cron worker for transitioning incomplete upload sessions to `expired`.

  Delegates entirely to `Rindle.Ops.UploadMaintenance.abort_incomplete_uploads/1`
  — no expiry logic lives here. Adopters can schedule this worker from their
  Oban cron config without requiring Rindle to supervise Oban.

  This worker should be scheduled **before** `Rindle.Workers.CleanupOrphans`
  to form the two-step cleanup lane:

  1. `AbortIncompleteUploads` — marks `signed`/`uploading` sessions past their
     TTL as `expired`.
  2. `CleanupOrphans` — removes sessions in the `expired` state and their
     staged objects from storage.

  ## Cron Configuration Example

  In your Oban configuration:

      config :my_app, Oban,
        queues: [rindle_maintenance: 1],
        plugins: [
          {Oban.Plugins.Cron,
           crontab: [
             {"0 1 * * *", Rindle.Workers.AbortIncompleteUploads},
             {"0 2 * * *", Rindle.Workers.CleanupOrphans,
              args: %{"dry_run" => false}}
           ]}
        ]

  ## Job Arguments

  This worker accepts no arguments. All behavior is driven by the underlying
  `UploadMaintenance` service and the session TTL values stored in the database.

  ## Return Contract

    * `:ok` — all eligible sessions were successfully transitioned.
    * `{:error, reason}` — the maintenance service returned an error; Oban will
      retry according to the worker's `max_attempts` policy so failures are
      tagged and observable in the job queue.

  ## Observability

  Failures appear as Oban job errors with `attempt` and `max_attempts` metadata.
  The underlying `UploadMaintenance` service emits structured `Logger` events
  tagged with `rindle.upload_maintenance.*` for per-session transitions and errors.
  """

  use Oban.Worker, queue: :rindle_maintenance, max_attempts: 3

  require Logger

  alias Rindle.Ops.UploadMaintenance

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    case UploadMaintenance.abort_incomplete_uploads([]) do
      {:ok, report} ->
        Logger.info("rindle.workers.abort_incomplete_uploads.completed",
          sessions_found: report.sessions_found,
          sessions_aborted: report.sessions_aborted,
          abort_errors: report.abort_errors
        )

        :ok

      {:error, reason} ->
        Logger.error("rindle.workers.abort_incomplete_uploads.failed",
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end
end
