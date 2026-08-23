---
phase: 126-curated-type-ratchet
plan: "04"
subsystem: testing
tags: [dialyzer, nightly, runtime-status, html, process-variant, safe-01]
requires:
  - phase: 126-03
    provides: exact TUS-only intermediate Nightly receipt
provides:
  - supported dispositions for historical runtime-status, HTML, and ProcessVariant atom filters
  - exact final receipt containing only later-owned E38-E40 warnings
affects: [126-05, 126-06, 126-07, 126-08, 126-09]
tech-stack:
  added: []
  patterns: [source-unchanged supported probe, exact retained-analyzer-noise rationale]
key-files:
  created: [.planning/phases/126-curated-type-ratchet/126-04-SUMMARY.md]
  modified: [.dialyzer_ignore.exs, .planning/phases/126-curated-type-ratchet/126-TYPE-EVIDENCE.md]
decisions:
  - "E04-E07 remain exact supported analyzer-noise filters because their fallback clauses preserve optional HTML, runtime diagnostics, and ProcessVariant lifecycle behavior."
  - "Intermediate exact-head Nightly acceptance remains the complete E38-E40 TUS-only multiset with Dialyzer failure and Nightly Summary success."
requirements-completed: []
coverage:
  - id: D1
    description: Runtime-status task output, HTML helpers, and ProcessVariant lifecycle behavior remain unchanged while E04-E07 are reconciled.
    requirement: SAFE-01
    verification:
      - kind: unit
        ref: MIX_ENV=test mix test test/rindle/ops/runtime_status_test.exs test/rindle/runtime_status_task_test.exs test/rindle/html_test.exs test/rindle/workers/process_variant_test.exs --seed 0
        status: pass
      - kind: other
        ref: bash scripts/maintainer/refactor_contract.sh
        status: pass
      - kind: other
        ref: Exact-head Nightly run 32642989666 annotation multiset
        status: pass
    human_judgment: false
metrics:
  tasks_completed: 2
  files_modified: 2
  supported_probe_run: 32642668846
  supported_final_run: 32642989666
duration: 14min
completed: 2026-08-23
status: complete
---

# Phase 126 Plan 04: Historical Runtime Pattern Summary

Runtime-status, HTML, and ProcessVariant retain only exact supported analyzer-noise filters while their task output, helper fallbacks, lifecycle behavior, telemetry, and error terms remain unchanged.

## Completed Tasks

1. **Probe historical runtime-status, HTML, and ProcessVariant atoms on 1.17/27**
   - Removed only E04-E07 from the curated baseline while preserving every owner source file.
   - Exact-head Nightly run 32642668846 reproduced E04-E07 and the three later-owned TUS warnings, with no other warning.
2. **Reconcile historical atoms and prove runtime owner behavior**
   - Retained E04-E07 with adjacent supported-run rationale because each inferred-unreachable clause protects a behaviorally valid fallback boundary.
   - Exact-head Nightly run 32642989666 emitted only later-owned E38-E40; Dialyzer failed while Nightly Summary succeeded and recorded `DIALYZER: failure`.

## Verification

- `MIX_ENV=test mix test test/install_smoke/dialyzer_ignore_policy_test.exs --seed 0`: 2 tests passed.
- Focused runtime-status/task/HTML/ProcessVariant suites: 65 tests passed.
- `bash scripts/maintainer/refactor_contract.sh`: 92 contract tests passed.
- Final supported [Nightly run 32642989666](https://github.com/szTheory/rindle/actions/runs/32642989666), exact head `82f8c557d4e32831ce4a0fa61160b35b35bc632d`:
  - [Dialyzer job 97202854464](https://github.com/szTheory/rindle/actions/runs/32642989666/job/97202854464) failed with exactly E38 at `tus_creation.ex:35` and E39-E40 at `tus_stream.ex:163` and `:66`.
  - [Nightly Summary job 97203393276](https://github.com/szTheory/rindle/actions/runs/32642989666/job/97203393276) succeeded and logged `DIALYZER: failure`.

## Task Commits

1. **Task 1: expose historical runtime filters** — `f446e68`
2. **Task 1: record supported probe receipt** — `82f8c55`
3. **Task 2: record final runtime receipt** — `8805dd9`

## Decisions Made

- E04 keeps the optional MIME safe fallback; E05 keeps arbitrary runtime refusal normalization; E06-E07 keep ProcessVariant’s dynamic cancel/error and non-map fallback behavior.
- The known verification predicate typo was corrected only while checking the result: emitted E38 is `{:error, _}.`, not `{:error, _.}`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Verification predicate] Corrected the E38 warning-text assertion**
- **Found during:** Task 2 final supported receipt verification.
- **Issue:** The plan predicate used `{:error, _.}` while the supported annotation emits `{:error, _}.`.
- **Fix:** Reran the complete paginated annotation assertion with the exact emitted text.
- **Files modified:** None.
- **Verification:** The exact three-warning E38-E40 multiset passed.
- **Committed in:** Not applicable; verification-only correction.

**Total deviations:** 1 auto-fixed (Rule 1).
**Impact on plan:** None; product behavior and the supported result are unchanged.

## Known Stubs

None.

## Next Phase Readiness

Plans 126-05 and 126-06 can rely on a truthful intermediate receipt: E04-E07 are no longer emitted, no unowned warning exists, and only Plan 126-07’s E38-E40 TUS findings remain.

## Self-Check: PASSED

Verified the curated ignore list, evidence ledger, and summary exist; all three
task commits are reachable.
