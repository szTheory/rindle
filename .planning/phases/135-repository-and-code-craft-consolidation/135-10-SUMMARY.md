---
phase: 135-repository-and-code-craft-consolidation
plan: 10
subsystem: test/install_smoke, root guard tests
status: complete
tags: [residue, tests, naming, mojibake, CRAFT-04, CRAFT-06]
requires: ["135-01", "135-03", "135-06", "135-08", "135-09", "135-13"]
provides:
  - "install_smoke residue shard with zero pending-removal entries"
  - "behavior-named CI policy tests (ci_lane_split, ci_observability, ci_cache_hygiene and the rest of install_smoke)"
  - "test/fixtures/ci_timing/topology_projection.json (renamed from the phase-numbered fixture, identical bytes)"
affects: ["135-11 (--require-no-pending all is already green)"]
tech-stack:
  added: []
  patterns: ["rename-only residue tranche; shard shrinks in the same commit as the edit", "per-file assert/refute line counts held constant"]
key-files:
  created:
    - test/fixtures/ci_timing/topology_projection.json
  modified:
    - test/install_smoke/docs_parity/operations_test.exs
    - test/install_smoke/ci_lane_split_test.exs
    - test/install_smoke/ci_observability_test.exs
    - test/install_smoke/ci_cache_hygiene_test.exs
    - test/install_smoke/evidence_census_test.exs
    - test/install_smoke/release_guard_meta_test.exs
    - test/install_smoke/refactor_contract_test.exs
    - test/install_smoke/support/generated_app/patcher.ex
    - test/install_smoke/support/generated_app/smoke_source.ex
    - test/async_safety_guard_test.exs
    - test/focus_visible_modality_guard_test.exs
    - test/planning_path_hygiene_test.exs
    - scripts/maintainer/live_residue_allowlist/install_smoke.json
decisions:
  - "Tag :phase_132_topology_recovery renamed to :required_job_topology; nothing outside the test file referenced it"
  - "SAFE-01 in refactor_contract and quality_signal_policy test names and messages became 'the preservation contract'; the ci.yml step name 'Run SAFE-01 preservation contract' stays contract-classed"
  - "Refuted stale-text literals (Phase 42, Phase 11, v1.10 roadmap text, obsolete audit filenames) are classed fixture: the literal is the thing the test refutes"
  - "Evidence-census assert_invalid literals that mirror validate_evidence_census.exs transition errors are classed immutable-receipt (D-135-03)"
metrics:
  duration: "~75 min"
  completed: 2026-10-19
actuals:
  tokens: 58650
  tasks: 3
  commits: 3
commits: 3
plan_head_before: 1e03234c5e7ca361122f397668747865f8a57835
plan_head_after: 8a078ec7a4c4e5a5a46e81328f3ea8af86dd9d6e
---

# Phase 135 Plan 10: Policy test names and mojibake (residue tranche C) Summary

The install_smoke policy tests now have names that describe what they assert, not requirement or decision ids. The mojibake in operations_test.exs is fixed, and the phase-numbered timing fixture has a new name. The install_smoke shard has no pending-removal entries left, and `--require-no-pending all` passes.

## Tasks

| Task | Name | Commit | Result |
|------|------|--------|--------|
| 1 (tracer) | Mojibake fix in operations_test.exs | 3dc0cf90 | Both double-encoded dash sequences are now ASCII and the TRUTH-07 / Plan 01 prose is rewritten. 5 shard entries removed. docs_parity: 35 tests, 0 failures |
| 2 | CI policy tests renamed, timing fixture renamed | 31935b5d | 188 shard entries removed. The three files: 56 tests, 0 failures. `cmp` against origin/main bytes passes. Ledger validator ok, because the `test-fixtures` glob covers the new path |
| 3 | Remaining install_smoke and root tests | 8a078ec7 | Shard went from 167 entries to 40, with 0 pending-removal: 28 fixture, 6 policy, 4 immutable-receipt, 2 contract |

## Assertion preservation (T-135-26)

Default suite: 1642 tests and 3 doctests both before and after the plan. Before: 2 failures and 2 invalid. The failures came from the residue scan test, which saw in-progress edits during the baseline run. The invalid tests are the known DoctorThresholds MIX_BUILD_PATH artifact. After: 0 failures, 87 excluded, 4 skipped.

Per-file `grep -cE '^\s*(assert|refute)'` counts, origin/main → HEAD. None changed:

| File | Before | After |
|------|--------|-------|
| test/async_safety_guard_test.exs | 6 | 6 |
| test/focus_visible_modality_guard_test.exs | 5 | 5 |
| test/planning_path_hygiene_test.exs | 4 | 4 |
| test/install_smoke/ci_lane_split_test.exs | 85 | 85 |
| test/install_smoke/ci_observability_test.exs | 33 | 33 |
| test/install_smoke/ci_cache_hygiene_test.exs | 60 | 60 |
| test/install_smoke/docs_parity/operations_test.exs | 56 | 56 |
| test/install_smoke/docs_parity/product_and_admin_test.exs | 40 | 40 |
| test/install_smoke/dialyzer_ignore_policy_test.exs | 9 | 9 |
| test/install_smoke/evidence_census_test.exs | 130 | 130 |
| test/install_smoke/generated_app_smoke_test.exs | 275 | 275 |
| test/install_smoke/live_truth_parity_test.exs | 137 | 137 |
| test/install_smoke/nightly_policy_test.exs | 85 | 85 |
| test/install_smoke/package_metadata_test.exs | 114 | 114 |
| test/install_smoke/phoenix_tus_truth_parity_test.exs | 39 | 39 |
| test/install_smoke/quality_signal_policy_test.exs | 33 | 33 |
| test/install_smoke/refactor_contract_test.exs | 17 | 17 |
| test/install_smoke/release_docs_parity_test.exs | 62 | 62 |
| test/install_smoke/release_guard_meta_test.exs | 45 | 45 |
| test/install_smoke/streaming_cancel_docs_parity_test.exs | 19 | 19 |
| test/install_smoke/support/generated_app/patcher.ex | 0 | 0 |
| test/install_smoke/support/generated_app/profile_helpers.ex | 7 | 7 |
| test/install_smoke/support/generated_app/smoke_source.ex | 137 | 137 |

The diff changes only comments, moduledoc prose, test names, failure-message strings, the fixture path attribute, two tag atoms, and `mix format` re-wrapping of shortened test headers. No assertion expression changed.

## Verification

- `scan_live_residue.exs --check --require-no-pending install_smoke`: ok (624 files, 180 hits, 158 allowlist entries)
- `scan_live_residue.exs --check --require-no-pending all`: ok. All seven shards have zero pending-removal entries, so the Plan 11 gate is already satisfied.
- `--regen-baseline`: `git diff --stat` showed only `install_smoke.json` changed, and a second regen was byte-identical.
- `mix test test/install_smoke`: 362 tests, 0 failures, 17 excluded
- `mix test test/install_smoke/live_residue_scan_test.exs` plus the three root guard tests: 35 tests, 0 failures
- Full default `mix test`: 3 doctests, 1642 tests, 0 failures, 87 excluded, 4 skipped
- `mix format --check-formatted`: ok
- `mix credo --strict` on the 23 touched Elixir files: one pre-existing `[F]` (patcher.ex:5 arity 9, untouched line) and design suggestions only. None are on edited lines.
- `validate_artifact_ledger.sh --offline`: ok (2890 files, 46 classes)
- `./scripts/maintainer/automation_first_contract.sh`: passed
- `grep -rn "\.planning/phases/135" scripts test .github lib`: no match

## Deviations from Plan

**1. [Rule 3 - commit hygiene] The fixture rename briefly landed in the Task 1 commit.** The `git mv` was already staged when Task 1 was committed. The commit was amended locally before anything else, so the Task 1 commit contains only operations_test.exs and the shard, and the rename lives in the Task 2 commit together with its reader.

**2. [Rule 2 - accuracy] Unflagged planning-era text in the same comments was rewritten.** This covers `T-93-05`, `T-103-03/05`, `T-111-09/10`, `T-112-02`, `T-113-04/05`, `V14`, `SC5`, `RESEARCH Pattern 2 / Open Q1 / Pitfall`, `CR-/WR-` review ids, `103-VALIDATION.md`, the `5c30b7f` history note, and the "Previously" narration in generated-app support comments. None of these were shard entries.

**3. [Scope] Unreferenced `@tag :plan108` renamed to `:copied_receipt_isolation`.** Nothing selects on it. The `phase_120_*` and `phase_132_generator_contract` tag atoms and helper names in the generated-app suite were left alone because they are functional identifiers. They are logged in `deferred-items.md`.

**4. [Precondition timing] The main push CI run for 1e03234c (Plan 13's merge) was `in_progress` when this plan ran.** The run for 30a59ef5 concluded success, and the fingerprint-fixture and landing-closure checks pass on origin/main. Recheck the 1e03234c conclusion before opening the PR.

## Notes for the orchestrator

- Branch `test/135-10-policy-test-names`, based on origin/main 1e03234c. Not pushed.
- PR subject: `test: rename requirement-id policy tests to behavior names and fix mojibake`.
- No ci.yml change, so this does not need to be serialized with ci.yml PRs.

## Known Stubs

None.

## Self-Check: PASSED

- test/fixtures/ci_timing/topology_projection.json exists, and test/fixtures/ci_timing/phase_132_topology_projection.json is gone.
- Commits 3dc0cf90, 31935b5d and 8a078ec7 are ancestors of HEAD.
- install_smoke.json has 0 pending-removal entries and no mojibake entry other than the 2 fixture regression literals.
