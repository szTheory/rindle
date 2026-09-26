defmodule Rindle.InstallSmoke.Phase133ReviewGateTest do
  use ExUnit.Case, async: false

  @script Path.expand("../../scripts/maintainer/validate_phase_133_review_gate.exs", __DIR__)
  @project Path.expand("../..", __DIR__)
  @phase "133-evidence-charter-and-live-truth"
  @subject System.cmd("git", ["rev-parse", "HEAD"], cd: Path.expand("../..", __DIR__))
           |> elem(0)
           |> String.trim()
  @high ~w(T-133-32 T-133-53 T-133-74 T-133-85 T-133-91 T-133-105 T-133-39-03 T-133-42-03)
  @frozen_validation_bytes 148_104
  @frozen_validation_sha256 "57eb4b1f46b7852bdda6cfbc399b62eb0fe35d6283d0139c892c4a8310698a5d"

  setup do
    tmp =
      Path.join(System.tmp_dir!(), "phase133-review-gate-#{System.unique_integer([:positive])}")

    dir = Path.join(tmp, ".planning/phases/#{@phase}")
    File.mkdir_p!(dir)

    census =
      @project
      |> Path.join(".planning/phases/#{@phase}/133-EVIDENCE-CENSUS.json")
      |> File.read!()

    ledger = Jason.decode!(census)
    digest = :crypto.hash(:sha256, census) |> Base.encode16(case: :lower)
    subject = ledger["subject_sha"]
    assert subject == @subject

    File.write!(Path.join(dir, "133-EVIDENCE-CENSUS.json"), census)
    File.write!(Path.join(dir, "133-52-SUMMARY.md"), summary(subject, digest))
    File.write!(Path.join(dir, "133-REVIEW.md"), review(subject, digest))

    full_validation =
      File.read!(Path.join(@project, ".planning/phases/#{@phase}/133-VALIDATION.md"))

    frozen = binary_part(full_validation, 0, @frozen_validation_bytes)

    assert :crypto.hash(:sha256, frozen) |> Base.encode16(case: :lower) ==
             @frozen_validation_sha256

    File.write!(
      Path.join(dir, "133-VALIDATION.md"),
      frozen <> "\n" <> validation(subject, digest)
    )

    inventory =
      @project
      |> Path.join(".planning/phases/#{@phase}/133-SECURITY-INVENTORY.json")
      |> File.read!()
      |> Jason.decode!()
      |> Map.put("binding", %{"subject_sha" => subject, "census_sha256" => digest})
      |> update_in(["items"], fn items ->
        Enum.map(items, fn item ->
          {path, command, assertion} = proof_for(item["id"])
          body = File.read!(Path.join(@project, path))

          item
          |> Map.put("current_disposition", "dispositioned")
          |> put_in(
            ["evidence", "disposition_proof"],
            "independent subject-bound review and executable proof"
          )
          |> put_in(
            ["evidence", "proof"],
            %{
              "subject_sha" => subject,
              "census_sha256" => digest,
              "path" => path,
              "command" => command,
              "assertion" => assertion,
              "result" => "passed",
              "file_sha256" => :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)
            }
          )
        end)
      end)

    File.write!(Path.join(dir, "133-SECURITY-INVENTORY.json"), Jason.encode!(inventory))
    File.write!(Path.join(dir, "133-SECURITY.md"), security(subject, digest, inventory))
    on_exit(fn -> File.rm_rf!(tmp) end)
    %{tmp: tmp, dir: dir, digest: digest}
  end

  @tag :requires_verified_security_report
  @tag timeout: 600_000
  test "accepts one exact current verdict and source-backed dispositions", %{tmp: tmp} do
    assert {output, 0} = invoke(tmp)
    assert output =~ "review gate valid"
  end

  test "rejects stale, duplicate, or frozen-prefix-mutating validation verdict", %{
    tmp: tmp,
    dir: dir,
    digest: digest
  } do
    path = Path.join(dir, "133-VALIDATION.md")
    original = File.read!(path)

    mutations = [
      String.replace(original, @subject, String.duplicate("b", 40)),
      original <> "\n" <> validation(@subject, digest),
      String.replace(
        original,
        "Phase 133 — Validation Strategy",
        "Phase 133 — Altered Validation Strategy"
      )
    ]

    for mutation <- mutations do
      File.write!(path, mutation)
      assert {output, status} = invoke(tmp)
      assert status != 0
      assert output =~ "validation" or output =~ "prefix"
    end
  end

  test "requires exact report metadata and current finding closures", %{tmp: tmp, dir: dir} do
    path = Path.join(dir, "133-REVIEW.md")
    original = File.read!(path)

    for mutation <- [
          String.replace(original, @subject, String.duplicate("b", 40)),
          String.replace(original, "| CR-08 | closed |", "| CR-08 | open |"),
          String.replace(original, "| CR-09 | closed |", "| CR-09 | open |"),
          String.replace(original, "| CR-10 | closed |", "| CR-10 | open |"),
          String.replace(original, "| WR-03 | closed |", "| WR-03 | open |"),
          String.replace(original, "blocking: 0", "blocking: 1"),
          String.replace(original, "status: approved", "status: blocked"),
          String.replace(original, "status: approved\n", "status: approved\nstatus: blocked\n"),
          String.replace(original, "status: approved", "status: blocked")
          |> String.replace("## Sign-Off", "status: approved\n## Sign-Off"),
          String.replace(original, "blocking: 0", "blocking: 1")
          |> String.replace("## Sign-Off", "blocking: 0\n## Sign-Off"),
          original <> "\n---\nstatus: approved\nblocking: 0\n---\n"
        ] do
      File.write!(path, mutation)
      assert {output, status} = invoke(tmp)
      assert status != 0
      assert output =~ "review"
    end
  end

  @tag :review_fenced_disposition
  test "does not count finding closures inside fenced examples", %{tmp: tmp, dir: dir} do
    path = Path.join(dir, "133-REVIEW.md")
    original = File.read!(path)

    mutation =
      original
      |> String.replace("| CR-09 | closed |", "| CR-09 | open |")
      |> String.replace("## Sign-Off", "```text\n| CR-09 | closed |\n```\n\n## Sign-Off")

    File.write!(path, mutation)
    assert {output, status} = invoke(tmp)
    assert status != 0
    assert output =~ "CR-09"
  end

  @tag :review_exact_dispositions
  test "requires exact unique disposition rows and visible sign-off", %{tmp: tmp, dir: dir} do
    path = Path.join(dir, "133-REVIEW.md")
    original = File.read!(path)

    mutations = [
      String.replace(
        original,
        "| CR-09 | closed |",
        "| CR-09 | open; previous version was closed |"
      ),
      String.replace(original, "| CR-09 | closed |", "| CR-09 | closed |\n| CR-09 | open |"),
      original
      |> String.replace("- [x] No blocking findings", "- [ ] No blocking findings")
      |> String.replace(
        "## Sign-Off",
        "## Sign-Off\n```text\n- [x] No blocking findings\n```"
      ),
      String.replace(original, "| CR-09 | closed |", "| CR-09 | open |")
      |> String.replace(
        "## Sign-Off",
        "<!--\n| CR-09 | closed |\n-->\n\n## Sign-Off"
      ),
      original
      |> String.replace("- [x] No blocking findings", "- [ ] No blocking findings")
      |> String.replace(
        "## Sign-Off",
        "## Sign-Off\n<!--\n- [x] No blocking findings\n-->"
      )
    ]

    for mutation <- mutations do
      File.write!(path, mutation)
      assert {output, status} = invoke(tmp)
      assert status != 0
      assert output =~ "review"
    end
  end

  test "requires every named high threat and inventory finding with no synthetic IDs", %{
    tmp: tmp,
    dir: dir
  } do
    path = Path.join(dir, "133-SECURITY.md")
    original = File.read!(path)

    for mutation <- [
          String.replace(
            original,
            "| T-133-53 | spoofing | component | high | mitigate | evidence | closed |",
            "| T-133-53 | spoofing | component | high | mitigate | evidence | open |"
          ),
          String.replace(
            original,
            "| T-133-71 | spoofing | component | low | mitigate | evidence | dispositioned |",
            "| T-133-71 | spoofing | component | low | mitigate | evidence | open |"
          ),
          String.replace(
            original,
            "| T-133-71 | spoofing | component | low | mitigate | evidence | dispositioned |",
            "| T-133-OTHER-01 | spoofing | component | low | mitigate | evidence | closed |"
          )
        ] do
      File.write!(path, mutation)
      assert {output, status} = invoke(tmp)
      assert status != 0
      assert output =~ "security"
    end
  end

  test "rejects lost inventory and report inventory disagreement", %{tmp: tmp, dir: dir} do
    path = Path.join(dir, "133-SECURITY-INVENTORY.json")
    data = path |> File.read!() |> Jason.decode!()
    File.write!(path, Jason.encode!(put_in(data, ["items"], tl(data["items"]))))
    assert {output, status} = invoke(tmp)
    assert status != 0
    assert output =~ "inventory"
  end

  test "rejects stale, mismatched, or changed executable proof bindings", %{tmp: tmp, dir: dir} do
    path = Path.join(dir, "133-SECURITY-INVENTORY.json")
    original = File.read!(path) |> Jason.decode!()

    mutations = [
      put_in(
        original,
        ["items", Access.at(0), "evidence", "proof", "subject_sha"],
        String.duplicate("b", 40)
      ),
      put_in(
        original,
        ["items", Access.at(0), "evidence", "proof", "census_sha256"],
        String.duplicate("0", 64)
      ),
      put_in(
        original,
        ["items", Access.at(0), "evidence", "proof", "assertion"],
        "unverified claim"
      ),
      put_in(
        original,
        ["items", Access.at(0), "evidence", "proof", "file_sha256"],
        String.duplicate("0", 64)
      )
    ]

    for mutation <- mutations do
      File.write!(path, Jason.encode!(mutation))
      assert {output, status} = invoke(tmp)
      assert status != 0
      assert output =~ "proof"
    end
  end

  defp invoke(tmp) do
    System.cmd(
      "mix",
      [
        "run",
        "--no-start",
        "--no-deps-check",
        "--no-compile",
        @script,
        "--root",
        @project,
        "--report-root",
        tmp,
        "--subject",
        @subject
      ],
      env: [{"ASDF_ERLANG_VERSION", "27.3.4.15"}],
      stderr_to_stdout: true
    )
  end

  defp summary(subject, digest),
    do:
      "---\nsubject_sha: #{subject}\ncensus_sha256: #{digest}\n---\n\n**Subject SHA:** #{subject}\n**Census SHA-256:** #{digest}\n"

  defp front(subject, digest, more),
    do: "---\nsubject_sha: #{subject}\ncensus_sha256: #{digest}\n#{more}---\n"

  defp review(subject, digest) do
    rows =
      Enum.map_join(
        ~w(CR-01 CR-02 CR-03 CR-04 CR-05 CR-06 CR-07 CR-08 CR-09 CR-10 WR-01 WR-02 WR-03),
        "\n",
        &"| #{&1} | closed |"
      )

    front(subject, digest, "status: approved\nblocking: 0\n") <>
      "\n#{rows}\n\n## Sign-Off\n- [x] No blocking findings\n"
  end

  defp validation(subject, digest) do
    "## Current Independent Validation Verdict\nsubject_sha: #{subject}\ncensus_sha256: #{digest}\nnyquist_compliant: true\nproduction_path_mutation_proof: passed\n\n- [x] Production path mutation proof passed\n"
  end

  defp security(subject, digest, inventory) do
    items = Map.new(inventory["items"], &{&1["id"], &1["current_disposition"]})
    ids = @high ++ Map.keys(items)

    rows =
      Enum.map_join(ids, "\n", fn id ->
        severity = if id in @high, do: "high", else: "low"
        disposition = Map.get(items, id, "closed")
        "| #{id} | spoofing | component | #{severity} | mitigate | evidence | #{disposition} |"
      end)

    front(subject, digest, "status: verified\nthreats_open: 0\n") <>
      "\n## Threat Register\n\n| ID | Threat | Component | Severity | Treatment | Evidence | Status |\n| --- | --- | --- | --- | --- | --- | --- |\n#{rows}\n\n## Sign-Off\n- [x] All findings closed or explicitly dispositioned\n"
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
