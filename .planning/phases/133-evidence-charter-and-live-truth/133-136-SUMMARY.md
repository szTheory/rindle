---
phase: 133-evidence-charter-and-live-truth
plan: "136"
subsystem: infra
tags: [qualification, authority, offline, first-red, terminal-transaction]
requires:
  - phase: 133-150
    provides: production-verified signed mux supply and original producer provenance
provides:
  - Fresh Plan 129 source, signed supply, literal decision and one-shot authority enforcement
  - Guarded Node authority regression before every qualification Mix stage
  - Fresh Plan 129 and Plan 150 terminal writer bindings with pending-journal protection
affects: [133-129, 133-121, 133-122, 133-123]
actuals:
  tokens: 19315
  tasks: 2
  commits: 4
plan_head_before: 00f1f6821799c816909f78cbeb58de3dae754d61
tech-stack:
  added: []
  patterns: [explicit historical read-only validation, authenticated private Hex staging, first-red child ordering]
key-files:
  created: [scripts/maintainer/phase_133_plan129_authority.test.mjs]
  modified:
    - scripts/maintainer/phase_133_recovery.mjs
    - scripts/maintainer/phase_133_local_gates.sh
    - scripts/maintainer/phase_133_local_supply.mjs
    - scripts/maintainer/validate_phase_133_reconciliation.exs
    - scripts/maintainer/phase_133_plan118_commit.exs
    - scripts/maintainer/test_phase_133_local_gates.sh
    - test/install_smoke/phase_133_reconciliation_test.exs
key-decisions:
  - "Delegate signed supply readback to the preserved Plan 150 producer, checking committed and current receipt bytes."
  - "Require a distinct Plan 129 source and qualification decision; no Plan 126 permission or terminal tuple transfers."
  - "Preserve Plan 126 fixtures only through explicit read-only historical validation; current terminal credit requires Plan 129."
requirements-completed: []
requirements-addressed: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
requirements_pending: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
coverage:
  - id: D1
    description: Fresh source and signed supply authority reject historical substitutions and altered input bytes.
    verification:
      - kind: unit
        ref: "node --test scripts/maintainer/phase_133_plan129_authority.test.mjs"
        status: pass
    human_judgment: false
  - id: D2
    description: Authority-first order, every first-red boundary, guard denial and exclusive attempts are executable harness contracts.
    verification:
      - kind: integration
        ref: "bash scripts/maintainer/test_phase_133_local_gates.sh"
        status: pass
    human_judgment: false
  - id: D3
    description: Current writer requires fresh authority and all interruption paths preserve pending-journal zero credit.
    verification:
      - kind: integration
        ref: "ASDF_ERLANG_VERSION=27.3.4.15 ASDF_ELIXIR_VERSION=1.17.3-otp-27 ERL_FLAGS='+S 2:2' MIX_ENV=test mix test test/install_smoke/phase_133_reconciliation_test.exs --seed 0"
        status: pass
    human_judgment: false
completed: 2026-10-10
completed_at: 2026-10-10T17:34:32Z
status: complete
qualification_credit: 0
unresolved_edge_rows: 11
network_request_count: 0
qualification_attempt_count: 0
---

# Phase 133 Plan 136: Fresh Qualification Authority

Fresh Plan 129 authority is enforced from source and original signed supply through the guarded runner and recoverable terminal writer. Seven pure Node regressions, the complete runner harness and all 116 reconciliation tests passed. Plan 136 implemented and tested the guards; it did not freeze Plan 129 source, retrieve supply, authorize qualification or run an actual qualification attempt.

## Accomplishments

- Production Plan 129 modes bind its own source/tree, independent supply, distinct literal answer, exclusive attempt and guarded result. Original Plan 150 committed receipts, sole GET, signed cache key and fresh offline readback remain authoritative from the preserved producer.
- The runner executes one positive Node authority suite before dependency retrieval. Zero-test pseudo-green, authority red, host denial, existing markers and CI red stop all later children. The JOSE diagnostic Mix lookup is separately counted and cannot run after CI red.
- Current reconciliation and terminal transaction require Plan 129 plus Plan 150 digests. Historical Plan 126 readers require explicit read-only mode; pending and faulted journals retain all five Pending statuses and zero credit.

## Task Commits

1. Task 1 RED: `9511d980` — missing fresh verifier export produced the intended assertion failures. Task 1 implementation: `c6917e6a`.
2. Task 2 RED: `5909b9d5` — fresh writer tuple was rejected by the old Plan 126-only mandatory keys. Final implementation, migration and first-red correction: `082c75f5`.

The GSD TDD evidence classifier returned `RED_EVIDENCE_OK` for both intended regression failures before their implementation. Evidence records remain in `_build/phase133-plan136-evidence/red.json` and `writer-red.json`; the writer evidence is a Node TAP wrapper around the actual targeted ExUnit exit and checks the intended assertion diagnostic before classifying red. Failed exploratory formatter setup was excluded from RED evidence.

## Verification

- Node authority suite: **7 tests, 7 passed, 0 failed**.
- Full runner harness: passed exact-source sequencing, authenticated staging, first-red and no-clobber assertions.
- Full pinned ExUnit reconciliation suite: **116 tests, 0 failures**, seed 0; 845.1 seconds. `ERL_FLAGS='+S 2:2'` bounds local scheduler use without changing the selected runtime.
- Existing private-cache isolation regression: **9 tests, 9 passed, 0 failed**.
- Production consumer readback: original Plan 150 supply `8b6f252791e5c032dd2d9f659d230cb2467c3046ecdf1f1ead710321afae5737`, correct `[versions, hexpm, mux]` cache key and 132 authenticated supported-runtime Hex files; fresh OS-denied-network readback, no GET.
- Read-only offline input audit: all 67 locked archives, Vix asset and pinned Lexbor repository (959 file hashes) authenticated. Reversible private copies were prepared for the following Plan 129, with no qualification child or request.
- Node/Bash syntax, pinned Elixir formatting, diff checks and automation-first contract passed. The contract is rerun after this closeout's planning writes.

| Current verification log | Raw SHA256 |
|---|---|
| `/private/tmp/rindle-p136-authority-green.tap` | `6fcc59498a32b3c259cdac747a6b5b1598a9562f5a8ce9de0c28a3e31268164e` |
| `/private/tmp/rindle-p136-runner-final.log` | `a82d6ecc8fedc0380f20146ddcc01d7daf5e9b90a4e34323c32de3de57f7a5cd` |
| `/private/tmp/rindle-p136-mix-reconciliation-final.log` | `46fff94f8092fa068420ad88aa30d6d9ef338daec7edc9d06c1f1484d04636d7` |
| `/private/tmp/rindle-p136-cache-regression.log` | `37c006621c16091d11a68fe52f69e37d2ad1ce3f77b8a92cefcb4b4b6570f9c2` |
| `/private/tmp/rindle-p136-producer-readback.log` | `971c0cf1df053c7422fad223242b47cf31e8c8edb28e67200696220a653ca522` |
| `/private/tmp/rindle-p136-offline-input-audit.log` | `4106e62b68d9ed47fb5c3bebe53f97cf09cbca4472cf6f0138469dd05256cb3f` |
| `/private/tmp/rindle-p136-automation-contract.log` | `ff8222dd1d5ae823f0ac49d5ddfdd8dba2917e62485c7dd302b31216bb9db413` |

## Deviations from Plan

**Necessary local supply staging extension:** `phase_133_local_supply.mjs` was added to the recorded worktree scope. Plan 129 needs to stage the authenticated supported-runtime Hex build and signed registry cache into private offline directories; its collected manifest now authenticates both. Terminal verification also preserves frozen requirement/Nightly input bytes after the later authorized terminal transaction. This is required for the planned production qualification and transaction consumer; historical Plan 126 behavior remains explicit and read-only.

**Additional first-red boundary:** inspection found a diagnostic `mix run` could execute after CI failed. The Plan 129 path now stops that child and coverage, and the Node suite and runner harness prove the ordering and separate counters.

## Issues Encountered

The isolated executor initially lacked generated compiled dependency directories needed by nested historical Mix fixtures. Existing local compiled dependencies were copied privately into ignored build directories; the required pinned Mix test command then ran normally. A historical decision fixture still used current validation during the first full run; it was changed to explicit historical mode, its focused test passed, and the final complete 116-test suite passed. No unresolved test failure remains.

## Next Plan Readiness

Ready to freeze new source and authenticate offline supply in Plan 129's own GSD-created executor. Keep the original Plan 150 proof checkout and durable bytes. Its mux authorization is consumed and grants no qualification authority. Plan 129's separate blocking decision must follow production verification of its concrete source, preflight, supply and command. Plans 121–123 remain blocked until a distinct green qualification result exists. Five requirements remain Pending, eleven edges unresolved, qualification credit zero, Phase 133 incomplete and Phase 132 last completed.
