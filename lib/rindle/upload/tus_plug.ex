defmodule Rindle.Upload.TusPlug do
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
  `creation,expiration,termination,checksum,creation-defer-length,concatenation`.

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

  require Logger

  alias Rindle.Config
  alias Rindle.Domain.MediaUploadSession
  alias Rindle.Ops.UploadMaintenance
  alias Rindle.Storage.Capabilities
  alias Rindle.Upload.{Broker, ResumableTelemetry}

  @tus_url_salt "rindle:tus:url"
  @tus_version "1.0.0"
  @tus_extensions "creation,expiration,termination,checksum,creation-defer-length,concatenation"
  @offset_content_type "application/offset+octet-stream"
  # Conservative adopter-overridable default (5 GiB). The only adopter-facing
  # size knob; the PATCH read-loop constants below stay fixed (D-07).
  @default_max_size 5 * 1024 * 1024 * 1024
  # Socket fill + per-read return size — a fixed safety constant so a slow-loris
  # PATCH cannot pin memory (D-07). Never adopter config.
  @read_length 1_048_576

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
         secret_key_base when is_binary(secret_key_base) <- Keyword.fetch!(opts, :secret_key_base),
         {:ok, length} <- normalize_length(Keyword.get(opts, :length)) do
      actor = Keyword.get(opts, :actor, "anonymous")
      content_type = Keyword.get(opts, :content_type)

      create_upload_for_path(path, profile,
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
    content_type = upload_metadata_content_type(conn)
    concat_header = get_req_header(conn, "upload-concat") |> List.first()

    cond do
      concat_header && String.starts_with?(concat_header, "final;") ->
        handle_concat_final(conn, concat_header, opts)

      true ->
        is_partial = concat_header == "partial"

        with {:ok, length} <- parse_upload_length(conn),
             :ok <- check_max_size(length, opts[:max_size]),
             {:ok, %{session: session, upload_url: location}} <-
               create_upload_for_path(location_base(conn), opts[:profile],
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
          |> put_resp_header("upload-expires", http_date(session.expires_at))
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

    with {:ok, tokens} <- extract_tokens_from_urls(urls),
         {:ok, payloads} <- verify_tokens_for_concat(tokens, opts),
         {:ok, %{session: final_session}} <-
           Broker.concatenate_tus_sessions(opts[:profile], payloads, opts),
         # No Upload-Length header allowed/parsed for final. The length is the sum of partials.
         {:ok, upload_url, signed_session} <-
           sign_and_persist(
             location_base(conn),
             final_session,
             final_session.upload_length,
             upload_metadata_content_type(conn),
             opts[:secret_key_base],
             opts[:identity_fn].(conn),
             false
           ) do
      conn
      |> put_tus_resumable()
      |> put_resp_header("location", upload_url)
      |> put_resp_header("upload-expires", http_date(signed_session.expires_at))
      |> send_resp(201, "")
      |> halt()
    else
      _ -> tus_error(conn, 400, "invalid concatenation request")
    end
  end

  defp extract_tokens_from_urls(urls) do
    tokens =
      Enum.map(urls, fn url ->
        url |> String.split("/") |> List.last()
      end)

    if Enum.all?(tokens, &(&1 != nil and &1 != "")), do: {:ok, tokens}, else: {:error, :invalid_urls}
  end

  defp verify_tokens_for_concat(tokens, opts) do
    Enum.reduce_while(tokens, {:ok, []}, fn token, {:ok, acc} ->
      with {:ok, payload} <- Plug.Crypto.verify(opts[:secret_key_base], @tus_url_salt, token),
           {:ok, payload} <- check_not_expired(payload) do
        {:cont, {:ok, [payload | acc]}}
      else
        _ -> {:halt, {:error, :invalid_token}}
      end
    end)
    |> case do
      {:ok, reversed_payloads} -> {:ok, Enum.reverse(reversed_payloads)}
      error -> error
    end
  end

  defp create_upload_for_path(base_path, profile, opts) do
    filename = Keyword.get(opts, :filename, "unknown")
    expires_in = Keyword.get(opts, :expires_in, 3600)
    length = Keyword.get(opts, :length)
    content_type = Keyword.get(opts, :content_type)
    actor = Keyword.get(opts, :actor, "anonymous")
    secret_key_base = Keyword.fetch!(opts, :secret_key_base)
    is_partial = Keyword.get(opts, :is_partial, false)

    with {:ok, %{session: session}} <-
           Broker.initiate_tus_upload(profile, filename: filename, expires_in: expires_in),
         {:ok, upload_url, signed_session} <-
           sign_and_persist(base_path, session, length, content_type, secret_key_base, actor, is_partial) do
      {:ok,
       %{session: signed_session, upload_url: upload_url, expires_at: signed_session.expires_at}}
    end
  end

  defp sign_and_persist(base_path, session, length, content_type, secret_key_base, actor, is_partial) do
    # Token payload is HMAC-signed and tamper-proof, so `length` rides inside it
    # rather than a new column (D-10 budget). HEAD/PATCH read it back on verify.
    payload = %{
      "session_id" => session.id,
      "actor" => actor,
      "exp" => DateTime.to_unix(session.expires_at),
      "length" => length
    }

    payload = maybe_put_content_type(payload, content_type)

    token = Plug.Crypto.sign(secret_key_base, @tus_url_salt, payload)
    location = join_upload_url(base_path, token)

    attrs = %{
      session_uri: location,
      session_uri_expires_at: session.expires_at
    }

    attrs =
      if is_partial do
        Map.put(attrs, :multipart_parts, %{"is_partial" => true})
      else
        attrs
      end

    # Persist ONLY into session_uri so the redacting Inspect applies (invariant 14).
    session
    |> MediaUploadSession.changeset(attrs)
    |> Config.repo().update()
    |> case do
      {:ok, updated} -> {:ok, location, updated}
      {:error, changeset} -> {:error, changeset}
    end
  end

  # ── HEAD (authoritative offset) ──────────────────────────────────────────────

  defp handle_head(conn, opts) do
    with {:ok, payload} <- verify_token(conn, opts),
         {:ok, session} <- load_active_session(payload),
         :ok <- authorize_resume(conn, payload, session, :head, opts) do
      conn
      |> put_tus_resumable()
      |> put_resp_header("upload-offset", Integer.to_string(session.last_known_offset))
      |> maybe_put_upload_length(effective_length(session, payload))
      |> put_resp_header("cache-control", "no-store")
      |> put_resp_header("upload-expires", http_date(session.expires_at))
      |> send_resp(204, "")
      |> halt()
    else
      {:error, reason} -> tus_error(conn, status_for(reason), "")
    end
  end

  # ── PATCH (resumable write + completion convergence) ─────────────────────────

  defp handle_patch(conn, opts) do
    # Order is strict: token → session → 415 (Content-Type) → 409 (offset) all
    # gate BEFORE any body is read (the 409 contract spine; never drain on mismatch).
    with {:ok, payload} <- verify_token(conn, opts),
         {:ok, session} <- load_active_session(payload),
         :ok <- authorize_resume(conn, payload, session, :patch, opts),
         :ok <- require_offset_octet_stream(conn),
         {:ok, inbound_offset} <- parse_upload_offset(conn),
         :ok <- check_offset_match(inbound_offset, session.last_known_offset),
         {:ok, session, effective_len} <- resolve_patch_length(conn, session, payload, opts),
         {:ok, checksum_alg, expected_hash} <- parse_upload_checksum(conn),
         {:ok, part_state} <-
           stream_append(conn, session, payload, effective_len, checksum_alg, expected_hash, opts) do
      new_offset = part_state.offset
      {:ok, advanced} = persist_offset(session, part_state)

      ResumableTelemetry.emit_patch(
        to_string(opts[:profile]),
        opts[:adapter],
        advanced,
        %{state: advanced.state, source: :patch, outcome: :ok, protocol: :tus},
        %{committed_bytes: new_offset, offset_delta: new_offset - session.last_known_offset}
      )

      maybe_complete(conn, advanced, new_offset, effective_len, payload, opts)
    else
      {:error, reason} -> tus_error(conn, status_for(reason), "")
    end
  end

  # Drains the PATCH body in 1 MiB chunks to a per-PATCH temp file (distinct from
  # the .part/.tail backing files) — never buffers the whole body (D-07). Bounds
  # total bytes by the per-PATCH ceiling (max_size) AND the declared Upload-Length
  # → 413. Then dispatches the temp path POLYMORPHICALLY through the storage
  # behaviour (`adapter.upload_part_stream/5`) — no `if adapter == Local` branch
  # (D-12). The temp file holds exactly ONE PATCH worth of bytes and is removed
  # after dispatch.
  defp stream_append(conn, session, payload, effective_len, checksum_alg, expected_hash, opts) do
    temp_path = Path.join([tus_tmp_dir(opts), session.id <> ".patch"])
    File.mkdir_p!(Path.dirname(temp_path))
    ceiling = opts[:max_size]

    hash_ctx =
      case checksum_alg do
        "sha1" -> :crypto.hash_init(:sha)
        "sha256" -> :crypto.hash_init(:sha256)
        _ -> nil
      end

    drain_result =
      case File.open(temp_path, [:write, :binary]) do
        {:ok, file} ->
          try do
            drain(conn, file, session.last_known_offset, 0, ceiling, effective_len, hash_ctx)
          after
            File.close(file)
          end

        {:error, reason} ->
          {:error, reason}
      end

    drain_result =
      case {drain_result, expected_hash} do
        {{:ok, new_offset, final_hash_ctx}, hash} when not is_nil(hash) ->
          if :crypto.hash_final(final_hash_ctx) == hash do
            {:ok, new_offset}
          else
            {:error, :checksum_mismatch}
          end

        {{:ok, new_offset, _}, _} ->
          {:ok, new_offset}

        {{:error, reason}, _} ->
          {:error, reason}
      end

    try do
      dispatch_part(drain_result, temp_path, session, payload, opts)
    after
      File.rm(temp_path)
    end
  end

  # Hands the drained temp file to the adapter's tus sink. The prior part-state
  # (offset + S3's multipart_upload_id/parts; nil/[] for Local) is threaded back
  # in as `state`; the adapter returns the updated `t:tus_part_state/0` to persist.
  defp dispatch_part({:ok, _new_offset}, temp_path, session, payload, opts) do
    opts[:adapter].upload_part_stream(
      session.upload_key,
      temp_path,
      session.last_known_offset,
      prior_state(session),
      call_opts(session, payload["content_type"], opts)
    )
  end

  defp dispatch_part({:error, reason}, _temp_path, _session, _payload, _opts),
    do: {:error, reason}

  # Rebuilds the prior `t:tus_part_state/0` from the persisted session row. The
  # `multipart_parts` column is typed `:map` (Phase 7), so the accumulated S3
  # parts list is stored wrapped under a `"parts"` key (same convention as the
  # presigned-multipart flow, broker.ex) and unwrapped back into a bare list
  # here. Local has no parts → `[]`.
  defp prior_state(session) do
    %{
      offset: session.last_known_offset,
      upload_id: session.multipart_upload_id,
      parts: decode_parts(session.multipart_parts)
    }
  end

  defp decode_parts(%{"parts" => parts}) when is_list(parts), do: parts
  defp decode_parts(_), do: []

  defp drain(conn, file, base_offset, written, ceiling, upload_length, hash_ctx) do
    case Plug.Conn.read_body(conn, length: @read_length, read_length: @read_length) do
      {:ok, chunk, _conn} ->
        write_chunk(file, chunk, base_offset, written, ceiling, upload_length, hash_ctx, :done)

      {:more, chunk, conn} ->
        case write_chunk(
               file,
               chunk,
               base_offset,
               written,
               ceiling,
               upload_length,
               hash_ctx,
               :more
             ) do
          {:cont, new_written, new_hash_ctx} ->
            drain(conn, file, base_offset, new_written, ceiling, upload_length, new_hash_ctx)

          other ->
            other
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp write_chunk(file, chunk, base_offset, written, ceiling, upload_length, hash_ctx, mode) do
    new_written = written + byte_size(chunk)

    cond do
      new_written > ceiling ->
        {:error, :too_large}

      is_integer(upload_length) and base_offset + new_written > upload_length ->
        {:error, :too_large}

      true ->
        IO.binwrite(file, chunk)
        new_hash_ctx = if hash_ctx, do: :crypto.hash_update(hash_ctx, chunk), else: nil

        if mode == :done do
          {:ok, base_offset + new_written, new_hash_ctx}
        else
          {:cont, new_written, new_hash_ctx}
        end
    end
  end

  # Persist the authoritative offset AND the cross-PATCH multipart bookkeeping
  # (S3's UploadId + accumulated parts). The `multipart_parts` column is `:map`
  # NOT NULL (Phase 7), so the S3 parts list is wrapped under a `"parts"` key
  # (matching the presigned-multipart convention in broker.ex) and an absent
  # parts list (Local — no part semantics) persists as the column default `%{}`,
  # never nil. `multipart_upload_id` is nullable; Local persists nil. Threaded
  # back in as the prior `state` on the next PATCH.
  defp persist_offset(session, part_state) do
    new_parts = encode_parts(Map.get(part_state, :parts))

    merged_parts =
      if new_parts do
        Map.merge(session.multipart_parts || %{}, new_parts)
      else
        session.multipart_parts
      end

    session
    |> MediaUploadSession.changeset(%{
      last_known_offset: part_state.offset,
      multipart_upload_id: Map.get(part_state, :upload_id),
      multipart_parts: merged_parts
    })
    |> Config.repo().update()
  end

  defp encode_parts(parts) when is_list(parts) and parts != [], do: %{"parts" => parts}
  defp encode_parts(_), do: %{}

  defp maybe_complete(conn, session, new_offset, effective_len, payload, opts) do
    if new_offset == effective_len do
      complete_upload(conn, session, payload, opts)
    else
      conn
      |> put_tus_resumable()
      |> put_resp_header("upload-offset", Integer.to_string(new_offset))
      |> put_resp_header("upload-expires", http_date(session.expires_at))
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
           opts[:adapter].complete_part_stream(
             session.upload_key,
             nil,
             prior_state(session),
             call_opts(session, payload["content_type"], opts)
           ),
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

  # Per-PATCH temp + adapter-call opts. The temp dir is under the storage root
  # (Local renames within the same filesystem) or the sweepable Rindle.tmp/ root.
  # `call_opts` thread the server-issued session_id (traversal-proof tmp keying)
  # and root; the S3 adapter resolves bucket/aws_config via its own app-env
  # fallback (Pitfall 4) so no creds are threaded through the Plug edge.
  defp tus_tmp_dir(opts) do
    opts[:root] || Rindle.AV.TempRunDir.root_dir()
  end

  defp call_opts(session_or_id, content_type, opts) do
    session_id =
      case session_or_id do
        %{id: id} -> id
        id when is_binary(id) -> id
      end

    [session_id: session_id, root: opts[:root]]
    |> maybe_put_opt(:content_type, content_type)
  end

  # ── DELETE (Termination) ─────────────────────────────────────────────────────

  # Termination order is load-bearing (CR-01): the backing store is aborted
  # BEFORE the state transition, so an explicitly-cancelled S3-backed upload never
  # leaks its multipart upload — even if the subsequent DB update fails. The abort
  # runs ONLY after token verification + session load succeed (auth order is
  # unchanged; a tampered token never reaches the abort).
  defp handle_delete(conn, opts) do
    with {:ok, payload} <- verify_token(conn, opts),
         {:ok, session} <- load_active_session(payload),
         :ok <- authorize_resume(conn, payload, session, :delete, opts) do
      # (1) FIRST abort the backing store polymorphically (S3 multipart abort, or
      # Local tmp removal) via the shared PUBLIC helper, using the adapter + root
      # the Plug already holds in `opts` — no DB profile re-resolution on the hot
      # DELETE path and no `if adapter == Local` branch (D-12). On a TRANSIENT
      # abort failure (CR-01) the abort is NOT silently swallowed: the row carries
      # a retryable `tus_abort_failed:<reason>` marker (folded into the aborted
      # changeset below) so the reaper re-aborts the orphaned multipart on the
      # next cron via `fetch_retryable_tus_abort_sessions/0`. A clean abort leaves
      # `failure_reason: nil` so the reaper never re-selects a cleanly cancelled row.
      abort_attrs = abort_delete_backing(session, opts)

      # (2) THEN persist the abort transition and honour the result (WR-02): a
      # failed update returns 5xx so the client is never falsely told 204 while the
      # row remains re-PATCHable / mis-reaped. The DELETE still returns 204 on a
      # successful update even when the backing abort failed (client-facing cancel
      # semantics preserved); the cost-leak compensation is the reaper's job.
      session
      |> MediaUploadSession.changeset(Map.put(abort_attrs, :state, "aborted"))
      |> Config.repo().update()
      |> case do
        {:ok, _aborted} ->
          conn |> put_tus_resumable() |> send_resp(204, "") |> halt()

        {:error, _changeset} ->
          tus_error(conn, 500, "")
      end
    else
      {:error, reason} -> tus_error(conn, status_for(reason), "")
    end
  end

  # Dispatch the backing abort through the shared PUBLIC polymorphic helper with
  # the EXACT call shape the reaper uses (adapter/root from opts, upload_id from
  # the row). S3 (upload_id present) aborts the multipart; Local (upload_id nil)
  # removes the tmp part/tail.
  #
  # Returns the failure_reason attrs to fold into the `aborted` changeset:
  #   * `%{failure_reason: nil}` on a clean abort (the reaper never re-selects it)
  #   * `%{failure_reason: "tus_abort_failed:<short_reason>"}` on a transient
  #     failure (CR-01) — the EXACT marker prefix the reaper's
  #     `like(failure_reason, "tus_abort_failed:%")` predicate matches byte-for-byte
  #     so the orphaned multipart is re-aborted next cron. The abort error is
  #     logged but never raised; the DELETE still returns 204.
  @spec abort_delete_backing(MediaUploadSession.t(), keyword()) :: %{
          failure_reason: String.t() | nil
        }
  defp abort_delete_backing(session, opts) do
    case UploadMaintenance.abort_tus_backing(session,
           adapter: opts[:adapter],
           root: opts[:root],
           upload_id: session.multipart_upload_id
         ) do
      :ok ->
        %{failure_reason: nil}

      {:error, reason} ->
        Logger.warning("rindle.tus.delete_backing_abort_failed",
          session_id: session.id,
          multipart_upload_id: session.multipart_upload_id,
          reason: inspect(reason)
        )

        %{failure_reason: tus_abort_marker(reason)}
    end
  end

  # Build the retryable marker the reaper keys on. The reason is normalised to a
  # bounded, single-token string (no internal path, session_uri, or unbounded
  # inspected term embedded — security invariant 14 / T-43-11-04): an atom reason
  # is used verbatim; anything else collapses to `transport`. The result is
  # truncated to a safe length and ALWAYS starts with exactly `tus_abort_failed:`.
  @tus_abort_marker_prefix "tus_abort_failed:"
  @tus_abort_marker_max_reason 64
  defp tus_abort_marker(reason) when is_atom(reason) and not is_nil(reason) do
    @tus_abort_marker_prefix <>
      (reason |> Atom.to_string() |> String.slice(0, @tus_abort_marker_max_reason))
  end

  defp tus_abort_marker(_reason), do: @tus_abort_marker_prefix <> "transport"

  defp require_offset_octet_stream(conn) do
    case get_req_header(conn, "content-type") do
      [@offset_content_type <> _rest] -> :ok
      _ -> {:error, :wrong_content_type}
    end
  end

  defp parse_upload_offset(conn) do
    case get_req_header(conn, "upload-offset") do
      [value] ->
        case Integer.parse(value) do
          {offset, ""} when offset >= 0 -> {:ok, offset}
          _ -> {:error, :invalid_offset}
        end

      _ ->
        {:error, :invalid_offset}
    end
  end

  defp check_offset_match(inbound, current) when inbound == current, do: :ok
  defp check_offset_match(_inbound, _current), do: {:error, :offset_mismatch}

  defp resolve_patch_length(conn, session, %{"length" => "deferred"}, opts) do
    if is_integer(session.upload_length) do
      {:ok, session, session.upload_length}
    else
      case get_req_header(conn, "upload-length") do
        [value] ->
          case Integer.parse(value) do
            {length, ""} when length >= 0 ->
              case check_max_size(length, opts[:max_size]) do
                :ok ->
                  # persist the length
                  {:ok, updated} =
                    session
                    |> MediaUploadSession.changeset(%{upload_length: length})
                    |> Config.repo().update()

                  {:ok, updated, length}

                {:error, :too_large} ->
                  {:error, :too_large}
              end

            _ ->
              {:error, :invalid_length}
          end

        _ ->
          # First PATCH must have Upload-Length
          {:error, :invalid_length}
      end
    end
  end

  defp resolve_patch_length(_conn, session, %{"length" => length}, _opts)
       when is_integer(length) do
    {:ok, session, length}
  end

  defp parse_upload_checksum(conn) do
    case get_req_header(conn, "upload-checksum") do
      [value] ->
        case String.split(value, " ", parts: 2) do
          [alg, hash] when alg in ["sha1", "sha256"] ->
            case Base.decode64(hash) do
              {:ok, decoded} -> {:ok, alg, decoded}
              :error -> {:error, :invalid_checksum}
            end

          _ ->
            {:error, :invalid_checksum}
        end

      _ ->
        {:ok, nil, nil}
    end
  end

  # ── Token extraction + verification ──────────────────────────────────────────

  # D-04: the signed token is the FINAL path segment, resolved from
  # `conn.path_info` AFTER `forward` strips the mount prefix.
  defp extract_token(%Plug.Conn{path_info: []}), do: nil
  defp extract_token(%Plug.Conn{path_info: segments}), do: List.last(segments)

  defp verify_token(conn, opts) do
    with token when is_binary(token) <- extract_token(conn),
         {:ok, payload} <- Plug.Crypto.verify(opts[:secret_key_base], @tus_url_salt, token) do
      check_not_expired(payload)
    else
      nil -> {:error, :invalid_token}
      {:error, :expired} -> {:error, :expired_token}
      {:error, _reason} -> {:error, :invalid_token}
    end
  end

  defp check_not_expired(%{"exp" => exp} = payload) when is_integer(exp) do
    if exp >= System.system_time(:second), do: {:ok, payload}, else: {:error, :expired_token}
  end

  defp check_not_expired(_payload), do: {:error, :invalid_token}

  defp load_active_session(%{"session_id" => session_id}) do
    case Config.repo().get(MediaUploadSession, session_id) do
      nil ->
        {:error, :not_found}

      %MediaUploadSession{} = session ->
        if expired?(session.expires_at), do: {:error, :gone}, else: {:ok, session}
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  # Tampered/forged/missing token → 404 (do not leak existence). Validly-signed
  # but expired token → 401. Session past `expires_at` → 410. Never 200.
  defp status_for(:invalid_token), do: 404
  defp status_for(:not_found), do: 404
  defp status_for(:expired_token), do: 401
  defp status_for(:resume_rejected), do: 401
  defp status_for(:gone), do: 410
  defp status_for(:wrong_content_type), do: 415
  defp status_for(:offset_mismatch), do: 409
  defp status_for(:too_large), do: 413
  defp status_for(:invalid_offset), do: 400
  defp status_for(:invalid_length), do: 400
  defp status_for(:invalid_checksum), do: 400
  defp status_for(:checksum_mismatch), do: 460
  defp status_for(_reason), do: 500

  defp tus_error(conn, status, body) do
    conn
    |> put_tus_resumable()
    |> send_resp(status, body)
    |> halt()
  end

  defp put_tus_resumable(conn), do: put_resp_header(conn, "tus-resumable", @tus_version)

  defp effective_length(%{upload_length: length}, %{"length" => "deferred"})
       when is_integer(length), do: length

  defp effective_length(_session, %{"length" => length}) when is_integer(length), do: length
  defp effective_length(_session, _payload), do: nil

  defp maybe_put_upload_length(conn, length) when is_integer(length) do
    put_resp_header(conn, "upload-length", Integer.to_string(length))
  end

  defp maybe_put_upload_length(conn, _length), do: conn

  defp parse_upload_length(conn) do
    case {get_req_header(conn, "upload-length"), get_req_header(conn, "upload-defer-length")} do
      {[value], _} ->
        case Integer.parse(value) do
          {length, ""} when length >= 0 -> {:ok, length}
          _ -> {:error, :invalid_length}
        end

      {[], ["1"]} ->
        {:ok, "deferred"}

      _ ->
        {:error, :invalid_length}
    end
  end

  defp upload_metadata_content_type(conn) do
    conn
    |> get_req_header("upload-metadata")
    |> List.first()
    |> decode_upload_metadata()
    |> Map.get("filetype")
  end

  defp decode_upload_metadata(nil), do: %{}

  defp decode_upload_metadata(header) when is_binary(header) do
    header
    |> String.split(",", trim: true)
    |> Enum.reduce(%{}, fn pair, acc ->
      case String.split(pair, " ", parts: 2) do
        [key, encoded] when key != "" ->
          case Base.decode64(encoded, padding: false) do
            {:ok, value} -> Map.put(acc, key, value)
            :error -> acc
          end

        _ ->
          acc
      end
    end)
  end

  defp maybe_put_content_type(payload, content_type)
       when is_binary(content_type) and content_type != "" do
    Map.put(payload, "content_type", content_type)
  end

  defp maybe_put_content_type(payload, _content_type), do: payload

  defp maybe_put_opt(opts, _key, nil), do: opts
  defp maybe_put_opt(opts, _key, ""), do: opts
  defp maybe_put_opt(opts, key, value), do: Keyword.put(opts, key, value)

  defp check_max_size("deferred", _max_size), do: :ok
  defp check_max_size(length, max_size) when length > max_size, do: {:error, :too_large}
  defp check_max_size(_length, _max_size), do: :ok

  defp join_upload_url(base_path, token) when is_binary(base_path) and is_binary(token) do
    String.trim_trailing(base_path, "/") <> "/" <> token
  end

  defp normalize_length("deferred"), do: {:ok, "deferred"}
  defp normalize_length(length) when is_integer(length) and length >= 0, do: {:ok, length}
  defp normalize_length(_), do: {:error, :invalid_length}

  # The Location reflects the actual mount: `forward` populates `script_name`
  # with the consumed prefix segments, so the URL is correct regardless of where
  # the adopter mounts the Plug. Falls back to the request path when unmounted.
  defp location_base(conn) do
    case conn.script_name do
      [] -> conn.request_path
      segments -> "/" <> Enum.join(segments, "/")
    end
  end

  defp expired?(nil), do: false
  defp expired?(%DateTime{} = at), do: DateTime.compare(at, DateTime.utc_now()) == :lt

  # RFC 9110 IMF-fixdate (e.g. "Wed, 21 Oct 2026 07:28:00 GMT"). `expires_at` is
  # stored as utc_datetime_usec, so it is already UTC.
  defp http_date(%DateTime{} = datetime),
    do: Calendar.strftime(datetime, "%a, %d %b %Y %H:%M:%S GMT")

  defp http_date(_), do: ""

  @doc false
  # Public so it can be used as a remote-capture default (`&__MODULE__.default_actor/1`),
  # which `Plug.Router` `forward init_opts:` can escape at compile time (an anonymous
  # capture cannot). Adopters override via the `:identity_fn` option.
  def default_actor(conn) do
    conn.assigns[:rindle_actor] || conn.assigns[:actor_subject] || "anonymous"
  end

  defp authorize_resume(conn, payload, session, method, opts) do
    case opts[:resume_authorizer] do
      nil ->
        :ok

      authorizer ->
        actor = opts[:identity_fn].(conn)

        case authorizer.authorize(actor, :resume, %{
               token_actor: Map.get(payload, "actor"),
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
