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
