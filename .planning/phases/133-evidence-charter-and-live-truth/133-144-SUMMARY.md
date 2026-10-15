---
phase: 133-evidence-charter-and-live-truth
plan: "144"
subsystem: testing
tags: [node, git, immutable-evidence, copied-checkout, one-shot-authority]
requires:
  - phase: 133-142
    provides: Independent Plan 143 production verifier and historical copied-checkout machinery
provides:
  - Authenticated frozen-source selection for fresh Plan 143 copied production checks
  - Complete suite regression before and after authentic preflight publication
  - Protected-history comparison and executable production one-shot rejection with zero credit
affects: [133, evidence-integrity, registry-fixtures]
actuals:
  tokens: 4098
  tasks: 2
  commits: 4
plan_head_before: 9005aab0a075b5b29db666efe7bdcd2fd26b1541
plan_head_after: 99f8d906e90cc4a303f9803d274400e1e3dd79ac
tech-stack:
  added: []
  patterns: [Pinned receipt identity and source ancestry, Bounded independent child suites, Complete disposable Git histories]
key-files:
  created:
    - .planning/phases/133-evidence-charter-and-live-truth/133-144-TASK-1-RED.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-144-TASK-2-RED.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-144-VERIFICATION.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-144-SUMMARY.md
  modified:
    - test/install_smoke/phase_133_registry_supply_test.mjs
key-decisions:
  - "Select the authentic Plan 143 frozen source SHA only after committed-byte, semantic digest, object and ancestry checks."
  - "Use complete disposable histories and independently reported child suites to exercise the actual production one-shot gate."
  - "Preserve terminal Plan 143 evidence, all five Pending requirements, eleven unresolved edge rows and zero qualification credit."
patterns-established:
  - "Published one-shot receipts select their authenticated pre-publication source for fresh copied fixtures."
  - "Child suite success requires exact test counts and passing named production checks, with the parent regression excluded only to prevent recursion."
requirements-completed: []
requirements-addressed: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
requirements_pending: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
coverage:
  - id: D1
    description: Fresh Plan 143 copies use authenticated frozen source; absent receipts use committed HEAD and invalid identity, missing objects or nonancestor sources fail closed.
    verification:
      - kind: unit
        ref: "test/install_smoke/phase_133_registry_supply_test.mjs#Plan 143 fresh copied checkout archives the frozen source before publication"
        status: pass
      - kind: unit
        ref: "test/install_smoke/phase_133_registry_supply_test.mjs#Plan 143 copied source selection uses HEAD before publication and rejects altered receipts"
        status: pass
      - kind: unit
        ref: "test/install_smoke/phase_133_registry_supply_test.mjs#Plan 143 copied source selection rejects missing objects and nonancestor sources"
        status: pass
    human_judgment: false
  - id: D2
    description: Both isolated history states pass the complete child suite and named production regressions; published-history production rejects another preflight without creating authority.
    verification:
      - kind: integration
        ref: "test/install_smoke/phase_133_registry_supply_test.mjs#Plan 143 complete suite stays green before and after frozen preflight publication"
        status: pass
      - kind: other
        ref: "node --test test/install_smoke/phase_133_registry_supply_test.mjs"
        status: pass
    human_judgment: false
  - id: D3
    description: Frozen receipts, eight source blobs, shared planning state and live Hex cache remain unchanged; five requirements remain Pending and eleven edge rows unresolved.
    verification:
      - kind: other
        ref: ".planning/phases/133-evidence-charter-and-live-truth/133-144-VERIFICATION.json#all_protected_unchanged"
        status: pass
      - kind: other
        ref: "./scripts/maintainer/automation_first_contract.sh"
        status: pass
    human_judgment: false
duration: 14 min
completed: 2026-10-09
status: complete
---

# Phase 133 Plan 144: Copied Registry History Repair Summary

**Authenticated frozen-source copies keep the registry suite green across preflight publication while preserving the production one-shot guard and terminal zero-credit history.**

## Performance

- **Duration:** 14 min
- **Started:** 2026-10-09T20:56:00Z
- **Completed:** 2026-10-09T21:10:06Z
- **Tasks:** 2
- **Files created/modified:** 5
- **Actuals:** 4098 tokens, measured as committed task-diff characters divided by four; 4 task commits measured from the persisted plan ledger. Metadata is committed separately.

## Accomplishments

- Fresh Plan 143 fixtures archive frozen source `38a615d26808d716772bd0b6de48088a45c718b4` when the authentic committed receipt is present. Selection validates committed bytes, production snapshot semantics, exact digest `a16233b4d8bc191f8393df7533b51cc5d5203645199f94f950a63d61b566a58a`, Git object existence and ancestry. Without a receipt, selection uses committed HEAD. Explicit copied-checkout revision callers and Plan 134 historical verification retain their behavior.
- An automated regression builds two independent Git histories with alternates, overlays and commits current production/test bytes, and runs bounded child suites before and after publication. The published receipt comes from preserved commit `9a666a814e08bf28742c504b504a2ae48d43072a`. A separate production CLI invocation in the complete published history rejects a second preflight at the one-shot gate.
- All 386 protected baseline files remain byte-identical, with 43 important before/after comparisons and eight authenticated frozen input blobs recorded in `133-144-VERIFICATION.json`. This includes `133-VALIDATION.md` and its existing edit, Plan 143 terminal evidence, production code, shared orchestrator artifacts and the live Hex cache.

## Task Commits

Each task followed RED then GREEN with normal commit hooks:

1. **Task 1 RED: Require the frozen copied source** — `eb4641ca` (`test`)
2. **Task 1 GREEN: Authenticate and archive the frozen source** — `4d0c2abc` (`feat`)
3. **Task 2 RED: Require committed source in each history** — `ee60bafa` (`test`)
4. **Task 2 GREEN: Prove full suites across publication** — `99f8d906` (`feat`)

**Plan metadata:** This summary and the final verification record are committed separately. Shared progression remains owned by the orchestrator.

## Files Created/Modified

- `test/install_smoke/phase_133_registry_supply_test.mjs` — frozen-source selector, adversarial identity checks and complete pre/post-publication suite regression.
- `133-144-TASK-1-RED.json` — actual failing frozen-source equality assertion and unchanged TAP output.
- `133-144-TASK-2-RED.json` — actual failing source-commitment equality assertion and unchanged TAP output.
- `133-144-VERIFICATION.json` — final TAP, history counts, tracer result, protected-file hashes, frozen blobs, artifact absence and Pending/unresolved checks.
- `133-144-SUMMARY.md` — plan execution and automated coverage.

## Decisions Made

The frozen source SHA remains the sole historical source identity. Receipt presence does not permit borrowing authority: the receipt must be committed and match the exact preserved identity before selection.

History copies materialize the complete Git tree and preserve file modes so production reaches its real one-shot rejection. Child runners clear inherited `NODE_TEST_CONTEXT`; exact TAP counters reject silent zero-test success. The parent history regression is not registered in its child invocation, preventing recursion without skipped tests.

## Verification

- Final `node --test test/install_smoke/phase_133_registry_supply_test.mjs`: **exit 0; 38 passed, 0 failed, 0 cancelled, 0 skipped, 0 todo**.
- **Before publication:** **37/37 child tests pass**, including both formerly failing production test names.
- **After publication:** **37/37 child tests pass**, including both names; the actual published-history production CLI returns exit 1 with `Plan 143 one-shot artifacts or signed object already exist`. The authentic receipt remains unchanged.
- The child suites execute every test except their owning parent history regression. The parent suite contains all 38 tests and proves both child outcomes.
- Task 1 focused verification: **5/5 pass**. The committed tracer gate rerun proves both formerly failing tests: **2/2 pass**.
- Both persisted RED records return **RED_EVIDENCE_OK** with intentional named assertion failures.
- Automation-first contract, Node syntax and `git diff --check`: passed.
- Disposable publication/source fixtures were cleaned; the one directory left by the temporary assertion-formatting crash was identified by its receipt/log and removed.
- No implementation stubs, skipped tests, unrun planned verification or new production endpoint remains. No structural codebase-map update is required.

## TDD Gate Compliance

| Task | Intentional RED | GREEN | Commit sequence |
| --- | --- | --- | --- |
| 1 | Copied parent SHA was publication HEAD instead of frozen source | Source selector, adversarial cases and both production regressions pass | `eb4641ca` → `4d0c2abc` |
| 2 | Isolated history bound the old test blob instead of committed current source | Complete pre/post-publication suites and real one-shot rejection pass | `ee60bafa` → `99f8d906` |

No separate refactor was needed.

## Zero-Authority and Protected-History Evidence

- Plan 143 remains immutable terminal zero-request history; its preflight, summary and post-freeze diagnostics are unchanged.
- Eight frozen implementation/test input blobs still match their recorded SHA-256 and Git object IDs.
- No live Plan 143 authorization, request-started marker, retrieval, supply or signed object was created.
- No package installation, mux registry request, new live tuple, native qualification run or Hex-cache write occurred.
- **Qualification credit: 0. Requirements completed: 0.**
- **EVID-01, EVID-02, EVID-03, EVID-04 and TRUTH-08 remain Pending. All eleven edge rows remain unresolved.**
- `STATE.md`, `ROADMAP.md`, `REQUIREMENTS.md`, `WINDOWS.md`, `PROJECT.md` and configuration remain unchanged.

Synthetic authorization/request cases in the existing suite exercise disposable structural fixtures. They do not constitute live signed mux supply or downstream acceptance evidence.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Avoided an oversized Buffer assertion diff.**
- **Found during:** Task 1 GREEN negative receipt verification.
- **Issue:** Formatting a dirty receipt against the large authentic Buffer exhausted Node's heap.
- **Fix:** Compare `Buffer.equals` with a boolean assertion; remove the identified disposable crash residue.
- **Files modified:** `test/install_smoke/phase_133_registry_supply_test.mjs`.
- **Verification:** Five focused checks, tracer rerun and final 38-test suite pass.
- **Committed in:** `4d0c2abc`.

**2. [Rule 3 - Blocking] Established independent child test-runner reporting.**
- **Found during:** Task 2 GREEN verification.
- **Issue:** Inherited `NODE_TEST_CONTEXT` returned status 0 without TAP; the required exact-count assertion correctly rejected it.
- **Fix:** Clear that variable in bounded child environments while retaining the explicit recursion sentinel.
- **Files modified:** `test/install_smoke/phase_133_registry_supply_test.mjs`.
- **Verification:** Both child histories report 37 passing tests and the parent reports 38 passing tests.
- **Committed in:** `99f8d906`.

**3. [Rule 3 - Blocking] Materialized complete published-history checkouts.**
- **Found during:** Task 2 GREEN negative production check.
- **Issue:** The existing selected-file archive left missing tracked files, so production stopped at its clean-checkout gate before the one-shot guard.
- **Fix:** Extract the complete frozen Git archive, preserve tracked modes, and assert a clean initial checkout before publication/overlay commits.
- **Files modified:** `test/install_smoke/phase_133_registry_supply_test.mjs`.
- **Verification:** Published-history production rejects another preflight with the exact one-shot diagnostic; both history suites pass.
- **Committed in:** `99f8d906`.

**[Rule 2 - Missing Critical] Withheld unearned requirement-completion metadata.** The generic template requests the plan's IDs under `requirements-completed`, but this plan explicitly preserves Pending status and AGENTS.md requires automated acceptance before closure. Following Plans 142/143, this summary records the original IDs under `requirements-addressed` and leaves `requirements-completed: []`. Shared requirement and defect-register writes are reserved for the orchestrator.

**Total deviations:** 3 resolved implementation/fixture issues (1 bug, 2 blockers), plus 1 workflow metadata adjustment. **Impact:** Test-fixture correctness and truthful reporting only; no product scope, production authority or requirement status changed.

## Issues Encountered

The temporary Buffer-formatting and nested-runner/partial-checkout failures were resolved within the corresponding GREEN task. The final suite and protected-history checks pass with no remaining blocker in this plan.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

The copied-fixture prerequisite is repaired and proven across publication. Plan 143 remains terminal and must not be retried or have its digest transferred as authorization. A replacement supply route, any new tuple and any mux request require separate planning and fresh authorization. Downstream automated qualification remains necessary; all five requirements and eleven edge rows remain open. The orchestrator owns shared phase progression.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-10-09*

## Self-Check: PASSED

All five created/modified files exist and all four task commits are ancestors of HEAD. The tested source hash matches the committed source. Final evidence proves 38/38 parent tests, 37/37 in each history, production one-shot rejection, eight intact frozen blobs and 386 unchanged protected files. Automation-first and all three automated coverage classifications pass. Shared orchestrator artifacts remain unchanged.
