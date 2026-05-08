---
phase: 41
slug: onboarding-docs-doctor-package-consumer-proof
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-07
---

# Phase 41 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/install_smoke/docs_parity_test.exs test/install_smoke/release_docs_parity_test.exs test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_checks_streaming_test.exs test/rindle/doctor_test.exs -x` |
| **Structural GCS smoke command** | `RINDLE_INSTALL_SMOKE_PROFILE=gcs mix test test/install_smoke/generated_app_smoke_test.exs` |
| **Full suite command** | `mix test` |
| **Live GCS proof** | GitHub Actions secret-gated generated-app GCS lane plus existing `gcs-soak` job |
| **Estimated runtime** | ~60-90 seconds local structural validation; live lane depends on cloud bucket latency |

---

## Sampling Rate

- **After every task commit:** Run the task-targeted ExUnit files named in that task's `<verify>`
- **After every plan wave:** Run the quick run command above
- **Before `$gsd-verify-work`:** `mix test` must be green, and the secret-gated live GCS generated-app lane should be green when secrets are present
- **Max feedback latency:** ~90 seconds for local structural validation

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 41-01-01 | 01 | 1 | RESUMABLE-12 | T-41-01 / T-41-02 | Deep GCS guide contains the locked onboarding, CORS, and secrecy posture without broadening the quickstart | docs | `grep -F "gsutil cors set" guides/storage_gcs.md && grep -F "session URI is a bearer credential" guides/storage_gcs.md` | ✅ | ⬜ pending |
| 41-01-02 | 01 | 1 | RESUMABLE-12 | T-41-03 | Capability matrix is adapter-honest; README/getting-started remain short optional pointers | docs / unit | `mix test test/install_smoke/docs_parity_test.exs test/install_smoke/release_docs_parity_test.exs -x` | ✅ | ⬜ pending |
| 41-02-01 | 02 | 1 | RESUMABLE-13 | T-41-04 / T-41-06 | Runtime checks emit resumable GCS onboarding warnings only for relevant profiles and keep warnings non-failing | unit | `mix test test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_checks_streaming_test.exs -x` | ✅ | ⬜ pending |
| 41-02-02 | 02 | 1 | RESUMABLE-13 | T-41-04 / T-41-05 | `mix rindle.doctor` renders `[WARN]` distinctly but fails only on `:error` rows | unit | `mix test test/rindle/doctor_test.exs -x` | ✅ | ⬜ pending |
| 41-03-01 | 03 | 2 | RESUMABLE-14 | T-41-07 / T-41-09 | Generated-app harness exposes a `:gcs` profile and structurally proves doctor -> initiate -> chunked upload -> status convergence -> verify completion -> asset promotion | structural | `RINDLE_INSTALL_SMOKE_PROFILE=gcs mix test test/install_smoke/generated_app_smoke_test.exs` | ✅ | ⬜ pending |
| 41-03-02 | 03 | 2 | RESUMABLE-14 | T-41-07 / T-41-08 | CI workflow includes structural GCS package-consumer proof plus secret-gated live lane with unconditional cleanup and secret-safe posture | workflow | `RINDLE_INSTALL_SMOKE_PROFILE=gcs mix test test/install_smoke/generated_app_smoke_test.exs && rg -n "install_smoke\\.sh gcs|GOOGLE_APPLICATION_CREDENTIALS_JSON|if: \\$\\{\\{ secrets\\.GOOGLE_APPLICATION_CREDENTIALS_JSON != '' \\}\\}|if: always\\(\\)" .github/workflows/ci.yml` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Wave 0 Requirements

- [ ] `guides/storage_gcs.md` — final guide headings/keywords present for the locked CORS + secrecy posture
- [ ] `test/rindle/ops/runtime_checks_test.exs` — explicit warning-row coverage for `doctor.gcs_resumable_cors`
- [ ] `test/rindle/doctor_test.exs` — warning rendering and non-failing exit semantics
- [ ] `test/install_smoke/generated_app_smoke_test.exs` — `:gcs` structural proof path exists and is executable

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Real-bucket generated-app resumable lifecycle on CI | RESUMABLE-14 | Requires live GCS credentials and bucket wiring outside local unit tests | Run the secret-gated generated-app GCS CI job and confirm doctor pass, resumable initiation, chunked upload, status convergence, verify completion, and asset promotion all succeed |
| Operator readability of the CORS-suspected warning | RESUMABLE-13 | Automated tests can prove strings and status semantics, but not whether the warning reads like a useful operations checklist | Run `mix rindle.doctor` against a resumable GCS profile lacking the required bucket CORS config and confirm the warning text clearly names origins, `PUT`, `PATCH`, `Content-Range`, `x-goog-resumable`, and secrecy caveats |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify steps
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers the phase's missing/changed structural seams
- [x] No watch-mode flags
- [x] Feedback latency is bounded for local structural checks
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
