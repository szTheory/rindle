---
phase: 01-foundation
plan: "04"
subsystem: domain
tags: [fsm, lifecycle, stale-policy, logging, ecto-query]

requires:
  - phase: 01-foundation
    provides: profile digest primitives and domain schema state columns
provides:
  - Explicit asset/variant/upload-session transition allowlists with invalid transition rejection
  - Structured lifecycle logging helpers for transition failures, quarantines, and upload session expiry
  - Stale serving policy primitives and stale-only query scope for future regeneration workflows
  - Automated transition-matrix tests for ASM, VSM, USM, and stale policy behavior
affects: [upload-broker, variant-regeneration, delivery-fallback, observability]

tech-stack:
  added: []
  patterns: [allowlisted state transitions, structured Logger metadata events, stale scope query helper]

key-files:
  created:
    - lib/rindle/domain/asset_fsm.ex
    - lib/rindle/domain/variant_fsm.ex
    - lib/rindle/domain/upload_session_fsm.ex
    - lib/rindle/domain/stale_policy.ex
    - test/rindle/domain/lifecycle_fsm_test.exs
  modified:
    - lib/rindle/domain/asset_fsm.ex
    - lib/rindle/domain/upload_session_fsm.ex

key-decisions:
  - "Represent lifecycle rules as explicit @allowed_transitions maps in dedicated domain modules."
  - "Log invalid lifecycle transitions with structured metadata rather than free-form strings."
  - "Model stale serving behavior as policy primitives now so delivery and mix tasks can layer on later."

patterns-established:
  - "FSM Pattern: transition/3 returns :ok or {:error, {:invalid_transition, from, to}} with no implicit coercion."
  - "Lifecycle Logging Pattern: warning/info event names scoped under rindle.asset.* and rindle.upload_session.*."
  - "Stale Query Pattern: stale-targeting uses a reusable where([v], v.state == \"stale\") helper."

requirements-completed:
  - ASM-01
  - ASM-02
  - ASM-03
  - ASM-04
  - ASM-05
  - ASM-06
  - ASM-07
  - ASM-08
  - ASM-09
  - ASM-10
  - VSM-01
  - VSM-02
  - VSM-03
  - VSM-04
  - VSM-05
  - VSM-06
  - VSM-07
  - VSM-08
  - USM-01
  - USM-02
  - USM-03
  - USM-04
  - USM-05
  - USM-06
  - USM-07
  - USM-08
  - USM-09
  - STALE-02
  - STALE-03
  - ERR-03
  - ERR-04
  - ERR-05

duration: 4 min
completed: 2026-04-24
---

# Phase 01 Plan 04: Lifecycle FSM Foundations Summary

**Asset, variant, and upload-session lifecycles are now enforced by explicit transition maps with structured failure logging and stale-policy primitives for downstream delivery/regeneration behavior.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-24T17:25:17Z
- **Completed:** 2026-04-24T17:29:22Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments
- Added `AssetFSM`, `VariantFSM`, and `UploadSessionFSM` modules with allowlisted transitions and invalid jump rejection.
- Added structured warning/info lifecycle logging hooks with required metadata keys for failure/quarantine/expiry paths.
- Added `StalePolicy` primitives (`resolve_stale_variant/3`, `stale_regeneration_scope/1`) for STALE-02/03 foundations.
- Added lifecycle transition-matrix tests covering valid and invalid ASM/VSM/USM flows plus stale policy behavior.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add explicit transition allowlists for lifecycle families** - `1f69a8d` (feat)
2. **Task 2: Add structured lifecycle logging helpers** - `43841fc` (feat)
3. **Task 3: Implement stale policy primitives and lifecycle matrix tests** - `5468215` (feat)

**Plan metadata:** pending docs commit for this summary

## Files Created/Modified
- `lib/rindle/domain/asset_fsm.ex` - Asset lifecycle matrix, invalid-transition rejection, and quarantine/transition warning helpers.
- `lib/rindle/domain/variant_fsm.ex` - Variant lifecycle matrix with stale/missing/failed/purged terminal controls.
- `lib/rindle/domain/upload_session_fsm.ex` - Upload session lifecycle matrix with expiry and transition-failure logging.
- `lib/rindle/domain/stale_policy.ex` - Stale serving decision and stale-only query scope helper.
- `test/rindle/domain/lifecycle_fsm_test.exs` - Transition matrix and stale-policy behavior coverage.

## Decisions Made
- Used explicit module-level allowlists rather than implicit branching so transition constraints remain auditable.
- Added structured logger metadata payloads using requirement key names (`asset_id`, `session_id`, `from_state`, `to_state`, `detected_mime`, `reason`).
- Introduced stale handling policy in Phase 1 to avoid coupling URL behavior decisions to later worker implementation details.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Verification target file absent before Task 2 verify command**
- **Found during:** Task 2 (Add lifecycle log helpers)
- **Issue:** `mix test test/rindle/domain/lifecycle_fsm_test.exs --seed 0` failed because the test file did not yet exist.
- **Fix:** Created a minimal lifecycle test scaffold immediately, validated Task 2, then expanded it in Task 3 to full matrix coverage.
- **Files modified:** `test/rindle/domain/lifecycle_fsm_test.exs`
- **Verification:** Re-ran the exact Task 2 verify command successfully after scaffold creation.
- **Committed in:** `5468215` (final expanded test suite commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** No scope creep; change preserved task verification gating and resulted in stronger final test coverage.

## Issues Encountered
- Task 2 verification command initially failed due to missing `lifecycle_fsm_test.exs` path; resolved during execution by creating the expected file and re-running verification.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 1 plan 04 lifecycle invariants are now enforceable and covered by executable matrix tests.
- Stale-serving behavior and stale-targeting query helper are ready for delivery-layer and mix-task consumers in later plans.
- Ready for `01-05` in Phase 1.

## Verification Evidence
- `mix compile --warnings-as-errors` ✅
- `mix test test/rindle/domain/lifecycle_fsm_test.exs` ✅ (15 tests, 0 failures)
- `rg "\"staged\" => \[\"validating\"\]" lib/rindle/domain/asset_fsm.ex` ✅
- `rg "Logger\.warning\(\"rindle\.asset\.quarantined\"" lib/rindle/domain/asset_fsm.ex` ✅

---
*Phase: 01-foundation*
*Completed: 2026-04-24*
