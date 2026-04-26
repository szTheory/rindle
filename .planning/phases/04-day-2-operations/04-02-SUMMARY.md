---
phase: 04-day-2-operations
plan: "02"
subsystem: ops
tags: [day2, variant-maintenance, mix-tasks, storage-reconciliation, tdd]
dependency_graph:
  requires:
    - 01-06  # Storage adapters and capabilities
    - 02-02  # Variant processing workers
    - 01-04  # Variant FSM and state management
  provides:
    - variant-regeneration-cli
    - storage-reconciliation-cli
    - shared-maintenance-operations
  affects:
    - lib/rindle/ops/variant_maintenance.ex
    - lib/mix/tasks/rindle.regenerate_variants.ex
    - lib/mix/tasks/rindle.verify_storage.ex
    - test/rindle/ops/variant_maintenance_test.exs
tech_stack:
  added: []
  patterns:
    - TDD (RED/GREEN/REFACTOR)
    - Filter-then-enumerate for targeted batch operations
    - HEAD check for storage reconciliation
    - Oban.insert/1 for job enqueueing
key_files:
  created:
    - lib/rindle/ops/variant_maintenance.ex
    - lib/mix/tasks/rindle.regenerate_variants.ex
    - lib/mix/tasks/rindle.verify_storage.ex
    - test/rindle/ops/variant_maintenance_test.exs
  modified: []
decisions:
  - Use Ecto.Query filter composition for profile/variant targeting instead of building SQL manually
  - Distinguish :not_found from other errors in HEAD check — only :not_found flips state to missing
  - Use Repo.update_all for missing state flip (avoids loading struct + changeset overhead)
  - Count ready/queued/processing variants as "skipped" (not errors) in regenerate result
  - Use Mox stub/3 instead of ordered expect/3 for multi-row verification test to avoid DB ordering sensitivity
metrics:
  duration: 8 min
  completed_date: "2026-04-26"
  tasks_completed: 2
  files_created: 4
  files_modified: 0
requirements:
  - OPS-03
  - OPS-04
  - OPS-05
  - OPS-06
  - OPS-09
---

# Phase 04 Plan 02: Variant Maintenance and Storage Reconciliation Summary

Variant maintenance CLI for Day-2 operations — stale/missing variant re-enqueueing and HEAD-based storage reconciliation with deterministic summary output.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| RED | Add failing tests for variant maintenance | 5aa3a4b | test/rindle/ops/variant_maintenance_test.exs |
| 1 | Implement variant maintenance and storage reconciliation | 98be7f7 | lib/rindle/ops/variant_maintenance.ex, lib/mix/tasks/rindle.regenerate_variants.ex, lib/mix/tasks/rindle.verify_storage.ex |
| fix | Order-independent mock in summary counts test | 4c88f04 | test/rindle/ops/variant_maintenance_test.exs |
| docs | Expand Mix task moduledocs | ed83907 | lib/mix/tasks/rindle.regenerate_variants.ex, lib/mix/tasks/rindle.verify_storage.ex |

## What Was Built

### `Rindle.Ops.VariantMaintenance`

Shared service module exposing two operations:

- **`regenerate_variants/1`** — Queries variants in `stale` or `missing` state, optionally filtered by `:profile` string or `:variant_name`, and enqueues `ProcessVariant` Oban jobs for each. Returns `{:ok, %{enqueued: N, skipped: M}}`.

- **`verify_storage/1`** — Walks variant records with a `storage_key` in verifiable states, calls `storage_adapter.head/2` on each object, flips absent entries to `missing` state, and returns `{:ok, %{checked: N, present: P, missing: M, errors: E}}`.

Both operations use Ecto query composition for filter targeting and return `{:error, reason}` on failures.

### `mix rindle.regenerate_variants`

Thin CLI entrypoint that delegates to `VariantMaintenance.regenerate_variants/1`. Accepts `--profile` and `--variant` flags. Exits with code 1 on errors.

### `mix rindle.verify_storage`

Thin CLI entrypoint that delegates to `VariantMaintenance.verify_storage/1`. Accepts `--profile` and `--variant` flags. Emits deterministic summary. Exits with code 1 on errors.

## TDD Gate Compliance

- RED gate: `test(04-02)` commit `5aa3a4b` — 12 failing tests
- GREEN gate: `feat(04-02)` commit `98be7f7` — 12 passing tests
- No REFACTOR gate needed (code was clean on first pass)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Ecto binding list compilation error**
- **Found during:** Task 1 (GREEN phase)
- **Issue:** `from [v | _] in query` is not valid in Ecto query bindings; must use `from v in query`
- **Fix:** Changed to `from v in query` in `maybe_filter_variant_name/2`
- **Files modified:** lib/rindle/ops/variant_maintenance.ex
- **Commit:** 98be7f7

**2. [Rule 1 - Bug] Mox expect ordering sensitivity in multi-row test**
- **Found during:** Task 2 full test suite run
- **Issue:** `Mox.expect` calls are consumed in FIFO order, but DB returns rows in non-deterministic order. The test for "reports summary with all counts" seeded thumb and large variants; large was returned first, causing the thumb expect to fail with FunctionClauseError.
- **Fix:** Replaced two ordered `expect` calls with a single `stub` using pattern matching on the storage key
- **Files modified:** test/rindle/ops/variant_maintenance_test.exs
- **Commit:** 4c88f04

## Known Stubs

None. All data flows are wired to DB queries and storage adapter calls.

## Threat Surface Scan

No new network endpoints or auth paths introduced. The two Mix tasks operate in a supervised Elixir process (`app.start`) and delegate all storage I/O to the configured profile adapter — consistent with the existing delivery and processing patterns.

## Self-Check: PASSED

Files exist:
- FOUND: lib/rindle/ops/variant_maintenance.ex
- FOUND: lib/mix/tasks/rindle.regenerate_variants.ex
- FOUND: lib/mix/tasks/rindle.verify_storage.ex
- FOUND: test/rindle/ops/variant_maintenance_test.exs

Commits exist:
- FOUND: 5aa3a4b (test RED)
- FOUND: 98be7f7 (feat GREEN)
- FOUND: 4c88f04 (fix test ordering)
- FOUND: ed83907 (docs expansion)

Test result: 12 tests, 0 failures
