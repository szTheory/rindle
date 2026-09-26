defmodule Rindle.InstallSmoke.Phase133ThreatInventoryTest do
  use ExUnit.Case, async: false

  Code.require_file("../../scripts/maintainer/phase_133_proof_checkout.exs", __DIR__)

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
    security_path = Path.join(tmp, "security.md")
    data = @inventory |> File.read!() |> Jason.decode!()
    binding = data["binding"]

    data =
      update_in(data["items"], fn items ->
        Enum.map(items, fn item ->
          {proof_path, command, assertion} = proof_for(item["id"])
          body = File.read!(Path.join(@root, proof_path))

          item
          |> Map.put("current_disposition", "dispositioned")
          |> put_in(["evidence", "disposition_proof"], "exact-ID executable proof recorded")
          |> put_in(
            ["evidence", "proof"],
            %{
              "subject_sha" => binding["subject_sha"],
              "census_sha256" => binding["census_sha256"],
              "path" => proof_path,
              "command" => command,
              "assertion" => assertion,
              "result" => "passed",
              "file_sha256" => :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)
            }
          )
        end)
      end)

    high_ids = ~w(T-133-32 T-133-53 T-133-74 T-133-85 T-133-91 T-133-105 T-133-39-03 T-133-42-03)

    security_rows =
      (high_ids |> Enum.map(&{&1, "high", "closed"})) ++
        (data["items"] |> Enum.map(&{&1["id"], "low", &1["current_disposition"]}))

    security_report = """
    ---
    status: verified
    subject_sha: #{binding["subject_sha"]}
    census_sha256: #{binding["census_sha256"]}
    threats_open: 0
    ---

    The historical attachment discrepancy remains unresolved: the claim is 706bd2bf5b1162907ab60a7cf910f40a5242cc203190f5578f098dd4647a9a65 while the committed blob is f004b5310be7cd432a09fbcd252d2dac6781f739a9104f19de044f8a17e5a8a7.
    The current item-level re-audit supersedes the aggregate attachment for disposition evidence.

    ## Threat Register

    ```markdown
    <!-- This unmatched delimiter is literal inside the fenced example.
    ```

    | ID | Finding | Component | Severity | Treatment | Evidence | Status |
    | --- | --- | --- | --- | --- | --- | --- |
    #{Enum.map_join(security_rows, "\n", fn {id, severity, status} -> "| #{id} | finding | component | #{severity} | mitigate | proof | #{status} |" end)}
    """

    File.write!(security_path, security_report)

    on_exit(fn -> File.rm_rf!(tmp) end)
    %{path: path, data: data, security_path: security_path}
  end

  @tag :requires_verified_security_report
  @tag timeout: 600_000
  test "accepts the complete recovered source inventory", %{
    path: path,
    data: data,
    security_path: security_path
  } do
    assert {output, 0} = invoke(write(path, data), security_path)
    assert output =~ "15 exact-ID findings have current executable disposition proofs"
  end

  test "rejects missing, duplicate, foreign, and source-mismatched identities", %{
    path: path,
    data: data,
    security_path: security_path
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
      assert_rejected(path, security_path, mutation)
    end
  end

  test "rejects unsupported dispositions, missing evidence, and changed audit mode", %{
    path: path,
    data: data,
    security_path: security_path
  } do
    mutations = [
      put_in(data, ["items", Access.at(0), "current_disposition"], "open"),
      put_in(data, ["items", Access.at(0), "evidence", "reason"], ""),
      put_in(data, ["items", Access.at(0), "evidence", "auditor_report_commit"], nil),
      put_in(
        data,
        ["items", Access.at(0), "evidence", "proof", "subject_sha"],
        String.duplicate("b", 40)
      ),
      put_in(
        data,
        ["items", Access.at(0), "evidence", "proof", "file_sha256"],
        String.duplicate("0", 64)
      ),
      put_in(data, ["mode"], "re-audit"),
      put_in(data, ["provenance", "raw_record_sha256"], String.duplicate("0", 64)),
      put_in(data, ["provenance", "observed_report_sha256"], String.duplicate("0", 64)),
      put_in(data, ["provenance", "historical_attachment_status"], "verified"),
      put_in(data, ["unresolved_high_ids"], ["T-133-53"])
    ]

    for mutation <- mutations do
      assert_rejected(path, security_path, mutation)
    end
  end

  @tag :proof_path_isolation
  test "detached proofs ignore caller source edits and project BEAMs" do
    tmp =
      Path.join(
        System.tmp_dir!(),
        "phase133-proof-isolation-#{System.unique_integer([:positive])}"
      )

    caller = Path.join(tmp, "caller")
    detached = Path.join(tmp, "detached")
    cache = Path.join(tmp, "cache")
    shared_lib = Path.join(cache, "_build/test/lib")
    File.mkdir_p!(Path.join(caller, "src"))
    File.mkdir_p!(Path.join(shared_lib, "rindle/ebin"))
    File.mkdir_p!(Path.join(shared_lib, "plug/ebin"))
    File.write!(Path.join(caller, "src/proof.txt"), "subject source")
    File.write!(Path.join(shared_lib, "rindle/ebin/caller.beam"), "caller-beam")
    File.write!(Path.join(shared_lib, "plug/ebin/dependency.beam"), "dependency-beam")

    git!(caller, ["init", "-q"])
    git!(caller, ["add", "src/proof.txt"])

    git!(caller, [
      "-c",
      "user.name=Phase 133 Test",
      "-c",
      "user.email=phase133@example.invalid",
      "commit",
      "-qm",
      "subject"
    ])

    {subject, 0} = System.cmd("git", ["rev-parse", "HEAD"], cd: caller)
    File.write!(Path.join(caller, "src/proof.txt"), "caller mutation")

    try do
      assert :ok =
               Rindle.Phase133ProofCheckout.checkout_subject!(
                 caller,
                 detached,
                 String.trim(subject)
               )

      assert File.read!(Path.join(detached, "src/proof.txt")) == "subject source"

      build_path = Rindle.Phase133ProofCheckout.prepare_build_path!(detached)
      deps_path = Rindle.Phase133ProofCheckout.prepare_deps_path!(detached)
      hex_path = Rindle.Phase133ProofCheckout.prepare_hex_path!(detached)

      for isolated_path <- [build_path, deps_path, hex_path] do
        {physical_path, 0} = System.cmd("pwd", ["-P"], cd: isolated_path)
        assert isolated_path == String.trim(physical_path)
        refute isolated_path =~ "/private/private/"
      end

      isolated_lib = Path.join(build_path, "test/lib")
      refute File.exists?(Path.join(isolated_lib, "rindle"))
      refute File.exists?(Path.join(isolated_lib, "plug"))

      File.write!(Path.join(shared_lib, "rindle/ebin/caller.beam"), "mutated caller-beam")
      refute File.exists?(Path.join(isolated_lib, "rindle/ebin/caller.beam"))
      refute File.exists?(Path.join(isolated_lib, "plug/ebin/dependency.beam"))
      assert File.read!(Path.join(detached, "src/proof.txt")) == "subject source"
    after
      File.rm_rf!(tmp)
    end
  end

  test "rejects an inventory bound to a different ledger subject or digest", %{
    path: path,
    data: data,
    security_path: security_path
  } do
    for binding <- [
          %{
            "subject_sha" => String.duplicate("a", 40),
            "census_sha256" => String.duplicate("0", 64)
          },
          %{
            "subject_sha" => "07beb46e6d438b3c41a2f2ac8dc9935a941600df",
            "census_sha256" => String.duplicate("0", 64)
          }
        ] do
      assert_rejected(path, security_path, Map.put(data, "binding", binding))
    end
  end

  test "rejects a contradictory, stale, or duplicate-row security report", %{
    path: path,
    data: data,
    security_path: security_path
  } do
    original = File.read!(security_path)

    mutations = [
      String.replace(original, "status: verified", "status: open_threats"),
      String.replace(original, data["binding"]["subject_sha"], String.duplicate("a", 40)),
      String.replace(original, data["binding"]["census_sha256"], String.duplicate("0", 64)),
      original <> "\n| T-133-53 | duplicate | component | high | mitigate | evidence | open |\n",
      String.replace(original, "| T-133-53 |", "<!--\n| T-133-53 |", global: false) <>
        "\n-->",
      String.replace(original, "| T-133-53 |", "<!--\n| T-133-53 |", global: false),
      String.replace(original, "| T-133-53 |", "```\n| T-133-53 |", global: false) <>
        "\n```",
      String.replace(original, "| T-133-53 |", "```\n| T-133-53 |", global: false),
      String.replace(original, "| T-133-53 |", "~~~\n| T-133-53 |", global: false)
    ]

    for report <- mutations do
      File.write!(security_path, report)
      assert_rejected(path, security_path, data)
    end
  end

  defp assert_rejected(path, security_path, data) do
    assert {output, status} = invoke(write(path, data), security_path)
    assert status != 0
    assert output =~ "validate-phase-133-threat-inventory"
  end

  defp git!(cwd, args) do
    {output, 0} = System.cmd("git", args, cd: cwd, stderr_to_stdout: true)
    output
  end

  defp write(path, data) do
    File.write!(path, Jason.encode!(data, pretty: true))
    path
  end

  defp invoke(path, security_path) do
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
        path,
        "--security-report",
        security_path
      ],
      env: [{"ASDF_ERLANG_VERSION", "27.3.4.15"}],
      stderr_to_stdout: true
    )
  end

  defp proof_for("T-133-71"),
    do:
      {"scripts/ci/test_verify_nightly_run.sh", "bash scripts/ci/test_verify_nightly_run.sh",
       "zero exact matches poll until timeout without a receipt"}

  defp proof_for("T-133-102"),
    do:
      {"test/install_smoke/phase_133_security_disclosure_test.exs",
       "MIX_ENV=test mix test test/install_smoke/phase_133_security_disclosure_test.exs --seed 0",
       "T-133-102: Plan 26 documentation contains no credential canary"}

  defp proof_for("T-133-34-05"),
    do:
      {"test/install_smoke/phase_133_reconciliation_test.exs",
       "MIX_ENV=test mix test test/install_smoke/phase_133_reconciliation_test.exs --only disclosure_canary --seed 0",
       "T-133-34-05: reconciliation diagnostics never echo raw planning canaries"}

  defp proof_for(id) when id in ["T-133-36-05", "T-133-41-05"],
    do:
      {"test/install_smoke/phase_133_security_disclosure_test.exs",
       "MIX_ENV=test mix test test/install_smoke/phase_133_security_disclosure_test.exs --seed 0",
       "T-133-36-05 and T-133-41-05: checkpoint records expose only safe public text"}

  defp proof_for(id)
       when id in [
              "T-133-33-SC",
              "T-133-34-SC",
              "T-133-35-SC",
              "T-133-36-SC",
              "T-133-37-SC",
              "T-133-38-SC",
              "T-133-39-SC",
              "T-133-40-SC",
              "T-133-41-SC",
              "T-133-42-SC"
            ],
       do:
         {"scripts/ci/test_phase_133_package_manager_guards.sh",
          "scripts/ci/test_phase_133_package_manager_guards.sh", id}
end
