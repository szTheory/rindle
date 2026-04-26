if Code.ensure_loaded?(Phoenix.HTML) do
  defmodule Rindle.HTML do
    @moduledoc """
    Phoenix template helpers for responsive media markup.

    The helper is intentionally thin: callers choose the explicit variant order,
    and the helper delegates delivery URL resolution to Rindle.Delivery.
    """

    import Phoenix.HTML, only: [raw: 1, html_escape: 1, safe_to_string: 1]

    @spec picture_tag(module(), map(), keyword()) :: Phoenix.HTML.safe()
    def picture_tag(profile, asset, opts \\ []) do
      variant_specs = Keyword.get(opts, :variants, [])
      placeholder = Keyword.get(opts, :placeholder)
      html_attrs = opts |> Keyword.drop([:variants, :placeholder]) |> Enum.sort_by(fn {k, _} -> to_string(k) end)

      sources =
        variant_specs
        |> Enum.flat_map(fn spec ->
          case resolve_variant_spec(spec) do
            {:ok, name, media} ->
              case ready_variant(asset, name) do
                nil ->
                  []

                variant ->
                  case Rindle.Delivery.variant_url(profile, asset, variant, opts) do
                    {:ok, url} ->
                      ["<source", media_attr(media), " srcset=\"", escape(url), "\">"]

                    {:error, _reason} ->
                      []
                  end
              end

            :error ->
              []
          end
        end)

      fallback_src = fallback_source(profile, asset, placeholder, opts)

      ["<picture>", sources, "<img", attrs_markup(html_attrs), " src=\"", escape(fallback_src), "\">", "</picture>"]
      |> raw()
    end

    defp resolve_variant_spec({name, media}) when is_atom(name), do: {:ok, name, media}
    defp resolve_variant_spec(%{name: name, media: media}) when is_atom(name), do: {:ok, name, media}
    defp resolve_variant_spec(%{name: name}) when is_atom(name), do: {:ok, name, nil}
    defp resolve_variant_spec(name) when is_atom(name), do: {:ok, name, nil}
    defp resolve_variant_spec(_), do: :error

    defp ready_variant(%{variants: variants}, name) when is_list(variants) do
      Enum.find(variants, fn variant -> variant_name(variant) == Atom.to_string(name) and variant_state(variant) == "ready" end)
    end

    defp ready_variant(_asset, _name), do: nil

    defp fallback_source(profile, asset, placeholder, opts) do
      cond do
        is_binary(placeholder) and placeholder != "" ->
          placeholder

        true ->
          case asset_source_url(profile, asset, opts) do
            {:ok, url} -> url
            {:error, _reason} -> ""
          end
      end
    end

    defp asset_source_url(profile, %{storage_key: storage_key}, opts) when is_binary(storage_key) do
      Rindle.Delivery.url(profile, storage_key, opts)
    end

    defp asset_source_url(_profile, _asset, _opts), do: {:error, :missing_storage_key}

    defp variant_name(%{name: name}) when is_atom(name), do: Atom.to_string(name)
    defp variant_name(%{name: name}) when is_binary(name), do: name

    defp variant_state(%{state: state}), do: state

    defp media_attr(nil), do: ""
    defp media_attr(media), do: " media=\"" <> escape(media) <> "\""

    defp attrs_markup(attrs) do
      attrs
      |> Enum.map(fn {key, value} -> attr_markup(key, value) end)
      |> Enum.join()
    end

    defp attr_markup(_key, value) when value in [nil, false], do: ""
    defp attr_markup(key, true), do: " " <> to_string(key)

    defp attr_markup(key, value) do
      " " <> to_string(key) <> "=\"" <> escape(value) <> "\""
    end

    defp escape(value) do
      value
      |> to_string()
      |> html_escape()
      |> safe_to_string()
    end
  end
end
