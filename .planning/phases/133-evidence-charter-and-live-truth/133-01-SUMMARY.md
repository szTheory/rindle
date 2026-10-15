---
phase: 133-evidence-charter-and-live-truth
plan: "01"
subsystem: testing
tags: [elixir, exunit, evidence, canonical-json, git]
requires: []
provides:
  - SHA-bound deterministic evidence census receipts with explicit worktree authority
  - Fail-closed twelve-dimension detector, candidate disposition, and transition validation
  - Mutation-tested stable candidate identity contract for the Phase 133 freeze
affects: [phase-133-plan-06, phase-135, phase-136, quality-census]
actuals:
  tokens: 12812
  tasks: 2
  commits: 6
tech-stack:
  added: []
  patterns:
    - Separate reviewed candidate ledger from generated exact-head receipt
    - Recursively key-sorted and semantic-ID-sorted canonical JSON
    - Reviewer-owned candidate IDs with digest-bound Phase 133 transitions
key-files:
  created:
    - scripts/maintainer/evidence_census.exs
    - scripts/maintainer/validate_evidence_census.exs
    - test/install_smoke/evidence_census_test.exs
  modified: []
key-decisions:
  - "Keep the reviewed ledger outside the inspected subject so its recorded subject SHA does not become self-referential."
  - "Bind candidates, their reviewed baseline, and Phase 133 transitions into one canonical candidates_digest while keeping volatile observation attributes out of candidate identity."
  - "Require the complete registry only when all dimensions are applicable, preserving a minimal explicit-inapplicability tracer fixture without weakening the final census contract."
patterns-established:
  - "Authority split: immutable repository SHA plus clean-state receipt is validated against a separate reviewed ledger."
  - "Transition reconciliation: candidate set equality is frozen and every changed observation digest requires one stable-ID Phase 133 transition."
requirements-completed: [EVID-01]
coverage:
  - id: D1
    description: "Generate and validate a deterministic clean exact-head census receipt with all twelve dimensions and bijective observation assignment."
    requirement: EVID-01
    verification:
      - kind: integration
        ref: "test/install_smoke/evidence_census_test.exs#clean exact-head and fail-closed mutation contracts"
        status: pass
    human_judgment: false
  - id: D2
    description: "Enforce the repository detector registry, disposition completeness, stable candidate IDs, and explicit Phase 133 transition reconciliation."
    requirement: EVID-01
    verification:
      - kind: integration
        ref: "test/install_smoke/evidence_census_test.exs#registry, transition, ordering, and precision contracts"
        status: pass
    human_judgment: false
duration: 27min
completed: 2026-09-09
status: complete
---

# Phase 133 Plan 01: Evidence Census Contract Summary

**Deterministic exact-head census receipts now fail closed on authority, taxonomy, detector, identity, disposition, precision, and transition drift.**

## Performance

- **Duration:** 27 min
- **Started:** 2026-09-09T22:31:13Z
- **Completed:** 2026-09-09T22:58:40Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added a clean-worktree, explicit-SHA collector that emits canonical repository-relative receipts with resolved toolchain and detector-input digests.
- Added a fail-closed validator for the exact twelve-dimension taxonomy, observation-to-candidate bijection, and complete `fix` / evidence-backed `retain` / trigger-bound `defer` dispositions.
- Locked the repository-owned detector registry and candidate-baseline transition contract so additions, removals, ID substitutions, and unexplained observation changes fail.
- Proved deterministic ordering plus zero/one/many, dirty, foreign-SHA, duplicate, missing, invalid-disposition, and integer-precision boundaries through 11 ExUnit tests.

## Task Commits

Each task used explicit RED and GREEN commits:

1. **Task 1 RED: exact-head census contract** - `ef6d0e6` (test)
2. **Task 1 GREEN: collector and validator** - `d08e2ed` (feat)
3. **Task 2 RED: detector and transition contract** - `07b480c` (test)
4. **Task 2 GREEN: complete registry and transitions** - `7b0d0e7` (feat)
5. **Boundary RED: precision and cardinality probes** - `3759104` (test)
6. **Boundary GREEN: integer count enforcement** - `4f23cb5` (fix)

## Files Created/Modified

- `scripts/maintainer/evidence_census.exs` - Collects exact-head authority facts and writes canonical census receipts.
- `scripts/maintainer/validate_evidence_census.exs` - Validates authority, registry, assignments, dispositions, baselines, and transitions.
- `test/install_smoke/evidence_census_test.exs` - Exercises valid, deterministic, and deliberately mutated ledger/receipt pairs through subprocess CLIs.

## Decisions Made

- The checked ledger records an already-immutable subject commit and remains separate from the generated receipt, avoiding Git-SHA self-reference.
- `candidates_digest` covers canonical candidates, candidate baselines, and transitions; observation counts and line evidence remain outside stable candidate identity.
- The validator accepts an explicitly inapplicable minimal tracer taxonomy, but any all-applicable census must match the exact repository-owned twelve-detector registry.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed a newly introduced curated-complexity finding from the test helper**

- **Found during:** Task 2 quality-signal verification
- **Issue:** Nested fixture rewriting added one finding to the removal-only Credo complexity baseline.
- **Fix:** Extracted candidate and observation rewrite helpers so the existing reviewed multiset remains unchanged.
- **Files modified:** `test/install_smoke/evidence_census_test.exs`
- **Verification:** `mix quality_signals` passed the exact complexity baseline.
- **Committed in:** `7b0d0e7`

---

**Total deviations:** 1 auto-fixed bug
**Impact on plan:** The fix preserved the existing quality ratchet without changing census behavior or scope.

## Issues Encountered

- The pinned Elixir 1.17.3 / OTP 27.2 toolchain is not installed locally, as recorded in phase research. Locked dependency checkouts were restored without changing `mix.lock`, and local verification ran on Elixir 1.19.5 / OTP 28.4.1. The collector records the actual resolved toolchain in every receipt; supported-cell authority remains owned by the planned CI evidence.

## Known Stubs

None.

## Authentication Gates

None.

## User Setup Required

None - no external service configuration required.

## Verification

- `mix test test/install_smoke/evidence_census_test.exs` - 11 tests, 0 failures.
- `mix format --check-formatted` - passed.
- `mix quality_signals` - passed Credo policy, 100% docs/spec validation, cycle check, and 97 contract tests.
- `./scripts/maintainer/automation_first_contract.sh` - run after this active planning artifact was written.

## Next Phase Readiness

- Plan 06 can populate the real post-repair ledger at an immutable detached subject SHA and validate its receipt without changing the schema.
- Phases 135 and 136 can reference reviewer-owned candidate IDs and must supply explicit transition records for changed observation sets.
- No census candidate source, threshold, suppression, CI topology, dependency, public API, schema/migration, telemetry, or error vocabulary changed.

## TDD Gate Compliance

- RED commits precede their GREEN commits for both planned tasks and the final precision boundary.

## Self-Check: PASSED

- All three declared artifacts exist.
- All six task commits are present in Git history.
- Focused acceptance and repository quality checks passed with non-zero test counts.
- No known stub or unrun verification blocks the plan goal.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-09-09*
