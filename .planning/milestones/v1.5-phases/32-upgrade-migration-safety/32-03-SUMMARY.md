---
phase: 32-upgrade-migration-safety
plan: 03
subsystem: docs
tags: [upgrade, docs, parity, smoke]
requires: [32-01, 32-02]
provides:
  - Canonical existing-adopter upgrade runbook
  - Docs parity across README, getting started, release, and upgrade guidance
affects: [docs, upgrade, smoke-parity]
tech-stack:
  added: []
  patterns: [guide split, executable docs parity, upgrade checkpoint sequencing]
requirements-completed: [UPGRADE-03]
completed: 2026-05-06
---

# Phase 32 Plan 32-03 Summary

## Implemented

- Added `guides/upgrading.md` as the canonical existing-adopter upgrade runbook
  for the pre-v1.4 to current path.
- Kept greenfield and upgrade guidance cleanly split by updating:
  - `README.md`
  - `guides/getting_started.md`
  - `guides/release_publish.md`
- Bound the upgrade guide to the executable proof lane by reusing the canonical
  ordered checkpoint sequence exposed by the generated-app helper.
- Extended docs parity coverage in
  `test/install_smoke/docs_parity_test.exs` to freeze upgrade discoverability
  and runbook sequencing.
- Verified the final package-consumer smoke matrix still passes end to end with
  the new upgrade lane enabled.

## Tests

- `mix test test/install_smoke/docs_parity_test.exs --warnings-as-errors`
- Result: 13 tests, 0 failures
- `mix test test/install_smoke/generated_app_smoke_test.exs --include minio --warnings-as-errors`
- Result: 6 tests, 0 failures

## Notes

- The full MinIO-backed matrix required a clean runner; stale BEAM smoke
  processes from interrupted attempts can make the long generated-app proof look
  hung even when the implementation is correct.
