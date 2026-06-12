defmodule Rindle.Upload.BrokerTest do
  alias Rindle.Adopter.CanonicalApp.Repo, as: AdopterRepo
  alias Rindle.Domain.{MediaAsset, MediaUploadSession}
  alias Rindle.Ops.{RuntimeStatus, UploadMaintenance}
  alias Rindle.Storage.Capabilities
  alias Rindle.Storage.GCS
  alias Rindle.Upload.Broker

  use Rindle.DataCase, async: false
  use Oban.Testing, repo: AdopterRepo
  import Ecto.Query
  import Mox

  alias Ecto.Adapters.SQL.Sandbox
  alias Phoenix.PubSub

  setup :set_mox_from_context
  setup :verify_on_exit!

  defmodule TestRepoProbe do
    @moduledoc false

    def transaction(fun) when is_function(fun, 0) do
      notify(:transaction)
      AdopterRepo.transaction(fun)
    end

    def transaction(multi) do
      notify(:transaction)
      AdopterRepo.transaction(multi)
    end

    def insert(changeset) do
      notify({:insert, changeset.data.__struct__})
      AdopterRepo.insert(changeset)
    end

    def update(changeset) do
      notify({:update, changeset.data.__struct__})
      AdopterRepo.update(changeset)
    end

    def all(queryable) do
      notify(:all)
      AdopterRepo.all(queryable)
    end

    def one(queryable) do
      notify(:one)
      AdopterRepo.one(queryable)
    end

    def get(schema, id) do
      notify({:get, schema, id})
      AdopterRepo.get(schema, id)
    end

    def delete(struct) do
      notify({:delete, struct.__struct__})
      AdopterRepo.delete(struct)
    end

    def preload(struct_or_structs, preloads) do
      notify({:preload, preloads})
      AdopterRepo.preload(struct_or_structs, preloads)
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

  defmodule LiveGCSProfile do
    use Rindle.Profile,
      storage: Rindle.Storage.GCS,
      variants: [
        thumb: [mode: :crop, width: 100, height: 100]
      ],
      allow_mime: ["text/plain", "image/jpeg"],
      max_bytes: 10_485_760
  end

  @gcs_credentials System.get_env("GOOGLE_APPLICATION_CREDENTIALS_JSON")
  @gcs_bucket System.get_env("RINDLE_GCS_BUCKET")
  @gcs_skip_reason (if Enum.any?([@gcs_credentials, @gcs_bucket], &is_nil/1) do
                      "Skipping live resumable broker proof because GOOGLE_APPLICATION_CREDENTIALS_JSON or RINDLE_GCS_BUCKET is missing"
                    end)

  setup do
    case start_supervised(AdopterRepo) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    Sandbox.checkout(AdopterRepo)
    Sandbox.mode(AdopterRepo, {:shared, self()})

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

      asset = AdopterRepo.preload(session, :asset).asset
      assert asset.state == "staged"
      assert asset.profile == to_string(TestProfile)
      assert asset.storage_key == session.upload_key
      assert asset.filename == "test.jpg"
    end
  end

  describe "sign_url/1" do
    test "transitions session to signed and returns presigned URL" do
      {:ok, session} = Broker.initiate_session(TestProfile, filename: "test.jpg")
      subscribe_upload_session_topics(session)

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
      assert_upload_session_broadcasts(:upload_session_signed, updated_session)
    end

    test "fails if session is in invalid state" do
      {:ok, session} = Broker.initiate_session(TestProfile, filename: "test.jpg")

      # Manually set to completed to make sign_url invalid
      {:ok, session} =
        session
        |> MediaUploadSession.changeset(%{state: "completed"})
        |> AdopterRepo.update()

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
      subscribe_upload_session_topics(session)

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
      assert_upload_session_broadcasts(:upload_session_completed, updated_session)
    end

    test "returns error if profile is unknown" do
      {:ok, session} = Broker.initiate_session(TestProfile, filename: "test.jpg")
      asset = AdopterRepo.preload(session, :asset).asset

      # Corrupt the profile name in DB
      asset
      |> MediaAsset.changeset(%{profile: "Elixir.NonExistentProfile12345"})
      |> AdopterRepo.update!()

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
      session = AdopterRepo.get!(MediaUploadSession, session.id)
      assert session.state == "signed"

      asset = AdopterRepo.get!(MediaAsset, session.asset_id)
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

      subscribe_upload_session_topics(session)

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
      assert_upload_session_broadcasts(:upload_session_signed, updated_session)
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
      subscribe_upload_session_topics(signed_session)

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

      persisted = AdopterRepo.get!(MediaUploadSession, completed_session.id)

      assert persisted.multipart_parts == %{
               "parts" => [
                 %{"part_number" => 1, "etag" => "\"etag-1\""},
                 %{"part_number" => 2, "etag" => "\"etag-2\""}
               ]
             }

      assert completed_session.state == "completed"
      assert asset.state == "validating"
      assert_upload_session_broadcasts(:upload_session_completed, completed_session)
    end

    test "multipart on an unsupported adapter fails with a tagged capability error" do
      assert {:error, {:upload_unsupported, :multipart_upload}} =
               Broker.initiate_multipart_session(UnsupportedMultipartProfile,
                 filename: "multipart.jpg"
               )
    end

    test "reserved resumable capabilities fail with the same tagged helper contract" do
      assert {:error, {:upload_unsupported, :resumable_upload_session}} =
               Capabilities.require_upload(
                 UnsupportedMultipartProfile.storage_adapter(),
                 :resumable_upload_session
               )
    end
  end

  describe "resumable upload lifecycle" do
    test "initiate_resumable_session/2 creates a signed resumable session and returns bootstrap data" do
      expect(Rindle.StorageMock, :capabilities, fn ->
        [:presigned_put, :head, :signed_url, :resumable_upload, :resumable_upload_session]
      end)

      expires_at = DateTime.add(DateTime.utc_now(), 7, :day)

      expect(Rindle.StorageMock, :initiate_resumable_upload, fn key, expected_size, _opts ->
        assert key =~ "testprofile"
        assert expected_size == 4096

        {:ok,
         %{
           session_uri: "https://storage.googleapis.com/upload/session-123",
           upload_id: "session-123",
           expires_at: expires_at,
           region_hint: "us-east1"
         }}
      end)

      assert {:ok, %{session: session, resumable: resumable}} =
               Broker.initiate_resumable_session(TestProfile,
                 filename: "resumable.jpg",
                 expected_size: 4096
               )

      assert session.state == "signed"
      assert session.upload_strategy == "resumable"
      assert session.session_uri == "https://storage.googleapis.com/upload/session-123"
      assert session.session_uri_expires_at == expires_at
      assert session.last_known_offset == 0
      assert session.region_hint == "us-east1"
      assert resumable.session_uri == session.session_uri
      assert resumable.upload_id == "session-123"
      assert resumable.expires_at == expires_at
    end

    test "initiate_resumable_session/2 does not persist rows when remote initiation fails" do
      expect(Rindle.StorageMock, :capabilities, fn ->
        [:presigned_put, :head, :signed_url, :resumable_upload, :resumable_upload_session]
      end)

      expect(Rindle.StorageMock, :initiate_resumable_upload, fn _key, _expected_size, _opts ->
        {:error, :storage_unavailable}
      end)

      session_count_before = length(AdopterRepo.all(MediaUploadSession))
      asset_count_before = length(AdopterRepo.all(MediaAsset))

      assert {:error, :storage_unavailable} =
               Broker.initiate_resumable_session(TestProfile, filename: "resumable.jpg")

      assert length(AdopterRepo.all(MediaUploadSession)) == session_count_before
      assert length(AdopterRepo.all(MediaAsset)) == asset_count_before
    end

    test "initiate_resumable_session/2 cancels the remote session when persistence fails" do
      previous_repo = Application.get_env(:rindle, :repo)
      Application.put_env(:rindle, :repo, FailingTransactionRepo)

      expect(Rindle.StorageMock, :capabilities, fn ->
        [:presigned_put, :head, :signed_url, :resumable_upload, :resumable_upload_session]
      end)

      expect(Rindle.StorageMock, :initiate_resumable_upload, fn key, _expected_size, _opts ->
        {:ok,
         %{
           session_uri: "https://storage.googleapis.com/upload/session-rollback",
           upload_id: "session-rollback",
           expires_at: DateTime.add(DateTime.utc_now(), 7, :day),
           region_hint: "us-east1",
           upload_key: key
         }}
      end)

      expect(Rindle.StorageMock, :cancel_resumable_upload, fn key, session_uri, _opts ->
        assert key =~ "testprofile"
        assert session_uri == "https://storage.googleapis.com/upload/session-rollback"
        {:ok, %{cancelled: true}}
      end)

      on_exit(fn ->
        case previous_repo do
          nil -> Application.delete_env(:rindle, :repo)
          value -> Application.put_env(:rindle, :repo, value)
        end
      end)

      assert {:error, :session_insert_failed} =
               Broker.initiate_resumable_session(TestProfile, filename: "resumable.jpg")
    end

    test "initiate_resumable_session/2 treats malformed capability declarations as unsupported" do
      assert {:error, {:upload_unsupported, :resumable_upload}} =
               Broker.initiate_resumable_session(
                 MalformedCapabilitiesProfile,
                 filename: "resumable.jpg"
               )
    end

    test "status polling refreshes bookkeeping without moving durable state" do
      expect(Rindle.StorageMock, :capabilities, fn ->
        [:presigned_put, :head, :signed_url, :resumable_upload, :resumable_upload_session]
      end)

      expires_at = DateTime.add(DateTime.utc_now(), 7, :day)

      expect(Rindle.StorageMock, :initiate_resumable_upload, fn _key, _expected_size, _opts ->
        {:ok,
         %{
           session_uri: "https://storage.googleapis.com/upload/session-status",
           upload_id: "session-status",
           expires_at: expires_at,
           region_hint: "us-east1"
         }}
      end)

      {:ok, %{session: session}} =
        Broker.initiate_resumable_session(TestProfile, filename: "resumable.jpg")

      subscribe_upload_session_topics(session)

      expect(Rindle.StorageMock, :capabilities, fn ->
        [:presigned_put, :head, :signed_url, :resumable_upload, :resumable_upload_session]
      end)

      expect(Rindle.StorageMock, :resumable_upload_status, fn key, session_uri, _opts ->
        assert key == session.upload_key
        assert session_uri == session.session_uri

        {:ok,
         %{
           committed_bytes: 2048,
           state: :in_progress,
           expires_at: DateTime.add(expires_at, 1, :day),
           region_hint: "us-central1"
         }}
      end)

      assert {:ok, %{session: updated_session, committed_bytes: 2048, state: :in_progress}} =
               Broker.resumable_session_status(session.id)

      assert updated_session.state == "signed"
      assert updated_session.last_known_offset == 2048
      assert updated_session.region_hint == "us-central1"

      persisted = AdopterRepo.get!(MediaUploadSession, session.id)
      assert persisted.state == "signed"
      assert persisted.last_known_offset == 2048
      assert persisted.region_hint == "us-central1"
      assert_upload_session_broadcasts(:upload_session_uploading, updated_session, offset: 2048)
    end

    test "cancel_resumable_session/2 uses the adapter callback and persists aborted state" do
      expect(Rindle.StorageMock, :capabilities, fn ->
        [:presigned_put, :head, :signed_url, :resumable_upload, :resumable_upload_session]
      end)

      expires_at = DateTime.add(DateTime.utc_now(), 7, :day)

      expect(Rindle.StorageMock, :initiate_resumable_upload, fn _key, _expected_size, _opts ->
        {:ok,
         %{
           session_uri: "https://storage.googleapis.com/upload/session-cancel",
           upload_id: "session-cancel",
           expires_at: expires_at
         }}
      end)

      {:ok, %{session: session}} =
        Broker.initiate_resumable_session(TestProfile, filename: "resumable.jpg")

      subscribe_upload_session_topics(session)

      expect(Rindle.StorageMock, :capabilities, fn ->
        [:presigned_put, :head, :signed_url, :resumable_upload, :resumable_upload_session]
      end)

      expect(Rindle.StorageMock, :cancel_resumable_upload, fn key, session_uri, _opts ->
        assert key == session.upload_key
        assert session_uri == session.session_uri
        {:ok, %{cancelled: true}}
      end)

      assert {:ok, %{session: cancelled_session}} = Broker.cancel_resumable_session(session.id)
      assert cancelled_session.state == "aborted"
      assert AdopterRepo.get!(MediaUploadSession, session.id).state == "aborted"
      assert_upload_session_broadcasts(:upload_session_cancelled, cancelled_session)
    end

    test "unsupported status and cancel calls return tagged resumable capability errors" do
      assert {:error, {:upload_unsupported, :resumable_upload}} =
               Broker.initiate_resumable_session(UnsupportedMultipartProfile,
                 filename: "resumable.jpg"
               )

      {:ok, session} =
        Broker.initiate_session(UnsupportedMultipartProfile, filename: "fallback.jpg")

      assert {:error, {:upload_unsupported, :resumable_upload_session}} =
               Broker.resumable_session_status(session.id)

      assert {:error, {:upload_unsupported, :resumable_upload_session}} =
               Broker.cancel_resumable_session(session.id)
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

  describe "live resumable proof" do
    @tag :gcs
    @tag skip: @gcs_skip_reason
    test "streams a resumable upload through the broker lifecycle and converges via verify_completion/2" do
      with_live_gcs_env(fn finch_name ->
        body = "resumable-broker-live-proof"
        midpoint = div(byte_size(body), 2)
        first_chunk = binary_part(body, 0, midpoint)
        second_chunk = binary_part(body, midpoint, byte_size(body) - midpoint)

        assert {:ok, %{session: session, resumable: resumable}} =
                 Broker.initiate_resumable_session(LiveGCSProfile,
                   filename: "live-proof.txt",
                   expected_size: byte_size(body),
                   content_type: "text/plain"
                 )

        first_response =
          Finch.build(
            :put,
            resumable.session_uri,
            [
              {"content-length", Integer.to_string(byte_size(first_chunk))},
              {"content-range", "bytes 0-#{midpoint - 1}/#{byte_size(body)}"},
              {"content-type", "text/plain"}
            ],
            first_chunk
          )
          |> Finch.request(finch_name)

        assert {:ok, %Finch.Response{status: 308}} = first_response

        final_response =
          Finch.build(
            :put,
            resumable.session_uri,
            [
              {"content-length", Integer.to_string(byte_size(second_chunk))},
              {"content-range", "bytes #{midpoint}-#{byte_size(body) - 1}/#{byte_size(body)}"},
              {"content-type", "text/plain"}
            ],
            second_chunk
          )
          |> Finch.request(finch_name)

        assert {:ok, %Finch.Response{status: status}} = final_response
        assert status in 200..299

        assert {:ok, %{session: completed_session, asset: asset}} =
                 Broker.verify_completion(session.id)

        assert completed_session.state == "completed"
        assert asset.state == "validating"
        assert asset.byte_size == byte_size(body)
        assert inspect(completed_session) =~ "[REDACTED]"
        refute inspect(completed_session) =~ resumable.session_uri
        assert {:ok, %{size: size, content_type: "text/plain"}} = GCS.head(session.upload_key, [])
        assert size == byte_size(body)
        _ = GCS.delete(session.upload_key, [])
      end)
    end

    @tag :gcs
    @tag skip: @gcs_skip_reason
    test "maintenance abort and cleanup clear a live resumable session through the existing lane" do
      with_live_gcs_env(fn _finch_name ->
        assert {:ok, %{session: session}} =
                 Broker.initiate_resumable_session(LiveGCSProfile,
                   filename: "maintenance-cancel.txt",
                   expected_size: 128,
                   content_type: "text/plain"
                 )

        backdate_session_expiry!(session.id)

        assert {:ok, abort_report} = UploadMaintenance.abort_incomplete_uploads([])
        assert abort_report.sessions_aborted == 1
        assert abort_report.resumable_aborts == 1
        assert abort_report.abort_errors == 0

        updated = AdopterRepo.get!(MediaUploadSession, session.id)
        assert updated.state == "expired"
        assert updated.session_uri == nil

        assert {:ok, report} =
                 RuntimeStatus.runtime_status(profile: to_string(LiveGCSProfile), format: :json)

        assert Map.get(report.upload_sessions.counts, :expired, 0) == 1
        refute Jason.encode!(report) =~ session.session_uri

        assert {:ok, cleanup_report} =
                 UploadMaintenance.cleanup_orphans(dry_run: false, storage: GCS)

        assert cleanup_report.sessions_deleted == 1
        assert AdopterRepo.get(MediaUploadSession, session.id) == nil
        _ = GCS.delete(session.upload_key, [])
      end)
    end

    @tag :gcs
    @tag skip: @gcs_skip_reason
    test "maintenance treats stale live resumable session URIs as idempotent success before cleanup" do
      with_live_gcs_env(fn _finch_name ->
        assert {:ok, %{session: session}} =
                 Broker.initiate_resumable_session(LiveGCSProfile,
                   filename: "maintenance-stale.txt",
                   expected_size: 128,
                   content_type: "text/plain"
                 )

        backdate_session_expiry!(session.id)

        stale_uri = session.session_uri <> "-stale"

        from(s in MediaUploadSession, where: s.id == ^session.id)
        |> AdopterRepo.update_all(
          set: [
            session_uri: stale_uri,
            session_uri_expires_at: DateTime.add(DateTime.utc_now(), -120, :second)
          ]
        )

        assert {:ok, abort_report} = UploadMaintenance.abort_incomplete_uploads([])
        assert abort_report.sessions_aborted == 1
        assert abort_report.resumable_aborts == 1
        assert abort_report.abort_errors == 0

        updated = AdopterRepo.get!(MediaUploadSession, session.id)
        assert updated.state == "expired"
        assert updated.session_uri == nil

        assert {:ok, report} =
                 RuntimeStatus.runtime_status(profile: to_string(LiveGCSProfile), format: :json)

        assert report.upload_sessions.resumable.resumable_sessions_expired == 1
        assert report.upload_sessions.resumable.resumable_session_uris_stale == 0
        refute Jason.encode!(report) =~ stale_uri

        assert {:ok, cleanup_report} =
                 UploadMaintenance.cleanup_orphans(dry_run: false, storage: GCS)

        assert cleanup_report.sessions_deleted == 1
        assert AdopterRepo.get(MediaUploadSession, session.id) == nil
        _ = GCS.delete(session.upload_key, [])
      end)
    end
  end

  defp with_live_gcs_env(fun) when is_function(fun, 1) do
    decoded = Jason.decode!(@gcs_credentials)
    goth_name = :"rindle_resumable_gcs_test_goth_#{System.unique_integer([:positive])}"
    finch_name = :"rindle_resumable_gcs_test_finch_#{System.unique_integer([:positive])}"

    {:ok, _} = Goth.start_link(name: goth_name, source: {:service_account, decoded})
    {:ok, _} = Finch.start_link(name: finch_name)

    original_env = Application.get_env(:rindle, GCS)

    Application.put_env(:rindle, GCS,
      bucket: @gcs_bucket,
      goth: goth_name,
      finch: finch_name,
      signing_key: decoded
    )

    try do
      fun.(finch_name)
    after
      if original_env do
        Application.put_env(:rindle, GCS, original_env)
      else
        Application.delete_env(:rindle, GCS)
      end
    end
  end

  defp backdate_session_expiry!(session_id) do
    from(s in MediaUploadSession, where: s.id == ^session_id)
    |> AdopterRepo.update_all(set: [expires_at: DateTime.add(DateTime.utc_now(), -60, :second)])
  end

  defp subscribe_upload_session_topics(session) do
    PubSub.subscribe(Rindle.PubSub, "rindle:upload_session:#{session.id}")
    PubSub.subscribe(Rindle.PubSub, "rindle:asset:#{session.asset_id}")
  end

  defp assert_upload_session_broadcasts(event_type, session, extra \\ []) do
    expected_topics =
      MapSet.new(["rindle:upload_session:#{session.id}", "rindle:asset:#{session.asset_id}"])

    messages =
      for _ <- 1..2 do
        assert_receive {:rindle_event, ^event_type, payload}
        payload
      end

    for payload <- messages do
      assert payload.session_id == session.id
      assert payload.asset_id == session.asset_id
      assert payload.state == session.state
      assert payload.upload_strategy == session.upload_strategy
      assert payload.resumable_protocol == session.resumable_protocol
      refute Map.has_key?(payload, :session_uri)
      refute Map.has_key?(payload, :provider_asset_id)
      refute Map.has_key?(payload, :authorization)
      refute Map.has_key?(payload, :token)

      if Keyword.has_key?(extra, :offset) do
        assert payload.offset == Keyword.fetch!(extra, :offset)
      end
    end

    assert MapSet.size(expected_topics) == 2
  end
end
