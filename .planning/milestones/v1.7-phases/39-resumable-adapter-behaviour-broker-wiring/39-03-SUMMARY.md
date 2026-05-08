---
phase: 39-resumable-adapter-behaviour-broker-wiring
plan: 03
subsystem: broker
tags: [broker, resumable, repo, compensation, telemetry, facade, tests]
requirements-completed: [RESUMABLE-06, RESUMABLE-07]
completed: 2026-05-07
---

# Phase 39 Plan 03 Summary

Wired the broker-owned resumable session lifecycle without changing completion trust.

## Accomplishments

- Added `initiate_resumable_session/2`, `resumable_session_status/2`, and `cancel_resumable_session/2` to `Rindle.Upload.Broker`.
- Mirrored the multipart remote-first boundary: storage-side initiation happens before DB persistence, and persist failure triggers compensating `cancel_resumable_upload/3`.
- Persisted resumable session bookkeeping on the session row with `upload_strategy: "resumable"`, `session_uri`, expiry, offset, and `region_hint`.
- Kept status polling observational only: it refreshes bookkeeping and emits resumable telemetry without consuming the `"resuming"` state.
- Left `verify_completion/2` on the existing `adapter.head/2` trust gate and added facade delegates in `Rindle`.
- Expanded broker tests to cover resumable bootstrap, failure/no-write behavior, compensation, status refresh, cancel behavior, and unsupported-adapter paths.

## Verification

- `mix test test/rindle/upload/broker_test.exs`

## Deviations

- The existing broker test suite still logs the known `rindle.upload_session.transition_failed` warning during invalid-transition coverage; the suite passed and no new failure path was introduced.

## Self-Check: PASSED
