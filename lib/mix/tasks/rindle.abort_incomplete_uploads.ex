defmodule Mix.Tasks.Rindle.AbortIncompleteUploads do
  @shortdoc "Transition timed-out upload sessions to expired"

  @moduledoc """
  Transitions upload sessions in the `signed` or `uploading` state that have
  passed their TTL (`expires_at`) into the `expired` state.

  This is a prerequisite for `mix rindle.cleanup_orphans`, which only removes
  sessions that are already in the `expired` state. Running both tasks in
  sequence provides a safe, two-step cleanup lane:

  1. `mix rindle.abort_incomplete_uploads` — mark timed-out sessions as expired.
  2. `mix rindle.cleanup_orphans` — delete expired sessions and their objects.

  ## Usage

      mix rindle.abort_incomplete_uploads

  ## Exit codes

    * `0` — all timed-out sessions were successfully transitioned.
    * `1` — one or more sessions could not be transitioned (errors are logged
      and counted in the output).

  ## Examples

      # Standard usage in a cron/CI pipeline
      mix rindle.abort_incomplete_uploads && mix rindle.cleanup_orphans

  ## Notes

  Sessions that are already in a terminal state (`completed`, `expired`,
  `aborted`, `failed`) are not touched. Only `signed` and `uploading` sessions
  past their expiry are eligible.
  """

  use Mix.Task

  alias Rindle.Ops.UploadMaintenance

  @requirements ["app.start"]

  @impl Mix.Task
  def run(argv) do
    {_opts, _args, _invalid} = OptionParser.parse(argv, strict: [])

    Mix.shell().info("Aborting incomplete uploads past their TTL...")

    case UploadMaintenance.abort_incomplete_uploads([]) do
      {:ok, report} ->
        print_abort_report(report)
        maybe_exit_nonzero(report.abort_errors)

      {:error, reason} ->
        Mix.shell().error("Abort task failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp print_abort_report(report) do
    Mix.shell().info("""
    Incomplete-upload abort complete:
      Sessions found:   #{report.sessions_found}
      Sessions aborted: #{report.sessions_aborted}
      Abort errors:     #{report.abort_errors}
    """)
  end

  defp maybe_exit_nonzero(0), do: :ok

  defp maybe_exit_nonzero(error_count) do
    Mix.shell().error("#{error_count} session(s) could not be transitioned to expired.")
    exit({:shutdown, 1})
  end
end
