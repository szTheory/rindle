---
phase: 126
slug: curated-type-ratchet
status: ready
nyquist_compliant: true
wave_0_complete: false
created: 2026-08-23
---

# Phase 126 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via Mix; Dialyxir in the supported Nightly home cell |
| **Config file** | `mix.exs`, `.dialyzer_ignore.exs`, `.github/workflows/nightly.yml` |
| **Quick run command** | Focused owner test command named by each task |
| **Full suite command** | `mix ci` plus `bash scripts/maintainer/refactor_contract.sh` |
| **Supported type authority** | Nightly `dialyzer` on Elixir 1.17 / OTP 27, exact branch head |
| **Estimated local runtime** | Focused suites <120 seconds; full local suite varies; Nightly is asynchronous |

## Sampling Rate

- **After every source-bearing task commit:** Run that owner's focused behavior tests and `bash scripts/maintainer/refactor_contract.sh`.
- **After every baseline-policy task:** Run the focused policy and CI-topology tests.
- **After every plan wave:** Run the phase aggregate named by the plan.
- **Before phase verification:** Run `mix ci`, SAFE-01, repository hygiene, exact-head PR CI, and the supported Nightly Dialyzer job.
- **Max local feedback latency:** 120 seconds for a focused task check; asynchronous CI is monitored to a terminal result.

## Per-Task Verification Map

Every task from the six sequential plans has a runnable local check or exact supported-CI receipt. Source-bearing tasks pair focused owner behavior with SAFE-01; every plan-level probe/finalizer binds evidence to a pushed Nightly `headSha` on Elixir 1.17 / OTP 27.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 126-01-01 | 01 | 1 | TYPE-01, TYPE-02 | T-126-01 | Strict tuples only; immutable 45-entry receipt | unit/policy | `MIX_ENV=test mix test test/install_smoke/dialyzer_ignore_policy_test.exs test/install_smoke/ci_lane_split_test.exs test/install_smoke/ci_cache_hygiene_test.exs --seed 0` | plan creates policy test | ⬜ pending |
| 126-01-02 | 01 | 1 | TYPE-01, TYPE-02, SAFE-01 | T-126-02, T-126-03 | Exact-head home-cell/topology receipt | supported CI + structural | `gh run view RUN_ID --json jobs` plus the three focused policy/topology/cache tests | existing inputs | ⬜ pending |
| 126-02-01 | 02 | 2 | TYPE-01, TYPE-02 | T-126-01, T-126-02 | Source-unchanged migration probe precedes edits | supported CI/policy | Exact-head Nightly failed-log inspection plus `dialyzer_ignore_policy_test.exs` | ✅ | ⬜ pending |
| 126-02-02 | 02 | 2 | TYPE-01, SAFE-01 | T-126-04 | Dispatcher/host behavior and migration ownership unchanged | owner integration + SAFE-01 | `MIX_ENV=test mix test test/rindle/migration_fast_test.exs test/rindle/migration_test.exs test/install_smoke/docs_parity/install_and_migrations_test.exs --seed 0 && bash scripts/maintainer/refactor_contract.sh` | ✅ | ⬜ pending |
| 126-02-03 | 02 | 2 | TYPE-01, TYPE-02, SAFE-01 | T-126-02, T-126-04 | V1 refusals/DDL/reversal unchanged; supported slice green | owner integration + SAFE-01 + supported CI | Migration fast/full tests, SAFE-01, exact-head Nightly Dialyzer success | ✅ | ⬜ pending |
| 126-03-01 | 03 | 3 | TYPE-01, TYPE-02 | T-126-01, T-126-02 | Source-unchanged operational/runtime probe | supported CI/policy | Exact-head Nightly failed-log inspection plus policy test | ✅ | ⬜ pending |
| 126-03-02 | 03 | 3 | TYPE-01, SAFE-01 | T-126-05 | Task/Admin/diagnostic results, telemetry, errors unchanged | owner integration + SAFE-01 | `MIX_ENV=test mix test test/rindle/batch_owner_erasure_task_test.exs test/rindle/admin/live/actions_live_test.exs test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_checks_streaming_test.exs --seed 0 && bash scripts/maintainer/refactor_contract.sh` | ✅ | ⬜ pending |
| 126-03-03 | 03 | 3 | TYPE-01, TYPE-02, SAFE-01 | T-126-02, T-126-05 | Runtime-status/HTML/ProcessVariant behavior unchanged; supported slice green | owner integration + SAFE-01 + supported CI | Focused status/HTML/worker tests, SAFE-01, exact-head Nightly Dialyzer success | ✅ | ⬜ pending |
| 126-04-01 | 04 | 4 | TYPE-01, TYPE-02 | T-126-01, T-126-07 | Source-unchanged storage probe; opacity preserved | supported CI/policy | Exact-head Nightly failed-log inspection plus policy test | ✅ | ⬜ pending |
| 126-04-02 | 04 | 4 | TYPE-01, SAFE-01 | T-126-06, T-126-07 | GCS/Local streams, cleanup, and tagged errors unchanged | owner integration + SAFE-01 | `MIX_ENV=test mix test test/rindle/storage/gcs/client_test.exs test/rindle/storage/gcs_test.exs test/rindle/storage/gcs_concatenate_test.exs test/rindle/storage/local_test.exs test/rindle/storage/local_tus_test.exs --seed 0 && bash scripts/maintainer/refactor_contract.sh` | ✅ | ⬜ pending |
| 126-04-03 | 04 | 4 | TYPE-01, TYPE-02, SAFE-01 | T-126-02, T-126-06 | S3 stream/tail behavior unchanged; supported slice green | owner integration + SAFE-01 + supported CI | Focused S3 tests, SAFE-01, exact-head Nightly Dialyzer success | ✅ | ⬜ pending |
| 126-05-01 | 05 | 5 | TYPE-01, TYPE-02 | T-126-01, T-126-07 | Source-unchanged tus/Mux/final-atom probe | supported CI/policy | Exact-head Nightly failed-log inspection plus policy test | ✅ | ⬜ pending |
| 126-05-02 | 05 | 5 | TYPE-01, SAFE-01 | T-126-07, T-126-08 | Tus opacity/protocol and Mux response/error behavior unchanged | owner integration + SAFE-01 | `MIX_ENV=test mix test test/rindle/upload/tus_plug_test.exs test/rindle/live_view_test.exs test/rindle/workers/mux_ingest_variant_test.exs test/rindle/workers/mux_sync_provider_asset_test.exs --seed 0 && bash scripts/maintainer/refactor_contract.sh` | ✅ | ⬜ pending |
| 126-05-03 | 05 | 5 | TYPE-01, TYPE-02, SAFE-01 | T-126-02, T-126-08 | Facade/Broker/PromoteAsset behavior unchanged; 45/45 dispositions complete | owner integration + SAFE-01 + supported CI | Focused facade/broker/promote tests, policy, SAFE-01, exact-head Nightly Dialyzer success | ✅ | ⬜ pending |
| 126-06-01 | 06 | 6 | TYPE-01, TYPE-02, SAFE-01 | T-126-01, T-126-03 | Complete local gates and bounded phase diff | aggregate | Policy/topology/cache tests, all mapped owner commands, SAFE-01, `mix ci`, `./scripts/maintainer/repo_hygiene_check.sh --ci` | ✅ | ⬜ pending |
| 126-06-02 | 06 | 6 | TYPE-01, TYPE-02, SAFE-01 | T-126-02, T-126-09 | Exact-head Nightly/summary/PR authority and conditional #76 state | supported CI/external state | HEAD=PR head; Dialyzer success; Nightly Summary Dialyzer row success; CI Summary SUCCESS; issue-state predicate | ✅ | ⬜ pending |

## Wave 0 Requirements

- [ ] Plan 126-01 Task 1 adds the focused policy ExUnit test for exact representation, duplicates, broad/file-only suppressions, missing owners, and stale inventory drift.
- [ ] Plan 126-01 Task 1 preserves and executes the existing Nightly gate/cache topology coverage.
- [ ] Plan 126-01 Task 1 records the exact 45-entry starting inventory: 8 legacy atom filters plus 37 strict description filters across 18 files.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Supported Dialyzer authority and issue #76 disposition | TYPE-01, TYPE-02 | GitHub Actions supplies the locked Elixir 1.17 / OTP 27 runtime and issue state | Dispatch Nightly on the exact branch head, require `dialyzer` and `Nightly Summary` success, inspect retained-filter evidence, and close #76 only after its acceptance criteria are met. |

## Validation Sign-Off

- [ ] All final tasks have an automated command or an explicit supported-CI receipt.
- [ ] Sampling continuity: no source-bearing task lacks focused behavior and SAFE-01 coverage.
- [ ] Wave 0 policy coverage is green before suppressions are changed.
- [ ] Unsupported local Dialyzer output is diagnostic only and never justifies baseline edits.
- [ ] No watch-mode flags.
- [x] `nyquist_compliant: true` set after the planner reconciled all 16 tasks.

**Approval:** ready for plan-checker review
