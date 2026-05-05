---
phase: 27
plan: 04
plan_id: 27-04
title: AV error vocabulary closure
status: completed
code_commit: e8c8331
verified:
  - mix test test/rindle/error_test.exs test/rindle/delivery_test.exs test/rindle/delivery/local_plug_test.exs test/rindle/workers/process_variant_test.exs
files_modified:
  - lib/rindle/delivery.ex
  - lib/rindle/delivery/local_plug.ex
  - lib/rindle/error.ex
  - lib/rindle/workers/process_variant.ex
  - test/rindle/delivery/local_plug_test.exs
  - test/rindle/error_test.exs
  - .planning/phases/27-html-helpers-liveview-integration/27-04-SUMMARY.md
---

# Phase 27 Plan 04 Summary

Closed the phase by normalizing AV-facing reasons at the delivery and worker seams and freezing the public error text in `Rindle.Error`.

## What Changed

- Normalized local playback route failures to `:streaming_not_configured` so the AV delivery surface no longer leaks the lower-level `:delivery_unsupported` tuple.
- Made malformed or multi-range local playback requests publish a stable `:range_unparseable` fallback reason while preserving the graceful `200 + full body` behavior.
- Extended `Rindle.Error.message/1` with the eight locked AV-facing reason branches and added byte-for-byte parity coverage in `test/rindle/error_test.exs`.
- Kept worker-side public failure normalization aligned with the locked AV vocabulary so visible cancellation and deterministic runtime failures use the same shared reason set.

## Verification

- `mix test test/rindle/error_test.exs test/rindle/delivery_test.exs test/rindle/delivery/local_plug_test.exs test/rindle/workers/process_variant_test.exs`

## Deviations

None. The plan completed with the public error surface centralized in `Rindle.Error`.
