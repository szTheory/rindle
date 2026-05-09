defmodule Rindle.Workers.MuxSyncProviderAssetTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo
  import Mox

  alias Ecto.Adapters.SQL
  alias Rindle.Domain.{MediaAsset, MediaProviderAsset}
  alias Rindle.Streaming.Provider.Mux.ClientMock
  alias Rindle.Workers.MuxSyncProviderAsset

  setup :set_mox_from_context
  setup :verify_on_exit!

  defmodule TestProfile do
    @moduledoc false
    # Image-shape profile (mirrors Plan 01 mux_test.exs deviation #1 — the
    # AV variant DSL would require a real video setup; the per-row sync
    # worker doesn't consult variant shape, so the image variant is fine).
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [hero: [mode: :fit, width: 320]],
      allow_mime: ["video/mp4"],
      max_bytes: 524_288_000,
      delivery: [signed_url_ttl_seconds: 900]
  end

  setup do
    prev = Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])

    Application.put_env(
      :rindle,
      Rindle.Streaming.Provider.Mux,
      Keyword.merge(prev,
        http_client: ClientMock,
        token_id: "test_id",
        token_secret: "test_secret",
        provider_stuck_threshold_seconds: 7200
      )
    )

    on_exit(fn -> Application.put_env(:rindle, Rindle.Streaming.Provider.Mux, prev) end)
    :ok
  end

  defp insert_asset! do
    %MediaAsset{}
    |> MediaAsset.changeset(%{
      state: "staged",
      profile: to_string(TestProfile),
      storage_key: "uploads/#{Ecto.UUID.generate()}.mp4",
      kind: "video"
    })
    |> Repo.insert!()
  end

  # W1/B2 fix: NO :variant_name in changeset attrs (no such column on
  # media_provider_assets).
  defp insert_row(state, age_seconds, opts \\ []) do
    provider_asset_id =
      Keyword.get(opts, :provider_asset_id, "AbCd1234EfGh5678IjKl9012MnOp3456QrSt")

    updated = DateTime.add(DateTime.utc_now(), -age_seconds, :second)
    asset = insert_asset!()

    {:ok, row} =
      %MediaProviderAsset{}
      |> MediaProviderAsset.changeset(%{
        asset_id: asset.id,
        profile: to_string(TestProfile),
        provider_name: "mux",
        playback_policy: "signed",
        provider_asset_id: provider_asset_id,
        state: state
      })
      |> Repo.insert()

    SQL.query!(
      Repo,
      "UPDATE media_provider_assets SET updated_at = $1 WHERE id = $2",
      [updated, Ecto.UUID.dump!(row.id)]
    )

    Repo.get!(MediaProviderAsset, row.id)
  end

  defp attach_telemetry(events) do
    test_pid = self()
    handler_id = "sync-test-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      events,
      fn evt, m, meta, _ -> send(test_pid, {:tele, evt, m, meta}) end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
    :ok
  end

  # ===========================================================
  # :resolved telemetry path — Mux returned new state
  # ===========================================================

  test "transitions row from :processing to :ready on Mux ready response, persists PLURAL playback_ids, emits :resolved" do
    row = insert_row("processing", 60)

    expect(ClientMock, :get_asset, fn _id ->
      {:ok,
       %{
         "id" => row.provider_asset_id,
         "status" => "ready",
         "playback_ids" => [%{"id" => "playback-id-test", "policy" => "signed"}]
       }}
    end)

    attach_telemetry([[:rindle, :provider, :sync, :resolved]])

    assert :ok =
             perform_job(MuxSyncProviderAsset, %{"provider_asset_id" => row.provider_asset_id})

    updated = Repo.get!(MediaProviderAsset, row.id)
    assert updated.state == "ready"
    # B1 fix: schema field is `playback_ids` (PLURAL ARRAY).
    assert is_list(updated.playback_ids)
    assert "playback-id-test" in updated.playback_ids

    assert_receive {:tele, [:rindle, :provider, :sync, :resolved], _,
                    %{provider_state: "ready", asset_id: redacted}},
                   500

    assert redacted =~ ~r/^\.\.\.[A-Za-z0-9]{4}$/,
           "asset_id must be redacted (security invariant 14)"
  end

  # ===========================================================
  # :stuck telemetry path — row exceeded threshold
  # ===========================================================

  test "transitions to :errored with reason :provider_asset_stuck past stuck threshold" do
    Application.put_env(:rindle, Rindle.Streaming.Provider.Mux,
      http_client: ClientMock,
      token_id: "test_id",
      token_secret: "test_secret",
      provider_stuck_threshold_seconds: 60
    )

    # 120s old, threshold 60s
    row = insert_row("processing", 120, provider_asset_id: "Stuck1234EfGh5678IjKl9012MnOp")

    # Stuck path does NOT call get_asset/1.
    Mox.stub(ClientMock, :get_asset, fn _ -> raise "should not be called" end)

    attach_telemetry([[:rindle, :provider, :sync, :stuck]])

    assert :ok =
             perform_job(MuxSyncProviderAsset, %{"provider_asset_id" => row.provider_asset_id})

    updated = Repo.get!(MediaProviderAsset, row.id)
    assert updated.state == "errored"
    assert updated.last_sync_error =~ "stuck in :processing"

    assert_receive {:tele, [:rindle, :provider, :sync, :stuck], _, %{asset_id: redacted}}, 500
    assert redacted =~ ~r/^\.\.\.[A-Za-z0-9]{4}$/
  end

  # ===========================================================
  # Mux 404 (asset deleted) path
  # ===========================================================

  test "transitions to :errored when Mux returns :not_found" do
    row = insert_row("processing", 60, provider_asset_id: "NotFound1234EfGh5678IjKl9012Mn")

    expect(ClientMock, :get_asset, fn _ ->
      {:error, "not found", %{status: 404, body: ""}}
    end)

    attach_telemetry([[:rindle, :provider, :sync, :resolved]])

    assert :ok =
             perform_job(MuxSyncProviderAsset, %{"provider_asset_id" => row.provider_asset_id})

    updated = Repo.get!(MediaProviderAsset, row.id)
    assert updated.state == "errored"
    assert updated.last_sync_error == "mux asset not found"
  end

  # ===========================================================
  # Idempotency — same state means no transition, but :resolved still fires
  # ===========================================================

  test "no-op transition when live state matches local row state" do
    row = insert_row("processing", 60, provider_asset_id: "Idem1234EfGh5678IjKl9012MnOp34")

    # Plan 01 `get_asset/1` reshapes "preparing" -> "processing".
    expect(ClientMock, :get_asset, fn _ ->
      {:ok, %{"id" => row.provider_asset_id, "status" => "preparing", "playback_ids" => []}}
    end)

    attach_telemetry([[:rindle, :provider, :sync, :resolved]])

    assert :ok =
             perform_job(MuxSyncProviderAsset, %{"provider_asset_id" => row.provider_asset_id})

    updated = Repo.get!(MediaProviderAsset, row.id)

    assert updated.state == "processing",
           "state should remain processing — no transition needed"

    assert_receive {:tele, [:rindle, :provider, :sync, :resolved], _, _}, 500
  end

  # ===========================================================
  # Missing row — coordinator scanned a row that was deleted before per-row ran
  # ===========================================================

  test "returns :ok when row no longer exists (race with deletion)" do
    assert :ok = perform_job(MuxSyncProviderAsset, %{"provider_asset_id" => "DoesNotExist1234"})
  end

  # ===========================================================
  # Worker config — schedulable as Oban job
  # ===========================================================

  test "worker uses :rindle_provider queue and max_attempts: 3" do
    opts = MuxSyncProviderAsset.__opts__()
    assert Keyword.get(opts, :queue) == :rindle_provider
    assert Keyword.get(opts, :max_attempts) == 3
  end
end
