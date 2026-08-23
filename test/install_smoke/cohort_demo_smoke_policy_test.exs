defmodule Rindle.InstallSmoke.CohortDemoSmokePolicyTest do
  @moduledoc """
  Locks the seeded-row probe against `pipefail` false negatives.

  `grep -q` may close a live curl pipeline after the first match, which makes
  curl exit with code 23 and turns a successful seed proof into a red CI job.
  """
  use ExUnit.Case, async: true

  @script_path Path.expand("../../scripts/ci/cohort_demo_smoke.sh", __DIR__)

  test "the seeded-row probe matches a buffered response" do
    script = File.read!(@script_path)

    refute Regex.match?(~r/curl[^\n]*\|\s*grep\s+-[A-Za-z]*q\b/, script)
    assert script =~ ~S|assets_page="$(curl -fsS "${base}/admin/rindle/assets")"|
    assert script =~ ~S|grep -Fq 'data-rindle-admin-row="asset"' <<< "${assets_page}"|
  end
end
