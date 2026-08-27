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
    assert output =~ "authorization checkpoint may not carry requirement acceptance or verification"
    assert output =~ "unclosed human-action checkpoint"
  end

  defp run_contract(phase_dir) do
    System.cmd("bash", [@script, "--phase-dir", phase_dir], stderr_to_stdout: true)
  end
end
