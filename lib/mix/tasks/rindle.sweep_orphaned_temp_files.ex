defmodule Mix.Tasks.Rindle.SweepOrphanedTempFiles do
  @shortdoc "Preview or sweep orphaned AV temp run directories"

  @moduledoc """
  Sweeps orphaned AV temp run directories under `Rindle.tmp/`.

  This is the explicit on-demand operator lane for temp-run-dir residue. It is
  separate from upload-session cleanup and shares the same internal sweep
  service contract as the scheduled worker path.

  ## Usage

      mix rindle.sweep_orphaned_temp_files [--dry-run | --no-dry-run | --live] [--threshold-sec SECONDS]

  ## Options

    * `--dry-run` — explicitly request preview mode. This is also the default.
    * `--no-dry-run` / `--live` — perform destructive deletions.
    * `--threshold-sec` — sweep directories older than this many seconds.
      Defaults to `14400` (4 hours).

  ## Exit codes

    * `0` — sweep completed successfully, including dry runs and zero-match runs.
    * `1` — one or more filesystem errors were encountered while scanning or deleting.

  ## Examples

      # Safe default: preview what would be swept
      mix rindle.sweep_orphaned_temp_files

      # Same, made explicit
      mix rindle.sweep_orphaned_temp_files --dry-run --threshold-sec 14400

      # Perform live deletion
      mix rindle.sweep_orphaned_temp_files --no-dry-run

  ## Safety default

  The Mix task, direct service call, and scheduled worker all default to
  `dry_run: true`. Live deletion requires explicit opt-in here
  (`--no-dry-run`/`--live`) and in Oban cron args (`"dry_run" => false`).
  """

  use Mix.Task

  alias Rindle.Ops.SweepOrphanedTempFiles

  @default_threshold_sec 14_400
  @failure_output_limit 5
  @requirements ["app.start"]

  @impl Mix.Task
  def run(argv) do
    {opts, _args, _invalid} =
      OptionParser.parse(argv,
        strict: [dry_run: :boolean, live: :boolean, threshold_sec: :integer]
      )

    dry_run? =
      case Keyword.fetch(opts, :dry_run) do
        {:ok, value} -> value
        :error -> not Keyword.get(opts, :live, false)
      end

    threshold_sec = Keyword.get(opts, :threshold_sec, @default_threshold_sec)

    Mix.shell().info(
      "Rindle: sweeping orphaned temp run directories " <>
        "(dry_run=#{dry_run?}, threshold_sec=#{threshold_sec})..."
    )

    report = SweepOrphanedTempFiles.sweep(threshold_sec: threshold_sec, dry_run: dry_run?)

    format_report(report)
    |> Enum.each(fn line -> Mix.shell().info(line) end)

    Mix.shell().info("Done.")

    if report.errors > 0 do
      Mix.shell().error("#{report.errors} sweep error(s) occurred.")
      System.halt(1)
    end
  end

  @doc false
  def format_report(report, limit \\ @failure_output_limit) do
    summary_lines = [
      "  run_dirs_scanned: #{report.run_dirs_scanned}",
      "  orphan_count:     #{report.orphan_count}",
      "  run_dirs_deleted: #{report.run_dirs_deleted}",
      "  errors:           #{report.errors}"
    ]

    summary_lines ++ failure_lines(report, limit)
  end

  defp failure_lines(%{errors: 0}, _limit), do: []

  defp failure_lines(report, limit) do
    failures = List.duplicate(sweep_failure_entry(report), min(report.errors, limit))

    rendered =
      Enum.map(failures, fn failure ->
        "  [#{failure.failure_class}] #{failure.reason}: #{failure.message}"
      end)

    remaining = report.errors - length(failures)

    if remaining > 0 do
      rendered ++ ["  ... #{remaining} additional sweep failure(s) omitted"]
    else
      rendered
    end
  end

  defp sweep_failure_entry(report) do
    %{
      failure_class: :filesystem,
      reason: :scan_or_delete_failed,
      message:
        "#{report.errors} filesystem operation(s) failed during sweep; inspect logs for per-path detail."
    }
  end
end
