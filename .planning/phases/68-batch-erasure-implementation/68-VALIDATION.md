---
phase: 68
slug: batch-erasure-implementation
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-27
---

# Phase 68 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (mix test) |
| **Config file** | `mix.exs` |
| **Quick run command** | `mix test test/rindle/owner_erasure_batch_test.exs test/rindle/owner_erasure_batch_boundary_test.exs test/rindle/owner_erasure_batch_error_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~15 seconds (batch subset) |

---

## Sampling Rate

- **After every task commit:** Run quick run command above
- **After every plan wave:** Run `mix test test/rindle/owner_erasure_batch_test.exs test/rindle/owner_erasure_batch_boundary_test.exs test/rindle/owner_erasure_batch_error_test.exs test/rindle/owner_erasure_batch_contract_test.exs`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 68-01-01 | 01 | 1 | BULK-03, BULK-04 | T-68-01 | Per-owner `OwnerErasure` only; no outer Multi | unit | `mix test test/rindle/owner_erasure_batch_boundary_test.exs` | ✅ | ⬜ pending |
| 68-01-02 | 01 | 1 | BULK-04, BULK-05 | — | N/A | integration | `mix test test/rindle/owner_erasure_batch_test.exs` | ❌ W0 | ⬜ pending |
| 68-02-01 | 02 | 2 | BULK-03 | T-68-02 | Partial failure exposes owner_ref only in error | unit | `mix test test/rindle/owner_erasure_batch_error_test.exs` | ✅ | ⬜ pending |
| 68-02-02 | 02 | 2 | BULK-03, BULK-05 | — | N/A | integration | `mix test test/rindle/owner_erasure_batch_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/rindle/owner_erasure_batch_contract_test.exs` — contract freeze (Phase 67)
- [x] `test/rindle/owner_erasure_batch_boundary_test.exs` — boundary behavior (update in Phase 68)
- [ ] `test/rindle/owner_erasure_batch_test.exs` — implementation integration tests (Plan 02)

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
