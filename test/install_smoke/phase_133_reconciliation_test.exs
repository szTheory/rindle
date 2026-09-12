defmodule Rindle.InstallSmoke.Phase133ReconciliationTest do
  use ExUnit.Case, async: true

  @script Path.expand("../../scripts/maintainer/validate_phase_133_reconciliation.exs", __DIR__)
  @heading "## Pending Gap-Closure Validation Addendum (Plans 11–17)"
  @success_prefix "phase 133 reconciliation valid:"
  @failure_prefix "[validate-phase-133-reconciliation]"
  @max_process_output_bytes 16_384
  @max_process_output_lines 16

  setup do
    root =
      Path.join(
        System.tmp_dir!(),
        "rindle-phase-133-reconciliation-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf!(root) end)
    fixture = write_fixture!(root)
    %{fixture: fixture}
  end

  test "accepts the exact historical preimage, roadmap, and pending pair map", %{fixture: fixture} do
    assert_valid(fixture)
  end

  test "accepts one authoritative success record with bounded launcher diagnostics" do
    success = "#{@success_prefix} 10 completed, 7 pending plans, 16 verification pairs"

    assert_valid_process_result({success, 0})
    assert_valid_process_result({"Compiling reconciliation launcher\n#{success}", 0})
  end

  test "rejects missing, duplicate, failure, and nonzero process results" do
    success = "#{@success_prefix} 10 completed, 7 pending plans, 16 verification pairs"

    assert_raise ExUnit.AssertionError, fn ->
      assert_valid_process_result({"bounded launcher diagnostic", 0})
    end

    assert_raise ExUnit.AssertionError, fn ->
      assert_valid_process_result({"#{success}\n#{success}", 0})
    end

    assert_raise ExUnit.AssertionError, fn ->
      assert_valid_process_result({"#{@failure_prefix} invalid roadmap\n#{success}", 0})
    end

    assert_raise ExUnit.AssertionError, fn ->
      assert_valid_process_result({success, 1})
    end
  end

  test "rejects process output beyond bounded bytes or lines before parsing records" do
    success = "#{@success_prefix} 10 completed, 7 pending plans, 16 verification pairs"

    assert_raise ExUnit.AssertionError, ~r/process output exceeds byte bound/, fn ->
      assert_valid_process_result(
        {success <> String.duplicate("x", @max_process_output_bytes), 0}
      )
    end

    assert_raise ExUnit.AssertionError, ~r/process output exceeds line bound/, fn ->
      diagnostics =
        Enum.map_join(1..@max_process_output_lines, "\n", &"launcher diagnostic #{&1}")

      assert_valid_process_result({"#{diagnostics}\n#{success}", 0})
    end
  end

  test "preserves multiple verification pairs owned by one task", %{fixture: fixture} do
    assert Enum.count(fixture.records, &String.starts_with?(&1.key, "133-11-01:")) == 2
    assert_valid(fixture)
  end

  test "loads compiled YAML authority for the standalone Elixir validator", %{fixture: fixture} do
    fixture
    |> run_validator_with("elixir", [@script])
    |> assert_valid_process_result()
  end

  test "rejects a one-byte historical mutation", %{fixture: fixture} do
    mutate_validation(fixture, &String.replace(&1, "19/19", "18/19", global: false))
    assert_invalid(fixture, "historical prefix")
  end

  test "rejects content inserted at the historical boundary", %{fixture: fixture} do
    mutate_validation(fixture, &String.replace(&1, @heading, "inserted\n" <> @heading))
    assert_invalid(fixture, "historical prefix")
  end

  test "rejects duplicate addendum headings", %{fixture: fixture} do
    mutate_validation(fixture, &String.replace(&1, @heading, @heading <> "\n" <> @heading))
    assert_invalid(fixture, "addendum heading")
  end

  test "rejects a missing mapping", %{fixture: fixture} do
    mutate_validation(fixture, &remove_record(&1, Enum.at(fixture.records, 2).key))
    assert_invalid(fixture, "pending mapping")
  end

  test "rejects a duplicate mapping", %{fixture: fixture} do
    record = render_record(hd(fixture.records))
    mutate_validation(fixture, &(&1 <> "\n" <> record))
    assert_invalid(fixture, "duplicate mapping")
  end

  test "rejects an extra mapping", %{fixture: fixture} do
    extra = %{
      key: "133-99-plan-verification:1",
      command: "true",
      failure: "non-zero",
      credit: "pending"
    }

    mutate_validation(fixture, &(&1 <> "\n" <> render_record(extra)))
    assert_invalid(fixture, "extra mapping")
  end

  test "rejects reordered mappings and noncontiguous source ordinals", %{fixture: fixture} do
    [first, second | _] = fixture.records

    mutate_validation(fixture, fn validation ->
      first_rendered = render_record(first)
      second_rendered = render_record(second)

      validation
      |> String.replace(first_rendered, "__FIRST__", global: false)
      |> String.replace(second_rendered, first_rendered, global: false)
      |> String.replace("__FIRST__", second_rendered, global: false)
    end)

    assert_invalid(fixture, "mapping order")
  end

  test "rejects command text mutation", %{fixture: fixture} do
    mutate_validation(
      fixture,
      &String.replace(&1, "fixture-command-11-a", "fixture-command-11-A")
    )

    assert_invalid(fixture, "command text")
  end

  test "rejects failure-direction text mutation", %{fixture: fixture} do
    mutate_validation(fixture, &String.replace(&1, "failure-11-a", "failure-11-A"))
    assert_invalid(fixture, "failure text")
  end

  test "rejects an automated command without an adjacent failure direction", %{fixture: fixture} do
    mutate_plan(fixture, 12, &String.replace(&1, "<fails_when>failure-12-a</fails_when>", ""))
    assert_invalid(fixture, "verification markup")
  end

  test "rejects an orphan failure direction", %{fixture: fixture} do
    mutate_plan(
      fixture,
      12,
      &String.replace(&1, "<automated>fixture-command-12-a</automated>", "")
    )

    assert_invalid(fixture, "verification markup")
  end

  test "rejects malformed verification tags", %{fixture: fixture} do
    mutate_plan(
      fixture,
      12,
      &String.replace(&1, "</automated>", "</automated-broken>", global: false)
    )

    assert_invalid(fixture, "verification markup")
  end

  test "rejects a missing plan input", %{fixture: fixture} do
    File.rm!(plan_path(fixture.root, 16))
    assert_invalid(fixture, "missing plan")
  end

  test "rejects wrong roadmap count or status", %{fixture: fixture} do
    mutate_roadmap(
      fixture,
      &String.replace(
        &1,
        "10/17 plans executed; 7 pending gap closure",
        "11/17 plans executed; 6 pending gap closure"
      )
    )

    assert_invalid(fixture, "roadmap status")
  end

  test "rejects a removed historical plan", %{fixture: fixture} do
    mutate_roadmap(fixture, &String.replace(&1, "- [x] 133-04-PLAN.md\n", ""))
    assert_invalid(fixture, "historical plan")
  end

  test "rejects an omitted or checked pending plan", %{fixture: fixture} do
    original = File.read!(fixture.roadmap)
    mutate_roadmap(fixture, &String.replace(&1, "- [ ] 133-14-PLAN.md\n", ""))
    assert_invalid(fixture, "pending plan")

    File.write!(
      fixture.roadmap,
      String.replace(original, "- [ ] 133-14-PLAN.md", "- [x] 133-14-PLAN.md")
    )

    assert_invalid(fixture, "pending plan")
  end

  test "rejects premature green or executed state", %{fixture: fixture} do
    mutate_validation(
      fixture,
      &String.replace(&1, "pending — not executed", "green — executed", global: false)
    )

    assert_invalid(fixture, "pending state")
  end

  defp write_fixture!(root) do
    phase_dir = Path.join(root, ".planning/phases/133-evidence-charter-and-live-truth")
    File.mkdir_p!(phase_dir)
    roadmap = Path.join(root, ".planning/ROADMAP.md")
    validation = Path.join(phase_dir, "133-VALIDATION.md")

    historical =
      "# Historical Phase 133 Validation\n\n19/19 automated implementation tasks are green.\n\n| Gaps found | 0 |\n"

    File.write!(roadmap, roadmap_fixture())
    File.write!(validation, historical)

    records =
      Enum.flat_map(11..17, fn plan ->
        task_pairs =
          if plan == 11,
            do: [
              {"fixture-command-11-a", "failure-11-a"},
              {"fixture-command-11-b", "failure-11-b"}
            ],
            else: [{"fixture-command-#{plan}-a", "failure-#{plan}-a"}]

        plan_pairs =
          if plan == 17,
            do: [
              {"fixture-plan-17-a", "plan-failure-17-a"},
              {"fixture-plan-17-b", "plan-failure-17-b"}
            ],
            else: [{"fixture-plan-#{plan}-a", "plan-failure-#{plan}-a"}]

        checkpoint? = plan == 17

        File.write!(
          plan_path(root, plan),
          plan_fixture(plan, task_pairs, plan_pairs, checkpoint?)
        )

        task_records =
          task_pairs
          |> Enum.with_index(1)
          |> Enum.map(fn {{command, failure}, pair} ->
            %{
              key: "133-#{plan}-01:#{pair}",
              command: command,
              failure: failure,
              credit: if(checkpoint?, do: "authorization-only", else: "pending")
            }
          end)

        plan_records =
          plan_pairs
          |> Enum.with_index(1)
          |> Enum.map(fn {{command, failure}, pair} ->
            %{
              key: "133-#{plan}-plan-verification:#{pair}",
              command: command,
              failure: failure,
              credit: "pending"
            }
          end)

        task_records ++ plan_records
      end)

    git!(root, ["init", "--quiet"])
    git!(root, ["config", "user.email", "phase133@example.invalid"])
    git!(root, ["config", "user.name", "Phase 133 Fixture"])
    git!(root, ["add", ".planning"])
    git!(root, ["commit", "--quiet", "-m", "historical fixture"])
    historical_ref = git!(root, ["rev-parse", "HEAD"])
    historical_sha256 = sha256(historical)

    File.write!(
      validation,
      historical <> @heading <> "\n\n" <> Enum.map_join(records, "\n", &render_record/1)
    )

    %{
      root: root,
      roadmap: roadmap,
      validation: validation,
      historical_ref: historical_ref,
      historical_sha256: historical_sha256,
      records: records
    }
  end

  defp plan_fixture(plan, task_pairs, plan_pairs, checkpoint?) do
    task_type = if checkpoint?, do: "checkpoint:decision", else: "auto"

    """
    ---
    phase: 133
    plan: #{plan}
    ---
    <tasks>
    <task type="#{task_type}">
      <name>Fixture task</name>
      <verify>
    #{render_pairs(task_pairs)}
      </verify>
    </task>
    </tasks>
    <verification>
    #{render_pairs(plan_pairs)}
    </verification>
    """
  end

  defp render_pairs(pairs) do
    Enum.map_join(pairs, "\n", fn {command, failure} ->
      "  <automated>#{command}</automated>\n  <fails_when>#{failure}</fails_when>"
    end)
  end

  defp roadmap_fixture do
    completed =
      Enum.map_join(
        1..10,
        "",
        &"- [x] 133-#{String.pad_leading(Integer.to_string(&1), 2, "0")}-PLAN.md\n"
      )

    pending = Enum.map_join(11..17, "", &"- [ ] 133-#{&1}-PLAN.md\n")

    "# Roadmap\n\n### Phase 133: Evidence Charter and Live Truth\n\n**Plans**: 10/17 plans executed; 7 pending gap closure\n\n#{completed}#{pending}\n### Phase 134: Next\n"
  end

  defp render_record(record) do
    """
    <pending-validation key="#{record.key}">
    <automated>
    #{record.command}
    </automated>
    <fails_when>
    #{record.failure}
    </fails_when>
    <state>pending — not executed</state>
    <acceptance-credit>#{record.credit}</acceptance-credit>
    </pending-validation>
    """
  end

  defp remove_record(validation, key) do
    Regex.replace(
      ~r/<pending-validation key="#{Regex.escape(key)}">.*?<\/pending-validation>\n?/s,
      validation,
      ""
    )
  end

  defp mutate_validation(fixture, fun),
    do: File.write!(fixture.validation, fun.(File.read!(fixture.validation)))

  defp mutate_roadmap(fixture, fun),
    do: File.write!(fixture.roadmap, fun.(File.read!(fixture.roadmap)))

  defp mutate_plan(fixture, plan, fun),
    do:
      File.write!(plan_path(fixture.root, plan), fun.(File.read!(plan_path(fixture.root, plan))))

  defp plan_path(root, plan),
    do:
      Path.join(root, ".planning/phases/133-evidence-charter-and-live-truth/133-#{plan}-PLAN.md")

  defp assert_valid(fixture) do
    result = run_validator(fixture)
    assert_valid_process_result(result)
    {output, 0} = result
    assert output =~ "phase 133 reconciliation valid"
    assert output =~ "16 verification pairs"
  end

  defp assert_valid_process_result({output, status}) do
    assert byte_size(output) <= @max_process_output_bytes,
           "process output exceeds byte bound"

    line_count =
      if output == "" do
        0
      else
        length(:binary.matches(output, "\n")) +
          if(String.ends_with?(output, "\n"), do: 0, else: 1)
      end

    assert line_count <= @max_process_output_lines,
           "process output exceeds line bound"

    assert status == 0

    lines = String.split(output, "\n", trim: true)
    success_records = Enum.filter(lines, &String.starts_with?(&1, @success_prefix))
    failure_records = Enum.filter(lines, &String.starts_with?(&1, @failure_prefix))

    assert length(success_records) == 1
    assert failure_records == []
  end

  defp assert_invalid(fixture, diagnostic) do
    assert {output, status} = run_validator(fixture)
    assert status != 0
    assert output =~ diagnostic
    assert byte_size(output) < 2_048
  end

  defp run_validator(fixture) do
    run_validator_with(fixture, "mix", [
      "run",
      "--no-start",
      "--no-deps-check",
      "--no-compile",
      @script
    ])
  end

  defp run_validator_with(fixture, executable, arguments) do
    System.cmd(
      executable,
      arguments ++
        [
          "--root",
          fixture.root,
          "--fixture-historical-ref",
          fixture.historical_ref,
          "--fixture-historical-sha256",
          fixture.historical_sha256
        ],
      cd: Path.expand("../..", __DIR__),
      env: [{"MIX_QUIET", "1"}],
      stderr_to_stdout: true
    )
  end

  defp git!(root, args) do
    case System.cmd("git", args, cd: root, stderr_to_stdout: true) do
      {output, 0} -> String.trim(output)
      {output, status} -> flunk("git #{Enum.join(args, " ")} failed (#{status}): #{output}")
    end
  end

  defp sha256(contents), do: :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)
end
