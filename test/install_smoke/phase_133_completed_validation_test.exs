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
  @rate_limited_run "34670574306"
  @rate_limited_subject "e70623e9ea956c750904af574f47221cc472d2f2"
  @rate_limited_ref "phase-133-evidence-e70623e9ea95"

  test "accepts the first post-repair 33/37 lifecycle state" do
    fixture = write_branch_fixture!()
    set_branch_state!(fixture, completed: [33], halted: [27, 32])

    assert {output, 0} = run_validator(fixture)

    assert output ==
             "phase 133 reconciliation valid: 31 completed, 2 halted, 4 pending plans, " <>
               "33/37 summarized, 28 validation records\n"
  end

  test "rejects contradictory first post-repair authorities with bounded diagnostics" do
    cases = [
      {:stale_total, "roadmap detail"},
      {:missing_baseline_halt, "Plan 32 must remain halted"},
      {:out_of_branch_halt, "halted set"},
      {:checked_requirement, "requirement EVID-01 must remain pending"},
      {:state_count, "STATE completed_plans"},
      {:progress_count, "roadmap Progress row"}
    ]

    for {mutation, diagnostic} <- cases do
      fixture = write_branch_fixture!()
      set_branch_state!(fixture, completed: [33], halted: [27, 32])
      mutate_branch_fixture!(fixture, mutation)

      assert_invalid(fixture, diagnostic)
    end
  end

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

  test "rejects omitted, duplicated, or altered repair mappings" do
    for mutation <- [:omitted, :duplicated, :altered] do
      fixture = write_fixture!()
      set_execution_state!(fixture, [28])

      mutate_validation!(fixture, fn validation ->
        record = record_for(validation, "133-32-02:4")

        case mutation do
          :omitted ->
            String.replace(validation, record, "")

          :duplicated ->
            validation <> "\n" <> record

          :altered ->
            String.replace(
              validation,
              record,
              String.replace(record, "temp_root=", "stale_temp_root=", global: false)
            )
        end
      end)

      assert_invalid(fixture, "mapping")
    end
  end

  test "rejects altered Plan 27 halted-history evidence" do
    fixture = write_fixture!()
    set_execution_state!(fixture, [28])

    mutate_validation!(fixture, fn validation ->
      record = record_for(validation, "133-27-halted-history:1")
      String.replace(validation, record, String.replace(record, @failed_run, "34661043058"))
    end)

    assert_invalid(fixture, "command text")
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

  defp write_branch_fixture! do
    root =
      Path.join(
        System.tmp_dir!(),
        "rindle-phase-133-branch-#{System.unique_integer([:positive])}"
      )

    phase_dir = Path.join(root, @phase_rel)
    File.mkdir_p!(phase_dir)
    on_exit(fn -> File.rm_rf!(root) end)

    for plan <- 28..37 do
      File.cp!(
        Path.join(@repo_root, "#{@phase_rel}/133-#{plan}-PLAN.md"),
        Path.join(phase_dir, "133-#{plan}-PLAN.md")
      )
    end

    source_validation = File.read!(Path.join(@repo_root, "#{@phase_rel}/133-VALIDATION.md"))
    active_prefix = active_prefix(source_validation)
    validation_path = Path.join(phase_dir, "133-VALIDATION.md")
    File.write!(validation_path, active_prefix)

    fixture = %{
      root: root,
      roadmap: Path.join(root, ".planning/ROADMAP.md"),
      state: Path.join(root, ".planning/STATE.md"),
      requirements: Path.join(root, ".planning/REQUIREMENTS.md"),
      validation: validation_path,
      topology: "branch-37"
    }

    set_branch_state!(fixture, completed: [33], halted: [27, 32])
    git!(root, ["init", "--quiet"])
    git!(root, ["config", "user.email", "phase133@example.invalid"])
    git!(root, ["config", "user.name", "Phase 133 Fixture"])
    git!(root, ["add", ".planning"])
    git!(root, ["commit", "--quiet", "-m", "branch validation prefix"])
    active_prefix_ref = git!(root, ["rev-parse", "HEAD"])
    File.write!(validation_path, source_validation)

    Map.merge(fixture, %{
      active_prefix_ref: active_prefix_ref,
      active_prefix_sha256: sha256(active_prefix)
    })
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

  defp set_branch_state!(fixture, completed: completed_tail, halted: halted) do
    completed = MapSet.new(Enum.to_list(1..26) ++ [28, 29, 30, 31] ++ completed_tail)
    halted = MapSet.new(halted)

    for plan <- 1..37 do
      path = summary_path(fixture.root, plan)
      File.mkdir_p!(Path.dirname(path))

      cond do
        MapSet.member?(completed, plan) -> File.write!(path, "---\nstatus: complete\n---\n")
        plan == 27 and MapSet.member?(halted, plan) -> File.write!(path, halted_summary())
        plan == 32 and MapSet.member?(halted, plan) -> File.write!(path, rate_limited_summary())
        MapSet.member?(halted, plan) -> File.write!(path, "---\nstatus: halted\n---\n")
        true -> File.rm(path)
      end
    end

    summarized_count = MapSet.size(completed) + MapSet.size(halted)
    pending_count = 37 - summarized_count

    rows =
      Enum.map_join(1..37, "", fn plan ->
        checked = if MapSet.member?(completed, plan), do: "x", else: " "
        id = String.pad_leading(Integer.to_string(plan), 2, "0")
        "- [#{checked}] 133-#{id}-PLAN.md\n"
      end)

    File.mkdir_p!(Path.join(fixture.root, ".planning"))

    File.write!(
      fixture.roadmap,
      """
      # Roadmap

      ### Phase 133: Evidence Charter and Live Truth

      **Plans**: #{summarized_count}/37 plans summarized; #{MapSet.size(completed)} completed, Plans 133-27 and 133-32 halted with immutable attempts preserved, #{pending_count} pending.

      #{rows}
      ### Phase 134: Next

      ## Progress

      | Phase | Plans Complete | Status | Completed |
      |-------|----------------|--------|-----------|
      | 133. Evidence Charter and Live Truth | #{summarized_count}/37 | In Progress|  |
      """
    )

    File.write!(
      fixture.state,
      """
      ---
      current_phase: 133
      status: executing
      progress:
        total_plans: 37
        completed_plans: #{summarized_count}
      ---

      ## Current Position

      Plan: #{summarized_count + 1} of 37
      Status: EXECUTING
      """
    )

    File.write!(fixture.requirements, requirements_fixture(false))
  end

  defp mutate_branch_fixture!(fixture, :stale_total) do
    mutate_roadmap!(
      fixture,
      &String.replace(&1, "33/37 plans summarized", "33/32 plans summarized")
    )
  end

  defp mutate_branch_fixture!(fixture, :missing_baseline_halt) do
    File.rm!(summary_path(fixture.root, 32))
  end

  defp mutate_branch_fixture!(fixture, :out_of_branch_halt) do
    File.write!(summary_path(fixture.root, 36), "---\nstatus: halted\n---\n")
  end

  defp mutate_branch_fixture!(fixture, :checked_requirement) do
    File.write!(fixture.requirements, requirements_fixture(true))
  end

  defp mutate_branch_fixture!(fixture, :state_count) do
    File.write!(
      fixture.state,
      String.replace(File.read!(fixture.state), "completed_plans: 33", "completed_plans: 32")
    )
  end

  defp mutate_branch_fixture!(fixture, :progress_count) do
    mutate_roadmap!(
      fixture,
      &String.replace(&1, "| 33/37 | In Progress|", "| 32/37 | In Progress|")
    )
  end

  defp requirements_fixture(checked?) do
    checkbox = if checked?, do: "x", else: " "

    Enum.map_join(["EVID-01", "EVID-02", "EVID-03", "EVID-04", "TRUTH-08"], "\n", fn id ->
      "- [#{checkbox}] **#{id}**: fixture requirement\n| #{id} | Phase 133 | #{if(checked?, do: "Complete", else: "Pending")} |"
    end)
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

  defp rate_limited_summary do
    """
    ---
    status: halted
    halt_reason: "Dispatch-owned Nightly run #{@rate_limited_run} could not be qualified."
    ---

    Run `#{@rate_limited_run}` on subject `#{@rate_limited_subject}` and ref `refs/heads/#{@rate_limited_ref}` remains immutable.
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
        fixture.active_prefix_sha256,
        "--fixture-topology",
        Map.get(fixture, :topology, "repair-32")
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

  defp record_for(validation, key) do
    [record] =
      Regex.run(
        ~r/<pending-validation key="#{Regex.escape(key)}">.*?<\/pending-validation>\n?/s,
        validation
      )

    record
  end

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
