defmodule Rindle.Processor.AV do
  @moduledoc """
  Public AV processor boundary for preset-led video, audio, and waveform recipes.
  """

  @behaviour Rindle.Processor

  alias Rindle.AV.Subprocess
  alias Rindle.Processor.AV.Recipe
  alias Rindle.Security.Argv

  @capabilities [
    :video_transcode,
    :video_frame_extract,
    :video_thumbnail_strip,
    :audio_transcode,
    :audio_normalize,
    :audio_waveform
  ]

  @spec capabilities() :: [atom()]
  def capabilities, do: @capabilities

  @spec normalize(map()) :: {:ok, map()} | {:error, term()}
  def normalize(spec), do: Recipe.normalize(spec)

  @spec normalize!(map()) :: map()
  def normalize!(spec) do
    case normalize(spec) do
      {:ok, normalized} ->
        normalized

      {:error, reason} ->
        raise ArgumentError, "invalid AV recipe: #{inspect(reason)}"
    end
  end

  @impl Rindle.Processor
  @spec process(Path.t(), map(), Path.t()) :: {:ok, Path.t()} | {:error, term()}
  def process(source_path, variant_spec, destination_path) do
    with {:ok, normalized} <- normalize(variant_spec),
         {:ok, args} <- build_args(source_path, normalized, destination_path),
         :ok <- validate_command(args),
         {output, status} <- Subprocess.run("ffmpeg", args) do
      case status do
        0 -> {:ok, destination_path}
        _ -> {:error, {:ffmpeg_failed, status, output}}
      end
    end
  end

  defp build_args(source, %{kind: :video} = spec, dest) do
    scale = ["-vf", "scale=#{spec.width}:#{spec.height}"]

    args =
      ["-i", source] ++
        ["-c:v", ffmpeg_video_codec(spec.video_codec)] ++
        ["-c:a", ffmpeg_audio_codec(spec.audio_codec)] ++
        ["-crf", Integer.to_string(spec.crf)] ++
        ["-b:a", "#{spec.audio_bitrate_kbps}k"] ++
        scale ++
        maybe_faststart(spec) ++ [dest]

    {:ok, args}
  end

  defp build_args(source, %{kind: :audio} = spec, dest) do
    args =
      ["-i", source] ++
        ["-c:a", ffmpeg_audio_codec(spec.audio_codec)] ++
        ["-b:a", "#{spec.audio_bitrate_kbps}k"] ++
        maybe_channels(spec) ++ maybe_loudnorm(spec) ++ [dest]

    {:ok, args}
  end

  defp build_args(_source, %{kind: :waveform}, _dest),
    do: {:error, {:processor_unsupported, :audio_waveform}}

  defp build_args(_source, %{kind: :image}, _dest),
    do: {:error, {:processor_unsupported, :image}}

  defp build_args(_source, spec, _dest), do: {:error, {:unsupported_recipe, spec}}

  defp validate_command(args) do
    full_args = Subprocess.build_args("ffmpeg", args, [])
    command_str = Enum.join(["ffmpeg" | full_args], " ")
    Argv.validate(command_str)
  end

  defp maybe_faststart(%{faststart: true}), do: ["-movflags", "+faststart"]
  defp maybe_faststart(_spec), do: []

  defp maybe_channels(%{channels: channels}) when channels in [1, 2],
    do: ["-ac", Integer.to_string(channels)]

  defp maybe_channels(_spec), do: []

  defp maybe_loudnorm(%{normalize: true, two_pass: false}),
    do: ["-af", "loudnorm=I=-16:TP=-1.5:LRA=11"]

  defp maybe_loudnorm(%{normalize: true, two_pass: true}),
    do: ["-af", "loudnorm=I=-16:TP=-1.5:LRA=11"]

  defp maybe_loudnorm(_spec), do: []

  defp ffmpeg_video_codec(:h264), do: "libx264"
  defp ffmpeg_video_codec(codec), do: to_string(codec)

  defp ffmpeg_audio_codec(:aac), do: "aac"
  defp ffmpeg_audio_codec(:mp3), do: "libmp3lame"
  defp ffmpeg_audio_codec(codec), do: to_string(codec)
end
