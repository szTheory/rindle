---
phase: 133-evidence-charter-and-live-truth
plan: "124"
subsystem: infra
tags: [phase-133, exact-source, validation, transaction, recovery, github]
requires:
  - phase: 133-119
    provides: Fresh Plan 120 source-fetch route and safe destination guard.
provides:
  - Production validation for fresh Plan 120, 121, 122, and 123 authority artifacts.
  - Plan 123 candidate promotion with a durable pending journal and byte-exact restart recovery.
  - Explicit GitHub exact-ref lookup, pinned clone, and separate remote mutation authorization rows.
affects: [133-120, 133-121, 133-122, 133-123, phase-133-validation]
actuals:
  tokens: 22839
  tasks: 3
  commits: 6
  plan_head_before: acc3b297002c9786845a6eb055bda2af5bd3458c
  plan_head_after: c549736d0c7b30c328375aec3481cfa4eab04180
tech-stack:
  added: []
  patterns:
    - Exact-source and upstream digest binding across the fresh authority chain.
    - Durable transaction journal retained until terminal consistency passes.
    - Byte-preserving append records for frozen authority inputs.
key-files:
  created:
    - scripts/maintainer/phase_133_plan118_commit.exs
    - .planning/phases/133-evidence-charter-and-live-truth/133-124-SUMMARY.md
  modified:
    - scripts/maintainer/validate_phase_133_reconciliation.exs
    - test/install_smoke/phase_133_reconciliation_test.exs
    - .planning/phases/133-evidence-charter-and-live-truth/COVERAGE.md
key-decisions:
  - "Keep Plan 115–118 evidence historical; fresh authority starts with Plan 120 and binds the exact source and independent digests."
  - "Accept the Plan 123 validation-ledger suffix only when the original frozen prefix and terminal proof digest both match."
  - "Clear the Plan 123 journal only after terminal proof, the five status writes, summary binding, and consistency checks pass."
  - "This plan establishes validator and recovery readiness only; it grants zero requirement credit."
patterns-established:
  - "Plan 123 recovery restores original bytes and verifies them before clearing a pending journal."
  - "A failed ordinary terminal read after clearance recreates the journal and rolls back the copied tree."
requirements-completed: []
requirements-addressed: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
qualification_credit: 0
coverage:
  - id: D1
    description: "Fresh Plan 120 source and Plan 121 census authority pass production validation; substituted historical evidence, changed source/digests, and early requirement closure fail."
    verification:
      - kind: integration
        ref: "test/install_smoke/phase_133_reconciliation_test.exs#Plan 121 production authority accepts only the exact Plan 120 source and census authority"
        status: pass
    human_judgment: false
  - id: D2
    description: "Plan 122 and Plan 123 validation bind the exact candidate and accept only the byte-preserving Plan 123 ledger append tied to terminal proof."
    verification:
      - kind: integration
        ref: "test/install_smoke/phase_133_reconciliation_test.exs#Plan 123 terminal validation accepts only its exact append to the frozen validation digest"
        status: pass
    human_judgment: false
  - id: D3
    description: "Plan 123 promotion remains pending until terminal proof and recovers byte-exactly after injected write faults or a failed ordinary terminal read."
    verification:
      - kind: integration
        ref: "test/install_smoke/phase_133_reconciliation_test.exs#every interrupted promotion restores original bytes and the five pending IDs on restart"
        status: pass
      - kind: integration
        ref: "test/install_smoke/phase_133_reconciliation_test.exs#recovery failure keeps the pending journal until idempotent byte-exact restore succeeds"
        status: pass
      - kind: integration
        ref: "test/install_smoke/phase_133_reconciliation_test.exs#a failed ordinary terminal read after clearance recreates the journal and rolls back"
        status: pass
    human_judgment: false
  - id: D4
    description: "The GitHub capability matrix records the exact read-only ref lookup and pinned clone, with separate Plan 120 and Plan 122 literal authorization boundaries."
    verification:
      - kind: other
        ref: "./scripts/maintainer/automation_first_contract.sh"
        status: pass
      - kind: other
        ref: "grep -Fq rows for git ls-remote --heads origin, pinned git clone, Plan 115 non-transfer, and separate Plan 122 authorization"
        status: pass
    human_judgment: false
duration: "1h 8m"
completed: 2026-10-07
status: complete
---

# Phase 133 Plan 124: Evidence Charter and Live Truth Summary

**Fresh Plan 120–123 validators now bind exact-source authority, while Plan 123 promotion uses a durable rollback journal and the GitHub matrix records distinct read and mutation gates.**

## Performance

- **Duration:** 1h 8m, measured from the first task commit through close-out.
- **Started:** 2026-10-07T21:43:06-04:00 (first task commit).
- **Completed:** 2026-10-07T22:51:45-04:00.
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments

- Added fresh Plan 121 authority validation over authenticated Plan 120 inputs, exact-source census receipts, twelve taxonomy dimensions, unique dispositions, frozen ledger, upstream digests, and the eleven flagged edge rows. Plan 122/123 validators bind the remote candidate and terminal proof without treating an authorization answer as requirement evidence.
- Added the Plan 123 journaled promotion and recovery entry point. Copied-tree tests cover every declared write interruption, idempotent byte-exact restoration, pending-journal denial, and rollback after an ordinary terminal-reader failure.
- Added exact GitHub capability rows for `git ls-remote --heads origin` and the pinned Plan 120 `git clone`, and kept Plan 122 publish/dispatch behind a separate fresh literal checkpoint.
- Kept EVID-01, EVID-02, EVID-03, EVID-04, and TRUTH-08 Pending with zero qualification credit. No network fetch, remote mutation, requirement closure, or shared state/roadmap update was performed.

## Task Commits

Each task was committed atomically; the TDD tasks have separate RED and GREEN commits:

1. **Task 1 RED: fresh-chain authority test** — `63c8c100` (`test(133-124)`).
2. **Task 1 GREEN: Plan 120–121 authority validation** — `5155267d` (`feat(133-124)`).
3. **Task 2 RED: pending Plan 123 journal test** — `d55cbbee` (`test(133-124)`).
4. **Task 2 GREEN: Plan 123 transaction and recovery** — `d88e1116` (`feat(133-124)`).
5. **Task 3: GitHub coverage gates** — `64c29834` (`docs(133-124)`).
6. **Supplemental: require literal Plan 122 decision context** — `c549736d` (`test(133-124)`).

## Files Created/Modified

- `scripts/maintainer/validate_phase_133_reconciliation.exs` — fresh Plan 120–123 authority, candidate, and terminal validation.
- `scripts/maintainer/phase_133_plan118_commit.exs` — Plan 123 transaction, durable journal, and restart recovery entry point.
- `test/install_smoke/phase_133_reconciliation_test.exs` — copied-tree authority, terminal, fault-injection, and rollback coverage.
- `.planning/phases/133-evidence-charter-and-live-truth/COVERAGE.md` — exact GitHub lookup, pinned clone, and separate mutation authorization rows.

## Verification

- `ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 MIX_ENV=test mix test test/install_smoke/phase_133_reconciliation_test.exs --seed 0` — 110 tests, 0 failures.
- Focused terminal-append, Plan 122 literal-checkpoint, and post-clear rollback tests — 110 tests discovered, 0 failures, 108 excluded.
- `./scripts/maintainer/automation_first_contract.sh` — passed after Task 2 and Task 3.
- Acceptance checks confirmed all five requirement entries remain Pending, both exact GitHub command rows exist, Plan 115 authorization is non-transferable, and Plan 122 mutation authorization is separate.
- Worktree diff check passed; no changes were made to STATE.md, ROADMAP.md, REQUIREMENTS.md, or the existing 133-VALIDATION.md evidence.

## Decisions Made

- Preserve the original validation ledger bytes exactly and permit only the specific Plan 123 proof suffix after terminal completion.
- Keep the pending journal through the final consistency proof; if the ordinary terminal reader rejects the cleared result, recreate the journal and restore all snapshots.
- Keep this work at zero requirement credit; terminal acceptance belongs to the later Plan 123 execution with an actual authenticated candidate.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Created the missing Plan 123 transaction entry point**

- **Found during:** Task 2, when the required `read_first` path `scripts/maintainer/phase_133_plan118_commit.exs` was absent from this worktree.
- **Issue:** The Plan 123 transaction could not be adapted from the referenced Plan 118 entry point because that source file was not present.
- **Fix:** Created the required entry point with the Plan 123 candidate, journal, terminal-proof, and recovery contract.
- **Files modified:** `scripts/maintainer/phase_133_plan118_commit.exs`.
- **Verification:** Full reconciliation suite and focused recovery tests passed.
- **Committed in:** `d88e1116`.

**Total deviations:** 1 auto-fixed (Rule 3 - blocking source file absent).
**Impact on plan:** The required Plan 123 output path now exists and is covered by copied-tree failure tests; no live evidence or requirement credit was created.

## Issues Encountered

The first focused run exposed that a duplicate keyword-list entry kept the default terminal callback in the rollback test. The test now uses `Keyword.put/3`; the focused rerun and full suite pass.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 120 can freeze its source with the Plan 124 validator and transaction changes already in the tree. Plan 120 still requires its own fresh literal fetch authorization; Plan 122 publish/dispatch authorization remains separate. All five Phase 133 requirements remain Pending until terminal reconciliation.

## Self-Check: PASSED

- All four task deliverable files and this SUMMARY exist.
- All six task commits exist on this worktree branch.
- The prescribed full reconciliation suite and automation-first contract passed.
- Five requirement IDs remain Pending; eleven flagged rows and existing validation evidence were not edited.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-10-07*
