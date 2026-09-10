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
  test "fresh unpacked generated image consumer report authorizes package proof" do
    report = Rindle.InstallSmoke.GeneratedAppHelper.prove_package_install!(:image)
    on_exit(fn -> Rindle.InstallSmoke.GeneratedAppHelper.cleanup(report) end)
    assert report.smoke_exit_code == 0, report.smoke_output
    assert report.lifecycle_proved?, report.smoke_output

    receipt = %{
      proof_origin: "generated-app-helper",
      install_mode: report.install_mode,
      install_source: report.install_source,
      package_root: report.package_root,
      generated_app_root: report.generated_app_root,
      package_root_provenance: report.package_root_provenance,
      repository_path_fallback: report.package_root_provenance.repository_path_fallback?,
      prebuilt_local_fallback: false,
      deps_rindle_present: report.deps_rindle_present?,
      compile_exit_code: report.compile_exit_code,
      boot_exit_code: report.boot_exit_code,
      smoke_exit_code: report.smoke_exit_code,
      lifecycle_proved: report.lifecycle_proved?
    }

    model = Rindle.ValidateLiveTruth.derive!(@repo_root, [])

    assert :ok =
             Rindle.ValidateLiveTruth.validate_claims!(model, [
               %{type: :package, receipt: receipt, claim: "built-package-consumer"},
               %{
                 type: :adoption,
                 receipt: receipt,
                 evidence_kind: "maintainer-operated-synthetic",
                 authorizes_1_0: false
               }
             ])
  end

  @tag :package_authority
  test "caller validation markers cannot impersonate generated package authority" do
    nonexistent_path =
      Path.join(
        System.tmp_dir!(),
        "rindle-forged-package-proof-#{System.unique_integer([:positive])}"
      )

    forged_receipt = %{
      validated: true,
      install_mode: "package",
      install_source: nonexistent_path,
      unpacked_path: nonexistent_path,
      deps_rindle_present: false
    }

    model = Rindle.ValidateLiveTruth.derive!(@repo_root, [])

    assert_raise ArgumentError, ~r/package proof is not a generated consumer report/, fn ->
      Rindle.ValidateLiveTruth.validate_claims!(model, [
        %{type: :package, receipt: forged_receipt}
      ])
    end

    forged_provenance_receipt =
      Map.merge(forged_receipt, %{
        proof_origin: "generated-app-helper",
        generated_app_root: "#{nonexistent_path}-consumer",
        package_root_provenance: %{
          path: nonexistent_path,
          unpacked?: true,
          repository_path_fallback?: false
        },
        repository_path_fallback: false,
        prebuilt_local_fallback: false,
        compile_exit_code: 0,
        boot_exit_code: 0,
        smoke_exit_code: 0,
        lifecycle_proved: true
      })

    assert_raise ArgumentError, ~r/unpacked package path does not exist/, fn ->
      Rindle.ValidateLiveTruth.validate_claims!(model, [
        %{type: :package, receipt: forged_provenance_receipt}
      ])
    end

    receipt_path = "#{nonexistent_path}-receipt.json"
    claims_path = "#{nonexistent_path}-claims.json"
    File.write!(receipt_path, Jason.encode!(forged_provenance_receipt))
    File.write!(claims_path, Jason.encode!([%{type: "package"}]))
    on_exit(fn -> File.rm(receipt_path) end)
    on_exit(fn -> File.rm(claims_path) end)

    assert_raise ArgumentError, ~r/unpacked package path does not exist/, fn ->
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
  test "repository, prebuilt, unpacked, and install-source provenance mutations fail closed" do
    receipt = package_receipt_fixture!()
    model = Rindle.ValidateLiveTruth.derive!(@repo_root, [])

    for {mutation, message} <- [
          {&Map.put(&1, :repository_path_fallback, true),
           "repository source fallback is forbidden"},
          {&Map.put(&1, :prebuilt_local_fallback, true), "prebuilt local fallback is forbidden"},
          {&put_in(&1, [:package_root_provenance, :unpacked?], false),
           "unpacked package evidence is required"},
          {&Map.put(&1, :install_source, "/tmp/not-the-unpacked-package"),
           "install source does not match unpacked package"}
        ] do
      assert_raise ArgumentError, ~r/#{Regex.escape(message)}/, fn ->
        Rindle.ValidateLiveTruth.validate_claims!(model, [
          %{type: :package, receipt: mutation.(receipt)}
        ])
      end
    end
  end

  @tag :package_authority
  test "prose, checkout-local, and mock-only reports cannot authorize package claims" do
    model = Rindle.ValidateLiveTruth.derive!(@repo_root, [])

    for {receipt, message} <- [
          {%{documentation: "the package consumer passed"},
           "package proof is not a generated consumer report"},
          {%{
             proof_origin: "checkout-compile",
             install_mode: :package,
             install_source: @repo_root,
             package_root_provenance: %{path: @repo_root, unpacked?: true}
           }, "package proof is not a generated consumer report"},
          {%{
             proof_origin: "generated-app-helper",
             install_mode: :package,
             install_source: "/tmp/fake",
             package_root_provenance: %{
               path: "/tmp/fake",
               unpacked?: true,
               repository_path_fallback?: false
             },
             repository_path_fallback: false,
             prebuilt_local_fallback: false
           }, "generated consumer proof is incomplete"}
        ] do
      assert_raise ArgumentError, ~r/#{Regex.escape(message)}/, fn ->
        Rindle.ValidateLiveTruth.validate_claims!(model, [
          %{type: :package, receipt: receipt}
        ])
      end
    end
  end

  @tag :package_authority
  test "synthetic evidence cannot impersonate a named independent adopter or authorize 1.0" do
    model = Rindle.ValidateLiveTruth.derive!(@repo_root, [])
    receipt = package_receipt_fixture!()

    assert_raise ArgumentError, ~r/synthetic evidence cannot authorize 1.0/, fn ->
      Rindle.ValidateLiveTruth.validate_claims!(model, [
        %{
          type: :adoption,
          receipt: receipt,
          evidence_kind: "maintainer-operated-synthetic",
          authorizes_1_0: true
        }
      ])
    end

    assert_raise ArgumentError,
                 ~r/independent adopter claim requires named independent evidence/,
                 fn ->
                   Rindle.ValidateLiveTruth.validate_claims!(model, [
                     %{
                       type: :adoption,
                       receipt: receipt,
                       evidence_kind: "independent-adopter",
                       adopter_name: nil,
                       authorizes_1_0: false
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

  defp package_receipt_fixture! do
    root =
      Path.join(System.tmp_dir!(), "rindle-package-proof-#{System.unique_integer([:positive])}")

    package_root = Path.join(root, "package/rindle-0.4.6")
    generated_app_root = Path.join(root, "consumer")
    File.mkdir_p!(package_root)
    File.mkdir_p!(generated_app_root)
    File.write!(Path.join(package_root, "hex_metadata.config"), "package metadata")
    File.write!(Path.join(package_root, "mix.exs"), "defmodule PackageFixture do\nend\n")
    on_exit(fn -> File.rm_rf(root) end)

    %{
      proof_origin: "generated-app-helper",
      install_mode: :package,
      install_source: package_root,
      package_root: package_root,
      generated_app_root: generated_app_root,
      package_root_provenance: %{
        path: package_root,
        unpacked?: true,
        repository_path_fallback?: false
      },
      repository_path_fallback: false,
      prebuilt_local_fallback: false,
      deps_rindle_present: false,
      compile_exit_code: 0,
      boot_exit_code: 0,
      smoke_exit_code: 0,
      lifecycle_proved: true
    }
  end
end
