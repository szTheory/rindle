defmodule Rindle.Upload.TusProtocol do
  @moduledoc false

  import Plug.Conn, only: [get_req_header: 2]

  @tus_url_salt "rindle:tus:url"
  @offset_content_type "application/offset+octet-stream"

  @doc false
  @spec verify_token(Plug.Conn.t(), String.t()) ::
          {:ok, map()} | {:error, :invalid_token | :expired_token}
  def verify_token(conn, secret_key_base) do
    with token when is_binary(token) <- extract_token(conn),
         {:ok, claims} <- Plug.Crypto.verify(secret_key_base, @tus_url_salt, token) do
      check_not_expired(claims)
    else
      nil -> {:error, :invalid_token}
      {:error, :expired} -> {:error, :expired_token}
      {:error, _reason} -> {:error, :invalid_token}
    end
  end

  @doc false
  @spec check_not_expired(map()) :: {:ok, map()} | {:error, :invalid_token | :expired_token}
  def check_not_expired(%{"exp" => exp} = claims) when is_integer(exp) do
    if exp >= System.system_time(:second), do: {:ok, claims}, else: {:error, :expired_token}
  end

  def check_not_expired(_claims), do: {:error, :invalid_token}

  @doc false
  @spec parse_upload_length(Plug.Conn.t()) ::
          {:ok, non_neg_integer() | String.t()} | {:error, :invalid_length}
  def parse_upload_length(conn) do
    case {get_req_header(conn, "upload-length"), get_req_header(conn, "upload-defer-length")} do
      {[value], _} -> parse_non_negative(value, :invalid_length)
      {[], ["1"]} -> {:ok, "deferred"}
      _ -> {:error, :invalid_length}
    end
  end

  @doc false
  @spec metadata_content_type(Plug.Conn.t()) :: String.t() | nil
  def metadata_content_type(conn) do
    conn
    |> get_req_header("upload-metadata")
    |> List.first()
    |> decode_upload_metadata()
    |> Map.get("filetype")
  end

  @doc false
  @spec require_offset_octet_stream(Plug.Conn.t()) :: :ok | {:error, :wrong_content_type}
  def require_offset_octet_stream(conn) do
    case get_req_header(conn, "content-type") do
      [@offset_content_type <> _rest] -> :ok
      _ -> {:error, :wrong_content_type}
    end
  end

  @doc false
  @spec parse_upload_offset(Plug.Conn.t()) :: {:ok, non_neg_integer()} | {:error, :invalid_offset}
  def parse_upload_offset(conn) do
    case get_req_header(conn, "upload-offset") do
      [value] -> parse_non_negative(value, :invalid_offset)
      _ -> {:error, :invalid_offset}
    end
  end

  @doc false
  @spec check_offset_match(term(), term()) :: :ok | {:error, :offset_mismatch}
  def check_offset_match(inbound, current) when inbound == current, do: :ok
  def check_offset_match(_inbound, _current), do: {:error, :offset_mismatch}

  @doc false
  @spec parse_upload_checksum(Plug.Conn.t()) ::
          {:ok, String.t() | nil, binary() | nil} | {:error, :invalid_checksum}
  def parse_upload_checksum(conn) do
    case get_req_header(conn, "upload-checksum") do
      [value] ->
        case String.split(value, " ", parts: 2) do
          [algorithm, hash] when algorithm in ["sha1", "sha256"] ->
            case Base.decode64(hash) do
              {:ok, decoded} -> {:ok, algorithm, decoded}
              :error -> {:error, :invalid_checksum}
            end

          _ ->
            {:error, :invalid_checksum}
        end

      _ ->
        {:ok, nil, nil}
    end
  end

  @doc false
  @spec normalize_length(term()) ::
          {:ok, non_neg_integer() | String.t()} | {:error, :invalid_length}
  def normalize_length("deferred"), do: {:ok, "deferred"}
  def normalize_length(length) when is_integer(length) and length >= 0, do: {:ok, length}
  def normalize_length(_), do: {:error, :invalid_length}

  @doc false
  @spec check_max_size(non_neg_integer() | String.t(), non_neg_integer()) ::
          :ok | {:error, :too_large}
  def check_max_size("deferred", _max_size), do: :ok
  def check_max_size(length, max_size) when length > max_size, do: {:error, :too_large}
  def check_max_size(_length, _max_size), do: :ok

  @doc false
  @spec effective_length(map(), map()) :: non_neg_integer() | nil
  def effective_length(%{upload_length: length}, %{"length" => "deferred"})
      when is_integer(length),
      do: length

  def effective_length(_session, %{"length" => length}) when is_integer(length), do: length
  def effective_length(_session, _payload), do: nil

  @doc false
  @spec status_for(term()) :: pos_integer()
  def status_for(:invalid_token), do: 404
  def status_for(:not_found), do: 404
  def status_for(:expired_token), do: 401
  def status_for(:resume_rejected), do: 401
  def status_for(:gone), do: 410
  def status_for(:wrong_content_type), do: 415
  def status_for(:offset_mismatch), do: 409
  def status_for(:too_large), do: 413
  def status_for(:invalid_offset), do: 400
  def status_for(:invalid_length), do: 400
  def status_for(:invalid_checksum), do: 400
  def status_for(:checksum_mismatch), do: 460
  def status_for(_reason), do: 500

  @doc false
  @spec http_date(DateTime.t() | term()) :: String.t()
  def http_date(%DateTime{} = datetime),
    do: Calendar.strftime(datetime, "%a, %d %b %Y %H:%M:%S GMT")

  def http_date(_), do: ""

  @doc false
  @spec location_base(Plug.Conn.t()) :: String.t()
  def location_base(conn) do
    case conn.script_name do
      [] -> conn.request_path
      segments -> "/" <> Enum.join(segments, "/")
    end
  end

  defp extract_token(%Plug.Conn{path_info: []}), do: nil
  defp extract_token(%Plug.Conn{path_info: segments}), do: List.last(segments)

  defp parse_non_negative(value, error) do
    case Integer.parse(value) do
      {number, ""} when number >= 0 -> {:ok, number}
      _ -> {:error, error}
    end
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
end
