defmodule Rindle.Workers.IngestProviderWebhook do
  @moduledoc """
  Oban worker driving idempotent ingest of streaming-provider webhooks.

  Enqueued by `Rindle.Delivery.WebhookPlug` after the Plug verifies the HMAC
  signature. The worker trusts upstream verification (single trust boundary
  at the Plug edge per D-19); it does NOT re-verify.

  ## Queue & retry posture (D-18, D-20)

    * Queue: `:rindle_provider` (shared with `Rindle.Workers.MuxIngestVariant`).
    * `max_attempts: 5` with default Oban exponential backoff for Repo errors.
    * `timeout/1 -> 30_000` ms.
    * Unique on the Mux event UUID (top-level `event_id` arg) for 24h
      (`states: [:scheduled, :executing, :retryable]`) — re-delivery during
      Mux outages is a no-op.

  ## Race-snooze (D-21) — divergence from sibling workers

  This is the ONLY Rindle worker that uses `{:snooze, n}`. The race window is
  data-visibility (webhook for `video.asset.ready` arrives before
  `MuxIngestVariant`'s Repo commit on the row is visible to this worker), not
  computation. Snoozes preserve the `max_attempts: 5` budget for genuine
  errors (Oban semantics: snoozed jobs do not consume `:attempt`).

    * attempt 1 → snooze 5s
    * attempt 2 → snooze 15s
    * attempt 3 → snooze 45s
    * attempt 4 → snooze 90s
    * attempt ≥ 5 → `{:cancel, :provider_asset_row_missing}`

  Cumulative budget ~155s. After cancel, the polling backstop
  (`Rindle.Workers.MuxSyncProviderAsset`, Phase 34) reconciles the row.

  ## Dispatch table (D-27)

  | Event type | FSM transition | Broadcast | Telemetry |
  |------------|----------------|-----------|-----------|
  | `video.asset.ready` | `* -> ready` | `:provider_asset_ready` | `:processed` |
  | `video.asset.errored` | `* -> errored` | `:provider_asset_errored` | `:processed` |
  | `video.asset.deleted` | `* -> deleted` | `:provider_asset_deleted` | `:processed` |
  | `video.asset.created` | `uploading -> processing` | none | `:processed` kind: :lifecycle_no_broadcast |
  | `video.upload.asset_created` | `uploading -> processing` | `:provider_asset_created` | `:processed` |
  | other | none (last_event_at bump only) | none | `:ignored` kind: :unknown_event |

  ## Telemetry (D-26 + security invariant 14)

    * `[:rindle, :provider, :webhook, :processed]` — happy path with FSM transition.
    * `[:rindle, :provider, :webhook, :ignored]` — no-op (unknown / deferred / race-snooze).
    * `[:rindle, :provider, :webhook, :exception]` — raised / FSM-rejected / race-snooze-exhausted.

  Metadata always routes `asset_id` through `MediaProviderAsset.redact_id/1`
  (security invariant 14).

  ## PubSub (D-31, D-32, D-33)

  Two-topic broadcast on `"rindle:provider_asset:#\{media_asset_id\}"` AND
  `"rindle:asset:#\{media_asset_id\}"`. Payload contract:

      {:rindle_event, event_type, %{
        asset_id, playback_ids, profile, provider, state
      }}

  `provider_asset_id` is FORBIDDEN in the payload (security invariant 14).
  """

  use Oban.Worker, queue: :rindle_provider, max_attempts: 5

  require Logger

  alias Phoenix.PubSub
  alias Rindle.Domain.{MediaProviderAsset, ProviderAssetFSM}

  # attempt -> snooze seconds (D-21).
  @snooze_curve [5, 15, 45, 90]

  @impl Oban.Worker
  def timeout(_job), do: 30_000

  @doc """
  Public unique-job opts for callers (e.g., the Plug) that build their own
  `Oban.Job.changeset` and need the same idempotency key (D-20).

  Includes `:available` in `states` because Oban inserts newly-enqueued jobs
  in `:available` state by default — without it the unique constraint never
  fires for the most common dedup case (re-delivery right after the first
  insert, before the worker picks up the job). This mirrors
  `Rindle.Workers.MuxIngestVariant.unique_job_opts/0` (Phase 34).
  """
  @spec unique_job_opts() :: keyword()
  def unique_job_opts do
    [
      fields: [:args],
      keys: [:event_id],
      states: [:available, :scheduled, :executing, :retryable],
      period: 86_400
    ]
  end

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) ::
          :ok
          | {:snooze, pos_integer()}
          | {:cancel, term()}
          | {:error, term()}
  def perform(%Oban.Job{args: args} = job) do
    repo = Rindle.Config.repo()

    provider_asset_id = get_in(args, ["event", "provider_asset_id"])
    event_type = args["event_type"]

    row =
      case lookup_row(repo, provider_asset_id) do
        nil when event_type == "video.upload.asset_created" -> lookup_passthrough_row(repo, args)
        other -> other
      end

    case row do
      nil ->
        handle_missing_row(job, args)

      row ->
        dispatch(repo, row, args)
    end
  rescue
    e ->
      emit(:exception, args, %{kind: :error, error: Exception.message(e)})
      reraise e, __STACKTRACE__
  end

  defp lookup_row(_repo, nil), do: nil

  defp lookup_row(repo, provider_asset_id) when is_binary(provider_asset_id) do
    repo.get_by(MediaProviderAsset, provider_asset_id: provider_asset_id)
  end

  defp lookup_passthrough_row(repo, args) do
    case get_in(args, ["event", "raw", "data", "passthrough"]) do
      passthrough when is_binary(passthrough) ->
        repo.get_by(MediaProviderAsset, provider_name: "mux", mux_passthrough: passthrough)

      _ ->
        nil
    end
  end

  # Race-snooze (D-21): row not visible yet → exponential backoff up to 4 attempts.
  defp handle_missing_row(%Oban.Job{attempt: attempt}, args) when attempt < 5 do
    delay = Enum.at(@snooze_curve, attempt - 1, List.last(@snooze_curve))

    emit(:ignored, args, %{
      kind: :race_snooze,
      attempt: attempt,
      delay_seconds: delay,
      from_state: nil,
      to_state: nil
    })

    {:snooze, delay}
  end

  defp handle_missing_row(_job, args) do
    emit(:exception, args, %{
      kind: :race_snooze_exhausted,
      from_state: nil,
      to_state: nil
    })

    {:cancel, :provider_asset_row_missing}
  end

  # ============================================================
  # Dispatch table (D-27).
  # ============================================================

  defp dispatch(repo, row, %{"event_type" => "video.asset.ready"} = args) do
    event = args["event"] || %{}
    playback_ids = event["playback_ids"] || []
    occurred_at = parse_datetime(event["occurred_at"])
    raw = event["raw"] || %{}

    # NB: `playback_ids` (PLURAL) is the only schema field; there is no
    # singular `playback_id` column. The plan-level "legacy single id" comment
    # was outdated — Phase 33 schema is plural-only.
    attrs = %{
      state: "ready",
      playback_ids: playback_ids,
      last_event_at: occurred_at,
      last_sync_error: nil,
      raw_provider_metadata: Map.get(raw, "data") || %{}
    }

    transition_and_broadcast(repo, row, attrs, "ready", :provider_asset_ready, args)
  end

  defp dispatch(repo, row, %{"event_type" => "video.asset.errored"} = args) do
    event = args["event"] || %{}
    raw = event["raw"] || %{}
    last_error = format_error(get_in(raw, ["data", "errors"]))
    occurred_at = parse_datetime(event["occurred_at"])

    attrs = %{
      state: "errored",
      last_event_at: occurred_at,
      last_sync_error: last_error,
      raw_provider_metadata: Map.get(raw, "data") || %{}
    }

    transition_and_broadcast(repo, row, attrs, "errored", :provider_asset_errored, args)
  end

  defp dispatch(repo, row, %{"event_type" => "video.asset.deleted"} = args) do
    event = args["event"] || %{}
    occurred_at = parse_datetime(event["occurred_at"])

    attrs = %{
      state: "deleted",
      last_event_at: occurred_at
    }

    transition_and_broadcast(repo, row, attrs, "deleted", :provider_asset_deleted, args)
  end

  defp dispatch(repo, row, %{"event_type" => "video.asset.created"} = args) do
    # FSM `:uploading -> :processing` (Mux says status: "preparing").
    # NO broadcast — upload linkage is announced by `video.upload.asset_created`.
    event = args["event"] || %{}
    occurred_at = parse_datetime(event["occurred_at"])

    attrs = %{
      state: "processing",
      last_event_at: occurred_at
    }

    case ProviderAssetFSM.transition(row.state, "processing", fsm_ctx(row)) do
      :ok ->
        case row |> MediaProviderAsset.changeset(attrs) |> repo.update() do
          {:ok, _updated} ->
            emit(:processed, args, %{
              kind: nil,
              from_state: row.state,
              to_state: "processing"
            })

            :ok

          {:error, _changeset} = err ->
            emit(:exception, args, %{
              kind: :error,
              from_state: row.state,
              to_state: "processing"
            })

            err
        end

      {:error, {:invalid_transition, from, to}} = fsm_err ->
        emit(:exception, args, %{
          kind: :invalid_transition,
          from_state: from,
          to_state: to
        })

        {:cancel, fsm_err}
    end
  end

  defp dispatch(repo, row, %{"event_type" => "video.upload.asset_created"} = args) do
    event = args["event"] || %{}
    occurred_at = parse_datetime(event["occurred_at"])
    raw = event["raw"] || %{}
    provider_asset_id = event["provider_asset_id"]

    attrs = %{
      provider_asset_id: provider_asset_id,
      last_event_at: occurred_at,
      raw_provider_metadata: Map.get(raw, "data") || %{}
    }

    cond do
      row.state == "uploading" ->
        transition_and_broadcast(
          repo,
          row,
          Map.put(attrs, :state, "processing"),
          "processing",
          :provider_asset_created,
          args
        )

      row.state in ["processing", "ready"] ->
        case row |> MediaProviderAsset.changeset(attrs) |> repo.update() do
          {:ok, updated} ->
            maybe_broadcast_linked(updated, row, provider_asset_id)

            emit(:processed, args, %{
              kind: if(row.provider_asset_id == provider_asset_id, do: :duplicate, else: nil),
              from_state: row.state,
              to_state: row.state
            })

            :ok

          {:error, _changeset} = err ->
            err
        end

      true ->
        emit(:exception, args, %{
          kind: :invalid_transition,
          from_state: row.state,
          to_state: "processing"
        })

        {:cancel, {:error, {:invalid_transition, row.state, "processing"}}}
    end
  end

  defp dispatch(repo, row, args) do
    # Unknown / out-of-table event types (D-25) — bump last_event_at, no FSM,
    # no broadcast.
    event = args["event"] || %{}
    occurred_at = parse_datetime(event["occurred_at"])

    case row |> MediaProviderAsset.changeset(%{last_event_at: occurred_at}) |> repo.update() do
      {:ok, _} ->
        emit(:ignored, args, %{
          kind: :unknown_event,
          from_state: row.state,
          to_state: row.state
        })

        :ok

      {:error, _changeset} = err ->
        err
    end
  end

  # ============================================================
  # Shared transition + broadcast helper.
  # ============================================================

  defp transition_and_broadcast(repo, row, attrs, target_state, event_type, args) do
    case ProviderAssetFSM.transition(row.state, target_state, fsm_ctx(row)) do
      :ok ->
        case row |> MediaProviderAsset.changeset(attrs) |> repo.update() do
          {:ok, updated} ->
            broadcast(updated, event_type)

            emit(:processed, args, %{
              kind: nil,
              from_state: row.state,
              to_state: target_state
            })

            :ok

          {:error, _changeset} = err ->
            emit(:exception, args, %{
              kind: :error,
              from_state: row.state,
              to_state: target_state
            })

            err
        end

      {:error, {:invalid_transition, from, to}} = fsm_err ->
        emit(:exception, args, %{
          kind: :invalid_transition,
          from_state: from,
          to_state: to
        })

        {:cancel, fsm_err}
    end
  end

  defp fsm_ctx(row) do
    %{profile: row.profile, provider: :mux, asset_id: row.asset_id}
  end

  # ============================================================
  # PubSub broadcast (D-31, D-32) — two-topic, payload omits
  # provider_asset_id (security invariant 14).
  # ============================================================

  defp broadcast(row, event_type) do
    payload = %{
      asset_id: row.asset_id,
      playback_ids: row.playback_ids || [],
      profile: row.profile,
      provider: :mux,
      state: row.state
      # NB: provider_asset_id is FORBIDDEN here (D-32).
    }

    for topic <- [
          "rindle:provider_asset:#{row.asset_id}",
          "rindle:asset:#{row.asset_id}"
        ] do
      :ok = PubSub.broadcast(pubsub_server(), topic, {:rindle_event, event_type, payload})
    end

    :ok
  end

  defp maybe_broadcast_linked(updated, original, provider_asset_id) do
    if is_binary(provider_asset_id) and provider_asset_id != original.provider_asset_id do
      broadcast(updated, :provider_asset_created)
    else
      :ok
    end
  end

  defp pubsub_server do
    Application.get_env(:rindle, :pubsub_server, Rindle.PubSub)
  end

  # ============================================================
  # Telemetry (D-26 + security invariant 14).
  # ============================================================

  defp emit(stage, args, extra) do
    provider_asset_id = get_in(args || %{}, ["event", "provider_asset_id"])

    metadata =
      %{
        provider: :mux,
        event_type: (args || %{})["event_type"],
        asset_id: MediaProviderAsset.redact_id(provider_asset_id),
        profile: get_in(args || %{}, ["event", "raw", "data", "profile"])
      }
      |> Map.merge(extra)

    :telemetry.execute(
      [:rindle, :provider, :webhook, stage],
      %{system_time: System.system_time()},
      metadata
    )
  end

  # ============================================================
  # Helpers.
  # ============================================================

  defp format_error(%{"type" => type, "messages" => messages})
       when is_binary(type) and is_list(messages) do
    "#{type}: #{Enum.join(messages, "; ")}"
  end

  defp format_error(%{"type" => type}) when is_binary(type), do: type
  defp format_error(_), do: nil

  defp parse_datetime(nil), do: nil

  defp parse_datetime(string) when is_binary(string) do
    case DateTime.from_iso8601(string) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp parse_datetime(%DateTime{} = dt), do: dt
  defp parse_datetime(_), do: nil
end
