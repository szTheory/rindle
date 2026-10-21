---
phase: 137-built-package-twin-foundation
plan: 05
subsystem: testing
tags: [synthetic, cleanup, postgres, docker]
requires: [137-01, 137-04]
provides: [complete pre-disposal inventory, liveness-guarded exact-resource janitor]
affects: [137-06]
actuals: {tokens: 8000, tasks: 2, commits: 2}
key-files:
  created: [scripts/maintainer/twin_cleanup.py, test/install_smoke/twin_cleanup_test.exs]
  modified: [scripts/maintainer/built_package_twin.py, scripts/maintainer/twin_receipt.py, test/twin/host/lib/twin/tracer.ex]
requirements-completed: []
completed: 2026-10-21
status: complete
---

# Phase 137 Plan 05 Summary

Maintainer-operated synthetic evidence; independent_pilot_credit: false.
The retained pre-allocation descriptor binds generated names, paths, inputs and
configuration hashes. Janitor observes every run-owned container before mutation,
refuses active/paused/unknown hosts and foreign resource users, and rechecks host
liveness before every destructive operation. Exact IDs/names and non-forced Docker
removals preserve unrelated resources. Repeated cleanup works after workspace
removal without reconstructing ownership from a receipt.

## Task Commits

1. `76a3c06a`: complete inventory and exact-resource disposal.
2. `5943dee1`: active/unknown/restart/foreign/decoy/idempotency controls.

## Verification

- Cleanup/receipt/fault suite: 7 tests, 0 failures.
- Fresh real run: `/private/tmp/rindle-twin-137-cleanup-final`, exit 0 including janitor.
- Separate retained-inputs/receipt/archive verify: exit 0.
- Real controls using the earlier janitor run: running and paused hosts each refused;
  all three owned volumes and workspace remained. After observed stop, two cleanup
  invocations passed and the original receipt remained unchanged.
- Fixture controls preserve decoys and failed receipts; unknown/truncated/denied,
  extra relation/history, residual object/temp/job and dry-run claims cannot pass.

## Deviations and Issues Encountered

Added explicit public/domain relation and bounded fixture/host-ledger/peer counts
in the existing host tracer, plus shared-fixture updates. These are required for
complete inventory, not new production APIs. Docker quiet output needed --no-trunc
for exact ID comparisons. Private captures now use exclusive sequence-plus-random
filenames to avoid collisions between separate cleanup/controller processes.
No global resource prune, authorization capsule, event journal or force-host override.
Infrastructure disposal never rewrites or upgrades the frozen domain receipt.

## Self-Check: PASSED

Artifacts and both commits exist. Real stop/refusal/idempotency and complete fresh
lifecycle/cleanup passed. Requirements remain open until final phase verification.
