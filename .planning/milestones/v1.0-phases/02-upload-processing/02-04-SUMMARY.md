---
phase: 02-upload-processing
plan: "04"
subsystem: background-processing
tags: [oban, workers, promote, variant]
requires: [BG-01, BG-02, BG-03, BG-06, BG-07]
provides:
  - "Asset promotion worker"
  - "Variant generation worker"
  - "Transactionally enqueued processing jobs"
key-files:
  created:
    - lib/rindle/workers/promote_asset.ex
    - lib/rindle/workers/process_variant.ex
    - test/rindle/workers/promote_asset_test.exs
    - test/rindle/workers/process_variant_test.exs
requirements-completed: [BG-01, BG-02, BG-03, BG-06, BG-07]
completed: 2026-04-25
---

# Phase 02 Plan 04: Oban Workers Summary

Promotion and variant generation now run through Oban workers, with asset state advancement, queued variant creation, and per-variant processing handled asynchronously.

## Verification

- `mix test test/rindle/workers/`
- `mix test test/rindle/upload/lifecycle_integration_test.exs`
