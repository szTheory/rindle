defmodule Rindle.CoverageFloorPolicyTest do
  use ExUnit.Case, async: false

  @root Path.expand("../..", __DIR__)
  @files ~w(scripts/maintainer/phase136_evidence.py scripts/maintainer/phase136_evidence_contract.json scripts/maintainer/verify_coverage_floor.exs)

  @tag :tmp_dir
  test "one same-run artifact reaches an exact source-bound floor verdict", %{tmp_dir: dir} do
    fixture = fixture!(dir, [1, 1, nil, 0, 1, 1, 1])
    assert {_, 0} = invoke(fixture, "--write")
    receipt = fixture.receipt |> File.read!() |> Jason.decode!()
    assert receipt["outcome"] == "complete"
    assert receipt["covered"] == 5
    assert receipt["relevant"] == 6
    assert receipt["subject_sha"] == fixture.sha
    assert {_, 0} = invoke(fixture, "--verify-only")
  end

  @tag :tmp_dir
  test "integer boundary equality passes and one covered line below fails", %{tmp_dir: dir} do
    for {covered, status} <- [{821_343, 0}, {821_342, 1}] do
      fixture =
        fixture!(
          Path.join(dir, to_string(covered)),
          List.duplicate(1, covered) ++ List.duplicate(0, 1_000_000 - covered)
        )

      assert {_, ^status} = invoke(fixture, "--write")
      assert {_, ^status} = invoke(fixture, "--verify-only")
    end
  end

  @tag :tmp_dir
  test "receipt mutations cannot forge counts source runtime local success or payload", %{
    tmp_dir: dir
  } do
    fixture = fixture!(dir, [1, 1, 1, 1, 1])
    assert {_, 0} = invoke(fixture, "--write")
    original = fixture.receipt |> File.read!() |> Jason.decode!()

    mutations = [
      Map.delete(original, "covered"),
      Map.put(original, "covered", 4),
      Map.put(original, "subject_sha", String.duplicate("0", 40)),
      Map.put(original, "source_tree", String.duplicate("0", 40)),
      Map.put(original, "toolchain", "unsupported"),
      Map.put(original, "node_version", "v26.0.0"),
      Map.put(original, "local_exit", 2),
      Map.put(original, "canonical_argv", ["mix", "test"]),
      Map.put(original, "artifact_sha256", String.duplicate("0", 64)),
      Map.put(original, "local_output_sha256", String.duplicate("0", 64))
    ]

    for mutation <- mutations do
      File.write!(fixture.receipt, Jason.encode!(mutation))
      assert {_, 1} = invoke(fixture, "--verify-only")
    end

    File.write!(fixture.receipt, Jason.encode!(original))
    assert {_, 0} = invoke(fixture, "--verify-only")
    before = File.read!(fixture.receipt)
    assert {_, 1} = invoke(fixture, "--write")
    assert File.read!(fixture.receipt) == before
  end

  @tag :tmp_dir
  test "stale malformed and failed local outputs never qualify", %{tmp_dir: dir} do
    for {label, coverage, extra} <- [
          {"stale", [1], []},
          {"negative", [-1], []},
          {"boolean", [true], []},
          {"local_red", [1], ["--local-exit", "2"]}
        ] do
      fixture = fixture!(Path.join(dir, label), coverage)

      fixture =
        if label == "stale",
          do: %{fixture | started: System.system_time(:second) + 1},
          else: fixture

      assert {_, 1} = invoke(fixture, "--write", extra)
      assert {_, 1} = invoke(fixture, "--verify-only")
    end
  end

  test "configured local analyzer rejects floored values below the exact accepted ratio" do
    options = ExCoveralls.Settings.get_coverage_options()
    assert options["floor_coverage"] == true
    assert options["minimum_coverage"] == 82.2
    assert ExCoveralls.Stats.get_coverage(1_000_000, 821_342) == 82.1
    assert ExCoveralls.Stats.get_coverage(1_000_000, 821_343) == 82.1
    assert ExCoveralls.Stats.get_coverage(1_000_000, 822_000) == 82.2

    below = [
      %{
        name: "fixture.ex",
        source: "fixture",
        coverage: List.duplicate(1, 821_342) ++ List.duplicate(0, 178_658)
      }
    ]

    assert ExUnit.CaptureIO.capture_io(fn ->
             assert catch_exit(ExCoveralls.Stats.ensure_minimum_coverage(below)) == {:shutdown, 1}
           end) =~ "Expected minimum coverage of 82.2%"

    representable = [
      %{
        name: "fixture.ex",
        source: "fixture",
        coverage: List.duplicate(1, 822) ++ List.duplicate(0, 178)
      }
    ]

    assert ExCoveralls.Stats.ensure_minimum_coverage(representable) == nil
  end

  defp fixture!(dir, coverage) do
    source = Path.join(dir, "source")

    Enum.each(@files, fn path ->
      target = Path.join(source, path)
      File.mkdir_p!(Path.dirname(target))
      File.cp!(Path.join(@root, path), target)
    end)

    git!(source, ["init", "--quiet"])
    git!(source, ["config", "user.name", "Coverage Fixture"])
    git!(source, ["config", "user.email", "coverage@example.test"])
    git!(source, ["add", "."])
    git!(source, ["commit", "--quiet", "-m", "frozen coverage validator"])
    sha = git!(source, ["rev-parse", "HEAD"]) |> String.trim()
    tree = git!(source, ["rev-parse", "HEAD^{tree}"]) |> String.trim()
    evidence = Path.join(source, ".planning/evidence")
    File.mkdir_p!(evidence)
    subject = Path.join(evidence, "subject.json")
    File.write!(subject, Jason.encode!(%{"subject_sha" => sha, "source_tree" => tree}))
    artifact = Path.join(evidence, "coverage.json")

    File.write!(
      artifact,
      Jason.encode!(%{"source_files" => [%{"name" => "fixture.ex", "coverage" => coverage}]})
    )

    local = Path.join(evidence, "suite.log")
    File.write!(local, "1 test, 0 failures\n")

    %{
      source: source,
      sha: sha,
      subject: subject,
      artifact: artifact,
      local: local,
      receipt: Path.join(evidence, "receipt.json"),
      started: System.system_time(:second) - 1
    }
  end

  defp invoke(fixture, mode, extra \\ []) do
    script = Path.join(fixture.source, "scripts/maintainer/verify_coverage_floor.exs")

    System.cmd(
      "elixir",
      [
        script,
        mode,
        "--subject-file",
        fixture.subject,
        "--receipt",
        fixture.receipt,
        "--artifact",
        fixture.artifact,
        "--local-output",
        fixture.local,
        "--local-exit",
        "0",
        "--run-started-at",
        to_string(fixture.started)
      ] ++ extra,
      cd: fixture.source,
      stderr_to_stdout: true
    )
  end

  defp git!(root, args) do
    {output, 0} = System.cmd("git", args, cd: root, stderr_to_stdout: true)
    output
  end
end
