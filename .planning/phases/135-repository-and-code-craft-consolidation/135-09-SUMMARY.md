---
phase: 135-repository-and-code-craft-consolidation
plan: 09
subsystem: ci-scripts-generators-residue
tags: [craft, residue, ci, brandbook, generators, fixtures]
status: complete
requires: ["135-05", "135-08"]
provides:
  - "test_nightly_dialyzer.sh reads scripts/ci/fixtures/nightly_failure_fingerprint.json (byte copy of the Phase 133 fingerprint), not the planning directory"
  - "shipped admin CSS free of planning-era ids, fixed in admin-css-build.mjs and regenerated and synced"
  - "automation_generators shard with zero pending-removal entries"
affects:
  - scripts/maintainer/live_residue_allowlist/automation_generators.json
tech-stack:
  added: []
  patterns: ["generator-side fix then regenerate (D-135-10)", "comment-only residue tranche; shard shrinks in the same commit as the edit"]
key-files:
  created:
    - scripts/ci/fixtures/nightly_failure_fingerprint.json
  modified:
    - scripts/ci/test_nightly_dialyzer.sh
    - brandbook/src/admin-css-build.mjs
    - brandbook/src/admin-design-system-data.mjs
    - brandbook/src/admin-gallery-check.mjs
    - brandbook/src/admin-gallery.mjs
    - brandbook/src/candidates.mjs
    - brandbook/src/cohort-contrast.mjs
    - brandbook/src/cohort-design-system-data.mjs
    - brandbook/src/contrast-constants.mjs
    - brandbook/src/sheet.mjs
    - brandbook/src/sync-admin-css.mjs
    - brandbook/tokens/rindle-admin.css
    - brandbook/assets/logo/candidates/sheet.html
    - priv/static/rindle_admin/rindle-admin.css
    - scripts/ci/check_required_checks.sh
    - scripts/ci/cohort_demo_smoke.sh
    - scripts/ci/collect_ci_baseline.sh
    - scripts/ci/e2e_local.sh
    - scripts/ci/eval_ci_summary.sh
    - scripts/ci/test_ci_summary_gate.sh
    - scripts/ci/test_collect_inbox.sh
    - scripts/ci/test_dep_landing_evidence.sh
    - scripts/ci/test_e2e_specs_scoping.sh
    - scripts/ci/test_setup_branch_protection.sh
    - scripts/ci/test_validate_inbox_ledger.sh
    - scripts/maintainer/live_residue_allowlist/automation_generators.json
decisions:
  - "The fingerprint fixture's only scanner hit is the Elixir toolchain string v1.17.3-otp-27; classed fixture (byte copy of a retained receipt)"
  - "brandbook/assets/logo/candidates/sheet.html is sheet.mjs output, so it was regenerated with node sheet.mjs rather than hand-edited (D-135-10)"
  - "Remaining automation_generators hits classed, not rewritten: collect_pr_timing_receipt.sh .planning/ path-partition logic, the Playwright image tag in e2e_local.sh and the twin-gate literal are contract; the no-phase-path guard in test_dep_landing_evidence.sh is policy; the three test_verify_nightly_run.sh literals are immutable-receipt because that harness stays byte-unchanged (D-135-03)"
  - "Section markers like §A..§D in the generated CSS were left; the scanner does not flag them and they label sections consistently across the file"
metrics:
  duration: "about 50 min"
  completed: 2026-10-19
estimate:
  tokens: 80000
actuals:
  tokens: 21000
  tasks: 3
  commits: 3
plan_head_before: 838ccf1ac234cf591a289111eb2eaf16666c9fe9
plan_head_after: 51655904
---

# Phase 135 Plan 09: CI scripts and brandbook generators residue tranche (B1) Summary

The Nightly Dialyzer harness reads its failure fingerprint from a `scripts/ci/fixtures/` copy. Planning-era ids are gone from the shipped admin CSS: they were removed in `admin-css-build.mjs`, then the CSS was regenerated and synced. `scripts/ci` comments now describe present intent. The automation_generators shard dropped from 152 entries (142 pending-removal) to 24 entries with 0 pending-removal: 8 contract, 4 fixture, 9 immutable-receipt and 3 policy.

## Tasks

| Task | Name | Commit | Shard effect |
|------|------|--------|--------------|
| 1 (tracer) | Fingerprint fixture copy and repoint | f5da4969 | -1 planning-path; +1 fixture (toolchain version in the copied JSON) |
| 2 | Generator-side CSS fix, regenerate and sync, brandbook sources | aaf2acc7 | -87 (brandbook/src 57, brandbook/tokens 15, priv/static 15) |
| 3 | Remaining scripts/ci comments, classify the rest | 51655904 | -41 removed; 13 reclassified (7 contract, 3 policy, 3 immutable-receipt) |

After each `--regen-baseline`, `git diff --stat` showed that only `automation_generators.json` had changed. `install_smoke.json` and `examples_docs.json` were untouched: Plan 08 left no examples_docs entry for these literals, and no `test/install_smoke` file needed an edit. Re-running `--regen-baseline` after the jq reclassification produced a byte-identical shard, so the format is stable.

Tracer gate: after Task 1, cmp, the Nightly Dialyzer harness (34 pass), test_verify_nightly_run (187 pass), the ledger offline check and the full-tree scanner `--check` all passed before Task 2 started.

## Verification

- `cmp` fixture vs `.planning/phases/133-.../133-NIGHTLY-FAILURE-FINGERPRINT.json`: identical; sha256 `119b2f9afb3736d1f217187f5399683e2ec72d4580c41b5396cf92519709bdd5`; `grep -c '\.planning' scripts/ci/test_nightly_dialyzer.sh` = 0
- `verify_nightly_run.sh`, `test_verify_nightly_run.sh`, `artifact_ledger.json` and `.github/` show no diff against origin/main
- Brandbook regeneration (`tokens-build`, `admin-css-build`, `admin-contrast` 58/58, `sync-admin-css`) on the committed tree leaves no git diff. `cmp brandbook/tokens/rindle-admin.css priv/static/rindle_admin/rindle-admin.css` passes, so the two copies are identical. The CSS diff touches comments only. `cohort-contrast.mjs` reports 28/28 pairs pass.
- Generators use node stdlib only. No `npm ci` was run. The DS-02 gallery check (Playwright) ran with `NODE_PATH=/Users/jon/projects/rindle/examples/adoption_demo/node_modules`, read-only from the primary checkout.
- `scan_live_residue.exs --check --require-no-pending automation_generators`: ok (625 files, 708 hits, 668 allowlist entries)
- automation_generators pending-removal count (jq): 0
- scripts/ci harnesses: 13 of 14 pass, including every harness whose script this plan touched. `test_compat_115_26.sh` fails for an environmental reason; see Deviations.
- `validate_artifact_ledger.sh --offline`: ok (2888 files, 47 classes)
- `test_repo_hygiene_check.sh`: 37 passed, 0 failed
- `mix test test/install_smoke test/brandbook --include integration`: 387 tests, 0 failures, 17 excluded
- `automation_first_contract.sh`: passed
- `! grep -rn ".planning/phases/135" scripts test .github lib`: clean
- Strict partition grep against Plan 13: prints nothing
- `bash -n` on the five edited non-harness scripts and `node --check` on all brandbook/src modules: ok

## Deviations from Plan

**1. [Rule 2 - accuracy] Unflagged planning-era text in the same comments was rewritten.** This covers `threat T-103-03` / `T-103-05`, `Pitfall 2/3/4`, `RESEARCH Open-Q1`, `research GATE-A3`, `[Rule 1]`, `BLOCKER-3` and `P2b surface migration`. It also drops the "byte-identical to the previous inline run: block" history sentence in eval_ci_summary.sh. None of these were shard entries.

**2. [Scope] sheet.html regenerated.** `sheet.mjs` emits a "Phase 83" sentence into `brandbook/assets/logo/candidates/sheet.html`. The generator was edited and `node sheet.mjs` was re-run; a run beforehand on the untouched tree showed it reproduces the committed file exactly. The file is under `brandbook/`, inside the plan's partition.

**3. [Environment] `scripts/ci/test_compat_115_26.sh` fails locally (out of scope, not touched).** This Elixir 1.15/OTP 26 Docker probe runs the full suite in a container. Inside it, the worktree's `.git` file points outside the mount (`fatal: not a git repository: .../.git/worktrees/agent-...`), so git-dependent tests fail: 22 failures, 2 invalid. No workflow runs this script, and this plan did not touch it. I did not re-run it on an origin/main archive, because the stated cause is the worktree layout.

**4. Precondition timing.** Plan 05's merge commit (838ccf1a) was still `in_progress` on the main push CI when this plan ran. The run for Plan 08's merge (05bff2dc) and earlier runs concluded success. The orchestrator dispatched this plan on 838ccf1a. Recheck that run's conclusion before opening the PR.

## Notes for the orchestrator

- Branch `ci/135-09-scripts-generators-residue`, based on origin/main 838ccf1a. Not pushed.
- PR subject: `ci: replace planning-era identifiers in ci scripts and brandbook generators`. Does not touch ci.yml.
- Post-merge: the main push CI run for the squash SHA should conclude success before Plan 13 starts (Proof job inputs changed).

## Known Stubs

None.

## Self-Check: PASSED

- `scripts/ci/fixtures/nightly_failure_fingerprint.json` exists.
- Commits f5da4969, aaf2acc7 and 51655904 are on `ci/135-09-scripts-generators-residue`.
- automation_generators.json has 0 pending-removal entries.
