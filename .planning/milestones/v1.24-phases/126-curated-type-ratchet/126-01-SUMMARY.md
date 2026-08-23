---
phase: 126-curated-type-ratchet
plan: "01"
subsystem: testing
tags: [dialyzer, exunit, nightly, policy, type-ratchet]
requires:
  - phase: 125-behavioral-test-support
    provides: focused behavioral-test support and SAFE-01 contract
provides:
  - permanent curated-ignore policy gate
  - immutable 45-entry starting inventory receipt
  - exact-head supported Nightly topology receipt
affects: [126-02, 126-03, 126-04, 126-05, 126-06, 126-07, 126-08, 126-09]
tech-stack:
  added: []
  patterns: [test-local literal-list validator, exact-head supported-CI receipt]
key-files:
  created:
    - test/install_smoke/dialyzer_ignore_policy_test.exs
    - .planning/phases/126-curated-type-ratchet/126-TYPE-EVIDENCE.md
  modified: []
decisions:
  - The Nightly Elixir 1.17 / OTP 27 job is the sole Dialyzer acceptance authority; local output is diagnostic only.
  - E38-E40 remain pending after the unchanged baseline emits their exact TUS warnings in supported CI.
metrics:
  tasks_completed: 2
  files_created: 2
  supported_nightly_run: 32637068060
status: complete
---

# Phase 126 Plan 01: Policy Tracer and Starting Inventory Summary

The curated ignore baseline is now machine-checked and paired with a SHA-bound
starting receipt, while supported CI establishes the exact Nightly authority
without changing topology.

## Completed Tasks

1. **Lock the curated-ignore policy and 45-entry starting inventory**
   - Added a TDD policy contract that validates tuple shape, owner existence,
     duplicate rejection, strict description strings, and the closed eight-entry
     historical atom allowlist.
   - Recorded the untouched 45-entry / 18-owner baseline and its SHA-256.
   - RED commit: `b662eea`; GREEN commit: `b3263d0`.
2. **Record the supported policy-tracer Nightly receipt without topology drift**
   - Dispatched and inspected [Nightly run 32637068060](https://github.com/szTheory/rindle/actions/runs/32637068060)
     for exact tracer SHA `b3263d096071ff51912eb4f31bb8e5c9473b16c1`.
   - Recorded the Elixir 1.17.3 / OTP 27.3.4.16 Dialyzer observation and the
     Nightly Summary row in the evidence ledger.
   - Commit: `c3a040d`.

## Verification

- `MIX_ENV=test mix test test/install_smoke/dialyzer_ignore_policy_test.exs test/install_smoke/ci_lane_split_test.exs test/install_smoke/ci_cache_hygiene_test.exs --seed 0` — passed (34 tests).
- Exact-head [Dialyzer job 97188327765](https://github.com/szTheory/rindle/actions/runs/32637068060/job/97188327765)
  ran on the supported cell and concluded `failure`; it emitted the three
  unchanged pending `tus_plug` warnings E38-E40 (46 errors, 43 skipped).
- [Nightly Summary job 97188615049](https://github.com/szTheory/rindle/actions/runs/32637068060/job/97188615049)
  concluded `success` and reports its Dialyzer row as `failure`.
- Forbidden-surface audit from the implementation base found no changes to
  `mix.exs`, `mix.lock`, workflows, cache shape, dependencies, or release policy.

## TDD Gate Compliance

The RED commit `b662eea` intentionally failed compilation because
`valid_ignore_list?/1` did not exist. The subsequent GREEN commit `b3263d0`
added the test-local validator and passed the focused suite.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - State accuracy] Prevented false phase-wide requirement completion**
- **Found during:** metadata state update
- **Issue:** the generic requirement-completion handler marked TYPE-01 and
  TYPE-02 complete even though the supported receipt is intentionally red and
  later phase plans own the remaining work.
- **Fix:** restored both requirements and their traceability rows to In Progress;
  retained the truthful 1/9 plan-progress update.
- **Files modified:** `.planning/REQUIREMENTS.md`, `.planning/STATE.md`

The supported failure is a recorded starting observation, not a deviation from
the tracer implementation or an acceptance-green claim.

## Known Stubs

None.

## Self-Check: PASSED

Verified both created artifacts exist and all three task commits are reachable.
