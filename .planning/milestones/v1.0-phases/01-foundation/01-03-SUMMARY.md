---
phase: 01-foundation
plan: "03"
subsystem: profile
tags: [profile-dsl, nimble-options, recipe-digest, stale-detection, testing]

requires:
  - phase: 01-foundation
    provides: behavior seams and schema substrate from 01-01/01-02
provides:
  - Compile-time validated `use Rindle.Profile` DSL
  - Deterministic `recipe_digest/1` backed by canonicalized variant specs
  - Regression test coverage for DSL compile failures and digest drift invariants
affects: [profile processing flows, stale variant detection, per-profile storage selection]

tech-stack:
  added: []
  patterns:
    - Compile-time option validation with NimbleOptions in DSL macros
    - Deterministic recipe hashing from canonicalized variant structures

key-files:
  created:
    - lib/rindle/profile.ex
    - lib/rindle/profile/validator.ex
    - lib/rindle/profile/digest.ex
    - test/rindle/profile/profile_test.exs
  modified: []

key-decisions:
  - "Profile options are expanded from macro AST before validation so module literals validate correctly at compile time."
  - "Variant recipe digesting canonicalizes nested keys before JSON encoding to keep hash outputs stable across key ordering."
  - "Unknown variant digests raise with explicit profile context rather than silently returning nil."

patterns-established:
  - "Profile DSL pattern: emit deterministic helper functions (`variants/0`, `validate_upload/1`, `recipe_digest/1`) from a validated option contract."
  - "Digest pattern: hash canonical JSON representation rather than raw map structures."

requirements-completed: [PROF-01, PROF-02, PROF-03, PROF-04, PROF-05, PROF-06, PROF-07, STALE-01, CONF-02]

duration: 3 min
completed: 2026-04-24
---

# Phase 1 Plan 03: Profile DSL + Digest Summary

**Rindle now ships a compile-time profile DSL with strict option validation plus deterministic variant recipe digests that change when recipe options drift.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-24T13:16:29-04:00
- **Completed:** 2026-04-24T13:19:57-04:00
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments
- Added `use Rindle.Profile` macro generation for `storage_adapter/0`, `variants/0`, `validate_upload/1`, and `recipe_digest/1`.
- Added strict profile/variant schema validation with compile-time failure semantics for unknown or contradictory options.
- Added stable SHA-256 digest generation and profile test coverage for compile-time errors, deterministic digesting, and digest drift.

## Task Commits

Each task was committed atomically:

1. **Task 1: Build `use Rindle.Profile` macro with strict option schema** - `fb64462` (feat)
2. **Task 2: Implement stable recipe digest generation for variant specs** - `d7c304d` (feat)
3. **Task 3: Add compile-time DSL tests and digest drift tests** - `35b1e6d` (test)

**Plan metadata:** `(this commit)`

## Files Created/Modified
- `lib/rindle/profile.ex` - Profile DSL macro and generated helper functions.
- `lib/rindle/profile/validator.ex` - NimbleOptions schemas and upload/variant validation rules.
- `lib/rindle/profile/digest.ex` - Canonicalized JSON digest generation for variant specs.
- `test/rindle/profile/profile_test.exs` - Compile-time DSL and digest drift regression tests.

## Decisions Made
- Expand macro literals before validating options so aliases like `Rindle.StorageMock` validate as modules.
- Use strict upload allowlist checks in generated `validate_upload/1` for MIME, extension, byte size, and pixel constraints.
- Canonicalize nested variant structures before hashing so key reordering does not change digest values.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Task 2 verify command targeted a file that did not exist yet**
- **Found during:** Task 2 (verify step)
- **Issue:** `mix test test/rindle/profile/profile_test.exs --seed 0` failed before Task 3 created tests.
- **Fix:** Added the expected test file path and completed full test coverage in Task 3.
- **Files modified:** `test/rindle/profile/profile_test.exs`
- **Verification:** targeted test command now passes in both Task 2 and plan-level verification.
- **Committed in:** `35b1e6d`

**2. [Rule 1 - Bug] Compile-time validation initially received unexpanded macro AST module literals**
- **Found during:** Task 3 (new compile-time tests)
- **Issue:** `storage: Rindle.StorageMock` failed validation because the DSL macro validated raw AST and used an incorrect `:mod_arg` schema type.
- **Fix:** Expanded macro literals before validation and adjusted storage schema typing to module atoms.
- **Files modified:** `lib/rindle/profile.ex`, `lib/rindle/profile/validator.ex`
- **Verification:** `mix test test/rindle/profile/profile_test.exs` passes with module literal profiles.
- **Committed in:** `35b1e6d`

---

**Total deviations:** 2 auto-fixed (1 blocking sequencing issue, 1 compile-time DSL bug)
**Impact on plan:** Both fixes were required for correctness and did not expand scope beyond profile DSL + digest primitives.

## Issues Encountered
- Task ordering in the plan referenced a test file in Task 2 before its dedicated Task 3 creation; resolved by creating the file and then filling full coverage in Task 3.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Profile DSL contract and digest primitives are stable for downstream processing/state transition work.
- Stale-detection consumers can now compare persisted digest values against profile recipe digests.

---
*Phase: 01-foundation*
*Completed: 2026-04-24*
