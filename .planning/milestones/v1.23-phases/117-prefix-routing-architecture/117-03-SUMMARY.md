---
phase: 117-prefix-routing-architecture
plan: 03
subsystem: testing
tags: [ecto, schema-prefix, compile-time, macro, regression-tests]
requires:
  - phase: 117-02
    provides: Prefix-routing integration proof and structural schema-boundary guards
provides:
  - Compile-finalization enforcement for Rindle.Schema consumer metadata
  - Dynamic post-use schema-prefix mutation regression coverage
  - Default and public compatibility build authority evidence
affects: [118-schema-provisioning, 119-runtime-boundaries, 120-release-proof]
tech-stack:
  added: []
  patterns: [bound compile-time macro inputs, after-compile Ecto metadata enforcement]
key-files:
  created: []
  modified:
    - lib/rindle/schema.ex
    - test/rindle/schema_prefix_contract_test.exs
    - test/rindle/config/config_test.exs
key-decisions:
  - "Rindle.Schema binds its already-compiled prefix before entering a consumer quote, then validates only final Ecto metadata after compilation."
  - "Application environment mutation after Rindle.Schema compiles cannot retarget later schema consumers; Oban remains independently configured."
patterns-established:
  - "Use an @after_compile callback at the macro boundary when a consumer can mutate metadata after use."
requirements-completed: [PREFIX-01, PREFIX-02, PREFIX-03]
coverage:
  - id: D1
    description: "A Rindle.Schema consumer that dynamically replaces :schema_prefix after use is rejected at compile finalization with expected and actual prefix details."
    requirement: PREFIX-01
    verification:
      - kind: unit
        ref: test/rindle/schema_prefix_contract_test.exs#rejects-a-dynamic-post-use-schema-prefix-override-at-compile-finalization
        status: pass
    human_judgment: false
  - id: D2
    description: "The explicit public test build and fresh default rindle build preserve a single compiled schema-prefix authority."
    requirement: PREFIX-02
    verification:
      - kind: integration
        ref: mix test test/rindle/config/config_test.exs test/rindle/domain/media_schema_test.exs test/rindle/schema_prefix_contract_test.exs test/rindle/schema_prefix_integration_test.exs --seed 0
        status: pass
      - kind: other
        ref: MIX_ENV=dev mix compile --force plus dynamic public override probe
        status: pass
    human_judgment: false
  - id: D3
    description: "Existing structural guards and prefix-routing integration retain independent host-owned Oban routing."
    requirement: PREFIX-03
    verification:
      - kind: integration
        ref: mix coveralls.multiple --type local --type json --slowest 20
        status: pass
    human_judgment: false
duration: 4min
completed: 2026-08-09
status: complete
---

# Phase 117 Plan 03: Prefix Routing Architecture Summary

**Rindle.Schema now binds and enforces one compiled Ecto prefix for every schema consumer, rejecting dynamic metadata overrides while retaining public compatibility and independent Oban routing.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-08-09T02:17:38Z
- **Completed:** 2026-08-09T02:20:49Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Bound `Rindle.Schema.prefix/0` outside the consumer quote and registered an after-compile metadata guard.
- Added a real `Module.put_attribute/3` compilation regression while retaining the six-schema source-level guard.
- Proved the explicit public test build and a fresh default `rindle` build preserve the shared authority without modifying Oban.

## Verification

- `mix format --check-formatted lib/rindle/schema.ex test/rindle/schema_prefix_contract_test.exs test/rindle/config/config_test.exs` — PASS
- `mix test test/rindle/config/config_test.exs test/rindle/domain/media_schema_test.exs test/rindle/schema_prefix_contract_test.exs test/rindle/schema_prefix_integration_test.exs --seed 0` — PASS (35 tests)
- `MIX_ENV=dev mix compile --force` plus the exact dynamic public prefix mutation probe — PASS (raised bounded `ArgumentError` as expected)
- `mix coveralls.multiple --type local --type json --slowest 20` — PASS (1,261 tests, 0 failures, 4 skipped, 77 excluded; 81.6% coverage)

## Task Commits

1. **Task 1: Reject a dynamic post-use prefix mutation at compile finalization** — `49bb38f` (RED test), `09aa63e` (GREEN implementation)
2. **Task 2: Prove default and public builds retain one authority without touching Oban** — `077c45b` (test)

## Files Created/Modified

- `lib/rindle/schema.ex` — binds the compiled authority and rejects final Ecto metadata mismatches.
- `test/rindle/schema_prefix_contract_test.exs` — exercises dynamic post-use prefix mutation and bounded rejection.
- `test/rindle/config/config_test.exs` — proves runtime application-env mutation cannot retarget compiled schema metadata.

## Decisions Made

- Use final Ecto metadata as the enforcement boundary; the literal source guard remains supplemental early warning.
- Keep Rindle's compile-time schema authority separate from host-owned Oban configuration and metadata.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The plan's one-line `~s(...)` default-build probe could not contain nested Elixir parentheses. The equivalent probe ran with a multiline string and the exact `Module.put_attribute(__MODULE__, :schema_prefix, "public")` mutation; it passed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 118 can provision the default `rindle` schema knowing consumers cannot silently replace the routing authority. Phase 119 and 120 retain ownership of runtime boundary and release-proof work.

## Self-Check: PASSED

- The three declared implementation/test files and this summary exist.
- Task commits `49bb38f`, `09aa63e`, and `077c45b` exist and modify only the three declared implementation/test files.
