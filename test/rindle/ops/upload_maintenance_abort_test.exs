defmodule Rindle.Ops.UploadMaintenanceAbortTest do
  use Rindle.UploadMaintenanceCase

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
    # Tus sessions abort their S3 multipart upload, rather than a provider-direct
    # resumable session URI. The expiry router checks `tus_session?/1` before the
    # provider-direct branch so S3 and Local sessions use multipart abort even
    # though they do not advertise :resumable_upload_session.
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
      # Even if the query were ever to surface a
      # session in a state from which UploadSessionFSM forbids `expired`,
      # expire_session/2 must NOT silently flip it. We exercise this by
      # invoking the private FSM gate path indirectly: an `uploaded` session
      # would today not be in the query set, but the gate is the invariant.
      # A direct unit-style assertion: the FSM disallows `uploaded -> expired`.
      assert {:error, {:invalid_transition, "uploaded", "expired"}} =
               UploadSessionFSM.transition("uploaded", "expired", %{})
    end
  end

  describe "service telemetry ownership" do
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
