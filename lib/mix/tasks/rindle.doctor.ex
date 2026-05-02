defmodule Mix.Tasks.Rindle.Doctor do
  @shortdoc "Checks the host environment for Rindle dependencies"

  @moduledoc """
  Validates that the host environment has all necessary system dependencies installed.

  Currently, it verifies:
    * `ffmpeg` >= 6.0 is installed and available in the system PATH.

  ## Usage

      mix rindle.doctor

  ## Exit codes

    * `0` — All checks passed.
    * `1` — One or more environment checks failed.
  """

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("Rindle: running environment checks...")

    try do
      Rindle.AV.Probe.check_ffmpeg!()
      Mix.shell().info("  FFmpeg: OK")
      Mix.shell().info("Rindle: Environment checks passed.")
    rescue
      e in RuntimeError ->
        Mix.shell().error("Rindle.Doctor failed: #{e.message}")
        System.halt(1)
    end
  end
end
