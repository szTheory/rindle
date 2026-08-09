---
phase: 117-prefix-routing-architecture
plan: 04
subsystem: database
tags: [ecto, schema-prefix, compile-time, macro, regression-tests]
requires:
  - phase: 117-03
    provides: Compile-time prefix authority and final Ecto metadata validation
provides:
  - Declaration-time Ecto schema prefix reassertion for Rindle.Schema consumers
  - Callback-removal regressions for explicit public and default rindle builds
  - Raw-Ecto declaration guardrails for owned domain schemas
affects: [118-schema-provisioning, 119-runtime-boundaries, 120-release-proof]
tech-stack:
  added: []
  patterns: [authoritative schema declaration wrapper, compile-time prefix routing]
key-files:
  created: []
  modified:
    - lib/rindle/schema.ex
    - test/rindle/schema_prefix_contract_test.exs
key-decisions:
  - "Rindle.Schema.schema/2 reassigns the compiled authority immediately before Ecto generates schema and struct metadata."
  - "The after-compile validation remains defense in depth for explicit raw Ecto.Schema.schema/2 use, while ordinary declarations use the wrapper."
patterns-established:
  - "Use a narrow macro wrapper when Ecto metadata must be reasserted at the declaration boundary."
requirements-completed: [PREFIX-01, PREFIX-02, PREFIX-03]
coverage:
  - id: D1
    description: "Callback-removal consumers still produce authoritative schema and new-struct metadata in the explicit public build."
    requirement: PREFIX-02
    verification:
      - kind: unit
        ref: test/rindle/schema_prefix_contract_test.exs#schema-declaration-restores-the-authority-after-callback-removal-and-prefix-mutation
        status: pass
    human_judgment: false
  - id: D2
    description: "The default rindle build resists the same callback-removal plus public-prefix mutation."
    requirement: PREFIX-01
    verification:
      - kind: other
        ref: MIX_ENV=dev mix compile --force plus callback-removal default probe
        status: pass
    human_judgment: false
  - id: D3
    description: "Facade, Multi, worker, loaded-struct, and new-struct routing retain the selected schema while the decoy remains untouched."
    requirement: PREFIX-03
    verification:
      - kind: integration
        ref: test/rindle/schema_prefix_integration_test.exs
        status: pass
    human_judgment: false
duration: 3min
completed: 2026-08-09
status: complete
---

# Phase 117 Plan 04: Callback-Resistant Schema Authority Summary

**Rindle-owned schemas now route ordinary declarations through a compile-time wrapper that restores authoritative prefix metadata even after a consumer removes finalization.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-08-09T02:48:40Z
- **Completed:** 2026-08-09T02:51:14Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Added `Rindle.Schema.schema/2` as the unqualified declaration boundary after preserving Ecto's supported schema setup and DSL imports.
- Reasserted the compiled `rindle` or `public` authority immediately before Ecto generates schema and new-struct metadata.
- Stored callback-removal regression coverage, retained direct raw-Ecto finalization validation, and strengthened the six-owned-schema structural contract.

## Verification

- `mix format --check-formatted lib/rindle/schema.ex test/rindle/schema_prefix_contract_test.exs` — PASS
- `mix test test/rindle/schema_prefix_contract_test.exs test/rindle/domain/media_schema_test.exs --seed 0` — PASS (27 tests)
- `mix test test/rindle/config/config_test.exs test/rindle/domain/media_schema_test.exs test/rindle/schema_prefix_contract_test.exs test/rindle/schema_prefix_integration_test.exs --seed 0` — PASS (36 tests)
- `MIX_ENV=dev mix compile --force` plus the exact callback-removal default-build probe — PASS
- `mix coveralls.multiple --type local --type json --slowest 20` — PASS (1,262 tests, 0 failures, 4 skipped, 77 excluded; 81.6% coverage)

## Task Commits

1. **Task 1: Make schema declaration reassert the compiled routing authority** — `19d8967` (RED regression), `7cc55bf` (GREEN implementation)
2. **Task 2: Prove callback-removal resistance in both release builds and retain every normal route** — `d45f4b9` (test)

## Files Created/Modified

- `lib/rindle/schema.ex` — imports the Rindle declaration wrapper while excluding raw unqualified Ecto `schema/2`, then delegates after restoring the compiled prefix.
- `test/rindle/schema_prefix_contract_test.exs` — covers callback deletion, both schema metadata surfaces, raw-Ecto finalization, and direct declaration ownership checks.

## Decisions Made

- `schema/2` is the sole normal declaration authority; selection stays compile-time and does not introduce runtime, Repo-wide, migration, or Oban routing semantics.
- Finalization remains a defense-in-depth check for deliberate remote Ecto declaration calls rather than the mutable primary control.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Reconciled the stale Phase 117 plan counter**
- **Found during:** Plan close-out
- **Issue:** `STATE.md` reported Plan 1 of 4 although three prior Phase 117 summaries existed, so the first state advance only reached Plan 2.
- **Fix:** Advanced the state handler through the remaining on-disk plan count until it entered the expected `ready_for_verification` state at Plan 4 of 4.
- **Files modified:** `.planning/STATE.md`
- **Verification:** State now reports 4/4 completed plans and `Phase complete — ready for verification`.

---

**Total deviations:** 1 auto-fixed (1 blocking metadata reconciliation).
**Impact on plan:** No production scope changed; the state now reflects the four completed on-disk summaries.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 118 can provision the `rindle` schema with both release build postures protected from the verified callback-removal bypass. No migration, Repo, Oban, documentation, workflow, dependency, release, or product-scope files changed.

## Self-Check: PASSED

- Confirmed both declared implementation/test files and this summary exist.
- Confirmed task commits `19d8967`, `7cc55bf`, and `d45f4b9` exist.
- Confirmed the task commit range changes only `lib/rindle/schema.ex` and `test/rindle/schema_prefix_contract_test.exs`.
