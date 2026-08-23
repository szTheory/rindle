defmodule Rindle.Upload.TusPlug do
  @tus_extensions "creation,expiration,termination,checksum,creation-defer-length,concatenation"

  @moduledoc """
  Bare, mountable [tus 1.0](https://tus.io/protocols/resumable-upload) protocol
  edge over the v1.7 resumable-session substrate.

  `TusPlug` is a `@behaviour Plug` (`init/1` + `call/2`) — it adds **no Phoenix
  dependency**. Mount it under your own auth pipeline via `forward`, in either a
  Phoenix Router:

      forward "/uploads/tus", Rindle.Upload.TusPlug,
        profile: MyApp.VideoProfile,
        secret_key_base:
          Application.compile_env!(:my_app, MyAppWeb.Endpoint)[:secret_key_base]

  or a `Plug.Router`:

      forward "/uploads/tus",
        to: Rindle.Upload.TusPlug,
        init_opts: [profile: MyApp.VideoProfile, secret_key_base: secret]

  ## Scope

  Implements tus **Core + Creation + Expiration + Termination + Checksum +
  Creation-Defer-Length + Concatenation** extensions. The advertised
  `Tus-Extension` header matches runtime:
  `#{@tus_extensions}`.

  Backing is **local and S3** tus paths — both are shipped in this module.

  | Method | Status | Notes |
  |--------|--------|-------|
  | `OPTIONS` | 204 | advertises `Tus-Version`/`Tus-Resumable`/`Tus-Extension`/`Tus-Max-Size` |
  | `POST` | 201 | Creation — `Upload-Length` + opaque `Upload-Metadata` → signed `Location` |
  | `HEAD` | 204 | authoritative `Upload-Offset` + `Cache-Control: no-store` |
  | `PATCH` | implemented | resumable write |
  | `DELETE` | implemented | Termination |
  | other | 405 | not a tus method |

  ## Security

  Every tus URL is HMAC-signed via `Plug.Crypto.sign/4` against the adopter's
  `secret_key_base` (salt `"rindle:tus:url"`); the signed token is the **final
  path segment** of the URL (`Location: <mount>/<token>`), resolved from
  `conn.path_info` after `forward` strips the mount prefix. The token is verified
  on every `HEAD`/`PATCH`/`DELETE`; a missing, tampered, or expired signature
  returns `404`/`401`, never `200`. The signed URL is persisted only into the
  redacting `session_uri` column and never appears in logs/telemetry/`inspect`.

  Mounting against a storage adapter that does not advertise the `:tus_upload`
  capability raises `ArgumentError` at `init/1` — a deploy-time failure, never a
  silent downgrade.

  ## Deployment constraint (S3 tus backing)

  When the mounted profile's storage adapter is S3-backed, the sub-5-MiB tail
  remainder of each PATCH is buffered on **node-local disk**, while the
  authoritative cross-PATCH bookkeeping (offset, multipart upload id, committed
  parts) lives in the **shared DB**. Because the tail buffer is node-local, the
  S3 tus backing REQUIRES single-node or sticky-session routing: a resumed PATCH
  MUST be routed to the **same node** that holds the in-progress tail buffer
  (node-affinity).

  A cross-node resume — where the DB shows a mid-multipart upload but the tail
  file is absent on the node that received the PATCH — is detected by the S3
  adapter and **fails loudly** with `{:error, :tus_tail_missing}` (surfaced as a
  `5xx`) rather than silently re-slicing from a fresh empty tail, which would
  corrupt the assembled object. Multi-node operators MUST pin tus PATCHes to a
  single node (sticky sessions / node-affinity) or accept this loud failure on
  misrouted resumes. This is a documented v1 constraint; shared-storage tail
  persistence is deferred.
  """

  @behaviour Plug

  import Plug.Conn

  alias Phoenix.PubSub
  alias Rindle.Config
  alias Rindle.Domain.MediaUploadSession
  alias Rindle.Storage.Capabilities

  alias Rindle.Upload.{
    Broker,
    ResumableTelemetry,
    TusCreation,
    TusProtocol,
    TusStream,
    TusTermination
  }

  @tus_version "1.0.0"
  # Conservative adopter-overridable default (5 GiB). The only adopter-facing
  # size knob; the PATCH read-loop constants below stay fixed (D-07).
  @default_max_size 5 * 1024 * 1024 * 1024

  @type create_upload_result ::
          {:ok,
           %{
             session: MediaUploadSession.t(),
             upload_url: String.t(),
             expires_at: DateTime.t()
           }}
          | {:error, term()}

  @impl true
  def init(opts) do
    profile = Keyword.fetch!(opts, :profile)
    secret_key_base = Keyword.fetch!(opts, :secret_key_base)
    max_size = Keyword.get(opts, :max_size, @default_max_size)
    identity_fn = Keyword.get(opts, :identity_fn, &__MODULE__.default_actor/1)
    resume_authorizer = validate_resume_authorizer!(Config.tus_resume_authorizer())
    adapter = profile.storage_adapter()

    case Capabilities.require_upload(adapter, :tus_upload) do
      :ok ->
        :ok

      {:error, {:upload_unsupported, :tus_upload}} ->
        raise ArgumentError,
              "Rindle.Upload.TusPlug requires the profile's storage adapter to advertise " <>
                ":tus_upload; #{inspect(adapter)} does not (no silent downgrade)"
    end

    root = if function_exported?(adapter, :root, 1), do: adapter.root(opts), else: nil

    [
      profile: profile,
      adapter: adapter,
      secret_key_base: secret_key_base,
      max_size: max_size,
      identity_fn: identity_fn,
      resume_authorizer: resume_authorizer,
      root: root
    ]
  end

  @impl true
  def call(%Plug.Conn{method: "OPTIONS"} = conn, opts), do: handle_options(conn, opts)
  def call(%Plug.Conn{method: "POST"} = conn, opts), do: handle_post(conn, opts)
  def call(%Plug.Conn{method: "HEAD"} = conn, opts), do: handle_head(conn, opts)
  # Phoenix's default Plug.Head rewrites HEAD to GET before a forwarded Plug
  # sees the request. Preserve resumable discovery by honoring that shape when
  # the tus protocol header is still present.
  def call(%Plug.Conn{method: "GET"} = conn, opts) do
    if get_req_header(conn, "tus-resumable") != [] do
      handle_head(conn, opts)
    else
      method_not_allowed(conn)
    end
  end

  def call(%Plug.Conn{method: "PATCH"} = conn, opts), do: handle_patch(conn, opts)
  def call(%Plug.Conn{method: "DELETE"} = conn, opts), do: handle_delete(conn, opts)

  def call(conn, _opts), do: method_not_allowed(conn)

  @doc false
  @spec create_upload(module(), keyword()) :: create_upload_result()
  def create_upload(profile, opts) when is_atom(profile) and is_list(opts) do
    with path when is_binary(path) <- Keyword.fetch!(opts, :path),
         secret_key_base when is_binary(secret_key_base) <-
           Keyword.fetch!(opts, :secret_key_base),
         {:ok, length} <- TusProtocol.normalize_length(Keyword.get(opts, :length)) do
      actor = Keyword.get(opts, :actor, "anonymous")
      content_type = Keyword.get(opts, :content_type)

      TusCreation.create(path, profile,
        filename: Keyword.get(opts, :filename, "unknown"),
        expires_in: Keyword.get(opts, :expires_in, 3600),
        secret_key_base: secret_key_base,
        actor: actor,
        content_type: content_type,
        length: length
      )
    else
      _ -> {:error, :invalid_length}
    end
  end

  defp method_not_allowed(conn) do
    conn
    |> put_tus_resumable()
    |> send_resp(405, "method not allowed")
    |> halt()
  end

  # ── OPTIONS (capability advertisement) ──────────────────────────────────────

  defp handle_options(conn, opts) do
    conn
    |> put_resp_header("tus-version", @tus_version)
    |> put_resp_header("tus-resumable", @tus_version)
    |> put_resp_header("tus-extension", @tus_extensions)
    |> put_resp_header("tus-max-size", Integer.to_string(opts[:max_size]))
    |> put_resp_header("tus-checksum-algorithm", "sha1,sha256")
    |> send_resp(204, "")
    |> halt()
  end

  # ── POST (Creation — HMAC-sign the URL, bind to a tus session) ───────────────

  defp handle_post(conn, opts) do
    content_type = TusProtocol.metadata_content_type(conn)
    concat_header = get_req_header(conn, "upload-concat") |> List.first()

    cond do
      concat_header && String.starts_with?(concat_header, "final;") ->
        handle_concat_final(conn, concat_header, opts)

      true ->
        is_partial = concat_header == "partial"

        with {:ok, length} <- TusProtocol.parse_upload_length(conn),
             :ok <- TusProtocol.check_max_size(length, opts[:max_size]),
             {:ok, %{session: session, upload_url: location}} <-
               TusCreation.create(TusProtocol.location_base(conn), opts[:profile],
                 filename: "unknown",
                 expires_in: 3600,
                 secret_key_base: opts[:secret_key_base],
                 actor: opts[:identity_fn].(conn),
                 content_type: content_type,
                 length: length,
                 is_partial: is_partial
               ) do
          conn
          |> put_tus_resumable()
          |> put_resp_header("location", location)
          |> put_resp_header("upload-expires", TusProtocol.http_date(session.expires_at))
          |> send_resp(201, "")
          |> halt()
        else
          {:error, :invalid_length} -> tus_error(conn, 400, "invalid Upload-Length")
          {:error, :too_large} -> tus_error(conn, 413, "Upload-Length exceeds Tus-Max-Size")
          {:error, _reason} -> tus_error(conn, 400, "upload creation failed")
        end
    end
  end

  defp handle_concat_final(conn, concat_header, opts) do
    "final;" <> urls_string = concat_header
    urls = String.split(urls_string, " ", trim: true)

    with {:ok, %{session: signed_session, upload_url: upload_url}} <-
           TusCreation.concatenate(
             TusProtocol.location_base(conn),
             opts[:profile],
             urls,
             opts
             |> Keyword.put(:secret_key_base, opts[:secret_key_base])
             |> Keyword.put(:actor, opts[:identity_fn].(conn))
             |> Keyword.put(:content_type, TusProtocol.metadata_content_type(conn))
           ) do
      conn
      |> put_tus_resumable()
      |> put_resp_header("location", upload_url)
      |> put_resp_header("upload-expires", TusProtocol.http_date(signed_session.expires_at))
      |> send_resp(201, "")
      |> halt()
    else
      _ -> tus_error(conn, 400, "invalid concatenation request")
    end
  end

  # ── HEAD (authoritative offset) ──────────────────────────────────────────────

  defp handle_head(conn, opts) do
    with {:ok, claims} <- TusProtocol.verify_token(conn, opts[:secret_key_base]),
         {:ok, session} <- load_active_session(claims),
         :ok <- authorize_resume(conn, claims, session, :head, opts) do
      conn
      |> put_tus_resumable()
      |> put_resp_header("upload-offset", Integer.to_string(session.last_known_offset))
      |> maybe_put_upload_length(TusProtocol.effective_length(session, claims))
      |> put_resp_header("cache-control", "no-store")
      |> put_resp_header("upload-expires", TusProtocol.http_date(session.expires_at))
      |> send_resp(204, "")
      |> halt()
    else
      {:error, reason} -> tus_error(conn, TusProtocol.status_for(reason), "")
    end
  end

  # ── PATCH (resumable write + completion convergence) ─────────────────────────

  defp handle_patch(conn, opts) do
    # Order is strict: token → session → 415 (Content-Type) → 409 (offset) all
    # gate BEFORE any body is read (the 409 contract spine; never drain on mismatch).
    with {:ok, claims} <- TusProtocol.verify_token(conn, opts[:secret_key_base]),
         {:ok, session} <- load_active_session(claims),
         :ok <- authorize_resume(conn, claims, session, :patch, opts),
         :ok <- TusProtocol.require_offset_octet_stream(conn),
         {:ok, inbound_offset} <- TusProtocol.parse_upload_offset(conn),
         :ok <- TusProtocol.check_offset_match(inbound_offset, session.last_known_offset),
         {:ok, session, effective_len} <- resolve_patch_length(conn, session, claims, opts),
         {:ok, checksum_alg, expected_hash} <- TusProtocol.parse_upload_checksum(conn),
         {:ok, part_state} <-
           TusStream.append(
             conn,
             session,
             claims,
             effective_len,
             checksum_alg,
             expected_hash,
             opts
           ) do
      new_offset = part_state.offset

      {:ok, advanced} =
        session
        |> MediaUploadSession.changeset(TusStream.persistence_attrs(session, part_state))
        |> Config.repo().update()

      broadcast_upload_session(advanced, :upload_session_uploading, %{offset: new_offset})

      ResumableTelemetry.emit_patch(
        to_string(opts[:profile]),
        opts[:adapter],
        advanced,
        %{state: advanced.state, source: :patch, outcome: :ok, protocol: :tus},
        %{committed_bytes: new_offset, offset_delta: new_offset - session.last_known_offset}
      )

      maybe_complete(conn, advanced, new_offset, effective_len, claims, opts)
    else
      {:error, reason} -> tus_error(conn, TusProtocol.status_for(reason), "")
    end
  end

  defp maybe_complete(conn, session, new_offset, effective_len, payload, opts) do
    if new_offset == effective_len do
      complete_upload(conn, session, payload, opts)
    else
      conn
      |> put_tus_resumable()
      |> put_resp_header("upload-offset", Integer.to_string(new_offset))
      |> put_resp_header("upload-expires", TusProtocol.http_date(session.expires_at))
      |> send_resp(204, "")
      |> halt()
    end
  end

  # Completion: finalize the upload POLYMORPHICALLY through the adapter's tus sink
  # (`adapter.complete_part_stream/4`) — S3 flushes the tail + completes the
  # multipart, Local atomic-renames its part file. NO `if adapter == Local`
  # branch (D-12). Then converge into the UNCHANGED verify_completion/2 lane
  # (D-08 — zero new completion vocabulary). The session is in "signed", so
  # verify_completion's signed -> verifying edge is legal (never parked in
  # "resuming" — Pitfall 7). `temp_path` is nil: the final PATCH's bytes were
  # already appended during the matching upload_part_stream/5 call.
  defp complete_upload(conn, session, payload, opts) do
    with {:ok, _result} <-
           TusStream.completion(session, payload, opts),
         {:ok, %{session: _completed}} <- Broker.verify_completion(session.id, root: opts[:root]) do
      conn
      |> put_tus_resumable()
      |> put_resp_header("upload-offset", Integer.to_string(session.last_known_offset))
      |> send_resp(204, "")
      |> halt()
    else
      {:error, _reason} -> tus_error(conn, 500, "")
    end
  end

  # ── DELETE (Termination) ─────────────────────────────────────────────────────

  # Termination order is load-bearing (CR-01): the backing store is aborted
  # BEFORE the state transition, so an explicitly-cancelled S3-backed upload never
  # leaks its multipart upload — even if the subsequent DB update fails. The abort
  # runs ONLY after token verification + session load succeed (auth order is
  # unchanged; a tampered token never reaches the abort).
  defp handle_delete(conn, opts) do
    with {:ok, claims} <- TusProtocol.verify_token(conn, opts[:secret_key_base]),
         {:ok, session} <- load_active_session(claims),
         :ok <- authorize_resume(conn, claims, session, :delete, opts) do
      # (1) FIRST abort the backing store polymorphically (S3 multipart abort, or
      # Local tmp removal) via the shared PUBLIC helper, using the adapter + root
      # the Plug already holds in `opts` — no DB profile re-resolution on the hot
      # DELETE path and no `if adapter == Local` branch (D-12). On a TRANSIENT
      # abort failure (CR-01) the abort is NOT silently swallowed: the row carries
      # a retryable `tus_abort_failed:<reason>` marker (folded into the aborted
      # changeset below) so the reaper re-aborts the orphaned multipart on the
      # next cron via `fetch_retryable_tus_abort_sessions/0`. A clean abort leaves
      # `failure_reason: nil` so the reaper never re-selects a cleanly cancelled row.
      abort_attrs = TusTermination.abort_attrs(session, opts)

      # (2) THEN persist the abort transition and honour the result (WR-02): a
      # failed update returns 5xx so the client is never falsely told 204 while the
      # row remains re-PATCHable / mis-reaped. The DELETE still returns 204 on a
      # successful update even when the backing abort failed (client-facing cancel
      # semantics preserved); the cost-leak compensation is the reaper's job.
      session
      |> MediaUploadSession.changeset(Map.put(abort_attrs, :state, "aborted"))
      |> Config.repo().update()
      |> case do
        {:ok, aborted} ->
          broadcast_upload_session(aborted, :upload_session_cancelled)
          conn |> put_tus_resumable() |> send_resp(204, "") |> halt()

        {:error, _changeset} ->
          tus_error(conn, 500, "")
      end
    else
      {:error, reason} -> tus_error(conn, TusProtocol.status_for(reason), "")
    end
  end

  defp resolve_patch_length(conn, session, %{"length" => "deferred"}, opts) do
    if is_integer(session.upload_length) do
      {:ok, session, session.upload_length}
    else
      with {:ok, length} when is_integer(length) <- TusProtocol.parse_upload_length(conn),
           :ok <- TusProtocol.check_max_size(length, opts[:max_size]) do
        # Deferred length is the facade's persistence boundary: parsing and bounds
        # are settled before the row changes, and streaming remains later in the
        # enclosing PATCH sequence.
        {:ok, updated} =
          session
          |> MediaUploadSession.changeset(%{upload_length: length})
          |> Config.repo().update()

        {:ok, updated, length}
      else
        {:ok, _deferred} -> {:error, :invalid_length}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp resolve_patch_length(_conn, session, %{"length" => length}, _opts)
       when is_integer(length) do
    {:ok, session, length}
  end

  defp load_active_session(%{"session_id" => session_id}) do
    case Config.repo().get(MediaUploadSession, session_id) do
      nil ->
        {:error, :not_found}

      %MediaUploadSession{} = session ->
        if expired?(session.expires_at), do: {:error, :gone}, else: {:ok, session}
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  defp tus_error(conn, status, body) do
    conn
    |> put_tus_resumable()
    |> send_resp(status, body)
    |> halt()
  end

  defp put_tus_resumable(conn), do: put_resp_header(conn, "tus-resumable", @tus_version)

  defp maybe_put_upload_length(conn, length) when is_integer(length) do
    put_resp_header(conn, "upload-length", Integer.to_string(length))
  end

  defp maybe_put_upload_length(conn, _length), do: conn

  defp expired?(nil), do: false
  defp expired?(%DateTime{} = at), do: DateTime.compare(at, DateTime.utc_now()) == :lt

  @doc false
  # Public so it can be used as a remote-capture default (`&__MODULE__.default_actor/1`),
  # which `Plug.Router` `forward init_opts:` can escape at compile time (an anonymous
  # capture cannot). Adopters override via the `:identity_fn` option.
  def default_actor(conn) do
    conn.assigns[:rindle_actor] || conn.assigns[:actor_subject] || "anonymous"
  end

  defp broadcast_upload_session(%MediaUploadSession{} = session, event_type, extra \\ %{}) do
    payload =
      %{
        session_id: session.id,
        asset_id: session.asset_id,
        state: session.state,
        upload_strategy: session.upload_strategy,
        resumable_protocol: session.resumable_protocol
      }
      |> Map.merge(Map.take(extra, [:offset]))

    topics =
      ["rindle:admin:lifecycle", "rindle:upload_session:#{session.id}"]
      |> maybe_append_asset_topic(session.asset_id)

    Enum.each(topics, fn topic ->
      :ok = PubSub.broadcast(pubsub_server(), topic, {:rindle_event, event_type, payload})
    end)

    :ok
  end

  defp maybe_append_asset_topic(topics, asset_id) when is_binary(asset_id),
    do: topics ++ ["rindle:asset:#{asset_id}"]

  defp maybe_append_asset_topic(topics, _asset_id), do: topics

  defp pubsub_server do
    Application.get_env(:rindle, :pubsub_server, Rindle.PubSub)
  end

  defp authorize_resume(conn, claims, session, method, opts) do
    case opts[:resume_authorizer] do
      nil ->
        :ok

      authorizer ->
        actor = opts[:identity_fn].(conn)

        case authorizer.authorize(actor, :resume, %{
               token_actor: Map.get(claims, "actor"),
               session: session,
               profile: opts[:profile],
               method: method
             }) do
          :ok -> :ok
          :reject -> {:error, :resume_rejected}
          other -> raise ArgumentError, "invalid tus resume authorizer result: #{inspect(other)}"
        end
    end
  end

  defp validate_resume_authorizer!(nil), do: nil

  defp validate_resume_authorizer!(authorizer) when is_atom(authorizer) do
    if Code.ensure_loaded?(authorizer) and function_exported?(authorizer, :authorize, 3) do
      authorizer
    else
      raise ArgumentError,
            "config :rindle, :tus_resume_authorizer must implement authorize/3, got: #{inspect(authorizer)}"
    end
  end
end
