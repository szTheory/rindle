# Compiled only when {:mux, "~> 3.2"} is loaded.
# Adopters who do not configure streaming pay zero transitive cost.
if Code.ensure_loaded?(Mux.Video.Assets) do
  defmodule Rindle.Workers.MuxSyncProviderAsset do
    @moduledoc false
    # Per-row defensive sync for `media_provider_assets` rows that may have
    # missed a webhook. Called by `Rindle.Workers.MuxSyncCoordinator`.
    #
    # Plan 04 promotes this to a documented `@moduledoc`; for Phase 34 wave 2
    # this worker is only invoked from the coordinator (internal contract).
    #
    # Behavior:
    #   1. Fetch row by `provider_asset_id`.
    #   2. If the row is past the stuck threshold, transition to `:errored`
    #      with `last_sync_error: "stuck in :<state> past threshold"` and emit
    #      `[:rindle, :provider, :sync, :stuck]`.
    #   3. Otherwise, call `Rindle.Streaming.Provider.Mux.get_asset/1` and
    #      reconcile FSM/playback_ids. Emit `[:rindle, :provider, :sync, :resolved]`.
    #   4. If Mux returns 404, transition to `:errored` with reason
    #      `"mux asset not found"` and emit `:resolved`.
    #
    # Telemetry metadata always carries the redacted `asset_id` per security
    # invariant 14 (`Rindle.Domain.MediaProviderAsset.redact_id/1`).

    use Oban.Worker, queue: :rindle_provider, max_attempts: 3

    alias Rindle.Domain.{MediaProviderAsset, ProviderAssetFSM}

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

    defp mark_stuck(repo, row) do
      reason = "stuck in :#{row.state} past threshold"
      profile_atom = String.to_existing_atom(row.profile)

      # B4 fix: third arg is a MAP, not a keyword list (provider_asset_fsm.ex:28).
      with :ok <-
             ProviderAssetFSM.transition(row.state, "errored", %{
               profile: profile_atom,
               provider: :mux,
               asset_id: row.asset_id
             }),
           {:ok, updated} <-
             row
             |> MediaProviderAsset.changeset(%{state: "errored", last_sync_error: reason})
             |> repo.update() do
        emit_sync_event(:stuck, updated, profile_atom)
        :ok
      end
    end

    # ============================================================
    # Per-row sync against live Mux state
    # ============================================================

    defp sync_with_provider(repo, row) do
      adapter = Rindle.Streaming.Provider.Mux

      case adapter.get_asset(row.provider_asset_id) do
        {:ok, %{state: live_state, playback_ids: pids, raw: _raw}} ->
          apply_state_transition(repo, row, live_state, pids)

        {:error, :not_found} ->
          # Mux deleted the asset; transition to :errored.
          profile_atom = String.to_existing_atom(row.profile)

          # B4 fix: third arg is a MAP.
          with :ok <-
                 ProviderAssetFSM.transition(row.state, "errored", %{
                   profile: profile_atom,
                   provider: :mux,
                   asset_id: row.asset_id
                 }),
               {:ok, updated} <-
                 row
                 |> MediaProviderAsset.changeset(%{
                   state: "errored",
                   last_sync_error: "mux asset not found"
                 })
                 |> repo.update() do
            emit_sync_event(:resolved, updated, profile_atom)
            :ok
          end

        {:error, reason} ->
          {:error, reason}
      end
    end

    # B1 fix: persist `playback_ids` (PLURAL ARRAY) — schema field is
    # `field :playback_ids, {:array, :string}`. Write the list verbatim.
    defp apply_state_transition(repo, row, live_state, playback_ids) do
      profile_atom = String.to_existing_atom(row.profile)

      cond do
        live_state == row.state ->
          # No transition needed; just emit :resolved with current state.
          emit_sync_event(:resolved, row, profile_atom)
          :ok

        true ->
          # Always persist the live PLURAL playback_ids list (default to []
          # if Mux returned no ids — schema default is [] so this is safe).
          attrs = %{
            state: live_state,
            playback_ids: playback_ids || []
          }

          # B4 fix: third arg is a MAP.
          with :ok <-
                 ProviderAssetFSM.transition(row.state, live_state, %{
                   profile: profile_atom,
                   provider: :mux,
                   asset_id: row.asset_id
                 }),
               {:ok, updated} <-
                 row |> MediaProviderAsset.changeset(attrs) |> repo.update() do
            emit_sync_event(:resolved, updated, profile_atom)
            :ok
          end
      end
    end

    # ============================================================
    # Telemetry — security invariant 14 redaction at every emit.
    # ============================================================

    defp emit_sync_event(stage, row, profile) do
      :telemetry.execute(
        [:rindle, :provider, :sync, stage],
        %{system_time: System.system_time()},
        %{
          profile: profile,
          provider: :mux,
          asset_id: MediaProviderAsset.redact_id(row.provider_asset_id),
          provider_state: row.state,
          age_ms: age_ms(row.updated_at)
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
