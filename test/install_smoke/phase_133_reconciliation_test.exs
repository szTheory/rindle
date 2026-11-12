defmodule Rindle.InstallSmoke.Plan278TerminalTest do
  use ExUnit.Case, async: false
  @compile {:no_warn_undefined, Rindle.ValidatePhase133Reconciliation}

  @repo_root Path.expand("../..", __DIR__)
  @requirements ".planning/REQUIREMENTS.md"
  @current_requirement_intro """
  The five Phase 133 requirements remain Pending until a fresh exact-subject evidence receipt and
  terminal reconciliation both pass. Plans 133-27, 133-32, 133-36, and 133-37 remain immutable
  history and provide no completion credit.
  """
  @historical_requirement_intro """
  The five Phase 133 requirements remain pending until a fresh Plan 133-37 exact-subject receipt and
  the terminal automated reconciliation gates both pass. The immutable halted attempts in Plans 133-27
  and 133-32, a Plan 133-36 authorization stop, or a failed Plan 133-37 attempt provide history but no
  completion credit.
  """

  setup_all do
    System.put_env("RINDLE_PHASE_133_RECONCILIATION_LIBRARY_ONLY", "1")
    Code.require_file("scripts/maintainer/validate_phase_133_reconciliation.exs", @repo_root)
    System.delete_env("RINDLE_PHASE_133_RECONCILIATION_LIBRARY_ONLY")
    :ok
  end

  test "Plan 278 replaces only the exact stale Plan 133-37 prerequisite paragraph" do
    before = preterminal_requirements()

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

    original = preterminal_requirements()

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

  defp preterminal_requirements do
    @repo_root
    |> Path.join(@requirements)
    |> File.read!()
    |> String.replace(@current_requirement_intro, @historical_requirement_intro, global: false)
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

    review_digest =
      :crypto.hash(:sha256, valid)
      |> Base.encode16(case: :lower)

    assert :ok =
             Rindle.ValidatePhase133Reconciliation.plan278_review_binding_digest_for_test(
               path,
               sha,
               tree,
               review_digest
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
             Rindle.ValidatePhase133Reconciliation.plan278_review_binding_digest_for_test(
               path,
               sha,
               tree,
               review_digest
             )

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

  test "Plan 278 candidate census ledger must be canonical except for the exact subject SHA" do
    prior_sha = String.duplicate("a", 40)
    current_sha = String.duplicate("b", 40)

    canonical = %{
      "schema_version" => 1,
      "subject_sha" => prior_sha,
      "detectors" => [%{"id" => "detector-a", "status" => "pass"}]
    }

    candidate = Map.put(canonical, "subject_sha", current_sha)

    assert :ok =
             Rindle.ValidatePhase133Reconciliation.plan278_census_ledger_binding_for_test(
               canonical,
               candidate,
               current_sha
             )

    forged_content =
      Map.put(candidate, "detectors", [%{"id" => "detector-a", "status" => "forged"}])

    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.plan278_census_ledger_binding_for_test(
               canonical,
               forged_content,
               current_sha
             )

    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.plan278_census_ledger_binding_for_test(
               canonical,
               Map.put(candidate, "unexpected", true),
               current_sha
             )

    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.plan278_census_ledger_binding_for_test(
               canonical,
               Map.put(candidate, "subject_sha", prior_sha),
               current_sha
             )
  end

  test "Plan 278 rechecks the candidate ledger against the transaction snapshot before promotion" do
    prior_sha = String.duplicate("a", 40)
    current_sha = String.duplicate("b", 40)

    canonical = %{
      "schema_version" => 1,
      "subject_sha" => prior_sha,
      "detectors" => [%{"id" => "detector-a", "status" => "pass"}]
    }

    candidate = Map.put(canonical, "subject_sha", current_sha)
    candidate_bytes = Jason.encode!(candidate)

    path =
      Path.join(
        System.tmp_dir!(),
        "phase133-plan278-ledger-#{System.unique_integer([:positive])}.json"
      )

    File.write!(path, candidate_bytes)

    on_exit(fn -> File.rm(path) end)

    candidate_digest =
      :crypto.hash(:sha256, candidate_bytes)
      |> Base.encode16(case: :lower)

    assert :ok =
             Rindle.ValidatePhase133Reconciliation.plan278_census_ledger_binding_files_for_test(
               Jason.encode!(canonical),
               path,
               current_sha,
               candidate_digest
             )

    unrelated_canonical =
      Map.put(canonical, "detectors", [%{"id" => "detector-a", "status" => "forged"}])

    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.plan278_census_ledger_binding_files_for_test(
               Jason.encode!(unrelated_canonical),
               path,
               current_sha,
               candidate_digest
             )

    File.write!(path, Jason.encode!(Map.put(candidate, "extra", true)))

    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.plan278_census_ledger_binding_files_for_test(
               Jason.encode!(canonical),
               path,
               current_sha,
               candidate_digest
             )
  end

  test "Plan 278 rolls back promotion when the pinned review or census ledger changes" do
    for changed_input <- [:review, :ledger] do
      root =
        Path.join(
          System.tmp_dir!(),
          "phase133-plan278-postcheck-#{changed_input}-#{System.unique_integer([:positive])}"
        )

      phase = Path.join(root, ".planning/phases/133-evidence-charter-and-live-truth")
      File.mkdir_p!(phase)
      requirements = Path.join(root, ".planning/REQUIREMENTS.md")
      canonical = Path.join(phase, "133-EVIDENCE-CENSUS.json")
      nightly = Path.join(phase, "133-NIGHTLY-EVIDENCE.json")
      ledger = Path.join(phase, "133-278-CENSUS-LEDGER.json")
      review = Path.join(root, "133-278-CODE-REVIEW.md")
      prior_sha = String.duplicate("a", 40)
      current_sha = String.duplicate("b", 40)
      tree = String.duplicate("c", 40)

      prior_ledger = %{
        "schema_version" => 1,
        "subject_sha" => prior_sha,
        "detectors" => [%{"id" => "detector-a", "status" => "pass"}]
      }

      candidate = Map.put(prior_ledger, "subject_sha", current_sha)
      candidate_bytes = Jason.encode!(candidate)
      candidate_digest = :crypto.hash(:sha256, candidate_bytes) |> Base.encode16(case: :lower)
      valid_review = plan278_review_report(current_sha, tree)
      review_digest = :crypto.hash(:sha256, valid_review) |> Base.encode16(case: :lower)

      originals = %{
        requirements => "prior requirements\n",
        canonical => Jason.encode!(prior_ledger),
        nightly => "prior nightly\n"
      }

      Enum.each(originals, fn {path, bytes} -> File.write!(path, bytes) end)
      File.write!(ledger, candidate_bytes)
      File.write!(review, valid_review)
      on_exit(fn -> File.rm_rf!(root) end)

      updates = %{
        requirements => "promoted requirements\n",
        canonical => candidate_bytes,
        nightly => "promoted nightly\n"
      }

      postcheck = fn ->
        case changed_input do
          :review ->
            changed_review = String.replace(valid_review, "verdict: PASS\n", "verdict: FAIL\n")
            File.write!(review, changed_review)

            Rindle.ValidatePhase133Reconciliation.plan278_review_binding_digest_for_test(
              review,
              current_sha,
              tree,
              review_digest
            )

          :ledger ->
            File.write!(ledger, Jason.encode!(Map.put(candidate, "extra", true)))

            Rindle.ValidatePhase133Reconciliation.plan278_census_ledger_binding_files_for_test(
              File.read!(canonical),
              ledger,
              current_sha,
              candidate_digest
            )
        end
      end

      assert {:error, message} =
               Rindle.ValidatePhase133Reconciliation.plan278_apply_transaction_for_test(
                 root,
                 originals,
                 updates,
                 postcheck
               )

      assert message =~ "post-promotion validation failed"
      Enum.each(originals, fn {path, bytes} -> assert File.read!(path) == bytes end)
      refute File.exists?(Path.join(phase, "133-278-TERMINAL.json"))
      refute File.exists?(Path.join(phase, "133-278-TRANSACTION.json"))
    end
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

defmodule Rindle.InstallSmoke.Plan279TerminalTest do
  use ExUnit.Case, async: false
  @compile {:no_warn_undefined, Rindle.ValidatePhase133Reconciliation}

  @repo_root Path.expand("../..", __DIR__)

  setup_all do
    System.put_env("RINDLE_PHASE_133_RECONCILIATION_LIBRARY_ONLY", "1")
    Code.require_file("scripts/maintainer/validate_phase_133_reconciliation.exs", @repo_root)
    System.delete_env("RINDLE_PHASE_133_RECONCILIATION_LIBRARY_ONLY")
    :ok
  end

  test "Plan 279 CLI requires separate source and census roots" do
    assert {:error, message} =
             Rindle.ValidatePhase133Reconciliation.run(["--expect-plan279-terminal"])

    assert message =~ "Plan 279 requires"
  end

  test "Plan 279 review requires exact source, tree, full code-path list, clean status, and zero findings" do
    sha = String.duplicate("a", 40)
    tree = String.duplicate("b", 40)
    report = plan279_review_report(sha, tree)

    assert :ok =
             Rindle.ValidatePhase133Reconciliation.plan279_review_binding_for_test(
               report,
               sha,
               tree
             )

    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.plan279_review_binding_for_test(
               report,
               String.duplicate("c", 40),
               tree
             )

    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.plan279_review_binding_for_test(
               report,
               sha,
               String.duplicate("d", 40)
             )

    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.plan279_review_binding_for_test(
               String.replace(report, "verdict: PASS", "verdict: FAIL"),
               sha,
               tree
             )

    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.plan279_review_binding_for_test(
               String.replace(report, "status: clean", "status: findings"),
               sha,
               tree
             )

    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.plan279_review_binding_for_test(
               String.replace(report, "total: 0", "total: 1"),
               sha,
               tree
             )

    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.plan279_review_binding_for_test(
               String.replace(report, "files_reviewed: 11", "files_reviewed: 10"),
               sha,
               tree
             )

    refute "133-278-CODE-REVIEW.md" in Rindle.ValidatePhase133Reconciliation.plan279_reviewed_paths_for_test()
  end

  test "Plan 279 census roots must be separate, clean, detached copies at the exact SHA and tree" do
    root = temp_root("plan279-census-roots")
    source = Path.join(root, "source")
    a = Path.join(root, "census-a")
    b = Path.join(root, "census-b")
    seed_git_repo(source)
    clone_detached(source, a)
    clone_detached(source, b)
    sha = git_output(a, ["rev-parse", "HEAD"])
    tree = git_output(a, ["rev-parse", "HEAD^{tree}"])
    on_exit(fn -> File.rm_rf!(root) end)

    assert :ok =
             Rindle.ValidatePhase133Reconciliation.plan279_census_roots_for_test(
               source,
               a,
               b,
               sha,
               tree
             )

    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.plan279_census_roots_for_test(
               source,
               a,
               a,
               sha,
               tree
             )

    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.plan279_census_roots_for_test(
               source,
               source,
               b,
               sha,
               tree
             )

    File.write!(Path.join(a, "untracked.txt"), "dirty\n")

    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.plan279_census_roots_for_test(
               source,
               a,
               b,
               sha,
               tree
             )
  end

  test "Plan 279 source rejects changed identity and active code-byte drift" do
    root = temp_root("plan279-source-identity")
    source = Path.join(root, "source")
    active = Path.join(root, "active")
    seed_plan279_code_repo(source, active)
    sha = git_output(source, ["rev-parse", "HEAD"])
    tree = git_output(source, ["rev-parse", "HEAD^{tree}"])
    on_exit(fn -> File.rm_rf!(root) end)

    assert {:ok, ^tree} =
             Rindle.ValidatePhase133Reconciliation.plan279_source_for_test(active, source, sha)

    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.plan279_source_for_test(
               active,
               source,
               String.duplicate("f", 40)
             )

    changed =
      Path.join(
        active,
        hd(Rindle.ValidatePhase133Reconciliation.plan279_reviewed_paths_for_test())
      )

    File.write!(changed, "changed code bytes\n")

    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.plan279_source_for_test(active, source, sha)
  end

  test "Plan 279 cannot substitute Plan 278 receipts for its versioned inputs" do
    root = temp_root("plan279-old-receipts")
    phase = Path.join(root, ".planning/phases/133-evidence-charter-and-live-truth")
    File.mkdir_p!(phase)

    File.cp!(
      Path.join(@repo_root, ".planning/REQUIREMENTS.md"),
      Path.join(root, ".planning/REQUIREMENTS.md")
    )

    File.write!(Path.join(phase, "133-EVIDENCE-CENSUS.json"), "prior census\n")
    File.write!(Path.join(phase, "133-NIGHTLY-EVIDENCE.json"), "prior nightly\n")
    File.write!(Path.join(phase, "133-278-CI-EVIDENCE.json"), "old ci\n")
    File.write!(Path.join(phase, "133-278-CENSUS-A.json"), "old census\n")
    before = File.read!(Path.join(phase, "133-EVIDENCE-CENSUS.json"))
    on_exit(fn -> File.rm_rf!(root) end)

    assert {:error, _message} =
             Rindle.ValidatePhase133Reconciliation.validate_plan279_terminal(
               root,
               root <> "-source",
               root <> "-a",
               root <> "-b"
             )

    assert File.read!(Path.join(phase, "133-EVIDENCE-CENSUS.json")) == before
    refute File.exists?(Path.join(phase, "133-279-TERMINAL.json"))
  end

  test "Plan 279 sealed history rejects any modified predecessor record" do
    root = temp_root("plan279-sealed")
    paths = Rindle.ValidatePhase133Reconciliation.plan279_sealed_history_paths_for_test()
    seed_sealed_plan279(root, paths)
    on_exit(fn -> File.rm_rf!(root) end)

    assert {:ok, sealed} =
             Rindle.ValidatePhase133Reconciliation.plan279_sealed_history_for_test(root)

    assert :ok =
             Rindle.ValidatePhase133Reconciliation.plan278_sealed_history_unchanged(root, sealed)

    File.write!(Path.join(root, hd(paths)), "mutated sealed bytes\n")

    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.plan278_sealed_history_unchanged(root, sealed)
  end

  test "Plan 279 transaction restores canonical bytes and removes terminal output on red or interruption" do
    for mode <- [:red, :interrupted] do
      root = temp_root("plan279-rollback-#{mode}")
      phase = Path.join(root, ".planning/phases/133-evidence-charter-and-live-truth")
      File.mkdir_p!(phase)
      census = Path.join(phase, "133-EVIDENCE-CENSUS.json")
      nightly = Path.join(phase, "133-NIGHTLY-EVIDENCE.json")
      originals = %{census => "prior census bytes\n", nightly => "prior nightly bytes\n"}
      Enum.each(originals, fn {path, bytes} -> File.write!(path, bytes) end)
      updates = %{census => "new census bytes\n", nightly => "new nightly bytes\n"}
      on_exit(fn -> File.rm_rf!(root) end)

      fail = fn ->
        if mode == :red, do: {:error, "red postcheck"}, else: raise("simulated interruption")
      end

      assert {:error, _} =
               Rindle.ValidatePhase133Reconciliation.plan279_apply_transaction_for_test(
                 root,
                 originals,
                 updates,
                 fail
               )

      Enum.each(originals, fn {path, bytes} -> assert File.read!(path) == bytes end)
      refute File.exists?(Path.join(phase, "133-279-TERMINAL.json"))
      refute File.exists?(Path.join(phase, "133-279-TRANSACTION.json"))
    end
  end

  test "Plan 279 transaction promotes only canonical census and Nightly bytes after a green postcheck" do
    root = temp_root("plan279-promote")
    phase = Path.join(root, ".planning/phases/133-evidence-charter-and-live-truth")
    File.mkdir_p!(phase)
    census = Path.join(phase, "133-EVIDENCE-CENSUS.json")
    nightly = Path.join(phase, "133-NIGHTLY-EVIDENCE.json")
    requirements = Path.join(root, ".planning/REQUIREMENTS.md")
    File.write!(census, "old census\n")
    File.write!(nightly, "old Nightly\n")
    File.write!(requirements, "requirements remain exact\n")
    on_exit(fn -> File.rm_rf!(root) end)

    assert :ok =
             Rindle.ValidatePhase133Reconciliation.plan279_apply_transaction_for_test(
               root,
               %{census => "old census\n", nightly => "old Nightly\n"},
               %{census => "new census\n", nightly => "new Nightly\n"},
               fn -> :ok end
             )

    assert File.read!(census) == "new census\n"
    assert File.read!(nightly) == "new Nightly\n"
    assert File.read!(requirements) == "requirements remain exact\n"
    assert File.exists?(Path.join(phase, "133-279-TERMINAL.json"))
    refute File.exists?(Path.join(phase, "133-279-TRANSACTION.json"))
  end

  test "Plan 279 journal recovery restores prior canonical evidence after an interrupted promotion" do
    root = temp_root("plan279-recovery")
    phase = Path.join(root, ".planning/phases/133-evidence-charter-and-live-truth")
    File.mkdir_p!(phase)
    census = Path.join(phase, "133-EVIDENCE-CENSUS.json")
    nightly = Path.join(phase, "133-NIGHTLY-EVIDENCE.json")
    journal = Path.join(phase, "133-279-TRANSACTION.json")
    terminal = Path.join(phase, "133-279-TERMINAL.json")
    File.write!(census, "partial census\n")
    File.write!(nightly, "partial Nightly\n")
    File.write!(terminal, "partial terminal\n")

    prior = %{
      ".planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json" =>
        Base.encode64("old census\n"),
      ".planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-EVIDENCE.json" =>
        Base.encode64("old Nightly\n")
    }

    File.write!(
      journal,
      Jason.encode!(%{
        "schema_version" => 1,
        "plan" => "133-279",
        "status" => "applying",
        "terminal_path" =>
          ".planning/phases/133-evidence-charter-and-live-truth/133-279-TERMINAL.json",
        "prior_bytes" => prior
      })
    )

    on_exit(fn -> File.rm_rf!(root) end)

    assert :ok = Rindle.ValidatePhase133Reconciliation.plan279_recover_journal_for_test(root)
    assert File.read!(census) == "old census\n"
    assert File.read!(nightly) == "old Nightly\n"
    refute File.exists?(terminal)
    refute File.exists?(journal)
  end

  test "Plan 279 recovers a partial promotion before rejecting missing versioned receipts" do
    root = temp_root("plan279-recovery-before-inputs")
    phase = Path.join(root, ".planning/phases/133-evidence-charter-and-live-truth")
    File.mkdir_p!(phase)
    File.mkdir_p!(Path.join(root, ".planning"))
    census = Path.join(phase, "133-EVIDENCE-CENSUS.json")
    nightly = Path.join(phase, "133-NIGHTLY-EVIDENCE.json")
    journal = Path.join(phase, "133-279-TRANSACTION.json")
    terminal = Path.join(phase, "133-279-TERMINAL.json")
    File.write!(census, "partially promoted census\n")
    File.write!(nightly, "partially promoted Nightly\n")
    File.write!(terminal, "partial terminal\n")
    File.write!(Path.join(root, ".planning/REQUIREMENTS.md"), "requirements\n")

    prior = %{
      ".planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json" =>
        Base.encode64("original census\n"),
      ".planning/phases/133-evidence-charter-and-live-truth/133-NIGHTLY-EVIDENCE.json" =>
        Base.encode64("original Nightly\n")
    }

    File.write!(
      journal,
      Jason.encode!(%{
        "schema_version" => 1,
        "plan" => "133-279",
        "status" => "applying",
        "terminal_path" =>
          ".planning/phases/133-evidence-charter-and-live-truth/133-279-TERMINAL.json",
        "prior_bytes" => prior
      })
    )

    on_exit(fn -> File.rm_rf!(root) end)

    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.validate_plan279_terminal(
               root,
               root <> "-source",
               root <> "-census-a",
               root <> "-census-b"
             )

    assert File.read!(census) == "original census\n"
    assert File.read!(nightly) == "original Nightly\n"
    refute File.exists?(terminal)
    refute File.exists?(journal)
  end

  defp temp_root(label),
    do: Path.join(System.tmp_dir!(), "#{label}-#{System.unique_integer([:positive])}")

  defp git_output(root, args) do
    {output, 0} = System.cmd("git", args, cd: root, stderr_to_stdout: true)
    String.trim(output)
  end

  defp git_ok(root, args) do
    {_output, 0} = System.cmd("git", args, cd: root, stderr_to_stdout: true)
  end

  defp seed_git_repo(root) do
    File.mkdir_p!(root)
    git_ok(root, ["init", "--quiet"])
    git_ok(root, ["config", "user.name", "Plan 279 test"])
    git_ok(root, ["config", "user.email", "plan279@example.test"])
    File.write!(Path.join(root, "source.txt"), "source\n")
    git_ok(root, ["add", "source.txt"])
    git_ok(root, ["commit", "--quiet", "-m", "fixture"])
  end

  defp clone_detached(source, destination) do
    {_output, 0} =
      System.cmd("git", ["clone", "--quiet", source, destination], stderr_to_stdout: true)

    git_ok(destination, ["checkout", "--quiet", "--detach", "HEAD"])
  end

  defp seed_plan279_code_repo(source, active) do
    seed_git_repo(source)

    Rindle.ValidatePhase133Reconciliation.plan279_reviewed_paths_for_test()
    |> Enum.each(fn relative ->
      source_path = Path.join(source, relative)
      active_path = Path.join(active, relative)
      File.mkdir_p!(Path.dirname(source_path))
      File.mkdir_p!(Path.dirname(active_path))
      File.cp!(Path.join(@repo_root, relative), source_path)
      File.cp!(source_path, active_path)
    end)

    git_ok(source, ["add", "--all"])
    git_ok(source, ["commit", "--quiet", "-m", "Plan 279 source fixture"])
  end

  defp seed_sealed_plan279(root, paths) do
    Enum.each(paths, fn relative ->
      path = Path.join(root, relative)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, "sealed fixture: #{relative}\n")
    end)
  end

  defp plan279_review_report(sha, tree) do
    reviewed_files = Rindle.ValidatePhase133Reconciliation.plan279_reviewed_paths_for_test()
    files = Enum.map_join(reviewed_files, "\n", &"  - #{&1}")

    """
    ---
    phase: 133-279
    source_commit: #{sha}
    source_tree: #{tree}
    files_reviewed: #{length(reviewed_files)}
    files_reviewed_list:
    #{files}
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
    Independent review passed.
    """
    |> String.trim_leading()
  end
end
