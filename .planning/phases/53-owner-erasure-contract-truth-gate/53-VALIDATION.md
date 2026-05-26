---
phase: 53
slug: owner-erasure-contract-truth-gate
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-26
---

# Phase 53 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via Mix |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/rindle/api_surface_boundary_test.exs test/install_smoke/docs_parity_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~25 seconds |

---

## Sampling Rate

- **After every task commit:** Run the narrowest task-scoped command from the verification map. Default quick loop: `mix test test/rindle/api_surface_boundary_test.exs test/install_smoke/docs_parity_test.exs`
- **After every plan wave:** Run `mix test`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 25 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 53-01-01 | 01 | 1 | LIFE-01 | T-53-01-01 | Code-facing facade docs freeze the exact preview/execute names and report buckets without implying inline destructive execution. | docs boundary | `mix test test/rindle/api_surface_boundary_test.exs` | ✅ | ⬜ pending |
| 53-02-01 | 02 | 1 | TRUTH-02 | T-53-02-01 | Active guide wording names the owner-erasure facade, retained-shared-asset rule, and `cleanup_orphans` maintenance-only boundary. | docs parity | `mix test test/install_smoke/docs_parity_test.exs` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Existing infrastructure covers all phase requirements.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None | N/A | All currently scoped Phase 53 contract truths can be frozen with ExUnit doc-boundary and docs-parity checks. | N/A |

---

## Validation Sign-Off

- [ ] All tasks have automated verification
- [ ] Sampling continuity maintained
- [x] Wave 0 coverage complete
- [ ] No watch-mode flags
- [ ] Feedback latency < 25s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
