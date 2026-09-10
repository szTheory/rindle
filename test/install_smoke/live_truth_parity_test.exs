Code.require_file("support/generated_app_helper.ex", __DIR__)

defmodule Rindle.InstallSmoke.LiveTruthParityTest do
  use ExUnit.Case, async: true
  @compile {:no_warn_undefined, Rindle.ValidateLiveTruth}

  @repo_root Path.expand("../..", __DIR__)
  @validator Path.join(@repo_root, "scripts/maintainer/validate_live_truth.exs")
  @historical_start "<!-- rindle:historical-receipt:start -->"
  @historical_end "<!-- rindle:historical-receipt:end -->"
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
    assert model.version == "0.4.6"

    assert model.version_authorities == %{
             mix_exs: "0.4.6",
             release_please_manifest: "0.4.6"
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

    assert :ok =
             Rindle.ValidateLiveTruth.validate_claims!(model, [
               %{
                 type: :package,
                 receipt: receipt,
                 evidence_context: evidence_context,
                 claim: "built-package-consumer"
               }
             ])

    mutations = [
      {&Map.delete(&1, :subject_sha), "package receipt fields mismatch"},
      {&Map.put(&1, :unexpected, true), "package receipt fields mismatch"},
      {&Map.put(&1, :schema_version, "rindle-package-consumer-v2"),
       "package receipt schema mismatch"},
      {&Map.put(&1, :evidence_type, "independent-adopter"), "package evidence type mismatch"},
      {&Map.put(&1, :subject_sha, String.duplicate("0", 40)), "package subject SHA mismatch"},
      {&Map.put(&1, :package_name, "not-rindle"), "package name mismatch"},
      {&Map.put(&1, :package_version, "999.0.0"), "package version mismatch"},
      {&Map.put(&1, :package_sha256, String.duplicate("0", 64)), "package digest mismatch"},
      {&Map.put(&1, :unpacked_tree_sha256, String.duplicate("0", 64)),
       "unpacked tree digest mismatch"},
      {&Map.put(&1, :generated_app_tree_sha256, String.duplicate("0", 64)),
       "generated app tree digest mismatch"},
      {&Map.put(&1, :dependency_lock_sha256, String.duplicate("0", 64)),
       "dependency lock digest mismatch"},
      {&put_in(&1, [:dependency_source, :type], "git"), "dependency source mismatch"},
      {&put_in(&1, [:commands, "compile"], ["mix", "compile", "--force"]),
       "package command argv mismatch"},
      {&put_in(&1, [:results, "compile", "exit_code"], 1), "package command results mismatch"}
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

  defp fixture_root! do
    root = Path.join(System.tmp_dir!(), "rindle-live-truth-#{System.unique_integer([:positive])}")

    for path <- [
          "mix.exs",
          ".release-please-manifest.json",
          ".github/workflows/ci.yml",
          ".github/workflows/nightly.yml",
          ".github/workflows/release.yml",
          "scripts/setup_branch_protection.sh"
        ] do
      destination = Path.join(root, path)
      File.mkdir_p!(Path.dirname(destination))
      File.cp!(Path.join(@repo_root, path), destination)
    end

    on_exit(fn -> File.rm_rf(root) end)
    root
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

  defp assert_error(root, message) do
    assert_raise ArgumentError, ~r/#{Regex.escape(message)}/, fn ->
      Rindle.ValidateLiveTruth.derive!(root, [])
    end
  end
end
