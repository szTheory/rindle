# Phase 33: Provider Boundary + State Schema — Pattern Map

**Mapped:** 2026-05-06
**Files analyzed:** 12 (6 CREATE + 6 MODIFY) + 6 Wave-0 test files
**Analogs found:** 12 / 12 (every load-bearing file has an in-repo mirror; zero "no analog")
**Source of truth:** RESEARCH.md `## Architecture Patterns` (line 227) and `## Code Examples` (line 1229) already cite verbatim analogs and line ranges; this file lifts those into per-file pattern assignments.

---

## File Classification

| New / Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/rindle/streaming/capabilities.ex` (CREATE) | Vocabulary module | pure-data lookup | `lib/rindle/storage/capabilities.ex:1-67` | exact |
| `lib/rindle/streaming/provider.ex` (MODIFY — full rewrite of 2-callback shim) | Behaviour | `@callback` declarations only | `lib/rindle/storage.ex` + `lib/rindle/processor.ex` (behaviour discipline); current shim at `lib/rindle/streaming/provider.ex:1-14` (the file being replaced) | exact (behaviour discipline) |
| `priv/repo/migrations/<ts>_create_media_provider_assets.exs` (CREATE) | Migration | additive DDL | `priv/repo/migrations/20260425090100_create_media_variants.exs:1-20` (FK + indexes) and `priv/repo/migrations/20260424155129_create_media_assets.exs:1-21` (binary_id PK + index pattern) | exact |
| `lib/rindle/domain/media_provider_asset.ex` (CREATE) | Schema + changeset + custom Inspect | Ecto schema + validation | `lib/rindle/domain/media_asset.ex:1-139` | exact |
| `lib/rindle/domain/provider_asset_fsm.ex` (CREATE) | FSM | transition allowlist + telemetry | `lib/rindle/domain/asset_fsm.ex:1-77` | exact |
| `lib/rindle/profile/validator.ex` (MODIFY) | DSL extension | NimbleOptions validation | `lib/rindle/profile/validator.ex:35-48` (`@delivery_schema`) and `validate_delivery!/1` at lines 211-232 | exact (extends self) |
| `lib/rindle/delivery.ex` (MODIFY — replace body of `streaming_url/3`) | Dispatch | `Repo.get_by/2` + decision tree + telemetry | `lib/rindle/delivery.ex:158-192` (signature + telemetry stay; body replaced) | exact (extends self) |
| `lib/rindle/error.ex` (MODIFY — add 5 `def message/1` clauses) | Error vocabulary | pattern-match on `%Rindle.Error{reason: ...}` | `lib/rindle/error.ex:195-221` (`:streaming_not_configured` clause) | exact |
| `lib/rindle/capability.ex` (CREATE) | Capability report aggregator | read-only aggregation over `Application.get_env/2` and `<vocab>.safe/1` | `lib/rindle/ops/runtime_checks.ex:1-66` (existing report aggregator pattern) + `lib/rindle/storage/capabilities.ex:32-46` (`safe/1` consumption pattern) | role-match (no prior aggregator at this exact layer; closest is RuntimeChecks) |
| `test/rindle/streaming/capabilities_test.exs` (CREATE) | Test (vocab) | unit | (mirror by inversion) `lib/rindle/storage/capabilities.ex` callers in test/ | role-match |
| `test/rindle/streaming/provider_test.exs` (CREATE) | Test (`behaviour_info`) | unit | `test/rindle/behaviour_docs_test.exs` style; assert `behaviour_info(:callbacks)` | role-match |
| `test/rindle/domain/media_provider_asset_test.exs` (CREATE) | Test (schema + changeset + Inspect) | unit | `test/rindle/domain/media_schema_test.exs` (existing) | exact |
| `test/rindle/domain/provider_asset_fsm_test.exs` (CREATE) | Test (FSM matrix + telemetry) | unit | `test/rindle/domain/lifecycle_fsm_test.exs:1-80` | exact |
| `test/rindle/error_streaming_freeze_test.exs` (CREATE) | Test (parity freeze) | unit | `test/rindle/error_test.exs:1-100` (AV-06-05 pattern) | exact |
| `test/rindle/capability_test.exs` (CREATE) | Test (report shape) | unit | RESEARCH §"Code Examples" Example 7 | role-match |

---

## Pattern Assignments

### `lib/rindle/streaming/capabilities.ex` (vocabulary module, pure-data lookup)

**Analog:** `lib/rindle/storage/capabilities.ex` (full file, 67 lines)

**Imports / module shape pattern** (lines 1-2): no imports — module is plain data + small functions. Mirror `@moduledoc false`.

**`@known` + `known/0` + `safe/1` pattern** (lines 19-46):
```elixir
@known [
  :presigned_put,
  :multipart_upload,
  :signed_url,
  :head,
  :local,
  :resumable_upload,
  :resumable_upload_session
]

@spec known() :: [capability()]
def known, do: @known

@spec safe(module()) :: [capability()]
def safe(adapter) do
  case adapter.capabilities() do
    capabilities when is_list(capabilities) ->
      Enum.filter(capabilities, &(&1 in @known))

    _ ->
      []
  end
rescue
  _ -> []
end

@spec supports?(module(), capability()) :: boolean()
def supports?(adapter, capability), do: capability in safe(adapter)
```

**Patterns / invariants the executor must preserve:**
- Closed `@known` allowlist with **5 atoms** (D-02): `:signed_playback`, `:public_playback`, `:webhook_ingest`, `:server_push_ingest`, `:direct_creator_upload` (last is *reserved*; document in `@typedoc`).
- `safe/1` MUST `rescue _ -> []` so an adapter that raises in `capabilities/0` never crashes the caller. This matches the storage analog's "capability honesty" guarantee.
- **Do NOT ship `require_streaming/2`** (D-03 — that's Phase 37 / MUX-22). The storage analog's `require_upload/2` and `require_delivery/2` (lines 48-66) are **not** mirrored in this phase.
- `supports?/2` is OPTIONAL but recommended — it's part of the storage analog and adds zero risk.

---

### `lib/rindle/streaming/provider.ex` (behaviour, `@callback` declarations only)

**Analog:** the file itself at `lib/rindle/streaming/provider.ex:1-14` (current 2-callback shim — full rewrite per D-04, D-08); behaviour-discipline reference: `lib/rindle/storage.ex` and `lib/rindle/processor.ex`.

**Existing 2-callback shim being replaced** (`lib/rindle/streaming/provider.ex:1-14`):
```elixir
defmodule Rindle.Streaming.Provider do
  @moduledoc """
  Reserved behaviour for future non-progressive streaming providers.

  Phase 26 intentionally reserves this namespace without introducing runtime
  dispatch, adapter lookup, or configuration coupling in core delivery paths.
  """

  @typedoc "Future streaming resolution result."
  @type result :: {:ok, %{url: String.t(), kind: atom(), mime: String.t()}} | {:error, term()}

  @callback streaming_url(profile :: module(), key :: String.t(), opts :: keyword()) :: result()
  @callback capabilities() :: [atom()]
end
```

**Replacement shape (verbatim from CONTEXT D-04, D-06, D-07; cited memo §4):**
- 6 required callbacks: `capabilities/0`, `create_asset/3`, `get_asset/1`, `delete_asset/1`, `signed_playback_url/3`, `verify_webhook/3`.
- 1 optional callback (under `@optional_callbacks`): `create_direct_upload/2`.
- Public types locked: `provider_asset_id :: String.t()`, `playback_id :: String.t()`, `provider_state :: :pending | :uploading | :processing | :ready | :errored | :deleted`, `provider_event` map shape, `capability` atom union.
- **`streaming_url/3` is REMOVED from the behaviour** (D-05) — it lives only on `Rindle.Delivery`.

**Patterns / invariants the executor must preserve:**
- Every callback returns `:ok`-tuple or `:error`-tuple (D-07). No raises on the happy path. Mirror the discipline used in `Rindle.Storage` and `Rindle.Processor` callback signatures.
- `verify_webhook/3` returns a normalized `provider_event` map, **NOT** a Mux struct (D-07). This is the single boundary that prevents Mux-isms from leaking into core; document it explicitly in the `@callback` doc.
- `@moduledoc` MUST note that `provider_asset_id` is never exposed in adopter-facing paths (security invariant 14, per RESEARCH §"Project Constraints").
- Removing the v1.4 2-callback shape is **non-breaking** (D-08): no shipped impls existed; no semver bump.

---

### `priv/repo/migrations/<ts>_create_media_provider_assets.exs` (additive Ecto migration)

**Analog (FK + indexes pattern):** `priv/repo/migrations/20260425090100_create_media_variants.exs:1-20`

**Analog (binary_id PK + state column + index pattern):** `priv/repo/migrations/20260424155129_create_media_assets.exs:1-21`

**Mirror excerpt** (`create_media_variants.exs` full file):
```elixir
defmodule Rindle.Repo.Migrations.CreateMediaVariants do
  use Ecto.Migration

  def change do
    create table(:media_variants) do
      add :asset_id, references(:media_assets, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :state, :string, null: false, default: "planned"
      add :recipe_digest, :string, null: false
      add :storage_key, :string
      add :error_reason, :text
      add :generated_at, :utc_datetime_usec

      timestamps()
    end

    create unique_index(:media_variants, [:asset_id, :name])
    create index(:media_variants, [:state])
  end
end
```

**Mirror excerpt** (additive AV migration body — most recent in-repo migration; `extend_media_for_av.exs:1-34`):
```elixir
defmodule Rindle.Repo.Migrations.ExtendMediaForAv do
  @moduledoc """
  Phase 24 — additive migration for AV (image / video / audio / waveform) support.
  ...
  No DDL transaction disabling and no `lock_timeout` — matches every prior
  migration in this project (D-01).
  """
  use Ecto.Migration

  def change do
    # ... add columns ...
    create index(:media_assets, [:kind])
  end
end
```

**Phase-33-specific column set (from CONTEXT D-09 verbatim):**
- `binary_id` PK (use `create table(:media_provider_assets, primary_key: false) do ... add :id, :binary_id, primary_key: true`)
- `add :asset_id, references(:media_assets, type: :binary_id, on_delete: :delete_all), null: false`
- `add :profile, :string, null: false`
- `add :provider_name, :string, null: false`
- `add :provider_asset_id, :string` (nullable until `create_asset/3` succeeds)
- `add :playback_ids, {:array, :string}, null: false, default: []`
- `add :playback_policy, :string`
- `add :ingest_mode, :string`
- `add :state, :string, null: false, default: "pending"`
- `add :last_event_id, :string`
- `add :last_event_at, :utc_datetime_usec`
- `add :last_sync_error, :text` (changeset truncates to 4096 chars; column is `:text`)
- `add :raw_provider_metadata, :map, null: false, default: %{}`
- `timestamps()`

**Locked indexes (CONTEXT D-10 verbatim):**
```elixir
create unique_index(:media_provider_assets, [:provider_name, :provider_asset_id],
  where: "provider_asset_id IS NOT NULL")
create unique_index(:media_provider_assets, [:asset_id, :profile, :provider_name])
create index(:media_provider_assets, [:state])
create index(:media_provider_assets, [:state, :updated_at])
```

**Patterns / invariants the executor must preserve:**
- **No `@disable_ddl_transaction`, no `lock_timeout`** — matches every prior in-repo migration (`extend_media_for_av.exs` `@moduledoc` line 9 explicitly states this convention).
- **Idempotent and additive only** (D-11): no change to `media_assets` / `media_variants`; adopters running this migration get one new empty table with their existing rows untouched.
- **Adopter-owned migration handoff:** library ships the file in `priv/repo/migrations`; adopters call `mix ecto.migrate` per `guides/getting_started.md` flow (`Application.app_dir(:rindle, "priv/repo/migrations")`). No inline runtime migration.
- The partial-where unique index (first index) is the load-bearing one for Phase 34's idempotency keys — the `where: "provider_asset_id IS NOT NULL"` clause is **not optional**.

---

### `lib/rindle/domain/media_provider_asset.ex` (Ecto schema + changeset + custom Inspect)

**Analog:** `lib/rindle/domain/media_asset.ex` (full file, 139 lines)

**Schema preamble pattern** (lines 28-46):
```elixir
use Ecto.Schema
import Ecto.Changeset

@primary_key {:id, :binary_id, autogenerate: true}
@foreign_key_type :binary_id

@states [
  "staged",
  "validating",
  ...
  "deleted"
]

@type t :: %__MODULE__{}

schema "media_assets" do
  field :state, :string, default: "staged"
  ...
  timestamps()
end
```

**Changeset pattern** (lines 90-115):
```elixir
@spec changeset(t() | %__MODULE__{}, map()) :: Ecto.Changeset.t()
def changeset(asset, attrs) do
  asset
  |> cast(attrs, [:state, :storage_key, ...])
  |> validate_required([:state, :storage_key, :profile, :kind])
  |> validate_inclusion(:state, @states)
  |> validate_inclusion(:kind, @kinds)
  |> unique_constraint(:storage_key)
end
```

**Phase-33-specific schema (lifted from CONTEXT D-09, D-12):**
- `@states ~w(pending uploading processing ready errored deleted)` (six states from D-13).
- `schema "media_provider_assets" do` with the 13 fields from the migration (state, asset_id FK, profile, provider_name, provider_asset_id, playback_ids `{:array, :string}` default `[]`, playback_policy, ingest_mode, last_event_id, last_event_at, last_sync_error, raw_provider_metadata `:map` default `%{}`) plus `timestamps()`.
- `belongs_to :asset, Rindle.Domain.MediaAsset, foreign_key: :asset_id` (mirrors `MediaAsset`'s `has_many` declarations).

**Changeset (Phase 33 shape):**
- `cast(attrs, [<all writable fields>])`
- `|> validate_required([:asset_id, :profile, :provider_name, :state])`
- `|> validate_inclusion(:state, @states)`
- `|> validate_length(:last_sync_error, max: 4096)` (D-09 truncation; safe to enforce at changeset level since DB column is `:text` with no DB-side length)
- `|> unique_constraint([:provider_name, :provider_asset_id], name: :media_provider_assets_provider_name_provider_asset_id_index)` (matches partial-where index from D-10)
- `|> unique_constraint([:asset_id, :profile, :provider_name])` (matches second unique index from D-10)
- `|> foreign_key_constraint(:asset_id)`

**Custom Inspect impl pattern (D-14, security invariant 14) — NOT in `MediaAsset` analog; this is new for Phase 33:**

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

**Patterns / invariants the executor must preserve:**
- `@primary_key {:id, :binary_id, autogenerate: true}` and `@foreign_key_type :binary_id` (mirrors `MediaAsset` lines 31-32 verbatim).
- State as `:string` with `validate_inclusion(:state, @states)` — **NOT** `Ecto.Enum` (RESEARCH §"Alternatives Considered" rationale: consistency with `MediaAsset`).
- Custom `Inspect` impl is the **only** schema-level enforcement of security invariant 14 — it MUST redact both `provider_asset_id` (last-4-char tag) and `raw_provider_metadata` (opaque sentinel). This is the freeze point; no opt-out.
- The Inspect impl runs at `inspect/2` boundary, telemetry-metadata logging, and `Logger`/`IO.inspect` outputs — covering every leak surface enumerated in PROJECT.md invariant 14.

---

### `lib/rindle/domain/provider_asset_fsm.ex` (FSM, transition allowlist + telemetry)

**Analog:** `lib/rindle/domain/asset_fsm.ex` (full file, 77 lines)

**Mirror excerpt (FULL — copy shape verbatim, swap states + telemetry event):**
```elixir
defmodule Rindle.Domain.AssetFSM do
  @moduledoc false

  require Logger

  @allowed_transitions %{
    "staged" => ["validating"],
    "validating" => ["analyzing"],
    "analyzing" => ["promoting", "quarantined"],
    "promoting" => ["available"],
    "available" => ["processing", "transcoding", "quarantined"],
    "processing" => ["ready", "quarantined"],
    "transcoding" => ["ready", "degraded", "quarantined"],
    "ready" => ["degraded", "deleted"],
    "degraded" => ["quarantined", "deleted"],
    "quarantined" => ["deleted"],
    "deleted" => []
  }

  @type state :: String.t()
  @type transition_error :: {:error, {:invalid_transition, state(), state()}}

  @spec transition(state(), state(), map()) :: :ok | transition_error()
  def transition(current_state, target_state, context \\ %{}) do
    if target_state in Map.get(@allowed_transitions, current_state, []) do
      :ok
      |> tap(fn _ ->
        :telemetry.execute(
          [:rindle, :asset, :state_change],
          %{system_time: System.system_time()},
          %{
            profile: Map.get(context, :profile, :unknown),
            adapter: Map.get(context, :adapter, :unknown),
            from: current_state,
            to: target_state
          }
        )
      end)
    else
      log_transition_failure(current_state, target_state, context)
      {:error, {:invalid_transition, current_state, target_state}}
    end
  end
  ...
end
```

**Phase-33 differences from analog:**
- `@allowed_transitions` map MUST match D-13 exactly:
  ```elixir
  @allowed_transitions %{
    "pending" => ["uploading"],
    "uploading" => ["processing", "errored"],
    "processing" => ["ready", "errored"],
    "ready" => ["errored", "deleted"],
    "errored" => ["deleted", "processing"],   # re-ingest re-entry edge
    "deleted" => []
  }
  ```
- Telemetry event is `[:rindle, :provider_asset, :state_change]` (NOT `[:rindle, :asset, :state_change]`).
- Telemetry metadata SHOULD include `provider:` key (as well as `profile:`) — the analog uses `:adapter`; mirror that key swap. Recommended metadata: `%{profile: ..., provider: ..., asset_id: ..., from: ..., to: ...}`.

**Patterns / invariants the executor must preserve:**
- `transition/3` returns `:ok | {:error, {:invalid_transition, from, to}}` exactly as the analog (RESEARCH §"Tier-misassignment risks" — no Repo writes; caller owns persistence).
- `tap/2` ensures the success branch returns `:ok` after telemetry emit (preserves the `:ok | error` shape).
- The `errored → processing` edge is the re-ingest path (D-13); Phase 34's `MuxIngestVariant` retry depends on it.
- `deleted` is a terminal sink — empty target list (matches `MediaAsset` "deleted").
- `Logger.warning` on rejected transitions (mirror line 50-52, 66-76 of analog).

---

### `lib/rindle/profile/validator.ex` (DSL extension — add `:streaming` key)

**Analog:** `lib/rindle/profile/validator.ex:35-48` (`@delivery_schema`) and `lib/rindle/profile/validator.ex:211-232` (`validate_delivery!/1`) — **extends self**.

**Existing `@delivery_schema` pattern** (lines 35-48):
```elixir
@delivery_schema [
  public: [
    type: :boolean,
    default: false
  ],
  signed_url_ttl_seconds: [
    type: {:or, [:pos_integer, nil]},
    default: nil
  ],
  authorizer: [
    type: {:or, [:atom, nil]},
    default: nil
  ]
]
```

**Existing `validate_delivery!/1` pattern** (lines 211-232):
```elixir
defp validate_delivery!(delivery_opts) do
  delivery_opts
  |> normalize_delivery_opts!()
  |> NimbleOptions.validate!(@delivery_schema)
  |> Keyword.new()
  |> then(fn delivery ->
    ttl =
      case Keyword.fetch!(delivery, :signed_url_ttl_seconds) do
        nil -> Rindle.Config.signed_url_ttl_seconds()
        value -> value
      end

    %{
      public: Keyword.fetch!(delivery, :public),
      signed_url_ttl_seconds: ttl,
      authorizer: Keyword.fetch!(delivery, :authorizer)
    }
  end)
rescue
  error in NimbleOptions.ValidationError ->
    reraise ArgumentError, "delivery: #{Exception.message(error)}", __STACKTRACE__
end
```

**Phase-33 extension shape (D-15, D-16):**

Add `@streaming_schema` (new module attribute):
```elixir
@streaming_schema [
  provider: [type: :atom, required: true],
  playback_policy: [type: {:in, [:signed, :public]}, required: true],
  ingest_mode: [type: {:in, [:server_push, :direct_creator_upload]}, required: true],
  source_variant: [type: :atom, required: true]
]
```

Extend `@delivery_schema` to allow the new key:
```elixir
@delivery_schema [
  public: [...],
  signed_url_ttl_seconds: [...],
  authorizer: [...],
  streaming: [type: {:or, [:keyword_list, :map, nil]}, default: nil]
]
```

Extend `validate_delivery!/1` to validate the `:streaming` key against `@streaming_schema` when present, AND cross-check `source_variant` exists in the profile's `variants/0` declaration (D-18 — atom presence only; `kind:` enforcement deferred to Phase 34).

**Patterns / invariants the executor must preserve:**
- NimbleOptions raises `ArgumentError` with `"delivery: ..."` prefix on validation failure — mirror the existing `rescue` clause for the new `streaming:` validation.
- Image-only and AV-only profiles MUST compile unchanged (D-17): `streaming: nil` is the default; absence keeps current delivery behavior.
- **Forbid raw provider knobs** (D-16): NimbleOptions rejects unknown keys by default — do NOT add catch-all options. The closed allowlist is the entire enforcement.
- `source_variant` cross-check: must be an atom AND must appear in `variants/0` (raise `ArgumentError` like `"streaming: source_variant :foo not declared in variants/0"`). This requires plumbing the variants list into `validate_delivery!/1` — done by reordering the validation pipeline OR by adding a post-validate cross-check at the call site in `Rindle.Profile.Validator.validate!/1`.
- The validated `:streaming` map is stored in `delivery_policy().streaming` — the dispatch tree (next file) reads it from there.

---

### `lib/rindle/delivery.ex` (replace body of `streaming_url/3`)

**Analog:** `lib/rindle/delivery.ex:158-192` — **extends self** (signature, `@spec`, telemetry emit preserved verbatim; body replaced).

**Existing function (full body to be replaced)** (lines 145-192):
```elixir
@doc """
Returns a progressive streaming URL wrapper for an asset's storage key.

This is an additive future-stable playback surface. In v1.4 it delegates to
`url/3`, preserving the same authorization, TTL, and error semantics while
wrapping successful results as `%{url, kind, mime}`. Emits
`[:rindle, :delivery, :streaming, :resolved]` telemetry on success.
...
"""
@spec streaming_url(module(), String.t(), keyword()) ::
        {:ok, %{url: String.t(), kind: :progressive, mime: String.t()}} | {:error, term()}
def streaming_url(profile, key, opts \\ []) do
  opts = normalize_delivery_opts(key, opts)
  mime = Keyword.get(opts, :mime, "video/mp4")
  adapter = profile.storage_adapter()
  mode = delivery_mode(profile)
  subject = %{profile: profile, key: key, mode: mode}

  with :ok <- authorize_delivery(profile, :deliver, subject, opts),
       :ok <- require_streaming_support(adapter, mode, opts),
       {:ok, url} <-
         resolve_streaming_url(profile, adapter, key, mode, opts, signed_url_ttl_seconds(profile)) do
    :telemetry.execute(
      [:rindle, :delivery, :streaming, :resolved],
      %{system_time: System.system_time()},
      %{
        profile: profile,
        adapter: adapter,
        mode: mode,
        kind: :progressive,
        mime: mime
      }
    )

    {:ok, %{url: url, kind: :progressive, mime: mime}}
  end
end
```

**Phase-33 replacement body shape (D-19, 8 branches; D-20 :strict; D-21 single Repo.get_by; D-22 provider_name derivation; D-23 pass-through return; D-24 telemetry preservation):**

Replacement shape (pseudocode the executor implements; preserves outer signature, `@spec`, and the telemetry emit on the v1.4 progressive path):

```elixir
@spec streaming_url(module(), String.t() | map(), keyword()) ::
        {:ok, %{url: String.t(), kind: :progressive | :hls, mime: String.t()}}
        | {:error, term()}
def streaming_url(profile, asset_or_key, opts \\ []) do
  streaming_config = Map.get(profile.delivery_policy(), :streaming)

  cond do
    # Step 1: profile streaming nil → existing v1.4 progressive path (unchanged)
    is_nil(streaming_config) ->
      do_progressive_streaming_url(profile, asset_or_key, opts)

    # Step 2: streaming configured + binary key → :streaming_provider_requires_asset_struct
    is_binary(asset_or_key) ->
      {:error, :streaming_provider_requires_asset_struct}

    # Steps 3-6: streaming + asset struct → Repo.get_by/2 → branch on row state
    true ->
      lookup_provider_row(profile, streaming_config, asset_or_key)
      |> dispatch_provider_state(profile, streaming_config, asset_or_key, opts)
  end
end
```

Where:
- **Step 1's `do_progressive_streaming_url/3`** preserves the existing `with`-chain (`authorize_delivery → require_streaming_support → resolve_streaming_url`) and the `[:rindle, :delivery, :streaming, :resolved]` telemetry emit with `kind: :progressive` (D-24 — preserved verbatim).
- **Step 3** (`row.state in ["pending", "uploading", "processing"]`) → `{:error, :provider_asset_not_ready}`.
- **Step 4** (`row.state == "errored"`) → `{:error, :provider_sync_failed}`.
- **Step 5** (`row.state == "ready"`) → `streaming_config.provider.signed_playback_url(profile, playback_id, opts)` — pass-through return (D-23). Emit `[:rindle, :delivery, :streaming, :resolved]` with `kind: :hls` after success.
- **Step 6** (no row): if `Keyword.get(opts, :strict, false)` → `{:error, :provider_asset_not_ready}` (D-20); else fall through to progressive path (Step 1's helper) and emit `kind: :progressive` telemetry (D-24).
- **`provider_name` derivation** (D-22): `streaming_config.provider |> Module.split() |> List.last() |> Macro.underscore()` (e.g. `Rindle.Streaming.Provider.Mux → "mux"`).
- **`Repo.get_by/2` lookup** (D-21): `Rindle.Repo.get_by(Rindle.Domain.MediaProviderAsset, asset_id: asset.id, profile: to_string(profile), provider_name: provider_name)` — uses the unique index from D-10, no N+1.

**Patterns / invariants the executor must preserve:**
- **Telemetry preservation is the load-bearing v1.4 contract** (D-24): the `[:rindle, :delivery, :streaming, :resolved]` event fires on Step 1 AND Step 6 (no-row, non-strict) with `kind: :progressive`, and on Step 5 with `kind: :hls`. Existing tests at `test/rindle/delivery_test.exs:340-391` and `test/rindle/contracts/telemetry_contract_test.exs:74, 277` MUST stay green.
- **Public `@spec` extension** (D-23): widen the kind to `:progressive | :hls` and the second arg to `String.t() | map()` (the asset struct). The `{:ok, %{url, kind, mime}}` return shape is preserved.
- **Authorization runs BEFORE dispatch** on the progressive path (RESEARCH §"Security Domain" V4): the `authorize_delivery/4` call inside `do_progressive_streaming_url/3` MUST run before any URL is minted.
- **No N+1 risk** (D-21): a single `Repo.get_by/2` per call. Do not introduce `preload` or per-variant lookups.
- **`provider_name` is opaque internal** (D-22): never rendered into public URLs or telemetry metadata except as the redacted module-suffix string.

---

### `lib/rindle/error.ex` (5 new `def message/1` clauses + reuse `:streaming_not_configured`)

**Analog:** `lib/rindle/error.ex:195-221` — **extends self** (cause→action style; bare-atom variants).

**Mirror excerpt** (`:streaming_not_configured` clause at lines 214-221):
```elixir
def message(%{reason: :streaming_not_configured}) do
  """
  Streaming playback was requested, but the current profile is not configured for that delivery path.

  Until a streaming provider is configured, callers should use `Rindle.Delivery.url/3` for progressive playback.
  """
  |> String.trim()
end
```

**Phase-33 additions (D-25, D-27 — exact wording is freeze-locked at ship via STREAM-09):**

Five new `def message/1` clauses, one per atom, each in cause→action style:
1. `:provider_asset_not_ready` — "The provider asset is not yet ready for playback. Check `mix rindle.runtime_status --provider-stuck` ... wait for webhook ... consider re-ingest via `Rindle.regenerate_variants/2`."
2. `:provider_webhook_invalid` — webhook signature failed verification; check secret rotation; reject the event.
3. `:provider_sync_failed` — the provider asset is in errored state; inspect `last_sync_error` on the row; consider re-ingest.
4. `:provider_quota_exceeded` — provider returned a quota/rate limit; check provider dashboard; back off retries.
5. `:streaming_provider_requires_asset_struct` — caller passed a binary `key` to `streaming_url/3` on a streaming-configured profile; pass the asset struct instead.

Each clause uses the heredoc + `|> String.trim()` shape exactly like the analog.

**Patterns / invariants the executor must preserve:**
- **Bare-atom variants only** in Phase 33 (D-27). NO map-keyed variants (e.g. `{:provider_quota_exceeded, %{provider: ..., retry_after: ...}}`). Map-keyed variants are explicitly deferred (`v1.7+`).
- **`:streaming_not_configured` clause is REUSED unchanged** (D-26). Do NOT edit it. The existing test at `test/rindle/error_test.exs:76-81` must stay green (D-26 freeze).
- **`String.trim/1` (not `String.trim_trailing/1`) is the analog's normalization** — mirror that for the 5 new clauses. (The parity test uses `String.trim_trailing/1` on its **expected** strings — see freeze test pattern below — but the production `message/1` uses `String.trim/1`.)
- **Clause order:** add the five new clauses adjacent to the existing `:streaming_not_configured` clause for readability; ordering does not affect correctness because they pattern-match on bare atoms.
- **Wording is frozen at ship via STREAM-09** (D-28): once the parity-freeze test asserts the exact text, future PRs cannot drift the wording without explicitly editing the freeze test. This is the AV-06-05 lesson.

---

### `lib/rindle/capability.ex` (CREATE — new module; report aggregator)

**Analog (closest):** `lib/rindle/ops/runtime_checks.ex:1-66` (existing report aggregator pattern); `lib/rindle/storage/capabilities.ex:32-46` (`safe/1` consumption pattern).

**Existing aggregator pattern** (`runtime_checks.ex:32-66`):
```elixir
@type report :: %{
        checks: [check_result()],
        failed: non_neg_integer(),
        success?: boolean(),
        total: non_neg_integer()
      }

@spec run([String.t()], keyword()) :: report()
def run(args, opts \\ []) do
  ...
  checks =
    [
      fn -> check_delivery_support(profiles) end,
      fn -> check_ffmpeg_runtime(probe) end,
      ...
    ]
    |> Enum.map(&run_check/1)
    |> Enum.sort_by(& &1.id)

  failed = Enum.count(checks, &(&1.status == :error))

  %{
    checks: checks,
    failed: failed,
    success?: failed == 0,
    total: length(checks)
  }
end
```

**Phase-33-specific shape (CONTEXT D-30 verbatim):**
```elixir
defmodule Rindle.Capability do
  @moduledoc """
  Aggregates Rindle runtime capability surfaces for ops/doctor consumers.

  Phase 33 ships the aggregator function only. Phase 36 (MUX-16) will refactor
  `mix rindle.doctor` to consume `report/0`.
  """

  @spec report() :: %{
          storage: %{module() => [atom()]},
          processor: %{module() => [atom()]},
          streaming: %{
            providers: %{module() => [atom()]},
            signed_playback_configured?: boolean(),
            configured_profiles: [module()]
          }
        }
  def report do
    %{
      storage: storage_report(),
      processor: processor_report(),
      streaming: %{
        providers: streaming_providers_report(),
        signed_playback_configured?: signed_playback_configured?(),
        configured_profiles: configured_streaming_profiles()
      }
    }
  end

  defp signed_playback_configured? do
    cfg = Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])
    is_binary(Keyword.get(cfg, :signing_key_id)) and
      is_binary(Keyword.get(cfg, :signing_private_key))
  end

  # storage_report/0, processor_report/0, streaming_providers_report/0,
  # configured_streaming_profiles/0 — thin aggregators using Capabilities.safe/1
end
```

**Patterns / invariants the executor must preserve:**
- **`signed_playback_configured?` MUST use `Application.get_env/2`** (RESEARCH §"Alternatives Considered"). It MUST NOT use `Code.ensure_loaded?/1` on the `:mux` dep — that crashes when the optional dep is absent (D-30 explicit guardrail).
- **D-30 returns booleans, NEVER config keys** (security invariant 14): the function returns `signed_playback_configured?: true | false`, never `signing_key_id: "..."`. This is the "credential leak via Mux config logging" mitigation in RESEARCH §"Security Domain".
- **`mix rindle.doctor` is NOT refactored to consume this in Phase 33** (D-31). Phase 33 ships the function only.
- **Read-only aggregator** (RESEARCH §"Architectural Responsibility Map"): no Repo, no I/O. Storage / processor / streaming subreports are pure data over `Capabilities.safe/1` and `Application.get_env/2`.
- **Public symbol locked: `Rindle.Capability.report/0`** (REQUIREMENTS STREAM-08; CONTEXT "Claude's Discretion" allows the module to be renamed but the function name `report/0` is locked).

---

### `test/rindle/error_streaming_freeze_test.exs` (parity freeze test — STREAM-09)

**Analog:** `test/rindle/error_test.exs:1-100` (AV-06-05 freeze pattern; full-file mirror).

**Mirror excerpt** (full freeze pattern):
```elixir
defmodule Rindle.ErrorTest do
  use ExUnit.Case, async: true

  @av_public_reasons [
    :processor_capability_missing,
    :ffmpeg_not_found,
    :capability_drift,
    :variant_source_not_found,
    :unsupported_codec,
    :streaming_not_configured,
    :variant_processing_cancelled,
    :range_unparseable
  ]

  test "locks the eight public AV reason atoms" do
    assert @av_public_reasons == [
             :processor_capability_missing,
             ...
             :range_unparseable
           ]
  end

  test "renders exact messages for generic AV-facing reason atoms" do
    expected_messages = %{
      processor_capability_missing:
        exact("""
        Variant processing requires a processor capability that is not available.

        To fix:
          1. Confirm FFmpeg is installed and on PATH (`which ffmpeg`).
          ...
        """),
      ...
    }

    for {reason, expected} <- expected_messages do
      error = struct!(Rindle.Error, action: :test_contract, reason: reason)
      assert Rindle.Error.message(error) == expected
    end
  end

  defp exact(text), do: String.trim_trailing(text)
end
```

**Phase-33-specific shape (D-28; RESEARCH §"Code Examples" Example 3):**

```elixir
defmodule Rindle.ErrorStreamingFreezeTest do
  use ExUnit.Case, async: true

  @public_streaming_reasons [
    :provider_asset_not_ready,
    :provider_webhook_invalid,
    :provider_sync_failed,
    :provider_quota_exceeded,
    :streaming_provider_requires_asset_struct
  ]

  test "locks the five public streaming reason atoms" do
    assert @public_streaming_reasons == [
             :provider_asset_not_ready,
             :provider_webhook_invalid,
             :provider_sync_failed,
             :provider_quota_exceeded,
             :streaming_provider_requires_asset_struct
           ]
  end

  test "renders exact messages for the five new streaming reason atoms" do
    expected_messages = %{
      provider_asset_not_ready: exact("""<heredoc>"""),
      provider_webhook_invalid: exact("""<heredoc>"""),
      provider_sync_failed:     exact("""<heredoc>"""),
      provider_quota_exceeded:  exact("""<heredoc>"""),
      streaming_provider_requires_asset_struct: exact("""<heredoc>""")
    }

    for {reason, expected} <- expected_messages do
      error = struct!(Rindle.Error, action: :test_contract, reason: reason)
      assert Rindle.Error.message(error) == expected
    end
  end

  defp exact(text), do: String.trim_trailing(text)
end
```

**Patterns / invariants the executor must preserve:**
- **`exact/1` uses `String.trim_trailing/1`** to normalize the heredoc (the analog uses `String.trim_trailing/1`; production code uses `String.trim/1` — the test's expected strings need only trailing-whitespace normalization since heredocs include a trailing newline).
- **Two test cases minimum** (mirror the analog): one locks the atom list verbatim; one asserts every message text byte-for-byte.
- **Heredocs are the wording freeze** — once this test ships, the wording is locked. The AV-06-05 lesson (RESEARCH §"Summary"): the parity gate test has to assert `String.trim_trailing/1`-normalized heredocs verbatim.
- **`async: true`** is safe (no shared state).
- **`:streaming_not_configured` is NOT in this list** (D-26; it stays in the existing AV freeze test). Adding it here would duplicate coverage and tighten the wrong freeze.

---

### `test/rindle/domain/provider_asset_fsm_test.exs` (FSM matrix + telemetry)

**Analog:** `test/rindle/domain/lifecycle_fsm_test.exs:1-80` (matrix style); RESEARCH §"Code Examples" Example 4 (full skeleton).

**Mirror excerpt** (matrix-test style):
```elixir
describe "asset transition matrix" do
  test "accepts the nominal asset lifecycle path" do
    assert :ok == AssetFSM.transition("staged", "validating")
    assert :ok == AssetFSM.transition("validating", "analyzing")
    ...
  end

  test "rejects non-allowlisted asset jumps" do
    assert {:error, {:invalid_transition, "staged", "ready"}} =
             AssetFSM.transition("staged", "ready")
    ...
  end
end
```

**Phase-33-specific coverage (per D-13 matrix):**
- Nominal path: `pending → uploading → processing → ready`.
- Errored branches from every in-flight state: `uploading → errored`, `processing → errored`, `ready → errored`.
- Terminal-delete from `ready` and `errored`.
- Re-ingest re-entry edge: `errored → processing`.
- Rejection coverage: `deleted → <anything>` (terminal sink); `pending → ready` (skips); `ready → uploading` (no backward).
- Telemetry: assert `[:rindle, :provider_asset, :state_change]` fires with metadata `%{profile, provider, from, to}` on accepted transitions (use `:telemetry.attach` + `assert_received`; mirror RESEARCH §"Code Examples" Example 4 for the attach/detach pattern).

---

### `test/rindle/domain/media_provider_asset_test.exs` (schema + changeset + Inspect)

**Analog:** `test/rindle/domain/media_schema_test.exs` (existing).

Coverage:
- Cast/changeset accepts all 6 states (`@states`).
- `validate_required/2` rejects missing `:asset_id`, `:profile`, `:provider_name`, `:state`.
- `validate_inclusion(:state, @states)` rejects unknown states.
- `unique_constraint` on `(provider_name, provider_asset_id)` and `(asset_id, profile, provider_name)`.
- **Inspect impl test (security invariant 14):**
  - Given `%MediaProviderAsset{provider_asset_id: "abc-12345"}`, `inspect/2` output contains `"...2345"` and does NOT contain `"abc-1"`.
  - Given `%MediaProviderAsset{raw_provider_metadata: %{secret: "x"}}`, `inspect/2` output contains `redacted: true` and does NOT contain `"x"`.

---

### `test/rindle/streaming/capabilities_test.exs` (vocabulary unit test)

Coverage:
- `Rindle.Streaming.Capabilities.known/0` returns the locked 5-atom list (`:signed_playback`, `:public_playback`, `:webhook_ingest`, `:server_push_ingest`, `:direct_creator_upload`).
- `safe/1` filters out unknown atoms; rescues raises in `adapter.capabilities()` and returns `[]`.
- `supports?/2` agrees with `safe/1`.

---

### `test/rindle/streaming/provider_test.exs` (`behaviour_info` unit test)

Coverage (assert via `Rindle.Streaming.Provider.behaviour_info(:callbacks)`):
- 6 required callbacks: `{:capabilities, 0}`, `{:create_asset, 3}`, `{:get_asset, 1}`, `{:delete_asset, 1}`, `{:signed_playback_url, 3}`, `{:verify_webhook, 3}`.
- 1 optional callback: `{:create_direct_upload, 2}` via `behaviour_info(:optional_callbacks)`.
- `streaming_url/3` is NOT in the callbacks list (D-05 enforcement).

---

### `test/rindle/capability_test.exs` (report shape)

**Analog:** RESEARCH §"Code Examples" Example 7.

Coverage:
- `report/0` returns the locked top-level keys (`:storage`, `:processor`, `:streaming` with sub-keys `:providers`, `:signed_playback_configured?`, `:configured_profiles`).
- `signed_playback_configured?` is `false` when `Application.put_env(:rindle, Rindle.Streaming.Provider.Mux, [])`.
- `signed_playback_configured?` is `true` when both `signing_key_id` AND `signing_private_key` are set.
- Does NOT crash when `:mux` dep is absent (D-30 — `Application.get_env/2` never raises).

---

## Shared Patterns

### Pattern A: Capability vocabulary (`@known` + `known/0` + `safe/1` with `rescue`)
**Source:** `lib/rindle/storage/capabilities.ex:1-67`
**Apply to:** `lib/rindle/streaming/capabilities.ex` (and any future `Rindle.<X>.Capabilities`).
**Excerpt:** see "Pattern Assignments → `lib/rindle/streaming/capabilities.ex`" above.
**Invariant:** closed allowlist; `safe/1` rescues to `[]`; do NOT add `require_*/2` helpers in Phase 33 (D-03).

### Pattern B: `binary_id` PK + `@foreign_key_type :binary_id` + state-as-string + `@states` allowlist
**Source:** `lib/rindle/domain/media_asset.ex:31-46, 58-81, 90-115`
**Apply to:** `lib/rindle/domain/media_provider_asset.ex`.
**Invariant:** `@primary_key {:id, :binary_id, autogenerate: true}` and `@foreign_key_type :binary_id` MUST appear before `schema/2`. State column is `:string` with `validate_inclusion(:state, @states)` (NOT `Ecto.Enum`).

### Pattern C: FSM as `@allowed_transitions` map + `transition/3` + `:telemetry.execute`
**Source:** `lib/rindle/domain/asset_fsm.ex:6-53`
**Apply to:** `lib/rindle/domain/provider_asset_fsm.ex`.
**Invariant:** caller-owned persistence (no Repo writes inside FSM); `tap/2` ensures `:ok` return after telemetry; `Logger.warning` on rejection.

### Pattern D: NimbleOptions schema + `validate!/2` + `rescue NimbleOptions.ValidationError → reraise ArgumentError`
**Source:** `lib/rindle/profile/validator.ex:35-48, 211-232`
**Apply to:** the new `:streaming` key validation in `lib/rindle/profile/validator.ex`.
**Invariant:** unknown keys rejected by default (D-16); error message prefixed with `"delivery: "` or `"streaming: "`.

### Pattern E: Adopter-owned migration handoff
**Source:** `priv/repo/migrations/20260424155129_create_media_assets.exs:1-21`; `priv/repo/migrations/20260502120000_extend_media_for_av.exs:1-34` (`@moduledoc` line 9 explicitly states "No DDL transaction disabling and no `lock_timeout`").
**Apply to:** the new `create_media_provider_assets` migration.
**Invariant:** additive only; idempotent; no inline runtime migration; adopters call `mix ecto.migrate` per `guides/getting_started.md`.

### Pattern F: Error-message clauses via `def message(%{reason: <atom>}) do "..." |> String.trim() end`
**Source:** `lib/rindle/error.ex:195-221`
**Apply to:** the 5 new clauses in `lib/rindle/error.ex`.
**Invariant:** bare-atom variants only in Phase 33 (D-27); cause→action wording style; heredoc + `String.trim/1`.

### Pattern G: Parity-freeze test via `@public_*_reasons` list + `expected_messages = %{...}` + `exact/1` heredoc helper
**Source:** `test/rindle/error_test.exs:1-100`
**Apply to:** `test/rindle/error_streaming_freeze_test.exs`.
**Invariant:** `exact/1` uses `String.trim_trailing/1`; two test cases minimum (atom-list lock + message-text lock); freeze locks wording at ship.

### Pattern H: Telemetry preservation on extended call sites
**Source:** `lib/rindle/delivery.ex:178-188`
**Apply to:** `Rindle.Delivery.streaming_url/3` body replacement.
**Invariant:** `[:rindle, :delivery, :streaming, :resolved]` fires with the SAME measurement key (`:system_time`) and the SAME metadata key set (`:profile, :adapter, :mode, :kind, :mime`) on Step 1 (no streaming) AND Step 6 (no row, non-strict) AND Step 5 (provider success); only `:kind` value changes (`:progressive` → `:hls` on Step 5).

### Pattern I: Custom `defimpl Inspect` for schema-level secret redaction
**Source:** new in Phase 33 (no in-repo analog — invariant 14 is added v1.6).
**Apply to:** `lib/rindle/domain/media_provider_asset.ex` only.
**Invariant:** D-14 — redact `provider_asset_id` to `"...<last4>"` and `raw_provider_metadata` to `%{redacted: true}`. This is the ONLY enforcement point for security invariant 14 at the schema layer; it must run on every `inspect/2`, telemetry-metadata logging, and `Logger`/`IO.inspect` boundary.

---

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| (none) | — | — | Every Phase 33 file has an in-repo mirror per RESEARCH.md `## Architectural Responsibility Map`. The Inspect-impl pattern (Pattern I above) is "new for Phase 33" but the Elixir-stdlib `defimpl Inspect` shape is canonical and well-documented; not a missing-analog risk. |

---

## Metadata

**Analog search scope:**
- `lib/rindle/storage/capabilities.ex` (vocab analog)
- `lib/rindle/domain/asset_fsm.ex` (FSM analog)
- `lib/rindle/domain/media_asset.ex` (schema analog)
- `lib/rindle/error.ex` (error vocab analog)
- `lib/rindle/delivery.ex` (dispatch analog — extends self)
- `lib/rindle/profile/validator.ex` (DSL analog — extends self)
- `lib/rindle/streaming/provider.ex` (current 2-callback shim — full rewrite)
- `lib/rindle/storage.ex`, `lib/rindle/processor.ex` (behaviour-discipline reference)
- `lib/rindle/ops/runtime_checks.ex` + `lib/mix/tasks/rindle.doctor.ex` (report-aggregator analog)
- `priv/repo/migrations/20260424155129_create_media_assets.exs`, `priv/repo/migrations/20260425090100_create_media_variants.exs`, `priv/repo/migrations/20260502120000_extend_media_for_av.exs` (migration analogs)
- `test/rindle/error_test.exs:1-100` (parity-freeze analog)
- `test/rindle/domain/lifecycle_fsm_test.exs:1-80` (FSM-test analog)
- `test/rindle/domain/media_schema_test.exs` (schema-test analog)

**Files scanned:** 12 source files + 3 test files.

**Pattern extraction date:** 2026-05-06.

---

## PATTERN MAPPING COMPLETE

**Phase:** 33 — Provider Boundary + State Schema
**Files classified:** 14 (8 production source CREATE/MODIFY + 6 Wave-0 test CREATE)
**Analogs found:** 14 / 14

### Coverage
- Files with exact analog: 11
- Files with role-match analog: 3 (`lib/rindle/capability.ex` aggregator; `test/rindle/streaming/capabilities_test.exs` and `test/rindle/streaming/provider_test.exs` test scaffolds and `test/rindle/capability_test.exs`)
- Files with no analog: 0

### Key Patterns Identified
- All capability vocabularies follow `@known` + `known/0` + `safe/1` with `rescue _ -> []` (Pattern A) — `lib/rindle/storage/capabilities.ex` is the canonical mirror.
- All Domain schemas use `binary_id` PK + `@foreign_key_type :binary_id` + state-as-`:string` + `validate_inclusion(:state, @states)` (Pattern B) — never `Ecto.Enum`.
- All FSMs are `@allowed_transitions` map + `transition/3` returning `:ok | {:error, {:invalid_transition, from, to}}` + `:telemetry.execute` on success (Pattern C); caller owns persistence.
- Profile DSL extensions follow NimbleOptions schema + `validate!/2` + `rescue NimbleOptions.ValidationError → reraise ArgumentError` (Pattern D); unknown keys rejected by default closes the "raw provider knobs" attack surface (D-16).
- Migrations are additive-only, no DDL transaction disabling, no `lock_timeout`; adopters run `mix ecto.migrate` (Pattern E).
- Error vocabulary clauses are `def message(%{reason: <atom>}) do "..." |> String.trim() end` with bare atoms only in Phase 33 (Pattern F); parity gate freezes wording at ship (Pattern G — AV-06-05 lesson).
- The `[:rindle, :delivery, :streaming, :resolved]` telemetry contract is the single load-bearing v1.4 carryover (Pattern H — D-24); preserved verbatim on Steps 1 & 6, fires with `kind: :hls` on Step 5.
- Security invariant 14 (provider-ID redaction) is enforced ONLY at the schema layer via custom `defimpl Inspect` (Pattern I — D-14); `Rindle.Capability.report/0` reinforces by returning booleans not config keys (D-30).

### File Created
`/Users/jon/projects/rindle/.planning/phases/33-provider-boundary-state-schema/33-PATTERNS.md`

### Ready for Planning
Pattern mapping complete. Planner can now reference per-file analog excerpts (with file paths + line numbers) and the 9 shared patterns A–I in the four locked plans (Capability vocab + Provider behaviour, Migration + schema + FSM + Inspect, Profile DSL + Dispatch tree, Error vocab + parity gate + Capability report).
