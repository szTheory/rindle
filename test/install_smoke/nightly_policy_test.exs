defmodule Rindle.InstallSmoke.NightlyPolicyTest do
  use ExUnit.Case, async: true

  @nightly_path Path.expand("../../.github/workflows/nightly.yml", __DIR__)
  @ci_path Path.expand("../../.github/workflows/ci.yml", __DIR__)
  @gating_jobs ["compat-matrix", "dialyzer", "gcs-soak", "package-consumer-gcs-live"]
  @required_ci_needs [
    "quality",
    "optional-dependencies",
    "integration",
    "contract",
    "proof",
    "package-consumer",
    "adoption-demo-unit",
    "adoption-demo-e2e-smoke",
    "adopter",
    "brandbook-tokens",
    "ci-script-tests"
  ]

  setup_all do
    {:ok,
     %{
       nightly: YamlElixir.read_from_file!(@nightly_path),
       ci: YamlElixir.read_from_file!(@ci_path)
     }}
  end

  test "Nightly summary owns the exact declared gate with always semantics", %{nightly: workflow} do
    summary = job(workflow, "nightly-summary")

    assert Enum.sort(summary["needs"]) == Enum.sort(@gating_jobs)
    assert summary["if"] == "always()"

    assert summary["outputs"] == %{
             "verdict" => "${{ steps.evaluate.outputs.verdict }}",
             "verdict-json" => "${{ steps.evaluate.outputs.verdict-json }}"
           }

    assert step(summary, "Checkout")["uses"] =~ "actions/checkout@"

    evaluator = step(summary, "Evaluate strict Nightly verdict")
    assert evaluator["id"] == "evaluate"
    assert evaluator["env"]["NEEDS_JSON"] == "${{ toJSON(needs) }}"
    assert evaluator["env"]["NIGHTLY_POLICY_JSON"] =~ "applicability_rule"
    assert evaluator["run"] =~ "bash scripts/ci/eval_nightly_summary.sh"
    assert evaluator["run"] =~ ~s(echo "verdict-json=${verdict_json}")
    assert evaluator["run"] =~ ~s(} >> "$GITHUB_OUTPUT")
    refute evaluator["continue-on-error"]

    enforcement = step(summary, "Enforce strict Nightly verdict")
    assert enforcement["run"] =~ ~s(test "${{ steps.evaluate.outputs.verdict }}" = "green")
    refute enforcement["continue-on-error"]
  end

  test "every gating job exports typed applicability and execution evidence", %{
    nightly: workflow
  } do
    for job_name <- @gating_jobs do
      gating_job = job(workflow, job_name)

      assert gating_job["outputs"] == %{
               "applicable" => "${{ steps.nightly-evidence.outputs.applicable }}",
               "applicability-rule" => "${{ steps.nightly-evidence.outputs.applicability-rule }}",
               "execution" => "${{ steps.nightly-evidence.outputs.execution }}",
               "inapplicability-reason" =>
                 "${{ steps.nightly-evidence.outputs.inapplicability-reason }}"
             }

      evidence = step(gating_job, "Publish Nightly evidence")
      assert evidence["id"] == "nightly-evidence"
      refute evidence["continue-on-error"]
    end
  end

  test "live GCS applicability is machine checked and skipped work is called not-run", %{
    nightly: workflow
  } do
    for job_name <- ["gcs-soak", "package-consumer-gcs-live"] do
      gating_job = job(workflow, job_name)
      refute Map.has_key?(gating_job, "if")

      config = step(gating_job, "Determine live GCS applicability")
      assert config["id"] == "gcs-live-config"
      assert config["env"]["UPSTREAM_REPOSITORY"] == "${{ github.repository }}"
      assert config["run"] =~ "not-upstream-repository"
      assert config["run"] =~ "required-secrets-unavailable"

      evidence = step(gating_job, "Publish Nightly evidence")
      assert evidence["if"] == "success()"
      assert evidence["run"] =~ "execution=not-run"
      assert evidence["run"] =~ "execution=passed"
    end
  end

  test "existing CI script carrier runs the Nightly matrix through the sole required join", %{
    ci: workflow
  } do
    script_tests = job(workflow, "ci-script-tests")
    summary = job(workflow, "ci-summary")

    assert step(script_tests, "Nightly Summary gate logic")["run"] ==
             "bash scripts/ci/test_nightly_summary_gate.sh"

    assert workflow["name"] == "CI"
    assert summary["name"] == "CI Summary"
    assert summary["needs"] == @required_ci_needs
    assert summary["if"] == "always()"

    assert workflow["jobs"]
           |> Enum.count(fn {_id, candidate} -> candidate["name"] == "CI Summary" end) == 1
  end

  defp job(workflow, name), do: workflow |> Map.fetch!("jobs") |> Map.fetch!(name)

  defp step(job, name) do
    Enum.find(job["steps"], &(Map.get(&1, "name") == name)) || flunk("missing step: #{name}")
  end
end
