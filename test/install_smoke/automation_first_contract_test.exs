defmodule Rindle.InstallSmoke.AutomationFirstContractTest do
  use ExUnit.Case, async: true

  @script Path.expand("../../scripts/maintainer/automation_first_contract.sh", __DIR__)

  setup do
    phase_dir =
      Path.join(
        System.tmp_dir!(),
        "rindle-automation-first-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(phase_dir)
    on_exit(fn -> File.rm_rf!(phase_dir) end)
    %{phase_dir: phase_dir}
  end

  test "accepts a fully automated phase and explicit authorization-only checkpoints", %{
    phase_dir: phase_dir
  } do
    File.write!(Path.join(phase_dir, "132-01-PLAN.md"), """
    ---
    autonomous: true
    ---
    <task type="checkpoint:human-action" gate="blocking">
      <purpose>authorization</purpose>
      <name>Authorize an irreversible publish</name>
    </task>
    """)

    File.write!(Path.join(phase_dir, "132-VALIDATION.md"), """
    ## Manual-Only Verifications

    None. Every requirement has an automated acceptance command.
    """)

    assert {output, 0} = run_contract(phase_dir)
    assert output =~ "automation-first contract passed"
  end

  test "rejects human verification checkpoints", %{phase_dir: phase_dir} do
    File.write!(Path.join(phase_dir, "132-01-PLAN.md"), """
    <task type="checkpoint:human-verify" gate="blocking">
      <name>Look at the result</name>
    </task>
    """)

    assert {output, 1} = run_contract(phase_dir)
    assert output =~ "checkpoint:human-verify"
  end

  test "rejects requirement-bearing human actions and manual validation rows", %{
    phase_dir: phase_dir
  } do
    File.write!(Path.join(phase_dir, "132-01-PLAN.md"), """
    <task type="checkpoint:human-action" gate="blocking">
      <name>Collect acceptance evidence</name>
      <acceptance_criteria>The requirement is accepted by a person.</acceptance_criteria>
    </task>
    """)

    File.write!(Path.join(phase_dir, "132-VALIDATION.md"), """
    ## Manual-Only Verifications

    | Behavior | Requirement | Why Manual | Test Instructions |
    | --- | --- | --- | --- |
    | Live timing | CI-14 | external | Click labels ten times. |

    | 132-01 | live acceptance | manual/external | pending |
    """)

    assert {output, 1} = run_contract(phase_dir)
    assert output =~ "human-action checkpoint is not authorization-only"
    assert output =~ "manual/external"
    assert output =~ "manual-only verification row"
  end

  test "rejects reordered and single-quoted human-action task markup", %{phase_dir: phase_dir} do
    File.write!(Path.join(phase_dir, "132-02-PLAN.md"), """
    <task gate='blocking' data-kind="credential" type='checkpoint:human-action'>
      <purpose>authorization</purpose>
      <verification>Human approval closes SAFE-02.</verification>
    </task>
    <task type="checkpoint:human-action" gate='blocking'>
      <purpose>credential-bootstrap</purpose>
    </task>
    <task gate="blocking" type='checkpoint:human-action'>
      <purpose>authorization</purpose>
    """)

    assert {output, 1} = run_contract(phase_dir)

    assert output =~
             "authorization checkpoint may not carry requirement acceptance or verification"

    assert output =~ "unclosed human-action checkpoint"
  end

  test "rejects multiline human actions while ignoring commented markup", %{phase_dir: phase_dir} do
    File.write!(Path.join(phase_dir, "132-03-PLAN.md"), """
    <!--
    <task type="checkpoint:human-action">
      <purpose>authorization</purpose>
    </task>
    -->
    <task
      gate='blocking'
      type='checkpoint:human-action'
    >
      <purpose>authorization</purpose>
      <verification>Human approval closes SAFE-02.</verification>
    </task>
    """)

    assert {output, 1} = run_contract(phase_dir)

    assert output =~
             "authorization checkpoint may not carry requirement acceptance or verification"
  end

  test "classifies large authorization blocks without a grep broken-pipe race", %{
    phase_dir: phase_dir
  } do
    padding = String.duplicate("x", 200_000)

    File.write!(Path.join(phase_dir, "132-03-PLAN.md"), """
    <task type="checkpoint:human-action" gate="blocking">
      <purpose>authorization</purpose>
      #{padding}
      <verification>Human approval closes SAFE-02.</verification>
    </task>
    """)

    assert {output, 1} = run_contract(phase_dir)
    refute output =~ "Broken pipe"
    refute output =~ "human-action checkpoint is not authorization-only"

    assert output =~
             "authorization checkpoint may not carry requirement acceptance or verification"
  end

  test "fails closed for an unclosed multiline human-action opener", %{phase_dir: phase_dir} do
    File.write!(Path.join(phase_dir, "132-04-PLAN.md"), """
    <!-- <task type="checkpoint:human-action">commented decoy -->
    <task
      type="checkpoint:human-action"
      gate="blocking">
      <purpose>credential-bootstrap</purpose>
    """)

    assert {output, 1} = run_contract(phase_dir)
    assert output =~ "unclosed human-action checkpoint"
  end

  test "fails closed when a human-action opener reaches EOF before its closing bracket", %{
    phase_dir: phase_dir
  } do
    File.write!(Path.join(phase_dir, "132-05-PLAN.md"), """
    <!-- <task type="checkpoint:human-action">commented decoy -->
    <task
      gate='blocking'
      type='checkpoint:human-action'
    """)

    assert {output, 1} = run_contract(phase_dir)
    assert output =~ "unclosed human-action checkpoint"
  end

  test "skips archived planning state when the active phases directory is absent", %{
    phase_dir: phase_dir
  } do
    repo_dir = Path.join(phase_dir, "archived-repo")
    script = Path.join(repo_dir, "scripts/maintainer/automation_first_contract.sh")
    state = Path.join(repo_dir, ".planning/STATE.md")

    File.mkdir_p!(Path.dirname(script))
    File.mkdir_p!(Path.dirname(state))
    File.cp!(@script, script)
    File.write!(state, "current_phase: null\n")

    assert {_output, 0} = System.cmd("git", ["init", "--quiet"], cd: repo_dir)

    assert {output, 0} =
             System.cmd("bash", [script], cd: repo_dir, stderr_to_stdout: true)

    assert output =~ "phase null has no active directory; skipped"
  end

  defp run_contract(phase_dir) do
    System.cmd("bash", [@script, "--phase-dir", phase_dir], stderr_to_stdout: true)
  end
end
