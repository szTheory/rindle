# Compiled only when {:mux, "~> 3.2"} is loaded.
# Adopters who do not configure streaming pay zero transitive cost.
if Code.ensure_loaded?(Mux.Video.Assets) do
  defmodule Rindle.Workers.MuxSyncCoordinator do
    @moduledoc """
    Oban cron worker that fans out per-row sync jobs for `media_provider_assets`
    rows in (`processing`, `uploading`) older than `provider_polling_floor_seconds`.

    Delegates per-row work to `Rindle.Workers.MuxSyncProviderAsset`. No sync
    logic lives here. Adopters can schedule this worker from their Oban cron
    config without requiring Rindle to supervise Oban.

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

    Cron resolution is 1 minute (`Oban.Plugins.Cron` docs); the coordinator's
    internal query enforces the `provider_polling_floor_seconds: 30` floor so
    rows that were just touched by a webhook (Phase 35) are not redundantly
    polled.

    ## Job Arguments

    This worker accepts no arguments. All behavior is driven by the
    `:provider_polling_floor_seconds` config under
    `config :rindle, Rindle.Streaming.Provider.Mux`.

    ## Return Contract

      * `:ok` — fan-out completed; per-row jobs enqueued.
      * Coordinator runs with `max_attempts: 1` because a missed cron tick is
        always cheaper to skip and re-run on the next tick than to retry
        mid-fanout.

    ## Backpressure (Pitfall 6 mitigation)

    Per-row unique constraint (`unique: [period: 60, keys: [:provider_asset_id]]`)
    deduplicates within the 60s window — the second cron tick will not
    re-fan-out a still-running per-row job. Phase 34 ships unbounded scan;
    if real-world adopter feedback shows queue floods (>1k stuck rows), add
    a `LIMIT` cap in v1.7.

    ## Observability

      * `Logger.info("rindle.workers.mux_sync_coordinator.completed", ...)` —
        emitted after each fan-out with `rows_scanned`, `jobs_enqueued`, and
        `floor_seconds`. The coordinator emits no per-row telemetry — that
        responsibility lives with `Rindle.Workers.MuxSyncProviderAsset` per
        row, with redacted `asset_id` metadata.
    """

    use Oban.Worker, queue: :rindle_provider, max_attempts: 1

    require Logger
    import Ecto.Query, only: [from: 2]

    alias Rindle.Domain.MediaProviderAsset

    @default_polling_floor_seconds 30

    @spec perform(Oban.Job.t()) :: :ok
    @impl Oban.Worker
    def perform(%Oban.Job{}) do
      repo = Rindle.Config.repo()
      floor = config(:provider_polling_floor_seconds, @default_polling_floor_seconds)
      cutoff = DateTime.add(DateTime.utc_now(), -floor, :second)

      provider_asset_ids =
        repo.all(
          from r in MediaProviderAsset,
            where:
              r.state in ["processing", "uploading"] and
                r.updated_at < ^cutoff and
                not is_nil(r.provider_asset_id),
            select: r.provider_asset_id
        )

      enqueued =
        provider_asset_ids
        |> Enum.map(fn provider_asset_id ->
          %{"provider_asset_id" => provider_asset_id}
          |> Rindle.Workers.MuxSyncProviderAsset.new(
            unique: [fields: [:args, :worker], period: 60, keys: [:provider_asset_id]]
          )
          |> Oban.insert()
        end)
        |> Enum.count(&match?({:ok, _}, &1))

      Logger.info("rindle.workers.mux_sync_coordinator.completed",
        rows_scanned: length(provider_asset_ids),
        jobs_enqueued: enqueued,
        floor_seconds: floor
      )

      :ok
    end

    defp config(key, default) do
      :rindle
      |> Application.get_env(Rindle.Streaming.Provider.Mux, [])
      |> Keyword.get(key, default)
    end
  end
end
