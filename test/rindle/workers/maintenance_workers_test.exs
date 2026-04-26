defmodule Rindle.Workers.MaintenanceWorkersTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo
  import Mox

  alias Rindle.Workers.CleanupOrphans
  alias Rindle.Workers.AbortIncompleteUploads
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
    end

    test "returns :ok on dry-run without touching storage" do
      asset = create_asset()
      _session = create_session(asset, %{state: "expired", expires_at: expired_at()})

      # No storage.delete expected in dry-run
      assert :ok = perform_job(CleanupOrphans, %{"dry_run" => true})
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
      assert CleanupOrphans.__queue__() == :rindle_maintenance
    end

    test "worker has max_attempts set for observability" do
      assert CleanupOrphans.__max_attempts__() >= 1
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
  end

  # ---------------------------------------------------------------------------
  # AbortIncompleteUploads worker — delegation
  # ---------------------------------------------------------------------------

  describe "AbortIncompleteUploads — delegation to UploadMaintenance" do
    test "delegates to UploadMaintenance.abort_incomplete_uploads/1 and returns :ok" do
      asset = create_asset()
      session = create_session(asset, %{state: "signed", expires_at: expired_at()})

      assert :ok = perform_job(AbortIncompleteUploads, %{})

      updated = Rindle.Repo.get!(MediaUploadSession, session.id)
      assert updated.state == "expired"
    end

    test "transitions uploading sessions to expired" do
      asset = create_asset()
      session = create_session(asset, %{state: "uploading", expires_at: expired_at()})

      assert :ok = perform_job(AbortIncompleteUploads, %{})

      updated = Rindle.Repo.get!(MediaUploadSession, session.id)
      assert updated.state == "expired"
    end

    test "returns :ok when no sessions to abort" do
      assert :ok = perform_job(AbortIncompleteUploads, %{})
    end

    test "worker is schedulable as Oban cron job" do
      assert AbortIncompleteUploads.__queue__() == :rindle_maintenance
    end

    test "worker has max_attempts set for observability" do
      assert AbortIncompleteUploads.__max_attempts__() >= 1
    end
  end

  # ---------------------------------------------------------------------------
  # Oban-specific contract: workers are safe for cron scheduling
  # ---------------------------------------------------------------------------

  describe "cron scheduling contract" do
    test "CleanupOrphans implements Oban.Worker" do
      assert function_exported?(CleanupOrphans, :perform, 1)
    end

    test "AbortIncompleteUploads implements Oban.Worker" do
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
end
