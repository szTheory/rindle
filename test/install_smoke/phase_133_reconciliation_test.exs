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

  @tag :disclosure_canary
  test "T-133-34-05: reconciliation diagnostics never echo raw planning canaries", %{
    fixture: fixture
  } do
    canary = "Authorization: Bearer phase133-secret-canary"
    mutate_validation(fixture, &String.replace(&1, "19/19", canary, global: false))

    {output, status} = run_validator(fixture)
    assert status != 0
    refute output =~ canary
    assert byte_size(output) < 2_048
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

  test "standalone validator never falls back outside MIX_BUILD_PATH", %{fixture: fixture} do
    isolated_build = Path.join(fixture.root, "isolated-build-without-yaml")
    File.mkdir_p!(isolated_build)

    {output, status} =
      run_validator_with(fixture, "elixir", [@script], [{"MIX_BUILD_PATH", isolated_build}])

    assert status != 0
    assert output =~ "compiled YAML dependency is unavailable under the configured build root"
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

  defp run_validator_with(fixture, executable, arguments, extra_env \\ []) do
    env = Map.new([{"MIX_QUIET", "1"} | extra_env])

    env =
      case System.get_env("MIX_BUILD_PATH") do
        build_path when is_binary(build_path) -> Map.put_new(env, "MIX_BUILD_PATH", build_path)
        _ -> env
      end

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
      env: Map.to_list(env),
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

defmodule Rindle.InstallSmoke.Phase133Reconciliation42Test do
  use ExUnit.Case, async: true

  @async_safety_allow [:file_mutation]
  def __async_safety_allow__, do: @async_safety_allow

  @repo_root Path.expand("../..", __DIR__)
  @phase_rel ".planning/phases/133-evidence-charter-and-live-truth"
  @census Path.join(@repo_root, Path.join(@phase_rel, "133-EVIDENCE-CENSUS.json"))
  @validator Path.join(@repo_root, "scripts/maintainer/validate_phase_133_reconciliation.exs")
  @branch_heading "## Branch-Aware Validation Addendum (Plans 33–37)"
  @plans_50_heading "## Plans 50–52 Gap-Closure Addendum"
  @latest_heading "## Plans 43–49 Gap-Closure Addendum"
  @requirements ~w(EVID-01 EVID-02 EVID-03 EVID-04 TRUTH-08)

  test "accepts the first live 38/42 lifecycle state" do
    fixture = write_fixture!()
    set_state!(fixture, :post_38)

    assert {output, 0} = run_validator(fixture)

    assert output ==
             "phase 133 reconciliation valid: 35 completed, 3 halted, 4 pending plans, " <>
               "38/42 summarized, 53 validation records\n"
  end

  test "accepts every reachable 42-plan authorization, stop, failure, and success state" do
    cases = [
      {:post_39, {36, 3, 3, 39}},
      {:post_40, {37, 3, 2, 40}},
      {:authorized, {38, 3, 1, 41}},
      {:stopped, {37, 4, 1, 41}},
      {:failed, {38, 4, 0, 42}},
      {:qualified_success, {39, 3, 0, 42}}
    ]

    for {lifecycle, {completed, halted, pending, summarized}} <- cases do
      fixture = write_fixture!()
      set_state!(fixture, lifecycle)

      assert {output, 0} = run_validator(fixture)
      assert output =~ "#{completed} completed, #{halted} halted"
      assert output =~ "#{pending} pending plans, #{summarized}/42 summarized"
    end
  end

  test "rejects every one-step 42-plan authority contradiction with bounded diagnostics" do
    cases = [
      {:post_38, :roadmap_count, "roadmap detail"},
      {:post_38, :missing_baseline_halt, "Plans 27, 32, and 37"},
      {:post_40, :checked_halted_row, "Plan 37 must remain unchecked"},
      {:post_40, :out_of_branch_halt, "roadmap detail"},
      {:authorized, :premature_requirements, "requirement EVID-01"},
      {:qualified_success, :pending_requirements, "requirements must be complete"},
      {:qualified_success, :receipt_subject, "canonical receipt digest"},
      {:post_39, :state_count, "STATE completed_plans"},
      {:post_39, :progress_count, "roadmap Progress row"}
    ]

    for {lifecycle, mutation, diagnostic} <- cases do
      fixture = write_fixture!()
      set_state!(fixture, lifecycle)
      mutate!(fixture, mutation)

      assert {output, status} = run_validator(fixture)
      assert status != 0
      assert output =~ diagnostic
      assert byte_size(output) < 2_048
    end
  end

  test "rejects drift in the exact Plan 41 authorization and halted Plan 42 tuple" do
    mutations = [
      {41, "subject_sha: c83f61379ad5033efef9afa7b5bc88913080bae2",
       "subject_sha: a83f61379ad5033efef9afa7b5bc88913080bae2"},
      {41, "authorized_ref: refs/heads/phase-133-evidence-c83f61379ad5",
       "authorized_ref: refs/heads/phase-133-evidence-a83f61379ad5"},
      {42, "run_id: 34768317696", "run_id: 34768317697"},
      {42, "run_attempt: 1", "run_attempt: 2"},
      {42, "qualification: failed", "qualification: success"},
      {42, "terminal_automation: halted", "terminal_automation: passed"},
      {42, "requirements_completed: []", "requirements_completed: [EVID-01]"},
      {42, "receipt_sha256: 1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4",
       "receipt_sha256: 2cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4"}
    ]

    for {plan, before, replacement} <- mutations do
      fixture = write_fixture!()
      set_state!(fixture, :failed)
      path = summary_path(fixture.root, plan)
      mutate_file!(path, &String.replace(&1, before, replacement, global: false))

      assert {output, status} = run_validator(fixture)
      assert status != 0

      assert output =~
               if(plan == 41, do: "Plan 41 authorization", else: "exact immutable Plan 42")

      assert byte_size(output) < 2_048
    end
  end

  test "rejects digest-consistent schema-free JSON on the terminal success branch" do
    fixture = write_fixture!()
    set_state!(fixture, :qualified_success)
    receipt_path = Path.join(fixture.root, "#{@phase_rel}/133-NIGHTLY-EVIDENCE.json")
    receipt = Jason.encode!(%{"subject_sha" => String.duplicate("a", 40)}) <> "\n"
    File.write!(receipt_path, receipt)
    summary = summary_path(fixture.root, 42)

    mutate_file!(summary, fn contents ->
      Regex.replace(~r/^receipt_sha256: .*$/m, contents, "receipt_sha256: #{sha256(receipt)}")
    end)

    assert {output, status} = run_validator(fixture)
    assert status != 0
    assert output =~ "canonical receipt schema is incomplete"
  end

  test "repair inventory binds every changed file to its exact Git commit range" do
    fixture = write_fixture!()
    phase_dir = Path.join(fixture.root, @phase_rel)

    File.cp!(
      Path.join(@repo_root, "#{@phase_rel}/133-47-PLAN.md"),
      Path.join(phase_dir, "133-47-PLAN.md")
    )

    git!(fixture.root, ["add", "."])
    git!(fixture.root, ["commit", "--quiet", "-m", "inventory parent"])
    parent = git!(fixture.root, ["rev-parse", "HEAD"])

    changed_path = "scripts/ci/test_compat_115_26.sh"
    changed_file = Path.join(fixture.root, changed_path)
    File.mkdir_p!(Path.dirname(changed_file))
    File.write!(changed_file, "#!/usr/bin/env bash\nexit 0\n")
    git!(fixture.root, ["add", changed_path])
    git!(fixture.root, ["commit", "--quiet", "-m", "inventory repair"])
    repair = git!(fixture.root, ["rev-parse", "HEAD"])

    next_path = "lib/rindle/domain/media_provider_asset.ex"
    next_file = Path.join(fixture.root, next_path)
    File.mkdir_p!(Path.dirname(next_file))
    File.write!(next_file, "defmodule Rindle.Domain.MediaProviderAsset do\nend\n")
    git!(fixture.root, ["add", next_path])
    git!(fixture.root, ["commit", "--quiet", "-m", "inventory follow-up repair"])
    next_repair = git!(fixture.root, ["rev-parse", "HEAD"])

    inventory = """

    <repair-inventory>
    <parent-sha>#{parent}</parent-sha>
    <repair-sha>#{repair}</repair-sha>
    <mapping><path>#{changed_path}</path><task>133-47-01</task><kind>compatibility-probe</kind></mapping>
    </repair-inventory>

    <repair-inventory>
    <parent-sha>#{repair}</parent-sha>
    <repair-sha>#{next_repair}</repair-sha>
    <mapping><path>#{next_path}</path><task>133-47-01</task><kind>module-compatibility-fix</kind></mapping>
    </repair-inventory>
    """

    File.write!(fixture.validation, File.read!(fixture.validation) <> inventory)

    assert {output, 0} = run_validator(fixture, ["--check-repair-inventory"])
    assert output =~ "phase 133 reconciliation valid"

    mutate_file!(
      fixture.validation,
      &String.replace(
        &1,
        "<mapping><path>#{changed_path}</path><task>133-47-01</task><kind>compatibility-probe</kind></mapping>",
        "<mapping><path>.github/workflows/nightly.yml</path><task>133-47-01</task><kind>compatibility-probe</kind></mapping>"
      )
    )

    assert {output, status} = run_validator(fixture, ["--check-repair-inventory"])
    assert status != 0
    assert output =~ "repair inventory file set differs"

    mutate_file!(fixture.validation, fn contents ->
      String.replace(contents, "<task>133-47-01</task>", "<task>133-47-02</task>")
    end)

    assert {output, status} = run_validator(fixture, ["--check-repair-inventory"])
    assert status != 0
    assert output =~ "mappings must name Task 133-47-01"
  end

  test "production reconciliation rejects drift in the Plans 43-52 map" do
    fixture = write_fixture!()
    append_gap_closure_section!(fixture)
    extend_gap_fixture_to_52!(fixture)

    assert {output, 0} = run_validator(fixture)
    assert output =~ "validation records"

    for {mutation, diagnostic} <- [
          {&String.replace(&1, ~s(key="133-43-01:1"), ~s(key="133-43-01:999"), global: false),
           "pending mapping is missing"},
          {&mutate_gap_record(
             &1,
             "133-48-02:1",
             "<acceptance-credit>authorization-only</acceptance-credit>",
             "<acceptance-credit>pending</acceptance-credit>"
           ), "acceptance credit differs"},
          {&String.replace(&1, ~s(key="133-50-01:1"), ~s(key="133-50-01:9"), global: false),
           "pending mapping is missing"},
          {&mutate_gap_record(
             &1,
             "133-50-01:1",
             "--only package_authority --seed 0",
             "--only forged --seed 0"
           ), "mapping command text differs"},
          {&mutate_gap_record(
             &1,
             "133-50-01:1",
             "no package-authority test runs",
             "package-authority test passes"
           ), "mapping failure text differs"},
          {&String.replace(&1, ~s(key="133-52-03:1"), ~s(key="133-52-03:9"), global: false),
           "pending mapping is missing"}
        ] do
      original = File.read!(fixture.validation)
      File.write!(fixture.validation, mutation.(original))

      assert {output, status} = run_validator(fixture)
      assert status != 0
      assert output =~ diagnostic, "expected #{diagnostic}; got #{output}"

      File.write!(fixture.validation, original)
    end

    plan52 = Path.join(fixture.root, "#{@phase_rel}/133-52-PLAN.md")
    File.rm!(plan52)
    assert {output, status} = run_validator(fixture)
    assert status != 0
    assert output =~ "missing plan 133-52"

    fixture = write_fixture!()
    append_gap_closure_section!(fixture)
    extend_gap_fixture_to_52!(fixture)
    mark_plans_complete!(fixture, 43..47)

    File.write!(
      summary_path(fixture.root, 48),
      "---\nstatus: complete\ndecision: authorize\nsubject_sha: #{String.duplicate("a", 40)}\nauthorized_ref: refs/heads/phase-133-evidence-aaaaaaaaaaaa\nrequirements-completed: []\n---\n"
    )

    mark_records_complete!(fixture, [48])
    mark_roadmap_complete!(fixture, [48])
    assert {output, status} = run_validator(fixture)
    assert status != 0
    assert output =~ "Plan 52 must be complete before Plan 48"

    fixture = write_fixture!()
    append_gap_closure_section!(fixture)
    extend_gap_fixture_to_52!(fixture)
    mark_plans_complete!(fixture, 43..47)

    File.write!(
      summary_path(fixture.root, 49),
      "---\nstatus: complete\nrequirements-completed: []\n---\n"
    )

    mark_records_complete!(fixture, [49])
    mark_roadmap_complete!(fixture, [49])
    assert {output, status} = run_validator(fixture)
    assert status != 0
    assert output =~ "Plan 48 must complete authorization before Plan 49"
  end

  @tag :plan48_report_gate
  test "allows a Plan 48 report-gate halt before a human decision, with no pair or credit" do
    fixture = write_fixture!()
    append_gap_closure_section!(fixture)
    extend_gap_fixture_to_52!(fixture)
    mark_plans_complete!(fixture, [43, 44, 45, 46, 47, 50, 51, 52])

    roadmap = File.read!(fixture.roadmap)

    roadmap =
      String.replace(
        roadmap,
        "**Plans**: 46/52 plans executed summarized; 43 completed, " <>
          "Plans 133-27, 133-32, and 133-37 halted with immutable attempts preserved, " <>
          "6 gap-closure plans pending.",
        "**Plans**: 47/52 plans executed summarized; 43 completed, " <>
          "Plans 133-27, 133-32, and 133-37 halted with immutable attempts preserved, " <>
          "Plan 133-48 halted before a decision, 5 gap-closure plans pending."
      )
      |> String.replace("| 46/52 |", "| 47/52 |")

    File.write!(fixture.roadmap, roadmap)

    state =
      File.read!(fixture.state)
      |> String.replace("completed_plans: 46", "completed_plans: 47")
      |> String.replace("Plan: 47 of 52", "Plan: 49 of 52")
      |> String.replace("status: executing", "status: blocked")
      |> String.replace("Status: EXECUTING", "Status: BLOCKED")

    File.write!(fixture.state, state)

    File.write!(
      summary_path(fixture.root, 48),
      "---\nstatus: halted\nreport-gate: blocked\nhalt_reason: security report gate failed\nrequirements-completed: []\n---\n"
    )

    validation = File.read!(fixture.validation)
    assert validation =~ "<pending-validation key=\"133-48-01:1\">"
    assert validation =~ "<state>pending — not executed</state>"
    refute validation =~ "<state>halted — blocking gate</state>"
    assert {output, 0} = run_validator(fixture)
    assert output =~ "phase 133 reconciliation valid"

    summary = File.read!(summary_path(fixture.root, 48))

    for mutation <- [
          String.replace(summary, "report-gate: blocked", "report-gate: passed"),
          String.replace(
            summary,
            "requirements-completed: []",
            "requirements-completed: []\nauthorized_ref: refs/heads/phase-133-evidence-aaaaaaaaaaaa"
          )
        ] do
      File.write!(summary_path(fixture.root, 48), mutation)
      assert {output, status} = run_validator(fixture)
      assert status != 0

      assert output =~ "133-48",
             "unexpected rejection diagnostic: #{output}"
    end
  end

  @tag :plan48_report_gate
  test "keeps Plan 48 pending at the human checkpoint after exact report gates pass" do
    fixture = write_fixture!()
    append_gap_closure_section!(fixture)
    extend_gap_fixture_to_52!(fixture)
    mark_plans_complete!(fixture, [43, 44, 45, 46, 47, 50, 51, 52])

    roadmap = File.read!(fixture.roadmap)

    roadmap =
      String.replace(
        roadmap,
        "**Plans**: 46/52 plans executed summarized; 43 completed, " <>
          "Plans 133-27, 133-32, and 133-37 halted with immutable attempts preserved, " <>
          "6 gap-closure plans pending.",
        "**Plans**: 47/52 plans executed summarized; 43 completed, " <>
          "Plans 133-27, 133-32, and 133-37 halted with immutable attempts preserved, " <>
          "Plan 133-48 halted before a decision, 5 gap-closure plans pending."
      )
      |> String.replace("| 46/52 |", "| 47/52 |")

    File.write!(fixture.roadmap, roadmap)

    state =
      File.read!(fixture.state)
      |> String.replace("completed_plans: 46", "completed_plans: 47")
      |> String.replace("Plan: 47 of 52", "Plan: 49 of 52")
      |> String.replace("status: executing", "status: blocked")
      |> String.replace("Status: EXECUTING", "Status: BLOCKED")

    File.write!(fixture.state, state)

    subject = git!(fixture.root, ["rev-parse", "HEAD"])
    census =
      @census
      |> File.read!()
      |> Jason.decode!()
      |> Map.put("subject_sha", subject)
      |> Jason.encode!()
      |> Kernel.<>("\n")

    census_path = Path.join(fixture.root, "#{@phase_rel}/133-EVIDENCE-CENSUS.json")
    File.write!(census_path, census)
    census_digest = sha256(census)
    proposed_ref = "refs/heads/phase-133-evidence-#{String.slice(subject, 0, 12)}"

    summary =
      """
      ---
      status: halted
      checkpoint: blocking-human-pending
      report-gate: pass
      subject_sha: #{subject}
      census_sha256: #{census_digest}
      proposed_ref: #{proposed_ref}
      proposed_ref_status: absent-read-only-lookup
      decision: null
      authorized_ref: null
      authorized_sha: null
      requirements-completed: []
      ---
      """

    File.write!(summary_path(fixture.root, 48), summary)
    frozen_prefix_before = binary_part(File.read!(fixture.validation), 0, 148_104)

    assert File.read!(fixture.validation) =~
             "<pending-validation key=\"133-48-01:1\">"

    assert File.read!(fixture.validation) =~
             "<pending-validation key=\"133-48-02:1\">"

    assert {output, 0} = run_validator(fixture)
    assert output =~ "phase 133 reconciliation valid"
    assert binary_part(File.read!(fixture.validation), 0, 148_104) == frozen_prefix_before

    minimal_census = Jason.encode!(%{"subject_sha" => subject}) <> "\n"
    minimal_digest = sha256(minimal_census)

    File.write!(census_path, minimal_census)

    File.write!(
      summary_path(fixture.root, 48),
      String.replace(summary, census_digest, minimal_digest)
    )

    assert {output, status} = run_validator(fixture)
    assert status != 0
    assert output =~ "133-48"

    File.write!(census_path, census)

    wrong_subject = String.duplicate("a", 40)
    wrong_subject_census =
      census
      |> Jason.decode!()
      |> Map.put("subject_sha", wrong_subject)
      |> Jason.encode!()
      |> Kernel.<>("\n")

    wrong_subject_digest = sha256(wrong_subject_census)
    File.write!(census_path, wrong_subject_census)

    File.write!(
      summary_path(fixture.root, 48),
      summary
      |> String.replace(subject, wrong_subject)
      |> String.replace(census_digest, wrong_subject_digest)
    )

    assert {output, status} = run_validator(fixture)
    assert status != 0
    assert output =~ "133-48"

    malformed_census =
      census
      |> Jason.decode!()
      |> update_in(["taxonomy", Access.at(0)], fn _row -> 5 end)
      |> Jason.encode!()
      |> Kernel.<>("\n")

    malformed_digest = sha256(malformed_census)
    File.write!(census_path, malformed_census)
    File.write!(summary_path(fixture.root, 48), String.replace(summary, census_digest, malformed_digest))

    assert {output, status} = run_validator(fixture)
    assert status != 0
    refute output =~ "FunctionClauseError"

    File.write!(census_path, census)

    for mutation <- [
          String.replace(summary, proposed_ref, proposed_ref <> "-wrong"),
          String.replace(summary, census_digest, String.duplicate("0", 64)),
          String.replace(summary, subject, String.duplicate("b", 40)),
          String.replace(summary, "decision: null", "decision: authorize")
        ] do
      File.write!(summary_path(fixture.root, 48), mutation)
      assert {output, status} = run_validator(fixture)
      assert status != 0
      assert output =~ "133-48"
    end
  end

  defp mark_plans_complete!(fixture, plans) do
    Enum.each(plans, &File.write!(summary_path(fixture.root, &1), "---\nstatus: complete\n---\n"))
    mark_records_complete!(fixture, plans)
    mark_roadmap_complete!(fixture, plans)
  end

  defp mark_records_complete!(fixture, plans) do
    validation = File.read!(fixture.validation)

    updated =
      Regex.replace(
        ~r/<pending-validation key="133-(\d+)-[^"]+">.*?<\/pending-validation>/s,
        validation,
        fn record, plan_text ->
          plan = String.to_integer(plan_text)

          if plan in plans do
            record
            |> String.replace(
              "<state>pending — not executed</state>",
              "<state>passed — executed</state>"
            )
            |> String.replace(
              "<branch-status>pending — not executed</branch-status>",
              "<branch-status>passed — executed</branch-status>"
            )
          else
            record
          end
        end
      )

    File.write!(fixture.validation, updated)
  end

  defp mark_roadmap_complete!(fixture, plans) do
    current = 38
    completed_total = current + Enum.count(plans)
    completed = 35 + Enum.count(plans)
    pending = 52 - completed_total
    roadmap = File.read!(fixture.roadmap)

    old_detail =
      "**Plans**: #{current}/52 plans executed summarized; 35 completed, Plans 133-27, 133-32, and 133-37 halted with immutable attempts preserved, 14 gap-closure plans pending."

    new_detail =
      "**Plans**: #{completed_total}/52 plans executed summarized; #{completed} completed, Plans 133-27, 133-32, and 133-37 halted with immutable attempts preserved, #{pending} gap-closure plans pending."

    roadmap = String.replace(roadmap, old_detail, new_detail)
    roadmap = String.replace(roadmap, "| #{current}/52 |", "| #{completed_total}/52 |")

    roadmap =
      Enum.reduce(plans, roadmap, fn plan, acc ->
        String.replace(acc, "- [ ] 133-#{plan}-PLAN.md", "- [x] 133-#{plan}-PLAN.md")
      end)

    File.write!(fixture.roadmap, roadmap)

    state =
      File.read!(fixture.state)
      |> String.replace("completed_plans: #{current}", "completed_plans: #{completed_total}")
      |> String.replace("Plan: #{current + 1} of 52", "Plan: #{completed_total + 1} of 52")

    File.write!(fixture.state, state)
  end

  defp extend_gap_fixture_to_52!(fixture) do
    phase_dir = Path.join(fixture.root, @phase_rel)

    for plan <- 50..52 do
      source = Path.join(@repo_root, Path.join(@phase_rel, "133-#{plan}-PLAN.md"))
      destination = Path.join(phase_dir, "133-#{plan}-PLAN.md")
      File.cp!(source, destination)
      git!(fixture.root, ["add", Path.relative_to(destination, fixture.root)])
    end

    source_validation =
      File.read!(Path.join(@repo_root, Path.join(@phase_rel, "133-VALIDATION.md")))

    [_, section] = String.split(source_validation, @plans_50_heading, parts: 2)

    section =
      section
      |> String.replace("passed — executed", "pending — not executed")
      |> String.replace(
        "<state>passed — executed</state>",
        "<state>pending — not executed</state>"
      )

    File.write!(
      fixture.validation,
      File.read!(fixture.validation) <> @plans_50_heading <> section
    )

    roadmap = File.read!(fixture.roadmap)

    rows =
      Enum.map_join(43..52, "", fn plan ->
        "- [ ] 133-#{String.pad_leading(Integer.to_string(plan), 2, "0")}-PLAN.md\n"
      end)

    roadmap =
      roadmap
      |> String.replace("38/42 plans summarized", "38/52 plans executed summarized")
      |> String.replace("4 pending.", "14 gap-closure plans pending.")
      |> String.replace("| 38/42 |", "| 38/52 |")
      |> String.replace("### Phase 134: Next", rows <> "### Phase 134: Next")

    File.write!(fixture.roadmap, roadmap)

    File.write!(
      fixture.state,
      fixture.state
      |> File.read!()
      |> String.replace("total_plans: 42", "total_plans: 52")
      |> String.replace("Plan: 39 of 42", "Plan: 39 of 52")
    )
  end

  defp mutate_gap_record(validation, key, before, replacement) do
    [prefix, rest] = String.split(validation, ~s(<pending-validation key="#{key}">), parts: 2)
    [record, suffix] = String.split(rest, "</pending-validation>", parts: 2)

    prefix <>
      ~s(<pending-validation key="#{key}">) <>
      String.replace(record, before, replacement, global: false) <>
      "</pending-validation>" <> suffix
  end

  defp append_gap_closure_section!(fixture) do
    phase_dir = Path.join(fixture.root, @phase_rel)

    for plan <- 43..49 do
      source = Path.join(@repo_root, Path.join(@phase_rel, "133-#{plan}-PLAN.md"))
      destination = Path.join(phase_dir, "133-#{plan}-PLAN.md")
      File.cp!(source, destination)
      git!(fixture.root, ["add", Path.relative_to(destination, fixture.root)])
    end

    source_validation =
      File.read!(Path.join(@repo_root, Path.join(@phase_rel, "133-VALIDATION.md")))

    [_, section] = String.split(source_validation, @latest_heading, parts: 2)
    section = section |> String.split(@plans_50_heading, parts: 2) |> hd()

    section =
      section
      |> String.replace(
        "<branch-status>passed — executed</branch-status>",
        "<branch-status>pending — not executed</branch-status>"
      )
      |> String.replace(
        "<state>passed — executed</state>",
        "<state>pending — not executed</state>"
      )

    File.write!(fixture.validation, File.read!(fixture.validation) <> @latest_heading <> section)
  end

  test "production reconciliation rejects drift in every Plans 38-42 validation dimension" do
    cases = [
      {&String.replace(&1, ~s(key="133-38-01:1"), ~s(key="133-38-01:999"), global: false),
       "pending mapping is missing"},
      {&remove_first_closure_record/1, "pending mapping is missing"},
      {&duplicate_first_closure_record/1, "duplicate mapping key"},
      {&String.replace(&1, "bash scripts/ci/test_verify_nightly_run.sh", "manual command",
         global: false
       ), "mapping command text differs"},
      {&String.replace(&1, "<requirements>EVID-01,EVID-02", "<requirements>BAD-01,EVID-02",
         global: false
       ), "requirement IDs differ"},
      {&String.replace(&1, "<validation-level>repair-backstop", "<validation-level>manual",
         global: false
       ), "validation level differs"},
      {&String.replace(&1, "<branch-status>passed — executed", "<branch-status>manual",
         global: false
       ), "branch status differs"},
      {&String.replace(&1, "<acceptance-credit>authorization-only", "<acceptance-credit>pending",
         global: false
       ), "acceptance credit differs"},
      {&String.replace(
         &1,
         "<flagged-unresolved key=\"133-38-specless-context-boundary\">",
         "<flagged-unresolved key=\"133-38-other-boundary\">",
         global: false
       ), "flagged-unresolved boundaries differ"}
    ]

    for {mutation, diagnostic} <- cases do
      fixture = write_fixture!()
      set_state!(fixture, :post_38)
      mutate_file!(fixture.validation, &mutate_closure(&1, mutation))

      assert {output, status} = run_validator(fixture)
      assert status != 0
      assert output =~ diagnostic
      assert byte_size(output) < 2_048
    end
  end

  defp write_fixture! do
    root =
      Path.join(
        System.tmp_dir!(),
        "rindle-phase-133-reconciliation-42-#{System.unique_integer([:positive])}"
      )

    phase_dir = Path.join(root, @phase_rel)
    File.mkdir_p!(phase_dir)
    on_exit(fn -> File.rm_rf!(root) end)

    for plan <- 28..42 do
      File.cp!(
        Path.join(@repo_root, "#{@phase_rel}/133-#{plan}-PLAN.md"),
        Path.join(phase_dir, "133-#{plan}-PLAN.md")
      )
    end

    source_validation = File.read!(Path.join(@repo_root, "#{@phase_rel}/133-VALIDATION.md"))
    prefix = branch_prefix(source_validation)
    validation = Path.join(phase_dir, "133-VALIDATION.md")
    File.write!(validation, prefix)

    fixture = %{
      root: root,
      roadmap: Path.join(root, ".planning/ROADMAP.md"),
      state: Path.join(root, ".planning/STATE.md"),
      requirements: Path.join(root, ".planning/REQUIREMENTS.md"),
      validation: validation
    }

    set_state!(fixture, :post_38)
    git!(root, ["init", "--quiet"])
    git!(root, ["config", "user.email", "phase133@example.invalid"])
    git!(root, ["config", "user.name", "Phase 133 Fixture"])
    git!(root, ["add", ".planning"])
    git!(root, ["commit", "--quiet", "-m", "42-plan validation prefix"])
    prefix_ref = git!(root, ["rev-parse", "HEAD"])
    File.write!(validation, before_heading(source_validation, @latest_heading))

    Map.merge(fixture, %{prefix_ref: prefix_ref, prefix_sha256: sha256(prefix)})
  end

  defp branch_prefix(validation) do
    case :binary.match(validation, @branch_heading) do
      {offset, _length} -> binary_part(validation, 0, offset)
      :nomatch -> validation
    end
  end

  defp before_heading(validation, heading) do
    case :binary.match(validation, heading) do
      {offset, _length} -> binary_part(validation, 0, offset)
      :nomatch -> validation
    end
  end

  defp mutate_closure(validation, mutation) do
    [prefix, closure] = String.split(validation, "## Plans 38–42 Gap-Closure Addendum", parts: 2)
    prefix <> "## Plans 38–42 Gap-Closure Addendum" <> mutation.(closure)
  end

  defp remove_first_closure_record(closure) do
    Regex.replace(
      ~r/<pending-validation key="133-38-01:1">.*?<\/pending-validation>/s,
      closure,
      "",
      global: false
    )
  end

  defp duplicate_first_closure_record(closure) do
    [record] =
      Regex.run(~r/<pending-validation key="133-38-01:1">.*?<\/pending-validation>/s, closure)

    closure <> "\n" <> record
  end

  defp set_state!(fixture, lifecycle) do
    {tail, halted, requirements_complete?} = lifecycle_state(lifecycle)
    completed = MapSet.new(Enum.to_list(1..26) ++ [28, 29, 30, 31] ++ tail)
    halted = MapSet.new(halted)

    receipt =
      if lifecycle == :qualified_success do
        source =
          File.read!(Path.join(@repo_root, "#{@phase_rel}/133-NIGHTLY-EVIDENCE.json"))
          |> Jason.decode!()
          |> Map.put("subject_sha", String.duplicate("a", 40))
          |> Map.put("remote_ref", "refs/heads/phase-133-evidence-aaaaaaaaaaaa")
          |> Map.put("run_id", 123_456)
          |> Map.put("run_attempt", 1)

        verifier = Path.join(fixture.root, "scripts/ci/verify_nightly_run.sh")
        File.mkdir_p!(Path.dirname(verifier))
        File.write!(verifier, "#!/bin/sh\n[ \"$1\" = verify-receipt ]\n")
        File.chmod!(verifier, 0o755)
        Jason.encode!(source) <> "\n"
      else
        Jason.encode!(%{"subject_sha" => String.duplicate("a", 40)}) <> "\n"
      end

    File.write!(Path.join(fixture.root, "#{@phase_rel}/133-NIGHTLY-EVIDENCE.json"), receipt)

    for plan <- 1..42 do
      write_summary!(fixture.root, plan, completed, halted, lifecycle, receipt)
    end

    summarized = MapSet.size(completed) + MapSet.size(halted)
    pending = 42 - summarized

    rows =
      Enum.map_join(1..42, "", fn plan ->
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

      #{roadmap_detail(lifecycle, summarized, MapSet.size(completed), pending)}

      #{rows}
      ### Phase 134: Next

      ## Progress

      | Phase | Plans Complete | Status | Completed |
      |-------|----------------|--------|-----------|
      | 133. Evidence Charter and Live Truth | #{summarized}/42 | #{progress_status(lifecycle)} | #{progress_date(lifecycle)} |
      """
    )

    File.write!(
      fixture.state,
      """
      ---
      current_phase: 133
      status: #{state_status(lifecycle)}
      progress:
        total_plans: 42
        completed_plans: #{summarized}
      ---

      ## Current Position

      Plan: #{state_plan(lifecycle, summarized)} of 42
      Status: #{String.upcase(state_status(lifecycle))}
      """
    )

    File.write!(fixture.requirements, requirements_fixture(requirements_complete?))
  end

  defp lifecycle_state(:post_38),
    do: {[33, 34, 35, 36, 38], [27, 32, 37], false}

  defp lifecycle_state(:post_39),
    do: {[33, 34, 35, 36, 38, 39], [27, 32, 37], false}

  defp lifecycle_state(:post_40),
    do: {[33, 34, 35, 36, 38, 39, 40], [27, 32, 37], false}

  defp lifecycle_state(:authorized),
    do: {[33, 34, 35, 36, 38, 39, 40, 41], [27, 32, 37], false}

  defp lifecycle_state(:stopped),
    do: {[33, 34, 35, 36, 38, 39, 40], [27, 32, 37, 41], false}

  defp lifecycle_state(:failed),
    do: {[33, 34, 35, 36, 38, 39, 40, 41], [27, 32, 37, 42], false}

  defp lifecycle_state(:qualified_success),
    do: {[33, 34, 35, 36, 38, 39, 40, 41, 42], [27, 32, 37], true}

  defp roadmap_detail(:stopped, _summarized, _completed, _pending) do
    "**Plans**: 41/42 plans summarized; 37 completed, Plans 133-27, 133-32, 133-37, " <>
      "and 133-41 halted with immutable attempts preserved, Plan 133-42 blocked."
  end

  defp roadmap_detail(:failed, _summarized, _completed, _pending) do
    "**Plans**: 42/42 plans summarized; 38 completed, Plans 133-27, 133-32, 133-37, " <>
      "and 133-42 halted with immutable attempts preserved, 0 pending."
  end

  defp roadmap_detail(_lifecycle, summarized, completed, pending) do
    "**Plans**: #{summarized}/42 plans summarized; #{completed} completed, " <>
      "Plans 133-27, 133-32, and 133-37 halted with immutable attempts preserved, " <>
      "#{pending} pending."
  end

  defp write_summary!(root, plan, completed, halted, lifecycle, receipt) do
    path = summary_path(root, plan)
    File.mkdir_p!(Path.dirname(path))

    if MapSet.member?(completed, plan) do
      File.write!(path, complete_summary(plan, lifecycle, receipt))
    else
      write_halted_summary_or_remove!(path, plan, halted)
    end
  end

  defp write_halted_summary_or_remove!(path, plan, halted) do
    case {MapSet.member?(halted, plan), halted_summary(plan)} do
      {true, summary} when is_binary(summary) -> File.write!(path, summary)
      _other -> File.rm(path)
    end
  end

  defp halted_summary(27), do: halted_27_summary()
  defp halted_summary(32), do: halted_32_summary()
  defp halted_summary(37), do: halted_37_summary()
  defp halted_summary(41), do: halted_41_summary()
  defp halted_summary(42), do: halted_42_summary()
  defp halted_summary(_plan), do: nil

  defp complete_summary(41, _lifecycle, _receipt) do
    """
    ---
    status: complete
    decision: authorize
    subject_sha: c83f61379ad5033efef9afa7b5bc88913080bae2
    authorized_ref: refs/heads/phase-133-evidence-c83f61379ad5
    requirements-completed: []
    ---
    """
  end

  defp complete_summary(42, :qualified_success, receipt) do
    """
    ---
    status: complete
    qualification: verified
    terminal_automation: passed
    subject_sha: #{String.duplicate("a", 40)}
    published_ref: refs/heads/phase-133-evidence-aaaaaaaaaaaa
    run_id: 123456
    run_attempt: 1
    receipt_sha256: #{sha256(receipt)}
    requirements_completed: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
    ---
    """
  end

  defp complete_summary(_plan, _lifecycle, _receipt), do: "---\nstatus: complete\n---\n"

  defp halted_27_summary do
    """
    ---
    status: halted
    halt_reason: "Dispatch-owned Nightly run 34661043059 attempt 1 completed failure."
    ---
    Run `34661043059`, attempt `1`, subject `0f8189ddeed7e7a52b5c7464f17b70ab44596c33`, ref `refs/heads/phase-133-evidence-0f8189ddeed7`.
    """
  end

  defp halted_32_summary do
    """
    ---
    status: halted
    halt_reason: "Dispatch-owned Nightly run 34670574306 could not be qualified."
    ---
    Run `34670574306`, subject `e70623e9ea956c750904af574f47221cc472d2f2`, ref `refs/heads/phase-133-evidence-e70623e9ea95`.
    """
  end

  defp halted_37_summary,
    do: "---\nstatus: halted\nhalt_reason: immutable terminal automation failure\n---\n"

  defp halted_41_summary,
    do: "---\nstatus: halted\ndecision: stop\n---\n"

  defp halted_42_summary do
    """
    ---
    status: halted
    halt_reason: "immutable run 34768317696 exhausted after compatibility failure"
    qualification: failed
    terminal_automation: halted
    requirements_completed: []
    subject_sha: c83f61379ad5033efef9afa7b5bc88913080bae2
    published_ref: refs/heads/phase-133-evidence-c83f61379ad5
    run_id: 34768317696
    run_attempt: 1
    receipt_sha256: 1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4
    ---
    """
  end

  defp progress_status(:qualified_success), do: "Complete"
  defp progress_status(_lifecycle), do: "In Progress"
  defp progress_date(:qualified_success), do: "2026-09-13"
  defp progress_date(_lifecycle), do: ""

  defp state_status(:qualified_success), do: "complete"
  defp state_status(lifecycle) when lifecycle in [:stopped, :failed], do: "blocked"
  defp state_status(_lifecycle), do: "executing"

  defp state_plan(lifecycle, _summarized)
       when lifecycle in [:qualified_success, :stopped, :failed],
       do: 42

  defp state_plan(_lifecycle, summarized), do: summarized + 1

  defp mutate!(fixture, :roadmap_count) do
    mutate_file!(
      fixture.roadmap,
      &String.replace(&1, "38/42 plans summarized", "37/42 plans summarized")
    )
  end

  defp mutate!(fixture, :missing_baseline_halt),
    do: File.rm!(summary_path(fixture.root, 37))

  defp mutate!(fixture, :checked_halted_row) do
    mutate_file!(
      fixture.roadmap,
      &String.replace(&1, "- [ ] 133-37-PLAN.md", "- [x] 133-37-PLAN.md")
    )
  end

  defp mutate!(fixture, :out_of_branch_halt),
    do: File.write!(summary_path(fixture.root, 41), halted_41_summary())

  defp mutate!(fixture, :premature_requirements),
    do: File.write!(fixture.requirements, requirements_fixture(true))

  defp mutate!(fixture, :pending_requirements),
    do: File.write!(fixture.requirements, requirements_fixture(false))

  defp mutate!(fixture, :receipt_subject) do
    receipt_path = Path.join(fixture.root, "#{@phase_rel}/133-NIGHTLY-EVIDENCE.json")

    File.write!(
      receipt_path,
      Jason.encode!(%{"subject_sha" => String.duplicate("b", 40)}) <> "\n"
    )
  end

  defp mutate!(fixture, :state_count) do
    mutate_file!(fixture.state, &String.replace(&1, "completed_plans: 39", "completed_plans: 38"))
  end

  defp mutate!(fixture, :progress_count) do
    mutate_file!(fixture.roadmap, &String.replace(&1, "| 39/42 |", "| 38/42 |"))
  end

  defp mutate_file!(path, fun), do: File.write!(path, fun.(File.read!(path)))

  defp requirements_fixture(complete?) do
    checkbox = if complete?, do: "x", else: " "
    status = if complete?, do: "Complete", else: "Pending"

    Enum.map_join(@requirements, "\n", fn id ->
      "- [#{checkbox}] **#{id}**: fixture requirement\n| #{id} | Phase 133 | #{status} |"
    end)
  end

  defp run_validator(fixture, extra_args \\ []) do
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
        fixture.prefix_ref,
        "--fixture-active-prefix-sha256",
        fixture.prefix_sha256,
        "--fixture-topology",
        "branch-42"
      ] ++ extra_args,
      cd: @repo_root,
      env: [{"MIX_QUIET", "1"}],
      stderr_to_stdout: true
    )
  end

  defp summary_path(root, plan) do
    id = String.pad_leading(Integer.to_string(plan), 2, "0")
    Path.join(root, Path.join(@phase_rel, "133-#{id}-SUMMARY.md"))
  end

  defp git!(root, args) do
    case System.cmd("git", args, cd: root, stderr_to_stdout: true) do
      {output, 0} -> String.trim(output)
      {output, status} -> flunk("git #{Enum.join(args, " ")} failed (#{status}): #{output}")
    end
  end

  defp sha256(contents), do: :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)
end
