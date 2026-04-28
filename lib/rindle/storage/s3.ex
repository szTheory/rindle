defmodule Rindle.Storage.S3 do
  @moduledoc """
  S3-compatible storage adapter powered by ExAws.
  """

  @behaviour Rindle.Storage

  alias ExAws.S3

  @impl true
  def store(key, source_path, opts) do
    # Return shape mirrors Rindle.Storage.Local.store/3 — `%{key: key, ...}` —
    # so consumers of the Storage behaviour (e.g. Rindle.Workers.ProcessVariant)
    # can read `storage_meta.key` uniformly across adapters. Surfaced by the
    # adopter lifecycle test in Plan 05-04 (CI-08).
    with {:ok, bucket} <- bucket(opts),
         {:ok, body} <- File.read(source_path),
         {:ok, response} <-
           request(S3.put_object(bucket, key, body, object_opts(opts)), opts) do
      {:ok, %{key: key, bucket: bucket, response: response}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def download(key, destination_path, opts) do
    # ExAws.S3.download_file returns an ExAws.S3.Download struct; ExAws.request
    # on a Download struct returns {:ok, :done} on success, NOT bare :ok.
    # Surfaced by the adopter lifecycle test in Plan 05-04 (CI-08); this was
    # a latent Rule-1 bug (Local adapter is used everywhere upstream so no
    # downstream test exercised this S3-specific path until now).
    with {:ok, bucket} <- bucket(opts),
         :ok <- File.mkdir_p(Path.dirname(destination_path)),
         {:ok, _result} <-
           S3.download_file(bucket, key, destination_path)
           |> request(opts) do
      {:ok, destination_path}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete(key, opts) do
    with {:ok, bucket} <- bucket(opts),
         {:ok, result} <- request(S3.delete_object(bucket, key), opts) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def url(key, opts) do
    with {:ok, bucket} <- bucket(opts) do
      S3.presigned_url(s3_config(opts), :get, bucket, key,
        expires_in: Keyword.get(opts, :expires_in, Rindle.Config.signed_url_ttl_seconds())
      )
    end
  end

  @impl true
  def presigned_put(key, expires_in, opts) do
    with {:ok, bucket} <- bucket(opts),
         {:ok, url} <-
           S3.presigned_url(s3_config(opts), :put, bucket, key, expires_in: expires_in) do
      {:ok, %{url: url, method: :put, headers: %{}}}
    end
  end

  @impl true
  def initiate_multipart_upload(key, part_size, opts) do
    with {:ok, bucket} <- bucket(opts),
         {:ok, %{body: %{upload_id: upload_id}}} <-
           request(S3.initiate_multipart_upload(bucket, key, object_opts(opts)), opts) do
      {:ok, %{upload_id: upload_id, upload_key: key, bucket: bucket, part_size: part_size}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def presigned_upload_part(key, upload_id, part_number, expires_in, opts) do
    with {:ok, bucket} <- bucket(opts),
         {:ok, url} <-
           S3.presigned_url(s3_config(opts), :put, bucket, key,
             expires_in: expires_in,
             query_params: [
               {"partNumber", Integer.to_string(part_number)},
               {"uploadId", upload_id}
             ]
           ) do
      {:ok,
       %{
         url: url,
         method: :put,
         headers: %{},
         part_number: part_number,
         upload_id: upload_id
       }}
    end
  end

  @impl true
  def complete_multipart_upload(key, upload_id, parts, opts) do
    with {:ok, bucket} <- bucket(opts),
         {:ok, %{body: body}} <-
           request(S3.complete_multipart_upload(bucket, key, upload_id, normalize_parts(parts)), opts) do
      {:ok, Map.merge(%{upload_id: upload_id, upload_key: key, bucket: bucket}, body)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def abort_multipart_upload(key, upload_id, opts) do
    with {:ok, bucket} <- bucket(opts),
         {:ok, response} <- request(S3.abort_multipart_upload(bucket, key, upload_id), opts) do
      {:ok, %{response: response, upload_id: upload_id, upload_key: key, bucket: bucket}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def head(key, opts) do
    with {:ok, bucket} <- bucket(opts) do
      handle_head_response(request(S3.head_object(bucket, key), opts))
    end
  end

  defp handle_head_response({:ok, %{headers: headers}}) do
    # Normalize headers to lowercase to handle varying S3 provider implementations
    normalized = Enum.into(headers, %{}, fn {k, v} -> {String.downcase(k), v} end)

    {:ok,
     %{
       size: parse_size(Map.get(normalized, "content-length")),
       content_type: Map.get(normalized, "content-type")
     }}
  end

  defp handle_head_response({:error, %{status_code: 404}}), do: {:error, :not_found}
  defp handle_head_response({:error, {:http_error, 404, _response}}), do: {:error, :not_found}
  defp handle_head_response({:error, reason}), do: {:error, reason}

  @impl true
  def capabilities, do: [:presigned_put, :head, :signed_url, :multipart_upload]

  defp parse_size(nil), do: 0

  defp parse_size(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      _ -> 0
    end
  end

  defp parse_size(val) when is_integer(val), do: val

  defp normalize_parts(parts) do
    Enum.map(parts, fn
      %{part_number: part_number, etag: etag} -> {part_number, etag}
      %{"part_number" => part_number, "etag" => etag} -> {part_number, etag}
      {part_number, etag} -> {part_number, etag}
    end)
  end

  defp bucket(opts) do
    case Keyword.get(opts, :bucket) || Application.get_env(:rindle, __MODULE__, [])[:bucket] do
      nil -> {:error, :missing_bucket}
      bucket -> {:ok, bucket}
    end
  end

  defp request(operation, opts) do
    ExAws.request(operation, Keyword.get(opts, :aws_config, []))
  rescue
    exception -> {:error, exception}
  end

  defp s3_config(opts) do
    ExAws.Config.new(:s3, Keyword.get(opts, :aws_config, []))
  end

  defp object_opts(opts) do
    case Keyword.get(opts, :content_type) do
      nil -> []
      content_type -> [content_type: content_type]
    end
  end
end
