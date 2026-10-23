---
phase: 138-lifecycle-failure-and-recovery-matrix
plan: 05
subsystem: testing
tags: [oban, restart, sigkill, package]
requires: [138-04]
provides: [Committed promotion cut, Abrupt host replacement proof, Same-job recovery receipt]
affects: [138-06]
actuals: {tasks: 2, commits: 2}
tech-stack:
  added: []
  patterns: [Paused attempt-zero cut, Independent container death observation]
key-files:
  created: []
  modified: [scripts/maintainer/built_package_twin.py, scripts/maintainer/twin_receipt.py, test/twin/host/lib/twin/tracer.ex, test/install_smoke/twin_tracer_contract_test.exs, test/install_smoke/twin_receipt_test.exs]
key-decisions:
  - Require an unchanged second cut read before SIGKILL, followed by observed exit 137 and a distinct container and boot.
  - Replacement resumes the original durable job with no second upload or completion request.
requirements-completed: []
requirements-covered: [RECOV-05]
coverage:
  - id: PROMOTION-RESTART
    description: The same committed available attempt-zero promotion job completes after SIGKILL under a distinct runtime.
    requirement: RECOV-05
    verification:
      - kind: e2e
        ref: /private/tmp/rindle-138-promotion-verified/receipt.json
        status: pass
      - kind: unit
        ref: test/install_smoke/twin_receipt_test.exs
        status: pass
    human_judgment: false
completed: 2026-10-22
status: complete
independent_pilot_credit: false
---

# Phase 138 Plan 05: Abrupt promotion-stage recovery

The real packaged consumer recovers committed promotion work after abrupt host replacement without repeating the upload.

## Task Commits

1. `2939e15b` — actual paused cut, SIGKILL/death/new runtime and same-job continuation.
2. `f51b110c` — closed typed restart receipt and mutation controls.

## Verification

- Real `run --case promotion-restart --verify --cleanup`: exit zero, `/private/tmp/rindle-138-promotion-verified`.
- Subsequent independent `verify --inputs ... --receipt ...`: exit zero.
- Promotion job 1 is available at attempt zero in both committed pre-kill reads, with paused queue and zero running work. The completed upload session and validating asset are retained.
- Only the owned host receives SIGKILL. Docker reports exited/137 before replacement; new container and boot differ while package image, durable database and bucket remain the same.
- The same job 1 completes at attempt one, followed by the one declared thumbnail job. Source checksum and exact original/thumbnail inventory pass; both stimulus counters remain one.
- Observed case runtime: 13442 ms within the fixed 180000 ms case deadline, excluding build. This is local synthetic runtime, with no CI speed credit.
- Focused tracer/receipt suite: 14 tests, zero failures. Controls reject running or attempted work at cut, changed identities, missing death, swapped runtimes, repeated stimuli and unknown fields.
- Format and diff checks pass. No scope deviation, public API, schema or dependency change.

All RECOV requirements remain pending the complete six-case matrix and pre-disposal audit in Plan 06. The Phase 137 controlled between-attempt retry keeps its distinct legacy meaning.
