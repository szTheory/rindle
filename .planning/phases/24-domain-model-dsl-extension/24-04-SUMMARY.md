---
phase: 24-domain-model-dsl-extension
plan: 04
subsystem: testing
tags: [elixir, nimble_options, profile-dsl, backward-compat]
requires:
  - phase: 24-01
    provides: v1.3 thumb digest snapshot and backward-compat guardrail
provides:
  - per-kind profile validator dispatch for image, video, audio, and waveform variants
  - digest-stable image validation that omits :kind from validated image specs
  - compile-time rejection for :from_variant chaining and invalid kind allowlists
affects: [phase-24, profile-digest, backward-compat, validator-tests]
tech-stack:
  added: []
  patterns: [per-kind NimbleOptions dispatch, digest-stable image normalization]
key-files:
  created:
    - test/rindle/profile/validator_test.exs
  modified:
    - lib/rindle/profile/validator.ex
    - test/rindle/backward_compat/v13_digest_snapshot_test.exs
    - test/rindle/profile/profile_test.exs
key-decisions:
  - "Persist :kind only for non-image variants so existing image recipe digests remain byte-for-byte stable."
  - "Reject :from_variant at compile time before schema validation to block cross-variant chaining."
patterns-established:
  - "Dispatch variant validation by pop_kind!/2 plus schema_for_kind/1."
  - "Keep image-only compatibility by normalizing validated image maps without a :kind key."
requirements-completed: [AV-02-06, AV-02-07, AV-02-08]
duration: 3min
completed: 2026-05-05
---

# Phase 24 Plan 04: Domain Model DSL Extension Summary

**Per-kind profile validator dispatch with image digest stability and compile-time cross-variant chaining rejection**

## Performance

- **Duration:** 3 min
- **Started:** 2026-05-05T11:31:08-04:00
- **Completed:** 2026-05-05T11:33:59-04:00
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Replaced the single image-only variant schema with per-kind image, video, audio, and waveform schemas in `Rindle.Profile.Validator`.
- Preserved the v1.3 `:thumb` digest snapshot by omitting `:kind` from all validated image variant maps, including explicit `kind: :image`.
- Added compile-time coverage for valid kind dispatch, allowlist enforcement, cross-kind key rejection, and `:from_variant` rejection, then activated the previously skipped snapshot parity tests.

## Task Commits

1. **Task 1: Replace @variant_schema with four per-kind schemas + dispatch** - `698cb6e` (`test`)
2. **Task 1: Replace @variant_schema with four per-kind schemas + dispatch** - `d2a415c` (`feat`)
3. **Task 2: Author validator_test.exs covering per-kind dispatch + un-skip the digest snapshot tests** - `e68538a` (`test`)

## Files Created/Modified

- `lib/rindle/profile/validator.ex` - Added per-kind schemas, `pop_kind!/2`, `guard_no_from_variant!/2`, `schema_for_kind/1`, and `maybe_put_kind/3`.
- `test/rindle/profile/validator_test.exs` - Added 17 compile-time validator tests covering dispatch, invalid kinds, key allowlists, presets, codecs, and dimension regressions.
- `test/rindle/backward_compat/v13_digest_snapshot_test.exs` - Unskipped the two load-bearing digest parity assertions.
- `test/rindle/profile/profile_test.exs` - Added an image-default regression guard asserting validated variants omit `:kind`.
- `.planning/phases/24-domain-model-dsl-extension/24-04-SUMMARY.md` - Recorded execution outcomes for this plan.

## Decisions Made

- Kept digest stability at the validator boundary instead of changing `Rindle.Profile.Digest`, matching D-14 exactly.
- Reused compile-time `Code.compile_string/1` profile fixtures for validator coverage so the tests exercise the real DSL entrypoint.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Removed a clause-grouping compiler warning in `validate_variant!/2`**
- **Found during:** Task 1 (validator implementation verification)
- **Issue:** The new fallback `validate_variant!/2` clause was separated from the primary clause, which caused `mix compile --warnings-as-errors` to fail.
- **Fix:** Moved the fallback clause adjacent to the main `validate_variant!/2` definition.
- **Files modified:** `lib/rindle/profile/validator.ex`
- **Verification:** `mix compile --warnings-as-errors`; `mix test test/rindle/profile/validator_test.exs test/rindle/backward_compat/v13_digest_snapshot_test.exs test/rindle/profile/profile_test.exs --warnings-as-errors`
- **Committed in:** `d2a415c`

---

**Total deviations:** 1 auto-fixed (Rule 3: blocking compiler warning)
**Impact on plan:** No scope creep. The auto-fix was required to satisfy the compile gate exactly as planned.

## Issues Encountered

None beyond the compiler warning resolved inline during Task 1 verification.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 04 leaves the profile validator on the required per-kind contract with the backward-compat digest guard active and green. Downstream Phase 24 work can rely on `:kind` being present for non-image variants and absent for image variants.

## Self-Check: PASSED

- Found `.planning/phases/24-domain-model-dsl-extension/24-04-SUMMARY.md`
- Found commits `698cb6e`, `d2a415c`, and `e68538a` in `git log`
