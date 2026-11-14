---
phase: 139-exact-head-readiness-closure
plan: "08"
subsystem: ci-evidence
tags: [github-actions, exact-sha, ci-receipts, bash]
requires:
  - phase: 139-07
    provides: Historical readiness acceptance context and the Phase 133 reconciliation path
provides:
  - Exact-SHA CI Summary receipts authenticated to GitHub Actions App ID 15368
  - Regression coverage for malformed and altered app identity
affects: [phase-133-reconciliation, readiness-ci-evidence]
actuals:
  tokens: 1621.5
  tasks: 2
  commits: 3
  plan_head_before: f3686d974eb8b5fd730e8394f16edc29b67b1e46
  plan_head_after: d7fdf3b9d8d891bd599dc33bbad101816ac01f4d
tech-stack:
  added: []
  patterns: [exact app identity binding, strict live receipt comparison]
key-files:
  created: []
  modified:
    - scripts/ci/verify_nightly_run.sh
    - scripts/ci/test_verify_nightly_run.sh
key-decisions:
  - Require numeric GitHub Actions App ID 15368 for the unique exact-name, exact-SHA CI Summary check.
  - Retain check_app_id in the receipt so live revalidation detects removed or altered identity.
requirements-completed: [READY-02, READY-04]
coverage:
  - id: D1
    description: Exact-SHA CI Summary receipts require GitHub Actions App ID 15368 and reject malformed or tampered app identity.
    requirement: READY-02
    verification:
      - kind: integration
        ref: bash scripts/ci/test_verify_nightly_run.sh
        status: pass
    human_judgment: false
duration: 29min
completed: 2026-11-14
status: complete
---

# Phase 139 Plan 08: Exact-SHA CI App Identity Summary

**Exact-SHA CI Summary receipts now bind GitHub Actions App ID 15368 and revalidate that identity against the live check.**

## Performance

- **Duration:** 29 min
- **Started:** Approximately 2026-11-14T02:14:00Z; invocation time was not captured.
- **Completed:** 2026-11-14T02:43:02Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- The verifier requires the selected successful `CI Summary` check to have numeric `app.id` 15368, the GitHub Actions app.
- The receipt stores `check_app_id`, so strict comparison with fresh live evidence rejects removed or changed app identity.
- Fake API regressions reject foreign, absent, null, and nonnumeric app IDs, plus retained receipts with changed or removed IDs.

## Task Commits

1. **Task 1 RED: app identity regression cases** - `6f997494` (`test(139-08): cover CI Summary app identity`)
2. **Task 1 GREEN: bind receipt to GitHub Actions** - `465d6475` (`feat(139-08): bind CI receipt to GitHub Actions`)
3. **Task 2: malformed and tampered receipt cases** - `d7fdf3b9` (`test(139-08): reject malformed and altered app receipts`)

Plan metadata is recorded in the commit containing this summary.

## Files Created/Modified

- `scripts/ci/verify_nightly_run.sh` - Validates the app identity and includes it in emitted receipt JSON.
- `scripts/ci/test_verify_nightly_run.sh` - Covers correct, foreign, missing, malformed, and tampered app identity.

## Decisions Made

- Kept the existing exact-name and exact-SHA uniqueness rules and used the current shell/jq path; no dependency or remote request was added.
- Preserved the existing strict whole-receipt comparison and non-overwrite behavior.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

The intentional RED run showed the existing verifier accepted a foreign app and omitted the receipt field. The implementation fixed both, and the final regression run passed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The Phase 133 reconciliation call path now receives app-bound CI evidence. This local fixture result grants no new current-head readiness; the retained historical terminal and unresolved edge-probe assumptions remain unchanged.

## Self-Check

PASSED. Both implementation files and this summary exist; all three task commits are ancestors of the worktree HEAD; coverage classification passed with one fully automated deliverable; and `./scripts/maintainer/automation_first_contract.sh` passed.

---
*Phase: 139-exact-head-readiness-closure*
*Completed: 2026-11-14*
