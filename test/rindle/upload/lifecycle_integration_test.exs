defmodule Rindle.Upload.LifecycleIntegrationTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo

  import Mox

  alias Rindle.Domain.{MediaAsset, MediaAttachment, MediaUploadSession, MediaVariant}
  alias Rindle.Upload.Broker
  alias Rindle.Workers.{ProcessVariant, PromoteAsset, PurgeStorage}

  @png_1x1 <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48,
             0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x00, 0x00,
             0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, 0x08,
             0xD7, 0x63, 0xF8, 0xFF, 0xFF, 0x3F, 0x00, 0x05, 0xFE, 0x02, 0xFE, 0xDC, 0x44, 0x74,
             0x06, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82>>

  defmodule LocalProfile do
    use Rindle.Profile,
      storage: Rindle.Storage.Local,
      variants: [thumb: [mode: :fit, width: 8, height: 8]],
      allow_mime: ["image/png"],
      max_bytes: 10_485_760
  end

  defmodule MultipartProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [thumb: [mode: :fit, width: 8, height: 8]],
      allow_mime: ["image/png"],
      max_bytes: 10_485_760
  end

  defmodule User do
    defstruct [:id]
  end

  setup do
    root =
      Path.join(System.tmp_dir!(), "rindle-integration-#{System.unique_integer([:positive])}")

    File.mkdir_p!(root)

    previous_local = Application.get_env(:rindle, Rindle.Storage.Local)
    Application.put_env(:rindle, Rindle.Storage.Local, root: root)

    on_exit(fn ->
      case previous_local do
        nil -> Application.delete_env(:rindle, Rindle.Storage.Local)
        value -> Application.put_env(:rindle, Rindle.Storage.Local, value)
      end

      File.rm_rf(root)
    end)

    {:ok, root: root}
  end

  defp write_fixture(root, name) do
    path = Path.join(root, name)
    File.write!(path, @png_1x1)
    path
  end

  defp storage_path_from_url(url) do
    URI.parse(url).path
  end

  @tag :integration
  test "direct upload completes through broker and queues promotion", %{root: root} do
    source = write_fixture(root, "direct-source.png")

    {:ok, session} = Broker.initiate_session(LocalProfile, filename: "direct.png")
    {:ok, %{session: signed, presigned: presigned}} = Broker.sign_url(session.id)

    assert signed.state == "signed"

    upload_path = storage_path_from_url(presigned.url)
    File.mkdir_p!(Path.dirname(upload_path))
    File.cp!(source, upload_path)

    {:ok, %{session: completed, asset: asset}} = Broker.verify_completion(session.id)

    assert completed.state == "completed"
    assert completed.verified_at != nil
    assert asset.state == "validating"
    assert asset.byte_size > 0

    assert Rindle.Repo.get!(MediaUploadSession, session.id).state == "completed"
    assert_enqueued worker: PromoteAsset, args: %{"asset_id" => asset.id}
  end

  @tag :integration
  test "multipart upload completes through broker and queues promotion" do
    expect(Rindle.StorageMock, :capabilities, 4, fn ->
      [:presigned_put, :head, :signed_url, :multipart_upload]
    end)

    expect(Rindle.StorageMock, :initiate_multipart_upload, fn key, part_size, _opts ->
      assert String.ends_with?(key, ".png")
      assert part_size > 0
      {:ok, %{upload_id: "upload-123", upload_key: key, part_size: part_size, part_headers: %{}}}
    end)

    expect(Rindle.StorageMock, :presigned_upload_part, 2, fn key, "upload-123", part_number, _expires_in, _opts ->
      {:ok,
       %{
         url: "https://example.com/#{key}?partNumber=#{part_number}",
         method: :put,
         headers: %{},
         upload_id: "upload-123",
         part_number: part_number
       }}
    end)

    expect(Rindle.StorageMock, :complete_multipart_upload, fn key, "upload-123", parts, _opts ->
      assert [%{etag: "\"etag-1\"", part_number: 1}, %{etag: "\"etag-2\"", part_number: 2}] = parts
      {:ok, %{upload_id: "upload-123", upload_key: key}}
    end)

    expect(Rindle.StorageMock, :head, fn _key, _opts ->
      {:ok, %{size: byte_size(@png_1x1), content_type: "image/png"}}
    end)

    assert {:ok, %{session: session, multipart: multipart}} =
             Rindle.initiate_multipart_upload(MultipartProfile, filename: "direct-multipart.png")

    assert session.state == "initialized"
    assert session.upload_strategy == "multipart"
    assert multipart.upload_id == "upload-123"

    assert {:ok, %{session: signed_session, presigned: part1}} =
             Rindle.sign_multipart_part(session.id, 1)

    assert {:ok, %{session: signed_again, presigned: part2}} =
             Rindle.sign_multipart_part(session.id, 2)

    assert signed_session.state == "signed"
    assert signed_again.state == "signed"
    assert part1.part_number == 1
    assert part2.part_number == 2

    assert {:ok, %{session: completed, asset: asset}} =
             Rindle.complete_multipart_upload(session.id, [
               %{part_number: 1, etag: "\"etag-1\""},
               %{part_number: 2, etag: "\"etag-2\""}
             ])

    assert completed.state == "completed"
    assert completed.verified_at != nil
    assert asset.state == "validating"
    assert_enqueued worker: PromoteAsset, args: %{"asset_id" => asset.id}

    persisted = Rindle.Repo.get!(MediaUploadSession, session.id)
    assert persisted.state == "completed"
    assert persisted.multipart_upload_id == "upload-123"
    assert persisted.multipart_parts == %{
             "parts" => [
               %{"etag" => "\"etag-1\"", "part_number" => 1},
               %{"etag" => "\"etag-2\"", "part_number" => 2}
             ]
           }
  end

  @tag :integration
  test "proxied upload promotes the asset and generates a ready variant", %{root: root} do
    source = write_fixture(root, "proxied-source.png")

    {:ok, asset} =
      Rindle.upload(LocalProfile, %{
        path: source,
        filename: "proxied.png",
        byte_size: File.stat!(source).size
      })

    assert asset.state == "analyzing"
    assert File.exists?(Path.join(root, asset.storage_key))
    assert_enqueued worker: PromoteAsset, args: %{"asset_id" => asset.id}

    assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})

    asset = Rindle.Repo.get!(MediaAsset, asset.id)
    assert asset.state == "available"

    assert_enqueued worker: ProcessVariant,
                    args: %{"asset_id" => asset.id, "variant_name" => "thumb"}

    assert :ok = perform_job(ProcessVariant, %{"asset_id" => asset.id, "variant_name" => "thumb"})

    variant =
      Rindle.Repo.get_by!(MediaVariant, asset_id: asset.id, name: "thumb")

    assert variant.state == "ready"
    assert variant.byte_size > 0
    assert File.exists?(Path.join(root, variant.storage_key))
  end

  @tag :integration
  test "attachment replacement purges the old object and keeps the newer asset", %{root: root} do
    first_source = write_fixture(root, "first.png")
    second_source = write_fixture(root, "second.png")
    user = %User{id: Ecto.UUID.generate()}

    {:ok, first_asset} =
      Rindle.upload(LocalProfile, %{
        path: first_source,
        filename: "first.png",
        byte_size: File.stat!(first_source).size
      })

    {:ok, second_asset} =
      Rindle.upload(LocalProfile, %{
        path: second_source,
        filename: "second.png",
        byte_size: File.stat!(second_source).size
      })

    {:ok, _} = Rindle.attach(first_asset, user, "avatar")
    {:ok, attachment} = Rindle.attach(second_asset, user, "avatar")

    assert attachment.asset_id == second_asset.id

    assert_enqueued worker: PurgeStorage,
                    args: %{"asset_id" => first_asset.id, "profile" => first_asset.profile}

    assert :ok =
             perform_job(PurgeStorage, %{
               "asset_id" => first_asset.id,
               "profile" => first_asset.profile
             })

    assert Rindle.Repo.get(MediaAsset, first_asset.id) == nil
    assert File.exists?(Path.join(root, second_asset.storage_key))
    assert Rindle.Repo.all(MediaAttachment) |> length() == 1
  end

  @tag :integration
  test "detach enqueues purge and removes the asset from storage", %{root: root} do
    source = write_fixture(root, "detach.png")
    user = %User{id: Ecto.UUID.generate()}

    {:ok, asset} =
      Rindle.upload(LocalProfile, %{
        path: source,
        filename: "detach.png",
        byte_size: File.stat!(source).size
      })

    {:ok, _} = Rindle.attach(asset, user, "avatar")

    assert :ok = Rindle.detach(user, "avatar")

    assert_enqueued worker: PurgeStorage,
                    args: %{"asset_id" => asset.id, "profile" => asset.profile}

    assert :ok = perform_job(PurgeStorage, %{"asset_id" => asset.id, "profile" => asset.profile})

    assert Rindle.Repo.all(MediaAttachment) == []
    assert Rindle.Repo.get(MediaAsset, asset.id) == nil
    refute File.exists?(Path.join(root, asset.storage_key))
  end
end

defmodule Rindle.Upload.AdopterRepoLifecycleIntegrationTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Adopter.CanonicalApp.Repo

  alias Rindle.Adopter.CanonicalApp.Repo
  alias Rindle.Domain.{MediaAsset, MediaVariant}
  alias Rindle.Workers.{ProcessVariant, PromoteAsset}

  @moduletag :integration
  @moduletag sandbox_repo: Rindle.Adopter.CanonicalApp.Repo

  @png_1x1 <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48,
             0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x00, 0x00,
             0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, 0x08,
             0xD7, 0x63, 0xF8, 0xFF, 0xFF, 0x3F, 0x00, 0x05, 0xFE, 0x02, 0xFE, 0xDC, 0x44, 0x74,
             0x06, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82>>

  defmodule LocalProfile do
    use Rindle.Profile,
      storage: Rindle.Storage.Local,
      variants: [thumb: [mode: :fit, width: 8, height: 8]],
      allow_mime: ["image/png"],
      max_bytes: 10_485_760
  end

  setup do
    case start_supervised(Rindle.Adopter.CanonicalApp.Repo) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    root =
      Path.join(System.tmp_dir!(), "rindle-adopter-integration-#{System.unique_integer([:positive])}")

    File.mkdir_p!(root)

    previous_local = Application.get_env(:rindle, Rindle.Storage.Local)
    previous_repo = Application.get_env(:rindle, :repo)

    Application.put_env(:rindle, Rindle.Storage.Local, root: root)
    Application.put_env(:rindle, :repo, Rindle.Adopter.CanonicalApp.Repo)

    on_exit(fn ->
      case previous_local do
        nil -> Application.delete_env(:rindle, Rindle.Storage.Local)
        value -> Application.put_env(:rindle, Rindle.Storage.Local, value)
      end

      case previous_repo do
        nil -> Application.delete_env(:rindle, :repo)
        value -> Application.put_env(:rindle, :repo, value)
      end

      File.rm_rf(root)
    end)

    {:ok, root: root}
  end

  defp write_fixture(root, name) do
    path = Path.join(root, name)
    File.write!(path, @png_1x1)
    path
  end

  test "proxied upload promotes the asset and generates a ready variant through the adopter repo", %{
    root: root
  } do
    source = write_fixture(root, "proxied-adopter-source.png")

    {:ok, asset} =
      Rindle.upload(LocalProfile, %{
        path: source,
        filename: "proxied-adopter.png",
        byte_size: File.stat!(source).size
      })

    assert asset.state == "analyzing"
    assert File.exists?(Path.join(root, asset.storage_key))
    assert_enqueued worker: PromoteAsset, args: %{"asset_id" => asset.id}

    assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})

    asset = Repo.get!(MediaAsset, asset.id)
    assert asset.state == "available"

    assert_enqueued worker: ProcessVariant,
                    args: %{"asset_id" => asset.id, "variant_name" => "thumb"}

    assert :ok = perform_job(ProcessVariant, %{"asset_id" => asset.id, "variant_name" => "thumb"})

    variant = Repo.get_by!(MediaVariant, asset_id: asset.id, name: "thumb")

    assert variant.state == "ready"
    assert variant.byte_size > 0
    assert File.exists?(Path.join(root, variant.storage_key))
  end
end
