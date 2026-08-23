---
phase: 125-behavioral-test-support
plan: "04"
subsystem: testing
tags: [elixir, exunit, phoenix, generated-app, patcher]
requires:
  - phase: 125-03
    provides: Stable GeneratedAppHelper facade with focused Contract, CommandRunner, and Workspace owners
provides:
  - Hidden generated Phoenix Patcher with explicit resolved patch inputs
  - Generated image consumer proof at compile, boot, smoke, and report boundaries
affects: [125-05, 125-06, generated-app-support]
tech-stack:
  added: []
  patterns: [explicit patcher inputs, generated-consumer outcome proof]
key-files:
  created: [test/install_smoke/support/generated_app/patcher.ex]
  modified: [test/install_smoke/support/generated_app_helper.ex, test/install_smoke/generated_app_smoke_test.exs]
key-decisions:
  - "Keep GeneratedAppHelper as the stable public test facade and make Patcher test-private."
  - "Resolve Oban and Mux mode facts in the facade, then pass them explicitly so Patcher does not own environment/package/command state."
requirements-completed: [TEST-01, TEST-02, SAFE-01]
coverage:
  - id: D1
    description: "Image generated consumer reaches compile, boot, smoke, lifecycle, and report outcomes through the stable facade"
    requirement: TEST-02
    verification:
      - kind: integration
        ref: "MIX_ENV=test mix test test/install_smoke/generated_app_smoke_test.exs --seed 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "Patcher owns generated Phoenix config, router, application, profile, and Mux fixture effects while the facade preserves migration, command, and reporting ownership"
    requirement: TEST-01
    verification:
      - kind: integration
        ref: "MIX_ENV=test mix test test/install_smoke/generated_app_smoke_test.exs --seed 0"
        status: pass
      - kind: integration
        ref: "bash scripts/maintainer/refactor_contract.sh"
        status: pass
    human_judgment: false
  - id: D3
    description: "SAFE-01 protected product and release boundaries remain unchanged"
    requirement: SAFE-01
    verification:
      - kind: integration
        ref: "bash scripts/maintainer/refactor_contract.sh"
        status: pass
    human_judgment: false
duration: 18min
completed: 2026-08-23
status: complete
---

# Phase 125 Plan 04: Generated Phoenix Patcher Summary

**Profile-aware Phoenix source patching now has one hidden owner while the generated consumer continues to prove compile, boot, and lifecycle behavior through the stable facade.**

## Performance

- **Duration:** 18 min
- **Tasks:** 2/2
- **Files modified:** 3

## Accomplishments

- Added an image tracer assertion that observes generated-consumer compile, boot, smoke, lifecycle, and report facts without reading support source.
- Extracted generated `mix.exs`, config, router, LiveView, Mux fixture/config, application-child, and profile patching into `GeneratedApp.Patcher`.
- Kept package selection, environment resolution, command execution, migration generation, smoke-source generation, and report shaping in the facade/workspace owners.

## Task Commits

1. **Task 1: Lock one real generated Phoenix patch path at the compiled boundary** — `bc86b6f` (test)
2. **Task 2: Extract profile-aware Phoenix patching into Patcher** — `4a98a8a` (refactor)

## Files Created/Modified

- `test/install_smoke/support/generated_app/patcher.ex` — hidden effect owner for generated Phoenix source/config patching.
- `test/install_smoke/support/generated_app_helper.ex` — stable facade that resolves and passes all patch facts explicitly.
- `test/install_smoke/generated_app_smoke_test.exs` — generated-consumer image boundary assertion.

## Decisions Made

- Patcher receives the resolved package/network, profile, compile-prefix, Oban, and Mux-mode facts; it does not read package/profile state, run commands, write migrations, or normalize reports.
- Existing tagged tus/mux/gcs generated-app cases remain the profile matrix authority rather than adding patcher-source snapshots.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## Next Phase Readiness

The facade now isolates generated Phoenix patch effects behind Patcher; Plan 125-05 can extract migration/report effects without taking over source patching.

## Self-Check: PASSED

The Patcher, facade, and generated-consumer test files exist; task commits `bc86b6f` and `4a98a8a` are present in git history.
