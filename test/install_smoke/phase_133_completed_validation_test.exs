defmodule Rindle.InstallSmoke.Phase133CompletedValidationTest do
  use ExUnit.Case, async: true
  # Each reconciliation matrix case owns a unique temporary planning tree.
  @async_safety_allow [:file_mutation]
  def __async_safety_allow__, do: @async_safety_allow

  @repo_root Path.expand("../..", __DIR__)
  @phase_rel ".planning/phases/133-evidence-charter-and-live-truth"
  @validator Path.join(@repo_root, "scripts/maintainer/validate_phase_133_reconciliation.exs")
  @active_heading "## Gap-Repair Validation Addendum (Plans 28–32)"
  @failed_run "34661043059"
  @failed_subject "0f8189ddeed7e7a52b5c7464f17b70ab44596c33"
  @failed_ref "phase-133-evidence-0f8189ddeed7"

  test "accepts every dependency-valid repair state with Plan 27 halted" do
    fixture = write_fixture!()

    for completed <- [
          [],
          [28],
          [29],
          [28, 29],
          [28, 29, 30],
          [28, 29, 30, 31],
          [28, 29, 30, 31, 32]
        ] do
      set_execution_state!(fixture, completed)
      completed_count = 26 + length(completed)
      pending_count = 5 - length(completed)
      summarized_count = completed_count + 1

      assert {output, 0} = run_validator(fixture)
      assert output =~ "#{completed_count} completed, 1 halted, #{pending_count} pending plans"
      assert output =~ "#{summarized_count}/32 summarized"
    end
  end

  test "accepts execution-complete only with 31 complete and one halted summary" do
    fixture = write_fixture!()
    set_execution_state!(fixture, Enum.to_list(28..32))

    assert {output, 0} = run_validator(fixture, ["--expect-execution-complete"])
    assert output =~ "31 completed, 1 halted, 0 pending plans"
    assert output =~ "32/32 summarized"
  end

  test "rejects repair states that skip a dependency" do
    for completed <- [
          [30],
          [28, 30],
          [29, 30],
          [28, 29, 31],
          [28, 29, 30, 32]
        ] do
      fixture = write_fixture!()
      set_execution_state!(fixture, completed)
      assert_invalid(fixture, "repair dependency")
    end
  end

  test "rejects body and fenced-code completion impersonation" do
    for summary <- [
          "---\nstatus: halted\n---\n\nstatus: complete\n",
          "---\nstatus: halted\n---\n\n```yaml\nstatus: complete\n```\n"
        ] do
      fixture = write_fixture!()
      set_execution_state!(fixture, [28])
      File.write!(summary_path(fixture.root, 28), summary)

      assert_invalid(fixture, "summary 133-28")
    end
  end

  test "rejects malformed, duplicate, non-scalar, and ambiguous frontmatter" do
    for summary <- [
          "status: complete\n",
          "---\nstatus: complete\n",
          "---\nstatus: complete\nmalformed: [\n---\n",
          "---\nstatus: complete\nstatus: halted\n---\n",
          "---\nstatus:\n  nested: complete\n---\n",
          "---\nstatus: complete\n---\n\n---\nowner: forged\n---\n"
        ] do
      fixture = write_fixture!()
      set_execution_state!(fixture, [28])
      File.write!(summary_path(fixture.root, 28), summary)

      assert_invalid(fixture, "summary 133-28")
    end
  end

  test "accepts the real completed Phase 133 summaries without scanning their bodies" do
    fixture = write_fixture!()
    set_execution_state!(fixture, [28])

    for plan <- 1..26 do
      File.cp!(
        summary_path(@repo_root, plan),
        summary_path(fixture.root, plan)
      )
    end

    File.cp!(summary_path(@repo_root, 28), summary_path(fixture.root, 28))

    assert {output, 0} = run_validator(fixture)
    assert output =~ "27 completed, 1 halted, 4 pending plans"
  end

  test "rejects wrong totals, stale Progress counts, status, and completion dates" do
    for mutation <- [:detail_total, :progress_count, :status, :completion_date] do
      fixture = write_fixture!()
      set_execution_state!(fixture, [28, 29])

      mutate_roadmap!(fixture, fn roadmap ->
        case mutation do
          :detail_total ->
            String.replace(
              roadmap,
              "29/32 plans executed summarized",
              "29/33 plans executed summarized"
            )

          :progress_count ->
            String.replace(roadmap, "| 29/32 | In Progress |  |", "| 28/32 | In Progress |  |")

          :status ->
            String.replace(roadmap, "| 29/32 | In Progress |  |", "| 29/32 | Complete |  |")

          :completion_date ->
            String.replace(
              roadmap,
              "| 29/32 | In Progress |  |",
              "| 29/32 | In Progress | 2026-09-11 |"
            )
        end
      end)

      assert_invalid(fixture, "roadmap")
    end
  end

  test "rejects checkbox and complete-summary mismatches in both directions" do
    fixture = write_fixture!()
    set_execution_state!(fixture, [28])
    mutate_roadmap!(fixture, &String.replace(&1, "- [ ] 133-29-PLAN.md", "- [x] 133-29-PLAN.md"))
    assert_invalid(fixture, "summary/checkbox mismatch")

    fixture = write_fixture!()
    set_execution_state!(fixture, [28, 29])
    mutate_roadmap!(fixture, &String.replace(&1, "- [x] 133-29-PLAN.md", "- [ ] 133-29-PLAN.md"))
    assert_invalid(fixture, "summary/checkbox mismatch")
  end

  test "rejects Plan 27 as complete, checked, or missing its immutable failure identity" do
    fixture = write_fixture!()
    set_execution_state!(fixture, [])
    File.write!(summary_path(fixture.root, 27), "---\nstatus: complete\n---\n")
    assert_invalid(fixture, "Plan 27 must remain halted")

    fixture = write_fixture!()
    set_execution_state!(fixture, [])
    mutate_roadmap!(fixture, &String.replace(&1, "- [ ] 133-27-PLAN.md", "- [x] 133-27-PLAN.md"))
    assert_invalid(fixture, "Plan 27 must remain unchecked")

    for identity <- [@failed_run, "attempt `1`", @failed_subject, @failed_ref] do
      fixture = write_fixture!()
      set_execution_state!(fixture, [])

      summary = File.read!(summary_path(fixture.root, 27))
      File.write!(summary_path(fixture.root, 27), String.replace(summary, identity, "altered"))
      assert_invalid(fixture, "halted summary 133-27")
    end
  end

  test "rejects any drift in the preserved Plans 01-27 validation history" do
    fixture = write_fixture!()
    set_execution_state!(fixture, [28])
    mutate_validation!(fixture, &String.replace(&1, "19/19", "18/19", global: false))
    assert_invalid(fixture, "historical validation prefix")
  end

  defp write_fixture! do
    root =
      Path.join(
        System.tmp_dir!(),
        "rindle-phase-133-completed-#{System.unique_integer([:positive])}"
      )

    phase_dir = Path.join(root, @phase_rel)
    File.mkdir_p!(phase_dir)
    on_exit(fn -> File.rm_rf!(root) end)

    for plan <- 28..32 do
      File.cp!(
        Path.join(@repo_root, "#{@phase_rel}/133-#{plan}-PLAN.md"),
        Path.join(phase_dir, "133-#{plan}-PLAN.md")
      )
    end

    source_validation = File.read!(Path.join(@repo_root, "#{@phase_rel}/133-VALIDATION.md"))
    active_prefix = active_prefix(source_validation)
    validation_path = Path.join(phase_dir, "133-VALIDATION.md")
    File.write!(validation_path, active_prefix)

    set_execution_state!(%{root: root}, [])
    git!(root, ["init", "--quiet"])
    git!(root, ["config", "user.email", "phase133@example.invalid"])
    git!(root, ["config", "user.name", "Phase 133 Fixture"])
    git!(root, ["add", ".planning"])
    git!(root, ["commit", "--quiet", "-m", "active validation prefix"])
    active_prefix_ref = git!(root, ["rev-parse", "HEAD"])
    File.write!(validation_path, source_validation)

    %{
      root: root,
      roadmap: Path.join(root, ".planning/ROADMAP.md"),
      validation: validation_path,
      active_prefix_ref: active_prefix_ref,
      active_prefix_sha256: sha256(active_prefix)
    }
  end

  defp active_prefix(validation) do
    case :binary.match(validation, @active_heading) do
      {offset, _length} -> binary_part(validation, 0, offset)
      :nomatch -> validation
    end
  end

  defp set_execution_state!(fixture, completed) do
    File.mkdir_p!(Path.dirname(summary_path(fixture.root, 1)))

    for plan <- 1..32 do
      path = summary_path(fixture.root, plan)

      cond do
        plan <= 26 or plan in completed ->
          File.write!(path, "---\nstatus: complete\n---\n")

        plan == 27 ->
          File.write!(path, halted_summary())

        true ->
          File.rm(path)
      end
    end

    File.mkdir_p!(Path.join(fixture.root, ".planning"))
    File.write!(Path.join(fixture.root, ".planning/ROADMAP.md"), roadmap(completed))
  end

  defp roadmap(completed) do
    completed_count = 26 + Enum.count(completed, &(&1 in 28..32))
    summarized_count = completed_count + 1
    pending_count = 32 - summarized_count

    rows =
      Enum.map_join(1..32, "", fn plan ->
        checked = if plan <= 26 or plan in completed, do: "x", else: " "
        id = String.pad_leading(Integer.to_string(plan), 2, "0")
        "- [#{checked}] 133-#{id}-PLAN.md\n"
      end)

    """
    # Roadmap

    ### Phase 133: Evidence Charter and Live Truth

    **Plans**: #{summarized_count}/32 plans executed summarized; #{completed_count} completed, Plan 133-27 halted with its failed immutable attempt preserved, #{pending_count} pending

    #{rows}
    ### Phase 134: Next

    ## Progress

    | Phase | Plans Complete | Status | Completed |
    |-------|----------------|--------|-----------|
    | 133. Evidence Charter and Live Truth | #{summarized_count}/32 | In Progress |  |
    """
  end

  defp halted_summary do
    """
    ---
    status: halted
    halt_reason: "Dispatch-owned Nightly run #{@failed_run} attempt 1 completed failure."
    ---

    The dispatch-owned Nightly run is `#{@failed_run}`, attempt `1`, on head SHA `#{@failed_subject}`.
    Failed ref: `refs/heads/#{@failed_ref}`.
    """
  end

  defp run_validator(fixture, extra \\ []) do
    System.cmd(
      "mix",
      [
        "run",
        "--no-start",
        "--no-deps-check",
        "--no-compile",
        @validator,
        "--root",
        fixture.root,
        "--fixture-active-prefix-ref",
        fixture.active_prefix_ref,
        "--fixture-active-prefix-sha256",
        fixture.active_prefix_sha256
      ] ++ extra,
      cd: @repo_root,
      env: [{"MIX_QUIET", "1"}],
      stderr_to_stdout: true
    )
  end

  defp assert_invalid(fixture, diagnostic, extra \\ []) do
    assert {output, status} = run_validator(fixture, extra)
    assert status != 0
    assert output =~ diagnostic
    assert byte_size(output) < 2_048
  end

  defp mutate_roadmap!(fixture, mutation),
    do: File.write!(fixture.roadmap, mutation.(File.read!(fixture.roadmap)))

  defp mutate_validation!(fixture, mutation),
    do: File.write!(fixture.validation, mutation.(File.read!(fixture.validation)))

  defp summary_path(root, plan) do
    id = String.pad_leading(Integer.to_string(plan), 2, "0")
    Path.join(root, "#{@phase_rel}/133-#{id}-SUMMARY.md")
  end

  defp git!(root, args) do
    case System.cmd("git", args, cd: root, stderr_to_stdout: true) do
      {output, 0} -> String.trim(output)
      {output, status} -> flunk("git #{Enum.join(args, " ")} failed (#{status}): #{output}")
    end
  end

  defp sha256(contents), do: :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)
end
