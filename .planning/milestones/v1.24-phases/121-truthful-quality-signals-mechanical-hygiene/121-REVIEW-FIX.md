---
phase: 121
fixed_at: 2026-08-22T00:00:00-04:00
review_path: /Users/jon/projects/rindle/.planning/phases/121-truthful-quality-signals-mechanical-hygiene/121-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 121: Code Review Fix Report

**Fixed at:** 2026-08-22T00:00:00-04:00
**Source review:** `/Users/jon/projects/rindle/.planning/phases/121-truthful-quality-signals-mechanical-hygiene/121-REVIEW.md`
**Iteration:** 1

**Summary:**

- Findings in scope: 3
- Fixed: 3
- Skipped: 0

## Fixed Issues

### CR-01: Public-contract Credo gate omits public APIs

**Files modified:** `.credo.exs`, `test/install_smoke/credo_policy_test.exs`
**Commit:** 7990cf9
**Applied fix:** Added every previously omitted ExDoc-group source file and replaced the count-only assertion with exact source-path equality derived from `Mix.Project.config()[:docs][:groups_for_modules]`.
**Verification:** Re-read the changed profile and test; `git diff --check` passed. The focused ExUnit command was attempted but could not start because the isolated worktree has no fetched Mix dependencies.

### WR-01: Local merge-parity alias requires an undeclared jq installation

**Files modified:** `scripts/maintainer/credo_quality.sh`, `scripts/maintainer/credo_quality_normalize.exs`, `test/install_smoke/credo_policy_test.exs`
**Commit:** ec84f08
**Applied fix:** Replaced the `jq` normalization pipeline with a project-runtime Elixir/Jason normalizer and asserted the aggregate shell script no longer references `jq`.
**Verification:** Re-read all changed sections; `bash -n scripts/maintainer/credo_quality.sh`, Elixir parse checks for the normalizer and policy test, and `git diff --check` passed. Focused ExUnit execution was blocked by unfetched worktree dependencies.

### WR-02: Quality-policy test can pass when required steps are disabled

**Files modified:** `mix.exs`, `test/install_smoke/quality_signal_policy_test.exs`
**Commit:** 372b784
**Applied fix:** Added the direct test-only YAML parser dependency and rewrote the policy test to inspect parsed jobs and steps, require expected commands and non-advisory status, verify canonical-matrix conditions, and reject a false-condition regression fixture.
**Verification:** Re-read the changed test; Elixir parse checks for the test and `mix.exs`, plus `git diff --check`, passed. Focused ExUnit execution was blocked by unfetched worktree dependencies.

---

_Fixed: 2026-08-22T00:00:00-04:00_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 1_

## Orchestrator follow-up

The first fixer pass exposed two executable defects that its isolated syntax checks could not
catch: the direct YAML dependency needed the same `[:dev, :test]` environments as its existing
transitive declaration, and the `mix run` script form must pass its argument without `--`.
Commit `2f174b0` corrected both, mapped ExDoc modules to their compiled source paths, and added the
small missing specs required by the now-complete public-contract boundary.

Fresh verification in the primary checkout passed:

- `mix deps.get`
- `mix format --check-formatted`
- `mix test test/install_smoke/credo_policy_test.exs test/install_smoke/quality_signal_policy_test.exs --seed 0` (12 tests)
- `bash scripts/maintainer/credo_quality.sh`

The standard-depth re-review then reported zero findings in `121-REVIEW.md`.
