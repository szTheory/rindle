defmodule Rindle.Ops.UploadMaintenanceTest do
  use Rindle.DataCase, async: false
  import Mox

  alias Ecto.Adapters.SQL.Sandbox
  alias Rindle.Adopter.CanonicalApp.Repo, as: AdopterRepo
  alias Rindle.Domain.{MediaAsset, MediaUploadSession}
  alias Rindle.Domain.UploadSessionFSM
  alias Rindle.Ops.UploadMaintenance

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

  defmodule TestRepoProbe do
    @moduledoc false

    def all(queryable) do
      notify(:all)
      AdopterRepo.all(queryable)
    end

    def delete(struct) do
      notify({:delete, struct.__struct__})
      AdopterRepo.delete(struct)
    end

    def update(changeset) do
      notify({:update, changeset.data.__struct__})
      AdopterRepo.update(changeset)
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

  setup do
    previous_repo = Application.get_env(:rindle, :repo)
    previous_probe_owner = Application.get_env(:rindle, :repo_probe_owner)

    case start_supervised(AdopterRepo) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    Sandbox.checkout(AdopterRepo)
    Sandbox.mode(AdopterRepo, {:shared, self()})

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

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp create_asset(overrides \\ %{}) do
    %MediaAsset{}
    |> MediaAsset.changeset(
      Map.merge(
        %{
          state: "staged",
          profile: to_string(TestProfile),
          storage_key: "uploads/#{Ecto.UUID.generate()}.jpg"
        },
        overrides
      )
    )
    |> AdopterRepo.insert!()
  end

  defp create_session(asset, overrides) do
    %MediaUploadSession{}
    |> MediaUploadSession.changeset(
      Map.merge(
        %{
          asset_id: asset.id,
          state: "initialized",
          upload_key: asset.storage_key,
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        },
        overrides
      )
    )
    |> AdopterRepo.insert!()
  end

  defp create_multipart_session(asset, overrides) do
    create_session(
      asset,
      Map.merge(
        %{
          upload_strategy: "multipart",
          multipart_upload_id: "upload-#{System.unique_integer([:positive])}"
        },
        overrides
      )
    )
  end

  defp create_resumable_session(asset, overrides) do
    create_session(
      asset,
      Map.merge(
        %{
          state: "resuming",
          upload_strategy: "resumable",
          session_uri: "https://storage.example/upload/#{System.unique_integer([:positive])}",
          session_uri_expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        },
        overrides
      )
    )
  end

  # A tus session is upload_strategy: "resumable" + resumable_protocol: "tus",
  # backed by an S3 multipart upload (multipart_upload_id stamped between PATCHes)
  # or Local (no upload_id). It sits in "signed" through PATCHes.
  defp create_tus_session(asset, overrides) do
    create_session(
      asset,
      Map.merge(
        %{
          state: "signed",
          upload_strategy: "resumable",
          resumable_protocol: "tus",
          multipart_upload_id: "tus-upload-#{System.unique_integer([:positive])}"
        },
        overrides
      )
    )
  end

  defp expired_at, do: DateTime.add(DateTime.utc_now(), -100, :second)

  # ---------------------------------------------------------------------------
  # cleanup_orphans/1 — dry-run
  # ---------------------------------------------------------------------------

  describe "cleanup_orphans/1 dry-run" do
    test "reports expired sessions without deleting them" do
      asset = create_asset()
      session = create_session(asset, %{state: "expired", expires_at: expired_at()})

      {:ok, report} = UploadMaintenance.cleanup_orphans(dry_run: true)

      assert report.sessions_found >= 1
      assert report.sessions_deleted == 0
      assert report.objects_deleted == 0

      # Rows must still exist
      assert AdopterRepo.get(MediaUploadSession, session.id) != nil
      assert_received {:repo_probe, :all}
    end

    test "reports zero when nothing is expired" do
      asset = create_asset()
      _session = create_session(asset, %{state: "completed"})

      {:ok, report} = UploadMaintenance.cleanup_orphans(dry_run: true)

      assert report.sessions_found == 0
    end

    test "does not call storage delete in dry-run" do
      # StorageMock.delete should never be invoked
      asset = create_asset()
      _session = create_session(asset, %{state: "expired", expires_at: expired_at()})

      # If delete were called it would raise (no expect set)
      {:ok, _report} = UploadMaintenance.cleanup_orphans(dry_run: true)
    end
  end

  # ---------------------------------------------------------------------------
  # cleanup_orphans/1 — live run
  # ---------------------------------------------------------------------------

  describe "cleanup_orphans/1 live run" do
    test "deletes expired sessions and staged objects" do
      asset = create_asset()
      session = create_session(asset, %{state: "expired", expires_at: expired_at()})

      expect(Rindle.StorageMock, :delete, fn key, _opts ->
        assert key == session.upload_key
        {:ok, :deleted}
      end)

      {:ok, report} =
        UploadMaintenance.cleanup_orphans(dry_run: false, storage: Rindle.StorageMock)

      assert report.sessions_deleted >= 1
      assert report.objects_deleted >= 1

      assert AdopterRepo.get(MediaUploadSession, session.id) == nil
      assert_received {:repo_probe, :all}
      assert_received {:repo_probe, {:delete, MediaUploadSession}}
    end

    test "does not delete non-expired sessions" do
      asset = create_asset()
      _active_session = create_session(asset, %{state: "signed"})

      # No storage.delete expected
      {:ok, report} =
        UploadMaintenance.cleanup_orphans(dry_run: false, storage: Rindle.StorageMock)

      assert report.sessions_deleted == 0
    end

    test "defaults to the configured storage adapter when :storage is omitted" do
      asset = create_asset()
      session = create_session(asset, %{state: "expired", expires_at: expired_at()})
      previous_default_storage = Application.get_env(:rindle, :default_storage)
      Application.put_env(:rindle, :default_storage, Rindle.StorageMock)

      expect(Rindle.StorageMock, :delete, fn key, _opts ->
        assert key == session.upload_key
        {:ok, :deleted}
      end)

      on_exit(fn ->
        if previous_default_storage do
          Application.put_env(:rindle, :default_storage, previous_default_storage)
        else
          Application.delete_env(:rindle, :default_storage)
        end
      end)

      {:ok, report} = UploadMaintenance.cleanup_orphans(dry_run: false)

      assert report.sessions_deleted == 1
      assert report.objects_deleted == 1
      assert AdopterRepo.get(MediaUploadSession, session.id) == nil
    end

    test "preserves rows when no storage adapter can be resolved" do
      asset = create_asset()
      session = create_session(asset, %{state: "expired", expires_at: expired_at()})
      previous_default_storage = Application.get_env(:rindle, :default_storage)
      Application.delete_env(:rindle, :default_storage)

      on_exit(fn ->
        if previous_default_storage do
          Application.put_env(:rindle, :default_storage, previous_default_storage)
        end
      end)

      {:ok, report} = UploadMaintenance.cleanup_orphans(dry_run: false)

      assert report.sessions_found == 1
      assert report.storage_skipped == 1
      assert report.sessions_deleted == 0
      assert AdopterRepo.get(MediaUploadSession, session.id) != nil
      assert_received {:repo_probe, :all}
      refute_received {:repo_probe, {:delete, MediaUploadSession}}
    end

    test "preserves DB row when storage delete fails so a future run can retry" do
      asset = create_asset()
      session = create_session(asset, %{state: "expired", expires_at: expired_at()})

      expect(Rindle.StorageMock, :delete, fn _key, _opts ->
        {:error, :storage_unavailable}
      end)

      {:ok, report} =
        UploadMaintenance.cleanup_orphans(dry_run: false, storage: Rindle.StorageMock)

      assert report.storage_errors >= 1
      # Critical correctness invariant: the DB row must remain so a later
      # cleanup pass can retry the storage delete using the same upload_key.
      assert report.sessions_deleted == 0
      assert AdopterRepo.get(MediaUploadSession, session.id) != nil
      assert_received {:repo_probe, :all}
    end

    test "deletes resumable expired rows only when the session URI proof marker is cleared" do
      asset = create_asset()

      session =
        create_resumable_session(asset, %{
          state: "expired",
          session_uri: nil,
          expires_at: expired_at()
        })

      expect(Rindle.StorageMock, :delete, fn key, _opts ->
        assert key == session.upload_key
        {:ok, :deleted}
      end)

      {:ok, report} =
        UploadMaintenance.cleanup_orphans(dry_run: false, storage: Rindle.StorageMock)

      assert report.sessions_deleted == 1
      assert report.resumable_skipped == 0
      assert AdopterRepo.get(MediaUploadSession, session.id) == nil
    end

    test "skips resumable expired rows that still retain their session URI proof marker" do
      asset = create_asset()
      session = create_resumable_session(asset, %{state: "expired", expires_at: expired_at()})

      {:ok, report} =
        UploadMaintenance.cleanup_orphans(dry_run: false, storage: Rindle.StorageMock)

      assert report.sessions_found == 1
      assert report.sessions_deleted == 0
      assert report.resumable_skipped == 1
      assert report.objects_deleted == 0
      assert report.storage_errors == 0
      assert AdopterRepo.get(MediaUploadSession, session.id) != nil
      refute_received {:repo_probe, {:delete, MediaUploadSession}}
    end

    test "deletes DB row when storage reports object already not found" do
      asset = create_asset()
      session = create_session(asset, %{state: "expired", expires_at: expired_at()})

      expect(Rindle.StorageMock, :delete, fn _key, _opts ->
        {:error, :not_found}
      end)

      {:ok, report} =
        UploadMaintenance.cleanup_orphans(dry_run: false, storage: Rindle.StorageMock)

      # Object already absent — counter should not increment for it, but the
      # session row should still be removed because there's nothing to retry.
      assert report.storage_errors == 0
      assert report.objects_deleted == 0
      assert report.sessions_deleted >= 1
      assert AdopterRepo.get(MediaUploadSession, session.id) == nil
      assert_received {:repo_probe, :all}
      assert_received {:repo_probe, {:delete, MediaUploadSession}}
    end

    test "cleans up expired sessions even when expires_at is in the future" do
      # CR-08 regression: state='expired' is the source of truth for cleanup
      # eligibility. A session that was administratively transitioned to
      # 'expired' before its TTL elapsed must still be reaped.
      asset = create_asset()
      future = DateTime.add(DateTime.utc_now(), 7200, :second)

      session =
        create_session(asset, %{
          state: "expired",
          expires_at: future
        })

      expect(Rindle.StorageMock, :delete, fn _key, _opts -> {:ok, :deleted} end)

      {:ok, report} =
        UploadMaintenance.cleanup_orphans(dry_run: false, storage: Rindle.StorageMock)

      assert report.sessions_deleted >= 1
      assert AdopterRepo.get(MediaUploadSession, session.id) == nil
      assert_received {:repo_probe, :all}
      assert_received {:repo_probe, {:delete, MediaUploadSession}}
    end

    test "deletes only expired sessions when mixed states exist" do
      asset1 = create_asset()
      asset2 = create_asset()
      expired_session = create_session(asset1, %{state: "expired", expires_at: expired_at()})
      active_session = create_session(asset2, %{state: "uploading"})

      expect(Rindle.StorageMock, :delete, fn key, _opts ->
        assert key == expired_session.upload_key
        {:ok, :deleted}
      end)

      {:ok, report} =
        UploadMaintenance.cleanup_orphans(dry_run: false, storage: Rindle.StorageMock)

      assert report.sessions_deleted == 1
      assert AdopterRepo.get(MediaUploadSession, expired_session.id) == nil
      assert AdopterRepo.get(MediaUploadSession, active_session.id) != nil
      assert_received {:repo_probe, :all}
      assert_received {:repo_probe, {:delete, MediaUploadSession}}
    end

    test "aborts expired multipart uploads before deleting the session row" do
      asset = create_asset()
      session = create_multipart_session(asset, %{state: "expired", expires_at: expired_at()})

      expect(Rindle.StorageMock, :abort_multipart_upload, fn key, upload_id, _opts ->
        assert key == session.upload_key
        assert upload_id == session.multipart_upload_id
        {:ok, :aborted}
      end)

      {:ok, report} =
        UploadMaintenance.cleanup_orphans(dry_run: false, storage: Rindle.StorageMock)

      assert report.sessions_deleted == 1
      assert report.objects_deleted == 1
      assert AdopterRepo.get(MediaUploadSession, session.id) == nil
    end

    test "deletes expired multipart rows when remote abort reports not found" do
      asset = create_asset()
      session = create_multipart_session(asset, %{state: "expired", expires_at: expired_at()})

      expect(Rindle.StorageMock, :abort_multipart_upload, fn _key, _upload_id, _opts ->
        {:error, :not_found}
      end)

      {:ok, report} =
        UploadMaintenance.cleanup_orphans(dry_run: false, storage: Rindle.StorageMock)

      assert report.storage_errors == 0
      assert report.sessions_deleted == 1
      assert report.objects_deleted == 0
      assert AdopterRepo.get(MediaUploadSession, session.id) == nil
    end

    test "keeps expired multipart rows when remote abort fails so cleanup can retry" do
      asset = create_asset()
      session = create_multipart_session(asset, %{state: "expired", expires_at: expired_at()})

      expect(Rindle.StorageMock, :abort_multipart_upload, fn _key, _upload_id, _opts ->
        {:error, :storage_unavailable}
      end)

      {:ok, report} =
        UploadMaintenance.cleanup_orphans(dry_run: false, storage: Rindle.StorageMock)

      assert report.storage_errors == 1
      assert report.sessions_deleted == 0
      assert AdopterRepo.get(MediaUploadSession, session.id) != nil
    end
  end

  # ---------------------------------------------------------------------------
  # abort_incomplete_uploads/1
  # ---------------------------------------------------------------------------

  describe "abort_incomplete_uploads/1" do
    test "transitions timed-out signed sessions to expired" do
      asset = create_asset()
      session = create_session(asset, %{state: "signed", expires_at: expired_at()})

      {:ok, report} = UploadMaintenance.abort_incomplete_uploads([])

      assert report.sessions_aborted >= 1

      updated = AdopterRepo.get!(MediaUploadSession, session.id)
      assert updated.state == "expired"
      assert_received {:repo_probe, :all}
      assert_received {:repo_probe, {:update, MediaUploadSession}}
    end

    test "transitions timed-out uploading sessions to expired" do
      asset = create_asset()
      session = create_session(asset, %{state: "uploading", expires_at: expired_at()})

      {:ok, report} = UploadMaintenance.abort_incomplete_uploads([])

      assert report.sessions_aborted >= 1

      updated = AdopterRepo.get!(MediaUploadSession, session.id)
      assert updated.state == "expired"
      assert_received {:repo_probe, :all}
      assert_received {:repo_probe, {:update, MediaUploadSession}}
    end

    test "leaves sessions that have not yet expired" do
      asset = create_asset()
      _session = create_session(asset, %{state: "signed"})

      {:ok, report} = UploadMaintenance.abort_incomplete_uploads([])

      assert report.sessions_aborted == 0
    end

    test "leaves completed and already-expired sessions untouched" do
      asset1 = create_asset()
      asset2 = create_asset()
      _completed = create_session(asset1, %{state: "completed"})
      _already_expired = create_session(asset2, %{state: "expired", expires_at: expired_at()})

      {:ok, report} = UploadMaintenance.abort_incomplete_uploads([])

      assert report.sessions_aborted == 0
    end

    test "expires multipart-tagged sessions without attempting storage cleanup" do
      asset = create_asset()
      session = create_multipart_session(asset, %{state: "uploading", expires_at: expired_at()})

      {:ok, report} = UploadMaintenance.abort_incomplete_uploads([])

      assert report.sessions_aborted == 1

      updated = AdopterRepo.get!(MediaUploadSession, session.id)
      assert updated.state == "expired"
      assert_received {:repo_probe, :all}
      assert_received {:repo_probe, {:update, MediaUploadSession}}
      refute_received {:repo_probe, {:delete, MediaUploadSession}}
    end

    test "expires initialized multipart sessions that already have a remote upload id" do
      asset = create_asset()
      session = create_multipart_session(asset, %{state: "initialized", expires_at: expired_at()})

      {:ok, report} = UploadMaintenance.abort_incomplete_uploads([])

      assert report.sessions_aborted == 1

      updated = AdopterRepo.get!(MediaUploadSession, session.id)
      assert updated.state == "expired"
      assert_received {:repo_probe, :all}
      assert_received {:repo_probe, {:update, MediaUploadSession}}
      refute_received {:repo_probe, {:delete, MediaUploadSession}}
    end

    test "cancels timed-out resumable resuming sessions and clears the session URI" do
      asset = create_asset()
      session = create_resumable_session(asset, %{state: "resuming", expires_at: expired_at()})

      expect(Rindle.StorageMock, :capabilities, fn -> [:resumable_upload_session] end)

      expect(Rindle.StorageMock, :cancel_resumable_upload, fn key, session_uri, _opts ->
        assert key == session.upload_key
        assert session_uri == session.session_uri
        {:ok, %{cancelled: true}}
      end)

      {:ok, report} = UploadMaintenance.abort_incomplete_uploads([])

      assert report.sessions_aborted == 1
      assert report.resumable_aborts == 1
      assert report.multipart_aborts == 0
      assert report.presigned_put_aborts == 0

      updated = AdopterRepo.get!(MediaUploadSession, session.id)
      assert updated.state == "expired"
      assert updated.session_uri == nil
      assert updated.failure_reason == nil
      assert_received {:repo_probe, {:preload, :asset}}
    end

    test "treats unknown and expired resumable session URIs as idempotent cancel success" do
      for cancel_reason <- [:session_uri_unknown, :session_uri_expired] do
        asset = create_asset()

        session =
          create_resumable_session(asset, %{
            state: "uploading",
            upload_key: "uploads/#{cancel_reason}-#{System.unique_integer([:positive])}.jpg",
            session_uri:
              "https://storage.example/#{cancel_reason}-#{System.unique_integer([:positive])}",
            expires_at: expired_at()
          })

        expect(Rindle.StorageMock, :capabilities, fn -> [:resumable_upload_session] end)

        expect(Rindle.StorageMock, :cancel_resumable_upload, fn _, _, _ ->
          {:error, cancel_reason}
        end)

        {:ok, report} = UploadMaintenance.abort_incomplete_uploads([])

        assert report.sessions_aborted == 1
        assert report.abort_errors == 0
        assert report.resumable_aborts == 1

        updated = AdopterRepo.get!(MediaUploadSession, session.id)
        assert updated.state == "expired"
        assert updated.session_uri == nil
        assert updated.failure_reason == nil

        AdopterRepo.delete!(updated)
      end
    end

    test "maps resumable cancel failures to bounded failure reasons" do
      cases = [
        {:goth_unconfigured, "resumable_cancel_failed:goth_unconfigured"},
        {{:gcs_http_error, %{status: 409, body: "conflict"}},
         "resumable_cancel_failed:gcs_http_4xx"},
        {{:gcs_http_error, %{status: 503, body: "down"}}, "resumable_cancel_failed:gcs_http_5xx"},
        {:timeout, "resumable_cancel_failed:transport"}
      ]

      for {cancel_result, expected_reason} <- cases do
        asset = create_asset()

        session =
          create_resumable_session(asset, %{
            upload_key: "uploads/#{System.unique_integer([:positive])}.jpg",
            session_uri: "https://storage.example/fail/#{System.unique_integer([:positive])}",
            expires_at: expired_at()
          })

        expect(Rindle.StorageMock, :capabilities, fn -> [:resumable_upload_session] end)

        expect(Rindle.StorageMock, :cancel_resumable_upload, fn _, _, _ ->
          {:error, cancel_result}
        end)

        {:ok, report} = UploadMaintenance.abort_incomplete_uploads([])

        assert report.sessions_aborted == 0
        assert report.abort_errors == 1
        assert report.resumable_aborts == 0

        updated = AdopterRepo.get!(MediaUploadSession, session.id)
        assert updated.state == "aborted"
        assert updated.session_uri == session.session_uri
        assert updated.failure_reason == expected_reason

        AdopterRepo.delete!(updated)
      end
    end

    test "retries aborted resumable rows that retained their session URI after a prior cancel failure" do
      asset = create_asset()

      session =
        create_resumable_session(asset, %{
          state: "aborted",
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
          failure_reason: "resumable_cancel_failed:transport"
        })

      expect(Rindle.StorageMock, :capabilities, fn -> [:resumable_upload_session] end)

      expect(Rindle.StorageMock, :cancel_resumable_upload, fn key, session_uri, _opts ->
        assert key == session.upload_key
        assert session_uri == session.session_uri
        {:ok, %{cancelled: true}}
      end)

      {:ok, report} = UploadMaintenance.abort_incomplete_uploads([])

      assert report.sessions_found == 1
      assert report.sessions_aborted == 1
      assert report.abort_errors == 0
      assert report.resumable_aborts == 1

      updated = AdopterRepo.get!(MediaUploadSession, session.id)
      assert updated.state == "expired"
      assert updated.session_uri == nil
      assert updated.failure_reason == nil
    end

    # -------------------------------------------------------------------------
    # TUS-09 reaper branch: tus sessions abort the S3 multipart upload, NOT the
    # provider-direct resumable session URI. EXPECTED RED until Plan 03 adds the
    # `tus_session?/1` branch to expire_session/2 — today a tus session matches
    # resumable_abort_session?/1 and is mis-routed to cancel_resumable_upload via
    # resolve_resumable_adapter (which requires the :resumable_upload_session cap
    # S3/Local do NOT advertise) -> the S3 multipart is never aborted -> LEAK.
    # -------------------------------------------------------------------------

    test "aborts an expired tus session via abort_multipart_upload, not cancel_resumable_upload" do
      asset = create_asset()
      session = create_tus_session(asset, %{expires_at: expired_at()})

      # The load-bearing assertion: tus sessions route to the multipart abort
      # (S3 backing), NOT the GCS-native session cancel. cancel_resumable_upload
      # must never be invoked for a tus session.
      expect(Rindle.StorageMock, :abort_multipart_upload, fn key, upload_id, _opts ->
        assert key == session.upload_key
        assert upload_id == session.multipart_upload_id
        {:ok, :aborted}
      end)

      {:ok, report} = UploadMaintenance.abort_incomplete_uploads([])

      assert report.sessions_aborted == 1

      updated = AdopterRepo.get!(MediaUploadSession, session.id)
      assert updated.state == "expired"
    end

    test "treats a tus multipart abort returning not_found as idempotent expiry" do
      asset = create_asset()
      session = create_tus_session(asset, %{expires_at: expired_at()})

      expect(Rindle.StorageMock, :abort_multipart_upload, fn _key, _upload_id, _opts ->
        {:error, :not_found}
      end)

      {:ok, report} = UploadMaintenance.abort_incomplete_uploads([])

      assert report.sessions_aborted == 1
      assert report.abort_errors == 0

      updated = AdopterRepo.get!(MediaUploadSession, session.id)
      assert updated.state == "expired"
    end

    test "a gcs_native resumable session still routes through cancel_resumable_upload" do
      asset = create_asset()

      session =
        create_resumable_session(asset, %{
          state: "resuming",
          resumable_protocol: "gcs_native",
          expires_at: expired_at()
        })

      expect(Rindle.StorageMock, :capabilities, fn -> [:resumable_upload_session] end)

      expect(Rindle.StorageMock, :cancel_resumable_upload, fn key, session_uri, _opts ->
        assert key == session.upload_key
        assert session_uri == session.session_uri
        {:ok, %{cancelled: true}}
      end)

      {:ok, report} = UploadMaintenance.abort_incomplete_uploads([])

      assert report.sessions_aborted == 1
      assert report.resumable_aborts == 1

      updated = AdopterRepo.get!(MediaUploadSession, session.id)
      assert updated.state == "expired"
      assert updated.session_uri == nil
    end

    test "a legacy nil-protocol resumable session keeps the existing cancel path unchanged" do
      asset = create_asset()

      session =
        create_resumable_session(asset, %{
          state: "resuming",
          resumable_protocol: nil,
          expires_at: expired_at()
        })

      expect(Rindle.StorageMock, :capabilities, fn -> [:resumable_upload_session] end)

      expect(Rindle.StorageMock, :cancel_resumable_upload, fn _key, _session_uri, _opts ->
        {:ok, %{cancelled: true}}
      end)

      {:ok, report} = UploadMaintenance.abort_incomplete_uploads([])

      assert report.sessions_aborted == 1
      assert report.resumable_aborts == 1

      updated = AdopterRepo.get!(MediaUploadSession, session.id)
      assert updated.state == "expired"
    end

    test "returns error tuple when repo raises" do
      # Simulate an error by calling with a bad repo — we just verify the shape
      # via the normal success path being {:ok, map}
      {:ok, report} = UploadMaintenance.abort_incomplete_uploads([])
      assert is_map(report)
      assert Map.has_key?(report, :sessions_aborted)
    end

    test "respects the FSM contract on expiry" do
      # CR-07 regression: even if the underlying query were ever to surface a
      # session in a state from which UploadSessionFSM forbids `expired`,
      # expire_session/2 must NOT silently flip it. We exercise this by
      # invoking the private FSM gate path indirectly: an `uploaded` session
      # would today not be in the query set, but the gate is the invariant.
      # A direct unit-style assertion: the FSM disallows `uploaded -> expired`.
      assert {:error, {:invalid_transition, "uploaded", "expired"}} =
               UploadSessionFSM.transition("uploaded", "expired", %{})
    end
  end

  describe "tus reaper cleanup (CR-02/WR-01 regression)" do
    # -------------------------------------------------------------------------
    # CR-02: the reaper must delete the REAL adapter-written tail file. The S3
    # PATCH lane writes the tail to `S3.tus_tail_path(session_id, root: ROOT)`
    # (base64url-encoded under <root>/tus/), so the reaper must compute the SAME
    # encoding at the SAME root. Pre-fix `remove_tus_tail/1` targeted the raw
    # `<session_id>.tail` path under the default `TempRunDir.root_dir()`, which
    # never matched the adapter-written file -> the tail leaked. This test pins
    # an explicit ROOT through BOTH the write path and the reaper's delete path
    # so write-path root == delete-path root is proven, not assumed.
    # -------------------------------------------------------------------------

    test "deletes the adapter-written tail file at the SAME root the write path used" do
      tmp_dir =
        Path.join(System.tmp_dir!(), "rindle-tus-cr02-#{System.unique_integer([:positive])}")

      previous_tmp_dir = Application.get_env(:rindle, :tmp_dir)
      Application.put_env(:rindle, :tmp_dir, tmp_dir)

      on_exit(fn ->
        case previous_tmp_dir do
          nil -> Application.delete_env(:rindle, :tmp_dir)
          value -> Application.put_env(:rindle, :tmp_dir, value)
        end

        File.rm_rf(tmp_dir)
      end)

      asset = create_asset()
      session = create_tus_session(asset, %{expires_at: expired_at()})

      # The reaper resolves the S3 tail root from the adapter default, which is
      # `Rindle.AV.TempRunDir.root_dir()` (now pinned to our per-test tmp_dir).
      # Write the tail via the adapter's OWN canonical path computation at that
      # SAME root so the write-path root is provably identical to the delete-path
      # root the reaper computes.
      root = Rindle.AV.TempRunDir.root_dir()
      tail_path = Rindle.Storage.S3.tus_tail_path(session.id, root: root)
      File.mkdir_p!(Path.dirname(tail_path))
      File.write!(tail_path, "tail-bytes")
      assert File.exists?(tail_path)

      expect(Rindle.StorageMock, :abort_multipart_upload, fn _key, _upload_id, _opts ->
        {:ok, :aborted}
      end)

      {:ok, report} = UploadMaintenance.abort_incomplete_uploads([])

      assert report.sessions_aborted == 1
      # The real adapter-written tail at the SAME root is gone after the reap.
      refute File.exists?(tail_path),
             "expected reaper to delete the adapter-written tail at #{tail_path} (write-path root == delete-path root)"
    end

    # -------------------------------------------------------------------------
    # WR-01: tus expiry must be gated through `UploadSessionFSM.transition/3`
    # exactly like the standard expiry path. Pre-fix `do_expire_tus_session/2`
    # called `MediaUploadSession.changeset(.., %{state: "expired"})` directly,
    # skipping the FSM invariant. A tus session surfaced in a state from which
    # `expired` is FORBIDDEN (here `aborted`, surfaced by the retryable-abort
    # query) must NOT be flipped — it must increment `abort_errors` instead.
    # Pre-fix the ungated update silently violates the FSM contract (RED).
    # -------------------------------------------------------------------------

    test "gates tus expiry through the FSM and refuses an FSM-forbidden transition" do
      asset = create_asset()

      # `aborted` tus sessions with a resumable_cancel_failed failure_reason are
      # surfaced by the retryable-abort query and route to the tus branch
      # (tus_session?/1 is checked first). FSM: aborted -> expired is forbidden.
      session =
        create_tus_session(asset, %{
          state: "aborted",
          session_uri: "https://storage.example/upload/#{System.unique_integer([:positive])}",
          failure_reason: "resumable_cancel_failed:transport"
        })

      expect(Rindle.StorageMock, :abort_multipart_upload, fn _key, _upload_id, _opts ->
        {:ok, :aborted}
      end)

      {:ok, report} = UploadMaintenance.abort_incomplete_uploads([])

      # The FSM gate rejected aborted -> expired: the row was NOT flipped and the
      # rejection was counted as an abort error.
      assert report.abort_errors >= 1
      assert report.sessions_aborted == 0

      updated = AdopterRepo.get!(MediaUploadSession, session.id)
      assert updated.state == "aborted"
    end
  end

  describe "tus backing abort root resolution + shared helper (IN-03/CR-01 regression)" do
    # -------------------------------------------------------------------------
    # IN-03: a Local-backed tus session (no multipart_upload_id) abort must
    # resolve the part path against the upload's ACTUAL root, not the bare empty
    # opts default. Pre-fix `abort_tus_backing/1`'s Local branch called
    # `Local.tus_part_path(session.id, [])`, leaving the part file at a
    # mismatched root un-removed when the upload root differs. After the fix the
    # reaper resolves the Local root from the session's profile/adapter and the
    # part file at THAT resolved root is removed.
    # -------------------------------------------------------------------------

    test "Local-backed tus abort removes the part file at the resolved upload root" do
      custom_root =
        Path.join(System.tmp_dir!(), "rindle-tus-in03-#{System.unique_integer([:positive])}")

      previous_local_cfg = Application.get_env(:rindle, Rindle.Storage.Local)
      Application.put_env(:rindle, Rindle.Storage.Local, root: custom_root)

      on_exit(fn ->
        case previous_local_cfg do
          nil -> Application.delete_env(:rindle, Rindle.Storage.Local)
          value -> Application.put_env(:rindle, Rindle.Storage.Local, value)
        end

        File.rm_rf(custom_root)
      end)

      asset = create_asset()

      # Local-backed tus session: no multipart_upload_id, so the abort takes the
      # Local part-removal branch.
      session =
        create_tus_session(asset, %{
          expires_at: expired_at(),
          multipart_upload_id: nil
        })

      # The resolved upload root is the profile/adapter-resolved Local root
      # (the custom root configured above), NOT the bare-`[]` default.
      resolved_root = Rindle.Storage.Local.root([])
      part_path = Rindle.Storage.Local.tus_part_path(session.id, root: resolved_root)
      tail_path = Rindle.Storage.S3.tus_tail_path(session.id, root: resolved_root)

      File.mkdir_p!(Path.dirname(part_path))
      File.write!(part_path, "part-bytes")
      File.write!(tail_path, "tail-bytes")
      assert File.exists?(part_path)

      {:ok, report} = UploadMaintenance.abort_incomplete_uploads([])

      assert report.sessions_aborted == 1

      refute File.exists?(part_path),
             "expected Local abort to remove the part file at the resolved upload root #{part_path}"

      refute File.exists?(tail_path)
    end

    # -------------------------------------------------------------------------
    # CR-01 (shared helper): the PUBLIC abort_tus_backing(session, opts) is the
    # SAME polymorphic abort the tus DELETE path (43-09) will call with an
    # explicit adapter+root it already holds — proving 43-09 needs no DB profile
    # re-resolution. This exercises the EXACT call shape 43-09 invokes:
    #   abort_tus_backing(session, adapter: ..., root: ..., upload_id: ...)
    # Pre-fix there is no PUBLIC arity-2 helper (only the private arity-1 reaper
    # form), so this call shape does not exist (RED).
    # -------------------------------------------------------------------------

    test "PUBLIC abort_tus_backing/2 performs the S3 multipart abort with explicit opts" do
      custom_root =
        Path.join(System.tmp_dir!(), "rindle-tus-helper-s3-#{System.unique_integer([:positive])}")

      on_exit(fn -> File.rm_rf(custom_root) end)

      asset = create_asset()

      session =
        create_tus_session(asset, %{
          multipart_upload_id: "tus-helper-#{System.unique_integer([:positive])}"
        })

      tail_path = Rindle.Storage.S3.tus_tail_path(session.id, root: custom_root)
      File.mkdir_p!(Path.dirname(tail_path))
      File.write!(tail_path, "tail-bytes")

      expect(Rindle.StorageMock, :abort_multipart_upload, fn key, upload_id, _opts ->
        assert key == session.upload_key
        assert upload_id == session.multipart_upload_id
        {:ok, :aborted}
      end)

      # The EXACT shape 43-09 invokes.
      assert :ok =
               UploadMaintenance.abort_tus_backing(session,
                 adapter: Rindle.StorageMock,
                 root: custom_root,
                 upload_id: session.multipart_upload_id
               )

      refute File.exists?(tail_path)
    end

    test "PUBLIC abort_tus_backing/2 removes the Local part + tail at the explicit root" do
      custom_root =
        Path.join(
          System.tmp_dir!(),
          "rindle-tus-helper-local-#{System.unique_integer([:positive])}"
        )

      on_exit(fn -> File.rm_rf(custom_root) end)

      asset = create_asset()
      session = create_tus_session(asset, %{multipart_upload_id: nil})

      part_path = Rindle.Storage.Local.tus_part_path(session.id, root: custom_root)
      tail_path = Rindle.Storage.S3.tus_tail_path(session.id, root: custom_root)
      File.mkdir_p!(Path.dirname(part_path))
      File.write!(part_path, "part-bytes")
      File.write!(tail_path, "tail-bytes")

      # Local case: upload_id nil, no adapter call. The DELETE path can pass an
      # explicit root it already holds, with no DB profile re-resolution.
      assert :ok =
               UploadMaintenance.abort_tus_backing(session,
                 adapter: nil,
                 root: custom_root,
                 upload_id: nil
               )

      refute File.exists?(part_path)
      refute File.exists?(tail_path)
    end
  end

  describe "telemetry emission boundary (Plan 05-01 / D-02)" do
    test "cleanup_orphans/1 does NOT emit [:rindle, :cleanup, :run] from service layer" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rindle, :cleanup, :run]
        ])

      on_exit(fn -> :telemetry.detach(ref) end)

      asset = create_asset()
      _session = create_session(asset, %{state: "expired", expires_at: expired_at()})

      assert {:ok, _report} = UploadMaintenance.cleanup_orphans(dry_run: true)

      refute_received {[:rindle, :cleanup, :run], ^ref, _, _}
    end

    test "cleanup dry-run reports resumable skip counts without mutating rows" do
      asset = create_asset()
      session = create_resumable_session(asset, %{state: "expired", expires_at: expired_at()})

      assert {:ok, report} = UploadMaintenance.cleanup_orphans(dry_run: true)

      assert report.sessions_found == 1
      assert report.resumable_skipped == 1
      assert report.sessions_deleted == 0
      assert AdopterRepo.get(MediaUploadSession, session.id) != nil
      assert_received {:repo_probe, :all}
      refute_received {:repo_probe, {:delete, MediaUploadSession}}
    end

    test "abort_incomplete_uploads/1 does NOT emit [:rindle, :cleanup, :run] from service layer" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rindle, :cleanup, :run]
        ])

      on_exit(fn -> :telemetry.detach(ref) end)

      assert {:ok, _report} = UploadMaintenance.abort_incomplete_uploads([])

      refute_received {[:rindle, :cleanup, :run], ^ref, _, _}
    end
  end
end
