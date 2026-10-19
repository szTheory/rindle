---
phase: 135-repository-and-code-craft-consolidation
plan: 05
subsystem: ci-release
tags: [hygiene, release-train, harness, artifact-ledger, ci-script-tests]
requires: ["135-03"]
provides:
  - "scripts/maintainer/repo_hygiene_check.sh: check_fetch, check_branch, check_artifact_ledger, check_tracked_junk, check_generated_drift, check_mix_ci, check_residue; --release-prep; RINDLE_HYGIENE_ROOT, RINDLE_HYGIENE_BRANCH; publish race WARN in --ci, BLOCK otherwise"
  - "scripts/ci/test_repo_hygiene_check.sh: 37-case real-git harness (bare origin, clone, PATH shims for mix, node, gh)"
  - "ci-script-tests step: Repo hygiene harness"
affects: [135-11]
tech-stack:
  added: []
  patterns: ["vetted generator list matched as data and run as argv", "background mix ci plus wait so INT/TERM traps fire at once", "porcelain -uall --ignored snapshot delta filtered by ledger verification roots"]
key-files:
  created:
    - scripts/ci/test_repo_hygiene_check.sh
  modified:
    - scripts/maintainer/repo_hygiene_check.sh
    - .github/workflows/ci.yml
    - scripts/maintainer/live_residue_allowlist/automation_generators.json
key-decisions:
  - "ExUnit sentinel accepts leading doctest/property counts: `^([0-9]+ (doctests?|propert(y|ies)), )*[0-9]+ tests?, 0 failures`; the literal plan regex never matches rindle's real summary (`3 doctests, 13 tests, 0 failures`)"
  - "Generated drift and mix ci run only after fetch, branch and head vs origin all PASS (T-135-14); otherwise each records BLOCK 'not run'"
  - "Ahead of origin is BLOCK in both default and --release-prep (must_haves truth); --release-prep is the explicit name for the same checks"
  - "Usage errors (unknown argument, --ci with --with-mix-ci) exit 64 as the plan contract states; previously 1"
status: complete
duration: ~1h
completed: 2026-10-19
commits: 3
plan_head_before: c23f287ec1bd16c028f90f6f3e1779e4fab6bddc
plan_head_after: 93a02a857682f543dccf3a63e4c4b41948aee9e1
actuals:
  tokens: 10660
  tasks: 3
  commits: 3
---

# Phase 135 Plan 05: Honest repo hygiene gate Summary

`repo_hygiene_check.sh` now BLOCKs on a failed fetch, a wrong or detached branch, HEAD behind or ahead of origin, tracked junk, generated drift, a failing or incomplete `mix ci`, and new paths left behind by verification. A 37-case harness that uses real git repos runs each failure as a merge-blocking `ci-script-tests` step.

## Tasks

| Task | Commit | Result |
| ---- | ------ | ------ |
| 1 Tracer: check_fetch, check_branch, RINDLE_HYGIENE_ROOT/BRANCH, --release-prep, harness | c7ec50fe | 11 cases; tracer verify re-run before expanding |
| 2 Tracked junk, generated drift, full mix ci with sentinels, residue delta, publish-race split | db02d715 | 37 cases |
| 3 ci-script-tests step, residue allowlist, live --ci run | 93a02a85 | step appended; 3 fixture allowlist entries |

## Verification

- `bash scripts/ci/test_repo_hygiene_check.sh`: 37 passed, 0 failed (~28 s). It also passes with macOS `/bin/bash` 3.2.57 as `bash` on PATH.
- Discrimination check: the same harness run against the origin/main script gives 6 passed and 31 failed.
- `bash scripts/maintainer/repo_hygiene_check.sh --ci` on this tree: 11 PASS, 0 WARN, 0 BLOCK, exit 0. Its checks include `artifact ledger` (ok, 2882 files, 47 classes) and `tracked junk`.
- `bash scripts/maintainer/validate_artifact_ledger.sh --offline`: ok (2882 files, 47 classes). The new harness falls under the existing scripts/ci class.
- `mix run --no-start scripts/maintainer/scan_live_residue.exs --check`: ok (624 files, 1269 hits, 1229 entries). `--regen-baseline` changed only `automation_generators.json` and is idempotent.
- `mix test test/install_smoke`: 362 tests, 0 failures, 17 excluded. This covers live_residue_scan, nightly_policy, ci_lane_split, ci_observability and quality_signal_policy.
- `./scripts/maintainer/automation_first_contract.sh`: passed.
- Acceptance greps:
  - no fetch `|| true`
  - `check_fetch|check_branch` count 4
  - RELEASE-TRAIN phrase still matches
  - no `mix test`; `mix ci` present
  - no `eval` or `bash -c`
  - each of the two fixed sentinels appears once
  - `test_repo_hygiene_check.sh` appears in ci.yml once, as does `repo_hygiene_check.sh --ci`
  - no `.planning/phases/135` under scripts, test, .github or lib

## Harness cases (37)

- **Fetch, branch and head:**
  - clean clone is safe in default and release-prep modes
  - unreachable remote is a fetch BLOCK in default and release-prep modes
  - `--ci` neither fetches nor checks the branch
  - feature branch and detached HEAD BLOCK the branch check
  - behind=1 and ahead=1 BLOCK head vs origin
  - RINDLE_HYGIENE_BRANCH works
  - usage errors exit 64 (two cases)
- **Tracked junk:**
  - `.DS_Store` in default mode and under `--ci`
  - a committed ignored file
  - a file that matches only a ledger junk pattern
- **Generated drift:**
  - a rewritten drift path, in default and release-prep modes
  - an untracked file beside a drift path
  - `--ci` skips the check and runs no generator
  - an unverified branch runs no generator
  - an unvetted ledger command BLOCKs and is never executed
- **mix ci:**
  - exit 2 BLOCKs
  - exit 0 with two of the three sentinels is `mix ci incomplete`
  - all sentinels PASS without printing the log, in default and release-prep modes
- **Residue:**
  - an untracked file BLOCKs
  - a write under `_build/` passes
  - an ignored file outside the roots BLOCKs
- **Interrupt:** SIGTERM while fake mix sleeps exits 143 in under 10 s, leaves an empty TMPDIR and leaves `git status --ignored` unchanged.
- **Publish race:** `--ci` gives WARN with exit 0, `--release-prep` gives BLOCK, and the pre-publish state is PASS.

The fake gh writes any call it does not recognize as read-only to a mutations file. Every case asserts that file stays empty.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] ExUnit sentinel regex never matches the real summary**
- **Found during:** Task 2
- **Issue:** The must_haves regex `^[0-9]+ tests?, 0 failures` misses rindle's real ExUnit line. Elixir 1.17 prints `3 doctests, 13 tests, 0 failures`, verified locally on `test/rindle/av/metadata_sanitizer_test.exs`. With the literal regex, every honest `--with-mix-ci` run would be a false `mix ci incomplete`.
- **Fix:** `^([0-9]+ (doctests?|propert(y|ies)), )*[0-9]+ tests?, 0 failures`. It still contains the pinned literal and still requires 0 failures. The harness fake prints a doctest-prefixed summary.
- **Commit:** db02d715

**2. [Rule 2 - Security] Generators and mix ci gated on a verified HEAD (T-135-14)**
- **Issue:** The plan order would run repository code (node generators, `mix ci`) even after a branch or head BLOCK.
- **Fix:** Both checks run only when fetch, branch and head vs origin all PASS. Otherwise each records `[BLOCK] <label>: not run: ...`. A harness case proves that no generator runs on a feature branch.
- **Commit:** db02d715

**3. [Rule 2 - Determinism] Tracked-ignored and residue checks ignore machine-local excludes**
- **Issue:** Following 135-03, `--exclude-standard` and `core.excludesFile` would make the verdict depend on the machine.
- **Fix:** The check uses `git ls-files -c -i --exclude-per-directory=.gitignore` in place of `-ci --exclude-standard`. Status snapshots use `-c core.excludesFile=/dev/null`.
- **Commit:** db02d715

### Instruction-driven differences

- The `mix ci` log is written by redirect into the private mktemp directory, not through `tee` under pipefail. Nothing is printed, so tee had no reader. The background-and-`wait` form lets INT/TERM reach the trap without waiting for `mix ci` to finish.
- `--release-prep` runs the same checks as the default mode. The must_haves truth makes ahead-of-origin BLOCK in both modes, and the publish race is BLOCK in both, so the flag only names the mode in the report.
- The usage-exit change (1 to 64) follows the plan's "64 usage" contract.
- The "must_haves must say exactly this" amendment (drift skipped in `--ci`) is reflected in the script usage text and the harness. I did not edit the plan file.
- Commit subjects use `ci(135-05):` as the orchestrator required. PR subject per plan: `ci: make repo hygiene fail honestly on fetch, branch, junk, drift, mix ci and residue`.

## Notes

- The hygiene script's RELEASE-TRAIN and DEVELOPMENT-TRAIN reads keep their exact text, so their `policy` entries in automation_workflows.json are unchanged. The three new residue hits are all harness fixture lines, classed `fixture` in automation_generators.json. No `pending-removal` entry was added.
- `nightly_policy_test.exs` and `ci_lane_split_test.exs` stayed green, so no step-list pin tripped (W4).
- The local and release-prep live run on a clean main clone belongs to Plan 11. The isolated worktree sandbox refuses git operations on a scratch clone, so the real node generators were not run end to end here. The harness covers the logic with shims.
- Bash 3.2 and jq 1.6 compatible: no mapfile, no associative arrays, and only `@tsv`, `test`, `//` and `tostring` in jq. The `ci-script-tests` run on ubuntu is the jq 1.6 proof.

## Known Stubs

None.

## Threat Flags

None. T-135-13: the vetted list is matched as data, and an injection fixture proves ledger text is not run. T-135-14: the verified-HEAD gate. T-135-15: the log is in mktemp, removed by trap, and only sentinel names are printed. T-135-16: the harness uses a local bare origin and shims, and the PR path makes no new network call. No package installs.

## Self-Check: PASSED
