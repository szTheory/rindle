defmodule Rindle.OwnerErasureTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo
  import Mox

  alias Rindle.Domain.{MediaAsset, MediaAttachment}
  alias Rindle.Workers.PurgeStorage

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

  setup :set_mox_from_context
  setup :verify_on_exit!

  describe "preview_owner_erasure/2" do
    test "returns a semantic report for orphaned and retained shared assets" do
      owner = %User{id: Ecto.UUID.generate()}
      other_owner = %User{id: Ecto.UUID.generate()}
      orphan_asset = insert_asset("assets/orphan/original.jpg")
      shared_asset = insert_asset("assets/shared/original.jpg")

      owner_orphan_attachment = insert_attachment(orphan_asset, owner, "avatar")
      owner_shared_attachment = insert_attachment(shared_asset, owner, "banner")
      _other_shared_attachment = insert_attachment(shared_asset, other_owner, "hero")

      assert {:ok, report} = Rindle.preview_owner_erasure(owner)

      assert report.mode == :preview
      assert report.purge_enqueued == 0
      assert Map.get(report, :purge_already_queued, 0) == 0

      assert normalize_entries(report.attachments_to_detach.entries) == [
               %{
                 asset_id: orphan_asset.id,
                 attachment_id: owner_orphan_attachment.id,
                 slot: "avatar"
               },
               %{
                 asset_id: shared_asset.id,
                 attachment_id: owner_shared_attachment.id,
                 slot: "banner"
               }
             ]

      assert report.attachments_to_detach.count == 2

      assert report.assets_to_purge == %{
               count: 1,
               entries: [%{asset_id: orphan_asset.id, profile: orphan_asset.profile}]
             }

      assert report.retained_shared_assets == %{
               count: 1,
               entries: [
                 %{
                   asset_id: shared_asset.id,
                   profile: shared_asset.profile,
                   surviving_attachment_count: 1
                 }
               ]
             }
    end
  end

  describe "erase_owner/2" do
    test "detaches owner rows, enqueues orphan-only purge work, and returns a semantic report" do
      owner = %User{id: Ecto.UUID.generate()}
      other_owner = %User{id: Ecto.UUID.generate()}
      orphan_asset = insert_asset("assets/execute-orphan/original.jpg")
      shared_asset = insert_asset("assets/execute-shared/original.jpg")

      _owner_orphan_attachment = insert_attachment(orphan_asset, owner, "avatar")
      _owner_shared_attachment = insert_attachment(shared_asset, owner, "banner")
      surviving_attachment = insert_attachment(shared_asset, other_owner, "hero")

      assert {:ok, report} = Rindle.erase_owner(owner)

      assert report.mode == :execute
      assert report.attachments_to_detach.count == 2
      assert report.assets_to_purge.count == 1
      assert report.retained_shared_assets.count == 1
      assert report.purge_enqueued == 1
      assert Map.get(report, :purge_already_queued, 0) == 0

      refute Repo.get(
               MediaAttachment,
               Enum.at(report.attachments_to_detach.entries, 0).attachment_id
             )

      assert Repo.get(MediaAttachment, surviving_attachment.id)

      assert_enqueued worker: PurgeStorage,
                      args: %{"asset_id" => orphan_asset.id, "profile" => orphan_asset.profile}
    end

    test "rerunning execute after the owner is already cleared returns a stable zeroed report" do
      owner = %User{id: Ecto.UUID.generate()}
      orphan_asset = insert_asset("assets/rerun/original.jpg")
      _attachment = insert_attachment(orphan_asset, owner, "avatar")

      assert {:ok, _first_report} = Rindle.erase_owner(owner)
      assert {:ok, report} = Rindle.erase_owner(owner)

      assert report.mode == :execute
      assert report.attachments_to_detach == %{count: 0, entries: []}
      assert report.assets_to_purge == %{count: 0, entries: []}
      assert report.retained_shared_assets == %{count: 0, entries: []}
      assert report.purge_enqueued == 0
      assert Map.get(report, :purge_already_queued, 0) == 0
    end

    test "returns semantic success when purge work is already queued" do
      owner = %User{id: Ecto.UUID.generate()}
      orphan_asset = insert_asset("assets/conflict/original.jpg")
      _attachment = insert_attachment(orphan_asset, owner, "avatar")

      args = %{"asset_id" => orphan_asset.id, "profile" => orphan_asset.profile}

      assert {:ok, _first_job} = Oban.insert(purge_job(args))
      assert {:ok, %Oban.Job{conflict?: true}} = Oban.insert(purge_job(args))
      assert {:ok, report} = Rindle.erase_owner(owner)

      assert report.mode == :execute
      assert report.purge_enqueued == 0
      assert report.purge_already_queued == 1

      assert report.assets_to_purge.entries == [
               %{asset_id: orphan_asset.id, profile: orphan_asset.profile}
             ]
    end

    test "orphan purge deletes the orphaned asset after execute while retained shared asset survives" do
      owner = %User{id: Ecto.UUID.generate()}
      other_owner = %User{id: Ecto.UUID.generate()}
      orphan_asset = insert_asset("assets/shared-vs-orphan/orphan.jpg")
      shared_asset = insert_asset("assets/shared-vs-orphan/shared.jpg")

      insert_attachment(orphan_asset, owner, "avatar")
      insert_attachment(shared_asset, owner, "banner")
      surviving_attachment = insert_attachment(shared_asset, other_owner, "hero")

      expect(Rindle.StorageMock, :delete, fn key, _opts ->
        assert key == orphan_asset.storage_key
        {:ok, :deleted}
      end)

      assert {:ok, report} = Rindle.erase_owner(owner)
      assert report.purge_enqueued == 1
      assert report.purge_already_queued == 0

      assert report.assets_to_purge.entries == [
               %{asset_id: orphan_asset.id, profile: orphan_asset.profile}
             ]

      assert report.retained_shared_assets.entries == [
               %{
                 asset_id: shared_asset.id,
                 profile: shared_asset.profile,
                 surviving_attachment_count: 1
               }
             ]

      assert :ok =
               perform_job(PurgeStorage, %{
                 "asset_id" => orphan_asset.id,
                 "profile" => orphan_asset.profile
               })

      refute Repo.get(MediaAsset, orphan_asset.id),
             "orphan asset should be deleted only after the purge worker runs"

      assert Repo.get(MediaAsset, shared_asset.id),
             "shared asset should remain because another attachment still exists"

      assert Repo.get(MediaAttachment, surviving_attachment.id),
             "surviving shared attachment should still be present"

      assert {:ok, rerun_report} = Rindle.erase_owner(owner)
      assert rerun_report.attachments_to_detach == %{count: 0, entries: []}
      assert rerun_report.assets_to_purge == %{count: 0, entries: []}
      assert rerun_report.retained_shared_assets == %{count: 0, entries: []}
      assert rerun_report.purge_enqueued == 0
      assert rerun_report.purge_already_queued == 0
    end
  end

  defp insert_asset(storage_key) do
    %MediaAsset{}
    |> MediaAsset.changeset(%{
      state: "available",
      profile: to_string(TestProfile),
      storage_key: storage_key
    })
    |> Repo.insert!()
  end

  defp insert_attachment(asset, owner, slot) do
    %MediaAttachment{}
    |> MediaAttachment.changeset(%{
      asset_id: asset.id,
      owner_type: owner_type(owner),
      owner_id: owner.id,
      slot: slot
    })
    |> Repo.insert!()
  end

  defp purge_job(args) do
    PurgeStorage.new(args,
      unique: [
        fields: [:args, :worker, :queue],
        keys: [:asset_id, :profile],
        states: [:available, :scheduled, :executing, :retryable],
        period: :infinity
      ]
    )
  end

  defp normalize_entries(entries) do
    Enum.sort_by(entries, &{&1.slot, &1.asset_id, &1.attachment_id})
  end

  defp owner_type(%{__struct__: module}), do: to_string(module)
end
