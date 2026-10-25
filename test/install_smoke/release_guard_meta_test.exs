defmodule Rindle.InstallSmoke.ReleaseGuardMetaTest do
  @moduledoc """
  Regression lock for the two release-train recurrence guards (drift guard and
  token-validity guard) and the release-coupling invariant.
  Mirrors the grep-meta pattern in ci_observability_test.exs: `setup_all`
  + `File.read!` + `=~` / `refute =~`, running inside the default `mix test` /
  `mix ci` suite (no exclude tag), so the guards cannot silently regress.

  ASSERTS CURRENT SHIPPED STATE. Every literal asserted below was grep-confirmed
  against the live workflow YAML on disk:

    - .github/workflows/release-train-drift.yml  (the drift guard ships + is wired)
    - .github/workflows/release.yml              (the token-validity guard ships)
    - .github/workflows/ci.yml                   (guards stay OFF the required path)

  Deliberately asserts SHIPPED artifacts ONLY (workflows). It does NOT couple to
  internal planning doc paths, which move when a milestone is archived
  (gsd-cleanup) and would break this suite for a non-shipped reason — the same
  discipline ci_observability_test.exs follows.

  Release coupling is the load-bearing invariant: the guards must NEVER appear in the
  `ci-summary:` job `needs:` list (the sole required check / PR critical path),
  and ci.yml `name: CI` (line 1) + the `CI Summary` check name must stay
  byte-stable — release-please-automerge.yml (`workflows: [CI]`) and
  release.yml `gate-ci-green` (`workflow_id: 'ci.yml'`) are coupled to them.
  """
  use ExUnit.Case, async: true

  @ci_path Path.expand("../../.github/workflows/ci.yml", __DIR__)
  @release_path Path.expand("../../.github/workflows/release.yml", __DIR__)
  @drift_path Path.expand("../../.github/workflows/release-train-drift.yml", __DIR__)
  @drift_template_path Path.expand(
                         "../../.github/ISSUE_TEMPLATE/release-train-drift.md",
                         __DIR__
                       )
  @progress_guard_path Path.expand(
                         "../../scripts/maintainer/check_release_please_progress.sh",
                         __DIR__
                       )
  @label_reconcile_path Path.expand(
                          "../../scripts/maintainer/reconcile_release_please_label.sh",
                          __DIR__
                        )

  setup_all do
    {:ok,
     %{
       ci: File.read!(@ci_path),
       release: File.read!(@release_path),
       drift: File.read!(@drift_path),
       drift_template: File.read!(@drift_template_path),
       progress_guard: File.read!(@progress_guard_path),
       label_reconcile: File.read!(@label_reconcile_path)
     }}
  end

  # ------------------------------------------------------------------
  # The release-train drift guard ships and is wired.
  # ------------------------------------------------------------------
  test "release-train-drift.yml ships, runs on cron + dispatch, least-privilege, and self-files",
       %{drift: drift} do
    assert drift =~ "name: Release Train Drift Check",
           "release-train-drift.yml must carry its stable workflow name"

    assert drift =~ "gh issue create",
           "release-train-drift.yml must create the rolling issue with the runner-native GitHub CLI"

    assert drift =~ "gh issue edit",
           "release-train-drift.yml must update an existing rolling issue instead of filing duplicates"

    refute drift =~ "JasonEtco/create-an-issue",
           "release-train-drift.yml must not depend on the retired Node 20 issue action"

    assert drift =~ "schedule:",
           "release-train-drift.yml must run on a `schedule` cron"

    assert drift =~ "workflow_dispatch:",
           "release-train-drift.yml must also be `workflow_dispatch`-runnable"

    # Least-privilege: contents:read + issues:write only.
    assert drift =~ "contents: read",
           "release-train-drift.yml must keep `contents: read` (least-privilege)"

    assert drift =~ "issues: write",
           "release-train-drift.yml must grant `issues: write` to file the rolling issue"

    # The predicate is keyed on rindle-v* tags.
    assert drift =~ "rindle-v",
           "release-train-drift.yml predicate must resolve the last `rindle-v*` tag"
  end

  test "the issue template ships with the close-step's searchable title substring",
       %{drift: drift, drift_template: drift_template} do
    # The workflow's close-on-recovery step searches issue titles on this exact
    # substring; the template title MUST contain it or recovery never closes.
    searchable = "Release train drift: main ahead of last rindle-v* tag with no open release PR"

    assert drift_template =~ searchable,
           "the issue template title must contain the close-step search substring"

    assert drift =~ searchable,
           "the workflow close step must search issue titles on the template's stable substring"
  end

  # ------------------------------------------------------------------
  # The token-validity guard ships inside release-please (a STEP, not a
  # new top-level job / required check).
  # ------------------------------------------------------------------
  test "release credentials use explicit App admission with a legacy rollout", %{release: release} do
    assert release =~ "uses: ./.github/actions/repository-credential"
    assert release =~ "app-client-id: ${{ vars.RELEASE_APP_CLIENT_ID }}"
    assert release =~ "app-private-key: ${{ secrets.RELEASE_APP_PRIVATE_KEY }}"
    assert release =~ "legacy-token: ${{ secrets.RELEASE_PLEASE_TOKEN }}"
    assert release =~ "token: ${{ steps.release_credential.outputs.token }}"
    refute release =~ "secrets.BRANCH_PROTECTION_PAT"
    refute release =~ "secrets.RELEASE_PLEASE_TOKEN ||"
    {admission, _} = :binary.match(release, "id: release_credential")
    {operation, _} = :binary.match(release, "name: Run Release Please")
    assert admission < operation
    refute release =~ ~r/(echo|printf)[^\n]*\$\{?GH_TOKEN/
  end

  test "the token guard is a STEP, not a new top-level job / required check name",
       %{release: release} do
    # A new top-level job would be a 2-space-indented `key:` under `jobs:`. The
    # guard must NOT introduce one — it lives as a step inside `release-please`.
    refute release =~ "\n  validate-release-please-token:",
           "the token guard must be a STEP inside release-please, not a new top-level job"

    refute release =~ "name: Validate RELEASE_PLEASE_TOKEN Job",
           "the token guard must not surface as a new job/check name"
  end

  test "App tokens use the reviewed per-role subset, one repository and post-job revocation" do
    action = YamlElixir.read_from_file!(".github/actions/repository-credential/action.yml")
    mint = Enum.find(action["runs"]["steps"], &(&1["id"] == "mint"))

    assert mint["uses"] ==
             "actions/create-github-app-token@64ab729a6294000f5aa4a4bc0b73d1f32bc45510"

    assert mint["if"] == "steps.select.outputs.source == 'app'"
    grants = mint["with"]
    assert grants["owner"] == "${{ github.repository_owner }}"
    assert grants["repositories"] == "${{ github.event.repository.name }}"
    assert grants["skip-token-revoke"] == false

    assert grants["permission-administration"] ==
             "${{ inputs.profile == 'protection' && 'write' || '' }}"

    assert grants["permission-issues"] == "${{ inputs.profile == 'release' && 'write' || '' }}"

    for grant <- ~w(permission-contents permission-pull-requests) do
      assert grants[grant] == "${{ inputs.profile != 'protection' && 'write' || '' }}"
    end

    refute Map.has_key?(grants, "permission-actions")
    refute Map.has_key?(grants, "permission-checks")
  end

  test "release and protection use separate configuration; dispatch and checks keep job authority" do
    merge = YamlElixir.read_from_file!(".github/workflows/release-please-automerge.yml")
    steps = merge["jobs"]["automerge"]["steps"]
    assert hd(steps)["with"]["ref"] == "main"
    assert hd(steps)["with"]["persist-credentials"] == false
    auth = Enum.find(steps, &(&1["id"] == "merge_credential"))
    assert auth["with"]["profile"] == "merge"
    assert auth["with"]["app-client-id"] == "${{ vars.RELEASE_APP_CLIENT_ID }}"

    dispatch =
      Enum.find(steps, &(&1["name"] == "Dispatch trusted release workflow for exact merge ref"))

    assert dispatch["env"]["GH_TOKEN"] == "${{ github.token }}"
    assert dispatch["run"] =~ "--field recovery_ref=\"$MERGE_SHA\""

    protection = YamlElixir.read_from_file!(".github/workflows/branch-protection-apply.yml")
    steps = protection["jobs"]["reassert-protection"]["steps"]
    auth = Enum.find(steps, &(&1["id"] == "protection_credential"))
    assert auth["with"]["profile"] == "protection"
    assert auth["with"]["app-client-id"] == "${{ vars.PROTECTION_APP_CLIENT_ID }}"
    assert auth["with"]["app-private-key"] == "${{ secrets.PROTECTION_APP_PRIVATE_KEY }}"
    refute Map.has_key?(auth["with"], "job-token")
    assert hd(steps)["with"]["ref"] == "main"
  end

  test "Release Please PR maintenance gets one bounded retry, never a publish retry",
       %{release: release} do
    assert release =~ "id: release_primary",
           "the primary Release Please attempt must have a stable outcome id"

    assert release =~ "continue-on-error: true",
           "the primary attempt must allow the bounded retry step to run"

    assert release =~ "if: ${{ steps.release_primary.outcome == 'failure' }}",
           "the retry must run only after the primary Release Please attempt fails"

    assert length(Regex.scan(~r/uses: googleapis\/release-please-action@/, release)) == 2,
           "Release Please must have exactly one primary attempt and one retry"

    [release_please_job, _protected_release_path] =
      String.split(release, "\n  recovery-validation:\n", parts: 2)

    assert release_please_job =~ "Retry Release Please once after a transient failure"

    refute release_please_job =~ "mix hex.publish",
           "the retry must remain isolated from the protected Hex publish path"
  end

  test "Release Please fails closed when a stale merged pending PR suppresses progress", %{
    release: release,
    progress_guard: progress_guard
  } do
    assert release =~ "bash scripts/maintainer/check_release_please_progress.sh"
    assert progress_guard =~ "releasable_commits"
    assert progress_guard =~ "open_release_prs"
    assert progress_guard =~ "stale_pending_prs"
    assert progress_guard =~ "Release Please made no progress"
    assert progress_guard =~ "autorelease: tagged"
  end

  test "public verification reconciles the matching Release Please PR label", %{
    release: release,
    label_reconcile: label_reconcile
  } do
    assert release =~ "needs: [gate-ci-green, publish, public_verify]"
    assert release =~ "needs.public_verify.result == 'success'"
    assert release =~ "bash scripts/maintainer/reconcile_release_please_label.sh"
    assert release =~ "RELEASE_SHA: ${{ needs.gate-ci-green.outputs.release_sha }}"
    assert label_reconcile =~ "commits/${RELEASE_SHA}/pulls"
    assert label_reconcile =~ "autorelease: pending"
    assert label_reconcile =~ "autorelease: tagged"
    assert label_reconcile =~ "label reconciliation did not persist"
  end

  test "baseline landing keeps public verification and ordinary protected PR CI", %{
    release: release,
    ci: ci
  } do
    [_, baseline] = String.split(release, "\n  update-release-train-baseline:\n", parts: 2)
    assert baseline =~ "needs: [gate-ci-green, publish, public_verify]"
    assert baseline =~ "needs.public_verify.result == 'success'"
    assert baseline =~ "BASELINE_BASE_SHA: ${{ steps.baseline_source.outputs.sha }}"
    assert baseline =~ "checks: read"
    assert baseline =~ "BASELINE_CHECKS_TOKEN: ${{ github.token }}"
    assert baseline =~ "python3 scripts/maintainer/land_release_train_baseline.py"
    assert ci =~ "python3 scripts/ci/test_land_release_train_baseline.py"
    refute baseline =~ "[skip ci]"
    refute baseline =~ "--admin"

    {repair, _} = :binary.match(baseline, "reconcile_release_please_label.sh")
    {setup, _} = :binary.match(baseline, "name: Set up Elixir")
    {freeze, _} = :binary.match(baseline, "id: baseline_source")
    {rewrite, _} = :binary.match(baseline, "update_release_train_baseline.sh")
    assert repair < setup
    assert freeze < rewrite
  end

  # ------------------------------------------------------------------
  # Neither guard sneaks onto the sole required CI path.
  # ------------------------------------------------------------------
  test "the ci-summary `needs:` block does NOT reference release-train-drift",
       %{ci: ci} do
    needs_block = ci_summary_needs_block(ci)

    refute needs_block =~ "release-train-drift",
           "release-train-drift must NOT appear in the ci-summary `needs:` list — it stays OFF the sole required path"

    # Sanity: confirm we isolated a real, non-empty needs block (so the refute is
    # meaningful, not vacuously true on a parse miss).
    assert needs_block =~ "quality",
           "ci-summary `needs:` isolation must capture the real needs list (it must list `quality`)"
  end

  test "the gate stays byte-stable: ci.yml line 1 is `name: CI` and the ci-summary job carries `name: CI Summary`",
       %{ci: ci} do
    [first_line | _] = String.split(ci, "\n", parts: 2)

    assert first_line == "name: CI",
           "ci.yml line 1 must stay exactly `name: CI` — release-please-automerge `workflows: [CI]` + gate-ci-green `workflow_id: ci.yml` are coupled to it"

    assert ci =~ "\n  ci-summary:\n",
           "ci.yml must declare the `ci-summary` job (the required-check carrier)"

    assert ci =~ "name: CI Summary",
           "the ci-summary job must keep the byte-stable required-check name `CI Summary`"
  end

  # ------------------------------------------------------------------
  # Block / scope isolators.
  # ------------------------------------------------------------------

  # The `ci-summary:` job `needs:` list, from `needs:` up to the job's
  # `if: always()` line (the next sibling key after the needs list).
  defp ci_summary_needs_block(ci) do
    [_, after_key] = String.split(ci, "\n  ci-summary:\n", parts: 2)
    [_, after_needs] = String.split(after_key, "\n    needs:\n", parts: 2)
    [block | _] = String.split(after_needs, "\n    if: always()", parts: 2)
    block
  end
end
