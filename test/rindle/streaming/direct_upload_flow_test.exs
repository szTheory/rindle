defmodule Rindle.Streaming.DirectUploadFlowTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo
  import Mox

  alias Phoenix.PubSub
  alias Rindle.Domain.{MediaAsset, MediaProviderAsset}
  alias Rindle.Streaming
  alias Rindle.Streaming.Provider.Mux
  alias Rindle.Streaming.Provider.Mux.ClientMock
  alias Rindle.Workers.IngestProviderWebhook

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

  test "create direct upload -> upload linked -> provider ready emits both provider events" do
    expect(ClientMock, :create_upload, fn _params ->
      {:ok, %{"id" => "upload-123", "url" => "https://mux.example/upload"}}
    end)

    assert {:ok, %{asset_id: asset_id}} =
             Streaming.create_direct_upload(DirectUploadProfile,
               filename: "demo.mp4",
               cors_origin: "https://app.example"
             )

    asset = Repo.get!(MediaAsset, asset_id)

    row =
      Repo.get_by!(MediaProviderAsset,
        asset_id: asset.id,
        profile: to_string(DirectUploadProfile),
        provider_name: "mux"
      )

    PubSub.subscribe(Rindle.PubSub, "rindle:provider_asset:#{asset.id}")
    PubSub.subscribe(Rindle.PubSub, "rindle:asset:#{asset.id}")

    upload_created_args = %{
      "event_id" => "evt-upload-created",
      "provider" => "mux",
      "event_type" => "video.upload.asset_created",
      "event" => %{
        "type" => "upload_asset_created",
        "provider_asset_id" => "mux-asset-123",
        "playback_ids" => [],
        "state" => nil,
        "occurred_at" => "2026-05-24T12:00:00.000Z",
        "raw" => %{
          "data" => %{
            "id" => "upload-123",
            "asset_id" => "mux-asset-123",
            "passthrough" => row.mux_passthrough
          }
        }
      }
    }

    assert :ok = perform_job(IngestProviderWebhook, upload_created_args)

    assert_receive {:rindle_event, :provider_asset_created, created_payload}
    assert created_payload.asset_id == asset.id
    assert created_payload.state == "processing"

    ready_args = %{
      "event_id" => "evt-asset-ready",
      "provider" => "mux",
      "event_type" => "video.asset.ready",
      "event" => %{
        "type" => "ready",
        "provider_asset_id" => "mux-asset-123",
        "playback_ids" => ["playback-123"],
        "state" => "ready",
        "occurred_at" => "2026-05-24T12:05:00.000Z",
        "raw" => %{"data" => %{"id" => "mux-asset-123"}}
      }
    }

    assert :ok = perform_job(IngestProviderWebhook, ready_args)

    assert_receive {:rindle_event, :provider_asset_ready, ready_payload}
    assert ready_payload.asset_id == asset.id
    assert ready_payload.state == "ready"
    assert ready_payload.playback_ids == ["playback-123"]
  end
end
