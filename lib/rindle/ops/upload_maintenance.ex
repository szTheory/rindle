defmodule Rindle.Ops.UploadMaintenance do
  @moduledoc false

  require Logger

  import Ecto.Query

  alias Rindle.Config
  alias Rindle.Domain.MediaUploadSession
  alias Rindle.Domain.UploadSessionFSM
  alias Rindle.Storage.Capabilities
  alias Rindle.Storage.S3

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type cleanup_report :: %{
          sessions_found: non_neg_integer(),
          sessions_deleted: non_neg_integer(),
          objects_deleted: non_neg_integer(),
          storage_errors: non_neg_integer(),
          storage_skipped: non_neg_integer(),
          resumable_skipped: non_neg_integer()
        }

  @type abort_report :: %{
          sessions_found: non_neg_integer(),
          sessions_aborted: non_neg_integer(),
          abort_errors: non_neg_integer(),
          resumable_aborts: non_neg_integer(),
          multipart_aborts: non_neg_integer(),
          presigned_put_aborts: non_neg_integer()
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
    storage_mod = Keyword.get(opts, :storage, Application.get_env(:rindle, :default_storage))

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
    case fetch_abortable_sessions() do
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
    repo = Config.repo()

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
      {:ok, repo.all(query)}
    rescue
      e -> {:error, e}
    end
  end

  @spec fetch_incomplete_timed_out_sessions() ::
          {:ok, [MediaUploadSession.t()]} | {:error, term()}
  defp fetch_incomplete_timed_out_sessions do
    repo = Config.repo()
    now = DateTime.utc_now()

    query =
      from(s in MediaUploadSession,
        where:
          s.state in ["signed", "uploading"] or
            (s.state == "resuming" and s.upload_strategy == "resumable") or
            (s.state == "initialized" and s.upload_strategy == "multipart" and
               not is_nil(s.multipart_upload_id)),
        where: s.expires_at < ^now,
        select: s
      )

    try do
      {:ok, repo.all(query)}
    rescue
      e -> {:error, e}
    end
  end

  @spec fetch_retryable_abort_sessions() :: {:ok, [MediaUploadSession.t()]} | {:error, term()}
  defp fetch_retryable_abort_sessions do
    repo = Config.repo()

    query =
      from(s in MediaUploadSession,
        where: s.state == "aborted",
        where: s.upload_strategy == "resumable",
        where: not is_nil(s.session_uri),
        where: like(s.failure_reason, "resumable_cancel_failed:%"),
        select: s
      )

    try do
      {:ok, repo.all(query)}
    rescue
      e -> {:error, e}
    end
  end

  # CR-01 (reaper half): re-select aborted tus sessions whose DELETE-time backing
  # abort failed transiently. The tus DELETE handler stamps a retryable
  # `tus_abort_failed:<reason>` marker on the row (instead of silently swallowing
  # the abort error), leaving the row in state="aborted" with the orphaned S3
  # multipart still live. This query makes that row re-discoverable so the next
  # cron re-aborts the multipart — ZERO permanent orphan (mirrors the GCS
  # `fetch_retryable_abort_sessions/0` marker pattern). The marker predicate must
  # match byte-for-byte the string the Plug writes (`tus_abort_failed:`).
  @spec fetch_retryable_tus_abort_sessions() ::
          {:ok, [MediaUploadSession.t()]} | {:error, term()}
  defp fetch_retryable_tus_abort_sessions do
    repo = Config.repo()

    query =
      from(s in MediaUploadSession,
        where: s.state == "aborted",
        where: s.resumable_protocol == "tus",
        where: not is_nil(s.multipart_upload_id),
        where: like(s.failure_reason, "tus_abort_failed:%"),
        select: s
      )

    try do
      {:ok, repo.all(query)}
    rescue
      e -> {:error, e}
    end
  end

  @spec fetch_abortable_sessions() :: {:ok, [MediaUploadSession.t()]} | {:error, term()}
  defp fetch_abortable_sessions do
    with {:ok, timed_out_sessions} <- fetch_incomplete_timed_out_sessions(),
         {:ok, retryable_sessions} <- fetch_retryable_abort_sessions(),
         {:ok, retryable_tus_sessions} <- fetch_retryable_tus_abort_sessions() do
      sessions =
        (timed_out_sessions ++ retryable_sessions ++ retryable_tus_sessions)
        |> Enum.uniq_by(& &1.id)

      {:ok, sessions}
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
      storage_errors: 0,
      storage_skipped: 0,
      resumable_skipped: 0
    }

    cond do
      dry_run? ->
        report = Enum.reduce(sessions, base_report, &preview_cleanup/2)
        log_dry_run_report(report)
        report

      is_nil(storage_mod) and sessions != [] ->
        sessions
        |> Enum.reduce(base_report, fn session, acc ->
          case resumable_cleanup_action(session) do
            :skip ->
              Map.update!(acc, :resumable_skipped, &(&1 + 1))

            :delete ->
              Map.update!(acc, :storage_skipped, &(&1 + 1))
          end
        end)
        |> maybe_warn_storage_adapter_missing(storage_mod)

      true ->
        sessions
        |> Enum.reduce(base_report, fn session, acc ->
          delete_session_and_object(session, acc, storage_mod)
        end)
        |> maybe_warn_storage_adapter_missing(storage_mod)
    end
  end

  defp preview_cleanup(session, acc) do
    case resumable_cleanup_action(session) do
      :skip ->
        Map.update!(acc, :resumable_skipped, &(&1 + 1))

      :delete ->
        acc
    end
  end

  defp delete_session_and_object(session, acc, storage_mod) do
    case resumable_cleanup_action(session) do
      :skip ->
        Map.update!(acc, :resumable_skipped, &(&1 + 1))

      :delete ->
        do_delete_session_and_object(session, acc, storage_mod)
    end
  end

  defp do_delete_session_and_object(session, acc, storage_mod) do
    # 1. Attempt storage deletion FIRST so the upload_key reference (only
    #    persisted on the session row) is preserved if storage fails. This
    #    keeps the row available for retry on the next cleanup cycle.
    case attempt_storage_delete(session, storage_mod) do
      {:ok, object_increment} ->
        proceed_with_db_delete(session, acc, object_increment, _skipped_increment = 0)

      {:skipped, skipped_increment} ->
        # Storage adapter is missing — increment the bypass counter so the
        # report surfaces the misconfiguration, then still delete the DB row
        # so the cleanup lane is not blocked indefinitely.
        proceed_with_db_delete(session, acc, _object_increment = 0, skipped_increment)

      :storage_error ->
        # Storage delete failed transiently. Leave the DB row in place so the
        # next cron run can retry — without the row we would never find the
        # upload_key again.
        Map.update!(acc, :storage_errors, &(&1 + 1))
    end
  end

  defp resumable_cleanup_action(%MediaUploadSession{
         upload_strategy: "resumable",
         state: "expired",
         session_uri: session_uri
       }) do
    if is_nil(session_uri), do: :delete, else: :skip
  end

  defp resumable_cleanup_action(_session), do: :delete

  defp maybe_warn_storage_adapter_missing(report, storage_mod)
       when is_nil(storage_mod) and report.storage_skipped > 0 do
    Logger.warning("rindle.upload_maintenance.storage_adapter_missing",
      sessions_to_clean: report.storage_skipped,
      remediation:
        "Configure :rindle :default_storage or pass --storage MODULE; cleanup is skipped so upload handles remain retryable."
    )

    report
  end

  defp maybe_warn_storage_adapter_missing(report, _storage_mod), do: report

  defp proceed_with_db_delete(session, acc, object_increment, skipped_increment) do
    repo = Config.repo()

    case repo.delete(session) do
      {:ok, _} ->
        acc
        |> Map.update!(:sessions_deleted, &(&1 + 1))
        |> Map.update!(:objects_deleted, &(&1 + object_increment))
        |> Map.update!(:storage_skipped, &(&1 + skipped_increment))

      {:error, reason} ->
        Logger.warning("rindle.upload_maintenance.session_delete_failed",
          session_id: session.id,
          reason: inspect(reason)
        )

        acc
        |> Map.update!(:objects_deleted, &(&1 + object_increment))
        |> Map.update!(:storage_skipped, &(&1 + skipped_increment))
    end
  end

  # No storage adapter configured; skip object deletion (the report surfaces
  # this via storage_skipped) and proceed to the DB delete.
  defp attempt_storage_delete(_session, nil), do: {:skipped, 1}

  # Remote storage cleanup stays outside DB transactions so multipart abort
  # retries do not hold database locks or hide network I/O in persistence work.
  defp attempt_storage_delete(
         %MediaUploadSession{
           upload_strategy: "multipart",
           multipart_upload_id: multipart_upload_id
         } = session,
         storage_mod
       )
       when is_binary(multipart_upload_id) and multipart_upload_id != "" do
    case storage_mod.abort_multipart_upload(session.upload_key, multipart_upload_id, []) do
      {:ok, _} ->
        {:ok, 1}

      {:error, :not_found} ->
        {:ok, 0}

      {:error, reason} ->
        Logger.warning("rindle.upload_maintenance.multipart_abort_failed",
          session_id: session.id,
          upload_key: session.upload_key,
          multipart_upload_id: multipart_upload_id,
          reason: inspect(reason)
        )

        :storage_error
    end
  end

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
      abort_errors: 0,
      resumable_aborts: 0,
      multipart_aborts: 0,
      presigned_put_aborts: 0
    }

    Enum.reduce(sessions, base_report, fn session, acc ->
      expire_session(session, acc)
    end)
  end

  defp expire_session(session, acc) do
    # Order is load-bearing (TUS-09 / Pitfall 1): tus sessions are
    # `upload_strategy: "resumable"` and would otherwise be swallowed by
    # `resumable_abort_session?/1` and mis-routed to the GCS session-URI cancel
    # path (which fails the `:resumable_upload_session` capability gate for
    # S3/Local), leaving the S3 multipart upload orphaned (cost leak). Branch on
    # `resumable_protocol: "tus"` FIRST so tus sessions abort the S3 multipart
    # (or remove the Local tmp) before the resumable check.
    cond do
      tus_session?(session) ->
        expire_tus_session(session, acc)

      resumable_abort_session?(session) ->
        expire_resumable_session(session, acc)

      true ->
        expire_standard_session(session, acc)
    end
  end

  defp tus_session?(%MediaUploadSession{
         upload_strategy: "resumable",
         resumable_protocol: "tus"
       }),
       do: true

  defp tus_session?(_session), do: false

  defp expire_standard_session(session, acc) do
    gated_expire(session, acc)
  end

  # Shared gated-expire helper used by BOTH the standard and tus expiry branches
  # (WR-01). Gate the persistence on the FSM so any future expansion of the query
  # set (e.g. expiring `uploaded`/`verifying` rows, or surfacing a tus session in
  # an `aborted`/forbidden state via the retryable-abort query) is caught at the
  # invariant boundary instead of silently violating the FSM contract.
  defp gated_expire(session, acc) do
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

  defp expire_resumable_session(session, acc) do
    case attempt_resumable_cancel(session) do
      {:ok, attrs} ->
        persist_resumable_abort_success(session, acc, attrs)

      {:error, failure_reason} ->
        persist_resumable_abort_failure(session, acc, failure_reason)
    end
  end

  # TUS-09: reap a tus session. Abort the S3 multipart upload (or remove the
  # Local tmp part/tail) idempotently FIRST, then persist `state: "expired"`.
  # On a backing-abort failure the row is left in place (increment
  # `:abort_errors`) so the next cron run retries — one failing session never
  # aborts the reduce over the batch (T-43-07).
  defp expire_tus_session(session, acc) do
    case abort_tus_backing(session) do
      :ok ->
        settle_tus_abort_success(session, acc)

      {:error, reason} ->
        Logger.warning("rindle.upload_maintenance.tus_abort_failed",
          session_id: session.id,
          multipart_upload_id: session.multipart_upload_id,
          reason: inspect(reason)
        )

        # CR-01: a DELETE-time-failure retry row stays state="aborted" with its
        # `tus_abort_failed:%` marker intact so the NEXT cron re-selects it (still
        # recoverable — never a new permanent orphan). The timeout-expiry path
        # likewise leaves its row untouched on failure for the next cron.
        Map.update!(acc, :abort_errors, &(&1 + 1))
    end
  end

  # WR-03 reconciliation. The FSM declares `"aborted" => []` (terminal), so a tus
  # session re-selected from the DELETE-time-failure retry query (already in
  # state "aborted" with a `tus_abort_failed:%` marker) MUST NOT be routed back
  # through `gated_expire/2` — that would attempt the FSM-forbidden
  # `aborted -> expired`, log an invalid transition, increment `abort_errors`,
  # and re-select the row forever (a silent infinite retry). On a successful (or
  # idempotent `:not_found`) re-abort, settle such a row via a dedicated persist
  # that mirrors `persist_resumable_abort_success/3` — clearing the marker and
  # bypassing the FSM gate — exactly how the GCS retryable path settles `aborted`
  # rows without an illegal transition. The timeout-expiry path (non-terminal
  # state) keeps the FSM-gated `gated_expire/2` call (WR-01).
  defp settle_tus_abort_success(
         %MediaUploadSession{state: "aborted", failure_reason: failure_reason} = session,
         acc
       )
       when is_binary(failure_reason) do
    if String.starts_with?(failure_reason, "tus_abort_failed:") do
      persist_tus_abort_retry_success(session, acc)
    else
      # Not a tus DELETE-failure retry marker (e.g. a GCS
      # `resumable_cancel_failed:%` marker surfaced by the other query). Preserve
      # the FSM-gated behavior so an FSM-forbidden aborted->expired is rejected
      # (WR-01 invariant boundary), never silently settled.
      gated_expire(session, acc)
    end
  end

  defp settle_tus_abort_success(session, acc) do
    # WR-01: gate the tus timeout-expiry persistence through the SAME FSM-gated
    # helper the standard branch uses, so a future query-set expansion can never
    # silently flip a tus session from an FSM-forbidden state.
    gated_expire(session, acc)
  end

  # Mirrors `persist_resumable_abort_success/3`: settle a recovered aborted-tus
  # row directly through the repo (NOT the FSM gate) to `state: "expired"` with
  # the retryable marker cleared, so it is no longer re-selected by
  # `fetch_retryable_tus_abort_sessions/0`.
  defp persist_tus_abort_retry_success(session, acc) do
    repo = Config.repo()
    changeset = MediaUploadSession.changeset(session, %{state: "expired", failure_reason: nil})

    case repo.update(changeset) do
      {:ok, _updated} ->
        Logger.info("rindle.upload_maintenance.tus_abort_retry_settled",
          session_id: session.id,
          previous_state: session.state
        )

        acc
        |> Map.update!(:sessions_aborted, &(&1 + 1))
        |> increment_abort_strategy(session)

      {:error, reason} ->
        Logger.warning("rindle.upload_maintenance.tus_abort_retry_persist_failed",
          session_id: session.id,
          reason: inspect(reason)
        )

        Map.update!(acc, :abort_errors, &(&1 + 1))
    end
  end

  # S3-backed tus session: abort the multipart upload via the resolved adapter.
  # `{:error, :not_found}` is treated as idempotent success (the upload was
  # already aborted/completed). The 5 MiB tail buffer the PATCH lane spills to
  # `<Rindle.tmp>/tus/<session_id>.tail` is removed best-effort regardless.
  defp abort_tus_backing(%MediaUploadSession{multipart_upload_id: id} = session)
       when is_binary(id) and id != "" do
    case resolve_tus_adapter(session) do
      {:ok, adapter} ->
        # The S3 tail buffer lives under the adapter's default tail root
        # (`TempRunDir.root_dir()`); thread it explicitly so the delete path
        # computes against the SAME root the write path used (CR-02).
        abort_tus_backing(session, adapter: adapter, root: nil, upload_id: id)

      {:error, _reason} = err ->
        # Still best-effort remove the local tail even if the adapter cannot be
        # resolved, then surface the error so the row is retried next cron.
        remove_tus_tail(session, nil)
        err
    end
  end

  # Local-backed tus session (no multipart_upload_id): resolve the upload's
  # ACTUAL Local root (IN-03) and remove the tmp part + tail at that root.
  defp abort_tus_backing(%MediaUploadSession{} = session) do
    root = resolve_local_root(session)
    abort_tus_backing(session, adapter: nil, root: root, upload_id: nil)
  end

  @doc """
  Aborts the backing store for a tus upload session, polymorphically.

  `opts` is a keyword list carrying:

    * `:adapter` — the resolved storage adapter (S3-backed only)
    * `:root` — the Local/tmp root the part/tail files live under (`nil`
      falls back to the adapter's default tail root)
    * `:upload_id` — the S3 multipart upload id (present => S3 multipart abort)

  When an S3 multipart `:upload_id` is present, aborts the multipart upload via
  the adapter (`{:error, :not_found}` is treated as idempotent success). The
  per-session tail buffer (and, for the Local case, the tmp part file) at
  `:root` is always best-effort removed.

  This is the SAME polymorphic abort the reaper performs from a session-resolved
  adapter/root, exposed as a PUBLIC reusable helper so the tus DELETE handler can
  invoke it with an explicit adapter/root it already holds — avoiding a DB
  profile re-resolution on the hot DELETE path.
  """
  @spec abort_tus_backing(MediaUploadSession.t(), keyword()) :: :ok | {:error, term()}
  def abort_tus_backing(%MediaUploadSession{} = session, opts) when is_list(opts) do
    root = Keyword.get(opts, :root)
    upload_id = Keyword.get(opts, :upload_id)

    # Best-effort remove the per-session tail buffer at the resolved root.
    remove_tus_tail(session, root)

    case upload_id do
      id when is_binary(id) and id != "" ->
        adapter = Keyword.fetch!(opts, :adapter)

        case adapter.abort_multipart_upload(session.upload_key, id, []) do
          {:ok, _} -> :ok
          # Idempotent: the multipart upload is already gone.
          {:error, :not_found} -> :ok
          {:error, _reason} = err -> err
        end

      _ ->
        # Local-backed (no multipart upload id): remove the tmp part file at the
        # SAME resolved root the write path used (IN-03). The orphan reaper
        # sweeps `Rindle.tmp` anyway, so failures here are non-fatal.
        _ = File.rm(Rindle.Storage.Local.tus_part_path(session.id, root_opt(root)))
        :ok
    end
  end

  @doc """
  Removes the per-session tus tail buffer at `root`.

  Delegates the path computation to `Rindle.Storage.S3.tus_tail_path/2` — the
  adapter's OWN canonical (base64url-encoded) tail-path source of truth (CR-02) —
  threading `root` so the delete path computes against the SAME root the write
  path used. When `root` is `nil` the adapter's default tail root
  (`Rindle.AV.TempRunDir.root_dir()`) is used. Best-effort: always returns `:ok`.
  """
  @spec remove_tus_tail(MediaUploadSession.t(), Path.t() | nil) :: :ok
  def remove_tus_tail(%MediaUploadSession{id: session_id}, root) do
    tail_path = S3.tus_tail_path(session_id, root_opt(root))
    _ = File.rm(tail_path)
    :ok
  end

  # Build a keyword opts list carrying `:root` only when it is non-nil so the
  # adapter's own default-root resolution kicks in for the `nil` case.
  defp root_opt(nil), do: []
  defp root_opt(root), do: [root: root]

  # Resolve the Local root for a Local-backed tus session (IN-03). The Local
  # adapter owns its own root resolution (`Local.root/1` reads the profile/
  # app-env `:root` config); resolving it here and threading it explicitly into
  # `tus_part_path/2` removes the previous bare empty-opts call that left the
  # part file at a mismatched root. There is no remote backing to abort for a
  # Local session, so no adapter/capability probe is needed.
  defp resolve_local_root(_session) do
    Rindle.Storage.Local.root([])
  end

  # Mirrors `resolve_resumable_adapter/1` but is intended for the tus
  # (`:tus_upload`) backing capability rather than the GCS-native
  # `:resumable_upload_session` lifecycle capability. The capability is probed
  # for intent/observability only — the abort itself is NOT hard-gated on it,
  # because failing to abort here is the exact cost-leak TUS-09 closes
  # (T-43-cost-leak). If the profile/adapter cannot be resolved at all we
  # surface the error so the row is retried next cron.
  defp resolve_tus_adapter(session) do
    repo = Config.repo()
    asset = repo.preload(session, :asset).asset

    with %{profile: profile_name} when is_binary(profile_name) <- asset,
         {:ok, profile_module} <- profile_name_to_module(profile_name),
         adapter when is_atom(adapter) <- profile_module.storage_adapter() do
      maybe_warn_tus_capability(adapter)
      {:ok, adapter}
    else
      nil -> {:error, :asset_missing}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_profile_value}
    end
  end

  defp maybe_warn_tus_capability(adapter) do
    case Capabilities.require_upload(adapter, :tus_upload) do
      :ok ->
        :ok

      {:error, {:upload_unsupported, :tus_upload}} ->
        # Defensive only: still abort the backing so the multipart is reaped.
        Logger.debug("rindle.upload_maintenance.tus_adapter_capability_unadvertised",
          adapter: inspect(adapter)
        )

        :ok
    end
  end

  defp do_expire_session(session, acc) do
    repo = Config.repo()
    changeset = MediaUploadSession.changeset(session, %{state: "expired"})

    case repo.update(changeset) do
      {:ok, _updated} ->
        Logger.info("rindle.upload_maintenance.session_expired",
          session_id: session.id,
          previous_state: session.state
        )

        acc
        |> Map.update!(:sessions_aborted, &(&1 + 1))
        |> increment_abort_strategy(session)

      {:error, reason} ->
        Logger.warning("rindle.upload_maintenance.session_expiry_failed",
          session_id: session.id,
          reason: inspect(reason)
        )

        Map.update!(acc, :abort_errors, &(&1 + 1))
    end
  end

  defp attempt_resumable_cancel(%MediaUploadSession{session_uri: nil}) do
    {:ok, %{state: "expired", session_uri: nil, failure_reason: nil}}
  end

  defp attempt_resumable_cancel(%MediaUploadSession{} = session) do
    with {:ok, adapter} <- resolve_resumable_adapter(session),
         {:ok, _result} <-
           adapter.cancel_resumable_upload(session.upload_key, session.session_uri, []) do
      {:ok, %{state: "expired", session_uri: nil, failure_reason: nil}}
    else
      {:error, :session_uri_unknown} ->
        {:ok, %{state: "expired", session_uri: nil, failure_reason: nil}}

      {:error, :session_uri_expired} ->
        {:ok, %{state: "expired", session_uri: nil, failure_reason: nil}}

      {:error, reason} ->
        {:error, resumable_failure_reason(reason)}
    end
  end

  defp persist_resumable_abort_success(session, acc, attrs) do
    repo = Config.repo()
    changeset = MediaUploadSession.changeset(session, attrs)

    case repo.update(changeset) do
      {:ok, _updated} ->
        Logger.info("rindle.upload_maintenance.resumable_session_expired",
          session_id: session.id,
          previous_state: session.state
        )

        acc
        |> Map.update!(:sessions_aborted, &(&1 + 1))
        |> increment_abort_strategy(session)

      {:error, reason} ->
        Logger.warning("rindle.upload_maintenance.resumable_session_expiry_failed",
          session_id: session.id,
          reason: inspect(reason)
        )

        Map.update!(acc, :abort_errors, &(&1 + 1))
    end
  end

  defp persist_resumable_abort_failure(session, acc, failure_reason) do
    repo = Config.repo()

    changeset =
      MediaUploadSession.changeset(session, %{
        state: "aborted",
        failure_reason: failure_reason
      })

    case repo.update(changeset) do
      {:ok, _updated} ->
        Logger.warning("rindle.upload_maintenance.resumable_cancel_failed",
          session_id: session.id,
          failure_reason: failure_reason
        )

        Map.update!(acc, :abort_errors, &(&1 + 1))

      {:error, reason} ->
        Logger.warning("rindle.upload_maintenance.resumable_failure_persist_failed",
          session_id: session.id,
          reason: inspect(reason)
        )

        Map.update!(acc, :abort_errors, &(&1 + 1))
    end
  end

  defp resolve_resumable_adapter(session) do
    repo = Config.repo()
    asset = repo.preload(session, :asset).asset

    with %{profile: profile_name} when is_binary(profile_name) <- asset,
         {:ok, profile_module} <- profile_name_to_module(profile_name),
         adapter <- profile_module.storage_adapter(),
         :ok <- Capabilities.require_upload(adapter, :resumable_upload_session) do
      {:ok, adapter}
    else
      nil -> {:error, :asset_missing}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_profile_value}
    end
  end

  defp resumable_failure_reason(:goth_unconfigured),
    do: "resumable_cancel_failed:goth_unconfigured"

  defp resumable_failure_reason({:gcs_http_error, %{status: status}})
       when is_integer(status) and status in 400..499,
       do: "resumable_cancel_failed:gcs_http_4xx"

  defp resumable_failure_reason({:gcs_http_error, %{status: status}})
       when is_integer(status) and status >= 500,
       do: "resumable_cancel_failed:gcs_http_5xx"

  defp resumable_failure_reason(_reason), do: "resumable_cancel_failed:transport"

  # tus sessions are reaped by `expire_tus_session/2` (the `tus_session?/1`
  # branch of `expire_session/2`). Exclude them here so a future expansion of
  # the abortable-session query can never double-route a tus session into the
  # GCS-native session-URI cancel lane.
  defp resumable_abort_session?(%MediaUploadSession{resumable_protocol: "tus"}), do: false

  defp resumable_abort_session?(%MediaUploadSession{upload_strategy: "resumable", state: state})
       when state in ["signed", "resuming", "uploading", "aborted"],
       do: true

  defp resumable_abort_session?(_session), do: false

  defp increment_abort_strategy(acc, %MediaUploadSession{upload_strategy: "resumable"}) do
    Map.update!(acc, :resumable_aborts, &(&1 + 1))
  end

  defp increment_abort_strategy(acc, %MediaUploadSession{upload_strategy: "multipart"}) do
    Map.update!(acc, :multipart_aborts, &(&1 + 1))
  end

  defp increment_abort_strategy(acc, _session) do
    Map.update!(acc, :presigned_put_aborts, &(&1 + 1))
  end

  defp profile_name_to_module(name) do
    {:ok, String.to_existing_atom(name)}
  rescue
    ArgumentError -> {:error, :unknown_profile}
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
