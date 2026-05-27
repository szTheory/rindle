---
phase: 70
slug: proof-adopter-guidance
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-27
---

# Phase 70 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Mix) |
| **Config file** | `mix.exs` |
| **Quick run command** | `mix test test/rindle/owner_erasure_batch_proof_test.exs` |
| **Full suite command** | `mix test test/rindle/owner_erasure_batch_test.exs test/rindle/owner_erasure_batch_proof_test.exs test/rindle/owner_erasure_batch_boundary_test.exs test/rindle/owner_erasure_batch_error_test.exs test/rindle/owner_erasure_batch_contract_test.exs test/rindle/owner_erasure_test.exs test/rindle/batch_owner_erasure_task_test.exs test/install_smoke/docs_parity_test.exs` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command (proof file) or `mix test test/install_smoke/docs_parity_test.exs` (guide tasks)
- **After every plan wave:** Run full suite command
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 70-01-01 | 01 | 1 | PROOF-05 | T-70-01 / — | Shared fixtures reduce drift across batch tests | unit | `mix test test/rindle/owner_erasure_batch_test.exs` | ✅ | ⬜ pending |
| 70-01-02 | 01 | 1 | PROOF-05 | T-70-02 / — | Partial failure does not roll back committed owners | integration | `mix test test/rindle/owner_erasure_batch_proof_test.exs` | ❌ W0 | ⬜ pending |
| 70-01-03 | 01 | 1 | PROOF-05 | T-70-02 / — | First-owner failure returns empty partial_report | integration | same | ❌ W0 | ⬜ pending |
| 70-02-01 | 02 | 2 | TRUTH-03 | T-70-03 / — | Guides document batch without duplicating mix contract | docs parity | `mix test test/install_smoke/docs_parity_test.exs` | ✅ | ⬜ pending |
| 70-02-02 | 02 | 2 | TRUTH-03 | T-70-03 / — | Stale bulk-orchestration deferral removed | docs parity | same | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements:
- [x] `test/rindle/owner_erasure_batch_test.exs` — Phase 68 baseline
- [x] `test/install_smoke/docs_parity_test.exs` — TRUTH-03 parity home
- [x] `test/rindle/batch_owner_erasure_task_test.exs` — CLI proof (no new matrix)

Wave 0 creates:
- [ ] `test/support/owner_erasure_batch_fixtures.ex`
- [ ] `test/support/counting_failing_txn_repo.ex`
- [ ] `test/rindle/owner_erasure_batch_proof_test.exs`

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
