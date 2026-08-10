---
phase: 119
slug: ownership-boundaries-diagnostics
status: ready
nyquist_compliant: true
wave_0_complete: true
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
| 119-01-01 | 01 | 1 | BOUNDARY-01, BOUNDARY-02, OPS-01 | T-119-01, T-119-02, T-119-03, T-119-04 | The tracer classifies one exact prefix mismatch, renders both stable doctor checks independently, states the complete D-119-08 no-management boundary, and redacts raw adapter data. | unit + doctor integration | `mix test test/rindle/ops/ownership_snapshot_test.exs test/rindle/doctor_test.exs --seed 0` | 🟡 create snapshot test; extend doctor test | ⬜ pending |
| 119-02-01 | 02 | 2 | BOUNDARY-01, BOUNDARY-02 | T-119-05, T-119-06, T-119-08 | Default-Oban normalization accepts only the locked supported shapes; `prefix: false` and every unsupported binding refuse before catalog I/O; classifier ambiguity and raw reasons remain bounded. | unit + check integration | `mix test test/rindle/ops/ownership_snapshot_test.exs test/rindle/ops/runtime_checks_test.exs --seed 0` | 🟡 extend existing plus Plan 01 test | ⬜ pending |
| 119-02-02 | 02 | 2 | BOUNDARY-01, BOUNDARY-02 | T-119-07 | Production diagnostic reads preserve `public.oban_jobs`, host `schema_migrations`, and host Oban/Rindle compatibility configuration exactly on healthy and refused paths. | live PostgreSQL integration | `mix test test/rindle/migration_test.exs --seed 0` | ✅ extend migration test | ⬜ pending |
| 119-03-01 | 03 | 3 | BOUNDARY-02, OPS-01 | T-119-09, T-119-10, T-119-12 | Runtime status interprets the shared snapshot before every report helper, preserves legacy tuples, routes split prefixes independently, and trips before queries for every refusal. | unit + integration | `mix test test/rindle/ops/runtime_status_test.exs --seed 0` | ✅ extend runtime-status test | ⬜ pending |
| 119-03-02 | 03 | 3 | OPS-01 | T-119-11 | Runtime-status text and JSON use explicit bounded clauses, constant unknown fallback, doctor-first action, and non-zero exit without sentinel leakage. | task integration | `mix test test/rindle/runtime_status_task_test.exs --seed 0` | ✅ extend task test | ⬜ pending |
| 119-04-01 | 04 | 4 | BOUNDARY-01, OPS-01 | T-119-13, T-119-15, T-119-16 | Admin facade and LiveView project only bounded diagnostic fields, retain separate stable Rindle/Oban ownership data, and add no remediation controls. | unit + render integration | `mix test test/rindle/admin/queries_test.exs --seed 0` | ✅ extend admin query test | ⬜ pending |
| 119-04-02 | 04 | 4 | BOUNDARY-01, OPS-01 | T-119-14, T-119-15, T-119-16 | Adoption-demo failures cross the real LiveView click/render path through a test-only provider fixture, delegate to the shared formatter, and retain bounded status/no-report-query/doctor-first copy without SQL, Postgrex, or credential sentinels. | focused LiveView event/render integration | `cd examples/adoption_demo && mix test test/adoption_demo_web/live/ops_live_test.exs --seed 0` | 🟡 create focused OpsLive test; retain ops E2E as supplemental healthy-path proof | ⬜ pending |

## Wave 0 Requirements

- [x] Plan 01 creates the dedicated snapshot test seam/fixture model before production refactor.
- [x] Plans 01–02 require selected/decoy-schema cases for expected-`public` and expected-`rindle` mismatch classification.
- [x] Plans 01, 03, and 04 require raw-reason redaction assertions at doctor, task, admin, and demo rendering boundaries.
- [x] Plan 03 requires a report-query tripwire for every legacy and new snapshot refusal.
- [x] Plan 04 creates a non-async adoption-demo LiveView fixture seam at the exact runtime-status call boundary and drives sentinel-bearing refusal data through the real click/render path.

## Manual-Only Verifications

All phase behaviors have automated verification.

## Validation Sign-Off

- [x] All seven tasks have focused automated verification and explicit test-file ownership.
- [x] Sampling continuity: every task has an automated command.
- [x] Wave 0 coverage is represented before each production edit.
- [x] No watch-mode flags.
- [x] Feedback latency target is less than 60 seconds for focused commands.
- [x] `nyquist_compliant: true` is set here and in every plan frontmatter.

**Approval:** ready for execution; implementation evidence remains pending.
