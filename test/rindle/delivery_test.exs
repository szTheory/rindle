defmodule Rindle.DeliveryTest do
  use Rindle.DataCase, async: true

  import Mox
  alias Rindle.Storage.Capabilities

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

    expect(Rindle.AuthorizerMock, :authorize, fn nil,
                                                 :deliver,
                                                 %{
                                                   profile: PrivateProfile,
                                                   key: ^key,
                                                   mode: :private
                                                 } ->
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

    expect(Rindle.AuthorizerMock, :authorize, fn nil,
                                                 :deliver,
                                                 %{
                                                   profile: PublicProfile,
                                                   key: ^key,
                                                   mode: :public
                                                 } ->
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

    expect(Rindle.AuthorizerMock, :authorize, fn nil,
                                                 :deliver,
                                                 %{
                                                   profile: UnsupportedProfile,
                                                   key: ^key,
                                                   mode: :private
                                                 } ->
      :ok
    end)

    assert {:error, {:delivery_unsupported, :signed_url}} =
             Rindle.Delivery.url(UnsupportedProfile, key)
  end

  test "shared delivery capability helper preserves tagged unsupported tuples" do
    assert {:error, {:delivery_unsupported, :signed_url}} =
             Capabilities.require_delivery(Rindle.Storage.Local, :signed_url)
  end

  test "variant_url/4 falls back to original for non-ready variants" do
    asset = %{storage_key: "assets/asset-1/original.jpg"}
    variant = %{state: "processing", storage_key: "assets/asset-1/thumb.jpg"}

    expect(Rindle.AuthorizerMock, :authorize, fn nil,
                                                 :deliver,
                                                 %{
                                                   profile: PublicProfile,
                                                   key: "assets/asset-1/original.jpg",
                                                   mode: :public
                                                 } ->
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

    expect(Rindle.AuthorizerMock, :authorize, fn nil,
                                                 :deliver,
                                                 %{
                                                   profile: PublicProfile,
                                                   key: "assets/asset-1/original.jpg",
                                                   mode: :public
                                                 } ->
      :ok
    end)

    expect(Rindle.StorageMock, :url, fn "assets/asset-1/original.jpg", _opts ->
      {:ok, "https://public.example/assets/asset-1/original.jpg"}
    end)

    expect(Rindle.AuthorizerMock, :authorize, fn nil,
                                                 :deliver,
                                                 %{
                                                   profile: PublicProfile,
                                                   key: "assets/asset-1/thumb.jpg",
                                                   mode: :public
                                                 } ->
      :ok
    end)

    expect(Rindle.StorageMock, :url, fn "assets/asset-1/thumb.jpg", _opts ->
      {:ok, "https://public.example/assets/asset-1/thumb.jpg"}
    end)

    assert {:ok, url} =
             Rindle.Delivery.variant_url(PublicProfile, asset, variant, stale_mode: :serve_stale)

    assert url == "https://public.example/assets/asset-1/thumb.jpg"
  end

  test "Rindle.url/2 routes through the delivery layer" do
    key = "assets/asset-1/original.jpg"

    expect(Rindle.AuthorizerMock, :authorize, fn nil,
                                                 :deliver,
                                                 %{
                                                   profile: PublicProfile,
                                                   key: ^key,
                                                   mode: :public
                                                 } ->
      :ok
    end)

    expect(Rindle.StorageMock, :url, fn ^key, _opts ->
      {:ok, "https://public.example/#{key}"}
    end)

    assert {:ok, url} = Rindle.url(PublicProfile, key)
    assert url == "https://public.example/#{key}"
  end

  describe "streaming_url/3" do
    test "wraps signed delivery with progressive shape and default mime" do
      key = "assets/asset-1/video.mp4"

      expect(Rindle.AuthorizerMock, :authorize, fn nil,
                                                   :deliver,
                                                   %{
                                                     profile: PrivateProfile,
                                                     key: ^key,
                                                     mode: :private
                                                   } ->
        :ok
      end)

      expect(Rindle.StorageMock, :capabilities, fn -> [:signed_url] end)

      expect(Rindle.StorageMock, :url, fn ^key, opts ->
        assert Keyword.get(opts, :expires_in) == 120
        {:ok, "https://signed.example/#{key}?ttl=120"}
      end)

      assert {:ok, %{url: url, kind: :progressive, mime: "video/mp4"}} =
               Rindle.Delivery.streaming_url(PrivateProfile, key)

      assert url == "https://signed.example/#{key}?ttl=120"
    end

    test "preserves request-time expires_in override and explicit mime" do
      key = "assets/asset-1/video.mp4"

      expect(Rindle.AuthorizerMock, :authorize, fn :viewer,
                                                   :deliver,
                                                   %{
                                                     profile: PrivateProfile,
                                                     key: ^key,
                                                     mode: :private
                                                   } ->
        :ok
      end)

      expect(Rindle.StorageMock, :capabilities, fn -> [:signed_url] end)

      expect(Rindle.StorageMock, :url, fn ^key, opts ->
        assert Keyword.get(opts, :expires_in) == 45
        {:ok, "https://signed.example/#{key}?ttl=45"}
      end)

      assert {:ok, %{url: url, kind: :progressive, mime: "audio/mpeg"}} =
               Rindle.Delivery.streaming_url(
                 PrivateProfile,
                 key,
                 actor: :viewer,
                 expires_in: 45,
                 mime: "audio/mpeg"
               )

      assert url == "https://signed.example/#{key}?ttl=45"
    end

    test "returns the same tagged delivery errors as url/3" do
      key = "assets/asset-1/video.mp4"

      expect(Rindle.AuthorizerMock, :authorize, fn _actor, :deliver, _subject -> :ok end)

      assert {:error, {:delivery_unsupported, :signed_url}} =
               Rindle.Delivery.streaming_url(UnsupportedProfile, key)
    end

    test "reserved provider namespace is callback-only" do
      behaviours =
        Rindle.Streaming.Provider.module_info(:attributes)
        |> Keyword.get(:behaviour, [])

      assert behaviours == []
      assert function_exported?(Rindle.Streaming.Provider, :behaviour_info, 1)
      assert {:streaming_url, 3} in Rindle.Streaming.Provider.behaviour_info(:callbacks)
      assert {:capabilities, 0} in Rindle.Streaming.Provider.behaviour_info(:callbacks)
    end
  end

  describe "telemetry emission (Plan 05-01 / TEL-04)" do
    setup do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rindle, :delivery, :signed],
          [:rindle, :delivery, :streaming, :resolved]
        ])

      on_exit(fn -> :telemetry.detach(ref) end)
      {:ok, ref: ref}
    end

    test "url/3 emits [:rindle, :delivery, :signed] inside with success arm (private mode)",
         %{ref: ref} do
      key = "assets/asset-1/original.jpg"

      expect(Rindle.AuthorizerMock, :authorize, fn nil,
                                                   :deliver,
                                                   %{
                                                     profile: PrivateProfile,
                                                     key: ^key,
                                                     mode: :private
                                                   } ->
        :ok
      end)

      expect(Rindle.StorageMock, :capabilities, fn -> [:signed_url] end)

      expect(Rindle.StorageMock, :url, fn ^key, _opts ->
        {:ok, "https://signed.example/#{key}?ttl=120"}
      end)

      assert {:ok, _url} = Rindle.Delivery.url(PrivateProfile, key)

      assert_received {[:rindle, :delivery, :signed], ^ref, measurements, metadata}
      assert is_integer(measurements.system_time)
      assert metadata.profile == PrivateProfile
      assert metadata.adapter == PrivateProfile.storage_adapter()
      assert metadata.mode == :private
    end

    test "url/3 emits [:rindle, :delivery, :signed] for public mode", %{ref: ref} do
      key = "assets/asset-1/original.jpg"

      expect(Rindle.AuthorizerMock, :authorize, fn nil,
                                                   :deliver,
                                                   %{
                                                     profile: PublicProfile,
                                                     key: ^key,
                                                     mode: :public
                                                   } ->
        :ok
      end)

      expect(Rindle.StorageMock, :url, fn ^key, _opts ->
        {:ok, "https://public.example/#{key}"}
      end)

      assert {:ok, _url} = Rindle.Delivery.url(PublicProfile, key)

      assert_received {[:rindle, :delivery, :signed], ^ref, _measurements, metadata}
      assert metadata.profile == PublicProfile
      assert metadata.mode == :public
    end

    test "url/3 does NOT emit when authorize_delivery/4 returns {:error, _}", %{ref: ref} do
      key = "assets/asset-1/original.jpg"

      expect(Rindle.AuthorizerMock, :authorize, fn _actor, :deliver, _subject ->
        {:error, :forbidden}
      end)

      assert {:error, :forbidden} = Rindle.Delivery.url(PrivateProfile, key)
      refute_received {[:rindle, :delivery, :signed], ^ref, _measurements, _metadata}
    end

    test "url/3 does NOT emit when storage adapter lacks :signed_url capability", %{ref: ref} do
      key = "assets/asset-1/original.jpg"

      expect(Rindle.AuthorizerMock, :authorize, fn _actor, :deliver, _subject -> :ok end)

      assert {:error, {:delivery_unsupported, :signed_url}} =
               Rindle.Delivery.url(UnsupportedProfile, key)

      refute_received {[:rindle, :delivery, :signed], ^ref, _measurements, _metadata}
    end

    test "streaming_url/3 emits [:rindle, :delivery, :streaming, :resolved] on success",
         %{ref: ref} do
      key = "assets/asset-1/video.mp4"

      expect(Rindle.AuthorizerMock, :authorize, fn nil,
                                                   :deliver,
                                                   %{
                                                     profile: PublicProfile,
                                                     key: ^key,
                                                     mode: :public
                                                   } ->
        :ok
      end)

      expect(Rindle.StorageMock, :url, fn ^key, _opts ->
        {:ok, "https://public.example/#{key}"}
      end)

      assert {:ok, %{url: _url, kind: :progressive, mime: "video/mp4"}} =
               Rindle.Delivery.streaming_url(PublicProfile, key)

      assert_received {[:rindle, :delivery, :streaming, :resolved], ^ref, measurements, metadata}
      assert is_integer(measurements.system_time)
      assert metadata.profile == PublicProfile
      assert metadata.adapter == PublicProfile.storage_adapter()
      assert metadata.mode == :public
      assert metadata.kind == :progressive
      assert metadata.mime == "video/mp4"
    end

    test "streaming_url/3 does NOT emit when url resolution fails", %{ref: ref} do
      key = "assets/asset-1/video.mp4"

      expect(Rindle.AuthorizerMock, :authorize, fn _actor, :deliver, _subject ->
        {:error, :forbidden}
      end)

      assert {:error, :forbidden} = Rindle.Delivery.streaming_url(PrivateProfile, key)
      refute_received {[:rindle, :delivery, :streaming, :resolved], ^ref, _, _}
    end
  end

  describe "content disposition normalization" do
    test "sanitizes explicit filename and disposition for private delivery" do
      key = "assets/asset-1/original.jpg"

      expect(Rindle.AuthorizerMock, :authorize, fn nil,
                                                   :deliver,
                                                   %{
                                                     profile: PrivateProfile,
                                                     key: ^key,
                                                     mode: :private
                                                   } ->
        :ok
      end)

      expect(Rindle.StorageMock, :capabilities, fn -> [:signed_url] end)

      expect(Rindle.StorageMock, :url, fn ^key, opts ->
        assert Keyword.get(opts, :expires_in) == 120

        assert Keyword.get(opts, :content_disposition) == %{
                 type: :attachment,
                 filename: "my_resume_.mp4",
                 filename_star: "UTF-8''my_resume_.mp4"
               }

        {:ok, "https://signed.example/#{key}?ttl=120"}
      end)

      assert {:ok, _url} =
               Rindle.Delivery.url(
                 PrivateProfile,
                 key,
                 filename: "../my resume?.mp4",
                 disposition: :attachment
               )
    end

    test "omits content disposition when caller does not request it" do
      key = "assets/asset-1/original.jpg"

      expect(Rindle.AuthorizerMock, :authorize, fn nil,
                                                   :deliver,
                                                   %{
                                                     profile: PrivateProfile,
                                                     key: ^key,
                                                     mode: :private
                                                   } ->
        :ok
      end)

      expect(Rindle.StorageMock, :capabilities, fn -> [:signed_url] end)

      expect(Rindle.StorageMock, :url, fn ^key, opts ->
        refute Keyword.has_key?(opts, :content_disposition)
        {:ok, "https://signed.example/#{key}?ttl=120"}
      end)

      assert {:ok, _url} = Rindle.Delivery.url(PrivateProfile, key)
    end

    test "defaults attachment filename from sanitized key basename when caller omits one" do
      key = "uploads/unsafe path/my clip?.mp4"

      expect(Rindle.AuthorizerMock, :authorize, fn nil,
                                                   :deliver,
                                                   %{
                                                     profile: PrivateProfile,
                                                     key: ^key,
                                                     mode: :private
                                                   } ->
        :ok
      end)

      expect(Rindle.StorageMock, :capabilities, fn -> [:signed_url] end)

      expect(Rindle.StorageMock, :url, fn ^key, opts ->
        assert Keyword.get(opts, :content_disposition) == %{
                 type: :attachment,
                 filename: "my_clip_.mp4",
                 filename_star: "UTF-8''my_clip_.mp4"
               }

        {:ok, "https://signed.example/#{key}?ttl=120"}
      end)

      assert {:ok, _url} =
               Rindle.Delivery.url(PrivateProfile, key, disposition: :attachment)
    end
  end
end
