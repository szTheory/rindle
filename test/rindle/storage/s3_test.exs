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
  test "round-trips the upload_part_stream/complete_part_stream tus callbacks against MinIO" do
    uri = URI.parse(@minio_url)
    key = "tus-callback/#{System.unique_integer([:positive])}.bin"
    session_id = "tus-callback-#{System.unique_integer([:positive])}"

    # An isolated tail-buffer root so the server-mediated tail file for THIS test
    # never collides with the global Rindle.tmp/ root or a sibling run.
    root =
      Path.join(System.tmp_dir!(), "rindle-tus-callback-#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf(root) end)

    opts = [
      bucket: @minio_bucket,
      content_type: "application/octet-stream",
      session_id: session_id,
      root: root,
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
    assert :tus_upload in S3.capabilities()

    # First PATCH: a > 5 MiB chunk. The tail buffer drains exactly one full
    # @multipart_min_part_size part and UploadParts it server-side; the leftover
    # (< 5 MiB) stays buffered until completion.
    head_chunk = String.duplicate("h", @multipart_min_part_size + 1_000_000)
    head_temp = Path.join(root, "patch-1.bin")
    File.mkdir_p!(root)
    File.write!(head_temp, head_chunk)

    assert {:ok, state1} = S3.upload_part_stream(key, head_temp, 0, %{}, opts)
    assert is_binary(state1.upload_id) and state1.upload_id != ""
    assert state1.offset == byte_size(head_chunk)
    assert [%{part_number: 1, etag: etag1} | _] = state1.parts
    assert is_binary(etag1) and etag1 != ""

    # Second PATCH: a sub-5-MiB chunk. Below the floor, so NO new part is sliced
    # here — it accumulates onto the buffered leftover for the final flush.
    tail_chunk = String.duplicate("t", 1_000_000)
    tail_temp = Path.join(root, "patch-2.bin")
    File.write!(tail_temp, tail_chunk)

    assert {:ok, state2} =
             S3.upload_part_stream(key, tail_temp, byte_size(head_chunk), state1, opts)

    assert state2.upload_id == state1.upload_id
    assert state2.offset == byte_size(head_chunk) + byte_size(tail_chunk)

    # complete_part_stream flushes the remaining buffered tail as the final part
    # (no 5 MiB floor on the last part) and completes the multipart upload.
    assert {:ok, %{upload_key: ^key}} = S3.complete_part_stream(key, nil, state2, opts)

    # The assembled object's size equals every byte we streamed across both PATCHes.
    assert {:ok, %{size: size}} = S3.head(key, opts)
    assert size == byte_size(head_chunk) + byte_size(tail_chunk)

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

  @tag :minio
  @tag skip: @minio_skip_reason
  test "concatenate/3 correctly merges chunks via UploadPartCopy and deletes sources" do
    uri = URI.parse(@minio_url)
    key = "concatenate/#{System.unique_integer([:positive])}-final.bin"
    src1_key = "concatenate/#{System.unique_integer([:positive])}-src1.bin"
    src2_key = "concatenate/#{System.unique_integer([:positive])}-src2.bin"

    opts = [
      bucket: @minio_bucket,
      aws_config: [
        access_key_id: @minio_access_key,
        secret_access_key: @minio_secret_key,
        scheme: "http://",
        host: uri.host,
        port: uri.port,
        region: @minio_region
      ]
    ]

    root =
      Path.join(System.tmp_dir!(), "rindle-s3-test-concat-#{System.unique_integer([:positive])}")

    File.mkdir_p!(root)

    path1 = Path.join(root, "src1.bin")
    path2 = Path.join(root, "src2.bin")

    # MinIO requires S3 multipart parts to be at least 5 MiB for UploadPartCopy too
    File.write!(path1, String.duplicate("a", @multipart_min_part_size))
    File.write!(path2, "hello world")

    assert {:ok, _} = S3.store(src1_key, path1, opts)
    assert {:ok, _} = S3.store(src2_key, path2, opts)

    assert {:ok, %{key: ^key}} = S3.concatenate(key, [src1_key, src2_key], opts)

    assert {:ok, %{size: size}} = S3.head(key, opts)
    assert size == @multipart_min_part_size + 11

    # verify sources are deleted
    assert {:error, :not_found} = S3.head(src1_key, opts)
    assert {:error, :not_found} = S3.head(src2_key, opts)

    assert {:ok, _result} = S3.delete(key, opts)
    File.rm_rf!(root)
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
