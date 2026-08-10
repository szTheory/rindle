---
phase: 120-adoption-proof-release-truth
plan: 05
subsystem: documentation
tags: [docs, postgres, migrations, oban, operator-runbook, parity-tests]
requires:
  - phase: 118-isolated-migration-safe-upgrade
    provides: version-pinned, host-owned public-to-rindle migration and guarded reverse
  - phase: 119-ownership-boundaries-diagnostics
    provides: bounded doctor/runtime diagnostic classifications and independent Oban ownership
  - phase: 120-adoption-proof-release-truth
    provides: fresh-install documentation parity from Plan 04
provides:
  - Executable populated-upgrade runbook with maintenance, permission, lock, deploy, and verification order
  - Bounded troubleshooting routes for Rindle prefix/setup and host Oban faults
  - Docs-parity contracts that reject unsafe migration claims
affects: [120-06-release-truth, docs-parity, operator-guidance]
tech-stack:
  added: []
  patterns:
    - Section-scoped docs-parity tests enforce operational ordering and ownership boundaries.
key-files:
  created:
    - .planning/phases/120-adoption-proof-release-truth/120-05-SUMMARY.md
  modified:
    - guides/upgrading.md
    - guides/troubleshooting.md
    - test/install_smoke/docs_parity_test.exs
key-decisions:
  - "Populated upgrades explicitly require backup/quiescence, a host migration with local lock timeout, matching deployment, then doctor and runtime-status verification."
  - "Troubleshooting routes Rindle schema faults separately from host-owned Oban binding faults without adding remediation authority."
patterns-established:
  - "Use per-condition documentation subsections when the same diagnostic command occurs in multiple operator funnels."
requirements-completed: [DOCS-01]
coverage:
  - id: D1
    description: "Populated 0.4.0 upgrade runbook states safe ordering, permissions, locking, verification, and bounded rollback."
    requirement: DOCS-01
    verification:
      - kind: unit
        ref: "mix test test/install_smoke/docs_parity_test.exs --seed 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "Troubleshooting preserves separate Rindle and host-Oban diagnosis and action boundaries."
    requirement: DOCS-01
    verification:
      - kind: unit
        ref: "mix test test/install_smoke/docs_parity_test.exs test/rindle/doctor_test.exs test/rindle/runtime_status_task_test.exs --seed 0"
        status: pass
    human_judgment: false
duration: 22min
completed: 2026-08-10
status: complete
---

# Phase 120 Plan 05: Operational Upgrade and Troubleshooting Truth Summary

**0.4.0 populated upgrades now have an ordered, permission-aware maintenance runbook and bounded schema/Oban troubleshooting routes, mechanically enforced by docs parity.**

## Performance

- **Duration:** 22 min
- **Started:** 2026-08-10T20:43:00Z
- **Completed:** 2026-08-10T21:05:14Z
- **Tasks:** 2/2
- **Files modified:** 3

## Accomplishments

- Made the populated public-to-`rindle` upgrade sequence explicit: backup and quiescence, host migration with local lock timeout, matching deployment, then doctor and runtime-status verification.
- Documented database-owner/privilege expectations, `ACCESS EXCLUSIVE` lock behavior, and the guarded-reverse versus backup-restore rollback boundary.
- Added discrete troubleshooting funnels for Rindle prefix mismatch, missing Rindle setup, and independently host-owned Oban binding faults.

## Task Commits

1. **Task 1: Make the populated 0.4.0 operator sequence executable**
   - `d448b5f` test: locked the RED docs-parity contract
   - `2dc8f37` docs: implemented the operator runbook
2. **Task 2: Route schema and Oban faults through bounded troubleshooting**
   - `87e64e6` test: locked the RED troubleshooting contract
   - `fc755b9` docs: implemented bounded diagnostic routes

## Files Created/Modified

- `guides/upgrading.md` — populated-upgrade sequencing, privilege/lock behavior, verification, and guarded rollback.
- `guides/troubleshooting.md` — owner-safe Rindle and Oban setup-fault routes.
- `test/install_smoke/docs_parity_test.exs` — ordered operator-story and forbidden-claim assertions.

## Decisions Made

- The runbook treats Ecto's migration lock as migrator serialization only; traffic quiescence remains an operator responsibility.
- Oban setup and the public host ledger remain host-owned even while Rindle relations move to `rindle`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Scoped repeated diagnostic-order assertions to their individual routes**
- **Found during:** Task 2
- **Issue:** The shared ordering helper finds the first occurrence of each snippet, so one combined assertion could not verify repeated `mix rindle.doctor` commands across three routes.
- **Fix:** Split the parity contract into prefix-mismatch, missing-setup, and Oban-binding sections before checking each route's order.
- **Files modified:** `test/install_smoke/docs_parity_test.exs`
- **Verification:** `mix test test/install_smoke/docs_parity_test.exs test/rindle/doctor_test.exs test/rindle/runtime_status_task_test.exs --seed 0`
- **Committed in:** `fc755b9`

**Total deviations:** 1 auto-fixed (Rule 1 - test assertion bug).
**Impact on plan:** The correction strengthens the intended section-scoped behavioral contract without expanding product scope.

## Issues Encountered

None.

## Known Stubs

None.

## Next Phase Readiness

- Plan 06 can consume a mechanically enforced, operationally honest documentation contract for release-truth reconciliation.
- No blocker remains for this plan.

## Self-Check: PASSED

- Confirmed all three modified artifacts exist.
- Confirmed task commits `d448b5f`, `2dc8f37`, `87e64e6`, and `fc755b9` exist in git history.
- Final focused verification passed: 59 tests, 0 failures.

---
*Phase: 120-adoption-proof-release-truth*
*Completed: 2026-08-10*
