defmodule Rindle.Delivery.WebhookPlugTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo

  alias Phoenix.PubSub
  alias Plug.Conn
  alias Plug.Test, as: PlugTest
  alias Rindle.Delivery.WebhookPlug
  alias Rindle.Domain.{MediaAsset, MediaProviderAsset}
  alias Rindle.Streaming.Provider.Mux, as: MuxAdapter
  alias Rindle.Test.MuxWebhookFixtures

  defmodule TestProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [hero: [kind: :video, preset: :web_720p]],
      allow_mime: ["video/mp4"],
      max_bytes: 524_288_000,
      delivery: [signed_url_ttl_seconds: 900]
  end

  @secret "test_webhook_secret_phase35"
  @ready_fixture_path Path.join([
                        File.cwd!(),
                        "test",
                        "fixtures",
                        "mux",
                        "webhook_video_asset_ready.json"
                      ])

  @plug_events [
    [:rindle, :provider, :webhook, :verified],
    [:rindle, :provider, :webhook, :rejected],
    [:rindle, :provider, :mux, :webhook_attempt, :secret_used],
    [:rindle, :provider, :mux, :webhook_attempt, :rejected]
  ]

  setup do
    # Mux adapter requires `webhook_tolerance_seconds` in app env for replay tests.
    prev_mux = Application.get_env(:rindle, MuxAdapter, [])

    Application.put_env(
      :rindle,
      MuxAdapter,
      Keyword.merge(prev_mux, webhook_tolerance_seconds: 300)
    )

    on_exit(fn -> Application.put_env(:rindle, MuxAdapter, prev_mux) end)

    handler_id = "webhook-plug-test-#{System.unique_integer([:positive])}"
    test_pid = self()

    :telemetry.attach_many(
      handler_id,
      @plug_events,
      fn evt, measurements, metadata, _ ->
        send(test_pid, {:tele, evt, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    body = File.read!(@ready_fixture_path)

    %{body: body, handler_id: handler_id}
  end

  defp signed_conn(method, path, body, secret, opts \\ []) do
    sig_header = MuxWebhookFixtures.sign_header(body, secret, opts)

    method
    |> PlugTest.conn(path, body)
    |> Conn.put_req_header("content-type", "application/json")
    |> Conn.put_req_header("mux-signature", sig_header)
    # D-37 — synthetic conns don't run Plug.Parsers, so we pre-populate the
    # :raw_body assign manually (matches what WebhookBodyReader would do).
    |> Conn.assign(:raw_body, [body])
  end

  defp init_opts(secrets) do
    WebhookPlug.init(provider: MuxAdapter, secrets: secrets)
  end

  defp drain_telemetry(filter, acc) do
    receive do
      {:tele, evt, _, _} = msg ->
        if filter == nil or evt == filter do
          drain_telemetry(filter, [msg | acc])
        else
          drain_telemetry(filter, acc)
        end
    after
      50 -> Enum.reverse(acc)
    end
  end

  defp last_telemetry(filter), do: drain_telemetry(filter, []) |> List.last()

  defp insert_provider_row(asset, state, attrs) do
    base = %{
      asset_id: asset.id,
      profile: to_string(TestProfile),
      provider_name: "mux",
      provider_asset_id: "mux-asset-id-" <> Ecto.UUID.generate(),
      playback_policy: "signed",
      state: state
    }

    %MediaProviderAsset{}
    |> MediaProviderAsset.changeset(Map.merge(base, attrs))
    |> Repo.insert!()
  end

  defp create_asset! do
    asset_id = Ecto.UUID.generate()

    {:ok, asset} =
      %MediaAsset{}
      |> MediaAsset.changeset(%{
        id: asset_id,
        state: "ready",
        storage_key: "media/#{asset_id}/source.mp4",
        profile: to_string(TestProfile),
        kind: "video",
        content_type: "video/mp4",
        byte_size: 100_000
      })
      |> Repo.insert()

    asset
  end

  # ============================================================
  # 1. Happy path: 202 + Oban job enqueued + telemetry :verified kind: :enqueued
  # ============================================================

  describe "happy path" do
    test "valid signature: 202 + IngestProviderWebhook job enqueued + telemetry :verified kind: :enqueued",
         ctx do
      conn = signed_conn(:post, "/", ctx.body, @secret)

      conn = WebhookPlug.call(conn, init_opts([@secret]))

      assert conn.status == 202
      assert conn.resp_body == ""

      assert_enqueued(worker: Rindle.Workers.IngestProviderWebhook)

      assert {:tele, [:rindle, :provider, :webhook, :verified], _, metadata} =
               last_telemetry([:rindle, :provider, :webhook, :verified])

      assert metadata.kind == :enqueued
      assert metadata.event_type == "video.asset.ready"
      assert metadata.provider == :mux
    end

    test "idempotent re-delivery: second identical post is no-op (Oban unique on event_id)",
         ctx do
      conn1 = signed_conn(:post, "/", ctx.body, @secret)
      conn1 = WebhookPlug.call(conn1, init_opts([@secret]))
      assert conn1.status == 202

      conn2 = signed_conn(:post, "/", ctx.body, @secret)
      conn2 = WebhookPlug.call(conn2, init_opts([@secret]))
      assert conn2.status == 202

      # Both POSTs returned 202; only ONE job exists (Oban unique on event_id).
      jobs = all_enqueued(worker: Rindle.Workers.IngestProviderWebhook)
      assert length(jobs) == 1
    end
  end

  # ============================================================
  # 3. Multi-secret rotation: secrets [old, current], header signed by current
  # 4. Multi-secret rotation: secrets [current, new], header signed by new
  # ============================================================

  describe "multi-secret rotation" do
    test "secrets [old, current], header signed by current: 202 + secret_used secret_index 1",
         ctx do
      conn = signed_conn(:post, "/", ctx.body, @secret)
      conn = WebhookPlug.call(conn, init_opts(["old-secret-rotating-out", @secret]))

      assert conn.status == 202

      assert {:tele, [:rindle, :provider, :mux, :webhook_attempt, :secret_used], _, metadata} =
               last_telemetry([:rindle, :provider, :mux, :webhook_attempt, :secret_used])

      assert metadata.secret_index == 1
    end

    test "secrets [current, new], header signed by new: 202 + secret_used secret_index 1",
         ctx do
      new_secret = "new_secret_rotating_in"
      conn = signed_conn(:post, "/", ctx.body, new_secret)
      conn = WebhookPlug.call(conn, init_opts([@secret, new_secret]))

      assert conn.status == 202

      assert {:tele, [:rindle, :provider, :mux, :webhook_attempt, :secret_used], _, metadata} =
               last_telemetry([:rindle, :provider, :mux, :webhook_attempt, :secret_used])

      assert metadata.secret_index == 1
    end
  end

  # ============================================================
  # 5. Replay attack: timestamp 600s old returns 400
  # 6. Signature mismatch: wrong-secret returns 400
  # 7. Missing mux-signature header returns 400
  # 8. Non-POST returns 405
  # 9. Empty :secrets list returns 400 :no_secrets_configured
  # 10. Missing body assign + empty fallback -> 500 :body_reader_missing
  # ============================================================

  describe "rejection paths" do
    test "replay attack: timestamp 600s old returns 400 + telemetry :rejected reason: :sig_mismatch",
         ctx do
      stale_ts = System.system_time(:second) - 600

      conn = signed_conn(:post, "/", ctx.body, @secret, timestamp: stale_ts)
      conn = WebhookPlug.call(conn, init_opts([@secret]))

      assert conn.status == 400
      assert conn.resp_body == "provider_webhook_invalid"

      assert {:tele, [:rindle, :provider, :webhook, :rejected], _, metadata} =
               last_telemetry([:rindle, :provider, :webhook, :rejected])

      assert metadata.reason == :sig_mismatch
    end

    test "signature mismatch: wrong secret returns 400", ctx do
      conn = signed_conn(:post, "/", ctx.body, "wrong-secret")
      conn = WebhookPlug.call(conn, init_opts([@secret]))

      assert conn.status == 400
      assert conn.resp_body == "provider_webhook_invalid"

      assert {:tele, [:rindle, :provider, :webhook, :rejected], _, metadata} =
               last_telemetry([:rindle, :provider, :webhook, :rejected])

      assert metadata.reason == :sig_mismatch
    end

    test "missing mux-signature header returns 400", ctx do
      conn =
        :post
        |> PlugTest.conn("/", ctx.body)
        |> Conn.put_req_header("content-type", "application/json")
        |> Conn.assign(:raw_body, [ctx.body])

      conn = WebhookPlug.call(conn, init_opts([@secret]))

      assert conn.status == 400
      assert conn.resp_body == "provider_webhook_invalid"
    end

    test "non-POST returns 405 + telemetry :rejected reason: :method_not_allowed",
         _ctx do
      conn = PlugTest.conn(:get, "/", "")
      conn = WebhookPlug.call(conn, init_opts([@secret]))

      assert conn.status == 405
      assert conn.resp_body == "method not allowed"

      assert {:tele, [:rindle, :provider, :webhook, :rejected], _, metadata} =
               last_telemetry([:rindle, :provider, :webhook, :rejected])

      assert metadata.reason == :method_not_allowed
    end

    test "empty :secrets list returns 400 :no_secrets_configured + telemetry :rejected",
         ctx do
      conn = signed_conn(:post, "/", ctx.body, @secret)
      conn = WebhookPlug.call(conn, init_opts([]))

      assert conn.status == 400
      assert conn.resp_body == "provider_webhook_invalid"

      assert {:tele, [:rindle, :provider, :webhook, :rejected], _, metadata} =
               last_telemetry([:rindle, :provider, :webhook, :rejected])

      assert metadata.reason == :no_secrets_configured
    end

    test "missing body assign + empty fallback body -> 500 :body_reader_missing",
         _ctx do
      # No raw_body assign; empty body — Plug.Conn.read_body/2 fallback returns
      # an empty binary, which the Plug treats as body_reader_missing (D-16).
      conn =
        :post
        |> PlugTest.conn("/", "")
        |> Conn.put_req_header("content-type", "application/json")

      conn = WebhookPlug.call(conn, init_opts([@secret]))

      assert conn.status == 500
      assert conn.resp_body == "server_misconfigured"

      assert {:tele, [:rindle, :provider, :webhook, :rejected], _, metadata} =
               last_telemetry([:rindle, :provider, :webhook, :rejected])

      assert metadata.reason == :body_reader_missing
    end
  end

  # ============================================================
  # 11. dispatch_kind == :drop -> 200 OK + telemetry kind: :dropped
  # ============================================================

  describe "dispatch_kind drop" do
    test "drop event (video.asset.updated): 200 + telemetry kind: :dropped + NO Oban job",
         _ctx do
      drop_payload = %{
        "type" => "video.asset.updated",
        "id" => "evt-fixture-updated-0001",
        "data" => %{"id" => "asset-id-1234", "status" => "ready"},
        "created_at" => "2026-05-06T00:00:00.000Z"
      }

      drop_body = Jason.encode!(drop_payload)

      conn = signed_conn(:post, "/", drop_body, @secret)
      conn = WebhookPlug.call(conn, init_opts([@secret]))

      assert conn.status == 200
      assert conn.resp_body == ""

      assert {:tele, [:rindle, :provider, :webhook, :verified], _, metadata} =
               last_telemetry([:rindle, :provider, :webhook, :verified])

      assert metadata.kind == :dropped
      assert metadata.event_type == "video.asset.updated"

      refute_enqueued(worker: Rindle.Workers.IngestProviderWebhook)
    end
  end

  # ============================================================
  # 12. End-to-end fixture flow: video.asset.ready posted to Plug -> worker
  #     drains -> row state flips to :ready -> :provider_asset_ready
  #     broadcast received with payload omitting provider_asset_id.
  # ============================================================

  describe "end-to-end" do
    test "video.asset.ready: post -> Plug verifies + enqueues -> worker drains -> row flips :processing -> :ready -> PubSub broadcast received",
         ctx do
      raw = Jason.decode!(ctx.body)
      provider_asset_id = raw["data"]["id"]

      asset = create_asset!()

      _row =
        insert_provider_row(asset, "processing", %{provider_asset_id: provider_asset_id})

      PubSub.subscribe(Rindle.PubSub, "rindle:asset:#{asset.id}")
      PubSub.subscribe(Rindle.PubSub, "rindle:provider_asset:#{asset.id}")

      conn = signed_conn(:post, "/", ctx.body, @secret)
      conn = WebhookPlug.call(conn, init_opts([@secret]))

      assert conn.status == 202

      # Drain the rindle_provider queue (testing: :manual; Oban won't auto-execute).
      Oban.drain_queue(queue: :rindle_provider)

      # Row flipped to :ready.
      reloaded =
        Repo.get_by!(MediaProviderAsset,
          asset_id: asset.id,
          profile: to_string(TestProfile),
          provider_name: "mux"
        )

      assert reloaded.state == "ready"
      assert reloaded.playback_ids == ["playback-id-test-fixture-1234"]
      assert reloaded.last_sync_error == nil

      # Two-topic PubSub broadcast received with payload omitting provider_asset_id.
      assert_receive {:rindle_event, :provider_asset_ready, payload1}
      assert_receive {:rindle_event, :provider_asset_ready, payload2}

      for payload <- [payload1, payload2] do
        assert payload.asset_id == asset.id
        assert payload.playback_ids == ["playback-id-test-fixture-1234"]
        assert payload.profile == to_string(TestProfile)
        assert payload.provider == :mux
        assert payload.state == "ready"
        refute Map.has_key?(payload, :provider_asset_id)
      end
    end
  end
end
