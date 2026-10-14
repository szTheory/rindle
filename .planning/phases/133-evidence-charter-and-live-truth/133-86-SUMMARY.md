---
phase: 133-evidence-charter-and-live-truth
plan: "86"
subsystem: maintainer-validation
tags: [phase-133, reconciliation, package-guard, zero-credit]
requires:
  - phase: 133-84
    provides: [formatter repair and source-bound reconciliation path]
  - phase: 133-85
    provides: [immutable first-red report and zero-credit halt]
provides:
  - Legacy Plan 65/66 fixtures bound to immutable Plan 64 authority bytes
  - Passing local package-manager and threat-inventory proof after fixture repair
affects: [phase-133-evidence-charter-and-live-truth, maintainer-validation]
actuals:
  tokens: 2637
  tasks: 2
  commits: 3
  plan_head_before: 0b538762ad93543533a8d85adce8a14eb3c014f5
  plan_head_after: 4619039fd2a167bc065db72dbc62e5ea5212708e
tech-stack:
  added: []
  patterns: [immutable-authority-backed fixture construction, zero-credit repair evidence]
key-files:
  created:
    - .planning/phases/133-evidence-charter-and-live-truth/133-86-SUMMARY.md
  modified:
    - test/install_smoke/phase_133_reconciliation_test.exs
    - .planning/phases/133-evidence-charter-and-live-truth/133-VALIDATION.md
key-decisions:
  - "Derive copied fixture digests from immutable Plan 64 artifact bytes; do not alter the live authority or production acceptance rules."
  - "Keep EVID-01, EVID-02, EVID-03, EVID-04, and TRUTH-08 pending; this repair grants no requirement or qualification credit."
patterns-established:
  - "Historical authority fixtures load the introducing commit's artifact bytes and verify that a post-binding mutation is rejected."
requirements-completed: []
requirements-pending: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
qualification: repair-only-zero-credit
plan85_report_sha256: 52adf02fc53743bd6b865e408e3a16fcb64de87b1434ac936d3955ace07a39c7
plan85_summary_sha256: 755db0769d723574b57d78da4892a0bb2512f7e2794ce741d17f5f9783727a4e
plan85_prior_canonical_receipt_sha256: 1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4
remote_action: none
coverage:
  - id: D1
    description: "Plan 65/66 copied fixtures use authentic immutable Plan 64 authority, reject a one-byte mutation, and preserve fail-closed production handling of the stale live digest."
    verification:
      - kind: unit
        ref: "test/install_smoke/phase_133_reconciliation_test.exs --seed 0 (80 tests, 0 failures)"
        status: pass
    human_judgment: false
  - id: D2
    description: "The package-manager guard and threat inventory proof complete without forbidden installs or requirement credit."
    verification:
      - kind: integration
        ref: "scripts/ci/test_phase_133_package_manager_guards.sh (168 checks; 182 tests, 0 failures, 1 excluded)"
        status: pass
      - kind: unit
        ref: "test/install_smoke/phase_133_threat_inventory_test.exs --seed 0 (14 tests, 0 failures)"
        status: pass
    human_judgment: false
duration: 1h 13m
completed: 2026-10-05
status: complete
---

# Phase 133 Plan 86: Immutable Fixture Repair

**The Plan 85 local proof blockers are cleared by repairing stale historical fixtures; all five Phase 133 requirements remain pending.**

## Performance

- **Duration:** 1h 13m
- **Started:** 2026-10-05T11:16:12-04:00
- **Completed:** 2026-10-05T12:29:20-04:00
- **Tasks:** 2
- **Files modified:** 3, including this summary

## Accomplishments

- Updated the Plan 65/66 fixture builder to read Plan 64 authority artifacts from their immutable introducing commit and derive the copied Nyquist digest from those bytes.
- Added a one-byte mutation case that confirms production reconciliation rejects a changed copied authority; updated the Plan 79 production assertion to preserve the fail-closed stale-live-authority behavior.
- Restored the package-manager guard proof and threat-inventory test without edits to either proof implementation. The complete named verification chain passed, and every Phase 133 requirement remains pending.

## Task Commits

1. **Task 1: Reconcile authentic Plan 64 authority through the legacy CI path** — `6a2e4907` (`test(133-86): bind legacy fixtures to immutable Plan 64 authority`)
2. **Task 2: Restore and reconcile the package-manager executable proof** — `4619039f` (`docs(133-86): record zero-credit repair evidence`)

## Files Created/Modified

- `test/install_smoke/phase_133_reconciliation_test.exs` — historical authority fixture binding, mutation rejection, and stale live Plan 79 expectation.
- `.planning/phases/133-evidence-charter-and-live-truth/133-VALIDATION.md` — append-only Plan 86 commands, results, fingerprints, and zero-credit boundary.
- `.planning/phases/133-evidence-charter-and-live-truth/133-86-SUMMARY.md` — this task closeout.

## Decisions Made

- Use immutable Plan 64 artifact bytes as the fixture source and compute the digest from the copied section; leave historical source documents and production reconciliation rules unchanged.
- Treat the Plan 85 report as an immutable first-red result. Do not retry or promote its subject; no remote lookup, publication, or dispatch was performed.

## Deviations from Plan

Task 2 did not require changes to the guard script or threat-inventory test. Fixing Task 1's stale fixture made the existing package proof pass as written, preserving its canary, no-install, and full-suite checks.

## Issues Encountered

- The baseline reconciliation command exited 2 with 79 tests and 5 failures. Four Plan 65/66 fixture cases stopped on the stale Plan 64 Nyquist digest; the Plan 79 production fixture also expected acceptance despite that live digest being stale. The fixture now uses immutable authority bytes, and the production assertion expects fail-closed rejection.
- The repaired full reconciliation suite passed with 80 tests and 0 failures. The package guard reported 168 shell checks and a nested suite of 182 tests, 0 failures, 1 excluded; the threat-inventory suite reported 14 tests and 0 failures.

## User Setup Required

None.

## Next Phase Readiness

Plan 86 completed its repair work with zero acceptance credit. Plan 85 remains an immutable halted result; Plan 86 does not qualify a new exact subject or authorize later qualification or remote actions. EVID-01, EVID-02, EVID-03, EVID-04, and TRUTH-08 remain pending.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-10-05*
