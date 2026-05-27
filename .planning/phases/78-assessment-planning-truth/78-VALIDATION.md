---
phase: 78
slug: assessment-planning-truth
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-27
---

# Phase 78 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | none — planning markdown only |
| **Config file** | none |
| **Quick run command** | `rg -i 'mix test still advisory|still advisory via Coveralls|optional CI unit-suite blocking|unit tests advisory' .planning/threads/` |
| **Full suite command** | Full TRUTH-06 + PLAN-02 grep audit from 78-RESEARCH.md § Validation Architecture |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick forbidden-phrase grep
- **After every plan wave:** Run full grep audit from RESEARCH.md
- **Before `/gsd-verify-work`:** Manual read checklist 7/7 (TRUTH-06) + charter checklist 6/6 (PLAN-02)
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 78-01-01 | 01 | 1 | TRUTH-06 | — | N/A | grep | `rg -i 'mix test still advisory|still advisory via Coveralls' .planning/threads/` | ✅ | ⬜ pending |
| 78-01-02 | 01 | 1 | TRUTH-06 | — | N/A | grep | `rg 'does not guarantee full unit/Credo/Dialyzer pass' .planning/threads/` | ✅ | ⬜ pending |
| 78-01-03 | 01 | 1 | TRUTH-06 | — | N/A | grep | `rg -i 'optional CI unit-suite blocking' .planning/threads/` | ✅ | ⬜ pending |
| 78-01-04 | 01 | 1 | TRUTH-06 | — | N/A | grep | `rg '\.github/workflows/ci\.yml|RUNNING\.md' .planning/threads/2026-05-27-post-v116-milestone-assessment.md` | ✅ | ⬜ pending |
| 78-02-01 | 02 | 2 | PLAN-02 | — | N/A | grep | `head -3 .planning/JTBD-MAP.md && git rev-parse --short HEAD` | ✅ | ⬜ pending |
| 78-02-02 | 02 | 2 | PLAN-02 | — | N/A | grep | `git log 3dbf7ab..HEAD --oneline -- lib/ guides/ CHANGELOG.md mix.exs` | ✅ | ⬜ pending |
| 78-02-03 | 02 | 2 | PLAN-02 | — | N/A | grep | `rg 'v1\.18\+' .planning/PROJECT.md .planning/STATE.md .planning/ROADMAP.md` | ✅ | ⬜ pending |
| 78-02-04 | 02 | 2 | TRUTH-06, PLAN-02 | — | N/A | manual | Manual read checklist from 78-RESEARCH.md § Validation Architecture | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No test framework install needed — validation is grep + manual read against canonical CI sources.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Thread CI severity claims match ci.yml | TRUTH-06 | Semantic accuracy beyond grep | Read assessment L30/L63/L81–82 and path-to-done drift note against RUNNING.md L20–36 |
| JTBD anchor reflects v1.16 boundary | PLAN-02 | Milestone judgment | Confirm anchor line milestone + sha; verify "What changed" entry for v1.17 planning delta |
| Charter consistency | PLAN-02 | Cross-doc alignment | Read PROJECT.md L3–17, STATE.md milestone position, ROADMAP success criteria |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
