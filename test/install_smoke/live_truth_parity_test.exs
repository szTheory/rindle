Code.require_file("support/generated_app_helper.ex", __DIR__)

defmodule Rindle.InstallSmoke.LiveTruthParityTest do
  use ExUnit.Case, async: false
  # Tests exercise Mix state and verifier-owned subprocesses.
  @async_safety_allow [:file_mutation]
  def __async_safety_allow__, do: @async_safety_allow

  @compile {:no_warn_undefined, Rindle.ValidateLiveTruth}

  @repo_root Path.expand("../..", __DIR__)
  @validator Path.join(@repo_root, "scripts/maintainer/validate_live_truth.exs")
  # Release-please bumps the version on every release PR; derive it rather than pin it.
  @current_version Mix.Project.config()[:version]
  @historical_start "<!-- rindle:historical-receipt:start -->"
  @historical_end "<!-- rindle:historical-receipt:end -->"
  @executable_elixir_requirement "~> 1.15"
  @required_needs [
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
    Code.require_file(@validator)
    :ok
  end

  @tag :derived_authority
  test "derives equal release authorities and exact CI/Nightly topology" do
    model = Rindle.ValidateLiveTruth.derive!(@repo_root, [])

    assert model.schema_version == 1
    assert model.version == @current_version

    assert model.version_authorities == %{
             mix_exs: @current_version,
             release_please_manifest: @current_version
           }

    assert model.ci.workflow_file == ".github/workflows/ci.yml"
    assert model.ci.workflow_name == "CI"
    assert model.ci.required_check == "CI Summary"
    assert model.ci.required_needs == @required_needs

    assert model.ci.off_critical_path == [
             "adoption-demo-e2e",
             "cohort-demo-smoke",
             "package-consumer-full"
           ]

    assert model.ci.fork_safe_pr_lanes == ["adoption-demo-e2e-smoke", "package-consumer"]
    assert model.ci.exact_sha_release_coupling
    assert model.ci.sole_required_check

    assert model.nightly.workflow_file == ".github/workflows/nightly.yml"
    assert model.nightly.workflow_name == "Nightly"
    assert model.nightly.triggers == ["schedule", "workflow_dispatch"]

    assert model.nightly.required_needs == [
             "compat-matrix",
             "dialyzer",
             "gcs-soak",
             "package-consumer-gcs-live"
           ]

    assert model.nightly.applicability["gcs-soak"] ==
             "upstream-repository-and-required-secrets"

    assert model.nightly.applicability["package-consumer-gcs-live"] ==
             "upstream-repository-and-required-secrets"
  end

  @tag :derived_authority
  test "release authority mismatch, absence, and malformed values fail closed" do
    root = fixture_root!()

    write!(root, ".release-please-manifest.json", ~s({".":"0.4.5"}))
    assert_error(root, "release authority mismatch")

    root = fixture_root!()
    File.rm!(Path.join(root, ".release-please-manifest.json"))
    assert_error(root, "missing release authority")

    root = fixture_root!()
    write!(root, ".release-please-manifest.json", ~s({".":false}))
    assert_error(root, "malformed release authority")
  end

  @tag :derived_authority
  test "workflow/check renames and changed aggregate membership fail with specific mismatches" do
    root = fixture_root!()
    replace!(root, ".github/workflows/ci.yml", "name: CI\n", "name: Other CI\n")
    assert_error(root, "ci workflow name mismatch")

    root = fixture_root!()

    replace!(
      root,
      ".github/workflows/ci.yml",
      "    name: CI Summary\n",
      "    name: Merge Gate\n"
    )

    assert_error(root, "required check identity mismatch")

    root = fixture_root!()

    replace!(
      root,
      ".github/workflows/ci.yml",
      "      - adoption-demo-e2e-smoke\n",
      "      - adoption-demo-e2e\n"
    )

    assert_error(root, "CI Summary needs mismatch")
  end

  @tag :derived_authority
  test "release coupling cannot be established by literals retained only in comments" do
    root = fixture_root!()

    replace!(
      root,
      ".github/workflows/release.yml",
      "                workflow_id: 'ci.yml',",
      "                workflow_id: 'nightly.yml',"
    )

    replace!(
      root,
      ".github/workflows/release.yml",
      "                head_sha: sha,",
      "                head_sha: '0000000000000000000000000000000000000000',"
    )

    replace!(
      root,
      ".github/workflows/release.yml",
      "              const runs = data.workflow_runs.filter((run) => run.head_sha === sha);",
      "              const runs = data.workflow_runs;"
    )

    replace!(
      root,
      ".github/workflows/release.yml",
      "              if (latest.conclusion !== 'success') {",
      "              if (latest.conclusion !== 'failure') {"
    )

    release_path = Path.join(root, ".github/workflows/release.yml")

    File.write!(
      release_path,
      File.read!(release_path) <>
        "\n# workflow_id: 'ci.yml'\n# head_sha: sha\n" <>
        "# run.head_sha === sha\n# latest.conclusion !== 'success'\n"
    )

    assert_error(root, "release CI run selection mismatch")
  end

  @tag :derived_authority
  test "release coupling rejects dead steps, duplicate gates, and broken graph edges" do
    root = fixture_root!()

    replace!(
      root,
      ".github/workflows/release.yml",
      "      - name: Wait for CI to finish green on release SHA\n        id: ci\n",
      "      - name: Wait for CI to finish green on release SHA\n        id: ci\n        if: ${{ false }}\n"
    )

    assert_error(root, "release step is unreachable: ci")

    root = fixture_root!()

    replace!(
      root,
      ".github/workflows/release.yml",
      "  publish:\n",
      "  duplicate-gate:\n    name: Gate on Exact-SHA Green CI\n    runs-on: ubuntu-22.04\n    steps: []\n\n  publish:\n",
      global: false
    )

    assert_error(root, "duplicate release job gate-ci-green")

    for {old, new, message} <- [
          {"    needs: [recovery-validation]\n", "    needs: []\n",
           "release gate needs mismatch"},
          {"      release_sha: ${{ steps.resolve.outputs.release_sha }}\n",
           "      release_sha: ${{ steps.resolve.outputs.checkout_ref }}\n",
           "release gate outputs mismatch"},
          {"                workflow_id: 'ci.yml',",
           "                workflow_id: 'nightly.yml',", "release CI run selection mismatch"},
          {"                head_sha: sha,", "                head_sha: ref,",
           "release CI run selection mismatch"},
          {"    if: ${{ github.event_name == 'workflow_dispatch' && needs.recovery-validation.result == 'success' }}\n",
           "    if: ${{ github.event_name == 'workflow_dispatch' }}\n",
           "release gate condition mismatch"}
        ] do
      root = fixture_root!()
      replace!(root, ".github/workflows/release.yml", old, new, global: false)
      assert_error(root, message)
    end
  end

  @tag :derived_authority
  test "release run evaluator accepts only completed success on the exact SHA" do
    sha = String.duplicate("a", 40)
    matching = %{"head_sha" => sha, "status" => "completed", "conclusion" => "success"}

    assert Rindle.ValidateLiveTruth.release_run_qualifies?(matching, sha)

    refute Rindle.ValidateLiveTruth.release_run_qualifies?(
             %{matching | "head_sha" => String.duplicate("b", 40)},
             sha
           )

    refute Rindle.ValidateLiveTruth.release_run_qualifies?(
             %{matching | "status" => "in_progress"},
             sha
           )

    refute Rindle.ValidateLiveTruth.release_run_qualifies?(
             %{matching | "conclusion" => "failure"},
             sha
           )
  end

  @tag :derived_authority
  test "required check authority comes from one exact structured policy" do
    policy_path = Path.join(@repo_root, "config/ci_required_checks.json")
    assert File.regular?(policy_path)

    model = Rindle.ValidateLiveTruth.derive!(@repo_root, [])

    assert model.ci.required_check_policy == %{
             schema_version: "rindle-required-checks-v1",
             workflow_file: "ci.yml",
             workflow_name: "CI",
             job_id: "ci-summary",
             contexts: ["CI Summary"]
           }

    {json, 0} =
      System.cmd("bash", ["scripts/setup_branch_protection.sh", "--print-expected-json"])

    assert Jason.decode!(json)["required_status_checks"]["contexts"] == ["CI Summary"]
  end

  @tag :derived_authority
  test "maintainer guidance and both consumers share the structured required-check authority" do
    model = Rindle.ValidateLiveTruth.derive!(@repo_root, [])
    running = File.read!(Path.join(@repo_root, "RUNNING.md"))
    setup = File.read!(Path.join(@repo_root, "scripts/setup_branch_protection.sh"))
    validator = File.read!(@validator)

    assert_running_required_check_authority!(running, model)
    assert_required_check_consumers!(setup, validator)

    for mutation <- [
          String.replace(
            running,
            "`config/ci_required_checks.json` is the sole structured authority",
            "`scripts/setup_branch_protection.sh` uses `REQUIRED_CHECKS=(\"CI Summary\")` as the authority",
            global: false
          ),
          String.replace(
            running,
            "config/ci_required_checks.json",
            "config/other_required_checks.json",
            global: false
          ),
          Regex.replace(
            ~r/sole required\s+context `CI Summary`/,
            running,
            "sole required context `Merge Gate`",
            global: false
          )
        ] do
      assert_raise ExUnit.AssertionError, fn ->
        assert_running_required_check_authority!(mutation, model)
      end
    end

    disconnected_setup =
      String.replace(
        setup,
        "POLICY_FILE=\"${SCRIPT_DIR}/../config/ci_required_checks.json\"",
        "POLICY_FILE=\"${SCRIPT_DIR}/../config/other_required_checks.json\"",
        global: false
      )

    assert_raise ExUnit.AssertionError, fn ->
      assert_required_check_consumers!(disconnected_setup, validator)
    end

    disconnected_validator =
      String.replace(
        validator,
        "@required_check_policy_file \"config/ci_required_checks.json\"",
        "@required_check_policy_file \"config/other_required_checks.json\"",
        global: false
      )

    assert_raise ExUnit.AssertionError, fn ->
      assert_required_check_consumers!(setup, disconnected_validator)
    end
  end

  @tag :derived_authority
  test "required check policy rejects missing, extra, duplicate, renamed, and topology drift" do
    valid = required_check_policy()

    for {mutation, message} <- [
          {&put_in(&1, ["contexts"], []), "required check policy contexts mismatch"},
          {&put_in(&1, ["contexts"], ["CI Summary", "Quality"]),
           "required check policy contexts mismatch"},
          {&put_in(&1, ["contexts"], ["CI Summary", "CI Summary"]),
           "required check policy contexts mismatch"},
          {&put_in(&1, ["contexts"], ["Merge Gate"]), "required check policy contexts mismatch"},
          {&put_in(&1, ["workflow", "name"], "Other CI"),
           "required check policy workflow mismatch"},
          {&put_in(&1, ["workflow", "file"], "other.yml"),
           "required check policy workflow mismatch"},
          {&put_in(&1, ["workflow", "job_id"], "other-summary"),
           "required check policy job mismatch"}
        ] do
      root = fixture_root!()
      write_policy!(root, mutation.(valid))
      assert_error(root, message)
    end
  end

  @tag :derived_authority
  test "commented and dead shell assignments cannot impersonate policy consumption" do
    root = fixture_root!()
    write_policy!(root, required_check_policy())

    replace!(
      root,
      "scripts/setup_branch_protection.sh",
      "  contexts_json=$(jq -c '.contexts' \"${POLICY_FILE}\")",
      "  contexts_json='[\"Merge Gate\"]'\n  # contexts_json=$(jq -c '.contexts' \"${POLICY_FILE}\")\n  if false; then contexts_json=$(jq -c '.contexts' \"${POLICY_FILE}\"); fi"
    )

    assert_error(root, "branch protection policy output mismatch")
  end

  @tag :derived_authority
  test "TRUTH-08: claims the derived model cannot classify fail instead of passing as prose" do
    model = Rindle.ValidateLiveTruth.derive!(@repo_root, [])

    for {claim, message} <- [
          {%{type: :benchmark, lane: "quality"}, ~r/unclassified claim type: :benchmark/},
          {%{"type" => "rumor"}, ~r/unclassified claim type: "rumor"/},
          {%{type: :lane, lane: "nonexistent-lane", severity: "merge-blocking"},
           ~r/unclassified CI lane: "nonexistent-lane"/},
          {%{type: :nightly, lane: "nonexistent-nightly", result: "passed", applicable: true},
           ~r/unclassified Nightly lane: "nonexistent-nightly"/}
        ] do
      assert_raise ArgumentError, message, fn ->
        Rindle.ValidateLiveTruth.validate_claims!(model, [claim])
      end
    end
  end

  @tag :derived_authority
  test "false lane and Nightly applicability claims are rejected from parsed topology" do
    model = Rindle.ValidateLiveTruth.derive!(@repo_root, [])

    assert_raise ArgumentError, ~r/lane severity mismatch.*adoption-demo-e2e/, fn ->
      Rindle.ValidateLiveTruth.validate_claims!(model, [
        %{type: :lane, lane: "adoption-demo-e2e", severity: "merge-blocking"}
      ])
    end

    assert_raise ArgumentError, ~r/nightly result mismatch.*gcs-soak/, fn ->
      Rindle.ValidateLiveTruth.validate_claims!(model, [
        %{type: :nightly, lane: "gcs-soak", result: "passed", applicable: false}
      ])
    end
  end

  @tag :derived_authority
  test "stale live versions fail while bounded history and milestone archives remain immutable" do
    model = Rindle.ValidateLiveTruth.derive!(@repo_root, [])

    assert_raise ArgumentError, ~r/unmarked stale version 0.4.5/, fn ->
      Rindle.ValidateLiveTruth.validate_claims!(model, [
        %{path: ".planning/STATE.md", content: "Current release is 0.4.5."}
      ])
    end

    assert :ok =
             Rindle.ValidateLiveTruth.validate_claims!(model, [
               %{
                 path: "guides/release_publish.md",
                 content:
                   Enum.join(
                     [@historical_start, "Release 0.4.5 was verified.", @historical_end],
                     "\n"
                   )
               },
               %{
                 path: ".planning/milestones/v1.25/receipt.md",
                 content: "Release 0.4.5 was verified."
               }
             ])

    for malformed <- [
          "#{@historical_start}\n0.4.5",
          "0.4.5\n#{@historical_end}",
          "#{@historical_start}\n#{@historical_start}\n0.4.5\n#{@historical_end}\n#{@historical_end}"
        ] do
      assert_raise ArgumentError, ~r/malformed historical boundary/, fn ->
        Rindle.ValidateLiveTruth.validate_claims!(model, [
          %{path: "RUNNING.md", content: malformed}
        ])
      end
    end
  end

  @tag :derived_authority
  test "active maintainer and adoption surfaces state the derived evidence classes" do
    for path <- [
          ".planning/INBOX-TRIAGE.md",
          ".planning/JTBD-MAP.md",
          "RUNNING.md",
          "examples/adoption_demo/docs/adoption-proof-matrix.md"
        ] do
      full_path = Path.join(@repo_root, path)

      assert :ok =
               Rindle.ValidateLiveTruth.validate_claims!(
                 Rindle.ValidateLiveTruth.derive!(@repo_root, []),
                 [%{path: path, content: File.read!(full_path)}]
               )
    end

    matrix =
      File.read!(Path.join(@repo_root, "examples/adoption_demo/docs/adoption-proof-matrix.md"))

    running = File.read!(Path.join(@repo_root, "RUNNING.md"))

    assert matrix =~ "Merge-blocking (`adoption-demo-e2e-smoke`)"
    assert matrix =~ "Off-critical-path (`adoption-demo-e2e`)"
    assert matrix =~ "maintainer-operated synthetic evidence"
    assert matrix =~ "does not satisfy the named independent adopter"

    assert running =~ "fresh and restored PLT modes"
    assert running =~ "strict Nightly verdict"
    assert running =~ "not-run rather than passed"

    adoption_gate =
      File.read!(Path.join(@repo_root, "scripts/maintainer/check_adoption_proof_matrix.sh"))

    assert adoption_gate =~ "live_truth_parity_test.exs"
    assert adoption_gate =~ "--only package_authority"
  end

  test "active surfaces stay valid across a release-please patch bump" do
    model = Rindle.ValidateLiveTruth.derive!(@repo_root, [])
    {:ok, current} = Version.parse(model.version)
    bumped = %{model | version: to_string(%{current | patch: current.patch + 1})}

    for path <- [
          ".planning/INBOX-TRIAGE.md",
          ".planning/JTBD-MAP.md",
          "RUNNING.md",
          "examples/adoption_demo/docs/adoption-proof-matrix.md"
        ] do
      assert :ok =
               Rindle.ValidateLiveTruth.validate_claims!(bumped, [
                 %{path: path, content: File.read!(Path.join(@repo_root, path))}
               ])
    end
  end

  @tag :derived_authority
  test "maintainer guidance binds Nightly gates and supported-cell proof to live authorities" do
    model = Rindle.ValidateLiveTruth.derive!(@repo_root, [])
    running = File.read!(Path.join(@repo_root, "RUNNING.md"))

    assert_running_nightly_authority!(running, model)

    stale_advisory =
      String.replace(
        running,
        "are all **Nightly-gating** inputs to the strict `Nightly Summary`",
        "are advisory and never required checks",
        global: false
      )

    assert_raise ExUnit.AssertionError, fn ->
      assert_running_nightly_authority!(stale_advisory, model)
    end

    stale_plan_authority =
      String.replace(
        running,
        "The current supported-cell acceptance authority is the exact-subject",
        "Plan 07 remains the live acceptance authority; the exact-subject",
        global: false
      )

    assert_raise ExUnit.AssertionError, fn ->
      assert_running_nightly_authority!(stale_plan_authority, model)
    end
  end

  @tag :package_authority
  test "package authority exposes the canonical producer and verifier interfaces" do
    assert function_exported?(
             Rindle.InstallSmoke.GeneratedAppHelper,
             :package_evidence_receipt!,
             2
           )

    assert function_exported?(Rindle.ValidateLiveTruth, :normalize_package_receipt!, 2)
    assert function_exported?(Rindle.ValidateLiveTruth, :verify_package_evidence!, 2)
  end

  @tag :package_authority
  test "executable package fixtures honor the repository Elixir support floor" do
    repository_requirement =
      @repo_root
      |> Path.join("mix.exs")
      |> File.read!()
      |> project_elixir_requirement!()

    generated_requirements = [
      package: executable_package_mix_source() |> project_elixir_requirement!(),
      consumer: executable_consumer_mix_source("/tmp/rindle") |> project_elixir_requirement!()
    ]

    for {project, requirement} <- generated_requirements do
      assert requirement == repository_requirement,
             "#{project} generated Elixir requirement diverged from repository support"

      for {version, cell} <- [
            {"1.15.0", "Elixir 1.15 / OTP 26"},
            {"1.16.0", "Elixir 1.16 / OTP 26"},
            {"1.17.0", "Elixir 1.17 / OTP 27"},
            {"1.18.0", "Elixir 1.18 / OTP 27 or 28"}
          ] do
        assert Version.match?(version, requirement),
               "#{project} excludes supported #{cell}"
      end
    end

    refute Version.match?("1.15.0", "~> 1.17"),
           "a fixture requirement above the support floor must not pass the contract"
  end

  @tag :package_authority
  test "package receipt producer rejects caller-authored command result maps" do
    root =
      Path.join(
        System.tmp_dir!(),
        "rindle-package-command-evidence-#{System.unique_integer([:positive])}"
      )

    package_root = Path.join(root, "package/rindle")
    generated_app_root = Path.join(root, "generated_app")
    File.mkdir_p!(package_root)
    File.mkdir_p!(generated_app_root)
    File.write!(Path.join(package_root, "hex_metadata.config"), "package metadata")
    File.write!(Path.join(generated_app_root, "mix.lock"), "%{}")
    on_exit(fn -> File.rm_rf(root) end)

    result = %{exit_code: 0, output: "1 test, 0 failures"}

    assert_raise ArgumentError, ~r/execution environment must contain string pairs/, fn ->
      Rindle.InstallSmoke.GeneratedAppHelper.package_evidence_receipt!(
        %{
          package_root_provenance: %{path: package_root},
          generated_app_root: generated_app_root
        },
        %{compile: result, boot: result, smoke: result, lifecycle: result}
      )
    end
  end

  @tag :package_authority
  test "caller supplied fake package evidence is rejected against the exact release version" do
    evidence = executable_package_evidence_fixture!()
    model = Rindle.ValidateLiveTruth.derive!(@repo_root, [])

    assert_raise ArgumentError, ~r/package digest mismatch/, fn ->
      Rindle.ValidateLiveTruth.validate_claims!(model, [
        %{
          type: :package,
          receipt: evidence.receipt,
          evidence_context: evidence.context
        }
      ])
    end
  end

  @tag :package_authority
  test "digest-consistent caller-authored results cannot prove package execution" do
    evidence = package_evidence_fixture!()

    assert_raise ArgumentError, ~r/package digest mismatch/, fn ->
      Rindle.ValidateLiveTruth.verify_package_evidence!(
        evidence.receipt,
        evidence.context
        |> Map.put(:expected_package_version, @current_version)
        |> Map.put(:execution_env, %{})
      )
    end
  end

  @tag :package_authority
  test "generated runtime mismatch reports compile before later command failures" do
    evidence = executable_package_evidence_fixture!()
    generated_mix = Path.join(evidence.context.generated_app_root, "mix.exs")

    replace_file!(generated_mix, @executable_elixir_requirement, "~> 99.0")

    receipt =
      Rindle.InstallSmoke.GeneratedAppHelper.package_evidence_receipt!(
        %{
          package_root_provenance: %{path: evidence.context.package_root},
          generated_app_root: evidence.context.generated_app_root
        },
        %{}
      )

    assert receipt.results["compile"]["exit_code"] != 0
    assert receipt.results["boot"]["exit_code"] != 0

    assert_raise ArgumentError, ~r/package command failed: compile/, fn ->
      Rindle.ValidateLiveTruth.verify_package_evidence!(
        receipt,
        Map.put(evidence.context, :expected_package_version, @current_version)
      )
    end
  end

  @tag :package_authority
  test "persisted package results fail closed in execution order" do
    evidence = package_evidence_fixture!()
    success = forged_command_result("success")
    failure = Map.put(success, "exit_code", 1)

    for {results, expected_stage} <- [
          {%{"compile" => failure, "boot" => failure, "smoke_lifecycle" => failure}, "compile"},
          {%{"compile" => success, "boot" => failure, "smoke_lifecycle" => failure}, "boot"},
          {%{"compile" => success, "boot" => success, "smoke_lifecycle" => failure},
           "smoke_lifecycle"}
        ] do
      File.write!(evidence.context.results_path, Jason.encode!(results))
      receipt = %{evidence.receipt | results: results}

      assert_raise ArgumentError, ~r/package command failed: #{expected_stage}/, fn ->
        Rindle.ValidateLiveTruth.verify_package_evidence!(
          receipt,
          Map.put(evidence.context, :expected_package_version, @current_version)
        )
      end
    end

    malformed = Map.delete(success, "truncated")
    results = %{"compile" => malformed, "boot" => success, "smoke_lifecycle" => success}
    File.write!(evidence.context.results_path, Jason.encode!(results))

    assert_raise ArgumentError, ~r/package command result fields mismatch: compile/, fn ->
      Rindle.ValidateLiveTruth.verify_package_evidence!(
        %{evidence.receipt | results: results},
        Map.put(evidence.context, :expected_package_version, @current_version)
      )
    end
  end

  @tag :package_authority
  test "self-consistent stale package evidence fails the independent version authority" do
    evidence = package_evidence_fixture!()
    stale_version = "0.4.5"
    package_mix = Path.join(evidence.context.package_root, "mix.exs")
    package_metadata = Path.join(evidence.context.package_root, "hex_metadata.config")
    File.write!(package_mix, package_mix_source(stale_version))
    File.write!(package_metadata, "version=#{stale_version}")

    package_tree_sha256 = test_tree_sha256(evidence.context.package_root)

    stale_receipt = %{
      evidence.receipt
      | package_version: stale_version,
        package_sha256: test_sha256(File.read!(package_metadata)),
        unpacked_tree_sha256: package_tree_sha256,
        dependency_source: %{
          type: "path",
          package_name: "rindle",
          package_version: stale_version,
          unpacked_tree_sha256: package_tree_sha256
        }
    }

    model = Rindle.ValidateLiveTruth.derive!(@repo_root, [])

    assert_raise ArgumentError, ~r/package version authority mismatch/, fn ->
      Rindle.ValidateLiveTruth.validate_claims!(model, [
        %{type: :package, receipt: stale_receipt, evidence_context: evidence.context}
      ])
    end
  end

  @tag :package_authority
  test "combined lifecycle evidence rejects copied slots and a failed execution" do
    evidence = package_evidence_fixture!()
    combined_command = evidence.receipt.commands["smoke_lifecycle"]
    combined_result = evidence.receipt.results["smoke_lifecycle"]

    duplicate_results = %{
      "compile" => evidence.receipt.results["compile"],
      "boot" => evidence.receipt.results["boot"],
      "smoke" => combined_result,
      "lifecycle" => combined_result
    }

    duplicate_receipt = %{
      evidence.receipt
      | commands: %{
          "compile" => evidence.receipt.commands["compile"],
          "boot" => evidence.receipt.commands["boot"],
          "smoke" => combined_command,
          "lifecycle" => combined_command
        },
        results: duplicate_results
    }

    File.write!(evidence.context.results_path, Jason.encode!(duplicate_results))

    assert_raise ArgumentError, ~r/duplicate package command evidence/, fn ->
      Rindle.ValidateLiveTruth.verify_package_evidence!(
        duplicate_receipt,
        Map.put(evidence.context, :expected_package_version, @current_version)
      )
    end

    failed_result = Map.put(combined_result, "exit_code", 1)
    failed_results = Map.put(evidence.receipt.results, "smoke_lifecycle", failed_result)
    failed_receipt = %{evidence.receipt | results: failed_results}
    File.write!(evidence.context.results_path, Jason.encode!(failed_results))

    assert_raise ArgumentError, ~r/package command failed: smoke_lifecycle/, fn ->
      Rindle.ValidateLiveTruth.verify_package_evidence!(
        failed_receipt,
        Map.put(evidence.context, :expected_package_version, @current_version)
      )
    end
  end

  @tag :package_authority
  test "package verifier requires an explicit version authority" do
    evidence = package_evidence_fixture!()

    assert_raise ArgumentError, ~r/expected package version authority is required/, fn ->
      Rindle.ValidateLiveTruth.verify_package_evidence!(evidence.receipt, evidence.context)
    end
  end

  @tag :package_authority
  test "subject helper materialization ignores caller edits and preserves Git bytes" do
    root = subject_helper_fixture_root!()
    subject_sha = git_head!(root)
    relative = "test/install_smoke/support/generated_app_helper.ex"
    original = git_show!(root, subject_sha, relative)
    nested_relative = "test/install_smoke/support/generated_app/workspace.ex"
    nested_original = git_show!(root, subject_sha, nested_relative)
    destination = temporary_fixture_root!("rindle-subject-helper-materialized")

    assert :ok =
             Rindle.ValidateLiveTruth.materialize_subject_helper!(
               git_executable!(),
               root,
               subject_sha,
               destination
             )

    File.write!(Path.join(root, relative), "raise \"caller edit\"\n")
    File.write!(Path.join(root, nested_relative), "raise \"caller nested edit\"\n")
    assert File.read!(Path.join(destination, "support/generated_app_helper.ex")) == original

    assert File.read!(Path.join(destination, "support/generated_app/workspace.ex")) ==
             nested_original
  end

  @tag :package_authority
  test "subject helper materialization rejects a missing closure member" do
    root = subject_helper_fixture_root!()
    missing = "test/install_smoke/support/generated_app/profile_helpers.ex"
    File.rm!(Path.join(root, missing))
    fixture_commit!(root, missing)

    assert_raise ArgumentError, ~r/subject helper member unavailable/, fn ->
      Rindle.ValidateLiveTruth.materialize_subject_helper!(
        git_executable!(),
        root,
        git_head!(root),
        temporary_fixture_root!("rindle-subject-helper-missing")
      )
    end
  end

  @tag :package_authority
  test "subject helper materialization rejects symlink members" do
    root = subject_helper_fixture_root!()
    linked = "test/install_smoke/support/generated_app/profile_helpers.ex"
    File.rm!(Path.join(root, linked))
    File.ln_s!("../../../../../../tmp/outside.ex", Path.join(root, linked))
    fixture_commit!(root, linked)

    assert_raise ArgumentError, ~r/invalid subject helper member/, fn ->
      Rindle.ValidateLiveTruth.materialize_subject_helper!(
        git_executable!(),
        root,
        git_head!(root),
        temporary_fixture_root!("rindle-subject-helper-symlink")
      )
    end
  end

  @tag :package_authority
  test "subject helper materialization rejects added and outside-root imports" do
    root = subject_helper_fixture_root!()
    helper = Path.join(root, "test/install_smoke/support/generated_app_helper.ex")
    File.write!(helper, File.read!(helper) <> "Code.require_file(\"../outside.ex\", __DIR__)\n")
    fixture_commit!(root, "test/install_smoke/support/generated_app_helper.ex")

    assert_raise ArgumentError, ~r/subject helper require-file closure mismatch/, fn ->
      Rindle.ValidateLiveTruth.materialize_subject_helper!(
        git_executable!(),
        root,
        git_head!(root),
        temporary_fixture_root!("rindle-subject-helper-extra")
      )
    end

    root = subject_helper_fixture_root!()
    support = Path.join(root, "test/install_smoke/support/generated_app/workspace.ex")
    File.write!(support, File.read!(support) <> "Code.require_file(\"/tmp/outside.ex\")\n")
    fixture_commit!(root, "test/install_smoke/support/generated_app/workspace.ex")

    assert_raise ArgumentError, ~r/untracked import/, fn ->
      Rindle.ValidateLiveTruth.materialize_subject_helper!(
        git_executable!(),
        root,
        git_head!(root),
        temporary_fixture_root!("rindle-subject-helper-nested-extra")
      )
    end
  end

  @tag :package_authority
  @tag :minio
  @tag timeout: :infinity
  test "fresh unpacked generated image consumer report authorizes package proof" do
    report = Rindle.InstallSmoke.GeneratedAppHelper.prove_package_install!(:image)
    on_exit(fn -> Rindle.InstallSmoke.GeneratedAppHelper.cleanup(report) end)
    assert report.smoke_exit_code == 0, report.smoke_output
    assert report.lifecycle_proved?, report.smoke_output
    receipt = report.package_evidence_receipt
    evidence_context = report.package_evidence_context
    model = Rindle.ValidateLiveTruth.derive!(@repo_root, [])

    caller_root = subject_helper_fixture_root!()

    for shared_path <- ["deps", "_build"] do
      File.ln_s!(Path.join(@repo_root, shared_path), Path.join(caller_root, shared_path))
    end

    helper_path = Path.join(caller_root, "test/install_smoke/support/generated_app_helper.ex")
    File.write!(helper_path, "raise \"untrusted caller helper was executed\"\n")
    fixture_context = Map.put(evidence_context, :repository_root, caller_root)
    fixture_model = Rindle.ValidateLiveTruth.derive!(caller_root, [])

    # The validator must run the real lifecycle from the authenticated subject's
    # private helper closure, even while the same path in the caller checkout lies.
    assert :ok =
             Rindle.ValidateLiveTruth.validate_claims!(fixture_model, [
               %{
                 type: :package,
                 receipt: receipt,
                 evidence_context: fixture_context,
                 claim: "built-package-consumer"
               }
             ])

    mutations = [
      {&Map.delete(&1, :subject_sha), "package receipt fields mismatch"},
      {&Map.put(&1, :unexpected, true), "package receipt fields mismatch"},
      {&Map.put(&1, :schema_version, "rindle-package-consumer-v3"),
       "package receipt schema mismatch"},
      {&Map.put(&1, :evidence_type, "independent-adopter"), "package evidence type mismatch"},
      {&Map.put(&1, :subject_sha, String.duplicate("0", 40)), "package subject SHA mismatch"},
      {&Map.put(&1, :package_name, "not-rindle"), "package name mismatch"},
      {&Map.put(&1, :package_version, "999.0.0"), "package version authority mismatch"},
      {&Map.put(&1, :package_sha256, String.duplicate("0", 64)), "package digest mismatch"},
      {&Map.put(&1, :unpacked_tree_sha256, String.duplicate("0", 64)),
       "unpacked package content mismatch"},
      {&Map.put(&1, :generated_app_tree_sha256, String.duplicate("0", 64)),
       "generated app tree digest mismatch"},
      {&Map.put(&1, :dependency_lock_sha256, String.duplicate("0", 64)),
       "dependency lock digest mismatch"},
      {&put_in(&1, [:dependency_source, :type], "git"), "dependency source mismatch"},
      {&put_in(&1, [:commands, "compile"], ["mix", "compile", "--force"]),
       "package command argv mismatch"},
      {&put_in(&1, [:results, "compile", "exit_code"], 1), "package command failed: compile"}
    ]

    for {mutation, message} <- mutations do
      assert_raise ArgumentError, ~r/#{Regex.escape(message)}/, fn ->
        Rindle.ValidateLiveTruth.validate_claims!(model, [
          %{
            type: :package,
            receipt: mutation.(receipt),
            evidence_context: evidence_context
          }
        ])
      end
    end

    hostile_context = %{
      package_root: @repo_root,
      generated_app_root: @repo_root,
      results_path: Path.join(report.package_root, "mix.exs"),
      execution_env: [{"PATH", fixture_root!()}]
    }

    assert :ok =
             Rindle.ValidateLiveTruth.validate_claims!(model, [
               %{type: :package, receipt: receipt, evidence_context: evidence_context},
               %{type: :package, receipt: receipt, evidence_context: hostile_context}
             ])
  end

  @tag :package_authority
  test "caller-authored summaries and arbitrary evidence directories cannot authorize package claims" do
    model = Rindle.ValidateLiveTruth.derive!(@repo_root, [])
    arbitrary_root = fixture_root!()

    assert_raise ArgumentError, ~r/package receipt fields mismatch/, fn ->
      Rindle.ValidateLiveTruth.validate_claims!(model, [
        %{type: :package, receipt: %{lifecycle_proved: true}, evidence_context: %{}}
      ])
    end

    forged =
      Map.new(
        ~w(
        schema_version evidence_type subject_sha package_name package_version package_sha256
        unpacked_tree_sha256 generated_app_tree_sha256 dependency_lock_sha256 dependency_source
        commands results
      ),
        &{&1, "forged"}
      )

    assert_raise ArgumentError, ~r/package receipt schema mismatch/, fn ->
      Rindle.ValidateLiveTruth.validate_claims!(model, [
        %{
          type: :package,
          receipt: forged,
          evidence_context: %{
            package_root: arbitrary_root,
            generated_app_root: arbitrary_root,
            results_path: Path.join(arbitrary_root, "mix.exs")
          }
        }
      ])
    end
  end

  @tag :package_authority
  test "standalone package receipt requires exactly one explicit consuming claim" do
    evidence = package_evidence_fixture!()
    receipt_path = write_json_fixture!(evidence.receipt)

    assert_raise ArgumentError, ~r/package receipt argument must be consumed exactly once/, fn ->
      Rindle.ValidateLiveTruth.run([
        "--root",
        @repo_root,
        "--package-receipt",
        receipt_path
      ])
    end
  end

  @tag :package_authority
  test "malformed package receipt JSON fails with a bounded validation error" do
    receipt_path = write_text_fixture!("{")

    assert_raise ArgumentError, ~r/malformed package receipt JSON/, fn ->
      Rindle.ValidateLiveTruth.run([
        "--root",
        @repo_root,
        "--package-receipt",
        receipt_path
      ])
    end
  end

  @tag :package_authority
  test "package receipt argument rejects multiple consumers and incomplete context" do
    evidence = package_evidence_fixture!()
    receipt_path = write_json_fixture!(evidence.receipt)

    consumer = %{
      type: "package",
      receipt_source: "package-receipt-argument",
      evidence_context: evidence.context
    }

    claims_path = write_json_fixture!([consumer, consumer])

    assert_raise ArgumentError, ~r/package receipt argument must be consumed exactly once/, fn ->
      Rindle.ValidateLiveTruth.run([
        "--root",
        @repo_root,
        "--package-receipt",
        receipt_path,
        "--claims",
        claims_path
      ])
    end

    incomplete_claims_path =
      write_json_fixture!([
        %{type: "package", receipt_source: "package-receipt-argument", evidence_context: %{}}
      ])

    assert_raise ArgumentError,
                 ~r/package receipt consumer requires complete evidence context/,
                 fn ->
                   Rindle.ValidateLiveTruth.run([
                     "--root",
                     @repo_root,
                     "--package-receipt",
                     receipt_path,
                     "--claims",
                     incomplete_claims_path
                   ])
                 end
  end

  @tag :package_authority
  test "one complete package claim consumes and normalizes the receipt argument" do
    evidence = executable_package_evidence_fixture!()
    receipt_path = write_json_fixture!(evidence.receipt)

    claims_path =
      write_json_fixture!([
        %{
          type: "package",
          receipt_source: "package-receipt-argument",
          evidence_context: evidence.context
        }
      ])

    assert_raise ArgumentError, ~r/package digest mismatch/, fn ->
      Rindle.ValidateLiveTruth.run([
        "--root",
        @repo_root,
        "--format",
        "json",
        "--package-receipt",
        receipt_path,
        "--claims",
        claims_path
      ])
    end
  end

  @tag :package_authority
  test "a caller supplied trivial package cannot stand in for the committed Rindle package" do
    evidence = executable_package_evidence_fixture!()
    model = Rindle.ValidateLiveTruth.derive!(@repo_root, [])

    assert_raise ArgumentError, ~r/package digest mismatch/, fn ->
      Rindle.ValidateLiveTruth.validate_claims!(model, [
        %{
          type: :package,
          receipt: evidence.receipt,
          evidence_context: evidence.context
        }
      ])
    end
  end

  @tag :package_authority
  test "package receipt argument rejects inline disagreement" do
    evidence = package_evidence_fixture!()
    receipt_path = write_json_fixture!(evidence.receipt)

    claims_path =
      write_json_fixture!([
        %{
          type: "package",
          receipt_source: "package-receipt-argument",
          receipt: Map.put(evidence.receipt, :subject_sha, String.duplicate("0", 40)),
          evidence_context: evidence.context
        }
      ])

    assert_raise ArgumentError, ~r/package receipt argument disagrees with inline receipt/, fn ->
      Rindle.ValidateLiveTruth.run([
        "--root",
        @repo_root,
        "--package-receipt",
        receipt_path,
        "--claims",
        claims_path
      ])
    end
  end

  @tag :package_authority
  test "independent adopter authority is repository-owned and empty until a pilot is approved" do
    assert function_exported?(
             Rindle.ValidateLiveTruth,
             :verify_independent_adopter_evidence!,
             2
           )

    model = Rindle.ValidateLiveTruth.derive!(@repo_root, [])
    copied_package_receipt = %{schema_version: "rindle-package-consumer-v2"}

    for caller_field <- [:evidence_kind, :adopter_name, :authorizes_1_0] do
      claim =
        %{type: :adoption, receipt: copied_package_receipt}
        |> Map.put(caller_field, true)

      assert_raise ArgumentError, ~r/caller-controlled adoption authority is forbidden/, fn ->
        Rindle.ValidateLiveTruth.validate_claims!(model, [claim])
      end
    end

    evidence_path = Path.join(System.tmp_dir!(), "rindle-independent-evidence.txt")
    File.write!(evidence_path, "independent evidence fixture")
    on_exit(fn -> File.rm(evidence_path) end)

    receipt = %{
      schema_version: "rindle-independent-adopter-v1",
      evidence_type: "independent-adopter",
      authority_id: "unapproved-pilot",
      subject_sha: String.duplicate("0", 40),
      evidence_sha256: String.duplicate("0", 64),
      authorization_scope: ["independent-adoption", "1.0"]
    }

    for {mutation, message} <- [
          {&Map.delete(&1, :subject_sha), "independent adopter receipt fields mismatch"},
          {&Map.put(&1, :caller_authorizes_1_0, true),
           "independent adopter receipt fields mismatch"},
          {&Map.put(&1, :schema_version, "rindle-package-consumer-v2"),
           "independent adopter schema mismatch"},
          {&Map.put(&1, :evidence_type, "maintainer-operated-package-consumer"),
           "independent adopter evidence type mismatch"}
        ] do
      assert_raise ArgumentError, ~r/#{Regex.escape(message)}/, fn ->
        Rindle.ValidateLiveTruth.verify_independent_adopter_evidence!(
          mutation.(receipt),
          %{evidence_path: evidence_path}
        )
      end
    end

    assert_raise ArgumentError, ~r/independent adopter authority is not allowlisted/, fn ->
      Rindle.ValidateLiveTruth.validate_claims!(model, [
        %{type: :adoption, receipt: receipt, evidence_context: %{evidence_path: evidence_path}}
      ])
    end
  end

  defp fixture_root! do
    root = Path.join(System.tmp_dir!(), "rindle-live-truth-#{System.unique_integer([:positive])}")

    for path <- [
          "mix.exs",
          ".release-please-manifest.json",
          ".github/workflows/ci.yml",
          ".github/workflows/nightly.yml",
          ".github/workflows/release.yml",
          "scripts/setup_branch_protection.sh",
          "config/ci_required_checks.json"
        ] do
      destination = Path.join(root, path)
      File.mkdir_p!(Path.dirname(destination))
      File.cp!(Path.join(@repo_root, path), destination)
    end

    on_exit(fn -> File.rm_rf(root) end)
    root
  end

  defp assert_running_nightly_authority!(running, model) do
    prose =
      running
      |> String.replace(~r/(^|\n)>\s?/, "\\1")
      |> String.replace(~r/\s+/, " ")

    assert prose =~ "not required PR checks"
    assert prose =~ "are all **Nightly-gating** inputs to the strict `Nightly Summary`"

    for lane <- model.nightly.required_needs do
      assert running =~ "`#{lane}`"
    end

    assert prose =~
             "Any applicable lane that fails, is cancelled, is unexpected, is missing, or is impermissibly skipped makes Nightly red."

    assert prose =~ "exact-subject Nightly evidence receipt"
    refute running =~ ".planning"
    assert running =~ "scripts/ci/verify_nightly_run.sh verify-receipt"
    refute prose =~ "advisory and never a required PR check"
    refute Regex.match?(~r/Plan \d+.*live acceptance authority/i, prose)
  end

  defp assert_running_required_check_authority!(running, model) do
    prose = String.replace(running, ~r/\s+/, " ")
    [context] = model.ci.required_check_policy.contexts

    assert prose =~ "`config/ci_required_checks.json` is the sole structured authority"
    assert prose =~ "`scripts/setup_branch_protection.sh` loads its contexts"

    assert prose =~
             "`scripts/maintainer/validate_live_truth.exs` cross-checks the same workflow, job, and context identity"

    assert prose =~
             "maps `ci.yml` / `CI` / `ci-summary` to the sole required context `#{context}`"

    refute prose =~ "REQUIRED_CHECKS=("
  end

  defp assert_required_check_consumers!(setup, validator) do
    assert setup =~ "POLICY_FILE=\"${SCRIPT_DIR}/../config/ci_required_checks.json\""
    assert setup =~ "jq -r '.contexts[]' \"${POLICY_FILE}\""
    assert validator =~ "@required_check_policy_file \"config/ci_required_checks.json\""
    assert validator =~ "policy = required_check_policy!(root)"
  end

  defp required_check_policy do
    %{
      "schema_version" => "rindle-required-checks-v1",
      "workflow" => %{
        "file" => "ci.yml",
        "name" => "CI",
        "job_id" => "ci-summary"
      },
      "contexts" => ["CI Summary"]
    }
  end

  defp package_evidence_fixture! do
    root =
      Path.join(
        System.tmp_dir!(),
        "rindle-package-authority-#{System.unique_integer([:positive])}"
      )

    package_root = Path.join(root, "package/rindle")
    generated_app_root = Path.join(root, "generated_app")
    results_path = Path.join(generated_app_root, "tmp/rindle_package_evidence_results.json")
    File.mkdir_p!(package_root)
    File.mkdir_p!(generated_app_root)
    File.write!(Path.join(package_root, "mix.exs"), package_mix_source(@current_version))
    File.write!(Path.join(package_root, "hex_metadata.config"), "version=#{@current_version}")

    File.write!(
      Path.join(generated_app_root, "mix.exs"),
      "defmodule Generated.MixProject do\n  defp deps, do: [{:rindle, path: #{inspect(package_root)}}]\nend\n"
    )

    File.write!(Path.join(generated_app_root, "mix.lock"), "%{}")
    on_exit(fn -> File.rm_rf(root) end)

    results = %{
      "compile" => forged_command_result("compile ok"),
      "boot" => forged_command_result("boot ok"),
      "smoke_lifecycle" => forged_command_result("2 tests, 0 failures")
    }

    File.mkdir_p!(Path.dirname(results_path))
    File.write!(results_path, Jason.encode!(results))

    package_tree_sha256 = test_tree_sha256(package_root)

    receipt = %{
      schema_version: "rindle-package-consumer-v2",
      evidence_type: "maintainer-operated-package-consumer",
      subject_sha: git_head!(),
      package_name: "rindle",
      package_version: @current_version,
      package_sha256: test_sha256(File.read!(Path.join(package_root, "hex_metadata.config"))),
      unpacked_tree_sha256: package_tree_sha256,
      generated_app_tree_sha256:
        test_tree_sha256(generated_app_root, [".git", "_build", "deps", "tmp"], [
          {package_root, "$RINDLE_PACKAGE_ROOT"}
        ]),
      dependency_lock_sha256: test_sha256(File.read!(Path.join(generated_app_root, "mix.lock"))),
      dependency_source: %{
        type: "path",
        package_name: "rindle",
        package_version: @current_version,
        unpacked_tree_sha256: package_tree_sha256
      },
      commands: package_commands(generated_app_root),
      results: results
    }

    %{
      receipt: receipt,
      context: %{
        repository_root: @repo_root,
        package_root: package_root,
        generated_app_root: generated_app_root,
        results_path: results_path,
        execution_env: %{}
      }
    }
  end

  defp executable_package_evidence_fixture! do
    root =
      Path.join(
        System.tmp_dir!(),
        "rindle-executable-package-authority-#{System.unique_integer([:positive])}"
      )

    package_root = Path.join(root, "package/rindle")
    generated_app_root = Path.join(root, "generated_app")
    results_path = Path.join(generated_app_root, "tmp/rindle_package_evidence_results.json")

    write_fixture_file!(package_root, "mix.exs", executable_package_mix_source())
    write_fixture_file!(package_root, "hex_metadata.config", "version=#{@current_version}")

    write_fixture_file!(
      generated_app_root,
      "mix.exs",
      executable_consumer_mix_source(package_root)
    )

    write_fixture_file!(generated_app_root, "mix.lock", "%{}")

    write_fixture_file!(
      generated_app_root,
      "config/config.exs",
      "import Config\nconfig :rindle, :repo, GeneratedApp.Repo\nconfig :generated_app, Oban, repo: GeneratedApp.Repo\n"
    )

    write_fixture_file!(
      generated_app_root,
      "lib/generated_app/repo.ex",
      "defmodule GeneratedApp.Repo do\nend\n"
    )

    write_fixture_file!(generated_app_root, "test/test_helper.exs", "ExUnit.start()\n")

    write_fixture_file!(
      generated_app_root,
      "test/rindle_install_smoke_test.exs",
      "defmodule GeneratedApp.InstallSmokeTest do\n  use ExUnit.Case\n  test \"lifecycle\", do: assert(true)\nend\n"
    )

    on_exit(fn -> File.rm_rf(root) end)

    receipt =
      Rindle.InstallSmoke.GeneratedAppHelper.package_evidence_receipt!(
        %{
          package_root_provenance: %{path: package_root},
          generated_app_root: generated_app_root
        },
        %{}
      )

    %{
      receipt: receipt,
      context: %{
        repository_root: @repo_root,
        package_root: package_root,
        generated_app_root: generated_app_root,
        results_path: results_path,
        execution_env: %{}
      }
    }
  end

  defp package_mix_source(version) do
    "defmodule Rindle.PackageFixture.MixProject do\n  @version #{inspect(version)}\nend\n"
  end

  defp test_tree_sha256(root, excluded_roots \\ [], substitutions \\ []) do
    root
    |> Path.join("**/*")
    |> Path.wildcard(match_dot: true)
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(&Path.relative_to(&1, root))
    |> Enum.reject(fn relative ->
      (relative |> Path.split() |> List.first()) in excluded_roots
    end)
    |> Enum.sort()
    |> Enum.map(fn relative ->
      content = File.read!(Path.join(root, relative))

      content =
        Enum.reduce(substitutions, content, fn {from, to}, content ->
          String.replace(content, from, to)
        end)

      relative <> "\0" <> test_sha256(content) <> "\n"
    end)
    |> IO.iodata_to_binary()
    |> test_sha256()
  end

  defp test_sha256(content),
    do: :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)

  defp forged_command_result(output) do
    %{
      "exit_code" => 0,
      "stdout_sha256" => test_sha256(output),
      "stderr_sha256" => test_sha256(""),
      "stderr_merged_into_stdout" => true,
      "captured_bytes" => byte_size(output),
      "truncated" => false
    }
  end

  defp package_commands(generated_app_root) do
    app_module = generated_app_root |> Path.basename() |> Macro.camelize()
    app_name = Macro.underscore(app_module)

    %{
      "compile" => ["mix", "compile"],
      "boot" => [
        "mix",
        "run",
        "--no-start",
        "-e",
        "Application.ensure_all_started(:#{app_name}); repo = Application.fetch_env!(:rindle, :repo); oban_repo = Application.fetch_env!(:#{app_name}, Oban)[:repo]; if repo != #{app_module}.Repo or oban_repo != #{app_module}.Repo, do: raise(\"boot wiring invalid\"); IO.puts(\"boot ok\")"
      ],
      "smoke_lifecycle" => [
        "mix",
        "test",
        "test/rindle_install_smoke_test.exs",
        "--seed",
        "0"
      ]
    }
  end

  defp git_head! do
    {sha, 0} = System.cmd("git", ["-C", @repo_root, "rev-parse", "HEAD"])
    String.trim(sha)
  end

  defp git_head!(root) do
    {sha, 0} = System.cmd("git", ["-C", root, "rev-parse", "HEAD"])
    String.trim(sha)
  end

  defp git_show!(root, subject_sha, relative) do
    {bytes, 0} = System.cmd("git", ["-C", root, "show", "#{subject_sha}:#{relative}"])
    bytes
  end

  defp git_executable! do
    System.find_executable("git") || flunk("git executable unavailable")
  end

  defp subject_helper_fixture_root! do
    root = temporary_fixture_root!("rindle-subject-helper-fixture")
    {_, 0} = System.cmd("git", ["clone", "--shared", "--quiet", @repo_root, root])
    root
  end

  defp temporary_fixture_root!(prefix) do
    root = Path.join(System.tmp_dir!(), "#{prefix}-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf(root) end)
    root
  end

  defp fixture_commit!(root, path) do
    {_, 0} = System.cmd("git", ["-C", root, "add", "--", path])

    {_, 0} =
      System.cmd("git", [
        "-C",
        root,
        "-c",
        "user.name=GSD Fixture",
        "-c",
        "user.email=gsd-fixture@example.invalid",
        "commit",
        "--quiet",
        "-m",
        "subject helper fixture"
      ])
  end

  defp write_fixture_file!(root, relative, content) do
    path = Path.join(root, relative)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
  end

  defp write_json_fixture!(value), do: write_text_fixture!(Jason.encode!(value))

  defp write_text_fixture!(content) do
    path =
      Path.join(
        System.tmp_dir!(),
        "rindle-live-truth-input-#{System.unique_integer([:positive])}.json"
      )

    File.write!(path, content)
    on_exit(fn -> File.rm(path) end)
    path
  end

  defp project_elixir_requirement!(source) do
    case Regex.run(~r/elixir:\s*"([^"]+)"/, source, capture: :all_but_first) do
      [requirement] -> requirement
      _ -> flunk("Mix project source does not declare an Elixir requirement")
    end
  end

  defp executable_package_mix_source do
    """
    defmodule Rindle.MixProject do
      use Mix.Project
      @version #{inspect(@current_version)}
      def project, do: [app: :rindle, version: @version, elixir: #{inspect(@executable_elixir_requirement)}]
      def application, do: []
    end
    """
  end

  defp executable_consumer_mix_source(package_root) do
    """
    defmodule GeneratedApp.MixProject do
      use Mix.Project
      def project, do: [app: :generated_app, version: "0.1.0", elixir: #{inspect(@executable_elixir_requirement)}, deps: deps()]
      def application, do: [extra_applications: [:logger]]
      defp deps, do: [{:rindle, path: #{inspect(package_root)}}]
    end
    """
  end

  defp write_policy!(root, policy) do
    path = Path.join(root, "config/ci_required_checks.json")
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Jason.encode!(policy))
  end

  defp write!(root, path, content), do: File.write!(Path.join(root, path), content)

  defp replace!(root, path, old, new, options \\ []) do
    full_path = Path.join(root, path)
    content = File.read!(full_path)

    replacement =
      if Keyword.get(options, :global, true) do
        String.replace(content, old, new)
      else
        String.replace(content, old, new, global: false)
      end

    assert replacement != content, "fixture mutation did not match #{old}"
    File.write!(full_path, replacement)
  end

  defp replace_file!(path, old, new) do
    content = File.read!(path)
    replacement = String.replace(content, old, new, global: false)
    assert replacement != content, "fixture mutation did not match #{old}"
    File.write!(path, replacement)
  end

  defp assert_error(root, message) do
    assert_raise ArgumentError, ~r/#{Regex.escape(message)}/, fn ->
      Rindle.ValidateLiveTruth.derive!(root, [])
    end
  end
end

defmodule Rindle.InstallSmoke.LiveTruthAtomSafetyTest do
  # VM atom count is global. Keep this probe synchronous so parallel ExUnit
  # examples cannot allocate legitimate atoms during the before/after sample.
  use ExUnit.Case, async: false

  @tag :package_authority
  test "migration resolver decoding is finite and cannot allocate caller atoms" do
    assert function_exported?(
             Rindle.InstallSmoke.GeneratedAppHelper,
             :decode_migration_resolver!,
             1
           )

    assert Rindle.InstallSmoke.GeneratedAppHelper.decode_migration_resolver!(nil) == nil

    assert Rindle.InstallSmoke.GeneratedAppHelper.decode_migration_resolver!("host_migrations") ==
             :host_migrations

    assert_raise ArgumentError, ~r/unknown generated migration resolver/, fn ->
      Rindle.InstallSmoke.GeneratedAppHelper.decode_migration_resolver!("resolver-warmup")
    end

    atom_count_before = :erlang.system_info(:atom_count)

    for suffix <- 1..1_000 do
      assert_raise ArgumentError, ~r/unknown generated migration resolver/, fn ->
        Rindle.InstallSmoke.GeneratedAppHelper.decode_migration_resolver!(
          "unknown-resolver-#{suffix}"
        )
      end
    end

    assert :erlang.system_info(:atom_count) == atom_count_before

    assert_raise ArgumentError, ~r/generated migration resolver must be a known string/, fn ->
      Rindle.InstallSmoke.GeneratedAppHelper.decode_migration_resolver!(42)
    end
  end
end
