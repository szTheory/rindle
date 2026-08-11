defmodule Rindle.InstallSmoke.GovernanceFilesTest do
  use ExUnit.Case, async: true

  @repo_root Path.expand("../..", __DIR__)

  @governance_paths [
    "SECURITY.md",
    "CODE_OF_CONDUCT.md",
    ".github/ISSUE_TEMPLATE/bug_report.yml",
    ".github/ISSUE_TEMPLATE/feature_proposal.yml",
    ".github/ISSUE_TEMPLATE/config.yml",
    ".github/PULL_REQUEST_TEMPLATE.md"
  ]

  test "governance files exist at their GitHub-discoverable paths" do
    for rel_path <- @governance_paths do
      assert File.exists?(Path.join(@repo_root, rel_path)), "#{rel_path} is missing"
    end
  end

  test "release train drift template remains available" do
    assert File.exists?(Path.join(@repo_root, ".github/ISSUE_TEMPLATE/release-train-drift.md"))
  end

  test "security policy routes private reports through GitHub advisories without email" do
    body = File.read!(Path.join(@repo_root, "SECURITY.md"))

    assert body |> String.downcase() |> String.contains?("advisories")
    refute body =~ ~r/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/
  end
end
