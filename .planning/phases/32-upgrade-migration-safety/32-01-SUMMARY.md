---
phase: 32-upgrade-migration-safety
plan: 01
subsystem: upgrade-proof
tags: [upgrade, migrations, smoke, package-consumer]
requires: [29-01, 29-02]
provides:
  - Generated-app upgrade proof from pre-v1.4 image-only state to current AV-aware state
  - Explicit packaged migration handoff through `Application.app_dir/2`
affects: [upgrade, install-smoke, migrations]
tech-stack:
  added: []
  patterns: [generated-app upgrade proof, packaged migration handoff, legacy-state seeding]
requirements-completed: [UPGRADE-01]
completed: 2026-05-06
---

# Phase 32 Plan 32-01 Summary

## Implemented

- Extended the generated package-consumer harness in
  `test/install_smoke/support/generated_app_helper.ex` with a dedicated
  `prove_upgrade_install!/0` lane.
- The new lane stages a truthful pre-v1.4 image-only adopter state by running
  only the legacy Rindle migration subset first, seeding legacy rows, then
  resuming the public packaged-migration handoff through
  `Application.app_dir(:rindle, "priv/repo/migrations")`.
- Added an upgrade-specific report contract that captures:
  - legacy migration cutoff
  - migration resolution
  - legacy image-only asset safety after upgrade
  - canonical ordered upgrade checkpoints for docs parity
- Added repository-side upgrade smoke assertions in
  `test/install_smoke/generated_app_smoke_test.exs`.
- Preserved the legacy image-default compatibility posture while proving the
  upgrade path stays on installed artifacts rather than repo-local deps.

## Tests

- `mix test test/install_smoke/generated_app_smoke_test.exs:98 --include minio --warnings-as-errors`
- Result: 2 tests, 0 failures (4 excluded)

## Notes

- The upgrade harness keeps the generated-app package-consumer lane as the only
  truth source; no frozen fixture Phoenix app was introduced.
