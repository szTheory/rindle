defmodule Rindle.Workers.ProcessVariantTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo
  import Mox

  alias Rindle.Domain.{MediaAsset, MediaVariant}
  alias Rindle.Workers.ProcessVariant

  setup :set_mox_from_context
  setup :verify_on_exit!

  defmodule TestProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [
        thumb: [mode: :crop, width: 10, height: 10]
      ],
      allow_mime: ["image/jpeg"],
      max_bytes: 10_485_760
  end

  setup do
    asset =
      %MediaAsset{}
      |> MediaAsset.changeset(%{
        state: "available",
        profile: to_string(TestProfile),
        storage_key: "test/key.jpg"
      })
      |> Rindle.Repo.insert!()

    variant =
      %MediaVariant{}
      |> MediaVariant.changeset(%{
        asset_id: asset.id,
        name: "thumb",
        state: "planned",
        recipe_digest: TestProfile.recipe_digest(:thumb)
      })
      |> Rindle.Repo.insert!()

    {:ok, asset: asset, variant: variant}
  end

  test "generates and stores variant successfully", %{asset: asset, variant: variant} do
    # 1. Mock download of source
    expect(Rindle.StorageMock, :download, fn _key, tmp_path, _opts ->
      # Create a fake source image
      File.write!(
        tmp_path,
        <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48,
          0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x00, 0x00,
          0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, 0x08,
          0xD7, 0x63, 0xF8, 0xFF, 0xFF, 0x3F, 0x00, 0x05, 0xFE, 0x02, 0xFE, 0xDC, 0x44, 0x74,
          0x06, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82>>
      )

      {:ok, tmp_path}
    end)

    # 2. Mock upload of result
    expect(Rindle.StorageMock, :store, fn key, _path, _opts ->
      assert key =~ asset.id
      assert key =~ "thumb"
      {:ok, %{key: key}}
    end)

    assert :ok = perform_job(ProcessVariant, %{"asset_id" => asset.id, "variant_name" => "thumb"})

    variant = Rindle.Repo.get!(MediaVariant, variant.id)
    assert variant.state == "ready"
    assert variant.storage_key =~ asset.id
    assert variant.byte_size > 0
    assert variant.generated_at != nil
  end

  test "handles processing failure", %{asset: asset, variant: variant} do
    # Mock download failure
    expect(Rindle.StorageMock, :download, fn _key, _tmp, _opts ->
      {:error, :not_found}
    end)

    assert {:error, :not_found} =
             perform_job(ProcessVariant, %{"asset_id" => asset.id, "variant_name" => "thumb"})

    variant = Rindle.Repo.get!(MediaVariant, variant.id)
    assert variant.state == "failed"
    assert variant.error_reason =~ ":not_found"
  end
end
