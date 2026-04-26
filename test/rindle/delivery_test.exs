defmodule Rindle.DeliveryTest do
  use Rindle.DataCase, async: true

  import Mox

  setup :set_mox_from_context
  setup :verify_on_exit!

  defmodule PrivateProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [thumb: [mode: :fit, width: 320]],
      allow_mime: ["image/jpeg"],
      delivery: [authorizer: Rindle.AuthorizerMock, signed_url_ttl_seconds: 120]
  end

  defmodule PublicProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [thumb: [mode: :fit, width: 320]],
      allow_mime: ["image/jpeg"],
      delivery: [public: true, authorizer: Rindle.AuthorizerMock]
  end

  defmodule UnsupportedProfile do
    use Rindle.Profile,
      storage: Rindle.Storage.Local,
      variants: [thumb: [mode: :fit, width: 320]],
      allow_mime: ["image/jpeg"],
      delivery: [authorizer: Rindle.AuthorizerMock]
  end

  test "Rindle.url/2 delegates delivery policy for private assets" do
    key = "assets/asset-1/original.jpg"

    expect(Rindle.AuthorizerMock, :authorize, fn nil, :deliver, %{profile: PrivateProfile, key: ^key, mode: :private} ->
      :ok
    end)

    expect(Rindle.StorageMock, :capabilities, fn ->
      [:signed_url]
    end)

    expect(Rindle.StorageMock, :url, fn ^key, opts ->
      assert Keyword.get(opts, :expires_in) == 120
      {:ok, "https://signed.example/#{key}?ttl=120"}
    end)

    assert {:ok, url} = Rindle.url(PrivateProfile, key)
    assert url == "https://signed.example/#{key}?ttl=120"
  end

  test "public delivery stays unsigned and still authorizes" do
    key = "assets/asset-1/original.jpg"

    expect(Rindle.AuthorizerMock, :authorize, fn nil, :deliver, %{profile: PublicProfile, key: ^key, mode: :public} ->
      :ok
    end)

    expect(Rindle.StorageMock, :url, fn ^key, opts ->
      refute Keyword.has_key?(opts, :expires_in)
      {:ok, "https://public.example/#{key}"}
    end)

    assert {:ok, url} = Rindle.url(PublicProfile, key)
    assert url == "https://public.example/#{key}"
  end

  test "private delivery without signed capability is rejected" do
    key = "assets/asset-1/original.jpg"

    expect(Rindle.AuthorizerMock, :authorize, fn nil, :deliver, %{profile: UnsupportedProfile, key: ^key, mode: :private} ->
      :ok
    end)

    assert {:error, {:delivery_unsupported, :signed_url}} = Rindle.Delivery.url(UnsupportedProfile, key)
  end

  test "variant_url/4 falls back to original for non-ready variants" do
    asset = %{storage_key: "assets/asset-1/original.jpg"}
    variant = %{state: "processing", storage_key: "assets/asset-1/thumb.jpg"}

    expect(Rindle.AuthorizerMock, :authorize, fn nil, :deliver, %{profile: PublicProfile, key: "assets/asset-1/original.jpg", mode: :public} ->
      :ok
    end)

    expect(Rindle.StorageMock, :url, fn "assets/asset-1/original.jpg", _opts ->
      {:ok, "https://public.example/assets/asset-1/original.jpg"}
    end)

    assert {:ok, url} = Rindle.Delivery.variant_url(PublicProfile, asset, variant)
    assert url == "https://public.example/assets/asset-1/original.jpg"
  end

  test "variant_url/4 can serve stale variants when explicitly allowed" do
    asset = %{storage_key: "assets/asset-1/original.jpg"}
    variant = %{state: "stale", storage_key: "assets/asset-1/thumb.jpg"}

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

    assert {:ok, url} = Rindle.Delivery.variant_url(PublicProfile, asset, variant, stale_mode: :serve_stale)
    assert url == "https://public.example/assets/asset-1/thumb.jpg"
  end

  test "Rindle.url/2 routes through the delivery layer" do
    key = "assets/asset-1/original.jpg"

    expect(Rindle.AuthorizerMock, :authorize, fn nil, :deliver, %{profile: PublicProfile, key: ^key, mode: :public} ->
      :ok
    end)

    expect(Rindle.StorageMock, :url, fn ^key, _opts ->
      {:ok, "https://public.example/#{key}"}
    end)

    assert {:ok, url} = Rindle.url(PublicProfile, key)
    assert url == "https://public.example/#{key}"
  end
end
