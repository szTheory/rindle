defmodule Rindle.Processor.AV do
  @moduledoc """
  Public AV processor boundary for preset-led video, audio, and waveform recipes.
  """

  @behaviour Rindle.Processor

  alias Rindle.Processor.AV.Audio
  alias Rindle.Processor.AV.Recipe
  alias Rindle.Processor.AV.Video
  alias Rindle.Processor.Waveform
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
  def normalize(%{kind: :image} = spec), do: normalize_image_recipe(spec)
  def normalize(%{output_kind: :image} = spec), do: normalize_image_recipe(Map.put_new(spec, :kind, :image))
  def normalize(%{kind: :waveform} = spec), do: normalize_waveform_recipe(spec)
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
         {:ok, processor} <- processor_for(normalized) do
      processor.(source_path, normalized, destination_path)
    end
  end

  defp processor_for(%{kind: :video, output_kind: :video}), do: {:ok, &Video.transcode/3}
  defp processor_for(%{kind: :image, output_kind: :image}), do: {:ok, &Video.image_output/3}
  defp processor_for(%{kind: :audio, output_kind: :audio}), do: {:ok, &Audio.transcode/3}
  defp processor_for(%{kind: :waveform, output_kind: :waveform}), do: {:ok, &Waveform.generate/3}
  defp processor_for(spec), do: {:error, {:unsupported_recipe, spec}}

  defp normalize_image_recipe(spec) do
    allowed_keys = [:kind, :output_kind, :preset]

    unsupported =
      spec
      |> Map.keys()
      |> Enum.reject(&(&1 in allowed_keys))
      |> Enum.sort()

    case unsupported do
      [] ->
        image_preset(spec[:preset])

      keys ->
        {:error, {:unsupported_keys, keys}}
    end
  end

  defp image_preset(:video_poster_scene) do
    {:ok,
     %{
       kind: :image,
       output_kind: :image,
       preset: :video_poster_scene,
       format: :jpg,
       scene_threshold: 0.4
     }}
  end

  defp image_preset(:video_thumbnail_strip) do
    {:ok,
     %{
       kind: :image,
       output_kind: :image,
       preset: :video_thumbnail_strip,
       format: :jpg,
       strip_count: 4,
       thumb_width: 160,
       thumb_height: 90,
       fps: 1
     }}
  end

  defp image_preset(preset), do: {:error, {:unknown_preset, preset}}

  defp normalize_waveform_recipe(spec) do
    allowed_keys = [:kind, :preset]

    unsupported =
      spec
      |> Map.keys()
      |> Enum.reject(&(&1 in allowed_keys))
      |> Enum.sort()

    case {spec[:preset], unsupported} do
      {:overview, []} ->
        {:ok,
         %{
           kind: :waveform,
           output_kind: :waveform,
           preset: :overview,
           format: :json,
           length: 1000,
           analysis_sample_rate: 8_000
         }}

      {_preset, [_ | _] = keys} ->
        {:error, {:unsupported_keys, keys}}

      {preset, []} ->
        {:error, {:unknown_preset, preset}}
    end
  end
end
