---
phase: 133-evidence-charter-and-live-truth
plan: "171"
subsystem: evidence
tags: [elixir, reconciliation, qualification, authorization, runtime]
requires:
  - phase: "133-155"
    provides: authenticated 96-name offline supply prerequisite
  - phase: "133-167"
    provides: durable post-marker first-red receipt pattern
provides:
  - Plan 170-only independently verified green reconciliation admission
  - Plan 123 writer requires Plan 170 receipt digests and rejects spent Plan 168 keys
affects: [133-170, 133-169, 133-121, 133-122, 133-123]
actuals:
  tokens: 48797
  tasks: 2
  commits: 8
  plan_head_before: 1417f1f32b7d4a1f2fafb6c567fa4d99e49d8f9e
  plan_head_after: 449e03cb9756f13f66a6f074ba034609e445058e
tech-stack:
  added: []
  patterns: [source-bound receipt identity, digest-only authorization, independent terminal verification]
key-files:
  created:
    - scripts/maintainer/phase_133_qualification_170.mjs
    - scripts/maintainer/phase_133_qualification_170.test.mjs
    - .planning/phases/133-evidence-charter-and-live-truth/133-171-TASK2-RED-EVIDENCE.json
  modified:
    - scripts/maintainer/phase_133_local_gates.sh
    - scripts/maintainer/test_phase_133_local_gates.sh
    - scripts/maintainer/validate_phase_133_reconciliation.exs
    - scripts/maintainer/phase_133_plan118_commit.exs
    - test/install_smoke/phase_133_reconciliation_test.exs
key-decisions:
  - "Plan 170 is the only current authority consumed by reconciliation; Plan 168 material remains spent."
  - "Reconciliation requires Plan 170's independent terminal verifier and grants no requirement or qualification credit."
  - "Plan 123 requires Plan 170 authority digests and rejects the old Plan 168 digest keys."
requirements-completed: []
coverage:
  - id: D1
    description: Plan 170 has its own source-bound, digest-only qualification authority and selected-Node local-gates route.
    verification:
      - kind: unit
        ref: node --test scripts/maintainer/phase_133_qualification_170.test.mjs
        status: pass
      - kind: integration
        ref: bash scripts/maintainer/test_phase_133_local_gates.sh
        status: pass
    human_judgment: false
  - id: D2
    description: Reconciliation admits Plan 170 only after independent green verification and preserves pending requirements, unresolved edges, and zero credit.
    verification:
      - kind: unit
        ref: test/install_smoke/phase_133_reconciliation_test.exs#Plan 121 admits independently verified green Plan 170 exact-source evidence only
        status: pass
      - kind: unit
        ref: test/install_smoke/phase_133_reconciliation_test.exs#Plan 121 rejects incomplete, stale, historical, forged, and first-red Plan 170 evidence
        status: pass
      - kind: unit
        ref: test/install_smoke/phase_133_reconciliation_test.exs#Plan 121 never promotes spent Plan 168 authority when Plan 170 evidence is absent
        status: pass
    human_judgment: false
  - id: D3
    description: Plan 123 transaction authority accepts Plan 170 digest keys and rejects spent Plan 168 substitutions.
    verification:
      - kind: unit
        ref: test/install_smoke/phase_133_reconciliation_test.exs#Plan 123 writer rejects missing Plan 155 keys and spent Plan 168 or historical substitutions
        status: pass
      - kind: integration
        ref: ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 MIX_ENV=test mix test test/install_smoke/phase_133_reconciliation_test.exs --seed 0
        status: pass
    human_judgment: false
duration: 1h 30m
completed: 2026-10-11
status: complete
---

# Phase 133 Plan 171: Plan 170 Reconciliation Summary

**Plan 121 reconciliation admits only independently verified Plan 170 green; Plan 123 rejects spent Plan 168 keys with no credit issued.**

## Performance

- **Duration:** 1h 30m
- **Started:** 2026-10-11T18:48:00Z
- **Completed:** 2026-10-11T20:18:47Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Added the Plan 170-only reconciliation path. It validates Plan 170 source, supply, preflight, retrieval, digest-only authorization, attempt, and terminal receipts, then invokes Plan 170's independent verifier before census.
- Migrated Plan 123 writer authority to the six Plan 170 receipt digests and explicitly rejects the spent Plan 168 key set.
- Preserved Plan 169 as a separate gate. All five requirements remain Pending, all eleven evidence edges remain unresolved, and qualification credit remains zero.
- Added copied-tree admission, stale/forged/missing authority, first-red, Plan 168 rejection, and Plan 123 writer tests. No real Plan 170 receipt or qualification attempt was created.

## Task Commits

1. **Task 1 RED:** `6ae03a1e` — assertion-level failure on the inherited Plan 168 authority identity; RED classifier passed.
2. **Task 1 GREEN:** `4a41544a` — added the Plan 170 source-bound producer, verifier, and selected-Node runner route.
3. **Task 2 RED:** `b580a867` — added Plan 170 reconciliation admission and spent-authority tests; JUnit RED evidence is recorded in `133-171-TASK2-RED-EVIDENCE.json`.
4. **Task 2 GREEN:** `449e03cb` — switched reconciliation and Plan 123 writer authority to independently verified Plan 170 evidence.

## Files Created/Modified

- `scripts/maintainer/phase_133_qualification_170.mjs` — Plan 170 source, receipt, and independent terminal verification.
- `scripts/maintainer/phase_133_qualification_170.test.mjs` — copied-tree and spent Plan 168 rejection coverage.
- `scripts/maintainer/phase_133_local_gates.sh` — Plan 170 routing and exact Node child binding while retaining Plan 168 history.
- `scripts/maintainer/test_phase_133_local_gates.sh` — disposable Plan 170 first-red and selected-runtime fixture.
- `scripts/maintainer/validate_phase_133_reconciliation.exs` — Plan 170-only authority and independent verifier admission.
- `scripts/maintainer/phase_133_plan118_commit.exs` — Plan 123 requires Plan 170 receipt digests.
- `test/install_smoke/phase_133_reconciliation_test.exs` — Plan 170 green admission, spent authority rejection, transaction fixtures, and current recovery DAG expectations.
- `133-171-TASK2-RED-EVIDENCE.json` — unchanged JUnit report details and semantic RED assessment.

## TDD Gate Compliance

- **Task 1:** The named Plan 170 identity test failed on the intended assertion; the RED classifier passed. The Plan 170 Node tests and local-gates integration suite passed after implementation.
- **Task 2 RED:** `MIX_ENV=test mix test test/install_smoke/phase_133_reconciliation_test.exs --seed 0 --only plan171_tdd_red --formatter JUnitFormatter` exited 2 on the named Plan 170 admission assertion. The target executed and failed because reconciliation still required Plan 168 authority. `gsd_run check tdd-red-evidence .planning/phases/133-evidence-charter-and-live-truth/133-171-TASK2-RED-EVIDENCE.json --raw` returned `RED_EVIDENCE_OK` (`target_test_failed`); the fixture loaded and reached the intended assertion.
- **Task 2 GREEN:** The Plan 170 admission and Plan 123 writer regressions pass. The required full reconciliation command completed with **126 tests, 0 failures**. No refactor commit was needed.

## Decisions Made

- Plan 170 owns the current preflight, supply, authorization, attempt, and terminal identity; Plan 168 authority cannot be replayed.
- The reconciliation path invokes the independent Plan 170 verifier before census and preserves zero credit.
- Plan 169 remains the separate rebind gate after independently verified Plan 170 green.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Aligned recovery DAG parity tests with the current Plan 169 → Plan 170 route**
- **Found during:** Task 2 (full reconciliation verification)
- **Issue:** The parity fixture still expected Plan 169 to depend on spent Plan 168 and used the previous active-plan summary and effective-wave assumptions.
- **Fix:** Updated the fixture to assert Plan 169's Plan 170 dependency, use declared wave floors while ignoring completed prerequisite summaries, and check the current active-plan summary. No roadmap or state artifact was changed.
- **Files modified:** `test/install_smoke/phase_133_reconciliation_test.exs`
- **Verification:** Recovery DAG parity test and the full reconciliation suite passed.
- **Committed in:** `449e03cb`

---

**2. [Rule 3 - Blocking] Align the downstream Plan 123 writer with Plan 170 authority**
- **Found during:** Task 2 full reconciliation verification.
- **Issue:** The Plan 123 writer still required spent Plan 168 digest keys, so an independently verified Plan 170 green result could not flow through the downstream transaction boundary while spent Plan 168 keys remained accepted.
- **Fix:** Migrated the writer to Plan 170 receipt digests and kept explicit Plan 168 substitution rejection tests. No qualification attempt, receipt, requirement closure, or credit was produced.
- **Files modified:** `scripts/maintainer/phase_133_plan118_commit.exs`, `test/install_smoke/phase_133_reconciliation_test.exs`.
- **Verification:** The full reconciliation suite passed with 126 tests and 0 failures.
- **Committed in:** `449e03cb`.

**Total deviations:** 2 auto-fixed (Rule 3 - Blocking).
**Impact:** Refreshed a stale recovery-DAG test contract and removed Plan 168 from the downstream Plan 123 writer authority set. Shared roadmap/state/requirements and qualification credit were unchanged.

## Issues Encountered

- The previous Task 2 attempt stopped before a test ran because dependencies were absent. After the owner cleared the package checkpoint, locked dependencies were restored using isolated Hex and Mix homes; `mix.lock` remained unchanged.
- An early full run found the Plan 123 writer still requiring Plan 168 digest keys. Task 2 migrated the writer and its synthetic transaction fixtures to Plan 170; the final full run passed.
- No Plan 170 preflight, source freeze, authorization, qualification attempt, receipt, or requirement credit was produced.

## User Setup Required

None.

## Verification

- `gsd_run check tdd-red-evidence ... --raw` — `RED_EVIDENCE_OK`.
- `ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 MIX_ENV=test mix test test/install_smoke/phase_133_reconciliation_test.exs --seed 0` — 126 tests, 0 failures.
- `./scripts/maintainer/automation_first_contract.sh` — passed after the summary commit.

## Next Phase Readiness

Plan 171 is complete and Plan 170's code and reconciliation contract are committed. Plan 170 may now proceed under its own authorization and qualification workflow. Plan 169 remains separate and blocked until Plan 170 produces independently verified green. Requirements remain Pending; eleven evidence edges remain unresolved; credit remains zero.

## Self-Check: PASSED

- Task 1 and Task 2 commits are present and are ancestors of this worktree HEAD.
- The Plan 170 RED evidence record exists and passes the format-aware classifier.
- The required full reconciliation test command passed.
- No Plan 170 receipt files exist in the phase directory.
- `STATE.md`, `ROADMAP.md`, and `REQUIREMENTS.md` are unchanged.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-10-11*

