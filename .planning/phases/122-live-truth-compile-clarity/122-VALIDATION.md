---
phase: 122
slug: live-truth-compile-clarity
status: planned
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-22
---

# Phase 122 — Validation Strategy

## Validation Contract

Phase 122 is behavior-preserving maintenance. Every changed source or documentation surface has a
focused feedback command, every public boundary remains covered by SAFE-01, and the final phase gate
uses the repository's merge-equivalent checks. Local Elixir 1.19/OTP 28 output is diagnostic because
that cell is unsupported; the GitHub Actions Elixir 1.17/OTP 27 cell and resulting `CI Summary` are the
authoritative acceptance environment.

## Test Infrastructure

| Property | Value |
|---|---|
| **Framework** | ExUnit / Mix, Mix xref, shell policy checks |
| **Config files** | `test/test_helper.exs`, `config/test.exs`, `.tool-versions`, `.github/workflows/ci.yml` |
| **Quick compile command** | `MIX_ENV=test mix compile --force && MIX_ENV=test mix xref graph --format cycles --label compile-connected --fail-above 0` |
| **SAFE-01 command** | `bash scripts/maintainer/refactor_contract.sh` |
| **Full local command** | `mix ci && ./scripts/maintainer/repo_hygiene_check.sh` |
| **Authoritative environment** | GitHub Actions Elixir 1.17 / OTP 27; sole required check `CI Summary` |

## Requirement → Observable Proof Map

| Requirement | Observable behavior | Automated command / test file | Review evidence |
|---|---|---|---|
| CLARITY-01 | The exact inventoried live source/test comments state current domain rationale; historical archives and active safety rationale are unchanged. | Focused commands in Plans 122-02/03; `git diff --check`; `git diff --quiet main...HEAD -- .planning/milestones` | Each 122-02/03 SUMMARY records the reviewed before→after inventory and confirms implementation/assertion-only lines did not change. |
| CLARITY-02 | CI/support, Admin, tus, and streaming docs match shipped workflow/component/adapter/provider behavior and reject the exact stale claims. | `mix test test/install_smoke/docs_parity_test.exs test/install_smoke/phoenix_tus_truth_parity_test.exs test/install_smoke/streaming_cancel_docs_parity_test.exs test/brandbook/admin_design_system_validation_test.exs` | Plan 122-04/05 SUMMARYs record the authoritative shipped code/workflow consulted and the stale claims removed. |
| CLARITY-03 | A fresh compile has zero compile-connected cycles; six owned schemas retain caller rejection and compiled/default/public prefix behavior. | `MIX_ENV=test mix compile --force && MIX_ENV=test mix xref graph --format cycles --label compile-connected --fail-above 0`; `mix test test/rindle/schema_prefix_contract_test.exs test/rindle/domain/media_schema_test.exs test/rindle/config/config_test.exs test/rindle/schema_prefix_integration_test.exs` | Plan 122-01 SUMMARY records pre-change one-cycle output and post-change zero-cycle output plus SAFE shell-context stability. |
| SAFE-01 | Public API, schema/migration, telemetry, error, CI, and release invariants remain unchanged across every slice. | `bash scripts/maintainer/refactor_contract.sh` and `mix ci` | Final verification records local results and the exact supported-CI run/SHA. |

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test type | Automated command | Status |
|---|---:|---:|---|---|---|---|
| 122-01-01 | 01 | 1 | CLARITY-03 | compiler graph + schema contract | `MIX_ENV=test mix compile --force && MIX_ENV=test mix xref graph --format cycles --label compile-connected --fail-above 0 && MIX_ENV=test mix test test/rindle/schema_prefix_contract_test.exs test/rindle/domain/media_schema_test.exs test/rindle/config/config_test.exs` | planned |
| 122-01-02 | 01 | 1 | CLARITY-03, SAFE-01 | SAFE runner policy + aggregate | `MIX_ENV=test mix test test/install_smoke/refactor_contract_test.exs && bash scripts/maintainer/refactor_contract.sh` | planned |
| 122-02-01 | 02 | 2 | CLARITY-01 | source compile + focused behavior | `MIX_ENV=test mix compile --warnings-as-errors && MIX_ENV=test mix test test/rindle/capability_test.exs test/rindle/delivery_test.exs test/rindle/streaming/provider/mux/mux_test.exs` | planned |
| 122-02-02 | 02 | 2 | CLARITY-01, SAFE-01 | source compile + provider behavior + aggregate | `MIX_ENV=test mix compile --warnings-as-errors && MIX_ENV=test mix test test/rindle/streaming/provider/mux/event_test.exs test/rindle/profile/validator_test.exs test/rindle/workers/mux_sync_coordinator_test.exs && bash scripts/maintainer/refactor_contract.sh` | planned |
| 122-03-01 | 03 | 2 | CLARITY-01 | tus/S3 behavior | `MIX_ENV=test mix test test/rindle/upload/tus_plug_test.exs test/rindle/storage/s3_tus_test.exs` | planned |
| 122-03-02 | 03 | 2 | CLARITY-01, SAFE-01 | adapter/maintenance behavior + aggregate | `MIX_ENV=test mix test test/rindle/storage/storage_adapter_test.exs test/rindle/ops/upload_maintenance_test.exs && bash scripts/maintainer/refactor_contract.sh` | planned |
| 122-04-01 | 04 | 2 | CLARITY-02 | rendered Admin label parity | `MIX_ENV=test mix test test/brandbook/admin_design_system_validation_test.exs test/rindle/admin/live/home_assets_upload_test.exs` | planned |
| 122-04-02 | 04 | 2 | CLARITY-02, SAFE-01 | Admin guide/live behavior + aggregate | `MIX_ENV=test mix test test/brandbook/admin_design_system_validation_test.exs test/rindle/admin/live/home_assets_upload_test.exs && bash scripts/maintainer/refactor_contract.sh` | planned |
| 122-05-01 | 05 | 3 | CLARITY-02 | CI/support parity | `MIX_ENV=test mix test test/install_smoke/docs_parity_test.exs test/install_smoke/ci_lane_split_test.exs test/install_smoke/quality_signal_policy_test.exs test/install_smoke/release_guard_meta_test.exs` | planned |
| 122-05-02 | 05 | 3 | CLARITY-02 | tus/adapter parity | `MIX_ENV=test mix test test/install_smoke/phoenix_tus_truth_parity_test.exs test/rindle/storage/storage_adapter_test.exs test/rindle/upload/tus_plug_test.exs test/rindle/storage/gcs_test.exs` | planned |
| 122-05-03 | 05 | 3 | CLARITY-02, SAFE-01 | all parity + aggregate + full local gate | `MIX_ENV=test mix test test/install_smoke/docs_parity_test.exs test/install_smoke/phoenix_tus_truth_parity_test.exs test/install_smoke/streaming_cancel_docs_parity_test.exs test/brandbook/admin_design_system_validation_test.exs && bash scripts/maintainer/refactor_contract.sh && mix ci && ./scripts/maintainer/repo_hygiene_check.sh` | planned |

## Wave 0 Ownership

All validation gaps identified by research are resolved to exact implementation tasks; no harness or
dependency must be added before execution.

| Gap | Resolution | Owner |
|---|---|---|
| Objective compile-cycle proof | Prove fresh compile+xref directly, prove sequential invocation in the SAFE shell context, then structurally lock command/order/status. No nested Mix invocation from ExUnit. | 122-01 Tasks 1–2 |
| Admin, CI/support, tus, streaming parity | Extend the existing domain-owned parity suites only for stable shipped claims. | 122-04 Tasks 1–2; 122-05 Tasks 1–3 |
| Commentary cleanup scope | Use the exact research inventory and human review receipt; do not create a blanket token/source-string ban. | 122-02 Tasks 1–2; 122-03 Tasks 1–2 |

## Sampling Cadence

- **After every task:** Run that task's focused command before its atomic commit.
- **After Wave 1:** Run the exact xref command and `bash scripts/maintainer/refactor_contract.sh`.
- **After each Wave 2 plan:** Run the plan's focused tests plus SAFE-01; confirm
  `git diff --quiet main...HEAD -- .planning/milestones`.
- **After Wave 2 merges:** Run all schema, commentary-adjacent behavior, and Admin parity tests listed
  above, followed by SAFE-01.
- **After Wave 3 / before PR:** Run all current-doc parity suites, SAFE-01, `mix ci`, and
  `./scripts/maintainer/repo_hygiene_check.sh`.
- **PR acceptance:** Run `gh pr checks --required --watch --fail-fast`; record the exact head SHA and
  supported Elixir 1.17/OTP 27 `CI Summary` result. If the local 1.19/28 cell differs, preserve the
  supported contract and record the local result as diagnostic evidence rather than changing scope.

## Manual Review Evidence

No interactive or visual verification is required. CLARITY-01's prose quality is not replaced by a
brittle source-string test: Plans 122-02 and 122-03 must record a finite before→after inventory in their
SUMMARYs showing that each researched stale claim became domain rationale, assertions/implementation
were unchanged, active safety explanations were retained, and historical archives were untouched.
CLARITY-02 uses the same review receipt for corrected claims in addition to automated parity tests.

## Phase Gate

1. `MIX_ENV=test mix compile --force`
2. `MIX_ENV=test mix xref graph --format cycles --label compile-connected --fail-above 0`
3. Focused schema/config/integration, commentary-adjacent behavior, and documentation parity commands
   from the table above
4. `bash scripts/maintainer/refactor_contract.sh`
5. `mix ci`
6. `./scripts/maintainer/repo_hygiene_check.sh`
7. `git diff --quiet main...HEAD -- .planning/milestones`
8. PR checks green at the exact head SHA, with supported Elixir 1.17/OTP 27 and `CI Summary` authoritative

## Validation Sign-Off Criteria

- [ ] Every task's focused command passes before commit.
- [ ] Mix xref reports zero compile-connected cycles after a fresh test compile.
- [ ] CLARITY-01/02 review receipts are present and bounded to the exact inventory.
- [ ] SAFE-01, `mix ci`, and repository hygiene pass.
- [ ] Historical archives, dependencies, Admin features, public API/schema/migration/telemetry/error
  contracts, and CI/release topology have no phase diff.
- [ ] Supported CI checks are green for the exact PR head SHA.

