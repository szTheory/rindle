defmodule Rindle.InstallSmoke.EvidenceCensusTest do
  use ExUnit.Case, async: true

  # Every mutation is confined to a per-test root suffixed with unique_integer/1;
  # no fixture path or git repository is shared between concurrent cases.
  @moduletag async_safety_allow: [:file_mutation]

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
       ".planning/milestones/v1.25-phases/132-measured-closure/132-02-SUMMARY.md"
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
  @inapplicable_dimension "performance"
  @inapplicable_reason "not exercised by the minimal tracer fixture"

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
    assert length(receipt["observations"]) == length(@detector_registry) - 1
    refute Enum.any?(receipt["observations"], &(&1["dimension"] == @inapplicable_dimension))
    assert is_binary(receipt["candidates_digest"])

    assert Enum.any?(receipt["inputs"], fn input ->
             input == %{
               "detector_id" => "default-exunit",
               "path" => "mix.exs",
               "sha256" => sha256("fixture input: mix.exs\n")
             }
           end)
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
      update_in(ledger, ["candidates"], fn [candidate | _] = candidates ->
        [candidate | candidates]
      end)
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
    assert_invalid(fixture, "detector authority differs from repository-owned registry")
  end

  test "EVID-01: mixed applicability preserves exact authority for every applicable detector" do
    fixture = census_fixture!()

    assert {_output, 0} = run_collector(fixture)
    assert {_output, 0} = run_validator(fixture)

    for {field, replacement} <- [
          {"command", "opaque replacement"},
          {"inputs", ["mix.lock"]},
          {"id", "replacement-id"},
          {"dimension", "reliability"}
        ] do
      mutated = census_fixture!()

      mutate_json!(mutated.ledger, fn ledger ->
        put_in(ledger, ["detectors", Access.at(0), field], replacement)
      end)

      assert {_output, 0} = run_collector(mutated)
      assert_invalid(mutated, "detector authority differs from repository-owned registry")
    end
  end

  test "EVID-01: inapplicability requires an allowlisted dimension and exact bounded reason" do
    fixture = census_fixture!()
    assert {_output, 0} = run_collector(fixture)

    for reason <- [nil, "", "not exercised"] do
      mutated = census_fixture!()

      mutate_json!(mutated.ledger, fn ledger ->
        update_in(ledger, ["taxonomy"], fn taxonomy ->
          Enum.map(taxonomy, fn
            %{"id" => @inapplicable_dimension} = row -> Map.put(row, "rationale", reason)
            row -> row
          end)
        end)
      end)

      assert {_output, 0} = run_collector(mutated)
      assert_invalid(mutated, "taxonomy inapplicability is not repository-authorized")
    end

    fixture = complete_census_fixture!()

    mutate_json!(fixture.ledger, fn ledger ->
      remove_dimension(ledger, "reliability", @inapplicable_reason)
    end)

    assert {_output, 0} = run_collector(fixture)
    assert_invalid(fixture, "taxonomy inapplicability is not repository-authorized")
  end

  test "EVID-01: candidate set changes and unexplained observation transitions fail closed" do
    for mutation <- [
          fn ledger -> update_in(ledger, ["candidates"], &tl/1) end,
          fn ledger ->
            new_observation = %{
              "id" => "obs-added-candidate",
              "kind" => "evidence-producer",
              "location" => "mix.exs",
              "status" => "pass",
              "attributes" => %{}
            }

            ledger
            |> update_in(["detectors", Access.at(0), "observations"], &(&1 ++ [new_observation]))
            |> update_in(["candidates"], fn candidates ->
              candidates ++
                [
                  %{
                    "id" => "candidate-added",
                    "observations" => ["obs-added-candidate"],
                    "disposition" => "fix",
                    "rationale" => "unreviewed addition",
                    "evidence" => ["mix test"],
                    "trigger" => nil
                  }
                ]
            end)
          end,
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

  test "EVID-01: zero-cardinality and imprecise count boundaries fail closed" do
    fixture = complete_census_fixture!()
    assert {_output, 0} = run_collector(fixture)

    mutate_json!(fixture.ledger, fn ledger ->
      ledger
      |> Map.put("candidates", [])
      |> Map.put("candidate_baseline", [])
      |> update_in(["detectors"], fn detectors ->
        Enum.map(detectors, &Map.put(&1, "observations", []))
      end)
    end)

    assert {_output, 0} = run_collector(fixture)
    assert_invalid(fixture, "detector record is incomplete")

    fixture = complete_census_fixture!()
    assert {_output, 0} = run_collector(fixture)

    mutate_ledger_and_recollect!(fixture, fn ledger ->
      put_in(
        ledger,
        ["detectors", Access.at(0), "observations", Access.at(0), "attributes", "count"],
        1.5
      )
    end)

    assert_invalid(fixture, "observation count attributes must be integers")
  end

  test "EVID-01: volatile evidence attributes do not replace reviewer-owned candidate identity" do
    fixture = complete_census_fixture!()
    assert {_output, 0} = run_collector(fixture)

    before_digest =
      fixture.receipt |> File.read!() |> Jason.decode!() |> Map.fetch!("candidates_digest")

    mutate_ledger_and_recollect!(fixture, fn ledger ->
      ledger
      |> put_in(
        ["detectors", Access.at(0), "observations", Access.at(0), "attributes", "count"],
        2
      )
      |> put_in(
        ["detectors", Access.at(0), "observations", Access.at(0), "attributes", "line"],
        99
      )
    end)

    receipt = fixture.receipt |> File.read!() |> Jason.decode!()
    assert receipt["candidates_digest"] == before_digest
    assert {_output, 0} = run_validator(fixture)
  end

  test "EVID-01: collector canonicalizes contained locations and rejects every escape family" do
    fixture = census_fixture!()

    mutate_json!(fixture.ledger, &put_observation_location(&1, "./nested/../mix.exs"))
    assert {_output, 0} = run_collector(fixture)

    receipt = fixture.receipt |> File.read!() |> Jason.decode!()

    assert Enum.find(receipt["observations"], &(&1["id"] == "obs-default-exunit"))["location"] ==
             "mix.exs"

    for location <- ["../outside", "nested/../../outside", "/tmp/outside"] do
      escaped = census_fixture!()
      mutate_json!(escaped.ledger, &put_observation_location(&1, location))

      assert {output, status} = run_collector(escaped)
      assert status != 0
      assert output =~ "observation location must remain within repository root"
      refute output =~ "/tmp/outside"
    end

    escaped = census_fixture!()
    external = Path.join(Path.dirname(escaped.root), "external-sentinel")
    File.write!(external, "external\n")
    File.ln_s!(external, Path.join(escaped.root, "external-link"))
    mutate_json!(escaped.ledger, &put_observation_location(&1, "external-link"))

    assert {output, status} = run_collector(escaped, ["--allow-dirty-diagnostic"])
    assert status != 0
    assert output =~ "observation location must remain within repository root"
    refute output =~ external
  end

  test "EVID-01: validator independently rejects lexical and symlink observation escapes" do
    for location <- ["../outside", "nested/../../outside", "/tmp/outside"] do
      fixture = census_fixture!()
      assert {_output, 0} = run_collector(fixture)
      mutate_ledger_and_receipt_location!(fixture, location)

      assert_invalid(fixture, "observation location must remain within repository root")
    end

    fixture = census_fixture!()
    assert {_output, 0} = run_collector(fixture)
    external = Path.join(Path.dirname(fixture.root), "external-sentinel")
    File.write!(external, "external\n")
    File.ln_s!(external, Path.join(fixture.root, "external-link"))
    mutate_ledger_and_receipt_location!(fixture, "external-link")

    {output, status} = run_validator(fixture)
    assert status != 0
    assert output =~ "observation location must remain within repository root"
    refute output =~ external
  end

  defp census_fixture!, do: registry_fixture!([@inapplicable_dimension])

  defp registry_fixture!(inapplicable_dimensions) do
    base =
      Path.join(System.tmp_dir!(), "rindle-evidence-census-#{System.unique_integer([:positive])}")

    root = Path.join(base, "subject")
    ledger_path = Path.join(base, "ledger.json")
    receipt_path = Path.join(base, "receipt.json")

    File.mkdir_p!(root)

    for {_id, _dimension, _command, inputs} <- @detector_registry,
        input <- inputs do
      path = Path.join(root, input)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, "fixture input: #{input}\n")
    end

    git!(root, ["init", "--quiet"])
    git!(root, ["config", "user.email", "fixture@example.invalid"])
    git!(root, ["config", "user.name", "Evidence Fixture"])
    git!(root, ["add", "."])
    git!(root, ["commit", "--quiet", "-m", "fixture"])
    sha = git!(root, ["rev-parse", "HEAD"])

    detectors =
      @detector_registry
      |> Enum.reject(fn {_id, dimension, _command, _inputs} ->
        dimension in inapplicable_dimensions
      end)
      |> Enum.map(fn {id, dimension, command, inputs} ->
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

          if detector do
            %{"id" => dimension, "applicable" => true, "detectors" => [detector["id"]]}
          else
            %{
              "id" => dimension,
              "applicable" => false,
              "detectors" => [],
              "rationale" => @inapplicable_reason
            }
          end
        end),
      "detectors" => detectors,
      "candidates" => candidates,
      "phase_133_transitions" => []
    }

    ledger = Map.put(ledger, "candidate_baseline", baseline_for(ledger["candidates"]))

    File.write!(ledger_path, Jason.encode!(ledger))
    on_exit(fn -> File.rm_rf(base) end)

    %{root: root, ledger: ledger_path, receipt: receipt_path, sha: sha}
  end

  defp complete_census_fixture! do
    registry_fixture!([])
  end

  defp remove_dimension(ledger, dimension, rationale) do
    detector = Enum.find(ledger["detectors"], &(&1["dimension"] == dimension))
    candidate_id = "candidate-#{detector["id"]}"

    ledger
    |> update_in(["taxonomy"], fn taxonomy ->
      Enum.map(taxonomy, fn
        %{"id" => ^dimension} = row ->
          row
          |> Map.put("applicable", false)
          |> Map.put("detectors", [])
          |> Map.put("rationale", rationale)

        row ->
          row
      end)
    end)
    |> update_in(["detectors"], &Enum.reject(&1, fn row -> row["dimension"] == dimension end))
    |> update_in(["candidates"], &Enum.reject(&1, fn row -> row["id"] == candidate_id end))
    |> update_in(
      ["candidate_baseline"],
      &Enum.reject(&1, fn row -> row["id"] == candidate_id end)
    )
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

  defp mutate_ledger_and_receipt_location!(fixture, location) do
    mutate_json!(fixture.ledger, &put_observation_location(&1, location))

    mutate_json!(fixture.receipt, fn receipt ->
      update_in(receipt, ["observations"], &put_receipt_observation_location(&1, location))
    end)
  end

  defp put_receipt_observation_location(observations, location) do
    Enum.map(observations, fn
      %{"id" => "obs-default-exunit"} = observation ->
        Map.put(observation, "location", location)

      observation ->
        observation
    end)
  end

  defp put_observation_location(ledger, location) do
    update_in(
      ledger,
      ["detectors", Access.at(0), "observations", Access.at(0)],
      &Map.put(&1, "location", location)
    )
  end

  defp replace_candidate_observation(ledger, candidate_id, replacement_id) do
    previous_id =
      ledger["candidates"]
      |> Enum.find(&(&1["id"] == candidate_id))
      |> Map.fetch!("observations")
      |> hd()

    ledger
    |> update_in(["candidates"], &replace_candidate_assignment(&1, candidate_id, replacement_id))
    |> update_in(["detectors"], &replace_detector_observation(&1, previous_id, replacement_id))
  end

  defp replace_candidate_assignment(candidates, candidate_id, replacement_id) do
    Enum.map(candidates, fn
      %{"id" => ^candidate_id} = candidate ->
        Map.put(candidate, "observations", [replacement_id])

      candidate ->
        candidate
    end)
  end

  defp replace_detector_observation(detectors, previous_id, replacement_id) do
    Enum.map(detectors, fn detector ->
      Map.update!(detector, "observations", &replace_observation(&1, previous_id, replacement_id))
    end)
  end

  defp replace_observation(observations, previous_id, replacement_id) do
    Enum.map(observations, fn
      %{"id" => ^previous_id} = observation -> Map.put(observation, "id", replacement_id)
      observation -> observation
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
