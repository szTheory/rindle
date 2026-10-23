---
phase: 139-exact-head-readiness-closure
plan: "00"
subsystem: runtime-diagnostics
tags: [doctor, ecto, migrations, regression]
requires:
  - phase: 138-lifecycle-failure-and-recovery-matrix
    provides: Verified versioned package-host reproduction
provides:
  - Doctor inspects configured host migration files against the host-owned ledger
  - Versioned marker and unavailable migration inspection retain failing diagnoses
affects: [139-02, readiness]
actuals:
  tasks: 2
  commits: 4
tech-stack:
  added: []
  patterns: [host-owned migration authority, sandboxed real-ledger regressions]
key-files:
  created: []
  modified: [lib/rindle/ops/runtime_checks.ex, lib/rindle/ops/runtime_checks/ownership_checks.ex, test/rindle/doctor_test.exs]
key-decisions:
  - Use Ecto.Migrator.migrations_path for the configured host Repo, including its priv setting.
  - Only known packaged legacy versions receive compatibility warnings; unknown host work remains failing.
requirements-completed: [READY-01]
evidence_scope: implementation_only
coverage:
  - id: doctor-host-ledger
    description: Completed versioned host ledger passes; down or unresolved wrapper and missing/invalid marker fail
    requirement: READY-01
    verification:
      - kind: integration
        ref: mix test test/rindle/doctor_test.exs test/rindle/ops/runtime_checks_test.exs test/rindle/migration_test.exs test/install_smoke/twin_cli_test.exs test/rindle/public_surface_snapshot_test.exs
        status: pass
    human_judgment: false
completed: 2026-10-22
status: complete
---

# Doctor host migration inspection

Doctor reads the configured host's Ecto migration path and ledger. A normal host-owned
versioned wrapper no longer appears as fifteen pending package migrations plus an
unresolved wrapper. Existing catalog, host-owned Oban and upgrade checks remain active.

## Task Commits

1. Task 1 RED: `ff942380` reproduces the completed/down host and empty marker faults.
2. Task 1 GREEN: `e393a6ea` inspects the host ledger and limits legacy compatibility.
3. Task 2 RED: `18aaf4ba` rejects unavailable host migration directories.
4. Task 2 GREEN: `ac60a898` preserves inspection errors and adverse catalog states.

## Verification

- Focused Doctor/runtime/migration/twin/public-surface suite: 66 tests, zero failures,
  four excluded. The Doctor suite includes actual sandboxed host ledger/catalog reads.
- `mix quality_signals`: reviewed Credo passed without baseline changes, measured
  documentation/spec coverage 100%, refactor contract passed, 97 tests, zero failures.
- Public API snapshot unchanged. No migration is replayed by Doctor.
- RED reports: `/private/tmp/rindle139-doctor-red.txt` and
  `/private/tmp/rindle139-doctor-adverse-red.txt`; assertion failures confirmed the
  planned diagnostic behavior before each correction.

## Deviations from Plan

The new real-ledger probe also exposed two bounded inspection defects: an empty marker
table was classified as a healthy legacy install, and a missing migration directory
looked like an empty inventory. Both now fail. Known legacy catalog/history retains
warning-only compatibility. A first Credo run rejected added nesting; the final
implementation uses a flat `with` and passes the unchanged quality policy.

## Next Phase Readiness

Plan 00 implementation is complete. READY-01 remains pending until Plan 07's actual
post-merge, exact-main acceptance; the requirements array above records coverage only.
Older verification fingerprints remain historical and are not rewritten.

## Self-Check: PASSED

All three changed source/test files exist, the four task commits are reachable,
focused tests and required quality checks passed after the last source edit.
