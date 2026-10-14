defmodule Rindle.PlanningPathHygieneTest do
  @moduledoc """
  Phase 111 (Regression Locks) LOCK-05 regression lock: NO test under `test/`
  may read a live repository planning-doc path at runtime.

  Internal planning directories move when a milestone is archived (gsd-cleanup
  relocates them under `milestones/<ver>-phases/`). A test that hard-codes a
  read rooted at the repository (the `install_smoke archive path coupling`
  footgun) silently breaks the merge-blocking `quality` lane for a non-shipped
  reason. Disposable fixture roots may contain planning artifacts so tests can
  verify byte-preserving behavior without coupling to the live planning tree.
  This lock globs the whole `test/**/*.exs` tree and fails if any file reads a
  planning path via `File.read!`, `File.exists?`, or `Path.expand`.

  Deliberately asserts SHIPPED artifacts ONLY: it reads files under `test/`
  (the glob root) and nothing else. The detection regex is assembled at runtime
  from interpolated fragments so this very file does NOT itself contain a line
  that both calls one of those read functions AND names the planning directory —
  otherwise the scan would flag itself. No exclude tag → default suite →
  merge-blocking `quality` lane, mirroring `async_safety_guard_test.exs`.
  """
  use ExUnit.Case, async: true

  @test_root Path.expand("..", __DIR__)
  @glob Path.join(@test_root, "test/**/*.exs")

  # The planning directory token, assembled from parts so the literal
  # "<dot>planning" path segment never appears as a bare written substring on a
  # line that also names a read call (which would make this file flag itself).
  @planning_dir_token "." <> "planning"

  # Read-call fragments combined with the directory token. Assembled via
  # Regex.compile! at runtime so the full offending pattern is never a literal
  # in this source. Requires BOTH a file-read call AND the planning directory on
  # the SAME line.
  @planning_read_regex Regex.compile!(
                         "(File\\.(read!|exists\\?)|Path\\.expand)[^)]*" <>
                           Regex.escape(@planning_dir_token)
                       )

  setup_all do
    files = Path.wildcard(@glob)

    # Anti-vacuous guard: an empty or mis-rooted glob must fail loudly rather
    # than passing silently (mirrors async_safety_guard_test.exs).
    assert files != [], "expected test/**/*.exs glob to match files, got none"

    {:ok, files: files}
  end

  test "no test/**/*.exs file reads a live repository planning path at runtime (LOCK-05)", %{
    files: files
  } do
    offenders =
      files
      |> Enum.flat_map(fn path ->
        relpath = Path.relative_to(path, @test_root)

        path
        |> File.read!()
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.filter(fn {line, _n} -> planning_path_read?(line) end)
        |> Enum.map(fn {line, n} -> "#{relpath}:#{n}: #{String.trim(line)}" end)
      end)
      |> Enum.sort()

    assert offenders == [], failure_message(offenders)
  end

  test "LOCK-05 distinguishes repository paths from disposable fixture roots" do
    requirements_path = @planning_dir_token <> "/REQUIREMENTS.md"
    repository_read = "File." <> "read!(Path.join(repo_root, \"" <> requirements_path <> "\"))"
    fixture_read = "File." <> "read!(Path.join(fixture.root, \"" <> requirements_path <> "\"))"

    assert planning_path_read?(repository_read)
    refute planning_path_read?(fixture_read)
  end

  defp planning_path_read?(line) do
    Regex.match?(@planning_read_regex, line) and not String.contains?(line, "fixture.root")
  end

  defp failure_message([]), do: "no planning-path-coupling offenders"

  defp failure_message(offenders) do
    lines = Enum.map_join(offenders, "\n", &"  - #{&1}")

    """
    Found #{length(offenders)} test file(s) that read an internal planning path at \
    runtime via File.read!/File.exists?/Path.expand:

    #{lines}

    Internal planning directories move when a milestone is archived (gsd-cleanup), \
    so a runtime read of such a path breaks the merge-blocking quality lane for a \
    non-shipped reason. Assert SHIPPED artifacts only (scripts/, test/, .github/).
    """
  end
end
