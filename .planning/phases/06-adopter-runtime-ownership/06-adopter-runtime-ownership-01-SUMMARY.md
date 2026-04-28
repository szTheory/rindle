---
phase: 06-adopter-runtime-ownership
plan: 01
subsystem: api
tags: [ecto, repo, runtime-config, oban]
requires:
  - phase: 05-ci-1-0-readiness
    provides: adopter and lifecycle coverage that exposed facade repo ownership leaks
provides:
  - runtime repo accessor via `Rindle.Config.repo/0`
  - facade persistence paths that resolve the configured repo once per call
  - regression coverage for repo config overrides and fallback behavior
affects: [adopter-runtime-ownership, upload-broker, guides]
tech-stack:
  added: []
  patterns: [application-env repo accessor, per-entrypoint repo resolution, transaction callback repo usage]
key-files:
  created: []
  modified: [lib/rindle/config.ex, config/config.exs, test/rindle/config/config_test.exs, lib/rindle.ex]
key-decisions:
  - "Keep `Rindle.Repo` as the repo-local default while shifting consumer runtime paths to `Rindle.Config.repo/0`."
  - "Limit this plan to the facade seam and explicitly defer adopter-only proof for direct and proxied upload paths to Plan 06-02."
patterns-established:
  - "Runtime Repo Resolution: public facade entrypoints resolve `Rindle.Config.repo/0` once and transact through that module."
  - "Transaction Repo Callbacks: `Ecto.Multi.run` callbacks use the callback repo argument instead of re-fetching via `Rindle.Repo`."
requirements-completed: [ADOPT-01, ADOPT-02]
duration: 1 min
completed: 2026-04-28
---

# Phase 06 Plan 01: Adopter Runtime Ownership Summary

**Configured adopter repo resolution now drives the public facade seam while preserving the in-repo `Rindle.Repo` harness default.**

## Performance

- **Duration:** 1 min
- **Started:** 2026-04-28T09:22:05Z
- **Completed:** 2026-04-28T09:23:40Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Added `Rindle.Config.repo/0` and repo-local config defaulting so adopters can set `config :rindle, :repo, MyApp.Repo` without breaking the library harness.
- Locked the repo seam with focused config tests covering both per-test overrides and fallback behavior.
- Refactored `attach/4`, `detach/3`, and `upload/3` to transact through the configured repo and use transaction callback repo arguments instead of `Rindle.Repo`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add the runtime Repo contract in `Rindle.Config`**
   - `ea75f8d` (`test`): failing `repo/0` contract tests
   - `d5abb75` (`feat`): `Rindle.Config.repo/0` plus repo-local default config
2. **Task 2: Move `attach/4`, `detach/3`, and `upload/3` onto the runtime Repo seam**
   - `c8c5fdf` (`feat`): facade repo resolution and docs cleanup

## Files Created/Modified
- `lib/rindle/config.ex` - adds the runtime repo accessor used by consumer-facing code.
- `config/config.exs` - preserves backward-compatible local harness behavior with `:repo` defaulting to `Rindle.Repo`.
- `test/rindle/config/config_test.exs` - proves configured and fallback repo resolution behavior.
- `lib/rindle.ex` - resolves the configured repo once per public entrypoint and removes direct facade persistence calls to `Rindle.Repo`.

## Decisions Made

- Kept `Rindle.Repo` as the application-env fallback so existing repo-local tests and harness behavior stay stable while adopters gain an explicit override seam.
- Deferred adopter-only proof for both direct-upload verification and proxied `Rindle.upload/3` runtime behavior to Plan 06-02, matching the plan boundary instead of overstating coverage here.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 06-02 can now prove runtime behavior against an adopter-owned repo without reworking the public facade API again.
- Direct-upload broker paths and canonical adopter proof still need the explicit fail-on-wrong-repo coverage called for by Phase 6.

## Self-Check: PASSED
