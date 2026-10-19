---
phase: 135-repository-and-code-craft-consolidation
plan: 02
subsystem: testing
tags: [craft, readability-trace, boundary-check, public-surface, ci-gate]
requires: ["135-01"]
provides:
  - "scripts/maintainer/readability_changes.json: trace with the embedded frozen candidate ledger identity and an empty changes list"
  - "scripts/maintainer/validate_readability_trace.sh: --offline / --base REF / --verify-source validator with pinned identity constants"
  - "scripts/maintainer/craft_boundary_check.sh BASE: forbidden-path and mix.exs version/deps/package guard"
  - "scripts/ci/test_craft_contract_tools.sh: 52-case fixture harness for both scripts"
  - "Rindle.Test.PublicSurface (render/0, render/1, canonical_lane?/1, diff/2) plus test/fixtures/public_surface.txt and the snapshot test"
  - "ci-script-tests steps: Craft contract tools harness, Readability trace shape (offline)"
affects: [135-03, 135-04, 135-05, 135-06, 135-07, 135-08, 135-09, 135-10, 135-11, 135-12, 135-13]
tech-stack:
  added: []
  patterns: ["identity pinned in the validator, not only in the data file", "boundary compared at merge-base(BASE, HEAD) plus working tree", "export list from __info__/1 filtered by docs-chunk visibility"]
key-files:
  created:
    - scripts/maintainer/readability_changes.json
    - scripts/maintainer/validate_readability_trace.sh
    - scripts/maintainer/craft_boundary_check.sh
    - scripts/ci/test_craft_contract_tools.sh
    - test/support/public_surface.ex
    - test/rindle/public_surface_snapshot_test.exs
    - test/fixtures/public_surface.txt
  modified:
    - .github/workflows/ci.yml
key-decisions:
  - "Public exports are taken from __info__(:functions | :macros) and kept only when a non-hidden docs-chunk entry covers that arity (defaults included); exports with no docs entry are compiler-generated and excluded"
  - "Public modules are the :rindle application modules whose compiled source is under lib/ and whose moduledoc is not hidden; test/support modules never enter the fixture"
  - "craft_boundary_check.sh compares mix.exs blocks and the committed diff at merge-base(BASE, HEAD), and also counts staged, unstaged and untracked files"
status: complete
duration: ~1h
completed: 2026-10-19
commits: 3
plan_head_before: 7fec8297c9ed2c569743f37921be6283673f87e0
plan_head_after: 14ec789f7c9b189eb18d0abbe35ee03816c34999
actuals:
  tokens: 13200
  tasks: 3
  commits: 3
---

# Phase 135 Plan 02: Readability trace, craft boundary and public surface gates Summary

Offline readability-trace validator with the frozen candidate ledger identity pinned in the script, a merge-base forbidden-path and mix.exs block guard, and a lane-gated public surface snapshot, all wired as merge-blocking checks.

## Tasks

| Task | Commit | Result |
| ---- | ------ | ------ |
| 1 Tracer: trace file, offline validator, harness, two ci-script-tests steps | af45fa43 | 27 trace cases pass; committed trace `ok (offline)`; tracer gate re-run end-to-end before expanding |
| 2 craft_boundary_check.sh with real-git fixtures | 28487d08 | 25 boundary cases pass (18 single-mutation cases plus uncommitted edit, all-reasons, moved base, usage, injection); `craft_boundary_check.sh HEAD` and `origin/main` exit 0 |
| 3 Public surface snapshot module, fixture, test | 14ec789f | 4 tests pass; fixture has 67 modules (57 `Rindle*`), 188 fun, 3 macro, 33 callback, 15 migration lines |

## Verification

- `bash scripts/ci/test_craft_contract_tools.sh`: 52 passed, 0 failed
- `validate_readability_trace.sh --offline` on the committed trace: ok; `--base HEAD`: ok; `--verify-source` against the frozen ledger file: ok (maintainer-only, not in CI)
- `craft_boundary_check.sh HEAD`: ok
- `mix test` on the snapshot, api_surface_boundary, nightly_policy, ci_lane_split, quality_signal_policy, ci_observability, ci_cache_hygiene, live_residue_scan, planning_path_hygiene and async_safety_guard tests: 132 tests, 0 failures
- `mix test test/install_smoke`: 359 tests, 0 failures, 17 excluded
- `mix coveralls test/rindle/public_surface_snapshot_test.exs`: 4 tests, 0 failures (the snapshot holds under cover-compiled modules)
- `scan_live_residue.exs --check`: `ok (618 files, 1348 hits, 1313 allowlist entries)`; no allowlist change was needed, so `unit_tests_b.json` is untouched
- `mix format --check-formatted` and `mix credo --strict` on the two Elixir files: clean
- Acceptance greps: identity sha256 in the validator, no `eval` in either script, 2 ci.yml matches, 15 migration lines for 15 migrations, skip reason names the canonical lane, no phase-135 planning path under scripts, test, .github or lib
- `./scripts/maintainer/automation_first_contract.sh`: passed
- Simulated drift (fixture with one line removed) fails with `+ fun Rindle.upload/3` and prints the regenerate command; fixture restored afterwards

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Drift sample module moved into test/support**
- **Found during:** Task 3
- **Issue:** `mix test` compiles test files with the `:docs` compiler option off, so a module compiled in the test (via `Code.compile_string`) has no docs chunk and `Code.fetch_docs/1` cannot see it; the simulated-drift test could not observe the extra function.
- **Fix:** `Rindle.Test.PublicSurface.DriftSample` (public `extra/1`, hidden `hidden_helper/0`) lives in `test/support/public_surface.ex`, compiled with docs as part of the test build. It is excluded from `lib_modules/0` because its source is not under `lib/`, and the test asserts it is absent from the real module list. No global compiler-option or code-path mutation, so the test stays `async: true`.
- **Files modified:** test/support/public_surface.ex, test/rindle/public_surface_snapshot_test.exs
- **Commit:** 14ec789f

### Additions beyond the plan text

- The fixture also lists public macros (`macro Mod.name/arity`, 3 lines) so a macro API change is caught.
- `craft_boundary_check.sh` also counts staged, unstaged and untracked files and rejects an option-shaped BASE (exit 64), and compares at the merge base so a base that moved on after branching does not cause false rejections.
- Validator adds `schema`, `detector`, `pr`, `anchor` shape and `changes` type rules alongside the planned ones.

### Notes

- Function listing choice (RESEARCH assumption A3): the docs-chunk visibility filter over `__info__/1` exports is used on the canonical lane; the 1.15 / OTP 26 leg skips the snapshot module through the version-gated `@moduletag skip`, so no fallback path was needed. No local 1.15 toolchain exists; the skipped-not-failed outcome on that leg is proven by the post-merge Quality matrix run.
- Task 2 was written test-and-implementation together rather than strict RED first; every boundary case asserts the exact REJECT reason, so a missing rule fails its case.
- This branch itself adds `test/fixtures/public_surface.txt`, so `craft_boundary_check.sh origin/main` run against this PR would reject it by design; the check is for readability PRs, not for the PR that introduces the fixture.
- Step-list pins: no install_smoke test pins the `ci-script-tests` step list; no file under `test/install_smoke/` was edited.

## Known Stubs

None. `changes: []` in the trace is the intended starting state; readability tranche plans append entries.

## Threat Flags

None. Trace and baseline values reach jq only through `--slurpfile`, `--arg` and `--argjson`; boundary paths are read NUL-delimited and only compared; both scripts are covered by injection fixtures. The pinned identity mitigates T-135-04, the tested boundary list T-135-05, and the fixture being a forbidden path T-135-06. No package installs.

## Self-Check: PASSED

All seven created files exist; commits af45fa43, 28487d08 and 14ec789f are ancestors of HEAD.
