---
phase: 73
slug: nyquist-validation-closure
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-27
---

# Phase 73 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Mix) — repo-truth gates only |
| **Config file** | `mix.exs` |
| **Quick run command** | Per restored phase: run that phase's quick command from its `*-VALIDATION.md` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~45 seconds (three targeted subsets) |

---

## Sampling Rate

- **After every task commit:** Run the sub-phase quick verify from restored VALIDATION.md
- **After every plan wave:** Re-grep all three archive `*-VALIDATION.md` for compliance markers
- **Before `/gsd-verify-work`:** VAL-01 ticked; v1.14 audit table updated
- **Max feedback latency:** 30 seconds per sub-phase probe

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 73-01-01 | 01 | 1 | VAL-01 | — | Phase 68 archive restored | docs | `test -d .planning/milestones/v1.14-phases/68-batch-erasure-implementation` | ✅ | ⬜ pending |
| 73-01-02 | 01 | 1 | VAL-01 | — | 68-VALIDATION Nyquist complete | docs | `grep nyquist_compliant: true .../68-VALIDATION.md` | ✅ | ⬜ pending |
| 73-02-01 | 02 | 2 | VAL-01 | — | Phase 69 archive + VALIDATION complete | docs | `grep nyquist_compliant: true .../69-VALIDATION.md` | ✅ | ⬜ pending |
| 73-03-01 | 03 | 3 | VAL-01 | — | Phase 70 archive + VALIDATION complete | docs | `grep nyquist_compliant: true .../70-VALIDATION.md` | ✅ | ⬜ pending |
| 73-04-01 | 04 | 4 | VAL-01 | — | REQUIREMENTS + audit table closed | docs | `grep '\[x\] Phase 73' .planning/REQUIREMENTS.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements (v1.14 tests already shipped).

---

## Manual-Only Verifications

All phase behaviors have automated verification (grep + mix test probes).

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
