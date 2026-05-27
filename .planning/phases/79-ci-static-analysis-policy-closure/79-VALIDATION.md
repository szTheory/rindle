---
phase: 79
slug: ci-static-analysis-policy-closure
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-27
---

# Phase 79 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | none — planning markdown + comment-only ci.yml |
| **Config file** | none |
| **Quick run command** | `rg 'Decision deferred.*Credo|Decision deferred.*Dialyzer' .planning/threads/` |
| **Full suite command** | Full CI-04 grep audit from 79-RESEARCH.md § Validation Architecture |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick forbidden-phrase grep
- **After every plan wave:** Run full CI-04 grep audit from RESEARCH.md
- **Before `/gsd-verify-work`:** Manual read checklist 7/7 from 79-RESEARCH.md
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 79-01-01 | 01 | 1 | CI-04 | — | N/A | grep | `rg 'Static analysis policy \(CI-04\)' RUNNING.md` | ✅ | ⬜ pending |
| 79-01-02 | 01 | 1 | CI-04 | — | N/A | grep | `rg 'fork latency|signal value|green-main' RUNNING.md -i` | ✅ | ⬜ pending |
| 79-01-03 | 01 | 1 | CI-04 | — | N/A | grep | `rg 'CI-04' .github/workflows/ci.yml` | ✅ | ⬜ pending |
| 79-01-04 | 01 | 1 | CI-04 | — | N/A | grep | `rg -A1 'Credo \(strict\)' .github/workflows/ci.yml \| rg 'continue-on-error: true'` | ✅ | ⬜ pending |
| 79-02-01 | 02 | 2 | CI-04 | — | N/A | grep | `rg 'Decision deferred.*Credo|Decision deferred.*Dialyzer' .planning/threads/` | ✅ | ⬜ pending |
| 79-02-02 | 02 | 2 | CI-04 | — | N/A | grep | `rg 'Static analysis policy \(CI-04\)' .planning/threads/2026-05-27-post-v116-milestone-assessment.md` | ✅ | ⬜ pending |
| 79-02-03 | 02 | 2 | CI-04 | — | N/A | grep | `rg '\[ \] \*\*CI-04\*\*' .planning/REQUIREMENTS.md; test $? -eq 1` | ✅ | ⬜ pending |
| 79-02-04 | 02 | 2 | CI-04 | — | N/A | manual | Manual read checklist 7/7 from 79-RESEARCH.md § Validation Architecture | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No test framework install needed — validation is grep + manual read against canonical CI sources.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Policy rationale completeness | CI-04 | Semantic accuracy | Read RUNNING.md CI-04 subsection for all three factors: signal value, fork latency, green-main honesty |
| Thread vs ci.yml alignment | CI-04 | Cross-source consistency | Read assessment Open concerns against ci.yml L97–99, L131–133 and RUNNING.md matrix |
| No wiring regression | CI-04 | YAML semantics | Confirm no step lost or gained `continue-on-error` beyond Credo/Dialyzer advisory posture |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
