defmodule Rindle.ContributorBootstrapTest do
  use ExUnit.Case, async: false

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

  @tag :tmp_dir
  test "full bootstrap follows the focused proof with the documented full PR command", %{
    tmp_dir: dir
  } do
    fixture = fixture!(dir)
    {output, status} = run_probe(fixture, ["--full"])
    assert status == 0, output
    receipt = fixture.receipt |> File.read!() |> Jason.decode!()
    assert receipt["full"] == true
    assert List.last(receipt["commands"])["argv"] == ["mix", "ci"]

    assert File.read!(fixture.log) |> String.split("\n", trim: true) ==
             Enum.map(@commands ++ [["mix", "ci"]], &Enum.join(&1, " "))
  end

  @tag :tmp_dir
  test "wrong runtime and dirty source cannot reach dependency installation", %{tmp_dir: dir} do
    for {name, binary, body, reason} <- [
          {"elixir", "elixir", "elixir-1.18.4/otp-27.3.4.15", "unsupported_elixir_otp"},
          {"otp", "elixir", "elixir-1.17.3/otp-27.2", "unsupported_elixir_otp"},
          {"node", "node", "v22.14.0", "unsupported_node"}
        ] do
      subdir = Path.join(dir, name)
      fixture = fixture!(subdir)
      File.write!(Path.join(fixture.bin, binary), "#!/usr/bin/env bash\necho '#{body}'\n")
      assert {_, 1} = run_probe(fixture)
      assert Jason.decode!(File.read!(fixture.receipt))["reason"] == reason
      refute File.exists?(fixture.log)
    end

    fixture = fixture!(Path.join(dir, "dirty"))
    File.write!(Path.join(fixture.source, "untracked.txt"), "dirty source")
    assert {_, 1} = run_probe(fixture)
    assert Jason.decode!(File.read!(fixture.receipt))["reason"] == "source_checkout_not_clean"
    refute File.exists?(fixture.log)
  end

  @tag :tmp_dir
  test "failed commands stop the clean path and an existing receipt never changes", %{
    tmp_dir: dir
  } do
    fixture = fixture!(dir)

    File.write!(Path.join(fixture.bin, "mix"), """
    #!/usr/bin/env bash
    echo "mix $*" >> "$BOOTSTRAP_CALL_LOG"
    if [[ "$1" == deps.get ]]; then exit 23; fi
    echo '1 test, 0 failures'
    """)

    assert {_, 1} = run_probe(fixture)
    before = File.read!(fixture.receipt)
    receipt = Jason.decode!(before)
    assert receipt["outcome"] == "open"
    assert List.last(receipt["commands"])["exit_status"] == 23
    assert length(receipt["commands"]) == 3
    assert {_, 64} = run_probe(fixture)
    assert File.read!(fixture.receipt) == before
    assert File.read!(fixture.log) |> String.split("\n", trim: true) |> length() == 3
  end

  @tag :tmp_dir
  test "deadline kills a slow command and removes the disposable checkout", %{tmp_dir: dir} do
    fixture = fixture!(dir)
    checkout_log = Path.join(dir, "checkout-path")

    File.write!(Path.join(fixture.bin, "mix"), """
    #!/usr/bin/env bash
    pwd > '#{checkout_log}'
    sleep 6
    """)

    assert {_, 1} = run_probe(fixture, ["--timeout-seconds", "3"])
    receipt = Jason.decode!(File.read!(fixture.receipt))
    assert receipt["reason"] == "command_timeout"
    assert receipt["outcome"] == "blocked"
    checkout = File.read!(checkout_log) |> String.trim()
    refute File.exists?(checkout)
  end

  test "documented lanes have executable owners and Node matches the actual CI setup" do
    {output, 0} = System.cmd("bash", [@script, "--validate"], cd: @root)
    manifest = Jason.decode!(output)
    assert manifest["commands"] == @commands

    assert manifest["runtime"] == %{
             "elixir" => "1.17.3",
             "otp" => "27.3.4.15",
             "node_major" => 20
           }

    ci = YamlElixir.read_from_file!(Path.join(@root, ".github/workflows/ci.yml"))

    versions =
      ci["jobs"]
      |> Map.values()
      |> Enum.flat_map(&Map.get(&1, "steps", []))
      |> Enum.filter(&String.starts_with?(Map.get(&1, "uses", ""), "actions/setup-node@"))
      |> Enum.map(&get_in(&1, ["with", "node-version"]))
      |> Enum.uniq()

    assert versions == ["20"]
    docs = File.read!(Path.join(@root, "CONTRIBUTING.md"))

    rows =
      Regex.scan(
        ~r/^\| ([^|]+) \| (focused|nightly|measurement|full|release) \| `([^`]+)` \|$/m,
        docs
      )

    assert length(rows) == 10

    for [_, _surface, lane, command] <- rows do
      assert_command_owner!(OptionParser.split(command))
      if lane == "full", do: assert(command == "mix ci")

      if lane == "release",
        do: assert(command == "bash scripts/maintainer/repo_hygiene_check.sh --ci")
    end

    assert docs =~ "mix coveralls.multiple --type local --type json"
  end

  defp assert_command_owner!(["mix", task | args]) do
    {_, 0} = System.cmd("mix", ["help", task], cd: @root, stderr_to_stdout: true)

    for path <- args,
        String.ends_with?(path, ".exs"),
        do: assert(File.regular?(Path.join(@root, path)))
  end

  defp assert_command_owner!(["bash", path | args]) do
    assert File.regular?(Path.join(@root, path))
    assert {_, 0} = System.cmd("bash", ["-n", path], cd: @root, stderr_to_stdout: true)

    if args == ["--validate"],
      do: assert({_, 0} = System.cmd("bash", [path | args], cd: @root, stderr_to_stdout: true))
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
