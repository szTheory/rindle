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

    expect(Rindle.StorageMock, :delete, 2, fn key, _opts ->
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

  test "preserves the durable rows and returns a variant deletion error for retry" do
    {asset, variant} = insert_asset_with_variant("variant-error")

    expect(Rindle.StorageMock, :delete, fn key, _opts ->
      assert key == variant.storage_key
      {:error, :storage_unavailable}
    end)

    assert {:error, :storage_unavailable} =
             perform_job(PurgeStorage, %{
               "asset_id" => asset.id,
               "profile" => to_string(TestProfile)
             })

    assert Rindle.Repo.get(MediaAsset, asset.id)
    assert Rindle.Repo.get(MediaVariant, variant.id)
  end

  test "preserves rows after a source failure and completes an idempotent retry" do
    {asset, variant} = insert_asset_with_variant("partial-retry")

    expect(Rindle.StorageMock, :delete, 4, fn key, _opts ->
      attempt_key = {__MODULE__, :delete_attempt, key}
      attempt = Process.get(attempt_key, 0) + 1
      Process.put(attempt_key, attempt)

      case {key, attempt} do
        {key, 1} when key == variant.storage_key -> {:ok, :deleted}
        {key, 1} when key == asset.storage_key -> {:error, :storage_unavailable}
        {key, 2} when key == variant.storage_key -> {:error, :not_found}
        {key, 2} when key == asset.storage_key -> {:ok, :deleted}
      end
    end)

    args = %{"asset_id" => asset.id, "profile" => to_string(TestProfile)}

    assert {:error, :storage_unavailable} = perform_job(PurgeStorage, args)
    assert Rindle.Repo.get(MediaAsset, asset.id)
    assert Rindle.Repo.get(MediaVariant, variant.id)

    assert :ok = perform_job(PurgeStorage, args)
    refute Rindle.Repo.get(MediaAsset, asset.id)
    refute Rindle.Repo.get(MediaVariant, variant.id)
  end

  test "treats remote and local already-absent results as idempotent success" do
    for reason <- [:not_found, :enoent] do
      {asset, variant} = insert_asset_with_variant("absent-#{reason}")

      expect(Rindle.StorageMock, :delete, 2, fn key, _opts ->
        assert key in [asset.storage_key, variant.storage_key]
        {:error, reason}
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

  test "returns normalized adapter exceptions and preserves rows for retry" do
    {asset, variant} = insert_asset_with_variant("adapter-exception")

    expect(Rindle.StorageMock, :delete, fn key, _opts ->
      assert key == variant.storage_key
      raise "storage exploded"
    end)

    assert {:error, {:storage_adapter_exception, %RuntimeError{message: "storage exploded"}}} =
             perform_job(PurgeStorage, %{
               "asset_id" => asset.id,
               "profile" => to_string(TestProfile)
             })

    assert Rindle.Repo.get(MediaAsset, asset.id)
    assert Rindle.Repo.get(MediaVariant, variant.id)
  end

  defp insert_asset_with_variant(suffix) do
    asset =
      %MediaAsset{}
      |> MediaAsset.changeset(%{
        state: "available",
        profile: to_string(TestProfile),
        storage_key: "assets/#{suffix}/original.jpg"
      })
      |> Rindle.Repo.insert!()

    variant =
      %MediaVariant{}
      |> MediaVariant.changeset(%{
        asset_id: asset.id,
        name: "thumb",
        state: "ready",
        recipe_digest: "digest-#{suffix}",
        storage_key: "assets/#{suffix}/thumb.jpg"
      })
      |> Rindle.Repo.insert!()

    {asset, variant}
  end
end
