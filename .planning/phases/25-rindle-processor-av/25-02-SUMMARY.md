---
phase: 25-rindle-processor-av
plan: 02
title: Queue-aware AV variant worker with run-dir cleanup and aggregate recompute
requirements:
  - AV-03-08
  - AV-03-10
  - AV-03-11
  - AV-03-12
files_changed:
  - lib/rindle/av/temp_run_dir.ex
  - lib/rindle/domain/asset_aggregate.ex
  - lib/rindle/workers/process_variant.ex
  - lib/rindle/workers/promote_asset.ex
  - test/rindle/workers/process_variant_test.exs
  - test/rindle/workers/promote_asset_test.exs
verified:
  - mix test test/rindle/workers/process_variant_test.exs test/rindle/workers/promote_asset_test.exs
completed_at: 2026-05-05
---

# Phase 25 Plan 02 Summary

Implemented the Phase 25 worker durability seam without introducing a second variant pipeline.

## What Changed

- Added `Rindle.AV.TempRunDir` so each variant run uses a single `Rindle.tmp/<uuid>/` subtree and always removes it on both success and handled failure paths.
- Added `Rindle.Domain.AssetAggregate.recompute/2` so asset state is derived from persisted sibling variant rows and moves through `transcoding`, `ready`, and `degraded`.
- Refactored `Rindle.Workers.ProcessVariant` to:
  - expose queue/timeout/uniqueness job builders for normalized AV specs,
  - use deterministic storage keys derived from `variant.name + recipe_digest + extension`,
  - run all local work inside one temp run directory,
  - apply an atomic ready guard that cancels stale-source promotions before the terminal ready write,
  - recompute aggregate asset state when processing starts and after terminal variant outcomes.
- Refactored `Rindle.Workers.PromoteAsset` to normalize variant specs at enqueue time, persist `output_kind`, and route AV variants onto the `:rindle_media` queue with the worker’s AV job options.
- Expanded worker tests to cover queue routing, active-job uniqueness, timeout propagation, deterministic storage keys, temp-root cleanup, aggregate degradation, and stale-source cancellation.

## Verification

`mix test test/rindle/workers/process_variant_test.exs test/rindle/workers/promote_asset_test.exs`

Result: `14 tests, 0 failures`

## Deviations from Plan

None.
