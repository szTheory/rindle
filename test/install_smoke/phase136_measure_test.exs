defmodule Rindle.PhaseEvidenceMeasureTest do
  use ExUnit.Case, async: true

  @root Path.expand("../..", __DIR__)

  @tag :tmp_dir
  test "supported fresh and restored analysis produces a verifiable pinned receipt", %{
    tmp_dir: dir
  } do
    fixture = fixture!(dir)
    assert {_, 0} = measure(fixture, "dialyzer")
    receipt = fixture.receipt |> File.read!() |> Jason.decode!()
    assert receipt["outcome"] == "complete"
    assert receipt["subject_sha"] == fixture.sha
    assert receipt["source_tree"] == fixture.tree
    assert Enum.map(receipt["analyses"], & &1["mode"]) == ["fresh", "restored"]
    assert {_, 0} = measure(fixture, "verify-dialyzer")
  end

  defp fixture!(dir) do
    source = Path.join(dir, "repo")
    bin = Path.join(dir, "bin")
    File.mkdir_p!(bin)

    for path <- ~w(scripts/maintainer/phase136_measure.sh scripts/maintainer/phase136_evidence.py) do
      target = Path.join(source, path)
      File.mkdir_p!(Path.dirname(target))
      File.cp!(Path.join(@root, path), target)
    end

    owner = Path.join(source, "scripts/ci/run_nightly_dialyzer.sh")
    File.mkdir_p!(Path.dirname(owner))

    File.write!(owner, """
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p priv/plts
    echo 'fixture PLT' > priv/plts/dialyzer.plt
    echo "nightly-dialyzer mode=$1 action=analyze"
    echo 'done (passed successfully)'
    """)

    File.write!(Path.join(bin, "mix"), "#!/usr/bin/env bash\necho 'prepared fixture'\n")

    File.write!(
      Path.join(bin, "elixir"),
      "#!/usr/bin/env bash\necho 'elixir-1.17.3/otp-27.3.4.15'\n"
    )

    File.write!(Path.join(bin, "node"), "#!/usr/bin/env bash\necho 'v20.18.1'\n")
    for name <- ~w(mix elixir node), do: File.chmod!(Path.join(bin, name), 0o755)
    git!(source, ["init", "--quiet"])
    git!(source, ["config", "user.name", "Evidence Fixture"])
    git!(source, ["config", "user.email", "evidence@example.test"])
    git!(source, ["add", "."])
    git!(source, ["commit", "--quiet", "-m", "frozen fixture"])
    sha = git!(source, ["rev-parse", "HEAD"]) |> String.trim()
    tree = git!(source, ["rev-parse", "HEAD^{tree}"]) |> String.trim()
    evidence = Path.join(source, ".planning/evidence")
    File.mkdir_p!(evidence)
    subject = Path.join(evidence, "subject.json")
    File.write!(subject, Jason.encode!(%{"subject_sha" => sha, "source_tree" => tree}))

    %{
      source: source,
      bin: bin,
      sha: sha,
      tree: tree,
      subject: subject,
      receipt: Path.join(evidence, "dialyzer.json")
    }
  end

  defp measure(fixture, operation, extra \\ []) do
    script = Path.join(fixture.source, "scripts/maintainer/phase136_measure.sh")

    System.cmd(
      "bash",
      [script, operation, "--subject-file", fixture.subject, "--receipt", fixture.receipt] ++
        extra,
      cd: fixture.source,
      env: [{"PATH", fixture.bin <> ":" <> System.get_env("PATH")}],
      stderr_to_stdout: true
    )
  end

  defp git!(root, args) do
    {output, 0} = System.cmd("git", args, cd: root, stderr_to_stdout: true)
    output
  end
end
