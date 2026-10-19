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

  # --------------------------------------------------------------- Task 2

  @planted_classes [
    {"requirement-id", "lib/planted.ex", "# per " <> "CRAFT" <> "-04\n"},
    {"phase-ref", "lib/planted.ex", "# see " <> "Phase" <> " 12\n"},
    {"spec-ref", "lib/planted.ex", "# layout " <> "UI" <> "-SPEC section\n"},
    {"planning-path", "lib/planted.ex", "# reads " <> "." <> "planning" <> "/PROJECT.md\n"},
    {"milestone-ref", "lib/planted.ex", "# since " <> "v1" <> ".7 only\n"},
    {"plan-ref", "lib/planted.ex", "# from " <> "Plan" <> " 05-04\n"},
    {"path-name", "scripts/phase_" <> "132_thing.json", "{}\n"}
  ]

  for {class, path, content} <- @planted_classes do
    test "planted #{class} violation fails with that class" do
      root = fixture(%{unquote(path) => unquote(content)})
      dir = shards(root, %{})

      {output, status} = run_fixture(root, dir, ["--check"])

      assert status == 1
      assert output =~ unquote(path) <> ":"
      assert output =~ ": #{unquote(class)}: "
    end
  end

  test "--require-no-pending AREA fails only for pending entries in that shard" do
    text = "# per " <> "CRAFT" <> "-04"
    root = fixture(%{"lib/planted.ex" => text <> "\n"})

    pending = %{"lib" => [entry("lib/planted.ex", "requirement-id", text, 1)]}
    dir = shards(root, pending)

    {output, status} = run_fixture(root, dir, ["--check", "--require-no-pending", "lib"])
    assert status == 1
    assert output =~ "pending-removal entry remains in lib"

    {_, other_status} =
      run_fixture(root, dir, ["--check", "--require-no-pending", "unit_tests_b"])

    assert other_status == 0

    {_, all_status} = run_fixture(root, dir, ["--check", "--require-no-pending", "all"])
    assert all_status == 1
  end

  test "--require-no-pending passes when only contract entries remain" do
    text = "# per " <> "CRAFT" <> "-04"
    root = fixture(%{"lib/planted.ex" => text <> "\n"})

    dir =
      shards(root, %{
        "lib" => [
          entry(
            "lib/planted.ex",
            "requirement-id",
            text,
            1,
            "contract",
            "The id is the contract."
          )
        ]
      })

    assert {_, 0} = run_fixture(root, dir, ["--check", "--require-no-pending", "all"])
  end

  test "a non-pending entry with an empty reason is rejected" do
    text = "# per " <> "CRAFT" <> "-04"
    root = fixture(%{"lib/planted.ex" => text <> "\n"})

    dir =
      shards(root, %{"lib" => [entry("lib/planted.ex", "requirement-id", text, 1, "policy", " ")]})

    {output, status} = run_fixture(root, dir, ["--check"])
    assert status == 1
    assert output =~ "needs a non-empty reason"
  end

  test "an unknown reason_class is rejected" do
    text = "# per " <> "CRAFT" <> "-04"
    root = fixture(%{"lib/planted.ex" => text <> "\n"})

    dir =
      shards(root, %{
        "lib" => [entry("lib/planted.ex", "requirement-id", text, 1, "tolerated", "x")]
      })

    {output, status} = run_fixture(root, dir, ["--check"])
    assert status == 1
    assert output =~ "unknown reason_class"
  end

  test "contract-classed message text is protected in the live shards" do
    lib = live_shard("lib")

    assert Enum.any?(lib["entries"], fn e ->
             e["path"] == "lib/rindle/error.ex" and e["class"] == "milestone-ref" and
               e["reason_class"] == "contract"
           end)

    generators = live_shard("automation_generators")

    receipts =
      for e <- generators["entries"],
          e["path"] == "scripts/ci/verify_nightly_run.sh" and e["class"] == "planning-path",
          do: e["reason_class"]

    assert receipts != []
    assert Enum.all?(receipts, &(&1 == "immutable-receipt"))
  end

  # --------------------------------------------------------------- Task 3

  @all_classes ~w(decision-id requirement-id phase-ref spec-ref planning-path milestone-ref
                  plan-ref path-name mojibake duplicated-prose narration artifact-comment)

  test "every one of the twelve classes is detected in one combined planted fixture" do
    root =
      fixture(%{
        "lib/decision.ex" => "# tuned (" <> d("D", "-98-03") <> ")\n",
        "lib/requirement.ex" => "# per " <> "CRAFT" <> "-04\n",
        "lib/phase.ex" => "# see " <> "Phase" <> " 12\n",
        "lib/spec.ex" => "# layout " <> "UI" <> "-SPEC section\n",
        "lib/planning.ex" => "# reads " <> "." <> "planning" <> "/PROJECT.md\n",
        "lib/milestone.ex" => "# since " <> "v1" <> ".7 only\n",
        "lib/plan.ex" => "# from " <> "Plan" <> " 05-04\n",
        ("scripts/phase_" <> "132_thing.json") => "{}\n",
        "lib/moji.ex" => "# caf" <> <<0xC3::utf8, 0xA9::utf8>> <> "\n",
        "lib/dup.ex" =>
          "# the clone without a running store again\n# clone without a running store is stated twice\n",
        "lib/narr.ex" => "# for now we skip the check\n",
        "lib/art.ex" => "# " <> "FIX" <> "ME later\n"
      })

    dir = shards(root, %{})
    {output, status} = run_fixture(root, dir, ["--check"])

    assert status == 1

    for class <- @all_classes do
      assert output =~ ": #{class}: ", "class #{class} was not detected:\n#{output}"
    end
  end

  test "repeated clause across two adjacent comment lines is duplicated-prose" do
    root =
      fixture(%{
        "lib/dup.ex" =>
          "# the clone without a running store again\n# clone without a running store is stated twice\n"
      })

    {output, status} = run_fixture(root, shards(root, %{}), ["--check"])

    assert status == 1
    assert output =~ "lib/dup.ex:2: duplicated-prose:"
  end

  test "repeated identifiers, backticks and code lines do not flag duplicated-prose" do
    root =
      fixture(%{
        "lib/code.ex" =>
          "# `alpha_beta_gamma_delta` is used here\n# `alpha_beta_gamma_delta` is used there\n" <>
            "defp alpha_beta_gamma_delta(a), do: alpha_beta_gamma_delta(a)\n" <>
            "defp alpha_beta_gamma_delta(b), do: alpha_beta_gamma_delta(b)\n"
      })

    assert {_, 0} = run_fixture(root, shards(root, %{}), ["--check"])
  end

  test "narration flags comments but not the same words in a string literal" do
    flagged = fixture(%{"lib/n.ex" => "# for now we skip it\n"})
    {output, status} = run_fixture(flagged, shards(flagged, %{}), ["--check"])
    assert status == 1
    assert output =~ "lib/n.ex:1: narration:"

    string = fixture(%{"lib/n.ex" => "message = \"for now we skip it, previously done\"\n"})
    assert {_, 0} = run_fixture(string, shards(string, %{}), ["--check"])
  end

  test "narration inside a multi-line block comment is detected" do
    root =
      fixture(%{
        "lib/b.ex" =>
          "<%!-- first line of the note\n     previously this was inline\n     closing --%>\n"
      })

    {output, status} = run_fixture(root, shards(root, %{}), ["--check"])
    assert status == 1
    assert output =~ "lib/b.ex:2: narration:"
  end

  test "artifact-comment flags a bare marker word but not a mktemp template" do
    flagged = fixture(%{"scripts/a.sh" => "# " <> "FIX" <> "ME: tidy this\n"})
    {output, status} = run_fixture(flagged, shards(flagged, %{}), ["--check"])
    assert status == 1
    assert output =~ "scripts/a.sh:1: artifact-comment:"

    template = fixture(%{"scripts/a.sh" => "# mktemp template X" <> "XXXXX is fine\n"})
    assert {_, 0} = run_fixture(template, shards(template, %{}), ["--check"])
  end

  test "the removed mix.exs duplicate stays gone and the regression literal is seeded as expected" do
    lib = live_shard("lib")

    refute Enum.any?(
             lib["entries"],
             &(&1["path"] == "mix.exs" and &1["class"] == "duplicated-prose")
           )

    for e <- live_shard("install_smoke")["entries"],
        e["path"] == "test/install_smoke/docs_parity/onboarding_and_capabilities_test.exs",
        e["class"] == "mojibake" do
      assert e["reason_class"] == "fixture"
    end
  end

  test "--regen-baseline is byte-idempotent and reproduces the committed shards" do
    live_dir = Path.join(@repo_root, "scripts/maintainer/live_residue_allowlist")

    dir =
      Path.join(System.tmp_dir!(), "rindle_residue_regen_#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)

    for file <- Path.wildcard(Path.join(live_dir, "*.json")),
        do: File.cp!(file, Path.join(dir, Path.basename(file)))

    assert {_, 0} = run_script(["--regen-baseline", "--allowlist-dir", dir])
    first = read_dir(dir)
    assert {_, 0} = run_script(["--regen-baseline", "--allowlist-dir", dir])

    assert read_dir(dir) == first
    assert first == read_dir(live_dir)
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

  defp read_dir(dir) do
    dir
    |> Path.join("*.json")
    |> Path.wildcard()
    |> Enum.sort()
    |> Map.new(&{Path.basename(&1), File.read!(&1)})
  end

  defp live_shard(area) do
    Path.join(@repo_root, "scripts/maintainer/live_residue_allowlist/#{area}.json")
    |> File.read!()
    |> Jason.decode!()
  end

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
