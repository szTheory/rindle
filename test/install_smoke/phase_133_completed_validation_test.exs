defmodule Rindle.InstallSmoke.Phase133CompletedValidationTest do
  use ExUnit.Case, async: true

  @root Path.expand("../..", __DIR__)
  @phase_dir Path.join(@root, ".planning/phases/133-evidence-charter-and-live-truth")

  test "completed Phase 133 exposes zero pending gap-closure plans" do
    roadmap = File.read!(Path.join(@root, ".planning/ROADMAP.md"))

    assert roadmap =~ "**Plans**: 17/17 plans executed; 0 pending gap closure"

    for plan <- 11..17 do
      summary = Path.join(@phase_dir, "133-#{plan}-SUMMARY.md")
      assert File.exists?(summary), "missing completed summary: #{summary}"
      assert File.read!(summary) =~ "status: complete"
    end

    receipt =
      @phase_dir
      |> Path.join("133-NIGHTLY-EVIDENCE.json")
      |> File.read!()
      |> Jason.decode!()

    assert receipt["schema_version"] == 2
    assert receipt["subject_sha"] == "08d2f4f55fb2f59319a371de56606b2e925e6d54"
    assert receipt["run_id"] == 34_550_391_882
    assert receipt["run_attempt"] == 1
    assert receipt["conclusion"] == "success"
    assert receipt["strict_verdict"]["verdict"] == "green"
  end
end
