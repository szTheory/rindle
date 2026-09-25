defmodule Rindle.InstallSmoke.Phase133ReviewGateTest do
  use ExUnit.Case, async: false

  @script Path.expand("../../scripts/maintainer/validate_phase_133_review_gate.exs", __DIR__)
  @phase "133-evidence-charter-and-live-truth"
  @subject "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  @high ~w(T-133-32 T-133-53 T-133-74 T-133-85 T-133-91 T-133-105 T-133-39-03 T-133-42-03)

  setup do
    root =
      Path.join(System.tmp_dir!(), "phase133-review-gate-#{System.unique_integer([:positive])}")

    dir = Path.join(root, ".planning/phases/#{@phase}")
    File.mkdir_p!(dir)
    census = Jason.encode!(%{"schema_version" => 1, "subject_sha" => @subject})
    digest = :crypto.hash(:sha256, census) |> Base.encode16(case: :lower)
    File.write!(Path.join(dir, "133-EVIDENCE-CENSUS.json"), census)
    File.write!(Path.join(dir, "133-47-SUMMARY.md"), bound_body(@subject, digest))
    File.write!(Path.join(dir, "133-REVIEW.md"), review(@subject, digest))
    File.write!(Path.join(dir, "133-VALIDATION.md"), validation(@subject, digest))
    File.write!(Path.join(dir, "133-SECURITY.md"), security(@subject, digest))
    on_exit(fn -> File.rm_rf!(root) end)
    %{root: root, dir: dir, digest: digest}
  end

  test "accepts exact subject-bound reports with complete dispositions", %{root: root} do
    assert {output, 0} = invoke(root)
    assert output =~ "review gate valid"
  end

  test "rejects missing, stale, or foreign subject bindings", %{
    root: root,
    dir: dir,
    digest: digest
  } do
    review_path = Path.join(dir, "133-REVIEW.md")
    original = File.read!(review_path)

    for mutation <- [
          String.replace(original, "subject_sha: #{@subject}", "subject_sha: ", global: false),
          String.replace(original, @subject, String.duplicate("b", 40)),
          String.replace(
            original,
            "census_sha256: #{digest}",
            "census_sha256: #{String.duplicate("0", 64)}"
          )
        ] do
      File.write!(review_path, mutation)
      assert {output, status} = invoke(root)
      assert status != 0
      assert output =~ "binding"
    end
  end

  test "requires true Nyquist and the production mutation proof", %{root: root, dir: dir} do
    path = Path.join(dir, "133-VALIDATION.md")
    original = File.read!(path)

    for mutation <- [
          String.replace(original, "nyquist_compliant: true", "nyquist_compliant: false"),
          String.replace(
            original,
            "production_path_mutation_proof: passed",
            "production_path_mutation_proof: missing"
          )
        ] do
      File.write!(path, mutation)
      assert {output, status} = invoke(root)
      assert status != 0
      assert output =~ "validation lacks Nyquist"
    end
  end

  test "requires report-specific independent sign-off", %{root: root, dir: dir} do
    path = Path.join(dir, "133-REVIEW.md")
    original = File.read!(path)
    File.write!(path, String.replace(original, "## Sign-Off\n- [x] No blocking findings\n", ""))

    assert {output, status} = invoke(root)
    assert status != 0
    assert output =~ "review sign-off"
  end

  test "rejects each unresolved high threat", %{root: root, dir: dir} do
    path = Path.join(dir, "133-SECURITY.md")
    original = File.read!(path)

    for id <- @high do
      mutated =
        String.replace(
          original,
          "| #{id} | spoofing | high | mitigate | closed |",
          "| #{id} | spoofing | high | mitigate | open |",
          global: false
        )

      File.write!(path, mutated)
      assert {output, status} = invoke(root)
      assert status != 0, "expected #{id} to fail closed"
      assert output =~ "security"
    end
  end

  defp invoke(root) do
    System.cmd(
      "mix",
      [
        "run",
        "--no-start",
        "--no-deps-check",
        "--no-compile",
        @script,
        "--root",
        root,
        "--subject",
        @subject
      ],
      env: [{"ASDF_ERLANG_VERSION", "27.3"}],
      stderr_to_stdout: true
    )
  end

  defp bound_body(subject, digest),
    do:
      "---\nsubject_sha: #{subject}\ncensus_sha256: #{digest}\n---\n\n**Subject SHA:** #{subject}\n**Census SHA-256:** #{digest}\n"

  defp review(subject, digest) do
    findings =
      Enum.map_join(~w(CR-01 CR-02 CR-03 CR-04 CR-05 CR-06 WR-01 WR-02), "\n", &"- #{&1}: closed")

    "---\nsubject_sha: #{subject}\ncensus_sha256: #{digest}\nstatus: approved\nblocking: 0\n---\n\n**Subject SHA:** #{subject}\n**Census SHA-256:** #{digest}\n#{findings}\n\n## Sign-Off\n- [x] No blocking findings\n"
  end

  defp validation(subject, digest),
    do:
      "---\nsubject_sha: #{subject}\ncensus_sha256: #{digest}\nnyquist_compliant: true\n---\n\n**Subject SHA:** #{subject}\n**Census SHA-256:** #{digest}\nproduction_path_mutation_proof: passed\n\n## Sign-Off\n- [x] Production path mutation proof passed\n"

  defp security(subject, digest) do
    ids =
      @high ++
        Enum.map(1..15, &"T-133-OTHER-#{String.pad_leading(Integer.to_string(&1), 2, "0")}")

    rows = Enum.map_join(ids, "\n", &"| #{&1} | spoofing | high | mitigate | closed |")

    "---\nsubject_sha: #{subject}\ncensus_sha256: #{digest}\nthreats_open: 0\nstatus: verified\n---\n\n**Subject SHA:** #{subject}\n**Census SHA-256:** #{digest}\n#{rows}\n\n## Sign-Off\n- [x] All 23 audited findings are closed or explicitly dispositioned\n"
  end
end
