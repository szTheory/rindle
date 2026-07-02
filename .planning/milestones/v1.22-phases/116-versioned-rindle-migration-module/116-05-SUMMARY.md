---
phase: 116-versioned-rindle-migration-module
plan: 05
subsystem: runtime
tags: [doctor, runtime-status, migrations, oban, postgres]

requires:
  - phase: 116-02
    provides: "RED contracts for hybrid doctor/runtime setup readiness"
  - phase: 116-04
    provides: "Rindle.Migration.V1 helper metadata and marker/catalog substrate"
provides:
  - "Hybrid doctor readiness for fresh Rindle.Migration installs and legacy packaged installs"
  - "Host-owned oban_jobs doctor readiness check and setup copy"
  - "Runtime status setup preflight returning setup_incomplete errors before report queries"
affects:
  - "Phase 116 docs/generated-app proof"
  - "mix rindle.doctor"
  - "mix rindle.runtime_status"

tech-stack:
  added: []
  patterns:
    - "Use Rindle.Migration.V1 catalog metadata for doctor/runtime setup readiness"
    - "Keep setup-readiness fixtures injectable while production probes information_schema"
    - "Render host-owned Oban setup failures as bounded operator copy"

key-files:
  created:
    - .planning/phases/116-versioned-rindle-migration-module/116-05-SUMMARY.md
    - .planning/phases/116-versioned-rindle-migration-module/deferred-items.md
  modified:
    - lib/rindle/ops/runtime_checks.ex
    - lib/rindle/ops/runtime_status.ex
    - lib/mix/tasks/rindle.runtime_status.ex

key-decisions:
  - "Doctor readiness now treats Rindle-owned schema readiness and host-owned Oban readiness as separate checks."
  - "Runtime status fails fast with setup_incomplete before any lifecycle report query touches missing tables."
  - "The existing doctor CLI renderer was sufficient for new warning/error rows; only runtime_status needed new setup-copy formatting."

patterns-established:
  - "Doctor catalog probes use Rindle.Migration.V1.catalog_requirements/0, rindle_tables/0, and marker_table/0."
  - "Runtime status setup preflight keeps a test fixture seam at config :rindle, Rindle.Ops.RuntimeStatus, setup_readiness: ..."

requirements-completed: [MIGRATE-01, MIGRATE-02]

duration: 11 min
completed: 2026-07-01
status: complete
---

# Phase 116 Plan 05: Hybrid Doctor and Runtime Status Summary

**Doctor and runtime status now distinguish Rindle-owned schema readiness from host-owned Oban setup and fail with bounded setup guidance.**

## Performance

- **Duration:** 11 min
- **Started:** 2026-07-01T20:20:24Z
- **Completed:** 2026-07-01T20:31:19Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added `doctor.rindle_schema.ready` using `Rindle.Migration.V1` marker/table metadata and prefix-aware `information_schema` checks.
- Added `doctor.oban_jobs.ready` so `oban_jobs` is treated as host-owned setup installed through `Oban.Migration`.
- Preserved `doctor.migrations.pending` and `doctor.migrations.unresolved`, downgrading catalog-proven healthy legacy drift to warning/history-only copy.
- Added runtime-status setup preflight returning `{:error, {:setup_incomplete, :rindle_schema}}` or `{:error, {:setup_incomplete, :oban_jobs}}` before report queries run.
- Updated `mix rindle.runtime_status` failure copy to name `mix rindle.doctor`, `Oban.Migration`, and Rindle's non-ownership of `oban_jobs`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement hybrid doctor migration health** - `c29247d` (feat)
2. **Task 2: Implement runtime-status setup preflight** - `527f713` (feat)

## Files Created/Modified

- `lib/rindle/ops/runtime_checks.ex` - Adds Rindle schema and host-owned Oban readiness checks, prefix-aware catalog probes, and legacy drift warning semantics.
- `lib/rindle/ops/runtime_status.ex` - Adds setup preflight before runtime report queries and uses V1 catalog metadata for Rindle table readiness.
- `lib/mix/tasks/rindle.runtime_status.ex` - Renders setup-incomplete repair guidance with host-owned Oban copy.
- `.planning/phases/116-versioned-rindle-migration-module/deferred-items.md` - Records the docs parity verifier failures owned by 116-06.

## Decisions Made

- Kept doctor output ordering stable by relying on the existing `Enum.sort_by(& &1.id)` check ordering and adding only the new locked IDs.
- Used the existing generic doctor CLI renderer for warning/error rows; no doctor task change was needed.
- Preserved old hard-failure behavior for unresolved migration file history unless a catalog fixture explicitly proves the healthy legacy drift path under test.

## Verification

- `mix test test/rindle/ops/runtime_checks_test.exs test/rindle/doctor_test.exs --seed 0` - PASS, 45 tests.
- `mix test test/rindle/ops/runtime_status_test.exs test/rindle/runtime_status_task_test.exs --seed 0` - PASS, 31 tests.
- `mix test test/rindle/migration_test.exs test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_status_test.exs test/rindle/doctor_test.exs test/rindle/runtime_status_task_test.exs --seed 0` - PASS, 81 tests.
- Full plan combined command including `test/install_smoke/docs_parity_test.exs` - FAILS with 2 docs parity failures: README still lacks the pinned `Rindle.Migration.up(version: 1)` docs and still includes the raw package-directory greenfield flow. This is outside 116-05 file scope and explicitly owned by 116-06.
- Source assertions - PASS: `RuntimeChecks` references `MigrationV1.catalog_requirements/0`, `MigrationV1.rindle_tables/0`, and `MigrationV1.marker_table/0`; catalog probes default to `"public"` and use `table_schema = $1`; runtime-status code only reads `oban_jobs`.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Non-DataCase doctor tests run with `Rindle.Repo` in SQL Sandbox manual mode. The new catalog probes now check out the sandbox only when the configured repo pool is `Ecto.Adapters.SQL.Sandbox`; production paths still query the already-started repo or use `Ecto.Migrator.with_repo/3` when needed.
- The plan-level combined verifier includes docs parity tests that are intentionally red until 116-06 updates README and guides. This is documented in `deferred-items.md`; doctor/runtime RED contracts from 116-02 are green.

## Authentication Gates

None.

## Known Stubs

None. Stub-pattern scan found no placeholder/TODO/FIXME or hardcoded empty UI data in files created or modified by this plan; matches were normal empty-list conditionals in existing runtime code.

## User Setup Required

None - no external service configuration required.

## Threat Flags

None beyond the planned threat model. This plan added expected Postgres catalog reads at the doctor/runtime trust boundary and kept `oban_jobs` read-only.

## Deferred Issues

- Docs parity remains red for README migration copy until 116-06 updates public install/upgrade documentation. The exact failing command and rationale are recorded in `deferred-items.md`.

## Next Phase Readiness

Plan 116-06 can now update README, getting-started, upgrading, operations, and troubleshooting docs against green doctor/runtime compatibility. The remaining red verifier surface is docs-only and already mapped to 116-06.

## Self-Check: PASSED

- FOUND: `lib/rindle/ops/runtime_checks.ex`
- FOUND: `lib/rindle/ops/runtime_status.ex`
- FOUND: `lib/mix/tasks/rindle.runtime_status.ex`
- FOUND: `.planning/phases/116-versioned-rindle-migration-module/deferred-items.md`
- FOUND: commit `c29247d`
- FOUND: commit `527f713`

---
*Phase: 116-versioned-rindle-migration-module*
*Completed: 2026-07-01*
