---
phase: 76
slug: tusplug-doc-parity-lock
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-27
---

# Phase 76 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Mix) |
| **Config file** | `mix.exs` |
| **Quick run command** | `mix test test/install_smoke/docs_parity_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~15 seconds (quick); ~minutes (full) |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/install_smoke/docs_parity_test.exs`
- **After every plan wave:** Run `mix test test/install_smoke/docs_parity_test.exs`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 76-01-01 | 01 | 1 | TRUTH-05 | T-76-01-1 / — | N/A (moduledoc SSoT) | compile | `mix compile --force` | ✅ | ⬜ pending |
| 76-01-02 | 01 | 1 | TRUTH-05 | T-76-01-2 / — | N/A (parity lock) | unit | `mix test test/install_smoke/docs_parity_test.exs` | ✅ | ⬜ pending |
| 76-02-01 | 02 | 2 | TRUTH-05 | T-76-02-1 / — | N/A (planning) | grep | `grep -q '\\[x\\] \\*\\*TRUTH-05\\*\\*' .planning/REQUIREMENTS.md` | ✅ | ⬜ pending |
| 76-02-02 | 02 | 2 | TRUTH-05 | — | N/A (audit gap) | grep | `grep -q 'TRUTH-05' .planning/milestones/v1.15-MILESTONE-AUDIT.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

- [x] `test/install_smoke/docs_parity_test.exs` — parity test home
- [x] `test/rindle/api_surface_boundary_test.exs` — fetch_docs helper precedent
- [x] `mix test` — ExUnit via Mix

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
