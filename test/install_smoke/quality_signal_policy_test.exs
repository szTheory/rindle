defmodule Rindle.InstallSmoke.QualitySignalPolicyTest do
  use ExUnit.Case, async: true

  @ci_path Path.expand("../../.github/workflows/ci.yml", __DIR__)
  @mix_path Path.expand("../../mix.exs", __DIR__)

  setup_all do
    {:ok, %{ci: File.read!(@ci_path), mix: File.read!(@mix_path)}}
  end

  test "deterministic quality signals block through the existing Quality carrier", %{ci: ci} do
    quality = job_block(ci, "quality")

    assert quality =~ "bash scripts/maintainer/credo_quality.sh"
    assert quality =~ "MIX_ENV=dev mix doctor --full --raise"

    assert quality =~
             "mix test test/rindle/probe/av_probe_test.exs test/rindle/processor/image_test.exs --seed 0"

    refute yaml_keys(blocking_step(quality, "Credo quality")) =~ "continue-on-error"
    refute yaml_keys(blocking_step(quality, "Doctor")) =~ "continue-on-error"

    refute yaml_keys(blocking_step(quality, "Run focused AV behavior tests")) =~
             "continue-on-error"
  end

  test "focused AV proof follows its FFmpeg and libvips prerequisites", %{ci: ci} do
    quality = job_block(ci, "quality")

    assert index_of(quality, "Install libvips") <
             index_of(quality, "Run focused AV behavior tests")

    assert index_of(quality, "Install FFmpeg") <
             index_of(quality, "Run focused AV behavior tests")
  end

  test "runtime doctor and full-tree Credo style remain visible advisory checks", %{ci: ci} do
    quality = job_block(ci, "quality")

    assert blocking_step(quality, "Verify AV runtime with public doctor task") =~
             "continue-on-error: true"

    assert blocking_step(quality, "Credo (strict, advisory style)") =~ "continue-on-error: true"
  end

  test "Contract carries deterministic contract tests and SAFE-01 without masking", %{ci: ci} do
    contract = job_block(ci, "contract")

    assert blocking_step(contract, "Run contract tests") =~ "mix test --only contract --seed 0"

    assert blocking_step(contract, "Run SAFE-01 preservation contract") =~
             "bash scripts/maintainer/refactor_contract.sh"

    refute yaml_keys(blocking_step(contract, "Run contract tests")) =~ "continue-on-error"

    refute yaml_keys(blocking_step(contract, "Run SAFE-01 preservation contract")) =~
             "continue-on-error"
  end

  test "the required CI and release topology remains unchanged", %{ci: ci} do
    [first_line | _] = String.split(ci, "\n", parts: 2)
    summary = job_block(ci, "ci-summary")

    assert first_line == "name: CI"
    assert summary =~ "name: CI Summary"
    assert summary =~ "- quality\n"
    assert summary =~ "- contract\n"
    assert summary =~ "bash scripts/ci/eval_ci_summary.sh"
    refute ci_summary_needs(summary) =~ "package-consumer-full"
  end

  test "local aliases run deterministic quality checks before one default suite", %{mix: mix} do
    assert mix =~ "refactor_contract: [\"cmd bash scripts/maintainer/refactor_contract.sh\"]"
    assert mix =~ "credo_quality: [\"cmd bash scripts/maintainer/credo_quality.sh\"]"
    assert mix =~ "quality_signals: ["
    assert mix =~ "\"cmd env MIX_ENV=dev mix doctor --full --raise\""

    ci = alias_block(mix, "ci")
    assert ci =~ "\"quality_signals\""
    assert index_of(ci, "\"quality_signals\"") < index_of(ci, "\"test\"")
    assert length(Regex.scan(~r/\"test\"/, ci)) == 1
  end

  defp job_block(ci, job) do
    [_, after_job] = String.split(ci, "\n  #{job}:\n", parts: 2)
    [block | _] = String.split(after_job, ~r/\n  [a-z][a-z0-9-]*:\n/, parts: 2)
    block
  end

  defp blocking_step(job, name) do
    [_, after_name] = String.split(job, "- name: #{name}", parts: 2)
    [step | _] = String.split(after_name, "\n      - name:", parts: 2)
    step
  end

  defp index_of(text, needle), do: :binary.match(text, needle) |> elem(0)

  defp ci_summary_needs(summary) do
    [_, after_needs] = String.split(summary, "    needs:\n", parts: 2)
    [needs | _] = String.split(after_needs, "    if: always()", parts: 2)
    needs
  end

  defp yaml_keys(step) do
    step
    |> String.split("\n")
    |> Enum.reject(&(String.trim_leading(&1) |> String.starts_with?("#")))
    |> Enum.join("\n")
  end

  defp alias_block(mix, name) do
    [_, after_name] = String.split(mix, "      #{name}: [", parts: 2)
    [block | _] = String.split(after_name, ~r/\n      [a-z_]+:/, parts: 2)
    block
  end
end
