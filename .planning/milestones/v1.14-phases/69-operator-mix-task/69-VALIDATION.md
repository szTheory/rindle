---
phase: 69
slug: operator-mix-task
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-27
---

# Phase 69 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (mix test) |
| **Config file** | `mix.exs` |
| **Quick run command** | `mix test test/rindle/batch_owner_erasure_task_test.exs test/rindle/api_surface_boundary_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~10 seconds (task subset) |

---

## Sampling Rate

- **After every task commit:** Run quick run command above
- **After every plan wave:** Run `mix test test/rindle/batch_owner_erasure_task_test.exs test/rindle/api_surface_boundary_test.exs test/rindle/owner_erasure_batch_test.exs`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 20 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 69-01-01 | 01 | 1 | OPS-02 | T-69-01 | Default preview; execute requires explicit flag | integration | `mix test test/rindle/batch_owner_erasure_task_test.exs` | ✅ | ✅ green |
| 69-01-02 | 01 | 1 | OPS-02 | T-69-02 | `String.to_existing_atom/1` for owner_type | unit | `mix test test/rindle/batch_owner_erasure_task_test.exs` | ✅ | ✅ green |
| 69-02-01 | 02 | 2 | OPS-02 | — | N/A | unit | `mix test test/rindle/api_surface_boundary_test.exs` | ✅ | ✅ green |
| 69-02-02 | 02 | 2 | OPS-02 | — | N/A | integration | `mix test test/rindle/batch_owner_erasure_task_test.exs` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/rindle/batch_owner_erasure_task_test.exs` — task test module (created in plan 02)
- [x] `lib/mix/tasks/rindle.batch_owner_erasure.ex` — task module (created in plan 01)

*Existing batch integration tests in `owner_erasure_batch_test.exs` provide fixture patterns; no new framework install.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `@moduledoc` guide links resolve after Phase 70 | OPS-02 | Guide body deferred to Phase 70 | Spot-check `guides/operations.md` anchor exists or note cross-link only |

*All core CLI behaviors have automated verification.*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 20s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-05-27

## Validation Audit

| Date | Action | Result |
|------|--------|--------|
| 2026-05-27 | Phase 73 metadata reconciliation | nyquist_compliant: true |
