---
phase: 132-measured-closure
plan: 01
subsystem: testing
tags: [elixir, exunit, phoenix, install-smoke, ci]
requires:
  - phase: 131-signal-preserving-ci-velocity
    provides: Independently-starting required image package-consumer proof and pinned Phoenix generator.
provides:
  - Phoenix generation without a pre-patch dependency installation.
  - A focused source-bounded ExUnit contract for the generator argv.
affects: [132-02-preservation-census, 132-03-ci-timing-receipt, package-consumer]
tech-stack:
  added: []
  patterns: [Generate, patch, then fetch dependencies through the existing authoritative workspace path.]
key-files:
  created: []
  modified:
    - test/install_smoke/support/generated_app/workspace.ex
    - test/install_smoke/generated_app_smoke_test.exs
key-decisions:
  - "Remove only Phoenix's --install argv entry; retain the existing post-patch Workspace.fetch_deps!/3 authority."
  - "Pin the generator command through a bounded source-region contract rather than a broad file snapshot."
requirements-completed: [CI-14, SAFE-02]
coverage:
  - id: D1
    description: Phoenix generation omits pre-patch dependency installation while retaining its pinned command contract.
    requirement: CI-14
    verification:
      - kind: unit
        ref: mix test test/install_smoke/generated_app_smoke_test.exs --only phase_132_generator_contract
        status: pass
    human_judgment: false
  - id: D2
    description: The built-package image consumer retains clean-room package provenance, compile, migration, boot, and lifecycle proof.
    requirement: SAFE-02
    verification:
      - kind: integration
        ref: bash scripts/install_smoke.sh image
        status: pass
    human_judgment: false
metrics:
  duration: 4 min
  completed: 2026-08-25
status: complete
---

# Phase 132 Plan 01: Measured Closure Summary

**Phoenix generation now defers dependency retrieval until the existing post-patch clean-room package path, protected by a focused contract and real image-consumer proof.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-08-25T18:52:00Z
- **Completed:** 2026-08-25T18:56:31Z
- **Tasks:** 1/1
- **Files modified:** 2

## Accomplishments

- Added a tagged, bounded-source contract that preserves the generator root, four feature omissions, one command-runner call, and `MIX_ENV=dev` while rejecting `--install`.
- Removed only `--install` from `Workspace.generate_phoenix_app!/2`.
- Verified the real built-package image consumer through generation, patching, dependency fetch, compile, host-owned migration, boot, and lifecycle.

## Task Commits

1. **Task 1: Validate the post-patch-only dependency path through the real image consumer** - `1e1bd1c` (test, RED) and `1161029` (fix, GREEN)

## Files Created/Modified

- `test/install_smoke/generated_app_smoke_test.exs` - Adds the `:phase_132_generator_contract` source-bounded Phoenix argv contract.
- `test/install_smoke/support/generated_app/workspace.ex` - Removes the redundant generator-owned dependency install argument.

## Decisions Made

- Kept `Workspace.fetch_deps!/3` as the sole dependency acquisition path after generated-app patching, including its existing network retry behavior.
- Left the package-consumer orchestration, CI Summary topology, package provenance checks, and lifecycle assertions unchanged.

## Verification

- RED: `mix test test/install_smoke/generated_app_smoke_test.exs --only phase_132_generator_contract` failed on the pre-existing `--install` argument.
- GREEN: `mix test test/install_smoke/generated_app_smoke_test.exs --only phase_132_generator_contract` passed: `1 test, 0 failures`.
- Integration: `bash scripts/install_smoke.sh image` passed: the clean-room suite completed with `17 tests, 0 failures`.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 02 can perform the required preservation census against this narrow correction. The live ten-run timing receipt remains Plan 03 work.

## Self-Check: PASSED

- Both declared implementation files exist and their two task commits are present in git history.
