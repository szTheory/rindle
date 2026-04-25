defmodule Rindle.Storage.S3 do
  @moduledoc """
  S3-compatible storage adapter powered by ExAws.
  """

  @behaviour Rindle.Storage

  alias ExAws.S3

  @impl true
  def store(key, source_path, opts) do
    with {:ok, bucket} <- bucket(opts),
         {:ok, body} <- File.read(source_path),
         {:ok, result} <- request(S3.put_object(bucket, key, body, object_opts(opts)), opts) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def download(key, destination_path, opts) do
    with {:ok, bucket} <- bucket(opts),
         :ok <- File.mkdir_p(Path.dirname(destination_path)),
         :ok <-
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
         {:ok, url} <- S3.presigned_url(s3_config(opts), :put, bucket, key, expires_in: expires_in) do
      {:ok, %{url: url, method: :put, headers: %{}}}
    end
  end

  @impl true
  def head(key, opts) do
    with {:ok, bucket} <- bucket(opts) do
      case request(S3.head_object(bucket, key), opts) do
        {:ok, %{headers: headers}} ->
          # Normalize headers to lowercase to handle varying S3 provider implementations
          normalized = Enum.into(headers, %{}, fn {k, v} -> {String.downcase(k), v} end)

          {:ok,
           %{
             size: parse_size(Map.get(normalized, "content-length")),
             content_type: Map.get(normalized, "content-type")
           }}

        {:error, %{status_code: 404}} ->
          {:error, :not_found}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @impl true
  def capabilities, do: [:presigned_put, :head]

  defp parse_size(nil), do: 0

  defp parse_size(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      _ -> 0
    end
  end

  defp parse_size(val) when is_integer(val), do: val

  defp bucket(opts) do
    case Keyword.get(opts, :bucket) || Application.get_env(:rindle, __MODULE__, [])[:bucket] do
      nil -> {:error, :missing_bucket}
      bucket -> {:ok, bucket}
    end
  end

  defp request(operation, opts) do
    ExAws.request(operation, s3_config(opts))
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
