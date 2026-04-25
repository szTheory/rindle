defmodule Rindle.Upload.BrokerTest do
  use Rindle.DataCase, async: true
  import Mox

  alias Rindle.Upload.Broker
  alias Rindle.Domain.{MediaAsset, MediaUploadSession}

  setup :set_mox_from_context
  setup :verify_on_exit!

  defmodule TestProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [
        thumb: [mode: :crop, width: 100, height: 100]
      ],
      allow_mime: ["image/jpeg"],
      max_bytes: 10_485_760
  end

  describe "initiate_session/2" do
    test "creates an initialized session and staged asset" do
      {:ok, session} = Broker.initiate_session(TestProfile, filename: "test.jpg")

      assert session.state == "initialized"
      assert session.upload_key =~ "testprofile"
      assert session.upload_key =~ ".jpg"
      
      asset = Rindle.Repo.preload(session, :asset).asset
      assert asset.state == "staged"
      assert asset.profile == to_string(TestProfile)
      assert asset.storage_key == session.upload_key
      assert asset.filename == "test.jpg"
    end
  end

  describe "sign_url/1" do
    test "transitions session to signed and returns presigned URL" do
      {:ok, session} = Broker.initiate_session(TestProfile, filename: "test.jpg")

      expect(Rindle.StorageMock, :presigned_put, fn key, _expires_in, _opts ->
        assert key == session.upload_key
        {:ok, %{url: "https://example.com/upload", method: :put, headers: %{}}}
      end)

      {:ok, %{session: updated_session, presigned: presigned}} = Broker.sign_url(session.id)

      assert updated_session.state == "signed"
      assert presigned.url == "https://example.com/upload"
    end

    test "fails if session is in invalid state" do
      {:ok, session} = Broker.initiate_session(TestProfile, filename: "test.jpg")
      
      # Manually set to completed to make sign_url invalid
      {:ok, session} = 
        session 
        |> MediaUploadSession.changeset(%{state: "completed"}) 
        |> Rindle.Repo.update()

      assert {:error, {:invalid_transition, "completed", "signed"}} = Broker.sign_url(session.id)
    end
  end

  describe "verify_completion/1" do
    test "confirms existence and transitions both session and asset" do
      {:ok, session} = Broker.initiate_session(TestProfile, filename: "test.jpg")

      # Transition to signed first
      expect(Rindle.StorageMock, :presigned_put, fn _key, _expires_in, _opts ->
        {:ok, %{url: "http://example.com", method: :put, headers: %{}}}
      end)
      {:ok, %{session: session}} = Broker.sign_url(session.id)
      
      # Mock head check success
      expect(Rindle.StorageMock, :head, fn key, _opts ->
        assert key == session.upload_key
        {:ok, %{size: 1234, content_type: "image/jpeg"}}
      end)

      {:ok, %{session: updated_session, asset: updated_asset}} = Broker.verify_completion(session.id)

      assert updated_session.state == "completed"
      assert updated_session.verified_at != nil
      
      assert updated_asset.state == "validating"
      assert updated_asset.byte_size == 1234
      assert updated_asset.content_type == "image/jpeg"
    end

    test "fails if storage object is missing" do
      {:ok, session} = Broker.initiate_session(TestProfile, filename: "test.jpg")
      
      # Transition to signed first
      expect(Rindle.StorageMock, :presigned_put, fn _key, _expires_in, _opts ->
        {:ok, %{url: "http://example.com", method: :put, headers: %{}}}
      end)
      {:ok, %{session: session}} = Broker.sign_url(session.id)

      expect(Rindle.StorageMock, :head, fn _key, _opts ->
        {:error, :not_found}
      end)

      assert {:error, :storage_object_missing} = Broker.verify_completion(session.id)
      
      # Verify states didn't change
      session = Rindle.Repo.get!(MediaUploadSession, session.id)
      assert session.state == "signed"
      
      asset = Rindle.Repo.get!(MediaAsset, session.asset_id)
      assert asset.state == "staged"
    end
  end
end
