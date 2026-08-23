---
phase: 121
slug: truthful-quality-signals-mechanical-hygiene
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-23
---

# Phase 121 — Validation Strategy

Phase 121's quality gates are behaviorally covered by ExUnit contracts and fail-closed maintainer commands. The fresh audit on 2026-08-23 re-ran the cross-phase focused suite, the compiler cycle check, Doctor, Credo aggregate, and SAFE-01; all exited successfully.

## Test Infrastructure

| Property | Value |
|---|---|
| **Framework** | ExUnit / Mix, Doctor, Credo, shell policy checks |
| **Config files** | `test/test_helper.exs`, `.doctor.exs`, `.credo.exs`, `.github/workflows/ci.yml` |
| **Focused command** | `MIX_ENV=test mix test <named files> --include contract --seed 0` |
| **Quality commands** | `MIX_ENV=dev mix doctor --full --raise`; `bash scripts/maintainer/credo_quality.sh` |
| **Preservation command** | `bash scripts/maintainer/refactor_contract.sh` |

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Behavioral proof | Test Type | Automated Command | Status |
|---|---:|---:|---|---|---|---|---|
| 121-01-01 | 01 | 1 | SAFE-01 | Root-independent runner fail-closes across preserved contracts | integration | `bash scripts/maintainer/refactor_contract.sh` | ✅ green |
| 121-01-02 | 01 | 1 | SAFE-01 | Runner rejects empty/partial, backgrounded, masked, or planning-coupled execution | unit | `mix test test/install_smoke/refactor_contract_test.exs --seed 0` | ✅ green |
| 121-02-01 | 02 | 1 | SIGNAL-01 | Public telemetry documentation matches the executed contract allowlist | integration | `mix test --only contract --seed 0` | ✅ green |
| 121-03-01 | 03 | 1 | SIGNAL-02 | Public Doctor report is measured at the unchanged ratchet | integration | `MIX_ENV=dev mix doctor --full --raise` | ✅ green |
| 121-03-02 | 03 | 1 | SIGNAL-02 | Regression test consumes Doctor's measured report rather than threshold literals | unit | `MIX_ENV=dev mix test test/rindle/doctor_thresholds_test.exs --seed 0` | ✅ green |
| 121-04-01 | 04 | 1 | SIGNAL-03, SAFE-01 | Warning cleanup preserves subprocess and migration behavior | unit | `mix test test/rindle/av/subprocess_epipe_test.exs test/rindle/migration_fast_test.exs --seed 0` | ✅ green |
| 121-04-02 | 04 | 1 | SIGNAL-03 | Tus S3 proof remains free of targeted Credo violations | static analysis | `mix credo --strict test/rindle/upload/tus_s3_integration_test.exs` | ✅ green |
| 121-05-01 | 05 | 1 | SIGNAL-04 | Cleanup deletes only exact untracked root residue and preserves tracked/package evidence | integration | `mix test test/install_smoke/repository_residue_test.exs --seed 0` | ✅ green |
| 121-05-02 | 05 | 1 | SIGNAL-04 | Root residue cannot recur and the canonical audit stays present | unit | `mix test test/install_smoke/repository_residue_test.exs test/planning_path_hygiene_test.exs --seed 0` | ✅ green |
| 121-06-01 | 06 | 2 | SIGNAL-03 | Fail-fast Credo profiles compare live normalized findings with the owned baseline | integration | `bash scripts/maintainer/credo_quality.sh` | ✅ green |
| 121-06-02 | 06 | 2 | SIGNAL-03 | Warning and baseline identity/count drift produce failing policy cases | unit | `mix test test/install_smoke/credo_policy_test.exs --seed 0` | ✅ green |
| 121-07-01 | 07 | 3 | SIGNAL-01, SIGNAL-02, SIGNAL-03, SIGNAL-04, SAFE-01 | Blocking CI carrier ordering, severity, prerequisites, and Summary topology are locked | unit | `mix test test/install_smoke/quality_signal_policy_test.exs test/install_smoke/ci_lane_split_test.exs test/install_smoke/release_guard_meta_test.exs --seed 0` | ✅ green |
| 121-07-02 | 07 | 3 | SIGNAL-01, SIGNAL-02, SIGNAL-03, SIGNAL-04, SAFE-01 | Local quality aliases compose the deterministic phase contract | integration | `mix ci` | ✅ green |

## Wave 0 Requirements

Existing infrastructure covers every requirement; no harness, fixture, or dependency was needed before execution.

## Manual-Only Verifications

All phase behaviors have automated verification. AV prerequisites are declared and behaviorally covered by the focused AV tests in CI; no manual acceptance step substitutes for a requirement.

## Validation Audit 2026-08-23

| Metric | Count |
|---|---:|
| Plan tasks mapped | 13 |
| Gaps found | 0 |
| Fresh focused suite | green |
| Fresh Doctor report | 79 modules, 0 failed, 100% docs/moduledocs/specs |
| Fresh SAFE-01 runner | 92 tests, 0 failures |

## Validation Sign-Off

- [x] Every plan task has automated proof.
- [x] Every mapped proof has current or recorded green execution evidence.
- [x] Wave 0 has no missing test infrastructure.
- [x] `nyquist_compliant: true` is supported by behavioral coverage.

**Approval:** validated 2026-08-23
