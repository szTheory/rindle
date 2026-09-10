---
phase: 133-evidence-charter-and-live-truth
plan: "12"
subsystem: ci-evidence
tags: [github-actions, eventual-consistency, cardinality, exact-sha, idempotency]
requires:
  - phase: 133-11
    provides: Reconciled Phase 133 evidence authorities and safe Nightly PLT reset boundary
  - phase: 133-09
    provides: Canonical Nightly receipt reconstruction and read-only exact-subject verification
provides:
  - Bounded zero/one/many selection for exact post-boundary diagnostic Nightly runs
  - Eventual-consistency tolerance when unrelated historical runs appear before the dispatched run
  - Immediate fail-closed rejection of concurrent exact matches before watch, view, or receipt writes
affects: [phase-133-verification, phase-139-readiness, nightly-evidence]
actuals:
  tokens: 2555
  tasks: 2
  commits: 4
tech-stack:
  added: []
  patterns:
    - Cardinality-aware filtering over immutable workflow, event, ref, SHA, and creation-boundary identity
    - Stateful fake GitHub CLI cases for eventual consistency and concurrent results
key-files:
  created: []
  modified:
    - scripts/ci/verify_nightly_run.sh
    - scripts/ci/test_verify_nightly_run.sh
key-decisions:
  - "Treat zero exact matches as an eventual-consistency wait state regardless of unrelated historical list contents."
  - "Treat more than one exact post-boundary match as immediate ambiguity rather than selecting by order or recency."
patterns-established:
  - "Zero/one/many selector: zero polls within the deadline, one selects, and many fails before downstream inspection."
  - "Diagnostic idempotency: repeated receipt verification reuses exact run/attempt authority and emits no mutation argv."
requirements-completed: [EVID-02, EVID-04]
coverage:
  - id: D1
    description: "A delayed exact Nightly run is selected after unrelated historical runs without watching or viewing a nonmatching ID."
    requirement: EVID-02
    verification:
      - kind: integration
        ref: "bash scripts/ci/test_verify_nightly_run.sh (old_runs_then_exact; 89 cases total)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Zero matches poll without a receipt, one match is accepted, and multiple exact matches fail immediately without remote mutation."
    requirement: EVID-04
    verification:
      - kind: integration
        ref: "bash scripts/ci/test_verify_nightly_run.sh (zero/one/many and repeated verify-receipt assertions)"
        status: pass
      - kind: other
        ref: "shellcheck -S warning scripts/ci/verify_nightly_run.sh scripts/ci/test_verify_nightly_run.sh"
        status: pass
    human_judgment: false
duration: 6min
completed: 2026-09-10
status: complete
---

# Phase 133 Plan 12: Cardinality-Aware Nightly Run Selection Summary

**Exact-run collection now tolerates stale GitHub run listings while accepting only one immutable post-boundary match and rejecting concurrent matches before downstream evidence handling.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-09-10T20:47:17Z
- **Completed:** 2026-09-10T20:53:19Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Replaced the old nonempty-history failure with bounded polling whenever the exact-match cardinality is zero.
- Added a stateful old-runs-first fixture proving only the later exact run ID reaches watch, view, validation, and receipt creation.
- Added explicit zero/one/many coverage that rejects two qualifying runs on the first list response before watch, view, or receipt creation.
- Repeated canonical receipt verification in the success path and retained the existing no-mutation command assertions.

## Task Commits

Each TDD task was committed as a RED test followed by its GREEN implementation:

1. **Task 1 RED: expose delayed exact-run listing** - `2f220c6` (test)
2. **Task 1 GREEN: wait through unrelated run history** - `a979b67` (fix)
3. **Task 2 RED: expose ambiguous run cardinality** - `b9544ff` (test)
4. **Task 2 GREEN: fail closed on ambiguous run matches** - `2f58881` (fix)

## Files Created/Modified

- `scripts/ci/verify_nightly_run.sh` - Classifies exact post-boundary match cardinality as wait, accept, or ambiguous failure.
- `scripts/ci/test_verify_nightly_run.sh` - Adds stateful delayed-list, duplicate-match, timeout poll-count, exact-ID, and repeated read-only verification assertions.

## Decisions Made

- Historical workflow-dispatch runs are normal eventual-consistency input; only exact post-boundary matches influence selection.
- Duplicate exact matches are evidence ambiguity and fail immediately; list ordering and recency never resolve cardinality.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## Known Stubs

None. Empty shell variables are bounded argument, fake-command, and selected-run initialization; they do not flow to UI or incomplete acceptance behavior.

## Authentication Gates

None.

## User Setup Required

None - no external service configuration required.

## Verification

- `bash scripts/ci/test_verify_nightly_run.sh` - 89 passed, 0 failed.
- `shellcheck -S warning scripts/ci/verify_nightly_run.sh scripts/ci/test_verify_nightly_run.sh` - passed with no warning-or-higher findings.
- `./scripts/maintainer/automation_first_contract.sh` - passed for the Phase 133 planning artifacts.

## Threat Flags

None. The planned selector hardens the existing GitHub-list trust boundary without adding endpoints, credentials, mutations, schema changes, or caller-selected execution.

## TDD Gate Compliance

- Task 1 RED commit `2f220c6` failed because unrelated older runs aborted before the later exact run appeared; GREEN commit `a979b67` made the delayed-list case pass.
- Task 2 RED commit `b9544ff` failed because two exact matches were not rejected immediately; GREEN commit `2f58881` made all zero/one/many and idempotency assertions pass.

## Self-Check: PASSED

- Both declared modified files exist.
- Commits `2f220c6`, `a979b67`, `b9544ff`, and `2f58881` exist in repository history.
- All task acceptance criteria and plan-level verification commands passed after the final implementation.
- No tracked files were deleted, no generated files were left untracked, and no unplanned security surface was introduced.

## Next Phase Readiness

- Verification gap CR-02 is closed with executable old-history, timeout, unique-match, and duplicate-match coverage.
- Plan 133-13 can proceed from a fail-closed exact-run selector; no blocker remains from this plan.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-09-10*
