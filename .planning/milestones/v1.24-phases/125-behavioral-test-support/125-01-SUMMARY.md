---
phase: 125-behavioral-test-support
plan: "01"
subsystem: testing
tags: [elixir, exunit, ecto-sandbox, excoveralls, async-isolation]
requires:
  - phase: 110
    provides: Process-local repository override and counting transaction double
provides:
  - 100-iteration causal proof that a bare process cannot observe a test-local repo override
  - Local-only, fail-fast 25-seed coverage evidence runner with sanitized JSONL evidence
affects: [125-10, async-isolation, maintainer-evidence]
tech-stack:
  added: []
  patterns: [causally coordinated bare-process test, fake-mix shell runner contract]
key-files:
  created: [scripts/maintainer/async_isolation_evidence.sh, test/install_smoke/async_isolation_evidence_runner_test.exs]
  modified: [test/rindle/config/repo_override_isolation_test.exs, RUNNING.md]
key-decisions:
  - "Use unique per-iteration message refs and a monitored bare reader to make each of 100 isolation windows independently diagnosable."
  - "Keep the 25 fresh coverage runs maintainer-local and fail-fast; Plan 125-10 owns executing the expensive matrix."
requirements-completed: [TEST-04, SAFE-01]
coverage:
  - id: D1
    description: "100 causally coordinated A/B repository-override isolation windows"
    requirement: TEST-04
    verification:
      - kind: integration
        ref: "MIX_ENV=test mix test test/rindle/config/repo_override_isolation_test.exs --seed 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "Local fail-fast 25-seed evidence runner with one coverage invocation per seed"
    requirement: TEST-04
    verification:
      - kind: integration
        ref: "test/install_smoke/async_isolation_evidence_runner_test.exs"
        status: pass
    human_judgment: false
  - id: D3
    description: "SAFE-01 preservation boundary remains green without CI or resolver changes"
    requirement: SAFE-01
    verification:
      - kind: integration
        ref: "bash scripts/maintainer/refactor_contract.sh"
        status: pass
    human_judgment: false
duration: 15min
completed: 2026-08-23
status: complete
---

# Phase 125 Plan 01: Behavioral Test Support Summary

**A 100-iteration causal repo-override proof and a contract-tested, local-only 25-seed coverage evidence runner.**

## Performance

- **Duration:** 15 min
- **Tasks:** 2/2
- **Files modified:** 4

## Accomplishments

- Repeated the open-override A/B isolation proof 100 times with distinct references, bounded receives, and monitored reader cleanup.
- Added a fixed 25-seed, one-foreground-process-per-seed evidence runner that stops on the first nonzero exit and stores allowlisted JSONL facts only.
- Documented the local protocol and explicit CI prohibition; full 25-process coverage execution remains intentionally deferred to Plan 125-10.

## Task Commits

1. **Task 1: Turn the causal isolation proof into a bounded high-iteration tracer** — `66c4157` (test)
2. **Task 2: Create the immutable fail-fast 25-seed evidence runner** — `31a951f` (test), `b9ab54e` (feat)

## Files Created/Modified

- `test/rindle/config/repo_override_isolation_test.exs` — bounded 100-iteration causal isolation tracer.
- `scripts/maintainer/async_isolation_evidence.sh` — strict local evidence runner with validation mode and sanitized reporting.
- `test/install_smoke/async_isolation_evidence_runner_test.exs` — fake-Mix behavioral contract for the runner.
- `RUNNING.md` — maintainer command and CI-topology prohibition.

## Decisions Made

- Each reader is created by bare `spawn_monitor`, never a Task descendant, and is released only after A has opened its override window.
- Evidence reports retain only iteration, seed, revision, toolchain, argv, exit status, and a bounded exception/location classifier; raw Mix output and environment values are excluded.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. The runner's controlled fake-Mix tests were used instead of the expensive 25-process coverage matrix, as required; Plan 125-10 owns that execution.

## Next Phase Readiness

The causal proof and local evidence contract are ready for the Phase 125 support refactors. The final evidence matrix remains pending Plan 125-10.

## Self-Check: PASSED

All four plan files and all three implementation commits (`66c4157`, `31a951f`, `b9ab54e`) exist.
