---
phase: 136-measured-quality-and-ci-ratchets
plan: 01
status: complete
subsystem: testing
tags: [credo, quality, removal-only]
requires:
  - phase: 135
    provides: Verified supported runtime and complexity inventory
provides:
  - Stable identity metric-vector complexity ceilings with tested behavior evidence
  - Executable retained-finding removal predicates
affects: [136-quality-qualification]
tech-stack:
  added: []
  patterns: [source-bound behavior evidence]
key-files:
  created: [scripts/maintainer/credo_removal_evidence.json]
  modified:
    - scripts/maintainer/credo_quality_normalize.exs
    - scripts/maintainer/credo_quality.sh
    - scripts/maintainer/credo_complexity_baseline.json
    - test/install_smoke/credo_policy_test.exs
key-decisions:
  - Keep all reviewed metrics and counts; no speculative application refactor or removal.
  - Use accepted Elixir 1.17.3 / OTP 27.3.4.15 through environment overrides; leave .tool-versions unchanged.
requirements-completed: [MAINT-04]
coverage:
  - id: complexity-policy
    description: Stable identity removal-only gate and executable retained triggers
    requirement: MAINT-04
    verification:
      - kind: unit
        ref: mix test test/install_smoke/credo_policy_test.exs --seed 0
        status: pass
      - kind: integration
        ref: MIX_ENV=test mix credo_quality
        status: pass
    human_judgment: false
duration: 14min
completed: 2026-10-20
---

# Phase 136 Plan 01: Removal-only Credo Policy

Stable check/file/trigger identities now compare descending metric vectors and occurrence counts against reviewed ceilings. Equal observations pass; growth fails; missing or lower observations require exact before/after vectors, current source SHA and an actually passing named behavior test. Stale, failed, empty-test and recursive proof cannot authorize a reduction.

## Accomplishments

- Removed frozen inventory-size enforcement. Singleton, empty, duplicate-metric and reordered inventories have executable verdicts.
- Replaced opaque removal prose with validated observed_metric predicates (complexity <=9, nesting <=2). Retained all 22 tuple records / 24 occurrences and their exact metrics.
- Added empty evidence ledger because no real finding was removed or reduced.

## Task Commits

1. RED 0baf5fed; GREEN ca400837 — stable identity vector comparator.
2. RED ffbb919a; GREEN 30acff33 — executable removal predicates and expanded evidence fixtures.

## Verification

- Supported runtime: Elixir 1.17.3 / OTP 27.3.4.15, MIX_ENV=test.
- Focused suite: 11 tests, 0 failures (47.8 seconds).
- Live mix credo_quality: passed all three profiles and comparison.
- Bash syntax, git diff --check and automation-first contract: passed.
- Both preserved JUnit RED reports returned RED_EVIDENCE_OK; target assertions failed for the intended policy gaps, with all unrelated tests passing.

## Deviations

GSD base-check selected sequential inline execution because recovery HEAD differs from origin/HEAD. Renamed the recovery branch from its reserved executor prefix to gsd/phase-136-execution. Initial copied dependency cache did not match the current lock; restored existing locked packages without changing mix.lock or adding dependencies. Hex failed persisting its global cache after fetching; subsequent compilation and tests completed normally from the isolated copies.

## Issues Encountered

None outstanding for this plan. MAINT-04 remains pending at phase level until final-subject evidence and all declaring plans close.

## Next Phase Readiness

Ready for remaining Wave 1 plans. Final qualification has not run.

## Self-Check: PASSED

## Wave 1 Review Follow-up

RED efc247c8 demonstrated a wholly skipped behavior test could authorize a reduction; GREEN fbb66229 rejects skipped, excluded or invalid named tests. Preserved 136-01-SKIPPED-RED.json returned RED_EVIDENCE_OK. Full policy suite after the fix: 11 tests, 0 failures (51.9s); live Credo passed. No reviewed metric/count change.
