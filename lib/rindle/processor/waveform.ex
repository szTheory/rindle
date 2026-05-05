defmodule Rindle.Processor.Waveform do
  @moduledoc false

  alias Rindle.AV.{Ffprobe, Subprocess}
  alias Rindle.Security.Argv

  @spec generate(Path.t(), map(), Path.t()) :: {:ok, Path.t()} | {:error, term()}
  def generate(source_path, spec, destination_path) do
    raw_path = destination_path <> ".raw"

    try do
      with {:ok, probe} <- Ffprobe.probe(source_path),
           {:ok, sample_rate} <- audio_sample_rate(probe),
           args <- waveform_args(source_path, spec, raw_path),
           :ok <- validate_command(args),
           {_output, 0} <- Subprocess.run("ffmpeg", args),
           {:ok, peaks} <- read_peaks(raw_path, spec.length),
           payload = %{length: spec.length, sample_rate: sample_rate, peaks: peaks},
           {:ok, json} <- Jason.encode(payload),
           :ok <- File.write(destination_path, json) do
        {:ok, destination_path}
      else
        {:error, _reason} = error -> error
        {output, status} -> {:error, {:ffmpeg_failed, status, output}}
      end
    after
      _ = File.rm(raw_path)
    end
  end

  defp audio_sample_rate(%{"streams" => streams}) when is_list(streams) do
    case Enum.find(streams, &(&1["codec_type"] == "audio")) do
      nil ->
        {:error, :missing_audio_track}

      %{"sample_rate" => sample_rate} ->
        parse_sample_rate(sample_rate)

      _stream ->
        {:error, :invalid_audio_sample_rate}
    end
  end

  defp audio_sample_rate(_probe), do: {:error, :missing_audio_track}

  defp parse_sample_rate(sample_rate) when is_binary(sample_rate) do
    case Integer.parse(sample_rate) do
      {value, ""} when value > 0 -> {:ok, value}
      _ -> {:error, :invalid_audio_sample_rate}
    end
  end

  defp parse_sample_rate(value) when is_integer(value) and value > 0, do: {:ok, value}
  defp parse_sample_rate(_value), do: {:error, :invalid_audio_sample_rate}

  defp waveform_args(source_path, spec, raw_path) do
    [
      "-y",
      "-i",
      source_path,
      "-map",
      "0:a:0",
      "-vn",
      "-ac",
      "1",
      "-ar",
      Integer.to_string(spec.analysis_sample_rate),
      "-c:a",
      "pcm_f32le",
      "-f",
      "f32le",
      raw_path
    ]
  end

  defp read_peaks(raw_path, bucket_count) do
    with {:ok, binary} <- File.read(raw_path),
         true <- byte_size(binary) > 0 do
      sample_count = div(byte_size(binary), 4)
      bucket_size = max(1, div(sample_count + bucket_count - 1, bucket_count))

      peaks =
        binary
        |> collect_peaks(bucket_size, 0, nil, nil, [])
        |> Enum.reverse()
        |> pad_peaks(bucket_count)

      {:ok, peaks}
    else
      false -> {:error, :empty_waveform}
      {:error, _reason} = error -> error
    end
  end

  defp collect_peaks(<<>>, _bucket_size, _bucket_pos, nil, nil, peaks), do: peaks

  defp collect_peaks(<<>>, _bucket_size, _bucket_pos, current_min, current_max, peaks) do
    [[round_peak(current_min), round_peak(current_max)] | peaks]
  end

  defp collect_peaks(
         <<sample::float-little-32, rest::binary>>,
         bucket_size,
         bucket_pos,
         current_min,
         current_max,
         peaks
       ) do
    sample = clamp_peak(sample)
    current_min = if is_nil(current_min), do: sample, else: min(current_min, sample)
    current_max = if is_nil(current_max), do: sample, else: max(current_max, sample)
    next_bucket_pos = bucket_pos + 1

    if next_bucket_pos >= bucket_size do
      collect_peaks(
        rest,
        bucket_size,
        0,
        nil,
        nil,
        [[round_peak(current_min), round_peak(current_max)] | peaks]
      )
    else
      collect_peaks(rest, bucket_size, next_bucket_pos, current_min, current_max, peaks)
    end
  end

  defp pad_peaks(peaks, bucket_count) do
    peaks
    |> Enum.take(bucket_count)
    |> then(fn collected ->
      collected ++ List.duplicate([0.0, 0.0], max(bucket_count - length(collected), 0))
    end)
  end

  defp validate_command(args) do
    full_args = Subprocess.build_args("ffmpeg", args, [])
    command_str = Enum.join(["ffmpeg" | full_args], " ")

    case Argv.validate(command_str) do
      {:ok, _command} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp clamp_peak(value), do: min(max(value, -1.0), 1.0)
  defp round_peak(value), do: Float.round(value, 6)
end
