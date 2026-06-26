---
phase: 90-console-ops-actions
plan: 02
subsystem: admin-console
tags:
  - ops
  - liveview
  - actions
requires:
  - 90-01
provides:
  - lifecycle_repair
  - variant_regeneration
  - quarantine_review
affects:
  - Rindle.Admin.Queries
  - Rindle.Admin.Live.ActionsLive
key_files:
  created: []
  modified:
    - lib/rindle/admin/live/actions_live.ex
    - lib/rindle/admin/queries.ex
    - test/rindle/admin/live/actions_live_test.exs
    - test/rindle/admin/queries_test.exs
tech_stack:
  added: []
  patterns:
    - LiveView inline receipts
    - Read-only triage panels
metrics:
  duration: 15
  completed_at: "2026-06-12T19:00:00Z"
---

# Phase 90 Plan 02: Console Ops Actions Summary

Non-destructive operations (Variant Regeneration, Lifecycle Repair, Quarantine Review) are now wired to existing Ops/Facade capabilities inside the Actions hub.

## Key Decisions

- Selected `Rindle.reprobe/1` and `Rindle.requeue_variants/1` directly for the Lifecycle Repair workflows.
- Filter inputs for Variant Regeneration are passed directly to `Rindle.Ops.VariantMaintenance.regenerate_variants/1`.
- Kept Quarantine Review strictly as a read-only instructional panel, directing users to the Asset List and Owner Erasure workflows as specified in D-90-17.
- Re-used `Rindle.Admin.Live.ActionsLiveTest.AdminImageProfile` internally for tests to avoid test cross-pollution.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None - adhered strictly to T-90-04 by ensuring Quarantine Review has no mutations.

## Self-Check: PASSED

- All specified components are tested.
- `ActionsLive` displays panels successfully and validates confirmations.
- Tests pass locally.
