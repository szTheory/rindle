defmodule Rindle.Storage.StorageAdapterTest do
  use ExUnit.Case, async: true

  @minio_url System.get_env("RINDLE_MINIO_URL")
  @minio_access_key System.get_env("RINDLE_MINIO_ACCESS_KEY")
  @minio_secret_key System.get_env("RINDLE_MINIO_SECRET_KEY")
  @minio_bucket System.get_env("RINDLE_MINIO_BUCKET")
  @minio_region System.get_env("RINDLE_MINIO_REGION") || "us-east-1"
  @minio_skip_reason (
                       if Enum.any?([@minio_url, @minio_access_key, @minio_secret_key, @minio_bucket], &is_nil/1) do
                         "Skipping :minio test because one or more RINDLE_MINIO_* environment variables are missing"
                       else
                         nil
                       end
                     )

  defmodule LocalProfile do
    use Rindle.Profile,
      storage: Rindle.Storage.Local,
      variants: [thumb: [mode: :fit, width: 32]]
  end

  defmodule S3Profile do
    use Rindle.Profile,
      storage: Rindle.Storage.S3,
      variants: [thumb: [mode: :fit, width: 32]]
  end

  test "both adapters implement the storage behaviour callbacks" do
    Code.ensure_loaded!(Rindle.Storage.Local)
    Code.ensure_loaded!(Rindle.Storage.S3)

    callbacks = Rindle.Storage.behaviour_info(:callbacks)

    for {name, arity} <- callbacks do
      assert function_exported?(Rindle.Storage.Local, name, arity)
      assert function_exported?(Rindle.Storage.S3, name, arity)
    end
  end

  test "capability lists are truthful for local and s3 adapters" do
    assert [:local, :presigned_put] == Rindle.Storage.Local.capabilities()
    assert [:presigned_put, :head] == Rindle.Storage.S3.capabilities()
  end

  test "local adapter supports store/url/delete with tagged tuple responses" do
    root = Path.join(System.tmp_dir!(), "rindle-storage-local-#{System.unique_integer([:positive])}")
    key = "assets/asset-1/original.jpg"
    source = Path.join(root, "source.jpg")

    File.mkdir_p!(root)
    File.write!(source, "local-storage-test-data")

    assert {:ok, %{key: ^key, path: stored_path}} = Rindle.Storage.Local.store(key, source, root: root)
    assert File.exists?(stored_path)

    assert {:ok, url} = Rindle.Storage.Local.url(key, root: root)
    assert url == "file://" <> stored_path

    assert {:ok, %{key: ^key}} = Rindle.Storage.Local.delete(key, root: root)
    refute File.exists?(stored_path)
  end

  test "storage failures return tagged error tuples" do
    assert {:error, _reason} =
             Rindle.Storage.Local.store("assets/missing.jpg", "/path/that/does/not/exist", root: "/tmp")

    assert {:error, :missing_bucket} = Rindle.Storage.S3.store("assets/a1.jpg", "/tmp/none", [])
  end

  test "profile module dispatch selects adapters per profile, not global config" do
    assert Rindle.storage_adapter_for(LocalProfile) == Rindle.Storage.Local
    assert Rindle.storage_adapter_for(S3Profile) == Rindle.Storage.S3
  end

  @tag :minio
  @tag skip: @minio_skip_reason
  test "s3 adapter integration hook stores and deletes against MinIO when configured" do
    root = Path.join(System.tmp_dir!(), "rindle-storage-minio-#{System.unique_integer([:positive])}")
    source = Path.join(root, "source.jpg")
    key = "integration/#{System.unique_integer([:positive])}.jpg"
    uri = URI.parse(@minio_url)

    File.mkdir_p!(root)
    File.write!(source, "minio-integration-data")

    opts = [
      bucket: @minio_bucket,
      content_type: "image/jpeg",
      aws_config: [
        access_key_id: @minio_access_key,
        secret_access_key: @minio_secret_key,
        scheme: uri.scheme |> to_string() |> String.to_atom(),
        host: uri.host,
        port: uri.port,
        region: @minio_region
      ]
    ]

    assert {:ok, _} = Rindle.Storage.S3.store(key, source, opts)
    assert {:ok, _} = Rindle.Storage.S3.url(key, opts)
    assert {:ok, _} = Rindle.Storage.S3.delete(key, opts)
  end
end
