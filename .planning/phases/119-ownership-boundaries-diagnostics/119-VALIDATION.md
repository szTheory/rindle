---
phase: 119
slug: ownership-boundaries-diagnostics
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-09
---

# Phase 119 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with Ecto SQL Sandbox / project `DataCase` |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_status_test.exs test/rindle/doctor_test.exs test/rindle/runtime_status_task_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~30 seconds |

## Sampling Rate

- **After every task commit:** Run the quick command above.
- **After every plan wave:** Run `mix test`.
- **Before `$gsd-verify-work`:** Full suite must be green.
- **Max feedback latency:** 30 seconds.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 119-01-01 | 01 | 1 | BOUNDARY-01, BOUNDARY-02 | T-119-01, T-119-02 | Inspection reads only the fixed Rindle relation allowlist and resolved host Oban `oban_jobs`; invalid prefixes and catalog failures refuse safely. | unit + integration | focused command above | ✅ extend focused ops tests | ⬜ pending |
| 119-02-01 | 02 | 2 | OPS-01 | T-119-03 | Doctor and runtime status share classifications, preserve stable IDs/legacy tuples, and never render raw database details. | unit + task integration | focused command above | ✅ extend doctor and task tests | ⬜ pending |
| 119-03-01 | 03 | 2 | BOUNDARY-01, OPS-01 | T-119-03, T-119-04 | Runtime report queries never execute after snapshot refusal; text, JSON, and demo surfaces remain bounded. | integration | focused command above | ✅ extend runtime and demo tests | ⬜ pending |

## Wave 0 Requirements

- [ ] Add a dedicated snapshot test seam/fixture model before production refactor.
- [ ] Add real selected/decoy-schema cases for expected-`public` and expected-`rindle` mismatch classification.
- [ ] Add raw-reason redaction assertions for task and demo renderers.
- [ ] Add a report-query tripwire proving no report query runs after snapshot refusal.

## Manual-Only Verifications

All phase behaviors have automated verification.

## Validation Sign-Off

- [ ] All tasks have automated verification or Wave 0 dependencies.
- [ ] Sampling continuity: no 3 consecutive tasks without automated verification.
- [ ] Wave 0 covers all identified gaps.
- [ ] No watch-mode flags.
- [ ] Feedback latency < 30 seconds.
- [ ] `nyquist_compliant: true` set in frontmatter.

**Approval:** pending
