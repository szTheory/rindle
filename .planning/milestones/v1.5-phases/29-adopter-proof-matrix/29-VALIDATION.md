---
phase: 29
slug: adopter-proof-matrix
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-06
---

# Phase 29 — Validation Strategy

> Per-phase validation contract for Phase 29 execution. This is the Nyquist gate artifact for `PROOF-01` through `PROOF-04`.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit generated-app smoke, docs parity tests, shell wrappers, and CI workflow assertions |
| **Config file** | `config/test.exs`, `test/test_helper.exs` |
| **Quick run command** | `mix test test/install_smoke/generated_app_smoke_test.exs --include minio --warnings-as-errors` |
| **Full phase command** | `mix test test/install_smoke/generated_app_smoke_test.exs test/install_smoke/docs_parity_test.exs test/install_smoke/release_docs_parity_test.exs --include minio --warnings-as-errors && bash scripts/release_preflight.sh` |
| **Estimated runtime** | ~2-5 minutes depending on generated-app and MinIO lanes |

## Phase Requirements → Plan/Test Map

| Req ID | Plan | Requirement Proof | Automated Command | Evidence Type | Status |
|--------|------|-------------------|-------------------|---------------|--------|
| PROOF-01 | 29-01 | Generated app proves image-only install, migrations, upload, processing, and signed delivery from built and published package sources | `mix test test/install_smoke/generated_app_smoke_test.exs --include minio --warnings-as-errors` | smoke/integration | ✅ green |
| PROOF-02 | 29-02 | Generated app proves AV install, probe, transcode, playback-ready variants, and signed delivery from package source | `mix test test/install_smoke/generated_app_smoke_test.exs --include minio --warnings-as-errors` | smoke/integration | ✅ green |
| PROOF-03 | 29-03 | CI and release-facing commands expose the explicit package-consumer proof matrix | `bash scripts/release_preflight.sh` and workflow grep checks in `29-03-SUMMARY.md` | ci/ops | ✅ green |
| PROOF-04 | 29-04 | Public docs and release docs stay in executable parity with the proved package-consumer matrix | `mix test test/install_smoke/docs_parity_test.exs test/install_smoke/release_docs_parity_test.exs --warnings-as-errors` | docs/regression | ✅ green |

## Validation Sign-Off

- [x] All Phase 29 plans map to automated verification.
- [x] `PROOF-01` through `PROOF-04` each have at least one explicit verification lane.
- [x] The generated-app image and AV smoke harness exists in the repository and is exercised by the phase lanes.
- [x] `nyquist_compliant: true` and `wave_0_complete: true` reflect the executed phase state.

**Approval:** complete — validation evidence is present and Phase 29 is Nyquist-compliant.
