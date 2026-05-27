defmodule Rindle.Test.OwnerErasureBatchFixtures do
  @moduledoc false

  alias Rindle.Domain.{MediaAsset, MediaAttachment}

  defmodule TestProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [],
      allow_mime: ["image/jpeg"],
      max_bytes: 10_485_760
  end

  defmodule User do
    defstruct [:id]
  end

  def test_profile, do: TestProfile
  def user_module, do: User

  def insert_asset(storage_key) do
    %MediaAsset{}
    |> MediaAsset.changeset(%{
      state: "available",
      profile: to_string(TestProfile),
      storage_key: storage_key
    })
    |> Rindle.Repo.insert!()
  end

  def insert_attachment(asset, owner, slot) do
    %MediaAttachment{}
    |> MediaAttachment.changeset(%{
      asset_id: asset.id,
      owner_type: owner_type(owner),
      owner_id: owner.id,
      slot: slot
    })
    |> Rindle.Repo.insert!()
  end

  def owner_ref(%{__struct__: module, id: id}), do: {to_string(module), id}
  def owner_type(%{__struct__: module}), do: to_string(module)
end
