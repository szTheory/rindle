defmodule Mix.Tasks.Rindle.Doctor do
  @shortdoc "Checks the host environment for Rindle dependencies"

  @moduledoc """
  Validates that the host environment has all necessary system dependencies installed.

  Currently, it verifies:
    * `ffmpeg` >= 6.0 is installed and available in the system PATH.
    * optional profile module arguments can be loaded and their AV variants are
      compatible with the bundled runtime/processor contract.

  ## Usage

      mix rindle.doctor
      mix rindle.doctor MyApp.VideoProfile MyApp.PodcastProfile

  ## Exit codes

    * `0` — All checks passed.
    * `1` — One or more environment checks failed.
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    run_checks(args)
  end

  @doc false
  def run_checks(args, opts \\ []) do
    shell = Keyword.get(opts, :shell, Mix.shell())
    probe = Keyword.get(opts, :probe, fn -> Rindle.AV.Probe.check_ffmpeg!() end)
    env = Keyword.get(opts, :env, System.get_env())

    shell.info("Rindle: running environment checks...")

    try do
      probe.()
      shell.info("  FFmpeg: OK")

      args
      |> resolve_profiles!()
      |> Enum.each(&check_profile!(&1, shell, env))

      shell.info("Rindle: Environment checks passed.")
      :ok
    rescue
      e in RuntimeError ->
        fail!(shell, e.message)
    end
  end

  defp resolve_profiles!(args) do
    Enum.map(args, fn arg ->
      module = module_from_string(arg)

      ensure_profile_loaded(module, arg)

      if Code.ensure_loaded?(module) and function_exported?(module, :__rindle_profile__, 0) and
           function_exported?(module, :variants, 0) do
        module
      else
        raise "unknown profile module #{arg}. Pass a loaded Rindle profile module like Rindle.Adopter.CanonicalApp.VideoProfile."
      end
    end)
  end

  defp check_profile!(module, shell, env) do
    variants =
      module.variants()
      |> Enum.filter(fn {_name, spec} -> av_variant?(spec) end)

    Enum.each(variants, fn {name, spec} ->
      normalized =
        case Rindle.Processor.AV.normalize(spec) do
          {:ok, value} -> value
          {:error, reason} -> raise "profile #{inspect(module)} variant #{inspect(name)} is invalid: #{inspect(reason)}"
        end

      case Rindle.Processor.AV.RuntimeGuard.check!(normalized, env: env) do
        :ok -> :ok
        {:error, reason} -> raise "profile #{inspect(module)} variant #{inspect(name)} failed runtime checks: #{inspect(reason)}"
      end

      capability = required_capability(normalized)

      unless capability in Rindle.Processor.AV.capabilities() do
        raise "profile #{inspect(module)} variant #{inspect(name)} requires unsupported processor capability #{inspect(capability)}"
      end
    end)

    shell.info("  Profile #{inspect(module)}: OK (variants checked: #{length(variants)})")
  end

  defp required_capability(%{kind: :video, output_kind: :video}), do: :video_transcode
  defp required_capability(%{kind: :audio, output_kind: :audio}), do: :audio_transcode
  defp required_capability(%{kind: :waveform, output_kind: :waveform}), do: :audio_waveform
  defp required_capability(%{preset: :video_thumbnail_strip}), do: :video_thumbnail_strip
  defp required_capability(%{kind: :image, output_kind: :image}), do: :video_frame_extract

  defp av_variant?(spec) when is_list(spec), do: spec |> Map.new() |> av_variant?()
  defp av_variant?(%{kind: kind}) when kind in [:video, :audio, :waveform], do: true

  defp av_variant?(%{preset: preset})
       when preset in [:video_poster_scene, :video_thumbnail_strip],
       do: true

  defp av_variant?(_spec), do: false

  defp module_from_string(name) do
    name
    |> String.split(".")
    |> Module.concat()
  end

  defp ensure_profile_loaded(module, module_name) do
    if Code.ensure_loaded?(module) do
      :ok
    else
      case source_path_for_module(module_name) do
        nil ->
          :ok

        path ->
          Code.compile_file(path)
          :ok
      end
    end
  end

  defp source_path_for_module(module_name) do
    ["lib", "test/support", "test/adopter"]
    |> Enum.flat_map(&Path.wildcard(Path.join(&1, "**/*.ex")))
    |> Enum.find(fn path ->
      File.read!(path) =~ "defmodule #{module_name} do"
    end)
  end

  defp fail!(shell, message) do
    formatted = "Rindle.Doctor failed: #{message}"
    shell.error(formatted)
    raise Mix.Error, message: formatted
  end
end
