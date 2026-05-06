---
phase: 29-adopter-proof-matrix
plan: 01
subsystem: testing
tags: [elixir, phoenix, hex, smoke, minio]
requires:
  - phase: 09-install-release-confidence
    provides: generated-app package-consumer harness
provides:
  - mode-explicit generated-app image-only package-consumer proof
  - aligned built-artifact and published-version smoke wrappers
affects: [phase-29, install-smoke, release-proof]
tech-stack:
  added: []
  patterns: [generated-app smoke report, explicit install-mode wrappers]
key-files:
  created: []
  modified:
    - test/install_smoke/support/generated_app_helper.ex
    - test/install_smoke/generated_app_smoke_test.exs
    - scripts/install_smoke.sh
    - scripts/public_smoke.sh
key-decisions:
  - "Keep one generated-app ExUnit harness for both built-package and published Hex installs, with helper report fields making the install source explicit."
  - "Make the wrapper scripts clear conflicting mode env vars instead of introducing separate smoke implementations."
patterns-established:
  - "Package-consumer smoke reports should state install mode and source while still proving deps/rindle absence."
  - "Built and published smoke entrypoints stay thin and delegate all lifecycle truth to test/install_smoke/generated_app_smoke_test.exs."
requirements-completed: [PROOF-01]
duration: 8min
completed: 2026-05-06
---

# Phase 29 Plan 01 Summary

**Image-only generated-app smoke now proves either unpacked-package or published-Hex installation explicitly while keeping one canonical presigned-upload lifecycle harness**

## Performance

- **Duration:** 8 min
- **Started:** 2026-05-06T01:21:00Z
- **Completed:** 2026-05-06T01:28:33Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added explicit `install_mode`, `install_source`, and `deps_rindle_present?` reporting to the generated-app smoke helper without changing the canonical image-only lifecycle proof.
- Updated the generated-app smoke assertions so the same ExUnit harness is truthful for both built-artifact and published-version installs.
- Kept `scripts/install_smoke.sh` and `scripts/public_smoke.sh` as thin wrappers while making each mode explicit by clearing conflicting install env vars.

## Task Commits

1. **Task 1: Harden the generated-app image-only proof as the canonical package-consumer baseline** - `5f1d3b6` (feat)
2. **Task 2: Keep built-artifact and published-version smoke entrypoints thin and aligned** - `89259a8` (fix)

## Files Created/Modified

- `test/install_smoke/support/generated_app_helper.ex` - records whether the generated app installed Rindle from an unpacked package path or a published Hex version and preserves migration-resolution evidence from `Application.app_dir/2`.
- `test/install_smoke/generated_app_smoke_test.exs` - asserts installability against the explicit helper report and keeps the canonical image-only lifecycle proof shared across both install modes.
- `scripts/install_smoke.sh` - keeps the built-artifact smoke lane explicit by clearing network-mode env before running the generated-app smoke test.
- `scripts/public_smoke.sh` - keeps the published-version smoke lane explicit by clearing package-root env before running the same generated-app smoke test.

## Decisions Made

- Reused the existing generated-app helper and ExUnit smoke file instead of splitting built-artifact and network-mode smoke logic.
- Represented install provenance in the helper report rather than adding separate shell-level assertions, so the trust signal stays in ExUnit alongside compile, boot, migration, and lifecycle checks.

## Verification

Passed task-level and plan-level commands:

```bash
mix test test/install_smoke/generated_app_smoke_test.exs --include minio
bash scripts/install_smoke.sh
```

Observed results:

- `mix test test/install_smoke/generated_app_smoke_test.exs --include minio` -> `2 tests, 0 failures`
- `bash scripts/install_smoke.sh` -> `2 tests, 0 failures`

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required beyond the existing local MinIO/Postgres smoke prerequisites already handled by the scripts.

## Next Phase Readiness

The package-consumer baseline is now explicit for both package and network install modes, which leaves Phase 29-02 free to extend the same generated-app harness with AV-specific proof instead of reworking image-mode install evidence again.

## Self-Check

PASSED
