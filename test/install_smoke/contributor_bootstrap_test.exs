defmodule Rindle.ContributorBootstrapTest do
  use ExUnit.Case, async: true

  @root Path.expand("../..", __DIR__)
  @script Path.join(@root, "scripts/maintainer/verify_contributor_bootstrap.sh")
  @commands [
    ["mix", "local.hex", "--force"],
    ["mix", "local.rebar", "--force"],
    ["mix", "deps.get", "--check-locked"],
    ["mix", "compile", "--warnings-as-errors"],
    ["mix", "test", "test/install_smoke/quality_signal_policy_test.exs", "--seed", "0"]
  ]

  @tag :tmp_dir
  test "clean copied source follows documented bootstrap through a focused test", %{tmp_dir: dir} do
    fixture = fixture!(dir)
    {output, status} = run_probe(fixture)
    assert status == 0, output
    receipt = fixture.receipt |> File.read!() |> Jason.decode!()
    assert receipt["outcome"] == "complete"
    assert receipt["subject_sha"] == fixture.sha

    assert File.read!(fixture.log) |> String.split("\n", trim: true) ==
             Enum.map(@commands, &Enum.join(&1, " "))

    assert receipt["clean_checkout"] == true
    assert receipt["commands"] |> Enum.all?(&(&1["exit_status"] == 0))
  end

  defp fixture!(dir) do
    source = Path.join(dir, "source")
    bin = Path.join(dir, "bin")
    File.mkdir_p!(source)
    File.mkdir_p!(bin)
    metadata = Jason.encode!(%{"elixir" => "1.17.3", "otp" => "27.3.4.15", "node_major" => 20})
    commands = Enum.map_join(@commands, "\n", &Enum.join(&1, " "))

    File.write!(Path.join(source, "CONTRIBUTING.md"), """
    <!-- rindle-bootstrap-runtime -->
    #{metadata}
    <!-- /rindle-bootstrap-runtime -->
    <!-- rindle-bootstrap-commands -->
    ```sh
    #{commands}
    ```
    <!-- /rindle-bootstrap-commands -->
    """)

    File.write!(Path.join(bin, "mix"), """
    #!/usr/bin/env bash
    echo "mix $*" >> "$BOOTSTRAP_CALL_LOG"
    echo '1 test, 0 failures'
    """)

    File.write!(
      Path.join(bin, "elixir"),
      "#!/usr/bin/env bash\necho 'elixir-1.17.3/otp-27.3.4.15'\n"
    )

    File.write!(Path.join(bin, "node"), "#!/usr/bin/env bash\necho 'v20.18.1'\n")
    for name <- ~w(mix elixir node), do: File.chmod!(Path.join(bin, name), 0o755)
    git!(source, ["init", "--quiet"])
    git!(source, ["config", "user.name", "Bootstrap Fixture"])
    git!(source, ["config", "user.email", "bootstrap@example.test"])
    git!(source, ["add", "CONTRIBUTING.md"])
    git!(source, ["commit", "--quiet", "-m", "documented fixture"])
    sha = git!(source, ["rev-parse", "HEAD"]) |> String.trim()

    %{
      source: source,
      bin: bin,
      sha: sha,
      receipt: Path.join(dir, "receipt.json"),
      log: Path.join(dir, "calls.log")
    }
  end

  defp run_probe(fixture, options \\ []) do
    System.cmd(
      "bash",
      [
        @script,
        "--run",
        "--source-root",
        fixture.source,
        "--subject-sha",
        fixture.sha,
        "--receipt",
        fixture.receipt
      ] ++ options,
      cd: @root,
      env: [
        {"PATH", fixture.bin <> ":" <> System.get_env("PATH")},
        {"BOOTSTRAP_CALL_LOG", fixture.log}
      ],
      stderr_to_stdout: true
    )
  end

  defp git!(root, args) do
    {output, 0} = System.cmd("git", args, cd: root, stderr_to_stdout: true)
    output
  end
end
