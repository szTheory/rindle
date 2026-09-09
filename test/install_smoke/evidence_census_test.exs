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
  @detector_registry [
    {"default-exunit", "correctness", "mix test", ["mix.exs"]},
    {"credo-quality", "maintainability", "mix credo_quality",
     ["scripts/maintainer/credo_complexity_baseline.json", "scripts/maintainer/credo_quality.sh"]},
    {"mix-audit", "security", "mix deps.audit", ["mix.exs", "mix.lock"]},
    {"pr-timing", "performance", "validate accepted PR timing receipt",
     [
       ".planning/milestones/v1.25-phases/132-final-craft-truth-and-feedback-proof/132-02-SUMMARY.md"
     ]},
    {"nightly-policy", "reliability", "evaluate Nightly evidence",
     [".github/workflows/nightly.yml"]},
    {"supported-toolchain", "compatibility", "verify supported toolchain matrix",
     [".tool-versions", ".github/workflows/nightly.yml"]},
    {"automation-first", "testing", "./scripts/maintainer/automation_first_contract.sh",
     ["RUNNING.md", "scripts/maintainer/automation_first_contract.sh"]},
    {"docs-accessibility", "documentation/accessibility", "mix doctor --full --raise",
     ["RUNNING.md", "scripts/maintainer/refactor_contract.sh"]},
    {"package-consumer", "packaging", "mix hex.build --unpack",
     ["mix.exs", "test/install_smoke/package_metadata_test.exs"]},
    {"workflow-topology", "CI/CD", "validate CI workflow topology",
     [".github/workflows/ci.yml", ".github/workflows/nightly.yml"]},
    {"release-authority", "release engineering", "validate exact-SHA release coupling",
     [".release-please-manifest.json", ".github/workflows/release.yml", "mix.exs"]},
    {"repository-hygiene", "repository hygiene", "./scripts/maintainer/repo_hygiene_check.sh",
     ["scripts/maintainer/repo_hygiene_check.sh"]}
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

  test "EVID-01: unchanged inputs produce byte-stable canonical receipts" do
    fixture = census_fixture!()
    assert {_output, 0} = run_collector(fixture)
    first = File.read!(fixture.receipt)

    assert {_output, 0} = run_collector(fixture)
    assert File.read!(fixture.receipt) == first
    assert String.ends_with?(first, "\n")
  end

  test "EVID-01: foreign SHA and dirty diagnostic receipts cannot become authoritative" do
    fixture = census_fixture!()
    assert {_output, 0} = run_collector(fixture)

    mutate_json!(fixture.receipt, &Map.put(&1, "source_sha", String.duplicate("0", 40)))
    assert_invalid(fixture, "receipt source SHA does not match repository HEAD")

    File.write!(Path.join(fixture.root, "mix.exs"), "dirty\n")
    assert {output, status} = run_collector(fixture)
    assert status != 0
    assert output =~ "authoritative census requires a clean worktree"

    assert {output, 0} = run_collector(fixture, ["--allow-dirty-diagnostic"])
    assert output =~ "non-authoritative diagnostic"
    assert_invalid(fixture, "diagnostic dirty receipt is not authoritative")
  end

  test "EVID-01: taxonomy and observation assignment mutations fail closed" do
    fixture = census_fixture!()
    assert {_output, 0} = run_collector(fixture)

    mutate_json!(fixture.ledger, fn ledger ->
      Map.update!(ledger, "taxonomy", &tl/1)
    end)

    assert_invalid(fixture, "taxonomy must contain exactly the twelve locked dimensions")

    fixture = census_fixture!()
    assert {_output, 0} = run_collector(fixture)

    mutate_ledger_and_recollect!(fixture, fn ledger ->
      update_in(ledger, ["detectors", Access.at(0), "observations"], fn [observation] ->
        [observation, observation]
      end)
    end)

    assert_invalid(fixture, "normalized observations contain duplicates")

    fixture = census_fixture!()
    assert {_output, 0} = run_collector(fixture)

    mutate_ledger_and_recollect!(fixture, fn ledger ->
      update_in(ledger, ["detectors", Access.at(0), "observations"], fn observations ->
        observations ++
          [
            %{
              "id" => "obs-unassigned",
              "kind" => "test-suite",
              "location" => "test/other",
              "status" => "pass",
              "attributes" => %{}
            }
          ]
      end)
    end)

    assert_invalid(fixture, "every observation must be assigned to exactly one candidate")
  end

  test "EVID-01: candidate identity and disposition mutations fail closed" do
    fixture = census_fixture!()
    assert {_output, 0} = run_collector(fixture)

    mutate_ledger_and_recollect!(fixture, fn ledger ->
      Map.update!(ledger, "candidates", fn [candidate] -> [candidate, candidate] end)
    end)

    assert_invalid(fixture, "candidate IDs must be unique")

    for {mutation, diagnostic} <- [
          {&put_in(&1, ["candidates", Access.at(0), "disposition"], "ignore"),
           "candidate disposition record is incomplete"},
          {fn ledger ->
             ledger
             |> put_in(["candidates", Access.at(0), "disposition"], "retain")
             |> put_in(["candidates", Access.at(0), "evidence"], [])
           end, "candidate disposition record is incomplete"},
          {fn ledger ->
             ledger
             |> put_in(["candidates", Access.at(0), "disposition"], "defer")
             |> put_in(["candidates", Access.at(0), "trigger"], nil)
           end, "candidate disposition record is incomplete"}
        ] do
      fixture = census_fixture!()
      assert {_output, 0} = run_collector(fixture)
      mutate_ledger_and_recollect!(fixture, mutation)
      assert_invalid(fixture, diagnostic)
    end
  end

  test "EVID-01: complete registry covers every locked dimension with repository-owned inputs" do
    fixture = complete_census_fixture!()

    assert {_output, 0} = run_collector(fixture)
    assert {_output, 0} = run_validator(fixture)

    mutate_json!(fixture.ledger, fn ledger ->
      put_in(ledger, ["detectors", Access.at(0), "command"], "opaque replacement")
    end)

    assert {_output, 0} = run_collector(fixture)
    assert_invalid(fixture, "detector registry differs from repository-owned authority")
  end

  test "EVID-01: candidate set changes and unexplained observation transitions fail closed" do
    for mutation <- [
          fn ledger -> update_in(ledger, ["candidates"], &tl/1) end,
          fn ledger ->
            update_in(ledger, ["candidates", Access.at(0), "id"], &(&1 <> "-replacement"))
          end
        ] do
      fixture = complete_census_fixture!()
      assert {_output, 0} = run_collector(fixture)
      mutate_ledger_and_recollect!(fixture, mutation)
      assert_invalid(fixture, "candidate set differs from the reviewed baseline")
    end

    fixture = complete_census_fixture!()
    assert {_output, 0} = run_collector(fixture)

    mutate_ledger_and_recollect!(fixture, fn ledger ->
      replace_candidate_observation(ledger, "candidate-automation-first", "obs-testing-after")
    end)

    assert_invalid(fixture, "changed candidate requires one Phase 133 transition")
  end

  test "EVID-01: an explicit stable-ID transition reconciles changed observations" do
    fixture = complete_census_fixture!()
    ledger = fixture.ledger |> File.read!() |> Jason.decode!()
    candidate_id = "candidate-automation-first"
    before_digest = baseline_digest(ledger, candidate_id)
    changed = replace_candidate_observation(ledger, candidate_id, "obs-testing-after")
    after_digest = observations_digest(["obs-testing-after"])

    transitioned =
      Map.put(changed, "phase_133_transitions", [
        %{
          "candidate_id" => candidate_id,
          "before_observations_digest" => before_digest,
          "after_observations_digest" => after_digest,
          "reason" => "Phase 133 replaced the testing evidence producer",
          "implementing_plan" => "133-06"
        }
      ])

    File.write!(fixture.ledger, Jason.encode!(transitioned))
    assert {_output, 0} = run_collector(fixture)
    assert {_output, 0} = run_validator(fixture)

    mutate_json!(fixture.ledger, &Map.put(&1, "phase_133_transitions", []))
    assert {_output, 0} = run_collector(fixture)
    assert_invalid(fixture, "changed candidate requires one Phase 133 transition")
  end

  test "EVID-01: registry, candidates, and transitions serialize canonically" do
    fixture = complete_census_fixture!()
    assert {_output, 0} = run_collector(fixture)
    canonical = File.read!(fixture.receipt)

    mutate_json!(fixture.ledger, fn ledger ->
      ledger
      |> Map.update!("taxonomy", &Enum.reverse/1)
      |> Map.update!("detectors", &Enum.reverse/1)
      |> Map.update!("candidates", &Enum.reverse/1)
      |> Map.update!("phase_133_transitions", &Enum.reverse/1)
    end)

    assert {_output, 0} = run_collector(fixture)
    assert File.read!(fixture.receipt) == canonical
    assert {_output, 0} = run_validator(fixture)
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

    ledger = Map.put(ledger, "candidate_baseline", baseline_for(ledger["candidates"]))

    File.write!(ledger_path, Jason.encode!(ledger))
    on_exit(fn -> File.rm_rf(base) end)

    %{root: root, ledger: ledger_path, receipt: receipt_path, sha: sha}
  end

  defp complete_census_fixture! do
    fixture = census_fixture!()

    for {_id, _dimension, _command, inputs} <- @detector_registry,
        input <- inputs,
        input != "mix.exs" do
      path = Path.join(fixture.root, input)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, "fixture input: #{input}\n")
    end

    git!(fixture.root, ["add", "."])
    git!(fixture.root, ["commit", "--quiet", "-m", "complete detector inputs"])
    sha = git!(fixture.root, ["rev-parse", "HEAD"])

    detectors =
      Enum.map(@detector_registry, fn {id, dimension, command, inputs} ->
        %{
          "id" => id,
          "dimension" => dimension,
          "command" => command,
          "inputs" => inputs,
          "observations" => [
            %{
              "id" => "obs-#{id}",
              "kind" => "evidence-producer",
              "location" => hd(inputs),
              "status" => "pass",
              "attributes" => %{"count" => 1, "line" => 42}
            }
          ]
        }
      end)

    candidates =
      Enum.map(detectors, fn detector ->
        %{
          "id" => "candidate-#{detector["id"]}",
          "observations" => ["obs-#{detector["id"]}"],
          "disposition" => "fix",
          "rationale" => "fixture disposition for #{detector["dimension"]}",
          "evidence" => [detector["command"]],
          "trigger" => nil
        }
      end)

    ledger = %{
      "schema_version" => 1,
      "subject_sha" => sha,
      "taxonomy" =>
        Enum.map(@dimensions, fn dimension ->
          detector = Enum.find(detectors, &(&1["dimension"] == dimension))
          %{"id" => dimension, "applicable" => true, "detectors" => [detector["id"]]}
        end),
      "detectors" => detectors,
      "candidates" => candidates,
      "candidate_baseline" => baseline_for(candidates),
      "phase_133_transitions" => []
    }

    File.write!(fixture.ledger, Jason.encode!(ledger))
    %{fixture | sha: sha}
  end

  defp run_collector(fixture, extra_args \\ []) do
    run_script(@collector, [
      "--root",
      fixture.root,
      "--ledger",
      fixture.ledger,
      "--output",
      fixture.receipt,
      "--source-sha",
      fixture.sha
      | extra_args
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

  defp assert_invalid(fixture, diagnostic) do
    {output, status} = run_validator(fixture)
    assert status != 0
    assert output =~ diagnostic
  end

  defp mutate_ledger_and_recollect!(fixture, mutation) do
    mutate_json!(fixture.ledger, mutation)
    assert {_output, 0} = run_collector(fixture)
  end

  defp mutate_json!(path, mutation) do
    value = path |> File.read!() |> Jason.decode!() |> mutation.()
    File.write!(path, Jason.encode!(value))
  end

  defp replace_candidate_observation(ledger, candidate_id, replacement_id) do
    previous_id =
      ledger["candidates"]
      |> Enum.find(&(&1["id"] == candidate_id))
      |> Map.fetch!("observations")
      |> hd()

    ledger
    |> update_in(["candidates"], fn candidates ->
      Enum.map(candidates, fn candidate ->
        if candidate["id"] == candidate_id,
          do: Map.put(candidate, "observations", [replacement_id]),
          else: candidate
      end)
    end)
    |> update_in(["detectors"], fn detectors ->
      Enum.map(detectors, fn detector ->
        Map.update!(detector, "observations", fn observations ->
          Enum.map(observations, fn observation ->
            if observation["id"] == previous_id,
              do: Map.put(observation, "id", replacement_id),
              else: observation
          end)
        end)
      end)
    end)
  end

  defp baseline_for(candidates) do
    Enum.map(candidates, fn candidate ->
      %{
        "id" => candidate["id"],
        "observations_digest" => observations_digest(candidate["observations"])
      }
    end)
  end

  defp baseline_digest(ledger, candidate_id) do
    ledger["candidate_baseline"]
    |> Enum.find(&(&1["id"] == candidate_id))
    |> Map.fetch!("observations_digest")
  end

  defp observations_digest(observations) do
    observations
    |> Enum.sort()
    |> Jason.encode!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp git!(root, args) do
    {output, 0} = System.cmd("git", args, cd: root, stderr_to_stdout: true)
    String.trim(output)
  end

  defp sha256(contents), do: :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)
end
