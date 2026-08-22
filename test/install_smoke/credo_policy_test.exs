defmodule Rindle.CredoPolicyTest do
  use ExUnit.Case, async: false

  @repo_root Path.expand("../..", __DIR__)
  @config_path Path.join(@repo_root, ".credo.exs")
  @aggregate_path Path.join(@repo_root, "scripts/maintainer/credo_quality.sh")
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

    assert length(entries) == 33
    assert Enum.sum(Enum.map(entries, & &1["count"])) == 37

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
    assert Enum.count(entries, &(&1["count"] == 2)) == 4
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
    baseline = File.read!(@baseline_path)

    refute baseline =~ "line_no"
    refute baseline =~ "column"
    refute baseline =~ "message"
    refute script =~ "line_no"
    refute script =~ "column"
    assert script =~ "capture(\"cyclomatic complexity is"
    assert script =~ "capture(\"was (?<metric>"
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
    |> Enum.map(fn module ->
      module
      |> Module.split()
      |> Enum.map_join("/", &Macro.underscore/1)
      |> then(&"lib/#{&1}.ex")
    end)
    |> Enum.sort()
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
