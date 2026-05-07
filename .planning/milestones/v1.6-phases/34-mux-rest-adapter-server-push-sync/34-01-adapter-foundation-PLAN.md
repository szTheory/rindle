---
phase: 34-mux-rest-adapter-server-push-sync
plan: 01
type: execute
wave: 1
depends_on: []
autonomous: true
requirements: [MUX-01, MUX-02, MUX-04]
files_modified:
  - mix.exs
  - lib/rindle/domain/media_provider_asset.ex
  - lib/rindle/streaming/provider/mux.ex
  - lib/rindle/streaming/provider/mux/client.ex
  - lib/rindle/streaming/provider/mux/http.ex
  - lib/rindle/streaming/provider/mux/event.ex
  - test/support/mocks.ex
  - test/fixtures/mux/asset_create_201.json
  - test/fixtures/mux/asset_get_processing.json
  - test/fixtures/mux/asset_get_ready.json
  - test/fixtures/mux/webhook_video_asset_ready.json
  - test/fixtures/mux/webhook_video_asset_errored.json
  - test/fixtures/mux/test_signing_private_key.pem
  - test/rindle/streaming/provider/mux/optional_dep_test.exs
  - test/rindle/streaming/provider/mux/mux_test.exs
  - test/rindle/streaming/provider/mux/signed_playback_url_test.exs

must_haves:
  truths:
    - "When `:mux` is loaded, `Rindle.Streaming.Provider.Mux` exists and exports every Phase 33 callback (`capabilities/0`, `create_asset/3`, `get_asset/1`, `delete_asset/1`, `signed_playback_url/3`, `verify_webhook/3`)."
    - "When `:mux` is NOT loaded, the module simply does not exist and `dispatch_streaming/4` surfaces `:streaming_not_configured`."
    - "`signed_playback_url/3` always passes `:expiration` explicitly to `Mux.Token.sign_playback_id/2` — the JWT `exp` claim equals `now + signed_url_ttl_seconds(profile)` (within 5s clock skew), never the SDK 7-day default."
    - "Adapter calls `Mux.Video.Assets.create/2` with **plural, current** Mux REST keys (`inputs`, `playback_policies`) — D-04 memo correction."
    - "`create_asset/3` returns the Phase 33 contract shape `{:ok, %{provider_asset_id: ..., playback_ids: [..]}}` with `playback_ids` PLURAL (matches Phase 33 schema field `field :playback_ids, {:array, :string}`)."
    - "`MediaProviderAsset.redact_id/1` is a public function that returns last-4-char tag (`...abcd`) for any provider id; the existing Inspect impl now delegates to it."
    - "`Rindle.Streaming.Provider.Mux.ClientMock` is registered in `test/support/mocks.ex` for downstream worker tests in Plans 02 and 03."
  artifacts:
    - path: "mix.exs"
      provides: "Optional `:mux` and `:jose` deps + Dialyzer PLT additions"
      contains: '{:mux, "~> 3.2", optional: true}'
    - path: "lib/rindle/domain/media_provider_asset.ex"
      provides: "Public `redact_id/1` callable from workers and telemetry emit sites"
      exports: ["redact_id/1"]
    - path: "lib/rindle/streaming/provider/mux.ex"
      provides: "Reference adapter implementing the Phase 33 behaviour"
      contains: "if Code.ensure_loaded?(Mux.Video.Assets) do"
    - path: "lib/rindle/streaming/provider/mux/client.ex"
      provides: "Internal HTTP-client behaviour with Mox-mockable callbacks"
      contains: "@callback create_asset"
    - path: "lib/rindle/streaming/provider/mux/http.ex"
      provides: "Real Mux SDK delegate; constructs `Mux.Base.new/2` per call"
      contains: "Mux.Video.Assets.create"
    - path: "lib/rindle/streaming/provider/mux/event.ex"
      provides: "Webhook event normalizer (called by `verify_webhook/3`)"
      contains: "@spec normalize"
    - path: "test/support/mocks.ex"
      provides: "ClientMock registration for Plans 02 and 03"
      contains: "Rindle.Streaming.Provider.Mux.ClientMock"
    - path: "test/fixtures/mux/test_signing_private_key.pem"
      provides: "RSA-2048 signing key fixture for JWT verification tests"
      min_lines: 20
  key_links:
    - from: "lib/rindle/streaming/provider/mux.ex"
      to: "lib/rindle/streaming/provider/mux/client.ex"
      via: "configurable `http_client` config key — runtime-swappable for ClientMock in tests"
      pattern: "config\\(:http_client.*Rindle.Streaming.Provider.Mux.HTTP\\)"
    - from: "lib/rindle/streaming/provider/mux.ex"
      to: "Mux.Token.sign_playback_id/2"
      via: "explicit `:expiration` keyword from `Rindle.Delivery.signed_url_ttl_seconds/1`"
      pattern: "expiration:.*signed_url_ttl_seconds"
    - from: "lib/rindle/streaming/provider/mux/http.ex"
      to: "Mux.Video.Assets.create/2"
      via: "params map keyed PLURAL `inputs` and `playback_policies`"
      pattern: '"playback_policies"'
    - from: "lib/rindle/domain/media_provider_asset.ex"
      to: "telemetry emit sites in Plans 02–04"
      via: "public `redact_id/1` consumed by every emit"
      pattern: "def redact_id"
---

<objective>
Lay the Phase 34 adapter foundation: optional Mux+JOSE dep wiring, the
`Rindle.Streaming.Provider.Mux` module implementing the Phase 33 behaviour
(capabilities, asset CRUD, signed playback URL, webhook verify callback),
the internal `Mux.Client` behaviour + `Mux.HTTP` real impl + `Mux.Event`
normalizer, the Mox `ClientMock` registration, the test scaffolding for
MUX-01/02/04, and the public promotion of `MediaProviderAsset.redact_id/1`
that downstream plans depend on.

Purpose: every other Phase 34 plan consumes either the adapter module
(Plans 02, 03 import `Mux.Client` and call `Mux.signed_playback_url/3`),
the ClientMock (Plans 02, 03 set Mox expectations on it), or `redact_id/1`
(Plans 02, 03, 04 redact telemetry metadata).

Output: 7 new lib files, 2 modified files, 4 new test files, 6 fixture
files. Adapter contract callbacks are implemented and unit-tested with
Mox; signed-playback URL JWT verification asserts the 7-day footgun is
guarded.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/34-mux-rest-adapter-server-push-sync/34-CONTEXT.md
@.planning/phases/34-mux-rest-adapter-server-push-sync/34-RESEARCH.md
@.planning/phases/34-mux-rest-adapter-server-push-sync/34-PATTERNS.md
@.planning/phases/34-mux-rest-adapter-server-push-sync/34-VALIDATION.md
@.planning/phases/33-provider-boundary-state-schema/33-CONTEXT.md

@lib/rindle/streaming/provider.ex
@lib/rindle/streaming/capabilities.ex
@lib/rindle/domain/media_provider_asset.ex
@lib/rindle/delivery.ex
@lib/rindle/live_view.ex
@lib/rindle/error.ex
@test/support/mocks.ex

<interfaces>
<!-- Phase 33 behaviour callbacks Plan 01 must implement (verbatim from lib/rindle/streaming/provider.ex:48-95) -->

```elixir
# Closed-vocabulary capability atoms (lib/rindle/streaming/capabilities.ex)
@type capability ::
        :signed_playback | :public_playback | :webhook_ingest
        | :server_push_ingest | :direct_creator_upload

# Phase 33 callbacks (lib/rindle/streaming/provider.ex)
@callback capabilities() :: [capability()]

@callback create_asset(profile :: module(), source_url :: String.t(), opts :: keyword()) ::
            {:ok, %{provider_asset_id: provider_asset_id(), playback_ids: [playback_id()]}}
            | {:error, term()}

@callback get_asset(provider_asset_id()) ::
            {:ok, %{state: provider_state(), playback_ids: [playback_id()], raw: map()}}
            | {:error, term()}

@callback delete_asset(provider_asset_id()) :: :ok | {:error, term()}

@callback signed_playback_url(profile :: module(), playback_id(), opts :: keyword()) ::
            {:ok, %{url: String.t(), kind: :hls, mime: String.t()}}
            | {:error, term()}

@callback verify_webhook(raw_body :: binary(), headers :: map(), secrets :: [String.t()]) ::
            {:ok, provider_event()} | {:error, term()}
```

<!-- ProviderAssetFSM.transition/3 — third arg is a MAP, not a keyword list -->
<!-- lib/rindle/domain/provider_asset_fsm.ex:28 -->
```elixir
@spec transition(state(), state(), map()) :: :ok | transition_error()
def transition(current_state, target_state, context \\ %{}) do
  # context is read via Map.get(context, :profile, :unknown), Map.get(context, :provider, ...), etc.
end
```

<!-- MediaProviderAsset schema (Phase 33, REAL FIELDS) — lib/rindle/domain/media_provider_asset.ex -->
<!-- Note the field is `playback_ids` (PLURAL ARRAY), NOT singular. -->
<!-- Note there is NO `variant_name` column. The unique constraint is on (asset_id, profile, provider_name). -->
```elixir
schema "media_provider_assets" do
  field :profile, :string
  field :provider_name, :string
  field :provider_asset_id, :string
  field :playback_ids, {:array, :string}, default: []   # PLURAL ARRAY
  field :playback_policy, :string
  field :ingest_mode, :string
  field :state, :string, default: "pending"
  field :last_event_id, :string
  field :last_event_at, :utc_datetime_usec
  field :last_sync_error, :string
  field :raw_provider_metadata, :map, default: %{}
  belongs_to :asset, Rindle.Domain.MediaAsset, foreign_key: :asset_id
  timestamps()
end

@writable [:asset_id, :profile, :provider_name, :provider_asset_id,
           :playback_ids, :playback_policy, :ingest_mode, :state,
           :last_event_id, :last_event_at, :last_sync_error,
           :raw_provider_metadata]
# Note: NO :variant_name in @writable — there is no such column.
```

<!-- Existing Inspect-impl redactor in lib/rindle/domain/media_provider_asset.ex:111-117 -->
<!-- Currently: defp redact_id/1. Plan 01 promotes to public def redact_id/1. -->
```elixir
defp redact_id(nil), do: nil
defp redact_id(id) when is_binary(id) and byte_size(id) >= 4 do
  "..." <> String.slice(id, -4, 4)
end
defp redact_id(_), do: "...redacted"
```

<!-- Existing Mox registrations in test/support/mocks.ex (one-line addition pattern) -->
```elixir
Mox.defmock(Rindle.StorageMock, for: Rindle.Storage)
Mox.defmock(Rindle.ProcessorMock, for: Rindle.Processor)
Mox.defmock(Rindle.AnalyzerMock, for: Rindle.Analyzer)
Mox.defmock(Rindle.ScannerMock, for: Rindle.Scanner)
Mox.defmock(Rindle.AuthorizerMock, for: Rindle.Authorizer)
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Optional deps + redact_id/1 promotion + ClientMock + signing-key fixture (Wave 0 prep)</name>
  <files>mix.exs, lib/rindle/domain/media_provider_asset.ex, lib/rindle/streaming/provider/mux/client.ex, test/support/mocks.ex, test/fixtures/mux/test_signing_private_key.pem, test/fixtures/mux/asset_create_201.json, test/fixtures/mux/asset_get_processing.json, test/fixtures/mux/asset_get_ready.json, test/fixtures/mux/webhook_video_asset_ready.json, test/fixtures/mux/webhook_video_asset_errored.json, test/rindle/streaming/provider/mux/optional_dep_test.exs</files>
  <read_first>
    - mix.exs (full file — see existing `{:phoenix_live_view, "~> 1.0", optional: true}` line ~65 and `dialyzer:` block lines ~20-24)
    - lib/rindle/domain/media_provider_asset.ex (full file — line 111-117 has `defp redact_id/1`)
    - test/support/mocks.ex (5-line file showing existing Mox.defmock pattern)
    - .planning/phases/34-mux-rest-adapter-server-push-sync/34-PATTERNS.md (sections "test/support/mocks.ex" and "lib/rindle/domain/media_provider_asset.ex (model, modify)")
    - .planning/phases/34-mux-rest-adapter-server-push-sync/34-CONTEXT.md (decisions D-01, D-02, D-27, D-34, D-37)
  </read_first>
  <action>
Foundation prep, executed in this exact order:

**1a. mix.exs deps (D-01) and PLT (D-02):**
In `defp deps`, add (mirroring the existing `{:phoenix_live_view, "~> 1.0", optional: true}` line shape):
```elixir
# Streaming providers (optional — Mux adapter only loads when these are present)
{:mux, "~> 3.2", optional: true},
{:jose, "~> 1.11", optional: true},
```
In the `dialyzer:` block, extend `plt_add_apps` (current shape `[:mix, :ex_unit]`) to `[:mix, :ex_unit, :mux, :jose]`.

Run `mix deps.get` after the edit. Then run `mix dialyzer --plt` (PLT regen takes ~2-5 min — run in background; do not block on it).

**1b. Promote `MediaProviderAsset.redact_id/1` to public (per Open Question 1, D-27):**
In `lib/rindle/domain/media_provider_asset.ex` add inside the `defmodule Rindle.Domain.MediaProviderAsset do` block (BEFORE the `defimpl Inspect` clause), exactly:
```elixir
@doc """
Redact a `provider_asset_id` to its last-4-character tag (`"...abcd"`).
Returns `nil` for `nil`, `"...redacted"` for ids shorter than 4 chars.

Used by telemetry emit sites and log lines to enforce security invariant 14.
"""
@spec redact_id(nil | String.t()) :: nil | String.t()
def redact_id(nil), do: nil

def redact_id(id) when is_binary(id) and byte_size(id) >= 4 do
  "..." <> String.slice(id, -4, 4)
end

def redact_id(_), do: "...redacted"
```
Then in the `defimpl Inspect, for: Rindle.Domain.MediaProviderAsset do` block, replace `redact_id(asset.provider_asset_id)` with `Rindle.Domain.MediaProviderAsset.redact_id(asset.provider_asset_id)`. DELETE the `defp redact_id/1` clauses inside the Inspect impl (now redundant).

**1c. Define internal client behaviour (D-34, no optional-dep guard — pure Elixir):**
Create `lib/rindle/streaming/provider/mux/client.ex`:
```elixir
defmodule Rindle.Streaming.Provider.Mux.Client do
  @moduledoc false

  # Internal HTTP-client behaviour for the Mux REST adapter.
  # Real impl: Rindle.Streaming.Provider.Mux.HTTP (delegates to mux SDK).
  # Test impl: Rindle.Streaming.Provider.Mux.ClientMock (Mox-defined).

  @callback create_asset(params :: map()) :: {:ok, map()} | {:error, term()} | {:error, term(), term()}
  @callback get_asset(provider_asset_id :: String.t()) :: {:ok, map()} | {:error, term()} | {:error, term(), term()}
  @callback delete_asset(provider_asset_id :: String.t()) :: :ok | {:error, term()} | {:error, term(), term()}
end
```

**1d. Register ClientMock (D-39):**
Append to `test/support/mocks.ex`:
```elixir
Mox.defmock(Rindle.Streaming.Provider.Mux.ClientMock,
  for: Rindle.Streaming.Provider.Mux.Client)
```

**1e. Generate signing-key fixture (D-37, A3) — use Erlang stdlib (W3 fix):**
Run this from the repo root as a one-shot Mix script (Erlang `:public_key` stdlib; no shell out to `openssl`):

```bash
mkdir -p test/fixtures/mux
mix run -e '
{_public_key, private_key} = :public_key.generate_key({:rsa, 2048, 65537})
pem = :public_key.pem_encode([:public_key.pem_entry_encode(:RSAPrivateKey, private_key)])
File.write!("test/fixtures/mux/test_signing_private_key.pem", pem)
'
```

This avoids the `openssl genrsa` shell dependency and uses the Erlang stdlib `:public_key` module directly. Verify the output file is a valid RSA private key by decoding it back via `:public_key.pem_decode/1` (or by calling `JOSE.JWK.from_pem(File.read!("test/fixtures/mux/test_signing_private_key.pem"))` — should return a `%JOSE.JWK{}` struct without raising). Commit the resulting PEM file verbatim. The public half is extracted at test runtime via `JOSE.JWK.from_pem(...) |> JOSE.JWK.to_public/1`.

**1f. Create cassette fixtures (D-36; hand-derive per Open Question 3):**
Hand-derive fixtures from `https://www.mux.com/docs/api-reference/video/assets/create-asset` and the Mux webhook docs. Each is a JSON file:

`test/fixtures/mux/asset_create_201.json` — Mux 201 response with PLURAL keys:
```json
{
  "id": "AbCd1234EfGh5678IjKl9012MnOp3456QrSt",
  "playback_ids": [{"id": "playback-id-test-fixture-1234", "policy": "signed"}],
  "status": "preparing",
  "mp4_support": "standard",
  "max_resolution_tier": "1080p",
  "playback_policies": ["signed"],
  "created_at": "1700000000"
}
```

`test/fixtures/mux/asset_get_processing.json` — same id, `"status": "preparing"` (Mux status names: `preparing | ready | errored`).

`test/fixtures/mux/asset_get_ready.json` — same id, `"status": "ready"`, includes `duration: 30.5` and `aspect_ratio: "16:9"` to mimic real ready-asset response.

`test/fixtures/mux/webhook_video_asset_ready.json` — Mux webhook envelope:
```json
{
  "type": "video.asset.ready",
  "data": {
    "id": "AbCd1234EfGh5678IjKl9012MnOp3456QrSt",
    "status": "ready",
    "playback_ids": [{"id": "playback-id-test-fixture-1234", "policy": "signed"}]
  },
  "created_at": "2026-05-06T00:00:00.000Z"
}
```

`test/fixtures/mux/webhook_video_asset_errored.json` — analogous with `"type": "video.asset.errored"` and `"errors": {"messages": ["..."], "type": "input_error"}` in `data`.

**1g. MUX-01 smoke test:**
Create `test/rindle/streaming/provider/mux/optional_dep_test.exs`:
```elixir
defmodule Rindle.Streaming.Provider.Mux.OptionalDepTest do
  use ExUnit.Case, async: true

  test "Rindle.Streaming.Provider.Mux is loaded with all required Phase 33 callbacks (test env)" do
    assert Code.ensure_loaded?(Rindle.Streaming.Provider.Mux),
           "Rindle.Streaming.Provider.Mux module must compile when :mux is loaded"

    for {fun, arity} <- [
          {:capabilities, 0},
          {:create_asset, 3},
          {:get_asset, 1},
          {:delete_asset, 1},
          {:signed_playback_url, 3},
          {:verify_webhook, 3}
        ] do
      assert function_exported?(Rindle.Streaming.Provider.Mux, fun, arity),
             "Rindle.Streaming.Provider.Mux must export #{fun}/#{arity}"
    end
  end

  test "Mux + JOSE deps are loaded in test env" do
    assert Code.ensure_loaded?(Mux.Video.Assets)
    assert Code.ensure_loaded?(Mux.Token)
    assert Code.ensure_loaded?(Mux.Webhooks)
    assert Code.ensure_loaded?(JOSE.JWK)
  end
end
```

This task does NOT yet add the adapter module body — Task 2 adds it. The smoke test will fail until Task 2 lands; that is expected (RED → GREEN within Plan 01).
  </action>
  <verify>
    <automated>mix deps.get && mix compile --warnings-as-errors 2>&1 | tail -20 && grep -c '{:mux, "~> 3.2", optional: true}' mix.exs && grep -c '{:jose, "~> 1.11", optional: true}' mix.exs && grep -c "plt_add_apps:.*:mux" mix.exs && grep -c "def redact_id" lib/rindle/domain/media_provider_asset.ex && grep -c "Rindle.Streaming.Provider.Mux.ClientMock" test/support/mocks.ex && test -f test/fixtures/mux/test_signing_private_key.pem && test -f test/fixtures/mux/asset_create_201.json && test -f test/rindle/streaming/provider/mux/optional_dep_test.exs</automated>
  </verify>
  <acceptance_criteria>
    - `mix.exs` contains `{:mux, "~> 3.2", optional: true}` (exact substring)
    - `mix.exs` contains `{:jose, "~> 1.11", optional: true}` (exact substring)
    - `mix.exs` `dialyzer:` block contains both `:mux` and `:jose` in `plt_add_apps`
    - `lib/rindle/domain/media_provider_asset.ex` contains `def redact_id(nil), do: nil` (top-level, not inside `defimpl`)
    - `lib/rindle/domain/media_provider_asset.ex` Inspect impl now references `Rindle.Domain.MediaProviderAsset.redact_id/1` (not bare `redact_id/1`)
    - `lib/rindle/streaming/provider/mux/client.ex` exists with three `@callback` lines: `create_asset(params :: map())`, `get_asset(provider_asset_id :: String.t())`, `delete_asset(provider_asset_id :: String.t())`
    - `test/support/mocks.ex` contains exactly one new line: `Mox.defmock(Rindle.Streaming.Provider.Mux.ClientMock, for: Rindle.Streaming.Provider.Mux.Client)`
    - `test/fixtures/mux/test_signing_private_key.pem` exists; `JOSE.JWK.from_pem(File.read!("test/fixtures/mux/test_signing_private_key.pem"))` returns a `%JOSE.JWK{}` struct without raising
    - All five JSON fixtures exist; each parses as valid JSON (`jq . file > /dev/null`)
    - `test/rindle/streaming/provider/mux/optional_dep_test.exs` exists with `function_exported?` assertions for all six Phase 33 callbacks
    - `mix compile --warnings-as-errors` exits 0
  </acceptance_criteria>
  <done>Optional deps wired, redact_id/1 public, ClientMock registered, fixtures committed, MUX-01 smoke test scaffold present (will pass once Task 2 lands the adapter module).</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Adapter module + HTTP impl + event normalizer (MUX-02 + MUX-04)</name>
  <files>lib/rindle/streaming/provider/mux.ex, lib/rindle/streaming/provider/mux/http.ex, lib/rindle/streaming/provider/mux/event.ex, test/rindle/streaming/provider/mux/mux_test.exs, test/rindle/streaming/provider/mux/signed_playback_url_test.exs</files>
  <read_first>
    - lib/rindle/streaming/provider.ex (full Phase 33 behaviour — callbacks at lines 57-95, types at 25-54)
    - lib/rindle/streaming/capabilities.ex (closed-vocabulary list — `safe/1` filter)
    - lib/rindle/live_view.ex (line 1 — exact optional-dep guard pattern to mirror)
    - lib/rindle/delivery.ex (lines 84-90 — `signed_url_ttl_seconds/1` shape; lines 244-303 — `dispatch_streaming/4` consumer)
    - lib/rindle/error.ex (lines 195-272 — existing `:provider_*` `def message(%{reason: ...})` clauses)
    - .planning/phases/34-mux-rest-adapter-server-push-sync/34-PATTERNS.md sections "lib/rindle/streaming/provider/mux.ex" and "lib/rindle/streaming/provider/mux/http.ex" and "lib/rindle/streaming/provider/mux/event.ex"
    - .planning/phases/34-mux-rest-adapter-server-push-sync/34-CONTEXT.md decisions D-03..D-12, D-29..D-33
    - .planning/phases/34-mux-rest-adapter-server-push-sync/34-RESEARCH.md "Memo Correction #1" (PLURAL keys), Pitfall 1 (7-day footgun), Pitfall 4 (guard precedence)
  </read_first>
  <behavior>
    - Test 1 (MUX-02): `Rindle.Streaming.Provider.Mux.capabilities/0` returns `[:signed_playback, :webhook_ingest, :server_push_ingest]` (closed list — no `:public_playback`, no `:direct_creator_upload`).
    - Test 2 (MUX-02): `create_asset/3` with Mox stub on `ClientMock.create_asset/1` reshapes the SDK response to `{:ok, %{provider_asset_id: "AbCd...", playback_ids: ["playback-id-..."]}}` (PLURAL `playback_ids` matches Phase 33 contract). The params map handed to ClientMock MUST contain string keys `"inputs"` (PLURAL, list of `%{"url" => _}` objects) and `"playback_policies"` (PLURAL, string list `["signed"]`) — D-04 memo correction.
    - Test 3 (MUX-02): `get_asset/1` reshapes `{:ok, %{"id" => _, "status" => "ready", "playback_ids" => [...]}}` from cassette to `{:ok, %{state: "ready", playback_ids: ["..."], raw: %{...}}}`.
    - Test 4 (MUX-02): `delete_asset/1` returns `:ok` on success and `:ok` on `:not_found` (idempotent per Phase 33 contract).
    - Test 5 (MUX-02): `verify_webhook/3` with a list of secrets calls `Mux.Webhooks.verify_header/4` for each secret, returns `{:ok, normalized_event}` on first match, `{:error, :provider_webhook_invalid}` if no secret matches.
    - Test 6 (MUX-04, the highest-leverage 7-day-footgun guard): `signed_playback_url/3` minted JWT decoded via `JOSE.JWT.peek_payload/1` shows `exp` claim within `now + signed_url_ttl_seconds(profile) ± 5s`. `refute exp > now + 604_800` (the SDK 7-day default would smell like this).
    - Test 7 (MUX-04): JWT verifies against the test signing-key fixture's public half via `JOSE.JWS.verify_strict/3`.
    - Test 8 (MUX-04): URL shape is `https://stream.mux.com/{playback_id}.m3u8?token={jwt}`; return tuple is `{:ok, %{url: _, kind: :hls, mime: "application/vnd.apple.mpegurl"}}`.
    - Test 9 (MUX-02): Mux SDK is invoked via the configured `:http_client` module — the test sets `Application.put_env(:rindle, Rindle.Streaming.Provider.Mux, http_client: Rindle.Streaming.Provider.Mux.ClientMock)` and verifies Mox expectations are hit.
  </behavior>
  <action>
**2a. Real HTTP impl (D-31, D-32; guarded per Pitfall 4):**
Create `lib/rindle/streaming/provider/mux/http.ex`:
```elixir
# Compiled only when {:mux, "~> 3.2"} is loaded.
# Adopters who do not configure streaming pay zero transitive cost.
if Code.ensure_loaded?(Mux.Video.Assets) do
  defmodule Rindle.Streaming.Provider.Mux.HTTP do
    @moduledoc false
    @behaviour Rindle.Streaming.Provider.Mux.Client

    @impl true
    def create_asset(params) when is_map(params) do
      # Returns {:ok, asset_map, %Tesla.Env{}} on success per D-05.
      # Returns {:error, msg, %Tesla.Env{}} on Mux-side failure (Pitfall 3).
      Mux.Video.Assets.create(build_client(), params)
    end

    @impl true
    def get_asset(provider_asset_id) when is_binary(provider_asset_id) do
      Mux.Video.Assets.get(build_client(), provider_asset_id)
    end

    @impl true
    def delete_asset(provider_asset_id) when is_binary(provider_asset_id) do
      case Mux.Video.Assets.delete(build_client(), provider_asset_id) do
        {:ok, _, _env} -> :ok
        {:error, _msg, %{status: 404}} -> :ok  # idempotent on :not_found per Phase 33 contract
        {:error, _, _} = err -> err
      end
    end

    defp build_client do
      cfg = Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])
      Mux.Base.new(Keyword.fetch!(cfg, :token_id), Keyword.fetch!(cfg, :token_secret))
    end
  end
end
```

**2b. Webhook event normalizer (D-39, no SDK calls — guard NOT needed):**
Create `lib/rindle/streaming/provider/mux/event.ex`:
```elixir
defmodule Rindle.Streaming.Provider.Mux.Event do
  @moduledoc false

  @doc """
  Normalize a Mux webhook event JSON map into the locked Phase 33 `provider_event`
  shape (see `Rindle.Streaming.Provider.@type provider_event`).
  """
  @spec normalize(map()) :: {:ok, map()} | {:error, term()}
  def normalize(%{"type" => type, "data" => data} = raw) when is_map(data) do
    {:ok,
     %{
       type: normalize_type(type),
       provider_asset_id: Map.get(data, "id"),
       playback_ids: extract_playback_ids(data),
       state: normalize_state(Map.get(data, "status")),
       occurred_at: parse_occurred_at(Map.get(raw, "created_at")),
       raw: raw
     }}
  end

  def normalize(_raw), do: {:error, :provider_webhook_invalid}

  defp normalize_type("video.asset.ready"), do: :ready
  defp normalize_type("video.asset.errored"), do: :errored
  defp normalize_type("video.asset.created"), do: :created
  defp normalize_type("video.asset.deleted"), do: :deleted
  defp normalize_type(other) when is_binary(other), do: :unknown

  defp normalize_state("preparing"), do: "processing"
  defp normalize_state("ready"), do: "ready"
  defp normalize_state("errored"), do: "errored"
  defp normalize_state(_), do: nil

  defp extract_playback_ids(data) do
    data
    |> Map.get("playback_ids", [])
    |> Enum.map(& &1["id"])
    |> Enum.reject(&is_nil/1)
  end

  defp parse_occurred_at(nil), do: nil
  defp parse_occurred_at(iso) when is_binary(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end
end
```

**2c. Main adapter module (D-04 PLURAL, D-06..D-12, D-29..D-33):**
Create `lib/rindle/streaming/provider/mux.ex`:
```elixir
# Compiled only when {:mux, "~> 3.2"} is loaded.
# Adopters who do not configure streaming pay zero transitive cost.
if Code.ensure_loaded?(Mux.Video.Assets) do
  defmodule Rindle.Streaming.Provider.Mux do
    @moduledoc """
    Mux REST adapter implementing `Rindle.Streaming.Provider`.

    Configuration (resolved at every call site, no caching — D-30):

        config :rindle, Rindle.Streaming.Provider.Mux,
          token_id: System.get_env("RINDLE_MUX_TOKEN_ID"),
          token_secret: System.get_env("RINDLE_MUX_TOKEN_SECRET"),
          signing_key_id: System.get_env("RINDLE_MUX_SIGNING_KEY_ID"),
          signing_private_key: System.get_env("RINDLE_MUX_SIGNING_PRIVATE_KEY"),
          webhook_secrets: [...],
          webhook_tolerance_seconds: 300,
          provider_polling_floor_seconds: 30,
          provider_stuck_threshold_seconds: 7200

    ## DSL ↔ Mux REST translation

    Phase 33 ships the DSL atom `:playback_policy` (singular) and the schema
    column `playback_policy` (singular). The Phase 33 schema also defines
    `field :playback_ids, {:array, :string}` (PLURAL ARRAY). At the SDK
    boundary this adapter translates to the **current Mux REST API keys**:
    `inputs` (PLURAL list of objects) and `playback_policies` (PLURAL string
    list). The Mux singular keys are deprecated as of 2026-05 — always use
    plural here (D-04 memo correction).

    The Phase 33 callback contract returns `playback_ids: [playback_id()]`
    (a list); the row schema persists `playback_ids` as `{:array, :string}`.
    Adapter writes the array verbatim; reads use `List.first/1` only when a
    single id is needed (e.g., for URL minting).
    """

    @behaviour Rindle.Streaming.Provider

    alias Rindle.Streaming.Provider.Mux.Event

    @impl Rindle.Streaming.Provider
    def capabilities, do: [:signed_playback, :webhook_ingest, :server_push_ingest]

    @doc """
    Server-push ingest entry point. Translates DSL `:playback_policy` (singular,
    via opts) to Mux REST PLURAL `playback_policies`. Returns the Phase 33
    contract shape `{:ok, %{provider_asset_id: _, playback_ids: [_]}}` (PLURAL
    array, even with one element).

    Errors are normalized to the Phase 33 atom set:
      * `:provider_quota_exceeded` (HTTP 429) — caller can extract Retry-After
        from `%Tesla.Env{}.headers` via `create_asset_with_retry_hint/3` if it
        needs the snooze duration (Plan 02 worker uses that variant).
      * `:provider_sync_failed` (HTTP 4xx/5xx other than 429)
    """
    @impl Rindle.Streaming.Provider
    def create_asset(profile, source_url, opts \\ []) when is_atom(profile) and is_binary(source_url) do
      policy_atom = Keyword.get(opts, :playback_policy, :signed)

      params = build_create_params(source_url, policy_atom)

      case http_client().create_asset(params) do
        {:ok, %{"id" => provider_asset_id, "playback_ids" => playback_ids}} ->
          {:ok,
           %{
             provider_asset_id: provider_asset_id,
             playback_ids: Enum.map(playback_ids, & &1["id"])
           }}

        {:ok, %{"id" => provider_asset_id} = _asset} ->
          # Defensive — older fixtures may lack "playback_ids"
          {:ok, %{provider_asset_id: provider_asset_id, playback_ids: []}}

        {:error, _, %{status: 429}} -> {:error, :provider_quota_exceeded}
        {:error, _, %{status: status}} when status in 500..599 -> {:error, :provider_sync_failed}
        {:error, _, %{status: status}} when status in 400..499 -> {:error, :provider_sync_failed}
        {:error, reason} -> {:error, reason}
      end
    end

    @doc """
    Worker-facing variant of `create_asset/3` that exposes the 429 Retry-After
    seconds value so the Plan 02 worker can snooze cleanly. Param construction
    (PLURAL keys) lives ONLY here in the adapter — never duplicated in workers.

    Returns:
      * `{:ok, %{provider_asset_id: _, playback_ids: [_]}}` — happy path
      * `{:error, :provider_quota_exceeded, retry_after_seconds}` — HTTP 429 with parsed Retry-After
      * `{:error, :provider_sync_failed}` — other 4xx/5xx
      * `{:error, term()}` — transport/lower-level error
    """
    @spec create_asset_with_retry_hint(module(), String.t(), keyword()) ::
            {:ok, %{provider_asset_id: String.t(), playback_ids: [String.t()]}}
            | {:error, :provider_quota_exceeded, non_neg_integer()}
            | {:error, atom()}
            | {:error, term()}
    def create_asset_with_retry_hint(profile, source_url, opts \\ [])
        when is_atom(profile) and is_binary(source_url) do
      policy_atom = Keyword.get(opts, :playback_policy, :signed)
      params = build_create_params(source_url, policy_atom)

      case http_client().create_asset(params) do
        {:ok, %{"id" => provider_asset_id, "playback_ids" => playback_ids}} ->
          {:ok,
           %{
             provider_asset_id: provider_asset_id,
             playback_ids: Enum.map(playback_ids, & &1["id"])
           }}

        {:ok, %{"id" => provider_asset_id}} ->
          {:ok, %{provider_asset_id: provider_asset_id, playback_ids: []}}

        # Pitfall 3 / SDK Issue #42: read Retry-After from %Tesla.Env{}.headers directly.
        {:error, _msg, %{status: 429, headers: headers}} ->
          {:error, :provider_quota_exceeded, retry_after_from(headers)}

        {:error, _msg, %{status: status}} when status in 500..599 ->
          {:error, :provider_sync_failed}

        {:error, _msg, %{status: status}} when status in 400..499 ->
          {:error, :provider_sync_failed}

        {:error, reason} ->
          {:error, reason}
      end
    end

    # SDK-boundary param construction — PLURAL keys, single source of truth.
    # NEVER duplicate this in workers (D-04 memo correction).
    defp build_create_params(source_url, policy_atom) do
      %{
        "inputs" => [%{"url" => source_url}],
        "playback_policies" => [Atom.to_string(policy_atom)],
        "mp4_support" => "standard",
        "max_resolution_tier" => "1080p"
      }
    end

    @impl Rindle.Streaming.Provider
    def get_asset(provider_asset_id) when is_binary(provider_asset_id) do
      case http_client().get_asset(provider_asset_id) do
        {:ok, %{"id" => _, "status" => status, "playback_ids" => pids} = raw} ->
          {:ok,
           %{
             state: normalize_state(status),
             playback_ids: Enum.map(pids, & &1["id"]),
             raw: raw
           }}

        {:error, _, %{status: 404}} -> {:error, :not_found}
        {:error, _, %{status: status}} when status in 500..599 -> {:error, :provider_sync_failed}
        {:error, reason} -> {:error, reason}
      end
    end

    @impl Rindle.Streaming.Provider
    def delete_asset(provider_asset_id) when is_binary(provider_asset_id) do
      http_client().delete_asset(provider_asset_id)
    end

    @impl Rindle.Streaming.Provider
    def signed_playback_url(profile, playback_id, _opts \\ []) when is_atom(profile) and is_binary(playback_id) do
      ttl = Rindle.Delivery.signed_url_ttl_seconds(profile)

      jwt =
        Mux.Token.sign_playback_id(playback_id,
          type: :video,
          # MUST pass :expiration explicitly — SDK default is 7 days (Pitfall 1).
          expiration: ttl,
          token_id: config(:signing_key_id),
          token_secret: config(:signing_private_key)
        )

      url = "https://stream.mux.com/#{playback_id}.m3u8?token=#{jwt}"

      {:ok, %{url: url, kind: :hls, mime: "application/vnd.apple.mpegurl"}}
    end

    @impl Rindle.Streaming.Provider
    def verify_webhook(raw_body, headers, secrets) when is_binary(raw_body) and is_map(headers) and is_list(secrets) do
      with {:ok, sig_header} <- fetch_sig_header(headers) do
        tolerance = config(:webhook_tolerance_seconds, 300)

        Enum.find_value(secrets, {:error, :provider_webhook_invalid}, fn secret ->
          case Mux.Webhooks.verify_header(raw_body, sig_header, secret, tolerance) do
            :ok ->
              with {:ok, decoded} <- Jason.decode(raw_body),
                   {:ok, evt} <- Event.normalize(decoded) do
                {:ok, evt}
              else
                _ -> nil
              end
            {:error, _} -> nil
          end
        end)
      end
    end

    defp fetch_sig_header(headers) do
      case Map.fetch(headers, "mux-signature") do
        {:ok, val} -> {:ok, val}
        :error ->
          case Map.fetch(headers, "Mux-Signature") do
            {:ok, val} -> {:ok, val}
            :error -> {:error, :provider_webhook_invalid}
          end
      end
    end

    defp normalize_state("preparing"), do: "processing"
    defp normalize_state("ready"), do: "ready"
    defp normalize_state("errored"), do: "errored"
    defp normalize_state(other), do: other

    defp retry_after_from(headers) do
      candidate =
        Enum.find(headers, fn
          {k, _} when is_binary(k) -> String.downcase(k) == "retry-after"
          _ -> false
        end)

      case candidate do
        {_, v} when is_binary(v) ->
          case Integer.parse(v) do
            {n, _} when n > 0 -> n
            _ -> 60
          end

        _ ->
          60
      end
    end

    @doc false
    def http_client do
      config(:http_client, Rindle.Streaming.Provider.Mux.HTTP)
    end

    defp config(key, default \\ nil) do
      Application.get_env(:rindle, __MODULE__, []) |> Keyword.get(key, default)
    end
  end
end
```

**2d. MUX-02 unit test:**
Create `test/rindle/streaming/provider/mux/mux_test.exs`:
```elixir
defmodule Rindle.Streaming.Provider.MuxTest do
  use Rindle.DataCase, async: false
  import Mox

  alias Rindle.Streaming.Provider.Mux, as: Adapter

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    # Make the adapter route through ClientMock for these tests.
    prev = Application.get_env(:rindle, Adapter, [])
    Application.put_env(:rindle, Adapter, Keyword.merge(prev, [
      http_client: Rindle.Streaming.Provider.Mux.ClientMock,
      token_id: "test_token_id",
      token_secret: "test_token_secret",
      signing_key_id: "test_kid",
      signing_private_key: File.read!("test/fixtures/mux/test_signing_private_key.pem"),
      webhook_tolerance_seconds: 300
    ]))
    on_exit(fn -> Application.put_env(:rindle, Adapter, prev) end)
    :ok
  end

  defp fixture(name) do
    File.read!("test/fixtures/mux/#{name}") |> Jason.decode!()
  end

  test "capabilities/0 returns the closed v1.6 set" do
    assert Adapter.capabilities() == [:signed_playback, :webhook_ingest, :server_push_ingest]
  end

  test "create_asset/3 sends PLURAL Mux keys and reshapes response with PLURAL playback_ids" do
    expect(Rindle.Streaming.Provider.Mux.ClientMock, :create_asset, fn params ->
      # D-04 memo correction: PLURAL keys at SDK boundary.
      assert params["inputs"] == [%{"url" => "https://signed.example/v.mp4"}]
      assert params["playback_policies"] == ["signed"]
      assert params["mp4_support"] == "standard"
      {:ok, fixture("asset_create_201.json")}
    end)

    profile = ProfilesFixture.test_profile()
    # Phase 33 contract: playback_ids is a LIST (matches schema field {:array, :string}).
    assert {:ok, %{provider_asset_id: pid, playback_ids: playback_ids}} =
             Adapter.create_asset(profile, "https://signed.example/v.mp4", playback_policy: :signed)
    assert is_binary(pid)
    assert is_list(playback_ids)
    assert [first | _] = playback_ids
    assert is_binary(first)
  end

  test "get_asset/1 reshapes Mux 200 to provider_event-style result" do
    expect(Rindle.Streaming.Provider.Mux.ClientMock, :get_asset, fn _id -> {:ok, fixture("asset_get_ready.json")} end)
    assert {:ok, %{state: "ready", playback_ids: [_ | _], raw: %{"id" => _}}} = Adapter.get_asset("AbCd1234")
  end

  test "delete_asset/1 is idempotent on :not_found" do
    expect(Rindle.Streaming.Provider.Mux.ClientMock, :delete_asset, fn _ -> :ok end)
    assert :ok = Adapter.delete_asset("AbCd1234")
  end

  test "verify_webhook/3 returns {:error, :provider_webhook_invalid} when no secret matches" do
    headers = %{"mux-signature" => "t=0,v1=ffffffffff"}
    assert {:error, :provider_webhook_invalid} =
             Adapter.verify_webhook(File.read!("test/fixtures/mux/webhook_video_asset_ready.json"), headers, ["wrong-secret"])
  end
end

defmodule ProfilesFixture do
  @moduledoc false
  defmodule TestProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      streaming: Rindle.Streaming.Provider.Mux,
      variants: [hero: [kind: :video, preset: :web_720p]],
      allow_mime: ["video/mp4"],
      max_bytes: 524_288_000
  end
  def test_profile, do: TestProfile
end
```

**2e. MUX-04 signed-URL JWT test (Pitfall 1 — the 7-day-footgun guard):**
Create `test/rindle/streaming/provider/mux/signed_playback_url_test.exs`:
```elixir
defmodule Rindle.Streaming.Provider.Mux.SignedPlaybackUrlTest do
  use Rindle.DataCase, async: false

  alias Rindle.Streaming.Provider.Mux, as: Adapter

  setup do
    prev = Application.get_env(:rindle, Adapter, [])
    Application.put_env(:rindle, Adapter, Keyword.merge(prev, [
      signing_key_id: "test_kid",
      signing_private_key: File.read!("test/fixtures/mux/test_signing_private_key.pem")
    ]))
    on_exit(fn -> Application.put_env(:rindle, Adapter, prev) end)
    :ok
  end

  defmodule TestProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      streaming: Rindle.Streaming.Provider.Mux,
      signed_url_ttl_seconds: 900,
      variants: [hero: [kind: :video, preset: :web_720p]],
      allow_mime: ["video/mp4"],
      max_bytes: 524_288_000
  end

  test "JWT exp matches profile signed_url_ttl_seconds (NOT SDK 7-day default)" do
    ttl = Rindle.Delivery.signed_url_ttl_seconds(TestProfile)
    assert ttl == 900

    before_unix = DateTime.utc_now() |> DateTime.to_unix()

    assert {:ok, %{url: url, kind: :hls, mime: "application/vnd.apple.mpegurl"}} =
             Adapter.signed_playback_url(TestProfile, "playback-id-test-fixture-1234")

    assert url =~ ~r{^https://stream\.mux\.com/playback-id-test-fixture-1234\.m3u8\?token=}

    %URI{query: query} = URI.parse(url)
    %{"token" => jwt} = URI.decode_query(query)

    # W4 fix — simplified JWT payload extraction.
    fields = jwt |> JOSE.JWT.peek_payload() |> Map.fetch!(:fields)
    exp = fields["exp"]

    # exp must be approximately now + ttl (±5s clock skew tolerance)
    assert_in_delta exp, before_unix + ttl, 5

    # SDK 7-day default would put exp at now + 604_800. Refute that.
    refute exp > before_unix + 604_800,
           "JWT carries SDK-default 7-day exp — :expiration not passed correctly"
  end

  test "JWT verifies against the test signing-key fixture's public half" do
    {:ok, %{url: url}} = Adapter.signed_playback_url(TestProfile, "playback-id-1")
    %{"token" => jwt} = URI.parse(url).query |> URI.decode_query()

    public_jwk =
      "test/fixtures/mux/test_signing_private_key.pem"
      |> File.read!()
      |> JOSE.JWK.from_pem()
      |> JOSE.JWK.to_public()

    assert {true, _payload, _jws} = JOSE.JWT.verify_strict(public_jwk, ["RS256"], jwt)
  end
end
```

Run `mix compile --warnings-as-errors` and `mix test test/rindle/streaming/provider/mux/ --max-failures 1` after writing all files.
  </action>
  <verify>
    <automated>mix compile --warnings-as-errors 2>&1 | tail -10 && grep -c "if Code.ensure_loaded?(Mux.Video.Assets) do" lib/rindle/streaming/provider/mux.ex && grep -c "if Code.ensure_loaded?(Mux.Video.Assets) do" lib/rindle/streaming/provider/mux/http.ex && grep -c '"playback_policies"' lib/rindle/streaming/provider/mux.ex && grep -c '"inputs"' lib/rindle/streaming/provider/mux.ex && grep -c "Mux.Token.sign_playback_id(" lib/rindle/streaming/provider/mux.ex && grep -c "expiration: ttl" lib/rindle/streaming/provider/mux.ex && grep -c "create_asset_with_retry_hint" lib/rindle/streaming/provider/mux.ex && mix test test/rindle/streaming/provider/mux/ --max-failures 1</automated>
  </verify>
  <acceptance_criteria>
    - `lib/rindle/streaming/provider/mux.ex` opens with `if Code.ensure_loaded?(Mux.Video.Assets) do`
    - `lib/rindle/streaming/provider/mux/http.ex` opens with `if Code.ensure_loaded?(Mux.Video.Assets) do`
    - `lib/rindle/streaming/provider/mux/event.ex` exists and does NOT have the optional-dep guard (pure Elixir, per Pitfall 4)
    - `mux.ex` calls `Mux.Token.sign_playback_id(` (NOT deprecated `Mux.Token.sign(`)
    - `mux.ex` defines a private `build_create_params/2` helper (single source of truth for PLURAL Mux keys — D-04)
    - `mux.ex` defines a public `create_asset_with_retry_hint/3` consumed by Plan 02's worker (returns `{:error, :provider_quota_exceeded, retry_after}` on 429)
    - `mux.ex` calls `Rindle.Delivery.signed_url_ttl_seconds(profile)` and passes the result as `expiration:` keyword (Pitfall 1)
    - `mux.ex` `capabilities/0` returns `[:signed_playback, :webhook_ingest, :server_push_ingest]` (closed list, NO `:public_playback` or `:direct_creator_upload`)
    - `mux.ex` `verify_webhook/3` accepts `secrets :: [String.t()]` and loops with `Enum.find_value` (D-11)
    - `Application.get_env(:rindle, __MODULE__, [])` is the only credential read path (D-30 — no module attributes, no caching)
    - `mix test test/rindle/streaming/provider/mux/ --max-failures 1` exits 0 (all 3 test files green: optional_dep, mux, signed_playback_url)
    - `mix test test/rindle/streaming/provider/mux/signed_playback_url_test.exs --max-failures 1` shows `assert_in_delta exp, before_unix + ttl, 5` passes (the 7-day-footgun guard)
    - `mix compile --warnings-as-errors` exits 0
  </acceptance_criteria>
  <done>Adapter module fully implements Phase 33 behaviour; PLURAL Mux keys at SDK boundary (single source via `build_create_params/2`); explicit `:expiration` on every `Mux.Token.sign_playback_id/2` call; webhook verify callback ready for Phase 35 plug wire-up; ClientMock-driven unit tests pass; JWT 7-day-footgun guard test green; `create_asset_with_retry_hint/3` exposed for Plan 02 worker.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Test process → Mux REST API | Tests never hit real Mux — Mox mediates every HTTP call. Bypassing the mock layer would expose `RINDLE_MUX_*` credentials to tests. |
| Adapter → Mux SDK | `Mux.Base.new/2` consumes `token_id` + `token_secret` per call (D-03, D-30); credentials never logged. |
| `signed_playback_url/3` → JWT consumer (downstream player) | The JWT is the only piece that crosses the trust boundary — the URL embeds `playback_id` (public) but never `provider_asset_id` (secret). |
| Webhook payload → adapter `verify_webhook/3` | Phase 34 ships the callback only (Phase 35 wires the plug). Plain HTTP body is signed by Mux; HMAC verify is constant-time. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-34-01-01 | Information Disclosure | `Rindle.Streaming.Provider.Mux.HTTP.build_client/0` | mitigate | Read credentials via `Application.get_env(:rindle, Mux, [])` per call (D-30); never log; `Mux.Base.new/2` puts secret into `Tesla.Middleware.BasicAuth` only — no `IO.inspect/1` of the client struct. |
| T-34-01-02 | Spoofing | `Mux.Token.sign_playback_id/2` 7-day default | mitigate | Always pass explicit `expiration: signed_url_ttl_seconds(profile)`; ExUnit test asserts JWT `exp` claim is within `now + ttl ± 5s` AND `refute exp > now + 604_800` (Pitfall 1). |
| T-34-01-03 | Information Disclosure | `provider_asset_id` leaking through Inspect/log/URL | mitigate | `MediaProviderAsset.redact_id/1` promoted to public in this plan; URLs embed only `playback_id`; Inspect impl preserved (delegates to public helper). Plans 02–04 redact at every telemetry emit site. |
| T-34-01-04 | Tampering | Webhook signature bypass via missing `mux-signature` header | mitigate | `verify_webhook/3` checks for header presence; missing/malformed → `{:error, :provider_webhook_invalid}`; constant-time HMAC compare via `Mux.Webhooks.verify_header/4` (D-10). |
| T-34-01-05 | Tampering | Multi-secret rotation gap (single-secret SDK API — D-10) | mitigate | Caller-side `Enum.find_value` over `secrets` list ORs the verify results; first-match wins; verified secret not exposed in callback return (Phase 35 will surface via telemetry). |
| T-34-01-06 | Repudiation | Test signing key reused in prod | accept | Test fixture is committed verbatim (`test/fixtures/mux/test_signing_private_key.pem`) but adopters generate their own via `mix rindle.doctor` flow in Phase 36. Test fixture has no Mux account binding. Low-risk; documented as test-only in fixture comment. |
| T-34-01-07 | Denial of Service | `:rindle_provider` queue not configured by adopter | accept | Phase 34 ships worker MODULES; adopter wires `Oban.Plugins.Cron` per Phase 36's guide. `mix rindle.doctor` (Phase 36) catches the misconfiguration. Phase 34 includes `@moduledoc` with cron snippet. |
| T-34-01-08 | Information Disclosure | Mux SDK 429 `Retry-After` swallowed (Issue #42) | transfer | `create_asset_with_retry_hint/3` reads `%Tesla.Env{}.headers` directly for `Retry-After`; Plan 02 worker consumes that variant; param construction stays in the adapter (PLURAL keys). |
</threat_model>

<verification>
- `mix compile --warnings-as-errors` exits 0
- `mix test test/rindle/streaming/provider/mux/ --max-failures 1` exits 0 (3 test files: `optional_dep_test.exs`, `mux_test.exs`, `signed_playback_url_test.exs`)
- `mix dialyzer` exits 0 (after PLT regen with `:mux` and `:jose` added)
- `grep -c '"playback_policies"' lib/rindle/streaming/provider/mux.ex` returns ≥ 1 (PLURAL key — D-04 memo correction)
- `grep -v '^[[:space:]]*#' lib/rindle/streaming/provider/mux.ex | grep -c '"playback_policy"\b'` returns 0 (no singular use at SDK boundary)
- `grep -c "Mux.Token.sign(" lib/rindle/streaming/provider/mux.ex` returns 0 (deprecated `sign/2` not used; only `sign_playback_id/2`)
- `grep -c "Application.put_env" lib/rindle/streaming/provider/mux.ex` returns 0 (D-30: read-only at call site, no boot-time caching)
- `grep -c "def redact_id" lib/rindle/domain/media_provider_asset.ex` returns ≥ 1 (public helper for Plans 02-04)
</verification>

<success_criteria>
1. **MUX-01:** `mix.exs` declares `:mux` and `:jose` as `optional: true`; PLT add_apps includes both; `function_exported?(Rindle.Streaming.Provider.Mux, :create_asset, 3)` is `true` in test env.
2. **MUX-02:** Every Phase 33 callback (`capabilities/0`, `create_asset/3`, `get_asset/1`, `delete_asset/1`, `signed_playback_url/3`, `verify_webhook/3`) is implemented and unit-tested via Mox. Adapter also exposes `create_asset_with_retry_hint/3` for the worker layer.
3. **MUX-04:** `signed_playback_url/3` ALWAYS passes `:expiration` explicitly; the resulting JWT's `exp` claim sits within `now + signed_url_ttl_seconds(profile) ± 5s`; `refute exp > now + 604_800` is asserted (the 7-day-footgun guard).
4. **D-04 memo correction (PLURAL keys):** `create_asset/3` and `create_asset_with_retry_hint/3` both call `build_create_params/2` (single source of truth) which emits `"inputs"` and `"playback_policies"` (PLURAL string keys).
5. **Phase 33 contract parity:** `create_asset/3` returns `playback_ids: [String.t()]` (PLURAL list, matches schema `field :playback_ids, {:array, :string}`).
6. **Security invariant 14:** `MediaProviderAsset.redact_id/1` is a public function callable by Plans 02-04; the Inspect impl now delegates to it.
7. **Mox foundation:** `Rindle.Streaming.Provider.Mux.ClientMock` is registered in `test/support/mocks.ex` (Plans 02 and 03 set expectations on it).
8. **Optional-dep guard:** Every Mux-touching lib file (except the pure-Elixir behaviour) opens with `if Code.ensure_loaded?(Mux.Video.Assets) do`.
9. **Phase 33 dispatch tree consumes the adapter:** No code change in `delivery.ex` is needed — `streaming_config.provider.signed_playback_url(profile, playback_id, opts)` (Phase 33 line ~287) now resolves to this plan's adapter.
</success_criteria>

<output>
After completion, create `.planning/phases/34-mux-rest-adapter-server-push-sync/34-01-SUMMARY.md` documenting:
- Adapter module + behaviour + HTTP impl + event normalizer files created
- Mux SDK call shape (PLURAL keys at SDK boundary, singular DSL preserved)
- 7-day-footgun guard test result
- ClientMock registration confirmation
- `redact_id/1` public-promotion line numbers
- `create_asset_with_retry_hint/3` 429-snooze contract for Plan 02 worker
- Tests run + exit codes
- Any deviations from CONTEXT.md (none expected)
</output>
</content>
</invoke>