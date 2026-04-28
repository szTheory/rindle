defmodule Rindle.Upload.BrokerTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Adopter.CanonicalApp.Repo
  import Mox

  alias Ecto.Adapters.SQL.Sandbox
  alias Rindle.Adopter.CanonicalApp.Repo, as: AdopterRepo
  alias Rindle.Domain.{MediaAsset, MediaUploadSession}
  alias Rindle.Upload.Broker

  setup :set_mox_from_context
  setup :verify_on_exit!

  defmodule TestRepoProbe do
    @moduledoc false

    def transaction(fun) when is_function(fun, 0) do
      notify(:transaction)
      Rindle.Adopter.CanonicalApp.Repo.transaction(fun)
    end

    def transaction(multi) do
      notify(:transaction)
      Rindle.Adopter.CanonicalApp.Repo.transaction(multi)
    end

    def insert(changeset) do
      notify({:insert, changeset.data.__struct__})
      Rindle.Adopter.CanonicalApp.Repo.insert(changeset)
    end

    def update(changeset) do
      notify({:update, changeset.data.__struct__})
      Rindle.Adopter.CanonicalApp.Repo.update(changeset)
    end

    def get(schema, id) do
      notify({:get, schema, id})
      Rindle.Adopter.CanonicalApp.Repo.get(schema, id)
    end

    def preload(struct_or_structs, preloads) do
      notify({:preload, preloads})
      Rindle.Adopter.CanonicalApp.Repo.preload(struct_or_structs, preloads)
    end

    defp notify(event) do
      if owner = Application.get_env(:rindle, :repo_probe_owner) do
        send(owner, {:repo_probe, event})
      end
    end
  end

  defmodule FailingTransactionRepo do
    @moduledoc false

    def transaction(_fun), do: {:error, :session_insert_failed}
  end

  defmodule TestProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [
        thumb: [mode: :crop, width: 100, height: 100]
      ],
      allow_mime: ["image/jpeg"],
      max_bytes: 10_485_760
  end

  defmodule UnsupportedMultipartProfile do
    use Rindle.Profile,
      storage: Rindle.Storage.Local,
      variants: [
        thumb: [mode: :crop, width: 100, height: 100]
      ],
      allow_mime: ["image/jpeg"],
      max_bytes: 10_485_760
  end

  defmodule MalformedCapabilitiesStorage do
    def capabilities, do: :broken
  end

  defmodule MalformedCapabilitiesProfile do
    use Rindle.Profile,
      storage: MalformedCapabilitiesStorage,
      variants: [
        thumb: [mode: :crop, width: 100, height: 100]
      ],
      allow_mime: ["image/jpeg"],
      max_bytes: 10_485_760
  end

  setup do
    case start_supervised(Rindle.Adopter.CanonicalApp.Repo) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    Sandbox.checkout(Rindle.Adopter.CanonicalApp.Repo)
    Sandbox.mode(Rindle.Adopter.CanonicalApp.Repo, {:shared, self()})

    previous_repo = Application.get_env(:rindle, :repo)
    previous_probe_owner = Application.get_env(:rindle, :repo_probe_owner)

    Application.put_env(:rindle, :repo, TestRepoProbe)
    Application.put_env(:rindle, :repo_probe_owner, self())

    on_exit(fn ->
      case previous_repo do
        nil -> Application.delete_env(:rindle, :repo)
        value -> Application.put_env(:rindle, :repo, value)
      end

      case previous_probe_owner do
        nil -> Application.delete_env(:rindle, :repo_probe_owner)
        value -> Application.put_env(:rindle, :repo_probe_owner, value)
      end
    end)

    :ok
  end

  describe "initiate_session/2" do
    test "creates an initialized session and staged asset" do
      {:ok, session} = Broker.initiate_session(TestProfile, filename: "test.jpg")

      assert session.state == "initialized"
      assert session.upload_key =~ "testprofile"
      assert session.upload_key =~ ".jpg"

      assert_received {:repo_probe, :transaction}
      assert_received {:repo_probe, {:insert, MediaAsset}}
      assert_received {:repo_probe, {:insert, MediaUploadSession}}

      asset = Rindle.Adopter.CanonicalApp.Repo.preload(session, :asset).asset
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

      assert_received {:repo_probe, {:get, MediaUploadSession, session_id}}
                      when session_id == session.id

      assert_received {:repo_probe, {:preload, :asset}}
      assert_received {:repo_probe, :transaction}
      assert_received {:repo_probe, {:update, MediaUploadSession}}

      assert updated_session.state == "signed"
      assert presigned.url == "https://example.com/upload"
    end

    test "fails if session is in invalid state" do
      {:ok, session} = Broker.initiate_session(TestProfile, filename: "test.jpg")

      # Manually set to completed to make sign_url invalid
      {:ok, session} =
        session
        |> MediaUploadSession.changeset(%{state: "completed"})
        |> Rindle.Adopter.CanonicalApp.Repo.update()

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

      {:ok, %{session: updated_session, asset: updated_asset}} =
        Broker.verify_completion(session.id)

      assert_received {:repo_probe, {:get, MediaUploadSession, session_id}}
                      when session_id == session.id

      assert_received {:repo_probe, {:preload, :asset}}
      assert_received {:repo_probe, :transaction}

      assert updated_session.state == "completed"
      assert updated_session.verified_at != nil

      assert updated_asset.state == "validating"
      assert updated_asset.byte_size == 1234
      assert updated_asset.content_type == "image/jpeg"
    end

    test "returns error if profile is unknown" do
      {:ok, session} = Broker.initiate_session(TestProfile, filename: "test.jpg")
      asset = Rindle.Adopter.CanonicalApp.Repo.preload(session, :asset).asset

      # Corrupt the profile name in DB
      asset
      |> MediaAsset.changeset(%{profile: "Elixir.NonExistentProfile12345"})
      |> Rindle.Adopter.CanonicalApp.Repo.update!()

      assert {:error, :unknown_profile} = Broker.verify_completion(session.id)
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
      session = Rindle.Adopter.CanonicalApp.Repo.get!(MediaUploadSession, session.id)
      assert session.state == "signed"

      asset = Rindle.Adopter.CanonicalApp.Repo.get!(MediaAsset, session.asset_id)
      assert asset.state == "staged"
    end
  end

  describe "multipart upload lifecycle" do
    test "Rindle.initiate_multipart_upload/2 creates a multipart session and returns bootstrap data" do
      expect(Rindle.StorageMock, :capabilities, fn ->
        [:presigned_put, :head, :signed_url, :multipart_upload]
      end)

      expect(Rindle.StorageMock, :initiate_multipart_upload, fn key, part_size, _opts ->
        assert key =~ "testprofile"
        assert part_size > 0

        {:ok,
         %{upload_id: "upload-123", upload_key: key, part_size: part_size, part_headers: %{}}}
      end)

      assert {:ok, %{session: session, multipart: multipart}} =
               Rindle.initiate_multipart_upload(TestProfile, filename: "multipart.jpg")

      assert session.state == "initialized"
      assert session.upload_strategy == "multipart"
      assert session.multipart_upload_id == "upload-123"
      assert multipart.upload_id == "upload-123"
      assert multipart.upload_key == session.upload_key
      assert multipart.part_headers == %{}
      assert multipart.part_size > 0
    end

    test "initiate_multipart_session/2 does not persist rows when remote multipart initiation fails" do
      expect(Rindle.StorageMock, :capabilities, fn ->
        [:presigned_put, :head, :signed_url, :multipart_upload]
      end)

      expect(Rindle.StorageMock, :initiate_multipart_upload, fn _key, _part_size, _opts ->
        {:error, :storage_unavailable}
      end)

      session_count_before = length(AdopterRepo.all(MediaUploadSession))
      asset_count_before = length(AdopterRepo.all(MediaAsset))

      assert {:error, :storage_unavailable} =
               Broker.initiate_multipart_session(TestProfile, filename: "multipart.jpg")

      assert length(AdopterRepo.all(MediaUploadSession)) == session_count_before
      assert length(AdopterRepo.all(MediaAsset)) == asset_count_before
    end

    test "initiate_multipart_session/2 aborts the remote upload when session persistence fails" do
      previous_repo = Application.get_env(:rindle, :repo)
      Application.put_env(:rindle, :repo, FailingTransactionRepo)

      expect(Rindle.StorageMock, :capabilities, fn ->
        [:presigned_put, :head, :signed_url, :multipart_upload]
      end)

      expect(Rindle.StorageMock, :initiate_multipart_upload, fn key, part_size, _opts ->
        {:ok,
         %{
           upload_id: "upload-rollback",
           upload_key: key,
           part_size: part_size,
           part_headers: %{}
         }}
      end)

      expect(Rindle.StorageMock, :abort_multipart_upload, fn key, upload_id, _opts ->
        assert key =~ "testprofile"
        assert upload_id == "upload-rollback"
        {:ok, :aborted}
      end)

      on_exit(fn ->
        case previous_repo do
          nil -> Application.delete_env(:rindle, :repo)
          value -> Application.put_env(:rindle, :repo, value)
        end
      end)

      assert {:error, :session_insert_failed} =
               Broker.initiate_multipart_session(TestProfile, filename: "multipart.jpg")
    end

    test "initiate_multipart_session/2 treats malformed capability declarations as unsupported" do
      assert {:error, {:upload_unsupported, :multipart_upload}} =
               Broker.initiate_multipart_session(
                 MalformedCapabilitiesProfile,
                 filename: "multipart.jpg"
               )
    end

    test "sign_multipart_part/3 signs a specific part through the multipart adapter path" do
      expect(Rindle.StorageMock, :capabilities, fn ->
        [:presigned_put, :head, :signed_url, :multipart_upload]
      end)

      expect(Rindle.StorageMock, :initiate_multipart_upload, fn key, part_size, _opts ->
        {:ok,
         %{upload_id: "upload-456", upload_key: key, part_size: part_size, part_headers: %{}}}
      end)

      {:ok, %{session: session}} =
        Broker.initiate_multipart_session(TestProfile, filename: "multipart.jpg")

      expect(Rindle.StorageMock, :capabilities, fn ->
        [:presigned_put, :head, :signed_url, :multipart_upload]
      end)

      expect(Rindle.StorageMock, :presigned_upload_part, fn key,
                                                            upload_id,
                                                            part_number,
                                                            expires_in,
                                                            _opts ->
        assert key == session.upload_key
        assert upload_id == "upload-456"
        assert part_number == 3
        assert expires_in == 1800
        {:ok, %{url: "https://example.com/part-3", method: :put, headers: %{}}}
      end)

      assert {:ok, %{session: updated_session, presigned: presigned}} =
               Broker.sign_multipart_part(session.id, 3, expires_in: 1800)

      assert updated_session.state == "signed"
      assert presigned.url == "https://example.com/part-3"
    end

    test "complete_multipart_upload/3 persists the manifest, completes remotely, and reuses verification" do
      expect(Rindle.StorageMock, :capabilities, 3, fn ->
        [:presigned_put, :head, :signed_url, :multipart_upload]
      end)

      expect(Rindle.StorageMock, :initiate_multipart_upload, fn key, part_size, _opts ->
        {:ok,
         %{upload_id: "upload-789", upload_key: key, part_size: part_size, part_headers: %{}}}
      end)

      {:ok, %{session: session}} =
        Broker.initiate_multipart_session(TestProfile, filename: "multipart.jpg")

      expect(Rindle.StorageMock, :presigned_upload_part, fn _key,
                                                            _upload_id,
                                                            _part_number,
                                                            _expires_in,
                                                            _opts ->
        {:ok, %{url: "https://example.com/part", method: :put, headers: %{}}}
      end)

      {:ok, %{session: signed_session}} = Broker.sign_multipart_part(session.id, 1)

      expect(Rindle.StorageMock, :complete_multipart_upload, fn key, upload_id, parts, _opts ->
        assert key == signed_session.upload_key
        assert upload_id == "upload-789"

        assert parts == [
                 %{part_number: 1, etag: "\"etag-1\""},
                 %{part_number: 2, etag: "\"etag-2\""}
               ]

        {:ok, %{upload_id: upload_id, upload_key: key}}
      end)

      expect(Rindle.StorageMock, :head, fn key, _opts ->
        assert key == signed_session.upload_key
        {:ok, %{size: 1234, content_type: "image/jpeg"}}
      end)

      parts = [
        %{part_number: 2, etag: "\"etag-2\""},
        %{part_number: 1, etag: "\"etag-1\""}
      ]

      assert {:ok, %{session: completed_session, asset: asset}} =
               Broker.complete_multipart_upload(session.id, parts)

      persisted = Rindle.Adopter.CanonicalApp.Repo.get!(MediaUploadSession, completed_session.id)

      assert persisted.multipart_parts == %{
               "parts" => [
                 %{"part_number" => 1, "etag" => "\"etag-1\""},
                 %{"part_number" => 2, "etag" => "\"etag-2\""}
               ]
             }

      assert completed_session.state == "completed"
      assert asset.state == "validating"
    end

    test "multipart on an unsupported adapter fails with a tagged capability error" do
      assert {:error, {:upload_unsupported, :multipart_upload}} =
               Broker.initiate_multipart_session(UnsupportedMultipartProfile,
                 filename: "multipart.jpg"
               )
    end

    test "reserved resumable capabilities fail with the same tagged helper contract" do
      assert {:error, {:upload_unsupported, :resumable_upload_session}} =
               Rindle.Storage.Capabilities.require_upload(
                 UnsupportedMultipartProfile.storage_adapter(),
                 :resumable_upload_session
               )
    end
  end

  describe "telemetry emission (Plan 05-01 / TEL-01)" do
    setup do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rindle, :upload, :start],
          [:rindle, :upload, :stop]
        ])

      on_exit(fn -> :telemetry.detach(ref) end)
      {:ok, ref: ref}
    end

    test "initiate_session/2 emits [:rindle, :upload, :start] after Repo.transaction commits",
         %{ref: ref} do
      {:ok, session} = Broker.initiate_session(TestProfile, filename: "telemetry-start.jpg")

      assert_received {[:rindle, :upload, :start], ^ref, measurements, metadata}
      assert is_integer(measurements.system_time)
      assert Map.has_key?(metadata, :profile)
      assert Map.has_key?(metadata, :adapter)
      assert metadata.session_id == session.id
    end

    test "verify_completion/2 emits [:rindle, :upload, :stop] after Multi commits",
         %{ref: ref} do
      {:ok, session} = Broker.initiate_session(TestProfile, filename: "telemetry-stop.jpg")

      expect(Rindle.StorageMock, :presigned_put, fn _key, _expires_in, _opts ->
        {:ok, %{url: "http://example.com", method: :put, headers: %{}}}
      end)

      {:ok, %{session: session}} = Broker.sign_url(session.id)

      expect(Rindle.StorageMock, :head, fn _key, _opts ->
        {:ok, %{size: 1234, content_type: "image/jpeg"}}
      end)

      {:ok, %{session: completed, asset: promoted}} = Broker.verify_completion(session.id)

      assert completed.state == "completed"
      assert promoted.state == "validating"

      assert_received {[:rindle, :upload, :stop], ^ref, measurements, metadata}
      assert is_integer(measurements.system_time)
      assert Map.has_key?(metadata, :profile)
      assert Map.has_key?(metadata, :adapter)
      assert metadata.session_id == completed.id
      assert metadata.asset_id == promoted.id
    end

    test "verify_completion/2 does NOT emit when storage object is missing", %{ref: ref} do
      {:ok, session} = Broker.initiate_session(TestProfile, filename: "telemetry-missing.jpg")

      expect(Rindle.StorageMock, :presigned_put, fn _key, _expires_in, _opts ->
        {:ok, %{url: "http://example.com", method: :put, headers: %{}}}
      end)

      {:ok, %{session: session}} = Broker.sign_url(session.id)

      expect(Rindle.StorageMock, :head, fn _key, _opts ->
        {:error, :not_found}
      end)

      assert {:error, :storage_object_missing} = Broker.verify_completion(session.id)
      refute_received {[:rindle, :upload, :stop], ^ref, _measurements, _metadata}
    end
  end
end
