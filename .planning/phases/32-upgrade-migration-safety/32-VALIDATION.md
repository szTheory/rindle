---
phase: 32
slug: upgrade-migration-safety
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-06
---

# Phase 32 — Validation Strategy

> Per-phase validation contract for Phase 32 execution. This is the Nyquist gate artifact for `UPGRADE-01` through `UPGRADE-03`.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit generated-app smoke plus docs parity coverage |
| **Config file** | `config/test.exs`, `test/test_helper.exs` |
| **Quick run command** | `mix test test/install_smoke/generated_app_smoke_test.exs:98 --include minio --warnings-as-errors` |
| **Full phase command** | `mix test test/install_smoke/generated_app_smoke_test.exs test/install_smoke/docs_parity_test.exs --include minio --warnings-as-errors` |
| **Estimated runtime** | ~2-4 minutes depending on generated-app lifecycle work |

## Phase Requirements → Plan/Test Map

| Req ID | Plan | Requirement Proof | Automated Command | Evidence Type | Status |
|--------|------|-------------------|-------------------|---------------|--------|
| UPGRADE-01 | 32-01 | Generated app upgrades a pre-v1.4 adopter through explicit host plus packaged migrations with legacy image safety preserved | `mix test test/install_smoke/generated_app_smoke_test.exs:98 --include minio --warnings-as-errors` | smoke/integration | ✅ green |
| UPGRADE-02 | 32-02 | Generated app proves doctor, runtime-status, and cancelled-work requeue recovery on public surfaces after upgrade | `mix test test/install_smoke/generated_app_smoke_test.exs:98 --include minio --warnings-as-errors` | smoke/integration | ✅ green |
| UPGRADE-03 | 32-03 | Upgrade guide, README, getting-started, and release docs stay aligned to the executable upgrade proof | `mix test test/install_smoke/docs_parity_test.exs --warnings-as-errors` | docs/regression | ✅ green |

## Validation Sign-Off

- [x] All Phase 32 plans map to automated verification.
- [x] `UPGRADE-01` through `UPGRADE-03` each have explicit automated evidence.
- [x] The generated-app upgrade lane exists and now proves cancelled-work resume truthfully.
- [x] `nyquist_compliant: true` and `wave_0_complete: true` reflect the executed phase state.

**Approval:** complete — validation evidence is present and Phase 32 is Nyquist-compliant.
