defmodule Rindle.PhaseEvidenceMeasureTest do
  use ExUnit.Case, async: false

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

  @tag :tmp_dir
  test "finite async and full bootstrap use the same pinned source owners", %{tmp_dir: dir} do
    fixture = fixture!(dir)

    for kind <- ["async", "bootstrap"] do
      fixture = %{fixture | receipt: Path.join(fixture.source, ".planning/evidence/#{kind}.json")}
      assert {output, 0} = measure(fixture, kind)
      assert Jason.decode!(output)["outcome"] == "complete"
      assert {_, 0} = measure(fixture, "verify-" <> kind)
    end
  end

  @tag :tmp_dir
  test "receipt kind mode output and restored PLT mutations fail closed", %{tmp_dir: dir} do
    fixture = fixture!(dir)
    assert {_, 0} = measure(fixture, "dialyzer")
    original = File.read!(fixture.receipt)
    receipt = Jason.decode!(original)

    mutations = [
      Map.put(receipt, "subject_sha", String.duplicate("0", 40)),
      Map.put(receipt, "toolchain", "elixir-1.18.4/otp-27.2"),
      Map.put(receipt, "kind", "foreign"),
      Map.put(receipt, "analyses", [hd(receipt["analyses"])]),
      put_in(receipt, ["restored_input_plt", "sha256"], String.duplicate("0", 64)),
      Map.update!(receipt, "analyses", fn [first, second] ->
        [Map.put(first, "mode", "unknown"), second]
      end)
    ]

    for invalid <- mutations do
      File.write!(fixture.receipt, Jason.encode!(invalid))
      assert {_, 1} = measure(fixture, "verify-dialyzer")
    end

    File.write!(fixture.receipt, original)
    assert {_, 1} = measure(fixture, "dialyzer")
    assert File.read!(fixture.receipt) == original
    log = receipt["analyses"] |> hd() |> Map.fetch!("artifact")
    File.write!(Path.join(fixture.receipt <> ".artifacts", log), "forged output")
    assert {_, 1} = measure(fixture, "verify-dialyzer")
  end

  @tag :tmp_dir
  test "subject accepts planning tails and rejects dirty untracked and reverted source", %{
    tmp_dir: dir
  } do
    fixture = fixture!(dir)
    assert {_, 0} = measure(fixture, "verify-subject")
    File.write!(Path.join(fixture.source, ".planning/new.md"), "new evidence")
    git!(fixture.source, ["add", ".planning/new.md"])
    git!(fixture.source, ["commit", "--quiet", "-m", "evidence-only tail"])
    assert {_, 0} = measure(fixture, "verify-subject")
    source = Path.join(fixture.source, "scripts/ci/run_nightly_dialyzer.sh")
    before = File.read!(source)
    File.write!(source, before <> "# changed source\n")
    assert {_, 1} = measure(fixture, "verify-subject")
    git!(fixture.source, ["add", source])
    git!(fixture.source, ["commit", "--quiet", "-m", "source mutation"])
    File.write!(source, before)
    git!(fixture.source, ["add", source])
    git!(fixture.source, ["commit", "--quiet", "-m", "source revert"])
    assert {_, 1} = measure(fixture, "verify-subject")
    git!(fixture.source, ["reset", "--hard", fixture.sha])
    File.write!(Path.join(fixture.source, "untracked.ex"), "untracked source")
    assert {_, 1} = measure(fixture, "verify-subject")
  end

  @tag :tmp_dir
  test "relative receipt paths work when owners execute in another checkout", %{tmp_dir: dir} do
    fixture = fixture!(dir)
    fixture = %{fixture | receipt: ".planning/evidence/relative-bootstrap.json"}
    assert {_, 0} = measure(fixture, "bootstrap")
    assert {_, 0} = measure(fixture, "verify-bootstrap")
    assert File.regular?(Path.join(fixture.source, fixture.receipt))
  end

  @tag :tmp_dir
  test "first-red analysis is preserved as open and cannot become a handwritten green", %{
    tmp_dir: dir
  } do
    fixture = fixture!(dir)
    owner = Path.join(fixture.source, "scripts/ci/run_nightly_dialyzer.sh")
    File.write!(owner, File.read!(owner) <> "exit 23\n")
    repin!(fixture)
    assert {_, 1} = measure(fixture, "dialyzer")
    data = fixture.receipt |> File.read!() |> Jason.decode!()
    assert data["outcome"] == "open"
    assert length(data["analyses"]) == 1
    assert {output, 0} = measure(fixture, "verify-dialyzer")
    assert Jason.decode!(output)["outcome"] == "open"
    File.write!(fixture.receipt, Jason.encode!(Map.put(data, "outcome", "complete")))
    assert {_, 1} = measure(fixture, "verify-dialyzer")
  end

  @tag :tmp_dir
  test "unsupported runtime creates blocked evidence without invoking an owner", %{tmp_dir: dir} do
    fixture = fixture!(dir)

    File.write!(
      Path.join(fixture.bin, "elixir"),
      "#!/usr/bin/env bash\necho 'elixir-1.18.4/otp-27.2'\n"
    )

    assert {_, 1} = measure(fixture, "dialyzer")
    receipt = fixture.receipt |> File.read!() |> Jason.decode!()
    assert receipt["outcome"] == "blocked"
    assert receipt["reason"] == "unsupported_toolchain"
    refute Map.has_key?(receipt, "analyses")
    assert {_, 1} = measure(fixture, "verify-dialyzer")
  end

  defp repin!(fixture) do
    git!(fixture.source, ["add", "scripts"])
    git!(fixture.source, ["commit", "--quiet", "-m", "fixture owner variation"])
    sha = git!(fixture.source, ["rev-parse", "HEAD"]) |> String.trim()
    tree = git!(fixture.source, ["rev-parse", "HEAD^{tree}"]) |> String.trim()
    File.write!(fixture.subject, Jason.encode!(%{"subject_sha" => sha, "source_tree" => tree}))
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

    for path <-
          ~w(scripts/maintainer/async_isolation_evidence.sh scripts/maintainer/verify_async_isolation_receipt.sh scripts/maintainer/verify_contributor_bootstrap.sh CONTRIBUTING.md) do
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

    File.write!(Path.join(bin, "mix"), "#!/usr/bin/env bash\necho '1 test, 0 failures'\n")

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
