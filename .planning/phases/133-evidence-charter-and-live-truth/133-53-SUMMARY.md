---
phase: 133-evidence-charter-and-live-truth
plan: "53"
subsystem: ci-evidence
tags: [bash, github-actions, coverage, evidence]

requires: []
provides:
  - "A bounded read-only collector for the five exact failed coverage jobs from Nightly run 36274589243."
  - "A redacted, digest-bound diagnosis that records the observed per-cell failures without inventing a shared cause."
affects: [Phase 133 coverage-repair planning]

actuals:
  tokens: 25805
  tasks: 2
  commits: 4
  plan_head_before: 38c751fd844fe1e861da0e1d8b9fd43cd1d1209c

tech-stack:
  added: []
  patterns:
    - "Exact run, attempt, ref, SHA, job, and failed-step validation before log retrieval."
    - "Private temporary raw logs with bounded, redacted excerpts and SHA-256 digests."

key-files:
  created:
    - .planning/phases/133-evidence-charter-and-live-truth/133-53-LOG-DIAGNOSIS.json
  modified:
    - scripts/ci/collect_phase133_49_coverage_logs.sh
    - scripts/ci/test_collect_phase133_49_coverage_logs.sh

key-decisions:
  - "Keep EVID-01 through EVID-04 and TRUTH-08 pending; this diagnostic is evidence collection, not acceptance."
  - "Report separate failure evidence groups because the five exact logs do not establish one shared cause."

requirements-completed: []

coverage:
  - id: D1
    description: "Read-only collector validates the immutable run identity, retrieves five exact failed coverage logs with bounded retries, and records redacted excerpts or explicit unavailable states."
    verification:
      - kind: integration
        ref: "bash scripts/ci/test_collect_phase133_49_coverage_logs.sh (14/14 cases)"
        status: pass
      - kind: other
        ref: "bash -n scripts/ci/collect_phase133_49_coverage_logs.sh && shellcheck scripts/ci/collect_phase133_49_coverage_logs.sh scripts/ci/test_collect_phase133_49_coverage_logs.sh"
        status: pass
    human_judgment: false
  - id: D2
    description: "Exact run 36274589243 attempt 1 on the pinned SHA has five authenticated job-log digests and redacted failure excerpts, with separate evidence groups and a failed strict summary."
    verification:
      - kind: other
        ref: ".planning/phases/133-evidence-charter-and-live-truth/133-53-LOG-DIAGNOSIS.json (authenticated read-only capture and exact-run acceptance predicate)"
        status: pass
    human_judgment: false

duration: 73 min
completed: 2026-09-27
status: complete
---

# Phase 133 Plan 53: Five-Job Coverage Diagnosis Summary

**Authenticated evidence collector and redacted five-cell diagnosis for exhausted Nightly run 36274589243**

## Performance

- **Duration:** 73 min
- **Started:** 2026-09-26T23:18:16Z
- **Completed:** 2026-09-27T00:31:53Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Extended the collector to validate the exact repository, workflow, run, attempt, ref, SHA, five compatibility job IDs, failed coverage steps, and failed Nightly Summary before retrieving logs.
- Retrieved all five exact job logs through authenticated read-only access. The diagnosis stores each log digest and bounded redacted assertion excerpts; the observed failures form separate evidence groups, so no single shared root cause is asserted.
- Added explicit complete, logs-incomplete, and logs-unavailable outcomes. Unavailable or malformed log retrieval retains precise failure categories and a null cause.

## Task Commits

1. **Task 1 RED: exact coverage log collector contract** — 1a9d33e6
2. **Task 1 GREEN: exact failed coverage job collector** — b3e7d47d
3. **Task 2 RED: five-job failure diagnosis tests** — 79ce2eb4
4. **Task 2 GREEN: five-job coverage diagnosis** — 4bc2377b

## Files Created/Modified

- .planning/phases/133-evidence-charter-and-live-truth/133-53-LOG-DIAGNOSIS.json — exact-run metadata, per-job retrieval results, redacted excerpts, log digests, and supported cause groups.
- scripts/ci/collect_phase133_49_coverage_logs.sh — pinned five-job metadata checks, bounded read-only log retrieval, redaction, and diagnosis serialization.
- scripts/ci/test_collect_phase133_49_coverage_logs.sh — fake-GitHub identity, availability, mutation, redaction, and divergent-failure contracts.

## Decisions Made

- Kept all five Phase 133 requirements pending because a failed Nightly attempt and its diagnosis do not establish acceptance.
- Kept the strict failed Nightly Summary as an aggregate consequence and did not promote it to a root cause.

## TDD Gate Compliance

- Task 1 has its committed RED/GREEN pair: 1a9d33e6 then b3e7d47d.
- Task 2 RED evidence was checked by GSD and returned RED_EVIDENCE_OK for the named five-job diagnosis assertion (8 of 14 contract cases failed before implementation).
- Task 2 GREEN commit 4bc2377b passes all 14 contract cases. No refactor was needed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Isolated retrieval-mode state between fake log scenarios**
- **Found during:** Task 2 verification
- **Issue:** The all-unavailable fixture left its fake retrieval settings in the parent shell, preventing the following divergent-log case from exercising its five logs.
- **Fix:** Reset the fake primary and fallback modes for the divergent-log scenario.
- **Files modified:** scripts/ci/test_collect_phase133_49_coverage_logs.sh
- **Verification:** The focused contract passes 14/14 cases, including divergent evidence grouping.
- **Committed in:** 4bc2377b

**Total deviations:** 1 auto-fixed (Rule 1 - bug).
**Impact on plan:** The fixture correction makes the planned divergent-failure assertion run against its intended inputs; it does not expand production scope.

## Issues Encountered

- The workspace-only sandbox denied the first Git index write because the worktree index lives under the parent checkout metadata. The same task commit completed with the reviewed Git-write escalation and ordinary hooks enabled; no verification bypass was used.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 53 is complete and the five exact failed job logs are available for evidence-based follow-up. All five requirements remain pending, the canonical receipt and exhausted Nightly run remain unchanged, and this plan authorized no new ref publication or Nightly dispatch. Plan 133-54 remains the next reviewed plan.

## Self-Check: PASSED

- Diagnosis artifact exists and satisfies the exact run, attempt, SHA, five-job, and status predicate.
- Task commits 1a9d33e6, b3e7d47d, 79ce2eb4, and 4bc2377b exist on this worktree branch.
- Focused fake-GitHub contract, shell validation, credential scan, live diagnosis predicate, and automation-first contract passed.
- Shared STATE.md and ROADMAP.md were not modified.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-09-27*
