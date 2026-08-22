defmodule Rindle.RepositoryResidueTest do
  use ExUnit.Case, async: true

  # async-safety: justified — every file mutation below is confined to a unique
  # System.tmp_dir! root and removed from on_exit.
  @async_safety_allow [:file_mutation]
  def __async_safety_allow__, do: @async_safety_allow

  @repo_root Path.expand("../..", __DIR__)
  @cleanup_script Path.join(@repo_root, "scripts/gsd_cleanup.sh")
  @gitignore_path Path.join(@repo_root, ".gitignore")
  @transient_files [
    ".DS_Store",
    "erl_crash.dump",
    "init.json",
    "progress.txt",
    "recent.txt",
    "roadmap.json",
    "state.json",
    "credo.json",
    "credo.txt"
  ]
  @root_anchored_gsd_credo_files [
    "init.json",
    "progress.txt",
    "recent.txt",
    "roadmap.json",
    "state.json",
    "credo.json",
    "credo.txt"
  ]
  @obsolete_root_audit_copies [
    "v1.7-v1.7-MILESTONE-AUDIT.md",
    "v1.8-MILESTONE-AUDIT.md",
    "fix_credo.exs",
    "fix_credo.py"
  ]

  test "known root residue never becomes tracked" do
    for path <- @transient_files do
      {_output, status} =
        System.cmd("git", ["ls-files", "--error-unmatch", "--", path],
          cd: @repo_root,
          stderr_to_stdout: true
        )

      assert status != 0, "#{path} is transient root residue and must not be tracked"
    end
  end

  test "ignore rules keep GSD and Credo output root-scoped while OS and crash rules stay general" do
    ignore_lines = @gitignore_path |> File.read!() |> String.split("\n")

    for path <- @root_anchored_gsd_credo_files do
      assert "/#{path}" in ignore_lines,
             "#{path} must keep an exact root-anchored ignore rule"
    end

    assert ".DS_Store" in ignore_lines
    assert "erl_crash.dump" in ignore_lines
    refute "/.DS_Store" in ignore_lines
    refute "/erl_crash.dump" in ignore_lines
  end

  test "obsolete root audit copies are absent without consulting planning paths" do
    for path <- @obsolete_root_audit_copies do
      refute File.exists?(Path.join(@repo_root, path)),
             "#{path} is obsolete root maintenance evidence; the canonical archive must not be duplicated"
    end
  end

  test "cleanup stays an exact non-recursive allowlist" do
    script = File.read!(@cleanup_script)

    for path <- @transient_files do
      assert script =~ ~s("#{path}"), "cleanup must name #{path} explicitly"
    end

    assert script =~ "rm -f -- \"$path\""
    refute script =~ "TRANSIENT_GLOBS"
    refute script =~ "rindle-*"
    refute script =~ "rm -rf"
  end

  test "cleanup removes exact untracked files but preserves tracked matches and package evidence" do
    root = Path.join(System.tmp_dir!(), "rindle-residue-#{System.unique_integer([:positive])}")
    script_path = Path.join(root, "scripts/gsd_cleanup.sh")
    package_sentinel = Path.join(root, "rindle-0.1.0-dev/sentinel.txt")

    File.mkdir_p!(Path.dirname(script_path))
    File.cp!(@cleanup_script, script_path)
    File.chmod!(script_path, 0o755)
    File.mkdir_p!(Path.dirname(package_sentinel))
    File.write!(package_sentinel, "package evidence")
    on_exit(fn -> File.rm_rf(root) end)

    run!("git", ["init", "-q"], root)
    run!("git", ["config", "user.email", "residue-test@example.invalid"], root)
    run!("git", ["config", "user.name", "Repository Residue Test"], root)

    tracked_fixture = Path.join(root, "init.json")
    File.write!(tracked_fixture, "tracked fixture")
    run!("git", ["add", "init.json"], root)
    run!("git", ["commit", "-qm", "tracked cleanup fixture"], root)

    for path <- List.delete(@transient_files, "init.json") do
      File.write!(Path.join(root, path), "untracked fixture")
    end

    {output, 0} = System.cmd("bash", [script_path], cd: root, stderr_to_stdout: true)

    assert output =~ "Skipped tracked paths that matched cleanup rules:"
    assert output =~ "  - init.json"
    assert File.read!(tracked_fixture) == "tracked fixture"
    assert File.read!(package_sentinel) == "package evidence"

    for path <- List.delete(@transient_files, "init.json") do
      refute File.exists?(Path.join(root, path)), "cleanup must remove untracked #{path}"
    end
  end

  defp run!(command, args, root) do
    {output, 0} = System.cmd(command, args, cd: root, stderr_to_stdout: true)
    output
  end
end
