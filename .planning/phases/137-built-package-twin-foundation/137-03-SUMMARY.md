---
phase: 137-built-package-twin-foundation
plan: 03
subsystem: testing
tags: [synthetic, docker, postgres, contracts]
requires: [137-01]
provides: [durable fault and supported ingress]
affects: [137-04, 137-05, 137-06]
actuals: {tokens: 5000, tasks: 2, commits: 2}
key-files:
  created: [test/install_smoke/twin_fault_test.exs]
  modified: [test/twin/host/lib/twin/storage.ex]
requirements-completed: []
completed: 2026-10-21
status: complete
---

# Phase 137 Plan 03 Summary

Maintainer-operated synthetic evidence; independent_pilot_credit: false.

One committed atomic source-key fault across concurrent calls and a fresh Repo pool; unchanged adapter delegation/options; missing selected fixture fails closed. A unique run/operation constraint prevents a second stimulus after source-key arming. Real observations include retained source plus a legitimately deleted variant before failure; normal same-job retry survives runtime replacement.

## Task Commits

1. Task 1: `895fa7a4`.
2. Task 2: `bd2c74a5`.

## Verification

- Default-safe boundary/fault/tracer suite: 9 tests, 0 failures.
- Real combined wave-two trace: `/private/tmp/rindle-twin-137-wave2/receipt.json`, exit 0 including cleanup.
- Archive is retained beside inputs/receipt; default fast tests never boot Docker.
- All TWIN requirements remain open pending remaining hardening and final verification.

## Deviations and Issues Encountered

The adapter normalizes HEAD 404 to :not_found; the tracer observes that documented tuple. The drift guard is a finite source check, not a sandbox or universal static analyzer. No private worker, forced retry, Sandbox, lifecycle write or schedule edit is used by the host.

## Self-Check: PASSED

Declared artifacts and both reachable task commits exist. Positive/negative fast
controls and the real trace passed. No independent pilot, AV execution, readiness,
exactly-once, executing-job crash or numeric speed credit.
