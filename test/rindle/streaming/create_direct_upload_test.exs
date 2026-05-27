defmodule Rindle.Streaming.CreateDirectUploadTest do
  use Rindle.DataCase, async: false
  import Mox

  alias Rindle.Domain.{MediaAsset, MediaProviderAsset}
  alias Rindle.Streaming
  alias Rindle.Streaming.Provider.Mux
  alias Rindle.Streaming.Provider.Mux.ClientMock

  setup :set_mox_from_context
  setup :verify_on_exit!

  defmodule DirectUploadProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [web: [kind: :video, preset: :web_720p]],
      allow_mime: ["video/mp4"],
      max_bytes: 524_288_000,
      delivery: [
        streaming: [
          provider: Rindle.Streaming.Provider.Mux,
          playback_policy: :signed,
          ingest_mode: :direct_creator_upload,
          source_variant: :web
        ]
      ]
  end

  defmodule ServerPushProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [web: [kind: :video, preset: :web_720p]],
      allow_mime: ["video/mp4"],
      max_bytes: 524_288_000,
      delivery: [
        streaming: [
          provider: Rindle.Streaming.Provider.Mux,
          playback_policy: :signed,
          ingest_mode: :server_push,
          source_variant: :web
        ]
      ]
  end

  setup do
    prev = Application.get_env(:rindle, Mux, [])

    Application.put_env(
      :rindle,
      Mux,
      Keyword.merge(prev,
        http_client: ClientMock,
        token_id: "test_token_id",
        token_secret: "test_token_secret"
      )
    )

    on_exit(fn -> Application.put_env(:rindle, Mux, prev) end)
    :ok
  end

  test "creates the local asset/provider rows and returns only upload_url + asset_id" do
    expect(ClientMock, :create_upload, fn params ->
      assert params["cors_origin"] == "https://app.example"
      assert params["new_asset_settings"]["playback_policies"] == ["signed"]
      assert is_binary(params["new_asset_settings"]["passthrough"])

      {:ok,
       %{
         "id" => "mux-upload-id-123",
         "url" => "https://storage.mux.com/upload/once"
       }}
    end)

    assert {:ok, %{upload_url: upload_url, asset_id: asset_id} = result} =
             Streaming.create_direct_upload(DirectUploadProfile,
               filename: "clip.mp4",
               cors_origin: "https://app.example"
             )

    assert upload_url == "https://storage.mux.com/upload/once"
    assert Map.keys(result) |> Enum.sort() == [:asset_id, :upload_url]

    asset = Repo.get!(MediaAsset, asset_id)
    assert asset.state == "ready"
    assert asset.kind == "video"
    assert asset.profile == to_string(DirectUploadProfile)
    assert asset.filename == "clip.mp4"

    provider_row =
      Repo.get_by!(MediaProviderAsset,
        asset_id: asset_id,
        profile: to_string(DirectUploadProfile),
        provider_name: "mux"
      )

    assert provider_row.state == "uploading"
    assert provider_row.provider_upload_id == "mux-upload-id-123"
    refute inspect(provider_row) =~ "mux-upload-id-123"
    assert provider_row.playback_policy == "signed"
    assert provider_row.ingest_mode == "direct_creator_upload"
    assert is_binary(provider_row.mux_passthrough)
    assert provider_row.provider_asset_id == nil
    refute Map.has_key?(result, :upload_id)
    refute Map.has_key?(result, :provider_asset_id)
    refute inspect(provider_row) =~ provider_row.mux_passthrough
  end

  test "returns :streaming_not_configured when the profile is not in direct-upload mode" do
    assert {:error, :streaming_not_configured} =
             Streaming.create_direct_upload(ServerPushProfile, cors_origin: "https://app.example")
  end
end
