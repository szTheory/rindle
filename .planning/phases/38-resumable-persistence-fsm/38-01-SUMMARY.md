---
phase: 38-resumable-persistence-fsm
plan: 01
subsystem: database
tags: [ecto, migrations, doctor, resumable-uploads]
requires: []
provides:
  - Packaged resumable upload-session migration template
  - Schema-only doctor check for resumable session drift
  - Regression coverage for resumable columns and expiry index shape
affects: [phase-39, operator-surfaces, upload-sessions]
tech-stack:
  added: []
  patterns: [packaged-additive-migration, schema-only-doctor-check, explicit-catalog-fixtures]
key-files:
  created: [priv/repo/migrations/20260507160000_extend_media_upload_sessions_for_resumable.exs]
  modified:
    [
      lib/rindle/ops/runtime_checks.ex,
      test/rindle/domain/migration_test.exs,
      test/rindle/ops/runtime_checks_test.exs,
      test/rindle/doctor_test.exs
    ]
key-decisions:
  - "Kept the packaged migration additive and reversible, with plaintext session_uri as the documented default posture."
  - "Made the doctor check schema-only so resumable drift stays visible without introducing GCS runtime noise."
  - "Used explicit test catalog fixtures instead of assuming the repo database has already applied the packaged migration."
patterns-established:
  - "Packaged migration templates ship with catalog-introspection regression tests for adopter-owned tables."
  - "Always-on doctor checks use injected catalog fixtures in tests when future packaged migrations are not applied to the local test database."
requirements-completed: [RESUMABLE-01]
duration: 6 min
completed: 2026-05-07
---

# Phase 38 Plan 01: Resumable migration template and schema-only doctor drift check

**Rindle now ships the resumable upload-session migration template plus a deterministic doctor check that detects missing persistence columns, offset drift, and expiry-index drift.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-05-07T15:59:22-04:00
- **Completed:** 2026-05-07T16:05:31-04:00
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added the packaged `media_upload_sessions` migration for `session_uri`, `session_uri_expires_at`, `last_known_offset`, `region_hint`, and the resumable expiry partial index.
- Added `doctor.resumable_session_schema` as an always-on schema-only runtime check for resumable upload-session drift.
- Added migration, doctor, and CLI regression coverage that validates the new check without depending on the local test database having already applied the packaged future migration.

## Task Commits

1. **Task 1: Add the packaged resumable migration template per D-01..D-05**
   - `eee0458` `test(38-01): add failing resumable migration assertions`
   - `1627ca2` `feat(38-01): add resumable upload session migration`
2. **Task 2: Add schema-only doctor drift detection for resumable upload sessions per D-24..D-27**
   - `8ffa6d0` `test(38-01): add failing resumable doctor checks`
   - `dc81d13` `feat(38-01): add resumable session schema doctor check`
   - `ed39688` `fix(38-01): stabilize resumable doctor verification`

## Files Created/Modified

- `priv/repo/migrations/20260507160000_extend_media_upload_sessions_for_resumable.exs` - Packaged additive migration template for resumable session persistence.
- `lib/rindle/ops/runtime_checks.ex` - Added `doctor.resumable_session_schema` catalog introspection and drift reporting.
- `test/rindle/domain/migration_test.exs` - Added catalog assertions for resumable columns, defaults, and expiry-index shape.
- `test/rindle/ops/runtime_checks_test.exs` - Added stable-order, success, and drift coverage for the new doctor row.
- `test/rindle/doctor_test.exs` - Kept doctor CLI output coverage deterministic with explicit resumable schema fixtures.

## Decisions Made

- Preserved additive migration posture instead of inventing new DB constraints for `upload_strategy`.
- Queried only `information_schema.columns` and `pg_indexes` so the new doctor check remains schema-only.
- Normalized doctor tests around explicit catalog fixtures instead of making runtime code infer success from test-only migration options.

## Verification

- `mix test test/rindle/domain/migration_test.exs test/rindle/ops/runtime_checks_test.exs test/rindle/doctor_test.exs` -> PASS
- Task 1 acceptance greps for all four columns, partial-index predicate, index name, and plaintext-at-rest warning comment -> PASS
- Task 2 acceptance greps for `doctor.resumable_session_schema`, `check_resumable_session_schema`, `session_uri_expires_at`, `last_known_offset`, and `upload_strategy = 'resumable'` -> PASS

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Replaced test assumptions that depended on the local repo database already having applied the packaged Phase 38 migration**
- **Found during:** Task 2 verification
- **Issue:** The new always-on doctor check caused unrelated runtime and CLI tests to fail because they stubbed migration status but still queried the current repo catalog, which does not yet contain the packaged resumable columns.
- **Fix:** Added explicit resumable schema catalog fixtures to doctor/runtime tests and kept production runtime introspection honest.
- **Files modified:** `test/rindle/ops/runtime_checks_test.exs`, `test/rindle/doctor_test.exs`, `lib/rindle/ops/runtime_checks.ex`
- **Verification:** `mix test test/rindle/domain/migration_test.exs test/rindle/ops/runtime_checks_test.exs test/rindle/doctor_test.exs`
- **Committed in:** `ed39688`

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** No scope change. The doctor check still validates the real schema contract; the deviation only stabilized the test harness around that contract.

## Issues Encountered

- The worktree already contained unrelated `.planning/` edits for the active milestone. They were left untouched.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 39 can rely on durable resumable session columns and a doctor check that flags missing schema before runtime behavior is layered on.
- No broker, adapter, status-probe, or cancel semantics were introduced here; those remain correctly deferred.

## Self-Check

PASSED

- Confirmed `.planning/phases/38-resumable-persistence-fsm/38-01-SUMMARY.md` exists.
- Confirmed task commits `eee0458`, `1627ca2`, `8ffa6d0`, `dc81d13`, and `ed39688` exist in git history.

---
*Phase: 38-resumable-persistence-fsm*
*Completed: 2026-05-07*
