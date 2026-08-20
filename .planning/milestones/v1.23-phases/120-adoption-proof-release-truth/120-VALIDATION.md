---
phase: 120
slug: adoption-proof-release-truth
status: draft
nyquist_compliant: false
wave_0_complete: true
created: 2026-08-09
---

# Phase 120 — Validation Strategy

## Test Infrastructure

| Property | Value |
|---|---|
| Framework | ExUnit with PostgreSQL-backed generated-app and demo smoke harnesses |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test test/install_smoke/docs_parity_test.exs --seed 0` |
| Full suite command | `mix test test/install_smoke/generated_app_smoke_test.exs test/install_smoke/docs_parity_test.exs --seed 0` |
| Estimated runtime | ~120 seconds |

## Sampling Rate

- After every task commit: run the focused affected ExUnit file.
- After every plan wave: run the relevant generated-app/docs/demo suite.
- Before verification: run the Phase 120 full-suite command plus its documented demo/CI lane checks.
- Max feedback latency: 180 seconds.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---|---|---|---|---|---|---|
| 120-01 | planned | 1 | PROOF-01 | package-consumer integration | `mix test test/install_smoke/generated_app_smoke_test.exs --seed 0` | pending |
| 120-02 | planned | 2 | PROOF-02 | Cohort/adoption integration | focused demo migration and boot tests | pending |
| 120-03 | planned | 3 | DOCS-01 | documentation parity | `mix test test/install_smoke/docs_parity_test.exs --seed 0` | pending |

## Wave 0 Requirements

Existing ExUnit, generated-app helper, docs-parity, and demo infrastructure covers this phase; no new framework setup is required.

## Manual-Only Verifications

All phase behaviors should be automated. Release publish itself remains governed by `guides/release_publish.md` and is not performed during phase execution.

## Validation Sign-Off

- [x] Existing infrastructure covers all phase requirements.
- [x] Every planned slice has an automated verification path.
- [ ] `nyquist_compliant: true` set after plans are reviewed.

**Approval:** pending plan review
