defmodule Rindle.LiveViewDirectUploadTest do
  use Rindle.DataCase, async: false
  import Mox

  Code.ensure_loaded!(Rindle.LiveView)

  alias Phoenix.LiveView.UploadEntry
  alias Rindle.Domain.MediaProviderAsset
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

  defp build_socket do
    %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}},
      private: %{live_temp: %{}}
    }
  end

  test "allow_direct_upload/4 configures an external upload helper" do
    socket = build_socket()

    updated_socket =
      Rindle.LiveView.allow_direct_upload(socket, :video, DirectUploadProfile,
        cors_origin: "https://app.example",
        accept: ~w(.mp4),
        max_entries: 1
      )

    config = updated_socket.assigns.uploads[:video]
    assert config.max_entries == 1
    assert is_function(config.external, 2)
  end

  test "external helper returns browser-safe endpoint metadata only" do
    socket = build_socket()

    updated_socket =
      Rindle.LiveView.allow_direct_upload(socket, :video, DirectUploadProfile,
        cors_origin: "https://app.example",
        accept: ~w(.mp4),
        max_entries: 1
      )

    external_fn = updated_socket.assigns.uploads[:video].external
    entry = %UploadEntry{client_name: "demo.mp4", ref: "video-ref"}

    expect(ClientMock, :create_upload, fn params ->
      assert params["cors_origin"] == "https://app.example"
      {:ok, %{"id" => "upload-123", "url" => "https://mux.example/upload"}}
    end)

    assert {:ok, meta, ^updated_socket} = external_fn.(entry, updated_socket)

    assert meta == %{
             uploader: "UpChunk",
             endpoint: "https://mux.example/upload",
             asset_id: meta.asset_id
           }

    refute Map.has_key?(meta, :upload_id)
    refute Map.has_key?(meta, :provider_asset_id)

    row =
      Repo.get_by!(MediaProviderAsset,
        asset_id: meta.asset_id,
        profile: to_string(DirectUploadProfile),
        provider_name: "mux"
      )

    assert row.state == "uploading"
  end
end
