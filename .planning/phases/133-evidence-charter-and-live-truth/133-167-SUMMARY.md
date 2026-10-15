---
phase: 133-evidence-charter-and-live-truth
plan: "167"
subsystem: testing
tags: [node, bash, detached-worktree, offline-supply, terminal-receipts]
requires:
  - phase: 133-155
    provides: Authenticated signed registry supply and route
  - phase: 133-165
    provides: Independent distinct-root guard verification
provides:
  - Exact-source detached staging of authenticated supply with non-root integrity preserved
  - Durable, no-clobber Plan 168 pre-Mix first-red receipt for injected failures
affects: [133-168, 133-169, 133-121, 133-122, 133-123, registry-qualification]
actuals:
  tokens: 18948.25
  tasks: 2
  commits: 2
plan_head_before: d96ff850
plan_head_after: e92eb6de
duration: ~45min
completed: 2026-10-11
tech-stack:
  added: []
  patterns: [authenticated detached-root relocation, fsynced no-clobber terminal publication, raw/effective exit preservation]
key-files:
  created: []
  modified:
    - scripts/maintainer/phase_133_local_supply.mjs
    - scripts/maintainer/phase_133_local_supply.test.mjs
    - scripts/maintainer/phase_133_local_gates.sh
    - scripts/maintainer/test_phase_133_local_gates.sh
key-decisions:
  - "Only authenticated root-sensitive fields are relocated for a same-SHA detached checkout; all other supply data and original report bytes remain bound."
  - "A terminal receipt records both the child's raw exit code and the runner's effective failure code, including raw 0/effective 1 for malformed or failing TAP."
  - "Plan 167 is repair-only: it creates no Plan 168 live preflight, authorization, attempt, or qualification receipt."
requirements-completed: []
coverage:
  - id: D1
    description: "Authentic signed supply stages in a real detached checkout at the same source tree, while altered non-root evidence fails closed."
    verification:
      - kind: unit
        ref: "scripts/maintainer/phase_133_local_supply.test.mjs#authentic Plan 166 supply stages in a real detached checkout at the same source tree"
        status: pass
      - kind: other
        ref: "node --test scripts/maintainer/phase_133_local_supply.test.mjs (22 assertions)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Plan 168 post-marker failures publish one durable zero-credit receipt with actual counts and no Mix/network/retry; replay cannot overwrite it."
    verification:
      - kind: other
        ref: "PHASE133_LOCAL_GATES_TEST_SCOPE=plan168_terminal bash scripts/maintainer/test_phase_133_local_gates.sh"
        status: pass
      - kind: other
        ref: "bash scripts/maintainer/test_phase_133_local_gates.sh"
        status: pass
    human_judgment: false
status: complete
commits: 2
---

# Phase 133 Plan 167: Detached Supply and Terminal Receipt Repair

**Plan 167 repairs same-source detached staging and records fail-closed Plan 168 pre-Mix outcomes without granting qualification credit.**

## Performance

- **Duration:** approximately 45 minutes
- **Started:** 2026-10-11T15:07:56Z (from the execution state at wave start)
- **Completed:** 2026-10-11
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Repaired authenticated supply staging for a real detached checkout at the same SHA/tree. The verifier relocates the validated root-sensitive fields while preserving the original report bytes and digest and retaining strict checks for every non-root field.
- Added durable Plan 168 pre-Mix first-red publication bound to the fresh preflight, authorization, source/tree, and exclusive attempt marker. Receipts preserve actual child counts, raw/effective exit codes, zero network/retry/Mix, zero credit, five Pending requirements, and eleven unresolved edges.
- Added disposable regressions for staging, runtime, guard, signal, cleanup, authority failure, raw exit zero with effective failure, and no-clobber replay. These fixtures did not create live Plan 168 receipts or run Mix.

## Task Commits

1. **Task 1: Stage the signed supply in a real detached source** — `5cc8369f` (`fix(133-167)`)
2. **Task 2: Publish every post-marker pre-Mix failure as terminal evidence** — `e92eb6de` (`fix(133-167)`)

## Verification

- RED/GREEN detached supply regression, followed by `node --test scripts/maintainer/phase_133_local_supply.test.mjs` — 22 assertions passed.
- RED/GREEN disposable Plan 168 terminal receipt regression — passed, including raw authority exit `0` with effective failure `1`, cleanup failure preservation, signal status, and replay no-clobber.
- `bash scripts/maintainer/test_phase_133_local_gates.sh` — passed. The default sandbox blocked fixture Git object creation; the same local suite passed with the required filesystem access.
- `bash -n scripts/maintainer/phase_133_local_gates.sh scripts/maintainer/test_phase_133_local_gates.sh` and `git diff --check` — passed.
- `automation_first_contract.sh` — passed before writing this summary, with the summary present, and again after the final State/ROADMAP update.
- GSD evaluation-scope check resolved both task commits for Plan 133-167.

## Decisions Made

- Normalize only authenticated root-sensitive detached-checkout fields; retain the signed input and every other report field as comparison inputs.
- Keep the raw child status distinct from an effective failure derived from its output, and retain cleanup errors without replacing the first-red cause.
- Keep EVID-01 through EVID-04 and TRUTH-08 Pending, all eleven evidence edges unresolved, and qualification credit at zero. Plan 168 remains a separate fresh-authority boundary.

## Deviations from Plan

None — the plan's two repair tasks and disposable test scope were followed.

## Issues Encountered

- The full shell suite's temporary Git fixtures require filesystem access to create Git objects and detached worktrees; the default sandbox denied that setup. The prescribed suite passed when rerun with that access.
- GSD initially could not resolve the task commits because their subjects lacked the `133-167` plan identifier. The two unpublished commits were rebuilt with plan-scoped subjects; the evaluation-scope check then resolved both.

## User Setup Required

None.

## Next Phase Readiness

Plan 167 is complete. Plan 168 is next in recovery DAG Wave 23 and must use its own fresh source, independent preauthorization checks, exact-literal checkpoint, and at most one attempt. Plan 169 and Plans 121–123 remain conditional or blocked; no requirement has closed.

## Self-Check: PASSED

- All four modified files exist and both task commits are reachable on this branch.
- The detached-supply and full local-gates regression suites passed; the terminal receipt tests prove zero Mix/network/retry and zero qualification credit.
- The automation-first contract passed after the final State/ROADMAP update.
- The GSD evaluation-scope resolver reports both commits for Plan 133-167.
- Active requirements remain Pending and Plan 168 live qualification artifacts were not created.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-10-11*
