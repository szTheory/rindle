defmodule Rindle.Streaming.Provider.MuxTest do
  use Rindle.DataCase, async: false
  import Mox

  alias Rindle.Streaming.Provider.Mux, as: Adapter
  alias Rindle.Streaming.Provider.Mux.ClientMock
  alias Rindle.Test.MuxWebhookFixtures

  setup :set_mox_from_context
  setup :verify_on_exit!

  defmodule TestProfile do
    # The plan-level test profile. The Phase 33 DSL nests delivery options
    # under `:delivery`; `signed_url_ttl_seconds: 900` becomes the profile-level
    # TTL that `Rindle.Delivery.signed_url_ttl_seconds/1` returns. We do not
    # exercise the `:streaming` DSL key here — `signed_playback_url/3` does not
    # consult it, and the `:streaming` schema requires fields that Plan 02 owns.
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [hero: [mode: :fit, width: 320]],
      allow_mime: ["video/mp4"],
      max_bytes: 524_288_000,
      delivery: [signed_url_ttl_seconds: 900]
  end

  setup do
    prev = Application.get_env(:rindle, Adapter, [])

    Application.put_env(
      :rindle,
      Adapter,
      Keyword.merge(prev,
        http_client: ClientMock,
        token_id: "test_token_id",
        token_secret: "test_token_secret",
        signing_key_id: "test_kid",
        signing_private_key: File.read!("test/fixtures/mux/test_signing_private_key.pem"),
        webhook_tolerance_seconds: 300
      )
    )

    on_exit(fn -> Application.put_env(:rindle, Adapter, prev) end)

    :ok
  end

  defp fixture(name) do
    File.read!("test/fixtures/mux/#{name}") |> Jason.decode!()
  end

  test "capabilities/0 returns the closed v1.6 set (no :public_playback, no :direct_creator_upload)" do
    assert Adapter.capabilities() == [:signed_playback, :webhook_ingest, :server_push_ingest]
  end

  test "create_asset/3 sends PLURAL Mux keys and reshapes response with PLURAL playback_ids" do
    expect(ClientMock, :create_asset, fn params ->
      # D-04 memo correction: PLURAL keys at SDK boundary.
      assert params["inputs"] == [%{"url" => "https://signed.example/v.mp4"}]
      assert params["playback_policies"] == ["signed"]
      assert params["mp4_support"] == "standard"
      assert params["max_resolution_tier"] == "1080p"
      {:ok, fixture("asset_create_201.json")}
    end)

    # Phase 33 contract: playback_ids is a LIST of strings (matches schema field
    # `field :playback_ids, {:array, :string}`).
    assert {:ok, %{provider_asset_id: pid, playback_ids: playback_ids}} =
             Adapter.create_asset(TestProfile, "https://signed.example/v.mp4",
               playback_policy: :signed
             )

    assert is_binary(pid)
    assert is_list(playback_ids)
    assert [first | _] = playback_ids
    assert is_binary(first)
    assert first == "playback-id-test-fixture-1234"
  end

  test "create_asset/3 forwards :passthrough to the SDK request body (Phase 36 CR-01 cleanup contract)" do
    # The soak install-smoke lane sets `RINDLE_MUX_PASSTHROUGH_TAG=rindle_soak`
    # so every Mux asset created during the lane carries
    # `passthrough: "rindle_soak"`. The layer-3 cleanup script
    # (`scripts/mux_soak_cleanup.sh`) filters on the same field — this
    # regression locks the producer/cleanup tag agreement.
    expect(ClientMock, :create_asset, fn params ->
      assert params["passthrough"] == "rindle_soak"
      {:ok, fixture("asset_create_201.json")}
    end)

    assert {:ok, %{provider_asset_id: _, playback_ids: _}} =
             Adapter.create_asset(TestProfile, "https://signed.example/v.mp4",
               playback_policy: :signed,
               passthrough: "rindle_soak"
             )
  end

  test "create_asset/3 omits :passthrough when not supplied (default Mux request shape)" do
    expect(ClientMock, :create_asset, fn params ->
      refute Map.has_key?(params, "passthrough")
      {:ok, fixture("asset_create_201.json")}
    end)

    assert {:ok, _} = Adapter.create_asset(TestProfile, "https://signed.example/v.mp4")
  end

  test "create_asset/3 maps 429 to :provider_quota_exceeded" do
    expect(ClientMock, :create_asset, fn _params ->
      {:error, "rate_limited", %{status: 429, headers: [{"retry-after", "30"}]}}
    end)

    assert {:error, :provider_quota_exceeded} =
             Adapter.create_asset(TestProfile, "https://signed.example/v.mp4")
  end

  test "create_asset/3 maps 5xx to :provider_sync_failed" do
    expect(ClientMock, :create_asset, fn _params ->
      {:error, "boom", %{status: 503, headers: []}}
    end)

    assert {:error, :provider_sync_failed} =
             Adapter.create_asset(TestProfile, "https://signed.example/v.mp4")
  end

  test "create_asset_with_retry_hint/3 surfaces Retry-After to the worker on 429" do
    expect(ClientMock, :create_asset, fn _params ->
      {:error, "rate_limited", %{status: 429, headers: [{"retry-after", "30"}]}}
    end)

    assert {:error, :provider_quota_exceeded, 30} =
             Adapter.create_asset_with_retry_hint(
               TestProfile,
               "https://signed.example/v.mp4"
             )
  end

  test "create_asset_with_retry_hint/3 falls back to 60s when Retry-After missing" do
    expect(ClientMock, :create_asset, fn _params ->
      {:error, "rate_limited", %{status: 429, headers: []}}
    end)

    assert {:error, :provider_quota_exceeded, 60} =
             Adapter.create_asset_with_retry_hint(
               TestProfile,
               "https://signed.example/v.mp4"
             )
  end

  test "get_asset/1 reshapes Mux 200 to provider-event-style result" do
    expect(ClientMock, :get_asset, fn _id -> {:ok, fixture("asset_get_ready.json")} end)

    assert {:ok, %{state: "ready", playback_ids: [_ | _], raw: %{"id" => _}}} =
             Adapter.get_asset("AbCd1234EfGh5678IjKl9012MnOp3456QrSt")
  end

  test "get_asset/1 reshapes preparing-state response with state \"processing\"" do
    expect(ClientMock, :get_asset, fn _id -> {:ok, fixture("asset_get_processing.json")} end)

    assert {:ok, %{state: "processing", playback_ids: [_ | _]}} =
             Adapter.get_asset("AbCd1234EfGh5678IjKl9012MnOp3456QrSt")
  end

  test "get_asset/1 maps 404 to :not_found" do
    expect(ClientMock, :get_asset, fn _id ->
      {:error, "not_found", %{status: 404, headers: []}}
    end)

    assert {:error, :not_found} = Adapter.get_asset("nonexistent-id")
  end

  test "delete_asset/1 returns :ok on success" do
    expect(ClientMock, :delete_asset, fn _ -> :ok end)
    assert :ok = Adapter.delete_asset("AbCd1234EfGh5678IjKl9012MnOp3456QrSt")
  end

  test "delete_asset/1 is idempotent on 404 (Phase 33 contract)" do
    # The HTTP impl absorbs 404 to :ok internally; if a mock simulates the
    # post-HTTP shape directly with :ok, the adapter passes it through.
    expect(ClientMock, :delete_asset, fn _ -> :ok end)
    assert :ok = Adapter.delete_asset("already-gone")
  end

  test "verify_webhook/3 returns {:error, :provider_webhook_invalid} when no secret matches" do
    body = File.read!("test/fixtures/mux/webhook_video_asset_ready.json")
    headers = %{"mux-signature" => "t=#{System.system_time(:second)},v1=ffffffffff"}

    assert {:error, :provider_webhook_invalid} =
             Adapter.verify_webhook(body, headers, ["wrong-secret"])
  end

  test "verify_webhook/3 returns :provider_webhook_invalid when signature header missing" do
    body = File.read!("test/fixtures/mux/webhook_video_asset_ready.json")

    assert {:error, :provider_webhook_invalid} =
             Adapter.verify_webhook(body, %{}, ["any-secret"])
  end

  test "verify_webhook/3 verifies and normalizes when at least one secret matches" do
    secret = "test-webhook-secret"
    body = File.read!("test/fixtures/mux/webhook_video_asset_ready.json")

    # HMAC recipe centralized in Rindle.Test.MuxWebhookFixtures (D-34).
    headers = %{"mux-signature" => MuxWebhookFixtures.sign_header(body, secret)}

    # Multi-secret rotation: verify_webhook/3 loops the list and OR-s results.
    assert {:ok, %{type: :ready, provider_asset_id: _, state: "ready", playback_ids: [_ | _]}} =
             Adapter.verify_webhook(body, headers, ["wrong-secret-a", secret, "wrong-secret-c"])
  end

  # ===========================================================
  # BL-03 — Event.extract_playback_ids/1 must tolerate explicit null
  # ===========================================================

  describe "BL-03: Event.normalize/1 nil-safety on playback_ids" do
    alias Rindle.Streaming.Provider.Mux.Event

    test "normalizes a video.asset.created payload with playback_ids: null without crashing" do
      # Mux fires `video.asset.created` BEFORE transcoding completes, with an
      # explicit "playback_ids": null. The previous Map.get(data, "playback_ids", [])
      # shape returned nil (not the default) and Enum.map(nil, _) raised
      # Protocol.UndefinedError, taking down verify_webhook/3 in the wild.
      body = File.read!("test/fixtures/mux/webhook_video_asset_created.json")
      raw = Jason.decode!(body)

      assert {:ok, evt} = Event.normalize(raw)
      assert evt.type == :created
      assert evt.provider_asset_id == "00ecNLnqiG02mmQwOgcEeYQU3aAtqiHIyMb01YGKcrt017A"
      assert evt.state == "processing"
      assert evt.playback_ids == []
    end

    test "normalizes a payload with playback_ids: missing key as []" do
      raw = %{
        "type" => "video.asset.created",
        "data" => %{"id" => "asset-without-playback-key", "status" => "preparing"}
      }

      assert {:ok, %{playback_ids: []}} = Event.normalize(raw)
    end

    test "normalizes a payload with playback_ids: non-list value as []" do
      # Defensive: future Mux schema drift could produce a string or map here.
      raw = %{
        "type" => "video.asset.created",
        "data" => %{"id" => "x", "status" => "preparing", "playback_ids" => "weird"}
      }

      assert {:ok, %{playback_ids: []}} = Event.normalize(raw)
    end

    test "verify_webhook/3 successfully verifies + normalizes an asset.created payload with playback_ids: null" do
      secret = "test-webhook-secret"
      body = File.read!("test/fixtures/mux/webhook_video_asset_created.json")

      # HMAC recipe centralized in Rindle.Test.MuxWebhookFixtures (D-34).
      headers = %{"mux-signature" => MuxWebhookFixtures.sign_header(body, secret)}

      # End-to-end: previously this path raised Protocol.UndefinedError;
      # the regression locks in the {:ok, _} happy path.
      assert {:ok,
              %{
                type: :created,
                provider_asset_id: "00ecNLnqiG02mmQwOgcEeYQU3aAtqiHIyMb01YGKcrt017A",
                state: "processing",
                playback_ids: []
              }} = Adapter.verify_webhook(body, headers, [secret])
    end
  end

  # ===========================================================
  # WR-02 (POLISH-01/D-13) — case-insensitive signature header lookup
  # ===========================================================

  describe "WR-02: case-insensitive Mux-Signature header lookup (RFC 7230)" do
    test "verify_webhook/3 resolves a mixed-case `Mux-Signature` header" do
      secret = "test-webhook-secret"
      body = File.read!("test/fixtures/mux/webhook_video_asset_ready.json")

      # Title-case header — an edge proxy or adopter wrapper may emit any
      # casing. Pre-WR-02 the hardcoded "mux-signature" lookup would miss this
      # and reject a valid signature with {:error, :provider_webhook_invalid}.
      headers = %{"Mux-Signature" => MuxWebhookFixtures.sign_header(body, secret)}

      assert {:ok, %{type: :ready}} =
               Adapter.verify_webhook(body, headers, [secret])
    end

    test "verify_webhook/3 resolves an upper-case `MUX-SIGNATURE` header" do
      secret = "test-webhook-secret"
      body = File.read!("test/fixtures/mux/webhook_video_asset_ready.json")

      headers = %{"MUX-SIGNATURE" => MuxWebhookFixtures.sign_header(body, secret)}

      assert {:ok, %{type: :ready}} =
               Adapter.verify_webhook(body, headers, [secret])
    end
  end

  # ===========================================================
  # WR-05 (POLISH-01/D-13) — unknown Mux status -> nil + Logger.warning
  # ===========================================================

  describe "WR-05: normalize_state/1 allowlists known Mux statuses" do
    test "get_asset/1 maps an unknown status to nil and logs a warning" do
      import ExUnit.CaptureLog

      expect(ClientMock, :get_asset, fn _id ->
        {:ok, %{"id" => "asset-unknown-status", "status" => "transcoding", "playback_ids" => []}}
      end)

      {result, log} =
        with_log(fn -> Adapter.get_asset("asset-unknown-status") end)

      # Unknown status is treated as "ignore" (nil) rather than passed through
      # to the FSM, where it would burn retries on an invalid transition.
      assert {:ok, %{state: nil}} = result
      assert log =~ "rindle.mux.unknown_status"
    end

    test "get_asset/1 passes through preparing|ready|errored statuses" do
      for {mux_status, expected} <- [
            {"preparing", "processing"},
            {"ready", "ready"},
            {"errored", "errored"}
          ] do
        expect(ClientMock, :get_asset, fn _id ->
          {:ok, %{"id" => "asset-#{mux_status}", "status" => mux_status, "playback_ids" => []}}
        end)

        assert {:ok, %{state: ^expected}} = Adapter.get_asset("asset-#{mux_status}")
      end
    end
  end
end
