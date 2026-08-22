defmodule Rindle.InstallSmoke.QualitySignalPolicyTest do
  use ExUnit.Case, async: true

  @ci_path Path.expand("../../.github/workflows/ci.yml", __DIR__)
  @mix_path Path.expand("../../mix.exs", __DIR__)
  @canonical_lint_condition "${{ matrix.lint }}"

  setup_all do
    {:ok, %{workflow: YamlElixir.read_from_file!(@ci_path), mix: File.read!(@mix_path)}}
  end

  test "deterministic quality signals block through the existing Quality carrier", %{workflow: workflow} do
    assert_required_step!(
      workflow,
      "quality",
      "Credo quality",
      "bash scripts/maintainer/credo_quality.sh",
      @canonical_lint_condition
    )

    assert_required_step!(
      workflow,
      "quality",
      "Doctor (full, raise)",
      "MIX_ENV=dev mix doctor --full --raise",
      @canonical_lint_condition
    )

    assert_required_step!(
      workflow,
      "quality",
      "Run focused AV behavior tests",
      "mix test test/rindle/probe/av_probe_test.exs test/rindle/processor/image_test.exs --seed 0"
    )
  end

  test "focused AV proof follows its FFmpeg and libvips prerequisites", %{workflow: workflow} do
    names = workflow |> steps("quality") |> Enum.map(&Map.get(&1, "name"))

    assert index_of(names, "Install libvips") < index_of(names, "Run focused AV behavior tests")
    assert index_of(names, "Install FFmpeg") < index_of(names, "Run focused AV behavior tests")
  end

  test "runtime doctor and full-tree Credo style remain visible advisory checks", %{workflow: workflow} do
    assert step(workflow, "quality", "Verify AV runtime with public doctor task")["continue-on-error"]
    assert step(workflow, "quality", "Credo (strict, advisory style)")["continue-on-error"]
  end

  test "Contract carries deterministic contract tests and SAFE-01 without masking", %{workflow: workflow} do
    assert_required_step!(
      workflow,
      "contract",
      "Run contract tests",
      "mix test --only contract --seed 0"
    )

    assert_required_step!(
      workflow,
      "contract",
      "Run SAFE-01 preservation contract",
      "bash scripts/maintainer/refactor_contract.sh"
    )
  end

  test "the required CI and release topology remains unchanged", %{workflow: workflow} do
    summary = job(workflow, "ci-summary")

    assert workflow["name"] == "CI"
    assert summary["name"] == "CI Summary"
    assert "quality" in summary["needs"]
    assert "contract" in summary["needs"]
    assert step(workflow, "ci-summary", "Evaluate gating job results")["run"] ==
             "bash scripts/ci/eval_ci_summary.sh"
    refute "package-consumer-full" in summary["needs"]
  end

  test "required steps reject a false condition on the canonical matrix cell" do
    refute enabled_for_canonical_quality_cell?(%{"if" => "${{ false }}"})
  end

  test "local aliases run deterministic quality checks before one default suite", %{mix: mix} do
    assert mix =~ "refactor_contract: [\"cmd bash scripts/maintainer/refactor_contract.sh\"]"
    assert mix =~ "credo_quality: [\"cmd bash scripts/maintainer/credo_quality.sh\"]"
    assert mix =~ "quality_signals: ["
    assert mix =~ "\"cmd env MIX_ENV=dev mix doctor --full --raise\""

    ci = alias_block(mix, "ci")
    assert ci =~ "\"quality_signals\""
    assert index_of(String.split(ci, "\n"), "        \"quality_signals\",") <
             index_of(String.split(ci, "\n"), "        \"test\"")
    assert length(Regex.scan(~r/\"test\"/, ci)) == 1
  end

  defp assert_required_step!(workflow, job_name, step_name, run, condition \\ nil) do
    required_step = step(workflow, job_name, step_name)

    assert required_step["run"] == run
    assert required_step["if"] == condition
    refute required_step["continue-on-error"]

    if job_name == "quality" do
      assert enabled_for_canonical_quality_cell?(required_step)
    end
  end

  defp enabled_for_canonical_quality_cell?(step),
    do: Map.get(step, "if") in [nil, @canonical_lint_condition]

  defp job(workflow, name), do: workflow |> Map.fetch!("jobs") |> Map.fetch!(name)
  defp steps(workflow, job_name), do: job(workflow, job_name) |> Map.fetch!("steps")

  defp step(workflow, job_name, name) do
    Enum.find(steps(workflow, job_name), &(Map.get(&1, "name") == name)) ||
      flunk("missing #{job_name} step: #{name}")
  end

  defp index_of(items, item), do: Enum.find_index(items, &(&1 == item))

  defp alias_block(mix, name) do
    [_, after_name] = String.split(mix, "      #{name}: [", parts: 2)
    [block | _] = String.split(after_name, ~r/\n      [a-z_]+:/, parts: 2)
    block
  end
end
