---
phase: 30-lifecycle-repair-operations
plan: 04
subsystem: lifecycle-repair
tags: [repair, reporting, sweep, operations-docs, troubleshooting]
requires: [30-01, 30-02, 30-03]
provides:
  - Deterministic repair report counters with typed failure entries and stable failure classes
  - Summary-first temp sweep task output with bounded tagged failure lines
  - Operator docs that teach `reprobe`, `requeue`, `regenerate`, `cleanup`, and `sweep` explicitly
affects: [repair-reporting, mix-task-output, operator-guidance, troubleshooting]
tech-stack:
  added: []
  patterns: [summary-first-reporting, bounded-failure-output, explicit-repair-verb-vocabulary]
key-files:
  modified:
    [
      lib/rindle/ops/lifecycle_repair.ex,
      lib/mix/tasks/rindle.sweep_orphaned_temp_files.ex,
      guides/operations.md,
      guides/troubleshooting.md,
      test/rindle/ops/lifecycle_repair_test.exs,
      test/rindle/ops/sweep_orphaned_temp_files_test.exs,
      test/rindle/error_test.exs
    ]
key-decisions:
  - "Repair reports keep deterministic counters first and use typed failure entries with stable `failure_class`, `reason`, and human-readable `message` fields."
  - "The temp sweep Mix task keeps summary counters first and emits bounded tagged failure lines only after the summary when `errors > 0`."
  - "Operator-facing docs now treat `reprobe`, `requeue`, `regenerate`, `cleanup`, and `sweep` as separate supported recovery lanes."
requirements-completed: [REPAIR-05, REPAIR-05-01]
completed: 2026-05-06
---

# Phase 30 Plan 04 Summary

## Accomplishments

- Normalized `Rindle.Ops.LifecycleRepair` report semantics so reprobe and
  requeue runs expose deterministic counters and typed failures with stable
  failure classes.
- Tightened `mix rindle.sweep_orphaned_temp_files` output to print summary
  counters first and to support bounded tagged failure rendering after the
  summary.
- Rewrote the operations and troubleshooting guides around the supported
  repair verbs: `reprobe`, `requeue`, `regenerate`, `cleanup`, and `sweep`.
- Extended owned tests to lock the new report shape, failure tagging, bounded
  sweep output formatting, and doc coverage for the supported repair verbs.

## Verification

- Executed:
  `mix test test/rindle/ops/lifecycle_repair_test.exs test/rindle/ops/sweep_orphaned_temp_files_test.exs test/rindle/error_test.exs`
- Result: pass (`29 tests, 0 failures`)

## Notes

- Test output still includes the expected warning log event
  `rindle.lifecycle_repair.requeue_variant_failed` when exercising typed
  per-variant failure reporting.
- Concurrent worktree edits outside the owned files were preserved.
