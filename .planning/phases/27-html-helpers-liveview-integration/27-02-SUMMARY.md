---
phase: 27-html-helpers-liveview-integration
plan: 02
subsystem: liveview-integration
tags: [liveview, pubsub, worker-events, tdd]
requires: ["27-01"]
provides:
  - "Thin LiveView subscribe/unsubscribe helpers for variant, asset, and upload_session topics"
  - "Public {:rindle_event, type, payload} contract on existing worker topics"
affects:
  - "LiveView-facing progress subscriptions"
  - "Worker PubSub event shape"
tech_stack:
  - "Elixir"
  - "Phoenix PubSub"
  - "Phoenix LiveView"
key_files:
  created:
    - ".planning/phases/27-html-helpers-liveview-integration/27-02-SUMMARY.md"
  modified:
    - "lib/rindle/live_view.ex"
    - "lib/rindle/workers/process_variant.ex"
    - "test/rindle/live_view_test.exs"
    - "test/rindle/workers/process_variant_test.exs"
    - "test/rindle/api_surface_boundary_test.exs"
decisions:
  - "LiveView stays a thin PubSub wrapper and returns topic strings as the unsubscribe token."
  - "Worker topics remain unchanged while the public message contract becomes {:rindle_event, type, payload}."
  - "Worker-side lifecycle state determines event type so cadence ownership stays in ProcessVariant."
metrics:
  completed_at: "2026-05-05T20:32:40Z"
  tasks_completed: 2
  task_commits: 4
---

# Phase 27 Plan 02: LiveView Event Contract Summary

Thin LiveView PubSub helpers now expose a stable `{:rindle_event, type, payload}` contract without moving cadence or state management out of the worker.

## What Changed

- Added `Rindle.LiveView.subscribe/2` and `unsubscribe/1` for exactly `:variant`, `:asset`, and `:upload_session`, with private topic mapping and public docs showing `handle_info({:rindle_event, type, payload}, socket)`.
- Updated `Rindle.Workers.ProcessVariant` to broadcast `{:rindle_event, event_type, payload}` on the existing variant and asset topics, mapping processing/ready/failed/cancelled lifecycle states to the locked public event types.
- Added contract tests for helper visibility, topic formatting, public docs, event tuple shape, and rejection of the old private tuple as the public contract.

## Verification

- `mix test test/rindle/live_view_test.exs test/rindle/workers/process_variant_test.exs test/rindle/api_surface_boundary_test.exs`

## Commits

- `390e86b` `test(27-02): add failing liveview subscription contract tests`
- `09ed7b4` `feat(27-02): add liveview subscription helpers`
- `eafc205` `test(27-02): add failing public worker event contract test`
- `4d115bf` `feat(27-02): publish liveview worker events`

## Deviations from Plan

None. The plan executed as written.

## Known Stubs

None.

## Threat Flags

None.

## Self-Check: PASSED

- Verified owned files exist: `lib/rindle/live_view.ex`, `lib/rindle/workers/process_variant.ex`, `test/rindle/live_view_test.exs`, `test/rindle/workers/process_variant_test.exs`, `test/rindle/api_surface_boundary_test.exs`
- Verified task commits exist in git history: `390e86b`, `09ed7b4`, `eafc205`, `4d115bf`
