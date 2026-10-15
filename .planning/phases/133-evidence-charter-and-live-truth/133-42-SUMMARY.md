---
phase: 133-evidence-charter-and-live-truth
plan: "42"
subsystem: planning-evidence
tags: [nightly, exact-sha, immutable-history, fail-closed, halted]

requires:
  - phase: 133-41
    provides: exact authorization for one non-force ref publication and one Nightly dispatch
provides:
  - Immutable exhausted history for ref phase-133-evidence-c83f61379ad5 and run 34768317696
  - Fail-closed preservation of the prior canonical Nightly receipt and pending requirement claims
affects: [133, EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]

actuals:
  tokens: 3789
  tasks: 1
  commits: 0
plan_head_before: a072c7c75f00235a57f2306818a5eac0e05be783

tech-stack:
  added: []
  patterns:
    - One authorized ref and run become immutable exhausted history after any Nightly gating failure
    - A failed exact-subject attempt cannot promote candidate evidence or complete requirements

key-files:
  created:
    - .planning/phases/133-evidence-charter-and-live-truth/133-42-SUMMARY.md
  modified:
    - .planning/ROADMAP.md
    - .planning/STATE.md
    - .planning/WINDOWS.md

key-decisions:
  - "Preserve ref phase-133-evidence-c83f61379ad5 and run 34768317696 as immutable exhausted history; never retry, replace, rerun, cancel, delete, or reuse them."
  - "Keep the prior canonical receipt byte-identical and EVID-01 through EVID-04 plus TRUTH-08 pending because the sole Nightly attempt failed."

requirements_completed: []
qualification: failed
terminal_automation: halted
subject_sha: c83f61379ad5033efef9afa7b5bc88913080bae2
published_ref: refs/heads/phase-133-evidence-c83f61379ad5
run_id: 34768317696
run_attempt: 1
receipt_sha256: 1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4
halt_reason: "immutable run 34768317696 exhausted after the supported Elixir 1.15 / OTP 26 Nightly compatibility cell failed its coverage test step"
duration: 15min
completed: 2026-09-13
status: halted
---

# Phase 133 Plan 42: Authorized Nightly Attempt Summary

**The exact authorized ref and sole dispatch-owned Nightly run were created once, then preserved as immutable exhausted history when a supported compatibility cell failed before candidate receipt creation or canonical promotion.**

## Performance

- **Duration:** 15 min
- **Started:** 2026-09-13T16:15:05Z
- **Halted:** 2026-09-13T16:28:12Z
- **Tasks completed:** 1 of 2
- **Tracked files changed:** summary, ROADMAP, STATE, and broken-windows ledger only

## Immutable Attempt Record

- **Authorized SHA:** `c83f61379ad5033efef9afa7b5bc88913080bae2`
- **Published ref:** `refs/heads/phase-133-evidence-c83f61379ad5`
- **Dispatch-owned run:** `34768317696`, attempt `1`
- **Workflow result:** completed `failure`
- **Failed gating job:** `Compat Matrix (1.15, 26)` at `Run tests with coverage`
- **Strict aggregate:** `Nightly Summary` failed at `Enforce strict Nightly verdict`
- **Incident jobs:** `Persist Nightly Incident Verdict` and `Nightly Incident Lifecycle` were skipped; open incident `#88` remained byte-for-byte unchanged in the bounded snapshot
- **Mutation counts:** one non-force ref creation, one workflow dispatch, zero incident mutations, zero receipt promotions
- **Candidate receipt:** never created
- **Canonical receipt:** unchanged at SHA-256 `1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4`, subject `1470cf8cb0f111d0b233efbf77ee69e92f25fd68`, ref `phase-133-evidence-1470cf8cb0f1`, run `34638437301`
- **Requirements:** EVID-01, EVID-02, EVID-03, EVID-04, and TRUTH-08 remain pending

The ref, SHA, and run are exhausted immutable history. No second dispatch, workflow rerun, force push, ref replacement, cancellation, deletion, authority transfer, or reuse is permitted.

## Automated Results

- The TDD behavior-adding predicate returned false because this plan adds no non-test source file; no MVP+TDD gate applied.
- Immediately before mutation, the census, Plan 40, and Plan 41 agreed on the exact SHA/ref; Plan 41 recorded `decision: authorize`; the prior receipt and reconciliation branch revalidated; the exact ref was absent through a successful read.
- Prior halted runs `34661043059`, `34670574306`, and `34732110533` retained their exact attempt, SHA, ref, workflow, status, and conclusion identities.
- The prior canonical receipt passed live exact-run, job, incident, package, truth, and detached local-authority verification.
- Current reconciliation passed at 38 completed, Plans 27/32/37 halted, one pending, and 41/42 summarized; automation-first validation passed.
- The one non-force push created only the authorized ref at the authorized SHA. The one collector invocation selected only run `34768317696`.
- The run completed with 11 jobs: seven successful gating jobs, failed `Compat Matrix (1.15, 26)`, failed strict `Nightly Summary`, and two skipped incident jobs.
- The collector failed closed before writing the private candidate. The old canonical receipt, all five pending requirements, and the pre-attempt incident snapshot remained unchanged.
- Task 2 qualification, canonical promotion, and completion gates were not run after the terminal attempt failure.

## Task Commits

No production task commit was created. The external ref/run are immutable evidence, and the halted summary plus sequential tracking are captured by the final plan metadata commit.

## Deviations from Plan

None. The plan's specified failure branch was executed exactly after the sole immutable attempt failed.

## Known Stubs

None.

## Deferred Issues

- Run `34768317696` failed the supported Elixir 1.15 / OTP 26 compatibility cell during coverage. This exact ref/run cannot be retried or reused.
- Task 2's candidate, local matrix, promotion, and terminal-completion verifications were intentionally not run because Task 1 entered the permanent halted branch.

## Authentication Gates

None. Covered GitHub access was authenticated and authorized for the exact bounded operation.

## Threat Flags

None. No new code, endpoint, authentication path, file-access boundary, or schema surface was introduced.

## Self-Check: PASSED

- Plan 42 summary exists with `status: halted`, `requirements_completed: []`, and immutable run `34768317696` attempt `1`.
- The prior canonical receipt remains byte-identical at SHA-256 `1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4`.
- The repository-private candidate is absent.
- ROADMAP records 42/42 summarized with Plans 27, 32, 37, and 42 halted and unchecked.
- STATE records Phase 133 blocked at Plan 42.
- EVID-01, EVID-02, EVID-03, EVID-04, and TRUTH-08 remain pending in both requirement authorities.
