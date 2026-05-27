---
phase: 77
slug: planning-artifact-cleanup
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-27
---

# Phase 77 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Shell grep + existing ExUnit (evidence probes only) |
| **Config file** | none — Wave 0 covers all requirements |
| **Quick run command** | Per-plan grep from Per-Task map below |
| **Full suite command** | All greps in `77-VERIFICATION.md` must-haves |
| **Estimated runtime** | ~20 seconds |

---

## Sampling Rate

- **After every task commit:** Run task-specific grep from acceptance_criteria
- **After every plan wave:** Re-run prior wave greps + current plan greps
- **Before `/gsd-verify-work`:** Full `77-VERIFICATION.md` must-have suite green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 77-01-01 | 01 | 1 | PLAN-01 | — | 71-02-02 criterion fixed | docs | `grep '≥ 6' .planning/phases/71-ci-proof-honesty/71-VALIDATION.md` | ✅ | ⬜ pending |
| 77-01-02 | 01 | 1 | PLAN-01 | — | Phase 71 verify commands green | grep+unit | four-command block from 77-01-PLAN | ✅ | ⬜ pending |
| 77-01-03 | 01 | 1 | PLAN-01 | — | 71-VALIDATION Nyquist complete | docs | `grep nyquist_compliant: true .planning/phases/71-ci-proof-honesty/71-VALIDATION.md` | ✅ | ⬜ pending |
| 77-02-01 | 02 | 1 | PLAN-01 | — | 72-01-01 row green | docs | `! grep '72-01-01.*⬜ pending' .planning/phases/72-mix-batch-failure-proof/72-VALIDATION.md` | ✅ | ⬜ pending |
| 77-02-02 | 02 | 1 | PLAN-01 | — | STATE position truth | docs | `! grep -q '^Plan: Not started' .planning/STATE.md` | ✅ | ⬜ pending |
| 77-02-03 | 02 | 1 | PLAN-01 | — | Operator queue updated | docs | `! grep '/gsd-plan-phase 71' .planning/STATE.md` | ✅ | ⬜ pending |
| 77-03-01 | 03 | 2 | PLAN-01 | — | Audit nyquist frontmatter synced | docs | `grep 'overall: complete' .planning/milestones/v1.15-MILESTONE-AUDIT.md` | ✅ | ⬜ pending |
| 77-03-02 | 03 | 2 | PLAN-01 | — | VERIFICATION contract exists | docs | `test -f .planning/phases/77-planning-artifact-cleanup/77-VERIFICATION.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements:

- Phase 71/72 verify commands and evidence in `*-VERIFICATION.md`
- Grep-as-contract pattern from Phases 14/74/73

---

## Manual-Only Verifications

All phase behaviors have automated verification (grep + optional mix test evidence probes).

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
