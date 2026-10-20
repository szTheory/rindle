---
phase: 135-repository-and-code-craft-consolidation
plan: 13
subsystem: workflows-maintainer-scripts-residue
tags: [craft, residue, ci, workflows, maintainer-scripts, docker, artifact-ledger]
status: complete
requires: ["135-09"]
provides:
  - "scripts/maintainer/check_phase_133_landing_closure.sh deleted; artifact ledger has no delete-disposition class and passes --require-settled"
  - "workflow, composite action, dependabot, maintainer-script, top-level script and docker comments free of planning-era ids"
  - "automation_workflows shard with zero pending-removal entries"
affects:
  - scripts/maintainer/live_residue_allowlist/automation_workflows.json
  - scripts/maintainer/artifact_ledger.json
tech-stack:
  added: []
  patterns: ["comment-only residue tranche; the shard shrinks in the same commit as the edit", "non-comment workflow hits are classed, not rewritten"]
key-files:
  created:
    - .planning/phases/135-repository-and-code-craft-consolidation/deferred-items.md
  deleted:
    - scripts/maintainer/check_phase_133_landing_closure.sh
  modified:
    - scripts/maintainer/artifact_ledger.json
    - scripts/maintainer/live_residue_allowlist/automation_workflows.json
    - .github/workflows/ci.yml
    - .github/workflows/nightly.yml
    - .github/workflows/release.yml
    - .github/workflows/release-train-drift.yml
    - .github/dependabot.yml
    - .github/actions/setup-elixir/action.yml
    - .github/actions/setup-minio/action.yml
    - scripts/maintainer/collect_inbox.sh
    - scripts/maintainer/dep_landing_evidence.sh
    - scripts/maintainer/refactor_contract.sh
    - scripts/maintainer/validate_inbox_ledger.sh
    - scripts/mux_soak_cleanup.sh
    - scripts/setup_branch_protection.sh
    - scripts/ensure_minio.sh
    - docker/compose.cohort-demo.yml
    - docker/dx-template/compose.__app__.yml
decisions:
  - "Workflow edits are comment-only. Non-comment hits stay and are classed: the setup-beam `# v1.24.x` pin comments (Dependabot-maintained) and the PLAYWRIGHT_IMAGE tag are contract; the TRUTH-01 step name and its TRUTH-01-OK sentinel are policy; the `## CI per-step timing (D-04 long-pole jobs)` summary heading is contract (no consumer, but executable text; logged in deferred-items.md)"
  - "Composite action `description:` text in setup-elixir and setup-minio was treated as documentation and cleaned; it is metadata that no step executes and no test asserts"
  - "The scripts-maintainer ledger class also dropped its now-dangling `:(exclude)` pathspec for the deleted closure script; the retained-receipt class is byte-identical to origin/main"
  - "Script echo text in setup_branch_protection.sh lost its decision id because no harness or consumer matches it; the twin-gate literal `(Phase 137)` and the evidence-census `Phase 133 transition` error messages are asserted by harnesses and tests, so they are contract"
  - "Present-tense reads of maintained planning files (async-isolation evidence dir, inbox ledger path, docs-link exclusion, live-truth archived prefix) are policy"
metrics:
  duration: "about 45 min"
  completed: 2026-10-19
estimate:
  tokens: 90000
actuals:
  tokens: 36000
  tasks: 3
  commits: 3
plan_head_before: 30a59ef52b32cbf34ea4bd4af00aa01953f8c355
plan_head_after: 8a4bcd380258a4d752c317e7efb86d2b991eb7f9
---

# Phase 135 Plan 13: Workflows and maintainer scripts residue tranche (B2) Summary

The finished Phase 133 landing closure checker is gone, and the artifact ledger has no unsettled delete class. Workflow, composite-action, dependabot, maintainer-script, top-level script and docker comments now describe present intent. The automation_workflows shard went from 250 entries (209 pending-removal) on origin/main to 60 entries with 0 pending-removal: 15 contract, 36 policy and 9 immutable-receipt. `ci.yml`'s `name: CI`, every job name, the `CI Summary` job and its `needs:`, `ADMIN-06 Optional Dependencies` and every consumed step name are unchanged.

## Tasks

| Task | Name | Commit | Shard effect |
|------|------|--------|--------------|
| 1 (tracer) | Delete the closure script; settle the ledger | 9dd0f860 | -12 entries (the script's hits) |
| 2 | Workflow, action and dependabot comments | 8f9361fc | -154 removed; 8 non-comment hits classed (6 contract, 2 policy) |
| 3 | Maintainer scripts, top-level scripts, docker | 8a4bcd38 | -24 removed; 11 classed (6 contract, 5 policy) |

After each `--regen-baseline`, `git diff --stat` listed only `automation_workflows.json` among the shards. No `test/install_smoke` file needed an edit, so `install_smoke.json` is untouched (the co-ownership amendment did not apply). Running `--regen-baseline` again after each jq reclassification left the shard format unchanged.

Tracer gate: after Task 1 and before Task 2 started, `validate_artifact_ledger.sh --offline --require-settled` passed (46 classes), as did `test_validate_artifact_ledger.sh` (58 passed) and the full-tree scanner `--check`. The retained_receipt class `cmp`'d identical to origin/main.

## Verification

- `validate_artifact_ledger.sh --offline --require-settled`: ok (2888 files, 46 classes). Plain `--offline`: ok.
- `jq` delete-class count is 0. The retained_receipt class matches origin/main byte for byte.
- `scan_live_residue.exs --check --require-no-pending automation_workflows`: ok (624 files, 500 hits, 478 allowlist entries).
- `.github/` pending-removal count is 0. The whole-shard pending-removal count is 0.
- `grep -c 'name: CI$'` = 1. `grep -c 'name: CI Summary'` = 2, and origin/main is also 2: the second match is the pre-existing `- name: CI Summary gate logic` step, so the plan's literal "is 1" never held. `ADMIN-06 Optional Dependencies` count = 1, the same as origin/main.
- release.yml diff: one comment line only. The plan's non-comment diff filter prints nothing.
- Across all of `.github/`, the only non-comment diff lines are composite-action `description:` text. Every workflow diff line is a comment.
- YAML: `python3 yaml.safe_load` ok on all 7 edited files. `actionlint` reports 6 findings in ci.yml, and the same 6 appear on the origin/main copy (SC2251 ×2, SC2209 ×2, `matrix.elixir` ×2). None of them is new.
- Workflow policy tests: ci_lane_split, ci_observability, ci_cache_hygiene, quality_signal_policy, nightly_policy, release_guard_meta, live_truth_parity and dependabot_policy all pass (122 tests, 0 failures).
- `mix test test/install_smoke`: 362 tests, 0 failures, 17 excluded. `live_residue_scan_test.exs`: 28 tests, 0 failures.
- scripts/ci harnesses: 13 of 13 run pass. ci_summary_gate 6, collect_inbox 70, craft_contract_tools 52, dep_landing_evidence 58, e2e_specs_scoping 5, nightly_dialyzer 34, nightly_incident 36, nightly_summary_gate 49, repo_hygiene_check 37, setup_branch_protection 6, validate_artifact_ledger 58, validate_inbox_ledger 72, verify_nightly_run 187. `test_compat_115_26.sh` (Docker Elixir 1.15 probe) was not run; it fails in worktrees for an environmental reason, per 135-09, and this plan did not touch it.
- `repo_hygiene_check.sh --ci`: 10 PASS, 1 WARN (the Hex.pm index could not be read), 0 BLOCK.
- `automation_first_contract.sh`: passed. `! grep -rn ".planning/phases/135" scripts test .github lib`: clean.
- Strict partition: `git diff --name-only origin/main` touches nothing under scripts/ci, brandbook, priv/static/rindle_admin, automation_generators.json or test/.
- `bash -n` passes on every edited shell script.

## Deviations from Plan

**1. [Rule 2 - accuracy] Unflagged planning-era text in the same comments was rewritten.** This covers `SIGNAL-02/03`, `107-RESEARCH Open-Q2`, `Q2 resolution`, `Pitfall 4/5/6`, `T-112-01/02`, `T-36-*`, `103-BASELINE.md`, `CONTEXT discretion`, `external research Topic 1/2`, `V14 / T-113-05` and `D-06a`. None of these were shard entries.

**2. [Scope] Composite action `description:` metadata edited.** setup-elixir and setup-minio carried ids in their `description:` strings, which are not YAML comments. They are documentation that no step runs and no test asserts, so they were cleaned. All other `.github` changes are comment-only.

**3. [Plan literal] The `name: CI Summary` count is 2, not 1.** origin/main already has the `CI Summary gate logic` step, so the count matches origin/main. Nothing was renamed.

**4. [Out of scope, logged] Latent shell bug in the docs-truth guard.** actionlint SC2251: the `! grep -q` lines in the TRUTH-01 guard step do not trip `set -e`, so only the positive grep gates. This predates this plan, and fixing it is a non-comment change, so it is recorded in `deferred-items.md` together with the `D-04` summary heading.

**5. [Precondition timing]** The main push CI run for 30a59ef5 (Plan 09's merge) was `in_progress` when this plan ran. The run for 838ccf1a concluded success, the fingerprint fixture exists on origin/main, and no open PR touches ci.yml. Recheck that run's conclusion before opening the PR.

## Notes for the orchestrator

- Branch `ci/135-13-workflows-maintainer-residue`, based on origin/main 30a59ef5. Not pushed.
- PR subject: `ci: replace planning-era identifiers in workflows and maintainer scripts`. This PR touches ci.yml, so serialize it with other ci.yml PRs.
- Post-merge: the main push CI run for the squash SHA should conclude success before Plan 10 starts.

## Known Stubs

None.

## Self-Check: PASSED

- `scripts/maintainer/check_phase_133_landing_closure.sh` is absent from the index.
- Commits 9dd0f860, 8f9361fc and 8a4bcd38 are ancestors of HEAD on `ci/135-13-workflows-maintainer-residue`.
- automation_workflows.json has 0 pending-removal entries.
