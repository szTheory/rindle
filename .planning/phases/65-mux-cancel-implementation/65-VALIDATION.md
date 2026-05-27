---
phase: 65
slug: mux-cancel-implementation
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-27
---

# Phase 65 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Mix) |
| **Config file** | `mix.exs` |
| **Quick run command** | `mix test test/rindle/streaming/cancel_direct_upload_contract_test.exs test/rindle/streaming/cancel_direct_upload_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~30–90 seconds (phase-scoped) |

---

## Sampling Rate

- **After every task commit:** Run the quick run command above (after plan 65-02); plan 65-01 uses `mix test test/rindle/streaming/provider/mux_cancel_upload_test.exs` if added, else compile-only `mix compile`
- **After every plan wave:** Run `mix test test/rindle/streaming/`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 65-01-01 | 01 | 1 | CANCEL-04 | T-65-01 | 403/404 idempotent at HTTP; no secret in errors | unit | `mix test test/rindle/streaming/provider/mux_cancel_upload_test.exs` | ⬜ W0 | ⬜ pending |
| 65-02-01 | 02 | 2 | CANCEL-04 | T-65-02 | FSM-first `update_all`; provider HTTP outside transaction | integration | `mix test test/rindle/streaming/cancel_direct_upload_test.exs` | ⬜ W0 | ⬜ pending |
| 65-02-02 | 02 | 2 | CANCEL-04 | — | Public `cancel_direct_upload/1` exported | contract | `mix test test/rindle/streaming/cancel_direct_upload_contract_test.exs` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/rindle/streaming/provider/mux_cancel_upload_test.exs` — adapter normalization via `ClientMock` (403/404/429 paths)
- [ ] `test/rindle/streaming/cancel_direct_upload_test.exs` — happy-path hermetic cancel

*Created by plan 65-01 / 65-02 during execute; not pre-existing.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Full PROOF-01 matrix | PROOF-01 | Deferred Phase 66 | Run Phase 66 plans |
| Live Mux API cancel | CANCEL-04 | No live credentials in CI | Optional manual with dev tokens |

---

## Threat References

| ID | Summary |
|----|---------|
| T-65-01 | Treating Mux 403 as failure breaks idempotent re-cancel |
| T-65-02 | Provider HTTP inside DB transaction violates invariant 4 |
| T-65-03 | TOCTOU: webhook promotes row while cancel reads stale state |
