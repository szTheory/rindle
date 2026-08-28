defmodule Rindle.Ops.UploadMaintenanceCleanupTest do
  use Rindle.UploadMaintenanceCase

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
      # The expired state is the cleanup source of truth even when the timestamp
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

  describe "service telemetry ownership" do
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
  end
end
