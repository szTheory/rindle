---
phase: 72
slug: mix-batch-failure-proof
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-27
---

# Phase 72 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Mix) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/rindle/batch_owner_erasure_task_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~5–15 seconds (targeted file) |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/rindle/batch_owner_erasure_task_test.exs`
- **After every plan wave:** Run `mix test test/rindle/batch_owner_erasure_task_test.exs`
- **Before `/gsd-verify-work`:** Targeted file must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 72-01-01 | 01 | 1 | PROOF-06 | T-72-01 / — | Partial report before error; exit 1 | integration | `mix test test/rindle/batch_owner_erasure_task_test.exs` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements:

- `test/support/counting_failing_txn_repo.ex` — txn failure injection
- `test/support/owner_erasure_batch_fixtures.ex` — owners/assets
- `test/rindle/batch_owner_erasure_task_test.exs` — Mix shell harness

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-05-27
