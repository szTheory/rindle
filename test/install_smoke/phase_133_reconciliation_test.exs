defmodule Rindle.InstallSmoke.Plan278TerminalTest do
  use ExUnit.Case, async: false
  @compile {:no_warn_undefined, Rindle.ValidatePhase133Reconciliation}

  @repo_root Path.expand("../..", __DIR__)
  @requirements ".planning/REQUIREMENTS.md"

  setup_all do
    System.put_env("RINDLE_PHASE_133_RECONCILIATION_LIBRARY_ONLY", "1")
    Code.require_file("scripts/maintainer/validate_phase_133_reconciliation.exs", @repo_root)
    System.delete_env("RINDLE_PHASE_133_RECONCILIATION_LIBRARY_ONLY")
    :ok
  end

  test "Plan 278 replaces only the exact stale Plan 133-37 prerequisite paragraph" do
    before = File.read!(Path.join(@repo_root, @requirements))

    assert {:ok, after_bytes} =
             Rindle.ValidatePhase133Reconciliation.plan278_requirement_paragraph(before)

    assert String.contains?(
             after_bytes,
             "Plans 133-27, 133-32, 133-36, and 133-37 remain immutable"
           )

    refute String.contains?(after_bytes, "Plan 133-37 exact-subject receipt")

    replacement =
      "The five Phase 133 requirements remain Pending until a fresh exact-subject evidence receipt and\n" <>
        "terminal reconciliation both pass. Plans 133-27, 133-32, 133-36, and 133-37 remain immutable\n" <>
        "history and provide no completion credit."

    original =
      "The five Phase 133 requirements remain pending until a fresh Plan 133-37 exact-subject receipt and\n" <>
        "the terminal automated reconciliation gates both pass. The immutable halted attempts in Plans 133-27\n" <>
        "and 133-32, a Plan 133-36 authorization stop, or a failed Plan 133-37 attempt provide history but no\n" <>
        "completion credit."

    assert String.replace(after_bytes, replacement, original) == before

    for id <- ~w(EVID-01 EVID-02 EVID-03 EVID-04 TRUTH-08) do
      [before_status] =
        Regex.run(~r/^- \[([ x])\] \*\*#{id}\*\*:/m, before, capture: :all_but_first)

      [after_status] =
        Regex.run(~r/^- \[([ x])\] \*\*#{id}\*\*:/m, after_bytes, capture: :all_but_first)

      assert after_status == before_status
    end
  end

  test "Plan 278 refuses missing or duplicated stale prerequisite paragraphs" do
    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.plan278_requirement_paragraph(
               "unrelated requirements"
             )

    original = File.read!(Path.join(@repo_root, @requirements))

    paragraph =
      "The five Phase 133 requirements remain pending until a fresh Plan 133-37 exact-subject receipt and\n" <>
        "the terminal automated reconciliation gates both pass. The immutable halted attempts in Plans 133-27\n" <>
        "and 133-32, a Plan 133-36 authorization stop, or a failed Plan 133-37 attempt provide history but no\n" <>
        "completion credit."

    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.plan278_requirement_paragraph(
               original <> "\n" <> paragraph
             )
  end

  test "a red Plan 278 terminal preflight leaves requirement bytes and terminal output untouched" do
    root =
      Path.join(System.tmp_dir!(), "phase133-plan278-red-#{System.unique_integer([:positive])}")

    File.mkdir_p!(Path.join(root, ".planning"))
    phase = Path.join(root, ".planning/phases/133-evidence-charter-and-live-truth")
    File.mkdir_p!(phase)
    File.cp!(Path.join(@repo_root, @requirements), Path.join(root, @requirements))
    original = File.read!(Path.join(root, @requirements))
    on_exit(fn -> File.rm_rf!(root) end)

    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.validate_plan278_terminal(root, root)

    assert File.read!(Path.join(root, @requirements)) == original
    refute File.exists?(Path.join(phase, "133-278-TERMINAL.json"))
  end

  test "Plan 278 requires every sealed predecessor inventory and detects later changes" do
    paths = Rindle.ValidatePhase133Reconciliation.plan278_sealed_history_paths_for_test()
    assert length(paths) == 26

    for plan <- ~w(205 217 240 243 275) do
      root =
        Path.join(
          System.tmp_dir!(),
          "phase133-plan278-sealed-missing-#{plan}-#{System.unique_integer([:positive])}"
        )

      omitted = Enum.find(paths, &String.starts_with?(Path.basename(&1), "133-#{plan}-"))
      assert is_binary(omitted)
      seed_sealed_history(root, [omitted])
      on_exit(fn -> File.rm_rf!(root) end)

      assert {:error, _} = Rindle.ValidatePhase133Reconciliation.plan278_sealed_history(root)
    end

    root =
      Path.join(
        System.tmp_dir!(),
        "phase133-plan278-sealed-complete-#{System.unique_integer([:positive])}"
      )

    originals = seed_sealed_history(root)
    on_exit(fn -> File.rm_rf!(root) end)

    assert {:ok, seal} = Rindle.ValidatePhase133Reconciliation.plan278_sealed_history(root)

    assert :ok =
             Rindle.ValidatePhase133Reconciliation.plan278_sealed_history_unchanged(root, seal)

    {relative, original} = Enum.at(originals, 0)
    File.write!(Path.join(root, relative), "changed bytes\n")

    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.plan278_sealed_history_unchanged(root, seal)

    File.write!(Path.join(root, relative), original)

    extra =
      Path.join(root, ".planning/phases/133-evidence-charter-and-live-truth/133-205-EXTRA.json")

    File.write!(extra, "unexpected entry\n")

    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.plan278_sealed_history_unchanged(root, seal)
  end

  test "Plan 278 binds a clean review verdict, source identity, and exact reviewed paths" do
    root =
      Path.join(
        System.tmp_dir!(),
        "phase133-plan278-review-binding-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(root)
    path = Path.join(root, "review.md")
    sha = String.duplicate("a", 40)
    tree = String.duplicate("b", 40)
    valid = plan278_review_report(sha, tree)
    File.write!(path, valid)
    on_exit(fn -> File.rm_rf!(root) end)

    assert :ok =
             Rindle.ValidatePhase133Reconciliation.plan278_review_binding_for_test(
               path,
               sha,
               tree
             )

    # The parsed frontmatter is the sole verdict authority. Body text, including
    # Markdown comments and contradictory prose, must not manufacture or alter it.
    body_markers =
      String.replace(
        valid,
        "**Verdict:** PASS — 0 BLOCKERs, 0 WARNINGs, 0 INFO findings.",
        "<!--\n**Verdict:** PASS\n-->\n**Verdict:** FAIL — stale body text"
      )

    File.write!(path, body_markers)

    assert :ok =
             Rindle.ValidatePhase133Reconciliation.plan278_review_binding_for_test(
               path,
               sha,
               tree
             )

    body_only = String.replace(valid, "verdict: PASS\n", "")
    File.write!(path, body_only)

    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.plan278_review_binding_for_test(
               path,
               sha,
               tree
             )

    contradictory =
      valid
      |> String.replace("verdict: PASS\n", "verdict: FAIL\n")
      |> Kernel.<>("\nverdict: PASS\nsource_commit: #{sha}\nsource_tree: #{tree}\n")

    File.write!(path, contradictory)

    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.plan278_review_binding_for_test(
               path,
               sha,
               tree
             )

    wrong_subject =
      valid
      |> String.replace(
        "source_commit: #{sha}\n",
        "source_commit: #{String.duplicate("c", 40)}\n"
      )
      |> Kernel.<>("\nsource_commit: #{sha}\nsource_tree: #{tree}\n")

    File.write!(path, wrong_subject)

    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.plan278_review_binding_for_test(
               path,
               sha,
               tree
             )

    duplicate =
      String.replace(
        valid,
        "source_tree: #{tree}\n",
        "source_tree: #{tree}\nsource_tree: #{tree}\n"
      )

    File.write!(path, duplicate)

    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.plan278_review_binding_for_test(
               path,
               sha,
               tree
             )

    wrong_scope =
      String.replace(valid, "scripts/ci/install_ffmpeg.sh", "scripts/ci/unreviewed.sh")

    File.write!(path, wrong_scope)

    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.plan278_review_binding_for_test(
               path,
               sha,
               tree
             )
  end

  test "Plan 278 crash recovery restores canonical and requirement bytes before accepting new evidence" do
    root =
      Path.join(
        System.tmp_dir!(),
        "phase133-plan278-recovery-#{System.unique_integer([:positive])}"
      )

    phase = Path.join(root, ".planning/phases/133-evidence-charter-and-live-truth")
    File.mkdir_p!(phase)
    requirements = Path.join(root, @requirements)
    canonical = Path.join(phase, "133-EVIDENCE-CENSUS.json")
    nightly = Path.join(phase, "133-NIGHTLY-EVIDENCE.json")

    originals = %{
      requirements => File.read!(Path.join(@repo_root, @requirements)),
      canonical => "prior-census\n",
      nightly => "prior-nightly\n"
    }

    Enum.each(originals, fn {path, bytes} ->
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, bytes)
    end)

    journal = Path.join(phase, "133-278-TRANSACTION.json")
    terminal_rel = ".planning/phases/133-evidence-charter-and-live-truth/133-278-TERMINAL.json"

    prior =
      Map.new(originals, fn {path, bytes} ->
        {Path.relative_to(path, root), Base.encode64(bytes)}
      end)

    File.write!(
      journal,
      Jason.encode!(%{
        "schema_version" => 1,
        "plan" => "133-278",
        "status" => "applying",
        "terminal_path" => terminal_rel,
        "prior_bytes" => prior
      })
    )

    Enum.each(originals, fn {path, _} -> File.write!(path, "partially-promoted\n") end)
    File.write!(Path.join(root, terminal_rel), "partial terminal\n")
    on_exit(fn -> File.rm_rf!(root) end)

    assert :ok = Rindle.ValidatePhase133Reconciliation.recover_plan278_transaction(root)
    Enum.each(originals, fn {path, bytes} -> assert File.read!(path) == bytes end)
    refute File.exists?(Path.join(root, terminal_rel))
    refute File.exists?(journal)
  end

  test "Plan 278 rejects traversal, malformed backups, and mismatched terminal paths without mutation" do
    for {label, mutate} <- [
          {"traversal",
           fn prior -> Map.put(prior, "../../outside", Base.encode64("overwrite")) end},
          {"invalid later backup",
           fn prior ->
             Map.put(
               prior,
               ".planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json",
               "%%%invalid"
             )
           end},
          {"terminal mismatch", fn prior -> prior end}
        ] do
      root =
        Path.join(
          System.tmp_dir!(),
          "phase133-plan278-invalid-journal-#{label}-#{System.unique_integer([:positive])}"
        )

      phase = Path.join(root, ".planning/phases/133-evidence-charter-and-live-truth")
      File.mkdir_p!(phase)
      requirements = Path.join(root, ".planning/REQUIREMENTS.md")
      census = Path.join(phase, "133-EVIDENCE-CENSUS.json")
      nightly = Path.join(phase, "133-NIGHTLY-EVIDENCE.json")

      originals = %{
        requirements => "untouched requirements\n",
        census => "untouched census\n",
        nightly => "untouched nightly\n"
      }

      Enum.each(originals, fn {path, bytes} -> File.write!(path, bytes) end)
      current = Map.new(originals, fn {path, _} -> {path, "current promoted bytes\n"} end)
      Enum.each(current, fn {path, bytes} -> File.write!(path, bytes) end)

      prior =
        Map.new(originals, fn {path, bytes} ->
          {Path.relative_to(path, root), Base.encode64(bytes)}
        end)
        |> mutate.()

      outside = root <> "-outside-terminal"
      File.write!(outside, "must remain\n")

      terminal_rel =
        if label == "terminal mismatch",
          do: Path.relative_to(outside, root),
          else: ".planning/phases/133-evidence-charter-and-live-truth/133-278-TERMINAL.json"

      journal = Path.join(phase, "133-278-TRANSACTION.json")

      journal_bytes =
        Jason.encode!(%{
          "schema_version" => 1,
          "plan" => "133-278",
          "status" => "applying",
          "terminal_path" => terminal_rel,
          "prior_bytes" => prior
        })

      File.write!(journal, journal_bytes)

      on_exit(fn ->
        File.rm_rf!(root)
        File.rm(outside)
      end)

      assert {:error, _} = Rindle.ValidatePhase133Reconciliation.recover_plan278_transaction(root)
      Enum.each(current, fn {path, bytes} -> assert File.read!(path) == bytes end)
      assert File.read!(journal) == journal_bytes
      assert File.read!(outside) == "must remain\n"

      if label == "terminal mismatch" do
        assert File.exists?(outside)
      else
        refute File.exists?(Path.join(root, terminal_rel))
      end
    end
  end

  test "Plan 278 recovery restores original bytes after interruption at every write boundary" do
    for boundary <- 1..5 do
      root =
        Path.join(
          System.tmp_dir!(),
          "phase133-plan278-boundary-#{boundary}-#{System.unique_integer([:positive])}"
        )

      phase = Path.join(root, ".planning/phases/133-evidence-charter-and-live-truth")
      File.mkdir_p!(phase)
      requirements = Path.join(root, ".planning/REQUIREMENTS.md")
      census = Path.join(phase, "133-EVIDENCE-CENSUS.json")
      nightly = Path.join(phase, "133-NIGHTLY-EVIDENCE.json")

      originals = %{
        requirements => "original requirements\n",
        census => "original census\n",
        nightly => "original nightly\n"
      }

      Enum.each(originals, fn {path, bytes} -> File.write!(path, bytes) end)
      on_exit(fn -> File.rm_rf!(root) end)

      assert {:interrupted, ^boundary} =
               Rindle.ValidatePhase133Reconciliation.plan278_interrupt_transaction_for_test(
                 root,
                 boundary
               )

      assert :ok = Rindle.ValidatePhase133Reconciliation.recover_plan278_transaction(root)
      Enum.each(originals, fn {path, bytes} -> assert File.read!(path) == bytes end)
      refute File.exists?(Path.join(phase, "133-278-TERMINAL.json"))
      refute File.exists?(Path.join(phase, "133-278-TRANSACTION.json"))
    end
  end

  test "Plan 278 rejects symlinked planning, phase, and evidence paths before recovery or fresh reads" do
    for kind <- [:planning_directory, :phase_directory, :evidence_leaf] do
      root =
        Path.join(
          System.tmp_dir!(),
          "phase133-plan278-symlink-#{kind}-#{System.unique_integer([:positive])}"
        )

      File.mkdir_p!(root)
      outside = root <> "-outside"
      File.mkdir_p!(outside)
      sentinel = Path.join(outside, "sentinel.json")
      File.write!(sentinel, "outside bytes stay unchanged\n")

      case kind do
        :planning_directory ->
          File.ln_s!(outside, Path.join(root, ".planning"))

        :phase_directory ->
          File.mkdir_p!(Path.join(root, ".planning/phases"))

          File.ln_s!(
            outside,
            Path.join(root, ".planning/phases/133-evidence-charter-and-live-truth")
          )

        :evidence_leaf ->
          phase = Path.join(root, ".planning/phases/133-evidence-charter-and-live-truth")
          File.mkdir_p!(phase)
          File.write!(Path.join(root, ".planning/REQUIREMENTS.md"), "requirements\n")
          File.ln_s!(sentinel, Path.join(phase, "133-EVIDENCE-CENSUS.json"))
      end

      on_exit(fn ->
        File.rm_rf!(root)
        File.rm_rf!(outside)
      end)

      assert {:error, _} = Rindle.ValidatePhase133Reconciliation.recover_plan278_transaction(root)

      assert {:error, _} =
               Rindle.ValidatePhase133Reconciliation.validate_plan278_terminal(root, root)

      assert File.read!(sentinel) == "outside bytes stay unchanged\n"

      refute File.exists?(
               Path.join(
                 root,
                 ".planning/phases/133-evidence-charter-and-live-truth/133-278-TRANSACTION.json"
               )
             )
    end
  end

  test "Plan 278 keeps its recovery journal when terminal removal fails" do
    root =
      Path.join(
        System.tmp_dir!(),
        "phase133-plan278-remove-failure-#{System.unique_integer([:positive])}"
      )

    phase = Path.join(root, ".planning/phases/133-evidence-charter-and-live-truth")
    File.mkdir_p!(phase)
    terminal = Path.join(phase, "133-278-TERMINAL.json")
    journal = Path.join(phase, "133-278-TRANSACTION.json")
    File.write!(terminal, "terminal\n")
    File.write!(journal, "journal\n")
    on_exit(fn -> File.rm_rf!(root) end)

    assert {:error, {:remove_failed, ^terminal, :eacces}} =
             Rindle.ValidatePhase133Reconciliation.plan278_remove_terminal_failure_for_test(
               terminal,
               journal
             )

    assert File.read!(terminal) == "terminal\n"
    assert File.read!(journal) == "journal\n"
  end

  defp seed_sealed_history(root, omitted \\ []) do
    File.mkdir_p!(root)

    Rindle.ValidatePhase133Reconciliation.plan278_sealed_history_paths_for_test()
    |> Enum.reject(&(&1 in omitted))
    |> Enum.reduce(%{}, fn relative, originals ->
      path = Path.join(root, relative)
      File.mkdir_p!(Path.dirname(path))
      bytes = "sealed fixture: #{relative}\n"
      File.write!(path, bytes)
      Map.put(originals, relative, bytes)
    end)
  end

  defp plan278_review_report(sha, tree) do
    reviewed_files = ~w(
      scripts/ci/install_ffmpeg.sh
      scripts/ci/test_verify_nightly_run.sh
      scripts/ci/verify_nightly_run.sh
      scripts/maintainer/live_residue_allowlist/automation_generators.json
      scripts/maintainer/scan_live_residue.exs
      scripts/maintainer/validate_phase_133_reconciliation.exs
      test/install_smoke/ci_cache_hygiene_test.exs
      test/install_smoke/live_residue_scan_test.exs
      test/install_smoke/phase_133_reconciliation_test.exs
    )

    assert Rindle.ValidatePhase133Reconciliation.plan278_reviewed_paths_for_test() ==
             reviewed_files

    file_lines = Enum.map_join(reviewed_files, "\n", &"  - #{&1}")

    """
    ---
    phase: 133-278
    source_commit: #{sha}
    source_tree: #{tree}
    files_reviewed: 9
    files_reviewed_list:
    #{file_lines}
    findings:
      critical: 0
      blocker: 0
      warning: 0
      info: 0
      total: 0
      necessity: 0
    status: clean
    verdict: PASS
    ---
    **Verdict:** PASS — 0 BLOCKERs, 0 WARNINGs, 0 INFO findings.
    """
    |> String.trim_leading()
  end
end
