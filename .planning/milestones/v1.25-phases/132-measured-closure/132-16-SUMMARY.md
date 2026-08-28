---
phase: 132-measured-closure
plan: 16
subsystem: ci-timing-controller
tags: [github-actions, timing-receipt, provenance, regression-test, closeout]
dependency_graph:
  requires: [132-15]
  provides: [verified preserved-tail controller repair]
  affects: [132-17 fresh preservation census, 132-18 CI-14 timing receipt]
tech_stack:
  added: []
  patterns: [preserved-subject manifest identity, planning-only tail census, read-only mutation census]
key_files:
  created:
    - .planning/phases/132-measured-closure/132-16-SUMMARY.md
  modified: []
decisions:
  - "Commit 15336d4cc8053aa90788c62377096081c5b07f21 is Plan 132-16's source repair and is closed without duplicating, amending, or reverting it."
  - "COV-05 and SAFE-02 require Plan 132-17's fresh post-15336d4 preservation census; CI-14 remains open for Plan 132-18's exact-ten API-backed receipt."
metrics:
  duration: "~4 minutes"
  completed_date: "2026-08-27"
status: complete
coverage:
  - id: D1
    description: "Existing preserved-tail controller repair is verified without a duplicate implementation."
    requirement: SAFE-02
    verification:
      - kind: integration
        ref: "mix test test/install_smoke/ci_timing_automation_test.exs --seed 0"
        status: pass
    human_judgment: false
---

# Phase 132 Plan 16: Preserved-tail repair closeout Summary

Commit `15336d4cc8053aa90788c62377096081c5b07f21` closes the controller's preserved-subject manifest-tail assumption, with an 18-test process regression and no GitHub sampler mutation.

## Tasks Completed

1. Verified and closed the existing preserved-tail repair at `15336d4`; no production or test source was edited, reimplemented, reverted, cherry-picked, squashed, or recommitted.

## Recovery Context

The prior terminal-sampler preflight was blocked because the controller compared manifest `repair_sha` to the current `HEAD`, which incorrectly rejected a valid planning-only evidence tail. The already-committed repair changes that identity comparison to `--preserved-subject-sha` while retaining the fail-closed post-subject census that rejects every non-`.planning/` path.

`15336d4` has parent `74d09e863be08cd57898fab8933ef5069b55a147` (the completed Plan 132-15 tracking commit) and exactly two changed paths:

- `scripts/ci/collect_pr_timing_receipt.sh`
- `test/install_smoke/ci_timing_automation_test.exs`

The regression fixture adds a planning-only commit after the preserved repair anchor and proves both exact-head and strict-ancestor no-publish preflight cases. This source commit belongs to Plan 132-16, not Plan 132-15.

## Verification

- Parent and exact two-path commit census for `15336d4` — passed.
- `mix format --check-formatted test/install_smoke/ci_timing_automation_test.exs` — passed.
- `mix test test/install_smoke/ci_timing_automation_test.exs --seed 0` — passed (`18 tests, 0 failures`).
- `bash -n scripts/ci/collect_pr_timing_receipt.sh` — passed.
- `./scripts/maintainer/automation_first_contract.sh` — passed.
- `git diff --check` — passed.
- Read-only GitHub/controller census — passed: PR #96 remains open at `7f025dfdf55d612861610a10773d86761a374277`, is draft, has no labels, and its `ci-timing-sample` label is absent. No matching timing workflow run was observed.
- Local mutation census — passed: `.gsd/ci-timing/phase-132-final` has no state file or lock, and `132-CI-TIMING-RECEIPT.md` contains zero current table/source marker pairs.

## Task Commit

1. **Task 1: Verify and close the existing preserved-tail repair** — `15336d4` (fix; existing source commit).

## Files Created/Modified

- `.planning/phases/132-measured-closure/132-16-SUMMARY.md` — truthful closeout and verification evidence for the existing repair.

## Decisions Made

- Preserve `15336d4` as the sole Plan 132-16 source repair; this closeout adds no implementation commit.
- CI-14 remains open. Plan 132-17 must produce a fresh post-`15336d4` preservation census for COV-05/SAFE-02, and Plan 132-18 alone may establish the exact-ten live CI timing receipt.

## Deviations from Plan

None - the revised closeout plan executed exactly as written. The missing summary was recovered by recording, rather than re-executing, the pre-existing source commit.

## Issues Encountered

The earlier sampler preflight had already been blocked by the preserved-tail identity assumption. This closeout verified the committed correction and confirmed that the blocked attempt created no remote or local sampler mutation.

## Known Stubs

None.

## Threat Flags

None — this closeout added a planning summary only; it introduced no endpoint, auth path, file-access pattern, schema change, or remote mutation.

## Next Phase Readiness

Plan 132-17 is unblocked to perform the fresh post-`15336d4` preservation census required for COV-05 and SAFE-02. CI-14 remains open and is reserved for Plan 132-18's machine-verifiable exact-ten API-backed receipt.

## Self-Check: PASSED

- Confirmed this summary exists.
- Confirmed source commit `15336d4cc8053aa90788c62377096081c5b07f21` exists with the recorded parent and exact two-file diff.
- Confirmed the focused tests and offline gates passed, and that the GitHub/controller mutation census was empty.
