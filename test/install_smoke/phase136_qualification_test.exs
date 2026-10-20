defmodule Rindle.PhaseEvidenceQualificationTest do
  use ExUnit.Case, async: true

  @root Path.expand("../..", __DIR__)
  @files ~w(scripts/maintainer/phase136_measure.sh scripts/maintainer/phase136_evidence.py scripts/maintainer/phase136_evidence_contract.json scripts/maintainer/verify_phase136_qualification.sh scripts/maintainer/async_isolation_evidence.sh scripts/maintainer/verify_async_isolation_receipt.sh scripts/maintainer/verify_contributor_bootstrap.sh CONTRIBUTING.md)

  @tag :tmp_dir
  test "qualification derives seven complete authorities from one frozen fixture subject", %{
    tmp_dir: dir
  } do
    fixture = fixture!(dir)
    assert {_, 0} = qualify(fixture, "generate")
    manifest = fixture.manifest |> File.read!() |> Jason.decode!()
    assert manifest["outcome"] == "complete"
    assert manifest["subject_sha"] == fixture.sha
    assert Enum.all?(manifest["requirements"], fn {_, value} -> value["status"] == "complete" end)
    assert {_, 0} = qualify(fixture, "verify")
  end

  defp fixture!(dir) do
    source = Path.join(dir, "repo")
    bin = Path.join(dir, "bin")
    File.mkdir_p!(bin)

    Enum.each(@files, fn path ->
      target = Path.join(source, path)
      File.mkdir_p!(Path.dirname(target))
      File.cp!(Path.join(@root, path), target)
    end)

    owner = Path.join(source, "scripts/ci/run_nightly_dialyzer.sh")
    File.mkdir_p!(Path.dirname(owner))

    File.write!(owner, """
    #!/usr/bin/env bash
    mkdir -p priv/plts
    echo 'fixture PLT' > priv/plts/dialyzer.plt
    echo "nightly-dialyzer mode=$1 action=analyze"
    echo 'done (passed successfully)'
    """)

    File.write!(Path.join(source, "scripts/ci/collect_pr_timing_receipt.sh"), """
    #!/usr/bin/env bash
    echo "$*" >> "$TIMING_AUTHORITY_CALLS"
    echo 'receipt verification passed'
    """)

    File.write!(Path.join(bin, "mix"), """
    #!/usr/bin/env bash
    if [[ "$1" == credo_quality ]]; then
      echo '[credo-quality] blocking warnings, public contract, and complexity inventory passed'
    else
      echo '1 test, 0 failures'
    fi
    """)

    File.write!(
      Path.join(bin, "elixir"),
      "#!/usr/bin/env bash\necho 'elixir-1.17.3/otp-27.3.4.15'\n"
    )

    File.write!(Path.join(bin, "node"), "#!/usr/bin/env bash\necho 'v20.18.1'\n")
    for name <- ~w(mix elixir node), do: File.chmod!(Path.join(bin, name), 0o755)
    git!(source, ["init", "--quiet"])
    git!(source, ["config", "user.name", "Qualification Fixture"])
    git!(source, ["config", "user.email", "qualification@example.test"])
    git!(source, ["add", "."])
    git!(source, ["commit", "--quiet", "-m", "frozen authorities"])
    sha = git!(source, ["rev-parse", "HEAD"]) |> String.trim()
    tree = git!(source, ["rev-parse", "HEAD^{tree}"]) |> String.trim()
    evidence = Path.join(source, ".planning/evidence")
    File.mkdir_p!(evidence)
    subject = Path.join(evidence, "subject.json")
    File.write!(subject, Jason.encode!(%{"subject_sha" => sha, "source_tree" => tree}))

    fixture = %{
      source: source,
      bin: bin,
      sha: sha,
      tree: tree,
      subject: subject,
      manifest: Path.join(evidence, "qualification.json"),
      evidence: evidence,
      timing_log: Path.join(dir, "timing-calls.log")
    }

    for mode <- ~w(dialyzer async bootstrap) do
      script = Path.join(source, "scripts/maintainer/phase136_measure.sh")

      assert {_, 0} =
               System.cmd(
                 "bash",
                 [
                   script,
                   mode,
                   "--subject-file",
                   subject,
                   "--receipt",
                   Path.join(evidence, mode <> ".json")
                 ],
                 cd: source,
                 env: environment(fixture),
                 stderr_to_stdout: true
               )
    end

    artifact =
      Jason.encode!(%{"source_files" => [%{"name" => "lib/fixture.ex", "coverage" => [1]}]})

    local = "1 test, 0 failures\n"

    coverage = %{
      "subject_sha" => sha,
      "source_tree" => tree,
      "covered" => 1,
      "relevant" => 1,
      "canonical_argv" => ["mix", "coveralls.multiple", "--type", "local", "--type", "json"],
      "local_exit" => 0,
      "artifact_sha256" => hash(artifact),
      "outcome" => "complete",
      "artifact_base64" => Base.encode64(artifact),
      "local_output_base64" => Base.encode64(local),
      "local_output_sha256" => hash(local)
    }

    File.write!(Path.join(evidence, "coverage.json"), Jason.encode!(coverage))
    runs = Enum.map(1..10, &%{"id" => &1, "duration_seconds" => 400})

    timing = %{
      "repo" => "szTheory/rindle",
      "pr" => 136,
      "sha" => sha,
      "runs" => runs,
      "median_seconds" => 400,
      "p95_seconds" => 400
    }

    File.write!(
      Path.join(evidence, "timing.md"),
      "CI_TIMING_CURRENT_SOURCE_BEGIN\n" <>
        Jason.encode!(timing) <> "\nCI_TIMING_CURRENT_SOURCE_END\n"
    )

    fixture
  end

  defp qualify(fixture, operation) do
    script = Path.join(fixture.source, "scripts/maintainer/verify_phase136_qualification.sh")

    args =
      [script, operation, "--subject-file", fixture.subject, "--manifest", fixture.manifest] ++
        Enum.flat_map(~w(coverage dialyzer async-receipt bootstrap timing), fn kind ->
          filename =
            if kind == "async-receipt",
              do: "async.json",
              else: kind <> if(kind == "timing", do: ".md", else: ".json")

          ["--" <> kind, Path.join(fixture.evidence, filename)]
        end)

    System.cmd("bash", args,
      cd: fixture.source,
      env: environment(fixture),
      stderr_to_stdout: true
    )
  end

  defp environment(fixture) do
    [
      {"PATH", fixture.bin <> ":" <> System.get_env("PATH")},
      {"TIMING_AUTHORITY_CALLS", fixture.timing_log}
    ]
  end

  defp hash(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)

  defp git!(root, args) do
    {output, 0} = System.cmd("git", args, cd: root, stderr_to_stdout: true)
    output
  end
end
