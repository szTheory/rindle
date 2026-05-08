if Code.ensure_loaded?(Phoenix.HTML) do
  defmodule Rindle.HTML do
    @moduledoc """
    Phoenix template helpers for responsive media markup.

    The helper is intentionally thin: callers choose the explicit variant order,
    and the helper delegates delivery URL resolution to Rindle.Delivery.
    """

    import Phoenix.HTML, only: [raw: 1, html_escape: 1, safe_to_string: 1]

    @doc """
    Renders a `<picture>` element with `<source>` entries for each ready variant
    and an `<img>` fallback to the original asset.

    Variant order in `:variants` is preserved as the source order rendered into
    the markup. Stale or non-ready variants are skipped — the fallback `<img>`
    URL always resolves to the original asset.

    ## Options

      * `:variants` — list of `{name, media_query}` tuples, `%{name: ..., media: ...}`
        maps, or bare atom variant names. Variants are rendered in the order given.
      * `:placeholder` — string to use as the `src` attribute when no variant is
        ready and the asset has no `:storage_key`.
      * Any other key is rendered as a literal HTML attribute on the `<img>` tag.

    ## Example

        <%= Rindle.HTML.picture_tag(MyApp.AvatarProfile, asset,
              variants: [{:thumb, "(max-width: 480px)"}, {:large, nil}],
              alt: "User avatar"
            ) %>
    """
    @spec picture_tag(module(), map(), keyword()) :: Phoenix.HTML.safe()
    def picture_tag(profile, asset, opts \\ []) do
      variant_specs = Keyword.get(opts, :variants, [])
      placeholder = Keyword.get(opts, :placeholder)

      html_attrs =
        opts
        |> Keyword.drop([:variants, :placeholder])
        |> Enum.sort_by(fn {k, _} -> to_string(k) end)

      sources =
        variant_specs
        |> Enum.flat_map(&build_source(&1, profile, asset, opts))

      fallback_src = fallback_source(profile, asset, placeholder, opts)

      [
        "<picture>",
        sources,
        "<img",
        attrs_markup(html_attrs),
        " src=\"",
        escape(fallback_src),
        "\">",
        "</picture>"
      ]
      |> raw()
    end

    @doc """
    Renders a `<video>` element with `<source>` entries for each ready variant
    and an original-asset `src` fallback.

    Variant order in `:variants` is preserved as the source order rendered into
    the markup. Stale or non-ready variants are skipped, and the root `<video>`
    always falls back to the original asset URL so callers do not need to branch
    on variant readiness.

    ## Options

      * `:variants` — list of variant names to render in the order given.
      * `:poster` — a ready image variant atom or literal poster URL string.
      * `:tracks` — reserved for future caption/subtitle support; accepted but
        not rendered in v1.4.
      * Any other key is rendered as a literal HTML attribute on the `<video>`
        tag. `preload` defaults to `"metadata"`.
    """
    @spec video_tag(module(), map(), keyword()) :: Phoenix.HTML.safe()
    def video_tag(profile, asset, opts \\ []) do
      opts = Keyword.put_new(opts, :preload, "metadata")
      media_tag("video", profile, asset, opts, &resolve_video_html_attrs/3)
    end

    @doc """
    Renders an `<audio>` element with `<source>` entries for each ready variant
    and an original-asset `src` fallback.

    Variant order in `:variants` is preserved as the source order rendered into
    the markup. Stale or non-ready variants are skipped, and the root `<audio>`
    always falls back to the original asset URL so callers do not need to branch
    on variant readiness.

    ## Options

      * `:variants` — list of variant names to render in the order given.
      * `:tracks` — reserved for future caption/subtitle support; accepted but
        not rendered in v1.4.
      * Any other key is rendered as a literal HTML attribute on the `<audio>`
        tag. `controls` defaults to `true`; `preload` defaults to `"metadata"`.
    """
    @spec audio_tag(module(), map(), keyword()) :: Phoenix.HTML.safe()
    def audio_tag(profile, asset, opts \\ []) do
      opts =
        opts
        |> Keyword.put_new(:controls, true)
        |> Keyword.put_new(:preload, "metadata")

      media_tag("audio", profile, asset, opts, &resolve_audio_html_attrs/3)
    end

    defp media_tag(tag_name, profile, asset, opts, html_attrs_resolver) do
      variant_specs = Keyword.get(opts, :variants, [])

      sources =
        variant_specs
        |> Enum.flat_map(&build_media_source(&1, profile, asset, opts))

      fallback_src = media_fallback_source(profile, asset, opts)
      html_attrs = html_attrs_resolver.(profile, asset, opts)

      [
        "<",
        tag_name,
        attrs_markup(html_attrs),
        " src=\"",
        escape(fallback_src),
        "\">",
        sources,
        "</",
        tag_name,
        ">"
      ]
      |> raw()
    end

    defp build_source(spec, profile, asset, opts) do
      with {:ok, name, media} <- resolve_variant_spec(spec),
           variant when not is_nil(variant) <- ready_variant(asset, name),
           {:ok, url} <- Rindle.Delivery.variant_url(profile, asset, variant, opts) do
        ["<source", media_attr(media), " srcset=\"", escape(url), "\">"]
      else
        _ -> []
      end
    end

    defp build_media_source(spec, profile, asset, opts) do
      with {:ok, name, _media} <- resolve_variant_spec(spec),
           variant when not is_nil(variant) <- ready_variant(asset, name),
           {:ok, %{url: url, mime: mime}} <-
             streaming_source(profile, variant, opts, asset_content_type(asset)) do
        ["<source src=\"", escape(url), "\"", source_type_attr(mime), ">"]
      else
        _ -> []
      end
    end

    defp resolve_variant_spec({name, media}) when is_atom(name), do: {:ok, name, media}

    defp resolve_variant_spec(%{name: name, media: media}) when is_atom(name),
      do: {:ok, name, media}

    defp resolve_variant_spec(%{name: name}) when is_atom(name), do: {:ok, name, nil}
    defp resolve_variant_spec(name) when is_atom(name), do: {:ok, name, nil}
    defp resolve_variant_spec(_), do: :error

    defp ready_variant(%{variants: variants}, name) when is_list(variants) do
      Enum.find(variants, fn variant ->
        variant_name(variant) == Atom.to_string(name) and variant_state(variant) == "ready"
      end)
    end

    defp ready_variant(_asset, _name), do: nil

    defp fallback_source(profile, asset, placeholder, opts) do
      if is_binary(placeholder) and placeholder != "" do
        placeholder
      else
        case asset_source_url(profile, asset, opts) do
          {:ok, url} -> url
          {:error, _reason} -> ""
        end
      end
    end

    defp asset_source_url(profile, %{storage_key: storage_key}, opts)
         when is_binary(storage_key) do
      Rindle.Delivery.url(profile, storage_key, opts)
    end

    defp asset_source_url(_profile, _asset, _opts), do: {:error, :missing_storage_key}

    defp media_fallback_source(profile, asset, opts) do
      case streaming_source(profile, asset, opts, asset_content_type(asset)) do
        {:ok, %{url: url}} -> url
        {:error, _reason} -> ""
      end
    end

    defp streaming_source(profile, %{storage_key: storage_key} = source, opts, fallback_mime)
         when is_binary(storage_key) do
      streaming_opts =
        opts
        |> Keyword.put(
          :mime,
          asset_content_type(source) || fallback_mime || default_streaming_mime(source)
        )

      Rindle.Delivery.streaming_url(profile, source, streaming_opts)
    end

    defp streaming_source(_profile, _source, _opts, _fallback_mime),
      do: {:error, :missing_storage_key}

    defp resolve_video_html_attrs(profile, asset, opts) do
      html_attrs =
        opts
        |> Keyword.drop([:variants, :poster, :tracks])
        |> Enum.sort_by(fn {k, _} -> to_string(k) end)

      case resolve_poster(profile, asset, opts) do
        nil -> html_attrs
        poster_url -> Keyword.put(html_attrs, :poster, poster_url)
      end
    end

    defp resolve_audio_html_attrs(_profile, _asset, opts) do
      opts
      |> Keyword.drop([:variants, :tracks])
      |> Enum.sort_by(fn {k, _} -> to_string(k) end)
    end

    defp resolve_poster(profile, asset, opts) do
      case Keyword.get(opts, :poster) do
        poster when is_binary(poster) and poster != "" ->
          poster

        poster_name when is_atom(poster_name) ->
          with variant when not is_nil(variant) <- ready_variant(asset, poster_name),
               {:ok, url} <- Rindle.Delivery.variant_url(profile, asset, variant, opts) do
            url
          else
            _ -> nil
          end

        _ ->
          nil
      end
    end

    defp asset_content_type(%{content_type: content_type}) when is_binary(content_type),
      do: content_type

    defp asset_content_type(_asset), do: nil

    defp default_streaming_mime(%{kind: "audio"}), do: "audio/mpeg"
    defp default_streaming_mime(%{kind: "video"}), do: "video/mp4"
    defp default_streaming_mime(%{output_kind: "audio"}), do: "audio/mpeg"
    defp default_streaming_mime(%{output_kind: "video"}), do: "video/mp4"
    defp default_streaming_mime(_source), do: "video/mp4"

    defp variant_name(%{name: name}) when is_atom(name), do: Atom.to_string(name)
    defp variant_name(%{name: name}) when is_binary(name), do: name

    defp variant_state(%{state: state}), do: state

    defp media_attr(nil), do: ""
    defp media_attr(media), do: " media=\"" <> escape(media) <> "\""

    defp source_type_attr(nil), do: ""
    defp source_type_attr(mime), do: " type=\"" <> escape(mime) <> "\""

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
