defmodule Rindle.InstallSmoke.LiveTruthParityTest do
  use ExUnit.Case, async: true

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
