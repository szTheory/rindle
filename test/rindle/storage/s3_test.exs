defmodule Rindle.Storage.S3Test do
  use ExUnit.Case, async: true

  alias Rindle.Storage.S3

  @minio_url System.get_env("RINDLE_MINIO_URL")
  @minio_access_key System.get_env("RINDLE_MINIO_ACCESS_KEY")
  @minio_secret_key System.get_env("RINDLE_MINIO_SECRET_KEY")
  @minio_bucket System.get_env("RINDLE_MINIO_BUCKET")
  @minio_region System.get_env("RINDLE_MINIO_REGION") || "us-east-1"
  @minio_skip_reason (
                       if Enum.any?([@minio_url, @minio_access_key, @minio_secret_key, @minio_bucket], &is_nil/1) do
                         "Skipping MinIO-backed S3 adapter test because one or more RINDLE_MINIO_* environment variables are missing"
                       end
                     )

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
  test "round-trips store, head, download, url, delete, and not_found against MinIO" do
    root =
      Path.join(System.tmp_dir!(), "rindle-s3-test-#{System.unique_integer([:positive])}")

    source = Path.join(root, "source.jpg")
    destination = Path.join(root, "downloaded.jpg")
    key = "integration/#{System.unique_integer([:positive])}.jpg"
    uri = URI.parse(@minio_url)

    File.mkdir_p!(root)
    File.write!(source, "s3-adapter-test-data")

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

    assert {:ok, %{key: ^key}} = S3.store(key, source, opts)
    assert {:ok, %{size: 20, content_type: "image/jpeg"}} = S3.head(key, opts)
    assert {:ok, ^destination} = S3.download(key, destination, opts)
    assert File.read!(destination) == "s3-adapter-test-data"

    assert {:ok, url} = S3.url(key, opts)
    assert String.contains?(url, key)

    assert {:ok, %{url: put_url, method: :put, headers: %{}}} = S3.presigned_put(key, 60, opts)
    assert String.contains?(put_url, key)

    assert {:ok, _result} = S3.delete(key, opts)
    assert {:error, :not_found} = S3.head(key, opts)
  end
end
