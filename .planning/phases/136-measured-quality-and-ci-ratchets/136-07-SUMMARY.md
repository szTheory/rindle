---
phase: 136-measured-quality-and-ci-ratchets
plan: 07
subsystem: quality
status: complete
tags: [qualification, evidence, ci, async]
requirements-completed: [MAINT-04, TYPE-03, COV-06, TEST-08, CI-15, DX-05]
requirements-deferred: [CI-16]
key-files:
  created: [136-QUALIFICATION-CLOSEOUT.json, 136-COVERAGE-EVIDENCE-SPEED.json, 136-DIALYZER-EVIDENCE-SPEED.json, 136-BOOTSTRAP-EVIDENCE-SPEED.json, 136-ASYNC-RESULT-SPEED.json]
  modified: [.planning/async-jobs/136-07-final-measurements.json]
key-decisions:
  - Preserve the qualification verifier's blocked timing verdict; the user-deferred numeric target earns no credit.
  - Reconcile the completed external job without resubmission or source edits.
coverage:
  - deliverable: Final-source measurement receipts and truthful qualification
    verification:
      - kind: command
        ref: bash scripts/maintainer/verify_phase136_qualification.sh verify --subject-file .planning/phases/136-measured-quality-and-ci-ratchets/136-SUBJECT-SPEED.json --manifest .planning/phases/136-measured-quality-and-ci-ratchets/136-QUALIFICATION-CLOSEOUT.json
        status: pass
    human_judgment: false
duration: external collection approximately 2h30m; reconciliation 10min
completed: 2026-10-21
---

# Phase 136 Plan 07: Final-subject qualification summary

The existing external job produced authenticated final-source coverage, fresh/restored Dialyzer, clean bootstrap, 25-seed isolation, quality-policy and regression evidence. The qualification manifest truthfully reports six complete authorities and blocked timing; the numeric speed target remains deferred unfinished to SEED-261021-918 with zero speed credit.

## Accomplishments

- Reconciled the completed `136-07-final-measurements` job without duplicate collection. All steps in `136-SPEED-LOCAL-COLLECTION.json` exited zero.
- Verified the frozen subject `e2d3b5c759e38c79744a1ef9bade8b6f2d92a2f9`, source projection `9e66e48b2fc64a29f5b973ce28c922eed053cfc3`, and authenticated measurement artifacts on Elixir 1.17.3 / OTP 27.3.4.15 with Node v20.18.1.
- Canonical suite: 3 doctests, 1700 tests, zero failures; 87 excluded, four skipped. Exact coverage is 5206/6329. Prior-phase regression: 228 tests, zero failures, 17 excluded.
- All 25 finite isolation iterations passed. This establishes the finite experiment only; it does not prove every schedule safe. Reopen on a reproducible failure or source change.
- Qualification verify exited zero on resumption, authenticating complete coverage, Dialyzer, bootstrap, async and quality authorities while retaining blocked timing. Verification success authenticates the manifest; it does not turn its blocked aggregate verdict into complete.

## Task Commits

| Work | Commit/evidence |
|---|---|
| Final source and CI topology | e2d3b5c7; Plan 15 summary |
| Existing collection ownership | d11143eb, 4e912332 |
| User-authorized speed deferral and protected merge | 973be4af, 39607058 |
| Final job outputs and reconciliation | This summary's evidence commit |

## Deviations from Plan

The recorded user decision deferred the original exact-ten <=480-second median / <=600-second p95 target. No timing collector was submitted, no timing success is claimed, and historical blocked receipts are preserved. The amended task produces truthful qualification with the exact outstanding authority rather than rerunning the deferred experiment.

## Issues Encountered

The unchanged qualification validator retains the original timing contract, so `136-QUALIFICATION-CLOSEOUT.json` remains `outcome: blocked` and CI-16 is blocked there. Phase verification must assess the explicitly amended requirement separately, retain the deferred target and award zero numeric-speed credit. No validator or frozen source was changed to manufacture acceptance.

## Self-Check: PASSED

The phase prerequisite, source projection, expected artifacts and qualification verification passed on resumption. All outputs are retained with their artifact directories. Plan completion records execution of the amended tasks; the independent phase verifier still owns the phase verdict.
