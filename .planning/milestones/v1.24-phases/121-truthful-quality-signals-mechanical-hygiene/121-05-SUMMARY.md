---
phase: 121-truthful-quality-signals-mechanical-hygiene
plan: "05"
subsystem: repository-hygiene
tags: [bash, git, exunit, cleanup, regression-lock]
requires: []
provides:
  - Exact, tracked-safe cleanup of known transient root outputs
  - ExUnit regression lock for root ignores, cleanup behavior, and package evidence preservation
affects: [SIGNAL-04, maintenance, release-hygiene]
tech-stack:
  added: []
  patterns:
    - Exact cleanup allowlists use non-recursive deletion only after a Git tracked-file check.
    - Filesystem cleanup behavior is proven in an isolated temporary Git repository.
key-files:
  created:
    - test/install_smoke/repository_residue_test.exs
  modified:
    - scripts/gsd_cleanup.sh
key-decisions:
  - "Restrict cleanup to nine exact root filenames; do not use directory or filename globs."
  - "Keep .DS_Store and erl_crash.dump as general ignore rules while GSD/Credo output rules remain root-anchored."
requirements-completed: [SIGNAL-04]
coverage:
  - id: D1
    description: Exact root cleanup preserves tracked matches and ignored package evidence.
    requirement: SIGNAL-04
    verification:
      - kind: integration
        ref: test/install_smoke/repository_residue_test.exs#cleanup removes exact untracked files but preserves tracked matches and package evidence
        status: pass
    human_judgment: false
  - id: D2
    description: Root residue cannot recur as tracked files or lose its narrow ignore contract.
    requirement: SIGNAL-04
    verification:
      - kind: unit
        ref: test/install_smoke/repository_residue_test.exs#known root residue never becomes tracked
        status: pass
      - kind: unit
        ref: test/install_smoke/repository_residue_test.exs#ignore rules keep GSD and Credo output root-scoped while OS and crash rules stay general
        status: pass
    human_judgment: false
metrics:
  duration: 3m
  completed: 2026-08-22
status: complete
---

# Phase 121 Plan 05: Tracked-Safe Root Residue Cleanup Summary

**Exact non-recursive cleanup for nine known root outputs, backed by an isolated-Git ExUnit regression contract that preserves tracked and package evidence.**

## Performance

- **Duration:** 3m
- **Started:** 2026-08-22T22:10:00Z
- **Completed:** 2026-08-22T22:12:53Z
- **Tasks:** 2/2
- **Files modified:** 2

## Accomplishments

- Replaced the broad `rindle-*` cleanup glob and recursive removal with an exact nine-file root allowlist guarded by `git ls-files`.
- Added a shipped-tree ExUnit lock for tracked residue, narrow ignore coverage, obsolete root maintenance copies, and non-recursive cleanup implementation.
- Proved cleanup in an isolated Git repository: a tracked fixture is reported and retained, eight untracked fixtures are deleted, and `rindle-0.1.0-dev/sentinel.txt` remains byte-present.
- Confirmed `.planning/milestones/v1.8-MILESTONE-AUDIT.md` remains non-empty and byte-identical (SHA-256 `aa579304462e5ed5ee44c7551856cf7ff7e9905aab5745133d72a2dc5de58b76`).

## Task Commits

1. **Task 1: Extend tracked-safe cleanup to the proven root residue set** - `c651dc4` (chore)
2. **Task 2: Lock residue recurrence and canonical audit preservation** - `211a09b` (test)

## Files Created/Modified

- `scripts/gsd_cleanup.sh` - Exact transient-file allowlist with tracked-file refusal and `rm -f` deletion only.
- `test/install_smoke/repository_residue_test.exs` - Repository hygiene and behavioral cleanup regression tests.

## Decisions Made

- Cleanup considers only `.DS_Store`, `erl_crash.dump`, five GSD outputs, and two Credo outputs at repository root.
- The cleanup command intentionally leaves all non-enumerated paths untouched, including `rindle-0.1.0-dev/`, worktrees, planning archives, debug/recovery directories, and maintainer evidence.

## Verification

- `bash scripts/gsd_cleanup.sh` — passed; final run found no transient root outputs.
- `mix test test/install_smoke/repository_residue_test.exs test/planning_path_hygiene_test.exs --seed 0` — passed (6 tests, 0 failures).
- `mix test test/async_safety_guard_test.exs --seed 0` — passed (3 tests, 0 failures).
- Canonical v1.8 audit presence and byte-identity check — passed.

## Cleanup Performed

The initial cleanup run removed these exact ignored root files present in this checkout:

- `.DS_Store`
- `erl_crash.dump`
- `init.json`
- `progress.txt`
- `roadmap.json`
- `state.json`

These were untracked local transient outputs. Git cannot restore them; regenerating the relevant local tooling output is the recovery path if needed. No other paths were removed.

## Deviations from Plan

None - plan executed exactly as written.

## TDD Gate Compliance

The plan orders the cleanup implementation (Task 1) before the shipped regression file (Task 2), so the committed test ran GREEN against Task 1 rather than as a separate RED commit. Its isolated-repository fixture confirms the required observable behavior; future plans should order the regression task before its implementation task when a RED commit is required.

## Issues Encountered

The configured GSD CLI could not run because the repository's Node asdf shim has no active Node version. This did not affect the scoped implementation or verification; the parent executor retains ownership of shared planning-state updates.

## Next Phase Readiness

SIGNAL-04 now has a repeatable cleanup contract. Future hygiene work must add a new exact filename plus a regression assertion rather than broadening the cleanup matcher.

## Self-Check: PASSED

- `scripts/gsd_cleanup.sh` and `test/install_smoke/repository_residue_test.exs` exist.
- Task commits `c651dc4` and `211a09b` exist.
- Canonical v1.8 audit evidence remains present and unchanged.
