defmodule Rindle.Processor.AV.Video do
  @moduledoc false

  alias Rindle.AV.Subprocess
  alias Rindle.Security.Argv

  @type strategy :: :scene_change | :first_i_frame | :first_frame | :strip

  @spec transcode(Path.t(), map(), Path.t()) :: {:ok, Path.t()} | {:error, term()}
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

  @spec image_output(Path.t(), map(), Path.t()) :: {:ok, Path.t()} | {:error, term()}
  def image_output(source_path, %{preset: :video_poster_scene} = spec, destination_path) do
    with {:ok, %{strategy: _strategy}} <- poster(source_path, spec, destination_path) do
      {:ok, destination_path}
    end
  end

  def image_output(source_path, %{preset: :video_thumbnail_strip} = spec, destination_path) do
    with {:ok, %{strategy: :strip}} <- strip(source_path, spec, destination_path) do
      {:ok, destination_path}
    end
  end

  def image_output(_source_path, spec, _destination_path),
    do: {:error, {:unsupported_recipe, spec}}

  @spec poster(Path.t(), map(), Path.t()) ::
          {:ok, %{path: Path.t(), strategy: strategy()}} | {:error, term()}
  def poster(source_path, spec, destination_path) do
    attempts = [
      {:scene_change, poster_scene_args(source_path, spec, destination_path)},
      {:first_i_frame, poster_iframe_args(source_path, destination_path)},
      {:first_frame, poster_first_frame_args(source_path, destination_path)}
    ]

    run_fallback_attempts(attempts, destination_path)
  end

  @spec strip(Path.t(), map(), Path.t()) ::
          {:ok, %{path: Path.t(), strategy: strategy()}} | {:error, term()}
  def strip(source_path, spec, destination_path) do
    args = strip_args(source_path, spec, destination_path)

    with :ok <- validate_command(args),
         {output, status} <- Subprocess.run("ffmpeg", args) do
      case status do
        0 ->
          if artifact_present?(destination_path) do
            {:ok, %{path: destination_path, strategy: :strip}}
          else
            {:error, {:ffmpeg_missing_output, :strip}}
          end

        _ ->
          {:error, {:ffmpeg_failed, status, output}}
      end
    end
  end

  defp run_fallback_attempts([], _destination_path),
    do: {:error, {:ffmpeg_missing_output, :poster}}

  defp run_fallback_attempts([{strategy, args} | rest], destination_path) do
    _ = File.rm(destination_path)

    with :ok <- validate_command(args),
         {output, status} <- Subprocess.run("ffmpeg", args) do
      cond do
        status == 0 and artifact_present?(destination_path) ->
          {:ok, %{path: destination_path, strategy: strategy}}

        status == 0 ->
          run_fallback_attempts(rest, destination_path)

        true ->
          if rest == [] do
            {:error, {:ffmpeg_failed, :poster, output}}
          else
            run_fallback_attempts(rest, destination_path)
          end
      end
    end
  end

  defp transcode_args(source_path, spec, destination_path) do
    scale =
      "scale=w=#{spec.width}:h=#{spec.height}:force_original_aspect_ratio=decrease," <>
        "pad=#{spec.width}:#{spec.height}:(ow-iw)/2:(oh-ih)/2:black"

    [
      "-y",
      "-i",
      source_path,
      "-map",
      "0:v:0",
      "-map",
      "0:a:0?",
      "-c:v",
      ffmpeg_video_codec(spec.video_codec),
      "-pix_fmt",
      "yuv420p",
      "-crf",
      Integer.to_string(spec.crf),
      "-maxrate",
      "2500k",
      "-bufsize",
      "5000k",
      "-vf",
      scale,
      "-c:a",
      ffmpeg_audio_codec(spec.audio_codec),
      "-b:a",
      "#{spec.audio_bitrate_kbps}k"
    ] ++ maybe_faststart(spec) ++ [destination_path]
  end

  defp poster_scene_args(source_path, spec, destination_path) do
    scene_threshold = :erlang.float_to_binary(spec.scene_threshold, decimals: 1)
    select_filter = "select='gt(scene,#{scene_threshold})*eq(pict_type,I)'"

    [
      "-y",
      "-i",
      source_path,
      "-vf",
      select_filter,
      "-frames:v",
      "1",
      "-vsync",
      "vfr",
      destination_path
    ]
  end

  defp poster_iframe_args(source_path, destination_path) do
    [
      "-y",
      "-i",
      source_path,
      "-vf",
      "select='eq(pict_type,I)'",
      "-frames:v",
      "1",
      "-vsync",
      "vfr",
      destination_path
    ]
  end

  defp poster_first_frame_args(source_path, destination_path) do
    [
      "-y",
      "-i",
      source_path,
      "-frames:v",
      "1",
      destination_path
    ]
  end

  defp strip_args(source_path, spec, destination_path) do
    tile = "#{spec.strip_count}x1:padding=0:margin=0"
    fps = "fps=#{spec.fps}"
    scale = "scale=#{spec.thumb_width}:#{spec.thumb_height}"

    [
      "-y",
      "-i",
      source_path,
      "-vf",
      "#{fps},#{scale},tile=#{tile}",
      "-frames:v",
      "1",
      destination_path
    ]
  end

  defp validate_command(args) do
    full_args = Subprocess.build_args("ffmpeg", args, [])
    command_str = Enum.join(["ffmpeg" | full_args], " ")

    case Argv.validate(command_str) do
      {:ok, _command} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp artifact_present?(destination_path) do
    case File.stat(destination_path) do
      {:ok, %File.Stat{size: size}} when size > 0 -> true
      _ -> false
    end
  end

  defp maybe_faststart(%{faststart: true}), do: ["-movflags", "+faststart"]
  defp maybe_faststart(_spec), do: []

  defp ffmpeg_video_codec(:h264), do: "libx264"
  defp ffmpeg_video_codec(codec), do: to_string(codec)

  defp ffmpeg_audio_codec(:aac), do: "aac"
  defp ffmpeg_audio_codec(:mp3), do: "libmp3lame"
  defp ffmpeg_audio_codec(codec), do: to_string(codec)
end
