---
phase: 75
slug: merge-blocking-proof-lanes
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-05-27
---

# Phase 75 — Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Mix) + GitHub Actions YAML |
| **Quick run** | `mix test test/install_smoke/docs_parity_test.exs test/rindle/batch_owner_erasure_task_test.exs` |
| **YAML lint** | `grep -n '^  proof:' .github/workflows/ci.yml` |

## Sampling Rate

- After every task touching tests: run both test files above
- After `ci.yml` edits: grep proof job + confirm adopter grep step absent
- Before phase close: full `docs_parity_test.exs` green

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| 75-01-01 | 01 | 1 | CI-03 | grep | `grep -q '^  proof:' .github/workflows/ci.yml` | ⬜ pending |
| 75-01-02 | 01 | 1 | CI-03 | grep | `grep -c 'docs_parity_test.exs' .github/workflows/ci.yml` | ⬜ pending |
| 75-01-03 | 01 | 1 | CI-03 | grep | `grep -c 'batch_owner_erasure_task_test.exs' .github/workflows/ci.yml` | ⬜ pending |
| 75-02-01 | 02 | 2 | CI-03 | grep | `! grep -q 'Verify AV onboarding docs stay on the public facade path' .github/workflows/ci.yml` | ⬜ pending |
| 75-03-01 | 03 | 2 | CI-03 | grep | `grep -c '`proof`' RUNNING.md` | ⬜ pending |
| 75-04-01 | 04 | 3 | CI-03 | unit | `mix test test/install_smoke/docs_parity_test.exs` | ⬜ pending |
| 75-04-02 | 04 | 3 | CI-03 | unit | `mix test test/rindle/batch_owner_erasure_task_test.exs` | ⬜ pending |
| 75-05-01 | 05 | 4 | CI-03 | grep | `grep -q '\[x\] \*\*CI-03\*\*' .planning/REQUIREMENTS.md` | ⬜ pending |
