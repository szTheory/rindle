---
phase: 138-lifecycle-failure-and-recovery-matrix
plan: 02
subsystem: testing
tags: [s3, oban, purge, packaged-consumer]
requires: [138-01]
provides: [Authoritative absence between ordinary purge attempts, Typed purge case verification]
affects: [138-03, 138-06]
actuals: {tokens: 3600, tasks: 2, commits: 2}
tech-stack:
  added: []
  patterns: [Independent exact-key removal with separate authoritative HEAD]
key-files:
  created: []
  modified: [scripts/maintainer/built_package_twin.py, scripts/maintainer/twin_receipt.py, test/twin/host/lib/twin/tracer.ex, test/install_smoke/twin_fault_test.exs, test/install_smoke/twin_receipt_test.exs, test/rindle/workers/purge_storage_test.exs]
key-decisions:
  - Missing unversioned S3 DELETE may succeed; absence comes from an independent HEAD after exact-key MinIO removal.
patterns-established:
  - Typed per-case identities plus exact empty domain and bounded job inventory.
requirements-completed: []
requirements-covered: [RECOV-02]
coverage:
  - id: PURGE-ABSENCE
    description: One persisted purge job completes on ordinary attempt two after independently established source absence.
    requirement: RECOV-02
    verification:
      - kind: e2e
        ref: /private/tmp/rindle-138-purge-verified/receipt.json
        status: pass
    human_judgment: false
  - id: PURGE-CONTROLS
    description: Denied/unknown storage responses preserve rows and false receipt convergence rejects.
    verification:
      - kind: unit
        ref: test/rindle/workers/purge_storage_test.exs
        status: pass
      - kind: unit
        ref: test/install_smoke/twin_receipt_test.exs
        status: pass
    human_judgment: false
completed: 2026-10-22
status: complete
independent_pilot_credit: false
---

# Phase 138 Plan 02: Durable purge with independent absence

The same committed purge job completes at attempt two after exact-key removal and real S3 HEAD absence, without a second detach.

## Accomplishments

- Reused the committed run-owned source-delete-once fault, public attach/detach and ordinary Oban scheduling.
- At retryable attempt one, retained asset/source and stored error were observed; paused/quiescent state was reread before independent MinIO deletion.
- A separate real HEAD returned not-found while the asset remained, then ordinary queue resume completed the same job at attempt two.
- Final domain rows, objects, multipart uploads and temp files were empty, with the exact foundation history allowances verified before disposal.
- Explicit not_found/enoent branches still succeed; eacces/access_denied/unknown failures retain durable rows. No worker production changes.

## Task Commits

1. `18e713d3` — actual absence and ordinary retry, fault and worker controls.
2. `db6999bb` — closed purge receipt, shared exact inventory predicates and mutations.

## Verification

- `run --case purge-absence --cleanup`: exit zero, `/private/tmp/rindle-138-purge-first`.
- `run --case purge-absence --verify --cleanup`: exit zero, `/private/tmp/rindle-138-purge-verified`.
- Independent CLI verify of the second inputs/receipt: exit zero.
- Final `mix test test/install_smoke/twin_*_test.exs test/rindle/workers/purge_storage_test.exs --seed 0`: 28 tests, zero failures.
- Red absence/receipt tests failed before their implementations. Mutations cover denied/unknown HEAD, swapped source/asset/job, raced pause, attempts/errors, duplicate detach, substituted history, residue and incomplete listings.
- Legacy and tus receipt paths remain green. `git diff --check`: clean.

## Deviations and Issues Encountered

Input discriminator recognition again lands with allocation in task 1. Exact empty-inventory checks were extracted from the legacy verifier into a shared finite function, preserving its predicates. A legacy variable reference exposed by the fast suite was corrected before commit. No public API/schema/dependency change or attempt/backoff manipulation.

## Next Phase Readiness

138-03 can add real audio/video failure and repair. All RECOV requirements remain pending for the full shared matrix in 138-06. This diagnostic case supplies no independent-adopter, readiness or release credit. No user setup is required.

## Self-Check: PASSED
