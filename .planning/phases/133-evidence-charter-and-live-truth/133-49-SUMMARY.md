---
phase: 133-evidence-charter-and-live-truth
plan: "49"
subsystem: planning-evidence
tags: [nightly, exact-sha, compatibility-matrix, immutable-history, halted]

requires:
  - phase: 133-48
    provides: exact-subject review gate and one-time SHA/ref authorization
provides:
  - Immutable record of the consumed Plan 49 Nightly attempt
  - Confirmation that the previous canonical receipt and five pending requirements remain unchanged
affects: [133, EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]

actuals:
  tokens: 3200
  tasks: 1
  commits: 1
plan_head_before: 68b1c82390b506da343116f49b943f05442692b0

tech-stack:
  added: []
  patterns:
    - One exact authorized Nightly attempt is immutable after any qualification failure
    - Compatibility coverage failures retain history but grant no requirement credit

key-files:
  created:
    - .planning/phases/133-evidence-charter-and-live-truth/133-49-SUMMARY.md
  modified:
    - .planning/ROADMAP.md
    - .planning/STATE.md
    - .planning/state.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-VALIDATION.md
    - .planning/phases/133-evidence-charter-and-live-truth/133-VERIFICATION.md
    - .planning/phases/133-evidence-charter-and-live-truth/continue.md

key-decisions:
  - "Preserve SHA 68b1c82390b506da343116f49b943f05442692b0, ref refs/heads/phase-133-evidence-68b1c82390b5, and run 36274589243 attempt 1 as exhausted immutable history."
  - "Keep EVID-01 through EVID-04 and TRUTH-08 pending; the failed Nightly run grants no acceptance credit."

requirements-completed: []
coverage: []
qualification: failed
terminal_automation: halted
subject_sha: 68b1c82390b506da343116f49b943f05442692b0
published_ref: refs/heads/phase-133-evidence-68b1c82390b5
run_id: 36274589243
run_attempt: 1
run_conclusion: failure
failed_compat_jobs:
  - "Compat Matrix (1.17, 27)"
  - "Compat Matrix (1.15, 26)"
  - "Compat Matrix (1.18, 27)"
  - "Compat Matrix (1.16, 26)"
  - "Compat Matrix (1.18, 28)"
failed_aggregate_job: "Nightly Summary — Enforce strict Nightly verdict"
receipt_sha256: 1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4
candidate_receipt: absent
halt_reason: "immutable Nightly run 36274589243 attempt 1 completed with failure: all five supported Compat Matrix jobs failed at Run tests with coverage, causing the strict Nightly Summary verdict to fail; no candidate receipt was created or promoted"
duration: "not reliably measured across the interrupted session"
completed: 2026-09-26
status: halted
---

# Phase 133 Plan 49: Authorized Nightly Attempt Summary

**The one authorized Plan 49 Nightly attempt ran to completion and failed in all five compatibility-matrix coverage jobs; its exact history is preserved, with the prior receipt and all five requirements unchanged.**

## Attempt identity

- Authorized subject: `68b1c82390b506da343116f49b943f05442692b0`
- Published ref: `refs/heads/phase-133-evidence-68b1c82390b5`
- Dispatch-owned run: [36274589243](https://github.com/szTheory/rindle/actions/runs/36274589243), attempt 1
- Workflow: `Nightly`, event `workflow_dispatch`, branch and SHA matched the authorized pair
- Run result: `completed`, conclusion `failure`
- Failed compatibility jobs: `Compat Matrix (1.17, 27)`, `(1.15, 26)`, `(1.18, 27)`, `(1.16, 26)`, and `(1.18, 28)`; each failed at step `Run tests with coverage`
- Strict aggregate: `Nightly Summary` failed at `Enforce strict Nightly verdict`
- The GitHub log endpoint was intermittently unavailable during this handoff. The exact failing assertions still need a bounded read in the next repair plan; no root cause is inferred here.

## Mutations and preserved authority

- The census ledger was committed locally as `300161fc8564ebadfac8d56c9bce94a9712a0408` so the exact-subject collector could validate a tracked, clean ledger before dispatch.
- One non-force push created the authorized ref and exactly one dispatch-and-record invocation created run `36274589243`. No workflow rerun or second dispatch was made.
- The collector rejected the completed run and removed its private candidate; `/private/tmp/rindle-phase133-49-nightly-candidate.json` is absent.
- The canonical receipt remains unchanged at SHA-256 `1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4`.
- EVID-01, EVID-02, EVID-03, EVID-04, and TRUTH-08 remain pending. No requirement receives credit from authorization or the failed run.
- Run `36274589243`, attempt 1, its SHA, and ref are exhausted immutable history. Do not rerun, relabel, delete, replace, force-push, or reuse them. A future attempt requires a repaired subject, fresh evidence gates, and a new exact-pair authorization.

## Automated checks completed before the one-way action

- The exact-subject independent review gate passed for the census subject.
- Exact-subject census and validator passed in a detached authority worktree.
- `./scripts/maintainer/automation_first_contract.sh` passed.
- `bash scripts/ci/test_verify_nightly_run.sh` passed 168 checks with zero failures.
- Exact GitHub repository, workflow, absent-ref, and preflight checks passed before publication.
- The worktree create/remove approval path was exercised and left only the primary checkout registered.
- Post-halt production reconciliation was attempted with the available Elixir/OTP toolchain and approved loopback access. It currently exits at `pending state differs for 133-42-01:1`: the Plan 42 record preserves its immutable halt, while the legacy production mapping still derives `pending`. The next gap plan must repair this status mapping without rewriting Plan 42's outcome.

## Halted work

Task 1 ended in the plan's terminal-failure branch. Task 2 was not run: there is no candidate to qualify or promote. Do not update canonical evidence or close requirements. The next gap plan should first retrieve the immutable failed-job logs when GitHub is reachable, identify the shared coverage failure mechanism across the five toolchains, repair the Plan 42 halted-state mapping discrepancy, add focused regression evidence, and pass the complete local gates before any future authorization checkpoint.

## Self-check

- Plan 49 is `status: halted`, `qualification: failed`, `terminal_automation: halted`, with zero completed requirements.
- The five requirements remain pending and the prior canonical receipt hash is unchanged.
- No private candidate receipt exists; the immutable Nightly run is preserved.
