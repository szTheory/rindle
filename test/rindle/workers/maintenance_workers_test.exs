defmodule Rindle.Workers.MaintenanceWorkersTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Adopter.CanonicalApp.Repo
  import Mox

  # why: swaps :rindle, :repo to an adopter/probe repo to exercise Config.repo/0
  # resolution — not the counting-double cross-pollution; see Phase 110 D-09.
  @async_safety_allow [:global_repo_swap]

  alias Ecto.Adapters.SQL.Sandbox
  alias Rindle.Adopter.CanonicalApp.Repo, as: AdopterRepo
  alias Rindle.Domain.{MediaAsset, MediaUploadSession}
  alias Rindle.Ops.SweepOrphanedTempFiles
  alias Rindle.Workers.AbortIncompleteUploads
  alias Rindle.Workers.CleanupOrphans

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

  defp expired_at, do: DateTime.add(DateTime.utc_now(), -100, :second)

  defp build_temp_run_dir!(root_dir, name, age_sec) do
    run_dir = Path.join(root_dir, name)
    nested = Path.join(run_dir, "nested")
    now = System.system_time(:second)

    File.mkdir_p!(nested)
    File.write!(Path.join(run_dir, "source.mp4"), "source")
    File.write!(Path.join(nested, "artifact.mp4"), "artifact")
    File.touch!(run_dir, now - age_sec)
    File.touch!(nested, now - age_sec)
    File.touch!(Path.join(run_dir, "source.mp4"), now - age_sec)
    File.touch!(Path.join(nested, "artifact.mp4"), now - age_sec)
    run_dir
  end

  # ---------------------------------------------------------------------------
  # CleanupOrphans worker — delegation
  # ---------------------------------------------------------------------------

  describe "CleanupOrphans — delegation to UploadMaintenance" do
    test "delegates to UploadMaintenance.cleanup_orphans/1 and returns :ok on success" do
      asset = create_asset()
      _session = create_session(asset, %{state: "expired", expires_at: expired_at()})

      expect(Rindle.StorageMock, :delete, fn _key, _opts ->
        {:ok, :deleted}
      end)

      assert :ok =
               perform_job(CleanupOrphans, %{
                 "dry_run" => false,
                 "storage" => to_string(Rindle.StorageMock)
               })

      assert_received {:repo_probe, :all}
      assert_received {:repo_probe, {:delete, MediaUploadSession}}
    end

    test "returns :ok on dry-run without touching storage" do
      asset = create_asset()
      _session = create_session(asset, %{state: "expired", expires_at: expired_at()})

      # No storage.delete expected in dry-run
      assert :ok = perform_job(CleanupOrphans, %{"dry_run" => true})
      assert_received {:repo_probe, :all}
    end

    test "returns {:error, reason} when cleanup fails" do
      # We use a job with an invalid storage module to trigger an error path
      # The worker should surface cleanup service errors as job errors
      assert {:error, _reason} =
               perform_job(CleanupOrphans, %{
                 "dry_run" => false,
                 "storage" => "Rindle.DoesNotExist.Module"
               })
    end

    test "worker is schedulable as Oban cron job" do
      # Verify the worker uses :rindle_maintenance queue
      opts = CleanupOrphans.__opts__()
      assert Keyword.get(opts, :queue) == :rindle_maintenance
    end

    test "worker has max_attempts set for observability" do
      opts = CleanupOrphans.__opts__()
      assert Keyword.get(opts, :max_attempts) >= 1
    end
  end

  # ---------------------------------------------------------------------------
  # CleanupOrphans worker — result shapes
  # ---------------------------------------------------------------------------

  describe "CleanupOrphans — result reporting" do
    test "processes zero sessions successfully when nothing is expired" do
      assert :ok = perform_job(CleanupOrphans, %{"dry_run" => true})
    end

    test "default dry_run is true when not specified" do
      asset = create_asset()
      _session = create_session(asset, %{state: "expired", expires_at: expired_at()})

      # No storage.delete expected — default should be dry_run: true
      assert :ok = perform_job(CleanupOrphans, %{})
    end

    test "leaves proof-missing resumable rows in place while reporting success" do
      asset = create_asset()
      session = create_resumable_session(asset, %{state: "expired", expires_at: expired_at()})

      assert :ok =
               perform_job(CleanupOrphans, %{
                 "dry_run" => false,
                 "storage" => to_string(Rindle.StorageMock)
               })

      assert AdopterRepo.get(MediaUploadSession, session.id) != nil
    end
  end

  describe "SweepOrphanedTempFiles — scheduled maintenance parity" do
    setup do
      tmp_dir =
        Path.join(
          System.tmp_dir!(),
          "rindle-maintenance-sweep-#{System.unique_integer([:positive])}"
        )

      File.mkdir_p!(tmp_dir)

      previous_tmp_dir = Application.get_env(:rindle, :tmp_dir)
      Application.put_env(:rindle, :tmp_dir, tmp_dir)

      on_exit(fn ->
        if is_nil(previous_tmp_dir) do
          Application.delete_env(:rindle, :tmp_dir)
        else
          Application.put_env(:rindle, :tmp_dir, previous_tmp_dir)
        end

        File.rm_rf(tmp_dir)
      end)

      {:ok, sweep_root: Path.join(tmp_dir, "Rindle.tmp")}
    end

    test "worker is schedulable on the maintenance queue" do
      opts = SweepOrphanedTempFiles.__opts__()
      assert Keyword.get(opts, :queue) == :rindle_maintenance
      assert Keyword.get(opts, :max_attempts) >= 1
    end

    test "worker defaults to dry-run for scheduled previews", %{sweep_root: sweep_root} do
      run_dir = build_temp_run_dir!(sweep_root, "scheduled-default-dry-run", 5 * 3600)

      assert :ok =
               perform_job(SweepOrphanedTempFiles, %{
                 "threshold_sec" => 4 * 3600
               })

      assert File.exists?(run_dir)
    end

    test "worker performs live deletion only with explicit opt-in", %{sweep_root: sweep_root} do
      run_dir = build_temp_run_dir!(sweep_root, "scheduled-live-run", 5 * 3600)

      assert :ok =
               perform_job(SweepOrphanedTempFiles, %{
                 "dry_run" => false,
                 "threshold_sec" => 4 * 3600
               })

      refute File.exists?(run_dir)
    end
  end

  # ---------------------------------------------------------------------------
  # AbortIncompleteUploads worker — delegation
  # ---------------------------------------------------------------------------

  describe "AbortIncompleteUploads — delegation to UploadMaintenance" do
    test "delegates to UploadMaintenance.abort_incomplete_uploads/1 and returns :ok" do
      asset = create_asset()
      session = create_session(asset, %{state: "signed", expires_at: expired_at()})

      assert :ok = perform_job(AbortIncompleteUploads, %{})

      updated = AdopterRepo.get!(MediaUploadSession, session.id)
      assert updated.state == "expired"
      assert_received {:repo_probe, :all}
      assert_received {:repo_probe, {:update, MediaUploadSession}}
    end

    test "transitions uploading sessions to expired" do
      asset = create_asset()
      session = create_session(asset, %{state: "uploading", expires_at: expired_at()})

      assert :ok = perform_job(AbortIncompleteUploads, %{})

      updated = AdopterRepo.get!(MediaUploadSession, session.id)
      assert updated.state == "expired"
      assert_received {:repo_probe, :all}
      assert_received {:repo_probe, {:update, MediaUploadSession}}
    end

    test "returns :ok when no sessions to abort" do
      assert :ok = perform_job(AbortIncompleteUploads, %{})
    end

    test "expires multipart-tagged sessions without cleanup side effects in the worker" do
      asset = create_asset()
      session = create_multipart_session(asset, %{state: "uploading", expires_at: expired_at()})

      assert :ok = perform_job(AbortIncompleteUploads, %{})

      updated = AdopterRepo.get!(MediaUploadSession, session.id)
      assert updated.state == "expired"
      assert_received {:repo_probe, :all}
      assert_received {:repo_probe, {:update, MediaUploadSession}}
      refute_received {:repo_probe, {:delete, MediaUploadSession}}
    end

    test "expires initialized multipart sessions without cleanup side effects in the worker" do
      asset = create_asset()
      session = create_multipart_session(asset, %{state: "initialized", expires_at: expired_at()})

      assert :ok = perform_job(AbortIncompleteUploads, %{})

      updated = AdopterRepo.get!(MediaUploadSession, session.id)
      assert updated.state == "expired"
      assert_received {:repo_probe, :all}
      assert_received {:repo_probe, {:update, MediaUploadSession}}
      refute_received {:repo_probe, {:delete, MediaUploadSession}}
    end

    test "worker is schedulable as Oban cron job" do
      opts = AbortIncompleteUploads.__opts__()
      assert Keyword.get(opts, :queue) == :rindle_maintenance
    end

    test "worker has max_attempts set for observability" do
      opts = AbortIncompleteUploads.__opts__()
      assert Keyword.get(opts, :max_attempts) >= 1
    end

    test "returns error when resumable abort errors remain so Oban can retry" do
      asset = create_asset()
      session = create_resumable_session(asset, %{expires_at: expired_at()})

      expect(Rindle.StorageMock, :capabilities, fn -> [:resumable_upload_session] end)

      expect(Rindle.StorageMock, :cancel_resumable_upload, fn _, _, _ ->
        {:error, :timeout}
      end)

      assert {:error, {:abort_errors, 1}} = perform_job(AbortIncompleteUploads, %{})

      updated = AdopterRepo.get!(MediaUploadSession, session.id)
      assert updated.state == "aborted"
      assert updated.failure_reason == "resumable_cancel_failed:transport"
    end
  end

  # ---------------------------------------------------------------------------
  # Oban-specific contract: workers are safe for cron scheduling
  # ---------------------------------------------------------------------------

  describe "cron scheduling contract" do
    test "CleanupOrphans implements Oban.Worker" do
      Code.ensure_loaded(CleanupOrphans)
      assert function_exported?(CleanupOrphans, :perform, 1)
    end

    test "AbortIncompleteUploads implements Oban.Worker" do
      Code.ensure_loaded(AbortIncompleteUploads)
      assert function_exported?(AbortIncompleteUploads, :perform, 1)
    end

    test "CleanupOrphans perform/1 accepts Oban.Job struct" do
      # Can be enqueued as a scheduled job
      job_args = %{}
      assert {:ok, _job} = Oban.insert(CleanupOrphans.new(job_args))
    end

    test "AbortIncompleteUploads perform/1 accepts Oban.Job struct" do
      job_args = %{}
      assert {:ok, _job} = Oban.insert(AbortIncompleteUploads.new(job_args))
    end
  end

  # ---------------------------------------------------------------------------
  # Telemetry emission (Plan 05-01 / TEL-05)
  # ---------------------------------------------------------------------------

  describe "telemetry emission (Plan 05-01 / TEL-05)" do
    setup do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:rindle, :cleanup, :run]
        ])

      on_exit(fn -> :telemetry.detach(ref) end)
      {:ok, ref: ref}
    end

    test "CleanupOrphans emits [:rindle, :cleanup, :run] on success", %{ref: ref} do
      asset = create_asset()
      _session = create_session(asset, %{state: "expired", expires_at: expired_at()})

      expect(Rindle.StorageMock, :delete, fn _key, _opts ->
        {:ok, :deleted}
      end)

      assert :ok =
               perform_job(CleanupOrphans, %{
                 "dry_run" => false,
                 "storage" => to_string(Rindle.StorageMock)
               })

      assert_received {[:rindle, :cleanup, :run], ^ref, measurements, metadata}
      assert is_integer(measurements.sessions_deleted)
      assert is_integer(measurements.objects_deleted)
      assert is_integer(measurements.resumable_skipped)
      assert metadata.profile == :unknown
      assert metadata.adapter == Rindle.StorageMock
      assert is_boolean(metadata.dry_run)
      assert metadata.worker == CleanupOrphans
    end

    test "CleanupOrphans telemetry includes resumable skip counts for proof-missing rows", %{
      ref: ref
    } do
      asset = create_asset()
      _session = create_resumable_session(asset, %{state: "expired", expires_at: expired_at()})

      assert :ok =
               perform_job(CleanupOrphans, %{
                 "dry_run" => false,
                 "storage" => to_string(Rindle.StorageMock)
               })

      assert_received {[:rindle, :cleanup, :run], ^ref, measurements, metadata}
      assert measurements.sessions_deleted == 0
      assert measurements.resumable_skipped == 1
      assert metadata.worker == CleanupOrphans
    end

    test "CleanupOrphans emits in dry-run with adapter and dry_run=true", %{ref: ref} do
      _ = create_asset()

      assert :ok = perform_job(CleanupOrphans, %{"dry_run" => true})

      assert_received {[:rindle, :cleanup, :run], ^ref, measurements, metadata}
      assert is_integer(measurements.sessions_deleted)
      assert is_integer(measurements.objects_deleted)
      assert metadata.dry_run == true
      assert metadata.worker == CleanupOrphans
    end

    test "CleanupOrphans does NOT emit on storage adapter resolution failure", %{ref: ref} do
      assert {:error, _} =
               perform_job(CleanupOrphans, %{
                 "dry_run" => false,
                 "storage" => "Rindle.DoesNotExist.Module"
               })

      refute_received {[:rindle, :cleanup, :run], ^ref, _, _}
    end

    test "AbortIncompleteUploads emits [:rindle, :cleanup, :run] on success", %{ref: ref} do
      asset = create_asset()
      session = create_resumable_session(asset, %{expires_at: expired_at()})

      expect(Rindle.StorageMock, :capabilities, fn -> [:resumable_upload_session] end)

      expect(Rindle.StorageMock, :cancel_resumable_upload, fn key, session_uri, _opts ->
        assert key == session.upload_key
        assert session_uri == session.session_uri
        {:ok, %{cancelled: true}}
      end)

      assert :ok = perform_job(AbortIncompleteUploads, %{})

      assert_received {[:rindle, :cleanup, :run], ^ref, measurements, metadata}
      assert is_integer(measurements.sessions_aborted)
      assert measurements.resumable_aborts == 1
      assert metadata.profile == :unknown
      assert metadata.adapter == :unknown
      assert metadata.worker == AbortIncompleteUploads
    end

    test "AbortIncompleteUploads emits even when no sessions match", %{ref: ref} do
      assert :ok = perform_job(AbortIncompleteUploads, %{})

      assert_received {[:rindle, :cleanup, :run], ^ref, measurements, metadata}
      assert measurements.sessions_aborted == 0
      assert metadata.worker == AbortIncompleteUploads
    end
  end
end
