---
phase: 26-delivery-surface
plan: 03
subsystem: delivery
tags: [delivery, telemetry, docs, html]
requires: [AV-04-06, AV-04-07, AV-04-08]
provides:
  - frozen streaming and range telemetry contract
  - published TTL guidance and local delivery caveats
  - image-helper regression guard against AV churn
affects:
  - lib/rindle/delivery.ex
  - lib/rindle/delivery/local_plug.ex
  - test/rindle/contracts/telemetry_contract_test.exs
  - test/rindle/html_test.exs
tech_stack:
  added:
    - telemetry contract coverage for delivery streaming and local range events
  patterns:
    - public event allowlist freezing
    - docs co-located with runtime emitters
    - no-churn image helper regression coverage
key_files:
  created:
    - .planning/phases/26-delivery-surface/26-03-SUMMARY.md
  modified:
    - lib/rindle/delivery.ex
    - lib/rindle/delivery/local_plug.ex
    - test/rindle/contracts/telemetry_contract_test.exs
    - test/rindle/html_test.exs
decisions:
  - delivery TTL guidance remains documentation and profile-policy guidance, not new DSL
  - local range telemetry stays scoped to LocalPlug rather than widening delivery-wide KPIs
metrics:
  completed_at: 2026-05-05T19:56:24Z
  task_commits: 1
  files_touched: 4
---

# Phase 26 Plan 03: Delivery Contract Closure Summary

Closed the delivery surface by freezing the two new telemetry events in the public contract lane, publishing TTL and dev-only posture guidance in module docs, and adding a narrow regression guard that keeps `picture_tag/3` on the existing image markup path.

## Tasks Completed

### Task 1: Freeze the new delivery telemetry events in the public contract lane

- Added `[:rindle, :delivery, :streaming, :resolved]` and `[:rindle, :delivery, :range_request]` to the public telemetry allowlist.
- Added contract assertions for numeric measurements and stable metadata on both new events.
- Published the delivery and local-range telemetry schemas directly in `Rindle.Delivery` and `Rindle.Delivery.LocalPlug` docs next to the runtime emitters.
- Commit: `fc6ffb5`

### Task 2: Publish TTL guidance and no-churn docs/tests for the delivery surface

- Documented TTL guidance for images, audio, video-on-demand, and long-form playback without widening the delivery DSL.
- Extended `Rindle.Delivery.LocalPlug` docs to make the dev-parity-only posture and shared filename/disposition contract explicit.
- Added a focused `picture_tag/3` regression test proving the helper still renders `<picture>`/`<img>` markup and does not adopt AV playback elements in Phase 26.
- Commit: `fc6ffb5`

## Verification

- Ran `mix test test/rindle/contracts/telemetry_contract_test.exs --only contract`
- Outcome: passed (`9 tests, 0 failures`)
- Ran `mix test test/rindle/delivery_test.exs test/rindle/html_test.exs`
- Outcome: passed (`23 tests, 0 failures`)

## Decisions Made

- Kept the telemetry contract in the existing allowlist lane instead of introducing a second contract mechanism.
- Treated TTL posture as public guidance only; runtime policy still flows from `signed_url_ttl_seconds`.
- Preserved the thin image-helper contract so Phase 27 can adopt `streaming_url/3` explicitly rather than by incidental Phase 26 drift.

## Deviations from Plan

None - plan executed within the owned file scope.

## Known Stubs

None.

## Self-Check: PASSED

- Verified modified files exist and compile.
- Verified task commit exists: `fc6ffb5`
- Verified plan checks passed: contract lane and delivery/html regression lane
