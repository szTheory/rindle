---
phase: 136-measured-quality-and-ci-ratchets
plan: 08
status: complete
subsystem: ci
tags: [timing, immutable-subject, fake-github]
requires:
  - phase: 135
    provides: Verified prerequisite
provides:
  - Explicit current-preflight/current-run modes without fabricated transition history
  - Pinned verify mode and pre-existing published-run boundary
affects: [136-final-timing]
tech-stack:
  added: []
  patterns: [explicit immutable subject, authenticated run population]
key-files:
  created: []
  modified: [scripts/ci/collect_pr_timing_receipt.sh, test/install_smoke/ci_timing_automation_test.exs]
key-decisions:
  - Current mode requires detached local HEAD and already-published matching PR SHA; publication is refused.
  - Preserve historical transition validation and the existing API-backed verifier.
  - Record completed pre-existing same-head PR runs as the initial population boundary before current sampling.
requirements-completed: [CI-16]
coverage:
  - id: current-timing
    description: Exact pinned subject collection and API verification without historical transition authority
    verification:
      - kind: unit
        ref: mix test test/install_smoke/ci_timing_automation_test.exs --seed 0
        status: pass
    human_judgment: false
duration: 8min
completed: 2026-10-20
---

# Phase 136 Plan 08: Current-Subject Timing Mode

Current-preflight/current-run accept an explicit full SHA equal to detached local HEAD and the already-published PR head. They validate the sole required-check authority and active CI workflow identity before labels, retain ownership/locks/deadlines and exactly ten sequential samples, and refuse implicit publication. Verify accepts --subject-sha so evidence-only HEAD advances cannot silently rebind a receipt.

## Accomplishments

- Current path reaches the existing bounded state/receipt machinery with no Phase 132 transition manifest.
- Historical preflight/run still require and authenticate their unchanged transition chronology.
- Completed runs from initial PR publication form an explicit recorded population boundary; active existing runs refuse new sampling. Unexpected final population drift terminalizes the state rather than leaving an invalid running state.
- Tests reject foreign SHA, authority changes, publication attempts, wrong sample counts, non-success summary and missing/extra/duplicate receipt runs. Inclusive median/p95 boundaries and evidence-only HEAD advances are covered.

## Task Commits

1. RED 6341191e; GREEN 8bff2c5a — current-subject tracer and mode.
2. RED 9fd2597a; GREEN f954dc09 — published-run boundary and receipt mutations.

## Verification

- Final focused suite: 32 tests, 0 failures (55.5 seconds).
- Both preserved JUnit assertion-failure reports returned RED_EVIDENCE_OK.
- Bash syntax and whitespace passed.
- All GitHub API/run/label activity was fake fixture activity. No live timing receipt, publication or CI-16 qualification credit claimed.

## Deviations

The already-published head case revealed the initial publication run would contaminate the new exact-ten population. The current-mode boundary fix uses the existing shared list/selection authority and recorded boundary field; historical mode retains its behavior. Final population mismatch now persists a terminal failed state.

## Issues Encountered

None outstanding for implementation. Actual required-lane and speed evidence remain Plan 07 work after final source freeze and separately authorized publication.

## Next Phase Readiness

Wave 1 implementation complete. Continue Plan 06 after combined Wave 1 verification.

## Self-Check: PASSED
