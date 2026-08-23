---
phase: 125-behavioral-test-support
plan: "02"
subsystem: testing
tags: [elixir, exunit, generated-app, contracts, facade]
requires:
  - phase: 125-01
    provides: SAFE-01-preserving behavioral test-support baseline
provides:
  - Hidden pure generated-app contract owner behind the unchanged helper facade
  - Report/catalog outcome assertions instead of upgrade helper implementation snapshots
affects: [125-03, 125-04, generated-app-support]
tech-stack:
  added: []
  patterns: [hidden pure contract owner, facade parity table]
key-files:
  created: [test/install_smoke/support/generated_app/contracts.ex]
  modified: [test/install_smoke/support/generated_app_helper.ex, test/install_smoke/generated_app_smoke_test.exs]
key-decisions:
  - "Keep GeneratedAppHelper as every consumer-facing contract and scenario entry point; Contracts is test-private."
  - "Treat catalog preservation and required report keys as observable behavior, not helper source wording."
requirements-completed: [TEST-01, TEST-02, SAFE-01]
coverage:
  - id: D1
    description: "Mutation-based isolation-upgrade catalog and report contract assertions"
    requirement: TEST-02
    verification:
      - kind: integration
        ref: "MIX_ENV=test mix test test/install_smoke/generated_app_smoke_test.exs --only phase_120_upgrade_contract --seed 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "Stable facade delegates pure contract maps, predicates, and representative reject cases"
    requirement: TEST-01
    verification:
      - kind: unit
        ref: "test/install_smoke/generated_app_smoke_test.exs#stable facade preserves every pure contract and scenario predicate"
        status: pass
    human_judgment: false
  - id: D3
    description: "SAFE-01 product and release boundaries remain unchanged"
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

# Phase 125 Plan 02: Behavioral Test Support Summary

**Generated-app report/catalog contracts now have a hidden pure owner while existing callers continue through an identical facade.**

## Performance

- **Duration:** 18 min
- **Tasks:** 2/2
- **Files modified:** 3

## Accomplishments

- Replaced upgrade report/catalog source snapshots with required-key and mutation-outcome assertions.
- Created `GeneratedApp.Contracts` for contract maps, catalog validation, scenario predicates, migration-source contracts, and profile selection.
- Preserved `GeneratedAppHelper` symbols and added parity coverage over contract maps, valid/invalid catalog reports, profile, and scenario predicates.

## Task Commits

1. **Task 1: Replace upgrade helper snapshots with explicit report and predicate behavior** — `ca525a7` (test)
2. **Task 2: Extract pure contracts behind the GeneratedAppHelper facade** — `21ead9d` (refactor)

## Files Created/Modified

- `test/install_smoke/support/generated_app/contracts.ex` — hidden pure owner for generated-app contracts and catalog validators.
- `test/install_smoke/support/generated_app_helper.ex` — requires Contracts before compilation and delegates stable facade functions.
- `test/install_smoke/generated_app_smoke_test.exs` — report/predicate behavior and facade-parity proof.

## Decisions Made

- The helper retains the unchanged public test-facing facade; the extracted module is test-only with hidden callable seams.
- Remaining source reads concern command/workspace behavior only and are deliberately deferred to Plan 125-03.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Preserved generated index-name interpolation after extraction**

- **Found during:** Task 2
- **Issue:** Removing the helper-local index constant left the generated migration report with an undefined module attribute.
- **Fix:** Moved the canonical index list into `Contracts.expected_media_variants_indexes/0` and used that owner at the interpolation site.
- **Files modified:** `test/install_smoke/support/generated_app/contracts.ex`, `test/install_smoke/support/generated_app_helper.ex`
- **Verification:** Full generated-app suite and SAFE-01 pass.
- **Committed in:** `21ead9d`

**Total deviations:** 1 auto-fixed (Rule 1)

## Issues Encountered

None beyond the extraction-boundary bug fixed above.

## Next Phase Readiness

The pure contract seam is ready for Plan 125-03 to extract command and workspace effects while preserving the same facade.

## Self-Check: PASSED

All three plan files and both task commits (`ca525a7`, `21ead9d`) exist.
