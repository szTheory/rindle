defmodule Rindle.Workers.PurgeStorageTest do
  use Rindle.DataCase, async: true
  use Oban.Testing, repo: Rindle.Repo
  import Mox

  alias Rindle.Domain.{MediaAsset, MediaAttachment, MediaVariant}
  alias Rindle.Workers.PurgeStorage

  setup :set_mox_from_context
  setup :verify_on_exit!

  defmodule TestProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: []
  end

  test "deletes variants and the asset and completes successfully" do
    asset =
      %MediaAsset{}
      |> MediaAsset.changeset(%{
        state: "available",
        profile: to_string(TestProfile),
        storage_key: "assets/asset-1/original.jpg"
      })
      |> Rindle.Repo.insert!()

    variant =
      %MediaVariant{}
      |> MediaVariant.changeset(%{
        asset_id: asset.id,
        name: "thumb",
        state: "ready",
        recipe_digest: "digest-1",
        storage_key: "assets/asset-1/thumb.jpg"
      })
      |> Rindle.Repo.insert!()

    expect(Rindle.StorageMock, :delete, fn key, _opts ->
      assert key in [asset.storage_key, variant.storage_key]
      {:ok, :deleted}
    end)

    assert :ok =
             perform_job(PurgeStorage, %{
               "asset_id" => asset.id,
               "profile" => to_string(TestProfile)
             })

    refute Rindle.Repo.get(MediaAsset, asset.id)
    refute Rindle.Repo.get(MediaVariant, variant.id)
  end

  test "skips delete when a surviving attachment still exists" do
    asset =
      %MediaAsset{}
      |> MediaAsset.changeset(%{
        state: "available",
        profile: to_string(TestProfile),
        storage_key: "assets/asset-2/original.jpg"
      })
      |> Rindle.Repo.insert!()

    variant =
      %MediaVariant{}
      |> MediaVariant.changeset(%{
        asset_id: asset.id,
        name: "thumb",
        state: "ready",
        recipe_digest: "digest-2",
        storage_key: "assets/asset-2/thumb.jpg"
      })
      |> Rindle.Repo.insert!()

    %MediaAttachment{}
    |> MediaAttachment.changeset(%{
      asset_id: asset.id,
      owner_type: "TestOwner",
      owner_id: Ecto.UUID.generate(),
      slot: "avatar"
    })
    |> Rindle.Repo.insert!()

    expect(Rindle.StorageMock, :delete, 0, fn _key, _opts -> {:ok, :deleted} end)

    assert :ok =
             perform_job(PurgeStorage, %{
               "asset_id" => asset.id,
               "profile" => to_string(TestProfile)
             })

    assert Rindle.Repo.get(MediaAsset, asset.id)
    assert Rindle.Repo.get(MediaVariant, variant.id)
  end
end
