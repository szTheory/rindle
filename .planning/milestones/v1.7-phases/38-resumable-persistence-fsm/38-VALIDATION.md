---
phase: 38
slug: resumable-persistence-fsm
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-07
---

# Phase 38 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit |
| **Config file** | none dedicated; repo uses `mix test` plus `Rindle.DataCase` / support helpers |
| **Quick run command** | `mix test test/rindle/domain/migration_test.exs test/rindle/domain/media_upload_session_test.exs test/rindle/domain/lifecycle_fsm_test.exs test/rindle/upload/resumable_telemetry_test.exs test/rindle/ops/runtime_checks_test.exs test/rindle/doctor_test.exs test/rindle/contracts/telemetry_contract_test.exs -x` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test` against the task's targeted files
- **After every plan wave:** Run `mix test`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 38-01-01 | 01 | 1 | RESUMABLE-01 | T-38-01 / T-38-03 | Migration adds resumable columns plus expiry index without leaking into optional runtime checks | integration | `mix test test/rindle/domain/migration_test.exs test/rindle/ops/runtime_checks_test.exs test/rindle/doctor_test.exs -x` | ✅ | ⬜ pending |
| 38-02-01 | 02 | 1 | RESUMABLE-02 | T-38-04 / T-38-05 / T-38-06 | `MediaUploadSession` casts new fields, inspect redacts `session_uri`, FSM only allows the locked `resuming` lane | unit | `mix test test/rindle/domain/media_upload_session_test.exs test/rindle/domain/lifecycle_fsm_test.exs -x` | ✅ / ❌ W0 | ⬜ pending |
| 38-03-01 | 03 | 2 | RESUMABLE-03 | T-38-07 / T-38-08 / T-38-09 | Telemetry emits only `:status` and `:cancel`, measurements stay numeric, `session_uri` never crosses telemetry or logger recipe surfaces | contract | `mix test test/rindle/upload/resumable_telemetry_test.exs test/rindle/contracts/telemetry_contract_test.exs -x` | ✅ / ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/rindle/domain/media_upload_session_test.exs` — changeset casting + `Inspect` redaction coverage for RESUMABLE-02
- [ ] `test/rindle/upload/resumable_telemetry_test.exs` — resumable telemetry parity/redaction coverage for RESUMABLE-03
- [ ] `guides/storage_gcs.md` — narrow logger metadata filter recipe required by RESUMABLE-03

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `mix rindle.doctor` against a local DB that has applied the packaged Phase 38 migration | RESUMABLE-01 | Requires a migrated adopter-style database state outside isolated unit tests | Apply the Phase 38 migration in the local test DB, run `mix rindle.doctor`, and confirm `doctor.resumable_session_schema` reports success with no GCS runtime config requirements |
| Logger translator recipe readability in `guides/storage_gcs.md` | RESUMABLE-03 | Docs usefulness is editorial; automated tests only prove the file exists and contains the recipe keywords | Read the guide section and verify it names `Logger.add_translator`, `:session_uri`, and the defense-in-depth purpose without promising full GCS onboarding |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
