---
phase: 133-evidence-charter-and-live-truth
plan: "04"
subsystem: ci
tags: [github-actions, bash, github-cli, nightly, incident-management]
requires:
  - phase-133-plan-03
provides:
  - Scheduled-only rolling Nightly incident decisions bound to exact current-main run evidence
  - Exact-label GitHub Issues adapter with cardinality and repeated-run protection
  - Strict-verdict workflow lifecycle with job-local issue mutation permission
affects: [phase-133-plan-05, phase-136, nightly, incident-automation]
actuals:
  tokens: 5230
  tasks: 2
  commits: 4
tech-stack:
  added: []
  patterns:
    - Pure bounded policy evaluator separated from a thin GitHub Issues mutation adapter
    - Exact run ID and attempt evidence marker for idempotent rolling incidents
    - Workflow always-inspection with scheduled-only mutation eligibility in policy
key-files:
  created:
    - scripts/ci/eval_nightly_incident.sh
    - scripts/ci/manage_nightly_incident.sh
    - scripts/ci/test_nightly_incident.sh
  modified:
    - test/install_smoke/nightly_policy_test.exs
    - .github/workflows/nightly.yml
    - .github/workflows/ci.yml
key-decisions:
  - "Treat every open issue carrying the exact nightly-failure label as part of cardinality; duplicates or an unexpected title fail closed instead of selecting a winner."
  - "Use one exact nightly-run:<run-id>:<attempt> marker across issue bodies and comments so adapter reruns are no-op."
  - "Run the lifecycle under always() and delegate schedule/current-main eligibility to the pure evaluator so dispatch remains diagnostic while cancelled and skipped dependencies stay observable."
patterns-established:
  - "Incident decision boundary: bounded event, verdict, run, ref, remote-main, and full open-inventory facts produce exactly open, update, close, or noop."
  - "Recovery transition: gh issue close receives the exact recovery evidence through its supported --comment form; there is no separate close-before-comment window."
requirements-completed: [EVID-04]
coverage:
  - id: D1
    description: "Evaluate scheduled failure, recovery, diagnostic, stale, malformed, duplicate, and repeated-run incident states without consulting live GitHub state."
    requirement: EVID-04
    verification:
      - kind: unit
        ref: "scripts/ci/test_nightly_incident.sh#22-case policy and fake-gh matrix"
        status: pass
    human_judgment: false
  - id: D2
    description: "Open, update, or close the sole rolling incident only from the strict scheduled current-main Nightly verdict with exact run evidence and least privilege."
    requirement: EVID-04
    verification:
      - kind: integration
        ref: "test/install_smoke/nightly_policy_test.exs#incident lifecycle topology and permissions"
        status: pass
      - kind: unit
        ref: "scripts/ci/test_nightly_incident.sh#fake-gh mutation and ordering proof"
        status: pass
    human_judgment: false
duration: 13min
completed: 2026-09-09
status: complete
---

# Phase 133 Plan 04: Scheduled Nightly Incident Lifecycle Summary

**Nightly now maintains one exact-run-bound rolling incident through a pure scheduled/current-main policy and a fail-closed, least-privileged GitHub Issues adapter.**

## Performance

- **Duration:** 13 min
- **Started:** 2026-09-10T00:54:58Z
- **Completed:** 2026-09-10T01:07:55Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Added a bounded pure evaluator for `open`, `update`, `close`, and `noop` decisions across schedule/dispatch, strict verdict, exact run, default ref, fresh remote-main SHA, full incident inventory, and repeated-run evidence.
- Added a thin GitHub Issues adapter that queries the complete exact-label set, rejects ambiguous cardinality, propagates every lookup/mutation error, and supplies recovery evidence atomically through `gh issue close --comment`.
- Replaced the failure-only workflow job with an `always()` lifecycle consuming `nightly-summary.outputs.verdict`, every gating result, and one read-only current-main lookup while keeping `issues: write` job-local.
- Added the 22-case fake-CLI suite to the existing `ci-script-tests` carrier without changing workflow `CI`, the sole `CI Summary`, its members, fork safety, release coupling, or required-check identity.

## Task Commits

1. **Task 1 RED: lifecycle policy and fake GitHub matrix** - `84c6433` (test)
2. **Task 1 GREEN: pure evaluator and GitHub Issues adapter** - `3bd1ae5` (feat)
3. **Task 2 RED: parsed workflow lifecycle authority** - `0131534` (test)
4. **Task 2 GREEN: strict-verdict scheduled lifecycle wiring** - `bf9b94e` (feat)

## Files Created/Modified

- `scripts/ci/eval_nightly_incident.sh` - Validates bounded facts and emits one incident action.
- `scripts/ci/manage_nightly_incident.sh` - Enforces exact-label cardinality, idempotency, and GitHub mutation behavior.
- `scripts/ci/test_nightly_incident.sh` - Exercises policy, fake-CLI errors, mutations, and recovery ordering.
- `test/install_smoke/nightly_policy_test.exs` - Parses workflow topology, strict-verdict consumption, exact-run inputs, and permissions.
- `.github/workflows/nightly.yml` - Runs the scheduled incident lifecycle with all dependency facts and fresh remote-main identity.
- `.github/workflows/ci.yml` - Runs the fake-CLI matrix in the existing required script-test carrier.

## Decisions Made

- Exact-label cardinality includes every open `nightly-failure` issue. More than one, or one with an unexpected title, is an error rather than an invitation to choose silently.
- Incident idempotency uses the bounded `nightly-run:<run-id>:<attempt>` evidence marker across the issue body and all comments.
- The lifecycle job uses `always()` so it can inspect every Nightly terminal state; only the pure evaluator grants mutation eligibility to a scheduled exact-current-main run.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The repository-pinned Elixir 1.17.3/OTP 27.2 toolchain is not installed locally. Focused ExUnit, formatting, and quality verification ran diagnostically on installed Elixir 1.19.5/OTP 28.4.1; scheduled Nightly remains the supported-cell authority.

## Known Stubs

None.

## Authentication Gates

None.

## User Setup Required

None - no external service configuration required.

## Verification

- `bash scripts/ci/test_nightly_incident.sh` - 22 cases, 0 failures.
- `bash scripts/ci/test_nightly_summary_gate.sh` - 49 cases, 0 failures.
- `bash scripts/ci/test_ci_summary_gate.sh` - 6 cases, 0 failures.
- `bash scripts/ci/test_nightly_dialyzer.sh` - 24 cases, 0 failures.
- `mix test test/install_smoke/nightly_policy_test.exs test/install_smoke/quality_signal_policy_test.exs test/install_smoke/ci_lane_split_test.exs` - 36 tests, 0 failures on the installed diagnostic toolchain.
- `shellcheck scripts/ci/eval_nightly_incident.sh scripts/ci/manage_nightly_incident.sh scripts/ci/test_nightly_incident.sh` - passed.
- `actionlint .github/workflows/nightly.yml` - passed.
- `mix format --check-formatted` - passed on the installed diagnostic toolchain.
- `mix quality_signals` - passed reviewed Credo, documentation/spec coverage, Doctor validation, cycle, and contract checks.
- `./scripts/maintainer/automation_first_contract.sh` - passed.

## Next Phase Readiness

- Plan 05 can reconcile active release, support, lane, and adoption claims against a truthful Nightly incident lifecycle.
- Phase 136 can consume the same strict verdict and rolling incident evidence without relying on `failure()` or ambiguous issue selection.
- No public API, schema, dependency, telemetry, release-coupling, or PR critical-path contract changed.

## TDD Gate Compliance

- Each planned task has a RED test commit followed by its GREEN implementation commit.

## Self-Check: PASSED

- All three declared new scripts and all three modified workflow/test files exist.
- All four task commits are present in Git history.
- Every plan-level and RUNNING.md-relevant automated check passed with non-zero case/test counts.
- No known stub, skipped test, deleted tracked file, unrun verification, or unplanned threat surface blocks EVID-04.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-09-09*
