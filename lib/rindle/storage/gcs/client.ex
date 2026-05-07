defmodule Rindle.Storage.GCS.Client do
  @moduledoc false

  # Hand-rolled Finch JSON-API client for Google Cloud Storage.
  #
  # See:
  # - .planning/phases/37-gcs-adapter-foundation/37-CONTEXT.md (D-01, D-03, D-09)
  # - .planning/phases/37-gcs-adapter-foundation/37-RESEARCH.md
  #   (Pattern 2 — Goth + rescue ArgumentError; Pattern 3 — uploadType=multipart;
  #    Pattern 4 — HEAD via alt=json; Pitfall 1 — `/` URL encoding;
  #    §Section 2 — size-as-string parse; Pitfall 6 — Goth ArgumentError rescue)

  @default_base_url "https://storage.googleapis.com"

  @type head_ok :: %{size: non_neg_integer(), content_type: String.t() | nil}

  @spec head(bucket :: String.t(), key :: String.t(), opts :: keyword()) ::
          {:ok, head_ok()}
          | {:error,
             :not_found
             | :goth_unconfigured
             | {:gcs_http_error, %{status: integer(), body: binary()}}
             | term()}
  def head(bucket, key, opts) do
    with {:ok, headers} <- authed_headers(opts) do
      url = url_for(:metadata, bucket, key, opts)
      req = Finch.build(:get, url, [{"accept", "application/json"} | headers])

      case finch_request(req, opts) do
        {:ok, %Finch.Response{status: 200, body: body}} ->
          json = Jason.decode!(body)
          {:ok, %{size: parse_size(json["size"]), content_type: json["contentType"]}}

        {:ok, %Finch.Response{status: 404}} ->
          {:error, :not_found}

        {:ok, %Finch.Response{status: status, body: body}} ->
          {:error, {:gcs_http_error, %{status: status, body: body}}}

        {:error, exception} ->
          {:error, exception}
      end
    end
  end

  @spec store(
          bucket :: String.t(),
          key :: String.t(),
          source_path :: Path.t(),
          opts :: keyword()
        ) ::
          {:ok, %{key: String.t(), bucket: String.t(), response: term()}}
          | {:error, term()}
  def store(bucket, key, source_path, opts) do
    with {:ok, auth_headers} <- authed_headers(opts) do
      content_type = Keyword.get(opts, :content_type, "application/octet-stream")
      content_disposition = Keyword.get(opts, :content_disposition)

      boundary = "rindle_gcs_" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)

      metadata =
        %{"name" => key, "contentType" => content_type}
        |> maybe_put("contentDisposition", content_disposition)

      metadata_json = Jason.encode!(metadata)

      file_stream =
        Stream.concat([
          [
            "--#{boundary}\r\n",
            "Content-Type: application/json; charset=UTF-8\r\n\r\n",
            metadata_json,
            "\r\n--#{boundary}\r\n",
            "Content-Type: #{content_type}\r\n\r\n"
          ],
          File.stream!(source_path, [], 8192),
          ["\r\n--#{boundary}--\r\n"]
        ])

      url = url_for(:upload, bucket, key, opts)
      headers = [{"content-type", "multipart/related; boundary=#{boundary}"} | auth_headers]
      req = Finch.build(:post, url, headers, {:stream, file_stream})

      case finch_request(req, opts) do
        {:ok, %Finch.Response{status: status, body: body}} when status in 200..299 ->
          {:ok, %{key: key, bucket: bucket, response: Jason.decode!(body)}}

        {:ok, %Finch.Response{status: status, body: body}} ->
          {:error, {:gcs_http_error, %{status: status, body: body}}}

        {:error, exception} ->
          {:error, exception}
      end
    end
  end

  @spec download(
          bucket :: String.t(),
          key :: String.t(),
          destination_path :: Path.t(),
          opts :: keyword()
        ) ::
          {:ok, Path.t()} | {:error, :not_found | :goth_unconfigured | term()}
  def download(bucket, key, destination_path, opts) do
    with {:ok, headers} <- authed_headers(opts),
         :ok <- File.mkdir_p(Path.dirname(destination_path)) do
      url = url_for(:media, bucket, key, opts)
      req = Finch.build(:get, url, headers)
      finch = finch_name(opts)

      result =
        File.open(destination_path, [:write, :binary], fn file ->
          Finch.stream(req, finch, :ok, fn
            {:status, status}, _acc when status in 200..299 ->
              :ok

            {:status, 404}, _acc ->
              :not_found

            {:status, status}, _acc ->
              {:gcs_http_error, status}

            {:headers, _headers}, acc ->
              acc

            {:data, chunk}, acc ->
              if acc == :ok, do: IO.binwrite(file, chunk)
              acc
          end)
        end)

      case result do
        {:ok, {:ok, :ok}} ->
          {:ok, destination_path}

        {:ok, {:ok, :not_found}} ->
          _ = File.rm(destination_path)
          {:error, :not_found}

        {:ok, {:ok, {:gcs_http_error, status}}} ->
          _ = File.rm(destination_path)
          {:error, {:gcs_http_error, %{status: status, body: ""}}}

        {:ok, {:error, exception}} ->
          _ = File.rm(destination_path)
          {:error, exception}

        {:error, exception} ->
          {:error, exception}
      end
    end
  rescue
    exception -> {:error, exception}
  end

  @spec delete(bucket :: String.t(), key :: String.t(), opts :: keyword()) ::
          {:ok, %{key: String.t()}} | {:error, :not_found | :goth_unconfigured | term()}
  def delete(bucket, key, opts) do
    with {:ok, headers} <- authed_headers(opts) do
      url = url_for(:metadata, bucket, key, opts)
      req = Finch.build(:delete, url, headers)

      case finch_request(req, opts) do
        {:ok, %Finch.Response{status: 204}} ->
          {:ok, %{key: key}}

        {:ok, %Finch.Response{status: 200}} ->
          {:ok, %{key: key}}

        {:ok, %Finch.Response{status: 404}} ->
          {:error, :not_found}

        {:ok, %Finch.Response{status: status, body: body}} ->
          {:error, {:gcs_http_error, %{status: status, body: body}}}

        {:error, exception} ->
          {:error, exception}
      end
    end
  end

  ## URL helpers

  # RESEARCH Pitfall 1 — `URI.encode/2` with `&URI.char_unreserved?/1` encodes
  # `/` as `%2F` so multi-segment object names hit the right GCS path. Plain
  # `URI.encode/1` would leave `/` alone and 404.
  defp url_for(:metadata, bucket, key, opts) do
    "#{base_url(opts)}/storage/v1/b/#{bucket}/o/#{URI.encode(key, &URI.char_unreserved?/1)}"
  end

  defp url_for(:media, bucket, key, opts) do
    url_for(:metadata, bucket, key, opts) <> "?alt=media"
  end

  defp url_for(:upload, bucket, _key, opts) do
    "#{base_url(opts)}/upload/storage/v1/b/#{bucket}/o?uploadType=multipart"
  end

  defp base_url(opts) do
    Keyword.get(opts, :base_url) ||
      Application.get_env(:rindle, Rindle.Storage.GCS, [])[:base_url] ||
      @default_base_url
  end

  defp finch_name(opts) do
    Keyword.get(opts, :finch) ||
      Application.get_env(:rindle, Rindle.Storage.GCS, [])[:finch] ||
      raise ArgumentError, "config :rindle, Rindle.Storage.GCS, finch: MyApp.Finch is required"
  end

  ## Auth helpers

  defp authed_headers(opts) do
    case Keyword.get(opts, :token) do
      token when is_binary(token) ->
        {:ok, [{"authorization", "Bearer #{token}"}]}

      nil ->
        case fetch_token(opts) do
          {:ok, %{token: token, type: type}} ->
            {:ok, [{"authorization", "#{type} #{token}"}]}

          {:error, :goth_unconfigured} ->
            {:error, :goth_unconfigured}

          {:error, _other} ->
            {:error, :goth_unconfigured}
        end
    end
  end

  # RESEARCH Pitfall 6: Goth.fetch/1 raises ArgumentError when the named
  # instance is not in the supervision tree (NOT `:exit, :noproc`). The
  # load-bearing rescue is `rescue ArgumentError`. `catch :exit, _reason`
  # is retained as defense-in-depth for older Goth versions or unexpected
  # exit propagation but is NOT the primary trap.
  defp fetch_token(opts) do
    name = goth_name(opts)

    if Code.ensure_loaded?(Goth) do
      try do
        case Goth.fetch(name) do
          {:ok, token} -> {:ok, %{token: token.token, type: token.type}}
          {:error, _exception} -> {:error, :goth_unconfigured}
        end
      rescue
        ArgumentError -> {:error, :goth_unconfigured}
      catch
        :exit, _reason -> {:error, :goth_unconfigured}
      end
    else
      {:error, :goth_unconfigured}
    end
  end

  defp goth_name(opts) do
    Keyword.get(opts, :goth) ||
      Application.get_env(:rindle, Rindle.Storage.GCS, [])[:goth] ||
      raise ArgumentError,
            "config :rindle, Rindle.Storage.GCS, goth: MyApp.Goth is required (or pass :token in opts for tests)"
  end

  ## HTTP envelope (mirrors S3 `defp request/2` rescue shape)

  defp finch_request(req, opts) do
    Finch.request(req, finch_name(opts))
  rescue
    exception -> {:error, exception}
  end

  ## Helpers — mirrors lib/rindle/storage/s3.ex:154-163 (parse_size/1)
  ## RESEARCH §Section 2 — GCS JSON API returns `size` as STRING; parse to integer.

  defp parse_size(nil), do: 0

  defp parse_size(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      _ -> 0
    end
  end

  defp parse_size(val) when is_integer(val), do: val

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
