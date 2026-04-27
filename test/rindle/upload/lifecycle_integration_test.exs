defmodule Rindle.Upload.LifecycleIntegrationTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo

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
