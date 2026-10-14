---
phase: 133-evidence-charter-and-live-truth
plan: "66"
subsystem: evidence
tags: [phase-133, exact-subject, local-gates, halted, zero-credit]
requires:
  - phase: 133-65
    provides: "Committed source-only reconciler handoff for one fresh local qualification attempt."
provides:
  - "Immutable exact-subject local gate report and production-reconciled halt reason."
affects: [phase-133-evidence-charter-and-live-truth]
requirements-completed: []
actuals:
  tasks: 1
  commits: 1
  plan_head_before: 24564cad2418f1bd60bc2348c9bf700be913516a
tech-stack:
  added: []
  patterns:
    - "A red exact-subject CI gate is terminal for its one-shot attempt and stops before coverage, census, independent authorities, and remote lookup."
key-files:
  created:
    - .planning/phases/133-evidence-charter-and-live-truth/133-66-LOCAL-GATES.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-66-SUMMARY.md
  modified:
    - .planning/ROADMAP.md
key-decisions:
  - "The only Plan 66 attempt halted at CI after the compiled JOSE include was missing from the detached test build; do not retry this subject."
  - "Plans 67 and 68 remain blocked; no remote lookup, publication, dispatch, census, or requirement credit follows a red gate."
requirements-pending: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
duration: "not recorded"
completed: 2026-10-01
status: halted
qualification: local-gates-failed
halt_stage: local-gates
halt_gate: ci
subject_sha: 6d58a02a1e5dee97b7d24750c7a583b4f06b4236
subject_tree: 6fbaa11ae67f5685bf0e343f947fe07186a13672
plan65_source_sha: 6d58a02a1e5dee97b7d24750c7a583b4f06b4236
local_gates_sha256: 5d7e1feba55d3858872d0105c9528295295a7296a0ea838c6a9fc4f33e1c4132
prior_receipt_sha256: 1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4
halt_reason: "mix ci exited 1 because the detached test build could not find _build/test/lib/jose/include/jose_jwt.hrl (ENOENT); no test count was emitted and coverage was not started."
remote_action: none
remote_ref: null
remote_lookup: not_run
census: not_run
production_reconciliation_exit_code: 0
automation_first_contract_exit_code: 0
terminal_reconciliation: passed
terminal_automation_first: passed
---

# Phase 133 Plan 66: Exact-Subject Local Gate Halt

**The one local qualification attempt for Plan 65 source `6d58a02a1e5dee97b7d24750c7a583b4f06b4236` halted at `mix ci`; the attempt grants no requirement credit and cannot be retried.**

## Result

The runner used its clean detached worktree at Elixir 1.17.3 / OTP 27 for the exact Plan 65 source SHA. Dependency retrieval exited 0, and the focused JOSE preflight exited 0 with the expected source header present and readable. The subsequent `mix ci` command exited 1 while compiling lib/jose/jwt.ex: its expected staged `_build/test/lib/jose/include/jose_jwt.hrl` was absent (`ENOENT`). CI emitted no test count. The saved report records the first failed gate as `ci` and binds it to SHA-256 `5d7e1feba55d3858872d0105c9528295295a7296a0ea838c6a9fc4f33e1c4132`.

Halt reason: mix ci exited 1 because the detached test build could not find _build/test/lib/jose/include/jose_jwt.hrl (ENOENT); no test count was emitted and coverage was not started.

Coverage was not started (`invocations: 0`). Census receipts, independent review/security/validation authorities, and the read-only remote-ref lookup were not started. The canonical prior Nightly receipt remains byte-identical at SHA-256 `1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4`.

## Task Outcome

- Task 1 performed the single permitted exact-subject local attempt and retained its bounded report. Its red CI result ends Plan 66 before any census work.
- Task 2 was skipped under the plan's red-gate branch.
- All five Phase 133 requirements remain pending. There is no candidate, ref handoff, remote lookup, publication, dispatch, or incident mutation.
- Plan 67 remains blocked pending a qualified Plan 66 outcome; Plan 68 remains blocked on Plan 67. Plans 56, 60, and 61 remain blocked as before.

## Halt Validation

Production reconciliation exited 0 with `--expect-plan66-halted`; the canonical prior receipt digest check and `./scripts/maintainer/automation_first_contract.sh` also exited 0.

## Coverage

| Check | Result |
|---|---|
| Runner invocation | bash scripts/maintainer/phase_133_local_gates.sh --subject 6d58a02a1e5dee97b7d24750c7a583b4f06b4236 --output .planning/phases/133-evidence-charter-and-live-truth/133-66-LOCAL-GATES.json — run exactly once; exit 1 after the failed CI gate |
| Conditional coverage | Not started; zero invocations after failed CI |
| Census and independent authorities | Not started under the required red-gate branch |
| Production halted-state reconciliation | Pass |
| Prior canonical receipt digest and automation-first contract | Pass |

---
*Phase: 133-evidence-charter-and-live-truth*
*Status: halted — immutable local-gate failure*
