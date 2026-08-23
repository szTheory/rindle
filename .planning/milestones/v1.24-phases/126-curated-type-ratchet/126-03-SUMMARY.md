---
phase: 126-curated-type-ratchet
plan: "03"
subsystem: testing
tags: [dialyzer, nightly, admin, runtime-checks, safe-01]
requires:
  - phase: 126-02
    provides: supported migration warning dispositions and exact TUS-only receipt
provides:
  - supported dispositions for batch task, Admin action, and runtime-check filters
  - exact final operational receipt with only later-owned TUS warnings
affects: [126-04, 126-05, 126-06, 126-07]
tech-stack:
  added: []
  patterns: [timestamp-bound exact-head Nightly receipt, exact retained-noise rationale]
key-files:
  created: [.planning/phases/126-curated-type-ratchet/126-03-SUMMARY.md]
  modified: [.dialyzer_ignore.exs, .planning/phases/126-curated-type-ratchet/126-TYPE-EVIDENCE.md]
decisions:
  - "E09, E10, and E24 remain exact supported analyzer-noise filters because removing their branches would weaken task output, Admin fallback, or runtime diagnostics."
  - "The plan predicate typo for E38 was corrected only in the verification command to match the supported emitted warning text."
requirements-completed: []
coverage:
  - id: D1
    description: Supported operational filter dispositions preserve task, Admin, and runtime-check behavior.
    requirement: SAFE-01
    verification:
      - kind: unit
        ref: MIX_ENV=test mix test test/rindle/batch_owner_erasure_task_test.exs test/rindle/admin/live/actions_live_test.exs test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_checks_streaming_test.exs --seed 0
        status: pass
      - kind: other
        ref: bash scripts/maintainer/refactor_contract.sh
        status: pass
    human_judgment: false
metrics:
  tasks_completed: 2
  files_modified: 2
  supported_probe_run: 32640992583
  supported_final_run: 32641395080
duration: 31min
completed: 2026-08-23
status: complete
---

# Phase 126 Plan 03: Operational Type Boundary Summary

Batch owner erasure, Admin actions, and runtime checks now have exact supported-CI dispositions while their task output, UI fallback, diagnostics, telemetry, and error shapes remain unchanged.

## Completed Tasks

1. **Expose and classify task, Admin, and runtime-check warnings on 1.17/27**
   - Removed only E09, E10, and E24 for the source-unchanged probe.
   - Exact-head Nightly run 32640992583 reproduced E09 twice, E10 once, and E24 once, alongside only the three later-owned TUS warnings.
2. **Correct actionable task, Admin, and runtime-check boundaries**
   - Existing focused owner coverage already represented every relevant behavior, so no behavior-changing correction was warranted.
   - Restored the three exact filters with adjacent run/job/warning rationale and recorded them as retained analyzer noise.
   - Exact-head Nightly run 32641395080 emitted only E38-E40; Dialyzer failed and Nightly Summary succeeded while honestly recording `DIALYZER: failure`.

## Verification

- Focused owner suites: 71 tests passed.
- `bash scripts/maintainer/refactor_contract.sh`: 92 contract tests passed.
- `MIX_ENV=test mix test test/install_smoke/dialyzer_ignore_policy_test.exs --seed 0`: 2 tests passed.
- Final supported [Nightly run 32641395080](https://github.com/szTheory/rindle/actions/runs/32641395080), exact head `19c53b2c37452ccaa0a0de685758cf0bfaf2feb0`:
  - [Dialyzer job 97198921550](https://github.com/szTheory/rindle/actions/runs/32641395080/job/97198921550) failed with exactly E38 at `tus_creation.ex:35` and E39-E40 at `tus_stream.ex:163` and `:66`.
  - [Nightly Summary job 97199446324](https://github.com/szTheory/rindle/actions/runs/32641395080/job/97199446324) succeeded and logged `DIALYZER: failure`.

## Task Commits

1. **Task 1: expose operational filters** — `7397e37`
2. **Task 1: record supported probe receipt** — `6e3f933`
3. **Task 2: retain supported analyzer noise** — `19c53b2`
4. **Task 2: record final receipt** — `a0f7b05`

## Decisions Made

- E09 retains distinct partial/general task error reporting; E10 retains the Admin non-binary facade-error fallback; E24 retains sandbox checkout error diagnostics.
- The final Nightly failure is intentional and limited to Plan 126-07’s E38-E40 TUS ownership.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Verification predicate] Corrected the E38 warning-text assertion**
- **Found during:** Task 2 final supported receipt verification.
- **Issue:** the plan predicate used `{:error, _.}` while the supported annotation text is `{:error, _}.`.
- **Fix:** reran the complete paginated annotation multiset assertion with the exact emitted text.
- **Files modified:** None.
- **Verification:** all three and only E38-E40 annotations matched.
- **Committed in:** Not applicable; verification-only correction.

**Total deviations:** 1 auto-fixed (Rule 1).
**Impact on plan:** None; the supported CI receipt is exact and unchanged.

## Known Stubs

None.

## Next Phase Readiness

Plans 126-04 onward can rely on a truthful operational receipt: no operational, migration/support, or unowned warning remains emitted. Plan 126-07 still owns E38-E40.

## Self-Check: PASSED

Verified the evidence ledger, retained-filter file, and summary exist; all four task commits are reachable.
