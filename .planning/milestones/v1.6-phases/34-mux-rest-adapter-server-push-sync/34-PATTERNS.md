# Phase 34: Mux REST Adapter + Server-Push Sync — Pattern Map

**Mapped:** 2026-05-06
**Files analyzed:** 17 (7 lib + 7 test + 3 fixtures-as-data)
**Analogs found:** 16 / 17 (cassette JSON has no in-repo analog; hand-derived from Mux API ref per D-36)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/rindle/streaming/provider/mux.ex` | adapter (provider) | request-response | `lib/rindle/streaming/provider.ex` (the behaviour) + `lib/rindle/live_view.ex` (optional-dep guard) | role-match (no concrete adapter exists yet) |
| `lib/rindle/streaming/provider/mux/client.ex` | behaviour | n/a | `lib/rindle/streaming/provider.ex`, `lib/rindle/storage.ex` | exact (behaviour-with-mock-pair pattern) |
| `lib/rindle/streaming/provider/mux/http.ex` | adapter (HTTP) | request-response | `lib/rindle/storage.ex` (Storage behaviour shape) + `lib/rindle/live_view.ex` (guard) | role-match |
| `lib/rindle/streaming/provider/mux/event.ex` | utility (normalizer) | transform | `lib/rindle/domain/provider_asset_fsm.ex` (pure-function module, `@moduledoc false`) | role-match |
| `lib/rindle/workers/mux_ingest_variant.ex` | worker (Oban) | event-driven (atomic-promote) | `lib/rindle/workers/process_variant.ex` | exact (CONTEXT-named template) |
| `lib/rindle/workers/mux_sync_coordinator.ex` | worker (Oban cron) | batch fan-out | `lib/rindle/workers/cleanup_orphans.ex`, `lib/rindle/workers/abort_incomplete_uploads.ex` | exact (CONTEXT-named template) |
| `lib/rindle/workers/mux_sync_provider_asset.ex` | worker (Oban per-row) | request-response | `lib/rindle/workers/abort_incomplete_uploads.ex` (simple `perform/1` shape) + `process_variant.ex` (FSM transition shape) | role-match |
| `lib/rindle/error.ex` (modify) | utility (error messages) | n/a | `lib/rindle/error.ex` lines 195-272 (existing `:streaming_not_configured`, `:provider_*` clauses) | exact (extend existing pattern) |
| `lib/rindle/domain/media_provider_asset.ex` (modify) | model (schema) | n/a | self — extract `defp redact_id/1` (lines 111-117) to public `def redact_id/1` | exact (in-place promotion) |
| `mix.exs` (modify) | config | n/a | self — current optional dep entry `{:phoenix_live_view, "~> 1.0", optional: true}` line 65 | exact |
| `test/support/mocks.ex` (modify) | test config | n/a | self — line 1-5 existing `Mox.defmock/2` calls | exact (one-line addition) |
| `test/test_helper.exs` (potentially modify) | test config | n/a | self — current 35-line file | exact |
| `test/rindle/streaming/provider/mux/optional_dep_test.exs` | test (smoke) | unit | `test/rindle/streaming/provider_test.exs` + `test/rindle/streaming/capabilities_test.exs` | role-match |
| `test/rindle/streaming/provider/mux/mux_test.exs` | test (Mox-driven) | unit | `test/rindle/workers/process_variant_test.exs` (Mox + DataCase pattern) | exact |
| `test/rindle/streaming/provider/mux/signed_playback_url_test.exs` | test (cassette+JOSE) | unit | `test/rindle/workers/process_variant_test.exs` | role-match |
| `test/rindle/streaming/provider/mux/telemetry_test.exs` | test (`:telemetry.attach`) | unit | `test/rindle/workers/process_variant_test.exs` (telemetry capture pattern) | role-match |
| `test/rindle/workers/mux_ingest_variant_test.exs` | test (Oban.Testing + Mox) | unit | `test/rindle/workers/process_variant_test.exs` | exact |
| `test/rindle/workers/mux_sync_coordinator_test.exs` | test (Oban.Testing) | unit | `test/rindle/workers/maintenance_workers_test.exs` | exact |
| `test/rindle/workers/mux_sync_provider_asset_test.exs` | test (Oban.Testing + Mox) | unit | `test/rindle/workers/maintenance_workers_test.exs` + `process_variant_test.exs` | role-match |
| `test/fixtures/mux/asset_create_201.json` etc. | fixture (data) | n/a | none — first cassette family | no analog (hand-derive per D-36) |
| `test/fixtures/mux/test_signing_private_key.pem` | fixture (key) | n/a | none — first signing-key fixture | no analog (`openssl genrsa -out ... 2048`, D-37) |

## Pattern Assignments

### `lib/rindle/streaming/provider/mux.ex` (adapter, request-response)

**Analog:** `lib/rindle/streaming/provider.ex` (behaviour contract — adapter implements it) + `lib/rindle/live_view.ex` (optional-dep guard)

**Optional-dep guard pattern** (mirrors `lib/rindle/live_view.ex` line 1-2 verbatim):
```elixir
# Compiled only when {:mux, "~> 3.2"} is loaded.
# Adopters who do not configure streaming pay zero transitive cost.
if Code.ensure_loaded?(Mux.Video.Assets) do
  defmodule Rindle.Streaming.Provider.Mux do
    @behaviour Rindle.Streaming.Provider
    # ...
  end
end
```

**Behaviour contract pattern** (callbacks Phase 34 implements — `lib/rindle/streaming/provider.ex:57-95`):
```elixir
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

**Capability advertisement pattern** (mirrors `lib/rindle/streaming/capabilities.ex:18-24` known list):
```elixir
@impl Rindle.Streaming.Provider
def capabilities do
  [:signed_playback, :webhook_ingest, :server_push_ingest]
end
```

**Config-at-call-site pattern** (D-30 — read at every call, no caching; mirrors `Rindle.Config.signed_url_ttl_seconds/0` at `lib/rindle/config.ex:14-16`):
```elixir
defp config(key, default \\ nil) do
  Application.get_env(:rindle, __MODULE__, [])
  |> Keyword.get(key, default)
end
```

**Profile TTL plumbing** (must always pass `:expiration` per Pitfall 1; mirrors `Rindle.Delivery.signed_url_ttl_seconds/1` at `lib/rindle/delivery.ex:84-90`):
```elixir
# Inside signed_playback_url/3:
ttl = Rindle.Delivery.signed_url_ttl_seconds(profile)
jwt = Mux.Token.sign_playback_id(playback_id,
  type: :video,
  expiration: ttl,                     # MUST pass; SDK default is 7 days
  token_id: config(:signing_key_id),
  token_secret: config(:signing_private_key)
)
```

---

### `lib/rindle/streaming/provider/mux/client.ex` (behaviour, no data flow)

**Analog:** `lib/rindle/streaming/provider.ex` (behaviour with `@callback` shapes) + `lib/rindle/storage.ex` (per-call behaviour)

**Behaviour module pattern** (no optional-dep guard needed — pure Elixir):
```elixir
defmodule Rindle.Streaming.Provider.Mux.Client do
  @moduledoc false

  @callback create_asset(map()) :: {:ok, map()} | {:error, term()}
  @callback get_asset(String.t()) :: {:ok, map()} | {:error, term()}
  @callback delete_asset(String.t()) :: :ok | {:error, term()}
end
```

---

### `lib/rindle/streaming/provider/mux/http.ex` (adapter HTTP impl, request-response)

**Analog:** `lib/rindle/streaming/provider.ex` (interface) + `lib/rindle/live_view.ex:1` (guard)

**Guarded behaviour-impl pattern** (Pitfall 4 — must be guarded):
```elixir
if Code.ensure_loaded?(Mux.Video.Assets) do
  defmodule Rindle.Streaming.Provider.Mux.HTTP do
    @moduledoc false
    @behaviour Rindle.Streaming.Provider.Mux.Client

    @impl true
    def create_asset(params) do
      client = build_client()
      Mux.Video.Assets.create(client, params)
    end

    # ... get_asset, delete_asset ...

    defp build_client do
      cfg = Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])
      Mux.Base.new(Keyword.fetch!(cfg, :token_id), Keyword.fetch!(cfg, :token_secret))
    end
  end
end
```

**429 Retry-After extraction pattern** (Pitfall 3; reads from `%Tesla.Env{}.headers` directly):
```elixir
case Mux.Video.Assets.create(client, params) do
  {:ok, asset, _env} ->
    {:ok, asset}

  {:error, _msg, %Tesla.Env{status: 429, headers: headers}} ->
    {:error, {:rate_limited, retry_after_from(headers)}}

  {:error, msg, %Tesla.Env{status: status}} ->
    {:error, {:provider_http, status, msg}}
end

defp retry_after_from(headers) do
  case List.keyfind(headers, "retry-after", 0) do
    {_, val} -> String.to_integer(val)
    _ -> 60
  end
end
```

---

### `lib/rindle/streaming/provider/mux/event.ex` (utility, transform)

**Analog:** `lib/rindle/domain/provider_asset_fsm.ex` (pure-function `@moduledoc false` module)

**Pure-function module pattern** (mirrors `provider_asset_fsm.ex:1-3` shape; pure validator/normalizer with no DB access):
```elixir
defmodule Rindle.Streaming.Provider.Mux.Event do
  @moduledoc false

  @doc """
  Normalize a Mux webhook event JSON map into the locked Phase 33
  `provider_event` shape (see `Rindle.Streaming.Provider.@type provider_event`).
  """
  @spec normalize(map()) :: {:ok, map()} | {:error, term()}
  def normalize(%{"type" => type, "data" => data} = raw) do
    {:ok,
     %{
       type: normalize_type(type),
       provider_asset_id: Map.get(data, "id"),
       playback_ids: Enum.map(Map.get(data, "playback_ids", []), & &1["id"]),
       state: normalize_state(Map.get(data, "status")),
       occurred_at: parse_occurred_at(Map.get(raw, "created_at")),
       raw: raw
     }}
  end
end
```

---

### `lib/rindle/workers/mux_ingest_variant.ex` (worker, event-driven with atomic-promote)

**Analog:** `lib/rindle/workers/process_variant.ex` (CONTEXT D-19 — verbatim mirror)

**Worker macro and queue/timeout shape** (`process_variant.ex:1-3, 22-37`):
```elixir
defmodule Rindle.Workers.MuxIngestVariant do
  @moduledoc """
  Push a Rindle-produced AV variant to Mux from server context.

  ## Adopter wiring (Phase 36 owns canonical guide)

      config :my_app, Oban,
        queues: [rindle_provider: 4]
  """
  use Oban.Worker, queue: :rindle_provider, max_attempts: 5

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(5)   # integer ms only — D-15

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    # ...
  end
end
```

**`unique_job_opts/0` shape** (mirrors `process_variant.ex:408-415` with D-16 changes — `period: 86_400` instead of `:infinity`, expanded states + `:completed`):
```elixir
@doc false
def unique_job_opts do
  [
    fields: [:args, :worker, :queue],
    keys: [:asset_id, :profile, :variant_name],
    states: [:scheduled, :executing, :retryable, :completed],
    period: 86_400  # 24h cooldown — D-16
  ]
end
```

Compare to original (`process_variant.ex:408-415`):
```elixir
defp unique_job_opts do
  [
    fields: [:args, :worker, :queue],
    keys: [:asset_id, :variant_name],
    states: @unique_states,        # @unique_states = [:available, :scheduled, :executing, :retryable]
    period: :infinity
  ]
end
```

**Atomic-promote race protection** (D-19 — mirrors `process_variant.ex:244-275` verbatim with `expected_*` args swap):
```elixir
defp persist_provider_processing(repo, args, mux_response) do
  asset_id = args["asset_id"]
  variant_name = args["variant_name"]

  current_asset = repo.get!(MediaAsset, asset_id)
  current_variant =
    repo.get_by!(MediaVariant, asset_id: asset_id, name: variant_name)

  cond do
    current_asset.storage_key != args["expected_storage_key"] ->
      {:cancel, {:stale_source, :asset_changed}}

    current_variant.recipe_digest != args["expected_recipe_digest"] ->
      {:cancel, {:stale_source, :recipe_changed}}

    true ->
      with {:ok, row} <- upsert_provider_row(repo, args, mux_response),
           :ok <- ProviderAssetFSM.transition(row.state, "processing",
                    profile: args["profile"], provider: :mux, asset_id: asset_id) do
        # ... persist next state via changeset ...
        :ok
      end
  end
end
```

Source pattern (`process_variant.ex:244-275`):
```elixir
defp persist_ready(repo, asset, variant, storage_meta, dest_tmp, variant_spec, output_attrs) do
  current_asset = repo.get!(MediaAsset, asset.id)
  current_variant = repo.get!(MediaVariant, variant.id)

  cond do
    current_asset.storage_key != asset.storage_key ->
      {:cancel, {:stale_source, :asset_changed}}

    current_variant.recipe_digest != variant.recipe_digest ->
      {:cancel, {:stale_source, :recipe_changed}}

    true ->
      with :ok <- update_variant_state(repo, current_variant, "ready", %{...}),
           :ok <- AssetAggregate.recompute(repo, asset.id) do
        :ok
      end
  end
end
```

**Telemetry execute pattern** (mirrors `process_variant.ex:461-463`, schema swap to `:provider`):
```elixir
defp emit_provider_event(stage, measurements, metadata) do
  :telemetry.execute([:rindle, :provider, :ingest, stage], measurements, metadata)
end
```

**Telemetry redaction at emit site** (Pitfall 5 — never raw `provider_asset_id`):
```elixir
metadata = %{
  profile: profile,
  provider: :mux,
  asset_id: MediaProviderAsset.redact_id(row.provider_asset_id),  # last-4 char tag
  variant_name: variant_name
}
```

**Repo access pattern** (mirrors `process_variant.ex:24` `repo = Config.repo()`):
```elixir
@impl Oban.Worker
def perform(%Oban.Job{args: args}) do
  repo = Rindle.Config.repo()
  # ...
end
```

**Error normalization with `{:cancel, ...}` and `{:snooze, ...}` returns** (Pitfall 3):
```elixir
case Mux.Video.Assets.create(client, params) do
  {:ok, asset, _env} ->
    persist_provider_processing(repo, args, asset)

  {:error, _msg, %Tesla.Env{status: 429, headers: headers}} ->
    {:snooze, retry_after_from(headers)}

  {:error, _msg, %Tesla.Env{status: status}} when status in 500..599 ->
    {:error, :provider_sync_failed}

  {:error, _msg, %Tesla.Env{status: status}} when status in 400..499 ->
    # persist last_sync_error truncated 4096; transition to :errored
    transition_to_errored(repo, args, status)
    {:error, :provider_sync_failed}
end
```

---

### `lib/rindle/workers/mux_sync_coordinator.ex` (worker, batch fan-out cron)

**Analog:** `lib/rindle/workers/cleanup_orphans.ex` + `lib/rindle/workers/abort_incomplete_uploads.ex`

**Module shape and `@moduledoc` cron snippet** (mirrors `cleanup_orphans.ex:1-57` and `abort_incomplete_uploads.ex:1-65`):
```elixir
defmodule Rindle.Workers.MuxSyncCoordinator do
  @moduledoc """
  Oban cron worker that fans out per-row sync jobs for `media_provider_assets`
  rows in (`processing`, `uploading`) older than `provider_polling_floor_seconds`.

  Delegates per-row work to `Rindle.Workers.MuxSyncProviderAsset`. No sync logic
  lives here. Adopters can schedule this worker from their Oban cron config
  without requiring Rindle to supervise Oban.

  ## Cron Configuration Example

  In your Oban configuration:

      config :my_app, Oban,
        queues: [rindle_provider: 4],
        plugins: [
          {Oban.Plugins.Cron,
           crontab: [
             {"* * * * *", Rindle.Workers.MuxSyncCoordinator}
           ]}
        ]

  ## Job Arguments

  This worker accepts no arguments. All behavior is driven by the
  `:provider_polling_floor_seconds` config.

  ## Return Contract

    * `:ok` — fan-out completed; per-row jobs have been enqueued.
    * Coordinator runs with `max_attempts: 1` because a missed cron tick is
      always cheaper to skip and re-run on the next tick than to retry mid-fanout.
  """

  use Oban.Worker, queue: :rindle_provider, max_attempts: 1
  # ...
end
```

**`perform/1` shape with explicit `@spec`** (mirrors `cleanup_orphans.ex:65-67` and `abort_incomplete_uploads.ex:71-73`):
```elixir
@spec perform(Oban.Job.t()) :: :ok | {:error, term()}
@impl Oban.Worker
def perform(%Oban.Job{}) do
  # ...
end
```

**Coordinator query + fan-out pattern** (D-23 verbatim):
```elixir
@impl Oban.Worker
def perform(%Oban.Job{}) do
  floor = config(:provider_polling_floor_seconds, 30)
  cutoff = DateTime.add(DateTime.utc_now(), -floor, :second)
  repo = Rindle.Config.repo()

  repo.all(
    from r in MediaProviderAsset,
      where: r.state in ["processing", "uploading"]
        and r.updated_at < ^cutoff,
      select: r.provider_asset_id
  )
  |> Enum.each(fn provider_asset_id ->
    %{"provider_asset_id" => provider_asset_id}
    |> Rindle.Workers.MuxSyncProviderAsset.new(
      unique: [fields: [:args, :worker], period: 60, keys: [:provider_asset_id]]
    )
    |> Oban.insert()
  end)

  :ok
end
```

**Logger/telemetry on fan-out completion** (mirrors `cleanup_orphans.ex:101-124`):
```elixir
Logger.info("rindle.workers.mux_sync_coordinator.completed",
  rows_scanned: length(rows),
  jobs_enqueued: enqueued,
  floor_seconds: floor
)
```

---

### `lib/rindle/workers/mux_sync_provider_asset.ex` (worker, per-row request-response)

**Analog:** `lib/rindle/workers/abort_incomplete_uploads.ex` (simple `perform/1` shape) + `process_variant.ex` (FSM-transition handling)

**Module + queue shape** (D-24, D-25):
```elixir
defmodule Rindle.Workers.MuxSyncProviderAsset do
  @moduledoc false
  use Oban.Worker, queue: :rindle_provider, max_attempts: 3

  @spec perform(Oban.Job.t()) :: :ok | {:error, term()}
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"provider_asset_id" => provider_asset_id}}) do
    # ...
  end
end
```

**Per-row sync flow** (D-24):
1. Fetch row by `provider_asset_id`
2. Call `Rindle.Streaming.Provider.Mux.get_asset(provider_asset_id)` (delegates to `Client.HTTP`)
3. Compare provider state to row state; transition via `ProviderAssetFSM.transition/3`
4. If row's `updated_at` exceeds `provider_stuck_threshold_seconds`: transition to `:errored` with `last_sync_error: "stuck in :processing past threshold"`; emit `[:rindle, :provider, :sync, :stuck]`
5. Else emit `[:rindle, :provider, :sync, :resolved]` with `provider_state` metadata

**FSM transition usage** (`provider_asset_fsm.ex:28-49`):
```elixir
:ok = ProviderAssetFSM.transition(row.state, target_state,
  profile: row.profile,
  provider: :mux,
  asset_id: row.asset_id
)
```

---

### `lib/rindle/error.ex` (utility, modify — extend message clauses)

**Analog:** Self — existing `def message(%{reason: ...})` clauses at lines 195-272.

**Existing `:provider_*` clauses already shipped** (lines 223-272):
```elixir
def message(%{reason: :provider_asset_not_ready}) do
  """
  The provider asset is not yet ready for playback.
  ...
  """ |> String.trim()
end

def message(%{reason: :provider_webhook_invalid}) do ... end
def message(%{reason: :provider_sync_failed}) do ... end
def message(%{reason: :provider_quota_exceeded}) do ... end
```

**Phase 34 may add** (per "Claude's Discretion" in CONTEXT — exact wording is impl detail; atom set was locked in Phase 33):
- Refinements to the bare-atom messages above to mention Mux-specific dashboards/UIs
- New clauses only if a Mux-specific atom not already in Phase 33 is required (atom set is otherwise locked)

**Pattern style** (mirrors lines 195-272):
```elixir
def message(%{reason: :the_atom}) do
  """
  Plain-English description.

  To fix:
    1. ...
    2. ...

  Reference: ...
  """
  |> String.trim()
end
```

---

### `lib/rindle/domain/media_provider_asset.ex` (model, modify — promote `redact_id/1` to public)

**Analog:** Self — currently `defp redact_id/1` at lines 111-117 inside `defimpl Inspect`.

**Current shape** (`media_provider_asset.ex:100-118`):
```elixir
defimpl Inspect, for: Rindle.Domain.MediaProviderAsset do
  def inspect(asset, opts) do
    redacted = %{
      asset
      | provider_asset_id: redact_id(asset.provider_asset_id),
        raw_provider_metadata: %{redacted: true}
    }

    Inspect.Any.inspect(redacted, opts)
  end

  defp redact_id(nil), do: nil

  defp redact_id(id) when is_binary(id) and byte_size(id) >= 4 do
    "..." <> String.slice(id, -4, 4)
  end

  defp redact_id(_), do: "...redacted"
end
```

**Phase 34 promotion** (per Open Question 1, A4): extract to public `def redact_id/1` on the schema module (NOT on the Inspect impl) so workers/telemetry can call it without depending on Inspect:
```elixir
defmodule Rindle.Domain.MediaProviderAsset do
  # ... existing schema ...

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
end

defimpl Inspect, for: Rindle.Domain.MediaProviderAsset do
  def inspect(asset, opts) do
    redacted = %{
      asset
      | provider_asset_id: Rindle.Domain.MediaProviderAsset.redact_id(asset.provider_asset_id),
        raw_provider_metadata: %{redacted: true}
    }
    Inspect.Any.inspect(redacted, opts)
  end
end
```

---

### `mix.exs` (config, modify — add optional deps + PLT)

**Analog:** Self — existing pattern `{:phoenix_live_view, "~> 1.0", optional: true}` at line 65.

**deps/0 entries to add** (D-01):
```elixir
defp deps do
  [
    # ... existing entries ...

    # Streaming providers (optional — Mux adapter only loads when these are present)
    {:mux, "~> 3.2", optional: true},
    {:jose, "~> 1.11", optional: true},

    # ... rest ...
  ]
end
```

**PLT add_apps** (D-02; current dialyzer block at lines 20-24):
```elixir
dialyzer: [
  plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
  plt_add_apps: [:mix, :ex_unit, :mux, :jose],   # ADD :mux and :jose
  ignore_warnings: ".dialyzer_ignore.exs"
]
```

---

### `test/support/mocks.ex` (test config, modify — one-line addition)

**Analog:** Self — existing 5-line file:
```elixir
Mox.defmock(Rindle.StorageMock, for: Rindle.Storage)
Mox.defmock(Rindle.ProcessorMock, for: Rindle.Processor)
Mox.defmock(Rindle.AnalyzerMock, for: Rindle.Analyzer)
Mox.defmock(Rindle.ScannerMock, for: Rindle.Scanner)
Mox.defmock(Rindle.AuthorizerMock, for: Rindle.Authorizer)
```

**Phase 34 addition** (D-34, D-39):
```elixir
Mox.defmock(Rindle.Streaming.Provider.Mux.ClientMock,
  for: Rindle.Streaming.Provider.Mux.Client)
```

---

### `test/test_helper.exs` (test config, may not need modification)

**Analog:** Self — current 35-line file already calls `Code.require_file("support/mocks.ex", __DIR__)` at line 33-35 if `Rindle.StorageMock` not yet loaded. The pattern auto-picks-up new `Mox.defmock` entries.

**Pattern** (no changes needed unless Mox load order differs):
```elixir
unless Code.ensure_loaded?(Rindle.StorageMock) do
  Code.require_file("support/mocks.ex", __DIR__)
end
```

---

### `test/rindle/workers/mux_ingest_variant_test.exs` (test, Oban.Testing + Mox)

**Analog:** `test/rindle/workers/process_variant_test.exs`

**Test module setup** (mirrors `process_variant_test.exs:1-10`):
```elixir
defmodule Rindle.Workers.MuxIngestVariantTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo
  import Mox

  alias Rindle.Domain.{MediaAsset, MediaVariant, MediaProviderAsset}
  alias Rindle.Workers.MuxIngestVariant

  setup :set_mox_from_context
  setup :verify_on_exit!
end
```

**Inline TestProfile pattern** (mirrors `process_variant_test.exs:12-30`):
```elixir
defmodule TestProfile do
  use Rindle.Profile,
    storage: Rindle.StorageMock,
    streaming: Rindle.Streaming.Provider.Mux,
    variants: [
      hero: [kind: :video, preset: :web_720p]
    ],
    allow_mime: ["video/mp4"],
    max_bytes: 524_288_000
end
```

**Mox expectations + perform_job pattern** (mirrors `process_variant_test.exs:82-100`):
```elixir
test "ingests variant, persists provider_asset_id, advances FSM to processing", ctx do
  expect(Rindle.Streaming.Provider.Mux.ClientMock, :create_asset, fn params ->
    assert params["inputs"] == [%{"url" => _signed_storage_url}]
    assert params["playback_policies"] == ["signed"]
    {:ok, fixture("asset_create_201.json")}
  end)

  args = %{
    "asset_id" => ctx.asset.id,
    "profile" => to_string(TestProfile),
    "variant_name" => "hero",
    "expected_storage_key" => ctx.asset.storage_key,
    "expected_recipe_digest" => ctx.variant.recipe_digest
  }

  assert :ok = perform_job(MuxIngestVariant, args)
  # ... assertions on media_provider_assets row + FSM state ...
end
```

**`set_mox_from_context` is correct** (Pitfall 5 — Oban testing process IS the test process, so process-local Mox works).

---

### `test/rindle/workers/mux_sync_coordinator_test.exs` (test, Oban.Testing + Repo)

**Analog:** `test/rindle/workers/maintenance_workers_test.exs`

**TestRepoProbe pattern** (mirrors `maintenance_workers_test.exs:16-39`):
```elixir
defmodule TestRepoProbe do
  @moduledoc false
  def all(queryable) do
    notify(:all)
    AdopterRepo.all(queryable)
  end
  # ... etc ...

  defp notify(event) do
    if owner = Application.get_env(:rindle, :repo_probe_owner) do
      send(owner, {:repo_probe, event})
    end
  end
end
```

**Setup with adopter Repo + Sandbox checkout** (mirrors `maintenance_workers_test.exs:41-69`):
```elixir
setup do
  case start_supervised(AdopterRepo) do
    {:ok, _pid} -> :ok
    {:error, {:already_started, _pid}} -> :ok
  end

  Sandbox.checkout(AdopterRepo)
  Sandbox.mode(AdopterRepo, {:shared, self()})

  Application.put_env(:rindle, :repo, TestRepoProbe)
  Application.put_env(:rindle, :repo_probe_owner, self())

  on_exit(fn -> ... end)
  :ok
end
```

**Cron worker test pattern** (use `Oban.Testing.perform_job/2` with empty args; assert fan-out via `assert_enqueued/1`).

---

### `test/rindle/workers/mux_sync_provider_asset_test.exs` (test, Oban.Testing + Mox)

**Analog:** `test/rindle/workers/process_variant_test.exs` + `maintenance_workers_test.exs`

**Pattern:** Same `setup :set_mox_from_context; setup :verify_on_exit!` as `process_variant_test.exs`. Insert a `media_provider_assets` row, expect `Rindle.Streaming.Provider.Mux.ClientMock.get_asset/1` to return one of the cassette fixtures, call `perform_job/2`, assert FSM transition + telemetry.

---

### `test/rindle/streaming/provider/mux/mux_test.exs` (test, Mox-driven)

**Analog:** `test/rindle/workers/process_variant_test.exs` (Mox + DataCase pattern)

**Pattern:** No Oban.Testing needed (pure adapter calls). `setup :set_mox_from_context; setup :verify_on_exit!`. Each test stubs `Rindle.Streaming.Provider.Mux.ClientMock` and calls the adapter functions directly:
```elixir
test "create_asset/3 reshapes Mux response to Phase 33 contract" do
  expect(Rindle.Streaming.Provider.Mux.ClientMock, :create_asset, fn _params ->
    {:ok, fixture("asset_create_201.json")}
  end)

  assert {:ok, %{provider_asset_id: id, playback_ids: [_pid | _]}} =
           Rindle.Streaming.Provider.Mux.create_asset(TestProfile, "https://...", [])
end
```

**Configure adapter to use the mock** (per-test or globally in `config/test.exs`):
```elixir
config :rindle, Rindle.Streaming.Provider.Mux,
  http_client: Rindle.Streaming.Provider.Mux.ClientMock
```

---

### `test/rindle/streaming/provider/mux/signed_playback_url_test.exs` (test, JOSE-decode JWT)

**Analog:** `test/rindle/workers/process_variant_test.exs` (DataCase + setup)

**Critical assertion** (Pitfall 1 — never silently mint a 7-day token):
```elixir
test "signed_playback_url/3 mints JWT with exp matching profile TTL (no SDK 7-day default)" do
  ttl = Rindle.Delivery.signed_url_ttl_seconds(TestProfile)
  before_unix = DateTime.utc_now() |> DateTime.to_unix()

  assert {:ok, %{url: url, kind: :hls}} =
           Rindle.Streaming.Provider.Mux.signed_playback_url(TestProfile, "playback-id-123", [])

  jwt = url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query() |> Map.fetch!("token")
  {:ok, %{fields: %{"exp" => exp}}} = JOSE.JWT.peek_payload(jwt) |> then(&{:ok, &1})

  # exp must be approximately now + ttl (±5s for clock skew tolerance)
  assert_in_delta exp, before_unix + ttl, 5
  refute exp > before_unix + 604_800   # SDK 7-day default would smell like this
end
```

---

### `test/rindle/streaming/provider/mux/telemetry_test.exs` (test, `:telemetry.attach`)

**Analog:** Existing telemetry-handler-based tests across the repo. Pattern:
```elixir
test "every emitted [:rindle, :provider, ...] event has redacted asset_id" do
  events = [
    [:rindle, :provider, :ingest, :start],
    [:rindle, :provider, :ingest, :stop],
    [:rindle, :provider, :ingest, :exception],
    [:rindle, :provider, :sync, :resolved],
    [:rindle, :provider, :sync, :stuck]
  ]

  test_pid = self()
  handler_id = "test-#{System.unique_integer([:positive])}"

  :telemetry.attach_many(handler_id, events,
    fn event, measurements, metadata, _ ->
      send(test_pid, {:telemetry, event, measurements, metadata})
    end, nil)

  on_exit(fn -> :telemetry.detach(handler_id) end)

  # ... drive a 720p sample through MuxIngestVariant via Mox cassette ...

  assert_receive {:telemetry, _, _, %{asset_id: redacted}}
  assert redacted =~ ~r/^\.\.\.[A-Za-z0-9]{4}$/   # invariant 14 enforcement
end
```

---

### `test/rindle/streaming/provider/mux/optional_dep_test.exs` (test, smoke)

**Analog:** `test/rindle/streaming/provider_test.exs` (verify behaviour module exports its callbacks).

**Pattern** (D-33 — assert in test env where `:mux` IS loaded):
```elixir
test "Rindle.Streaming.Provider.Mux is loaded with all required callbacks" do
  assert Code.ensure_loaded?(Rindle.Streaming.Provider.Mux)
  assert function_exported?(Rindle.Streaming.Provider.Mux, :capabilities, 0)
  assert function_exported?(Rindle.Streaming.Provider.Mux, :create_asset, 3)
  assert function_exported?(Rindle.Streaming.Provider.Mux, :get_asset, 1)
  assert function_exported?(Rindle.Streaming.Provider.Mux, :delete_asset, 1)
  assert function_exported?(Rindle.Streaming.Provider.Mux, :signed_playback_url, 3)
  assert function_exported?(Rindle.Streaming.Provider.Mux, :verify_webhook, 3)
end
```

---

## Shared Patterns

### Optional-dep guard

**Source:** `lib/rindle/live_view.ex:1-2` and `lib/rindle/html.ex:1-2`
**Apply to:** Every top-level Mux-touching module (`mux.ex`, `mux/http.ex`, `mux/event.ex`, AND all three `mux_*` workers per Pitfall 4 #2)
**NOT applied to:** `mux/client.ex` (pure-Elixir behaviour with no SDK refs)

```elixir
if Code.ensure_loaded?(Mux.Video.Assets) do
  defmodule Rindle.Streaming.Provider.Mux do
    # ... entire module body ...
  end
end
```

### Config-at-call-site (no caching)

**Source:** `lib/rindle/config.ex:14-16` (`Application.get_env(:rindle, ...)`)
**Apply to:** Every read of `RINDLE_MUX_*` credentials and tunables
**Pattern:**
```elixir
defp config(key, default \\ nil) do
  Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])
  |> Keyword.get(key, default)
end
```

### Repo access via `Rindle.Config.repo()`

**Source:** `lib/rindle/workers/process_variant.ex:24` (`repo = Config.repo()`)
**Apply to:** Every worker `perform/1` body that reads/writes `media_provider_assets`
**Pattern:**
```elixir
@impl Oban.Worker
def perform(%Oban.Job{args: args}) do
  repo = Rindle.Config.repo()
  # ... use repo for all reads/writes ...
end
```

### FSM transition with telemetry context

**Source:** `lib/rindle/domain/provider_asset_fsm.ex:28-49`
**Apply to:** Every state transition on `media_provider_assets.state`
**Pattern:**
```elixir
:ok = ProviderAssetFSM.transition(row.state, target_state,
  profile: row.profile,
  provider: :mux,
  asset_id: row.asset_id   # internal MediaAsset id (not provider id)
)
# Caller owns the changeset apply / persistence step.
```

### Telemetry redaction (security invariant 14)

**Source:** `lib/rindle/domain/media_provider_asset.ex:111-117` (currently `defp` — Phase 34 promotes to public per Pitfall 5 #3)
**Apply to:** Every `:telemetry.execute/3` emit metadata that includes `asset_id` or `provider_asset_id`
**Pattern:**
```elixir
metadata = %{
  profile: profile,
  provider: :mux,
  asset_id: MediaProviderAsset.redact_id(row.provider_asset_id),
  variant_name: variant_name
}
:telemetry.execute([:rindle, :provider, :ingest, :stop], measurements, metadata)
```

### Mox + behaviour test setup

**Source:** `test/rindle/workers/process_variant_test.exs:1-10` and `test/support/mocks.ex:1-5`
**Apply to:** Every Phase 34 test file that uses the Mux client mock
**Pattern:**
```elixir
defmodule MyTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo   # only for worker tests
  import Mox

  setup :set_mox_from_context   # NEVER set_mox_global (Pitfall 5)
  setup :verify_on_exit!
end
```

### Worker `@spec perform/1` and `:ok | {:error, term()}` contract

**Source:** `lib/rindle/workers/cleanup_orphans.ex:65-66` and `abort_incomplete_uploads.ex:71-72`
**Apply to:** Every Phase 34 worker
**Pattern:**
```elixir
@spec perform(Oban.Job.t()) :: :ok | {:error, term()}
@impl Oban.Worker
def perform(%Oban.Job{args: args}) do
  # ...
end
```

### Adopter cron-snippet `@moduledoc`

**Source:** `lib/rindle/workers/cleanup_orphans.ex:9-22` and `abort_incomplete_uploads.ex:17-30`
**Apply to:** `mux_ingest_variant.ex` (queue size only) and `mux_sync_coordinator.ex` (cron entry)
**Pattern:**
```elixir
@moduledoc """
...

## Cron Configuration Example

In your Oban configuration:

    config :my_app, Oban,
      queues: [rindle_provider: 4],
      plugins: [
        {Oban.Plugins.Cron,
         crontab: [
           {"* * * * *", Rindle.Workers.MuxSyncCoordinator}
         ]}
      ]

...
"""
```

### Logger structured event keys

**Source:** `lib/rindle/workers/cleanup_orphans.ex:101-130` and `abort_incomplete_uploads.ex:75-99`
**Apply to:** Every log line in Phase 34 workers
**Pattern:**
```elixir
Logger.info("rindle.workers.mux_ingest_variant.completed",
  asset_id: asset.id,                                 # internal MediaAsset id
  provider_asset_id: MediaProviderAsset.redact_id(...) # last-4 char tag
)

Logger.error("rindle.workers.mux_ingest_variant.failed",
  reason: inspect(reason),
  asset_id: asset.id
)
```

---

## No Analog Found

Files with no close match in the codebase:

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `test/fixtures/mux/asset_create_201.json` | fixture data | n/a | First Mux REST cassette in repo. Hand-derive per D-36 from `https://www.mux.com/docs/api-reference/video/assets/create-asset`. RESEARCH.md Memo Correction #1 documents the exact cURL example shape. |
| `test/fixtures/mux/asset_get_processing.json` | fixture data | n/a | Same as above — hand-derive from API ref. |
| `test/fixtures/mux/asset_get_ready.json` | fixture data | n/a | Same as above — hand-derive from API ref. |
| `test/fixtures/mux/webhook_video_asset_ready.json` | fixture data | n/a | First webhook fixture. Hand-derive from `https://www.mux.com/docs/core/listen-for-webhooks` per D-36. |
| `test/fixtures/mux/webhook_video_asset_errored.json` | fixture data | n/a | Same as above. |
| `test/fixtures/mux/test_signing_private_key.pem` | fixture key | n/a | First RSA signing-key fixture. Generate via `openssl genrsa -out ... 2048` per D-37 (one-time setup). |

Phase 34 hand-derives all six per D-36 and D-37; Phase 36 swaps to captured-from-real-Mux cassettes when the soak lane lands.

## Key Patterns Identified

1. **Optional-dep guard wraps the entire `defmodule`** (mirrors `live_view.ex:1` exactly) — applies to 6 of the 7 new lib files; only the pure-Elixir behaviour module (`client.ex`) is unguarded.
2. **Atomic-promote race protection is a verbatim mirror of `process_variant.ex:244-275`** with field swap (`expected_storage_key` and `expected_recipe_digest` from worker args instead of from the captured asset/variant struct).
3. **Cron-driven coordinator + per-row sibling worker** mirrors the existing `cleanup_orphans.ex` / `abort_incomplete_uploads.ex` pair (adopter-owned Oban supervision, `@moduledoc` cron snippet, `max_attempts: 1` for coordinator).
4. **Mox + behaviour test pattern** is a one-line addition to `test/support/mocks.ex` (matching `Rindle.StorageMock`, `Rindle.ProcessorMock`, etc.); test files use `setup :set_mox_from_context; setup :verify_on_exit!` and `use Oban.Testing` where applicable.
5. **Security invariant 14 redaction** requires promoting `MediaProviderAsset.redact_id/1` from `defp` (inside `defimpl Inspect`) to public `def` on the schema module; every telemetry emit and log line then calls `MediaProviderAsset.redact_id/1` before passing the id into metadata.
6. **`Rindle.Error.message/1` extension** is purely additive — Phase 33 already shipped the `:provider_*` atom set; Phase 34 may refine wording per "Claude's Discretion" but does not introduce new atoms.
7. **Telemetry events follow the `[:rindle, :<scope>, :<action>, :<stage>]` shape** (mirrors `[:rindle, :media, :transcode, :stage]` in `process_variant.ex:461-463`). Phase 34 adds `[:rindle, :provider, :ingest | :sync, ...]` family.
8. **`unique_job_opts/0` shape mirrors `process_variant.ex:408-415`** with two intentional differences: `keys` adds `:profile`, and `period: 86_400` instead of `:infinity` to allow re-ingest cooldown (D-16).

## Metadata

**Analog search scope:**
- `lib/rindle/workers/` (5 existing workers)
- `lib/rindle/streaming/` (Phase 33 contract)
- `lib/rindle/domain/` (FSM + schema)
- `lib/rindle/{live_view,html,error,config,delivery}.ex` (cross-cutting helpers)
- `test/rindle/workers/` (3 existing worker tests)
- `test/support/mocks.ex` + `test/test_helper.exs`
- `mix.exs` (existing optional-dep precedent)

**Files scanned:** 17 (all read in this session)
**Pattern extraction date:** 2026-05-06
