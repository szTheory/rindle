---
phase: 66
slug: proof-adopter-guidance
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-05-27
---

# Phase 66 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Mix) |
| **Config file** | `mix.exs` |
| **Quick run command** | `mix test test/rindle/streaming/cancel_direct_upload_test.exs test/rindle/streaming/provider/mux/http_cancel_upload_test.exs` |
| **Full suite command** | `mix test test/rindle/streaming/cancel_direct_upload_contract_test.exs test/rindle/streaming/cancel_direct_upload_test.exs test/rindle/streaming/provider/mux_cancel_upload_test.exs test/rindle/streaming/provider/mux/http_cancel_upload_test.exs test/install_smoke/streaming_cancel_docs_parity_test.exs` |
| **Estimated runtime** | ~30–120 seconds (phase-scoped) |

---

## Sampling Rate

- **After every task commit:** Run the quick run command for the plan's touched test files
- **After every plan wave:** Run the full suite command above
- **Before `/gsd-verify-work`:** Full `mix test` must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 66-01-01 | 01 | 1 | PROOF-01 | T-66-01 | base_url test seam only; no credential logging | unit | `mix test test/rindle/streaming/provider/mux/http_cancel_upload_test.exs` | ⬜ W0 | ⬜ pending |
| 66-01-02 | 01 | 1 | PROOF-01 | T-66-02 | Provider HTTP outside transaction; row deleted before provider call | integration | `mix test test/rindle/streaming/cancel_direct_upload_test.exs` | ✅ | ⬜ pending |
| 66-02-01 | 02 | 2 | TRUTH-01 | — | Guide documents Mux-only scope; no raw Mux ids in examples | docs parity | `mix test test/install_smoke/streaming_cancel_docs_parity_test.exs` | ⬜ W0 | ⬜ pending |
| 66-02-02 | 02 | 2 | TRUTH-01 | T-66-03 | §10 disambiguates Oban cancel from streaming cancel | docs parity | same | ⬜ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/rindle/streaming/provider/mux/http_cancel_upload_test.exs` — Bypass 403/404 idempotency
- [ ] `test/install_smoke/streaming_cancel_docs_parity_test.exs` — guide substring contract

*Created by plans 66-01 / 66-02 during execute; not pre-existing.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live Mux API cancel | PROOF-01 | No live credentials in CI | Optional dev manual with real upload id |
| Guide readability / prose flow | TRUTH-01 | Subjective | Human review during `/gsd-verify-work` |

---

## Threat References

| ID | Summary |
|----|---------|
| T-66-01 | Skipping HTTP-layer 403 test repeats delete_asset 404 gap |
| T-66-02 | Provider failure rollback would violate CANCEL-02 local-first contract |
| T-66-03 | §10 Oban "cancel" wording causes adopters to cancel jobs instead of uploads |
