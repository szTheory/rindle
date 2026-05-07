defmodule Rindle.Streaming.Provider.Mux.TelemetryTest do
  @moduledoc """
  Cross-cutting telemetry-redaction parity test (security invariant 14, MUX-08).

  This is the phase-gate test for Phase 34: if any `[:rindle, :provider, _, _]`
  event leaks a raw `provider_asset_id` (any 20+ char alnum string instead of
  the last-4-char tag), this test fails and the phase does not ship.

  It also serves as the end-to-end integration smoke for the full ingest →
  sync → signed-URL flow.
  """

  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo
  import Mox

  alias Rindle.Domain.{MediaAsset, MediaProviderAsset, MediaVariant}
  alias Rindle.Streaming.Provider.Mux, as: Adapter
  alias Rindle.Streaming.Provider.Mux.ClientMock
  alias Rindle.Workers.{MuxIngestVariant, MuxSyncProviderAsset}

  setup :set_mox_from_context
  setup :verify_on_exit!

  @raw_id_regex ~r/^[A-Za-z0-9]{20,}$/
  @redacted_id_regex ~r/^\.\.\.[A-Za-z0-9]{4}$/

  defmodule TestProfile do
    @moduledoc false
    # Per Plan 01 deviation #1: Phase 33 DSL nests delivery TTL under `:delivery`;
    # top-level `signed_url_ttl_seconds:` and `streaming:` keys are invalid.
    # AV variant DSL `[kind: :video, preset: :web_720p]` validates through
    # `@video_variant_schema` (Phase 24 / AV-02).
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [hero: [kind: :video, preset: :web_720p]],
      allow_mime: ["video/mp4"],
      max_bytes: 524_288_000,
      delivery: [signed_url_ttl_seconds: 900]
  end

  @phase_34_events [
    [:rindle, :provider, :ingest, :start],
    [:rindle, :provider, :ingest, :stop],
    [:rindle, :provider, :ingest, :exception],
    [:rindle, :provider, :sync, :resolved],
    [:rindle, :provider, :sync, :stuck]
  ]

  setup do
    prev = Application.get_env(:rindle, Adapter, [])

    Application.put_env(
      :rindle,
      Adapter,
      Keyword.merge(prev,
        http_client: ClientMock,
        token_id: "test_id",
        token_secret: "test_secret",
        signing_key_id: "test_kid",
        signing_private_key: File.read!("test/fixtures/mux/test_signing_private_key.pem"),
        provider_polling_floor_seconds: 30,
        provider_stuck_threshold_seconds: 7200
      )
    )

    on_exit(fn -> Application.put_env(:rindle, Adapter, prev) end)

    # StorageMock stubs for Rindle.Delivery.url/3 used inside MuxIngestVariant.
    stub(Rindle.StorageMock, :capabilities, fn -> [:signed_url] end)

    stub(Rindle.StorageMock, :url, fn _key, opts ->
      {:ok, "https://signed.example/v.mp4?expires=#{Keyword.get(opts, :expires_in, 0)}"}
    end)

    asset_id = Ecto.UUID.generate()
    storage_key = "media/#{asset_id}/source.mp4"
    recipe_digest = "sha256:" <> String.duplicate("a", 64)

    # B3 fix: REAL MediaAsset schema fields — content_type (NOT mime), required kind.
    {:ok, asset} =
      %MediaAsset{}
      |> MediaAsset.changeset(%{
        id: asset_id,
        state: "ready",
        storage_key: storage_key,
        profile: to_string(TestProfile),
        kind: "video",
        content_type: "video/mp4",
        byte_size: 100_000
      })
      |> Repo.insert()

    # B3 fix: REAL MediaVariant schema fields — output_kind (NOT kind), required state.
    {:ok, variant} =
      %MediaVariant{}
      |> MediaVariant.changeset(%{
        asset_id: asset.id,
        name: "hero",
        state: "ready",
        recipe_digest: recipe_digest,
        storage_key: storage_key,
        output_kind: "video"
      })
      |> Repo.insert()

    args = %{
      "asset_id" => asset.id,
      "profile" => to_string(TestProfile),
      "variant_name" => "hero",
      "expected_storage_key" => storage_key,
      "expected_recipe_digest" => recipe_digest
    }

    test_pid = self()
    handler_id = "phase34-telemetry-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      @phase_34_events,
      fn evt, measurements, metadata, _ ->
        send(test_pid, {:tele, evt, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    %{asset: asset, variant: variant, args: args, handler_id: handler_id}
  end

  defp fixture(name), do: File.read!("test/fixtures/mux/#{name}") |> Jason.decode!()

  defp drain_telemetry(acc \\ []) do
    receive do
      {:tele, _, _, _} = msg -> drain_telemetry([msg | acc])
    after
      100 -> Enum.reverse(acc)
    end
  end

  # ===========================================================
  # CROSS-CUTTING PARITY — SECURITY INVARIANT 14
  # ===========================================================
  # This test is the phase-gate. If it fails, Phase 34 does not ship.

  test "every Phase 34 telemetry event redacts asset_id (no raw provider_asset_id leaks)",
       ctx do
    expect(ClientMock, :create_asset, fn _params -> {:ok, fixture("asset_create_201.json")} end)

    # Drive the ingest path — emits :start and :stop.
    assert :ok = perform_job(MuxIngestVariant, ctx.args)

    # Drive the sync path with a :ready response — emits :resolved.
    row =
      Repo.get_by!(MediaProviderAsset,
        asset_id: ctx.asset.id,
        profile: to_string(TestProfile),
        provider_name: "mux"
      )

    expect(ClientMock, :get_asset, fn _id ->
      {:ok,
       %{
         "id" => row.provider_asset_id,
         "status" => "ready",
         "playback_ids" => [%{"id" => "pb-id-test", "policy" => "signed"}]
       }}
    end)

    assert :ok =
             perform_job(MuxSyncProviderAsset, %{
               "provider_asset_id" => row.provider_asset_id
             })

    events = drain_telemetry()

    assert length(events) >= 3,
           "Expected at least 3 events; got #{length(events)} — pipeline may not be emitting"

    Enum.each(events, fn {:tele, event_name, _measurements, metadata} ->
      asset_id = metadata[:asset_id]

      # asset_id is allowed to be nil (e.g., :start before Mux response known) OR
      # the redacted last-4-char tag. It MUST NOT be a raw provider id.
      assert asset_id == nil or asset_id =~ @redacted_id_regex,
             """
             SECURITY INVARIANT 14 VIOLATION on event #{inspect(event_name)}.
             Expected nil or "...XXXX" (last-4-char tag); got #{inspect(asset_id)}.
             Every telemetry emit must call MediaProviderAsset.redact_id/1 before
             metadata reaches :telemetry.execute/3.
             """

      if is_binary(asset_id) do
        refute asset_id =~ @raw_id_regex,
               """
               SECURITY INVARIANT 14 VIOLATION on event #{inspect(event_name)}.
               asset_id #{inspect(asset_id)} matches the raw-id regex (20+ alnum chars).
               Provider asset ids must never cross telemetry boundary unredacted.
               """
      end
    end)
  end

  # ===========================================================
  # END-TO-END SMOKE: ingest → sync → signed playback URL
  # ===========================================================

  test "full pipeline: ingest variant, sync to ready, mint signed playback URL", ctx do
    expect(ClientMock, :create_asset, fn _params -> {:ok, fixture("asset_create_201.json")} end)

    # 1. Ingest
    assert :ok = perform_job(MuxIngestVariant, ctx.args)

    row =
      Repo.get_by!(MediaProviderAsset,
        asset_id: ctx.asset.id,
        profile: to_string(TestProfile),
        provider_name: "mux"
      )

    assert row.state == "processing"
    assert is_binary(row.provider_asset_id)
    # B1 fix: playback_ids is a PLURAL ARRAY (Phase 33 schema field).
    assert is_list(row.playback_ids)
    assert [first_playback_id | _] = row.playback_ids
    assert is_binary(first_playback_id)

    # 2. Simulate sync to ready (would also be webhook-driven in Phase 35)
    expect(ClientMock, :get_asset, fn _id ->
      {:ok,
       %{
         "id" => row.provider_asset_id,
         "status" => "ready",
         "playback_ids" => [%{"id" => first_playback_id, "policy" => "signed"}]
       }}
    end)

    assert :ok =
             perform_job(MuxSyncProviderAsset, %{
               "provider_asset_id" => row.provider_asset_id
             })

    ready = Repo.get!(MediaProviderAsset, row.id)
    assert ready.state == "ready"
    # B1 fix: read from PLURAL `playback_ids` list, not singular column.
    assert is_list(ready.playback_ids)
    [ready_first_id | _] = ready.playback_ids

    # 3. Sign a playback URL — JWT exp claim must respect profile TTL (Pitfall 1 guard).
    before_unix = DateTime.utc_now() |> DateTime.to_unix()

    # B1 fix: signed_playback_url/3 takes ONE playback_id; extract via List.first.
    assert {:ok, %{url: url, kind: :hls, mime: "application/vnd.apple.mpegurl"}} =
             Adapter.signed_playback_url(TestProfile, ready_first_id)

    %{"token" => jwt} = url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

    # Simplified JWT payload extraction.
    fields = jwt |> JOSE.JWT.peek_payload() |> Map.fetch!(:fields)
    exp = fields["exp"]

    ttl = Rindle.Delivery.signed_url_ttl_seconds(TestProfile)
    assert_in_delta exp, before_unix + ttl, 5

    refute exp > before_unix + 604_800,
           "JWT exp suggests SDK 7-day default leaked through (Pitfall 1)"

    # 4. JWT verifies against test signing-key fixture's public half.
    public_jwk =
      "test/fixtures/mux/test_signing_private_key.pem"
      |> File.read!()
      |> JOSE.JWK.from_pem()
      |> JOSE.JWK.to_public()

    assert {true, _payload, _jws} = JOSE.JWT.verify_strict(public_jwk, ["RS256"], jwt)
  end

  # ===========================================================
  # Documented schema parity — every event has the keys we promise
  # ===========================================================

  test ":ingest events expose documented measurement + metadata keys", ctx do
    expect(ClientMock, :create_asset, fn _params -> {:ok, fixture("asset_create_201.json")} end)

    assert :ok = perform_job(MuxIngestVariant, ctx.args)

    events = drain_telemetry()

    start_event =
      Enum.find(events, &match?({:tele, [:rindle, :provider, :ingest, :start], _, _}, &1))

    assert start_event, "Expected :start event"
    {:tele, _, measurements, metadata} = start_event
    assert is_integer(measurements[:system_time])
    assert metadata[:provider] == :mux
    assert metadata[:profile] == TestProfile
    assert metadata[:variant_name] == "hero"

    stop_event =
      Enum.find(events, &match?({:tele, [:rindle, :provider, :ingest, :stop], _, _}, &1))

    assert stop_event, "Expected :stop event"
    {:tele, _, measurements, _metadata} = stop_event
    assert is_integer(measurements[:system_time])
    assert is_integer(measurements[:duration])
  end

  test ":sync events expose documented measurement + metadata keys", ctx do
    # B2/W1 fix: NO :variant_name in changeset attrs (no such column).
    {:ok, row} =
      %MediaProviderAsset{}
      |> MediaProviderAsset.changeset(%{
        asset_id: ctx.asset.id,
        profile: to_string(TestProfile),
        provider_name: "mux",
        playback_policy: "signed",
        provider_asset_id: "AbCd1234EfGh5678IjKl9012MnOp3456QrSt",
        state: "processing"
      })
      |> Repo.insert()

    expect(ClientMock, :get_asset, fn _id ->
      {:ok, %{"id" => row.provider_asset_id, "status" => "ready", "playback_ids" => []}}
    end)

    assert :ok =
             perform_job(MuxSyncProviderAsset, %{
               "provider_asset_id" => row.provider_asset_id
             })

    events = drain_telemetry()

    resolved =
      Enum.find(events, &match?({:tele, [:rindle, :provider, :sync, :resolved], _, _}, &1))

    assert resolved, "Expected :resolved event"

    {:tele, _, measurements, metadata} = resolved
    assert is_integer(measurements[:system_time])
    assert metadata[:provider] == :mux
    assert metadata[:profile] == TestProfile
    assert is_binary(metadata[:provider_state])
    assert is_integer(metadata[:age_ms])
  end
end
