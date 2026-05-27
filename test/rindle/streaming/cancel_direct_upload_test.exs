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

  @not_cancellable_states ~w(processing ready)

  defp insert_provider_row!(attrs) do
    defaults = %{
      state: "uploading",
      provider_upload_id: "mux-upload-default",
      ingest_mode: "direct_creator_upload",
      provider_name: "mux",
      playback_policy: "signed",
      profile: to_string(DirectUploadProfile)
    }

    {:ok, asset} =
      %MediaAsset{}
      |> MediaAsset.changeset(%{
        state: "ready",
        storage_key: "streaming/mux/direct_upload/#{Ecto.UUID.generate()}",
        profile: to_string(DirectUploadProfile),
        kind: "video",
        filename: "clip.mp4",
        content_type: "video/mp4",
        byte_size: 1_024,
        metadata: %{"ingest_mode" => "direct_creator_upload"}
      })
      |> Repo.insert()

    merged = Map.merge(defaults, Map.new(attrs))

    {:ok, provider_row} =
      %MediaProviderAsset{}
      |> MediaProviderAsset.changeset(%{
        asset_id: asset.id,
        profile: merged.profile,
        provider_name: merged.provider_name,
        playback_policy: merged.playback_policy,
        ingest_mode: merged.ingest_mode,
        provider_upload_id: merged.provider_upload_id,
        state: merged.state
      })
      |> Repo.insert()

    {asset, provider_row}
  end

  test "create_direct_upload/2 then cancel_direct_upload/1 deletes row and calls provider cancel" do
    expect(ClientMock, :create_upload, fn _params ->
      {:ok, %{"id" => "mux-upload-create-cancel", "url" => "https://storage.mux.com/upload/x"}}
    end)

    expect(ClientMock, :cancel_upload, fn "mux-upload-create-cancel" -> :ok end)

    assert {:ok, %{asset_id: asset_id}} =
             Streaming.create_direct_upload(DirectUploadProfile,
               filename: "clip.mp4",
               cors_origin: "https://app.example"
             )

    assert :ok = Streaming.cancel_direct_upload(asset_id)

    row = Repo.get_by!(MediaProviderAsset, asset_id: asset_id)
    assert row.state == "deleted"
    assert row.provider_upload_id == "mux-upload-create-cancel"
  end

  test "cancel_direct_upload/1 is idempotent when row is already deleted" do
    {asset, _row} =
      insert_provider_row!(%{
        state: "deleted",
        provider_upload_id: "mux-upload-re-cancel"
      })

    stub(ClientMock, :cancel_upload, fn _ -> :ok end)

    assert :ok = Streaming.cancel_direct_upload(asset.id)
    assert :ok = Streaming.cancel_direct_upload(asset.id)
  end

  for state <- @not_cancellable_states do
    test "cancel_direct_upload/1 returns not_cancellable for #{state} state" do
      expected_state = unquote(state)
      {asset, row} = insert_provider_row!(%{state: expected_state})

      assert {:error, {:not_cancellable, %{reason: :state, state: returned_state}}} =
               Streaming.cancel_direct_upload(asset.id)

      assert returned_state == expected_state

      unchanged = Repo.get!(MediaProviderAsset, row.id)
      assert unchanged.state == expected_state
    end
  end

  test "cancel_direct_upload/1 returns not_cancellable when provider_upload_id is missing" do
    {asset, row} = insert_provider_row!(%{provider_upload_id: nil})

    assert {:error, {:not_cancellable, %{reason: :missing_upload_id}}} =
             Streaming.cancel_direct_upload(asset.id)

    unchanged = Repo.get!(MediaProviderAsset, row.id)
    assert unchanged.state == "uploading"
  end

  test "cancel_direct_upload/1 keeps row deleted when provider cancel fails" do
    {asset, row} =
      insert_provider_row!(%{
        state: "uploading",
        provider_upload_id: "mux-upload-sync-fail"
      })

    expect(ClientMock, :cancel_upload, fn "mux-upload-sync-fail" ->
      {:error, "unavailable", %{status: 503}}
    end)

    assert {:error, :provider_sync_failed} = Streaming.cancel_direct_upload(asset.id)

    updated = Repo.get!(MediaProviderAsset, row.id)
    assert updated.state == "deleted"
  end

  test "cancel_direct_upload/1 cancels pending rows" do
    {asset, provider_row} =
      insert_provider_row!(%{state: "pending", provider_upload_id: "mux-upload-pending"})

    expect(ClientMock, :cancel_upload, fn "mux-upload-pending" -> :ok end)

    assert :ok = Streaming.cancel_direct_upload(asset.id)

    row = Repo.get!(MediaProviderAsset, provider_row.id)
    assert row.state == "deleted"
  end

  test "cancel_direct_upload/1 returns provider_quota_exceeded and keeps row deleted" do
    {asset, row} =
      insert_provider_row!(%{
        state: "uploading",
        provider_upload_id: "mux-upload-quota"
      })

    expect(ClientMock, :cancel_upload, fn "mux-upload-quota" ->
      {:error, "rate limited", %{status: 429}}
    end)

    assert {:error, :provider_quota_exceeded} = Streaming.cancel_direct_upload(asset.id)

    updated = Repo.get!(MediaProviderAsset, row.id)
    assert updated.state == "deleted"
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
