defmodule Rindle.InstallSmoke.EvidenceCensusTest do
  use ExUnit.Case, async: true

  @repo_root Path.expand("../..", __DIR__)
  @collector Path.join(@repo_root, "scripts/maintainer/evidence_census.exs")
  @validator Path.join(@repo_root, "scripts/maintainer/validate_evidence_census.exs")
  @dimensions [
    "correctness",
    "maintainability",
    "security",
    "performance",
    "reliability",
    "compatibility",
    "testing",
    "documentation/accessibility",
    "packaging",
    "CI/CD",
    "release engineering",
    "repository hygiene"
  ]

  test "EVID-01: clean exact-head receipt validates against a separate reviewed ledger" do
    fixture = census_fixture!()

    assert {collector_output, 0} = run_collector(fixture)
    assert collector_output =~ "wrote non-authoritative" == false

    assert {validator_output, 0} = run_validator(fixture)
    assert validator_output =~ "evidence census valid"

    receipt = fixture.receipt |> File.read!() |> Jason.decode!()

    assert receipt["source_sha"] == fixture.sha
    assert receipt["dirty"] == false
    assert Enum.map(receipt["dimensions"], & &1["id"]) == @dimensions
    assert Enum.map(receipt["observations"], & &1["id"]) == ["obs-default-tests"]
    assert is_binary(receipt["candidates_digest"])

    assert receipt["inputs"] == [
             %{
               "detector_id" => "default-exunit",
               "path" => "mix.exs",
               "sha256" => sha256("fixture\n")
             }
           ]
  end

  defp census_fixture! do
    base =
      Path.join(System.tmp_dir!(), "rindle-evidence-census-#{System.unique_integer([:positive])}")

    root = Path.join(base, "subject")
    ledger_path = Path.join(base, "ledger.json")
    receipt_path = Path.join(base, "receipt.json")

    File.mkdir_p!(root)
    File.write!(Path.join(root, "mix.exs"), "fixture\n")
    git!(root, ["init", "--quiet"])
    git!(root, ["config", "user.email", "fixture@example.invalid"])
    git!(root, ["config", "user.name", "Evidence Fixture"])
    git!(root, ["add", "mix.exs"])
    git!(root, ["commit", "--quiet", "-m", "fixture"])
    sha = git!(root, ["rev-parse", "HEAD"])

    ledger = %{
      "schema_version" => 1,
      "subject_sha" => sha,
      "taxonomy" =>
        Enum.map(@dimensions, fn dimension ->
          if dimension == "correctness" do
            %{"id" => dimension, "applicable" => true, "detectors" => ["default-exunit"]}
          else
            %{
              "id" => dimension,
              "applicable" => false,
              "detectors" => [],
              "rationale" => "not exercised by the minimal tracer fixture"
            }
          end
        end),
      "detectors" => [
        %{
          "id" => "default-exunit",
          "dimension" => "correctness",
          "command" => "mix test",
          "inputs" => ["mix.exs"],
          "observations" => [
            %{
              "id" => "obs-default-tests",
              "kind" => "test-suite",
              "location" => "test",
              "status" => "pass",
              "attributes" => %{"count" => 1}
            }
          ]
        }
      ],
      "candidates" => [
        %{
          "id" => "candidate-default-tests",
          "observations" => ["obs-default-tests"],
          "disposition" => "fix",
          "rationale" => "fixture candidate exercises the exact-head contract",
          "evidence" => ["mix test"],
          "trigger" => nil
        }
      ],
      "phase_133_transitions" => []
    }

    File.write!(ledger_path, Jason.encode!(ledger))
    on_exit(fn -> File.rm_rf(base) end)

    %{root: root, ledger: ledger_path, receipt: receipt_path, sha: sha}
  end

  defp run_collector(fixture) do
    run_script(@collector, [
      "--root",
      fixture.root,
      "--ledger",
      fixture.ledger,
      "--output",
      fixture.receipt,
      "--source-sha",
      fixture.sha
    ])
  end

  defp run_validator(fixture) do
    run_script(@validator, [
      "--root",
      fixture.root,
      "--ledger",
      fixture.ledger,
      "--receipt",
      fixture.receipt
    ])
  end

  defp run_script(script, args) do
    System.cmd("mix", ["run", "--no-compile", "--no-start", script | args],
      cd: @repo_root,
      stderr_to_stdout: true
    )
  end

  defp git!(root, args) do
    {output, 0} = System.cmd("git", args, cd: root, stderr_to_stdout: true)
    String.trim(output)
  end

  defp sha256(contents), do: :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)
end
