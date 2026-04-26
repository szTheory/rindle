defmodule Rindle.HTMLTest do
  use Rindle.DataCase, async: true

  import Mox

  setup :set_mox_from_context
  setup :verify_on_exit!

  defmodule PublicProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [thumb: [mode: :fit, width: 320], wide: [mode: :fit, width: 1280]],
      allow_mime: ["image/jpeg"],
      delivery: [public: true, authorizer: Rindle.AuthorizerMock]
  end

  defp asset_with_variants(variants) do
    %Rindle.Domain.MediaAsset{
      storage_key: "assets/asset-1/original.jpg",
      variants: variants
    }
  end

  defp variant(name, state, storage_key) do
    %Rindle.Domain.MediaVariant{name: name, state: state, storage_key: storage_key}
  end

  test "picture_tag/3 renders ready variants in order and passes through html attrs" do
    asset =
      asset_with_variants([
        variant("thumb", "ready", "assets/asset-1/thumb.jpg"),
        variant("wide", "processing", "assets/asset-1/wide.jpg")
      ])

    expect(Rindle.AuthorizerMock, :authorize, fn nil, :deliver, %{profile: PublicProfile, key: "assets/asset-1/original.jpg", mode: :public} ->
      :ok
    end)

    expect(Rindle.StorageMock, :url, fn "assets/asset-1/original.jpg", _opts ->
      {:ok, "https://public.example/assets/asset-1/original.jpg"}
    end)

    expect(Rindle.AuthorizerMock, :authorize, fn nil, :deliver, %{profile: PublicProfile, key: "assets/asset-1/thumb.jpg", mode: :public} ->
      :ok
    end)

    expect(Rindle.StorageMock, :url, fn "assets/asset-1/thumb.jpg", _opts ->
      {:ok, "https://public.example/assets/asset-1/thumb.jpg"}
    end)

    html =
      Rindle.HTML.picture_tag(PublicProfile, asset,
        variants: [thumb: "(max-width: 640px)", wide: "(min-width: 641px)"],
        placeholder: "/images/placeholder.jpg",
        alt: "Avatar",
        class: "rounded",
        loading: "lazy"
      )
      |> Phoenix.HTML.safe_to_string()

    assert html =~ "<picture>"
    assert html =~ "media=\"(max-width: 640px)\""
    assert html =~ "srcset=\"https://public.example/assets/asset-1/thumb.jpg\""
    refute html =~ "wide.jpg"
    assert html =~ "src=\"/images/placeholder.jpg\""
    assert html =~ "alt=\"Avatar\""
    assert html =~ "class=\"rounded\""
    assert html =~ "loading=\"lazy\""
  end

  test "picture_tag/3 falls back to the original when no variant is ready" do
    asset =
      asset_with_variants([
        variant("thumb", "processing", "assets/asset-1/thumb.jpg")
      ])

    expect(Rindle.AuthorizerMock, :authorize, fn nil, :deliver, %{profile: PublicProfile, key: "assets/asset-1/original.jpg", mode: :public} ->
      :ok
    end)

    expect(Rindle.StorageMock, :url, fn "assets/asset-1/original.jpg", _opts ->
      {:ok, "https://public.example/assets/asset-1/original.jpg"}
    end)

    html =
      Rindle.HTML.picture_tag(PublicProfile, asset,
        variants: [thumb: "(max-width: 640px)"],
        alt: "Fallback"
      )
      |> Phoenix.HTML.safe_to_string()

    assert html =~ "src=\"https://public.example/assets/asset-1/original.jpg\""
    refute html =~ "thumb.jpg"
  end
end
