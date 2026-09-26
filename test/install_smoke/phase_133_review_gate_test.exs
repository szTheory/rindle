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
          String.replace(original, "| CR-11 | closed |", "| CR-11 | open |"),
          String.replace(original, "| CR-12 | closed |", "| CR-12 | open |"),
          String.replace(original, "| CR-13 | closed |", "| CR-13 | open |"),
          String.replace(original, "| CR-14 | closed |", "| CR-14 | open |"),
          String.replace(original, "| CR-15 | closed |", "| CR-15 | open |"),
          String.replace(original, "| CR-16 | closed |", "| CR-16 | open |"),
          String.replace(original, "| CR-17 | closed |", "| CR-17 | open |"),
          String.replace(original, "| CR-18 | closed |", "| CR-18 | open |"),
          String.replace(original, "| CR-19 | closed |", "| CR-19 | open |"),
          String.replace(original, "| CR-23 | closed |", "| CR-23 | open |"),
          String.replace(original, "| CR-23 | closed |", ""),
          String.replace(original, "| CR-24 | closed |", "| CR-24 | open |"),
          String.replace(original, "| CR-25 | closed |", "| CR-25 | open |"),
          String.replace(original, "| CR-26 | closed |", "| CR-26 | open |"),
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

  @tag :review_dynamic_findings
  @tag :phase133_focus
  test "requires dispositions for every visible finding and validates declared counts", %{
    tmp: tmp,
    dir: dir
  } do
    path = Path.join(dir, "133-REVIEW.md")
    original = File.read!(path)

    undispositioned =
      original
      |> String.replace(
        "No narrative findings.",
        "### WR-27: Newly reported finding\n\n**Severity:** WARNING\n",
        global: false
      )
      |> String.replace("warning: 0", "warning: 1", global: false)
      |> String.replace("total: 0", "total: 1", global: false)

    File.write!(path, undispositioned)
    assert {output, status} = invoke(tmp)
    assert status != 0
    assert output =~ "WR-27"

    indented_undispositioned =
      original
      |> String.replace(
        "No narrative findings.",
        "   ### WR-27: Indented visible finding\n\n**Severity:** WARNING\n",
        global: false
      )
      |> String.replace("warning: 0", "warning: 1", global: false)
      |> String.replace("total: 0", "total: 1", global: false)

    File.write!(path, indented_undispositioned)
    assert {output, status} = invoke(tmp)
    assert status != 0
    assert output =~ "WR-27"

    for indent <- [" ", "  "] do
      indented_heading =
        original
        |> String.replace(
          "No narrative findings.",
          "#{indent}### WR-27: Indented visible finding\n\n**Severity:** WARNING\n",
          global: false
        )
        |> String.replace("warning: 0", "warning: 1", global: false)
        |> String.replace("total: 0", "total: 1", global: false)

      File.write!(path, indented_heading)
      assert {output, status} = invoke(tmp)
      assert status != 0
      assert output =~ "WR-27"
    end

    four_space_code_heading =
      String.replace(
        original,
        "No narrative findings.",
        "    ### WR-27: Code example only\n\n    **Severity:** WARNING\n",
        global: false
      )

    File.write!(path, four_space_code_heading)
    assert {output, 0} = invoke(tmp)
    assert output =~ "review gate valid"

    count_mismatch = String.replace(original, "total: 0", "total: 1", global: false)
    File.write!(path, count_mismatch)
    assert {output, status} = invoke(tmp)
    assert status != 0
    assert output =~ "finding counts"

    critical_count_mismatch =
      original
      |> String.replace("critical: 0", "critical: 1", global: false)
      |> String.replace("total: 0", "total: 1", global: false)

    File.write!(path, critical_count_mismatch)
    assert {output, status} = invoke(tmp)
    assert status != 0
    assert output =~ "finding counts"

    warning_count_mismatch =
      original
      |> String.replace("warning: 0", "warning: 1", global: false)
      |> String.replace("total: 0", "total: 1", global: false)

    File.write!(path, warning_count_mismatch)
    assert {output, status} = invoke(tmp)
    assert status != 0
    assert output =~ "finding counts"

    valid_critical_severity =
      original
      |> String.replace(
        "No narrative findings.",
        "### CR-27: Critical finding\n\n**Severity:** CRITICAL\n",
        global: false
      )
      |> String.replace("critical: 0", "critical: 1", global: false)
      |> String.replace("total: 0", "total: 1", global: false)
      |> String.replace("blocking: 0", "blocking: 1", global: false)
      |> String.replace("| CR-26 | closed |", "| CR-26 | closed |\n| CR-27 | closed |",
        global: false
      )

    File.write!(path, valid_critical_severity)
    assert {output, status} = invoke(tmp)
    assert status != 0
    assert output =~ "review has blocking findings"
    refute output =~ "severity does not match"

    mismatched_severity =
      original
      |> String.replace(
        "No narrative findings.",
        "### CR-27: Misclassified finding\n\n**Severity:** INFO\n",
        global: false
      )
      |> String.replace("info: 0", "info: 1", global: false)
      |> String.replace("total: 0", "total: 1", global: false)

    File.write!(path, mismatched_severity)
    assert {output, status} = invoke(tmp)
    assert status != 0
    assert output =~ "severity does not match"

    malformed_heading =
      original
      |> String.replace(
        "No narrative findings.",
        "### CR-27 — Critical issue\n\n**Severity:** BLOCKER\n",
        global: false
      )

    File.write!(path, malformed_heading)
    assert {output, status} = invoke(tmp)
    assert status != 0
    assert output =~ "finding heading is malformed"

    for id <- ["CR-1", "WR-1", "IN-1", "CR-27x", "WR-5x", "IN-12x"] do
      malformed_id_heading =
        String.replace(
          original,
          "No narrative findings.",
          "### #{id}: Malformed finding\n\n**Severity:** INFO\n",
          global: false
        )

      File.write!(path, malformed_id_heading)
      assert {output, status} = invoke(tmp)
      assert status != 0
      assert output =~ "finding heading is malformed"
    end

    undispositioned_info =
      original
      |> String.replace(
        "No narrative findings.",
        "### IN-01: Informational finding\n\n**Severity:** INFO\n",
        global: false
      )
      |> String.replace("info: 0", "info: 1", global: false)
      |> String.replace("total: 0", "total: 1", global: false)

    File.write!(path, undispositioned_info)
    assert {output, status} = invoke(tmp)
    assert status != 0
    assert output =~ "IN-01"

    info_count_mismatch =
      original
      |> String.replace(
        "No narrative findings.",
        "### IN-01: Informational finding\n\n**Severity:** INFO\n",
        global: false
      )

    File.write!(path, info_count_mismatch)
    assert {output, status} = invoke(tmp)
    assert status != 0
    assert output =~ "finding counts"
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

  @tag :review_tab_bypass
  @tag :phase133_focus
  test "does not treat tab-expanded indentation or tab-indented fences as visible evidence", %{
    tmp: tmp,
    dir: dir
  } do
    path = Path.join(dir, "133-REVIEW.md")
    original = File.read!(path)

    hidden_indented_closure =
      original
      |> String.replace("| CR-09 | closed |", "| CR-09 | open |")
      |> String.replace(
        "## Sign-Off",
        "   \t| CR-09 | closed |\n\n## Sign-Off"
      )

    File.write!(path, hidden_indented_closure)
    assert {output, status} = invoke(tmp)
    assert status != 0
    assert output =~ "CR-09"

    hidden_fenced_closure =
      original
      |> String.replace("| CR-09 | closed |", "| CR-09 | open |")
      |> String.replace(
        "## Sign-Off",
        "~~~text\n   \t~~~\n| CR-09 | closed |\n## Sign-Off"
      )

    File.write!(path, hidden_fenced_closure)
    assert {output, status} = invoke(tmp)
    assert status != 0
    assert output =~ "fence"
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
      String.replace(
        original,
        "| CR-09 | closed |",
        "| CR-09 | closed |\n| CR-09 | open | extra |"
      ),
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
      ),
      String.replace(original, "| CR-15 | closed |", "| CR-15 | open |")
      |> String.replace(
        "## Sign-Off",
        "    | CR-15 | closed |\n\n## Sign-Off"
      ),
      String.replace(original, "| CR-16 | closed |", "| CR-16 | open |")
      |> String.replace(
        "## Sign-Off",
        "<pre>\n| CR-16 | closed |\n</pre>\n\n## Sign-Off"
      ),
      original
      |> String.replace("- [x] No blocking findings", "- [ ] No blocking findings")
      |> String.replace(
        "## Sign-Off",
        "## Sign-Off\n<pre>\n- [x] No blocking findings\n</pre>"
      ),
      String.replace(original, "| CR-17 | closed |", "| CR-17 | open |")
      |> String.replace("## Sign-Off", "| CR-17 | closed |\n\n## Sign-Off"),
      String.replace(original, "| CR-17 | closed |", "| CR-17 | open |")
      |> String.replace(
        "## Sign-Off",
        "<textarea>\n| CR-17 | closed |\n- [x] No blocking findings\n</textarea>\n\n## Sign-Off"
      ),
      String.replace(original, "| CR-18 | closed |", "| CR-18 | open |")
      |> String.replace(
        "| Finding ID | Disposition |",
        "<?phase-audit\n| Finding ID | Disposition |"
      )
      |> String.replace("## Sign-Off", "?>\n\n## Sign-Off")
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
        ~w(CR-01 CR-02 CR-03 CR-04 CR-05 CR-06 CR-07 CR-08 CR-09 CR-10 CR-11 CR-12 CR-13 CR-14 CR-15 CR-16 CR-17 CR-18 CR-19 CR-20 CR-21 CR-22 CR-23 CR-24 CR-25 CR-26 WR-01 WR-02 WR-03),
        "\n",
        &"| #{&1} | closed |"
      )

    front(
      subject,
      digest,
      "status: approved\nblocking: 0\nfindings:\n  critical: 0\n  warning: 0\n  info: 0\n  total: 0\n"
    ) <>
      "\n## Narrative Findings (AI reviewer)\nNo narrative findings.\n\n| Finding ID | Disposition |\n| --- | --- |\n#{rows}\n\n## Sign-Off\n- [x] No blocking findings\n"
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
      "\n## Historical Attachment Provenance\n\nHistorical report SHA-256: 706bd2bf5b1162907ab60a7cf910f40a5242cc203190f5578f098dd4647a9a65\nObserved committed report SHA-256: f004b5310be7cd432a09fbcd252d2dac6781f739a9104f19de044f8a17e5a8a7\nThe historical attachment discrepancy remains unresolved. The current item-level re-audit supersedes the aggregate attachment.\n\n## Threat Register\n\n| ID | Finding | Component | Severity | Treatment | Evidence | Status |\n| --- | --- | --- | --- | --- | --- | --- |\n#{rows}\n\n## Sign-Off\n- [x] All findings closed or explicitly dispositioned\n"
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
