---
phase: 133-evidence-charter-and-live-truth
plan: "18"
subsystem: ci-evidence
tags: [github-actions, nightly, dispatch-ownership, immutable-evidence, shell]
requires:
  - phase: 133-17
    provides: Schema-v2 exact-subject Nightly receipt and read-only revalidation contract
provides:
  - Pre-dispatch canonical matching run-ID snapshot for diagnostic Nightly collection
  - Exact one-new-ID set-difference ownership selector independent of timestamp granularity
  - Adversarial fake-GitHub coverage for malformed, duplicate, delayed, unrelated, zero-new, and many-new inventories
affects: [133-19, 133-22, nightly-evidence, EVID-02, EVID-04]
actuals:
  tokens: 5239
  tasks: 2
  commits: 5
plan_head_before: 6ebb56b8cdb36edc6fda76808ba007d7379fa42a
tech-stack:
  added: []
  patterns:
    - Snapshot remote identity sets before mutation and attribute ownership only through canonical set difference
    - Validate bounded remote inventories before crossing dispatch or evidence-collection boundaries
key-files:
  created: []
  modified:
    - scripts/ci/verify_nightly_run.sh
    - scripts/ci/test_verify_nightly_run.sh
key-decisions:
  - "Bind diagnostic dispatch ownership to exactly one matching database ID absent from the validated pre-dispatch snapshot; createdAt remains receipt metadata only."
  - "Cross-bind the selected run ID to the detailed run databaseId before collecting logs, local authority, or receipt evidence."
patterns-established:
  - "Dispatch ownership: pre_dispatch_ids -> one workflow dispatch -> post_dispatch_ids - pre_dispatch_ids -> cardinality exactly one."
  - "Remote inventory trust boundary: malformed shapes, duplicate IDs, and non-integer IDs fail before dispatch or downstream inspection."
requirements-completed: [EVID-02, EVID-04]
coverage:
  - id: D1
    description: "Diagnostic Nightly collection selects exactly one workflow/ref/SHA run ID that was absent from the canonical pre-dispatch snapshot, independent of createdAt granularity."
    requirement: EVID-02
    verification:
      - kind: integration
        ref: "scripts/ci/test_verify_nightly_run.sh#same-second ownership, zero-new polling, and multiple-new ambiguity cases"
        status: pass
    human_judgment: false
  - id: D2
    description: "Invalid or ambiguous run inventories fail closed without run/incident mutation or receipt writes, while the accepted ID retains schema-v2 exact-run and read-only revalidation semantics."
    requirement: EVID-04
    verification:
      - kind: integration
        ref: "bash scripts/ci/test_verify_nightly_run.sh"
        status: pass
      - kind: other
        ref: "shellcheck -S warning scripts/ci/verify_nightly_run.sh scripts/ci/test_verify_nightly_run.sh"
        status: pass
    human_judgment: false
duration: 26min
completed: 2026-09-11
status: complete
---

# Phase 133 Plan 18: Diagnostic Nightly Dispatch Ownership Summary

**Diagnostic Nightly evidence now belongs to one collector-created run through validated pre/post ID-set difference, with timestamp-independent adversarial coverage and exact detail-ID binding.**

## Performance

- **Duration:** 26 min
- **Started:** 2026-09-11T14:18:11Z
- **Completed:** 2026-09-11T14:43:58Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Replaced whole-second `createdAt` ownership inference with a canonical pre-dispatch matching-ID snapshot and exact post-minus-pre set difference.
- Fail closed before dispatch or selection on malformed inventories, duplicate database IDs, non-integer IDs, and more than one newly observed exact run.
- Expanded the fake-GitHub matrix from 113 to 130 passing cases covering same-second old runs, zero-new polling, delayed and unrelated histories, command ordering, and selected/detail-ID mismatch.
- Preserved the schema-v2 receipt, first-attempt workflow/ref/SHA/job/log authority, local evidence reconstruction, and byte-identical diagnostic incident snapshots.

## Task Commits

Each task used an explicit RED-GREEN cycle, followed by one behavior-preserving cleanup:

1. **Task 1 RED: add failing diagnostic ownership cases** - `b7271be` (test)
2. **Task 1 GREEN: select the collector-owned run by ID difference** - `66b8684` (feat)
3. **Task 2 RED: add failing ownership integration matrix** - `8528af2` (test)
4. **Task 2 GREEN: bind detailed run identity to selection** - `71e8df5` (feat)
5. **REFACTOR: remove obsolete timestamp-selector test input** - `39a603f` (refactor)

**Plan metadata:** committed with this summary.

## Files Created/Modified

- `scripts/ci/verify_nightly_run.sh` - Validates bounded run inventories, snapshots matching IDs before dispatch, selects exactly one new ID, and cross-binds detail identity.
- `scripts/ci/test_verify_nightly_run.sh` - Exercises ownership, ordering, malformed/duplicate inventory, delayed/unrelated polling, ambiguity, nonmutation, and receipt reconstruction.

## Decisions Made

- `createdAt` is retained as validated receipt metadata but has no authority over dispatch ownership.
- Every returned bounded run row is shape/type validated and every database ID must be a unique positive integer before the inventory can influence dispatch or selection.
- The detailed run payload must report the same database ID selected from the one-element set difference before any logs or local evidence are collected.

## TDD Gate Compliance

- **Task 1 RED:** `RED_EVIDENCE_OK` for the same-second pre-existing-run impersonation case.
- **Task 1 GREEN:** ownership-focused matrix passed 10/10; full tracer verification passed 113/113.
- **Task 2 RED:** `RED_EVIDENCE_OK` for selected/detail database-ID mismatch.
- **Task 2 GREEN/REFACTOR:** final matrix passed 130/130 and ShellCheck produced no warning-or-higher diagnostics.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected the next-plan position after SDK advancement**

- **Found during:** Plan metadata close-out
- **Issue:** The execution-start state had initialized the position as Plan 1 despite seventeen existing summaries, so `state.advance-plan` moved it to Plan 2 while correctly recording eighteen completed plans.
- **Fix:** Reconciled the human-readable current position to the next incomplete plan, 19 of 22, while preserving the SDK-derived completed-plan count and roadmap progress.
- **Files modified:** `.planning/STATE.md`
- **Verification:** Phase inventory reports 22 plans, 18 summaries, and Plan 19 as the next incomplete plan.
- **Committed in:** Plan metadata commit

---

**Total deviations:** 1 auto-fixed (1 Rule 1 bug)
**Impact on plan:** Bookkeeping-only correction; no product scope or evidence semantics changed.

## Issues Encountered

None.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 133-19 can harden incident mutation ordering against overlapping scheduled runs without depending on timestamp-based diagnostic ownership.
- Plan 133-22 can revalidate diagnostic nonmutation against a collector whose accepted run is now uniquely attributable.
- No Plan 133-18 blockers or goal-preventing stubs remain.

## Self-Check: PASSED

- Both modified shell files exist and all five RED/GREEN/refactor commits resolve in repository history.
- `bash scripts/ci/test_verify_nightly_run.sh` passed 130/130 cases after the final code change.
- Warning-level ShellCheck passed for both modified files after the final code change.
- Ownership acceptance is explicit in command-log assertions: snapshot before the sole dispatch, watch/view only the unique new ID, and no downstream inspection for zero or many new IDs.
- Coverage metadata classifies both deliverables as automated and passing.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-09-11*
