defmodule Rindle.HTMLTest do
  use Rindle.DataCase, async: true

  import Mox

  setup :set_mox_from_context
  setup :verify_on_exit!

  alias Rindle.Domain.MediaProviderAsset

  defmodule PublicProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [thumb: [mode: :fit, width: 320], wide: [mode: :fit, width: 1280]],
      allow_mime: ["image/jpeg"],
      delivery: [public: true, authorizer: Rindle.AuthorizerMock]
  end

  defmodule FakeStreamingProvider do
    @behaviour Rindle.Streaming.Provider

    @impl true
    def capabilities, do: [:signed_playback]

    @impl true
    def create_asset(_profile, _source_url, _opts), do: {:error, :not_implemented}

    @impl true
    def get_asset(_provider_asset_id), do: {:error, :not_implemented}

    @impl true
    def delete_asset(_provider_asset_id), do: :ok

    @impl true
    def signed_playback_url(_profile, playback_id, _opts) do
      {:ok,
       %{
         url: "https://stream.example/#{playback_id}.m3u8?token=test-token",
         kind: :hls,
         mime: "application/vnd.apple.mpegurl"
       }}
    end

    @impl true
    def verify_webhook(_raw_body, _headers, _secrets), do: {:error, :provider_webhook_invalid}
  end

  defmodule StreamingProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [web_720p: [kind: :video, preset: :web_720p]],
      allow_mime: ["video/mp4"],
      delivery: [
        public: true,
        streaming: [
          provider: FakeStreamingProvider,
          playback_policy: :signed,
          ingest_mode: :server_push,
          source_variant: :web_720p
        ]
      ]
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

  defp av_asset_with_variants(kind, storage_key, content_type, variants) do
    %Rindle.Domain.MediaAsset{
      kind: to_string(kind),
      storage_key: storage_key,
      content_type: content_type,
      variants: variants
    }
  end

  defp av_variant(name, state, storage_key, output_kind, content_type) do
    %Rindle.Domain.MediaVariant{
      name: name,
      state: state,
      storage_key: storage_key,
      output_kind: to_string(output_kind),
      content_type: content_type
    }
  end

  defp expect_public_delivery(key) when is_binary(key) do
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
  end

  defp expect_public_delivery(keys) when is_list(keys) do
    allowed_keys = MapSet.new(keys)

    expect(Rindle.AuthorizerMock, :authorize, length(keys), fn nil,
                                                               :deliver,
                                                               %{
                                                                 profile: PublicProfile,
                                                                 key: key,
                                                                 mode: :public
                                                               } ->
      assert MapSet.member?(allowed_keys, key)
      :ok
    end)

    expect(Rindle.StorageMock, :url, length(keys), fn key, _opts ->
      assert MapSet.member?(allowed_keys, key)
      {:ok, "https://public.example/#{key}"}
    end)
  end

  test "picture_tag/3 renders ready variants in order and passes through html attrs" do
    asset =
      asset_with_variants([
        variant("thumb", "ready", "assets/asset-1/thumb.jpg"),
        variant("wide", "processing", "assets/asset-1/wide.jpg")
      ])

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

    html =
      Rindle.HTML.picture_tag(PublicProfile, asset,
        variants: [thumb: "(max-width: 640px)"],
        alt: "Fallback"
      )
      |> Phoenix.HTML.safe_to_string()

    assert html =~ "src=\"https://public.example/assets/asset-1/original.jpg\""
    refute html =~ "thumb.jpg"
  end

  test "picture_tag/3 stays on image markup and does not adopt AV playback elements" do
    asset = asset_with_variants([])

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

    html =
      Rindle.HTML.picture_tag(PublicProfile, asset, alt: "Still image")
      |> Phoenix.HTML.safe_to_string()

    assert html =~ "<picture>"
    assert html =~ "<img"
    refute html =~ "<video"
    refute html =~ "<audio"
  end

  test "video_tag/3 preserves variant order, defaults preload, resolves poster variants, and passes attrs through" do
    asset =
      av_asset_with_variants(:video, "assets/asset-1/original.mp4", "video/mp4", [
        av_variant("web_480p", "ready", "assets/asset-1/web-480.mp4", :video, "video/mp4"),
        av_variant("poster", "ready", "assets/asset-1/poster.jpg", :image, "image/jpeg"),
        av_variant("web_720p", "ready", "assets/asset-1/web-720.mp4", :video, "video/mp4")
      ])

    expect_public_delivery([
      "assets/asset-1/original.mp4",
      "assets/asset-1/original.mp4",
      "assets/asset-1/web-720.mp4",
      "assets/asset-1/web-480.mp4",
      "assets/asset-1/poster.jpg"
    ])

    html =
      Rindle.HTML.video_tag(PublicProfile, asset,
        variants: [:web_720p, :web_480p],
        poster: :poster,
        controls: true,
        class: "player"
      )
      |> Phoenix.HTML.safe_to_string()

    assert html =~ "<video"
    assert html =~ "class=\"player\""
    assert html =~ "controls"
    assert html =~ "preload=\"metadata\""
    assert html =~ "poster=\"https://public.example/assets/asset-1/poster.jpg\""
    assert html =~ "src=\"https://public.example/assets/asset-1/original.mp4\""
    assert html =~ "type=\"video/mp4\""

    {first_index, _} = :binary.match(html, "https://public.example/assets/asset-1/web-720.mp4")
    {second_index, _} = :binary.match(html, "https://public.example/assets/asset-1/web-480.mp4")

    assert first_index < second_index
  end

  test "video_tag/3 skips non-ready variants and falls back to the original asset url" do
    asset =
      av_asset_with_variants(:video, "assets/asset-1/original.mp4", "video/mp4", [
        av_variant("web_720p", "processing", "assets/asset-1/web-720.mp4", :video, "video/mp4")
      ])

    expect(Rindle.AuthorizerMock, :authorize, fn nil,
                                                 :deliver,
                                                 %{
                                                   profile: PublicProfile,
                                                   key: "assets/asset-1/original.mp4",
                                                   mode: :public
                                                 } ->
      :ok
    end)

    expect(Rindle.StorageMock, :url, fn "assets/asset-1/original.mp4", _opts ->
      {:ok, "https://public.example/assets/asset-1/original.mp4"}
    end)

    html =
      Rindle.HTML.video_tag(PublicProfile, asset,
        variants: [:web_720p],
        poster: "https://cdn.example/posters/manual.jpg"
      )
      |> Phoenix.HTML.safe_to_string()

    assert html =~ "src=\"https://public.example/assets/asset-1/original.mp4\""
    assert html =~ "poster=\"https://cdn.example/posters/manual.jpg\""
    refute html =~ "web-720.mp4"
  end

  test "audio_tag/3 defaults controls and preload, preserves source order, and accepts reserved tracks" do
    asset =
      av_asset_with_variants(:audio, "assets/asset-1/original.m4a", "audio/mp4", [
        av_variant("podcast_mp3", "ready", "assets/asset-1/podcast.mp3", :audio, "audio/mpeg"),
        av_variant("podcast_m4a", "ready", "assets/asset-1/podcast.m4a", :audio, "audio/mp4")
      ])

    expect_public_delivery([
      "assets/asset-1/original.m4a",
      "assets/asset-1/podcast.mp3",
      "assets/asset-1/podcast.m4a"
    ])

    html =
      Rindle.HTML.audio_tag(PublicProfile, asset,
        variants: [:podcast_mp3, :podcast_m4a],
        tracks: [%{kind: "captions", srclang: "en"}],
        class: "podcast-player"
      )
      |> Phoenix.HTML.safe_to_string()

    assert html =~ "<audio"
    assert html =~ "class=\"podcast-player\""
    assert html =~ "controls"
    assert html =~ "preload=\"metadata\""
    assert html =~ "src=\"https://public.example/assets/asset-1/original.m4a\""
    assert html =~ "type=\"audio/mpeg\""
    assert html =~ "type=\"audio/mp4\""
    refute html =~ "<track"

    {first_index, _} = :binary.match(html, "https://public.example/assets/asset-1/podcast.mp3")
    {second_index, _} = :binary.match(html, "https://public.example/assets/asset-1/podcast.m4a")

    assert first_index < second_index
  end

  test "video_tag/3 uses provider-backed streaming URLs for streaming-enabled profiles" do
    db_asset =
      %Rindle.Domain.MediaAsset{}
      |> Rindle.Domain.MediaAsset.changeset(%{
        state: "ready",
        profile: to_string(StreamingProfile),
        kind: "video",
        storage_key: "assets/asset-1/original.mp4",
        content_type: "video/mp4"
      })
      |> Repo.insert!()

    asset =
      %Rindle.Domain.MediaAsset{
        id: db_asset.id,
        kind: "video",
        storage_key: "assets/asset-1/original.mp4",
        content_type: "video/mp4",
        variants: [
          %Rindle.Domain.MediaVariant{
            id: Ecto.UUID.generate(),
            asset_id: db_asset.id,
            name: "web_720p",
            state: "ready",
            storage_key: "assets/asset-1/web-720.mp4",
            output_kind: "video",
            content_type: "video/mp4"
          }
        ]
      }

    %MediaProviderAsset{}
    |> MediaProviderAsset.changeset(%{
      asset_id: db_asset.id,
      profile: to_string(StreamingProfile),
      provider_name: "fake_streaming_provider",
      state: "ready",
      playback_ids: ["playback-123"],
      playback_policy: "signed",
      ingest_mode: "server_push"
    })
    |> Repo.insert!()

    html =
      Rindle.HTML.video_tag(StreamingProfile, asset, variants: [:web_720p])
      |> Phoenix.HTML.safe_to_string()

    assert html =~ "src=\"https://stream.example/playback-123.m3u8?token=test-token\""
    assert html =~ "type=\"application/vnd.apple.mpegurl\""
    refute html =~ "streaming_provider_requires_asset_struct"
  end

  test "audio_tag/3 uses provider-backed streaming URLs for streaming-enabled profiles" do
    db_asset =
      %Rindle.Domain.MediaAsset{}
      |> Rindle.Domain.MediaAsset.changeset(%{
        state: "ready",
        profile: to_string(StreamingProfile),
        kind: "audio",
        storage_key: "assets/asset-1/original.m4a",
        content_type: "audio/mp4"
      })
      |> Repo.insert!()

    asset =
      %Rindle.Domain.MediaAsset{
        id: db_asset.id,
        kind: "audio",
        storage_key: "assets/asset-1/original.m4a",
        content_type: "audio/mp4",
        variants: [
          %Rindle.Domain.MediaVariant{
            id: Ecto.UUID.generate(),
            asset_id: db_asset.id,
            name: "web_720p",
            state: "ready",
            storage_key: "assets/asset-1/audio.m4a",
            output_kind: "audio",
            content_type: "audio/mp4"
          }
        ]
      }

    %MediaProviderAsset{}
    |> MediaProviderAsset.changeset(%{
      asset_id: db_asset.id,
      profile: to_string(StreamingProfile),
      provider_name: "fake_streaming_provider",
      state: "ready",
      playback_ids: ["playback-audio-123"],
      playback_policy: "signed",
      ingest_mode: "server_push"
    })
    |> Repo.insert!()

    html =
      Rindle.HTML.audio_tag(StreamingProfile, asset, variants: [:web_720p])
      |> Phoenix.HTML.safe_to_string()

    assert html =~ "src=\"https://stream.example/playback-audio-123.m3u8?token=test-token\""
    assert html =~ "type=\"application/vnd.apple.mpegurl\""
    refute html =~ "streaming_provider_requires_asset_struct"
  end
end
