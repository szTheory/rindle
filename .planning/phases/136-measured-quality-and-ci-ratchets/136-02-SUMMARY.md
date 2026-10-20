---
phase: 136-measured-quality-and-ci-ratchets
plan: 02
status: complete
subsystem: testing
tags: [dialyzer, plt, removal-only]
requires:
  - phase: 135
    provides: Supported runtime and reviewed ignores
provides:
  - Exact Dialyxir matcher characterization
  - Byte-exact fresh and restored analysis transcript fixtures
affects: [136-final-evidence]
tech-stack:
  added: []
  patterns: [exact warning identities, immutable first-red evidence]
key-files:
  created: []
  modified: [test/install_smoke/dialyzer_ignore_policy_test.exs, scripts/ci/test_nightly_dialyzer.sh]
key-decisions:
  - Retain every live suppression pending final supported analysis; no speculative narrowing.
  - Existing production behavior passes characterization, so changes are test-only rather than an invented RED implementation cycle.
requirements-completed: [TYPE-03]
coverage:
  - id: narrow-identities
    description: Exact approved subset and actual Dialyxir matcher behavior
    verification:
      - kind: unit
        ref: mix test test/install_smoke/dialyzer_ignore_policy_test.exs --seed 0
        status: pass
    human_judgment: false
  - id: plt-mode-contracts
    description: Fresh/restored status and exact first-red transcript preservation
    verification:
      - kind: unit
        ref: bash scripts/ci/test_nightly_dialyzer.sh
        status: pass
    human_judgment: false
duration: 5min
completed: 2026-10-20
---

# Phase 136 Plan 02: Narrow Dialyzer Policy

Approved suppressions remain removal-only; matcher-level fixtures distinguish the documented migration up/0 warning from other functions and files, and deleting its exact filter exposes it. Every approved identity is tested against duplicate, regex, file-wide and truncated-description mutations.

## Task Commits

1. e7ad0d82 — exact warning identity characterization.
2. a383112b — exact first-red transcript assertions for fresh/restored runner fixtures.

## Verification

- Elixir 1.17.3 / OTP 27.3.4.15, MIX_ENV=test: 5 tests, 0 failures.
- Nightly runner harness: passed 45, failed 0. Includes fresh genuine warning, restored success, one stale rebuild, missing/corrupt PLT, arbitrary analysis failure, failed rebuild and failed reanalysis.
- Persisted transcript comparisons retain first-red bytes before successful or failed reanalysis.
- Bash syntax and git diff --check pass.

## Deviations

Production subset and recovery behavior already met the requested contract. Added characterization and preservation tests without changing .dialyzer_ignore.exs or the production runner. Initial fixture expectations used a logical temporary path; runner intentionally resolves physical paths, so fixture comparisons now resolve the same physical directory. No production change was needed.

The matcher warning is a fixture of the exact warning identity documented in the current ignore list, not a fresh analyzer result. Fresh/restored supported analysis remains Plan 09 work. TYPE-03 remains Pending; fixture success grants no measured qualification credit.

## Issues Encountered

None outstanding for implementation.

## Next Phase Readiness

Final-source collector can use the existing fresh/restored runner and its logs. Continue Wave 1 Plan 04.

## Self-Check: PASSED
