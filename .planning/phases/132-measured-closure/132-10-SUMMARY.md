---
phase: 132-measured-closure
plan: 10
subsystem: ci-evidence
tags: [github-actions, coverage, excoveralls, ci-timing, preservation]
requires:
  - phase: 132-09
    provides: D-08 topology correction, source contract, and deterministic projection fixture
provides:
  - immutable preservation receipt for the D-08 topology subject
  - machine-derived authoritative COV-05 coverage census
  - read-only sampler preflight result with no GitHub mutation
affects: [132-11, CI-14, COV-05, SAFE-02]
tech-stack:
  added: []
  patterns: [fail-closed ExCoveralls parsing, immutable no-publish controller preflight]
key-files:
  created: [ .planning/phases/132-measured-closure/132-10-SUMMARY.md ]
  modified: [ .planning/phases/132-measured-closure/132-PRESERVATION-RECEIPT.md ]
key-decisions:
  - "COV-05 is closed only from one fresh ExCoveralls artifact parsed into integer covered and relevant counts."
  - "The PR-head mismatch is a fail-closed 132-11 publication-path blocker; this plan does not push, label, trigger, rerun, or sample."
patterns-established:
  - "Preservation receipts bind code-bearing correction, final subject, bounded diff, ordered authorities, and machine output in one artifact."
requirements-completed: [COV-05, SAFE-02]
coverage:
  - id: D1
    description: "Immutable D-08 topology preservation and SAFE-02 local backstops"
    requirement: SAFE-02
    verification:
      - kind: integration
        ref: "mix test test/install_smoke/ci_lane_split_test.exs test/install_smoke/ci_observability_test.exs test/install_smoke/ci_timing_automation_test.exs --seed 0"
        status: pass
      - kind: other
        ref: "bash scripts/ci/test_ci_summary_gate.sh && mix quality_signals && bash scripts/maintainer/refactor_contract.sh && ./scripts/maintainer/automation_first_contract.sh && ./scripts/maintainer/repo_hygiene_check.sh --ci"
        status: pass
    human_judgment: false
  - id: D2
    description: "Authoritative inclusive 82.13% coverage arithmetic"
    requirement: COV-05
    verification:
      - kind: integration
        ref: "mix coveralls.multiple --type local --type json; fail-closed jq parser"
        status: pass
    human_judgment: false
  - id: D3
    description: "CI-14 no-publish sampler preflight"
    requirement: CI-14
    verification:
      - kind: other
        ref: "bash scripts/ci/collect_pr_timing_receipt.sh preflight --no-publish"
        status: fail
    human_judgment: false
duration: 12min
completed: 2026-08-26
status: complete
---

# Phase 132 Plan 10: Recovery topology preservation census Summary

**Immutable D-08 topology evidence with one 82.1343% ExCoveralls census and a fail-closed no-publish PR-head preflight.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-08-26T21:18:00Z
- **Completed:** 2026-08-26T21:31:52Z
- **Tasks:** 1/1 executed
- **Files modified:** 2

## Accomplishments

- Bound the exact D-08 correction `11bfee5…` to preserved subject `5add065…` with a bounded, three-surface non-planning diff census.
- Ran all ordered local authorities, including a single coverage invocation; the machine-derived result is 5,149 / 6,269 (82.13431169245494%) and passes the inclusive 82.13% floor.
- Confirmed packed image consumption (22 tests) and no GitHub mutation from the sampler preflight: no owned label, state directory, controller lock, or new workflow run remains.

## Task Commits

1. **Task 1: Re-census and preflight the immutable recovery subject** - `eed5db1` (docs)

## Files Created/Modified

- `.planning/phases/132-measured-closure/132-PRESERVATION-RECEIPT.md` - immutable subjects, diff census, ordered command evidence, canonical coverage JSON, and fail-closed preflight result.
- `.planning/phases/132-measured-closure/132-10-SUMMARY.md` - execution outcome and Plan 132-11 handoff.

## Decisions Made

- COV-05 and SAFE-02 are backed only by current machine evidence; CI-14 remains open until Plan 132-11 records a successful API-backed ten-run receipt.
- PR #96 must be brought to `5add06528a45cc927079563138e71dd8459fe5d2` through the authorized publication path before sampling; the preflight mismatch is not bypassable locally.

## Deviations from Plan

None - plan executed exactly as written. The preflight's PR-head mismatch is an explicitly specified fail-closed outcome, not a deviation.

## Issues Encountered

The read-only controller preflight exited 1 because PR #96 points to `f3476633fdc459779a937c5dc3c7234379bd8ce3`, while the preserved local subject is `5add06528a45cc927079563138e71dd8459fe5d2`. The receipt records the condition exactly. No external state was changed.

## Known Stubs

None.

## Next Phase Readiness

Plan 132-11 is blocked until the authorized publication path aligns PR #96 with the preserved subject. Once aligned, it remains the sole live controller for CI-14; COV-05 and SAFE-02 local preservation evidence is complete.

---
*Phase: 132-measured-closure*
*Completed: 2026-08-26*
