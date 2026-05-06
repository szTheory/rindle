---
phase: 32-upgrade-migration-safety
plan: 02
subsystem: upgrade-recovery
tags: [upgrade, repair, runtime-status, doctor, smoke]
requires: [32-01, 30-02, 31-02]
provides:
  - Deterministic cancelled-work recovery proof after upgrade
  - Upgrade diagnostics-to-requeue operator path on public surfaces only
affects: [upgrade, repair, runtime-status, troubleshooting]
tech-stack:
  added: []
  patterns: [public-surface recovery proof, cancelled-work resume, upgrade smoke report]
requirements-completed: [UPGRADE-02]
completed: 2026-05-06
---

# Phase 32 Plan 32-02 Summary

## Implemented

- Reused the generated-app upgrade lane to seed one deterministic post-upgrade
  AV cancellation on a single asset.
- Proved the recovery story stays on the public operator surfaces:
  - `mix rindle.doctor`
  - `mix rindle.runtime_status`
  - `Rindle.requeue_variants/2`
- Made the upgrade proof deterministic by clearing in-flight uniqueness
  conflicts before requeue so the asset-scoped cancelled-work repair path
  always proves a fresh enqueue.
- Locked the recovery narrative to one cancelled asset with ready siblings
  preserved after repair.
- Updated `guides/operations.md` and `guides/troubleshooting.md` so upgrade
  recovery still teaches diagnosis first, repair second, and keeps broad
  regeneration separate from one-asset repair.

## Tests

- `mix test test/install_smoke/generated_app_smoke_test.exs:98 --include minio --warnings-as-errors`
- Result: 2 tests, 0 failures (4 excluded)

## Notes

- The generated-app proof now exercises the truthful cancelled-work recovery
  contract end to end: `mix rindle.runtime_status` surfaces
  `cancelled_work`, recommends `Rindle.requeue_variants/2`, and the shared
  worker/FSM path resumes the variant to `ready`.
