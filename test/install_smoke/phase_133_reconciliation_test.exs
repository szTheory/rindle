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

  test "Plan 278 rejects changes to sealed predecessor and P275 records" do
    root =
      Path.join(
        System.tmp_dir!(),
        "phase133-plan278-sealed-#{System.unique_integer([:positive])}"
      )

    phase = Path.join(root, ".planning/phases/133-evidence-charter-and-live-truth")
    File.mkdir_p!(phase)
    stop = Path.join(phase, "133-243-STOP.json")
    prior = Path.join(phase, "133-275-HOST-RESULT.json")
    File.write!(stop, "{\"status\":\"halted\"}\n")
    File.write!(prior, "{\"status\":\"stopped\"}\n")
    on_exit(fn -> File.rm_rf!(root) end)

    assert {:ok, seal} = Rindle.ValidatePhase133Reconciliation.plan278_sealed_history(root)

    assert :ok =
             Rindle.ValidatePhase133Reconciliation.plan278_sealed_history_unchanged(root, seal)

    File.write!(stop, "{\"status\":\"reopened\"}\n")

    assert {:error, _} =
             Rindle.ValidatePhase133Reconciliation.plan278_sealed_history_unchanged(root, seal)
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
end
