---
phase: 30-lifecycle-repair-operations
plan: 02
subsystem: lifecycle-repair
tags: [repair, requeue, public-api, variants, operator-guidance]
requires: [30-01]
provides:
  - Public asset-scoped `Rindle.requeue_variants/2` facade entrypoint
  - Hidden `Rindle.Ops.LifecycleRepair.requeue_failed_variants/2` service with explicit variant-name validation
  - Shared `Rindle.Workers.ProcessVariant.build_job/3` seam for targeted repair job construction and uniqueness reuse
affects: [public-api, variant-repair, operator-guidance, compiled-docs-boundary]
tech-stack:
  added: []
  patterns: [facade-over-hidden-ops, report-based-repair, shared-worker-job-builder]
key-files:
  modified:
    [
      lib/rindle.ex,
      lib/rindle/error.ex,
      lib/rindle/ops/lifecycle_repair.ex,
      lib/rindle/workers/process_variant.ex,
      test/rindle/api_surface_boundary_test.exs,
      test/rindle/error_test.exs,
      test/rindle/ops/lifecycle_repair_test.exs,
      test/rindle/workers/process_variant_test.exs
    ]
key-decisions:
  - "Default targeted repair stays asset-scoped and selects only variants already in `failed` or `cancelled` state."
  - "Explicit `variant_names` narrowing validates against variants that belong to the asset and fails loudly on unknown names."
  - "Targeted repair reuses `ProcessVariant` job args, queue selection, timeout handling, and Oban uniqueness through a shared worker helper instead of inventing a second enqueue contract."
  - "Cancellation guidance now names real recovery surfaces: `Rindle.requeue_variants/2` for one asset and `mix rindle.regenerate_variants` for broad regeneration."
patterns-established:
  - "Asset-scoped public repair APIs may return `{:ok, report}` with partial-failure detail instead of short-circuiting item-level problems."
  - "Hidden repair services can classify uniqueness conflicts as deterministic skips while keeping non-repairable selections as typed failures."
requirements-completed: [REPAIR-02, REPAIR-02-01]
completed: 2026-05-06
---

# Phase 30 Plan 02 Summary

## Accomplishments

- Added public `Rindle.requeue_variants/2` as the supported asset-scoped targeted repair entrypoint.
- Extended hidden `Rindle.Ops.LifecycleRepair` with `requeue_failed_variants/2`, including:
  - explicit `variant_names` narrowing
  - loud unknown-name validation
  - deterministic `selected`, `enqueued`, `skipped`, and `errors` counters
  - typed per-variant failure entries for non-repairable selections or enqueue failures
- Reused `Rindle.Workers.ProcessVariant` job building and uniqueness behavior through a shared `build_job/3` helper, preserving queue/timeout behavior and Oban conflict handling.
- Corrected stale operator guidance in `Rindle.Error` so cancellation recovery points at real APIs instead of nonexistent `Rindle.regenerate_variant/2`.
- Locked the new boundary and repair semantics in API, error, ops, and worker tests.

## Verification

- `mix test test/rindle/api_surface_boundary_test.exs test/rindle/error_test.exs test/rindle/ops/lifecycle_repair_test.exs test/rindle/workers/process_variant_test.exs`
- Result: `44 tests, 0 failures`

## Notes

- The worktree already contained concurrent edits from prior plan work on `lib/rindle.ex`, `test/rindle/api_surface_boundary_test.exs`, `lib/rindle/ops/lifecycle_repair.ex`, and `test/rindle/ops/lifecycle_repair_test.exs`. This plan was applied on top without reverting them.
