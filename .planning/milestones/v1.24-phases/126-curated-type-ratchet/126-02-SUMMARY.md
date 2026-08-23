---
phase: 126-curated-type-ratchet
plan: "02"
subsystem: migration
tags: [dialyzer, ecto, migration, nightly]
requires:
  - phase: 126-01
    provides: supported type-ratchet policy and starting receipt
provides:
  - supported migration warning dispositions
affects: [126-03, 126-07]
tech-stack:
  added: []
  patterns: [exact-head supported annotation receipt]
key-files:
  created: [.planning/phases/126-curated-type-ratchet/126-02-SUMMARY.md]
  modified: [.dialyzer_ignore.exs, .planning/phases/126-curated-type-ratchet/126-TYPE-EVIDENCE.md]
decisions:
  - Migration Ecto callback and intentional-raise warnings remain exact supported analyzer-noise filters.
metrics:
  tasks_completed: 3
  supported_nightly_run: 32640649625
status: complete
---

# Phase 126 Plan 02: Migration Type Boundary Summary

Migration and host-support Dialyzer filters now have exact supported-cell dispositions while preserving the fixed migration contract.

## Completed Tasks

1. Exposed and recorded all 16 migration/support warnings on supported Nightly run 32637455725.
2. Retained dispatcher and host Ecto callback noise with exact run-bound comments after focused tests and SAFE-01.
3. Retained V1 intentional-raise/preflight noise and proved the exact final head emits only the later-owned Tus warnings.

## Verification

- Focused migration/docs tests and SAFE-01 passed.
- Exact-head [Nightly run 32640649625](https://github.com/szTheory/rindle/actions/runs/32640649625) has Dialyzer failure only for E38 at `tus_creation.ex` and E39–E40 at `tus_stream.ex`; Nightly Summary is success and records `DIALYZER: failure`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Policy test] Removed the live-count freeze from the policy test.**
- The original test contradicted Plan 126-01’s retirement-aware contract; strict shape, ownership, duplicate, and atom validation remain.

## Known Stubs

None.

## Self-Check: PASSED
