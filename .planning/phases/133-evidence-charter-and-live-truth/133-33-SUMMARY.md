---
phase: 133-evidence-charter-and-live-truth
plan: "33"
subsystem: ci-evidence
tags: [github-cli, rate-limit, nightly, exact-sha, shell, tdd]
status: complete
requires:
  - phase: 133-31
    provides: one-time exact-SHA/ref authorization boundary and immutable prior-attempt history
provides:
  - bounded recovery for exact GitHub primary and secondary rate limits on covered post-dispatch reads
  - immutable databaseId/SHA/ref ownership across recovered run-list, detail, log, and incident observations
  - adversarial shell fixtures proving one dispatch, no recovery mutations, and fail-closed exhaustion
affects: [133-34, 133-35, 133-36, 133-37, EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
plan_head_before: 5ed9b1b120c3ed6f29c07c6611b9ee1d44a0d475
actuals:
  tokens: 4608
  tasks: 2
  commits: 5
tech-stack:
  added: []
  patterns:
    - one collector deadline bounds every recoverable post-dispatch GitHub read
    - exact rate-limit classification is separated from fail-closed identity validation
key-files:
  created:
    - .planning/phases/133-evidence-charter-and-live-truth/133-33-SUMMARY.md
  modified:
    - scripts/ci/verify_nightly_run.sh
    - scripts/ci/test_verify_nightly_run.sh
    - .planning/STATE.md
    - .planning/ROADMAP.md
key-decisions:
  - "Retry only exact GitHub primary or secondary rate-limit diagnostics; authentication, permission, malformed, and unrelated failures remain terminal."
  - "Carry the original collector deadline and selected databaseId through recovery while keeping workflow dispatch and issue mutations outside the recovery helper."
patterns-established:
  - "Read-only recovery: capture bounded stdout/stderr, classify narrowly, retry under the original deadline, then apply the existing exact-identity validator."
  - "Mutation isolation: recovery helpers may wrap only covered run-list, run-detail, job-log, and issue-snapshot reads."
requirements-completed: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
coverage:
  - id: D1
    description: A transient watch rate limit preserves the one dispatch-owned run and can still produce its exact candidate receipt.
    requirement: EVID-02
    verification:
      - kind: integration
        ref: scripts/ci/test_verify_nightly_run.sh#transient watch rate limit preserves one dispatch-owned run
        status: pass
    human_judgment: false
  - id: D2
    description: Every covered post-dispatch read family recovers transient limits without changing identity or mutation count and exhausts fail-closed.
    requirement: EVID-04
    verification:
      - kind: integration
        ref: bash scripts/ci/test_verify_nightly_run.sh
        status: pass
      - kind: other
        ref: bash -n and shellcheck for both collector scripts
        status: pass
    human_judgment: false
metrics:
  duration: 19m
  completed: 2026-09-12
---

# Phase 133 Plan 33: Bounded Exact-Run Observation Recovery Summary

**One dispatch-owned Nightly run now survives transient GitHub read rate limits under its original deadline without changing database identity, evidence authority, or mutation count.**

## Performance

- **Duration:** 19 minutes
- **Started:** 2026-09-12T19:33:45Z
- **Completed:** 2026-09-12T19:52:12Z
- **Tasks:** 2
- **Files modified:** 2 production/test files plus this summary and 2 sequential tracking files

## Accomplishments

- Added a narrow GitHub primary/secondary rate-limit classifier and deadline-bounded read recovery without placing workflow dispatch or issue mutation inside retry control flow.
- Preserved the originally selected databaseId, subject SHA, subject-derived ref, workflow, repository, exact job identities, and incident snapshot checks across recovered observations.
- Expanded the fake-`gh` contract to 154 passing assertions covering transient and exhausted limits, malformed recovered data, unrelated 403 errors, exact call counts, and all prior fail-closed behavior.

## Task Commits

1. **Task 1 RED: Pin one dispatch-owned watch recovery path** - `155e898`
2. **Task 1 GREEN: Recover transient watch limits** - `0a3305d`
3. **Task 2 RED: Cover every post-dispatch read family** - `30dab74`
4. **Task 2 GREEN: Recover all covered post-dispatch reads** - `660a7f6`
5. **Task 2 REFACTOR: Document embedded fixture lint intent** - `79fb36b`

## Files Created/Modified

- `scripts/ci/verify_nightly_run.sh` — narrowly classifies rate-limit diagnostics and retries only covered post-dispatch reads under the original collector deadline.
- `scripts/ci/test_verify_nightly_run.sh` — proves transient, persistent, malformed, foreign/unauthorized, identity, and mutation-count behavior through deterministic fake GitHub responses.
- `.planning/phases/133-evidence-charter-and-live-truth/133-33-SUMMARY.md` — records the local repair, evidence, TDD gates, and unchanged-authority boundary.
- `.planning/STATE.md` and `.planning/ROADMAP.md` — record Plan 33 completion while preserving the branch-aware halted-plan topology.

## Decisions Made

- Recognize only diagnostics containing GitHub's primary `API rate limit exceeded` or secondary `secondary rate limit` forms; never retry generic HTTP 403, authentication, permission, or malformed-output failures.
- Reuse the deadline created immediately after the sole workflow dispatch so discovery, watch, detail, logs, and the post-dispatch incident snapshot share one outer bound.
- Leave preflight and the pre-dispatch run/incident snapshots single-attempt, and keep every mutation outside the read-recovery helper.

## Verification

- `bash scripts/ci/test_verify_nightly_run.sh` — passed, 154 assertions and zero failures.
- `bash -n scripts/ci/verify_nightly_run.sh scripts/ci/test_verify_nightly_run.sh` — passed.
- `shellcheck scripts/ci/verify_nightly_run.sh scripts/ci/test_verify_nightly_run.sh` — passed.
- `git diff --exit-code 5ed9b1b120c3ed6f29c07c6611b9ee1d44a0d475..HEAD -- .../133-NIGHTLY-EVIDENCE.json .../COVERAGE.md` — passed; neither authority file changed.
- Canonical SHA-256 remained `1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4`; coverage SHA-256 remained `35cb8271cf453237d7aeace3ac138a8e32574974d06fb582edaab861544b1e25`.
- `./scripts/maintainer/automation_first_contract.sh` — passed.

## TDD Gate Compliance

- Task 1 RED was machine-validated as `RED_EVIDENCE_OK` for `transient watch rate limit preserves one dispatch-owned run` before production edits.
- Task 1 GREEN passed the focused 31-assertion ownership suite and the full existing suite before commit.
- Task 2 RED was machine-validated as `RED_EVIDENCE_OK` for `detail_rate_limit_once preserves identity and mutation count` before expansion edits.
- Task 2 GREEN passed the focused 51-assertion rate-limit suite; the final full suite passed 154/154 before refactor completion.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Scoped the new fake watch counter to rate-limit scenarios**
- **Found during:** Task 1 GREEN full-suite verification
- **Issue:** Baseline receipt helpers intentionally lacked the new watch-counter environment variable, so unconditional counter access broke unrelated cases.
- **Fix:** Accessed the counter only in the two watch rate-limit states.
- **Files modified:** `scripts/ci/test_verify_nightly_run.sh`
- **Verification:** Full collector suite passed 134/134 at the Task 1 tracer gate.
- **Committed in:** `0a3305d`

**2. [Rule 3 - Blocking] Declared intentional embedded-fixture shellcheck semantics**
- **Found during:** Final Task 2 shell style verification
- **Issue:** Shellcheck reported literal single-quoted fake-script bodies and the extraction-only helper even though they execute only after being copied into the fake executable.
- **Fix:** Added file-level annotations for the intentional embedded-script diagnostics.
- **Files modified:** `scripts/ci/test_verify_nightly_run.sh`
- **Verification:** Shellcheck exited cleanly and the full suite remained 154/154.
- **Committed in:** `79fb36b`

**3. [Rule 3 - Blocking] Restored branch-aware sequential tracking after the generic handlers**
- **Found during:** Final STATE/ROADMAP updates
- **Issue:** The generic state handler advanced the stale displayed plan from 1 to 2, and the roadmap handler counted halted summaries as completed checkboxes while producing malformed summary prose.
- **Fix:** Kept the handler-produced 33-summary aggregate and metric, restored Plan 34 as the next position, preserved Plans 27/32 as unchecked halted history, and reconciled the semantic totals to 31 complete / two halted / four pending.
- **Files modified:** `.planning/STATE.md`, `.planning/ROADMAP.md`
- **Verification:** Inspected the exact current-position, halted-plan checkbox, phase-summary, and progress-table rows after correction.
- **Committed in:** Final plan metadata commit.

**Total deviations:** 3 auto-fixed (one Rule 1 bug, two Rule 3 blocking issues).
**Impact on plan:** The code fixes were limited to deterministic test-fixture correctness and lintability; the tracking correction preserved the established branch-aware halt semantics. Production recovery scope did not expand.

## Issues Encountered

None beyond the auto-fixed fixture issues above.

## Known Stubs

None.

## Threat Flags

None. The modified GitHub observation boundary and mutation separation are the surfaces explicitly covered by the plan's threat model; no endpoint, credential, schema, package, remote ref, workflow run, or issue mutation was added.

## User Setup Required

None.

## Next Phase Readiness

- Plan 133-34 can reconcile the 37-plan lifecycle and automation map against this tracked, locally verified repair.
- Plan 32's ref `phase-133-evidence-e70623e9ea95`, SHA `e70623e9ea956c750904af574f47221cc472d2f2`, and run `34670574306` remain immutable, unqualified history.
- This plan created no remote mutation and promoted no candidate receipt; EVID-01 through EVID-04 and TRUTH-08 remain pending until the successful Plan 37 receipt and terminal automated reconciliation pass.

## Self-Check: PASSED

Both modified scripts exist, all five TDD commits resolve from the recorded plan base, the full automated contract is green, and the canonical receipt and coverage bytes remain unchanged.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-09-12*
