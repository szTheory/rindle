defmodule Mix.Tasks.Rindle.Doctor do
  @shortdoc "Checks the host environment for Rindle dependencies"

  @moduledoc """
  Validates that the host environment has all necessary system dependencies installed.

  Currently, it verifies:
    * `ffmpeg` >= 6.0 is installed and available in the system PATH.
    * optional profile module arguments can be loaded and their AV variants are
      compatible with the bundled runtime/processor contract.
    * Phase 36 / MUX-16 — when at least one profile opts into `:streaming`,
      four additional checks validate Mux credentials, signing key, webhook
      secrets, and (with `--streaming`) a 5s-bounded live API smoke ping.

  ## Usage

      mix rindle.doctor
      mix rindle.doctor MyApp.VideoProfile MyApp.PodcastProfile
      mix rindle.doctor --streaming

  Pass `--streaming` to enable a 5-second live smoke ping against
  `Mux.Video.Assets.list/1`. The default run never hits the network.

  ## Exit codes

    * `0` — All checks passed.
    * `1` — One or more environment checks failed.
  """

  use Mix.Task

  alias Rindle.Ops.RuntimeChecks

  @impl Mix.Task
  def run(args) do
    {parsed, rest, invalid} =
      OptionParser.parse(args, strict: [streaming: :boolean])

    # Phase 36 WR-06: fail loudly on unknown flags so a typo like
    # `--streming` surfaces immediately. Mix tasks generally fail on
    # unknown flags; the previous implementation discarded `invalid`
    # and silently ran without the requested flag.
    case invalid do
      [] ->
        :ok

      invalid_flags ->
        Mix.raise(
          "Unknown options: " <>
            Enum.map_join(invalid_flags, ", ", fn {flag, _} -> flag end)
        )
    end

    streaming? = Keyword.get(parsed, :streaming, false)

    run_checks(rest, streaming: streaming?)
  end

  @doc false
  def run_checks(args, opts \\ []) do
    shell = Keyword.get(opts, :shell, Mix.shell())
    mix_app = Keyword.get(opts, :mix_app, Mix.Project.config()[:app])
    exit_on_failure? = Keyword.get(opts, :exit_on_failure?, true)
    streaming? = Keyword.get(opts, :streaming, false)

    shell.info("Rindle: running environment checks...")

    report =
      args
      |> RuntimeChecks.run(
        opts
        |> Keyword.put(:mix_app, mix_app)
        |> Keyword.put(:streaming, streaming?)
      )
      |> emit_report(shell)

    if exit_on_failure? and not report.success? do
      raise Mix.Error, message: "Rindle.Doctor failed: #{report.failed} check(s) failed"
    end

    report
  end

  defp emit_report(report, shell) do
    Enum.each(report.checks, &emit_check(shell, &1))

    if report.success? do
      shell.info("Rindle: Environment checks passed (#{report.total} checks).")
    else
      shell.info(
        "Rindle: Environment checks failed (#{report.failed}/#{report.total} checks failed)."
      )
    end

    report
  end

  defp emit_check(shell, %{
         status: status,
         id: id,
         component: component,
         summary: summary,
         fix: fix
       }) do
    shell.info("[#{String.upcase(to_string(status))}] #{id} (#{component}) #{summary}")

    if status in [:warn, :error] do
      shell.info("  Fix: #{fix}")
    end
  end
end
