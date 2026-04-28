---
phase: 04-day-2-operations
plan: "03"
subsystem: day2-ops
tags: [metadata, backfill, maintenance, oban, workers, cron]
dependency_graph:
  requires:
    - 04-01 (UploadMaintenance service — workers delegate to it)
  provides:
    - Rindle.Ops.MetadataBackfill (reusable metadata backfill service)
    - Mix.Tasks.Rindle.BackfillMetadata (CLI)
    - Rindle.Workers.CleanupOrphans (cron worker)
    - Rindle.Workers.AbortIncompleteUploads (cron worker)
  affects:
    - Any adopter scheduling Oban cron maintenance jobs
tech_stack:
  added: []
  patterns:
    - TDD (RED/GREEN per task)
    - Delegation pattern (workers own no logic; delegate to service layer)
    - Failure-accumulation (per-asset errors counted, run never aborted)
    - T-04-07 mitigation (only analyzer output persisted; raw bytes never logged)
    - T-04-09 mitigation (CLI is thin wrapper around service)
key_files:
  created:
    - lib/rindle/ops/metadata_backfill.ex
    - lib/mix/tasks/rindle.backfill_metadata.ex
    - lib/rindle/workers/cleanup_orphans.ex
    - lib/rindle/workers/abort_incomplete_uploads.ex
    - test/rindle/ops/metadata_backfill_test.exs
    - test/rindle/workers/maintenance_workers_test.exs
  modified: []
decisions:
  - Backfill targets ready/available/degraded assets only — in-progress and terminal states excluded
  - Per-asset failures accumulated (never abort run); exit non-zero only on any failure count > 0
  - Workers use :rindle_maintenance queue so adopters can keep maintenance separate from processing queues
  - Storage adapter and analyzer resolved via opts or app config (not hardcoded)
  - Workers return {:error, reason} not raise, so Oban retries tag failures as observable job errors
metrics:
  duration: "6 minutes"
  completed_date: "2026-04-26"
  tasks_completed: 2
  files_changed: 6
---

# Phase 04 Plan 03: Metadata Backfill and Cron Maintenance Workers Summary

**One-liner:** Metadata backfill service with failure-accumulation and two delegation-only Oban cron workers for scheduled upload maintenance.

## What Was Built

### Task 1: Metadata Backfill Service and CLI

`Rindle.Ops.MetadataBackfill.backfill_metadata/1` iterates assets in `ready`, `available`, or `degraded` states, downloads each source from storage, reruns the configured analyzer, and persists the resulting metadata map. Failures are accumulated in the report rather than aborting the run. An optional `:profile` filter allows scoping to a single profile.

`Mix.Tasks.Rindle.BackfillMetadata` is a thin CLI wrapper that resolves the storage and analyzer modules from flags or app config, calls the service, prints a formatted run summary, and exits non-zero when any failures occurred.

### Task 2: Cron-Capable Maintenance Workers

`Rindle.Workers.CleanupOrphans` and `Rindle.Workers.AbortIncompleteUploads` are Oban workers on the `:rindle_maintenance` queue that delegate entirely to `Rindle.Ops.UploadMaintenance`. No cleanup logic is duplicated. Both workers return `{:error, reason}` on failure so Oban retries are observable in the job queue. Both workers are documented with cron configuration examples.

## Test Coverage

- **Task 1:** 9 tests covering success paths (all states, profile filter, zero assets, multi-asset), failure paths (storage errors, analyzer errors, all-fail), and report shape.
- **Task 2:** 16 tests covering delegation to UploadMaintenance, queue contract (`:rindle_maintenance`), max_attempts observability, dry-run, live run, error paths, and Oban.Worker cron schedulability contract.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed `__queue__` and `__max_attempts__` test assertions**
- **Found during:** Task 2 GREEN phase
- **Issue:** Tests used `CleanupOrphans.__queue__()` and `__max_attempts__()` which are not public functions in Oban 2.21. Oban exposes worker options via `__opts__/0` which returns a keyword list.
- **Fix:** Updated test assertions to use `CleanupOrphans.__opts__()` and check the `:queue` / `:max_attempts` keys.
- **Files modified:** `test/rindle/workers/maintenance_workers_test.exs`
- **Commit:** 8dc4c0e

**2. [Rule 1 - Bug] Fixed CleanupOrphans raising instead of returning {:error, reason}**
- **Found during:** Task 2 GREEN phase (test expected `{:error, reason}` for invalid storage module)
- **Issue:** Initial implementation raised `RuntimeError` for unresolvable storage modules; Oban `perform_job` in test mode wraps raises as test failures.
- **Fix:** Changed `resolve_storage_adapter/1` to return `{:ok, mod}` / `{:error, reason}` tuples; updated `perform/1` to use `with` matching.
- **Files modified:** `lib/rindle/workers/cleanup_orphans.ex`
- **Commit:** 8dc4c0e

## TDD Gate Compliance

Both tasks followed RED/GREEN order:
- Task 1: `0e4cd87` (test/RED) → `fde754d` (feat/GREEN)
- Task 2: `377f04b` (test/RED) → `8dc4c0e` (feat/GREEN)

## Known Stubs

None — all data flows are wired to actual DB queries, storage adapters, and analyzer callbacks.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes introduced. The backfill downloads files through the existing `Rindle.Storage` behaviour and only persists analyzer output back to `media_assets.metadata` (T-04-07 compliant).

## Self-Check: PASSED

Files exist:
- lib/rindle/ops/metadata_backfill.ex: FOUND
- lib/mix/tasks/rindle.backfill_metadata.ex: FOUND
- lib/rindle/workers/cleanup_orphans.ex: FOUND
- lib/rindle/workers/abort_incomplete_uploads.ex: FOUND
- test/rindle/ops/metadata_backfill_test.exs: FOUND
- test/rindle/workers/maintenance_workers_test.exs: FOUND

Commits:
- 0e4cd87 (test RED for task 1): FOUND
- fde754d (feat GREEN for task 1): FOUND
- 377f04b (test RED for task 2): FOUND
- 8dc4c0e (feat GREEN for task 2): FOUND
- 4f9552b (docs expand): FOUND

Tests: 25 tests, 0 failures
