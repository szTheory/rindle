defmodule Rindle.OwnerErasureBatchTest do
  use Rindle.DataCase, async: true
  use Oban.Testing, repo: Rindle.Repo
  import Mox
  import Rindle.Test.OwnerErasureBatchFixtures

  alias Rindle.Domain.MediaAttachment
  alias Rindle.Test.OwnerErasureBatchFixtures.User
  alias Rindle.Workers.PurgeStorage

  setup :set_mox_from_context
  setup :verify_on_exit!

  test "batch preview aggregates two owners" do
    owner1 = %User{id: Ecto.UUID.generate()}
    owner2 = %User{id: Ecto.UUID.generate()}
    asset1 = insert_asset("assets/batch-preview-1/original.jpg")
    asset2 = insert_asset("assets/batch-preview-2/original.jpg")
    insert_attachment(asset1, owner1, "avatar")
    insert_attachment(asset2, owner2, "banner")

    assert {:ok, batch} = Rindle.preview_batch_owner_erasure([owner1, owner2])

    assert batch.mode == :preview
    assert length(batch.owners) == 2
    assert batch.attachments_to_detach.count == 2

    assert Enum.map(batch.owners, & &1.owner) |> Enum.sort() ==
             [owner_ref(owner1), owner_ref(owner2)] |> Enum.sort()

    assert Enum.all?(batch.owners, fn %{report: report} -> report.mode == :preview end)
  end

  test "batch execute processes owners sequentially without cross-owner rollback" do
    owner1 = %User{id: Ecto.UUID.generate()}
    owner2 = %User{id: Ecto.UUID.generate()}
    asset1 = insert_asset("assets/batch-execute-1/original.jpg")
    asset2 = insert_asset("assets/batch-execute-2/original.jpg")
    attachment1 = insert_attachment(asset1, owner1, "avatar")
    attachment2 = insert_attachment(asset2, owner2, "banner")

    assert {:ok, batch} = Rindle.erase_batch_owner_erasure([owner1, owner2])

    assert batch.mode == :execute
    assert length(batch.owners) == 2
    assert batch.attachments_to_detach.count == 2
    assert batch.assets_to_purge.count == 2

    refute Repo.get(MediaAttachment, attachment1.id)
    refute Repo.get(MediaAttachment, attachment2.id)

    assert_enqueued worker: PurgeStorage,
                    args: %{"asset_id" => asset1.id, "profile" => asset1.profile}

    assert_enqueued worker: PurgeStorage,
                    args: %{"asset_id" => asset2.id, "profile" => asset2.profile}
  end

  test "batch execute idempotent rerun returns zeroed reports" do
    owner = %User{id: Ecto.UUID.generate()}
    asset = insert_asset("assets/batch-rerun/original.jpg")
    insert_attachment(asset, owner, "avatar")

    assert {:ok, _first_batch} = Rindle.erase_batch_owner_erasure([owner])

    assert {:ok, batch} = Rindle.erase_batch_owner_erasure([owner])

    assert [%{report: report}] = batch.owners
    assert report.attachments_to_detach.count == 0
    assert report.assets_to_purge.count == 0
    assert report.retained_shared_assets.count == 0
  end

  test "duplicate owners in input dedupe to one entry" do
    owner = %User{id: Ecto.UUID.generate()}
    asset = insert_asset("assets/batch-dedupe/original.jpg")
    insert_attachment(asset, owner, "avatar")

    assert {:ok, batch} = Rindle.preview_batch_owner_erasure([owner, owner])

    assert length(batch.owners) == 1
    assert batch.attachments_to_detach.count == 1
  end
end
