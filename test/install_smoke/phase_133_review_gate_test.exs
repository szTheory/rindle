defmodule Rindle.InstallSmoke.Phase133ReviewGateTest do
  use ExUnit.Case, async: false

  @script Path.expand("../../scripts/maintainer/validate_phase_133_review_gate.exs", __DIR__)
  @project Path.expand("../..", __DIR__)
  @phase "133-evidence-charter-and-live-truth"
  @subject String.duplicate("a", 40)
  @high ~w(T-133-32 T-133-53 T-133-74 T-133-85 T-133-91 T-133-105 T-133-39-03 T-133-42-03)

  setup do
    tmp =
      Path.join(System.tmp_dir!(), "phase133-review-gate-#{System.unique_integer([:positive])}")

    dir = Path.join(tmp, ".planning/phases/#{@phase}")
    File.mkdir_p!(dir)
    census = Jason.encode!(%{"schema_version" => 1, "subject_sha" => @subject})
    digest = :crypto.hash(:sha256, census) |> Base.encode16(case: :lower)
    File.write!(Path.join(dir, "133-EVIDENCE-CENSUS.json"), census)
    File.write!(Path.join(dir, "133-52-SUMMARY.md"), summary(@subject, digest))
    File.write!(Path.join(dir, "133-REVIEW.md"), review(@subject, digest))

    frozen = File.read!(Path.join(@project, ".planning/phases/#{@phase}/133-VALIDATION.md"))

    File.write!(
      Path.join(dir, "133-VALIDATION.md"),
      frozen <> "\n" <> validation(@subject, digest)
    )

    File.write!(Path.join(dir, "133-SECURITY.md"), security(@subject, digest))

    inventory =
      @project
      |> Path.join(".planning/phases/#{@phase}/133-SECURITY-INVENTORY.json")
      |> File.read!()
      |> Jason.decode!()
      |> Map.put("binding", %{"subject_sha" => @subject, "census_sha256" => digest})
      |> update_in(["items"], fn items ->
        Enum.map(items, fn item ->
          item
          |> Map.put("current_disposition", "closed")
          |> put_in(
            ["evidence", "disposition_proof"],
            "independent subject-bound review and executable proof"
          )
        end)
      end)

    File.write!(Path.join(dir, "133-SECURITY-INVENTORY.json"), Jason.encode!(inventory))
    on_exit(fn -> File.rm_rf!(tmp) end)
    %{tmp: tmp, dir: dir, digest: digest}
  end

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

  test "requires exact report metadata and CR-07 closure", %{tmp: tmp, dir: dir} do
    path = Path.join(dir, "133-REVIEW.md")
    original = File.read!(path)

    for mutation <- [
          String.replace(original, @subject, String.duplicate("b", 40)),
          String.replace(original, "| CR-07 | closed |", "| CR-07 | open |"),
          String.replace(original, "blocking: 0", "blocking: 1")
        ] do
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
            "| T-133-53 | spoofing | high | closed |",
            "| T-133-53 | spoofing | high | open |"
          ),
          String.replace(
            original,
            "| T-133-71 | spoofing | low | closed |",
            "| T-133-71 | spoofing | low | open |"
          ),
          String.replace(
            original,
            "| T-133-71 | spoofing | low | closed |",
            "| T-133-OTHER-01 | spoofing | low | closed |"
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
        ~w(CR-01 CR-02 CR-03 CR-04 CR-05 CR-06 CR-07 WR-01 WR-02),
        "\n",
        &"| #{&1} | closed |"
      )

    front(subject, digest, "status: approved\nblocking: 0\n") <>
      "\n#{rows}\n\n## Sign-Off\n- [x] No blocking findings\n"
  end

  defp validation(subject, digest) do
    "## Current Independent Validation Verdict\nsubject_sha: #{subject}\ncensus_sha256: #{digest}\nnyquist_compliant: true\nproduction_path_mutation_proof: passed\n\n- [x] Production path mutation proof passed\n"
  end

  defp security(subject, digest) do
    inventory =
      @project
      |> Path.join(".planning/phases/#{@phase}/133-SECURITY-INVENTORY.json")
      |> File.read!()
      |> Jason.decode!()

    ids = @high ++ Enum.map(inventory["items"], & &1["id"])

    rows =
      Enum.map_join(ids, "\n", fn id ->
        severity = if id in @high, do: "high", else: "low"
        "| #{id} | spoofing | #{severity} | closed |"
      end)

    front(subject, digest, "status: verified\nthreats_open: 0\n") <>
      "\n#{rows}\n\n## Sign-Off\n- [x] All findings closed or explicitly dispositioned\n"
  end
end
