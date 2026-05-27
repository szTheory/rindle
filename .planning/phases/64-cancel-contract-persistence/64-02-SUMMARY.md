---
phase: 64-cancel-contract-persistence
plan: 02
subsystem: domain
tags: [fsm, cancel]
provides:
  - pending/uploading → deleted FSM edges for direct-upload cancel
key-files:
  modified:
    - lib/rindle/domain/provider_asset_fsm.ex
    - test/rindle/domain/provider_asset_fsm_test.exs
requirements-completed: [CANCEL-02]
completed: 2026-05-27
---

# Phase 64 Plan 02 Summary

**FSM allowlist extended so Phase 65 can transition cancellable rows to deleted.**

## Accomplishments
- `pending` and `uploading` may reach `deleted`; `processing` still rejects
- ExUnit matrix locks the cancel edges

## Task Commits
1. **Task 1: Extend FSM allowlist and tests** - `d17bd2d`

## Self-Check: PASSED
- `mix test test/rindle/domain/provider_asset_fsm_test.exs` — 0 failures
