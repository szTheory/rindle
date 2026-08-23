---
phase: 125-behavioral-test-support
plan: "03"
subsystem: testing
tags: [elixir, exunit, command-runner, workspace, generated-app]
requires:
  - phase: 125-02
    provides: Stable GeneratedAppHelper facade and pure Contracts owner
provides:
  - Bounded stage-aware CommandRunner with structured result and fail-fast raising behavior
  - Workspace owner for temporary roots, generated-consumer setup, package provenance, environments, and cleanup
affects: [125-04, generated-app-support]
tech-stack:
  added: []
  patterns: [explicit child command argv/env, workspace lifecycle owner]
key-files:
  created: [test/install_smoke/support/generated_app/command_runner.ex, test/install_smoke/support/generated_app/workspace.ex]
  modified: [test/install_smoke/support/generated_app_helper.ex, test/install_smoke/generated_app_smoke_test.exs]
key-decisions:
  - "CommandRunner receives explicit cwd, argv, env, stage, and optional test-only timeout; the production facade still supplies 20 minutes."
  - "Workspace owns temporary paths, package/network provenance, dependency preparation, and cleanup without selecting a profile."
requirements-completed: [TEST-01, TEST-02, SAFE-01]
coverage:
  - id: D1
    description: "Executed fast-success, nonzero, and short-timeout command behavior"
    requirement: TEST-02
    verification:
      - kind: integration
        ref: "MIX_ENV=test mix test test/install_smoke/generated_app_smoke_test.exs --only phase_120_upgrade_contract --seed 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "Workspace allocation and idempotent cleanup behavior under the OS temporary root"
    requirement: TEST-01
    verification:
      - kind: unit
        ref: "test/install_smoke/generated_app_smoke_test.exs#generated workspaces use OS-global temporary directory allocation"
        status: pass
    human_judgment: false
  - id: D3
    description: "SAFE-01 preservation boundaries remain green"
    requirement: SAFE-01
    verification:
      - kind: integration
        ref: "bash scripts/maintainer/refactor_contract.sh"
        status: pass
    human_judgment: false
duration: 23min
completed: 2026-08-23
status: complete
---

# Phase 125 Plan 03: Behavioral Test Support Summary

**Generated command execution and workspace lifecycle now have explicit hidden owners with executable timeout, diagnostics, allocation, and cleanup proof.**

## Performance

- **Duration:** 23 min
- **Tasks:** 2/2
- **Files modified:** 4

## Accomplishments

- Replaced the command-runner source snapshot with fast success, nonzero-stage, raising, and timeout execution checks.
- Moved foreground child-command execution, the 20-minute default, stage-labelled result shaping, and brutal timeout shutdown into `CommandRunner`.
- Moved OS-global temporary allocation, cleanup, package/network provenance, generated-app preparation, dependency fetching, and profile environment construction into `Workspace`.

## Task Commits

1. **Task 1: Prove bounded child-command behavior and extract CommandRunner** — `417fe17` (refactor)
2. **Task 2: Prove real temporary roots and extract Workspace** — `7fd1a52` (refactor)

## Files Created/Modified

- `test/install_smoke/support/generated_app/command_runner.ex` — bounded explicit child-process owner.
- `test/install_smoke/support/generated_app/workspace.ex` — temporary workspace, provenance, environment, dependency, and cleanup owner.
- `test/install_smoke/support/generated_app_helper.ex` — stable facade delegates command and workspace mechanics.
- `test/install_smoke/generated_app_smoke_test.exs` — executed command and workspace behavior checks.

## Decisions Made

- `CommandRunner.run/4` accepts a short timeout only as an explicit test input; production calls retain the existing 20-minute wrapper timeout.
- `Workspace.cleanup/1` is idempotent, allowing test cleanup paths to safely run after an earlier assertion cleanup.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Normalized OS temporary-root paths in the allocation proof**

- **Found during:** Task 2
- **Issue:** macOS returned `System.tmp_dir!/0` with a trailing slash while `Path.dirname/1` omits it.
- **Fix:** Compared normalized paths with `Path.expand/1`.
- **Files modified:** `test/install_smoke/generated_app_smoke_test.exs`
- **Verification:** Full generated-app suite and SAFE-01 pass.
- **Committed in:** `7fd1a52`

**Total deviations:** 1 auto-fixed (Rule 1)

## Next Phase Readiness

The facade now has explicit Contracts, CommandRunner, and Workspace seams. Plan 125-04 can isolate generated Phoenix patching without re-owning command or workspace effects.

## Self-Check: PASSED

All four plan files and both task commits (`417fe17`, `7fd1a52`) exist.
