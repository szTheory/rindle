---
phase: 133-evidence-charter-and-live-truth
plan: "165"
subsystem: testing
tags: [node, registry, preflight, guard-proof, worktree]
requires:
  - phase: 133-164
    provides: Canonical Plan 154 ESM entry guard and detached-checkout regression
provides:
  - Distinct-root Plan 154 comparison that normalizes only the validated worktree root
  - Guard, report, source, cache, and zero-authority regression coverage
affects: [133-163, 133-121, 133-122, 133-123, registry-qualification]
actuals:
  tokens: 3968.25
  tasks: 2
  commits: 3
plan_head_before: 47145a961e3f92f5859b051629a921ccbecbd3ff
plan_head_after: 85c4f176bf821c89a37440a955f552b0c0059319
duration: 19min
completed: 2026-10-11
tech-stack:
  added: []
  patterns: [authenticate the receipt and live guard before normalizing one root field and recomputing its digest]
key-files:
  created:
    - .planning/phases/133-evidence-charter-and-live-truth/133-165-TDD-RED-EVIDENCE.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-165-SUMMARY.md
  modified:
    - scripts/maintainer/phase_133_registry_closure_154.mjs
    - scripts/maintainer/phase_133_registry_closure_154.test.mjs
key-decisions:
  - Only guard.worktree_root is relocatable; all other report and guard fields remain comparison inputs.
  - Keep all five requirements Pending and qualification credit at zero; this repair grants no authority.
requirements-completed: []
coverage:
  - id: D1
    description: The authenticated committed Plan 154 preflight verifies from two distinct clean canonical roots without changing the receipt.
    verification:
      - kind: unit
        ref: scripts/maintainer/phase_133_registry_closure_154.test.mjs#authenticated Plan 154 preflight verifies from either of two distinct clean roots
        status: pass
    human_judgment: false
  - id: D2
    description: Host, executable, launcher, profile, control, network-denial, root, report, source, and cache mutations fail closed; Plan 163 remains a zero-attempt halt.
    verification:
      - kind: unit
        ref: scripts/maintainer/phase_133_registry_closure_154.test.mjs#distinct-root comparison rejects every guard and report mutation through the production verifier
        status: pass
      - kind: other
        ref: read-only Plan 163 artifact inventory and REQUIREMENTS.md status check
        status: pass
    human_judgment: false
duration: 19min
completed: 2026-10-11
status: complete
commits: 3
---

# Phase 133 Plan 165: Distinct-Root Preflight Summary

**Plan 154's authenticated preflight now verifies from a second clean worktree while only its validated canonical root is normalized for comparison.**

## Performance

- **Duration:** 19 minutes
- **Started:** 2026-10-11T11:39:00Z
- **Completed:** 2026-10-11T11:58:32Z
- **Tasks:** 2
- **Files modified/created:** 4

## Accomplishments

- Reproduced the literal root mismatch with a classifier-approved RED assertion, then changed the distinct-source verifier to authenticate the report and validate the fresh guard before normalizing only `guard.worktree_root`; the comparison digest is recomputed after normalization.
- Added production-path regressions for two canonical roots, byte-identical receipt preservation, and host, actual-host marker, Node executable/version path, launcher, profile, control, denial, root, report, source, and cache mutations. Guard checks use `recovery.probeGuard` and `supply.verifyGuardProof` with stubbed child outcomes, so this regression does not perform network operations.
- Confirmed Plan 163 still has only its PLAN and halted SUMMARY artifacts; all five requirements remain Pending, eleven evidence edges remain unresolved, and qualification credit remains zero.

## Task Commits

1. **Task 1 RED: reproduce the distinct-root preflight mismatch** — `ae2e86cd` (`test`)
2. **Task 1 GREEN: compare distinct-root preflight safely** — `4ac8c538` (`fix`)
3. **Task 2: reject distinct-root guard mutations** — `85c4f176` (`test`)

## Files Created/Modified

- `scripts/maintainer/phase_133_registry_closure_154.mjs` — validates the current guard and compares reports after normalizing only the worktree-root field.
- `scripts/maintainer/phase_133_registry_closure_154.test.mjs` — covers root portability and fail-closed guard/report mutations through the verifier.
- `.planning/phases/133-evidence-charter-and-live-truth/133-165-TDD-RED-EVIDENCE.json` — records the real failing TAP report and `RED_EVIDENCE_OK` classification.
- `.planning/phases/133-evidence-charter-and-live-truth/133-165-SUMMARY.md` — this execution record.

## Verification

- RED: `node --test --test-name-pattern='authenticated Plan 154 preflight verifies from either' scripts/maintainer/phase_133_registry_closure_154.test.mjs` failed on the target portability assertion with `registry_qualification_preflight_mismatch`; `gsd-tools check tdd-red-evidence` returned `RED_EVIDENCE_OK`.
- GREEN/focused suite: `node --test scripts/maintainer/phase_133_registry_closure_154.test.mjs` — 12 passed, 0 failed.
- Combined authority suites: 19 passed, 0 failed. The negative-lookahead name filter did not exclude the live Plan 154 test under Node 20.18.1; see the execution deviation below.
- `./scripts/maintainer/automation_first_contract.sh` — passed.
- `git diff --check` — passed. Evaluation scope resolved the three plan commits on this branch.
- Read-only artifact/status check — Plan 163 has only its PLAN and halted SUMMARY, and EVID-01 through EVID-04 and TRUTH-08 remain Pending.

## TDD Gate Compliance

- **RED:** `ae2e86cd` contains the targeted failing two-root assertion. The TAP record identifies `registry_qualification_preflight_mismatch` as the observed failure.
- **GREEN:** `4ac8c538` implements root-only normalization and the focused suite passed.
- **REFACTOR:** None needed.
- **Task 2 regression commit:** `85c4f176` adds mutation coverage without changing production behavior.

## Decisions Made

- Recompute the normalized report digest after replacing only the comparison copy's `guard.worktree_root`; authenticate the original receipt before normalization and leave its bytes untouched.
- Keep requirement completion empty. The fix repairs a prerequisite and provides no qualification or requirement credit.

## Deviations from Plan

**1. Test-scope filter failed to exclude the live preflight test**

- **Found during:** Task 2 combined authority-suite verification.
- **Issue:** The command used a negative-lookahead `--test-name-pattern` to avoid the real Plan 154 `qualification-preflight` test, but Node 20.18.1 ran that test anyway. Its detached child variants performed the read-only actual-host preflight, including the local loopback network-denial probe. This exceeded the explicit execution fence.
- **Fix:** No rerun was made. The temporary detached test checkout was cleaned by the test; a read-only check confirmed no Plan 163 preflight, supply, retrieval, authorization, attempt, or local-gates artifact was created in this worktree.
- **Files modified:** None beyond planned implementation, tests, and this summary.
- **Verification:** Plan 163 artifact inventory contains only `133-163-PLAN.md` and `133-163-SUMMARY.md`; all five requirements remain Pending and credit remains zero.

**Total deviations:** 1 execution-scope deviation. **Impact:** The verifier repair and regressions passed, but the explicitly prohibited read-only Plan 154 preflight was invoked by the broader test suite; no Plan 163 authority or qualification output was produced.

## Issues Encountered

- Writing the required plan ledger under Git's shared metadata directory was denied by the workspace sandbox on the first attempt. The authorized Git operation was retried with sandbox access; the RED commit and subsequent commits ran normally with hooks enabled.

## User Setup Required

None.

## Next Phase Readiness

The cross-worktree comparison prerequisite is repaired and committed. Plan 163 remains an immutable zero-attempt halt; a separately reviewed successor is still required before Plans 121–123 can proceed. No requirements were completed and no qualification credit was recorded.

## Self-Check: PASSED

- Source, regression, RED evidence, and SUMMARY files exist.
- All three measured task commits are ancestors of HEAD; plan evaluation scope resolves them.
- Both summary deliverables classify as fully automated with passing evidence.
- Plan 163 retains only its PLAN and halted SUMMARY; all five requirements remain Pending.
- `automation_first_contract.sh` passed after SUMMARY creation. STATE.md and ROADMAP.md are unchanged.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-10-11*
