---
phase: 24-domain-model-dsl-extension
plan: 02
subsystem: database
tags: [ecto, postgres, migration, schema, av, media]
requires:
  - phase: 24-01
    provides: base phase-24 domain model and DSL context
provides:
  - additive AV migration for media assets and variants
  - schema-layer kind and output_kind validation
  - typed probe-column consistency checks for media assets
affects: [24-03, 24-05, av-processor, delivery]
tech-stack:
  added: []
  patterns: [additive ecto migration, schema-layer string enums, per-kind changeset invariants, single-file domain schema tests]
key-files:
  created:
    - priv/repo/migrations/20260502120000_extend_media_for_av.exs
    - test/rindle/domain/migration_test.exs
  modified:
    - lib/rindle/domain/media_asset.ex
    - lib/rindle/domain/media_variant.ex
    - test/rindle/domain/media_schema_test.exs
key-decisions:
  - "Kept media_assets.kind restricted to image/video/audio while media_variants.output_kind allows waveform as an output-only kind."
  - "Used additive nullable typed probe columns with default image discriminators so existing rows remain valid without backfill."
  - "Added schema-layer state support for transcoding and cancelled ahead of Plan 03 FSM work."
patterns-established:
  - "Migration additions for AV stay additive and index queryable discriminator columns."
  - "MediaAsset enforces kind/field coherence in the changeset rather than JSON metadata."
requirements-completed: [AV-02-01, AV-02-02]
duration: 5min
completed: 2026-05-05
---

# Phase 24 Plan 02: Domain Model AV Migration Summary

**Additive AV schema support with typed probe columns, image/video/audio asset kinds, and waveform-capable variant output kinds**

## Performance

- **Duration:** 5 min
- **Started:** 2026-05-05T15:30:00Z
- **Completed:** 2026-05-05T15:34:40Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments

- Added migration `20260502120000_extend_media_for_av.exs` with `kind`, `output_kind`, typed AV probe columns, and discriminator indexes.
- Extended `MediaAsset` with `@kinds ~w(image video audio)`, typed fields, `error_reason`, `transcoding`, and D-11 per-kind field consistency validation.
- Extended `MediaVariant` with `@output_kinds ~w(image video audio waveform)`, typed fields, and `cancelled`, while keeping all domain schema tests green.

## Task Commits

1. **Task 1: Author the additive Ecto migration `extend_media_for_av`** - `bf41e54` (`test`), `e49852f` (`feat`)
2. **Task 2: Extend `Rindle.Domain.MediaAsset` schema + changeset** - `5a04a93` (`test`), `8448055` (`feat`)
3. **Task 3: Extend `Rindle.Domain.MediaVariant` schema + changeset** - `18186f2` (`test`), `a06d779` (`feat`)

## Files Created/Modified

- `priv/repo/migrations/20260502120000_extend_media_for_av.exs` - additive AV migration with defaults and indexes
- `test/rindle/domain/migration_test.exs` - migration smoke tests for added columns, defaults, and index presence
- `lib/rindle/domain/media_asset.ex` - asset kinds, typed probe fields, `transcoding`, and per-kind invariant enforcement
- `lib/rindle/domain/media_variant.ex` - output kinds, typed output fields, and `cancelled`
- `test/rindle/domain/media_schema_test.exs` - Phase 24 asset/variant schema validation coverage in the existing single-file layout

## Decisions Made

- `@kinds` remains exactly three values: `image`, `video`, `audio`. `waveform` is output-only and lives only in `@output_kinds`.
- `duration_ms` stays `:bigint` at the database layer and `:integer` in Ecto schema fields.
- The schema state lists now include `transcoding` and `cancelled` so Plan 03 FSM transitions can land without schema rejection.

## Verification

- `mix ecto.reset`
- `mix test test/rindle/domain/ --warnings-as-errors`
- `mix compile --warnings-as-errors`
- `psql -d rindle_dev -c '\\d media_assets'`
- `psql -d rindle_dev -c '\\d media_variants'`

All verification passed. `media_assets` now exposes `kind`, `width`, `height`, `duration_ms`, `has_video_track`, `has_audio_track`, and `error_reason`. `media_variants` now exposes `output_kind`, `duration_ms`, `width`, and `height`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Resolved contradictory migration acceptance text**
- **Found during:** Task 1
- **Issue:** The required migration body text included the literal string `disable_ddl_transaction` in the moduledoc, but Task 1 acceptance required `grep -c "disable_ddl_transaction"` to return `0`.
- **Fix:** Reworded the moduledoc sentence to preserve the intent while removing the conflicting literal string.
- **Files modified:** `priv/repo/migrations/20260502120000_extend_media_for_av.exs`
- **Verification:** `grep -c 'disable_ddl_transaction' priv/repo/migrations/20260502120000_extend_media_for_av.exs` returned `0`; migration and tests still passed.
- **Committed in:** `e49852f`

---

**Total deviations:** 1 auto-fixed (`Rule 1`)
**Impact on plan:** No scope change. The adjustment was required to satisfy the plan's own acceptance gate.

## Issues Encountered

- `DATABASE_URL` was unset for the shell, so the plan's literal `psql "$DATABASE_URL"` verification could not target the migrated database. Verification used the repo's configured local development database (`rindle_dev`) instead, which is what `mix ecto.reset` had just migrated.
- A build-directory lock briefly blocked the combined `mix compile --warnings-as-errors` run after tests. Re-running compile separately succeeded with no warnings.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 03 can add FSM transitions against schema states that now recognize `transcoding` and `cancelled`.
- Plan 05 can persist probe output into typed columns and quarantine failures through `error_reason`.

## Self-Check: PASSED

- Verified summary file exists on disk.
- Verified task commits `bf41e54`, `e49852f`, `5a04a93`, `8448055`, `18186f2`, and `a06d779` exist in git history.
