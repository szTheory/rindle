---
phase: 31-runtime-diagnostics-drift-visibility
plan: 03
subsystem: telemetry
tags: [telemetry, docs, contracts, runtime, repair]
requires: [31-01, 31-02]
provides:
  - Frozen repair/runtime telemetry families and metadata
  - Docs parity for doctor/runtime-status/repair split
affects: [telemetry, docs-parity, contracts]
tech-stack:
  added: []
  patterns: [additive telemetry families, low-cardinality metadata, docs-contract parity]
requirements-completed: [DIAG-03]
completed: 2026-05-06
---

# Phase 31 Plan 31-03 Summary

## Implemented

- Added the Phase 31 additive telemetry families:
  - `[:rindle, :repair, :start]`
  - `[:rindle, :repair, :stop]`
  - `[:rindle, :repair, :exception]`
  - `[:rindle, :runtime, :refusal]`
  - `[:rindle, :runtime, :check, :stop]`
- Emitted repair telemetry from hidden lifecycle-repair flows and runtime telemetry from hidden runtime-status and runtime-check modules.
- Kept telemetry metadata low-cardinality:
  - repair: `operation`, `scope`, `result`, `dry_run`
  - runtime refusal: `surface`, `reason`, `mode`
  - runtime check: `check`, `status`, `component`
- Updated telemetry docs and operator docs to teach the Phase 31 split explicitly:
  - doctor validates setup and drift
  - runtime status reports degraded or stuck work
  - repair verbs perform change
- Locked the public event allowlist and docs parity around the new telemetry and diagnostics contract.

## Tests

- `mix test test/install_smoke/docs_parity_test.exs test/rindle/contracts/telemetry_contract_test.exs --warnings-as-errors`
- Result: 11 tests, 0 failures (14 excluded)

## Notes

- The existing cleanup/transcode telemetry families remain intact; Phase 31 adds the repair/runtime layer without renaming the older public events.
- The old temp-sweep event family remains unblessed as a separate public contract; the guides now point operators at the additive repair/runtime layer instead.
