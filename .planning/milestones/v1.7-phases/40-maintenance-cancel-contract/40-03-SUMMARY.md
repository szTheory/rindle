---
phase: 40-maintenance-cancel-contract
plan: 03
subsystem: observability
tags: [runtime-status, resumable, gcs, broker, tests]
requirements-completed: [RESUMABLE-10, RESUMABLE-11]
completed: 2026-05-07
---

# Phase 40 Plan 03 Summary

Runtime status now exposes bounded resumable maintenance counters inside `upload_sessions`, and the secret-gated live GCS proof harness covers maintenance-lane scenarios without leaking session URIs.

## Accomplishments

- Added nested resumable counters under `report.upload_sessions` for pending sessions, expired session URIs, and stale retained URIs.
- Updated `mix rindle.runtime_status` text and JSON surfaces to render the resumable counters inside the existing `Upload sessions:` section.
- Added tests that lock redaction expectations so neither text nor JSON output exposes raw `session_uri` values.
- Extended `test/rindle/upload/broker_test.exs` so the existing live GCS harness also covers maintenance-lane cancel and stale-session cleanup scenarios, while remaining secret-gated.
- Upgraded the broker test repo probe to support maintenance and runtime-status reads inside the shared live proof harness.

## Verification

- `mix test test/rindle/ops/runtime_status_test.exs test/rindle/runtime_status_task_test.exs test/rindle/upload/broker_test.exs`

## Deviations

- The live GCS maintenance proofs compile and remain secret-gated, but they were skipped in this session because the required GCS environment was not present.

## Self-Check: PASSED
