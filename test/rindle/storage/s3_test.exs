defmodule Rindle.Storage.S3Test do
  use ExUnit.Case, async: true

  alias Rindle.Storage.S3

  @multipart_min_part_size 5 * 1024 * 1024

  @minio_url System.get_env("RINDLE_MINIO_URL")
  @minio_access_key System.get_env("RINDLE_MINIO_ACCESS_KEY")
  @minio_secret_key System.get_env("RINDLE_MINIO_SECRET_KEY")
  @minio_bucket System.get_env("RINDLE_MINIO_BUCKET")
  @minio_region System.get_env("RINDLE_MINIO_REGION") || "us-east-1"
  @minio_skip_reason (if Enum.any?(
                           [@minio_url, @minio_access_key, @minio_secret_key, @minio_bucket],
                           &is_nil/1
                         ) do
                        "Skipping MinIO-backed S3 adapter test because one or more RINDLE_MINIO_* environment variables are missing"
                      end)

  test "returns missing_bucket when no bucket is configured" do
    assert {:error, :missing_bucket} = S3.store("assets/a1.jpg", "/tmp/missing", [])
    assert {:error, :missing_bucket} = S3.delete("assets/a1.jpg", [])
    assert {:error, :missing_bucket} = S3.url("assets/a1.jpg", [])
    assert {:error, :missing_bucket} = S3.presigned_put("assets/a1.jpg", 60, [])
    assert {:error, :missing_bucket} = S3.download("assets/a1.jpg", "/tmp/out", [])
    assert {:error, :missing_bucket} = S3.head("assets/a1.jpg", [])
  end

  @tag :minio
  @tag skip: @minio_skip_reason
  test "round-trips multipart initiate, upload parts, complete, and head against MinIO" do
    uri = URI.parse(@minio_url)
    key = "multipart/#{System.unique_integer([:positive])}.bin"

    opts = [
      bucket: @minio_bucket,
      content_type: "application/octet-stream",
      aws_config: [
        access_key_id: @minio_access_key,
        secret_access_key: @minio_secret_key,
        scheme: "http://",
        host: uri.host,
        port: uri.port,
        region: @minio_region
      ]
    ]

    assert_upload_capabilities!(S3.capabilities())

    part1 = String.duplicate("a", @multipart_min_part_size)
    part2 = "multipart-part-two"

    assert {:ok, %{upload_id: upload_id, upload_key: ^key, part_size: part_size}} =
             S3.initiate_multipart_upload(key, @multipart_min_part_size, opts)

    assert part_size == @multipart_min_part_size

    assert {:ok, %{url: part1_url, part_number: 1, upload_id: ^upload_id}} =
             S3.presigned_upload_part(key, upload_id, 1, 60, opts)

    assert {:ok, %{url: part2_url, part_number: 2, upload_id: ^upload_id}} =
             S3.presigned_upload_part(key, upload_id, 2, 60, opts)

    etag1 = put_part_to_presigned_url(part1_url, part1)
    etag2 = put_part_to_presigned_url(part2_url, part2)

    assert {:ok, %{upload_id: ^upload_id, upload_key: ^key}} =
             S3.complete_multipart_upload(
               key,
               upload_id,
               [
                 %{part_number: 1, etag: etag1},
                 %{part_number: 2, etag: etag2}
               ],
               opts
             )

    assert {:ok, %{size: size}} = S3.head(key, opts)
    assert size == byte_size(part1) + byte_size(part2)

    assert {:ok, _result} = S3.delete(key, opts)
  end

  @tag :minio
  @tag skip: @minio_skip_reason
  test "round-trips presigned put, head, download, url, delete, and not_found against MinIO" do
    root =
      Path.join(System.tmp_dir!(), "rindle-s3-test-#{System.unique_integer([:positive])}")

    destination = Path.join(root, "downloaded.jpg")
    key = "integration/#{System.unique_integer([:positive])}.jpg"
    uri = URI.parse(@minio_url)
    body = "s3-adapter-test-data"

    File.mkdir_p!(root)

    opts = [
      bucket: @minio_bucket,
      content_type: "image/jpeg",
      aws_config: [
        access_key_id: @minio_access_key,
        secret_access_key: @minio_secret_key,
        scheme: "http://",
        host: uri.host,
        port: uri.port,
        region: @minio_region
      ]
    ]

    assert_upload_capabilities!(S3.capabilities())

    assert {:ok, %{url: put_url, method: :put, headers: %{}}} = S3.presigned_put(key, 60, opts)
    assert String.contains?(put_url, key)

    :ok = put_to_presigned_url(put_url, body)

    assert {:ok, %{size: 20, content_type: "image/jpeg"}} = S3.head(key, opts)
    assert {:ok, ^destination} = S3.download(key, destination, opts)
    assert File.read!(destination) == body

    assert {:ok, url} = S3.url(key, opts)
    assert String.contains?(url, key)

    assert {:ok, _result} = S3.delete(key, opts)
    assert {:error, :not_found} = S3.head(key, opts)
  end

  defp put_part_to_presigned_url(presigned_url, body) do
    request = {String.to_charlist(presigned_url), [], ~c"application/octet-stream", body}

    case :httpc.request(:put, request, [], []) do
      {:ok, {{_http_version, status, _reason}, response_headers, _resp_body}}
      when status in 200..299 ->
        response_headers
        |> Enum.find_value(fn
          {header, value} when header in [~c"etag", ~c"ETag"] -> List.to_string(value)
          _other -> nil
        end)
        |> case do
          nil -> flunk("multipart UploadPart response did not include an ETag header")
          etag -> etag
        end

      {:ok, {{_http_version, status, reason}, _response_headers, resp_body}} ->
        flunk(
          "multipart UploadPart failed with status #{status} #{reason}: #{inspect(resp_body)}"
        )

      {:error, reason} ->
        flunk("multipart UploadPart failed: #{inspect(reason)}")
    end
  end

  defp put_to_presigned_url(presigned_url, body) do
    request = {String.to_charlist(presigned_url), [], ~c"application/octet-stream", body}

    case :httpc.request(:put, request, [], []) do
      {:ok, {{_http_version, status, _reason}, _response_headers, _resp_body}}
      when status in 200..299 ->
        :ok

      {:ok, {{_http_version, status, reason}, _response_headers, resp_body}} ->
        flunk("presigned PUT failed with status #{status} #{reason}: #{inspect(resp_body)}")

      {:error, reason} ->
        flunk("presigned PUT failed: #{inspect(reason)}")
    end
  end

  defp assert_upload_capabilities!(capabilities) do
    assert :presigned_put in capabilities
    assert :multipart_upload in capabilities
  end
end
