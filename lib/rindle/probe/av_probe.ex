defmodule Rindle.Probe.AVProbe do
  @moduledoc """
  FFprobe-backed probe for video and audio. Wraps `Rindle.AV.Ffprobe.probe/1`
  and reshapes raw FFprobe JSON into `Rindle.Probe.result()`.

  Phase 23 HTML-escapes FFprobe string output at the shim layer. This module
  applies Phase 24 metadata truncation and control-character stripping before
  returning the probe result for persistence.
  """

  @behaviour Rindle.Probe

  alias Rindle.AV.{Ffprobe, MetadataSanitizer}

  @video_mime_prefixes ["video/"]
  @audio_mime_prefixes ["audio/"]

  @impl Rindle.Probe
  @spec accepts?(term()) :: boolean()
  def accepts?(content_type) when is_binary(content_type) do
    Enum.any?(@video_mime_prefixes ++ @audio_mime_prefixes, &String.starts_with?(content_type, &1))
  end

  def accepts?(_), do: false

  @impl Rindle.Probe
  @spec probe(Path.t()) :: {:ok, Rindle.Probe.result()} | {:error, term()}
  def probe(source) when is_binary(source) do
    with {:ok, raw} <- Ffprobe.probe(source) do
      {:ok, reshape(raw)}
    end
  end

  defp reshape(%{"format" => format, "streams" => streams})
       when is_map(format) and is_list(streams) do
    video_stream = Enum.find(streams, &(&1["codec_type"] == "video"))
    audio_stream = Enum.find(streams, &(&1["codec_type"] == "audio"))

    %{
      kind: classify_kind(video_stream, audio_stream),
      has_video_track: not is_nil(video_stream),
      has_audio_track: not is_nil(audio_stream),
      duration_ms: parse_duration_ms(format),
      metadata: MetadataSanitizer.sanitize(raw_metadata(format, streams))
    }
    |> maybe_put_dimensions(video_stream)
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp classify_kind(nil, _audio_stream), do: :audio
  defp classify_kind(_video_stream, _audio_stream), do: :video

  defp parse_duration_ms(%{"duration" => duration}) when is_binary(duration) do
    case Float.parse(duration) do
      {seconds, _rest} -> trunc(seconds * 1000)
      :error -> nil
    end
  end

  defp parse_duration_ms(_format), do: nil

  defp maybe_put_dimensions(result, %{"width" => width, "height" => height})
       when is_integer(width) and is_integer(height) do
    Map.merge(result, %{width: width, height: height})
  end

  defp maybe_put_dimensions(result, _stream), do: result

  defp raw_metadata(format, streams) do
    %{
      "format" => Map.get(format, "tags", %{}),
      "streams" => Enum.map(streams, &Map.get(&1, "tags", %{}))
    }
  end
end
