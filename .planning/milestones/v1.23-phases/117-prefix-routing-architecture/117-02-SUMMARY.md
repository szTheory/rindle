---
phase: 117-prefix-routing-architecture
plan: 02
subsystem: testing
tags: [ecto, postgres, schema-prefix, integration, contract-tests]
requires:
  - phase: 117-01
    provides: Compile-time Rindle.Schema prefix metadata on all owned schemas
provides:
  - Isolated selected-schema and decoy-schema fixture support
  - Facade, Ecto.Multi, association, loaded-struct, and worker prefix-routing proof
  - Structural guard against bypassing Rindle.Schema in owned domain modules
affects: [118-schema-provisioning, 119-runtime-boundaries, 120-release-proof]
tech-stack:
  added: []
  patterns: [sandbox-owned decoy schema fixtures, AST-enforced shared schema macro boundary]
key-files:
  created:
    - test/support/schema_prefix_case.ex
    - test/rindle/schema_prefix_integration_test.exs
    - test/rindle/schema_prefix_contract_test.exs
  modified: []
key-decisions:
  - "The current public-compatibility test build treats public as selected and rindle as the distinguishable decoy until Phase 118 provisions the default schema."
  - "Prefix-boundary regression protection parses each owned schema source and rejects direct Ecto.Schema or @schema_prefix declarations."
patterns-established:
  - "Use Rindle.SchemaPrefixCase for serial, sandbox-owned tests that need selected and decoy Postgres schemas without search_path mutation."
requirements-completed: [PREFIX-01, PREFIX-02, PREFIX-03]
coverage:
  - id: D1
    description: "Facade Multi writes, association preloads, and worker loaded-struct updates retain the compiled selected prefix while a decoy row stays untouched."
    requirement: PREFIX-03
    verification:
      - kind: integration
        ref: test/rindle/schema_prefix_integration_test.exs
        status: pass
    human_judgment: false
  - id: D2
    description: "All six Rindle-owned schemas remain bound to Rindle.Schema and cannot override its prefix metadata directly."
    requirement: PREFIX-01
    verification:
      - kind: unit
        ref: test/rindle/schema_prefix_contract_test.exs
        status: pass
    human_judgment: false
  - id: D3
    description: "The full local quality coverage gate retains routing and regression proof."
    requirement: PREFIX-02
    verification:
      - kind: integration
        ref: mix coveralls.multiple --type local --type json
        status: pass
    human_judgment: false
duration: 3min
completed: 2026-08-09
status: complete
---

# Phase 117 Plan 02: Prefix Routing Architecture Summary

**Prefix-routing integration and contract tests now prove that real Rindle facade and worker paths honor the shared schema metadata rather than leaking into a like-named decoy schema.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-08-09T01:41:19Z
- **Completed:** 2026-08-09T01:44:11Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- Added serial, sandbox-owned prefix fixtures that seed selected and decoy schemas without global `search_path` changes or test-state leakage.
- Proved real facade `Ecto.Multi` writes, association loading, newly-created attachment records, and `PromoteAsset` loaded-struct writes use the compiled selected prefix.
- Added AST-backed structural tests requiring all six Rindle-owned schemas to use `Rindle.Schema` and rejecting direct `Ecto.Schema` or `@schema_prefix` bypasses.

## Verification

- `mix test test/rindle/schema_prefix_integration_test.exs test/rindle/schema_prefix_contract_test.exs --seed 0` — PASS (4 tests)
- `mix coveralls.multiple --type local --type json` — PASS (1,260 tests, 0 failures, 4 skipped, 77 excluded; 81.6% coverage)

## Task Commits

1. **Task 1: Build isolated PostgreSQL test support** — `834f118` (test)
2. **Task 2: Add facade, Multi, worker, and loaded-struct proof** — `f08e019` (test)
3. **Task 3: Add shared-schema structural contract tests** — `edfa4de` (test)

## Files Created/Modified

- `test/support/schema_prefix_case.ex` — sandbox-owned selected/decoy fixtures and table setup.
- `test/rindle/schema_prefix_integration_test.exs` — end-to-end schema-selection assertions for facade and worker paths.
- `test/rindle/schema_prefix_contract_test.exs` — AST contracts for the six owned schema modules.

## Decisions Made

- The existing Phase 117 test build remains explicitly compiled for `public` compatibility; the harness makes `rindle` the distinguishable decoy until Phase 118 provisions the default schema.
- Structural AST checks enforce the one approved routing model at the source boundary, complementing database integration coverage.

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 1 - Test fixture bug] Encode raw-SQL UUID parameters as PostgreSQL UUID binaries**
- **Found during:** Task 2 (facade, Multi, worker, and loaded-struct proof)
- **Issue:** Postgrex rejected string UUID values passed to the raw decoy-fixture SQL path.
- **Fix:** Used `Ecto.UUID.dump!/1` before binding IDs in the raw fixture insert and lookup queries.
- **Files modified:** `test/support/schema_prefix_case.ex`
- **Verification:** Focused integration and contract tests passed; full coverage suite passed.
- **Committed in:** `f08e019`

---

**Total deviations:** 1 auto-fixed (1 Rule 1). **Impact:** The correction is confined to test fixture encoding and does not expand product routing, migrations, Oban ownership, or schema provisioning scope.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 118 can provision the default `rindle` schema and implement the public-to-`rindle` move. Phase 120 remains responsible for separately compiled packaged-consumer proof of both the fresh default and explicit public compatibility modes.

## Self-Check: PASSED

- `test/support/schema_prefix_case.ex`, `test/rindle/schema_prefix_integration_test.exs`, and `test/rindle/schema_prefix_contract_test.exs` exist.
- Task commits `834f118`, `f08e019`, and `edfa4de` exist.
