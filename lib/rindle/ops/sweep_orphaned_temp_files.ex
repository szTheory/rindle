defmodule Rindle.Ops.SweepOrphanedTempFiles do
  @moduledoc """
  Dedicated recursive sweeper for `Rindle.tmp/` AV run directories.

  This module is the shared service contract for the direct Elixir call,
  the on-demand Mix task, and the scheduled Oban worker lane.

  ## tus/ regular-file aging (CR-03 safety net)

  AV run dirs are aged out as whole directories. The tus backing files used by
  the resumable-upload path, however, live as individual regular files under a
  single shared `<root>/tus/` subdirectory (S3 tails at `<root>/tus/<id>.tail`,
  Local parts at `<root>/tus/<id>.part`). That `tus/` directory's mtime is
  refreshed on every write, so it never crosses the age threshold on any active
  system and is never reaped as a whole. To prevent unbounded accumulation, the
  sweeper recurses into `tus/` specifically and ages out individual regular
  files there (per-file mtime older than the threshold). Deletion is confined
  strictly to `<root>/tus/`; no other directory's regular files are touched.
  This is a backstop behind the explicit end-of-life cleanup (the S3
  best-effort `File.rm`, the tus DELETE handler, and the reaper) — not the
  primary cleanup path.
  """

  use Oban.Worker, queue: :rindle_maintenance, max_attempts: 3

  require Logger

  alias Rindle.AV.TempRunDir

  @default_threshold_sec 14_400

  @type report :: %{
          run_dirs_scanned: non_neg_integer(),
          orphan_count: non_neg_integer(),
          run_dirs_deleted: non_neg_integer(),
          errors: non_neg_integer()
        }

  @spec perform(Oban.Job.t()) :: :ok
  def perform(%Oban.Job{args: args}) do
    threshold_sec = Map.get(args, "threshold_sec", @default_threshold_sec)
    dry_run? = Map.get(args, "dry_run", true)
    report = sweep(threshold_sec: threshold_sec, dry_run: dry_run?)

    Logger.info("rindle.ops.sweep_orphaned_temp_files.completed",
      run_dirs_scanned: report.run_dirs_scanned,
      orphan_count: report.orphan_count,
      run_dirs_deleted: report.run_dirs_deleted,
      dry_run: dry_run?
    )

    :telemetry.execute(
      [:rindle, :media, :sweep_orphans, :stop],
      %{
        orphan_count: report.orphan_count,
        run_dirs_deleted: report.run_dirs_deleted
      },
      %{
        worker: __MODULE__,
        sweep_root: TempRunDir.root_dir(),
        dry_run: dry_run?
      }
    )

    :ok
  end

  @spec sweep(keyword()) :: report()
  def sweep(opts \\ []) do
    root = Keyword.get(opts, :dir, TempRunDir.root_dir())
    threshold_sec = Keyword.get(opts, :threshold_sec, @default_threshold_sec)
    dry_run? = Keyword.get(opts, :dry_run, true)
    threshold_time = System.system_time(:second) - threshold_sec

    base = %{run_dirs_scanned: 0, orphan_count: 0, run_dirs_deleted: 0, errors: 0}

    if File.dir?(root) do
      root
      |> File.ls!()
      |> Enum.reduce(base, fn entry, acc ->
        path = Path.join(root, entry)
        process_run_dir(path, threshold_time, dry_run?, acc)
      end)
    else
      base
    end
  end

  defp process_run_dir(path, threshold_time, dry_run?, acc) do
    case File.lstat(path) do
      {:ok, %File.Stat{type: :directory, mtime: mtime}} ->
        # The shared `tus/` subdir holds individual resumable-upload backing
        # files whose own mtimes age, but the directory mtime is perpetually
        # refreshed on write — so recurse and age out the files themselves
        # (CR-03) instead of waiting for the whole directory to cross the
        # threshold (which never happens on an active system).
        if Path.basename(path) == "tus" do
          sweep_tus_dir(path, threshold_time, dry_run?, acc)
        else
          run_dir_mtime = mtime_to_unix(mtime)
          acc = %{acc | run_dirs_scanned: acc.run_dirs_scanned + 1}

          if run_dir_mtime < threshold_time do
            delete_run_dir(path, dry_run?, acc)
          else
            acc
          end
        end

      {:ok, _stat} ->
        acc

      {:error, _reason} ->
        %{acc | errors: acc.errors + 1}
    end
  end

  # Recurse into `<root>/tus/` and age out individual regular files. Deletion is
  # confined strictly to this directory — only regular files (never nested dirs
  # or symlinks) whose own mtime is past the threshold are removed. dry_run
  # semantics mirror `delete_run_dir/3`: count, do not delete.
  defp sweep_tus_dir(tus_path, threshold_time, dry_run?, acc) do
    acc = %{acc | run_dirs_scanned: acc.run_dirs_scanned + 1}

    case File.ls(tus_path) do
      {:ok, entries} ->
        Enum.reduce(entries, acc, fn entry, acc ->
          age_tus_file(Path.join(tus_path, entry), threshold_time, dry_run?, acc)
        end)

      {:error, _reason} ->
        %{acc | errors: acc.errors + 1}
    end
  end

  defp age_tus_file(path, threshold_time, dry_run?, acc) do
    case File.lstat(path) do
      {:ok, %File.Stat{type: :regular, mtime: mtime}} ->
        if mtime_to_unix(mtime) < threshold_time do
          delete_tus_file(path, dry_run?, acc)
        else
          acc
        end

      # Non-regular entries (nested dirs, symlinks) are left untouched — the
      # safety net only reaps aged regular tail/part files.
      {:ok, _stat} ->
        acc

      {:error, _reason} ->
        %{acc | errors: acc.errors + 1}
    end
  end

  defp delete_tus_file(_path, true, acc) do
    %{acc | orphan_count: acc.orphan_count + 1}
  end

  defp delete_tus_file(path, false, acc) do
    case File.rm(path) do
      :ok ->
        %{acc | orphan_count: acc.orphan_count + 1, run_dirs_deleted: acc.run_dirs_deleted + 1}

      {:error, _reason} ->
        %{acc | orphan_count: acc.orphan_count + 1, errors: acc.errors + 1}
    end
  end

  defp delete_run_dir(_path, true, acc) do
    %{acc | orphan_count: acc.orphan_count + 1}
  end

  defp delete_run_dir(path, false, acc) do
    case File.rm_rf(path) do
      {:ok, _paths} ->
        %{acc | orphan_count: acc.orphan_count + 1, run_dirs_deleted: acc.run_dirs_deleted + 1}

      {:error, _reason, _bad_path} ->
        %{acc | orphan_count: acc.orphan_count + 1, errors: acc.errors + 1}
    end
  end

  defp mtime_to_unix(mtime) do
    mtime
    |> NaiveDateTime.from_erl!()
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_unix()
  end
end
