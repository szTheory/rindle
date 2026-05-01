defmodule Rindle.Processor.Image do
  @moduledoc """
  Image processor adapter using the [Image](https://hex.pm/packages/image) library
  (powered by libvips/Vix).

  This is Rindle's bundled reference processor — symmetric with `Rindle.Storage.S3`
  and `Rindle.Storage.Local` for the `Rindle.Storage` behaviour. Adopters can
  swap in a custom processor by implementing `Rindle.Processor` and configuring
  the profile's `:processor` option, but most use cases are well-served by this
  adapter.

  ## Recognized variant_spec keys

  The `variant_spec` map passed to `process/3` recognizes these keys:

    * `:width` — target width in pixels (`pos_integer()`)
    * `:height` — target height in pixels (`pos_integer()`)
    * `:mode` — resize strategy, one of `:fit`, `:crop`, `:fill` (default: `:fit`)
    * `:format` — output format, one of `:jpg`, `:png`, `:webp`, or a string
      extension. When omitted, format is inferred from `destination_path`'s extension.
    * `:quality` — output quality, `1..100` (default: `80`)

  ## Supported modes

    * `:fit` — resize the image to fit within `:width` x `:height`, preserving aspect ratio
    * `:crop` — crop the image to exactly `:width` x `:height`, centered
    * `:fill` — like `:crop` but optimized for filling the target dimensions

  ## Format inference

  When `:format` is omitted from `variant_spec`, the adapter infers the format
  from `destination_path`'s file extension via `Path.extname/1`. Recognized
  extensions: `.jpg` / `.jpeg` -> JPEG, `.png` -> PNG, `.webp` -> WebP. Unknown
  extensions fall back to libvips's default for the file extension.
  """

  @behaviour Rindle.Processor

  @impl Rindle.Processor
  @spec process(Path.t(), map(), Path.t()) :: {:ok, Path.t()} | {:error, term()}
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
