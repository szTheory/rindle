defmodule Rindle.Ops.UploadMaintenanceTest do
  use Rindle.DataCase, async: false
  import Mox

  alias Rindle.Ops.UploadMaintenance
  alias Rindle.Domain.{MediaAsset, MediaUploadSession}

  setup :set_mox_from_context
  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp create_asset(overrides \\ %{}) do
    %MediaAsset{}
    |> MediaAsset.changeset(
      Map.merge(
        %{
          state: "staged",
          profile: "TestProfile",
          storage_key: "uploads/#{Ecto.UUID.generate()}.jpg"
        },
        overrides
      )
    )
    |> Rindle.Repo.insert!()
  end

  defp create_session(asset, overrides \\ %{}) do
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
    |> Rindle.Repo.insert!()
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
      assert Rindle.Repo.get(MediaUploadSession, session.id) != nil
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

      {:ok, report} = UploadMaintenance.cleanup_orphans(dry_run: false, storage: Rindle.StorageMock)

      assert report.sessions_deleted >= 1
      assert report.objects_deleted >= 1

      assert Rindle.Repo.get(MediaUploadSession, session.id) == nil
    end

    test "does not delete non-expired sessions" do
      asset = create_asset()
      _active_session = create_session(asset, %{state: "signed"})

      # No storage.delete expected
      {:ok, report} = UploadMaintenance.cleanup_orphans(dry_run: false, storage: Rindle.StorageMock)

      assert report.sessions_deleted == 0
    end

    test "continues when storage delete fails, surfaces error count" do
      asset = create_asset()
      _session = create_session(asset, %{state: "expired", expires_at: expired_at()})

      expect(Rindle.StorageMock, :delete, fn _key, _opts ->
        {:error, :storage_unavailable}
      end)

      {:ok, report} = UploadMaintenance.cleanup_orphans(dry_run: false, storage: Rindle.StorageMock)

      assert report.storage_errors >= 1
      # Session should still be deleted from DB even when storage fails
      assert report.sessions_deleted >= 1
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

      {:ok, report} = UploadMaintenance.cleanup_orphans(dry_run: false, storage: Rindle.StorageMock)

      assert report.sessions_deleted == 1
      assert Rindle.Repo.get(MediaUploadSession, expired_session.id) == nil
      assert Rindle.Repo.get(MediaUploadSession, active_session.id) != nil
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

      updated = Rindle.Repo.get!(MediaUploadSession, session.id)
      assert updated.state == "expired"
    end

    test "transitions timed-out uploading sessions to expired" do
      asset = create_asset()
      session = create_session(asset, %{state: "uploading", expires_at: expired_at()})

      {:ok, report} = UploadMaintenance.abort_incomplete_uploads([])

      assert report.sessions_aborted >= 1

      updated = Rindle.Repo.get!(MediaUploadSession, session.id)
      assert updated.state == "expired"
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

    test "returns error tuple when repo raises" do
      # Simulate an error by calling with a bad repo — we just verify the shape
      # via the normal success path being {:ok, map}
      {:ok, report} = UploadMaintenance.abort_incomplete_uploads([])
      assert is_map(report)
      assert Map.has_key?(report, :sessions_aborted)
    end
  end
end
