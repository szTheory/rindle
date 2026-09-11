defmodule Rindle.InstallSmoke.NightlyPolicyTest do
  use ExUnit.Case, async: true

  @nightly_path Path.expand("../../.github/workflows/nightly.yml", __DIR__)
  @ci_path Path.expand("../../.github/workflows/ci.yml", __DIR__)
  @retired_incident_evaluator_path Path.expand(
                                      "../../scripts/ci/eval_nightly_incident.sh",
                                      __DIR__
                                    )
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

  test "incident lifecycle consumes the strict verdict after every gating result", %{
    nightly: workflow
  } do
    producer = job(workflow, "nightly-incident-verdict")
    lifecycle = job(workflow, "nightly-failure-issue")

    assert producer["needs"] == "nightly-summary"
    assert producer["if"] == "${{ always() && github.event_name == 'schedule' }}"
    assert producer["permissions"] == %{"contents" => "read"}
    refute Map.has_key?(producer, "concurrency")

    write = step(producer, "Write immutable Nightly verdict event")

    assert write["env"]["STRICT_VERDICT_JSON"] ==
             "${{ needs.nightly-summary.outputs.verdict-json }}"

    assert write["run"] =~ "rindle-nightly-incident-verdict-v1"
    assert write["run"] =~ "--argjson run_id"
    assert write["run"] =~ "--argjson run_attempt"
    assert write["run"] =~ "--argjson verdict"
    assert write["run"] =~ "jq -e"

    upload = step(producer, "Upload immutable Nightly verdict event")

    assert upload["uses"] ==
             "actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a"

    assert upload["with"]["name"] ==
             "nightly-incident-verdict-${{ github.run_id }}-${{ github.run_attempt }}"

    assert upload["with"]["overwrite"] == false
    assert upload["with"]["if-no-files-found"] == "error"

    assert lifecycle["needs"] == "nightly-incident-verdict"
    assert lifecycle["if"] == "${{ always() && github.event_name == 'schedule' }}"

    assert lifecycle["permissions"] == %{
             "actions" => "read",
             "contents" => "read",
             "issues" => "write"
           }

    assert lifecycle["concurrency"] == %{
             "group" => "nightly-incident-${{ github.repository }}-${{ github.workflow }}",
             "cancel-in-progress" => false
           }

    refute lifecycle["concurrency"]["group"] =~ "run_id"
    refute lifecycle["concurrency"]["group"] =~ "run_attempt"
    refute lifecycle["concurrency"]["group"] =~ "sha"

    remote_main = step(lifecycle, "Resolve current remote default-branch SHA")
    assert remote_main["id"] == "remote-main"
    assert remote_main["run"] =~ "gh api --method GET"
    assert remote_main["run"] =~ "git/ref/heads/${DEFAULT_BRANCH}"

    manage = step(lifecycle, "Manage scheduled Nightly incident")

    assert manage["env"]["REMOTE_MAIN_SHA"] == "${{ steps.remote-main.outputs.sha }}"
    assert manage["run"] == "bash scripts/ci/manage_nightly_incident.sh"

    refute lifecycle["if"] =~ "failure()"
  end

  test "incident mutation stays job-local and diagnostic dispatch remains evaluator-owned", %{
    nightly: workflow,
    ci: ci
  } do
    assert workflow["permissions"] == %{"contents" => "read"}

    writers =
      for {name, candidate} <- workflow["jobs"],
          get_in(candidate, ["permissions", "issues"]) == "write",
          do: name

    assert writers == ["nightly-failure-issue"]

    producer = job(workflow, "nightly-incident-verdict")
    refute get_in(producer, ["permissions", "issues"])
    refute get_in(producer, ["permissions", "actions"])

    lifecycle = job(workflow, "nightly-failure-issue")
    manage = step(lifecycle, "Manage scheduled Nightly incident")
    assert manage["env"]["WORKFLOW_NAME"] == "${{ github.workflow }}"
    assert manage["env"]["WORKFLOW_REF"] == "${{ github.workflow_ref }}"
    assert manage["env"]["CURRENT_RUN_ID"] == "${{ github.run_id }}"
    assert manage["env"]["CURRENT_RUN_ATTEMPT"] == "${{ github.run_attempt }}"

    refute Enum.any?(workflow["jobs"], fn {name, candidate} ->
             name != "nightly-incident-verdict" &&
               Enum.any?(candidate["steps"] || [], fn candidate_step ->
                 get_in(candidate_step, ["with", "name"])
                 |> to_string()
                 |> String.starts_with?("nightly-incident-verdict-")
               end)
           end)

    assert step(job(ci, "ci-script-tests"), "Nightly incident lifecycle")["run"] ==
             "bash scripts/ci/test_nightly_incident.sh"
  end

  test "Nightly has one executable incident-policy owner", %{nightly: workflow} do
    refute File.exists?(@retired_incident_evaluator_path),
           "retired incident evaluator must stay absent from the executable surface"

    policy_steps =
      for {job_name, candidate} <- workflow["jobs"],
          candidate_step <- candidate["steps"] || [],
          run = candidate_step["run"],
          is_binary(run),
          String.contains?(run, [
            "scripts/ci/manage_nightly_incident.sh",
            "scripts/ci/eval_nightly_incident.sh"
          ]),
          do: {job_name, candidate_step["name"], run}

    assert policy_steps == [
             {"nightly-failure-issue", "Manage scheduled Nightly incident",
              "bash scripts/ci/manage_nightly_incident.sh"}
           ]

    assert job(workflow, "nightly-incident-verdict")["permissions"] == %{"contents" => "read"}

    assert Enum.count(workflow["jobs"], fn {_name, candidate} ->
             get_in(candidate, ["permissions", "issues"]) == "write"
           end) == 1
  end

  defp job(workflow, name), do: workflow |> Map.fetch!("jobs") |> Map.fetch!(name)

  defp step(job, name) do
    Enum.find(job["steps"], &(Map.get(&1, "name") == name)) || flunk("missing step: #{name}")
  end
end
