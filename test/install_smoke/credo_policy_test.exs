defmodule Rindle.CredoPolicyTest do
  use ExUnit.Case, async: false

  @repo_root Path.expand("../..", __DIR__)
  @config_path Path.join(@repo_root, ".credo.exs")
  @aggregate_path Path.join(@repo_root, "scripts/maintainer/credo_quality.sh")
  @normalizer_path Path.join(@repo_root, "scripts/maintainer/credo_quality_normalize.exs")
  @baseline_path Path.join(@repo_root, "scripts/maintainer/credo_complexity_baseline.json")

  test "profiles keep warnings global, public contracts explicit, and style advisory" do
    {config, _bindings} = Code.eval_file(@config_path)
    configs = Map.new(config.configs, &{&1.name, &1})

    warnings = Map.fetch!(configs, "blocking_warnings")
    assert warnings.files.included == ["lib/", "test/"]
    refute Map.has_key?(warnings.files, :excluded)
    assert Enum.all?(warnings.checks.enabled, &warning_check?/1)

    public_contract = Map.fetch!(configs, "public_contract")
    assert Enum.all?(public_contract.files.included, &String.ends_with?(&1, ".ex"))
    assert Enum.sort(public_contract.files.included) == public_exdoc_source_files()
    refute Map.has_key?(public_contract.files, :excluded)

    assert check_modules(public_contract) == [
             Credo.Check.Readability.ModuleDoc,
             Credo.Check.Readability.Specs
           ]

    complexity = Map.fetch!(configs, "complexity_inventory")
    assert complexity.files.included == ["lib/", "test/"]
    refute Map.has_key?(complexity.files, :excluded)

    assert check_modules(complexity) == [
             Credo.Check.Refactor.CyclomaticComplexity,
             Credo.Check.Refactor.Nesting
           ]

    default = Map.fetch!(configs, "default")

    assert {Credo.Check.Design.AliasUsage, options} =
             Enum.find(default.checks.enabled, &(elem(&1, 0) == Credo.Check.Design.AliasUsage))

    assert options[:priority] == :low
    refute Credo.Check.Design.AliasUsage in check_modules(warnings)
  end

  test "manifest is a complete counted identity inventory without location or prose gates" do
    entries = baseline_entries()

    assert entries != []

    assert Enum.all?(entries, fn entry ->
             Map.keys(entry) |> Enum.sort() == [
               "check",
               "count",
               "file",
               "observed_metric",
               "owner",
               "removal_trigger",
               "trigger"
             ]
           end)

    assert Enum.all?(entries, fn entry ->
             Enum.all?(
               ["check", "file", "trigger", "owner", "removal_trigger"],
               &(entry[&1] != "")
             ) and
               is_integer(entry["observed_metric"]) and entry["count"] > 0
           end)

    identities = Enum.map(entries, &Map.take(&1, ["check", "file", "trigger", "observed_metric"]))
    assert length(identities) == length(Enum.uniq(identities))
  end

  test "aggregate passes the reviewed tree and fails before later profiles on a warning anywhere in test" do
    assert {_, 0} = run_aggregate()

    fixture = Path.join(@repo_root, "test/install_smoke/credo_policy_warning_fixture.exs")

    File.write!(
      fixture,
      "defmodule Rindle.CredoPolicyWarningFixture do\n  IO.inspect(:fixture_warning)\nend\n"
    )

    on_exit(fn -> File.rm(fixture) end)

    {output, status} = run_aggregate()
    assert status != 0
    assert output =~ "IO.inspect"
    refute output =~ "public_contract"
  end

  test "aggregate rejects added, deleted, changed, and count-drift baseline identities" do
    entries = baseline_entries()
    extra = hd(entries) |> Map.put("file", "lib/rindle/new_debt.ex")

    assert_fails_with_baseline(entries ++ [extra])
    assert_fails_with_baseline(tl(entries))

    assert_fails_with_baseline(
      List.update_at(entries, 0, &Map.put(&1, "trigger", "renamed_trigger"))
    )

    assert_fails_with_baseline(List.update_at(entries, 0, &Map.put(&1, "count", 2)))
  end

  test "aggregate comparison is explicitly independent of lines and non-metric wording" do
    script = File.read!(@aggregate_path)
    normalizer = File.read!(@normalizer_path)
    baseline = File.read!(@baseline_path)

    refute baseline =~ "line_no"
    refute baseline =~ "column"
    refute baseline =~ "message"
    refute script =~ "line_no"
    refute script =~ "column"
    refute script =~ "jq"
    assert normalizer =~ "cyclomatic complexity is"
    assert normalizer =~ "was (?<metric>"
  end

  test "normalizers never compile while JSON is redirected" do
    script = File.read!(@aggregate_path)

    assert script =~
             "mix run --no-compile --no-start scripts/maintainer/credo_quality_normalize.exs issues"

    assert script =~
             "mix run --no-compile --no-start scripts/maintainer/credo_quality_normalize.exs baseline"

    refute script =~ "mix run --no-start scripts/maintainer/credo_quality_normalize.exs"
  end

  test "aggregate accepts a singleton reviewed identity without a frozen inventory size" do
    entry = hd(baseline_entries())
    {output, status} = fixture_aggregate([entry], [entry])
    assert status == 0, output
  end

  test "retained entries reject opaque removal triggers" do
    entry = hd(baseline_entries()) |> Map.put("removal_trigger", "someday")
    {_, status} = fixture_aggregate([entry], [entry])
    assert status != 0
  end

  test "metric ceilings preserve duplicate identities and ignore ordering" do
    entry = hd(baseline_entries())
    larger = Map.put(entry, "observed_metric", entry["observed_metric"] + 2)
    assert {_, 0} = fixture_aggregate([entry, larger], [larger, entry])

    for live <- [
          [Map.put(larger, "observed_metric", larger["observed_metric"] + 1), entry],
          [Map.put(entry, "count", 3)],
          [Map.put(entry, "trigger", "unknown")]
        ] do
      assert {_, status} = fixture_aggregate([entry, larger], live)
      assert status != 0
    end
  end

  test "empty inventories and reductions have explicit evidence requirements" do
    entry = hd(baseline_entries())
    assert {_, 0} = fixture_aggregate([], [])

    for live <- [[], [Map.put(entry, "observed_metric", entry["observed_metric"] - 1)]] do
      assert {_, status} = fixture_aggregate([entry], live)
      assert status != 0
    end

    assert {_, status} = fixture_aggregate([], [entry])
    assert status != 0
  end

  test "reductions run a current subject behavior test and reject stale failing or recursive proof" do
    entry = hd(baseline_entries())
    target = "test/install_smoke/behavior_preservation_fixture_test.exs"

    File.write!(
      target,
      "defmodule BehaviorPreservationFixtureTest do\n use ExUnit.Case\n test \"preserves owner behavior\", do: assert true\nend\n"
    )

    on_exit(fn -> File.rm(target) end)
    {sha, 0} = System.cmd("git", ["rev-parse", "HEAD"])

    record =
      Map.take(entry, ~w(check file trigger))
      |> Map.merge(%{
        "before" => [entry["observed_metric"]],
        "after" => [],
        "source_sha" => String.trim(sha),
        "behavior_test" => target
      })

    assert {output, status} = fixture_aggregate([entry], [], [record])
    assert status == 0, output

    for invalid <- [
          Map.put(record, "source_sha", String.duplicate("0", 40)),
          Map.put(record, "after", [1]),
          Map.put(record, "behavior_test", "test/install_smoke/credo_policy_test.exs")
        ] do
      assert {_, status} = fixture_aggregate([entry], [], [invalid])
      assert status != 0
    end

    File.write!(
      target,
      "defmodule BehaviorPreservationFixtureTest do\n use ExUnit.Case\n test \"preserves owner behavior\", do: assert false\nend\n"
    )

    assert {_, status} = fixture_aggregate([entry], [], [record])
    assert status != 0

    for tag <- [:skip, :integration] do
      File.write!(
        target,
        "defmodule BehaviorPreservationFixtureTest do\n use ExUnit.Case\n @tag :#{tag}\n test \"preserves owner behavior\", do: assert true\nend\n"
      )

      assert {_, status} = fixture_aggregate([entry], [], [record])
      assert status != 0, "unexecuted behavior tests cannot prove a reduction"
    end
  end

  defp fixture_aggregate(baseline, live, evidence \\ []) do
    dir = Path.join(System.tmp_dir!(), "credo-policy-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    File.write!(Path.join(dir, "baseline.json"), Jason.encode!(%{"entries" => baseline}))
    File.write!(Path.join(dir, "evidence.json"), Jason.encode!(%{"entries" => evidence}))

    issues =
      Enum.flat_map(live, fn entry ->
        message =
          if String.ends_with?(entry["check"], "Nesting"),
            do: "Nesting was #{entry["observed_metric"]}",
            else: "cyclomatic complexity is #{entry["observed_metric"]}"

        List.duplicate(
          %{
            "check" => entry["check"],
            "filename" => entry["file"],
            "trigger" => entry["trigger"],
            "message" => message
          },
          entry["count"]
        )
      end)

    File.write!(Path.join(dir, "issues.json"), Jason.encode!(%{"issues" => issues}))
    real_mix = System.find_executable("mix")

    File.write!(Path.join(dir, "mix"), """
    #!/usr/bin/env bash
    if [[ "$1" == credo ]]; then
      if [[ "$*" == *complexity_inventory* ]]; then
        cat "#{dir}/issues.json"
      fi
      exit 0
    fi
    exec "#{real_mix}" "$@"
    """)

    File.chmod!(Path.join(dir, "mix"), 0o755)

    run_aggregate(%{
      "PATH" => dir <> ":" <> System.get_env("PATH"),
      "CREDO_QUALITY_BASELINE" => Path.join(dir, "baseline.json"),
      "CREDO_QUALITY_EVIDENCE" => Path.join(dir, "evidence.json")
    })
  end

  defp warning_check?({module, _options}),
    do: module |> Atom.to_string() |> String.starts_with?("Elixir.Credo.Check.Warning.")

  defp check_modules(config), do: Enum.map(config.checks.enabled, &elem(&1, 0))

  defp public_exdoc_source_files do
    Mix.Project.config()
    |> Keyword.fetch!(:docs)
    |> Keyword.fetch!(:groups_for_modules)
    |> Keyword.values()
    |> List.flatten()
    |> Enum.map(&source_file!/1)
    |> Enum.sort()
  end

  defp source_file!(module) do
    assert Code.ensure_loaded?(module), "expected #{inspect(module)} to be compiled"

    module
    |> apply(:module_info, [:compile])
    |> Keyword.fetch!(:source)
    |> List.to_string()
    |> Path.relative_to(@repo_root)
  end

  defp baseline_entries do
    @baseline_path
    |> File.read!()
    |> Jason.decode!()
    |> Map.fetch!("entries")
  end

  defp assert_fails_with_baseline(entries) do
    path =
      Path.join(
        System.tmp_dir!(),
        "rindle-credo-baseline-#{System.unique_integer([:positive])}.json"
      )

    File.write!(path, Jason.encode!(%{"entries" => entries}))
    on_exit(fn -> File.rm(path) end)

    {output, status} = run_aggregate(%{"CREDO_QUALITY_BASELINE" => path})
    assert status != 0
    assert output =~ "baseline" or output =~ "identity multiset differs"
  end

  defp run_aggregate(env \\ %{}) do
    System.cmd("bash", [@aggregate_path],
      cd: @repo_root,
      env: Map.to_list(env),
      stderr_to_stdout: true
    )
  end
end
