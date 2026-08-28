---
phase: 130
slug: runtime-diagnostics-complexity
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-28
---

# Phase 130 — Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | ExUnit plus SAFE-01 Bash runner |
| Quick run command | `mix test test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_checks_gcs_test.exs test/install_smoke/credo_policy_test.exs --seed 0` |
| Full suite command | `mix quality_signals && bash scripts/maintainer/refactor_contract.sh` |

## Per-Task Verification Map

| Task | Requirement | Automated evidence | Status |
|------|-------------|--------------------|--------|
| Provider diagnostic owners | MAINT-01 | Runtime core/GCS behavior suites | Green |
| Curated complexity reduction | MAINT-02 | Credo identity/count policy test | Green |
| Compile-cycle preservation | MAINT-03 | SAFE-01 graph and contract runner | Green |

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

## Manual-Only Verifications

None.

## Validation Sign-Off

- [x] All requirements have automated verification
- [x] No watch-mode flags
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated 2026-08-28
