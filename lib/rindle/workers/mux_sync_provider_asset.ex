# Compiled only when {:mux, "~> 3.2"} is loaded.
# Adopters who do not configure streaming pay zero transitive cost.
if Code.ensure_loaded?(Mux.Video.Assets) do
  defmodule Rindle.Workers.MuxSyncProviderAsset do
    @moduledoc """
    Per-row defensive sync for `media_provider_assets` rows that may have
    missed a webhook. Called by `Rindle.Workers.MuxSyncCoordinator` and the
    webhook-driven synchronization path.

    ## Job Arguments

        %{"provider_asset_id" => mux_asset_id}

    ## Behavior

      1. Fetch row by `provider_asset_id`.
      2. If the row is past the stuck threshold, transition to `:errored`
         with `last_sync_error: "stuck in :<state> past threshold"` and emit
         `[:rindle, :provider, :sync, :stuck]`.
      3. Otherwise, call the provider adapter's `get_asset/1` callback and
         reconcile FSM/playback_ids. Emit `[:rindle, :provider, :sync, :resolved]`.
      4. If Mux returns 404, transition to `:errored` with reason
         `"mux asset not found"` and emit `:resolved` (the row IS now reconciled
         with reality — there is no asset to wait for).

    ## Telemetry Contract

      * `[:rindle, :provider, :sync, :resolved]` — fires on every successful
        `get_asset/1` call (whether or not a state change occurred).

            measurements: %{system_time}
            metadata:     %{profile, provider, asset_id, provider_state, age_ms, no_change}

      * `[:rindle, :provider, :sync, :stuck]` — fires when the row's
        `updated_at` exceeds `:provider_stuck_threshold_seconds` (default 7200).
        Same metadata shape; `provider_state` reflects the row's final
        `:errored` state.

    `metadata.asset_id` is the redacted last-4-char tag of the
    `provider_asset_id` (security invariant 14, via
    `Rindle.Domain.MediaProviderAsset.redact_id/1`).

    ### `age_ms` semantics across `:resolved` and `:stuck`

    `metadata.age_ms` is ALWAYS "time since the row's `updated_at`", never
    "time since the last sync attempt". Because a no-op `:resolved` event
    (live state already matches the row — see `metadata.no_change: true`)
    performs no DB write, `updated_at` is unchanged and `age_ms` keeps growing
    while syncs are succeeding. The same metric therefore carries two
    operational semantics depending on the event/branch:

      * `:resolved` with `no_change: false` — a transition just happened, so
        `age_ms` measures the age of the row *before* this sync resolved it.
      * `:resolved` with `no_change: true` — nothing changed, so `age_ms`
        reflects "time since the last actual state change", which legitimately
        balloons even though sync is healthy. Dashboards MUST gate on
        `no_change` (or use `:stuck`) before treating a large `age_ms` as a
        liveness problem.
      * `:stuck` — `age_ms` IS the threshold-driving liveness metric (the row
        exceeded `:provider_stuck_threshold_seconds`).

    Filter `:resolved` events by `no_change` before alerting on `age_ms`; the
    `:stuck` event is the canonical staleness signal.
    """

    use Oban.Worker, queue: :rindle_provider, max_attempts: 3

    alias Rindle.Domain.{MediaProviderAsset, ProviderAssetFSM}
    import Ecto.Query

    @default_stuck_threshold_seconds 7200

    @spec perform(Oban.Job.t()) :: :ok | {:error, term()}
    @impl Oban.Worker
    def perform(%Oban.Job{args: %{"provider_asset_id" => provider_asset_id}})
        when is_binary(provider_asset_id) do
      repo = Rindle.Config.repo()

      case repo.get_by(MediaProviderAsset, provider_asset_id: provider_asset_id) do
        nil ->
          # Row was deleted between coordinator scan and per-row execution.
          :ok

        row ->
          if stuck?(row) do
            mark_stuck(repo, row)
          else
            sync_with_provider(repo, row)
          end
      end
    end

    # ============================================================
    # Stuck-threshold check + transition to :errored
    # ============================================================

    defp stuck?(row) do
      threshold = config(:provider_stuck_threshold_seconds, @default_stuck_threshold_seconds)
      age = age_seconds(row.updated_at)
      row.state in ["processing", "uploading"] and age > threshold
    end

    # Schema `timestamps()` produces `:naive_datetime` by default; coerce to a
    # DateTime in UTC so `DateTime.diff/3` accepts it. Adopters may run with
    # `:utc_datetime` columns too — handle both shapes safely.
    defp age_seconds(%DateTime{} = ts), do: DateTime.diff(DateTime.utc_now(), ts, :second)

    defp age_seconds(%NaiveDateTime{} = ts) do
      DateTime.diff(DateTime.utc_now(), DateTime.from_naive!(ts, "Etc/UTC"), :second)
    end

    defp age_ms(%DateTime{} = ts), do: DateTime.diff(DateTime.utc_now(), ts, :millisecond)

    defp age_ms(%NaiveDateTime{} = ts) do
      DateTime.diff(DateTime.utc_now(), DateTime.from_naive!(ts, "Etc/UTC"), :millisecond)
    end

    defp mark_stuck(repo, snapshot) do
      with_current_snapshot(repo, snapshot, fn row ->
        change_state(
          repo,
          row,
          "errored",
          %{last_sync_error: "stuck in :#{row.state} past threshold"},
          :stuck
        )
      end)
    end

    defp sync_with_provider(repo, snapshot) do
      # Keep network I/O outside the lock. The response belongs to this exact
      # snapshot, not whichever row happens to exist when the request finishes.
      response = Rindle.Streaming.Provider.Mux.get_asset(snapshot.provider_asset_id)

      with_current_snapshot(repo, snapshot, fn row ->
        case response do
          {:ok, %{state: live_state, playback_ids: pids, raw: _raw}} ->
            apply_state_transition(repo, row, live_state, pids)

          {:error, :not_found} ->
            change_state(
              repo,
              row,
              "errored",
              %{last_sync_error: "mux asset not found"},
              :resolved
            )

          {:error, reason} ->
            case row
                 |> MediaProviderAsset.changeset(%{
                   last_sync_error: inspect(reason) |> String.slice(0, 4096)
                 })
                 |> repo.update() do
              {:ok, _} -> {:remote_error, reason}
              {:error, changeset} -> repo.rollback(changeset)
            end
        end
      end)
    end

    defp apply_state_transition(repo, row, live_state, playback_ids) do
      if live_state == row.state do
        {:sync, :resolved, row, row, true}
      else
        if live_state in Map.get(ProviderAssetFSM.allowed_transitions(), row.state, []) do
          change_state(repo, row, live_state, %{playback_ids: playback_ids}, :resolved)
        else
          change_state(
            repo,
            row,
            "errored",
            %{last_sync_error: "live state #{live_state} not reachable from #{row.state}"},
            :resolved
          )
        end
      end
    end

    defp change_state(repo, row, state, attrs, stage) do
      context = %{
        profile: String.to_existing_atom(row.profile),
        provider: :mux,
        asset_id: row.asset_id,
        emit?: false
      }

      with :ok <- ProviderAssetFSM.transition(row.state, state, context) do
        case row
             |> MediaProviderAsset.changeset(Map.put(attrs, :state, state))
             |> repo.update() do
          {:ok, updated} -> {:sync, stage, row, updated, false}
          {:error, changeset} -> repo.rollback(changeset)
        end
      end
    end

    defp with_current_snapshot(repo, snapshot, fun) do
      result =
        repo.transaction(fn ->
          current =
            repo.one(
              from p in MediaProviderAsset, where: p.id == ^snapshot.id, lock: "FOR UPDATE"
            )

          if current && snapshot_identity(current) == snapshot_identity(snapshot),
            do: fun.(current),
            else: :stale
        end)

      case result do
        {:ok, {:sync, stage, original, updated, no_change}} ->
          profile = String.to_existing_atom(updated.profile)

          if original.state != updated.state do
            :telemetry.execute(
              [:rindle, :provider_asset, :state_change],
              %{system_time: System.system_time()},
              %{
                profile: profile,
                provider: :mux,
                asset_id: updated.asset_id,
                from: original.state,
                to: updated.state
              }
            )
          end

          emit_sync_event(stage, updated, profile, no_change: no_change)
          :ok

        {:ok, :stale} ->
          :ok

        {:ok, {:remote_error, reason}} ->
          {:error, reason}

        {:ok, other} ->
          other

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp snapshot_identity(row) do
      # updated_at has second precision; an accepted webhook within that second
      # is still a different snapshot, including when its timestamp is absent.
      Map.take(row, [
        :id,
        :asset_id,
        :profile,
        :provider_name,
        :provider_asset_id,
        :updated_at,
        :state,
        :playback_ids,
        :last_event_at,
        :last_event_id,
        :last_sync_error,
        :raw_provider_metadata
      ])
    end

    # ============================================================
    # Telemetry — security invariant 14 redaction at every emit.
    # ============================================================

    defp emit_sync_event(stage, row, profile, opts) do
      :telemetry.execute(
        [:rindle, :provider, :sync, stage],
        %{system_time: System.system_time()},
        %{
          profile: profile,
          provider: :mux,
          asset_id: MediaProviderAsset.redact_id(row.provider_asset_id),
          provider_state: row.state,
          age_ms: age_ms(row.updated_at),
          no_change: Keyword.get(opts, :no_change, false)
        }
      )
    end

    defp config(key, default) do
      :rindle
      |> Application.get_env(Rindle.Streaming.Provider.Mux, [])
      |> Keyword.get(key, default)
    end
  end
end
