---
phase: 133-evidence-charter-and-live-truth
plan: "15"
subsystem: release-engineering
tags: [elixir, yaml, github-actions, branch-protection, evidence]
requires:
  - phase: 133-evidence-charter-and-live-truth
    provides: Plans 05 and 14 live-truth derivation and authenticated package authority
provides:
  - Parsed active release workflow graph proving exact-SHA CI-to-publish coupling
  - One structured required-check policy consumed by branch-protection production and validation
  - Adversarial inert, unreachable, duplicate, mismatch, and cardinality fixtures
affects: [phase-133-plan-16, phase-139, release-truth, branch-protection]
actuals:
  tokens: 5811
  tasks: 2
  commits: 4
tech-stack:
  added: []
  patterns:
    - Parse executable workflow topology before accepting release authority
    - Generate and validate branch-protection state from one exact-schema policy
key-files:
  created:
    - config/ci_required_checks.json
  modified:
    - scripts/maintainer/validate_live_truth.exs
    - scripts/setup_branch_protection.sh
    - test/install_smoke/live_truth_parity_test.exs
key-decisions:
  - "Bind release authority to exact parsed recovery, gate, checkout, CI-run, and publish semantics, with a pure exact-SHA completed-success evaluator."
  - "Keep ci_required_checks.json as the sole required-check identity owner; shell arrays may only be runtime projections of its bytes."
patterns-established:
  - "Active-step authority: comments, false-gated steps, duplicate job identities, and preserved literals cannot establish workflow truth."
  - "Policy projection: text output, JSON output, context-existence guards, PUT payloads, and live validation consume the same structured policy."
requirements-completed: [TRUTH-08, EVID-03]
coverage:
  - id: D1
    description: "Derive immutable release coupling from parsed executable workflow jobs, edges, outputs, conditions, and active step expressions."
    requirement: TRUTH-08
    verification:
      - kind: unit
        ref: "test/install_smoke/live_truth_parity_test.exs#derived_authority release coupling fixtures"
        status: pass
    human_judgment: false
  - id: D2
    description: "Make one structured policy the sole authority for the exact CI Summary branch-protection context."
    requirement: EVID-03
    verification:
      - kind: unit
        ref: "test/install_smoke/live_truth_parity_test.exs#derived_authority required-check fixtures"
        status: pass
      - kind: other
        ref: "bash scripts/setup_branch_protection.sh --print-expected-json | jq -e '.required_status_checks.contexts == [\"CI Summary\"]'"
        status: pass
      - kind: other
        ref: "shellcheck -S warning scripts/setup_branch_protection.sh"
        status: pass
    human_judgment: false
duration: 8min
completed: 2026-09-10
status: complete
---

# Phase 133 Plan 15: Executable Release and Required-Check Authority Summary

**Parsed release topology now proves exact-SHA CI-to-publish coupling, while one exact-schema policy drives every branch-protection producer and validator.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-09-10T21:32:46Z
- **Completed:** 2026-09-10T21:40:59Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Replaced inert release-source substring checks with parsed recovery, gate, checkout, CI-run, and publish graph validation plus an exact-SHA completed-success evaluator.
- Added `config/ci_required_checks.json` as the sole owner of `ci.yml`, workflow `CI`, job `ci-summary`, and context `CI Summary`.
- Refactored branch-protection text, JSON, context guard, and PUT body generation to consume that policy and taught live truth to compare executable producer output with parsed CI topology.
- Locked the authority boundary with comment-only, unreachable, duplicate, missing, extra, renamed, workflow-ID, condition, output, and SHA mutation fixtures.

## Task Commits

1. **Task 1 RED: inert release authority contract** - `00d544e` (test)
2. **Task 1 GREEN: parsed exact-SHA release graph** - `3128fde` (feat)
3. **Task 2 RED: required-check policy authority contract** - `dc02fc8` (test)
4. **Task 2 GREEN: structured branch-protection policy** - `184b90d` (feat)

## Files Created/Modified

- `config/ci_required_checks.json` - Exact-schema source for workflow, aggregate job, and sole required context identity.
- `scripts/setup_branch_protection.sh` - Projects policy bytes into text, JSON, pre-mutation guards, and the GitHub PUT payload.
- `scripts/maintainer/validate_live_truth.exs` - Derives release coupling from parsed executable semantics and verifies policy topology plus producer output.
- `test/install_smoke/live_truth_parity_test.exs` - Exercises executable authority and adversarial semantic mutation matrices.

## Decisions Made

- Parsed job topology and exact active step lines are authoritative; source comments and unreachable steps are not.
- A CI run qualifies only when its head SHA exactly equals the release SHA and it is completed with conclusion `success`.
- The shell script retains a runtime context array only as a projection of the JSON policy, never as parallel authority.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The repository-pinned Elixir 1.17.3/OTP 27 toolchain is not installed locally. Verification ran on the installed Elixir 1.19.5/OTP 27 toolchain; the change is workflow/policy parsing and does not replace the phase's separately owned supported-toolchain acceptance evidence.

## Known Stubs

None.

## Authentication Gates

None.

## User Setup Required

None - no external service configuration required.

## Verification

- `mix test test/install_smoke/live_truth_parity_test.exs --only derived_authority` - 12 tests, 0 failures, 4 excluded.
- `bash scripts/setup_branch_protection.sh --print-expected-json | jq -e '.required_status_checks.contexts == ["CI Summary"]'` - true.
- `shellcheck -S warning scripts/setup_branch_protection.sh` - passed with no findings.
- `mix format --check-formatted scripts/maintainer/validate_live_truth.exs test/install_smoke/live_truth_parity_test.exs` - passed.

## Next Phase Readiness

- Plan 16 can build on executable release/check authority without relying on preserved prose or duplicated shell identity.
- No public API, package, schema/migration, telemetry/error, workflow identity, release behavior, or branch-protection mutation path changed.

## TDD Gate Compliance

- Both tasks have RED test commits followed by GREEN implementation commits.

## Self-Check: PASSED

- All four declared files exist and all four task commits are present in Git history.
- Every task and plan verification passed with non-zero selected-test counts.
- No tracked file was deleted, no planned verification was skipped, and no known stub or unplanned threat surface remains.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-09-10*
