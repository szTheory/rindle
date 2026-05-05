---
phase: 27
plan: 03
plan_id: 27-03
title: Asset-scoped processing cancellation
status: completed
code_commit: dd1efcc
verified:
  - mix test test/rindle/workers/process_variant_test.exs test/rindle/api_surface_boundary_test.exs
files_modified:
  - lib/rindle.ex
  - lib/rindle/workers/process_variant.ex
  - test/rindle/workers/process_variant_test.exs
  - test/rindle/api_surface_boundary_test.exs
  - .planning/phases/27-html-helpers-liveview-integration/27-03-SUMMARY.md
---

# Phase 27 Plan 03 Summary

Completed the asset-scoped cancellation path behind `Rindle.cancel_processing/1`.

## What Changed

- Kept `Rindle.cancel_processing/1` as the only public cancellation entrypoint and preserved the locked `:ok | {:error, :not_processing}` return contract.
- Completed the worker-side cancellation flow so asset-scoped cancellation now cancels matching `Oban` `ProcessVariant` jobs, transitions queued or processing variants to `cancelled`, recomputes the asset aggregate state, and emits public `:variant_cancelled` events on the existing variant and asset topics.
- Added regression coverage for both queued-job and executing-job cancellation paths, including job-row state, variant persistence, aggregate asset state, and public PubSub broadcasts.

## Verification

- `mix test test/rindle/workers/process_variant_test.exs test/rindle/api_surface_boundary_test.exs`

## Deviations

None. The remaining gap from the initial `27-03` facade commit was closed in this plan.
