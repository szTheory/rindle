defmodule Rindle.AsyncIsolationEvidenceRunnerTest do
  use ExUnit.Case, async: true

  @moduletag async_safety_allow: [:file_mutation]

  @repo_root Path.expand("../..", __DIR__)
  @runner Path.join(@repo_root, "scripts/maintainer/async_isolation_evidence.sh")
  @phase_dir Path.join(@repo_root, ".planning/phases/125-behavioral-test-support")

  test "validation exposes the fixed matrix, one coverage argv, and report schema without running Mix" do
    {output, 0} =
      System.cmd("bash", [@runner, "--validate"], cd: @repo_root, stderr_to_stdout: true)

    [matrix, argv, schema] = String.split(output, "\n", trim: true)

    assert matrix =~ ~s("kind":"matrix")
    assert seeds(matrix) |> length() == 25
    assert seeds(matrix) == Enum.uniq(seeds(matrix))

    assert argv ==
             ~s({"kind":"argv","argv":["mix","coveralls.multiple","--type","local","--type","json","--seed","SEED","--slowest","20"]})

    assert schema =~ ~s("kind":"report_schema")
    assert schema =~ ~s("failure_location")
  end

  test "runner invokes coverage once per seed in order and writes 25 passing evidence records" do
    report = report_path("success")
    log = temporary_path("success.log")

    {_output, 0} = run_runner(report, log)

    invocations = log |> File.read!() |> String.split("\n", trim: true)
    assert length(invocations) == 25
    assert Enum.map(invocations, &seed_from_invocation/1) == validation_seeds()

    records = report |> File.read!() |> String.split("\n", trim: true)
    assert length(records) == 26
    assert Enum.all?(Enum.drop(records, 1), &String.contains?(&1, ~s("exit_status":0)))
    assert Enum.all?(Enum.drop(records, 1), &String.contains?(&1, ~s("failure_location":null)))
  end

  test "runner stops at the first failed seed, propagates its status, and redacts fake Mix output" do
    [first_seed, failing_seed | _rest] = validation_seeds()
    report = report_path("failure")
    log = temporary_path("failure.log")

    {_output, status} = run_runner(report, log, fail_seed: failing_seed, fail_status: 23)

    assert status == 23

    assert log
           |> File.read!()
           |> String.split("\n", trim: true)
           |> Enum.map(&seed_from_invocation/1) ==
             [first_seed, failing_seed]

    report = File.read!(report)
    assert report =~ ~s("exit_status":23)
    assert report =~ ~s("failure_location":"RuntimeError:private-config.ex:42")
    refute report =~ "super-secret"
    refute report =~ "/tmp/secret-settings"
  end

  defp validation_seeds do
    {output, 0} =
      System.cmd("bash", [@runner, "--validate"], cd: @repo_root, stderr_to_stdout: true)

    [matrix | _rest] = String.split(output, "\n", trim: true)
    seeds(matrix)
  end

  defp run_runner(report, log, options \\ []) do
    shim_dir = temporary_path("mix-shim")
    File.mkdir_p!(shim_dir)
    on_exit(fn -> File.rm_rf!(shim_dir) end)

    shim = Path.join(shim_dir, "mix")

    File.write!(shim, """
    #!/usr/bin/env bash
    set -euo pipefail
    printf '%s\\n' \"$*\" >> \"$RINDLE_ASYNC_LOG\"
    seed=\"\"
    for ((index = 1; index <= $#; index++)); do
      if [ \"${!index}\" = \"--seed\" ]; then
        next=$((index + 1))
        seed=\"${!next}\"
      fi
    done
    if [ \"${RINDLE_ASYNC_FAIL_SEED:-}\" = \"$seed\" ]; then
      echo '** (RuntimeError) super-secret /tmp/secret-settings/private-config.ex:42' >&2
      exit \"${RINDLE_ASYNC_FAIL_STATUS:-1}\"
    fi
    """)

    File.chmod!(shim, 0o755)
    on_exit(fn -> File.rm_rf(report) end)
    on_exit(fn -> File.rm_rf(log) end)

    env = [
      {"PATH", shim_dir <> ":" <> System.get_env("PATH", "")},
      {"RINDLE_ASYNC_LOG", log},
      {"RINDLE_ASYNC_FAIL_SEED", to_string(Keyword.get(options, :fail_seed, ""))},
      {"RINDLE_ASYNC_FAIL_STATUS", to_string(Keyword.get(options, :fail_status, 1))}
    ]

    System.cmd("bash", [@runner, "--report", report],
      cd: @repo_root,
      env: env,
      stderr_to_stdout: true
    )
  end

  defp report_path(label) do
    Path.join(
      @phase_dir,
      "async-isolation-evidence-#{label}-#{System.unique_integer([:positive])}.jsonl"
    )
  end

  defp temporary_path(name) do
    Path.join(
      System.tmp_dir!(),
      "rindle-async-isolation-#{name}-#{System.unique_integer([:positive])}"
    )
  end

  defp seeds(matrix) do
    Regex.scan(~r/\d+/, matrix)
    |> List.flatten()
    |> Enum.map(&String.to_integer/1)
  end

  defp seed_from_invocation(invocation) do
    [seed] = Regex.run(~r/--seed (\d+)/, invocation, capture: :all_but_first)
    String.to_integer(seed)
  end
end
