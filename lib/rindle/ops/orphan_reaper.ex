defmodule Rindle.Ops.OrphanReaper do
  @moduledoc """
  Scans a configured temporary directory and cleans up files older than a threshold.
  Prevents storage bloat from orphaned AV temporary files.
  """
  require Logger

  @type report :: %{
          files_scanned: non_neg_integer(),
          files_deleted: non_neg_integer(),
          errors: non_neg_integer()
        }

  @doc """
  Reaps orphan temporary files.

  ## Options

    * `:dir` - the directory to scan (defaults to Application environment or system tmp)
    * `:threshold_sec` - files older than this (in seconds) are deleted (defaults to 86400, 24 hours)
    * `:dry_run` - if true, just reports what would be deleted without actually deleting (default false)
  """
  @spec reap(keyword()) :: report()
  def reap(opts \\ []) do
    dir = Keyword.get(opts, :dir, default_tmp_dir())
    threshold_sec = Keyword.get(opts, :threshold_sec, 86_400)
    dry_run? = Keyword.get(opts, :dry_run, false)

    now = System.system_time(:second)
    threshold_time = now - threshold_sec

    report = %{
      files_scanned: 0,
      files_deleted: 0,
      errors: 0
    }

    if File.exists?(dir) do
      do_reap(dir, threshold_time, dry_run?, report)
    else
      report
    end
  end

  defp do_reap(dir, threshold_time, dry_run?, acc_report) do
    # Only scan top-level or recurse? The plan says "Rindle.tmp/ temporary files".
    # Assuming standard temp files directly in the directory.
    case File.ls(dir) do
      {:ok, files} ->
        Enum.reduce(files, acc_report, fn file_name, acc ->
          process_file(Path.join(dir, file_name), threshold_time, dry_run?, acc)
        end)

      {:error, reason} ->
        Logger.error("rindle.ops.orphan_reaper.ls_failed", dir: dir, reason: inspect(reason))
        %{acc_report | errors: acc_report.errors + 1}
    end
  end

  defp process_file(path, threshold_time, dry_run?, acc) do
    # Use lstat to not follow symlinks, for safety
    case File.lstat(path) do
      {:ok, %File.Stat{type: :regular, mtime: mtime}} ->
        # mtime is a naive datetime tuple from File.stat like {{Y, M, D}, {h, m, s}}
        mtime_seconds =
          mtime
          |> NaiveDateTime.from_erl!()
          |> DateTime.from_naive!("Etc/UTC")
          |> DateTime.to_unix()

        if mtime_seconds < threshold_time do
          delete_file(path, dry_run?, acc)
        else
          %{acc | files_scanned: acc.files_scanned + 1}
        end

      {:ok, _} ->
        # Ignore non-regular files (directories, etc)
        acc

      {:error, _reason} ->
        # Cannot stat file, could be removed already or permission issue
        %{acc | errors: acc.errors + 1}
    end
  end

  defp delete_file(path, dry_run?, acc) do
    if dry_run? do
      Logger.info("rindle.ops.orphan_reaper.dry_run_delete", path: path)
      %{acc | files_scanned: acc.files_scanned + 1}
    else
      case File.rm(path) do
        :ok ->
          Logger.info("rindle.ops.orphan_reaper.deleted", path: path)
          %{acc | files_scanned: acc.files_scanned + 1, files_deleted: acc.files_deleted + 1}

        {:error, reason} ->
          Logger.warning("rindle.ops.orphan_reaper.delete_failed",
            path: path,
            reason: inspect(reason)
          )

          %{acc | files_scanned: acc.files_scanned + 1, errors: acc.errors + 1}
      end
    end
  end

  defp default_tmp_dir do
    Application.get_env(:rindle, :tmp_dir, System.tmp_dir!())
  end
end
