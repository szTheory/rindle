defmodule Rindle.AttachDetachTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo
  import Mox

  alias Rindle.Domain.{MediaAsset, MediaAttachment}

  setup :set_mox_from_context
  setup :verify_on_exit!

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

  setup do
    asset = 
      %MediaAsset{}
      |> MediaAsset.changeset(%{
        state: "available",
        profile: to_string(TestProfile),
        storage_key: "user/1/avatar.jpg"
      })
      |> Rindle.Repo.insert!()
      
    user = %User{id: Ecto.UUID.generate()}
      
    {:ok, asset: asset, user: user}
  end

  describe "attach/4" do
    test "successfully attaches an asset", %{asset: asset, user: user} do
      {:ok, attachment} = Rindle.attach(asset, user, "avatar")

      assert attachment.asset_id == asset.id
      assert attachment.owner_type =~ "User"
      assert attachment.owner_id == user.id
      assert attachment.slot == "avatar"
    end

    test "replaces existing attachment and enqueues purge", %{asset: asset, user: user} do
      # 1. Attach first asset
      {:ok, _} = Rindle.attach(asset, user, "avatar")
      
      # 2. Create second asset
      asset2 = 
        %MediaAsset{}
        |> MediaAsset.changeset(%{
          state: "available",
          profile: to_string(TestProfile),
          storage_key: "user/1/avatar2.jpg"
        })
        |> Rindle.Repo.insert!()

      # 3. Attach second asset (replaces first)
      {:ok, attachment} = Rindle.attach(asset2, user, "avatar")
      
      assert attachment.asset_id == asset2.id
      
      # 4. Verify old attachment is gone
      attachments = Rindle.Repo.all(MediaAttachment)
      assert length(attachments) == 1
      assert hd(attachments).asset_id == asset2.id
      
      # 5. Verify purge was enqueued for first asset
      assert_enqueued worker: Rindle.Workers.PurgeStorage, args: %{"asset_id" => asset.id, "profile" => asset.profile}
    end
  end

  describe "detach/3" do
    test "removes attachment and enqueues purge", %{asset: asset, user: user} do
      {:ok, _} = Rindle.attach(asset, user, "avatar")
      
      assert :ok = Rindle.detach(user, "avatar")
      
      assert Rindle.Repo.all(MediaAttachment) == []
      assert_enqueued worker: Rindle.Workers.PurgeStorage, args: %{"asset_id" => asset.id, "profile" => asset.profile}
    end

    test "is idempotent", %{user: user} do
      assert :ok = Rindle.detach(user, "avatar")
    end
  end
end
