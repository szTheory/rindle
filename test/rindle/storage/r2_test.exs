defmodule Rindle.Storage.R2Test do
  use ExUnit.Case, async: true

  alias Rindle.Storage.Capabilities
  alias Rindle.Storage.S3

  @multipart_min_part_size 5 * 1024 * 1024

  @r2_url System.get_env("RINDLE_R2_URL")
  @r2_access_key System.get_env("RINDLE_R2_ACCESS_KEY_ID")
  @r2_secret_key System.get_env("RINDLE_R2_SECRET_ACCESS_KEY")
  @r2_bucket System.get_env("RINDLE_R2_BUCKET")
  @r2_region System.get_env("RINDLE_R2_REGION") || "auto"
  @r2_skip_reason (
                    if Enum.any?([@r2_url, @r2_access_key, @r2_secret_key, @r2_bucket], &is_nil/1) do
                      "Skipping Cloudflare R2 contract test because one or more RINDLE_R2_* environment variables are missing. This lane is opt-in/manual only and is not part of default CI."
                    end
                  )

  @tag :r2
  @tag skip: @r2_skip_reason
  test "R2 contract stays on the shipped S3 adapter seam" do
    uri = URI.parse(@r2_url)
    capabilities = S3.capabilities()

    assert :presigned_put in capabilities
    assert {:error, {:upload_unsupported, :resumable_upload}} =
             Capabilities.require_upload(S3, :resumable_upload)

    key = "r2/presigned/#{System.unique_integer([:positive])}.txt"
    body = "r2-contract-test-data"
    opts = r2_opts(uri, "text/plain")

    assert {:ok, %{url: put_url, method: :put, headers: %{}}} = S3.presigned_put(key, 60, opts)
    assert String.contains?(put_url, key)

    :ok = put_to_presigned_url(put_url, body)

    assert {:ok, %{size: size, content_type: "text/plain"}} = S3.head(key, opts)
    assert size == byte_size(body)

    if :signed_url in capabilities do
      assert {:ok, signed_url} = S3.url(key, opts)
      assert String.contains?(signed_url, key)
    end

    assert {:ok, _result} = S3.delete(key, opts)
    assert {:error, :not_found} = S3.head(key, opts)

    if :multipart_upload in capabilities do
      multipart_key = "r2/multipart/#{System.unique_integer([:positive])}.bin"
      part1 = String.duplicate("a", @multipart_min_part_size)
      part2 = "r2-multipart-part-two"

      assert {:ok, %{upload_id: upload_id, upload_key: ^multipart_key, part_size: part_size}} =
               S3.initiate_multipart_upload(multipart_key, @multipart_min_part_size, opts)

      assert part_size == @multipart_min_part_size

      assert {:ok, %{url: part1_url, part_number: 1, upload_id: ^upload_id}} =
               S3.presigned_upload_part(multipart_key, upload_id, 1, 60, opts)

      assert {:ok, %{url: part2_url, part_number: 2, upload_id: ^upload_id}} =
               S3.presigned_upload_part(multipart_key, upload_id, 2, 60, opts)

      etag1 = put_part_to_presigned_url(part1_url, part1)
      etag2 = put_part_to_presigned_url(part2_url, part2)

      assert {:ok, %{upload_id: ^upload_id, upload_key: ^multipart_key}} =
               S3.complete_multipart_upload(
                 multipart_key,
                 upload_id,
                 [
                   %{part_number: 1, etag: etag1},
                   %{part_number: 2, etag: etag2}
                 ],
                 opts
               )

      assert {:ok, %{size: multipart_size}} = S3.head(multipart_key, opts)
      assert multipart_size == byte_size(part1) + byte_size(part2)

      assert {:ok, _result} = S3.delete(multipart_key, opts)
      assert {:error, :not_found} = S3.head(multipart_key, opts)
    end
  end

  defp r2_opts(uri, content_type) do
    [
      bucket: @r2_bucket,
      content_type: content_type,
      aws_config: [
        access_key_id: @r2_access_key,
        secret_access_key: @r2_secret_key,
        scheme: "#{uri.scheme}://",
        host: uri.host,
        port: uri.port,
        region: @r2_region
      ]
    ]
  end

  defp put_part_to_presigned_url(presigned_url, body) do
    request = {String.to_charlist(presigned_url), [], ~c"application/octet-stream", body}

    case :httpc.request(:put, request, [], []) do
      {:ok, {{_http_version, status, _reason}, response_headers, _resp_body}} when status in 200..299 ->
        response_headers
        |> Enum.find_value(fn
          {header, value} when header in [~c"etag", ~c"ETag"] -> List.to_string(value)
          _other -> nil
        end)
        |> case do
          nil -> flunk("R2 multipart UploadPart response did not include an ETag header")
          etag -> etag
        end

      {:ok, {{_http_version, status, reason}, _response_headers, resp_body}} ->
        flunk("R2 multipart UploadPart failed with status #{status} #{reason}: #{inspect(resp_body)}")

      {:error, reason} ->
        flunk("R2 multipart UploadPart failed: #{inspect(reason)}")
    end
  end

  defp put_to_presigned_url(presigned_url, body) do
    request = {String.to_charlist(presigned_url), [], ~c"application/octet-stream", body}

    case :httpc.request(:put, request, [], []) do
      {:ok, {{_http_version, status, _reason}, _response_headers, _resp_body}}
      when status in 200..299 ->
        :ok

      {:ok, {{_http_version, status, reason}, _response_headers, resp_body}} ->
        flunk("R2 presigned PUT failed with status #{status} #{reason}: #{inspect(resp_body)}")

      {:error, reason} ->
        flunk("R2 presigned PUT failed: #{inspect(reason)}")
    end
  end
end
