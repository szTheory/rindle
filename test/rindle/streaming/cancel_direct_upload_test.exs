defmodule Rindle.Streaming.CancelDirectUploadTest do
  use Rindle.DataCase, async: false
  import Mox

  alias Rindle.Domain.{MediaAsset, MediaProviderAsset, ProviderAssetFSM}
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

  test "cancel_direct_upload/1 marks row deleted and calls provider cancel" do
    {:ok, asset} =
      %MediaAsset{}
      |> MediaAsset.changeset(%{
        state: "ready",
        storage_key: "streaming/mux/direct_upload/test",
        profile: to_string(DirectUploadProfile),
        kind: "video",
        filename: "clip.mp4",
        content_type: "video/mp4",
        byte_size: 1_024,
        metadata: %{"ingest_mode" => "direct_creator_upload"}
      })
      |> Repo.insert()

    {:ok, provider_row} =
      %MediaProviderAsset{}
      |> MediaProviderAsset.changeset(%{
        asset_id: asset.id,
        profile: to_string(DirectUploadProfile),
        provider_name: "mux",
        playback_policy: "signed",
        ingest_mode: "direct_creator_upload",
        provider_upload_id: "mux-upload-cancel-1",
        state: "uploading"
      })
      |> Repo.insert()

    expect(ClientMock, :cancel_upload, fn "mux-upload-cancel-1" -> :ok end)

    assert :ok = Streaming.cancel_direct_upload(asset.id)

    row = Repo.get!(MediaProviderAsset, provider_row.id)
    assert row.state == "deleted"
  end

  test "@cancellable_states matches FSM deleted edges" do
    fsm = ProviderAssetFSM.allowed_transitions()
    assert "deleted" in fsm["pending"]
    assert "deleted" in fsm["uploading"]
  end
end
