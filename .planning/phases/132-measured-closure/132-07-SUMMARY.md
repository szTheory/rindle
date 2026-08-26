---
phase: 132-measured-closure
plan: 07
subsystem: ci-preservation-evidence
tags: [ci, coverage, safe-02, packed-consumer, evidence]
requires:
  - phase: 132-06
    provides: Bounded install-first apt remediation and executable helper contracts.
provides:
  - Immutable post-remediation subject bound to ordered preservation authorities.
  - One-run authoritative coverage arithmetic above the inclusive COV-05 floor.
  - Exact prohibited-surface and required-gate topology census before live sampling.
affects: [ci-14, cov-05, safe-02, phase-132-timing-receipt]
tech-stack:
  added: []
  patterns: [immutable-subject evidence, single-run coverage arithmetic, ordered preservation authorities]
key-files:
  created: [.planning/phases/132-measured-closure/132-07-SUMMARY.md]
  modified: [.planning/phases/132-measured-closure/132-PRESERVATION-RECEIPT.md]
decisions:
  - Preserve full HEAD 0696c49896f34f8747a38fbe6ac08fa2c3355b05 as the final post-Plan-06 evidence subject.
  - Accept COV-05 only from the single fresh 5149/6269 coverage artifact using inclusive integer arithmetic.
requirements-completed: [CI-14, COV-05, SAFE-02]
coverage:
  - id: D1
    description: Final remediation subject retains executable COV-05 and SAFE-02 preservation evidence.
    requirement: COV-05
    verification:
      - kind: integration
        ref: mix coveralls.multiple --type local --type json
        status: pass
      - kind: integration
        ref: bash scripts/install_smoke.sh image
        status: pass
    human_judgment: false
  - id: D2
    description: Required CI summary topology and skip-as-pass contract remain unchanged before live sampling.
    requirement: SAFE-02
    verification:
      - kind: unit
        ref: test/install_smoke/ci_lane_split_test.exs + test/install_smoke/ci_observability_test.exs
        status: pass
      - kind: other
        ref: bash scripts/ci/test_ci_summary_gate.sh
        status: pass
    human_judgment: false
metrics:
  duration: 10 minutes
  completed: 2026-08-26
  tasks_completed: 1
  files_modified: 2
status: complete
---

# Phase 132 Plan 07: Final Preservation Census Summary

The post-apt-remediation subject is bound to fresh ordered quality, SAFE-01, hygiene, coverage, topology, and packed-image authorities, with COV-05 confirmed at 82.1343% by one authoritative run.

## Tasks Completed

| Task | Description | Commit |
| --- | --- | --- |
| 1 | Re-census the immutable remediation subject | `5ae4312` |

## Accomplishments

- Recorded full immutable subject `0696c49896f34f8747a38fbe6ac08fa2c3355b05` and its exact measured-head diff census.
- Ran focused topology, summary, quality, SAFE-01, automation-first, hygiene, single-run coverage, and packed-image authorities in the required order; all passed.
- Derived `5149 / 6269 = 82.1343%` from the non-empty JSON artifact and recorded the inclusive integer threshold proof.

## Verification

- `mix test test/install_smoke/ci_cache_hygiene_test.exs test/install_smoke/ci_lane_split_test.exs test/install_smoke/ci_observability_test.exs --seed 0` — 49 tests passed.
- `bash scripts/ci/test_ci_summary_gate.sh` — 6 checks passed.
- `mix quality_signals`, `bash scripts/maintainer/refactor_contract.sh`, `./scripts/maintainer/automation_first_contract.sh`, and `./scripts/maintainer/repo_hygiene_check.sh --ci` — passed.
- `mix coveralls.multiple --type local --type json` — passed once; JSON was non-empty with 5,149 covered / 6,269 relevant entries.
- `bash scripts/install_smoke.sh image` — passed.

## Decisions Made

- The evidence subject is the full post-Plan-06 HEAD; its only non-planning changes from the measured head are the approved apt helper and helper contract.
- Equality is inclusive for both the 82.13% coverage floor and the subsequent 480-second median / 600-second p95 timing receipt.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None. No new network endpoint, authentication path, file-access pattern, or trust-boundary schema change was introduced.

## Next Phase Readiness

Plan 132-08 can collect the comparable live CI-14 sample against the preserved subject. It must retain the recorded subject identity and resolve CI-14 only through automated timing evidence.

## Self-Check: PASSED

- Confirmed the preservation receipt and this summary exist.
- Confirmed task commit `5ae4312` exists in git history.
