defmodule Rindle.Workers.MuxSyncCoordinatorTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo

  alias Rindle.Domain.{MediaAsset, MediaProviderAsset}
  alias Rindle.Workers.{MuxSyncCoordinator, MuxSyncProviderAsset}

  setup do
    prev = Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])
    on_exit(fn -> Application.put_env(:rindle, Rindle.Streaming.Provider.Mux, prev) end)
    :ok
  end

  defp insert_asset! do
    %MediaAsset{}
    |> MediaAsset.changeset(%{
      state: "staged",
      profile: "TestProfile",
      storage_key: "uploads/#{Ecto.UUID.generate()}.mp4",
      kind: "video"
    })
    |> Repo.insert!()
  end

  defp insert_row(state, age_seconds, provider_asset_id) do
    updated = DateTime.add(DateTime.utc_now(), -age_seconds, :second)
    asset = insert_asset!()

    # W1 fix: NO :variant_name in changeset attrs (no such column on
    # media_provider_assets). The required schema fields are
    # [:asset_id, :profile, :provider_name, :state].
    {:ok, row} =
      %MediaProviderAsset{}
      |> MediaProviderAsset.changeset(%{
        asset_id: asset.id,
        profile: "TestProfile",
        provider_name: "mux",
        playback_policy: "signed",
        provider_asset_id: provider_asset_id,
        state: state
      })
      |> Repo.insert()

    # Force the updated_at to simulate age (changeset always bumps it).
    Ecto.Adapters.SQL.query!(
      Repo,
      "UPDATE media_provider_assets SET updated_at = $1 WHERE id = $2",
      [updated, Ecto.UUID.dump!(row.id)]
    )

    row
  end

  test "fans out per-row jobs for processing/uploading rows older than the floor" do
    prev = Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])

    Application.put_env(
      :rindle,
      Rindle.Streaming.Provider.Mux,
      Keyword.merge(prev, provider_polling_floor_seconds: 30)
    )

    _stale_processing = insert_row("processing", 60, "AbCd1234EfGh5678IjKl9012MnOp3456QrSt")
    _stale_uploading = insert_row("uploading", 45, "Up1234EfGh5678IjKl9012MnOp3456QrStAbCd")
    _fresh = insert_row("processing", 5, "Fresh1234EfGh5678IjKl9012MnOp3456QrSt")
    _ready = insert_row("ready", 3600, "Ready1234EfGh5678IjKl9012MnOp3456QrSt")

    assert :ok = perform_job(MuxSyncCoordinator, %{})

    # Two stale rows fanned out; fresh and ready did not.
    assert_enqueued(
      worker: MuxSyncProviderAsset,
      args: %{"provider_asset_id" => "AbCd1234EfGh5678IjKl9012MnOp3456QrSt"}
    )

    assert_enqueued(
      worker: MuxSyncProviderAsset,
      args: %{"provider_asset_id" => "Up1234EfGh5678IjKl9012MnOp3456QrStAbCd"}
    )

    refute_enqueued(
      worker: MuxSyncProviderAsset,
      args: %{"provider_asset_id" => "Fresh1234EfGh5678IjKl9012MnOp3456QrSt"}
    )

    refute_enqueued(
      worker: MuxSyncProviderAsset,
      args: %{"provider_asset_id" => "Ready1234EfGh5678IjKl9012MnOp3456QrSt"}
    )
  end

  test "second tick does not re-enqueue still-running per-row jobs (unique period: 60)" do
    prev = Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])

    Application.put_env(
      :rindle,
      Rindle.Streaming.Provider.Mux,
      Keyword.merge(prev, provider_polling_floor_seconds: 30)
    )

    _row = insert_row("processing", 60, "DupCheck1234EfGh5678IjKl9012MnOp3456")

    assert :ok = perform_job(MuxSyncCoordinator, %{})
    queued_after_first = all_enqueued(worker: MuxSyncProviderAsset) |> length()
    assert queued_after_first == 1

    # Second tick: per-row unique constraint with period: 60 deduplicates.
    assert :ok = perform_job(MuxSyncCoordinator, %{})
    queued_after_second = all_enqueued(worker: MuxSyncProviderAsset) |> length()

    assert queued_after_second == 1,
           "Second cron tick must not re-enqueue (Pitfall 6 mitigation via per-row unique)"
  end

  test "respects custom provider_polling_floor_seconds" do
    prev = Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])

    Application.put_env(
      :rindle,
      Rindle.Streaming.Provider.Mux,
      Keyword.merge(prev, provider_polling_floor_seconds: 120)
    )

    _just_old = insert_row("processing", 60, "JustOld1234EfGh5678IjKl9012MnOp3456QrSt")
    _very_old = insert_row("processing", 200, "VeryOld1234EfGh5678IjKl9012MnOp3456QrSt")

    assert :ok = perform_job(MuxSyncCoordinator, %{})

    refute_enqueued(
      worker: MuxSyncProviderAsset,
      args: %{"provider_asset_id" => "JustOld1234EfGh5678IjKl9012MnOp3456QrSt"}
    )

    assert_enqueued(
      worker: MuxSyncProviderAsset,
      args: %{"provider_asset_id" => "VeryOld1234EfGh5678IjKl9012MnOp3456QrSt"}
    )
  end

  test "worker is schedulable as Oban cron job on :rindle_provider queue" do
    opts = MuxSyncCoordinator.__opts__()
    assert Keyword.get(opts, :queue) == :rindle_provider
    assert Keyword.get(opts, :max_attempts) == 1
  end
end
