defmodule Rindle.SchemaPrefixIntegrationTest do
  use Rindle.SchemaPrefixCase, async: false

  alias Rindle.Domain.{MediaAsset, MediaAttachment}
  alias Rindle.Workers.PromoteAsset

  defmodule Owner do
    defstruct [:id]
  end

  test "the facade Multi writes and reads the selected schema instead of the decoy", %{
    selected: selected,
    decoy: decoy,
    selected_prefix: selected_prefix,
    decoy_prefix: decoy_prefix
  } do
    owner = %Owner{id: Ecto.UUID.generate()}

    assert {:ok, attachment} = Rindle.attach(selected, owner, "avatar")
    assert attachment.__meta__.prefix == selected_prefix
    assert attachment.asset_id == selected.id

    assert %MediaAttachment{asset: attached_asset} = Rindle.attachment_for(owner, "avatar")
    assert attached_asset.id == selected.id
    assert attached_asset.storage_key == "selected-#{selected_prefix}"
    assert attached_asset.__meta__.prefix == selected_prefix

    assert Repo.get(MediaAsset, decoy.id) == nil

    assert %{storage_key: decoy_storage_key, content_type: nil} =
             decoy_asset!(decoy_prefix, decoy.id)

    assert decoy_storage_key == "decoy-#{decoy_prefix}"
  end

  test "a worker persistence path updates a loaded selected-schema struct only", %{
    selected: selected,
    decoy: decoy,
    selected_prefix: selected_prefix,
    decoy_prefix: decoy_prefix
  } do
    loaded = Repo.get!(MediaAsset, selected.id)
    assert loaded.__meta__.prefix == selected_prefix

    assert {:ok, updated} =
             PromoteAsset.persist_probe_result(Repo, loaded, %{
               content_type: "image/jpeg",
               kind: "image",
               width: 1,
               height: 1
             })

    assert updated.__meta__.prefix == selected_prefix
    assert Repo.get!(MediaAsset, selected.id).content_type == "image/jpeg"

    assert %{storage_key: decoy_storage_key, content_type: nil} =
             decoy_asset!(decoy_prefix, decoy.id)

    assert decoy_storage_key == "decoy-#{decoy_prefix}"
  end
end
