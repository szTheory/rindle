---
phase: 133-evidence-charter-and-live-truth
plan: "19"
subsystem: ci-evidence
tags: [github-actions, nightly, immutable-events, replay, idempotency, shell]
requires:
  - phase: 133-17
    provides: Schema-v2 exact-subject Nightly receipt and strict machine-verdict authority
provides:
  - Scheduled-only immutable verdict artifacts persisted before incident concurrency
  - Stable non-cancelling repository/workflow replay drainer with least-privilege artifact and issue access
  - Authenticated ordered event replay with deterministic mutation markers and bounded stale-preimage recovery
  - Adversarial red/red/green replaced-middle overlap and replay-safety regression matrix
affects: [133-22, nightly-evidence, EVID-03, EVID-04, readiness-manifest]
actuals:
  tokens: 12750
  tasks: 2
  commits: 4
plan_head_before: 6c71150bdb0709b37ff7bab6925e4f389b639238
tech-stack:
  added: []
  patterns:
    - Persist immutable inputs before entering a replaceable pending concurrency slot
    - Replay a complete authenticated log and record only idempotent real mutations
    - Re-fetch all-state remote preimages immediately before mutation and restart on drift or uncertainty
key-files:
  created: []
  modified:
    - .github/workflows/nightly.yml
    - scripts/ci/manage_nightly_incident.sh
    - scripts/ci/test_nightly_incident.sh
    - test/install_smoke/nightly_policy_test.exs
key-decisions:
  - "Persist each scheduled strict verdict outside the stable incident concurrency group so pending-job replacement cannot erase replay input."
  - "Use deterministic action/run/attempt mutation markers only for real issue mutations; green with no logical incident remains an unmarked replay-safe no-op."
  - "Treat all-state issue history and authenticated artifacts as replay authority; never add a mutable acknowledgement cursor."
patterns-established:
  - "Incident event identity: nightly-incident-verdict-<run_id>-<attempt> names a canonical JSON event cross-bound to workflow-run metadata."
  - "Mutation identity: nightly-mutation:<action>:<run_id>:<attempt> is atomic with create, comment, or close evidence."
  - "Replay safety: one missing intent per fresh-preimage cycle, followed by full replay until convergence or bounded failure."
requirements-completed: [EVID-03, EVID-04]
coverage:
  - id: D1
    description: "Every scheduled strict Nightly verdict is uploaded as canonical exact-run JSON before the stable non-cancelling incident drainer concurrency group."
    requirement: EVID-03
    verification:
      - kind: integration
        ref: "test/install_smoke/nightly_policy_test.exs#incident lifecycle consumes the strict verdict after every gating result"
        status: pass
      - kind: integration
        ref: "mix test test/install_smoke/nightly_policy_test.exs"
        status: pass
    human_judgment: false
  - id: D2
    description: "A surviving drainer authenticates and orders complete verdict artifacts through its high-watermark, rejecting missing, duplicate, malformed, foreign, or mismatched evidence before mutation."
    requirement: EVID-04
    verification:
      - kind: integration
        ref: "scripts/ci/test_nightly_incident.sh#delayed, missing, duplicate, malformed, foreign, and identity-mismatch cases"
        status: pass
    human_judgment: false
  - id: D3
    description: "Red/red/green overlap with the middle pending drainer replaced preserves the middle verdict once and converges the single rolling incident to closed."
    requirement: EVID-04
    verification:
      - kind: integration
        ref: "scripts/ci/test_nightly_incident.sh#three-overlap replacement replays A-red/B-red/C-green exactly once"
        status: pass
    human_judgment: false
  - id: D4
    description: "Deterministic markers suppress duplicate real mutations, while repeated green with no incident remains successful without a marker or false acknowledgement."
    requirement: EVID-04
    verification:
      - kind: integration
        ref: "scripts/ci/test_nightly_incident.sh#same complete log replay and repeated green no-incident cases"
        status: pass
    human_judgment: false
  - id: D5
    description: "Fresh all-state preimages and bounded full replay converge after drift or uncertain mutation outcomes and fail closed on exhaustion."
    requirement: EVID-04
    verification:
      - kind: integration
        ref: "scripts/ci/test_nightly_incident.sh#stale preimage, uncertain mutation, and bounded exhaustion cases"
        status: pass
      - kind: other
        ref: "shellcheck -S warning scripts/ci/eval_nightly_incident.sh scripts/ci/manage_nightly_incident.sh scripts/ci/test_nightly_incident.sh"
        status: pass
    human_judgment: false
duration: 17min
completed: 2026-09-11
status: complete
---

# Phase 133 Plan 19: Immutable Nightly Incident Replay Summary

**Scheduled Nightly verdicts now survive replaceable pending jobs as authenticated immutable events, and one idempotent replay drainer deterministically converges the rolling incident under overlap and mutation races.**

## Performance

- **Duration:** 17 min
- **Started:** 2026-09-11T14:48:41Z
- **Completed:** 2026-09-11T15:06:08Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added a scheduled-only producer that validates and uploads canonical strict-verdict JSON before the incident concurrency gate, while diagnostic dispatch remains event-free and non-mutating.
- Reduced the incident lane to one stable repository/workflow concurrency group with `cancel-in-progress: false` and job-local `actions: read`, `contents: read`, and `issues: write` permissions.
- Replaced single-run check-then-act behavior with authenticated artifact/run inventory, integer run/attempt ordering, all-state issue replay, and action-specific mutation idempotency.
- Proved the replaced-middle red/red/green overlap, same-log replay, unmarked green no-op, evidence rejection, stale preimage, uncertain mutation, and bounded-exhaustion paths in a 15-case stateful matrix.

## Task Commits

Each TDD task was committed as an explicit RED-GREEN pair:

1. **Task 1 RED: immutable event topology contract** - `e74ab14` (test)
2. **Task 1 GREEN: pre-concurrency verdict producer and serialized drainer** - `9ce8569` (feat)
3. **Task 2 RED: immutable replay convergence matrix** - `1543015` (test)
4. **Task 2 GREEN: authenticated idempotent replay manager** - `70aa4b1` (feat)

**Plan metadata:** committed with this summary.

## Files Created/Modified

- `.github/workflows/nightly.yml` - Persists exact scheduled verdict events before the stable non-cancelling incident concurrency group.
- `test/install_smoke/nightly_policy_test.exs` - Parses and enforces producer/drainer ordering, permission, trigger, upload, and concurrency topology.
- `scripts/ci/manage_nightly_incident.sh` - Authenticates ordered run/artifact evidence and reconciles one rolling issue with fresh preimages and deterministic markers.
- `scripts/ci/test_nightly_incident.sh` - Models GitHub runs, artifacts, downloads, all-state issues, mutations, retries, overlap, and failure boundaries.

## Decisions Made

- Current-main scheduled workflow runs through the current run/attempt form the finite replay set; every member must have exactly one canonical, non-expired verdict artifact before issue state is read.
- Existing mutation markers must be unique and ordered; a later applied marker cannot cause an earlier missing transition to be appended out of order.
- Every mutation cycle performs a fresh exact-label all-state inventory comparison immediately before calling GitHub; drift or uncertain command outcome restarts replay rather than advancing durable state.

## TDD Gate Compliance

- **Task 1 RED:** `RED_EVIDENCE_OK`; both parsed topology tests failed because `nightly-incident-verdict` was absent.
- **Task 1 GREEN:** the focused parsed workflow contract passed 6/6 and passed again at the automated tracer feedback gate.
- **Task 2 RED:** `RED_EVIDENCE_OK`; the legacy single-run manager rejected the immutable replay environment and the three-overlap target failed.
- **Task 2 GREEN:** the stateful replay matrix passed 15/15 and warning-level ShellCheck produced no diagnostics.
- **REFACTOR:** no separate refactor commit was needed; the minimal GREEN remained cohesive and fully verified.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Kept generated execution state within its canonical size bound**

- **Found during:** Plan metadata close-out
- **Issue:** The state handlers appended three decisions and produced a 153-line `STATE.md`, exceeding the executor's 150-line state contract.
- **Fix:** Removed four presentation-only blank lines without changing state content or structure.
- **Files modified:** `.planning/STATE.md`
- **Verification:** `wc -l .planning/STATE.md` reports 149 lines and the state SDK still loads the document.
- **Committed in:** Plan metadata commit

---

**Total deviations:** 1 auto-fixed (1 Rule 1 bug)
**Impact on plan:** Metadata formatting only; Nightly evidence and replay behavior are unchanged.

## Issues Encountered

- The repository pins Elixir 1.17.3/OTP 27, which is not installed in this checkout's local asdf inventory. The YAML-parsing ExUnit contract was executed successfully with available Elixir 1.19.5/OTP 27.3.4.15; supported-toolchain authority remains the exact Nightly cell owned by earlier Phase 133 evidence.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 133-22 can reverify EVID-03/EVID-04 against durable pre-gate events, stable non-cancelling replay, and adversarial overlap evidence.
- Later exact-head closure can treat the strict verdict artifact log and deterministic issue mutation history as machine authority without relying on pending-job retention or false no-op acknowledgement state.
- No Plan 133-19 blocker or goal-preventing stub remains.

## Self-Check: PASSED

- All four modified implementation/test files exist, and the four RED/GREEN commits resolve in repository history.
- Parsed workflow verification passed 6/6 tests; the replay matrix passed 15/15 cases; warning-level ShellCheck passed all three incident scripts.
- The three-overlap fixture preserves B's update marker exactly once and leaves the rolling incident closed after A/B/C replay.
- Coverage metadata classifies every shipped deliverable as automated and passing.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-09-11*
