---
phase: 125-behavioral-test-support
plan: "06"
subsystem: testing
tags: [elixir, exunit, phoenix, tus, generated-app, package-consumer]
requires:
  - phase: 125-05
    provides: Hidden migration/catalog owner behind the stable generated-app facade
provides:
  - Hidden generated SmokeSource and ProfileHelpers owners
  - Compiled-public-contract tus parity without implementation-file snapshots
  - Packed image consumer proof for the unchanged facade
affects: [125-07, generated-app-support]
tech-stack:
  added: []
  patterns: [generated source ownership, compiled metadata parity, packed consumer proof]
key-files:
  created: [test/install_smoke/support/generated_app/smoke_source.ex, test/install_smoke/support/generated_app/profile_helpers.ex]
  modified: [test/install_smoke/support/generated_app_helper.ex, test/install_smoke/generated_app_smoke_test.exs, test/install_smoke/phoenix_tus_truth_parity_test.exs]
key-decisions:
  - "Keep generated lifecycle bodies in SmokeSource and profile-specific emitted helpers in ProfileHelpers behind the stable facade."
  - "Assert tus public capability through exports and compiled docs rather than private library/helper source text."
requirements-completed: [TEST-01, TEST-02, SAFE-01]
coverage:
  - id: D1
    description: "Generated profile source remains behind focused hidden owners"
    requirement: TEST-01
    verification:
      - kind: integration
        ref: "MIX_ENV=test mix test test/install_smoke/generated_app_smoke_test.exs --seed 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "Tus parity uses compiled exports/docs and generated-app report contracts, not helper snapshots"
    requirement: TEST-02
    verification:
      - kind: integration
        ref: "MIX_ENV=test mix test test/install_smoke/generated_app_smoke_test.exs test/install_smoke/phoenix_tus_truth_parity_test.exs --seed 0"
        status: pass
    human_judgment: false
  - id: D3
    description: "Packed image consumer builds, unpacks, compiles, migrates, boots, and passes generated smoke without local fallback"
    requirement: SAFE-01
    verification:
      - kind: integration
        ref: "bash scripts/install_smoke.sh image (21 tests, 0 failures, 154.1s)"
        status: pass
    human_judgment: false
duration: 32min
completed: 2026-08-23
status: complete
---

# Phase 125 Plan 06: Generated Profile Source Summary

**Generated lifecycle/profile templates now have focused hidden owners, while tus parity proves public compiled capability and the packed image consumer remains green.**

## Accomplishments

- Extracted emitted lifecycle/upgrade test bodies into `SmokeSource` and profile-specific helpers/imports/tags/app naming into `ProfileHelpers`.
- Removed Phoenix tus implementation-file reads; parity now checks shipped guides, public exports, compiled docs, and storage capabilities.
- Verified the packaged image consumer cleanly: 21 tests, zero failures, 154.1 seconds.

## Task Commits

1. **Task 1: Extract emitted lifecycle source by cohesive generated responsibility** — `4367aa6` (refactor)
2. **Task 2: Replace Phoenix tus source snapshots and prove packed facade authority** — `718cac4` (test)
3. **Task 2 fixes: generated report contract** — `cdcc23b`, `b06369c` (test)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed nested JSON string-key access in generated report handling**
- **Commit:** `cdcc23b`

**2. [Rule 1 - Bug] Exposed host migration paths in the isolation report contract**
- **Commit:** `b06369c`

## Verification

- `MIX_ENV=test mix test test/install_smoke/generated_app_smoke_test.exs test/install_smoke/phoenix_tus_truth_parity_test.exs --seed 0` — pass.
- `bash scripts/maintainer/refactor_contract.sh` — pass.
- `bash scripts/install_smoke.sh image` — pass (21 tests, 0 failures, 154.1s).
- `mix format --check-formatted` for all Plan 125-06 code/test files — pass.

## Self-Check: PASSED

All declared artifacts exist and commits `4367aa6`, `718cac4`, `cdcc23b`, and `b06369c` are present.
