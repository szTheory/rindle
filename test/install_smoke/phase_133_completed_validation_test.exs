defmodule Rindle.InstallSmoke.Phase133CompletedValidationTest do
  use ExUnit.Case, async: true

  @root Path.expand("../..", __DIR__)
  @validator Path.join(@root, "scripts/maintainer/validate_phase_133_reconciliation.exs")

  test "completed Phase 133 validator exposes zero pending gap-closure plans" do
    assert {output, 0} =
             System.cmd("elixir", [@validator, "--root", @root], stderr_to_stdout: true)

    assert output ==
             "phase 133 reconciliation valid: 17 completed, 0 pending plans, 27 historical verification pairs\n"
  end
end
