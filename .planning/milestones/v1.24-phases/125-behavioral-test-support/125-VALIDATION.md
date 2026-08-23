---
phase: 125
slug: behavioral-test-support
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-23
---

# Phase 125 — Validation Strategy

> Per-phase validation contract for behavior-preserving test-support decomposition, documentation-domain ownership, and issue #42 evidence.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit, Ecto SQL Sandbox, ExCoveralls |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `MIX_ENV=test mix test test/rindle/config/repo_override_isolation_test.exs test/install_smoke/generated_app_smoke_test.exs --seed 0` |
| **Full suite command** | `mix coveralls.multiple --type local --type json --seed 0 --slowest 20` |
| **Exact supported authority** | Required `CI Summary` on Elixir 1.17 / OTP 27 for the exact final PR head |

## Sampling Rate

- **After every task commit:** Run the focused test file(s) named by the task and `mix format --check-formatted` for changed Elixir files.
- **After every extraction plan:** Run `bash scripts/maintainer/refactor_contract.sh` so SAFE-01 remains continuous.
- **After the documentation wave:** Run every new domain file explicitly and the exact Proof command recorded in `.github/workflows/ci.yml`.
- **Before issue disposition:** Run up to 25 deterministic seeds as fresh processes through the shipped `coveralls.multiple --type local --type json` command; stop on the first failure and retain that bounded result.
- **Phase authority:** The 100-iteration causal test, SAFE-01, and required exact-head `CI Summary` must be green. Issue #42 closes only after all 25 local runs pass; otherwise the requirement closes through the explicitly allowed, evidence-backed narrowing branch and the issue stays open.

## Per-Task Verification Map

| Task ID | Plan owner | Wave | Requirement | Threat Ref | Test Type | Automated Command | File Exists | Status |
|---------|------------|------|-------------|------------|-----------|-------------------|-------------|--------|
| 125-01-T1 | high-iteration causal isolation proof | 1 | TEST-04, SAFE-01 | T-125-01 | concurrency/integration | `MIX_ENV=test mix test test/rindle/config/repo_override_isolation_test.exs --seed 0` | ✅ | ✅ green |
| 125-01-T2 | fixed 25-seed fresh-process evidence runner | 1 | TEST-04 | T-125-02, T-125-03 | shell/integration | `MIX_ENV=test mix test test/install_smoke/async_isolation_evidence_runner_test.exs --seed 0` | ✅ | ✅ green |
| 125-02-T1 | observable generated contract replacements | 2 | TEST-02, SAFE-01 | T-125-04 | unit/contract | `MIX_ENV=test mix test test/install_smoke/generated_app_smoke_test.exs --only phase_120_upgrade_contract --seed 0` | ✅ | ✅ green |
| 125-02-T2 | Contracts extraction behind facade | 2 | TEST-01, SAFE-01 | T-125-04 | unit/contract | same focused contract suite plus SAFE-01 | ✅ | ✅ green |
| 125-03-T1 | command-runner behavior | 3 | TEST-01, TEST-02 | T-125-02, T-125-03 | unit/process | focused generated-app contract suite | ✅ | ✅ green |
| 125-03-T2 | workspace/package extraction | 3 | TEST-01, SAFE-01 | T-125-03, T-125-04 | filesystem/contract | focused generated-app suite plus SAFE-01 | ✅ | ✅ green |
| 125-04-T1 | generated Phoenix patch behavior | 4 | TEST-01, TEST-02 | T-125-04 | integration/compiled contract | `MIX_ENV=test mix test test/install_smoke/generated_app_smoke_test.exs --seed 0` | ✅ | ✅ green |
| 125-04-T2 | Patcher extraction | 4 | TEST-01, SAFE-01 | T-125-04 | integration | generated-app suite plus SAFE-01 | ✅ | ✅ green |
| 125-05-T1 | migration/report behavior | 5 | TEST-01, TEST-02 | T-125-04 | contract/integration | generated-app phase-120 contract suite | ✅ | ✅ green |
| 125-05-T2 | Migrations extraction | 5 | TEST-01, SAFE-01 | T-125-04 | integration | generated-app suite plus SAFE-01 | ✅ | ✅ green |
| 125-06-T1 | generated profile source extraction | 6 | TEST-01, SAFE-01 | T-125-04 | integration/adopter | generated-app suite | ✅ | ✅ green |
| 125-06-T2 | tus outcome/compiled-metadata parity | 6 | TEST-01, TEST-02 | T-125-04 | integration/compiled docs | generated-app + Phoenix tus parity suites | ✅ | ✅ green |
| 125-07-T1 | shared docs support | 7 | TEST-03 | T-125-04 | unit/static docs | migration domain suite | ✅ | ✅ green |
| 125-07-T2 | install/migration domain | 7 | TEST-03, SAFE-01 | T-125-04 | static docs/compiled metadata | migration domain suite plus SAFE-01 | ✅ | ✅ green |
| 125-08-T1 | onboarding/capabilities domain | 8 | TEST-03 | T-125-04 | static docs/compiled metadata | onboarding domain suite | ✅ | ✅ green |
| 125-08-T2 | operations domain | 8 | TEST-03, SAFE-01 | T-125-04 | static docs/structural | operations domain suite plus SAFE-01 | ✅ | ✅ green |
| 125-09-T1 | product/admin domain and aggregate retirement | 9 | TEST-03 | T-125-04 | static docs | all four domain suites | ✅ | ✅ green |
| 125-09-T2 | exact Proof coverage wiring | 9 | TEST-03, SAFE-01 | T-125-05 | CI contract | exact Proof command plus SAFE-01 meta-test | ✅ | ✅ green |
| 125-10-T1 | finite local evidence | 10 | TEST-04 | T-125-02, T-125-03 | full coverage/stress | `bash scripts/maintainer/async_isolation_evidence.sh` | ✅ | ✅ verified narrowing: stopped honestly at 1/25 |
| 125-10-T2 | exact-head CI and issue disposition | 10 | TEST-01–04, SAFE-01 | T-125-05, T-125-06 | supported CI/external evidence | required `CI Summary`, exact head OID, issue-state/evidence checks | ✅ | ✅ green; issue #42 remains open |

## Wave 0 Completion

- `scripts/maintainer/async_isolation_evidence.sh` and its ExUnit contract establish the immutable 25-seed command/evidence schema and fail-fast behavior.
- Generated-app support modules and all four docs-domain files exist and are exercised by their owning suites.
- Existing generated-app reports, ExUnit, Ecto Sandbox, ExCoveralls, SAFE-01, and CI Summary supplied every required observer without a new dependency.

## Environment-Provisioned Verification

| Behavior | Requirement | Authority | Automated command |
|----------|-------------|-----------|-------------------|
| Packed image consumer and full generated-app profile matrix | TEST-01, TEST-02 | Package Consumer / Package Consumer Full and focused local profiles | `bash scripts/install_smoke.sh image` plus exact-head CI lanes |
| Supported single-run coverage | TEST-04 | Quality matrix on Elixir 1.17 / OTP 27 | one `mix coveralls.multiple --type local --type json --slowest 20` invocation per existing job |
| Merge topology and Proof domain coverage | TEST-03, SAFE-01 | required `CI Summary` | exact final PR head only |

## Threat References

- **T-125-01:** unrelated process inherits or observes the counting repo override and corrupts async isolation.
- **T-125-02:** repeated evidence masks the first failure or reports a retry as success.
- **T-125-03:** command output or temporary generated-app configuration leaks secrets into tracked evidence or issue #42.
- **T-125-04:** test-support extraction changes generated consumer, documentation, API, schema/migration, telemetry, or error behavior.
- **T-125-05:** documentation/coverage wiring silently drops a domain or creates a second CI coverage invocation.
- **T-125-06:** issue #42 is closed against a stale head, unsupported toolchain, incomplete matrix, or red required check.

## Executed Receipts

- Phase verification: 57 focused tests passed, SAFE-01 passed 92 tests with no compile cycle, and packed image/tus consumers passed.
- Exact-head PR CI: run `32630138216`, attempt 2, required CI Summary `97173569874` succeeded.
- Post-merge main: run `32632283097` completed successfully across all 22 applicable jobs.
- TEST-04: 100 causal isolation windows passed; the one authorized matrix stopped at seed 0 after 1/25, retained its sanitized receipt, and left issue #42 open under the requirement's explicit narrowing branch.

## Validation Sign-Off

- [x] Every TEST requirement and inherited SAFE-01 has focused automated proof.
- [x] Every implementation task has a runnable automated command; missing files are explicitly created in their owning wave.
- [x] The finite matrix is local/maintainer evidence, preserves its first failure without retry, and does not expand CI topology.
- [x] Exact-head supported CI is the final authority; local Elixir 1.19 / OTP 28 remains diagnostic.
- [x] `nyquist_compliant: true` is set and no watch-mode command is used.

**Validation:** reconciled 2026-08-23 from completed plan summaries, phase verification, exact-head CI, and post-merge main evidence.
