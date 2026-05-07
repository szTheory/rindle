# Phase 35: Signed-Webhook Plug + Idempotent Ingest — Pattern Map

**Mapped:** 2026-05-06
**Files analyzed:** 18 (10 added per D-43 + 8 modified per D-44)
**Analogs found:** 17 / 18 (one new fixture has no exact analog — uses sibling fixtures as template)

> CONTEXT.md `<code_context>` section already pre-identified the analog mappings.
> This document verifies each analog exists, extracts concrete code excerpts the
> executor can paste verbatim into `<read_first>` blocks, and notes the additions /
> modifications Phase 35 introduces over each analog.

---

## File Classification

| New / Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---------------------|------|-----------|----------------|---------------|
| `lib/rindle/delivery/webhook_plug.ex` *(NEW)* | plug (HTTP edge) | request-response, verify-and-enqueue | `lib/rindle/delivery/local_plug.ex` | exact (same `@behaviour Plug` shape) |
| `lib/rindle/delivery/webhook_body_reader.ex` *(NEW)* | plug body reader (MFA) | request-response, raw-body cache | `Plug.Conn.read_body/2` + Plaid `CacheBodyReader` precedent | role-match (no in-tree analog) |
| `lib/rindle/workers/ingest_provider_webhook.ex` *(NEW)* | Oban worker | event-driven, idempotent ingest | `lib/rindle/workers/mux_ingest_variant.ex` | exact (same queue / FSM / telemetry posture) |
| `test/support/mux_webhook_fixtures.ex` *(NEW)* | test helper | test-only signing wrapper | `deps/mux/lib/mux/webhooks/test_utils.ex` (SDK) | exact (thin wrapper over SDK) |
| `test/fixtures/mux/webhook_video_asset_deleted.json` *(NEW)* | test fixture | static JSON | `test/fixtures/mux/webhook_video_asset_errored.json` | role-match (sibling fixture shape) |
| `test/fixtures/mux/webhook_video_upload_asset_created.json` *(NEW)* | test fixture | static JSON | `test/fixtures/mux/webhook_video_asset_created.json` | role-match (extends with `data.asset_id` field) |
| `test/rindle/delivery/webhook_plug_test.exs` *(NEW)* | test | request-response | `test/rindle/delivery/local_plug_test.exs` | exact (Plug.Test conn pattern) |
| `test/rindle/delivery/webhook_body_reader_test.exs` *(NEW)* | test | request-response | `test/rindle/delivery/local_plug_test.exs` | role-match (Plug.Test conn pattern) |
| `test/rindle/workers/ingest_provider_webhook_test.exs` *(NEW)* | test | event-driven | `test/rindle/workers/mux_ingest_variant_test.exs` | exact (Oban worker test) |
| `test/rindle/streaming/provider/mux/event_test.exs` *(EXTENDED)* | test | normalize | already exists; D-29 adds `:upload_asset_created` cases | exact |
| `lib/rindle/streaming/provider/mux/event.ex` *(MOD)* | module | transform | self (extending existing `normalize/1` clauses) | exact |
| `lib/rindle/streaming/provider.ex` *(MOD)* | behaviour | typespec | self (extending `@type provider_event`) | exact |
| `lib/rindle/streaming/provider/mux.ex` *(MOD)* | provider impl | callback + telemetry | self (extends `verify_webhook/3`; adds `dispatch_kind/1`; drops dead `fetch_sig_header` branch) | exact |
| `lib/rindle/ops/runtime_status.ex` *(MOD)* | ops/report | report assembly | self (`variant_report/3` is the template `provider_assets_report/2` mirrors) | exact |
| `lib/mix/tasks/rindle.runtime_status.ex` *(MOD)* | Mix task | CLI wrapper | self (`format_findings/1` is the template `format_provider_findings/1` mirrors) | exact |
| `test/fixtures/mux/webhook_video_asset_{ready,errored,created}.json` *(MOD)* | test fixture | static JSON | self (replace `AbCd1234...` placeholder with realistic 36-char Mux IDs per D-36) | exact |
| `test/rindle/streaming/provider/mux/mux_test.exs:174-181` *(MOD)* | test | replace handrolled HMAC | `Rindle.Test.MuxWebhookFixtures.sign_header/3` (NEW) | exact |

---

## Pattern Assignments

### `lib/rindle/delivery/webhook_plug.ex` (plug, request-response)

**Analog:** `lib/rindle/delivery/local_plug.ex` (the existing in-tree `@behaviour Plug` template).

**Plug skeleton — copy verbatim** (`lib/rindle/delivery/local_plug.ex:21-61`):

```elixir
@behaviour Plug

import Plug.Conn

# ... aliases ...

@impl true
def init(opts) do
  profile = Keyword.fetch!(opts, :profile)
  secret_key_base = Keyword.fetch!(opts, :secret_key_base)

  if profile.storage_adapter() != Local do
    raise ArgumentError,
          "Rindle.Delivery.LocalPlug requires #{inspect(Local)} but got #{inspect(profile.storage_adapter())}"
  end

  [
    profile: profile,
    adapter: Local,
    root: Local.root(opts),
    secret_key_base: secret_key_base
  ]
end

@impl true
def call(conn, opts) do
  conn = fetch_query_params(conn)

  with {:ok, payload} <- verify_token(conn, opts),
       {:ok, path} <- resolve_path(payload, opts),
       {:ok, file_size} <- file_size(payload["key"], opts) do
    send_local_file(conn, opts, payload, path, file_size)
  else
    {:error, :invalid_token} -> forbidden(conn)
    {:error, :expired_token} -> forbidden(conn)
    {:error, :path_outside_root} -> forbidden(conn)
    {:error, :not_found} -> not_found(conn)
  end
end
```

**Plain-text response helpers — copy verbatim** (`lib/rindle/delivery/local_plug.ex:237-247`):

```elixir
defp forbidden(conn) do
  conn
  |> send_resp(403, "forbidden")
  |> halt()
end

defp not_found(conn) do
  conn
  |> send_resp(404, "not found")
  |> halt()
end
```

**Phase 35 additions over `LocalPlug`:**
- D-01..D-03: `init/1` validates `provider:` (module) + `secrets:` (resolver) opts; raises `ArgumentError` if `Code.ensure_loaded?(provider) and function_exported?(provider, :verify_webhook, 3)` fails (mirrors line 35 raise).
- D-02: secrets resolver supports four shapes — `[binary()] | {:system, env_var} | {:application, app, [atom()]} | (-> [binary()])`; resolution at `call/2` time, NOT `init/1` (runtime rotation without restart).
- D-04: enforce POST-only — non-POST → `405 Method Not Allowed` + telemetry `reason: :method_not_allowed` (deliberate Stripe divergence; Stripe uses 400).
- D-05: header lookup uses `Plug.Conn` lowercase headers only (drop the case-fork in `mux.ex:298-304` — see modifications below).
- D-11: `call/2` body wraps `provider.verify_webhook/3` in `try/rescue` → on rescue `400 :provider_webhook_invalid` + telemetry `reason: :provider_callback_raised`.
- D-12..D-16: response code table — `202` happy path (empty body, halt) / `400 "provider_webhook_invalid"` (sig fail or replay) / `503` (Oban enqueue failure) / `500 "server_misconfigured"` (body reader assign missing AND fallback empty).
- D-19: enqueue arg shape — `%{"event_id" => uuid, "provider" => "mux", "event_type" => raw_type, "event" => normalized_event_map}`; NO `raw_body` in args.
- D-26 + D-28: telemetry namespace `[:rindle, :provider, :webhook, :verified | :rejected | :secret_used]`; `dispatch_kind/1` from provider decides `:dispatch | :drop` for the DROP table.

---

### `lib/rindle/delivery/webhook_body_reader.ex` (plug body reader, request-response)

**Analog:** No in-tree analog. External precedent: Plaid Elixir `CacheBodyReader` and Mux SDK README. Phase 35 ships the first Rindle implementation.

**Calling shape (matches `Plug.Parsers` MFA contract):**
```elixir
# adopter wires this in endpoint.ex:
plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json],
  pass: ["*/*"],
  body_reader: {Rindle.Delivery.WebhookBodyReader, :read_body, []},
  json_decoder: Jason
```

**Phase 35 contract (D-06..D-10, D-16):**
- `read_body(conn, opts)` returns `{:ok, body, conn}` after draining all `{:more, ...}` chunks via `Enum.reduce_while`-style accumulator (D-07 — `Plug.Parsers.JSON.decode/3` does NOT loop on `{:more, ...}`).
- 1 MiB hard cap (D-08); over-limit returns `{:error, :too_large}` and `Plug.Parsers` raises `Plug.Parsers.RequestTooLargeError` (Phoenix maps to 413).
- Stores body in `conn.assigns[:raw_body]` as a LIST of binaries (most-recent-first; multipart-safe per D-06).
- Public accessor `WebhookBodyReader.raw_body(conn)`:
  - List with single binary → `List.first`.
  - Multi-chunk list → `Enum.reverse |> IO.iodata_to_binary`.
  - Missing assign → `nil` (caller in `WebhookPlug` falls back to `Plug.Conn.read_body/2`; if THAT returns empty too → `500 server_misconfigured` + telemetry `reason: :body_reader_missing`).

**No code excerpt to copy** — this is greenfield. Reference `Plug.Conn.read_body/2` docs and the D-06..D-10 specifications above.

---

### `lib/rindle/workers/ingest_provider_webhook.ex` (Oban worker, event-driven)

**Analog:** `lib/rindle/workers/mux_ingest_variant.ex` — same queue, retry budget, FSM call-site, telemetry redaction posture.

**Worker preamble — mirror the optional-dep guard + use macro** (`lib/rindle/workers/mux_ingest_variant.ex:1-88`):

```elixir
# Compiled only when {:mux, "~> 3.2"} is loaded (Pitfall 4 #2 —
# guards prevent dead module references in adopters without :mux).
if Code.ensure_loaded?(Mux.Video.Assets) do
  defmodule Rindle.Workers.MuxIngestVariant do
    @moduledoc """ ... """

    use Oban.Worker, queue: :rindle_provider, max_attempts: 5

    require Logger

    alias Rindle.Domain.{MediaAsset, MediaVariant, MediaProviderAsset, ProviderAssetFSM}
    alias Rindle.Streaming.Provider.Mux, as: Adapter

    @impl Oban.Worker
    def timeout(_job), do: :timer.minutes(5)

    @impl Oban.Worker
    @spec perform(Oban.Job.t()) :: ...
    def perform(%Oban.Job{args: args}) do
      repo = Rindle.Config.repo()
      ...
```

**Phase 35 deltas:**
- D-18: `IngestProviderWebhook` is PUBLIC (no optional-dep guard wrapping — adopters see it in dashboards even before `:mux` lands), `queue: :rindle_provider, max_attempts: 5`, `timeout(_job) -> 30_000`.
- The guard pattern is required ONLY when the module references `Mux.*` symbols at compile time. `IngestProviderWebhook` works on already-normalized `provider_event` maps; do NOT wrap in `Code.ensure_loaded?`.

**`unique_job_opts/0` shape — copy and adapt** (`lib/rindle/workers/mux_ingest_variant.ex:212-219`):

```elixir
@spec unique_job_opts() :: keyword()
def unique_job_opts do
  [
    fields: [:args, :worker, :queue],
    keys: [:asset_id, :profile, :variant_name],
    states: [:available, :scheduled, :executing, :retryable, :completed],
    period: 86_400
  ]
end
```

**Phase 35 D-20 swap:** `keys: [:event_id]` (not `[:asset_id, :profile, :variant_name]`); `states: [:scheduled, :executing, :retryable]` (NOT `:completed` — re-delivery after success IS a no-op on a different `event_id`, so we don't need to dedupe completed); `period: 86_400`.

**FSM-validate-then-update — copy verbatim** (`lib/rindle/workers/mux_ingest_variant.ex:314-328`):

```elixir
defp transition_uploading(repo, row, profile, asset) do
  # B4 fix: ProviderAssetFSM.transition/3 third arg is a MAP, not keyword list.
  with :ok <-
         ProviderAssetFSM.transition(row.state, "uploading", %{
           profile: profile,
           provider: :mux,
           asset_id: asset.id
         }),
       {:ok, _} <-
         row
         |> MediaProviderAsset.changeset(%{state: "uploading"})
         |> repo.update() do
    :ok
  end
end
```

**Phase 35 D-22 application:** the worker uses this exact `with :ok <- ProviderAssetFSM.transition/3, {:ok, _} <- row |> MediaProviderAsset.changeset(attrs) |> repo.update()` chain. NO `SELECT ... FOR UPDATE` (D-22 — Postgres MVCC + FSM allowlist provides correctness).

**Telemetry redaction — copy verbatim** (`lib/rindle/workers/mux_ingest_variant.ex:460-471`):

```elixir
defp base_metadata(profile, variant_name, provider_asset_id) do
  %{
    profile: profile,
    provider: :mux,
    asset_id: MediaProviderAsset.redact_id(provider_asset_id),
    variant_name: variant_name
  }
end

defp emit_event(stage, measurements, metadata) do
  :telemetry.execute([:rindle, :provider, :ingest, stage], measurements, metadata)
end
```

**Phase 35 D-26 swap:** event names are `[:rindle, :provider, :webhook, :processed | :ignored | :exception]` (NOT `:ingest`). Metadata schema:
```elixir
%{
  provider: :mux,
  event_type: "video.asset.ready",  # raw Mux type
  asset_id: MediaProviderAsset.redact_id(provider_asset_id),  # CRITICAL — redacted
  profile: "MyApp.Profiles.Web",
  from_state: "processing",  # nil if no transition
  to_state: "ready",
  kind: nil  # :out_of_order | :unknown_event | :deferred_to_phase_37 | :error | :invalid_transition | :race_snooze | :dropped
}
```

**Race-snooze posture (D-21) — Phase 35 NEW pattern, no in-tree analog:**

```elixir
# attempt 1 → 5s, attempt 2 → 15s, attempt 3 → 45s, attempt 4 → 90s
# attempt ≥ 5 → {:cancel, :provider_asset_row_missing}
defp handle_missing_row(%Oban.Job{attempt: attempt}) when attempt < 5 do
  delay = Enum.at([5, 15, 45, 90], attempt - 1)
  {:snooze, delay}
end

defp handle_missing_row(%Oban.Job{attempt: _}), do: {:cancel, :provider_asset_row_missing}
```

Snooze does NOT consume `attempt` (Oban semantics — snoozed jobs preserve `max_attempts: 5` budget).

**Two-topic PubSub broadcast — copy verbatim** (`lib/rindle/workers/process_variant.ex:465-500`):

```elixir
defp broadcast_progress(asset, variant, progress, state) do
  ensure_pubsub_started()

  payload = %{
    asset_id: asset.id,
    progress: progress,
    variant_id: variant.id,
    variant_name: variant.name,
    state: state
  }

  event_type = public_event_type(progress, state)

  for topic <- ["rindle:variant:#{variant.id}", "rindle:asset:#{asset.id}"] do
    :ok = PubSub.broadcast(pubsub_server(), topic, {:rindle_event, event_type, payload})
  end

  :ok
end

defp pubsub_server do
  Application.get_env(:rindle, :pubsub_server, Rindle.PubSub)
end
```

**Phase 35 D-31, D-32 swap:**
- Topics: `["rindle:provider_asset:#{media_asset_id}", "rindle:asset:#{media_asset_id}"]` (NOT `"rindle:variant:..."`).
- Topic key is `MediaAsset.id` (NOT `MediaProviderAsset.id`, NOT `provider_asset_id` — D-31 forbids it; security invariant 14).
- Payload (D-32):
  ```elixir
  {:rindle_event, event_type, %{
    asset_id:     binary_id,            # MediaAsset.id
    playback_ids: [String.t()],         # PUBLIC playback ids (safe)
    profile:      String.t(),
    provider:     :mux,
    state:        String.t()
  }}
  ```
  CRITICAL: `provider_asset_id` is NEVER in the payload (security invariant 14).
- D-33: only broadcast `:provider_asset_ready | :provider_asset_errored | :provider_asset_deleted` in Phase 35. `:provider_asset_created` is RESERVED for Phase 37 / MUX-23.

**`Rindle.Config.repo()` call site** (`mux_ingest_variant.ex:97`): worker reads repo via `Rindle.Config.repo()` (NOT `Rindle.Repo`) — adopter-owned posture.

---

### `test/support/mux_webhook_fixtures.ex` (test helper, test-only signing wrapper)

**Analog:** `deps/mux/lib/mux/webhooks/test_utils.ex` — the SDK helper Phase 35 wraps.

**SDK helper — Phase 35 wraps this** (`deps/mux/lib/mux/webhooks/test_utils.ex:30-43`):

```elixir
def generate_signature(payload, secret, _scheme \\ @default_scheme) do
  timestamp = System.system_time(:second)
  signed_payload = "#{timestamp}.#{payload}"
  signature = compute_signature(signed_payload, secret)

  "t=#{timestamp},#{@default_scheme}=#{signature}"
end

def compute_signature(payload, secret) do
  hmac(:sha256, secret, payload)
  |> Base.encode16(case: :lower)
end
```

**Phase 35 wrapper (D-34) — `Rindle.Test.MuxWebhookFixtures.sign_header/3`:**

The SDK helper hardcodes `System.system_time(:second)` — useless for replay-attack tests that need a 600s-old timestamp. The Rindle wrapper exists ONLY to add a `:timestamp` override:

```elixir
defmodule Rindle.Test.MuxWebhookFixtures do
  @moduledoc false

  @doc """
  Mirror of `Mux.Webhooks.TestUtils.generate_signature/2` with a
  `:timestamp` override for replay-attack tests.
  """
  @spec sign_header(payload :: binary(), secret :: binary(), opts :: keyword()) :: binary()
  def sign_header(payload, secret, opts \\ []) do
    timestamp = Keyword.get(opts, :timestamp, System.system_time(:second))
    signed_payload = "#{timestamp}.#{payload}"
    signature =
      :crypto.mac(:hmac, :sha256, secret, signed_payload)
      |> Base.encode16(case: :lower)
    "t=#{timestamp},v1=#{signature}"
  end
end
```

**HMAC recipe is verified** (D-35) — matches SDK's `compute_signature/2` byte-for-byte.

---

### `test/fixtures/mux/webhook_video_asset_deleted.json` (test fixture, NEW)

**Analog:** `test/fixtures/mux/webhook_video_asset_errored.json` — sibling fixture shape.

**Sibling reference shape** (`test/fixtures/mux/webhook_video_asset_errored.json:1-18`):

```json
{
  "type": "video.asset.errored",
  "id": "evt-fixture-errored-0001",
  "object": {
    "type": "asset",
    "id": "AbCd1234EfGh5678IjKl9012MnOp3456QrSt"
  },
  "data": {
    "id": "AbCd1234EfGh5678IjKl9012MnOp3456QrSt",
    "status": "errored",
    "errors": {
      "type": "input_error",
      "messages": ["Failed to fetch input from signed URL"]
    }
  },
  "created_at": "2026-05-06T00:01:00.000Z"
}
```

**Phase 35 D-36 deltas:**
- `type: "video.asset.deleted"`, `id: "evt-fixture-deleted-0001"`.
- `data` is sparse: `{id, status: "deleted"}` — no `playback_ids`, no `errors`, no `duration`.
- Use realistic 36-char Mux asset IDs (e.g., `00ecNLnqiG02mmQwOgcEeYQU3aAtqiHIyMb01YGKcqj017A`) — NOT the placeholder `AbCd1234...` style.

---

### `test/fixtures/mux/webhook_video_upload_asset_created.json` (test fixture, NEW)

**Analog:** `test/fixtures/mux/webhook_video_asset_created.json` — sibling fixture shape.

**Sibling reference** (`test/fixtures/mux/webhook_video_asset_created.json:1-15`):

```json
{
  "type": "video.asset.created",
  "id": "evt-fixture-created-0001",
  "object": {
    "type": "asset",
    "id": "AbCd1234EfGh5678IjKl9012MnOp3456QrSt"
  },
  "data": {
    "id": "AbCd1234EfGh5678IjKl9012MnOp3456QrSt",
    "status": "preparing",
    "playback_ids": null
  },
  "created_at": "2026-05-06T00:00:00.000Z"
}
```

**Phase 35 D-29 critical delta:** `data.id` is the UPLOAD-id, `data.asset_id` is the asset-id (silent footgun — current generic `Event.normalize/1` mis-attributes `data.id` as `provider_asset_id`):

```json
{
  "type": "video.upload.asset_created",
  "id": "evt-fixture-upload-asset-created-0001",
  "data": {
    "id": "<UPLOAD-ID; 36-char>",
    "asset_id": "<ASSET-ID; 36-char>"
  },
  "created_at": "..."
}
```

The Phase 35 `Event.normalize/1` typed branch (D-29 — see `lib/rindle/streaming/provider/mux/event.ex` modifications below) reads `data.asset_id` for `provider_asset_id` and `data.id` for `upload_id`.

---

### `test/rindle/delivery/webhook_plug_test.exs` (test, request-response)

**Analog:** `test/rindle/delivery/local_plug_test.exs` — the existing in-tree Plug test pattern.

**Test header — copy verbatim** (`test/rindle/delivery/local_plug_test.exs:1-7`):

```elixir
defmodule Rindle.Delivery.LocalPlugTest do
  use Rindle.DataCase, async: true

  alias Plug.Conn
  alias Plug.Test
  alias Rindle.Delivery.LocalPlug
  alias Rindle.Storage.Local
```

**Phase 35 D-37 specific test pattern** (synthetic `Plug.Test.conn` does NOT invoke the body reader — pre-populate manually):

```elixir
# D-37 — for unit tests of the Plug, manually pre-populate :raw_body
conn =
  :post
  |> Plug.Test.conn("/", body)
  |> Plug.Conn.assign(:raw_body, [body])
  |> Plug.Conn.put_req_header("mux-signature", sig_header)
```

The `signed_conn/4` helper bakes this in. Real HTTP integration via `Bypass` or `Phoenix.ConnTest` with a router DOES invoke the body reader — use that path for end-to-end tests.

**Phase 35 D-38 zero-Mox posture:** the Plug + worker test path uses ZERO new Mox expectations. `Rindle.Streaming.Provider.Mux.ClientMock` (Phase 34) remains unused for the Phase 35 happy path.

---

### `test/rindle/delivery/webhook_body_reader_test.exs` (test, request-response)

**Analog:** `test/rindle/delivery/local_plug_test.exs` — same `Plug.Test.conn` pattern with body parsing.

**Phase 35 test focuses:**
- `read_body/2` chunked reads (D-07): `Plug.Test.conn(:post, "/", body)` with body large enough to force multiple `{:more, ...}` reads.
- `read_body/2` 1 MiB cap (D-08): body just over 1 MiB returns `{:error, :too_large}`.
- `raw_body/1` accessor: list-of-one-binary returns `List.first`; multi-chunk list returns reversed iodata-to-binary; missing assign returns `nil`.

---

### `test/rindle/workers/ingest_provider_webhook_test.exs` (test, event-driven)

**Analog:** `test/rindle/workers/mux_ingest_variant_test.exs` — Oban worker test pattern with the same queue, FSM, telemetry redaction posture.

**Phase 35 test focuses:**
- Idempotency under Oban `unique` keyed on `event_id` (D-20).
- FSM transitions per D-27 dispatch table (`:ready`, `:errored`, `:deleted`, `:created → :processing`).
- `:upload_asset_created` no-op + bump `last_event_at` (D-27).
- Unknown event type → `:ok` no-op + bump `last_event_at` + telemetry `kind: :unknown_event` (D-25).
- Race-snooze attempt curve: missing row → `{:snooze, 5} | {:snooze, 15} | {:snooze, 45} | {:snooze, 90} | {:cancel, :provider_asset_row_missing}` (D-21).
- FSM rejection → `{:cancel, ...}` (D-23).
- Repo error → `raise` → Oban retry (D-24).
- Telemetry: `[:rindle, :provider, :webhook, :processed]` with redacted `asset_id` metadata (D-26 + security invariant 14).
- Two-topic PubSub broadcast on `"rindle:provider_asset:#{asset.id}"` AND `"rindle:asset:#{asset.id}"` (D-31).
- PubSub payload omits `provider_asset_id` (security invariant 14, D-32).

---

### `test/rindle/streaming/provider/mux/event_test.exs` (test, transform — EXTENDED)

**Analog:** itself — the existing `event_test.exs` already covers the generic `normalize/1` branch. Phase 35 D-29 adds cases for:
- `video.upload.asset_created` typed branch returns `%{type: :upload_asset_created, provider_asset_id: data["asset_id"], upload_id: data["id"], playback_ids: [], state: nil, ...}`.
- `:upload_asset_created` is in `normalize_type/1` clauses.
- The fixture loaded is `webhook_video_upload_asset_created.json`.

---

## File Modification Patterns

### `lib/rindle/streaming/provider/mux/event.ex` (MOD — D-29)

**Existing shape** (`lib/rindle/streaming/provider/mux/event.ex:17-36`):

```elixir
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
defp normalize_type(_), do: :unknown
```

**Phase 35 D-29 addition — INSERT typed branch BEFORE the generic clause** (so pattern-match order is correct):

```elixir
def normalize(%{"type" => "video.upload.asset_created", "data" => data} = raw) when is_map(data) do
  {:ok,
   %{
     type: :upload_asset_created,
     provider_asset_id: Map.get(data, "asset_id"),  # NB: NOT data["id"]
     upload_id: Map.get(data, "id"),
     playback_ids: [],
     state: nil,
     occurred_at: parse_occurred_at(Map.get(raw, "created_at")),
     raw: raw
   }}
end

# ... existing generic clause ...

defp normalize_type("video.upload.asset_created"), do: :upload_asset_created
# ... existing normalize_type clauses ...
```

**Critical invariant:** the typed branch MUST come BEFORE the generic `def normalize(%{"type" => type, ...})` clause; otherwise the generic branch matches first and `data.id` (the upload-id) gets mis-assigned to `provider_asset_id`. Test `event_test.exs` MUST cover this ordering.

---

### `lib/rindle/streaming/provider.ex` (MOD — D-30)

**Existing typespec** (`lib/rindle/streaming/provider.ex:52-59`):

```elixir
@type provider_event :: %{
        required(:type) => atom(),
        required(:provider_asset_id) => provider_asset_id() | nil,
        required(:playback_ids) => [playback_id()],
        required(:state) => provider_state() | nil,
        required(:occurred_at) => DateTime.t() | nil,
        required(:raw) => map()
      }
```

**Phase 35 D-30 addition — append optional field:**

```elixir
@type provider_event :: %{
        required(:type) => atom(),
        required(:provider_asset_id) => provider_asset_id() | nil,
        required(:playback_ids) => [playback_id()],
        required(:state) => provider_state() | nil,
        required(:occurred_at) => DateTime.t() | nil,
        required(:raw) => map(),
        optional(:upload_id) => String.t() | nil   # added v1.6 Phase 35
      }
```

**Note:** D-19 (worker arg shape) also references `event_id` and `event_type` keys. The CONTEXT.md typespec snippet at line 400 shows a DIFFERENT shape with `:event_id` and `:event_type` required — this conflicts with the v1.5-shipped Phase 33 typespec. The Phase 33 / live source (`provider.ex:52-59`) is the truth; D-30 is purely additive (`upload_id`). The `event_id` / `event_type` keys live in the Oban arg shape (D-19), NOT the `provider_event` typespec.

Additive change only — every existing call site continues to compile and runtime-match.

---

### `lib/rindle/streaming/provider/mux.ex` (MOD — D-05, D-17, D-28)

**`verify_webhook/3` (already shipped Phase 34) — DO NOT TOUCH the loop body** (`lib/rindle/streaming/provider/mux.ex:271-296`):

```elixir
@impl Rindle.Streaming.Provider
def verify_webhook(raw_body, headers, secrets)
    when is_binary(raw_body) and is_map(headers) and is_list(secrets) do
  case fetch_sig_header(headers) do
    {:ok, sig_header} ->
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

          {:error, _} ->
            nil
        end
      end)

    :error ->
      {:error, :provider_webhook_invalid}
  end
end
```

**Phase 35 D-05 modification — drop dead case-fork at lines 298-304:**

```elixir
# REMOVE the case-fork:
defp fetch_sig_header(headers) do
  cond do
    Map.has_key?(headers, "mux-signature") -> {:ok, Map.fetch!(headers, "mux-signature")}
    Map.has_key?(headers, "Mux-Signature") -> {:ok, Map.fetch!(headers, "Mux-Signature")}
    true -> :error
  end
end

# REPLACE with lowercase-only (Plug.Conn already lowercases per HTTP/2 spec):
defp fetch_sig_header(headers) do
  case Map.fetch(headers, "mux-signature") do
    {:ok, value} -> {:ok, value}
    :error -> :error
  end
end
```

**Phase 35 D-17 addition — provider-internal telemetry inside `verify_webhook/3`:**

Wrap each secret-loop iteration to emit `[:rindle, :provider, :mux, :webhook_attempt, :rejected]` with the SDK reason string when `Mux.Webhooks.verify_header/4` returns `{:error, sdk_reason}`. This is provider-INTERNAL telemetry, additive, does NOT touch the public `Rindle.Streaming.Provider.verify_webhook/3` callback contract (which still returns `:ok | {:error, :provider_webhook_invalid}`).

Also emit `[:rindle, :provider, :mux, :webhook_attempt, :secret_used]` with `metadata: %{secret_index: i}` when a secret matches — operators confirm rotation completed before retiring the previous secret (success criterion 4).

**Phase 35 D-28 addition — `dispatch_kind/1` helper** (`@moduledoc false`, internal):

```elixir
@doc false
@spec dispatch_kind(String.t()) :: :dispatch | :drop
def dispatch_kind("video.asset.ready"), do: :dispatch
def dispatch_kind("video.asset.errored"), do: :dispatch
def dispatch_kind("video.asset.deleted"), do: :dispatch
def dispatch_kind("video.asset.created"), do: :dispatch
def dispatch_kind("video.upload.asset_created"), do: :dispatch
# DROP table — events Rindle v1.6 does not care about (per Mux 2026 catalog):
def dispatch_kind("video.asset.updated"), do: :drop
def dispatch_kind("video.asset.warning"), do: :drop
def dispatch_kind("video.asset.non_standard_input_detected"), do: :drop
def dispatch_kind("video.asset.master." <> _), do: :drop
def dispatch_kind("video.asset.track." <> _), do: :drop
def dispatch_kind("video.asset.static_rendition." <> _), do: :drop
def dispatch_kind("video.asset.live_stream_completed"), do: :drop
def dispatch_kind("video.upload." <> _), do: :drop  # direct uploads (Phase 37)
def dispatch_kind("video.live_stream." <> _), do: :drop
def dispatch_kind(_other), do: :drop  # default: drop unknown events (forward-compat safety)
```

The Plug consults `dispatch_kind/1` BEFORE enqueuing — `:drop` returns `200 OK` with empty body + telemetry `kind: :dropped, event_type: <type>`; `:dispatch` enqueues the worker.

**Internal ordering** of `dispatch_kind/1` clauses is planner discretion (alphabetical vs by frequency).

---

### `lib/rindle/ops/runtime_status.ex` (MOD — D-39, D-40)

**Analog inside the same file:** `variant_report/3` (lines 82-107) is the template `provider_assets_report/2` mirrors.

**`variant_report/3` template — copy structure** (`lib/rindle/ops/runtime_status.ex:82-107`):

```elixir
defp variant_report(filters, cutoff, now) do
  rows =
    variant_finding_rows_query(filters, cutoff)
    |> Config.repo().all()

  findings =
    rows
    |> classify_variants(oban_index(rows), now)
    |> summarize_findings(filters.limit)

  counts =
    from(v in MediaVariant,
      join: a in MediaAsset,
      on: a.id == v.asset_id,
      select: {v.state, count(v.id)}
    )
    |> maybe_filter_profile(:variant, filters.profile)
    |> group_by([v, _a], v.state)
    |> Config.repo().all()
    |> count_map()

  %{
    counts: Map.put(counts, :total, Enum.sum(Map.values(counts))),
    findings: findings
  }
end
```

**`summarize_findings/2` shape — copy verbatim** (`lib/rindle/ops/runtime_status.ex:360-374`):

```elixir
defp summarize_findings(samples, limit) do
  samples
  |> Enum.group_by(& &1.class)
  |> Enum.sort_by(fn {class, _} -> Atom.to_string(class) end)
  |> Enum.map(fn {class, rows} ->
    sorted = Enum.sort_by(rows, &{-&1.age_seconds, inspect(&1.sample)})

    %{
      class: class,
      count: length(rows),
      oldest_age_seconds: hd(sorted).age_seconds,
      samples: sorted |> Enum.take(limit) |> Enum.map(& &1.sample)
    }
  end)
end
```

**`recommendation_for_class/1` shape — copy verbatim** (`lib/rindle/ops/runtime_status.ex:392-420`):

```elixir
defp recommendation_for_class(:probe_drift) do
  %{
    class: :probe_drift,
    action: :reprobe,
    surface: "Rindle.reprobe/1",
    summary: "Refresh probe-owned fields for affected assets."
  }
end
```

**Phase 35 additions:**

1. **`@allowed_filter_keys` extension** (line 11): add `:provider_stuck` to the existing `[:profile, :older_than, :limit, :format]`.

2. **`provider_assets_report/2` (NEW)** modeled on `variant_report/3` — D-40 sample shape:

   ```elixir
   defp provider_assets_report(filters, now) do
     threshold =
       filters[:provider_stuck_threshold_seconds] ||
         Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])[:provider_stuck_threshold_seconds] ||
         7200

     # filters.older_than (operator override) wins over the app-config default (D-39)
     effective_threshold = filters.older_than || threshold

     rows =
       provider_assets_finding_rows_query(filters, effective_threshold, now)
       |> Config.repo().all()
       |> Enum.map(&provider_asset_sample(&1, now))

     %{
       counts: provider_assets_counts(filters),
       threshold_seconds: effective_threshold,
       findings: summarize_findings(rows, filters.limit)
     }
   end
   ```

3. **Sample shape (D-40 — security invariant 14):**

   ```elixir
   defp provider_asset_sample(row, now) do
     %{
       class: :provider_stuck,
       age_seconds: age_seconds(row.updated_at, now),
       sample: %{
         asset_id: row.asset_id,                                    # MediaAsset.id (full UUID)
         provider_asset_id: MediaProviderAsset.redact_id(row.provider_asset_id),  # last-4 tag
         profile: row.profile,
         provider: row.provider_name,
         state: row.state,
         updated_at: row.updated_at,
         last_event_at: row.last_event_at,
         last_sync_error: row.last_sync_error,
         reason: "row stuck in #{row.state} for #{age_seconds(row.updated_at, now)}s"
       }
     }
   end
   ```

4. **New recommendation handler** for class `:provider_stuck`:

   ```elixir
   defp recommendation_for_class(:provider_stuck) do
     %{
       class: :provider_stuck,
       action: :resync,
       surface: "Rindle.Workers.MuxSyncProviderAsset",
       summary: "Re-sync provider state for rows stuck in :uploading or :processing past threshold."
     }
   end
   ```

5. **Wire into top-level `runtime_status/1` return** (lines 39-48): add `provider_assets: provider_assets_report(filters, now)` field to the report map (only when `filters.provider_stuck` is truthy, OR always with `findings: []` when not — planner's call; default-always keeps schema stable).

6. **Query filter:** rows where `state in ("uploading", "processing")` AND `updated_at < now() - threshold`.

---

### `lib/mix/tasks/rindle.runtime_status.ex` (MOD — D-41)

**Existing structure** (`lib/mix/tasks/rindle.runtime_status.ex:27-31`):

```elixir
def run(args) do
  {opts, _rest, _invalid} =
    OptionParser.parse(args,
      strict: [profile: :string, older_than_sec: :integer, limit: :integer, format: :string]
    )
```

**Phase 35 D-41 modification — add `provider_stuck: :boolean`:**

```elixir
def run(args) do
  {opts, _rest, _invalid} =
    OptionParser.parse(args,
      strict: [
        profile: :string,
        older_than_sec: :integer,
        limit: :integer,
        format: :string,
        provider_stuck: :boolean
      ]
    )
```

**`format_findings/1` template — model `format_provider_findings/1` on this** (`lib/mix/tasks/rindle.runtime_status.ex:90-102`):

```elixir
defp format_findings([]), do: ["Findings:", "  none"]

defp format_findings(findings) do
  ["Findings:"] ++
    Enum.flat_map(findings, fn finding ->
      [
        "  #{finding.class}: #{finding.count} (oldest_age_seconds=#{finding.oldest_age_seconds})"
      ] ++
        Enum.map(finding.samples, fn sample ->
          "    - #{sample.variant_name || sample.asset_id}: #{sample.reason}"
        end)
    end)
end
```

**Phase 35 D-41 addition — `format_provider_findings/1`:**

```elixir
defp format_provider_findings([]), do: ["Provider asset findings:", "  none"]

defp format_provider_findings(findings) do
  ["Provider asset findings:"] ++
    Enum.flat_map(findings, fn finding ->
      [
        "  #{finding.class}: #{finding.count} (oldest_age_seconds=#{finding.oldest_age_seconds})"
      ] ++
        Enum.map(finding.samples, fn sample ->
          "    - #{sample.asset_id} (#{sample.provider_asset_id}): #{sample.reason}"
        end)
    end)
end
```

**Wire into `format_text_report/1`** (line 57-74) — append `format_provider_findings(report.provider_assets.findings)` to the section list. Section order: keep existing (runtime_checks → assets → variants → upload_sessions) and append `provider_assets` AFTER `upload_sessions` and BEFORE `format_recommendations(report.recommendations)`.

**Format-detail discretion:** column widths, indentation match existing `format_findings/1` style — planner picks (CONTEXT.md "Claude's Discretion" item).

---

### `test/fixtures/mux/webhook_video_asset_{ready,errored,created}.json` (MOD — D-36)

**Existing placeholder IDs:** `AbCd1234EfGh5678IjKl9012MnOp3456QrSt` (36 chars but synthetic).

**Phase 35 D-36 swap:** replace with realistic 36-char Mux-style asset IDs (base32-ish), e.g., `00ecNLnqiG02mmQwOgcEeYQU3aAtqiHIyMb01YGKcqj017A`. Keep `id` (top-level event id) untouched — those are `evt-fixture-*-NNNN` (deliberately synthetic for test traceability).

**Critical:** tests assert on SPECIFIC keys (`assert %{type: :ready, state: "ready"} = evt`), NEVER on the full `data` map. Mux ships new fields regularly; full-map asserts trip on every Mux schema update.

---

### `test/rindle/streaming/provider/mux/mux_test.exs:174-181` (MOD — D-34)

**Existing handrolled HMAC** (`test/rindle/streaming/provider/mux/mux_test.exs:174-181`):

```elixir
# Compute the v1 signature the same way Mux.Webhooks.verify_header does:
# HMAC-SHA256("#{timestamp}.#{body}", secret) -> hex.
signed_payload = "#{timestamp}.#{body}"

sig =
  :crypto.mac(:hmac, :sha256, secret, signed_payload)
  |> Base.encode16(case: :lower)

headers = %{"mux-signature" => "t=#{timestamp},v1=#{sig}"}
```

**Phase 35 D-34 replacement — thin wrapper call:**

```elixir
sig_header = Rindle.Test.MuxWebhookFixtures.sign_header(body, secret)
headers = %{"mux-signature" => sig_header}
```

(For replay-attack tests — pass `timestamp:` opt: `sign_header(body, secret, timestamp: System.system_time(:second) - 600)`.)

---

## Shared Patterns

### Security Invariant 14 — `provider_asset_id` redaction (THREE Phase 35 layers)

**Source:** `lib/rindle/domain/media_provider_asset.ex:88-95`

```elixir
@spec redact_id(nil | String.t()) :: nil | String.t()
def redact_id(nil), do: nil

def redact_id(id) when is_binary(id) and byte_size(id) >= 4 do
  "..." <> String.slice(id, -4, 4)
end

def redact_id(_), do: "...redacted"
```

**Apply to (all three layers MUST use this helper):**
- **`lib/rindle/workers/ingest_provider_webhook.ex` (D-26)** — telemetry metadata `asset_id:` field.
- **PubSub payload (D-32)** — `provider_asset_id` is FORBIDDEN in payload entirely (NEVER even redacted form). Only `playback_ids` (public) cross.
- **`lib/rindle/ops/runtime_status.ex` (D-40)** — `samples[].provider_asset_id` field uses the redacted last-4 tag; `samples[].asset_id` is the full `MediaAsset.id` UUID (operator's natural key).

The `MediaProviderAsset.redact_id/1` helper is THE single source of truth for the redaction recipe (CONTEXT.md `<specifics>` first bullet).

---

### FSM-validate-then-changeset-update

**Source:** `lib/rindle/domain/provider_asset_fsm.ex:9-49` + `lib/rindle/workers/mux_ingest_variant.ex:314-328`

**Allowlist** (`provider_asset_fsm.ex:9-16`):

```elixir
@allowed_transitions %{
  "pending" => ["uploading", "errored"],
  "uploading" => ["processing", "errored"],
  "processing" => ["ready", "errored"],
  "ready" => ["errored", "deleted"],
  "errored" => ["deleted", "processing"],
  "deleted" => []
}
```

**Apply to:** every state transition in `IngestProviderWebhook` worker. `:errored → :processing` re-ingest edge is included (D-23 / Mux can re-ready a previously-errored asset post-reprocessing).

**Pattern — copy verbatim:**

```elixir
with :ok <- ProviderAssetFSM.transition(row.state, target, %{profile: profile, provider: :mux, asset_id: asset_id}),
     {:ok, updated} <- row |> MediaProviderAsset.changeset(attrs) |> repo.update() do
  {:ok, updated}
end
```

**FSM rejection:** `{:error, {:invalid_transition, from, to}}` → worker returns `{:cancel, {:invalid_transition, from, to}}` (D-23). Polling backstop (`MuxSyncProviderAsset` Phase 34) reconciles genuinely-stuck rows.

---

### `Rindle.Config.repo()` call-site (adopter-owned Repo)

**Source:** `lib/rindle/workers/mux_ingest_variant.ex:97`

```elixir
def perform(%Oban.Job{args: args}) do
  repo = Rindle.Config.repo()
  # ... use repo throughout perform/1 ...
```

**Apply to:** every Phase 35 worker / report function. NEVER reference `Rindle.Repo` directly — adopters bring their own.

---

### `pubsub_server/0` indirection

**Source:** `lib/rindle/workers/process_variant.ex:498-500`

```elixir
defp pubsub_server do
  Application.get_env(:rindle, :pubsub_server, Rindle.PubSub)
end
```

**Apply to:** `Rindle.Workers.IngestProviderWebhook.broadcast_provider_event/2`. Default is `Rindle.PubSub` (started in `application.ex:15`).

---

### `config/2` helper (Mux module) — call-site config reads (no caching)

**Source:** `lib/rindle/streaming/provider/mux.ex:351-355`

```elixir
defp config(key, default \\ nil) do
  :rindle
  |> Application.get_env(__MODULE__, [])
  |> Keyword.get(key, default)
end
```

**Apply to:** every `Rindle.Streaming.Provider.Mux` config read, including the Plug's secrets resolver `{:application, :rindle, [Rindle.Streaming.Provider.Mux, :webhook_secrets]}` (D-02). Phase 34 D-30 locks "no caching" — every call site reads `Application.get_env` afresh so runtime config / rotation works without restart (CONTEXT.md `<deferred>` "Caching Application.get_env reads" — only revisit if profiling shows it materializing).

---

### Telemetry namespacing (Plug vs worker; distinct lifecycles)

| Stage | Event family |
|-------|--------------|
| Plug edge | `[:rindle, :provider, :webhook, :verified \| :rejected \| :secret_used]` |
| Worker | `[:rindle, :provider, :webhook, :processed \| :ignored \| :exception]` |
| Provider-internal (SDK reasons) | `[:rindle, :provider, :mux, :webhook_attempt, :rejected \| :secret_used]` |
| FSM transition (Phase 33, called by worker) | `[:rindle, :provider_asset, :state_change]` |

**Operators see both Plug and worker signals** — `:verified` proves the edge works, `:processed` proves the queue drains. Provider-internal events surface SDK-specific reasons WITHOUT polluting the public callback contract (D-17).

**Metadata always includes `MediaProviderAsset.redact_id/1`-redacted `asset_id`** (security invariant 14).

---

## No Analog Found

No Phase 35 file lacks an analog in either the Rindle codebase or upstream precedent (Plaid `CacheBodyReader` covers the body-reader case the SDK references). The `webhook_body_reader.ex` is the only file without a direct in-tree code excerpt to copy — D-06..D-10 fully specify the contract, and `Plug.Conn.read_body/2` docs cover the chunked-read semantics.

---

## Metadata

**Analog search scope:**
- `lib/rindle/delivery/` (Plug pattern)
- `lib/rindle/streaming/provider/` (provider impl + behaviour + Event normalizer)
- `lib/rindle/workers/` (Oban worker pattern, PubSub broadcast)
- `lib/rindle/domain/` (FSM, schema redaction helper)
- `lib/rindle/ops/` (runtime_status report shape)
- `lib/mix/tasks/` (Mix task wrapper)
- `lib/rindle/application.ex` (PubSub server name)
- `test/rindle/delivery/` + `test/rindle/workers/` + `test/rindle/streaming/provider/mux/` (test patterns)
- `test/fixtures/mux/` (fixture shape)
- `test/support/` (test helper layout)
- `deps/mux/lib/mux/webhooks/test_utils.ex` (SDK signing helper)

**Files scanned:** ~22 source files + 4 fixtures + 6 test files + 1 SDK file = 33 files inspected.

**Pattern extraction date:** 2026-05-06.

**Verification:** every analog file referenced in CONTEXT.md `<code_context>` was opened; line numbers verified against current `main` (commit `879a79b`); excerpts above are byte-accurate paste-able into executor `<read_first>` blocks.
