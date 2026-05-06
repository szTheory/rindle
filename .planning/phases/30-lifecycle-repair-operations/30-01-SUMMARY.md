---
phase: 30-lifecycle-repair-operations
plan: 01
subsystem: lifecycle-repair
tags: [repair, reprobe, public-api, probe, av]
requires: []
provides:
  - Public asset-scoped `Rindle.reprobe/1` facade entrypoint
  - Hidden `Rindle.Ops.LifecycleRepair.reprobe_asset/1` service that reuses the promote/probe seam
  - Probe-only persistence with explicit stale-field clearing and no unrelated lifecycle mutation
affects: [public-api, probe-persistence, lifecycle-repair, compiled-docs-boundary]
tech-stack:
  added: []
  patterns: [facade-over-hidden-ops, shared probe seam, probe-field allowlist persistence]
key-files:
  created:
    [
      lib/rindle/ops/lifecycle_repair.ex,
      test/rindle/ops/lifecycle_repair_test.exs,
      .planning/phases/30-lifecycle-repair-operations/30-01-SUMMARY.md
    ]
  modified:
    [
      lib/rindle.ex,
      lib/rindle/workers/promote_asset.ex,
      test/rindle/api_surface_boundary_test.exs,
      test/rindle/workers/promote_asset_test.exs
    ]
key-decisions:
  - "Reprobe reuses `Rindle.Workers.PromoteAsset` probe/download/normalize logic instead of introducing a second probe implementation."
  - "The repair lane persists only `content_type`, `kind`, `width`, `height`, `duration_ms`, `has_video_track`, `has_audio_track`, and `updated_at`."
  - "Missing probe-derived fields are cleared explicitly so stale AV/image values cannot survive a successful reprobe."
patterns-established:
  - "Hidden worker seams may expose narrow helper functions when a new operator API must share production probe behavior exactly."
  - "Asset-scoped repair APIs return `{:ok, report}` on success and reserve `{:error, reason}` for run-level failures."
requirements-completed: [REPAIR-01, REPAIR-01-01]
completed: 2026-05-06
---

# Phase 30 Plan 01 Summary

## Accomplishments

- Added public `Rindle.reprobe/1` and kept the implementation behind hidden `Rindle.Ops.LifecycleRepair`.
- Extracted a shared probe seam in `Rindle.Workers.PromoteAsset` so promotion and reprobe both use the same download, MIME detect, probe dispatch, and normalization path.
- Restricted reprobe persistence to probe-derived asset fields only, with explicit stale-field clearing and no mutation of asset state, error reason, metadata, profile, storage key, filename, byte size, variants, or upload sessions.
- Extended boundary and worker tests to lock the new public/hidden API split and the stale-field-clearing behavior.

## Verification

- `mix test test/rindle/api_surface_boundary_test.exs test/rindle/ops/lifecycle_repair_test.exs test/rindle/workers/promote_asset_test.exs`
- Result: `26 tests, 0 failures`

## Notes

- The worktree already had unrelated concurrent edits outside this plan. They were preserved.
