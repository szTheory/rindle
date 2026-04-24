---
phase: 01-foundation
plan: "02"
subsystem: testing
tags: [behaviours, contracts, mox, adapters, validation]

requires:
  - phase: 01-foundation
    provides: schema substrate and repo harness from 01-01
provides:
  - Typed behaviour contracts for storage, processing, analyzer, scanner, and authorizer seams
  - Mox-backed mock wiring for all behaviour callbacks
  - Executable contract test suite asserting callback return semantics
affects: [storage adapters, processors, analyzers, scanners, delivery authorization, phase-01 follow-up plans]

tech-stack:
  added: [mox]
  patterns:
    - Tuple-returning behaviour boundaries for adapter seams
    - Contract-first callback verification via Mox expectations

key-files:
  created:
    - lib/rindle/storage.ex
    - lib/rindle/processor.ex
    - lib/rindle/analyzer.ex
    - lib/rindle/scanner.ex
    - lib/rindle/authorizer.ex
    - test/support/mocks.ex
    - test/rindle/contracts/behaviour_contract_test.exs
  modified:
    - test/test_helper.exs
    - mix.exs
    - mix.lock

key-decisions:
  - "All adapter-facing contracts use explicit callback types and tagged tuple semantics where operations can fail."
  - "Storage capability branching is standardized via capabilities/0 to prevent unsupported backend assumptions."
  - "Behaviour contract validation runs through Mox-based unit tests so later adapters can be swapped without real I/O."

patterns-established:
  - "Behaviour seam pattern: define adapter contracts before concrete implementations."
  - "Mock boot pattern: centralize behaviour mocks in test/support and make helper loading idempotent."

requirements-completed: [BHV-01, BHV-02, BHV-03, BHV-04, BHV-05, BHV-06]

duration: 5 min
completed: 2026-04-24
---

# Phase 1 Plan 02: Behaviour Contracts Summary

**Core adapter seams are now frozen as typed behaviours with capability signaling and executable Mox contract tests for deterministic callback semantics.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-24T17:05:11Z
- **Completed:** 2026-04-24T17:10:07Z
- **Tasks:** 3
- **Files modified:** 10

## Accomplishments
- Added all five Phase 1 behaviour modules with explicit callback signatures and transaction-boundary docs.
- Introduced central Mox mocks and test boot wiring so contracts are executable in isolation.
- Added a dedicated contract suite that asserts success/error/quarantine/unauthorized callback outcomes.

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement typed behaviour contracts for storage, processing, analysis, scanning, and authorization** - `1de5088` (feat)
2. **Task 2: Add Mox mocks for all behaviours and wire them into test boot** - `b681754` (feat)
3. **Task 3: Create behaviour contract tests with explicit callback result expectations** - `3a269d3` (test)

**Plan metadata:** `(this commit)`

## Files Created/Modified
- `lib/rindle/storage.ex` - Storage behaviour contract including `capabilities/0`.
- `lib/rindle/processor.ex` - Processor callback contract for source/spec/destination processing.
- `lib/rindle/analyzer.ex` - Analyzer callback contract for metadata extraction responses.
- `lib/rindle/scanner.ex` - Scanner callback contract with quarantine return type.
- `lib/rindle/authorizer.ex` - Authorization callback contract for delivery policy decisions.
- `test/support/mocks.ex` - Mox mock declarations for all behaviour contracts.
- `test/test_helper.exs` - Global test boot requiring mocks after ExUnit start with idempotent load guard.
- `test/rindle/contracts/behaviour_contract_test.exs` - Contract-level callback semantics tests.
- `mix.exs` - Added `:mox` test dependency.
- `mix.lock` - Resolved lockfile updates for `:mox` and dependencies.

## Decisions Made
- Capability branching is contract-level (`capabilities/0`) rather than adapter-internal convention.
- Non-boolean behaviour operations use tagged tuples for deterministic failure handling at call boundaries.
- Contract tests assert callback semantics directly against mocks to prevent drift before adapter implementations exist.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Missing `:mox` dependency prevented contract test execution**
- **Found during:** Task 3 (Create behaviour contract tests with explicit callback result expectations)
- **Issue:** `mix test` failed because `Mox.defmock/2` was undefined.
- **Fix:** Added `{:mox, "~> 1.2", only: :test}` to `mix.exs` and fetched dependencies.
- **Files modified:** `mix.exs`, `mix.lock`
- **Verification:** `mix test test/rindle/contracts/behaviour_contract_test.exs` passes.
- **Committed in:** `3a269d3` (part of Task 3 commit)

**2. [Rule 1 - Bug] Duplicate mock loading produced module redefinition warnings**
- **Found during:** Plan-level verification
- **Issue:** `test/support/mocks.ex` loaded both through test compile paths and explicit require in `test_helper`.
- **Fix:** Guarded `Code.require_file/2` with `Code.ensure_loaded?/1` in `test/test_helper.exs`.
- **Files modified:** `test/test_helper.exs`
- **Verification:** `mix test` and targeted contract test run without redefinition warnings.
- **Committed in:** `3d5be2c`

---

**Total deviations:** 2 auto-fixed (1 blocking dependency, 1 warning-level bug)
**Impact on plan:** Both fixes were contained, preserved plan scope, and improved reliability of contract verification.

## Issues Encountered
- `mix deps.get` prompted for Hex re-authentication due token refresh failure; continued unauthenticated for public packages and completed dependency resolution.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Behaviour seams and callback semantics are now stable for adapter implementation in `01-03`.
- No blockers remain for storage adapter conformance work.

---
*Phase: 01-foundation*
*Completed: 2026-04-24*
