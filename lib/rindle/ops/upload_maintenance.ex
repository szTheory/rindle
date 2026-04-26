defmodule Rindle.Ops.UploadMaintenance do
  @moduledoc """
  Shared service for upload-session maintenance operations.

  Provides two core operations:

    * `cleanup_orphans/1` — deletes expired upload sessions and their staged
      objects from storage. Supports a dry-run mode that reports planned
      actions without executing destructive side effects.

    * `abort_incomplete_uploads/1` — transitions `signed` and `uploading`
      sessions that have passed their TTL into the `expired` state so that
      a subsequent cleanup run can remove them.

  Storage side effects are intentionally kept outside DB transactions per the
  Rindle security invariant. Failures in individual storage deletes are
  accumulated and surfaced in the report rather than short-circuiting the
  entire cleanup lane.
  """

  require Logger

  import Ecto.Query

  alias Rindle.Domain.MediaUploadSession
  alias Rindle.Domain.UploadSessionFSM
  alias Rindle.Repo

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type cleanup_report :: %{
          sessions_found: non_neg_integer(),
          sessions_deleted: non_neg_integer(),
          objects_deleted: non_neg_integer(),
          storage_errors: non_neg_integer()
        }

  @type abort_report :: %{
          sessions_found: non_neg_integer(),
          sessions_aborted: non_neg_integer(),
          abort_errors: non_neg_integer()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Removes expired upload sessions and their staged objects.

  ## Options

    * `:dry_run` (boolean, default `true`) — when `true`, reports planned
      actions without deleting anything from the database or storage.
    * `:storage` (module) — storage adapter used for object deletion.
      Defaults to the global Rindle storage adapter from config.

  ## Returns

    `{:ok, cleanup_report()}` on success (even when some storage deletes fail;
    storage errors are counted in `storage_errors`).

    `{:error, reason}` when the database query itself fails.
  """
  @spec cleanup_orphans(keyword()) :: {:ok, cleanup_report()} | {:error, term()}
  def cleanup_orphans(opts \\ []) do
    dry_run? = Keyword.get(opts, :dry_run, true)
    storage_mod = Keyword.get(opts, :storage, nil)

    case fetch_expired_sessions() do
      {:ok, sessions} ->
        report = process_cleanup(sessions, dry_run?, storage_mod)
        {:ok, report}

      {:error, reason} ->
        Logger.error("rindle.upload_maintenance.cleanup_query_failed",
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  @doc """
  Transitions incomplete upload sessions that have passed their TTL to `expired`.

  Targets sessions in the `signed` or `uploading` states whose `expires_at` is
  in the past. This prepares them for removal by `cleanup_orphans/1`.

  ## Options

  Currently accepts an empty keyword list (reserved for future use).

  ## Returns

    `{:ok, abort_report()}` on success.
    `{:error, reason}` when the database query itself fails.
  """
  @spec abort_incomplete_uploads(keyword()) :: {:ok, abort_report()} | {:error, term()}
  def abort_incomplete_uploads(opts \\ []) when is_list(opts) do
    case fetch_incomplete_timed_out_sessions() do
      {:ok, sessions} ->
        report = process_abort(sessions)
        {:ok, report}

      {:error, reason} ->
        Logger.error("rindle.upload_maintenance.abort_query_failed",
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Private — query helpers
  # ---------------------------------------------------------------------------

  @spec fetch_expired_sessions() :: {:ok, [MediaUploadSession.t()]} | {:error, term()}
  defp fetch_expired_sessions do
    # The state column is the source of truth for cleanup eligibility — the
    # FSM transition into "expired" is the authoritative lifecycle decision.
    # Filtering additionally on expires_at < now would strand
    # administratively-expired sessions whose expires_at sits in the future
    # (e.g. a future cancellation feature, or a long-TTL session marked
    # expired manually by an operator).
    query =
      from(s in MediaUploadSession,
        where: s.state == "expired",
        select: s
      )

    try do
      {:ok, Repo.all(query)}
    rescue
      e -> {:error, e}
    end
  end

  @spec fetch_incomplete_timed_out_sessions() ::
          {:ok, [MediaUploadSession.t()]} | {:error, term()}
  defp fetch_incomplete_timed_out_sessions do
    now = DateTime.utc_now()

    query =
      from(s in MediaUploadSession,
        where: s.state in ["signed", "uploading"],
        where: s.expires_at < ^now,
        select: s
      )

    try do
      {:ok, Repo.all(query)}
    rescue
      e -> {:error, e}
    end
  end

  # ---------------------------------------------------------------------------
  # Private — processing logic
  # ---------------------------------------------------------------------------

  defp process_cleanup(sessions, dry_run?, storage_mod) do
    base_report = %{
      sessions_found: length(sessions),
      sessions_deleted: 0,
      objects_deleted: 0,
      storage_errors: 0
    }

    if dry_run? do
      log_dry_run_report(base_report)
      base_report
    else
      Enum.reduce(sessions, base_report, fn session, acc ->
        delete_session_and_object(session, acc, storage_mod)
      end)
    end
  end

  defp delete_session_and_object(session, acc, storage_mod) do
    # 1. Attempt storage deletion FIRST so the upload_key reference (only
    #    persisted on the session row) is preserved if storage fails. This
    #    keeps the row available for retry on the next cleanup cycle.
    case attempt_storage_delete(session, storage_mod) do
      {:ok, object_increment} ->
        # 2. Storage object is gone (or there was no adapter); now safe to
        #    drop the DB row.
        case Repo.delete(session) do
          {:ok, _} ->
            acc
            |> Map.update!(:sessions_deleted, &(&1 + 1))
            |> Map.update!(:objects_deleted, &(&1 + object_increment))

          {:error, reason} ->
            Logger.warning("rindle.upload_maintenance.session_delete_failed",
              session_id: session.id,
              reason: inspect(reason)
            )

            # Storage object was removed but the DB row stuck around. Reflect
            # the storage success in the counter so operators can correlate
            # the warning with a concrete object.
            Map.update!(acc, :objects_deleted, &(&1 + object_increment))
        end

      :storage_error ->
        # Storage delete failed transiently. Leave the DB row in place so the
        # next cron run can retry — without the row we would never find the
        # upload_key again.
        Map.update!(acc, :storage_errors, &(&1 + 1))
    end
  end

  # No storage adapter configured; skip object deletion and proceed to DB delete.
  defp attempt_storage_delete(_session, nil), do: {:ok, 0}

  defp attempt_storage_delete(session, storage_mod) do
    case storage_mod.delete(session.upload_key, []) do
      {:ok, _} ->
        {:ok, 1}

      {:error, :not_found} ->
        # Object already gone — treat as success so the DB row can be cleaned up.
        {:ok, 0}

      {:error, reason} ->
        Logger.warning("rindle.upload_maintenance.object_delete_failed",
          session_id: session.id,
          upload_key: session.upload_key,
          reason: inspect(reason)
        )

        :storage_error
    end
  end

  defp process_abort(sessions) do
    base_report = %{
      sessions_found: length(sessions),
      sessions_aborted: 0,
      abort_errors: 0
    }

    Enum.reduce(sessions, base_report, fn session, acc ->
      expire_session(session, acc)
    end)
  end

  defp expire_session(session, acc) do
    # Gate the persistence on the FSM so any future expansion of the query
    # set (e.g. expiring `uploaded`/`verifying` rows) is caught at the
    # invariant boundary instead of silently violating the FSM contract.
    case UploadSessionFSM.transition(session.state, "expired", %{session_id: session.id}) do
      :ok ->
        do_expire_session(session, acc)

      {:error, {:invalid_transition, from, to}} ->
        Logger.warning("rindle.upload_maintenance.session_expiry_invalid_transition",
          session_id: session.id,
          from_state: from,
          to_state: to
        )

        Map.update!(acc, :abort_errors, &(&1 + 1))
    end
  end

  defp do_expire_session(session, acc) do
    changeset = MediaUploadSession.changeset(session, %{state: "expired"})

    case Repo.update(changeset) do
      {:ok, _updated} ->
        Logger.info("rindle.upload_maintenance.session_expired",
          session_id: session.id,
          previous_state: session.state
        )

        Map.update!(acc, :sessions_aborted, &(&1 + 1))

      {:error, reason} ->
        Logger.warning("rindle.upload_maintenance.session_expiry_failed",
          session_id: session.id,
          reason: inspect(reason)
        )

        Map.update!(acc, :abort_errors, &(&1 + 1))
    end
  end

  # ---------------------------------------------------------------------------
  # Private — logging
  # ---------------------------------------------------------------------------

  defp log_dry_run_report(report) do
    Logger.info("rindle.upload_maintenance.cleanup_dry_run",
      sessions_found: report.sessions_found,
      dry_run: true
    )
  end
end
