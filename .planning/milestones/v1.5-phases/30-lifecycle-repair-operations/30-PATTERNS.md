# Phase 30: Lifecycle Repair Operations - Patterns

**Captured:** 2026-05-05
**Source:** Local codebase pattern pass for lifecycle repair and maintenance seams

## Public Boundary Pattern

- Keep adopter-facing, asset-scoped lifecycle control on `Rindle`.
- Keep `Rindle.Ops.*` hidden from compiled docs and public teaching surfaces.
- Keep batch/global maintenance as Mix-task-first over hidden services.

Evidence:
- `lib/rindle.ex`
- `test/rindle/api_surface_boundary_test.exs`

## Report Contract Pattern

- Maintenance services return `{:ok, report}` for completed runs, even with
  partial per-item failures.
- Reserve `{:error, reason}` for top-level query/setup failures that prevent a
  meaningful report.
- Reports use deterministic counters and accumulate partial failures instead of
  failing fast on the first bad row or storage error.

Evidence:
- `lib/rindle/ops/variant_maintenance.ex`
- `lib/rindle/ops/upload_maintenance.ex`
- `lib/rindle/ops/metadata_backfill.ex`

## Mix Task Wrapper Pattern

- Mix tasks stay thin: parse flags, build service options, call one internal
  service, print deterministic summaries, and exit non-zero only for true
  infrastructure or counted error conditions.
- Human-readable failure lines should be bounded and follow the summary rather
  than replacing structured counters.

Evidence:
- `lib/mix/tasks/rindle.regenerate_variants.ex`
- `lib/mix/tasks/rindle.cleanup_orphans.ex`
- `lib/mix/tasks/rindle.abort_incomplete_uploads.ex`

## Dry-Run Safety Pattern

- Destructive maintenance defaults to dry-run at the service layer.
- Mix tasks and workers mirror the same default and only go live via explicit
  opt-in.
- Preview mode should surface the same counters/operators would use for a live
  run.

Evidence:
- `lib/rindle/ops/upload_maintenance.ex`
- `lib/mix/tasks/rindle.cleanup_orphans.ex`
- `lib/rindle/workers/cleanup_orphans.ex`
- `lib/rindle/ops/sweep_orphaned_temp_files.ex`

## Enqueue-Only Repair Pattern

- Repair/regeneration orchestration should enqueue durable workers instead of
  performing variant processing inline.
- Idempotency should reuse Oban uniqueness and existing worker job builders
  where possible.
- Ready siblings must remain untouched when only failed/cancelled items are
  targeted for repair.

Evidence:
- `lib/rindle/ops/variant_maintenance.ex`
- `lib/rindle/workers/process_variant.ex`
- `lib/rindle/workers/promote_asset.ex`

## Scheduled Parity Pattern

- Scheduled maintenance workers should delegate to the same service contract
  used by on-demand function and Mix-task lanes.
- Worker-specific code should focus on arg normalization, logging, telemetry,
  and adapter lookup rather than owning separate maintenance logic.

Evidence:
- `lib/rindle/workers/abort_incomplete_uploads.ex`
- `lib/rindle/workers/cleanup_orphans.ex`
- `lib/rindle/ops/sweep_orphaned_temp_files.ex`

## Planning Implications

- Public asset-scoped repair APIs can land on `Rindle`, but broad profile-wide
  or catalog-wide repair should remain on `mix rindle.*`.
- Reprobe should reuse existing probe/persist code paths while avoiding
  promotion-state coupling.
- Targeted failed/cancelled repair should be modeled as enqueue-only
  orchestration with explicit report semantics.
- Temp-run-dir sweeping needs explicit on-demand operator entrypoints and dry-run
  parity to match the rest of the maintenance surface.
