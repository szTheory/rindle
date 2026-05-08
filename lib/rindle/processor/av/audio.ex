defmodule Rindle.Processor.AV.Audio do
  @moduledoc false

  alias Rindle.AV.Subprocess
  alias Rindle.Security.Argv

  @loudnorm_targets %{integrated: "-16", true_peak: "-1.5", loudness_range: "11"}

  @spec transcode(Path.t(), map(), Path.t()) :: {:ok, Path.t()} | {:error, term()}
  def transcode(_source_path, %{two_pass: true, normalize: false}, _destination_path) do
    {:error, {:invalid_audio_recipe, :two_pass_requires_normalize}}
  end

  def transcode(source_path, %{normalize: true, two_pass: true} = spec, destination_path) do
    with {:ok, measurements} <- loudnorm_measurements(source_path, spec),
         args <- transcode_args(source_path, spec, destination_path, measurements),
         :ok <- validate_command(args),
         {output, status} <- Subprocess.run("ffmpeg", args) do
      case status do
        0 -> {:ok, destination_path}
        _ -> {:error, {:ffmpeg_failed, status, output}}
      end
    end
  end

  def transcode(source_path, spec, destination_path) do
    args = transcode_args(source_path, spec, destination_path)

    with :ok <- validate_command(args),
         {output, status} <- Subprocess.run("ffmpeg", args) do
      case status do
        0 -> {:ok, destination_path}
        _ -> {:error, {:ffmpeg_failed, status, output}}
      end
    end
  end

  defp transcode_args(source_path, spec, destination_path, measurements \\ nil) do
    [
      "-y",
      "-i",
      source_path,
      "-vn",
      "-map",
      "0:a:0",
      "-c:a",
      ffmpeg_audio_codec(spec.audio_codec),
      "-b:a",
      "#{spec.audio_bitrate_kbps}k"
    ] ++
      maybe_channels(spec) ++
      maybe_audio_filters(spec, measurements) ++
      [destination_path]
  end

  defp maybe_audio_filters(%{normalize: true, two_pass: true}, measurements)
       when is_map(measurements) do
    ["-af", two_pass_loudnorm_filter(measurements)]
  end

  defp maybe_audio_filters(%{normalize: true}, _measurements) do
    ["-af", base_loudnorm_filter()]
  end

  defp maybe_audio_filters(_spec, _measurements), do: []

  defp maybe_channels(%{channels: channels}) when channels in [1, 2] do
    ["-ac", Integer.to_string(channels)]
  end

  defp maybe_channels(_spec), do: []

  defp loudnorm_measurements(source_path, spec) do
    args =
      [
        "-y",
        "-i",
        source_path,
        "-vn",
        "-map",
        "0:a:0"
      ] ++
        maybe_channels(spec) ++
        ["-af", "#{base_loudnorm_filter()}:print_format=json", "-f", "null", null_device()]

    with :ok <- validate_command(args),
         {output, 0} <- Subprocess.run("ffmpeg", args),
         {:ok, measurements} <- parse_loudnorm_measurements(output) do
      {:ok, measurements}
    else
      {output, status} -> {:error, {:ffmpeg_failed, status, output}}
    end
  end

  defp parse_loudnorm_measurements(output) do
    case Regex.scan(~r/\{[\s\S]*?\}/, output) |> List.last() do
      [json] ->
        with {:ok, decoded} <- Jason.decode(json),
             :ok <- validate_loudnorm_measurements(decoded) do
          {:ok, decoded}
        end

      _ ->
        {:error, :invalid_loudnorm_output}
    end
  end

  defp validate_loudnorm_measurements(decoded) do
    required = ["input_i", "input_tp", "input_lra", "input_thresh", "target_offset"]

    if Enum.all?(required, &Map.has_key?(decoded, &1)) do
      :ok
    else
      {:error, :invalid_loudnorm_output}
    end
  end

  defp two_pass_loudnorm_filter(measurements) do
    base_loudnorm_filter() <>
      ":measured_I=#{measurements["input_i"]}" <>
      ":measured_TP=#{measurements["input_tp"]}" <>
      ":measured_LRA=#{measurements["input_lra"]}" <>
      ":measured_thresh=#{measurements["input_thresh"]}" <>
      ":offset=#{measurements["target_offset"]}" <>
      ":linear=true:print_format=summary"
  end

  defp base_loudnorm_filter do
    "loudnorm=I=#{@loudnorm_targets.integrated}" <>
      ":TP=#{@loudnorm_targets.true_peak}" <>
      ":LRA=#{@loudnorm_targets.loudness_range}"
  end

  defp validate_command(args) do
    full_args = Subprocess.build_args("ffmpeg", args, [])
    command_str = Enum.join(["ffmpeg" | full_args], " ")

    case Argv.validate(command_str) do
      {:ok, _command} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp null_device do
    if match?({:win32, _}, :os.type()), do: "NUL", else: "/dev/null"
  end

  defp ffmpeg_audio_codec(:aac), do: "aac"
  defp ffmpeg_audio_codec(:mp3), do: "libmp3lame"
  defp ffmpeg_audio_codec(codec), do: to_string(codec)
end
