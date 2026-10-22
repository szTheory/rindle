---
phase: 138-lifecycle-failure-and-recovery-matrix
plan: 01
subsystem: testing
tags: [tus, plug, s3, oban, packaged-consumer]
requires:
  - phase: 137-built-package-twin-foundation
    provides: Fresh-package external host and owned resource isolation
provides:
  - HTTP tus client recreation with committed offsets and exact ready inventory
  - Independently verified closed diagnostic tus receipt
affects: []
actuals:
  tokens: 4500
  tasks: 2
  commits: 2
tech-stack:
  added: []
  patterns: [Separate exited HTTP client processes, Source-owned typed case predicates]
key-files:
  created: []
  modified: [scripts/maintainer/built_package_twin.py, scripts/maintainer/twin_receipt.py, test/twin/host/lib/twin/web.ex, test/twin/host/lib/twin/tracer.ex, test/install_smoke/twin_tracer_contract_test.exs, test/install_smoke/twin_receipt_test.exs]
key-decisions:
  - Use two sequential exited container shell clients and curl; no new client dependency.
  - Keep signed Location and headers private on the same retained S3 tus node.
patterns-established:
  - A schema-version-two case receipt is diagnostic; it is not full-matrix acceptance.
requirements-completed: []
requirements-covered: [RECOV-01]
coverage:
  - id: TUS-HTTP
    description: A new HTTP client resumes after an acknowledged nonfinal PATCH and wrong-offset refusal.
    requirement: RECOV-01
    verification:
      - kind: e2e
        ref: /private/tmp/rindle-138-tus-verified/receipt.json
        status: pass
    human_judgment: false
  - id: TUS-VERIFIER
    description: Strict bound receipt rejects foreign identities, reused clients, checksum and inventory mutations.
    verification:
      - kind: unit
        ref: test/install_smoke/twin_receipt_test.exs
        status: pass
    human_judgment: false
completed: 2026-10-22
status: complete
independent_pilot_credit: false
---

# Phase 138 Plan 01: Packaged tus recovery

Two exited HTTP clients resume one S3 tus session and produce one ready asset with an exact original and thumb.

## Accomplishments

- Mounted the shipped TusPlug on the external Phoenix endpoint; ordinary committed Oban work creates the derivative.
- First client: POST 201, nonfinal PATCH 204/32 bytes. After it exits, a distinct client observes HEAD 204/32/no-store, PATCH 409 at the wrong offset, unchanged HEAD 32, and final PATCH 204/69.
- Downloaded source SHA-256 matches the fixed 69-byte PNG; exactly the original plus the declared thumb key exist. One session, asset and upload stimulus are required.
- Added closed schema-version-two diagnostic verification while preserving the Phase 137 verifier.

## Task Commits

1. `cd642006` — recreated HTTP client trace and host route.
2. `059ebca1` — independent typed receipt and mutation controls.

## Verification

- `mix test test/install_smoke/twin_tracer_contract_test.exs test/install_smoke/twin_receipt_test.exs --seed 0`: 9 tests, zero failures after final edits.
- Broader Docker-free twin suite: 19 tests, zero failures before the final dictionary-shape guard; focused suite rerun afterward.
- `run --case tus-resume --cleanup`: passed at `/private/tmp/rindle-138-tus-fourth`.
- `run --case tus-resume --verify --cleanup`: passed at `/private/tmp/rindle-138-tus-verified`; a subsequent independent CLI verify using its inputs/receipt also passed.
- Red tests failed on the missing client validator and missing case verifier before implementation. Negative controls cover input swaps, client identity/HEAD/offset, duplicate stimuli, checksum, ready state, exact keys, missing/unknown fields and sensitive extras.
- `git diff --check`: clean. Schema drift: no ORM/schema files. UI and schema-drift hook flags are disabled; codebase drift skips because no STRUCTURE.md.

## Deviations from Plan

Input-version recognition landed with task 1 so allocation/disposal can validate the new diagnostic descriptor. The client validator and fixed fixture moved into the receipt owner in task 2 to share the exact predicates without an import cycle. No public API/schema or dependency change.

## Issues Encountered

The first real attempt stopped at Docker Buildx sandbox activity-file access; execution was retried with approved escalation. Two host assertions were corrected to the shipped download `{:ok, path}` result and terminal `ready` state. Original failed receipts remain retained in `/private/tmp/rindle-138-tus-first`, `-second` and `-third`; disposal did not turn those attempts green.

## Next Phase Readiness

138-02 can add authoritative-absence purge recovery. All RECOV requirements remain pending until the shared full-matrix integration and separate verification in 138-06. This case does not claim cross-node or mid-PATCH transport recovery, full cleanup, AV, independent adoption or readiness. No user setup is required.

## Self-Check: PASSED
