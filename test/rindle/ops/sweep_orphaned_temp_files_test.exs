defmodule Rindle.Ops.SweepOrphanedTempFilesTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo

  alias Rindle.AV.TempRunDir
  alias Rindle.Ops.SweepOrphanedTempFiles

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "rindle-sweep-orphans-#{System.unique_integer([:positive])}")

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

    {:ok, root_dir: TempRunDir.root_dir()}
  end

  test "recursively deletes orphaned run directories older than the configured threshold", %{root_dir: root_dir} do
    old_dir = build_run_dir!(root_dir, "old-run", 5 * 3600)
    fresh_dir = build_run_dir!(root_dir, "fresh-run", 60)

    report = SweepOrphanedTempFiles.sweep(threshold_sec: 4 * 3600, dry_run: false)

    assert report.run_dirs_scanned == 2
    assert report.orphan_count == 1
    assert report.run_dirs_deleted == 1
    assert report.errors == 0
    refute File.exists?(old_dir)
    assert File.exists?(fresh_dir)
  end

  test "supports dry runs without deleting directories", %{root_dir: root_dir} do
    old_dir = build_run_dir!(root_dir, "old-run", 5 * 3600)

    report = SweepOrphanedTempFiles.sweep(threshold_sec: 4 * 3600, dry_run: true)

    assert report.orphan_count == 1
    assert report.run_dirs_deleted == 0
    assert File.exists?(old_dir)
  end

  test "worker emits orphan-count telemetry on success", %{root_dir: root_dir} do
    _old_dir = build_run_dir!(root_dir, "telemetry-old-run", 5 * 3600)
    ref = :telemetry_test.attach_event_handlers(self(), [[:rindle, :media, :sweep_orphans, :stop]])
    on_exit(fn -> :telemetry.detach(ref) end)

    assert :ok =
             perform_job(SweepOrphanedTempFiles, %{
               "dry_run" => false,
               "threshold_sec" => 4 * 3600
             })

    assert_received {[:rindle, :media, :sweep_orphans, :stop], ^ref, measurements, metadata}
    assert measurements.orphan_count == 1
    assert is_integer(measurements.run_dirs_deleted)
    assert metadata.worker == SweepOrphanedTempFiles
    assert metadata.sweep_root == root_dir
    assert metadata.dry_run == false
  end

  defp build_run_dir!(root_dir, name, age_sec) do
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
end
