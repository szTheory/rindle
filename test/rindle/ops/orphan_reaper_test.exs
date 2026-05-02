defmodule Rindle.Ops.OrphanReaperTest do
  use ExUnit.Case, async: true
  alias Rindle.Ops.OrphanReaper

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    # Create some files with different mtimes
    now = System.system_time(:second)

    # 1. Fresh file (should not be deleted)
    fresh_file = Path.join(tmp_dir, "fresh.tmp")
    File.write!(fresh_file, "fresh")
    File.touch!(fresh_file, now)

    # 2. Old file (should be deleted)
    old_file = Path.join(tmp_dir, "old.tmp")
    File.write!(old_file, "old")
    # Set mtime to 48 hours ago
    File.touch!(old_file, now - 48 * 3600)

    # 3. Very old file (should be deleted)
    very_old_file = Path.join(tmp_dir, "very_old.tmp")
    File.write!(very_old_file, "very_old")
    File.touch!(very_old_file, now - 72 * 3600)

    %{
      tmp_dir: tmp_dir,
      fresh_file: fresh_file,
      old_file: old_file,
      very_old_file: very_old_file
    }
  end

  describe "reap/1" do
    test "deletes files older than threshold", %{
      tmp_dir: tmp_dir,
      fresh_file: fresh_file,
      old_file: old_file,
      very_old_file: very_old_file
    } do
      # Run with 24h threshold
      report = OrphanReaper.reap(dir: tmp_dir, threshold_sec: 24 * 3600)

      assert report.files_scanned == 3
      assert report.files_deleted == 2
      assert report.errors == 0

      # Check files
      assert File.exists?(fresh_file)
      refute File.exists?(old_file)
      refute File.exists?(very_old_file)
    end

    test "handles dry_run option", %{
      tmp_dir: tmp_dir,
      fresh_file: fresh_file,
      old_file: old_file,
      very_old_file: very_old_file
    } do
      report = OrphanReaper.reap(dir: tmp_dir, threshold_sec: 24 * 3600, dry_run: true)

      assert report.files_scanned == 3
      assert report.files_deleted == 0
      assert report.errors == 0

      # Check files all exist still
      assert File.exists?(fresh_file)
      assert File.exists?(old_file)
      assert File.exists?(very_old_file)
    end

    test "handles non-existent directory" do
      report = OrphanReaper.reap(dir: "/path/does/not/exist/for/sure", threshold_sec: 24 * 3600)
      
      assert report.files_scanned == 0
      assert report.files_deleted == 0
      assert report.errors == 0
    end
  end
end
