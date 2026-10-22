defmodule Rindle.Workers.MuxSyncProviderAssetTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo
  import Mox

  alias Ecto.Adapters.SQL
  alias Rindle.Domain.{MediaAsset, MediaProviderAsset}
  alias Rindle.Streaming.Provider.Mux.ClientMock
  alias Rindle.Workers.MuxSyncProviderAsset

  defmodule BeforeTransactionRepo do
    defdelegate get_by(model, fields), to: Rindle.Repo
    defdelegate one(query), to: Rindle.Repo
    defdelegate update(changeset), to: Rindle.Repo
    defdelegate rollback(reason), to: Rindle.Repo

    def transaction(fun) do
      send(Process.get(:before_transaction_observer), {:before_sync_transaction, self()})

      receive do
        :continue_sync -> :ok
      after
        5000 -> raise "sync barrier timed out"
      end

      Rindle.Repo.transaction(fun)
    end
  end

  setup :set_mox_from_context
  setup :verify_on_exit!

  defmodule TestProfile do
    @moduledoc false
    # Image-shape profile (mirrors mux_test.exs — the
    # AV variant DSL would require a real video setup; the per-row sync
    # worker doesn't consult variant shape, so the image variant is fine).
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [hero: [mode: :fit, width: 320]],
      allow_mime: ["video/mp4"],
      max_bytes: 524_288_000,
      delivery: [signed_url_ttl_seconds: 900]
  end

  setup tags do
    Process.put(:committed_fixture, tags[:sandbox] == false)
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
    id = Ecto.UUID.generate()

    if Process.get(:committed_fixture) do
      on_exit(fn ->
        Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
          assert {1, nil} =
                   Repo.delete_all(
                     from a in MediaAsset,
                       where: a.id == ^id and a.profile == ^to_string(TestProfile)
                   )

          refute Repo.exists?(from a in MediaAsset, where: a.id == ^id)
        end)
      end)
    end

    %MediaAsset{id: id}
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

    # `get_asset/1` reshapes "preparing" -> "processing".
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
  # An invalid FSM transition reconciles to :errored
  # instead of burning Oban retries on a structurally-impossible edge.
  # ===========================================================

  test "forbidden live transition reconciles row to :errored (no infinite retry)" do
    # Local row is :ready (a terminal-ish state); Mux reports it back to
    # :processing ("preparing"). `ready -> processing` is NOT a permitted FSM
    # edge. Returning {:error, {:invalid_transition, _, _}} would make Oban retry
    # the same impossible transition every attempt, so the worker catches the
    # rejection and force-resolves to :errored with a diagnostic reason.
    row = insert_row("ready", 60, provider_asset_id: "BadEdge1234EfGh5678IjKl9012Mn")

    expect(ClientMock, :get_asset, fn _ ->
      {:ok, %{"id" => row.provider_asset_id, "status" => "preparing", "playback_ids" => []}}
    end)

    attach_telemetry([[:rindle, :provider, :sync, :resolved]])

    assert :ok =
             perform_job(MuxSyncProviderAsset, %{"provider_asset_id" => row.provider_asset_id})

    updated = Repo.get!(MediaProviderAsset, row.id)
    assert updated.state == "errored"
    assert updated.last_sync_error =~ "not reachable from ready"

    # :resolved still fires (the row IS now reconciled with a definite state).
    assert_receive {:tele, [:rindle, :provider, :sync, :resolved], _, _}, 500
  end

  # ===========================================================
  # Adapter failure persists last_sync_error
  # (inspect-truncated to 4096) before propagating {:error, _}.
  # ===========================================================

  test "adapter error persists last_sync_error breadcrumb before returning {:error, _}" do
    row = insert_row("processing", 60, provider_asset_id: "AdapterErr1234EfGh5678IjKl90")

    # A non-:not_found adapter failure (transport/5xx). The worker records a
    # row-level breadcrumb before propagating {:error, reason} to Oban, so
    # operators keep a diagnostic after retries are exhausted.
    expect(ClientMock, :get_asset, fn _ ->
      {:error, :provider_sync_failed}
    end)

    assert {:error, :provider_sync_failed} =
             perform_job(MuxSyncProviderAsset, %{"provider_asset_id" => row.provider_asset_id})

    updated = Repo.get!(MediaProviderAsset, row.id)
    assert updated.last_sync_error =~ "provider_sync_failed"
    assert String.length(updated.last_sync_error) <= 4096
    # Row state is untouched (only the breadcrumb was written).
    assert updated.state == "processing"
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

  @tag sandbox: false
  test "fetched ready error 404 and no-change snapshots cannot overwrite a committed webhook" do
    attach_telemetry([[:rindle, :provider, :sync, :resolved], [:rindle, :provider, :sync, :stuck]])

    responses = [
      {:ok, %{"status" => "errored", "playback_ids" => []}},
      {:ok, %{"status" => "ready", "playback_ids" => [%{"id" => "stale-playback"}]}},
      {:ok, %{"status" => "preparing", "playback_ids" => []}},
      {:error, "not found", %{status: 404, body: ""}},
      {:error, :provider_sync_failed}
    ]

    for response <- responses do
      row = insert_row("processing", 60, provider_asset_id: "race-#{Ecto.UUID.generate()}")

      response =
        case response do
          {:ok, body} -> {:ok, Map.put(body, "id", row.provider_asset_id)}
          other -> other
        end

      parent = self()

      expect(ClientMock, :get_asset, fn _ ->
        send(parent, {:fetched_provider, self()})

        receive do
          :return_provider -> response
        after
          5000 -> raise "provider barrier timed out"
        end
      end)

      task =
        sync_writer(fn ->
          MuxSyncProviderAsset.perform(%Oban.Job{
            args: %{"provider_asset_id" => row.provider_asset_id}
          })
        end)

      assert_receive {:fetched_provider, worker}, 2000
      args = webhook_args(row, "video.asset.ready", ["fresh-playback"])
      assert :ok = Rindle.Workers.IngestProviderWebhook.perform(%Oban.Job{args: args, attempt: 1})
      # Explicit focused fixture for the real timestamps() second collision.
      Repo.update_all(from(p in MediaProviderAsset, where: p.id == ^row.id),
        set: [updated_at: row.updated_at]
      )

      send(worker, :return_provider)
      assert :ok = Task.await(task, 5000)
      current = Repo.get!(MediaProviderAsset, row.id)
      assert current.updated_at == row.updated_at
      assert current.state == "ready" and current.playback_ids == ["fresh-playback"]
      assert current.last_event_id == args["event_id"] and is_nil(current.last_sync_error)
      refute_receive {:tele, [:rindle, :provider, :sync, :resolved], _, _}, 20
    end
  end

  @tag sandbox: false
  test "an accepted watermark alone invalidates an error snapshot within the same second" do
    row = insert_row("processing", 60, provider_asset_id: "same-state-#{Ecto.UUID.generate()}")
    parent = self()

    expect(ClientMock, :get_asset, fn _ ->
      send(parent, {:fetched_provider, self()})

      receive do
        :return_provider -> {:error, :provider_sync_failed}
      after
        5000 -> raise "provider barrier timed out"
      end
    end)

    task =
      sync_writer(fn ->
        MuxSyncProviderAsset.perform(%Oban.Job{
          args: %{"provider_asset_id" => row.provider_asset_id}
        })
      end)

    assert_receive {:fetched_provider, worker}, 2000
    args = webhook_args(row, "provider.future_event", [])
    assert :ok = Rindle.Workers.IngestProviderWebhook.perform(%Oban.Job{args: args, attempt: 1})

    Repo.update_all(from(p in MediaProviderAsset, where: p.id == ^row.id),
      set: [updated_at: row.updated_at]
    )

    send(worker, :return_provider)
    assert :ok = Task.await(task, 5000)
    current = Repo.get!(MediaProviderAsset, row.id)

    assert current.state == row.state and current.playback_ids == row.playback_ids and
             current.updated_at == row.updated_at

    assert current.last_event_id == args["event_id"] and is_nil(current.last_sync_error)
  end

  @tag sandbox: false
  test "stuck snapshot is revalidated after a concurrent committed ready webhook" do
    row = insert_row("processing", 8000, provider_asset_id: "stuck-race-#{Ecto.UUID.generate()}")
    attach_telemetry([[:rindle, :provider, :sync, :stuck]])
    parent = self()

    task =
      sync_writer(fn ->
        Process.put(:before_transaction_observer, parent)
        Rindle.Config.put_repo_override(BeforeTransactionRepo)

        MuxSyncProviderAsset.perform(%Oban.Job{
          args: %{"provider_asset_id" => row.provider_asset_id}
        })
      end)

    assert_receive {:before_sync_transaction, worker}, 2000
    args = webhook_args(row, "video.asset.ready", ["fresh-playback"])
    assert :ok = Rindle.Workers.IngestProviderWebhook.perform(%Oban.Job{args: args, attempt: 1})
    send(worker, :continue_sync)
    assert :ok = Task.await(task, 5000)
    assert Repo.get!(MediaProviderAsset, row.id).state == "ready"
    refute_receive {:tele, [:rindle, :provider, :sync, :stuck], _, _}, 20
  end

  defp webhook_args(row, type, playback) do
    %{
      "event_id" => "evt-#{Ecto.UUID.generate()}",
      "event_type" => type,
      "provider" => "mux",
      "event" => %{
        "provider_asset_id" => row.provider_asset_id,
        "occurred_at" => "2026-05-06T00:00:02.123456Z",
        "playback_ids" => playback,
        "raw" => %{}
      }
    }
  end

  defp sync_writer(fun) do
    task =
      Task.async(fn ->
        :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo, sandbox: false)

        try do
          fun.()
        after
          Ecto.Adapters.SQL.Sandbox.checkin(Repo)
        end
      end)

    on_exit(fn -> if Process.alive?(task.pid), do: Process.exit(task.pid, :kill) end)
    task
  end
end
