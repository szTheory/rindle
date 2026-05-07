---
phase: 34-mux-rest-adapter-server-push-sync
plan: 04
type: execute
wave: 3
depends_on: [34-01, 34-02, 34-03]
autonomous: true
requirements: [MUX-08]
files_modified:
  - lib/rindle/streaming/provider/mux.ex
  - lib/rindle/workers/mux_ingest_variant.ex
  - lib/rindle/workers/mux_sync_coordinator.ex
  - lib/rindle/workers/mux_sync_provider_asset.ex
  - test/rindle/streaming/provider/mux/telemetry_test.exs

must_haves:
  truths:
    - "Every `[:rindle, :provider, :ingest, _]` and `[:rindle, :provider, :sync, _]` event emitted across the full Phase 34 surface (Plans 01-03) carries `metadata.asset_id` matching `~r/^\\.\\.\\.[A-Za-z0-9]{4}$/` — never a raw 30+ char `provider_asset_id` (security invariant 14)."
    - "The telemetry contract is documented in adapter and worker `@moduledoc` blocks: every event family lists the `measurements` keys, the `metadata` keys, and which keys are redacted."
    - "Dialyzer PLT regenerated with `:mux` and `:jose` (PLT add_apps from Plan 01) and `mix dialyzer` exits 0 across the full Mux subsystem."
    - "End-to-end integration smoke: enqueue a `MuxIngestVariant` with valid args + Mox cassette → row reaches `:processing` with PLURAL `playback_ids` populated → simulated webhook (or per-row `MuxSyncProviderAsset` against a `:ready` cassette) flips the row to `:ready` → `signed_playback_url/3` (called with `List.first(row.playback_ids)`) returns a JWT verifiable against the test signing-key fixture (TTL respects profile policy)."
  artifacts:
    - path: "test/rindle/streaming/provider/mux/telemetry_test.exs"
      provides: "Cross-cutting redaction-parity test (security invariant 14) + end-to-end ingest→sync→signed-URL smoke"
      min_lines: 120
    - path: "lib/rindle/streaming/provider/mux.ex"
      provides: "Updated @moduledoc documenting telemetry contract emitted by Plan 02/03 workers"
      contains: "[:rindle, :provider, :ingest"
    - path: "lib/rindle/workers/mux_ingest_variant.ex"
      provides: "Updated @moduledoc with telemetry-redaction note (already added in Plan 02 — Plan 04 verifies)"
      contains: "redact_id"
    - path: "lib/rindle/workers/mux_sync_provider_asset.ex"
      provides: "@moduledoc updated to document `[:rindle, :provider, :sync, :resolved | :stuck]` schemas"
      contains: ":resolved"
  key_links:
    - from: "test/rindle/streaming/provider/mux/telemetry_test.exs"
      to: "All five Plan 02/03 telemetry events"
      via: ":telemetry.attach_many on every [:rindle, :provider, _, _] event"
      pattern: "attach_many"
    - from: "lib/rindle/streaming/provider/mux.ex (moduledoc)"
      to: "Adopter telemetry-handler authoring guide (Phase 36)"
      via: "Documented event-shape schemas — single source of truth for adopter telemetry"
      pattern: "## Telemetry"
---

<objective>
Close Phase 34 with the cross-cutting telemetry-redaction parity test
(security invariant 14, MUX-08), `@moduledoc` documentation of the
telemetry contract on every emit-site module, Dialyzer PLT regeneration
with `:mux` and `:jose`, and an end-to-end integration smoke test
covering the full ingest → sync → signed-URL flow.

Purpose: Plans 01-03 each test their own slice of the telemetry contract.
Plan 04 is the cross-cutting parity check — a single ExUnit test that
attaches a handler to *every* `[:rindle, :provider, _, _]` event family,
drives a 720p sample through the worker pipeline (with Mox cassettes),
and asserts that NO event leaks a raw `provider_asset_id`. This test is
the highest-leverage security-invariant-14 enforcement and the single
phase-gate "if it doesn't pass, the phase doesn't ship" check.

Output: 1 new test file, `@moduledoc` extensions on adapter + 3 workers,
Dialyzer PLT regen completed, full Phase 34 test bundle green.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/34-mux-rest-adapter-server-push-sync/34-CONTEXT.md
@.planning/phases/34-mux-rest-adapter-server-push-sync/34-RESEARCH.md
@.planning/phases/34-mux-rest-adapter-server-push-sync/34-PATTERNS.md
@.planning/phases/34-mux-rest-adapter-server-push-sync/34-VALIDATION.md
@.planning/phases/34-mux-rest-adapter-server-push-sync/34-01-SUMMARY.md
@.planning/phases/34-mux-rest-adapter-server-push-sync/34-02-SUMMARY.md
@.planning/phases/34-mux-rest-adapter-server-push-sync/34-03-SUMMARY.md

@lib/rindle/streaming/provider/mux.ex
@lib/rindle/workers/mux_ingest_variant.ex
@lib/rindle/workers/mux_sync_coordinator.ex
@lib/rindle/workers/mux_sync_provider_asset.ex
@lib/rindle/domain/media_asset.ex
@lib/rindle/domain/media_variant.ex
@lib/rindle/domain/media_provider_asset.ex

<interfaces>
<!-- Telemetry contract (D-26 verbatim) — single source of truth doc -->
```
[:rindle, :provider, :ingest, :start | :stop | :exception]
  measurements: %{system_time, duration?}
  metadata:     %{profile, provider, asset_id, variant_name, kind?, reason?}
                # asset_id REDACTED via MediaProviderAsset.redact_id/1 (last-4 char tag)
                # kind: :error | :cancelled  (only on :exception events)

[:rindle, :provider, :sync, :resolved | :stuck]
  measurements: %{system_time}
  metadata:     %{profile, provider, asset_id, provider_state, age_ms}
                # asset_id REDACTED

# NOT in Phase 34 (Phase 35 wires up):
[:rindle, :provider, :webhook, :received | :verified | :rejected]
```

<!-- Existing v1.4-stable event (already fires from Phase 33 dispatch — Phase 34 confirms unchanged) -->
```
[:rindle, :delivery, :streaming, :resolved]
  metadata: %{profile, kind: :hls}  # Phase 33 already emits this when adapter signs URL
```

<!-- REAL schema field names (Plan 04 test setup must match) -->
<!-- MediaAsset (lib/rindle/domain/media_asset.ex): -->
<!--   field :content_type (NOT mime), validate_required([:state, :storage_key, :profile, :kind]) -->
<!-- MediaVariant (lib/rindle/domain/media_variant.ex): -->
<!--   field :output_kind (NOT kind), validate_required([:asset_id, :name, :state, :recipe_digest, :output_kind]) -->
<!-- MediaProviderAsset (lib/rindle/domain/media_provider_asset.ex): -->
<!--   field :playback_ids (PLURAL ARRAY), no :variant_name column -->
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Cross-cutting redaction-parity + end-to-end smoke test</name>
  <files>test/rindle/streaming/provider/mux/telemetry_test.exs</files>
  <read_first>
    - lib/rindle/streaming/provider/mux.ex (Plan 01 — adapter + http_client/0 accessor)
    - lib/rindle/workers/mux_ingest_variant.ex (Plan 02 — emits :ingest events)
    - lib/rindle/workers/mux_sync_provider_asset.ex (Plan 03 — emits :sync events)
    - lib/rindle/domain/media_asset.ex (REAL field names: `content_type`, NOT `mime`)
    - lib/rindle/domain/media_variant.ex (REAL field names: `output_kind`, NOT `kind`)
    - lib/rindle/domain/media_provider_asset.ex (REAL field: `playback_ids` PLURAL ARRAY; no `variant_name` column)
    - test/rindle/streaming/provider/mux/mux_test.exs (Plan 01 — Mox setup pattern)
    - test/rindle/workers/mux_ingest_variant_test.exs (Plan 02 — TestProfile + ctx setup using REAL schema fields)
    - .planning/phases/34-mux-rest-adapter-server-push-sync/34-RESEARCH.md "Validation Architecture" section (cross-cutting parity test paragraph) + Pitfall 5
    - .planning/phases/34-mux-rest-adapter-server-push-sync/34-VALIDATION.md per-task verification map (MUX-08 row + cross-cutting parity paragraph)
  </read_first>
  <action>
Create `test/rindle/streaming/provider/mux/telemetry_test.exs`:

B3 fix applies here — the test setup must use REAL schema field names:
  - `MediaAsset`: `content_type` (NOT `mime`), required `kind`
  - `MediaVariant`: `output_kind` (NOT `kind`), required `state`
B1 fix applies here — `playback_ids` is a PLURAL ARRAY; signed-URL minting
must call `List.first(row.playback_ids)` to extract a single id for the URL.

```elixir
defmodule Rindle.Streaming.Provider.Mux.TelemetryTest do
  @moduledoc """
  Cross-cutting telemetry-redaction parity test (security invariant 14, MUX-08).

  This is the phase-gate test for Phase 34: if any `[:rindle, :provider, _, _]`
  event leaks a raw `provider_asset_id` (any 30+ char string instead of the
  last-4-char tag), this test fails and the phase does not ship.

  It also serves as the end-to-end integration smoke for the full ingest →
  sync → signed-URL flow.
  """

  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo
  import Mox

  alias Rindle.Domain.{MediaAsset, MediaVariant, MediaProviderAsset}
  alias Rindle.Workers.{MuxIngestVariant, MuxSyncProviderAsset}
  alias Rindle.Streaming.Provider.Mux, as: Adapter
  alias Rindle.Streaming.Provider.Mux.ClientMock

  setup :set_mox_from_context
  setup :verify_on_exit!

  @raw_id_regex ~r/^[A-Za-z0-9]{20,}$/   # 20+ alnum chars = strong signal of raw provider id
  @redacted_id_regex ~r/^\.\.\.[A-Za-z0-9]{4}$/

  defmodule TestProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      streaming: Rindle.Streaming.Provider.Mux,
      signed_url_ttl_seconds: 900,
      variants: [hero: [kind: :video, preset: :web_720p]],
      allow_mime: ["video/mp4"],
      max_bytes: 524_288_000
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

    Application.put_env(:rindle, Adapter,
      Keyword.merge(prev, [
        http_client: ClientMock,
        token_id: "test_id",
        token_secret: "test_secret",
        signing_key_id: "test_kid",
        signing_private_key: File.read!("test/fixtures/mux/test_signing_private_key.pem"),
        provider_polling_floor_seconds: 30,
        provider_stuck_threshold_seconds: 7200
      ])
    )

    on_exit(fn -> Application.put_env(:rindle, Adapter, prev) end)

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
        asset_id: asset_id,
        name: "hero",
        state: "ready",
        recipe_digest: recipe_digest,
        storage_key: storage_key,
        output_kind: "video"
      })
      |> Repo.insert()

    args = %{
      "asset_id" => asset_id,
      "profile" => to_string(TestProfile),
      "variant_name" => "hero",
      "expected_storage_key" => storage_key,
      "expected_recipe_digest" => recipe_digest
    }

    test_pid = self()
    handler_id = "phase34-telemetry-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(handler_id, @phase_34_events,
      fn evt, measurements, metadata, _ -> send(test_pid, {:tele, evt, measurements, metadata}) end,
      nil)

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

  test "every Phase 34 telemetry event redacts asset_id (no raw provider_asset_id leaks)", ctx do
    expect(ClientMock, :create_asset, fn _params -> {:ok, fixture("asset_create_201.json")} end)

    # Drive the ingest path — emits :start and :stop.
    assert :ok = perform_job(MuxIngestVariant, ctx.args)

    # Drive the sync path with a :ready response — emits :resolved.
    row =
      Repo.get_by!(MediaProviderAsset,
        asset_id: ctx.asset.id,
        profile: to_string(TestProfile)
      )

    expect(ClientMock, :get_asset, fn _id ->
      {:ok, %{
        "id" => row.provider_asset_id,
        "status" => "ready",
        "playback_ids" => [%{"id" => "pb-id-test", "policy" => "signed"}]
      }}
    end)

    assert :ok = perform_job(MuxSyncProviderAsset, %{"provider_asset_id" => row.provider_asset_id})

    events = drain_telemetry()
    assert length(events) >= 3, "Expected ≥3 events; got #{length(events)} — pipeline may not be emitting"

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
        profile: to_string(TestProfile)
      )

    assert row.state == "processing"
    assert is_binary(row.provider_asset_id)
    # B1 fix: playback_ids is a PLURAL ARRAY (Phase 33 schema field).
    assert is_list(row.playback_ids)
    assert [first_playback_id | _] = row.playback_ids
    assert is_binary(first_playback_id)

    # 2. Simulate sync to ready (would also be webhook-driven in Phase 35)
    expect(ClientMock, :get_asset, fn _id ->
      {:ok, %{
        "id" => row.provider_asset_id,
        "status" => "ready",
        "playback_ids" => [%{"id" => first_playback_id, "policy" => "signed"}]
      }}
    end)

    assert :ok = perform_job(MuxSyncProviderAsset, %{"provider_asset_id" => row.provider_asset_id})

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

    # W4-equivalent: simplified JWT payload extraction.
    fields = jwt |> JOSE.JWT.peek_payload() |> Map.fetch!(:fields)
    exp = fields["exp"]

    ttl = Rindle.Delivery.signed_url_ttl_seconds(TestProfile)
    assert_in_delta exp, before_unix + ttl, 5
    refute exp > before_unix + 604_800, "JWT exp suggests SDK 7-day default leaked through (Pitfall 1)"

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

    start_event = Enum.find(events, &match?({:tele, [:rindle, :provider, :ingest, :start], _, _}, &1))
    assert start_event, "Expected :start event"
    {:tele, _, measurements, metadata} = start_event
    assert is_integer(measurements[:system_time])
    assert metadata[:provider] == :mux
    assert metadata[:profile] == TestProfile
    assert metadata[:variant_name] == "hero"

    stop_event = Enum.find(events, &match?({:tele, [:rindle, :provider, :ingest, :stop], _, _}, &1))
    assert stop_event, "Expected :stop event"
    {:tele, _, measurements, _metadata} = stop_event
    assert is_integer(measurements[:system_time])
    assert is_integer(measurements[:duration])
  end

  test ":sync events expose documented measurement + metadata keys", ctx do
    # Set up: insert a provider row directly + drive sync.
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

    assert :ok = perform_job(MuxSyncProviderAsset, %{"provider_asset_id" => row.provider_asset_id})

    events = drain_telemetry()
    resolved = Enum.find(events, &match?({:tele, [:rindle, :provider, :sync, :resolved], _, _}, &1))
    assert resolved, "Expected :resolved event"

    {:tele, _, measurements, metadata} = resolved
    assert is_integer(measurements[:system_time])
    assert metadata[:provider] == :mux
    assert metadata[:profile] == TestProfile
    assert is_binary(metadata[:provider_state])
    assert is_integer(metadata[:age_ms])
  end
end
```

Run `mix test test/rindle/streaming/provider/mux/telemetry_test.exs --max-failures 1` after writing the file.
  </action>
  <verify>
    <automated>mix test test/rindle/streaming/provider/mux/telemetry_test.exs --max-failures 1 2>&1 | tail -30</automated>
  </verify>
  <acceptance_criteria>
    - File exists at `test/rindle/streaming/provider/mux/telemetry_test.exs`
    - File contains `@phase_34_events` list with all five events: `:ingest, :start | :stop | :exception` and `:sync, :resolved | :stuck`
    - File contains `@redacted_id_regex ~r/^\.\.\.[A-Za-z0-9]{4}$/` and `@raw_id_regex ~r/^[A-Za-z0-9]{20,}$/`
    - File contains test "every Phase 34 telemetry event redacts asset_id (no raw provider_asset_id leaks)" — the cross-cutting parity test
    - File contains test "full pipeline: ingest variant, sync to ready, mint signed playback URL" — the end-to-end smoke
    - File asserts `is_list(row.playback_ids)` and `[first_playback_id | _] = row.playback_ids` (B1 fix — PLURAL field assertion)
    - File calls `Adapter.signed_playback_url(TestProfile, ready_first_id)` where `ready_first_id` came from `List.first/hd` of the PLURAL list (B1)
    - File `MediaAsset.changeset(%{...})` test setup uses `content_type: "video/mp4"` (NOT `mime:`) and `kind: "video"` (B3)
    - File `MediaVariant.changeset(%{...})` test setup uses `output_kind: "video"` (NOT `kind:`) and `state: "ready"` (B3)
    - File `MediaProviderAsset.changeset(%{...})` test setup does NOT include `variant_name:` (B2/W1)
    - File asserts `refute exp > before_unix + 604_800` (Pitfall 1 — 7-day-footgun guard, again, in the smoke flow)
    - File asserts `JOSE.JWT.verify_strict(public_jwk, ["RS256"], jwt)` returns `{true, _, _}`
    - `mix test test/rindle/streaming/provider/mux/telemetry_test.exs --max-failures 1` exits 0
  </acceptance_criteria>
  <done>The cross-cutting redaction-parity test is the phase-gate; end-to-end smoke confirms the full ingest → sync → signed-URL pipeline works against Mox cassettes using REAL Phase 33 schema fields and PLURAL playback_ids; both tests are green.</done>
</task>

<task type="auto">
  <name>Task 2a: @moduledoc telemetry contract on adapter + workers</name>
  <files>lib/rindle/streaming/provider/mux.ex, lib/rindle/workers/mux_ingest_variant.ex, lib/rindle/workers/mux_sync_coordinator.ex, lib/rindle/workers/mux_sync_provider_asset.ex</files>
  <read_first>
    - lib/rindle/streaming/provider/mux.ex (current `@moduledoc` from Plan 01)
    - lib/rindle/workers/mux_ingest_variant.ex (current `@moduledoc` from Plan 02)
    - lib/rindle/workers/mux_sync_coordinator.ex (current `@moduledoc` from Plan 03)
    - lib/rindle/workers/mux_sync_provider_asset.ex (currently `@moduledoc false` — Plan 03; this task promotes to documented)
    - .planning/phases/34-mux-rest-adapter-server-push-sync/34-CONTEXT.md decisions D-26, D-27, D-28, D-41 (no separate guides; inline @moduledoc only)
  </read_first>
  <action>
W2 fix: this task does ONLY the @moduledoc edits. Dialyzer regen and the
full-suite gate are split into Tasks 2b and 2c.

**1. Extend `lib/rindle/streaming/provider/mux.ex` `@moduledoc` (after the existing DSL ↔ REST translation paragraph):**

Append (within the existing `@moduledoc`):
```
## Telemetry Contract

The adapter and its companion workers emit the following events. All
events with `metadata.asset_id` redact the value to its last-4-char tag
(`"...abcd"`) via `Rindle.Domain.MediaProviderAsset.redact_id/1`
(security invariant 14). Adopters writing telemetry handlers MUST treat
`asset_id` as a redacted identifier — it is not a stable correlation key.

  * `[:rindle, :provider, :ingest, :start | :stop | :exception]` — emitted
    by `Rindle.Workers.MuxIngestVariant` (Phase 34).
    - measurements: `%{system_time, duration?}` (`duration` only on `:stop`/`:exception`)
    - metadata: `%{profile, provider, asset_id, variant_name, kind?, reason?}`
    - `kind: :error | :cancelled` is added on `:exception` to distinguish
      genuine errors (`{:error, _}`) from atomic-promote cancellations
      (`{:cancel, {:stale_source, _}}`).

  * `[:rindle, :provider, :sync, :resolved | :stuck]` — emitted by
    `Rindle.Workers.MuxSyncProviderAsset` (Phase 34).
    - measurements: `%{system_time}`
    - metadata: `%{profile, provider, asset_id, provider_state, age_ms}`
    - `:stuck` fires when a row in `:processing`/`:uploading` exceeds
      `:provider_stuck_threshold_seconds` (default 7200).

  * `[:rindle, :delivery, :streaming, :resolved]` — already shipped by
    Phase 33's `dispatch_streaming/4`. No new event from Phase 34 on this
    path; the metadata extension is the documented v1.4-contract addition.

Phase 35 will add `[:rindle, :provider, :webhook, _]` events. Phase 34
does not emit them.
```

**2. Confirm `lib/rindle/workers/mux_ingest_variant.ex` `@moduledoc` already documents the contract (from Plan 02). If the existing block is missing the `kind?` clarification, add a short note:**

```
## Telemetry — kind metadata

`[:rindle, :provider, :ingest, :exception]` events carry an additional
`metadata.kind` key:

  * `:cancelled` — atomic-promote race aborted the job (`{:cancel, ...}`)
  * `:error` — a genuine failure (`{:error, _}`)

Adopters can route the two cases differently in their handlers.
```

**3. `lib/rindle/workers/mux_sync_provider_asset.ex` is currently `@moduledoc false` (Plan 03). Promote to documented `@moduledoc` since Phase 36 will publish this:**

Replace `@moduledoc false` with:
```
@moduledoc """
Per-row defensive sync for `media_provider_assets` rows that may have
missed a webhook. Called by `Rindle.Workers.MuxSyncCoordinator` (Phase 34
ships the cron coordinator; Phase 35 wires up webhook-driven sync).

## Job Arguments

    %{"provider_asset_id" => mux_asset_id}

## Telemetry Contract

  * `[:rindle, :provider, :sync, :resolved]` — fires on every successful
    `get_asset/1` call (whether or not a state change occurred).
    measurements: %{system_time}
    metadata:     %{profile, provider, asset_id, provider_state, age_ms}

  * `[:rindle, :provider, :sync, :stuck]` — fires when the row's
    `updated_at` exceeds `provider_stuck_threshold_seconds` (default 7200).
    Same metadata shape; `provider_state` reflects the row's final
    `:errored` state.

`metadata.asset_id` is the redacted last-4-char tag of the
`provider_asset_id` (security invariant 14, via
`Rindle.Domain.MediaProviderAsset.redact_id/1`).
"""
```

**4. Confirm `lib/rindle/workers/mux_sync_coordinator.ex` `@moduledoc` from Plan 03 already covers the cron snippet — no change needed unless the existing text is missing the `Adopter telemetry note: this worker emits no telemetry; per-row sync emits :resolved/:stuck.` paragraph. If missing, append within the existing `@moduledoc`:**

```
## Telemetry

This worker emits NO `[:rindle, :provider, :sync, _]` events itself —
the per-row `Rindle.Workers.MuxSyncProviderAsset` worker is the source
of truth for telemetry. The coordinator logs structured events under
`Logger.info("rindle.workers.mux_sync_coordinator.completed", ...)` for
operator visibility.
```

After the four edits run `mix compile --warnings-as-errors` to confirm the moduledoc edits do not introduce syntax errors.
  </action>
  <verify>
    <automated>mix compile --warnings-as-errors 2>&1 | tail -10 && grep -c "## Telemetry Contract" lib/rindle/streaming/provider/mux.ex && grep -c "## Telemetry" lib/rindle/workers/mux_sync_provider_asset.ex && grep -c "@moduledoc false" lib/rindle/workers/mux_sync_provider_asset.ex</automated>
  </verify>
  <acceptance_criteria>
    - `lib/rindle/streaming/provider/mux.ex` `@moduledoc` contains `## Telemetry Contract` heading
    - `lib/rindle/streaming/provider/mux.ex` `@moduledoc` documents both `[:rindle, :provider, :ingest, _]` and `[:rindle, :provider, :sync, _]` event families with measurements + metadata keys
    - `lib/rindle/workers/mux_sync_provider_asset.ex` no longer has `@moduledoc false` — replaced with full docstring documenting the telemetry contract
    - `grep -c "@moduledoc false" lib/rindle/workers/mux_sync_provider_asset.ex` returns 0
    - `mix compile --warnings-as-errors` exits 0
  </acceptance_criteria>
  <done>Telemetry contract is documented in every emit-site `@moduledoc`; no `@moduledoc false` left on the published per-row sync worker; compilation clean.</done>
</task>

<task type="auto">
  <name>Task 2b: Dialyzer PLT regen + dialyzer run</name>
  <files></files>
  <read_first>
    - mix.exs (Plan 01 added `:mux` and `:jose` to `dialyzer.plt_add_apps`)
  </read_first>
  <action>
W2 fix: regenerate Dialyzer PLT (with the `:mux` and `:jose` apps added in
Plan 01) and run Dialyzer on the full Mux subsystem. The PLT regen is
~2-5 minutes — run it as a foreground command in this task; nothing else
in this task depends on it.

```bash
mix dialyzer --plt 2>&1 | tail -20
mix dialyzer 2>&1 | tail -50
```

After completion, `mix dialyzer` should exit 0 with no new warnings on
the Mux subsystem files. Phase 34 PLT additions are `:mux` and `:jose`
per Plan 01 / D-02.

If `mix dialyzer` reports `:none_callback` or `:contract_supertype`
warnings on the Mux subsystem, those indicate Plan 01-03 type drift —
fix the offending file (NOT this task's scope) and re-run before
proceeding to Task 2c.
  </action>
  <verify>
    <automated>mix dialyzer 2>&1 | tail -30 ; echo "EXIT=$?"</automated>
  </verify>
  <acceptance_criteria>
    - `mix dialyzer --plt` regen completes without crash
    - `mix dialyzer` exits 0 (no new warnings after PLT regen with `:mux`/`:jose`)
    - No `:none_callback` warnings on `lib/rindle/streaming/provider/mux*` or `lib/rindle/workers/mux_*` files
  </acceptance_criteria>
  <done>PLT regenerated with Phase 34 apps; Dialyzer clean across the Mux subsystem.</done>
</task>

<task type="auto">
  <name>Task 2c: Full Phase 34 test bundle + Credo gate</name>
  <files></files>
  <read_first>
    - .planning/phases/34-mux-rest-adapter-server-push-sync/34-VALIDATION.md (per-task verification map — confirms which tests gate the phase)
  </read_first>
  <action>
W2 fix: run the full Phase 34 test bundle and the full repo suite + Credo
strict. This is the phase gate — if any of these fails, Phase 34 does
NOT ship and a revision iteration is required.

**1. Full Phase 34 test bundle:**
```bash
mix test test/rindle/streaming/provider/mux/ \
         test/rindle/workers/mux_ingest_variant_test.exs \
         test/rindle/workers/mux_sync_coordinator_test.exs \
         test/rindle/workers/mux_sync_provider_asset_test.exs \
         --max-failures 1
```
Expected: 0 failures across all 7 test files (`optional_dep_test`,
`mux_test`, `signed_playback_url_test`, `telemetry_test`,
`mux_ingest_variant_test`, `mux_sync_coordinator_test`,
`mux_sync_provider_asset_test`).

**2. Full repo suite (regression check):**
```bash
mix test --max-failures 1
```
Expected: 0 failures. Phase 34 is purely additive — no existing test
should break.

**3. Credo strict:**
```bash
mix credo --strict 2>&1 | tail -20
```
Expected: 0 new issues on Phase 34 files.
  </action>
  <verify>
    <automated>mix test test/rindle/streaming/provider/mux/ test/rindle/workers/mux_ingest_variant_test.exs test/rindle/workers/mux_sync_coordinator_test.exs test/rindle/workers/mux_sync_provider_asset_test.exs --max-failures 1 2>&1 | tail -10 && mix test --max-failures 1 2>&1 | tail -10 && mix credo --strict 2>&1 | tail -20</automated>
  </verify>
  <acceptance_criteria>
    - All 7 Phase 34 test files pass (`mix test test/rindle/streaming/provider/mux/ test/rindle/workers/mux_*_test.exs --max-failures 1` exits 0)
    - Full repo `mix test --max-failures 1` exits 0 (no regressions)
    - `mix credo --strict` reports 0 new issues on Phase 34 files
  </acceptance_criteria>
  <done>Full Phase 34 + full repo test suites green; Credo strict reports 0 new issues; phase gate PASSED.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Worker telemetry emit → adopter handler | Adopter telemetry handlers run in the same BEAM; metadata reaches them as-emitted (no further sanitization). Phase 34 emit-site redaction is the last line of defense. |
| Test harness → telemetry capture | `:telemetry.attach_many` in tests captures every event — used by Plan 04 to enforce the redaction invariant phase-wide. |
| Adapter `@moduledoc` → adopter onboarding (Phase 36) | Phase 36 will publish docs that reference the telemetry contract. Plan 04's `@moduledoc` is the single source of truth. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-34-04-01 | Information Disclosure | A future code path emits raw `provider_asset_id` in telemetry, breaking security invariant 14 silently | mitigate | Plan 04 `telemetry_test.exs` cross-cutting parity test attaches to ALL five `[:rindle, :provider, _, _]` events and asserts every `metadata.asset_id` matches `~r/^\.\.\.[A-Za-z0-9]{4}$/` (or is nil). Any new emit site that forgets to call `redact_id/1` fails this test. |
| T-34-04-02 | Spoofing | JWT signed with the wrong key ends up in production | mitigate | End-to-end smoke test in Plan 04 verifies the JWT against the test signing-key fixture's public half via `JOSE.JWT.verify_strict/3` — the contract is exercised end-to-end. JWT minting takes a single id from the PLURAL `playback_ids` list via `List.first/1` (B1 schema fidelity). |
| T-34-04-03 | Repudiation | Telemetry contract drifts between code and docs | mitigate | Plan 04 documents the contract in `@moduledoc` blocks AND asserts the documented keys are present in tests (`assert metadata[:provider] == :mux`, `assert is_integer(measurements[:system_time])`). Drift causes a test failure. |
| T-34-04-04 | Tampering | Dialyzer warnings on Mux subsystem mask type drift between Plans 01-03 | mitigate | Task 2b includes `mix dialyzer` as a phase-gate command after PLT regen with `:mux` and `:jose`. Type drift surfaces as `:none_callback` or `:contract_supertype` warnings that block phase ship. |
| T-34-04-05 | Information Disclosure | Telemetry contract docs reveal too much about internal asset id format | accept | The docs note `asset_id` is a redacted last-4-char tag; raw format is not documented. Adopters cannot reconstruct the raw id from the tag (need to brute-force 4 chars × 26+10+26 = 62^4 = ~14M possibilities, useless without other side channel). Documenting the redaction is itself a security feature. |
</threat_model>

<verification>
- `mix test test/rindle/streaming/provider/mux/ test/rindle/workers/mux_ingest_variant_test.exs test/rindle/workers/mux_sync_coordinator_test.exs test/rindle/workers/mux_sync_provider_asset_test.exs --max-failures 1` exits 0 (full Phase 34 bundle)
- `mix test --max-failures 1` exits 0 (full repo — no regressions)
- `mix dialyzer` exits 0 (PLT regenerated with `:mux` + `:jose`)
- `mix credo --strict` reports 0 new issues
- `grep -c "## Telemetry" lib/rindle/streaming/provider/mux.ex lib/rindle/workers/mux_sync_provider_asset.ex` returns ≥ 2
- `grep -c "@moduledoc false" lib/rindle/workers/mux_sync_provider_asset.ex` returns 0 (false moduledoc replaced with documented one)
- The cross-cutting redaction-parity test in `telemetry_test.exs` asserts `asset_id == nil or asset_id =~ @redacted_id_regex` for every captured event
- The end-to-end smoke test in `telemetry_test.exs` asserts `is_list(row.playback_ids)` (B1) AND `assert_in_delta exp, before_unix + ttl, 5` AND `refute exp > before_unix + 604_800` (Pitfall 1 final guard) AND `JOSE.JWT.verify_strict(public_jwk, ["RS256"], jwt)` returns `{true, _, _}`
- `grep -A 5 "MediaAsset.changeset" test/rindle/streaming/provider/mux/telemetry_test.exs | grep -c "content_type:"` returns ≥ 1 (B3 — real schema field)
- `grep -A 5 "MediaAsset.changeset" test/rindle/streaming/provider/mux/telemetry_test.exs | grep -c "mime:"` returns 0 (B3 — fictional field absent)
- `grep -A 5 "MediaVariant.changeset" test/rindle/streaming/provider/mux/telemetry_test.exs | grep -c "output_kind:"` returns ≥ 1 (B3 — real schema field)
- `grep -A 5 "MediaProviderAsset.changeset" test/rindle/streaming/provider/mux/telemetry_test.exs | grep -c "variant_name:"` returns 0 (B2 — fictional column absent)
</verification>

<success_criteria>
1. **MUX-08 cross-cutting parity:** A single ExUnit test attaches to all five `[:rindle, :provider, _, _]` events, drives the ingest+sync pipeline, and asserts every `metadata.asset_id` is nil or `~r/^\.\.\.[A-Za-z0-9]{4}$/` (security invariant 14 enforced phase-wide).
2. **MUX-08 schema parity:** Tests assert each event family carries the documented measurement + metadata keys (`system_time`, `duration` for `:ingest`; `system_time`, `profile`, `provider`, `provider_state`, `age_ms` for `:sync`).
3. **End-to-end smoke:** Full pipeline test exercises `MuxIngestVariant → MuxSyncProviderAsset → signed_playback_url/3`; asserts `is_list(row.playback_ids)` (B1 PLURAL), uses `List.first/hd` to extract a single id for URL minting; final JWT verifies against the test signing-key fixture and respects `signed_url_ttl_seconds(profile) ± 5s`.
4. **Telemetry contract @moduledoc:** Adapter + per-row sync worker `@moduledoc` blocks document both event families. `mux_sync_provider_asset.ex` is no longer `@moduledoc false`.
5. **Dialyzer clean:** PLT regenerated with `:mux` + `:jose` (Plan 01's `dialyzer.plt_add_apps` additions); `mix dialyzer` exits 0 across the full Mux subsystem (Task 2b).
6. **Phase gate:** `mix test --max-failures 1` (full repo) exits 0; `mix credo --strict` reports 0 new issues — Phase 34 is additive and breaks no existing tests (Task 2c).
7. **Pitfall 1 final guard:** End-to-end smoke includes the `refute exp > before_unix + 604_800` assertion that re-runs the 7-day-footgun guard inside the integration flow (Plan 01 has the unit-level guard; Plan 04 has the integration-level guard).
8. **Schema fidelity:** Test setup uses real Phase 33 / Phase 33-prereq schema field names — `content_type` (NOT `mime`), `output_kind` (NOT `kind`), no fictional `variant_name:` column on `media_provider_assets` — matches the corrections in Plans 02 and 03.
</success_criteria>

<output>
After completion, create `.planning/phases/34-mux-rest-adapter-server-push-sync/34-04-SUMMARY.md` documenting:
- Cross-cutting redaction-parity test result (event count + redaction violations: 0 expected)
- End-to-end smoke pipeline confirmation (ingest → sync → signed URL using PLURAL playback_ids)
- Dialyzer + Credo + full-suite results
- Telemetry contract `@moduledoc` line counts
- Phase 34 phase-gate verdict (PASS/FAIL — must be PASS for /gsd-verify-work)
- Any deviations from CONTEXT.md / RESEARCH.md (none expected)
</output>
</content>
</invoke>