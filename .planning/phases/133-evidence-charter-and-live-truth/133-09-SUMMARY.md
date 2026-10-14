---
phase: 133-evidence-charter-and-live-truth
plan: "09"
subsystem: ci-evidence
tags: [github-actions, canonical-json, tamper-evidence, exact-subject, incident-revalidation]
requires:
  - phase: 133-07
    provides: Exact-subject Nightly receipt, fake-GitHub harness, and supported-cell run evidence
  - phase: 133-08
    provides: Claim-boundary package authority hardening
provides:
  - Canonical field-for-field reconstruction of every remotely reproducible Nightly receipt fact
  - Exact nested receipt schemas that reject missing, extra, reordered, duplicated, or type-changed evidence
  - Fresh read-only incident comparison and fixed exact-subject census/live-truth revalidation
  - Deterministic 78-case receipt mutation and authority-failure matrix
affects: [phase-133-verification, phase-133-plan-10, release-evidence]
actuals:
  tokens: 5723
  tasks: 2
  commits: 5
tech-stack:
  added: []
  patterns:
    - Reconstruct untrusted receipts from canonical live projections before exact equality
    - Execute repository-owned validators from a detached exact-subject worktree with fixed commands
key-files:
  created: []
  modified:
    - scripts/ci/verify_nightly_run.sh
    - scripts/ci/test_verify_nightly_run.sh
key-decisions:
  - "Normalize GitHub's expanded job objects to the four persisted job fields before exact receipt comparison."
  - "Treat incident drift as stale evidence and never reconcile it through a verifier-side mutation."
  - "Materialize the receipt subject detached and invoke only fixed repository-owned census and live-truth validators."
patterns-established:
  - "Canonical reconstruction: schema validation and exact live equality are separate mandatory gates."
  - "Read-only revalidation: verification may inspect GitHub and create an isolated local worktree but never dispatch or mutate remote state."
requirements-completed: [EVID-01, EVID-03, EVID-04, TRUTH-08]
coverage:
  - id: D1
    description: "Every persisted remote run, job, Dialyzer, strict-verdict, and preflight field is reconstructed and compared exactly."
    requirement: EVID-03
    verification:
      - kind: integration
        ref: "bash scripts/ci/test_verify_nightly_run.sh (78 cases, 0 failures)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Fresh exact-label incidents and fixed exact-subject local authorities must equal both persisted receipt authorities."
    requirement: EVID-04
    verification:
      - kind: integration
        ref: "bash scripts/ci/test_verify_nightly_run.sh (incident drift and local-validator failure cases)"
        status: pass
    human_judgment: false
duration: 1h 17min
completed: 2026-09-10
status: complete
---

# Phase 133 Plan 09: Independently Verifiable Nightly Receipt Summary

**Nightly receipts now survive only exact canonical reconstruction of remote facts plus fresh read-only incident and exact-subject local-authority revalidation.**

## Performance

- **Duration:** 1h 17min
- **Started:** 2026-09-10T15:17:05Z
- **Completed:** 2026-09-10T16:34:25Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Replaced partial success/type predicates with canonical reconstruction and exact equality for repository, workflow, ref, SHA, run timestamp/attempt/conclusion, every sorted job member, full Dialyzer evidence, strict-verdict provenance, and preflight.
- Enforced exact top-level and nested receipt key sets, unique job identities, canonical job ordering, and fail-closed incident/comment/local-authority shapes.
- Recollected the exact-label incident inventory once through `gh issue list` and compared it to both persisted snapshots without any dispatch, run mutation, or issue mutation.
- Reran the fixed census collector/validator and live-truth validator from a detached worktree at the receipt's exact `subject_sha`; neither receipt data nor environment variables select commands, paths, keys, or accepted statuses.
- Expanded the fake-GitHub harness from 28 to 78 passing cases, including a field-by-field remote mutation table, jointly forged incident snapshots, local authority shape mutations, live incident drift, and validator failure.

## Task Commits

1. **Task 1 RED: expose forged remote receipt fields** - `c61d58e` (test)
2. **Task 1 GREEN: reconstruct exact remote receipt evidence** - `96413a0` (feat)
3. **Task 2 RED: expose forged incident and local authority** - `1b08068` (test)
4. **Task 2 GREEN: revalidate incident and local authority** - `d7d10f0` (feat)
5. **Task 2 live compatibility: execute and report exact-subject validation precisely** - `22f3bca` (fix)

## Files Created/Modified

- `scripts/ci/verify_nightly_run.sh` - Exact receipt schemas, canonical remote reconstruction, fresh incident lookup, exact-subject local validator reruns, and precise comparison failures.
- `scripts/ci/test_verify_nightly_run.sh` - Complete mutation matrix plus fake fixed-command authority runner and read-only argv assertions.

## Decisions Made

- GitHub returns expanded job objects even when `jobs` is the requested field; verification projects those objects to the receipt's exact `{id,name,status,conclusion}` contract before equality rather than treating unrelated API metadata as persisted evidence.
- The census ledger remains the post-subject, fixed repository artifact established by Plan 06 while the collector and validators execute from the detached pre-ledger subject, preserving the intentional anti-self-reference design.
- The verifier does not refresh or rewrite stale evidence. A later scheduled incident update makes the historical receipt invalid until separately authorized evidence collection produces a new receipt.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Normalized expanded live GitHub job objects before validation**

- **Found during:** Task 2 real receipt verification
- **Issue:** `gh run view --json jobs` returns job steps, URLs, and timestamps in addition to the four receipt fields, so requiring the raw API object's key set incorrectly rejected the valid historical run.
- **Fix:** Projected each live job to the exact persisted fields, then validated identity/cardinality and compared the canonical sorted projection.
- **Files modified:** `scripts/ci/verify_nightly_run.sh`
- **Verification:** The real run passed remote reconstruction and the 78-case fake matrix remained green.
- **Committed in:** `22f3bca`

**2. [Rule 3 - Blocking] Made exact-subject validators executable with the installed diagnostic toolchain**

- **Found during:** Task 2 real receipt verification
- **Issue:** The subject-pinned Elixir/OTP pair is not installed locally, and compiling the subject against the installed Elixir 1.19 runtime failed in an older dependency.
- **Fix:** Executed the exact-subject script sources with the already-compiled test dependency graph using fixed `mix run --no-deps-check --no-compile` commands; the detached worktree still supplies every repository-owned validator and authority input.
- **Files modified:** `scripts/ci/verify_nightly_run.sh`, `scripts/ci/test_verify_nightly_run.sh`
- **Verification:** All three fixed authority commands succeeded against subject `4f83e153eb7e19f3e1e3ca43b40eefdfee87a4d2`; the fake matrix proves a validator failure remains fatal.
- **Committed in:** `22f3bca`

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking issue)
**Impact on plan:** Both adjustments preserve exact receipt semantics and the fixed read-only capability boundary; no API, schema, workflow, package, or remote mutation scope was added.

## Issues Encountered

- The historical Plan 07 receipt is now correctly stale: issue `#88` gained an eleventh scheduled-failure comment at `2026-09-10T07:37:44Z` for run `34450521817`. The real `verify-receipt` command reconstructed remote and local authorities, then exited nonzero because neither persisted incident snapshot equals current live state. The verifier did not mutate or rewrite the receipt.

## Known Stubs

None. Empty shell variables are argument/parser or fake-command initialization and do not flow to acceptance output.

## Authentication Gates

None. Existing GitHub CLI read access was sufficient.

## User Setup Required

None - no external service configuration required.

## Verification

- `bash scripts/ci/test_verify_nightly_run.sh` - 78 cases, 0 failures.
- Real Plan 07 `verify-receipt` invocation - expected nonzero stale-evidence rejection after remote reconstruction and exact-subject local validation; live issue `#88` differs from both stored snapshots.
- `bash scripts/ci/test_nightly_incident.sh` - 22 cases, 0 failures.
- `bash scripts/ci/test_nightly_summary_gate.sh` - 49 cases, 0 failures.
- `shellcheck scripts/ci/verify_nightly_run.sh scripts/ci/test_verify_nightly_run.sh` - exited 0; only intentional embedded-fake single-quote informational diagnostics.
- `./scripts/maintainer/automation_first_contract.sh` - passed.

## Threat Flags

None. The detached worktree and fixed validator commands implement the planned T-133-35/T-133-36 mitigations; no unplanned endpoint, auth path, external mutation, schema boundary, or caller-selected executable surface was introduced.

## TDD Gate Compliance

- Task 1 RED commit `c61d58e` demonstrated 15 forged remote fields were accepted before implementation; GREEN commit `96413a0` made the expanded 70-case matrix pass.
- Task 2 RED commit `1b08068` demonstrated jointly forged incident snapshots, live incident drift, and local validator failure were accepted; GREEN commit `d7d10f0` and compatibility fix `22f3bca` made all 78 cases pass.

## Self-Check: PASSED

- Both declared modified files exist.
- Commits `c61d58e`, `96413a0`, `1b08068`, `d7d10f0`, and `22f3bca` exist in repository history.
- The final fake-authority matrix has a nonzero case count and passes completely; exact-subject worktrees are removed after every real or fake verification.
- No known stub, skipped test, deleted tracked file, unrun plan verification, or unplanned threat surface remains.

## Next Phase Readiness

- Gap 2 is closed: any persisted remote, incident, or local-authority forgery fails exact reconstruction or independent rebinding.
- Plan 10 can address the remaining supported-toolchain verifier closure. A fresh Nightly receipt requires a separately authorized collection run; verification itself remains intentionally read-only.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-09-10*
