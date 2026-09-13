---
phase: 133-evidence-charter-and-live-truth
plan: "37"
subsystem: planning-evidence
tags: [nightly, exact-sha, immutable-history, fail-closed, halted]

requires:
  - phase: 133-36
    provides: exact authorization for one non-force ref publication and one Nightly dispatch
provides:
  - Immutable exhausted history for ref phase-133-evidence-4ab38ab62878 and run 34732110533
  - Fail-closed preservation of the prior canonical Nightly receipt and pending requirement claims
affects: [133, EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]

actuals:
  tokens: 3552
  tasks: 1
  commits: 0
plan_head_before: 0f36ff86ae57ca0d77748c03ee32a1a775380811

tech-stack:
  added: []
  patterns:
    - One authorized ref and run become immutable exhausted history after any post-publication qualification failure
    - A green remote run does not substitute for the complete local and live qualification matrix

key-files:
  created:
    - .planning/phases/133-evidence-charter-and-live-truth/133-37-SUMMARY.md
  modified:
    - .planning/ROADMAP.md
    - .planning/STATE.md
    - .planning/WINDOWS.md

key-decisions:
  - "Preserve ref phase-133-evidence-4ab38ab62878 and run 34732110533 as immutable exhausted history; never retry, replace, rerun, cancel, delete, or reuse them."
  - "Keep the prior canonical receipt byte-identical and EVID-01 through EVID-04 plus TRUTH-08 pending because post-publication qualification failed."

requirements_completed: []
qualification: failed
terminal_automation: halted
halt_reason: "immutable run 34732110533 exhausted after detached exact-SHA census qualification could not start the uncompiled :rindle application"
duration: 22min
completed: 2026-09-12
status: halted
---

# Phase 133 Plan 37: Authorized Nightly Attempt Summary

**One exact non-force ref and one dispatch-owned green Nightly run were created, then preserved as immutable exhausted history when the mandatory post-publication qualification matrix failed before canonical receipt promotion.**

## Performance

- **Duration:** 22 min
- **Started:** 2026-09-13T01:52:00Z
- **Halted:** 2026-09-13T02:14:15Z
- **Tasks completed:** 1 of 2
- **Tracked files changed:** summary, ROADMAP, STATE, and the broken-windows ledger

## Immutable Attempt Record

- **Authorized SHA:** `4ab38ab62878eea936f20bb76e2f7321da6c2e90`
- **Published ref:** `refs/heads/phase-133-evidence-4ab38ab62878`
- **Dispatch-owned run:** `34732110533`, attempt `1`
- **Workflow result:** completed `success` with strict verdict `green`
- **Collector result:** candidate receipt written to explicit executor scratch and verified twice against the live run
- **Canonical receipt:** unchanged at SHA-256 `1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4`
- **Requirements:** EVID-01, EVID-02, EVID-03, EVID-04, and TRUTH-08 remain pending

The ref, SHA, and run are exhausted immutable history. No second dispatch, workflow rerun, force push, ref replacement, cancellation, deletion, or reuse is permitted.

## Automated Results

- Pre-publication exact SHA/ref/authorization/ref-absence gates passed.
- The repository-wide preflight passed `mix ci`, 1,621 tests plus doctests, 97 contract tests, cycle detection, the refactor contract, collector tests, focused Phase 133 tests, reconciliation, automation-first validation, and prior canonical receipt verification.
- The sole collector invocation selected exactly run `34732110533`; the candidate independently verified twice against the authorized SHA/ref and green run.
- Post-publication census fixtures passed 20 tests with zero failures.
- The next mandatory detached exact-SHA census generation gate failed because the clean worktree lacked compiled `rindle.app`; Mix could not start `:rindle`.
- Remaining qualification, promotion, and terminal-completion gates were not run after the terminal failure, as the one-attempt contract requires.

## Deviations from Plan

### Auto-fixed Command Drift Before Publication

**1. [Rule 3 - Blocking] Used repository-native census and refactor entry points**

- **Found during:** Task 1 preflight
- **Issue:** The plan names removed census wrapper scripts and a nonexistent `mix refactor` task.
- **Resolution:** Used the existing ExUnit census suite, detached generator/validator scripts, and `scripts/maintainer/refactor_contract.sh`, matching Plan 35's recorded repository-native equivalents.

**2. [Rule 3 - Blocking] Used the collector's current positional CLI contract**

- **Found during:** Task 1 verification
- **Issue:** Plan snippets use `--mode verify-receipt`, omit required live identity arguments, and refer to `.head_sha`; the tracked collector requires positional `verify-receipt`, explicit repo/workflow/ref/SHA arguments, and records `.subject_sha`.
- **Resolution:** Ran the tracked CLI contract with the exact authorized identities.

## Known Stubs

None.

## Deferred Issues

- The clean detached exact-SHA census command cannot start without compiled application artifacts. This is the terminal Plan 37 qualification failure, not authority to retry the consumed ref/run.
- All qualification commands after that failure are intentionally unrun; a new subject/ref/authorization cycle is required before another remote attempt.

## Self-Check: PASSED

- Plan 37 summary exists with `status: halted`, `requirements_completed: []`, and the immutable run identity.
- The prior canonical receipt matches its pre-attempt SHA-256 byte for byte.
- ROADMAP records 37/37 summarized with Plans 27, 32, and 37 halted and Plan 37 unchecked.
- STATE records Phase 133 blocked at Plan 37.
