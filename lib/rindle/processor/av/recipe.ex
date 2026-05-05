defmodule Rindle.Processor.AV.Recipe do
  @moduledoc false

  @video_overrides ~w(faststart)a
  @audio_overrides ~w(normalize two_pass channels)a
  @waveform_overrides ~w(sample_rate length channels)a

  @video_presets %{
    web_720p: %{
      kind: :video,
      output_kind: :video,
      preset: :web_720p,
      container: :mp4,
      video_codec: :h264,
      audio_codec: :aac,
      width: 1280,
      height: 720,
      crf: 23,
      audio_bitrate_kbps: 128,
      faststart: true
    },
    web_480p: %{
      kind: :video,
      output_kind: :video,
      preset: :web_480p,
      container: :mp4,
      video_codec: :h264,
      audio_codec: :aac,
      width: 854,
      height: 480,
      crf: 23,
      audio_bitrate_kbps: 128,
      faststart: true
    }
  }

  @audio_presets %{
    m4a_128k: %{
      kind: :audio,
      output_kind: :audio,
      preset: :m4a_128k,
      container: :m4a,
      audio_codec: :aac,
      audio_bitrate_kbps: 128,
      normalize: false,
      two_pass: false
    },
    mp3_128k: %{
      kind: :audio,
      output_kind: :audio,
      preset: :mp3_128k,
      container: :mp3,
      audio_codec: :mp3,
      audio_bitrate_kbps: 128,
      normalize: false,
      two_pass: false
    }
  }

  @waveform_presets %{
    overview: %{
      kind: :waveform,
      output_kind: :waveform,
      preset: :overview,
      format: :json,
      length: 1000
    }
  }

  @type normalized_recipe :: %{required(atom()) => term()}

  @spec normalize(map()) :: {:ok, normalized_recipe()} | {:error, term()}
  def normalize(spec) when is_map(spec) do
    kind = Map.get(spec, :kind)

    case {kind, Map.get(spec, :preset)} do
      {:video, preset} ->
        normalize_with_preset(spec, preset, @video_presets, @video_overrides)

      {:audio, preset} ->
        normalize_with_preset(spec, preset, @audio_presets, @audio_overrides)

      {:waveform, preset} ->
        normalize_with_preset(spec, preset, @waveform_presets, @waveform_overrides)

      {:image, _preset} ->
        {:ok, spec}

      {nil, _preset} ->
        {:ok, spec}

      {unsupported_kind, _preset} ->
        {:error, {:unsupported_kind, unsupported_kind}}
    end
  end

  def normalize(_spec), do: {:error, :invalid_variant_spec}

  defp normalize_with_preset(spec, preset, preset_map, allowed_overrides) do
    with {:ok, base} <- fetch_preset(preset, preset_map),
         :ok <- validate_keys(spec, allowed_overrides) do
      merged =
        base
        |> Map.merge(Map.take(spec, allowed_overrides))
        |> reject_nil_values()

      {:ok, merged}
    end
  end

  defp fetch_preset(preset, preset_map) do
    case Map.fetch(preset_map, preset) do
      {:ok, normalized} -> {:ok, normalized}
      :error -> {:error, {:unknown_preset, preset}}
    end
  end

  defp validate_keys(spec, allowed_overrides) do
    allowed_keys = [:kind, :preset | allowed_overrides]

    unsupported =
      spec
      |> Map.keys()
      |> Enum.reject(&(&1 in allowed_keys))
      |> Enum.sort()

    case unsupported do
      [] -> :ok
      keys -> {:error, {:unsupported_keys, keys}}
    end
  end

  defp reject_nil_values(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end
end
