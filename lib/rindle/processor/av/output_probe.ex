defmodule Rindle.Processor.AV.OutputProbe do
  @moduledoc """
  Post-condition verification for generated AV outputs.
  """

  alias Rindle.Probe.{AVProbe, Image}

  @duration_tolerance_ms 250

  @spec verify!(Path.t(), map(), map()) :: {:ok, map()} | {:error, term()}
  def verify!(path, asset, variant_spec) do
    case output_kind(variant_spec) do
      :video -> verify_av_output(path, asset, variant_spec, :video)
      :audio -> verify_av_output(path, asset, variant_spec, :audio)
      :image -> verify_image_output(path)
      :waveform -> verify_waveform_output(path, variant_spec)
    end
  end

  defp verify_av_output(path, asset, variant_spec, expected_kind) do
    with {:ok, probe} <- AVProbe.probe(path),
         :ok <- ensure_kind(probe, expected_kind),
         :ok <- ensure_duration(asset, probe),
         :ok <- ensure_track_presence(probe, variant_spec) do
      {:ok,
       %{
         duration_ms: probe[:duration_ms],
         width: probe[:width],
         height: probe[:height]
       }}
    end
  end

  defp verify_image_output(path) do
    with {:ok, probe} <- Image.probe(path) do
      {:ok, %{width: probe.width, height: probe.height}}
    end
  end

  defp verify_waveform_output(path, variant_spec) do
    with {:ok, body} <- File.read(path),
         {:ok, payload} <- Jason.decode(body),
         :ok <- ensure_waveform_length(payload, Map.get(variant_spec, :length)) do
      {:ok, %{}}
    end
  end

  defp ensure_kind(%{kind: kind}, kind), do: :ok
  defp ensure_kind(%{kind: actual}, expected), do: {:error, {:output_kind_mismatch, %{expected: expected, actual: actual}}}

  defp ensure_duration(%{duration_ms: expected_ms}, %{duration_ms: actual_ms})
       when is_integer(expected_ms) and is_integer(actual_ms) do
    if abs(actual_ms - expected_ms) <= @duration_tolerance_ms do
      :ok
    else
      {:error, {:output_duration_mismatch, %{expected_ms: expected_ms, actual_ms: actual_ms}}}
    end
  end

  defp ensure_duration(_asset, _probe), do: :ok

  defp ensure_track_presence(%{has_audio_track: true}, %{kind: :video}), do: :ok
  defp ensure_track_presence(%{has_audio_track: true}, %{kind: :audio}), do: :ok
  defp ensure_track_presence(%{has_audio_track: false}, %{kind: :video}), do: {:error, {:output_track_missing, :audio}}
  defp ensure_track_presence(%{has_audio_track: false}, %{kind: :audio}), do: {:error, {:output_track_missing, :audio}}
  defp ensure_track_presence(_probe, _variant_spec), do: :ok

  defp ensure_waveform_length(%{"length" => length}, length) when is_integer(length), do: :ok
  defp ensure_waveform_length(%{"length" => actual}, expected), do: {:error, {:waveform_length_mismatch, %{expected: expected, actual: actual}}}

  defp output_kind(%{output_kind: kind}) when is_atom(kind), do: kind
  defp output_kind(%{kind: kind}) when is_atom(kind), do: kind
  defp output_kind(_variant_spec), do: :image
end
