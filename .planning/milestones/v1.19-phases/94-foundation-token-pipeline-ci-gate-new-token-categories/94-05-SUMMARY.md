---
phase: 94-foundation-token-pipeline-ci-gate-new-token-categories
plan: 05
subsystem: release-train
tags: [branch-protection, github-actions, brandbook-tokens, ci-gate, pipe-01]

# Dependency graph
requires:
  - phase: 94-04
    provides: standalone brandbook-tokens CI job
provides:
  - branch-protection source of truth requiring brandbook-tokens
  - maintainer documentation listing brandbook-tokens as merge-blocking
  - remote main branch protection updated to require brandbook-tokens
affects: [release-train, branch-protection, phase-94-verification, pipe-01]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "scripts/setup_branch_protection.sh remains the single branch-protection source of truth"
    - "GitHub Actions job display name must match the required branch-protection context exactly"

key-files:
  created: []
  modified:
    - scripts/setup_branch_protection.sh
    - RUNNING.md
    - .github/workflows/ci.yml

key-decisions:
  - "Required branch-protection context is the literal brandbook-tokens check"
  - "Aligned the CI job display name to brandbook-tokens so PR check rollups can satisfy the required context"
  - "Applied branch protection after pushing the phase branch, then confirmed PR #23 shows brandbook-tokens passing"

patterns-established:
  - "Gap-closure branch-protection changes must verify both expected JSON and live GitHub required contexts"

requirements-completed: [PIPE-01]

# Metrics
duration: 6min
completed: 2026-06-15
---

# Phase 94 Plan 05: Branch Protection Gap Closure Summary

**Closed BP-94-01 by making `brandbook-tokens` a required branch-protection context, documenting it as merge-blocking, pushing PR #23 to a SHA that emits the check, and verifying the check passes in the PR rollup.**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-06-15T20:29:13Z
- **Completed:** 2026-06-15T20:35:21Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added `brandbook-tokens` to `scripts/setup_branch_protection.sh` `REQUIRED_CHECKS`.
- Added `brandbook-tokens` to the script's human-readable expected required-check list.
- Documented `brandbook-tokens` as a merge-blocking maintainer lane in `RUNNING.md`.
- Updated the release-train required-check paragraph to include `brandbook-tokens`.
- Aligned the CI job display name to `brandbook-tokens`, matching the exact branch-protection context.
- Pushed `ci/replace-flaky-ffmpeg-action` to `364d749`.
- Applied branch protection to `main` with `scripts/setup_branch_protection.sh main`.
- Verified remote required status checks include `brandbook-tokens` at index `12`.
- Verified PR #23 reports `brandbook-tokens` passing on run `27574464166`, job `81519519377`.

## Task Commits

Each repository-change task was committed atomically:

1. **Task 1: Add `brandbook-tokens` to required-check source of truth** - `364d749` (fix)
2. **Task 2: Apply and verify remote branch protection** - no source commit; applied through GitHub API using the existing script and verified against PR #23.

## Files Created/Modified

- `scripts/setup_branch_protection.sh` - Adds `brandbook-tokens` to expected branch-protection required contexts.
- `RUNNING.md` - Documents `brandbook-tokens` as merge-blocking and part of the branch-protection required-check set.
- `.github/workflows/ci.yml` - Renames the `brandbook-tokens` job display name to exactly `brandbook-tokens` so the required context is satisfiable.

## Decisions Made

- Branch protection requires the literal `brandbook-tokens` context from the gap plan and verifier report.
- GitHub required checks in this repo follow Actions display names, not just job keys, so the CI job display name must match the required context exactly.
- The owner-controlled apply path is still `scripts/setup_branch_protection.sh main`; no separate manual branch-protection state was introduced.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Aligned CI job display name with required context**
- **Found during:** Task 1 (source-of-truth update)
- **Issue:** Existing required checks use GitHub Actions display names as branch-protection contexts (`Cohort Demo Smoke`, `Adoption Demo E2E`, matrix `Quality (...)`). The Plan 04 job key was `brandbook-tokens`, but its display name was `Brandbook Tokens (PIPE-01 drift gate)`, so requiring the literal `brandbook-tokens` context would have produced an unsatisfied branch-protection check.
- **Fix:** Changed the job display name to `brandbook-tokens`.
- **Files modified:** `.github/workflows/ci.yml`
- **Verification:** `gh pr checks 23` shows `brandbook-tokens` passing; branch protection required contexts include `brandbook-tokens`.
- **Committed in:** `364d749`

---

**Total deviations:** 1 auto-fixed (Rule 2 - Missing Critical)
**Impact on plan:** Required to make the branch-protection context satisfiable. No scope creep beyond PIPE-01 branch-protection correctness.

## Issues Encountered

- The first branch-protection apply succeeded before the new check had completed; after `brandbook-tokens` appeared and passed in PR #23, the apply path was run again and the required context remained present.
- GitHub's `required_status_checks.checks` response still reports `app_id: null` for `brandbook-tokens` because the script uses the existing legacy `contexts` array contract. The authoritative `contexts` list includes the check, and PR #23 shows the matching Actions check passing.

## User Setup Required

None - the available GitHub credentials had sufficient permission to apply branch protection.

## Verification

- `scripts/setup_branch_protection.sh --print-expected | rg 'brandbook-tokens'` passed.
- `scripts/setup_branch_protection.sh --print-expected-json | jq -e '.required_status_checks.contexts | index("brandbook-tokens")'` returned `12`.
- `python3 -c "import yaml; d=yaml.safe_load(open('.github/workflows/ci.yml')); assert d['jobs']['brandbook-tokens']['name']=='brandbook-tokens'"` passed.
- `gh api repos/szTheory/rindle/branches/main/protection/required_status_checks --jq '.contexts | index("brandbook-tokens")'` returned `12`.
- `gh pr checks 23 --watch=false | rg '^brandbook-tokens'` returned `brandbook-tokens pass 43s`.

## Next Phase Readiness

- BP-94-01 is closed: the local branch-protection source of truth, live branch protection, and PR check rollup all include `brandbook-tokens`.
- Phase 94 is ready for re-verification to move from `gaps_found` to passed/complete.

## Self-Check: PASSED

- FOUND: `scripts/setup_branch_protection.sh`
- FOUND: `RUNNING.md`
- FOUND: `.github/workflows/ci.yml`
- FOUND: `94-05-SUMMARY.md`
- FOUND commit: `364d749` (Task 1)
- VERIFIED remote required context: `brandbook-tokens`
- VERIFIED PR check: `brandbook-tokens` passing

---
*Phase: 94-foundation-token-pipeline-ci-gate-new-token-categories*
*Completed: 2026-06-15*
