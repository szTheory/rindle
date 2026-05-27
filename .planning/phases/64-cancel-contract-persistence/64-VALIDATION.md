---
phase: 64
slug: cancel-contract-persistence
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-27
---

# Phase 64 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Mix) |
| **Config file** | `mix.exs` |
| **Quick run command** | `mix test test/rindle/domain/migration_test.exs test/rindle/domain/provider_asset_fsm_test.exs test/rindle/streaming/create_direct_upload_test.exs test/rindle/error_streaming_freeze_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~30–90 seconds (phase-scoped) |

---

## Sampling Rate

- **After every task commit:** Run the quick run command above
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 64-01-01 | 01 | 1 | CANCEL-03 | T-64-01 | `provider_upload_id` nullable; partial unique index | unit | `mix test test/rindle/domain/migration_test.exs` | ✅ | ⬜ pending |
| 64-02-01 | 02 | 1 | CANCEL-02 | — | FSM allows `pending/uploading → deleted` | unit | `mix test test/rindle/domain/provider_asset_fsm_test.exs` | ✅ | ⬜ pending |
| 64-03-01 | 03 | 2 | CANCEL-03 | T-64-01 | Mint persists `provider_upload_id`; inspect redacts | unit | `mix test test/rindle/streaming/create_direct_upload_test.exs` | ✅ | ⬜ pending |
| 64-04-01 | 04 | 2 | CANCEL-01/02 | T-64-02 | `:not_cancellable` messages frozen; no secret leakage in errors | unit | `mix test test/rindle/error_streaming_freeze_test.exs` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No Wave 0 stubs required.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Phase 65 cancel orchestration | CANCEL-01 | `cancel_direct_upload/1` body deferred | Verify in Phase 65 execute |

---

## Threat References

| ID | Summary |
|----|---------|
| T-64-01 | Provider upload handle leakage via logs/inspect |
| T-64-02 | Error messages exposing provider secrets |
