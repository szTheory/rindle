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

    ## Telemetry — kind metadata

    `[:rindle, :provider, :ingest, :exception]` events carry an additional
    `metadata.kind` key:

      * `:cancelled` — atomic-promote race aborted the job (`{:cancel, ...}`)
      * `:error` — a genuine failure (`{:error, _}`)

    Adopters can route the two cases differently in their handlers.
    """

    use Oban.Worker, queue: :rindle_provider, max_attempts: 5

    require Logger

    alias Rindle.Domain.{MediaAsset, MediaVariant, MediaProviderAsset, ProviderAssetFSM}
    alias Rindle.Streaming.Provider.Mux, as: Adapter

    @impl Oban.Worker
    def timeout(_job), do: :timer.minutes(5)

    @impl Oban.Worker
    @spec perform(Oban.Job.t()) ::
            :ok
            | {:error, term()}
            | {:snooze, non_neg_integer()}
            | {:cancel, term()}
    def perform(%Oban.Job{args: args}) do
      repo = Rindle.Config.repo()
      start_time = System.monotonic_time()
      profile_mod = String.to_existing_atom(args["profile"])

      emit_event(
        :start,
        %{system_time: System.system_time()},
        base_metadata(profile_mod, args["variant_name"], nil)
      )

      with {:ok, asset, variant} <- fetch_source(repo, args),
           :ok <- check_freshness(asset, variant, args),
           {:ok, row} <- ensure_pending_row(repo, args, asset),
           {:cont, _row} <- maybe_skip_already_in_progress(row, profile_mod, args, start_time),
           {:ok, signed_url} <-
             Rindle.Delivery.url(profile_mod, variant.storage_key, expires_in: 1_800),
           :ok <- transition_uploading(repo, row, profile_mod, asset),
           {:ok, mux_response} <- call_mux_create(profile_mod, signed_url),
           {:ok, persisted} <-
             persist_provider_processing(repo, args, mux_response, profile_mod) do
        emit_event(
          :stop,
          %{
            system_time: System.system_time(),
            duration: System.monotonic_time() - start_time
          },
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

          emit_event(
            :stop,
            %{
              system_time: System.system_time(),
              duration: System.monotonic_time() - start_time
            },
            base_metadata(profile_mod, args["variant_name"], nil)
          )

          :ok

        {:halt, {:cancel, reason}} ->
          # BL-02 fix: row is in a terminal state for ingest (`:errored` or
          # `:deleted`). The FSM forbids errored→uploading, so attempting to
          # transition would burn `max_attempts: 5` retries with no useful
          # state change. Return `{:cancel, _}` so Oban stops retrying;
          # operators reset the row out-of-band before re-ingest.
          emit_event(
            :exception,
            %{
              system_time: System.system_time(),
              duration: System.monotonic_time() - start_time
            },
            base_metadata(profile_mod, args["variant_name"], nil)
            |> Map.put(:kind, :cancelled)
          )

          {:cancel, reason}

        {:cancel, {:stale_source, _why} = reason} ->
          emit_event(
            :exception,
            %{
              system_time: System.system_time(),
              duration: System.monotonic_time() - start_time
            },
            base_metadata(profile_mod, args["variant_name"], nil)
            |> Map.put(:kind, :cancelled)
          )

          {:cancel, reason}

        {:snooze, _} = snooze ->
          snooze

        {:error, reason} = err ->
          emit_event(
            :exception,
            %{
              system_time: System.system_time(),
              duration: System.monotonic_time() - start_time
            },
            base_metadata(profile_mod, args["variant_name"], nil)
            |> Map.put(:kind, :error)
            |> Map.put(:reason, reason)
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

    Includes `:available` in `states` because Oban inserts newly-enqueued
    jobs in `:available` state by default — without it the unique constraint
    never fires for the most common dedup case (re-enqueue right after the
    first insert, before the worker picks up the job).
    """
    @spec unique_job_opts() :: keyword()
    def unique_job_opts do
      [
        fields: [:args, :worker, :queue],
        keys: [:asset_id, :profile, :variant_name],
        states: [:available, :scheduled, :executing, :retryable, :completed],
        period: 86_400
      ]
    end

    # ============================================================
    # Source fetch + freshness (atomic-promote race — mirrors
    # process_variant.ex:244-275 verbatim with arg-shape swap).
    # ============================================================

    defp fetch_source(repo, args) do
      case repo.get(MediaAsset, args["asset_id"]) do
        nil ->
          {:error, :not_found}

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
    #
    # BL-02 fix: treat `:errored` and `:deleted` as terminal for THIS worker
    # path. The FSM only allows `errored → processing | deleted` (NOT
    # `errored → uploading`), so falling through to transition_uploading/4
    # would burn `max_attempts: 5` retries with `{:invalid_transition,
    # "errored", "uploading"}` on every attempt. Returning `{:cancel, _}`
    # signals Oban to stop retrying — operators who want to re-ingest an
    # `:errored` row must reset it explicitly via a maintenance task that
    # walks `errored → processing` (or by deleting the row). The reason
    # tuple carries `last_sync_error` so dashboards can surface why we
    # stopped.
    defp maybe_skip_already_in_progress(row, _profile, _args, _start_time) do
      case row.state do
        "pending" ->
          {:cont, row}

        state when state in ["uploading", "processing", "ready"] ->
          {:halt, :already_in_progress}

        "errored" ->
          {:halt, {:cancel, {:provider_asset_errored, row.last_sync_error}}}

        "deleted" ->
          {:halt, {:cancel, :provider_asset_deleted}}
      end
    end

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

    # B1 fix: persist `playback_ids` (PLURAL ARRAY), not singular `playback_id`.
    # Phase 33 schema field is `field :playback_ids, {:array, :string}`.
    #
    # BL-01 fix: when the post-create freshness re-check rejects the promotion,
    # the Mux asset was already created (and is billed). We MUST best-effort
    # delete it before returning `{:cancel, _}` to avoid a billing/lifecycle
    # leak. `Adapter.delete_asset/1` is idempotent on 404 (mux.ex:246).
    defp persist_provider_processing(repo, args, mux_response, profile_mod) do
      # Atomic-promote: re-fetch source rows just before flipping to processing.
      # Mirrors process_variant.ex:244-275 with arg-shape swap.
      current_asset = repo.get!(MediaAsset, args["asset_id"])

      current_variant =
        repo.get_by!(MediaVariant,
          asset_id: args["asset_id"],
          name: args["variant_name"]
        )

      cond do
        current_asset.storage_key != args["expected_storage_key"] ->
          compensate_delete_mux_asset(mux_response, :asset_changed)
          {:cancel, {:stale_source, :asset_changed}}

        current_variant.recipe_digest != args["expected_recipe_digest"] ->
          compensate_delete_mux_asset(mux_response, :recipe_changed)
          {:cancel, {:stale_source, :recipe_changed}}

        true ->
          row =
            repo.get_by!(MediaProviderAsset,
              asset_id: args["asset_id"],
              profile: args["profile"],
              provider_name: "mux"
            )

          # B1 fix: write the PLURAL array verbatim.
          attrs = %{
            provider_asset_id: mux_response.provider_asset_id,
            playback_ids: mux_response.playback_ids,
            state: "processing",
            raw_provider_metadata: %{}
          }

          # B4 fix: third arg is a MAP.
          with :ok <-
                 ProviderAssetFSM.transition(row.state, "processing", %{
                   profile: profile_mod,
                   provider: :mux,
                   asset_id: args["asset_id"]
                 }),
               {:ok, persisted} <-
                 row
                 |> MediaProviderAsset.changeset(attrs)
                 |> repo.update() do
            {:ok, persisted}
          end
      end
    end

    # BL-01 compensating delete: best-effort idempotent cleanup of the Mux
    # asset created at line 114 when the post-create freshness re-check
    # rejects the promotion. Result is intentionally discarded — failure to
    # delete is logged but does not change the {:cancel, _} return value
    # (the row is already in :uploading and the sync coordinator will reap
    # it on the next pass). The adapter absorbs 404 to :ok so a double-fire
    # is safe.
    defp compensate_delete_mux_asset(%{provider_asset_id: provider_asset_id}, reason)
         when is_binary(provider_asset_id) do
      case Adapter.delete_asset(provider_asset_id) do
        :ok ->
          Logger.debug("rindle.workers.mux_ingest_variant.compensating_delete",
            asset_id: MediaProviderAsset.redact_id(provider_asset_id),
            reason: reason
          )

          :ok

        {:error, err_reason} ->
          # Best-effort: log + drop. The sync coordinator's stuck-threshold
          # path provides eventual consistency for the row state; the Mux
          # asset itself remains as cleanup debt the operator can reconcile
          # via a Mux dashboard sweep.
          Logger.warning("rindle.workers.mux_ingest_variant.compensating_delete_failed",
            asset_id: MediaProviderAsset.redact_id(provider_asset_id),
            reason: reason,
            error: inspect(err_reason)
          )

          {:error, err_reason}

        {:error, err_reason, _env} ->
          Logger.warning("rindle.workers.mux_ingest_variant.compensating_delete_failed",
            asset_id: MediaProviderAsset.redact_id(provider_asset_id),
            reason: reason,
            error: inspect(err_reason)
          )

          {:error, err_reason}
      end
    end

    defp compensate_delete_mux_asset(_mux_response, _reason), do: :ok

    # ============================================================
    # Adapter call — routed through `create_asset_with_retry_hint/3`.
    # PLURAL SDK key construction lives ONLY in the adapter (Plan 01);
    # NEVER duplicated here. (B7 fix.)
    # ============================================================

    defp call_mux_create(profile_mod, signed_url) do
      # Phase 34 default policy is :signed (capability `[:signed_playback, ...]`).
      # Profile-level overrides happen at the adapter layer, not the worker.
      #
      # Phase 36 CR-01: when the soak install-smoke lane sets
      # `RINDLE_MUX_PASSTHROUGH_TAG=rindle_soak`, the adapter stamps the
      # `passthrough` field on the create-asset request so the layer-3
      # cleanup script (`scripts/mux_soak_cleanup.sh`) can filter on a
      # tag that is actually written. Unset in normal production runs —
      # `nil` → adapter omits the key.
      opts = [playback_policy: :signed]

      opts =
        case System.get_env("RINDLE_MUX_PASSTHROUGH_TAG") do
          nil -> opts
          "" -> opts
          tag when is_binary(tag) -> Keyword.put(opts, :passthrough, tag)
        end

      case Adapter.create_asset_with_retry_hint(profile_mod, signed_url, opts) do
        {:ok, %{provider_asset_id: _, playback_ids: _} = ok} ->
          {:ok, ok}

        # Pitfall 3 / SDK Issue #42: 429 surfaces with parsed Retry-After.
        {:error, :provider_quota_exceeded, retry_after}
        when is_integer(retry_after) and retry_after > 0 ->
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
