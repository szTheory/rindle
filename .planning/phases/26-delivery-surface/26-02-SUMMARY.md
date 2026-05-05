---
phase: 26-delivery-surface
plan: 02
subsystem: delivery
tags: [delivery, local-playback, range, plug]
requires: [AV-04-03, AV-04-04, AV-04-05, AV-04-06]
provides:
  - delivery-owned local playback URL minting
  - canonical local root/path resolver seam
  - dev-only local playback plug with signed token verification
affects:
  - lib/rindle/delivery.ex
  - lib/rindle/delivery/local_plug.ex
  - lib/rindle/storage/local.ex
  - test/rindle/delivery/local_plug_test.exs
tech_stack:
  added:
    - Plug.Crypto signed local playback token verification
    - Plug.Conn.send_file/5 single-range serving
  patterns:
    - delivery-owned local route minting
    - canonical local root/path resolver
    - request-level temp-file verification
key_files:
  created:
    - lib/rindle/delivery/local_plug.ex
    - test/rindle/delivery/local_plug_test.exs
  modified:
    - lib/rindle/delivery.ex
    - lib/rindle/storage/local.ex
decisions:
  - local playback URLs are minted only when explicit local route context is supplied to streaming_url/3
  - LocalPlug verifies signed token payloads and enforces root containment before any file lookup
metrics:
  completed_at: 2026-05-05T19:54:07Z
  task_commits: 4
  files_touched: 5
---

# Phase 26 Plan 02: Local Playback Plug Summary

Added the narrow local delivery seam without changing `url/3`: `Rindle.Storage.Local` now publishes canonical `root/1` and `path_for/2`, `Rindle.Delivery.streaming_url/3` can mint a delivery-owned signed local playback URL when explicit local route context is provided, and `Rindle.Delivery.LocalPlug` serves verified local files over HTTP with single-range `send_file/5`.

## Tasks Completed

### Task 1: Publish the narrow local resolver seam and mint signed local playback URLs

- Added `Rindle.Storage.Local.root/1` and `path_for/2` as the canonical local filesystem seam used by delivery and tests.
- Kept `Rindle.Delivery.url/3` unchanged while extending `streaming_url/3` to mint signed local playback URLs only for `Rindle.Storage.Local` when `local_route:` context is explicitly provided.
- Bound local playback tokens to `key`, expiry, and actor-derived subject with `Plug.Crypto`.
- Commits: `fa58c6f`, `de9f79c`

### Task 2: Implement LocalPlug with boot-time validation, single-range sendfile, and narrow telemetry

- Added `Rindle.Delivery.LocalPlug` with fail-fast init validation for non-local adapters, signed token verification, root containment enforcement, `404`/`403` outcomes, and shared content-disposition headers.
- Implemented single explicit, suffix, and open-ended range support via `Plug.Conn.send_file/5`; malformed and multi-range headers fall back to `200` full-body responses.
- Emitted local-only `[:rindle, :delivery, :range_request]` telemetry on successful `206` responses with numeric measurements and stable metadata.
- Commits: `6ecc34e`, `a712cb0`

## Verification

- Ran `mix test test/rindle/delivery/local_plug_test.exs`
- Outcome: passed (`11 tests, 0 failures`)

## Decisions Made

- Preserved the existing private-delivery error path for local profiles when no explicit local route context is supplied.
- Kept token verification and path containment inside `LocalPlug` rather than widening the storage behaviour.
- Reused the normalized content-disposition map from Plan 01 directly inside local byte-serving responses.

## Deviations from Plan

None - plan executed within the owned file scope.

## Known Stubs

None.

## Self-Check: PASSED

- Verified created files exist: `lib/rindle/delivery/local_plug.ex`, `test/rindle/delivery/local_plug_test.exs`, `.planning/phases/26-delivery-surface/26-02-SUMMARY.md`
- Verified task commits exist: `fa58c6f`, `de9f79c`, `6ecc34e`, `a712cb0`
