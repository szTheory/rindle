---
phase: 34-mux-rest-adapter-server-push-sync
plan: 02
type: execute
wave: 2
depends_on: [34-01]
autonomous: true
requirements: [MUX-03, MUX-05, MUX-06]
files_modified:
  - lib/rindle/workers/mux_ingest_variant.ex
  - test/rindle/workers/mux_ingest_variant_test.exs

must_haves:
  truths:
    - "`Rindle.Workers.MuxIngestVariant.perform/1` reads the source variant via `Rindle.Delivery.url(profile, key, expires_in: 1_800)`, calls `Rindle.Streaming.Provider.Mux.create_asset_with_retry_hint/3` (Plan 01's worker-facing variant), persists `provider_asset_id` + `playback_ids` (PLURAL ARRAY) into a `media_provider_assets` row, and advances the FSM `pending → uploading → processing` on the first run."
    - "Re-running with the same `(asset_id, profile, variant_name)` Oban-job args yields a no-op idempotent return when the row is already in `:uploading`, `:processing`, or `:ready` (the worker logs and returns `:ok` — it does NOT try the forbidden `processing → uploading` FSM edge). The Oban `unique` opts deduplicate at the JOB level via the `variant_name` arg key; the row-level uniqueness is `(asset_id, profile, provider_name)` which is intentional — different variants of the same asset+profile share one provider row."
    - "If the source `MediaAsset.storage_key` or `MediaVariant.recipe_digest` changes between enqueue and the flip to `:processing`, the worker returns `{:cancel, {:stale_source, :asset_changed | :recipe_changed}}` and emits `[:rindle, :provider, :ingest, :exception]` with `kind: :cancelled` (mirrors `process_variant.ex:244-275` verbatim)."
    - "Mux 429 responses surface `Retry-After` via `Rindle.Streaming.Provider.Mux.create_asset_with_retry_hint/3` — the adapter parses `%Tesla.Env{}.headers` (SDK Issue #42 footgun) and returns `{:error, :provider_quota_exceeded, retry_after}`; the worker translates that to `{:snooze, retry_after}` cleanly."
    - "Telemetry events `[:rindle, :provider, :ingest, :start | :stop | :exception]` fire with metadata `%{profile, provider, asset_id, variant_name, kind?}` and `asset_id` is the **redacted last-4-char tag** of the `provider_asset_id` (security invariant 14, via `MediaProviderAsset.redact_id/1` from Plan 01)."
    - "Worker is wrapped in `if Code.ensure_loaded?(Mux.Video.Assets) do` (Pitfall 4 #2 — adopters without `:mux` do not compile dead module references)."
  artifacts:
    - path: "lib/rindle/workers/mux_ingest_variant.ex"
      provides: "Server-push ingest worker (queue: :rindle_provider, max_attempts: 5)"
      contains: "use Oban.Worker, queue: :rindle_provider, max_attempts: 5"
    - path: "test/rindle/workers/mux_ingest_variant_test.exs"
      provides: "Oban.Testing.perform_job/2 + Mox-driven test suite covering MUX-03, MUX-05, MUX-06"
      min_lines: 200
  key_links:
    - from: "lib/rindle/workers/mux_ingest_variant.ex"
      to: "Rindle.Streaming.Provider.Mux.create_asset_with_retry_hint/3"
      via: "Adapter-internal API; PLURAL SDK key construction lives in adapter, NOT worker"
      pattern: "Rindle.Streaming.Provider.Mux.create_asset_with_retry_hint"
    - from: "lib/rindle/workers/mux_ingest_variant.ex"
      to: "Rindle.Domain.MediaProviderAsset.redact_id/1"
      via: "Telemetry metadata redaction at every emit"
      pattern: "MediaProviderAsset.redact_id"
    - from: "lib/rindle/workers/mux_ingest_variant.ex"
      to: "Rindle.Workers.ProcessVariant pattern"
      via: "Atomic-promote race protection mirrors `process_variant.ex:244-275`"
      pattern: ":stale_source"
    - from: "test/rindle/workers/mux_ingest_variant_test.exs"
      to: "Rindle.Streaming.Provider.Mux.ClientMock"
      via: "Mox.expect on `:create_asset/1` returns cassette fixture"
      pattern: "expect.*ClientMock.*:create_asset"
---

<objective>
Implement the Mux server-push ingest worker. The worker reads a Rindle-
produced AV variant via a private signed storage URL (TTL ≥ 30 min), pushes
the asset to Mux via the Plan-01 adapter's worker-facing
`create_asset_with_retry_hint/3` API (PLURAL SDK keys constructed inside
the adapter — never duplicated in the worker), persists `provider_asset_id`
and `playback_ids` (PLURAL array) into `media_provider_assets`, and
advances the FSM to `:processing`. Three closely related invariants —
idempotency under Oban unique (MUX-05), atomic-promote race protection on
flip-to-`:ready`-precondition (MUX-06, mirrors `process_variant.ex:244-275`),
and 429 `Retry-After` snooze (Pitfall 3) — are all enforced in this plan.

Purpose: this is the operationally most-novel piece of Phase 34 (memo
§7) — atomic-promote race + Oban unique + Mux SDK-Issue-#42 retry
handling all converge here.

Output: 1 new worker file, 1 new test file. The `:rindle_provider` queue
is exercised end-to-end via `Oban.Testing.perform_job/2` with Mox cassette
fixtures from Plan 01.
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

@lib/rindle/workers/process_variant.ex
@lib/rindle/streaming/provider.ex
@lib/rindle/domain/media_provider_asset.ex
@lib/rindle/domain/media_asset.ex
@lib/rindle/domain/media_variant.ex
@lib/rindle/domain/provider_asset_fsm.ex
@lib/rindle/delivery.ex
@lib/rindle/error.ex
@lib/rindle/config.ex
@test/rindle/workers/process_variant_test.exs

<interfaces>
<!-- Adapter callbacks Plan 02 invokes (from Plan 01) -->
```elixir
# lib/rindle/streaming/provider/mux.ex (Plan 01)

# Worker-facing variant — exposes 429 Retry-After cleanly. PLURAL SDK key
# construction lives ONLY in the adapter. Plan 02 worker MUST use this,
# never duplicate the params map.
@spec create_asset_with_retry_hint(module(), String.t(), keyword()) ::
        {:ok, %{provider_asset_id: String.t(), playback_ids: [String.t()]}}
        | {:error, :provider_quota_exceeded, non_neg_integer()}
        | {:error, atom()}
        | {:error, term()}

# Public redactor (Plan 01)
@spec Rindle.Domain.MediaProviderAsset.redact_id(nil | String.t()) :: nil | String.t()
```

<!-- ProcessVariant atomic-promote pattern (lib/rindle/workers/process_variant.ex:244-275) -->
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
      # ... happy path FSM transition + persist ...
  end
end
```

<!-- ProcessVariant unique_job_opts use site (lib/rindle/workers/process_variant.ex:51) -->
<!-- IMPORTANT: opts are wrapped as `unique:` keyword option. -->
```elixir
base_opts = [unique: unique_job_opts()]
# ... ProcessVariant.new(args, base_opts) ...
```

<!-- ProviderAssetFSM.transition/3 — third arg is a MAP (lib/rindle/domain/provider_asset_fsm.ex:28) -->
```elixir
@spec transition(state :: String.t(), state :: String.t(), context :: map()) :: :ok | {:error, term()}
def transition(current_state, target_state, context \\ %{}) do
  # context is read via Map.get(context, :profile, :unknown), NOT Keyword.get/2
end

# Locked transitions (provider_asset_fsm.ex:9-16):
#   "pending" => ["uploading", "errored"]
#   "uploading" => ["processing", "errored"]
#   "processing" => ["ready", "errored"]    # NOTE: processing -> uploading is FORBIDDEN
#   "ready" => ["errored", "deleted"]
#   "errored" => ["deleted", "processing"]
#   "deleted" => []
```

<!-- MediaProviderAsset schema (REAL FIELDS — Phase 33 lib/rindle/domain/media_provider_asset.ex) -->
<!-- Note `playback_ids` is PLURAL ARRAY. There is NO `variant_name` column. -->
<!-- Unique constraint is on (asset_id, profile, provider_name). -->
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

# @writable does NOT include :variant_name (no such column).
# changeset validate_required([:asset_id, :profile, :provider_name, :state])
# unique_constraint([:asset_id, :profile, :provider_name])
```

<!-- MediaAsset schema (lib/rindle/domain/media_asset.ex) — NOTE field name is `content_type`, NOT `mime` -->
```elixir
field :state, :string, default: "staged"
field :storage_key, :string
field :content_type, :string                # NOT `mime`
field :byte_size, :integer
field :profile, :string
field :kind, :string, default: "image"      # required: validate_required([:state, :storage_key, :profile, :kind])
```

<!-- MediaVariant schema (lib/rindle/domain/media_variant.ex) — NOTE field name is `output_kind`, NOT `kind` -->
```elixir
field :name, :string
field :state, :string, default: "planned"
field :recipe_digest, :string
field :storage_key, :string
field :output_kind, :string, default: "image"   # NOT `kind`
# validate_required([:asset_id, :name, :state, :recipe_digest, :output_kind])
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: MuxIngestVariant worker module</name>
  <files>lib/rindle/workers/mux_ingest_variant.ex</files>
  <read_first>
    - lib/rindle/workers/process_variant.ex (lines 1-37: macro/queue/timeout shape; line 51: `[unique: unique_job_opts()]` keyword wrapper; lines 244-275: atomic-promote `persist_ready`; lines 408-415: `unique_job_opts/0`; lines 461-485: telemetry + PubSub broadcast)
    - lib/rindle/streaming/provider.ex (provider behaviour)
    - lib/rindle/streaming/provider/mux.ex (Plan 01 — `create_asset_with_retry_hint/3` worker-facing API)
    - lib/rindle/domain/media_provider_asset.ex (schema + public `redact_id/1` from Plan 01; field is `playback_ids` PLURAL ARRAY; no `variant_name` column)
    - lib/rindle/domain/provider_asset_fsm.ex (FSM `transition/3` — third arg is a MAP; `processing → uploading` is FORBIDDEN)
    - lib/rindle/delivery.ex (lines 84-90: `signed_url_ttl_seconds/1`; lines 124-145 + `resolve_url/4`: `expires_in:` opt pass-through)
    - lib/rindle/config.ex (Repo access via `Config.repo()`)
    - .planning/phases/34-mux-rest-adapter-server-push-sync/34-PATTERNS.md section "lib/rindle/workers/mux_ingest_variant.ex"
    - .planning/phases/34-mux-rest-adapter-server-push-sync/34-CONTEXT.md decisions D-13..D-20, D-26..D-28, D-31..D-33
    - .planning/phases/34-mux-rest-adapter-server-push-sync/34-RESEARCH.md Pitfalls 1, 2, 3, 4, 5
    - .planning/phases/34-mux-rest-adapter-server-push-sync/34-01-SUMMARY.md (Plan 01 outputs — confirms ClientMock + adapter contracts; `create_asset_with_retry_hint/3` exists)
  </read_first>
  <behavior>
    - Test 1 (MUX-03 happy path): `perform_job(MuxIngestVariant, args)` with valid args + Mox `create_asset` cassette returns `:ok`; the matching `media_provider_assets` row exists with `provider_asset_id`, `playback_ids` (PLURAL ARRAY containing at least one string), `state: "processing"`.
    - Test 2 (MUX-03): Worker calls `Rindle.Streaming.Provider.Mux.create_asset_with_retry_hint/3` (NOT a direct `client.create_asset/1` call) — the adapter-internal API is the single channel; PLURAL SDK key construction is asserted via Mox at the ClientMock layer (the adapter still routes through ClientMock in tests).
    - Test 3 (MUX-03): FSM advances `pending → uploading → processing` (telemetry fires `[:rindle, :provider, :ingest, :start]` then `[:rindle, :provider, :ingest, :stop]`).
    - Test 4 (MUX-05 idempotency at job level): `MuxIngestVariant.new(args, unique: MuxIngestVariant.unique_job_opts())` deduplicates same-args enqueue (`Oban.insert/1` returns `conflict?: true` for the second enqueue within the period).
    - Test 5 (MUX-05 idempotent re-perform — does NOT trigger forbidden FSM edge): If the worker is re-`perform`'d when the row is already in `:uploading` / `:processing` / `:ready`, it returns `:ok` (no-op) and does NOT call the adapter again, and does NOT attempt the forbidden `processing → uploading` transition.
    - Test 6 (MUX-06 atomic-promote on `storage_key` drift): Mutate `MediaAsset.storage_key` between enqueue and perform — `perform/1` returns `{:cancel, {:stale_source, :asset_changed}}` and emits `[:rindle, :provider, :ingest, :exception]` with `kind: :cancelled`.
    - Test 7 (MUX-06 atomic-promote on `recipe_digest` drift): Mutate `MediaVariant.recipe_digest` — returns `{:cancel, {:stale_source, :recipe_changed}}`.
    - Test 8 (Pitfall 3 — 429 snooze): Mox stub on ClientMock returns `{:error, "rate limit", %Tesla.Env{status: 429, headers: [{"retry-after", "60"}]}}` — the adapter's `create_asset_with_retry_hint/3` returns `{:error, :provider_quota_exceeded, 60}` and the worker returns `{:snooze, 60}`.
    - Test 9 (security invariant 14): Telemetry capture confirms `metadata.asset_id` matches `~r/^\.\.\.[A-Za-z0-9]{4}$/` (NEVER raw 30+ char id).
  </behavior>
  <action>
Create `lib/rindle/workers/mux_ingest_variant.ex`:

```elixir
# Compiled only when {:mux, "~> 3.2"} is loaded (Pitfall 4 #2 —
# guards prevent dead module references in adopters without :mux).
if Code.ensure_loaded?(Mux.Video.Assets) do
  defmodule Rindle.Workers.MuxIngestVariant do
    @moduledoc """
    Push a Rindle-produced AV variant to Mux from server context.

    The worker reads the source variant via a private signed storage URL
    (`Rindle.Delivery.url(profile, key, expires_in: 1_800)`), calls
    `Rindle.Streaming.Provider.Mux.create_asset_with_retry_hint/3`, persists
    the resulting `provider_asset_id` + `playback_ids` (PLURAL ARRAY) into
    a `media_provider_assets` row, and advances the FSM
    `pending → uploading → processing`.

    ## Adopter wiring (Phase 36 owns the canonical guide)

        config :my_app, Oban,
          queues: [rindle_provider: 4]

    ## Job arguments

        %{
          "asset_id" => binary_id,
          "profile" => "MyApp.Profiles.Web",            # module name as string
          "variant_name" => "hero",
          "expected_storage_key" => storage_key_at_enqueue,
          "expected_recipe_digest" => recipe_digest_at_enqueue
        }

    The two `expected_*` fields are the captured-at-enqueue values used by
    the atomic-promote race protection (mirrors `process_variant.ex:244-275`
    verbatim — AV-03-10).

    Note: `variant_name` lives ONLY in Oban job args (and in the Oban
    `unique` key for job-level idempotency). It is NOT a column on
    `media_provider_assets`. The row-level uniqueness is
    `(asset_id, profile, provider_name)` — different variants of the same
    asset+profile share one provider row, by design (Phase 33 schema).

    ## Telemetry contract (security invariant 14 enforced via
    `MediaProviderAsset.redact_id/1` on every metadata `asset_id`)

        [:rindle, :provider, :ingest, :start]
          measurements: %{system_time}
          metadata:     %{profile, provider, asset_id, variant_name}

        [:rindle, :provider, :ingest, :stop]
          measurements: %{system_time, duration}
          metadata:     %{profile, provider, asset_id, variant_name}

        [:rindle, :provider, :ingest, :exception]
          measurements: %{system_time, duration?}
          metadata:     %{profile, provider, asset_id, variant_name, kind}
                        # kind: :error | :cancelled

    ## Idempotency — two layers

      1. JOB LEVEL (Oban `unique`): keys on `(asset_id, profile, variant_name)`
         across `[:scheduled, :executing, :retryable, :completed]` states with
         a `period: 86_400` (24h) cooldown. Use `unique: unique_job_opts()`
         when enqueueing (matches `process_variant.ex:51` shape).

      2. PERFORM LEVEL: if the worker is re-invoked while the row is already
         in `:uploading`, `:processing`, or `:ready`, the worker logs and
         returns `:ok` immediately. It does NOT re-call the adapter and does
         NOT attempt the forbidden `processing → uploading` FSM edge
         (`provider_asset_fsm.ex:9-16`).
    """

    use Oban.Worker, queue: :rindle_provider, max_attempts: 5

    require Logger

    alias Rindle.Domain.{MediaAsset, MediaVariant, MediaProviderAsset, ProviderAssetFSM}
    alias Rindle.Streaming.Provider.Mux, as: Adapter

    @impl Oban.Worker
    def timeout(_job), do: :timer.minutes(5)  # integer ms only — D-15 (Oban 2.21 rejects tuple form)

    @impl Oban.Worker
    @spec perform(Oban.Job.t()) :: :ok | {:error, term()} | {:snooze, non_neg_integer()} | {:cancel, term()}
    def perform(%Oban.Job{args: args}) do
      repo = Rindle.Config.repo()
      start_time = System.monotonic_time()
      profile_mod = String.to_existing_atom(args["profile"])

      emit_event(:start, %{system_time: System.system_time()},
        base_metadata(profile_mod, args["variant_name"], nil)
      )

      with {:ok, asset, variant} <- fetch_source(repo, args),
           :ok <- check_freshness(asset, variant, args),
           {:ok, row} <- ensure_pending_row(repo, args, asset),
           {:cont, _} <- maybe_skip_already_in_progress(row, profile_mod, args, start_time),
           {:ok, signed_url} <- Rindle.Delivery.url(profile_mod, variant.storage_key, expires_in: 1_800),
           :ok <- transition_uploading(repo, row, profile_mod, asset),
           {:ok, mux_response} <- call_mux_create(profile_mod, signed_url),
           {:ok, persisted} <- persist_provider_processing(repo, args, mux_response, profile_mod) do
        emit_event(:stop,
          %{system_time: System.system_time(), duration: System.monotonic_time() - start_time},
          base_metadata(profile_mod, args["variant_name"], persisted.provider_asset_id)
        )
        :ok
      else
        {:halt, :already_in_progress} ->
          # B5 fix: idempotent re-perform when row is already past :pending.
          # Do NOT attempt processing -> uploading (FSM forbids it).
          Logger.debug("rindle.workers.mux_ingest_variant.skip_already_in_progress",
            profile: profile_mod,
            variant_name: args["variant_name"]
          )
          emit_event(:stop,
            %{system_time: System.system_time(), duration: System.monotonic_time() - start_time},
            base_metadata(profile_mod, args["variant_name"], nil)
          )
          :ok

        {:cancel, {:stale_source, _} = reason} ->
          emit_event(:exception,
            %{system_time: System.system_time(), duration: System.monotonic_time() - start_time},
            base_metadata(profile_mod, args["variant_name"], nil) |> Map.put(:kind, :cancelled)
          )
          {:cancel, reason}

        {:snooze, _} = snooze ->
          snooze

        {:error, reason} = err ->
          emit_event(:exception,
            %{system_time: System.system_time(), duration: System.monotonic_time() - start_time},
            base_metadata(profile_mod, args["variant_name"], nil) |> Map.put(:kind, :error) |> Map.put(:reason, reason)
          )
          err
      end
    end

    @doc """
    Oban `unique` opts for job-level idempotency. Wrap as
    `unique: unique_job_opts()` when enqueueing — matches the
    `process_variant.ex:51` `[unique: unique_job_opts()]` shape.

    Differs from `process_variant.ex:408-415` by adding `:profile` to keys
    (since the same `asset_id` can ingest into multiple profiles) and using
    `period: 86_400` instead of `:infinity` (re-ingest is possible after 24h).
    """
    @spec unique_job_opts() :: keyword()
    def unique_job_opts do
      [
        fields: [:args, :worker, :queue],
        keys: [:asset_id, :profile, :variant_name],
        states: [:scheduled, :executing, :retryable, :completed],
        period: 86_400
      ]
    end

    # ============================================================
    # Source fetch + freshness (atomic-promote race — mirrors
    # process_variant.ex:244-275 verbatim with arg-shape swap).
    # ============================================================

    defp fetch_source(repo, args) do
      case repo.get(MediaAsset, args["asset_id"]) do
        nil -> {:error, :not_found}
        asset ->
          case repo.get_by(MediaVariant, asset_id: asset.id, name: args["variant_name"]) do
            nil -> {:error, :not_found}
            variant -> {:ok, asset, variant}
          end
      end
    end

    defp check_freshness(%MediaAsset{} = asset, %MediaVariant{} = variant, args) do
      cond do
        asset.storage_key != args["expected_storage_key"] ->
          {:cancel, {:stale_source, :asset_changed}}

        variant.recipe_digest != args["expected_recipe_digest"] ->
          {:cancel, {:stale_source, :recipe_changed}}

        true ->
          :ok
      end
    end

    # ============================================================
    # MediaProviderAsset row lifecycle.
    # ============================================================

    # B2 fix: NO :variant_name in attrs — the schema has no such column.
    # Row uniqueness is (asset_id, profile, provider_name); the same provider
    # row is reused across variants of the same asset+profile.
    defp ensure_pending_row(repo, args, asset) do
      attrs = %{
        asset_id: asset.id,
        profile: args["profile"],
        provider_name: "mux",
        playback_policy: "signed",
        state: "pending"
      }

      case repo.get_by(MediaProviderAsset,
             asset_id: asset.id,
             profile: args["profile"],
             provider_name: "mux"
           ) do
        nil ->
          %MediaProviderAsset{}
          |> MediaProviderAsset.changeset(attrs)
          |> repo.insert()

        existing ->
          {:ok, existing}
      end
    end

    # B5 fix: branch on row.state BEFORE attempting transition_uploading.
    # `processing → uploading` is NOT in @allowed_transitions
    # (provider_asset_fsm.ex:9-16). Re-performs on rows in those states
    # are no-op idempotent successes, NOT FSM violations.
    defp maybe_skip_already_in_progress(row, _profile, _args, _start_time) do
      case row.state do
        "pending" -> {:cont, row}
        state when state in ["uploading", "processing", "ready"] -> {:halt, :already_in_progress}
        # :errored / :deleted fall through to normal flow; transition_uploading
        # will fail safely if the FSM rejects it.
        _ -> {:cont, row}
      end
    end

    defp transition_uploading(repo, row, profile, asset) do
      # B4 fix: ProviderAssetFSM.transition/3 third arg is a MAP, not keyword list.
      with :ok <- ProviderAssetFSM.transition(row.state, "uploading",
                    %{profile: profile, provider: :mux, asset_id: asset.id}),
           {:ok, _} <- row |> MediaProviderAsset.changeset(%{state: "uploading"}) |> repo.update() do
        :ok
      end
    end

    # B1 fix: persist `playback_ids` (PLURAL ARRAY), not singular `playback_id`.
    # Phase 33 schema field is `field :playback_ids, {:array, :string}`.
    defp persist_provider_processing(repo, args, mux_response, profile_mod) do
      # Atomic-promote: re-fetch source rows just before flipping to processing.
      # Mirrors process_variant.ex:244-275 with arg-shape swap.
      current_asset = repo.get!(MediaAsset, args["asset_id"])
      current_variant = repo.get_by!(MediaVariant, asset_id: args["asset_id"], name: args["variant_name"])

      cond do
        current_asset.storage_key != args["expected_storage_key"] ->
          {:cancel, {:stale_source, :asset_changed}}

        current_variant.recipe_digest != args["expected_recipe_digest"] ->
          {:cancel, {:stale_source, :recipe_changed}}

        true ->
          row =
            repo.get_by!(MediaProviderAsset,
              asset_id: args["asset_id"],
              profile: args["profile"],
              provider_name: "mux"
            )

          # B1 fix: write the PLURAL array verbatim. Even if Mux returned a
          # single id, we wrap it in a list to match the schema field shape.
          attrs = %{
            provider_asset_id: mux_response.provider_asset_id,
            playback_ids: mux_response.playback_ids,
            state: "processing",
            raw_provider_metadata: %{}
          }

          # B4 fix: third arg is a MAP.
          with :ok <- ProviderAssetFSM.transition(row.state, "processing",
                        %{profile: profile_mod, provider: :mux, asset_id: args["asset_id"]}),
               {:ok, persisted} <- row |> MediaProviderAsset.changeset(attrs) |> repo.update() do
            {:ok, persisted}
          end
      end
    end

    # ============================================================
    # Adapter call — routed through `create_asset_with_retry_hint/3`.
    # PLURAL SDK key construction lives ONLY in the adapter (Plan 01);
    # NEVER duplicated here. (B7 fix.)
    # ============================================================

    defp call_mux_create(profile_mod, signed_url) do
      # Phase 34 default policy is :signed (capability `[:signed_playback, ...]`).
      # Profile-level overrides happen at the adapter layer, not the worker.
      case Adapter.create_asset_with_retry_hint(profile_mod, signed_url, playback_policy: :signed) do
        {:ok, %{provider_asset_id: _, playback_ids: _} = ok} ->
          {:ok, ok}

        # Pitfall 3 / SDK Issue #42: 429 surfaces with parsed Retry-After.
        {:error, :provider_quota_exceeded, retry_after} when is_integer(retry_after) and retry_after > 0 ->
          {:snooze, retry_after}

        {:error, reason} ->
          {:error, reason}
      end
    end

    # ============================================================
    # Telemetry — security invariant 14 redaction at every emit.
    # ============================================================

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
  end
end
```

Run `mix compile --warnings-as-errors` after writing the file. The worker compiles in test env (where `:mux` is loaded) and is excluded from compilation in adopters without `:mux`.
  </action>
  <verify>
    <automated>mix compile --warnings-as-errors 2>&1 | tail -10 && grep -c "use Oban.Worker, queue: :rindle_provider, max_attempts: 5" lib/rindle/workers/mux_ingest_variant.ex && grep -c "if Code.ensure_loaded?(Mux.Video.Assets) do" lib/rindle/workers/mux_ingest_variant.ex && grep -c ":stale_source, :asset_changed" lib/rindle/workers/mux_ingest_variant.ex && grep -c ":stale_source, :recipe_changed" lib/rindle/workers/mux_ingest_variant.ex && grep -c "MediaProviderAsset.redact_id" lib/rindle/workers/mux_ingest_variant.ex && grep -c ":snooze" lib/rindle/workers/mux_ingest_variant.ex && grep -c "expires_in: 1_800" lib/rindle/workers/mux_ingest_variant.ex && grep -c "period: 86_400" lib/rindle/workers/mux_ingest_variant.ex && grep -c "playback_ids:" lib/rindle/workers/mux_ingest_variant.ex && grep -c "create_asset_with_retry_hint" lib/rindle/workers/mux_ingest_variant.ex</automated>
  </verify>
  <acceptance_criteria>
    - File opens with `if Code.ensure_loaded?(Mux.Video.Assets) do` (Pitfall 4 #2)
    - File contains `use Oban.Worker, queue: :rindle_provider, max_attempts: 5` (D-13, D-14)
    - File contains `def timeout(_job), do: :timer.minutes(5)` (D-15 — integer ms, not tuple)
    - `unique_job_opts/0` returns keyword list with `keys: [:asset_id, :profile, :variant_name]`, `period: 86_400`, and `states: [:scheduled, :executing, :retryable, :completed]` (D-16)
    - `perform/1` calls `Rindle.Delivery.url(profile_mod, variant.storage_key, expires_in: 1_800)` (D-18, Pitfall 2 — uses `expires_in:`, not `ttl:`)
    - `perform/1` includes `cond` with `current_asset.storage_key != args["expected_storage_key"]` returning `{:cancel, {:stale_source, :asset_changed}}` (MUX-06)
    - `perform/1` includes `cond` with `current_variant.recipe_digest != args["expected_recipe_digest"]` returning `{:cancel, {:stale_source, :recipe_changed}}` (MUX-06)
    - `maybe_skip_already_in_progress/4` returns `{:halt, :already_in_progress}` for rows in `:uploading` / `:processing` / `:ready` (B5 — idempotent re-perform without touching forbidden FSM edge)
    - File contains `{:snooze, retry_after}` returned from `call_mux_create/2` on `{:error, :provider_quota_exceeded, retry_after}` (Pitfall 3, B7)
    - File calls `Rindle.Streaming.Provider.Mux.create_asset_with_retry_hint(profile_mod, signed_url, playback_policy: :signed)` — NEVER constructs `params` with `"inputs"` / `"playback_policies"` directly (B7 — PLURAL SDK key construction lives in adapter)
    - `persist_provider_processing/4` writes `playback_ids: mux_response.playback_ids` (PLURAL ARRAY — B1 fix, matches schema `field :playback_ids, {:array, :string}`)
    - `ensure_pending_row/3` attrs map does NOT contain `variant_name:` (B2 fix — no such column on `media_provider_assets`)
    - `ProviderAssetFSM.transition/3` is called with a MAP as the third argument (B4 — `%{profile: ..., provider: :mux, asset_id: ...}`), NEVER a keyword list `[profile: ...]`
    - Every `:telemetry.execute([:rindle, :provider, :ingest, _], ...)` emits metadata where `asset_id:` value flows through `MediaProviderAsset.redact_id/1` (security invariant 14)
    - File does NOT reference `args["opts"]` (B7 — dead path removed)
    - File contains `String.to_existing_atom(args["profile"])` (string-keyed args — D-17)
    - `mix compile --warnings-as-errors` exits 0
  </acceptance_criteria>
  <done>Worker module compiles cleanly under optional-dep guard; uses adapter-internal `create_asset_with_retry_hint/3` (no SDK param duplication); writes PLURAL `playback_ids`; idempotent re-perform short-circuits without touching forbidden FSM edge; FSM `transition/3` called with a MAP; all four cross-cutting invariants — atomic-promote race, Oban unique idempotency, 429 Retry-After extraction, security invariant 14 redaction — are present at the precise grep locations the test file in Task 2 will exercise.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: MuxIngestVariant test suite (MUX-03/05/06 + Pitfall 3 + invariant 14)</name>
  <files>test/rindle/workers/mux_ingest_variant_test.exs</files>
  <read_first>
    - lib/rindle/workers/mux_ingest_variant.ex (the file Task 1 just created)
    - test/rindle/workers/process_variant_test.exs (full test shape — `setup :set_mox_from_context`, inline `TestProfile`, Oban.Testing usage)
    - test/rindle/streaming/provider/mux/mux_test.exs (Plan 01 — adapter test pattern with ClientMock setup)
    - test/support/mocks.ex (ClientMock registration from Plan 01)
    - lib/rindle/domain/media_asset.ex (REAL field names: `content_type`, NOT `mime`; `validate_required([:state, :storage_key, :profile, :kind])`)
    - lib/rindle/domain/media_variant.ex (REAL field names: `output_kind`, NOT `kind`; `validate_required([:asset_id, :name, :state, :recipe_digest, :output_kind])`)
    - .planning/phases/34-mux-rest-adapter-server-push-sync/34-PATTERNS.md section "test/rindle/workers/mux_ingest_variant_test.exs"
    - .planning/phases/34-mux-rest-adapter-server-push-sync/34-VALIDATION.md per-task verification map (MUX-03, MUX-05, MUX-06)
  </read_first>
  <action>
Create `test/rindle/workers/mux_ingest_variant_test.exs`:

```elixir
defmodule Rindle.Workers.MuxIngestVariantTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo
  import Mox
  import Ecto.Query, only: [from: 2]

  alias Rindle.Domain.{MediaAsset, MediaVariant, MediaProviderAsset}
  alias Rindle.Workers.MuxIngestVariant
  alias Rindle.Streaming.Provider.Mux.ClientMock

  setup :set_mox_from_context
  setup :verify_on_exit!

  defmodule TestProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      streaming: Rindle.Streaming.Provider.Mux,
      signed_url_ttl_seconds: 900,
      variants: [hero: [kind: :video, preset: :web_720p]],
      allow_mime: ["video/mp4"],
      max_bytes: 524_288_000
  end

  setup do
    prev = Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])

    Application.put_env(:rindle, Rindle.Streaming.Provider.Mux,
      Keyword.merge(prev, [
        http_client: ClientMock,
        token_id: "test_token_id",
        token_secret: "test_token_secret",
        signing_key_id: "test_kid",
        signing_private_key: File.read!("test/fixtures/mux/test_signing_private_key.pem")
      ])
    )

    on_exit(fn -> Application.put_env(:rindle, Rindle.Streaming.Provider.Mux, prev) end)

    # Stub Storage adapter to return a signed URL when worker calls Rindle.Delivery.url/3.
    stub(Rindle.StorageMock, :url, fn _key, opts ->
      {:ok, "https://signed.example/v.mp4?expires=#{Keyword.get(opts, :expires_in, 0)}"}
    end)

    asset_id = Ecto.UUID.generate()
    storage_key = "media/#{asset_id}/source.mp4"
    recipe_digest = "sha256:" <> String.duplicate("a", 64)

    # B3 fix: use REAL MediaAsset schema field names.
    #   - `content_type` (NOT `mime`)
    #   - validate_required([:state, :storage_key, :profile, :kind])
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

    # B3 fix: use REAL MediaVariant schema field names.
    #   - `output_kind` (NOT `kind`)
    #   - validate_required([:asset_id, :name, :state, :recipe_digest, :output_kind])
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

    %{asset: asset, variant: variant, args: args}
  end

  defp fixture(name), do: File.read!("test/fixtures/mux/#{name}") |> Jason.decode!()

  # ===========================================================
  # MUX-03 — happy path
  # ===========================================================

  test "ingests variant, persists provider_asset_id + playback_ids (PLURAL), advances FSM to :processing", ctx do
    expect(ClientMock, :create_asset, fn params ->
      # D-04 memo correction: PLURAL keys at SDK boundary.
      assert params["inputs"] == [%{"url" => "https://signed.example/v.mp4?expires=1800"}]
      assert params["playback_policies"] == ["signed"]
      assert params["mp4_support"] == "standard"
      {:ok, fixture("asset_create_201.json")}
    end)

    assert :ok = perform_job(MuxIngestVariant, ctx.args)

    row = Repo.get_by!(MediaProviderAsset, asset_id: ctx.asset.id, profile: to_string(TestProfile))
    assert row.state == "processing"
    assert is_binary(row.provider_asset_id)
    # B1 fix: row.playback_ids is a PLURAL ARRAY (Phase 33 schema field).
    assert is_list(row.playback_ids)
    assert [first | _] = row.playback_ids
    assert is_binary(first)
  end

  # ===========================================================
  # MUX-05 — idempotency
  # ===========================================================

  test "Oban.unique semantics: enqueue with unique opts deduplicates at the JOB level", ctx do
    # B6 fix: opts are wrapped as `unique:` keyword option (matches process_variant.ex:51).
    job = MuxIngestVariant.new(ctx.args, unique: MuxIngestVariant.unique_job_opts())
    assert {:ok, _} = Oban.insert(job)

    # Re-enqueue same args within period — should return existing job, not new.
    job2 = MuxIngestVariant.new(ctx.args, unique: MuxIngestVariant.unique_job_opts())
    assert {:ok, returned} = Oban.insert(job2)
    assert returned.conflict?
  end

  test "re-running perform on a row already in :processing yields :ok no-op (does not retry forbidden FSM edge)", ctx do
    expect(ClientMock, :create_asset, 1, fn _params -> {:ok, fixture("asset_create_201.json")} end)

    # First run: rows reach :processing.
    assert :ok = perform_job(MuxIngestVariant, ctx.args)
    rows_after_first = Repo.all(from r in MediaProviderAsset, where: r.asset_id == ^ctx.asset.id)
    assert length(rows_after_first) == 1

    # Second run on the same args. ClientMock.expect was called exactly once
    # (verified by `verify_on_exit!`); the worker must NOT call create_asset again.
    # B5 fix: re-perform short-circuits via maybe_skip_already_in_progress/4 and
    # returns :ok WITHOUT attempting the forbidden processing -> uploading transition.
    assert :ok = perform_job(MuxIngestVariant, ctx.args)
    rows_after_second = Repo.all(from r in MediaProviderAsset, where: r.asset_id == ^ctx.asset.id)
    assert length(rows_after_second) == 1
    assert hd(rows_after_second).state == "processing"
  end

  # ===========================================================
  # MUX-06 — atomic-promote race protection
  # ===========================================================

  test "atomic_promote: storage_key drift returns {:cancel, {:stale_source, :asset_changed}}", ctx do
    # No ClientMock expectation: drift should be detected before the SDK call.
    # Drift: mutate storage_key after enqueue (simulates a re-upload during ingest).
    {:ok, _} = ctx.asset |> MediaAsset.changeset(%{storage_key: "media/" <> ctx.asset.id <> "/different.mp4"}) |> Repo.update()

    assert {:cancel, {:stale_source, :asset_changed}} = perform_job(MuxIngestVariant, ctx.args)
  end

  test "atomic_promote: recipe_digest drift returns {:cancel, {:stale_source, :recipe_changed}}", ctx do
    {:ok, _} = ctx.variant |> MediaVariant.changeset(%{recipe_digest: "sha256:" <> String.duplicate("b", 64)}) |> Repo.update()

    assert {:cancel, {:stale_source, :recipe_changed}} = perform_job(MuxIngestVariant, ctx.args)
  end

  test "atomic_promote: drift emits [:rindle, :provider, :ingest, :exception] with kind: :cancelled", ctx do
    test_pid = self()
    handler_id = "ingest-cancelled-#{System.unique_integer([:positive])}"

    :telemetry.attach(handler_id, [:rindle, :provider, :ingest, :exception], fn _e, m, meta, _ ->
      send(test_pid, {:tele, m, meta})
    end, nil)

    on_exit(fn -> :telemetry.detach(handler_id) end)

    {:ok, _} = ctx.asset |> MediaAsset.changeset(%{storage_key: "media/" <> ctx.asset.id <> "/drifted.mp4"}) |> Repo.update()

    assert {:cancel, _} = perform_job(MuxIngestVariant, ctx.args)
    assert_receive {:tele, _, %{kind: :cancelled}}, 1_000
  end

  # ===========================================================
  # Pitfall 3 — 429 Retry-After extraction (SDK Issue #42)
  # ===========================================================

  test "429 from Mux returns {:snooze, retry_after_seconds}", ctx do
    expect(ClientMock, :create_asset, fn _params ->
      {:error, "rate limit",
       %Tesla.Env{status: 429, headers: [{"retry-after", "60"}], body: ""}}
    end)

    assert {:snooze, 60} = perform_job(MuxIngestVariant, ctx.args)
  end

  test "429 with missing Retry-After defaults to 60s snooze", ctx do
    expect(ClientMock, :create_asset, fn _params ->
      {:error, "rate limit", %Tesla.Env{status: 429, headers: [], body: ""}}
    end)

    assert {:snooze, 60} = perform_job(MuxIngestVariant, ctx.args)
  end

  # ===========================================================
  # Security invariant 14 — telemetry asset_id is redacted
  # ===========================================================

  test "every [:rindle, :provider, :ingest, _] event has redacted asset_id (last-4-char tag)", ctx do
    expect(ClientMock, :create_asset, fn _params -> {:ok, fixture("asset_create_201.json")} end)

    test_pid = self()
    handler_id = "ingest-redact-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(handler_id,
      [
        [:rindle, :provider, :ingest, :start],
        [:rindle, :provider, :ingest, :stop]
      ],
      fn event, _m, metadata, _ -> send(test_pid, {:tele, event, metadata}) end,
      nil)

    on_exit(fn -> :telemetry.detach(handler_id) end)

    assert :ok = perform_job(MuxIngestVariant, ctx.args)

    # :start has nil asset_id (no Mux response yet); :stop has redacted last-4-char tag.
    assert_receive {:tele, [:rindle, :provider, :ingest, :start], %{asset_id: nil}}, 500
    assert_receive {:tele, [:rindle, :provider, :ingest, :stop], %{asset_id: redacted}}, 500
    assert redacted =~ ~r/^\.\.\.[A-Za-z0-9]{4}$/,
           "Telemetry must redact provider_asset_id to last-4-char tag (security invariant 14); got: #{inspect(redacted)}"
  end
end
```

Run `mix test test/rindle/workers/mux_ingest_variant_test.exs --max-failures 1` after writing the file.
  </action>
  <verify>
    <automated>mix test test/rindle/workers/mux_ingest_variant_test.exs --max-failures 1 2>&1 | tail -30</automated>
  </verify>
  <acceptance_criteria>
    - File exists at `test/rindle/workers/mux_ingest_variant_test.exs`
    - File contains `setup :set_mox_from_context` and `setup :verify_on_exit!` (Mox + Oban-test-process pattern)
    - File contains `use Oban.Testing, repo: Rindle.Repo`
    - `MediaAsset.changeset(%{...})` test setup uses `content_type: "video/mp4"` (NOT `mime:`) and includes the required `kind: "video"` (B3 fix)
    - `MediaVariant.changeset(%{...})` test setup uses `output_kind: "video"` (NOT `kind:`) and includes `state: "ready"` (B3 fix)
    - File contains test "ingests variant, persists provider_asset_id + playback_ids (PLURAL), advances FSM to :processing" (MUX-03) — assertions `is_list(row.playback_ids)` and `[first | _] = row.playback_ids` (B1)
    - File contains test "Oban.unique semantics: enqueue with unique opts deduplicates at the JOB level" — uses `MuxIngestVariant.new(ctx.args, unique: MuxIngestVariant.unique_job_opts())` (B6 — `unique:` keyword wrapper)
    - File contains test "re-running perform on a row already in :processing yields :ok no-op" — calls `perform_job/2` twice and asserts only ONE adapter call AND ONE row (B5 — idempotent re-perform without forbidden FSM edge)
    - File contains test "atomic_promote: storage_key drift returns {:cancel, {:stale_source, :asset_changed}}" (MUX-06)
    - File contains test "atomic_promote: recipe_digest drift returns {:cancel, {:stale_source, :recipe_changed}}" (MUX-06)
    - File contains test "429 from Mux returns {:snooze, retry_after_seconds}" (Pitfall 3)
    - File contains test "every [:rindle, :provider, :ingest, _] event has redacted asset_id" (security invariant 14)
    - File contains `params["playback_policies"] == ["signed"]` assertion (D-04 PLURAL guard)
    - File contains `assert redacted =~ ~r/^\.\.\.[A-Za-z0-9]{4}$/` regex assertion
    - `mix test test/rindle/workers/mux_ingest_variant_test.exs --max-failures 1` exits 0
  </acceptance_criteria>
  <done>All MUX-03/05/06 + Pitfall 3 + invariant 14 invariants are exercised by tests using REAL schema field names; the worker is end-to-end driveable from `Oban.Testing.perform_job/2` with cassette + Mox; idempotent re-perform path verified; redaction is verified by regex on telemetry metadata; `unique:` keyword wrapper used at all enqueue sites.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Adopter app → Rindle worker | Adopter enqueues `MuxIngestVariant` jobs from their own hook code; args are validated at perform time. |
| Worker → Mux REST API (via Plan 01 adapter) | Server-to-server with HTTP Basic Auth; never embeds adopter-supplied data unsanitized. The worker uses `create_asset_with_retry_hint/3`; PLURAL SDK key construction never crosses this boundary outside the adapter. |
| Worker → `media_provider_assets` row | Repo writes go through `Rindle.Config.repo()`; FSM transitions allowlisted in Phase 33's `ProviderAssetFSM` with MAP context. |
| Worker → telemetry consumers | Adopter telemetry handlers receive metadata; redaction enforced at emit (security invariant 14). |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-34-02-01 | Tampering / Data Integrity | `MuxIngestVariant.persist_provider_processing/4` (atomic-promote) | mitigate | `expected_storage_key` + `expected_recipe_digest` captured at enqueue, re-checked just before flip-to-`:processing`; drift → `{:cancel, {:stale_source, _}}` aborts cleanly (D-19; mirrors AV-03-10 / `process_variant.ex:244-275`). |
| T-34-02-02 | Information Disclosure | Telemetry `metadata.asset_id` leaking raw `provider_asset_id` | mitigate | Every emit metadata flows through `MediaProviderAsset.redact_id/1` (Plan 01); regex test asserts `~r/^\.\.\.[A-Za-z0-9]{4}$/` on the captured metadata (Pitfall 5). Security invariant 14. |
| T-34-02-03 | Denial of Service (self-inflicted) | Mux 429 retry storm | mitigate | Worker calls `Adapter.create_asset_with_retry_hint/3` which reads `Retry-After` from `%Tesla.Env{}.headers` directly (SDK Issue #42); worker translates `{:error, :provider_quota_exceeded, retry_after}` to `{:snooze, retry_after}` (Pitfall 3, B7). |
| T-34-02-04 | Tampering | Duplicate `media_provider_assets` rows for same source variant | mitigate | Two-layer protection: (1) Oban `unique` keyed on `(asset_id, profile, variant_name)` for `[:scheduled, :executing, :retryable, :completed]` with `period: 86_400` — JOB-LEVEL idempotency; (2) row-level `unique_constraint([:asset_id, :profile, :provider_name])` from Phase 33 schema; `ensure_pending_row/3` looks up before insert. Different variants of the same asset+profile share one provider row (intentional per Phase 33 schema). |
| T-34-02-05 | Information Disclosure | Source-storage URL TTL too long → leaked URL grants extended access | mitigate | `Rindle.Delivery.url(profile, key, expires_in: 1_800)` — exactly 30 min, the floor for Mux ingest queue depth (Pitfall 2 / D-18). Mux fetches asynchronously; once `create_asset` returns, the URL can expire. |
| T-34-02-06 | Spoofing | `args["profile"]` allowing arbitrary atom creation | mitigate | `String.to_existing_atom/1` (NOT `String.to_atom/1`); only previously-loaded profile modules resolve. |
| T-34-02-07 | Information Disclosure | `last_sync_error` field accidentally including `RINDLE_MUX_TOKEN_SECRET` | mitigate | Worker stores only HTTP status codes + Mux `msg` strings (no env var values touch the field); `last_sync_error` truncated to 4096 bytes per D-20. |
| T-34-02-08 | Availability | Worker compiled in adopter without `:mux` dep → crash at runtime | mitigate | Worker module wrapped in `if Code.ensure_loaded?(Mux.Video.Assets) do` (Pitfall 4 #2). Adopters without `:mux` get a no-op compile; dispatch tree surfaces `:streaming_not_configured`. |
| T-34-02-09 | Tampering | Re-perform attempts forbidden `processing → uploading` FSM edge | mitigate | `maybe_skip_already_in_progress/4` short-circuits BEFORE `transition_uploading/4` for rows in `:uploading` / `:processing` / `:ready` (B5 — `processing → uploading` is NOT in `@allowed_transitions`). |
</threat_model>

<verification>
- `mix compile --warnings-as-errors` exits 0
- `mix test test/rindle/workers/mux_ingest_variant_test.exs --max-failures 1` exits 0
- `mix test test/rindle/streaming/provider/mux/ test/rindle/workers/mux_ingest_variant_test.exs --max-failures 1` exits 0 (Plan 01 + Plan 02 together)
- `grep -c ":stale_source" lib/rindle/workers/mux_ingest_variant.ex` returns ≥ 2 (asset_changed + recipe_changed branches)
- `grep -c ":snooze" lib/rindle/workers/mux_ingest_variant.ex` returns ≥ 1 (Pitfall 3)
- `grep -v '^[[:space:]]*#' lib/rindle/workers/mux_ingest_variant.ex | grep -c "MediaProviderAsset.redact_id"` returns ≥ 1 (security invariant 14)
- `grep -c "expires_in: 1_800" lib/rindle/workers/mux_ingest_variant.ex` returns ≥ 1 (D-18, Pitfall 2)
- `grep -c "create_asset_with_retry_hint" lib/rindle/workers/mux_ingest_variant.ex` returns ≥ 1 (B7 — adapter-internal API consumed)
- `grep -v '^[[:space:]]*#' lib/rindle/workers/mux_ingest_variant.ex | grep -c '"playback_policies"'` returns 0 (B7 — PLURAL key construction lives in adapter, not worker)
- `grep -c 'args\["opts"\]' lib/rindle/workers/mux_ingest_variant.ex` returns 0 (B7 — dead read removed)
- `grep -c "playback_ids:" lib/rindle/workers/mux_ingest_variant.ex` returns ≥ 1 (B1 — PLURAL field write)
- `grep -c "playback_id:" lib/rindle/workers/mux_ingest_variant.ex` returns 0 (B1 — singular field is gone)
- `grep -c "variant_name:" lib/rindle/workers/mux_ingest_variant.ex | xargs -I{} test {} -le 0` succeeds — `variant_name:` does NOT appear in any changeset attrs map (only in Oban args, telemetry metadata, and string-keyed args reads); to validate explicitly, `grep -A 5 "MediaProviderAsset.changeset" lib/rindle/workers/mux_ingest_variant.ex | grep -c "variant_name:"` returns 0 (B2)
- `grep -E "ProviderAssetFSM\.transition\(.*,\s*\[" lib/rindle/workers/mux_ingest_variant.ex | wc -l` returns 0 (B4 — no keyword-list third arg)
- `grep -c "ProviderAssetFSM.transition" lib/rindle/workers/mux_ingest_variant.ex` returns ≥ 2 (uploading + processing transitions, both with MAP context)
- `mix test test/rindle/workers/process_variant_test.exs --max-failures 1` exits 0 (regression check — `redact_id/1` promotion did not break ProcessVariant tests)
</verification>

<success_criteria>
1. **MUX-03:** `MuxIngestVariant.perform/1` reads source via `Rindle.Delivery.url(profile, key, expires_in: 1_800)`, calls Mux via `Adapter.create_asset_with_retry_hint/3` (NOT direct ClientMock construction), persists `provider_asset_id` + `playback_ids` (PLURAL ARRAY) to `media_provider_assets`, advances FSM `pending → uploading → processing`.
2. **MUX-05 job-level:** Re-enqueueing same `(asset_id, profile, variant_name)` within 24h via `MuxIngestVariant.new(args, unique: MuxIngestVariant.unique_job_opts())` returns `conflict?: true`.
3. **MUX-05 perform-level:** Re-`perform_job` on a row already in `:uploading` / `:processing` / `:ready` returns `:ok` without re-calling the adapter and without attempting the forbidden `processing → uploading` FSM edge.
4. **MUX-06:** Atomic-promote race aborts with `{:cancel, {:stale_source, :asset_changed | :recipe_changed}}` on `storage_key` or `recipe_digest` drift; emits `[:rindle, :provider, :ingest, :exception]` with `kind: :cancelled`.
5. **Pitfall 3 (Mux SDK Issue #42):** 429 with `Retry-After: 60` → `{:snooze, 60}`; missing header → `{:snooze, 60}` (default). Adapter's `create_asset_with_retry_hint/3` extracts the value; worker translates to snooze. NO PLURAL SDK key construction in the worker.
6. **Security invariant 14:** Telemetry metadata `asset_id` redacted to last-4-char tag at every emit; regex asserted in test.
7. **Optional-dep guard:** Worker module wrapped in `if Code.ensure_loaded?(Mux.Video.Assets) do` — adopters without `:mux` do not compile dead module references.
8. **Schema fidelity:** Test setup uses real Phase 33 / Phase 33-prereq schema field names — `content_type` (NOT `mime`), `output_kind` (NOT `kind`), required `state` and `kind` fields populated.
9. **FSM contract:** Every `ProviderAssetFSM.transition/3` call in the worker passes a MAP as the third argument (per `provider_asset_fsm.ex:28` spec), never a keyword list.
10. **No regression:** `process_variant_test.exs` still passes (Plan 01's `redact_id/1` public-promotion did not break the existing Inspect impl).
</success_criteria>

<output>
After completion, create `.planning/phases/34-mux-rest-adapter-server-push-sync/34-02-SUMMARY.md` documenting:
- Worker file + test file created (line counts)
- Test pass/fail breakdown per requirement (MUX-03, MUX-05 job-level + perform-level, MUX-06, Pitfall 3, invariant 14)
- Atomic-promote race line numbers (the verbatim mirror of process_variant.ex:244-275)
- `create_asset_with_retry_hint/3` consumption confirmation (no PLURAL SDK keys in worker)
- Telemetry events emitted + redaction confirmation
- Any deviations from CONTEXT.md / RESEARCH.md (none expected)
</output>
</content>
</invoke>