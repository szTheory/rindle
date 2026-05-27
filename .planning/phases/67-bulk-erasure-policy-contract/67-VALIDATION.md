---
phase: 67
slug: bulk-erasure-policy-contract
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-27
---

# Phase 67 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Mix) |
| **Config file** | `mix.exs` |
| **Quick run command** | `mix test test/rindle/owner_erasure_batch_contract_test.exs test/rindle/owner_erasure_batch_boundary_test.exs --color` |
| **Full suite command** | `mix test --color` |
| **Estimated runtime** | ~30 seconds (contract subset); ~2 minutes (full suite) |

---

## Sampling Rate

- **After every task commit:** Run quick run command
- **After every plan wave:** Run `mix test test/rindle/api_surface_boundary_test.exs test/rindle/owner_erasure_batch_* --color`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 67-01-01 | 01 | 1 | BULK-01 | — | N/A | unit | `mix test test/rindle/owner_erasure_batch_contract_test.exs --color` | ❌ W0 | ⬜ pending |
| 67-01-02 | 01 | 1 | BULK-02 | — | Batch size enforced at public boundary before planner | unit | `mix test test/rindle/owner_erasure_batch_boundary_test.exs --color` | ❌ W0 | ⬜ pending |
| 67-02-01 | 02 | 2 | BULK-02 | — | Operator-facing over-limit guidance | unit | `mix test test/rindle/owner_erasure_batch_error_test.exs --color` | ❌ W0 | ⬜ pending |
| 67-02-02 | 02 | 2 | BULK-01 | — | Facade moduledoc/export freeze | unit | `mix test test/rindle/api_surface_boundary_test.exs --color` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Existing ExUnit + DataCase infrastructure covers phase requirements
- [ ] Contract/boundary test modules created in Plan 01/02 tasks (stubs acceptable until task lands)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None | — | — | All phase behaviors have automated verification |

---

## Validation Sign-Off

- [x] All tasks have automated verify commands
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 120s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
