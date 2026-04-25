defmodule Rindle.Processor.Image do
  @moduledoc """
  Image processor adapter using the Image library (powered by libvips/Vix).
  """

  @behaviour Rindle.Processor

  @doc """
  Processes an image from source_path to destination_path according to variant_spec.
  """
  def process(source_path, variant_spec, destination_path) do
    width = Map.get(variant_spec, :width)
    height = Map.get(variant_spec, :height)
    mode = Map.get(variant_spec, :mode, :fit)
    format = Map.get(variant_spec, :format)
    quality = Map.get(variant_spec, :quality, 80)

    with {:ok, image} <- Image.open(source_path),
         {:ok, processed} <- apply_resize(image, width, height, mode),
         {:ok, _written} <- write_image(processed, destination_path, format, quality) do
      {:ok, destination_path}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp apply_resize(image, width, height, :crop) do
    # thumbnail/3 handles cropping if dimensions are provided
    Image.thumbnail(image, "#{width}x#{height}", crop: :center)
  end

  defp apply_resize(image, width, height, :fit) do
    Image.thumbnail(image, "#{width}x#{height}", resize: :force)
  end

  defp apply_resize(image, width, height, :fill) do
    # Fill often implies resize then crop to fill exactly
    # For now, let's use thumbnail which is close
    Image.thumbnail(image, "#{width}x#{height}", crop: :center)
  end

  defp apply_resize(image, width, _height, _mode) when not is_nil(width) do
    Image.thumbnail(image, width)
  end

  defp apply_resize(image, _width, _height, _mode) do
    {:ok, image}
  end

  defp write_image(image, path, format, quality) do
    write_opts = [quality: quality]

    case normalize_format(format || Path.extname(path)) do
      :jpg -> Image.write(image, path, Keyword.put(write_opts, :suffix, ".jpg"))
      :png -> Image.write(image, path, Keyword.put(write_opts, :suffix, ".png"))
      :webp -> Image.write(image, path, Keyword.put(write_opts, :suffix, ".webp"))
      _ -> Image.write(image, path)
    end
  end

  defp normalize_format(format) when is_atom(format), do: format

  defp normalize_format(format) when is_binary(format) do
    format
    |> String.downcase()
    |> String.replace(".", "")
    |> case do
      "jpeg" -> :jpg
      "jpg" -> :jpg
      "png" -> :png
      "webp" -> :webp
      _ -> :unknown
    end
  end

  defp normalize_format(_), do: :unknown
end
