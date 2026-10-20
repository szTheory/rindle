---
phase: 135-repository-and-code-craft-consolidation
plan: 14
subsystem: scripts/maintainer residue scanner, test/install_smoke, unit tests
status: complete
gap_closure: true
tags: [residue, tests, naming, CRAFT-04]
requires: ["135-11"]
provides:
  - "phase-ref class that sees snake_case, dashed, uppercase and CamelCase phase identifiers"
  - "planted positive and negative phase-ref fixtures"
  - "behavior-named generated-app scenario/contract tags and GeneratedAppHelper.scenario_enabled?/2"
  - "zero pending-removal entries across all seven allowlist shards"
affects: ["135 phase verification (CRAFT-04 gap)"]
tech-stack:
  added: []
  patterns: ["widen detector, regen shards, rename to zero pending in the same plan", "per-file assert/refute line counts held constant"]
key-files:
  created: []
  modified:
    - scripts/maintainer/scan_live_residue.exs
    - test/install_smoke/live_residue_scan_test.exs
    - scripts/maintainer/live_residue_allowlist/automation_generators.json
    - scripts/maintainer/live_residue_allowlist/automation_workflows.json
    - scripts/maintainer/live_residue_allowlist/install_smoke.json
    - test/install_smoke/generated_app_smoke_test.exs
    - test/install_smoke/support/generated_app/contracts.ex
    - test/install_smoke/support/generated_app_helper.ex
    - test/install_smoke/support/generated_app/profile_helpers.ex
    - test/rindle/streaming/provider/mux/telemetry_test.exs
    - test/rindle/test/mux_webhook_fixtures_test.exs
    - test/rindle/delivery/webhook_plug_test.exs
    - test/rindle/doctor_test.exs
    - test/rindle/admin/queries_test.exs
    - test/rindle/ops/runtime_checks_test.exs
    - test/rindle/admin/live/variants_runtime_actions_test.exs
    - examples/adoption_demo/e2e/admin-destructive-ux.spec.js
    - .planning/phases/135-repository-and-code-craft-consolidation/deferred-items.md
decisions:
  - "phase-ref regex is (?i:(?<![a-z0-9])phase[_ -]?\\d{1,3}(?!\\d))|(?<=[a-z0-9])Phase\\d{1,3}(?!\\d); class name unchanged so existing phase-ref keys still match"
  - "phase_133_transitions (9 lines) and the phase-133-evidence-* harness refs (3 keys, 14 lines) are classed immutable-receipt (D-135-03); those files stay byte-identical to origin/main"
  - "Rename map applied exactly as planned; the new tag atoms :public_compatibility_contract and :isolation_upgrade_contract share names with existing contract functions and facade labels, which is harmless (tags are a separate namespace) and matches what the tagged tests cover"
metrics:
  duration: "~75 min"
  completed: 2026-10-20
estimate:
  tokens: 90000
  tasks: 3
actuals:
  tokens: 7600
  tasks: 3
  commits: 3
plan_head_before: e8f6895abd00d188400c65a9499a68d8326201d4
plan_head_after: 528e16f4
---

# Phase 135 Plan 14: phase-ref gap closure Summary

The residue scanner's phase-ref class now catches `:phase_120_x`, `@phase_34_events`, `phase-35`, `PHASE_12` and `GeneratedAppPhase132Test`-style identifiers. Every live hit is either renamed to a behavior name (51 lines, 12 files) or classed immutable-receipt (Phase 133 census field and Nightly harness fixture refs, 23 lines). `--check --require-no-pending all` is clean.

## Tasks

| Task | Commit | Result |
|------|--------|--------|
| 1 Tracer: widened regex, planted fixtures, regen, immutable-receipt classing | 8fdbcc77 | RED confirmed at HEAD regex. Regen added exactly 74 pending lines (the plan's hit list). After jq classing: 51 pending phase-ref, all receipt literals immutable-receipt. Second regen byte-identical. |
| 2 Generated-app smoke suite renamed | ff5102cd | 41 lines renamed across 4 files; install_smoke shard has 0 pending |
| 3 Remaining unit-test and example identifiers, deferred item closed | 528e16f4 | 9 test lines + 1 e2e comment; all shards 0 pending |

## Verification

- `scan_live_residue.exs --check --require-no-pending all`: `ok (626 files, 203 hits, 170 allowlist entries)`, exit 0 (was 158 entries; +12 immutable-receipt keys)
- `jq` acceptance checks: receipt-literal entries all immutable-receipt (true), pending phase-ref after Task 1 = 51, pending after Task 3 = 0 (true)
- Old-name `git grep` over lib/test/scripts/examples/.github/mix.exs: 0 lines (51 at HEAD)
- Receipt-bound files (`verify_nightly_run.sh`, `test_verify_nightly_run.sh`, `evidence_census.exs`, `validate_evidence_census.exs`, `evidence_census_test.exs`, the 133 phase dir): `git diff --quiet origin/main` passes
- Default `mix test`: before 1643 tests (3 doctests, 0 failures, 2 invalid, 87 excluded, 4 skipped); after 1645 tests, 0 failures. +2 is the two new planted phase-ref tests. The 2 invalid are the pre-existing `DoctorThresholdsTest` flake (see Deferred), included in the total both times.
- `mix test test/install_smoke`: 365 tests, 0 failures, 17 excluded
- `mix test test/install_smoke/generated_app_smoke_test.exs`: 33 tests, 0 failures, 16 excluded
- `mix format --check-formatted` (whole repo): pass
- `mix credo --strict` on the 13 touched Elixir files: 29 pre-existing design/refactor suggestions, none on changed lines, no warnings
- `validate_artifact_ledger.sh --offline --require-settled`: `ok (offline, 2896 files, 46 classes)`
- `scripts/ci/test_verify_nightly_run.sh`: passed 187, failed 0
- `automation_first_contract.sh`: passed
- `grep -rn ".planning/phases/135" scripts test .github lib`: no matches

### assert/refute line counts (before = after)

| File | Count |
|------|-------|
| test/install_smoke/generated_app_smoke_test.exs | 275 |
| test/install_smoke/support/generated_app/contracts.ex | 0 |
| test/install_smoke/support/generated_app_helper.ex | 0 |
| test/install_smoke/support/generated_app/profile_helpers.ex | 7 |
| test/rindle/streaming/provider/mux/telemetry_test.exs | 34 |
| test/rindle/test/mux_webhook_fixtures_test.exs | 8 |
| test/rindle/delivery/webhook_plug_test.exs | 60 |
| test/rindle/doctor_test.exs | 63 |
| test/rindle/admin/queries_test.exs | 84 |
| test/rindle/ops/runtime_checks_test.exs | 73 |
| test/rindle/admin/live/variants_runtime_actions_test.exs | 94 |
| test/install_smoke/live_residue_scan_test.exs | 55 before, 59 after (the two new tests add 4) |

### Generated-app scenario with the renamed tag

`mix test test/install_smoke/generated_app_smoke_test.exs --only public_compatibility_scenario` (MinIO up via `scripts/ensure_minio.sh`) selected exactly the public-compatibility module: 18 tests, 1 run, 17 excluded. So the renamed tag gates module definition through `scenario_enabled?/2`. The one test failed on `assert report.smoke_exit_code == 0` (left 2). origin/main 65395f2c with `--only phase_120_public_compat` fails the same way with the same shape, so the failure is a pre-existing local-host issue and not caused by the rename. The isolation-upgrade scenario was not run.

## Deviations from Plan

None in the shipped code. The rename map, regex and reasons were applied as written.

Process notes:
- The first scenario run exported `MIX_DEPS_PATH`/`MIX_BUILD_PATH`. The generated Phoenix app inherited them and fetched newer deps (phoenix 1.8.16 and four others) into the shared scratch deps dir. A lock-respecting `mix deps.get` restored it (`mix.lock` unchanged). The comparison runs then used in-worktree copies with no `MIX_*_PATH`, and those copies were deleted afterwards. The full suite was re-run after the restore: 1645 tests, 0 failures.
- I added a "From 135-14" section to deferred-items.md for the two pre-existing local findings below. The plan's deferred-items acceptance still holds: `From 135-10` 0, `From 135-1[13]` 2.

## Deferred Issues

- `Rindle.DoctorThresholdsTest` setup_all is invalidated when it runs in the same invocation as `test/install_smoke` with an out-of-tree build path. It passes alone and also appears in the pre-edit baseline.
- Generated-app public-compatibility scenario: `smoke_exit_code` 2 locally on both this branch and origin/main.

## Delivery

PR subject: `test: catch snake_case phase identifiers in residue scan and rename phase-named test tags`

## Self-Check: PASSED

- Commits 8fdbcc77, ff5102cd, 528e16f4 are ancestors of HEAD
- All modified files listed above exist
