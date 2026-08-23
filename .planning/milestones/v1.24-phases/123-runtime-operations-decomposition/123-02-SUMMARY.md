---
phase: 123-runtime-operations-decomposition
plan: "02"
subsystem: database migration preflight
tags: [elixir, ecto, postgresql, migration, preflight, rollback]
requires:
  - phase: 123-01
    provides: runtime-diagnostics decomposition and SAFE-01-preserving refactor posture
provides:
  - Read-only V1-provided migration snapshot observation
  - Explicit forward and reverse fixed-catalog preflight classification
  - Preserved V1-owned DDL, ordered moves, transaction behavior, and error vocabulary
affects: [runtime-status decomposition, migration operations, SAFE-01]
tech-stack:
  added: []
  patterns: [V1-owned requirements passed to read-only snapshot, pure directional preflight classifier]
key-files:
  created:
    - lib/rindle/migration/v1/snapshot.ex
    - lib/rindle/migration/v1/preflight.ex
  modified:
    - lib/rindle/migration/v1.ex
    - test/rindle/migration_fast_test.exs
    - test/rindle/migration_test.exs
key-decisions:
  - "V1 remains the sole authority for the fixed catalog, DDL, ordered relation moves, transaction behavior, test failure injection, and bounded errors."
  - "Snapshot receives V1-provided requirements and only observes PostgreSQL state; Preflight classifies one immutable snapshot with explicit forward and reverse precedence."
patterns-established:
  - "Keep migration mutation in the V1 facade and pass fixed requirements into read-only internal observers."
  - "Express safety-critical directional refusal order in pure classifiers while preserving the facade's result vocabulary."
requirements-completed: [OPS-02, SAFE-01]
coverage:
  - id: D1
    description: "Forward populated-install observation and refusal classification retain V1's fixed catalog and mutation boundary."
    requirement: OPS-02
    verification:
      - kind: unit
        ref: "test/rindle/migration_fast_test.exs#classifies the V1-provided fixed catalog before any move authority runs"
        status: pass
      - kind: integration
        ref: "MIX_ENV=test mix test test/rindle/migration_fast_test.exs test/rindle/migration_test.exs --seed 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "Reverse preflight, fixed relation movement, host relation exclusion, rollback, privilege, and lock safety retain their prior behavior."
    requirement: OPS-02
    verification:
      - kind: integration
        ref: "test/rindle/migration_test.exs#Rindle.Migration.move_rindle_to_public/1 preflight"
        status: pass
      - kind: other
        ref: "bash scripts/maintainer/refactor_contract.sh"
        status: pass
    human_judgment: false
  - id: D3
    description: "SAFE-01 confirms the refactor leaves public API, schema, migration, telemetry, error, and release contracts intact."
    requirement: SAFE-01
    verification:
      - kind: other
        ref: "bash scripts/maintainer/refactor_contract.sh"
        status: pass
    human_judgment: false
metrics:
  duration: 14 minutes
  completed: 2026-08-23
  tasks_completed: 2
  files_changed: 5
status: complete
---

# Phase 123 Plan 02: Runtime Operations Decomposition Summary

V1 now delegates one immutable PostgreSQL observation to `Snapshot` and explicit directional refusal ordering to `Preflight`, while retaining the fixed catalog, DDL, relation moves, rollback, and bounded error authority.

## Tasks Completed

1. **Prove observe-classify-refuse on the forward populated move** — `b39a134` (`chore(123-02)`)
   - Extracted V1-fed, read-only snapshot observation and forward pure classification.
   - Kept target provisioning and ordered owned-relation moves behind the unchanged V1 facade.
   - Added a behavior-level fixed-catalog classifier test; it was first run RED (`UndefinedFunctionError`), then GREEN.

2. **Preserve reverse classification, ordered moves, and rollback safety** — `838b2ec` (`chore(123-02)`)
   - Added the explicit reverse branch to the same pure classifier and routed the V1 reverse preflight through it.
   - Added reverse first-refusal coverage; it was first run RED (`FunctionClauseError`), then GREEN.
   - Preserved integration proof for exact owned relation movement, host relation exclusion, rollback, lock guidance, privilege refusal, and safe reverse.

## Verification

- `MIX_ENV=test mix test test/rindle/migration_fast_test.exs --seed 0` — PASS (6 tests) after Task 1.
- `MIX_ENV=test mix test test/rindle/migration_test.exs --seed 0` — PASS (18 tests, 4 `migration_e2e` tests intentionally excluded by the focused default tag set) after Task 2.
- `MIX_ENV=test mix compile --force` — PASS (137 files).
- `MIX_ENV=test mix test test/rindle/migration_fast_test.exs test/rindle/migration_test.exs --seed 0` — PASS (24 tests, 4 excluded).
- `bash scripts/maintainer/refactor_contract.sh` — PASS: forced compile (137 files), no compile-connected cycles, and 87 contract tests passing.

## Decisions Made

- `Rindle.Migration.V1` remains sole owner of `current_version/0`, marker/catalog helpers, DDL, fixed move order, failure injection, transaction effects, and bounded error rendering.
- `Snapshot` carries only V1-provided fixed requirements while observing database state; `Preflight.classify/2` performs no queries or mutations and retains the pre-existing ordered refusal vocabulary for both directions.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- Created internal files `lib/rindle/migration/v1/snapshot.ex` and `lib/rindle/migration/v1/preflight.ex` exist.
- Task commits `b39a134` and `838b2ec` exist in git history.

## Next Phase Readiness

- OPS-02 and SAFE-01 are green; Plan 123-03 may decompose runtime-status collection and presentation without reopening migration behavior.
