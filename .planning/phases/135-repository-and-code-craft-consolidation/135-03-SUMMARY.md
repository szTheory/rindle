---
phase: 135-repository-and-code-craft-consolidation
plan: 03
subsystem: testing
tags: [artifact-ledger, package-set, gitignore, ci-gate, craft]
requires: ["135-01", "135-02"]
provides:
  - "scripts/maintainer/artifact_ledger.json: 47-class rindle-artifact-ledger-v1 partition with 64 ignore rules, 20 tracked-junk patterns and 13 verification ignored roots"
  - "scripts/maintainer/validate_artifact_ledger.sh: --offline [--ledger] [--require-settled] [--root] partition, field, receipt, package, ignore, junk and roots validator"
  - "scripts/ci/test_validate_artifact_ledger.sh: 58-case real-git harness including the live archive simulation"
  - "Rindle.InstallSmoke.PackageBuild.build_package!/0 and test/install_smoke/artifact_package_set_test.exs"
  - "ci-script-tests steps: Artifact ledger validator harness, Artifact ledger partition (offline)"
affects: [135-10, 135-11, 135-12, 135-13]
tech-stack:
  added: []
  patterns: ["git pathspec partition with anchored excludes", "retained receipt guard replaces the stale-class line", "vetted generator commands pinned in the validator and compared as data"]
key-files:
  created:
    - scripts/maintainer/artifact_ledger.json
    - scripts/maintainer/validate_artifact_ledger.sh
    - scripts/ci/test_validate_artifact_ledger.sh
    - test/install_smoke/support/package_build_helper.ex
    - test/install_smoke/artifact_package_set_test.exs
  modified:
    - .github/workflows/ci.yml
    - .gitignore
    - scripts/maintainer/live_residue_allowlist/automation_workflows.json
    - test/install_smoke/package_metadata_test.exs
  deleted:
    - .mcp.json
key-decisions:
  - "Exclude pathspecs must start with a literal path: git 2.41 does not combine `:(glob,exclude)**/x` reliably with other pathspecs (it emptied one class and failed to exclude in another), so the validator rejects unanchored wildcard excludes and the nested .gitignore files are listed explicitly"
  - "Tracked-ignored and verification-root checks read only tracked .gitignore files (`--exclude-per-directory=.gitignore`, `core.excludesFile=/dev/null`), so machine-local excludes never change the verdict"
  - "--ledger defaults to scripts/maintainer/artifact_ledger.json under --root"
status: complete
duration: ~1h45m
completed: 2026-10-19
commits: 5
plan_head_before: d19bd41f
plan_head_after: a8531bb5001524426573c89be76a6c635aa9c48d
actuals:
  tokens: 21900
  tasks: 3
  commits: 5
---

# Phase 135 Plan 03: Artifact ledger with partition validator and package-set check Summary

A 47-class git-pathspec ledger that puts every tracked path in exactly one class, with its authority, consumer, package status and disposition recorded. A bash+jq validator also checks ignore rules, tracked junk, generator authority and the retained evidence receipt. An ExUnit test checks the ledger's shipped set against the real unpacked Hex package.

## Tasks

| Task | Commit | Result |
| ---- | ------ | ------ |
| 1 Tracer: ledger, partition validator, harness, ci-script-tests steps | 1c6be6c1 | 21 harness cases; live ledger ok; tracer verify re-run end to end before expanding |
| 2 Field, package, ignore, junk, receipt rules; `.env.example` re-included | 130de20d | 57 cases incl. injection, retained receipt and live archive simulation |
| 2 `.mcp.json` deletion (own commit) | 5b452be0 | file removed, `/.mcp.json` ignored, junk pattern added, `machine-local-junk` class dropped in the same commit |
| 3 Shared package build helper and package-set test | 73941b3c | 3 new tests; package_metadata_test unchanged in names and assertions |
| follow-up: default ledger path | a8531bb5 | `validate_artifact_ledger.sh --offline` works without `--ledger`; 58 cases |

## Verification

- `bash scripts/ci/test_validate_artifact_ledger.sh`: 58 passed, 0 failed (~19 s locally)
- `bash scripts/maintainer/validate_artifact_ledger.sh --offline [--ledger scripts/maintainer/artifact_ledger.json]`: `ok (offline, 2879 files, 47 classes)`
- `mix run --no-start scripts/maintainer/scan_live_residue.exs --check`: `ok (623 files, 1365 hits, 1324 allowlist entries)`; `--regen-baseline` reproduces the committed shards
- `mix test` on the plan's seven files: 83 tests, 0 failures
- `mix test test/install_smoke`: 362 tests, 0 failures, 17 excluded
- `mix format --check-formatted` and `mix credo --strict` on the three Elixir files: clean
- `./scripts/maintainer/automation_first_contract.sh`: passed
- Acceptance: schema true and classes >= 30; one immutable-receipt retain class; no `/Users/` or `/home/` in the ledger; 2 ci.yml matches; `git ls-files -ci --exclude-standard` is 0 lines; no `eval`; `retained_receipt` jq check true; `retained receipt` appears 11 times in the harness; `.mcp.json` untracked; `git check-ignore .env.example` exits 1 and `.env.local` exits 0; `machine-local-junk` class absent; no `defp build_package!` left in package_metadata_test; `@prohibited_paths` kept; no phase-135 planning path under scripts, test, lib or .github
- Archive simulation (D-135-02), on a fresh repo built from the tracked tree with the 134 and 135 phase directories moved under `.planning/milestones/`: validator ok, harness 57/57 at the time, residue scan ok, `mix test test/install_smoke test/planning_path_hygiene_test.exs` 364 tests 0 failures. Moving the 133 directory as well: exit 1 with exactly `REJECT: retained receipt: .planning/phases/133-evidence-charter-and-live-truth must not be archived (verify_nightly_run.sh census identity)`. The harness repeats the validator half of this in CI by archiving every phase directory except the receipt, with the paths taken from the ledger.

## Ledger shape

Shipped classes (union equals the mix.exs `files:` set): package-lib, package-migrations, package-admin-css (generated, hygiene `sync-admin-css.mjs`), package-admin-static, package-manifest, package-docs, package-changelog (history), package-guides. Generated classes: brandbook-tokens-css and brandbook-admin-css (hygiene), brandbook-admin-gallery, brandbook-logo and brandbook-logo-candidates (drift_check none with reasons). Others: community docs, tool config, release config, lockfiles, ignore files, app config, CI required checks, workflows, actions, GitHub meta, scripts (ci, ci fixtures via `:(glob)scripts/ci/fixtures/**`, maintainer, maintainer ledgers, root), the retired-script `delete` class for `check_phase_133_landing_closure.sh`, tests, test fixtures, brandbook book/sources/lockfile/token source/social/fonts, example app/vendor/fonts/fixtures/lockfiles, docker, prompts, agent tooling, planning history (excluding the 133 directory and the ui-reviews ignore file) and `planning-evidence-receipt` with `retained_receipt`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Unanchored exclude pathspecs (research assumption A1)**
- **Found during:** Task 1 prototype
- **Issue:** `:(glob,exclude)**/.gitignore` combined with `:(glob)examples/adoption_demo/**` matched 0 files, and combined with `:(glob).planning/**` excluded nothing (git 2.41).
- **Fix:** Anchored excludes per class plus an explicit `vcs-ignore-files` list; the validator rejects any exclude pathspec that starts with a wildcard, with a harness case.
- **Commit:** 1c6be6c1

**2. [Rule 2 - Missing critical] Deterministic ignore evaluation**
- **Issue:** `--exclude-standard` and `check-ignore` read machine-local excludes, so results could differ between a laptop and CI.
- **Fix:** Tracked-ignored uses `--exclude-per-directory=.gitignore`; all git calls set `core.excludesFile=/dev/null`; a verification root counts only when a tracked `.gitignore` non-negated pattern decides it.
- **Commit:** 130de20d

**3. [Rule 3 - Blocking] Default `--ledger` path**
- **Issue:** The orchestrator's verification command `validate_artifact_ledger.sh --offline` (no `--ledger`) exited 64.
- **Fix:** `--ledger` defaults to `scripts/maintainer/artifact_ledger.json` under `--root`; harness case added. The ci.yml step keeps the explicit flag.
- **Commit:** a8531bb5

### Instruction-driven differences

- Commit subjects use `ci(135-03):` / `test(135-03):` / `chore(135-03):` as the orchestrator required. The deletion subject is `chore(135-03): remove tracked machine-specific .mcp.json`, not the plan's bare `chore: ...` acceptance string.
- `/.mcp.json` in `.gitignore` and its ignore rule land in the deletion commit, not the Task 2 rules commit. Ignoring the file while it was still tracked would have failed the tracked-ignored rule at that commit, and this order keeps every commit green.

### Additions beyond the plan text

- Extra validator rules: duplicate class ids, exclude-only pathspec lists (they would match the whole tree), exclude-only junk patterns, relative-path verification roots, a missing `retained_receipt` identity, `produced_by` required, and duplicate effective lines inside a single `.gitignore`.
- Extra junk patterns `Thumbs.db`, `*.swo`, `.env`; verification roots include the example app `_build`, `deps`, `node_modules`, `playwright-report`, `test-results` and `tmp`.

### Notes

- The install_smoke residue shard needed no change: none of the edited or moved lines in `package_metadata_test.exs` had an allowlist entry, and the new test and helper have no hits. Only `automation_workflows.json` gained entries: 11, all for ledger lines naming planning paths (3 `immutable-receipt` for the receipt lines, 8 `policy`). No `pending-removal` entry was added.
- The CI runner's jq is 1.6; only jq 1.7.1 was available locally. The validator uses only 1.5/1.6 builtins (`IN`, `all/2`, `any/2`, `group_by`, `unique`, `test`, `sub`), and NUL handling is done in bash/tr, not jq. The post-merge `ci-script-tests` run is the jq 1.6 proof.

## Known Stubs

None.

## Threat Flags

None. T-135-07: vetted command set pinned in the validator, injection fixture proves ledger text is never executed. T-135-08: `.mcp.json` deleted, ignored and listed as junk. T-135-09: package-set equality test. T-135-10: partition prototyped, anchored-exclude rule added. T-135-30: retained receipt guard with harness fixture and live simulation. No package installs.

## Self-Check: PASSED

All five created files exist; commits 1c6be6c1, 130de20d, 5b452be0, 73941b3c and a8531bb5 are ancestors of HEAD.
