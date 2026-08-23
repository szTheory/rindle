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
- **Intermediate supported finalizers (Plans 126-02 through 126-06):** Deterministically capture or verified-reuse the exact-head workflow_dispatch run, poll its database ID to terminal without aborting on the expected workflow failure, aggregate every annotations page with `--paginate --slurp`, and assert complete-set equality. The only permitted emitted set is E38 text at `lib/rindle/upload/tus_creation.ex` plus E39-E40 text at `lib/rindle/upload/tus_stream.ex`; these are extracted owners distinct from the immutable E38-E40 starting filter paths at `tus_plug.ex`. Require Dialyzer `failure`, Nightly Summary `success`, and its log to record `DIALYZER: failure`. Any extra page item, count, path, message, head/event mismatch, ambiguity, or conclusion fails the plan.
- **Before phase verification:** Run `mix ci`, SAFE-01, repository hygiene, exact-head PR CI, and the supported Nightly Dialyzer job.
- **Max local feedback latency:** 120 seconds for a focused task check; asynchronous CI is monitored to a terminal result.

## Per-Task Verification Map

Every task from the nine sequential plans has a runnable local check or exact supported-CI receipt. Each source-bearing slice has its own source-unchanged supported probe, focused owner behavior with SAFE-01, and exact-head Nightly finalizer on Elixir 1.17 / OTP 27.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 126-01-01 | 01 | 1 | TYPE-01, TYPE-02 | T-126-01 | Strict tuples only; immutable 45-entry receipt | unit/policy | `MIX_ENV=test mix test test/install_smoke/dialyzer_ignore_policy_test.exs test/install_smoke/ci_lane_split_test.exs test/install_smoke/ci_cache_hygiene_test.exs --seed 0` | plan creates policy test | ⬜ pending |
| 126-01-02 | 01 | 1 | TYPE-01, TYPE-02, SAFE-01 | T-126-02, T-126-03 | Exact-head home-cell/topology receipt | supported CI + structural | `gh run view RUN_ID --json jobs` plus the three focused policy/topology/cache tests | existing inputs | ⬜ pending |
| 126-02-01 | 02 | 2 | TYPE-01, TYPE-02 | T-126-01, T-126-02 | Source-unchanged migration probe precedes edits | supported CI/policy | Exact-head Nightly failed-log inspection plus `dialyzer_ignore_policy_test.exs` | ✅ | ⬜ pending |
| 126-02-02 | 02 | 2 | TYPE-01, SAFE-01 | T-126-04 | Dispatcher/host behavior and migration ownership unchanged | owner integration + SAFE-01 | `MIX_ENV=test mix test test/rindle/migration_fast_test.exs test/rindle/migration_test.exs test/install_smoke/docs_parity/install_and_migrations_test.exs --seed 0 && bash scripts/maintainer/refactor_contract.sh` | ✅ | ⬜ pending |
| 126-02-03 | 02 | 2 | TYPE-01, TYPE-02, SAFE-01 | T-126-02, T-126-04 | V1 refusals/DDL/reversal unchanged; no migration/support or unowned warning; only later-owned E38-E40 may remain | owner integration + SAFE-01 + supported CI | Migration tests, SAFE-01, exact three Tus annotation identities/count, Dialyzer failure, Summary success with `DIALYZER: failure` | ✅ | ⬜ pending |
| 126-03-01 | 03 | 3 | TYPE-01, TYPE-02 | T-126-01, T-126-02 | Source-unchanged task/Admin/runtime-check probe | supported CI/policy | Exact-head Nightly failed-log inspection plus policy test | ✅ | ⬜ pending |
| 126-03-02 | 03 | 3 | TYPE-01, TYPE-02, SAFE-01 | T-126-02, T-126-05 | Task/Admin/diagnostic results, telemetry, errors unchanged; no owned/earlier or unowned warning; only later-owned E38-E40 may remain | owner integration + SAFE-01 + supported CI | Focused owner tests, SAFE-01, exact three Tus annotation identities/count, Dialyzer failure, Summary success with `DIALYZER: failure` | ✅ | ⬜ pending |
| 126-04-01 | 04 | 4 | TYPE-01, TYPE-02 | T-126-01, T-126-02 | Source-unchanged runtime-status/HTML/ProcessVariant atom probe | supported CI/policy | Exact-head Nightly failed-log inspection plus policy test | ✅ | ⬜ pending |
| 126-04-02 | 04 | 4 | TYPE-01, TYPE-02, SAFE-01 | T-126-02, T-126-05 | Runtime-status/task/HTML/ProcessVariant behavior unchanged; no owned/earlier or unowned warning; only later-owned E38-E40 may remain | owner integration + SAFE-01 + supported CI | Focused owner tests, SAFE-01, exact three Tus annotation identities/count, Dialyzer failure, Summary success with `DIALYZER: failure` | ✅ | ⬜ pending |
| 126-05-01 | 05 | 5 | TYPE-01, TYPE-02 | T-126-01, T-126-07 | Source-unchanged GCS/Local probe; opacity preserved | supported CI/policy | Exact-head Nightly failed-log inspection plus policy test | ✅ | ⬜ pending |
| 126-05-02 | 05 | 5 | TYPE-01, TYPE-02, SAFE-01 | T-126-06, T-126-07 | GCS/Local streams, cleanup, concatenation, and tagged errors unchanged; no owned/earlier or unowned warning; only later-owned E38-E40 may remain | owner integration + SAFE-01 + supported CI | Focused owner tests, SAFE-01, exact three Tus annotation identities/count, Dialyzer failure, Summary success with `DIALYZER: failure` | ✅ | ⬜ pending |
| 126-06-01 | 06 | 6 | TYPE-01, TYPE-02 | T-126-01, T-126-07 | Source-unchanged S3 probe; opacity preserved | supported CI/policy | Exact-head Nightly failed-log inspection plus policy test | ✅ | ⬜ pending |
| 126-06-02 | 06 | 6 | TYPE-01, TYPE-02, SAFE-01 | T-126-06, T-126-07 | S3 stream/tail/endpoint behavior unchanged; no owned/earlier or unowned warning; only later-owned E38-E40 may remain | owner integration + SAFE-01 + supported CI | Focused owner tests, SAFE-01, exact three Tus annotation identities/count, Dialyzer failure, Summary success with `DIALYZER: failure` | ✅ | ⬜ pending |
| 126-07-01 | 07 | 7 | TYPE-01, TYPE-02 | T-126-01, T-126-07 | Starting `tus_plug` filter paths preserved separately from extracted `tus_creation`/`tus_stream` owners | supported CI/policy | Deterministic exact-head Nightly failed-log inspection, exhaustive annotations, policy test | ✅ | ⬜ pending |
| 126-07-02 | 07 | 7 | TYPE-01, TYPE-02, SAFE-01 | T-126-07, T-126-08 | Tus creation/stream opacity/protocol and Mux response/error behavior unchanged | owner integration + SAFE-01 + supported CI | `tus_plug_test.exs`, `storage/local_tus_test.exs`, focused Mux tests, SAFE-01, terminal exact-head overall/Dialyzer/Summary success | ✅ | ⬜ pending |
| 126-08-01 | 08 | 8 | TYPE-01, TYPE-02 | T-126-01, T-126-07 | Source-unchanged facade/Broker/PromoteAsset probe | supported CI/policy | Exact-head Nightly failed-log inspection plus policy test | ✅ | ⬜ pending |
| 126-08-02 | 08 | 8 | TYPE-01, TYPE-02, SAFE-01 | T-126-02, T-126-08 | Facade/Broker/PromoteAsset unchanged; 45/45 dispositions complete | owner integration + SAFE-01 + supported CI | Focused facade/broker/promote tests, policy, SAFE-01, exact-head Nightly Dialyzer and Summary success | ✅ | ⬜ pending |
| 126-09-01 | 09 | 9 | TYPE-01, TYPE-02, SAFE-01 | T-126-01, T-126-03 | Complete local gates, clean candidate commit, and bounded phase diff | aggregate | Policy/topology/cache tests, all mapped owner commands, SAFE-01, `mix ci`, `./scripts/maintainer/repo_hygiene_check.sh --ci` | ✅ | ⬜ pending |
| 126-09-02 | 09 | 9 | TYPE-01, TYPE-02, SAFE-01 | T-126-02, T-126-09 | Exact-head authorities and immutable external #76 receipt without repository mutation | supported CI/external state | Candidate=PR head; Dialyzer/Summary success; CI Summary SUCCESS; sanitized issue comment links; issue-state predicate; candidate unchanged | ✅ | ⬜ pending |

## Wave 0 Requirements

- [ ] Plan 126-01 Task 1 adds the focused policy ExUnit test for exact representation, duplicates, broad/file-only suppressions, missing owners, and stale inventory drift.
- [ ] Plan 126-01 Task 1 preserves and executes the existing Nightly gate/cache topology coverage.
- [ ] Plan 126-01 Task 1 records the exact 45-entry starting inventory: 8 legacy atom filters plus 37 strict description filters across 18 files.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Supported Dialyzer authority and issue #76 disposition | TYPE-01, TYPE-02 | GitHub Actions supplies the locked Elixir 1.17 / OTP 27 runtime and issue state | Dispatch Nightly on the exact candidate head, require `dialyzer` and `Nightly Summary` success, require PR `CI Summary`, publish the sanitized immutable issue receipt, and close #76 only after its acceptance criteria are met. |

## Validation Sign-Off

- [ ] All final tasks have an automated command or an explicit supported-CI receipt.
- [ ] Sampling continuity: no source-bearing task lacks focused behavior and SAFE-01 coverage.
- [ ] Wave 0 policy coverage is green before suppressions are changed.
- [ ] Unsupported local Dialyzer output is diagnostic only and never justifies baseline edits.
- [ ] No watch-mode flags.
- [x] `nyquist_compliant: true` set after the planner reconciled all 19 tasks.

**Approval:** ready for plan-checker review
