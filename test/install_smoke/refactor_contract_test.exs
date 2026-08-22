defmodule Rindle.RefactorContractTest do
  use ExUnit.Case, async: true

  @script_path Path.expand("../../scripts/maintainer/refactor_contract.sh", __DIR__)

  @required_suites [
    "test/rindle/api_surface_boundary_test.exs",
    "test/rindle/schema_prefix_contract_test.exs",
    "test/rindle/migration_fast_test.exs",
    "test/rindle/contracts/telemetry_contract_test.exs",
    "test/rindle/error_test.exs",
    "test/rindle/error_streaming_freeze_test.exs",
    "test/install_smoke/ci_lane_split_test.exs",
    "test/install_smoke/release_guard_meta_test.exs"
  ]

  setup_all do
    {:ok,
     script: File.read!(@script_path),
     meaningful_lines: meaningful_lines(File.read!(@script_path))}
  end

  test "SAFE-01 remains an executable, planning-independent preservation command", %{
    script: script
  } do
    assert executable?(@script_path), "SAFE-01 runner must remain executable"
    assert script =~ "set -euo pipefail"
    assert script =~ "BASH_SOURCE[0]"
    assert script =~ "repo_root="
    assert script =~ "cd \"${repo_root}\""
    refute script =~ ".planning/"
  end

  test "SAFE-01 keeps every behavior-preservation domain represented", %{script: script} do
    for suite <- @required_suites do
      assert script =~ suite, "SAFE-01 is missing #{suite}"
    end
  end

  test "SAFE-01 fails closed on compile-connected cycles before preservation tests", %{
    meaningful_lines: lines
  } do
    compile_line = "MIX_ENV=test mix compile --force"

    xref_line =
      "MIX_ENV=test mix xref graph --format cycles --label compile-connected --fail-above 0"

    assert Enum.find_index(lines, &(&1 == compile_line))
    assert Enum.find_index(lines, &(&1 == xref_line))

    assert Enum.find_index(lines, &(&1 == compile_line)) <
             Enum.find_index(lines, &(&1 == xref_line))

    assert Enum.find_index(lines, &(&1 == xref_line)) <
             Enum.find_index(lines, &String.contains?(&1, "mix test"))
  end

  test "SAFE-01 uses one foreground Mix test process with the telemetry contract enabled", %{
    meaningful_lines: lines
  } do
    mix_test_lines = Enum.filter(lines, &String.contains?(&1, "mix test"))

    assert mix_test_lines != [], "SAFE-01 must not have an empty test selection"
    assert length(mix_test_lines) == 1, "SAFE-01 must use one Mix test process"

    [mix_test_line] = mix_test_lines
    assert mix_test_line =~ "exec mix test"
    assert mix_test_line =~ "--include contract"
    refute mix_test_line =~ "--only contract"
  end

  test "SAFE-01 cannot background, hide, or mask test failures", %{meaningful_lines: lines} do
    refute Enum.any?(lines, &background_or_failure_mask?(&1))
  end

  defp meaningful_lines(script) do
    script
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
  end

  defp executable?(path) do
    {:ok, stat} = File.stat(path)
    Bitwise.band(stat.mode, 0o111) != 0
  end

  defp background_or_failure_mask?(line) do
    Regex.match?(~r/(^|\s)(nohup|disown|wait)(\s|$)/, line) or
      Regex.match?(~r/&\s*$/, line) or
      String.contains?(line, "|| true") or
      String.contains?(line, "; true") or
      String.contains?(line, "set +e") or
      String.contains?(line, ">/dev/null") or
      String.contains?(line, "2>&1")
  end
end
