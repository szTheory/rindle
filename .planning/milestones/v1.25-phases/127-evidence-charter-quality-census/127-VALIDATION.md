---
phase: 127
slug: evidence-charter-quality-census
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-28
---

# Phase 127 — Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | ExUnit plus checked-in evidence receipt |
| Quick run command | `mix test test/install_smoke/credo_policy_test.exs --seed 0` |
| Full suite command | `mix quality_signals` |

## Per-Task Verification Map

| Task | Requirement | Automated evidence | Status |
|------|-------------|--------------------|--------|
| Finite census and baselines | CRAFT-01 | Structural audit of `127-QUALITY-CENSUS.md`; Credo baseline policy test | Green |
| Explicit candidate dispositions | CRAFT-02 | Census ledger audit; prose-independent Credo identity contract | Green |

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

## Manual-Only Verifications

None. Requirement closure is based on a checked-in census and executable policy contracts.

## Validation Sign-Off

- [x] All requirements have automated or structured evidence
- [x] No watch-mode flags
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated 2026-08-28
