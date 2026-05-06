---
phase: 31-runtime-diagnostics-drift-visibility
plan: 02
subsystem: diagnostics
tags: [runtime-status, operator-reporting, oban, repair]
requires: [31-01]
provides:
  - Public `Rindle.runtime_status/1` plus `mix rindle.runtime_status`
  - Bounded runtime classifications for failed, cancelled, starved, drifted, and orphan-suspect work
affects: [runtime-status, operator-reporting, api-boundary]
tech-stack:
  added: []
  patterns: [bounded status report, shared api-task projection, recommendation map]
requirements-completed: [DIAG-02]
completed: 2026-05-06
---

# Phase 31 Plan 31-02 Summary

## Implemented

- Added public `Rindle.runtime_status/1` with a hidden `Rindle.Ops.RuntimeStatus` service.
- Added `mix rindle.runtime_status` with deterministic text and JSON output.
- Classified bounded runtime findings for:
  - `failed_work`
  - `cancelled_work`
  - `queue_starved`
  - `orphan_suspect`
  - `recipe_drift`
  - `storage_drift`
  - `probe_drift`
- Kept the report read-only, filter-bounded (`profile`, `older_than`, `limit`, `format`), and backed by lifecycle rows plus `oban_jobs` corroboration.
- Extended the public/hidden docs boundary tests so `Rindle.runtime_status/1` and the Mix task stay public while `Rindle.Ops.RuntimeStatus` remains hidden.

## Tests

- `mix test test/rindle/api_surface_boundary_test.exs test/rindle/ops/runtime_status_test.exs test/rindle/runtime_status_task_test.exs --warnings-as-errors`
- Result: 24 tests, 0 failures

## Notes

- Runtime status derives truth from `media_assets`, `media_variants`, `media_upload_sessions`, and `oban_jobs`; it does not treat `media_processing_runs` as authoritative.
- The text and JSON task surfaces are both thin projections of the same runtime report.
