---
phase: 137-built-package-twin-foundation
plan: 04
subsystem: testing
tags: [synthetic, receipts, privacy]
requires: [137-01, 137-02]
provides: [strict typed semantic receipt, safe export controls]
affects: [137-05, 137-06]
actuals: {tokens: 9000, tasks: 2, commits: 2}
key-files:
  created: [scripts/maintainer/twin_receipt.py, test/install_smoke/twin_receipt_test.exs, test/install_smoke/support/twin_fixture.py]
  modified: [scripts/maintainer/built_package_twin.py]
requirements-completed: []
completed: 2026-10-21
status: complete
---

# Phase 137 Plan 04 Summary

Maintainer-operated synthetic evidence; independent_pilot_credit: false.
Exact record keys, source-owned scenario, separately supplied runner inputs,
identities, digest/number types and bounds, same-job attempts, distinct runtime
identities, explicit observation ordering, complete inventory and bounded history
now derive the verdict. No receipt-derived expected identities or permissive verdict
flag exists. Failed/unknown observations never become exported green candidates.

## Task Commits

1. `1f15f53f`: strict contract and mandatory explicit inputs.
2. `c35aaba3`: export canary controls.

## Verification

- Receipt/tracer checks: 7 tests, 0 failures.
- Real run: `/private/tmp/rindle-twin-137-private-exports`, exit 0 including cleanup.
- Separate CLI verify with retained inputs/receipt/archive: exit 0.
- Duplicate/unknown/missing keys, nonfinite values, exact 65536-byte boundary,
  full 63-bit integer precision, wrong run/digest/job/attempt/boot/order/cleanup and
  synthetic-credit mutations reject. Actual HTTP canaries do not occur in returned
  fields or host logs; private process capture and exported diagnostic projections
  are tested for URL/body/credential/job-error/access-log/telemetry canaries.

## Deviations and Issues Encountered

Added one small shared Python fixture under existing install-smoke support and
updated tracer tests to consume the full strict fixture. No dependency added.
The host has no request-body logger or raw telemetry exporter. Private bounded
captures intentionally remain private, not sanitized publication artifacts.
Checksums and semantic consistency cannot authenticate a wholly fabricated trusted
manifest/receipt pair. No signing or authorization framework was introduced.

## Self-Check: PASSED

Both task commits and declared artifacts exist. Fresh real evidence and separate
verification passed. All TWIN requirements remain open until final phase acceptance.
