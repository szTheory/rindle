---
phase: 121-truthful-quality-signals-mechanical-hygiene
plan: 06
subsystem: quality-policy
tags: [credo, bash, jq, static-analysis, regression-tests]
requires:
  - phase: 121-03
    provides: Curated public documentation and specification surface.
  - phase: 121-04
    provides: Zero-warning full-tree baseline.
provides:
  - A fail-fast aggregate for warnings, public docs/specs, and complexity/nesting debt.
  - A stable 33-identity, 37-occurrence Credo debt manifest with ownership metadata.
affects: [phase-123, phase-124, phase-125, maintainer-quality]
tech-stack:
  added: []
  patterns: [separate Credo named profiles, stable identity multiset comparison]
key-files:
  created:
    - scripts/maintainer/credo_quality.sh
    - scripts/maintainer/credo_complexity_baseline.json
    - test/install_smoke/credo_policy_test.exs
  modified:
    - .credo.exs
key-decisions:
  - "Use three Credo 1.7-compatible named configurations instead of unsupported per-check exclusions."
  - "Gate complexity debt by counted check/file/trigger/metric identities, never source locations or full diagnostic prose."
patterns-established:
  - "Maintain quality debt as an explicit owner/removal-trigger inventory rather than exclusions."
requirements-completed: [SIGNAL-03]
coverage:
  - id: D1
    description: Fail-fast Credo aggregate for global warnings, explicit public contracts, and complexity debt.
    requirement: SIGNAL-03
    verification:
      - kind: integration
        ref: bash scripts/maintainer/credo_quality.sh
        status: pass
    human_judgment: false
  - id: D2
    description: Regression proof for profile scope and baseline additions, deletions, identity changes, and count drift.
    requirement: SIGNAL-03
    verification:
      - kind: unit
        ref: test/install_smoke/credo_policy_test.exs
        status: pass
    human_judgment: false
duration: 8min
completed: 2026-08-22
status: complete
---

# Phase 121 Plan 06: Credo Quality Aggregate Summary

**A Credo 1.7-compatible quality ratchet now blocks global warnings and curated public contract drift while inventorying 37 complexity/nesting findings as 33 stable identities.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-08-22T18:14:00-04:00
- **Completed:** 2026-08-22T18:22:00-04:00
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added distinct `blocking_warnings`, `public_contract`, and `complexity_inventory` Credo profiles without exclusions.
- Added a fail-fast maintainer command that validates Credo JSON and compares normalized counted identities against the checked-in debt inventory.
- Added focused policy tests for warning bite, profile restraint, manifest ownership, and identity/count drift.

## Task Commits

1. **Task 1: Build the multi-profile Credo aggregate and exact debt manifest** — `40d7515` (chore)
2. **Task 2: Prove aggregate bite, restraint, and baseline ownership** — `72cce6b` (test)

## Files Created/Modified

- `.credo.exs` — advisory default plus three purpose-specific blocking profiles.
- `scripts/maintainer/credo_quality.sh` — fail-fast aggregate and normalized multiset comparator.
- `scripts/maintainer/credo_complexity_baseline.json` — 33 debt identities, 37 occurrences, owners, and removal triggers.
- `test/install_smoke/credo_policy_test.exs` — aggregate and baseline regression coverage.

## Decisions Made

- Warnings, public docs/specs, and complexity/nesting run in separate named configurations because Credo 1.7 cannot truthfully scope them with per-check exclusions in one profile.
- The complexity comparator extracts only the numeric metric from diagnostic text; line, column, scope, and full-message churn cannot change the gate.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Issues Encountered

The initial explicit Mix task paths used directory-style names; the repository uses dotted task filenames. The profile was corrected before its task commit and verified against the live Credo run.

## User Setup Required

None - `jq`, already used by repository maintainer tooling, is the only external command required by the aggregate.

## Next Phase Readiness

Phases 123–125 can retire their assigned rows only by updating the counted manifest alongside green Credo output; unassigned rows remain visibly owned by developer-approved scope.

## Self-Check: PASSED

- All four plan artifacts exist.
- Task commits `40d7515` and `72cce6b` exist.
- Focused policy tests and the fresh aggregate both passed.
