---
phase: 74
slug: support-truth-milestone-audit
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-27
---

# Phase 74 — Validation Strategy

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
| 74-01-01 | 01 | 1 | TRUTH-04 | T-74-01-1 / — | N/A (docs) | unit | `mix test test/install_smoke/docs_parity_test.exs` | ✅ | ⬜ pending |
| 74-01-02 | 01 | 1 | TRUTH-04 | T-74-01-2 / — | N/A (moduledoc) | compile | `mix compile --force` | ✅ | ⬜ pending |
| 74-01-03 | 01 | 1 | TRUTH-04 | — | N/A | unit | `mix test test/install_smoke/docs_parity_test.exs` | ✅ | ⬜ pending |
| 74-02-01 | 02 | 2 | AUDIT-01 | T-74-02-1 / — | N/A (planning) | grep | `test -f .planning/milestones/v1.15-MILESTONE-AUDIT.md` | ✅ | ⬜ pending |
| 74-02-02 | 02 | 2 | AUDIT-01 | — | N/A | grep | `grep -q '\\[x\\] \\*\\*TRUTH-04\\*\\*' .planning/REQUIREMENTS.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

- [x] `test/install_smoke/docs_parity_test.exs` — parity test home
- [x] `mix test` — ExUnit via Mix

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| JTBD-MAP narrative quality | AUDIT-01 | Subjective prose | Spot-read "What changed" entry |
| Milestone audit prose | AUDIT-01 | Cross-doc synthesis | Compare to v1.14 audit structure |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
