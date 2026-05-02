---
phase: 14
slug: validation-closure-for-publish-milestone
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-28
---

# Phase 14 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | none — document-editing phase only |
| **Config file** | none |
| **Quick run command** | `grep -c "approved" .planning/milestones/v1.2-phases/10-publish-readiness/10-VALIDATION.md` |
| **Full suite command** | `grep -c "approved" .planning/milestones/v1.2-phases/10-publish-readiness/10-VALIDATION.md && grep -c "approved" .planning/milestones/v1.2-phases/11-protected-publish-automation/11-VALIDATION.md` |
| **Estimated runtime** | ~2 seconds |

---

## Sampling Rate

- **After every task commit:** Verify target VALIDATION.md fields updated correctly
- **After every plan wave:** Confirm both VALIDATION files reflect evidence-backed state
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 14-01-01 | 01 | 1 | none | — | N/A | manual | `grep "wave_0_complete: true" .planning/milestones/v1.2-phases/10-publish-readiness/10-VALIDATION.md` | ✅ | ⬜ pending |
| 14-01-02 | 01 | 1 | none | — | N/A | manual | `grep "approved" .planning/milestones/v1.2-phases/10-publish-readiness/10-VALIDATION.md` | ✅ | ⬜ pending |
| 14-02-01 | 02 | 1 | none | — | N/A | manual | `grep "wave_0_complete: true" .planning/milestones/v1.2-phases/11-protected-publish-automation/11-VALIDATION.md` | ✅ | ⬜ pending |
| 14-02-02 | 02 | 1 | none | — | N/A | manual | `grep "approved" .planning/milestones/v1.2-phases/11-protected-publish-automation/11-VALIDATION.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Phase 10 VALIDATION sign-off fields updated | none | Document editing, not code | Read 10-VALIDATION.md and confirm approval line and checkboxes are updated |
| Phase 11 VALIDATION sign-off fields updated | none | Document editing, not code | Read 11-VALIDATION.md and confirm approval line and wave_0_complete are true |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
