defmodule Rindle.InstallSmoke.LiveResidueScanTest do
  @moduledoc """
  Merge-blocking live residue scan (CRAFT-04 / CRAFT-06).

  Runs `scripts/maintainer/scan_live_residue.exs --check` against the live tree,
  and exercises every residue class against planted violations in disposable
  git fixture roots. The scanner reads only tracked shipped files and its own
  allowlist shards; it reads nothing from the internal planning tree.

  Planted text is assembled from fragments so this file never contains a line
  the scanner would flag; the scanner also excludes this file by fixed path.
  """
  use ExUnit.Case, async: true

  # Every fixture lives in a root suffixed with unique_integer/1; no path or git
  # repository is shared between concurrent cases.
  @moduletag async_safety_allow: [:file_mutation]

  @repo_root Path.expand("../..", __DIR__)
  @script Path.join(@repo_root, "scripts/maintainer/scan_live_residue.exs")

  # --------------------------------------------------------------- live tree

  test "live tree is fully accounted for by the allowlist shards" do
    {output, status} = run_script(["--check"])

    assert status == 0, output

    assert [_, files] = Regex.run(~r/\((\d+) files,/, output)
    assert String.to_integer(files) > 500, "scan looks vacuous: #{output}"
  end

  # --------------------------------------------------------------- Task 1

  test "unallowlisted decision-id comment fails with path:line: class: text" do
    root =
      fixture(%{
        "lib/planted.ex" => "defmodule P do\n  # tuned (" <> d("D", "-98-03") <> ")\nend\n"
      })

    dir = shards(root, %{})

    {output, status} = run_fixture(root, dir, ["--check"])

    assert status == 1
    assert output =~ "lib/planted.ex:2: decision-id: # tuned ("
  end

  test "an allowlist entry whose count exceeds the live hit count is stale" do
    root = fixture(%{"lib/planted.ex" => "# tuned (" <> d("D", "-98-03") <> ")\n"})

    dir =
      shards(root, %{
        "lib" => [
          entry("lib/planted.ex", "decision-id", "# tuned (" <> d("D", "-98-03") <> ")", 2)
        ]
      })

    {output, status} = run_fixture(root, dir, ["--check"])

    assert status == 1
    assert output =~ "allowlist count differs"
    assert output =~ "entry count 2, live 1"
  end

  test "an exact-count entry passes" do
    root = fixture(%{"lib/planted.ex" => "# tuned (" <> d("D", "-98-03") <> ")\n"})

    dir =
      shards(root, %{
        "lib" => [
          entry("lib/planted.ex", "decision-id", "# tuned (" <> d("D", "-98-03") <> ")", 1)
        ]
      })

    assert {_output, 0} = run_fixture(root, dir, ["--check"])
  end

  test "mojibake sequences fail, correctly encoded text does not" do
    bad_one = <<0xC3::utf8, 0xA9::utf8>>
    bad_two = <<0xE2::utf8, 0x20AC::utf8, 0x201C::utf8>>

    root =
      fixture(%{
        "lib/bad.ex" => "# caf#{bad_one} and #{bad_two}quoted\n",
        "lib/good.ex" => "# café — “quoted” and ’ apostrophe\n"
      })

    dir = shards(root, %{})
    {output, status} = run_fixture(root, dir, ["--check"])

    assert status == 1
    assert output =~ "lib/bad.ex:1: mojibake:"
    refute output =~ "lib/good.ex"
  end

  test "a file that is not valid UTF-8 text fails as mojibake" do
    root = fixture(%{"lib/invalid.ex" => <<"# ", 0xFF, 0xFE, "\n">>})
    dir = shards(root, %{})

    {output, status} = run_fixture(root, dir, ["--check"])

    assert status == 1
    assert output =~ "lib/invalid.ex:1: mojibake:"
  end

  test "misfiled entries are rejected" do
    root = fixture(%{"lib/planted.ex" => "# plain\n"})

    dir =
      shards(root, %{
        "automation_workflows" => [entry("lib/planted.ex", "decision-id", "# x", 1)],
        "unit_tests_a" => [entry("test/rindle/ops/x_test.exs", "decision-id", "# x", 1)]
      })

    {output, status} = run_fixture(root, dir, ["--check"])

    assert status == 1
    assert output =~ "automation_workflows.json"
    assert output =~ "unit_tests_a.json"
    assert output =~ "misfiled"
  end

  test "the self-exclusion list is exactly the scanner, the allowlist directory and this test" do
    assert Enum.sort(excluded_paths_in_source()) ==
             Enum.sort([
               "scripts/maintainer/scan_live_residue.exs",
               "scripts/maintainer/live_residue_allowlist/",
               "test/install_smoke/live_residue_scan_test.exs"
             ])
  end

  # ----------------------------------------------------------------- helpers

  defp excluded_paths_in_source do
    source = File.read!(@script)

    files =
      Regex.scan(~r/@self_files \[(.*?)\]/s, source) |> List.first() |> List.last()

    dir = Regex.run(~r/@self_dir "([^"]+)"/, source) |> List.last()

    Regex.scan(~r/"([^"]+)"/, files) |> Enum.map(&List.last/1) |> Kernel.++([dir])
  end

  # Joins fragments so no source line carries a flagged identifier verbatim.
  defp d(a, b), do: a <> b

  defp entry(path, class, text, count, reason_class \\ "pending-removal", reason \\ "") do
    %{
      "path" => path,
      "class" => class,
      "text" => text,
      "count" => count,
      "reason_class" => reason_class,
      "reason" => reason
    }
  end

  defp fixture(files) do
    root = Path.join(System.tmp_dir!(), "rindle_residue_#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf!(root) end)

    {_, 0} = System.cmd("git", ["init", "-q", root], stderr_to_stdout: true)

    for {rel, content} <- files do
      path = Path.join(root, rel)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, content)
    end

    {_, 0} = System.cmd("git", ["-C", root, "add", "-A"], stderr_to_stdout: true)
    root
  end

  defp shards(root, by_area) do
    dir = root <> "_allow"
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)

    areas = ~w(lib automation_generators automation_workflows install_smoke unit_tests_a
               unit_tests_b examples_docs)

    for area <- areas do
      body = %{
        "schema" => "rindle-live-residue-allowlist-v1",
        "area" => area,
        "entries" => Map.get(by_area, area, [])
      }

      File.write!(Path.join(dir, area <> ".json"), Jason.encode!(body))
    end

    dir
  end

  defp run_fixture(root, dir, args) do
    run_script(["--root", root, "--allowlist-dir", dir | args])
  end

  defp run_script(args) do
    System.cmd("mix", ["run", "--no-compile", "--no-start", @script | args],
      cd: @repo_root,
      env: mix_env(),
      stderr_to_stdout: true
    )
  end

  defp mix_env do
    [
      {"MIX_ENV", Atom.to_string(Mix.env())},
      {"MIX_BUILD_PATH", Mix.Project.build_path()},
      {"MIX_DEPS_PATH", Mix.Project.deps_path()}
    ]
  end
end
