---
phase: 118-isolated-migration-safe-upgrade
plan: "02"
subsystem: database
tags: [elixir, ecto, postgresql, migrations, schema-isolation]
requires:
  - phase: 118-01
    provides: "Provisioned rindle schema and fixed V1 ownership authority"
provides:
  - "Pinned public-to-rindle migration API with no generic schema mover"
  - "Read-only catalog and privilege preflight for the fixed seven-relation move"
  - "Transactional ALTER TABLE relocation that preserves populated relational state"
affects: [118-03-refusal-and-reverse-safety, upgrade-documentation, generated-app-proof]
tech-stack:
  added: []
  patterns:
    - "Preflight all fixed relation, marker, ownership, and privilege state before queued DDL"
    - "Use V1's allowlisted identifiers for ordered ALTER TABLE SET SCHEMA operations"
key-files:
  created: []
  modified:
    - lib/rindle/migration.ex
    - lib/rindle/migration/v1.ex
    - test/rindle/migration_fast_test.exs
    - test/rindle/migration_test.exs
    - test/rindle/api_surface_boundary_test.exs
key-decisions:
  - "Approved D-118-06: use the fixed, transactional public-to-rindle ALTER TABLE move after complete preflight."
  - "The directional public wrapper accepts only version: 1 and exposes no prefix/source/target configuration."
metrics:
  duration: "~31 min"
  tasks_completed: 2
  files_modified: 5
completed: 2026-08-09
status: complete
---

# Phase 118 Plan 02: Guarded Public-to-Rindle Move Summary

**A host migration can now call the one-way, version-pinned `move_public_to_rindle(version: 1)` helper to preflight and transactionally relocate exactly Rindle's seven owned relations.**

## Accomplishments

- Added the documented, directional public move API and rejected empty, generic, prefix, source, and target options.
- Added a fixed V1 catalog classifier for absent/empty destinations, complete source/destination state, markers, ownership, and required creation/usability privileges.
- Used the approved `ALTER TABLE ... SET SCHEMA` operation after complete classification, provisioning an absent `rindle` schema before the ordered seven-relation loop.
- Added live PostgreSQL proof for populated assets, attachments, variants, marker state, indexes, foreign-key enforcement, and host relation stability.

## Task Commits

1. **Task 1 RED: Classify legacy state before exposing the forward move** — `efcd34d` (test)
2. **Task 1 GREEN: Classify legacy state before exposing the forward move** — `d62c9fd` (feat)
3. **Task 2 RED: Move the populated fixed relation set and prove integrity** — `3b76b05` (test)
4. **Task 2 GREEN: Move the populated fixed relation set and prove integrity** — `8022575` (feat)

## Decisions Made

- The maintainer selected `proceed-fixed-move`: run a transactional fixed `ALTER TABLE ... SET SCHEMA` move only after complete preflight.
- `Rindle.Migration.V1.owned_relations/0` remains the exclusive authority for the six Rindle tables and migration marker; `oban_jobs` and `schema_migrations` are never candidates for mutation.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test fixture] Bound UUID fixture parameters as PostgreSQL UUID binaries**
- **Found during:** Task 2 RED
- **Issue:** Raw Postgrex parameters need UUID binaries; passing string UUIDs prevented the populated fixture from reaching the intended RED assertion.
- **Fix:** Converted fixture and FK-probe UUID parameters through `Ecto.UUID.dump!/1`, while comparing result values as text.
- **Files modified:** `test/rindle/migration_test.exs`
- **Verification:** Live migration test passed.

**2. [Rule 1 - Catalog safety] Avoided querying privileges for an absent target schema**
- **Found during:** Task 1 GREEN
- **Issue:** PostgreSQL rejects `has_schema_privilege` for a non-existent `rindle` schema, which would make the provisionable-destination preflight fail before classification.
- **Fix:** Derive target existence from the bound namespace snapshot and query target privileges only when it exists.
- **Files modified:** `lib/rindle/migration/v1.ex`
- **Verification:** Complete public/absent-rindle preflight and populated move tests passed.

**Total deviations:** 2 auto-fixed (Rule 1). **Impact:** Both corrections make the required absent-target and populated-data proofs executable without widening the migration surface.

## Verification

- `mix format --check-formatted lib/rindle/migration.ex lib/rindle/migration/v1.ex test/rindle/migration_fast_test.exs test/rindle/migration_test.exs test/rindle/api_surface_boundary_test.exs` — PASS
- `mix test test/rindle/migration_fast_test.exs --seed 0` — PASS (4 tests)
- `mix test test/rindle/migration_test.exs --seed 0` — PASS (9 tests)
- `mix test test/rindle/api_surface_boundary_test.exs test/rindle/schema_prefix_contract_test.exs --seed 0` — PASS (22 tests)

## Self-Check: PASSED

- Verified all five modified migration and test artifacts exist.
- Verified task commits `efcd34d`, `d62c9fd`, `3b76b05`, and `8022575` exist in git history.
- No stubs, skipped tests, or unrun planned verification remain.

---
*Phase: 118-isolated-migration-safe-upgrade*
*Completed: 2026-08-09*
