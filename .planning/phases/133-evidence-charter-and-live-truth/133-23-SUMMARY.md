---
phase: 133-evidence-charter-and-live-truth
plan: "23"
subsystem: ci-evidence
tags: [github-actions, nightly, immutable-events, replay, workflow-topology, tdd]
requires:
  - phase: 133-22
    provides: Gap verification identifying cross-SHA replay loss and the orphaned evaluator
provides:
  - Per-event workflow-run SHA authentication across historical Nightly commits
  - Current high-watermark authentication against the fresh remote main SHA
  - One executable Nightly incident-policy owner with the obsolete evaluator retired
  - Cross-SHA recovery, mismatch rejection, replay idempotency, and topology regressions
affects: [133-24, EVID-04, nightly-evidence, readiness-manifest]
actuals:
  tokens: 3118
  tasks: 2
  commits: 4
plan_head_before: c85ebdd0f1e9a277f82ce4cf97ad2c5ffc08db5c
tech-stack:
  added: []
  patterns:
    - Authenticate immutable events against their own workflow-run metadata before replay
    - Constrain only the current replay high-watermark to the fresh remote main SHA
    - Derive production policy ownership from parsed workflow topology and tracked executable presence
key-files:
  created: []
  modified:
    - scripts/ci/manage_nightly_incident.sh
    - scripts/ci/test_nightly_incident.sh
    - test/install_smoke/nightly_policy_test.exs
key-decisions:
  - "Authenticate each historical verdict event against its own workflow-run head SHA; reserve current remote-main equality for the high-watermark run."
  - "Retire the Plan 04 evaluator as superseded executable history and keep manage_nightly_incident.sh as the sole production incident-policy owner."
patterns-established:
  - "Cross-SHA replay: completed historical runs retain their own validated 40-hex head SHA while the current run alone must match REMOTE_MAIN_SHA."
  - "Single-owner topology: parsed workflow steps plus tracked script existence reject a restored or referenced competing evaluator."
requirements-completed: [EVID-04]
coverage:
  - id: D1
    description: "Historical red events survive a later main SHA and converge through one ordered, idempotent green recovery."
    requirement: EVID-04
    verification:
      - kind: integration
        ref: "scripts/ci/test_nightly_incident.sh#red-A/green-B history opens, updates, and closes exactly once"
        status: pass
      - kind: other
        ref: "shellcheck -S warning scripts/ci/manage_nightly_incident.sh scripts/ci/test_nightly_incident.sh"
        status: pass
    human_judgment: false
  - id: D2
    description: "The Nightly workflow has exactly one issue-writing incident-policy owner and the retired evaluator is absent."
    requirement: EVID-04
    verification:
      - kind: integration
        ref: "test/install_smoke/nightly_policy_test.exs#Nightly has one executable incident-policy owner"
        status: pass
      - kind: other
        ref: "test ! -e scripts/ci/eval_nightly_incident.sh"
        status: pass
    human_judgment: false
duration: 8min
completed: 2026-09-11
status: complete
---

# Phase 133 Plan 23: Cross-SHA Nightly Incident Authority Summary

**Nightly replay now authenticates each historical verdict against its own run SHA while one parsed and tested workflow path retains sole incident-mutation authority.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-09-11T21:07:07Z
- **Completed:** 2026-09-11T21:14:43Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Preserved red verdicts from an earlier main SHA through a later green high-watermark, producing one ordered open/update/close lifecycle and zero mutations on replay.
- Kept the current run fail-closed against fresh remote main while rejecting historical event/run SHA disagreement before any issue mutation.
- Deleted the obsolete standalone evaluator and added a parsed-workflow topology contract that locks the replay manager as the sole production policy owner.

## Task Commits

Each TDD task was committed as an explicit RED-GREEN pair:

1. **Task 1 RED: cross-SHA replay and mismatch regressions** - `4c5c99f` (test)
2. **Task 1 GREEN: per-run historical SHA authentication** - `3e965f4` (feat)
3. **Task 2 RED: single executable incident-policy owner** - `4864f5b` (test)
4. **Task 2 GREEN: retire competing evaluator** - `351e443` (feat)

**Plan metadata:** committed with this summary.

## Files Created/Modified

- `scripts/ci/manage_nightly_incident.sh` - Selects bounded historical runs independently of current main and authenticates event SHA against each selected run.
- `scripts/ci/test_nightly_incident.sh` - Models red SHA A followed by green SHA B and rejects historical/current SHA mismatches.
- `test/install_smoke/nightly_policy_test.exs` - Proves one parsed workflow policy invocation, one issue writer, and absence of the retired evaluator.
- `scripts/ci/eval_nightly_incident.sh` - Deleted intentionally; Plans 19 and 23 supersede its orphaned Plan 04 policy path.

## Decisions Made

- Historical scheduled runs are selected by bounded run identity, status, branch, and workflow metadata; their SHA authority comes from their own authenticated run rows.
- Fresh remote-main equality remains mandatory only for the current high-watermark run.
- Plan 04 remains immutable historical planning, while its standalone evaluator is explicitly superseded by the serialized replay manager selected in the live workflow.

## TDD Gate Compliance

- **Task 1 RED:** `RED_EVIDENCE_OK`; the red-A/green-B target failed because current-main filtering removed SHA A before replay.
- **Task 1 GREEN:** 17 shell cases passed after historical selection stopped applying `REMOTE_MAIN_SHA` to every row.
- **Task 2 RED:** `RED_EVIDENCE_OK`; the single-owner target failed solely because the retired evaluator still existed.
- **Task 2 GREEN:** 7 ExUnit tests passed after the obsolete evaluator was deleted.
- Commit order is `test -> feat -> test -> feat`; no refactor commit was needed.

## Verification

- `bash scripts/ci/test_nightly_incident.sh` — 17 passed, 0 failed.
- `ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 mix test test/install_smoke/nightly_policy_test.exs` — 7 tests, 0 failures.
- `shellcheck -S warning scripts/ci/manage_nightly_incident.sh scripts/ci/test_nightly_incident.sh` — exit 0, no warnings.
- `test ! -e scripts/ci/eval_nightly_incident.sh` — exit 0.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The repository's `.tool-versions` requests Erlang 27.2, which is not installed locally. The focused ExUnit verification used the installed supported OTP 27 patch `27.3.4.15` with Elixir `1.17.3-otp-27`; the initial environment-only failure was not counted as TDD RED evidence.

## Known Stubs

None. Empty shell locals in the fake-`gh` argument parser are intentional initialized values, not rendered or executable placeholders.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Cross-SHA incident replay and single-owner executable authority are ready for Phase 133 gap closure and Plan 133-24.
- No workflow permission, schedule, public API, dependency, schema, or release-coupling change was introduced.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-09-11*

## Self-Check: PASSED

- All three retained key files exist and the retired evaluator is absent.
- All four RED/GREEN task commits exist in Git history.
- Coverage metadata classified successfully with both deliverables automated and passing.
