---
phase: 04-day-2-operations
plan: "01"
subsystem: ops
tags: [maintenance, mix-tasks, cleanup, upload-sessions, tdd]
dependency_graph:
  requires:
    - lib/rindle/domain/media_upload_session.ex
    - lib/rindle/domain/upload_session_fsm.ex
    - lib/rindle/storage.ex
    - lib/rindle/config.ex
  provides:
    - Rindle.Ops.UploadMaintenance (cleanup_orphans/1, abort_incomplete_uploads/1)
    - Mix.Tasks.Rindle.CleanupOrphans
    - Mix.Tasks.Rindle.AbortIncompleteUploads
  affects:
    - lib/rindle/workers/purge_storage.ex (related cleanup path)
tech_stack:
  added: []
  patterns:
    - Storage side effects outside DB transactions (Rindle security invariant)
    - Batch-with-error-accumulation (continue on single-item failure)
    - TDD RED/GREEN/REFACTOR cycle
key_files:
  created:
    - lib/rindle/ops/upload_maintenance.ex
    - lib/mix/tasks/rindle.cleanup_orphans.ex
    - lib/mix/tasks/rindle.abort_incomplete_uploads.ex
    - test/rindle/ops/upload_maintenance_test.exs
  modified: []
decisions:
  - Storage deletion failures are accumulated (not fatal) so one bad object does not abort the lane
  - DB row is deleted before attempting storage delete (storage I/O outside transaction)
  - dry_run defaults to true for safety in cleanup_orphans
  - abort_incomplete_uploads requires no storage adapter (DB-only operation)
metrics:
  duration: 5 min
  completed: 2026-04-26
  tasks_completed: 2
  files_created: 4
  files_modified: 0
---

# Phase 04 Plan 01: Upload-Session Maintenance Lane Summary

Upload-session maintenance lane with shared service, two Mix task entrypoints, and regression tests. Operators can now abort incomplete uploads and remove orphaned staged objects from the CLI without manual SQL.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 (RED) | Failing tests for upload maintenance | 7ef3393 | test/rindle/ops/upload_maintenance_test.exs |
| 1 (GREEN) | Implement cleanup operations + CLI wrappers | f92c44f | lib/rindle/ops/upload_maintenance.ex, lib/mix/tasks/rindle.cleanup_orphans.ex, lib/mix/tasks/rindle.abort_incomplete_uploads.ex |
| 2 | Lock behavior in regression tests | 5f94ab6 | lib/mix/tasks/rindle.abort_incomplete_uploads.ex |

## What Was Built

### Rindle.Ops.UploadMaintenance (263 lines)

Shared service providing two public functions:

- `cleanup_orphans/1` — queries sessions in `expired` state with `expires_at` in the past, optionally deletes them from DB and calls `storage_mod.delete/2` on their upload keys. Dry-run mode reports counts without side effects. Storage failures are accumulated in `storage_errors` rather than aborting the batch.
- `abort_incomplete_uploads/1` — queries sessions in `signed` or `uploading` states with `expires_at` in the past, transitions each to `expired` via Ecto changeset update.

Both return `{:ok, report_map}` or `{:error, reason}`.

### mix rindle.cleanup_orphans (120 lines)

CLI entrypoint supporting `--dry-run` and `--storage MODULE` flags. Prints a structured report and exits non-zero when `storage_errors > 0`.

### mix rindle.abort_incomplete_uploads (81 lines)

CLI entrypoint with no flags. Prints a structured report and exits non-zero when `abort_errors > 0`.

### test/rindle/ops/upload_maintenance_test.exs (209 lines)

12 tests covering:
- Dry-run: reports counts without deleting or calling storage
- Live cleanup: deletes expired sessions + staged objects
- Storage failure resilience: error count accumulated, cleanup continues
- Mixed state isolation: non-expired sessions untouched
- Abort: transitions signed/uploading past TTL to expired
- Abort edge cases: completed/already-expired sessions untouched; valid report shape always returned

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Storage errors accumulated, not fatal | Single broken object should not abort lane (T-04-02) |
| DB delete before storage delete | Storage I/O must stay outside DB transactions (security invariant 4) |
| `dry_run` defaults to `true` | Safest default for maintenance operations; operator must opt into destructive run |
| Separate abort and cleanup tasks | Two-step pipeline is safer; abort is DB-only, cleanup deletes objects |

## Threat Model Compliance

| Threat | Mitigation Applied |
|--------|--------------------|
| T-04-01 (Tampering via cleanup scope) | dry-run gate is entirely separate from destructive path; TTL/state checked before any delete |
| T-04-02 (Denial via full-lane failure) | Errors accumulated per session; single failure never short-circuits rest of batch |
| T-04-03 (Info disclosure) | Reports include counts and session IDs only; no storage credentials or asset contents leaked |

## Deviations from Plan

None — plan executed exactly as written.

## TDD Gate Compliance

- RED gate commit: 7ef3393 `test(04-01): add failing tests for upload maintenance cleanup and abort`
- GREEN gate commit: f92c44f `feat(04-01): implement upload-session cleanup operations and CLI wrappers`
- No REFACTOR gate needed (code was clean after GREEN)

## Known Stubs

None — all functions are fully implemented and wired.

## Self-Check: PASSED

All 5 files present. All 3 commits found (7ef3393, f92c44f, 5f94ab6).
