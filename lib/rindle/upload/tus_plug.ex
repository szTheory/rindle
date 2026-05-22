defmodule Rindle.Upload.TusPlug do
  @moduledoc """
  Bare, mountable [tus 1.0](https://tus.io/protocols/resumable-upload) protocol
  edge over the v1.7 resumable-session substrate.

  `TusPlug` is a `@behaviour Plug` (`init/1` + `call/2`) — it adds **no Phoenix
  dependency**. Mount it under your own auth pipeline via `forward`, in either a
  Phoenix Router:

      forward "/uploads/tus", Rindle.Upload.TusPlug,
        profile: MyApp.VideoProfile,
        secret_key_base: MyAppWeb.Endpoint.config(:secret_key_base)

  or a `Plug.Router`:

      forward "/uploads/tus",
        to: Rindle.Upload.TusPlug,
        init_opts: [profile: MyApp.VideoProfile, secret_key_base: secret]

  ## Scope (Phase 42)

  Implements the tus **Core + Creation + Expiration + Termination** extensions
  ONLY, proven against `Rindle.Storage.Local` tmp-append backing. The advertised
  `Tus-Extension` set is exactly `creation,expiration,termination`.

  | Method | Status | Notes |
  |--------|--------|-------|
  | `OPTIONS` | 204 | advertises `Tus-Version`/`Tus-Resumable`/`Tus-Extension`/`Tus-Max-Size` |
  | `POST` | 201 | Creation — `Upload-Length` + opaque `Upload-Metadata` → signed `Location` |
  | `HEAD` | 204 | authoritative `Upload-Offset` + `Cache-Control: no-store` |
  | `PATCH` | — | resumable write (Plan 03) |
  | `DELETE` | — | Termination (Plan 03) |
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
  """

  @behaviour Plug

  import Plug.Conn

  alias Rindle.Config
  alias Rindle.Domain.MediaUploadSession
  alias Rindle.Storage.{Capabilities, Local}
  alias Rindle.Upload.Broker

  @tus_url_salt "rindle:tus:url"
  @tus_version "1.0.0"
  @tus_extensions "creation,expiration,termination"
  @offset_content_type "application/offset+octet-stream"
  # Conservative adopter-overridable default (5 GiB). The only adopter-facing
  # size knob; the PATCH read-loop constants below stay fixed (D-07).
  @default_max_size 5 * 1024 * 1024 * 1024
  # Socket fill + per-read return size — a fixed safety constant so a slow-loris
  # PATCH cannot pin memory (D-07). Never adopter config.
  @read_length 1_048_576

  @impl true
  def init(opts) do
    profile = Keyword.fetch!(opts, :profile)
    secret_key_base = Keyword.fetch!(opts, :secret_key_base)
    max_size = Keyword.get(opts, :max_size, @default_max_size)
    identity_fn = Keyword.get(opts, :identity_fn, &__MODULE__.default_actor/1)
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
      root: root
    ]
  end

  @impl true
  def call(%Plug.Conn{method: "OPTIONS"} = conn, opts), do: handle_options(conn, opts)
  def call(%Plug.Conn{method: "POST"} = conn, opts), do: handle_post(conn, opts)
  def call(%Plug.Conn{method: "HEAD"} = conn, opts), do: handle_head(conn, opts)
  def call(%Plug.Conn{method: "PATCH"} = conn, opts), do: handle_patch(conn, opts)
  def call(%Plug.Conn{method: "DELETE"} = conn, opts), do: handle_delete(conn, opts)

  def call(conn, _opts) do
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
    |> send_resp(204, "")
    |> halt()
  end

  # ── POST (Creation — HMAC-sign the URL, bind to a tus session) ───────────────

  defp handle_post(conn, opts) do
    with {:ok, length} <- parse_upload_length(conn),
         :ok <- check_max_size(length, opts[:max_size]),
         {:ok, %{session: session}} <- Broker.initiate_tus_upload(opts[:profile]),
         {:ok, location, session} <- sign_and_persist(conn, session, length, opts) do
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

  defp sign_and_persist(conn, session, length, opts) do
    actor = opts[:identity_fn].(conn)

    # Token payload is HMAC-signed and tamper-proof, so `length` rides inside it
    # rather than a new column (D-10 budget). HEAD/PATCH read it back on verify.
    payload = %{
      "session_id" => session.id,
      "actor" => actor,
      "exp" => DateTime.to_unix(session.expires_at),
      "length" => length
    }

    token = Plug.Crypto.sign(opts[:secret_key_base], @tus_url_salt, payload)
    location = location_base(conn) <> "/" <> token

    # Persist ONLY into session_uri so the redacting Inspect applies (invariant 14).
    session
    |> MediaUploadSession.changeset(%{
      session_uri: location,
      session_uri_expires_at: session.expires_at
    })
    |> Config.repo().update()
    |> case do
      {:ok, updated} -> {:ok, location, updated}
      {:error, changeset} -> {:error, changeset}
    end
  end

  # ── HEAD (authoritative offset) ──────────────────────────────────────────────

  defp handle_head(conn, opts) do
    with {:ok, payload} <- verify_token(conn, opts),
         {:ok, session} <- load_active_session(payload) do
      conn
      |> put_tus_resumable()
      |> put_resp_header("upload-offset", Integer.to_string(session.last_known_offset))
      |> maybe_put_upload_length(payload)
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
         :ok <- require_offset_octet_stream(conn),
         {:ok, inbound_offset} <- parse_upload_offset(conn),
         :ok <- check_offset_match(inbound_offset, session.last_known_offset),
         {:ok, new_offset} <- stream_append(conn, session, payload, opts) do
      {:ok, advanced} = persist_offset(session, new_offset)
      maybe_complete(conn, advanced, new_offset, payload, opts)
    else
      {:error, reason} -> tus_error(conn, status_for(reason), "")
    end
  end

  # Streams the request body in 1 MiB chunks straight to the tmp .part file —
  # never buffers the whole body (D-07). Bounds total bytes by the per-PATCH
  # ceiling (max_size) AND the declared Upload-Length → 413.
  defp stream_append(conn, session, payload, opts) do
    part_path = Local.tus_part_path(session.id, root: opts[:root])
    File.mkdir_p!(Path.dirname(part_path))
    ceiling = opts[:max_size]
    upload_length = payload["length"]

    case File.open(part_path, [:append, :binary]) do
      {:ok, file} ->
        try do
          drain(conn, file, session.last_known_offset, 0, ceiling, upload_length)
        after
          File.close(file)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp drain(conn, file, base_offset, written, ceiling, upload_length) do
    case Plug.Conn.read_body(conn, length: @read_length, read_length: @read_length) do
      {:ok, chunk, _conn} ->
        write_chunk(file, chunk, base_offset, written, ceiling, upload_length, :done)

      {:more, chunk, conn} ->
        case write_chunk(file, chunk, base_offset, written, ceiling, upload_length, :more) do
          {:cont, new_written} ->
            drain(conn, file, base_offset, new_written, ceiling, upload_length)

          other ->
            other
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp write_chunk(file, chunk, base_offset, written, ceiling, upload_length, mode) do
    new_written = written + byte_size(chunk)

    cond do
      new_written > ceiling ->
        {:error, :too_large}

      is_integer(upload_length) and base_offset + new_written > upload_length ->
        {:error, :too_large}

      true ->
        IO.binwrite(file, chunk)
        if mode == :done, do: {:ok, base_offset + new_written}, else: {:cont, new_written}
    end
  end

  defp persist_offset(session, new_offset) do
    session
    |> MediaUploadSession.changeset(%{last_known_offset: new_offset})
    |> Config.repo().update()
  end

  defp maybe_complete(conn, session, new_offset, payload, opts) do
    if new_offset == payload["length"] do
      complete_upload(conn, session, opts)
    else
      conn
      |> put_tus_resumable()
      |> put_resp_header("upload-offset", Integer.to_string(new_offset))
      |> put_resp_header("upload-expires", http_date(session.expires_at))
      |> send_resp(204, "")
      |> halt()
    end
  end

  # Completion: atomic-rename the tmp part into the final key, then converge into
  # the UNCHANGED verify_completion/2 lane (D-08 — zero new completion vocabulary).
  # The session is in "signed", so verify_completion's signed -> verifying edge is
  # legal (never parked in "resuming" — Pitfall 7).
  defp complete_upload(conn, session, opts) do
    with {:ok, _path} <- Local.tus_complete(session.id, session.upload_key, root: opts[:root]),
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

  defp handle_delete(conn, opts) do
    with {:ok, payload} <- verify_token(conn, opts),
         {:ok, session} <- load_active_session(payload) do
      session
      |> MediaUploadSession.changeset(%{state: "aborted"})
      |> Config.repo().update()

      # Best-effort tmp cleanup; the reaper sweeps Rindle.tmp/ regardless.
      File.rm(Local.tus_part_path(session.id, root: opts[:root]))

      conn
      |> put_tus_resumable()
      |> send_resp(204, "")
      |> halt()
    else
      {:error, reason} -> tus_error(conn, status_for(reason), "")
    end
  end

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
  defp status_for(:gone), do: 410
  defp status_for(:wrong_content_type), do: 415
  defp status_for(:offset_mismatch), do: 409
  defp status_for(:too_large), do: 413
  defp status_for(:invalid_offset), do: 400

  defp tus_error(conn, status, body) do
    conn
    |> put_tus_resumable()
    |> send_resp(status, body)
    |> halt()
  end

  defp put_tus_resumable(conn), do: put_resp_header(conn, "tus-resumable", @tus_version)

  defp maybe_put_upload_length(conn, %{"length" => length}) when is_integer(length) do
    put_resp_header(conn, "upload-length", Integer.to_string(length))
  end

  defp maybe_put_upload_length(conn, _payload), do: conn

  defp parse_upload_length(conn) do
    case get_req_header(conn, "upload-length") do
      [value] ->
        case Integer.parse(value) do
          {length, ""} when length >= 0 -> {:ok, length}
          _ -> {:error, :invalid_length}
        end

      _ ->
        {:error, :invalid_length}
    end
  end

  defp check_max_size(length, max_size) when length > max_size, do: {:error, :too_large}
  defp check_max_size(_length, _max_size), do: :ok

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
end
