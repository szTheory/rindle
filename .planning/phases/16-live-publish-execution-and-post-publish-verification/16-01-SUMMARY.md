---
phase: 16-live-publish-execution-and-post-publish-verification
plan: 01
subsystem: release
tags: [release, hex, idempotency, shell, testing]
requirements_completed:
  - PUBLISH-03
  - RELEASE-01
  - VERIFY-01
completed: 2026-04-30
---

# Phase 16 Plan 01 Summary

Phase 16 plan 01 added a deterministic Hex.pm idempotency probe plus a fully shimmed ExUnit harness so recovery reruns can answer "already published?" without touching the network.

## Accomplishments

- Added `scripts/hex_release_exists.sh` with `set -euo pipefail`, `RINDLE_PROJECT_ROOT` discipline, a primary `mix hex.info` probe, and a curl fallback against the Hex.pm releases API.
- Kept the probe output contract strict: stdout emits only `already_published=true|false`, diagnostics stay on stderr, and `GITHUB_OUTPUT` receives the same single-line result when present.
- Added `test/install_smoke/support/fake_hex_bin.sh` so tests can drive `mix` and `curl` exit codes deterministically without live Hex or network access.
- Added `test/install_smoke/hex_release_exists_test.exs` covering published, missing, fallback-only, inconclusive, project-root, auth-command-ban, and `GITHUB_OUTPUT` cases.

## Verification

- `MIX_ENV=test mix test test/install_smoke/hex_release_exists_test.exs`

The probe suite passed with 7 tests on 2026-04-30.

## Notes

- All four idempotency artifacts (`scripts/hex_release_exists.sh`, `test/install_smoke/hex_release_exists_test.exs`, `test/install_smoke/support/fake_hex_bin.sh`, `.github/workflows/release.yml`) are tracked in git as of 2026-04-30; the v1.3 milestone audit reflects this at `.planning/v1.3-MILESTONE-AUDIT.md:200-201` (TD-16 entry).
