---
phase: 126
slug: curated-type-ratchet
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-23
---

# Phase 126 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via Mix; Dialyxir in the supported Nightly home cell |
| **Config file** | `mix.exs`, `.dialyzer_ignore.exs`, `.github/workflows/nightly.yml` |
| **Quick run command** | Focused owner test command named by each task |
| **Full suite command** | `mix ci` plus `bash scripts/maintainer/refactor_contract.sh` |
| **Supported type authority** | Nightly `dialyzer` on Elixir 1.17 / OTP 27, exact branch head |
| **Estimated local runtime** | Focused suites <120 seconds; full local suite varies; Nightly is asynchronous |

## Sampling Rate

- **After every source-bearing task commit:** Run that owner's focused behavior tests and `bash scripts/maintainer/refactor_contract.sh`.
- **After every baseline-policy task:** Run the focused policy and CI-topology tests.
- **After every plan wave:** Run the phase aggregate named by the plan.
- **Before phase verification:** Run `mix ci`, SAFE-01, repository hygiene, exact-head PR CI, and the supported Nightly Dialyzer job.
- **Max local feedback latency:** 120 seconds for a focused task check; asynchronous CI is monitored to a terminal result.

## Per-Task Verification Map

The planner must replace this placeholder with every concrete task from the final `126-*-PLAN.md` files. Each source-bearing row must name its focused behavior command and SAFE-01; baseline and final rows must name the policy/topology tests and exact supported Nightly evidence respectively.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 126-plan-time | — | — | TYPE-01, TYPE-02, SAFE-01 | — | No new warning is suppressed; runtime contracts remain unchanged | planning gate | Plan checker validates the final task map | ✅ | ⬜ pending |

## Wave 0 Requirements

- [ ] Add a focused baseline-policy ExUnit test that validates the exact curated entry representation, rejects duplicates and broad/file-only suppressions, and detects stale inventory drift.
- [ ] Preserve existing Nightly gate/cache topology coverage in `test/install_smoke/ci_lane_split_test.exs` and `test/install_smoke/ci_cache_hygiene_test.exs`.
- [ ] Record the exact 45-entry starting inventory: 8 legacy atom filters plus 37 strict description filters across 18 files.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Supported Dialyzer authority and issue #76 disposition | TYPE-01, TYPE-02 | GitHub Actions supplies the locked Elixir 1.17 / OTP 27 runtime and issue state | Dispatch Nightly on the exact branch head, require `dialyzer` and `Nightly Summary` success, inspect retained-filter evidence, and close #76 only after its acceptance criteria are met. |

## Validation Sign-Off

- [ ] All final tasks have an automated command or an explicit supported-CI receipt.
- [ ] Sampling continuity: no source-bearing task lacks focused behavior and SAFE-01 coverage.
- [ ] Wave 0 policy coverage is green before suppressions are changed.
- [ ] Unsupported local Dialyzer output is diagnostic only and never justifies baseline edits.
- [ ] No watch-mode flags.
- [ ] `nyquist_compliant: true` set after the planner reconciles the complete task map.

**Approval:** pending plan-checker review
