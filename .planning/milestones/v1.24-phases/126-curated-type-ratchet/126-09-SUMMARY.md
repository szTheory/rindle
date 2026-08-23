---
phase: 126-curated-type-ratchet
plan: "09"
subsystem: ci
tags: [dialyzer, nightly, github-actions, type-ratchet]
requires:
  - phase: 126-08
    provides: complete curated disposition ledger
provides:
  - immutable exact-head GitHub acceptance receipt
  - closed issue #76 evidence
affects: [release-train, v1.24-closeout]
tech-stack:
  added: []
  patterns: [exact-head authority, immutable external receipt]
key-files:
  created: [.planning/phases/126-curated-type-ratchet/126-09-SUMMARY.md]
  modified: [.planning/phases/126-curated-type-ratchet/126-TYPE-EVIDENCE.md, lib/rindle/storage/gcs/client.ex]
key-decisions:
  - "Only exact-head Nightly 1.17/27 Dialyzer and PR CI Summary authorize the baseline."
  - "The issue receipt binds the authority candidate; later planning metadata is not authority."
requirements-completed: [TYPE-01, TYPE-02, SAFE-01]
coverage:
  - id: D1
    description: Exact-head Nightly Dialyzer, Nightly Summary, and PR CI Summary passed for the immutable candidate.
    requirement: TYPE-01
    verification:
      - kind: other
        ref: GitHub runs 32649101781 and 32649086802
        status: pass
    human_judgment: false
  - id: D2
    description: Issue #76 contains the final sanitized evidence receipt and is closed under the complete predicate.
    requirement: TYPE-02
    verification:
      - kind: other
        ref: GitHub issue #76 comment 5386893237
        status: pass
    human_judgment: false
duration: 24min
completed: 2026-08-23
status: complete
---

# Phase 126 Plan 09: Final Type Authority Summary

**Curated Dialyzer baseline accepted by exact-head Nightly and PR CI, with issue #76 closed by an immutable external receipt.**

## Accomplishments

- Completed the 45-entry local disposition ledger and passed policy, all mapped owner proof, SAFE-01, `mix ci`, hygiene, and the forbidden-surface audit.
- Bound candidate `a36cd146cd40fe6dee0f0e4350a0fd1072f57ef8` to successful [Nightly](https://github.com/szTheory/rindle/actions/runs/32649101781) Dialyzer/Summary and [PR CI](https://github.com/szTheory/rindle/actions/runs/32649086802) Summary receipts.
- Posted one sanitized [issue #76 receipt](https://github.com/szTheory/rindle/issues/76#issuecomment-5386893237) and closed the issue only after every predicate passed.

## Task Commits

1. **Task 1: Close local policy, preservation, CI, hygiene, and scope gates** — `a36cd14` (`fix`)
2. **Task 2: Obtain exact-head authorities and publish the immutable external #76 receipt** — external-only; no repository commit.

## Decisions Made

- Nightly Summary’s emitted `DIALYZER: success` line is the literal log form of its successful Dialyzer result; the workflow script’s markdown echo remains interpolated in the log command text.
- The candidate commit is the authority head. This later summary/state metadata commit records execution only and is not used for the GitHub acceptance receipts.

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 1 - Bug] Formatted the GCS `url_for/4` spec**
   - **Found during:** Task 1 `mix ci`.
   - **Fix:** Applied the repository formatter to `lib/rindle/storage/gcs/client.ex`.
   - **Verification:** `mix ci` passed afterward.

2. **[Rule 1 - Verification] Used the emitted Nightly Summary result form**
   - **Found during:** Task 2 final log assertion.
   - **Fix:** Validated `DIALYZER: success`, which the Summary job emits, rather than a non-interpolated markdown command line.

## Known Stubs

None.

## Self-Check: PASSED

The candidate commit, both exact-head workflow receipts, PR #91, and issue #76 receipt were verified before this metadata closeout.
