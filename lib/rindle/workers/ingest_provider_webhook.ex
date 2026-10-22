defmodule Rindle.Workers.IngestProviderWebhook do
  @moduledoc """
  Oban worker driving idempotent ingest of streaming-provider webhooks.

  Enqueued by `Rindle.Delivery.WebhookPlug` after the Plug verifies the HMAC
  signature. The worker trusts that single edge boundary and does not re-verify.

  ## Queue and retry posture

    * Queue: `:rindle_provider` (shared with `Rindle.Workers.MuxIngestVariant`).
    * `max_attempts: 5` with default Oban exponential backoff for Repo errors.
    * `timeout/1 -> 30_000` ms.
    * Unique on the Mux event UUID (top-level `event_id` arg) for 24h
      (`states: [:scheduled, :executing, :retryable]`) — re-delivery during
      Mux outages is a no-op.

  ## Race snooze

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
  (`Rindle.Workers.MuxSyncProviderAsset`) reconciles the row.

  ## Dispatch table

  | Event type | FSM transition | Broadcast | Telemetry |
  |------------|----------------|-----------|-----------|
  | `video.asset.ready` | `* -> ready` | `:provider_asset_ready` | `:processed` |
  | `video.asset.errored` | `* -> errored` | `:provider_asset_errored` | `:processed` |
  | `video.asset.deleted` | `* -> deleted` | `:provider_asset_deleted` | `:processed` |
  | `video.asset.created` | `uploading -> processing` | none | `:processed` kind: :lifecycle_no_broadcast |
  | `video.upload.asset_created` | `uploading -> processing` | `:provider_asset_created` | `:processed` |
  | other | none (last_event_at bump only) | none | `:ignored` kind: :unknown_event |

  ## Telemetry

    * `[:rindle, :provider, :webhook, :processed]` — happy path with FSM transition.
    * `[:rindle, :provider, :webhook, :ignored]` — no-op (unknown / deferred / race-snooze).
    * `[:rindle, :provider, :webhook, :exception]` — raised / FSM-rejected / race-snooze-exhausted.

  Metadata always routes `asset_id` through `MediaProviderAsset.redact_id/1`
  (security invariant 14).

  ## PubSub

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
  import Ecto.Query
  alias Rindle.Domain.{MediaProviderAsset, ProviderAssetFSM}

  # attempt -> snooze seconds
  @snooze_curve [5, 15, 45, 90]

  @impl Oban.Worker
  def timeout(_job), do: 30_000

  @doc """
  Public unique-job opts for callers (e.g., the Plug) that build their own
  `Oban.Job.changeset` and need the same idempotency key.

  Includes `:available` in `states` because Oban inserts newly-enqueued jobs
  in `:available` state by default — without it the unique constraint never
  fires for the most common dedup case (re-delivery right after the first
  insert, before the worker picks up the job). This mirrors
  `Rindle.Workers.MuxIngestVariant.unique_job_opts/0`.
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

    result = repo.transaction(fn -> accept_locked_event(repo, args) end)

    case result do
      {:ok, :missing} ->
        handle_missing_row(job, args)

      {:ok, {:ignored, row, kind}} ->
        emit(:ignored, args, %{
          kind: kind,
          from_state: row.state,
          to_state: row.state,
          profile: row.profile
        })

        :ok

      {:ok, {:accepted, original, updated, event_type, transitioned, stage, kind}} ->
        if transitioned, do: emit_state_change(original, updated)
        if event_type, do: broadcast(updated, event_type)

        emit(stage, args, %{
          kind: kind,
          from_state: original.state,
          to_state: updated.state,
          profile: updated.profile
        })

        :ok

      {:ok, other} ->
        other

      {:error, reason} ->
        emit(:exception, args, %{kind: :error})
        {:error, reason}
    end
  rescue
    e ->
      emit(:exception, args, %{kind: :error, error: "provider_update_failed"})
      reraise e, __STACKTRACE__
  end

  defp accept_locked_event(repo, args) do
    case event_row(repo, args) do
      nil -> :missing
      row -> accept_current_event(repo, row, args)
    end
  end

  defp event_row(repo, args) do
    case lookup_row(repo, get_in(args, ["event", "provider_asset_id"])) do
      nil -> passthrough_event_row(repo, args)
      row -> row
    end
  end

  defp passthrough_event_row(repo, %{"event_type" => "video.upload.asset_created"} = args),
    do: lookup_passthrough_row(repo, args)

  defp passthrough_event_row(_repo, _args), do: nil

  defp accept_current_event(repo, row, args) do
    cond do
      is_binary(args["event_id"]) and args["event_id"] == row.last_event_id ->
        {:ignored, row, :duplicate}

      older_event?(row, args) ->
        {:ignored, row, nil}

      true ->
        dispatch(repo, row, args)
    end
  end

  defp lookup_row(_repo, nil), do: nil

  defp lookup_row(repo, provider_asset_id) when is_binary(provider_asset_id) do
    repo.one(
      from p in MediaProviderAsset,
        where: p.provider_asset_id == ^provider_asset_id,
        lock: "FOR UPDATE"
    )
  end

  defp lookup_passthrough_row(repo, args) do
    case get_in(args, ["event", "raw", "data", "passthrough"]) do
      passthrough when is_binary(passthrough) ->
        repo.one(
          from p in MediaProviderAsset,
            where: p.provider_name == "mux" and p.mux_passthrough == ^passthrough,
            lock: "FOR UPDATE"
        )

      _ ->
        nil
    end
  end

  defp older_event?(row, args) do
    case {row.last_event_at, parse_datetime(get_in(args, ["event", "occurred_at"]))} do
      {%DateTime{} = known, %DateTime{} = incoming} -> DateTime.compare(incoming, known) == :lt
      _ -> false
    end
  end

  # The provider row may commit just after webhook enqueue; retry that bounded race.
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

  # Each event keeps its existing FSM and payload semantics. The caller holds
  # the row lock across freshness, validation, watermark and persistence.
  defp dispatch(repo, row, %{"event_type" => "video.asset.ready"} = args) do
    event = args["event"] || %{}

    attrs = %{
      state: "ready",
      playback_ids: event["playback_ids"] || [],
      last_sync_error: nil,
      raw_provider_metadata: get_in(event, ["raw", "data"]) || %{}
    }

    transition_and_broadcast(repo, row, attrs, "ready", :provider_asset_ready, args)
  end

  defp dispatch(repo, row, %{"event_type" => "video.asset.errored"} = args) do
    event = args["event"] || %{}

    attrs = %{
      state: "errored",
      last_sync_error: format_error(get_in(event, ["raw", "data", "errors"])),
      raw_provider_metadata: get_in(event, ["raw", "data"]) || %{}
    }

    transition_and_broadcast(repo, row, attrs, "errored", :provider_asset_errored, args)
  end

  defp dispatch(repo, row, %{"event_type" => "video.asset.deleted"} = args) do
    transition_and_broadcast(
      repo,
      row,
      %{state: "deleted"},
      "deleted",
      :provider_asset_deleted,
      args
    )
  end

  defp dispatch(repo, row, %{"event_type" => "video.asset.created"} = args) do
    transition_and_broadcast(repo, row, %{state: "processing"}, "processing", nil, args)
  end

  defp dispatch(repo, row, %{"event_type" => "video.upload.asset_created"} = args) do
    event = args["event"] || %{}

    attrs = %{
      provider_asset_id: event["provider_asset_id"],
      raw_provider_metadata: get_in(event, ["raw", "data"]) || %{}
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
        linked =
          is_binary(event["provider_asset_id"]) and
            row.provider_asset_id != event["provider_asset_id"]

        event_type = if linked, do: :provider_asset_created
        kind = if row.provider_asset_id == event["provider_asset_id"], do: :duplicate
        persist_event(repo, row, attrs, args, event_type, false, :processed, kind)

      true ->
        reject_transition(row, "processing", args)
    end
  end

  defp dispatch(repo, row, args) do
    persist_event(repo, row, %{}, args, nil, false, :ignored, :unknown_event)
  end

  defp transition_and_broadcast(repo, row, attrs, target_state, event_type, args) do
    case ProviderAssetFSM.transition(
           row.state,
           target_state,
           Map.put(fsm_ctx(row), :emit?, false)
         ) do
      :ok -> persist_event(repo, row, attrs, args, event_type, true, :processed, nil)
      {:error, _} -> reject_transition(row, target_state, args)
    end
  end

  defp reject_transition(row, target_state, args) do
    emit(:exception, args, %{
      kind: :invalid_transition,
      from_state: row.state,
      to_state: target_state
    })

    {:cancel, {:error, {:invalid_transition, row.state, target_state}}}
  end

  defp persist_event(repo, row, attrs, args, event_type, transitioned, stage, kind) do
    incoming = parse_datetime(get_in(args, ["event", "occurred_at"]))
    # Equal and undated events follow serialized FSM order; a known watermark
    # survives them. No timestamp/ID total order is invented.
    watermark = incoming || row.last_event_at

    attrs =
      Map.merge(attrs, %{
        last_event_at: watermark,
        last_event_id: args["event_id"] || row.last_event_id
      })

    case row |> MediaProviderAsset.changeset(attrs) |> repo.update() do
      {:ok, updated} -> {:accepted, row, updated, event_type, transitioned, stage, kind}
      {:error, changeset} -> repo.rollback(changeset)
    end
  end

  defp fsm_ctx(row), do: %{profile: row.profile, provider: :mux, asset_id: row.asset_id}

  defp emit_state_change(original, updated) do
    :telemetry.execute(
      [:rindle, :provider_asset, :state_change],
      %{system_time: System.system_time()},
      Map.merge(fsm_ctx(updated), %{from: original.state, to: updated.state})
    )
  end

  # ============================================================
  # Broadcast on both ownership topics; the payload omits
  # provider_asset_id (security invariant 14).
  # ============================================================

  defp broadcast(row, event_type) do
    payload = %{
      asset_id: row.asset_id,
      playback_ids: row.playback_ids || [],
      profile: row.profile,
      provider: :mux,
      state: row.state
      # Provider asset IDs are deliberately omitted from the public payload.
    }

    for topic <- [
          "rindle:provider_asset:#{row.asset_id}",
          "rindle:asset:#{row.asset_id}"
        ] do
      :ok = PubSub.broadcast(pubsub_server(), topic, {:rindle_event, event_type, payload})
    end

    :ok
  end

  defp pubsub_server do
    Application.get_env(:rindle, :pubsub_server, Rindle.PubSub)
  end

  # ============================================================
  # Telemetry metadata excludes provider asset IDs and raw provider payloads.
  # ============================================================

  defp emit(stage, args, extra) do
    provider_asset_id = get_in(args || %{}, ["event", "provider_asset_id"])

    metadata =
      %{
        provider: :mux,
        event_type: (args || %{})["event_type"],
        asset_id: MediaProviderAsset.redact_id(provider_asset_id),
        profile: nil
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
      {:ok, dt, _} ->
        dt

      _ ->
        case Integer.parse(string) do
          {seconds, ""} -> parse_datetime(seconds)
          _ -> nil
        end
    end
  end

  defp parse_datetime(seconds) when is_integer(seconds) do
    case DateTime.from_unix(seconds) do
      {:ok, dt} -> dt
      _ -> nil
    end
  end

  defp parse_datetime(%DateTime{} = dt), do: dt
  defp parse_datetime(_), do: nil
end
