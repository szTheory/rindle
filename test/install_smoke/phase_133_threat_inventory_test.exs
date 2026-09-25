defmodule Rindle.InstallSmoke.Phase133ThreatInventoryTest do
  use ExUnit.Case, async: false

  @script Path.expand("../../scripts/maintainer/validate_phase_133_threat_inventory.exs", __DIR__)
  @inventory Path.expand(
               "../../.planning/phases/133-evidence-charter-and-live-truth/133-SECURITY-INVENTORY.json",
               __DIR__
             )
  @root Path.expand("../..", __DIR__)

  setup do
    tmp =
      Path.join(
        System.tmp_dir!(),
        "phase133-threat-inventory-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(tmp)
    path = Path.join(tmp, "inventory.json")
    data = @inventory |> File.read!() |> Jason.decode!()
    on_exit(fn -> File.rm_rf!(tmp) end)
    %{path: path, data: data}
  end

  test "accepts the complete recovered source inventory", %{path: path, data: data} do
    assert {output, 0} = invoke(write(path, data))
    assert output =~ "15 recovered findings"
  end

  test "rejects missing, duplicate, foreign, and source-mismatched identities", %{
    path: path,
    data: data
  } do
    first = hd(data["items"])

    mutations = [
      put_in(data, ["items"], tl(data["items"])),
      put_in(data, ["items", Access.at(1), "id"], first["id"]),
      put_in(data, ["items", Access.at(0), "id"], "T-133-OTHER-01"),
      put_in(data, ["items", Access.at(0), "source", "line"], 999),
      put_in(data, ["items", Access.at(0), "source", "commit"], String.duplicate("a", 40)),
      put_in(data, ["items", Access.at(0), "source", "path"], "README.md")
    ]

    for mutation <- mutations do
      assert_rejected(path, mutation)
    end
  end

  test "rejects unsupported dispositions, missing evidence, and changed audit mode", %{
    path: path,
    data: data
  } do
    mutations = [
      put_in(data, ["items", Access.at(0), "current_disposition"], "closed"),
      put_in(data, ["items", Access.at(0), "evidence", "reason"], ""),
      put_in(data, ["items", Access.at(0), "evidence", "auditor_report_commit"], nil),
      put_in(data, ["mode"], "re-audit"),
      put_in(data, ["provenance", "raw_record_sha256"], String.duplicate("0", 64)),
      put_in(data, ["unresolved_high_ids"], ["T-133-53"])
    ]

    for mutation <- mutations do
      assert_rejected(path, mutation)
    end
  end

  defp assert_rejected(path, data) do
    assert {output, status} = invoke(write(path, data))
    assert status != 0
    assert output =~ "validate-phase-133-threat-inventory"
  end

  defp write(path, data) do
    File.write!(path, Jason.encode!(data, pretty: true))
    path
  end

  defp invoke(path) do
    System.cmd(
      "mix",
      [
        "run",
        "--no-start",
        "--no-deps-check",
        "--no-compile",
        @script,
        "--root",
        @root,
        "--inventory",
        path
      ],
      env: [{"ASDF_ERLANG_VERSION", "27.3.4.15"}],
      stderr_to_stdout: true
    )
  end
end
