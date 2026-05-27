---
phase: 80
slug: post-ship-planning-hygiene
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-27
---

# Phase 80 — Validation Strategy

> Grep + manual-read verification for planning-artifact hygiene (no test suite).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ripgrep (`rg`) + manual markdown read |
| **Config file** | none |
| **Quick run command** | `rg 'remains Phase 79|selected — active|Active micro milestone' .planning/threads/` (expect no matches) |
| **Full suite command** | Full gate in 80-02-PLAN.md Task 4 |
| **Estimated runtime** | &lt;5 seconds |

---

## Sampling Rate

- **After every task commit:** Run task-level `acceptance_criteria` rg commands
- **After plan 80-02:** Run full forbidden/required grep gate
- **Before milestone archive:** Manual read checklist 7/7 from 80-RESEARCH.md

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| 80-01 T1–T5 | 80-01 | 1 | tech-debt threads | grep | per-task acceptance_criteria | pending |
| 80-02 T1–T4 | 80-02 | 2 | charter + STATE | grep + read | per-task acceptance_criteria | pending |
