defmodule Rindle.Workers.PromoteAssetTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo

  alias Rindle.Domain.{MediaAsset, MediaVariant}
  alias Rindle.Workers.PromoteAsset

  defmodule TestProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [
        thumb: [mode: :crop, width: 100, height: 100],
        large: [mode: :fit, width: 800, height: 600]
      ],
      allow_mime: ["image/jpeg"],
      max_bytes: 10_485_760
  end

  setup do
    asset =
      %MediaAsset{}
      |> MediaAsset.changeset(%{
        state: "analyzing",
        profile: to_string(TestProfile),
        storage_key: "test/key.jpg"
      })
      |> Rindle.Repo.insert!()

    {:ok, asset: asset}
  end

  test "promotes asset to available and enqueues variants", %{asset: asset} do
    assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})

    asset = Rindle.Repo.get!(MediaAsset, asset.id)
    assert asset.state == "available"

    # Check variants
    variants = Rindle.Repo.all(MediaVariant)
    assert length(variants) == 2
    assert Enum.any?(variants, fn v -> v.name == "thumb" and v.state == "planned" end)
    assert Enum.any?(variants, fn v -> v.name == "large" and v.state == "planned" end)

    # Check Oban jobs
    assert_enqueued worker: Rindle.Workers.ProcessVariant,
                    args: %{"asset_id" => asset.id, "variant_name" => "thumb"}

    assert_enqueued worker: Rindle.Workers.ProcessVariant,
                    args: %{"asset_id" => asset.id, "variant_name" => "large"}
  end

  test "handles assets starting from validating state", %{asset: asset} do
    {:ok, asset} = asset |> MediaAsset.changeset(%{state: "validating"}) |> Rindle.Repo.update()

    assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})

    asset = Rindle.Repo.get!(MediaAsset, asset.id)
    assert asset.state == "available"
  end
end
