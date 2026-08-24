defmodule Rindle.Ops.UploadMaintenanceTusTest do
  use Rindle.UploadMaintenanceCase

  describe "tus reaper cleanup" do
    # -------------------------------------------------------------------------
    # The reaper must delete the adapter-written tail file. The S3
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
    # Tus expiry must pass through `UploadSessionFSM.transition/3`
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

  describe "tus backing abort root resolution and shared helper" do
    # -------------------------------------------------------------------------
    # A Local-backed tus session without a multipart upload ID must
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
    # The public abort_tus_backing(session, opts) helper is the
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

  describe "tus DELETE-time abort-failure recovery" do
    # -------------------------------------------------------------------------
    # A tus DELETE whose backing abort failed transiently
    # leaves the row in state="aborted" with a retryable `tus_abort_failed:%`
    # marker (written by tus_plug.ex). The reaper MUST re-select such a row,
    # re-invoke abort_multipart_upload, and on success settle it WITHOUT an
    # forbidden aborted->expired FSM transition. Without the retry query, the
    # `fetch_retryable_tus_abort_sessions/0` query does not exist, so the row is
    # never selected and the Mox expect goes unsatisfied -> RED.
    # -------------------------------------------------------------------------

    test "re-aborts a marked tus session and settles it without an invalid FSM transition" do
      asset = create_asset()

      session =
        create_tus_session(asset, %{
          state: "aborted",
          failure_reason: "tus_abort_failed:transport"
        })

      # The orphaned multipart is re-aborted with
      # the session's upload_key + multipart_upload_id.
      expect(Rindle.StorageMock, :abort_multipart_upload, fn key, upload_id, _opts ->
        assert key == session.upload_key
        assert upload_id == session.multipart_upload_id
        {:ok, :aborted}
      end)

      {:ok, report} = UploadMaintenance.abort_incomplete_uploads([])

      assert report.sessions_found == 1
      assert report.sessions_aborted == 1
      # The settle path bypasses the FSM gate, so no invalid transition
      # was attempted -> abort_errors stays 0.
      assert report.abort_errors == 0
      assert report.resumable_aborts == 1

      updated = AdopterRepo.get!(MediaUploadSession, session.id)
      assert updated.state == "expired"
      assert updated.failure_reason == nil
    end

    test "treats a re-abort returning not_found as idempotent success and settles the row" do
      asset = create_asset()

      session =
        create_tus_session(asset, %{
          state: "aborted",
          failure_reason: "tus_abort_failed:transport"
        })

      expect(Rindle.StorageMock, :abort_multipart_upload, fn _key, _upload_id, _opts ->
        {:error, :not_found}
      end)

      {:ok, report} = UploadMaintenance.abort_incomplete_uploads([])

      assert report.sessions_aborted == 1
      assert report.abort_errors == 0

      updated = AdopterRepo.get!(MediaUploadSession, session.id)
      assert updated.state == "expired"
      assert updated.failure_reason == nil
    end

    test "a re-abort that still fails keeps the row aborted with the marker intact (re-selectable next cron, no new permanent orphan)" do
      asset = create_asset()

      session =
        create_tus_session(asset, %{
          state: "aborted",
          failure_reason: "tus_abort_failed:transport"
        })

      expect(Rindle.StorageMock, :abort_multipart_upload, fn _key, _upload_id, _opts ->
        {:error, :transport}
      end)

      {:ok, report} = UploadMaintenance.abort_incomplete_uploads([])

      assert report.sessions_aborted == 0
      assert report.abort_errors == 1

      updated = AdopterRepo.get!(MediaUploadSession, session.id)
      # Still aborted, marker intact -> re-selectable on the next cron.
      assert updated.state == "aborted"
      assert updated.failure_reason == "tus_abort_failed:transport"
    end

    test "does NOT re-select a clean aborted tus session whose abort succeeded (failure_reason nil) — keys on the marker, not state==aborted" do
      asset = create_asset()

      _session =
        create_tus_session(asset, %{
          state: "aborted",
          failure_reason: nil
        })

      # No Mox expect: a clean cancel must NEVER be re-aborted (no double-abort).
      {:ok, report} = UploadMaintenance.abort_incomplete_uploads([])

      assert report.sessions_found == 0
      assert report.sessions_aborted == 0
    end
  end
end
