---
phase: 133-evidence-charter-and-live-truth
plan: "127"
subsystem: infra
tags: [elixir, exunit, exact-source, offline-supply, transaction, recovery]
requires:
  - phase: 133-125
    provides: Independent Plan 126 admission, schema-2 supply, and guarded qualification reports.
  - phase: 133-124
    provides: Production downstream validators and the recoverable Plan 123 writer.
provides:
  - Production authority bound to the fresh Plan 126 -> 121 -> 122 -> 123 chain.
  - Authenticated durable supply and committed-source drift rejection after qualification cleanup.
  - Exact private-candidate and automated terminal-proof binding with byte-exact Pending recovery.
affects: [133-126, 133-121, 133-122, 133-123]
actuals:
  tokens: 15839
  tasks: 2
  commits: 4
  plan_head_before: 4e9758ed75e6f1032a2a78aa0be1b9cf7f4a58f0
  plan_head_after: 013f6ac183fadd9c73b361066bc2970b499ca052
tech-stack:
  added: []
  patterns:
    - Reauthenticate durable locked inputs through the existing offline-supply helper.
    - Bind source, authority digests, candidate bytes, and automated proof before status closure.
    - Retain the recovery journal until original bytes and all five Pending IDs verify.
key-files:
  created:
    - .planning/phases/133-evidence-charter-and-live-truth/133-127-SUMMARY.md
  modified:
    - scripts/maintainer/validate_phase_133_reconciliation.exs
    - scripts/maintainer/phase_133_plan118_commit.exs
    - test/install_smoke/phase_133_reconciliation_test.exs
key-decisions:
  - "Plan 126 authority uses schema-2 supply and its own preflight, authorization, local-gates, and qualification-attempt digests; historical Plan 115/120 artifacts cannot substitute."
  - "Committed code changes after the source freeze remain disqualifying even when later reverted."
  - "A restart before journal clearance restores original bytes; a restart after clearance preserves the already verified completed transaction."
  - "This plan grants zero qualification credit and leaves all five live requirements Pending."
patterns-established:
  - "Ordinary terminal readers reject every pending journal, including partially restored transactions."
  - "Final transaction consistency revalidates fresh upstream authority while the journal remains pending."
requirements-completed: []
qualification_credit: 0
coverage:
  - id: D1
    description: Fresh Plan 126 source, supply, authorization, and census authority pass while historical substitutions, forged reports, digest tampering, and source drift fail.
    verification:
      - kind: integration
        ref: "test/install_smoke/phase_133_reconciliation_test.exs#Plan 121 production authority accepts only fresh Plan 126 source and census authority"
        status: pass
      - kind: integration
        ref: "test/install_smoke/phase_133_reconciliation_test.exs#fresh authority rejects historical decisions forged green and post-freeze drift"
        status: pass
    human_judgment: false
  - id: D2
    description: Private candidate bytes, exact source/tree, fresh authority digests, zero credit, and automated terminal proof remain bound through promotion.
    verification:
      - kind: integration
        ref: "test/install_smoke/phase_133_reconciliation_test.exs#production preterminal validation rejects private source and authority substitution"
        status: pass
      - kind: unit
        ref: "test/install_smoke/phase_133_reconciliation_test.exs#terminal proof requires automated exact-source and fresh authority binding"
        status: pass
      - kind: unit
        ref: "test/install_smoke/phase_133_reconciliation_test.exs#terminal journal rejects historical Plan 120 authority substitution"
        status: pass
    human_judgment: false
  - id: D3
    description: Production copied transactions prove success, all 19 interruption points, all six recovery-file boundaries, Pending-reader denial, and exact five-status ordering.
    verification:
      - kind: integration
        ref: "test/install_smoke/phase_133_reconciliation_test.exs#fresh production transaction proves success and byte-exact restart at every boundary"
        status: pass
      - kind: unit
        ref: "test/install_smoke/phase_133_reconciliation_test.exs#recovery retains its journal until all five restored IDs are Pending"
        status: pass
      - kind: unit
        ref: "test/install_smoke/phase_133_reconciliation_test.exs#recovery failure keeps the pending journal until idempotent byte-exact restore succeeds"
        status: pass
      - kind: other
        ref: "./scripts/maintainer/automation_first_contract.sh"
        status: pass
    human_judgment: false
duration: 1h 42m
completed: 2026-10-08
status: complete
---

# Phase 133 Plan 127: Fresh Downstream Authority and Terminal Recovery Summary

**Production reconciliation now binds Plan 126's exact source and durable supply to Plans 121–123, with automated proof before five-status closure and verified Pending rollback before journal clearance.**

## Performance

- **Duration:** 1h 42m
- **Started:** 2026-10-08T13:20:50Z
- **Completed:** 2026-10-08T15:03:02Z
- **Tasks:** 2/2
- **Files modified:** Three implementation/test files plus this summary.
- **Actuals:** 63,355 characters / 4, rounded up to 15,839 tokens over the committed task diff. Four task commits measured from the persisted plan ledger; this metadata commit is outside that interval.

## Accomplishments

- Rebased production authority on Plan 126's schema-2 supply, independent authorization and qualification attempt, supported runtime, authenticated locked archives, Vix checksum, durable Lexbor source, and recorded guard/stage proof. Exact SHA/tree checks reject dirty or committed code drift, including a later revert. Existing twelve-dimension census, frozen dispositions, eleven flagged rows, and historical policy/truth regression coverage remain intact.
- Bound both public and private Plan 122 candidate identity to fresh authority. The writer requires the exact validated private bytes and persists proof bound to SHA, tree, candidate digest, authority digest, and `automated: true`. Ordinary terminal validation reconstructs the expected proof digest and requires the cleared/consistent summary state.
- Exercised default production validators through copied success and 19 interruption points, including summary proof and both sides of journal clearance. Tests compare actual checkbox/table statuses with the journal's ordered writes, prove exactly five changes, preserve all eleven flagged rows, and retry recovery at each of six snapshot paths. Internally consistent recovery hashes with a completed original ID cannot clear the journal.

## Task Commits

1. **Task 1 RED:** `e87751cd832c485bfd8dddcb565a8ae79c3b5a45` — `test(133-127): reject the obsolete Plan 120 authority route`
2. **Task 1 GREEN:** `37c123829fa4cc85f743cfd347460556216d07e0` — `feat(133-127): bind downstream authority to fresh Plan 126 proof`
3. **Task 2 RED:** `0bf9affe448af53837ce01466f3996095da4737c` — `test(133-127): reject unbound terminal proof and unsafe recovery`
4. **Task 2 GREEN:** `013f6ac183fadd9c73b361066bc2970b499ca052` — `feat(133-127): bind terminal recovery to fresh automated proof`

**Plan metadata:** Separate `docs(133-127)` commit containing this summary only. STATE.md, ROADMAP.md, REQUIREMENTS.md, and other shared orchestrator artifacts were not modified.

## Files Created/Modified

- `scripts/maintainer/validate_phase_133_reconciliation.exs` — Fresh lineage, durable input authentication, frozen-source checks, private candidate binding, and terminal summary proof validation.
- `scripts/maintainer/phase_133_plan118_commit.exs` — Fresh journal authority, exact candidate bytes, automated proof binding, final upstream revalidation, extra interruption points, and verified Pending recovery.
- `test/install_smoke/phase_133_reconciliation_test.exs` — Independent copied archive/source fixtures, authority mutation regressions, real production transaction coverage, and recovery/status-order assertions.
- `133-127-SUMMARY.md` — Execution evidence and zero-credit close-out.

## TDD Gate Compliance

- **Task 1 RED:** The named production authority test executed and failed its planned acceptance assertion: expected exit 0 for fresh Plan 126 evidence, actual exit 1 while the old validator requested Plan 120 evidence. Complete unchanged JUnit output and console output are retained in `_build/phase133-127-task1-red.json`. `check tdd-red-evidence` returned `RED_EVIDENCE_OK`; semantic inspection confirmed an intended assertion failure, not a load or fixture error.
- **Task 1 GREEN:** Fresh authority and mutation tests passed. The complete planned suite passed **111 tests, 0 failures**, followed by the required tracer rerun with **111 tests, 0 failures**.
- **Task 2 RED:** Three executed tests exposed acceptance of non-automated proof, completed recovery originals, and substituted Plan 120 authority. `_build/phase133-127-task2-red.json` preserves the actual unchanged JUnit report and console output. The named proof-binding target failed on success instead of rejection; GSD returned `RED_EVIDENCE_OK`, and semantic inspection confirmed all three planned assertions failed for their intended reasons.
- **Task 2 GREEN:** The complete planned suite passed **116 tests, 0 failures**, followed by the automation-first contract. A final test-only strengthening of actual status ordering passed the focused transaction run: **8 tests passed, 108 excluded by the explicit tag filter**. Production code was unchanged after the full run.
- **REFACTOR:** No separate cleanup was necessary. Both tasks have RED commits preceding GREEN commits; no gate violations or skipped required verification.

## Verification

- `ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 MIX_ENV=test mix test test/install_smoke/phase_133_reconciliation_test.exs --seed 0` — **PASS**, final full run 116 tests / 0 failures. Tracer and final runs inherited `ERL_FLAGS='+S 4:4'`; the required test command, seed, and versions were unchanged.
- The same test command with `--only plan127_transaction` after the final assertion enhancement — **PASS**, 8 selected tests / 0 failures; `_build/phase133-127-task2-status-order.log`.
- `./scripts/maintainer/automation_first_contract.sh` — **PASS**.
- `mix format --check-formatted` on all three changed code/test files and `git diff --check` — **PASS**.
- GSD branch-local evaluation scope resolves all four task commits. Explicit checks confirm exactly one unchecked and one Pending entry for each of EVID-01/02/03/04 and TRUTH-08.
- Base comparison confirms the entire existing `.planning/` tree, including Plan 120 history, canonical receipt, PROJECT, REQUIREMENTS, STATE, and ROADMAP, remained unchanged before adding this summary.

## Decisions Made

Use the existing offline-supply authentication routines for durable post-cleanup evidence rather than launching qualification again. Keep journal clearance as the commit point: all earlier interruptions restore original bytes; a restart after clearance preserves the verified result. Qualification and remote action remain separate future gates and provide no acceptance credit here.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Populate isolated test caches from existing local dependencies**
- **Found during:** Task 1 verification setup.
- **Issue:** The new worktree lacked dependencies and compiled test output, preventing the prescribed Mix test command from starting.
- **Fix:** Copied existing local dependency/build caches into ignored worktree-local `deps/` and `_build/test/`, then compiled and tested the worktree sources. No package installation or source-checkout mutation was performed.
- **Files modified:** Ignored local caches only; no additional tracked files.
- **Verification:** Both complete Task 1 runs and the complete Task 2 suite passed.
- **Commit:** No cache commit; documented in this metadata commit.

**Total deviations:** 1 auto-fixed blocker. **Impact:** Test-environment setup only; no product-scope change, new dependency, or omitted check.

## Issues Encountered

Early overlapping verification attempts exhausted local PostgreSQL connections and were stopped. Those interrupted runs were not accepted as evidence. Definitive full runs were serialized against stable code and HEAD. A warning introduced by a dynamically loaded test helper was fixed before final verification.

## User Setup Required

None for this plan. All delivered acceptance evidence is executable and copied-tree based.

## Next Phase Readiness

Ready for Plan 126 to freeze a source containing these validators and the recoverable writer. No live fetch, native qualification, remote publication, or canonical promotion occurred. The five live requirements remain Pending, all eleven flagged rows remain visible, and immutable Plan 120 history retains zero credit. Shared planning state remains owned by the orchestrator.

## Self-Check: PASSED

All declared files exist. All four task commits are ancestors of this worktree's HEAD and resolve through GSD's branch-local evaluation scope. Both RED records passed machine classification and semantic review. Required full-suite, tracer, focused recovery, formatting, and automation checks passed. Coverage classification reports three automatically covered deliverables with no errors. No production stubs or unrun required checks remain.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-10-08*
