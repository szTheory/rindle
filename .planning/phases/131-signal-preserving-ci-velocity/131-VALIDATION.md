---
phase: 131
slug: signal-preserving-ci-velocity
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-28
---

# Phase 131 — Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | ExUnit and Bash CI contracts |
| Quick run command | `mix test test/install_smoke/ci_lane_split_test.exs test/install_smoke/ci_observability_test.exs test/install_smoke/install_smoke_preflight_test.exs --seed 0` |
| Full suite command | `mix quality_signals && bash scripts/ci/test_ci_summary_gate.sh` |

## Per-Task Verification Map

| Task | Requirement | Automated evidence | Status |
|------|-------------|--------------------|--------|
| Change-to-proof and topology documentation | DX-04 | CI topology plus RUNNING parity regression | Green |
| Concurrent authoritative coverage | CI-10 | CI observability source contract | Green |
| Consumer breadth preservation | CI-11 | Lean/full lane topology contracts | Green |
| Independent image proof | CI-12 | Exact job-needs and CI Summary contracts | Green |
| Pinned Phoenix installer | CI-13 | Cold/reuse/mismatch process tests | Green |

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

## Manual-Only Verifications

None.

## Validation Sign-Off

- [x] All requirements have automated verification
- [x] No watch-mode flags
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated 2026-08-28
