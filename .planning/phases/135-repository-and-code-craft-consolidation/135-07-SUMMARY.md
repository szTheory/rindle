---
phase: 135-repository-and-code-craft-consolidation
plan: 07
subsystem: test-residue
tags: [craft, residue, tests, comments]
status: complete
requires: ["135-02", "135-04"]
provides:
  - "unit_tests_a area (top-level test/rindle files plus admin, av, backward_compat, config, contracts, delivery and domain) free of planning-era ids, with behavior-named tests"
  - "scripts/maintainer/live_residue_allowlist/unit_tests_a.json with zero pending-removal entries (6 contract entries remain)"
affects: [scripts/maintainer/live_residue_allowlist/unit_tests_a.json]
tech-stack:
  added: []
  patterns: ["comment and test-name-only residue tranche; shard shrinks in the same commit as the edit"]
key-files:
  created: []
  modified:
    - test/rindle/delivery/streaming_dispatch_test.exs
    - test/rindle/api_surface_boundary_test.exs
    - test/rindle/batch_owner_erasure_task_test.exs
    - test/rindle/behaviour_docs_test.exs
    - test/rindle/capability_test.exs
    - test/rindle/convenience_api_test.exs
    - test/rindle/delivery_test.exs
    - test/rindle/doctor_thresholds_test.exs
    - test/rindle/owner_erasure_batch_proof_test.exs
    - test/rindle/runtime_status_task_test.exs
    - test/rindle/admin/live/actions_live_test.exs
    - test/rindle/admin/live/home_assets_upload_test.exs
    - test/rindle/admin/live/variants_runtime_actions_test.exs
    - test/rindle/admin/queries_test.exs
    - test/rindle/admin/router_test.exs
    - test/rindle/av/metadata_sanitizer_test.exs
    - test/rindle/av/subprocess_epipe_canary_test.exs
    - test/rindle/av/subprocess_epipe_test.exs
    - test/rindle/av/subprocess_stdin_test.exs
    - test/rindle/backward_compat/v13_digest_snapshot_test.exs
    - test/rindle/config/config_test.exs
    - test/rindle/config/repo_override_isolation_test.exs
    - test/rindle/contracts/telemetry_contract_test.exs
    - test/rindle/delivery/webhook_plug_test.exs
    - test/rindle/domain/lifecycle_fsm_test.exs
    - test/rindle/domain/media_provider_asset_test.exs
    - test/rindle/domain/media_schema_test.exs
    - test/rindle/domain/migration_test.exs
    - test/rindle/domain/provider_asset_fsm_test.exs
    - scripts/maintainer/live_residue_allowlist/unit_tests_a.json
decisions:
  - "The six error-test literals that mirror Rindle.Error message text (v1.4, v1.6, pre-v1.13, Phase 34) are classed contract, not rewritten (D-135-05)"
  - "\"security invariant 14\" stays in the MediaProviderAsset describe name because guides/streaming_providers.md uses the same public numbering"
metrics:
  duration: "about 50 min"
  completed: 2026-10-19
estimate:
  tokens: 80000
actuals:
  tokens: 21000
  tasks: 3
  commits: 3
plan_head_before: d8bf703db1b5ffcf683f17ca242fef12ee26921f
plan_head_after: 3bf5dc40aa8e159aba358c4ff33b2ddcd629bd64
---

# Phase 135 Plan 07: unit_tests_a residue tranche Summary

Tests in the unit_tests_a area now describe the behavior they protect instead of the planning history behind them. Decision ids (D-NN, D-89-0N, D-98-NN), review findings (CR-0N, WR-0N), UI-SPEC sections, phase, plan and milestone references, and "previously/no longer" narration were removed or rewritten as present-tense rationale. Requirement-id test names were renamed to behavior names (D-135-07). The unit_tests_a shard went from 140 entries (all pending-removal) to 6 entries (all contract). No assertion, test or fixture value changed.

## Tasks

| Task | Name | Commit | Shard entries |
|------|------|--------|---------------|
| 1 | Tracer: streaming_dispatch_test.exs | 0279e433 | 15 removed |
| 2 | Files directly under test/rindle/ | b12bcec6 | 28 removed, 6 reclassified as contract |
| 3 | admin, av, backward_compat, config, contracts, delivery, domain | 3bf5dc40 | 91 removed |

15 + 28 + 6 + 91 = 140, the full pre-plan shard. After each `--regen-baseline`, `git diff --stat` showed `unit_tests_a.json` as the only shard that changed. Its diff contained only deleted entries plus the six `reason_class`/`reason` changes.

## Baselines and counts

- Partition test count, measured before the first edit and over `test/rindle/*_test.exs` plus the seven subtrees: **3 doctests, 564 tests, 0 failures, 21 excluded**. After all edits: **3 doctests, 564 tests, 0 failures, 21 excluded**.
- Default-suite `mix test` after the plan: **3 doctests, 1639 tests, 0 failures, 87 excluded, 4 skipped**. That matches the 1639 recorded by 135-04 on the same base. This run had no `invalid` tests.
- For every one of the 29 edited test files, the counts on origin/main and on HEAD are equal, both for `test`/`describe` macros and for `^\s*(assert|refute)` lines (mismatch=0). `git diff origin/main -- test/` contains 0 added or removed assert/refute lines.

## Verification

- `scan_live_residue.exs --check`: ok (618 files, 1115 hits, 1081 allowlist entries)
- `scan_live_residue.exs --check --require-no-pending unit_tests_a`: ok
- `jq '[.entries[]|select(.reason_class=="pending-removal")]|length'` on unit_tests_a.json returns 0
- Strict partition: `git diff --name-only origin/main`, filtered by the plan's allow-list, prints nothing
- Tests for each task's files:
  - Task 1: 17 tests, 0 failures
  - Task 2: the 12 top-level files, 145 tests, 0 failures
  - Task 3: the full partition, 564 tests, 0 failures
- `mix test test/install_smoke`: 359 tests, 0 failures, 17 excluded
- `mix format --check-formatted`: clean, both on the touched files and repo-wide
- `mix credo --strict` on the touched files: two findings, both on lines this plan did not edit, so both pre-existing:
  - `router_test.exs:5`: nested-module alias suggestion
  - `media_schema_test.exs:9`: alias ordering
- `./scripts/maintainer/automation_first_contract.sh`: passed
- `! grep -rn ".planning/phases/135" scripts test .github lib`: clean

## Deviations from Plan

**1. [Rule 2 - D-135-07 completeness] Requirement ids the scanner does not cover were renamed.**
- The scanner's requirement prefix list does not include PROOF, MUX or AV-02, so five test names carrying those ids were not on the worklist:
  - `PROOF-06: partial failure` became `partial failure across owners`
  - `PROOF-05: shared assets` / `PROOF-05: partial failure` became `shared assets` / `partial failure`
  - `--provider-stuck (MUX-14)` became `--provider-stuck`
  - `cancelled is a valid state (AV-02-04 prerequisite)` became `cancelled is a valid state`
- D-135-07 requires renaming id-bearing test names, so these were renamed. The renames are in Task 3's commit, including the three that sit in top-level files Task 2 owned.
- `test/rindle/ops/runtime_status_test.exs:404` `(MUX-14)` is in the unit_tests_b area and was left alone.

**2. [Rule 1 - accuracy] Comments rewritten beyond the flagged lines.**
- In the same blocks as flagged hits, two pieces of text were stale and were removed:
  - `(threat T-110-06)` in repo_override_isolation_test.exs
  - the "RED signal until the module ships" narration in convenience_api_test.exs, which is false now that Rindle.Error exists
- The 135-04 follow-up was applied: the canary comment now points to the `# NOTE (MuonTrap #98)` block, matching lib/rindle/av/subprocess.ex.

**3. [Note] telemetry_contract_test.exs edit.** The only change there is that the moduledoc line naming `.planning/phases/05-...` was removed. It was a comment-equivalent edit, and no event name changed. `craft_boundary_check.sh` lists this path as a readability-change boundary file. That script guards readability-pilot PRs, and no CI lane runs it on residue tranches, but it would flag this branch if someone ran it against it.

## Environment notes

- Local Postgres hit `too_many_connections` twice because concurrent agents were using it. The partition run was retried after a capacity poll and passed. This was environmental contention, not a test failure.

## Known Stubs

None.

## Self-Check: PASSED

- Commits 0279e433, b12bcec6 and 3bf5dc40 are ancestors of HEAD on `test/135-07-unit-tests-a-residue`.
- unit_tests_a.json holds 6 entries, all `contract` with a non-empty reason.
