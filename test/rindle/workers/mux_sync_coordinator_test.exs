defmodule Rindle.Workers.MuxSyncCoordinatorTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo

  alias Ecto.Adapters.SQL
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
    SQL.query!(
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

  # ===========================================================
  # WR-08 (POLISH-01/D-13) — distinguish fresh / dedup'd / failed inserts.
  # Pre-WR-08 the coordinator counted only {:ok, _} and silently swallowed the
  # dedup'd-vs-failed distinction, logging "N of M enqueued" with no signal.
  # ===========================================================

  describe "WR-08: insert outcomes are distinguished (fresh vs dedup'd)" do
    # The completed line is `Logger.info` with the fresh/conflicted counts in
    # STRUCTURED metadata. Capture both via a temporary primary-logger handler
    # so we can assert the fresh-vs-dedup'd distinction WR-08 introduced
    # (pre-WR-08 only `{:ok, _}` was counted; dedup'd vs failed was lost).
    defp completed_meta(fun) do
      test_pid = self()
      ref = make_ref()
      handler_id = :"wr08_#{System.unique_integer([:positive])}"

      # The primary logger level (test env) is :warning and filters :info at
      # the core BEFORE dispatching to any handler. Lower it for the duration
      # of the capture, then restore.
      prev_primary = :logger.get_primary_config()
      :logger.update_primary_config(%{level: :info})

      :logger.add_handler(handler_id, __MODULE__.TestLogHandler, %{
        level: :info,
        config: %{test_pid: test_pid, ref: ref}
      })

      try do
        fun.()
      after
        :logger.remove_handler(handler_id)
        :logger.set_primary_config(:level, Map.get(prev_primary, :level, :warning))
      end

      drain_completed_meta(ref, nil, [])
    end

    defp drain_completed_meta(ref, completed, errors) do
      receive do
        {^ref, msg, meta} ->
          completed = if msg =~ "mux_sync_coordinator.completed", do: meta, else: completed

          errors =
            if msg =~ "mux_sync_coordinator.enqueue_errors", do: [meta | errors], else: errors

          drain_completed_meta(ref, completed, errors)
      after
        0 -> {completed, errors}
      end
    end

    test "a second tick is counted as conflicted (dedup'd), not fresh and not silently dropped" do
      prev = Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])

      Application.put_env(
        :rindle,
        Rindle.Streaming.Provider.Mux,
        Keyword.merge(prev, provider_polling_floor_seconds: 30)
      )

      _row = insert_row("processing", 60, "WR08Conflict1234EfGh5678IjKl9012")

      # First tick: one fresh insert.
      {meta_first, errors_first} =
        completed_meta(fn -> assert :ok = perform_job(MuxSyncCoordinator, %{}) end)

      assert meta_first[:jobs_enqueued] == 1
      assert meta_first[:jobs_conflicted] == 0
      assert errors_first == []

      # Second tick within the unique window: the row is CONFLICTED (dedup'd),
      # not a fresh enqueue and not silently dropped.
      {meta_second, errors_second} =
        completed_meta(fn -> assert :ok = perform_job(MuxSyncCoordinator, %{}) end)

      assert meta_second[:jobs_enqueued] == 0
      assert meta_second[:jobs_conflicted] == 1
      # No error log line on the dedup path.
      assert errors_second == []
    end
  end

  # Minimal `:logger` handler that forwards each event's rendered message +
  # structured metadata to the test process (the test env console backend is
  # :warning-level, so coordinator :info lines never reach ExUnit.CaptureLog).
  defmodule TestLogHandler do
    @moduledoc false
    def log(%{msg: msg, meta: meta}, %{config: %{test_pid: pid, ref: ref}}) do
      rendered =
        case msg do
          {:string, s} -> IO.iodata_to_binary(s)
          {format, args} -> :erlang.iolist_to_binary(:io_lib.format(format, args))
          other -> inspect(other)
        end

      send(pid, {ref, rendered, meta})
      :ok
    end
  end
end
