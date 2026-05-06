---
phase: 26-delivery-surface
plan: 01
subsystem: delivery
tags: [delivery, streaming, content-disposition, telemetry]
requires: [AV-04-01, AV-04-02, AV-04-08]
provides:
  - additive streaming_url/3 playback surface
  - callback-only streaming provider namespace
  - shared RFC 5987 content disposition normalization
affects:
  - lib/rindle/delivery.ex
  - lib/rindle/delivery/content_disposition.ex
  - lib/rindle/streaming/provider.ex
  - test/rindle/delivery_test.exs
tech_stack:
  added:
    - Elixir content disposition helper
  patterns:
    - thin wrapper over url/3
    - normalized adapter opts instead of header strings
key_files:
  created:
    - lib/rindle/delivery/content_disposition.ex
    - lib/rindle/streaming/provider.ex
  modified:
    - lib/rindle/delivery.ex
    - test/rindle/delivery_test.exs
decisions:
  - streaming_url/3 delegates to url/3 and only changes the success shape
  - content disposition is passed to adapters as normalized data, not a prebuilt header
metrics:
  completed_at: 2026-05-05T19:44:08Z
  task_commits: 2
  files_touched: 4
---

# Phase 26 Plan 01: Delivery Surface Summary

Reserved the future-stable playback seam by adding `Rindle.Delivery.streaming_url/3` as a thin wrapper over `url/3`, then normalized explicit filename and disposition intent into shared RFC 5987-safe adapter opts.

## Tasks Completed

### Task 1: Add the reserved streaming surface without changing `url/3` semantics

- Added `streaming_url/3` to `Rindle.Delivery` with the same auth, TTL, capability, and error path as `url/3`.
- Added `[:rindle, :delivery, :streaming, :resolved]` telemetry on successful streaming resolution.
- Added callback-only `Rindle.Streaming.Provider` with no runtime dispatch or adapter lookup.
- Commit: `7971323`

### Task 2: Normalize download filename/disposition policy for redirect-compatible delivery

- Added `Rindle.Delivery.ContentDisposition` to sanitize filenames and emit normalized `%{type, filename, filename_star}` data.
- Threaded normalized `:content_disposition` opts through `Rindle.Delivery` so redirect-capable adapters can consume shared policy later.
- Added tests for explicit filename sanitization, omitted intent, and attachment fallback naming from sanitized key basenames.
- Commit: `a01b0b5`

## Verification

- Ran `mix test test/rindle/delivery_test.exs`
- Outcome: passed (`20 tests, 0 failures`)

## Decisions Made

- Kept `url/3` semver-stable and emitted the progressive wrapper only after successful shared URL resolution.
- Preserved shallow public opts (`filename:` and `disposition:`) while normalizing them once inside `Rindle.Delivery`.
- Limited the attachment fallback name to a sanitized basename derived from the storage key instead of exposing raw paths or metadata.

## Deviations from Plan

None - plan executed as written.

## Known Stubs

None.

## Self-Check: PASSED

- Verified created files exist: `lib/rindle/delivery/content_disposition.ex`, `lib/rindle/streaming/provider.ex`
- Verified task commits exist: `7971323`, `a01b0b5`
