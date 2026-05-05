defmodule Rindle.Probe.Image do
  @moduledoc """
  Image probe adapter using the [Image](https://hex.pm/packages/image) library
  (powered by libvips/Vix). Symmetric with `Rindle.Processor.Image`.

  Returns dimensions and the `:image` kind discriminator. No FFmpeg required.
  """

  @behaviour Rindle.Probe

  @image_mime_prefixes ["image/"]

  @impl Rindle.Probe
  @spec accepts?(term()) :: boolean()
  def accepts?(content_type) when is_binary(content_type),
    do: Enum.any?(@image_mime_prefixes, &String.starts_with?(content_type, &1))

  def accepts?(_), do: false

  @impl Rindle.Probe
  @spec probe(Path.t()) :: {:ok, Rindle.Probe.result()} | {:error, term()}
  def probe(source) when is_binary(source) do
    with {:ok, image} <- Image.open(source) do
      {:ok,
       %{
         kind: :image,
         width: Image.width(image),
         height: Image.height(image)
       }}
    end
  end
end
