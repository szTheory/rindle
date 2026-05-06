---
phase: 30-lifecycle-repair-operations
plan: 03
subsystem: maintenance
tags: [repair, maintenance, sweep, regenerate, operations-docs]
requires: [30-01, 30-02]
provides:
  - Explicit `mix rindle.sweep_orphaned_temp_files` maintenance lane with dry-run-first semantics
  - Tightened `mix rindle.regenerate_variants` boundary for broad stale or missing drift only
  - Scheduled/on-demand parity for AV temp sweeping
affects: [maintenance, temp-sweep, regenerate, operations-docs]
tech-stack:
  added: []
  patterns: [dry-run-first maintenance, task-worker parity, narrow repair-vs-regenerate boundary]
requirements-completed: [REPAIR-03, REPAIR-04]
completed: 2026-05-06
---

# Plan 30-03 Summary

Implemented the maintenance-lane tightening for lifecycle repair operations.

## Delivered

- Added `mix rindle.sweep_orphaned_temp_files` as the explicit on-demand AV
  temp sweep lane with dry-run-first semantics and deterministic summary
  output.
- Normalized `Rindle.Ops.SweepOrphanedTempFiles` so direct calls and scheduled
  worker runs default to `dry_run: true`, preserving live deletion behind
  explicit opt-in.
- Tightened `mix rindle.regenerate_variants` documentation and operator
  messaging so broad regeneration stays Mix-task-first maintenance and is not
  treated as a single-asset repair surrogate.
- Updated the operations guide to keep upload cleanup and temp sweeping
  separate, document the new temp sweep task, and clarify when to use broad
  regeneration versus focused residue cleanup lanes.
- Extended owned tests to lock dry-run defaults, task/worker parity, and the
  boundary that broad regeneration only targets `stale`/`missing` variants.

## Verification

- Executed:
  `mix test test/rindle/ops/sweep_orphaned_temp_files_test.exs test/rindle/workers/maintenance_workers_test.exs test/rindle/ops/variant_maintenance_test.exs`
- Result: pass (`51 tests, 0 failures`)
