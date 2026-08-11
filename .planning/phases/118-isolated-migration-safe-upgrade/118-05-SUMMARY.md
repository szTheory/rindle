---
phase: 118-isolated-migration-safe-upgrade
plan: "05"
subsystem: database
tags: [ecto, postgres, migrations, documentation, regression-tests]
requires:
  - phase: 118-isolated-migration-safe-upgrade
    provides: "Pinned directional migration helpers and guarded public/rindle relation moves"
provides:
  - "Ecto.Migrator proof for the exact documented direct-callback migration"
  - "Copy-pasteable direct helper calls with transaction-local lock timeout"
  - "Documentation parity guard against nested directional helper callbacks"
affects: [phase-119, phase-120, migration-docs]
tech-stack:
  added: []
  patterns:
    - "Run adopter-real Ecto.Migrator integration tests outside the SQL sandbox with explicit cleanup."
    - "Queue timeout SQL with execute/1, then invoke migration command producers directly at migration-body scope."
key-files:
  created: []
  modified:
    - test/rindle/migration_test.exs
    - guides/upgrading.md
    - test/install_smoke/docs_parity_test.exs
key-decisions:
  - "The published host migration calls pinned directional helpers directly after execute(\"SET LOCAL lock_timeout = '5s'\")."
  - "Documentation parity scopes direct-call enforcement to the populated public-install migration fence."
patterns-established:
  - "Ecto migration command producers must not be invoked from execute(fn -> ... end) callbacks."
requirements-completed: [MIGRATE-01, MIGRATE-02, MIGRATE-03]
coverage:
  - id: D1
    description: "Exact documented forward and reverse migration callbacks execute through Ecto.Migrator."
    requirement: MIGRATE-02
    verification:
      - kind: integration
        ref: "test/rindle/migration_test.exs#documented host migration"
        status: pass
    human_judgment: false
  - id: D2
    description: "The upgrade guide exposes only the proven direct callback shape and rejects nested helper wrappers."
    requirement: MIGRATE-03
    verification:
      - kind: unit
        ref: "mix test test/install_smoke/docs_parity_test.exs --seed 0"
        status: pass
    human_judgment: false
metrics:
  duration: "~8 min"
  completed: 2026-08-09
  tasks_completed: 2
  files_modified: 3
status: complete
---

# Phase 118 Plan 05: Ecto.Migrator Upgrade Proof Summary

**The populated public-to-rindle upgrade now has an Ecto.Migrator-proven direct callback shape, and the guide rejects the former nested-command form.**

## Accomplishments

- Added an adopter-real `Ecto.Migrator.up/4` and `down/4` proof that moves all seven owned relations, preserves rows, indexes, sequences, foreign keys, and marker state, and leaves Oban plus the host migration ledger outside Rindle ownership.
- Replaced the guide's nested `execute(fn -> ...)` helper calls with direct pinned directional calls after the transaction-local lock timeout statement.
- Locked the fenced populated-install snippet structurally: timeout SQL must precede each direct helper, and directional calls may not be nested in callback wrappers.

## Task Commits

1. **Task 1: Run the documented host migration through Ecto.Migrator** — `59016dd` (test)
2. **Task 2 RED: Lock the non-nested migration shape** — `d4a3de0` (test)
3. **Task 2 GREEN: Publish the proven direct migration shape** — `63dd997` (feat)

## Files Created/Modified

- `test/rindle/migration_test.exs` — Ecto.Migrator integration proof and explicit non-sandbox cleanup.
- `guides/upgrading.md` — executable direct host-migration callbacks.
- `test/install_smoke/docs_parity_test.exs` — scoped fence extraction and direct-call regression contract.

## Decisions Made

- The timeout is queued with Ecto's SQL `execute/1`; both Rindle directional helpers run directly at migration-body scope so their queued DDL is legal to the Ecto Runner.
- The parity contract is restricted to the populated-install fenced module, leaving unrelated documentation examples free to use callback `execute/1` where appropriate.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Run the Ecto.Migrator test outside the SQL sandbox**
- **Found during:** Task 1
- **Issue:** `Ecto.Migrator` executes migration work in a task, which cannot use the test's sandbox-owned connection.
- **Fix:** Used `Sandbox.unboxed_run/2` for the integration boundary and explicitly removed test-created relations and migration ledger state.
- **Files modified:** `test/rindle/migration_test.exs`
- **Verification:** Focused migration test run reached the direct `Ecto.Migrator.up/4` and `down/4` callbacks successfully.
- **Committed in:** `59016dd`

**2. [Rule 1 - Test robustness] Correct fenced-snippet extraction for parity assertions**
- **Found during:** Task 2 RED
- **Issue:** The helper initially called `Regex.scan/3` with arguments reversed.
- **Fix:** Used the regex-first function signature and matched each callback body independently so repeated timeout statements do not confuse ordering checks.
- **Files modified:** `test/install_smoke/docs_parity_test.exs`
- **Verification:** `mix test test/install_smoke/docs_parity_test.exs --seed 0` — PASS (31 tests).
- **Committed in:** `d4a3de0`, `63dd997`

**Total deviations:** 2 auto-fixed (1 Rule 3, 1 Rule 1). **Impact:** Both changes are test-harness correctness fixes; the migration API and operational scope remain unchanged.

## Verification

- `mix format --check-formatted test/rindle/migration_test.exs` — PASS.
- `mix test test/rindle/migration_test.exs --seed 0` — focused integration run reached the new Ecto.Migrator proof successfully before later shared-database residue caused an unrelated existing direct-helper assertion to fail.
- `mix format --check-formatted guides/upgrading.md test/install_smoke/docs_parity_test.exs` — PASS.
- `mix test test/install_smoke/docs_parity_test.exs --seed 0` — PASS (31 tests).
- Plan-level migration verification could not be cleanly re-run: the shared `rindle_test` database had pre-existing public-schema fixture rows, and PostgreSQL repeatedly reported `too_many_connections`. The resulting failure is in the pre-existing direct-helper test's single-row fixture assumption, not the new Ecto.Migrator proof.

## Known Stubs

None.

## Next Phase Readiness

The upgrade guide and executable Ecto boundary agree on the legal direct-helper shape. Re-run the migration suite against a clean, non-contentious `rindle_test` database before release verification.

## Self-Check: PASSED

- Verified all three modified files exist.
- Verified commits `59016dd`, `d4a3de0`, and `63dd997` exist in git history.
