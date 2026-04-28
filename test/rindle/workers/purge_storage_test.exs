defmodule Rindle.Workers.PurgeStorageTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo
  import Mox

  alias Rindle.Domain.{MediaAsset, MediaVariant}
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
end
