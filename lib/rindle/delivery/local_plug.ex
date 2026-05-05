defmodule Rindle.Delivery.LocalPlug do
  @moduledoc """
  Dev-parity-only local playback Plug for `Rindle.Storage.Local`.

  This Plug exists to give browser playback a correct HTTP path in local
  development when the storage adapter is `Rindle.Storage.Local`. It is not the
  production delivery posture for Rindle; production delivery stays on
  redirect/native object-store byte serving.
  """

  @behaviour Plug

  import Plug.Conn

  alias Rindle.Storage.Local

  @local_playback_salt "rindle:delivery:local-playback"

  @impl true
  def init(opts) do
    profile = Keyword.fetch!(opts, :profile)
    secret_key_base = Keyword.fetch!(opts, :secret_key_base)

    if profile.storage_adapter() != Local do
      raise ArgumentError,
            "Rindle.Delivery.LocalPlug requires #{inspect(Local)} but got #{inspect(profile.storage_adapter())}"
    end

    [
      profile: profile,
      adapter: Local,
      root: Local.root(opts),
      secret_key_base: secret_key_base
    ]
  end

  @impl true
  def call(conn, opts) do
    conn = fetch_query_params(conn)

    with {:ok, payload} <- verify_token(conn, opts),
         {:ok, path} <- resolve_path(payload, opts),
         {:ok, file_size} <- file_size(payload["key"], opts) do
      send_local_file(conn, opts, payload, path, file_size)
    else
      {:error, :invalid_token} -> forbidden(conn)
      {:error, :expired_token} -> forbidden(conn)
      {:error, :path_outside_root} -> forbidden(conn)
      {:error, :not_found} -> not_found(conn)
    end
  end

  defp verify_token(conn, opts) do
    token = conn.query_params["token"]

    case Plug.Crypto.verify(opts[:secret_key_base], @local_playback_salt, token) do
      {:ok, %{"expires_at" => expires_at} = payload} ->
        if expires_at >= System.system_time(:second) do
          {:ok, payload}
        else
          {:error, :expired_token}
        end

      {:error, :expired} ->
        {:error, :expired_token}

      {:error, _reason} ->
        {:error, :invalid_token}
    end
  end

  defp resolve_path(%{"key" => key}, opts) do
    path = Local.path_for(key, root: opts[:root])

    if within_root?(path, opts[:root]) do
      {:ok, path}
    else
      {:error, :path_outside_root}
    end
  end

  defp file_size(key, opts) do
    case Local.head(key, root: opts[:root]) do
      {:ok, %{size: size}} -> {:ok, size}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  defp send_local_file(conn, opts, payload, path, file_size) do
    conn =
      conn
      |> maybe_put_resp_content_type(payload["mime"])
      |> maybe_put_content_disposition(payload["content_disposition"])
      |> put_resp_header("accept-ranges", "bytes")

    case resolve_range(get_req_header(conn, "range"), file_size) do
      {:range, offset, last_byte} ->
        length = last_byte - offset + 1

        :telemetry.execute(
          [:rindle, :delivery, :range_request],
          %{
            system_time: System.system_time(),
            offset: offset,
            length: length,
            file_size: file_size
          },
          %{
            profile: opts[:profile],
            adapter: opts[:adapter],
            key: payload["key"],
            actor_subject: payload["actor_subject"]
          }
        )

        conn
        |> put_resp_header("content-length", Integer.to_string(length))
        |> put_resp_header("content-range", "bytes #{offset}-#{last_byte}/#{file_size}")
        |> send_file(206, path, offset, length)
        |> halt()

      :all ->
        conn
        |> put_resp_header("content-length", Integer.to_string(file_size))
        |> send_file(200, path, 0, :all)
        |> halt()
    end
  end

  defp maybe_put_resp_content_type(conn, nil), do: conn
  defp maybe_put_resp_content_type(conn, mime), do: put_resp_content_type(conn, mime)

  defp maybe_put_content_disposition(conn, nil), do: conn

  defp maybe_put_content_disposition(conn, %{
         "type" => type,
         "filename" => filename,
         "filename_star" => filename_star
       }) do
    header = "#{type}; filename=\"#{filename}\"; filename*=#{filename_star}"
    put_resp_header(conn, "content-disposition", header)
  end

  defp maybe_put_content_disposition(conn, %{type: type, filename: filename, filename_star: filename_star}) do
    header = "#{type}; filename=\"#{filename}\"; filename*=#{filename_star}"
    put_resp_header(conn, "content-disposition", header)
  end

  defp resolve_range([], _file_size), do: :all
  defp resolve_range([header | _], file_size), do: parse_range(header, file_size)

  defp parse_range("bytes=" <> value, file_size) do
    case String.split(value, ",", trim: true) do
      [single_range] -> parse_single_range(String.trim(single_range), file_size)
      _multiple -> :all
    end
  end

  defp parse_range(_header, _file_size), do: :all

  defp parse_single_range("-" <> suffix, file_size) do
    with {suffix_length, ""} <- Integer.parse(suffix),
         true <- suffix_length > 0 do
      offset = max(file_size - suffix_length, 0)
      {:range, offset, file_size - 1}
    else
      _ -> :all
    end
  end

  defp parse_single_range(range, file_size) do
    case String.split(range, "-", parts: 2) do
      [start_value, ""] ->
        with {start_offset, ""} <- Integer.parse(start_value),
             true <- start_offset < file_size do
          {:range, start_offset, file_size - 1}
        else
          _ -> :all
        end

      [start_value, stop_value] ->
        with {start_offset, ""} <- Integer.parse(start_value),
             {stop_offset, ""} <- Integer.parse(stop_value),
             true <- start_offset <= stop_offset,
             true <- start_offset < file_size do
          {:range, start_offset, min(stop_offset, file_size - 1)}
        else
          _ -> :all
        end

      _ ->
        :all
    end
  end

  defp within_root?(path, root) do
    normalized_root = Path.join(root, "")
    path == root or String.starts_with?(path, normalized_root)
  end

  defp forbidden(conn) do
    conn
    |> send_resp(403, "forbidden")
    |> halt()
  end

  defp not_found(conn) do
    conn
    |> send_resp(404, "not found")
    |> halt()
  end
end
