defmodule Rindle.ConvenienceApiTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo
  import Mox

  alias Rindle.Domain.{MediaAsset, MediaAttachment, MediaVariant}

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

  # Helper: insert a second asset for multi-row tests
  defp insert_asset(suffix) do
    %MediaAsset{}
    |> MediaAsset.changeset(%{
      state: "available",
      profile: to_string(TestProfile),
      storage_key: "user/1/avatar-#{suffix}.jpg"
    })
    |> Rindle.Repo.insert!()
  end

  # Helper: insert a variant row in a given state
  defp insert_variant(asset_id, name, state) do
    %MediaVariant{}
    |> MediaVariant.changeset(%{
      asset_id: asset_id,
      name: name,
      state: state,
      recipe_digest: "digest-#{name}"
    })
    |> Rindle.Repo.insert!()
  end

  describe "attachment_for/2" do
    test "returns nil when no attachment exists at slot", %{user: user} do
      assert Rindle.attachment_for(user, "ghost_slot") == nil
    end

    test "returns attachment with :asset preloaded by default", %{asset: asset, user: user} do
      {:ok, _} = Rindle.attach(asset, user, "avatar")

      result = Rindle.attachment_for(user, "avatar")

      assert %MediaAttachment{} = result
      assert result.asset_id == asset.id
      assert %MediaAsset{} = result.asset
    end

    test "returns most recent attachment when multiple rows exist for same owner+slot",
         %{asset: asset, user: user} do
      # First attach
      {:ok, _} = Rindle.attach(asset, user, "avatar")

      # Replace via second attach (last-write-wins per attach/4 semantics)
      asset2 = insert_asset("v2")
      {:ok, _} = Rindle.attach(asset2, user, "avatar")

      result = Rindle.attachment_for(user, "avatar")

      assert result.asset_id == asset2.id
    end
  end

  describe "attachment_for/3" do
    test "with preload: [] does not preload :asset", %{asset: asset, user: user} do
      {:ok, _} = Rindle.attach(asset, user, "avatar")

      result = Rindle.attachment_for(user, "avatar", preload: [])

      assert %MediaAttachment{} = result
      assert %Ecto.Association.NotLoaded{} = result.asset
    end

    test "with custom preload replaces the default", %{asset: asset, user: user} do
      {:ok, _} = Rindle.attach(asset, user, "avatar")

      # preload: [:asset] is the default; passing a list replaces it.
      # Here we pass [asset: []] which is functionally equivalent to [:asset]
      # but exercises the keyword-form replacement path.
      result = Rindle.attachment_for(user, "avatar", preload: [asset: []])

      assert %MediaAsset{} = result.asset
    end
  end

  describe "ready_variants_for/1" do
    test "returns empty list when asset has no variants", %{asset: asset} do
      assert Rindle.ready_variants_for(asset) == []
    end

    test "returns only variants in the \"ready\" state", %{asset: asset} do
      ready = insert_variant(asset.id, "thumb", "ready")
      _processing = insert_variant(asset.id, "large", "processing")

      result = Rindle.ready_variants_for(asset)

      assert [%MediaVariant{} = only] = result
      assert only.id == ready.id
      assert only.name == "thumb"
    end

    test "returns variants ordered by :name ascending", %{asset: asset} do
      _ = insert_variant(asset.id, "thumb", "ready")
      _ = insert_variant(asset.id, "large", "ready")

      result = Rindle.ready_variants_for(asset)

      assert Enum.map(result, & &1.name) == ["large", "thumb"]
    end

    test "accepts a binary asset id", %{asset: asset} do
      _ = insert_variant(asset.id, "thumb", "ready")

      result = Rindle.ready_variants_for(asset.id)

      assert [%MediaVariant{name: "thumb"}] = result
    end

    test "accepts a %MediaAsset{} struct", %{asset: asset} do
      _ = insert_variant(asset.id, "thumb", "ready")

      result = Rindle.ready_variants_for(asset)

      assert [%MediaVariant{name: "thumb"}] = result
    end
  end

  describe "Rindle.Error.message/1" do
    test "formats :not_found reason" do
      # Use struct!/2 (runtime resolution) instead of %Rindle.Error{} literal
      # so this test file compiles before Rindle.Error exists. The runtime
      # call below still raises UndefinedFunctionError, preserving the RED
      # signal until Plan 19-02 ships the module.
      err = struct!(Rindle.Error, action: :attach, reason: :not_found)
      assert Rindle.Error.message(err) == "could not attach: not found"
    end

    test "formats {:quarantine, why} reason" do
      err = struct!(Rindle.Error, action: :upload, reason: {:quarantine, :mime_mismatch})
      msg = Rindle.Error.message(err)

      assert msg =~ "could not upload"
      assert msg =~ "quarantined"
      assert msg =~ inspect(:mime_mismatch)
    end

    test "formats arbitrary reason via inspect" do
      err = struct!(Rindle.Error, action: :url, reason: :unauthorized)
      msg = Rindle.Error.message(err)

      assert msg =~ "could not url"
      assert msg =~ inspect(:unauthorized)
    end
  end

  describe "attach!/4" do
    test "returns the unwrapped MediaAttachment on success", %{asset: asset, user: user} do
      result = Rindle.attach!(asset, user, "avatar")

      assert %MediaAttachment{} = result
      assert result.asset_id == asset.id
      assert result.slot == "avatar"
    end

    test "raises Rindle.Error with action :attach for non-changeset errors", %{user: user} do
      # Non-existent asset id — FK constraint failure surfaces as {:error, reason}
      ghost_id = Ecto.UUID.generate()

      assert_raise Rindle.Error, fn ->
        Rindle.attach!(ghost_id, user, "avatar")
      end
    end
  end

  describe "detach!/3" do
    test "returns :ok on success (and unwraps bare :ok, NOT {:ok, _})",
         %{asset: asset, user: user} do
      {:ok, _} = Rindle.attach(asset, user, "avatar")

      assert :ok = Rindle.detach!(user, "avatar")
    end

    test "is idempotent — returns :ok when no attachment exists", %{user: user} do
      assert :ok = Rindle.detach!(user, "ghost_slot")
    end
  end

  describe "upload!/3" do
    test "returns the unwrapped MediaAsset on success" do
      tmp_path =
        Path.join(
          System.tmp_dir!(),
          "rindle_test_upload_#{System.unique_integer([:positive])}.jpg"
        )

      File.write!(tmp_path, <<0xFF, 0xD8, 0xFF, 0xE0>> <> :crypto.strong_rand_bytes(16))
      on_exit(fn -> File.rm(tmp_path) end)

      expect(Rindle.StorageMock, :store, fn _key, _path, _opts -> {:ok, %{}} end)

      upload = %{
        path: tmp_path,
        filename: "x.jpg",
        content_type: "image/jpeg"
      }

      result = Rindle.upload!(TestProfile, upload)

      assert %MediaAsset{} = result
    end

    test "re-raises the underlying exception when storage adapter raises" do
      tmp_path =
        Path.join(
          System.tmp_dir!(),
          "rindle_test_upload_raise_#{System.unique_integer([:positive])}.jpg"
        )

      File.write!(tmp_path, <<0xFF, 0xD8, 0xFF, 0xE0>> <> :crypto.strong_rand_bytes(16))
      on_exit(fn -> File.rm(tmp_path) end)

      expect(Rindle.StorageMock, :store, fn _key, _path, _opts ->
        raise RuntimeError, "simulated S3 timeout"
      end)

      upload = %{
        path: tmp_path,
        filename: "x.jpg",
        content_type: "image/jpeg"
      }

      assert_raise RuntimeError, "simulated S3 timeout", fn ->
        Rindle.upload!(TestProfile, upload)
      end
    end
  end

  describe "url!/3" do
    test "returns the unwrapped URL string on success" do
      # Private TestProfile + StorageMock requires advertising :signed_url so
      # Rindle.Delivery.require_delivery_support/2 lets the call reach :url.
      expect(Rindle.StorageMock, :capabilities, fn -> [:signed_url] end)
      expect(Rindle.StorageMock, :url, fn _key, _opts -> {:ok, "https://example.com/u.jpg"} end)

      result = Rindle.url!(TestProfile, "uploads/u.jpg")

      assert is_binary(result)
      assert result == "https://example.com/u.jpg"
    end

    test "raises Rindle.Error on storage failure" do
      expect(Rindle.StorageMock, :capabilities, fn -> [:signed_url] end)
      expect(Rindle.StorageMock, :url, fn _key, _opts -> {:error, :unauthorized} end)

      assert_raise Rindle.Error, fn ->
        Rindle.url!(TestProfile, "uploads/u.jpg")
      end
    end
  end

  describe "variant_url!/4" do
    test "raises Rindle.Error on failure" do
      # Force a failure path: TestProfile is private and StorageMock advertises
      # no capabilities, so `Rindle.Delivery.url/3` returns
      # {:error, {:delivery_unsupported, :signed_url}} before reaching adapter.url.
      # The bang must convert that to a raise.
      expect(Rindle.StorageMock, :capabilities, fn -> [] end)

      asset = %MediaAsset{
        id: Ecto.UUID.generate(),
        profile: to_string(TestProfile),
        storage_key: "k"
      }

      variant = %MediaVariant{name: "thumb", state: "failed", storage_key: "v"}

      assert_raise Rindle.Error, fn ->
        Rindle.variant_url!(TestProfile, asset, variant)
      end
    end
  end
end
