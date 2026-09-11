defmodule Rindle.InstallSmoke.Phase133CompletedValidationTest do
  use ExUnit.Case, async: true
  # Each reconciliation matrix case owns a unique temporary planning tree.
  @async_safety_allow [:file_mutation]
  def __async_safety_allow__, do: @async_safety_allow

  @repo_root Path.expand("../..", __DIR__)
  @phase_rel ".planning/phases/133-evidence-charter-and-live-truth"
  @validator Path.join(@repo_root, "scripts/maintainer/validate_phase_133_reconciliation.exs")
  @active_heading "## Pending Gap-Closure Validation Addendum (Plans 23–27)"

  test "accepts every summary-backed Wave 17 subset and keeps Plan 27 pending" do
    fixture = write_fixture!()

    for mask <- 0..15 do
      completed = Enum.filter(23..26, &(Bitwise.band(mask, Bitwise.bsl(1, &1 - 23)) != 0))
      set_execution_state!(fixture, completed)
      expected = 22 + length(completed)

      assert {output, 0} = run_validator(fixture)
      assert output =~ "#{expected} completed, #{27 - expected} pending plans"
    end
  end

  test "accepts execution-complete only with all 27 summaries and aligned roadmap truth" do
    fixture = write_fixture!()
    set_execution_state!(fixture, Enum.to_list(23..27))

    assert {output, 0} = run_validator(fixture, ["--expect-execution-complete"])
    assert output =~ "27 completed, 0 pending plans"
  end

  test "rejects body and fenced-code completion impersonation" do
    for summary <- [
          "---\nstatus: halted\n---\n\nstatus: complete\n",
          "---\nstatus: halted\n---\n\n```yaml\nstatus: complete\n```\n"
        ] do
      fixture = write_fixture!()
      set_execution_state!(fixture, [23])
      File.write!(summary_path(fixture.root, 23), summary)

      assert_invalid(fixture, "completed summary 133-23")
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
      set_execution_state!(fixture, [23])
      File.write!(summary_path(fixture.root, 23), summary)

      assert_invalid(fixture, "completed summary 133-23")
    end
  end

  test "accepts the real completed Phase 133 summaries without scanning their bodies" do
    fixture = write_fixture!()
    set_execution_state!(fixture, [23, 24])

    for plan <- 1..24 do
      File.cp!(
        summary_path(@repo_root, plan),
        summary_path(fixture.root, plan)
      )
    end

    assert {output, 0} = run_validator(fixture)
    assert output =~ "24 completed, 3 pending plans"
  end
  test "rejects wrong totals, stale Progress counts, status, and completion dates" do
    for mutation <- [:detail_total, :progress_count, :status, :completion_date] do
      fixture = write_fixture!()
      set_execution_state!(fixture, Enum.to_list(23..26))

      mutate_roadmap!(fixture, fn roadmap ->
        case mutation do
          :detail_total ->
            String.replace(roadmap, "26/27 plans executed", "26/28 plans executed")

          :progress_count ->
            String.replace(roadmap, "| 26/27 | In Progress |  |", "| 25/27 | In Progress |  |")

          :status ->
            String.replace(roadmap, "| 26/27 | In Progress |  |", "| 26/27 | Complete |  |")

          :completion_date ->
            String.replace(
              roadmap,
              "| 26/27 | In Progress |  |",
              "| 26/27 | In Progress | 2026-09-11 |"
            )
        end
      end)

      assert_invalid(fixture, "roadmap")
    end
  end

  test "rejects checkbox and complete-summary mismatches in both directions" do
    fixture = write_fixture!()
    set_execution_state!(fixture, [23, 24, 25])
    mutate_roadmap!(fixture, &String.replace(&1, "- [ ] 133-26-PLAN.md", "- [x] 133-26-PLAN.md"))
    assert_invalid(fixture, "summary/checkbox mismatch")

    fixture = write_fixture!()
    set_execution_state!(fixture, Enum.to_list(23..26))
    mutate_roadmap!(fixture, &String.replace(&1, "- [x] 133-26-PLAN.md", "- [ ] 133-26-PLAN.md"))
    assert_invalid(fixture, "summary/checkbox mismatch")
  end

  test "rejects early Plan 27 and missing or incomplete execution-complete summary" do
    fixture = write_fixture!()
    set_execution_state!(fixture, Enum.to_list(23..27))
    assert_invalid(fixture, "Plan 27 must remain pending")

    fixture = write_fixture!()
    set_execution_state!(fixture, Enum.to_list(23..27))
    File.rm!(summary_path(fixture.root, 27))
    assert_invalid(fixture, "completed summary 133-27", ["--expect-execution-complete"])

    File.write!(summary_path(fixture.root, 27), "---\nstatus: halted\n---\n")
    assert_invalid(fixture, "completed summary 133-27", ["--expect-execution-complete"])
  end

  test "rejects omitted, duplicated, or altered post-summary mappings" do
    for mutation <- [:omitted, :duplicated, :altered] do
      fixture = write_fixture!()
      set_execution_state!(fixture, Enum.to_list(23..26))

      mutate_validation!(fixture, fn validation ->
        record = record_for(validation, "133-27-post-summary:1")

        case mutation do
          :omitted ->
            String.replace(validation, record, "")

          :duplicated ->
            validation <> "\n" <> record

          :altered ->
            String.replace(
              validation,
              record,
              String.replace(record, "27/27", "26/27", global: false)
            )
        end
      end)

      assert_invalid(fixture, "mapping")
    end
  end

  test "rejects authorization credit assigned to the Plan 27 publication checkpoint" do
    fixture = write_fixture!()
    set_execution_state!(fixture, Enum.to_list(23..26))

    mutate_validation!(fixture, fn validation ->
      record = record_for(validation, "133-27-02:1")
      String.replace(validation, record, String.replace(record, "authorization-only", "pending"))
    end)

    assert_invalid(fixture, "acceptance credit")
  end

  test "rejects any drift in the preserved Plans 01-22 validation history" do
    fixture = write_fixture!()
    set_execution_state!(fixture, Enum.to_list(23..26))
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

    for plan <- 23..27 do
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

    for plan <- 1..27 do
      path = summary_path(fixture.root, plan)

      if plan <= 22 or plan in completed do
        File.write!(path, "---\nstatus: complete\n---\n")
      else
        File.rm(path)
      end
    end

    File.mkdir_p!(Path.join(fixture.root, ".planning"))
    File.write!(Path.join(fixture.root, ".planning/ROADMAP.md"), roadmap(completed))
  end

  defp roadmap(completed) do
    count = 22 + Enum.count(completed, &(&1 in 23..27))

    rows =
      Enum.map_join(1..27, "", fn plan ->
        checked = if plan <= 22 or plan in completed, do: "x", else: " "
        id = String.pad_leading(Integer.to_string(plan), 2, "0")
        "- [#{checked}] 133-#{id}-PLAN.md\n"
      end)

    """
    # Roadmap

    ### Phase 133: Evidence Charter and Live Truth

    **Plans**: #{count}/27 plans executed

    #{rows}
    ### Phase 134: Next

    ## Progress

    | Phase | Plans Complete | Status | Completed |
    |-------|----------------|--------|-----------|
    | 133. Evidence Charter and Live Truth | #{count}/27 | In Progress |  |
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
