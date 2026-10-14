---
phase: 133-evidence-charter-and-live-truth
plan: "38"
subsystem: ci-evidence
tags: [nightly, exact-sha, mix, tdd, shell]

requires:
  - phase: 133-37
    provides: immutable exhausted Plan 37 ref/run history and the detached uncompiled-application failure fingerprint
provides:
  - Exact-subject census and live-truth validation that never starts the uncompiled Rindle application
  - Per-call regression proof for detached cwd, root cache reuse, ordered argv, and fail-closed guard removal
affects: [133-39, EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]

actuals:
  tokens: 2912
  tasks: 2
  commits: 4
plan_head_before: 8d4f70bda4c2753b1585936fe4acc7a4212908fd

tech-stack:
  added: []
  patterns:
    - Detached Mix script execution uses --no-start with no dependency check or compilation
    - Authority commands form an explicit fail-closed chain so no middle failure can be masked

key-files:
  created:
    - .planning/phases/133-evidence-charter-and-live-truth/133-38-SUMMARY.md
  modified:
    - scripts/ci/verify_nightly_run.sh
    - scripts/ci/test_verify_nightly_run.sh

key-decisions:
  - "Run all three detached exact-subject authorities with --no-start while retaining the receipt subject as cwd and the supported root dependency/build caches."
  - "Propagate each authority result through an explicit command chain so a census-validator failure cannot be hidden by a later live-truth success."
  - "Keep Plan 37 receipt/ref/run history immutable and grant no Phase 133 requirement credit from this local repair."

patterns-established:
  - "Uncompiled-subject proof: fake Mix rejects any detached authority invocation without --no-start."
  - "Per-call contract: the harness records cwd, cache environment, order, script identity, and exact safety flags without evaluating logged argv."

requirements-completed: []

coverage:
  - id: D1
    description: "All three receipt-bound detached authorities execute without starting the uncompiled Rindle application."
    verification:
      - kind: integration
        ref: "bash scripts/ci/test_verify_nightly_run.sh"
        status: pass
    human_judgment: false
  - id: D2
    description: "Each authority call is ordered, exact-context bound, and independently rejects removal of --no-start without remote mutation."
    verification:
      - kind: integration
        ref: "VERIFY_NIGHTLY_TEST_SCOPE=authority-argv bash scripts/ci/test_verify_nightly_run.sh"
        status: pass
      - kind: other
        ref: "shellcheck scripts/ci/verify_nightly_run.sh scripts/ci/test_verify_nightly_run.sh"
        status: pass
    human_judgment: false

duration: 16min
completed: 2026-09-13
status: complete
---

# Phase 133 Plan 38: Detached Authority Startup Repair Summary

**Receipt-bound census and live-truth scripts now execute from the exact detached subject without starting `:rindle`, with deterministic per-call proof and fail-closed sequencing.**

## Performance

- **Duration:** 16 min
- **Started:** 2026-09-13T13:45:39Z
- **Completed:** 2026-09-13T14:01:26Z
- **Tasks:** 2
- **Files modified:** 2 implementation/test files

## Accomplishments

- Added `--no-start` to census generation, census validation, and live-truth validation while preserving `--no-deps-check --no-compile`, exact-subject cwd, and root cache bindings.
- Added an uncompiled-subject fake-Mix regression plus exact ordered assertions for all three authority invocations.
- Added one adversarial missing-guard mutation per authority and made the production sequence stop at the first failure.
- Preserved Plan 37's canonical receipt, exhausted ref/run record, census, and GitHub CLI coverage matrix byte for byte.

## TDD Gate Compliance

- **Task 1 RED:** `106fde06` — the focused uncompiled-subject assertion failed because all three production calls omitted `--no-start`; `tdd-red-evidence` returned `RED_EVIDENCE_OK`.
- **Task 1 GREEN:** `efc0379d` — all three calls gained `--no-start`; the focused regression and full 158-case collector suite passed.
- **Task 2 RED:** `4606bcea` — exact detached context was not recorded and the middle missing-guard mutation exposed masked failure propagation; `tdd-red-evidence` returned `RED_EVIDENCE_OK` for the target assertion.
- **Task 2 GREEN:** `c93d615f` — fake-Mix context logging and explicit command chaining made all four focused assertions pass; the expanded collector suite passed 163/163.
- **REFACTOR:** No separate refactor commit was needed; the green changes are already minimal and cohesive.

## Task Commits

Each TDD gate was committed atomically:

1. **Task 1 RED: reproduce the uncompiled authority startup failure** — `106fde06` (test)
2. **Task 1 GREEN: prevent detached authority application startup** — `efc0379d` (feat)
3. **Task 2 RED: lock the detached authority invocation contract** — `4606bcea` (test)
4. **Task 2 GREEN: enforce the fail-closed authority call chain** — `c93d615f` (feat)

## Files Created/Modified

- `scripts/ci/verify_nightly_run.sh` — applies all three Mix safety flags and chains local authorities fail closed.
- `scripts/ci/test_verify_nightly_run.sh` — exercises an uncompiled exact subject, records detached execution context, and mutates each startup guard independently.
- `.planning/phases/133-evidence-charter-and-live-truth/133-38-SUMMARY.md` — records repair evidence without promoting Phase 133 acceptance.

## Decisions Made

- Reused only root `deps` and `_build` cache paths; authority scripts and working directory remain receipt-bound to the detached exact subject.
- Kept the remote-command seam, incident behavior, receipt schema, GitHub endpoints, and `COVERAGE.md` unchanged.
- Left EVID-01 through EVID-04 and TRUTH-08 pending; Plan 39 and the later authorized exact-run sequence own fresh acceptance.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Prevented a middle authority failure from being masked**

- **Found during:** Task 2 adversarial guard-removal test
- **Issue:** The authority subshell is the left side of an outer `||`; Bash therefore did not stop after the second command failed, allowing a successful third command to return an overall success.
- **Fix:** Joined census generation, census validation, and live-truth validation with explicit `&&` boundaries.
- **Files modified:** `scripts/ci/verify_nightly_run.sh`, `scripts/ci/test_verify_nightly_run.sh`
- **Verification:** Each of the three independent `--no-start` removal mutations now exits nonzero before receipt creation or remote mutation.
- **Committed in:** `c93d615f`

**Total deviations:** 1 auto-fixed bug.
**Impact on plan:** The fix is required for the plan's per-call fail-closed invariant and does not widen authority or remote scope.

## Verification Results

- `bash scripts/ci/test_verify_nightly_run.sh` — PASS, 163 collector cases and zero failures.
- `bash scripts/ci/test_nightly_incident.sh` — PASS, 17 cases and zero failures.
- `bash scripts/ci/test_nightly_summary_gate.sh` — PASS, 49 cases and zero failures.
- `bash scripts/ci/test_nightly_dialyzer.sh` — PASS, 34 cases and zero failures.
- `bash -n scripts/ci/verify_nightly_run.sh scripts/ci/test_verify_nightly_run.sh` — PASS.
- `shellcheck scripts/ci/verify_nightly_run.sh scripts/ci/test_verify_nightly_run.sh` — PASS with no new suppression.
- Plan 37 summary, canonical receipt, census, and `COVERAGE.md` SHA-256 values — unchanged from the pre-plan snapshot.

## Known Stubs

None.

## Threat Flags

None. The repair changes no network endpoint, authentication path, file authority boundary, schema, or mutation capability; it strengthens the declared detached-command tampering and denial-of-service mitigations.

## Issues Encountered

None beyond the auto-fixed fail-closed sequencing bug above.

## Next Phase Readiness

- The local failure that exhausted Plan 37 is reproducibly closed in tracked collector code.
- Phase 133 remains open with all five requirements pending; Plan 39 may generate the next exact subject without reusing or relabeling Plan 37 evidence.

## Self-Check: PASSED

- Both modified shell files exist and contain the three guarded production calls.
- All four TDD commits exist in order from the persisted plan ledger base.
- The summary records no requirement completion or remote/canonical evidence mutation.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-09-13*
