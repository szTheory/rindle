---
phase: 121-truthful-quality-signals-mechanical-hygiene
plan: 01
subsystem: testing
tags: [elixir, exunit, bash, regression-contract, safe-01]
requires:
  - phase: 121-02
    provides: Current telemetry documentation required by the existing contract suite.
provides:
  - One deterministic SAFE-01 preservation runner for later refactor slices.
  - A shipped structural lock for runner membership and truthful failure propagation.
affects: [phases-122-126, refactor-verification, ci-contracts]
tech-stack:
  added: []
  patterns:
    - Explicit serial Mix test file lists for behavior-preservation proof.
    - Structural ExUnit checks for shell runner truthfulness without prose snapshots.
key-files:
  created:
    - scripts/maintainer/refactor_contract.sh
    - test/install_smoke/refactor_contract_test.exs
  modified: []
key-decisions:
  - "Use --include contract so telemetry tests excluded by default run alongside the explicit SAFE-01 file list."
  - "Use exec with set -euo pipefail for a single foreground Mix process and direct exit-status propagation."
patterns-established:
  - "SAFE-01 runners must name their contract files explicitly, remain independent of .planning, and avoid background or masking shell constructs."
requirements-completed: [SAFE-01]
coverage:
  - id: D1
    description: "Executable SAFE-01 runner covers public API, schema/migration, telemetry, errors, and CI/release invariants in one foreground command."
    requirement: SAFE-01
    verification:
      - kind: integration
        ref: "bash scripts/maintainer/refactor_contract.sh"
        status: pass
    human_judgment: false
  - id: D2
    description: "Structural regression lock prevents an empty, partial, planning-coupled, backgrounded, or failure-masked SAFE-01 runner."
    requirement: SAFE-01
    verification:
      - kind: unit
        ref: "test/install_smoke/refactor_contract_test.exs"
        status: pass
    human_judgment: false
duration: 5min
completed: 2026-08-22
status: complete
---

# Phase 121 Plan 01: SAFE-01 Preservation Runner Summary

**One executable SAFE-01 command now proves API, schema, telemetry, error, and CI/release contracts through a serial, failure-propagating Mix invocation.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-08-22T21:54:13Z
- **Completed:** 2026-08-22T21:59:09Z
- **Tasks:** 2/2
- **Files modified:** 2

## Accomplishments

- Added an executable repository-root-aware runner with an explicit eight-file preservation suite and the existing telemetry contract tag enabled.
- Kept output native and failure status truthful through strict Bash mode and one foreground `exec mix test` process.
- Added a shipped structural contract that checks executable status, domain coverage, tag inclusion, single-process composition, and prohibited masking/background constructs.

## Task Commits

1. **Task 1: Wire one SAFE-01 command through every preserved contract domain** — `b7727db` (`test`)
2. **Task 2: Lock SAFE-01 membership and edge behavior as a shipped structural contract** — `86532e6` (`test`), `77a2ab3` (`style`)

## Files Created

- `scripts/maintainer/refactor_contract.sh` — strict, root-resolving SAFE-01 regression entry point.
- `test/install_smoke/refactor_contract_test.exs` — structural integrity lock for the shipped runner.

## Decisions Made

- Used `--include contract`, rather than `--only contract`, so default-excluded telemetry coverage runs without turning the other explicit files into empty selections.
- Used a direct `exec mix test` file list rather than composition pipelines or background work so Mix output and exit status remain authoritative.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Initial tracer verification exposed the known stale telemetry-guide assertion. It was owned and repaired by concurrent Plan 121-02; after commit `1ca9f2e`, fresh SAFE-01 verification passed with 86 tests.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Self-Check: PASSED

- Both shipped files exist.
- Task commits `b7727db`, `86532e6`, and `77a2ab3` exist in git history.
- Focused structural verification and the root-independent SAFE-01 runner both pass.

## Next Phase Readiness

Later refactor plans can invoke `bash scripts/maintainer/refactor_contract.sh` as the behavior-preservation gate.
