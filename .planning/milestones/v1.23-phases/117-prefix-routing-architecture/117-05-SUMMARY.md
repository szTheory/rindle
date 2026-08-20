---
phase: 117-prefix-routing-architecture
plan: "05"
subsystem: database
tags: [elixir, ecto, schema-prefix, compile-time, security-boundary]
requires:
  - phase: 117-04
    provides: "Compile-time prefix authority and wrapper declarations for Rindle schemas"
provides:
  - "Internal-only Rindle.Schema macro gate for the six owned domain schemas"
  - "Combined callback-deletion and raw-Ecto rejection coverage in public and default builds"
affects: [117-prefix-routing-architecture, schema-routing, phase-118]
tech-stack:
  added: []
  patterns:
    - "Validate macro callers before emitting caller-owned Ecto attributes or callbacks"
key-files:
  created: []
  modified:
    - lib/rindle/schema.ex
    - test/rindle/schema_prefix_contract_test.exs
    - test/rindle/config/config_test.exs
key-decisions:
  - "Rindle.Schema is an internal macro boundary, not an adopter schema-extension API."
  - "Only the six Rindle-owned media schema modules may consume Rindle.Schema."
patterns-established:
  - "Boundary macros validate __CALLER__.module before returning quoted consumer setup."
requirements-completed: [PREFIX-01, PREFIX-02, PREFIX-03]
coverage:
  - id: D1
    description: "Non-owned consumers cannot combine callback deletion, opposite-prefix mutation, and raw Ecto schema declarations through Rindle.Schema."
    requirement: PREFIX-01
    verification:
      - kind: unit
        ref: "test/rindle/schema_prefix_contract_test.exs#rejects callback deletion plus raw Ecto declaration from a non-owned consumer"
        status: pass
      - kind: other
        ref: "MIX_ENV=dev mix run --no-start raw-Ecto default-prefix probe"
        status: pass
    human_judgment: false
  - id: D2
    description: "All six owned schemas retain compile-time authority and normal selected-versus-decoy routing."
    requirement: PREFIX-03
    verification:
      - kind: integration
        ref: "test/rindle/schema_prefix_integration_test.exs"
        status: pass
      - kind: other
        ref: "mix coveralls.multiple --type local --type json --slowest 20"
        status: pass
    human_judgment: false
duration: 7min
completed: 2026-08-09
status: complete
---

# Phase 117 Plan 05: Owned Schema Boundary Summary

**Rindle.Schema now admits only six Rindle-owned domain schemas, rejecting the combined raw-Ecto metadata bypass before consumer setup is emitted.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-08-09T03:16:12Z
- **Completed:** 2026-08-09T03:22:58Z
- **Tasks:** 2/2
- **Files modified:** 3

## Accomplishments

- Added a compile-time caller allowlist for the six Rindle-owned media schemas before Ecto attributes or callbacks are emitted.
- Locked the callback-deletion, opposite-prefix, remote `Ecto.Schema.schema/2` bypass as a bounded compile-time rejection in the public build and verified the symmetric default build probe.
- Retained AST confinement and selected-versus-decoy data-path coverage, including facade, Multi, worker, loaded-struct, and new-struct behavior.

## Task Commits

1. **Task 1: Reject the combined raw-Ecto bypass at the owned-consumer boundary** — `85eaeb1` (RED test), `7f187cd` (GREEN implementation)
2. **Task 2: Prove the narrowed boundary in both builds and retain normal routing evidence** — `0351b34` (test)

## Files Created/Modified

- `lib/rindle/schema.ex` — validates the macro caller against the exact owned-schema allowlist before emitting Ecto setup.
- `test/rindle/schema_prefix_contract_test.exs` — proves the complete raw-Ecto bypass is rejected and preserves the six-source structural contract.
- `test/rindle/config/config_test.exs` — proves runtime configuration cannot retarget metadata for the six permitted schemas.

## Decisions Made

- Enforced the routing contract at Rindle's owned-consumer boundary rather than claiming that Ecto's public macro can be sandboxed for arbitrary Elixir modules.
- Kept declaration reassertion and the final metadata check as defense in depth for the six controlled sources.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test correctness] Replaced a now-invalid dynamic adopter-schema test**
- **Found during:** Task 2
- **Issue:** `config_test.exs` dynamically consumed `Rindle.Schema`, contradicting the plan's newly enforced internal-only boundary and failing the required focused suite.
- **Fix:** Converted it into an equivalent compile-time authority check over the six allowed Rindle-owned schemas.
- **Files modified:** `test/rindle/config/config_test.exs`
- **Verification:** Focused suite passed with 35 tests and the full coverage gate passed with 1,261 tests.
- **Committed in:** `0351b34`

**Total deviations:** 1 auto-fixed (Rule 1).

## Verification

- `mix format --check-formatted lib/rindle/schema.ex test/rindle/config/config_test.exs test/rindle/schema_prefix_contract_test.exs` — passed.
- Focused routing suite — 35 tests, 0 failures.
- `MIX_ENV=dev mix compile --force` plus the default `rindle` raw-Ecto callback-deletion probe — passed; the probe received the required internal-boundary `ArgumentError`.
- `mix coveralls.multiple --type local --type json --slowest 20` — 1,261 tests, 0 failures, 81.5% coverage.

## Issues Encountered

None beyond the corrected stale test described above.

## User Setup Required

None.

## Next Phase Readiness

The six owned schemas have an enforceable compile-time macro boundary and retain normal routing evidence. Phase-level verification can now reassess PREFIX-01 through PREFIX-03.

## Self-Check: PASSED

- All three modified files exist.
- Task commits `85eaeb1`, `7f187cd`, and `0351b34` exist in git history.
