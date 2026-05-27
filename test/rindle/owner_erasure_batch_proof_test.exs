defmodule Rindle.OwnerErasureBatchProofTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo
  import Mox
  import Rindle.Test.OwnerErasureBatchFixtures

  alias Rindle.Domain.{MediaAsset, MediaAttachment}
  alias Rindle.Test.OwnerErasureBatchFixtures.User

  setup :set_mox_from_context
  setup :verify_on_exit!

  describe "PROOF-05: shared assets" do
    test "batch preview with shared asset aggregates retained_shared_assets" do
      owner1 = %User{id: Ecto.UUID.generate()}
      owner2 = %User{id: Ecto.UUID.generate()}
      orphan_asset1 = insert_asset("assets/batch-proof-preview-orphan-1/original.jpg")
      orphan_asset2 = insert_asset("assets/batch-proof-preview-orphan-2/original.jpg")
      shared_asset = insert_asset("assets/batch-proof-preview-shared/original.jpg")

      insert_attachment(orphan_asset1, owner1, "avatar")
      insert_attachment(orphan_asset2, owner2, "banner")
      insert_attachment(shared_asset, owner1, "gallery")
      insert_attachment(shared_asset, owner2, "hero")

      assert {:ok, batch} = Rindle.preview_batch_owner_erasure([owner1, owner2])

      assert batch.mode == :preview
      assert batch.retained_shared_assets.count >= 1

      assert Enum.any?(batch.owners, fn %{report: report} ->
               report.retained_shared_assets.count >= 1 and
                 Enum.any?(report.retained_shared_assets.entries, fn entry ->
                   entry.asset_id == shared_asset.id
                 end)
             end)
    end

    test "batch execute with shared asset retains asset and surviving attachment" do
      owner1 = %User{id: Ecto.UUID.generate()}
      owner2 = %User{id: Ecto.UUID.generate()}
      other_owner = %User{id: Ecto.UUID.generate()}
      orphan_asset1 = insert_asset("assets/batch-proof-execute-orphan-1/original.jpg")
      orphan_asset2 = insert_asset("assets/batch-proof-execute-orphan-2/original.jpg")
      shared_asset = insert_asset("assets/batch-proof-execute-shared/original.jpg")

      owner1_orphan = insert_attachment(orphan_asset1, owner1, "avatar")
      owner2_orphan = insert_attachment(orphan_asset2, owner2, "banner")
      insert_attachment(shared_asset, owner1, "gallery")
      insert_attachment(shared_asset, owner2, "hero")
      surviving_attachment = insert_attachment(shared_asset, other_owner, "thumb")

      assert {:ok, batch} = Rindle.erase_batch_owner_erasure([owner1, owner2])

      assert batch.mode == :execute
      assert batch.retained_shared_assets.count >= 1

      refute Repo.get(MediaAttachment, owner1_orphan.id)
      refute Repo.get(MediaAttachment, owner2_orphan.id)
      assert Repo.get(MediaAsset, shared_asset.id)
      assert Repo.get(MediaAttachment, surviving_attachment.id)

      assert Enum.any?(batch.retained_shared_assets.entries, fn entry ->
               entry.asset_id == shared_asset.id and entry.surviving_attachment_count >= 1
             end)
    end
  end
end
