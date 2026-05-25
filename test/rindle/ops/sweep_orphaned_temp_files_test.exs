defmodule Rindle.Ops.SweepOrphanedTempFilesTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo

  import ExUnit.CaptureLog

  alias Mix.Tasks.Rindle.SweepOrphanedTempFiles, as: SweepOrphanedTempFilesTask
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

    previous_shell = Mix.shell()
    Mix.shell(Mix.Shell.Process)

    on_exit(fn ->
      Mix.shell(previous_shell)
    end)

    {:ok, root_dir: TempRunDir.root_dir()}
  end

  test "recursively deletes orphaned run directories older than the configured threshold", %{
    root_dir: root_dir
  } do
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

    report = SweepOrphanedTempFiles.sweep(threshold_sec: 4 * 3600)

    assert report.orphan_count == 1
    assert report.run_dirs_deleted == 0
    assert File.exists?(old_dir)
  end

  test "defaults direct service calls to dry-run", %{root_dir: root_dir} do
    old_dir = build_run_dir!(root_dir, "default-dry-run", 5 * 3600)

    report = SweepOrphanedTempFiles.sweep(threshold_sec: 4 * 3600)

    assert report.orphan_count == 1
    assert report.run_dirs_deleted == 0
    assert File.exists?(old_dir)
  end

  test "worker emits orphan-count telemetry on success", %{root_dir: root_dir} do
    _old_dir = build_run_dir!(root_dir, "telemetry-old-run", 5 * 3600)

    ref =
      :telemetry_test.attach_event_handlers(self(), [[:rindle, :media, :sweep_orphans, :stop]])

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

  test "worker defaults to dry-run when not specified", %{root_dir: root_dir} do
    old_dir = build_run_dir!(root_dir, "worker-default-dry-run", 5 * 3600)

    assert :ok = perform_job(SweepOrphanedTempFiles, %{"threshold_sec" => 4 * 3600})

    assert File.exists?(old_dir)
  end

  test "mix task defaults to dry-run and prints the shared report counters", %{root_dir: root_dir} do
    old_dir = build_run_dir!(root_dir, "task-default-dry-run", 5 * 3600)

    capture_log(fn ->
      SweepOrphanedTempFilesTask.run(["--threshold-sec", Integer.to_string(4 * 3600)])
    end)

    assert File.exists?(old_dir)

    assert_received {:mix_shell, :info,
                     [
                       "Rindle: sweeping orphaned temp run directories (dry_run=true, threshold_sec=14400)..."
                     ]}

    assert_received {:mix_shell, :info, ["  run_dirs_scanned: 1"]}
    assert_received {:mix_shell, :info, ["  orphan_count:     1"]}
    assert_received {:mix_shell, :info, ["  run_dirs_deleted: 0"]}
    assert_received {:mix_shell, :info, ["  errors:           0"]}
    assert_received {:mix_shell, :info, ["Done."]}
  end

  test "format_report/2 keeps summary counters first and bounds tagged failures" do
    lines =
      SweepOrphanedTempFilesTask.format_report(
        %{run_dirs_scanned: 7, orphan_count: 4, run_dirs_deleted: 3, errors: 3},
        2
      )

    assert lines == [
             "  run_dirs_scanned: 7",
             "  orphan_count:     4",
             "  run_dirs_deleted: 3",
             "  errors:           3",
             "  [filesystem] scan_or_delete_failed: 3 filesystem operation(s) failed during sweep; inspect logs for per-path detail.",
             "  [filesystem] scan_or_delete_failed: 3 filesystem operation(s) failed during sweep; inspect logs for per-path detail.",
             "  ... 1 additional sweep failure(s) omitted"
           ]
  end

  test "mix task and worker agree on live sweep counters", %{root_dir: root_dir} do
    task_dir = build_run_dir!(root_dir, "task-live-run", 5 * 3600)

    capture_log(fn ->
      SweepOrphanedTempFilesTask.run([
        "--no-dry-run",
        "--threshold-sec",
        Integer.to_string(4 * 3600)
      ])
    end)

    assert_received {:mix_shell, :info, ["  run_dirs_scanned: 1"]}
    assert_received {:mix_shell, :info, ["  orphan_count:     1"]}
    assert_received {:mix_shell, :info, ["  run_dirs_deleted: 1"]}
    assert_received {:mix_shell, :info, ["  errors:           0"]}
    refute File.exists?(task_dir)

    worker_dir = build_run_dir!(root_dir, "worker-live-run", 5 * 3600)

    assert :ok =
             perform_job(SweepOrphanedTempFiles, %{
               "dry_run" => false,
               "threshold_sec" => 4 * 3600
             })

    refute File.exists?(worker_dir)
  end

  describe "tus/ regular-file aging (CR-03 safety net)" do
    test "removes an aged tus/<id>.tail file on a non-dry-run pass", %{root_dir: root_dir} do
      tail = build_tus_file!(root_dir, "aged-session.tail", 5 * 3600)

      report = SweepOrphanedTempFiles.sweep(threshold_sec: 4 * 3600, dry_run: false)

      refute File.exists?(tail)
      assert report.orphan_count >= 1
      assert report.run_dirs_deleted >= 1
      assert report.errors == 0
    end

    test "preserves a fresh tus/<id>.tail file (age threshold respected)", %{root_dir: root_dir} do
      fresh = build_tus_file!(root_dir, "fresh-session.tail", 60)

      report = SweepOrphanedTempFiles.sweep(threshold_sec: 4 * 3600, dry_run: false)

      assert File.exists?(fresh)
      assert report.errors == 0
    end

    test "ages out a tus/<id>.part file alongside .tail files", %{root_dir: root_dir} do
      part = build_tus_file!(root_dir, "aged-session.part", 5 * 3600)

      report = SweepOrphanedTempFiles.sweep(threshold_sec: 4 * 3600, dry_run: false)

      refute File.exists?(part)
      assert report.run_dirs_deleted >= 1
    end

    test "a dry-run pass over an aged tus/ file counts but does not delete", %{root_dir: root_dir} do
      tail = build_tus_file!(root_dir, "aged-session.tail", 5 * 3600)

      report = SweepOrphanedTempFiles.sweep(threshold_sec: 4 * 3600, dry_run: true)

      assert File.exists?(tail)
      assert report.orphan_count >= 1
      assert report.run_dirs_deleted == 0
    end

    test "confines deletion to <root>/tus/ — aged files outside tus/ are untouched", %{
      root_dir: root_dir
    } do
      # An aged regular file directly under <root> (a sibling of tus/), NOT inside
      # tus/. The tus recursion must never touch it; the directory-mtime path does
      # not delete top-level regular files either.
      now = System.system_time(:second)
      File.mkdir_p!(root_dir)
      outside = Path.join(root_dir, "loose-file.bin")
      File.write!(outside, "do-not-delete")
      File.touch!(outside, now - 5 * 3600)

      aged_tail = build_tus_file!(root_dir, "aged-session.tail", 5 * 3600)

      report = SweepOrphanedTempFiles.sweep(threshold_sec: 4 * 3600, dry_run: false)

      # The tus tail is reaped; the loose file outside tus/ survives.
      refute File.exists?(aged_tail)
      assert File.exists?(outside)
      assert report.errors == 0
    end
  end

  defp build_tus_file!(root_dir, filename, age_sec) do
    tus_dir = Path.join(root_dir, "tus")
    File.mkdir_p!(tus_dir)
    path = Path.join(tus_dir, filename)
    File.write!(path, "tail-or-part-bytes")
    now = System.system_time(:second)
    File.touch!(path, now - age_sec)
    # Refresh the tus/ directory mtime so the WHOLE-directory aging path can never
    # be what reaps the file (proving per-file recursion is what deletes it).
    File.touch!(tus_dir, now)
    path
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
