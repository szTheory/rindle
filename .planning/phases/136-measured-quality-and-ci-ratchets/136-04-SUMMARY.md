---
phase: 136-measured-quality-and-ci-ratchets
plan: 04
status: complete
subsystem: testing
tags: [async, evidence, no-clobber]
requires:
  - phase: 135
    provides: Supported runtime evidence
provides:
  - Complete/open/blocked async receipt validator
  - Atomic immutable report reservation and exact runtime provenance
affects: [136-final-evidence]
tech-stack:
  added: []
  patterns: [exclusive report creation, strict source-bound receipts]
key-files:
  created: [scripts/maintainer/verify_async_isolation_receipt.sh]
  modified: [scripts/maintainer/async_isolation_evidence.sh, test/install_smoke/async_isolation_evidence_runner_test.exs]
key-decisions:
  - Finite first-red outcome remains open with uncertainty and next trigger.
  - Fixture runtime is explicitly synthetic; real supported evidence belongs to Plan 09.
requirements-completed: [TEST-08]
coverage:
  - id: async-receipts
    description: Strict bounded seed-prefix validation and immutable report creation
    verification:
      - kind: unit
        ref: mix test test/install_smoke/async_isolation_evidence_runner_test.exs --seed 0
        status: pass
    human_judgment: false
duration: 8min
completed: 2026-10-20
---

# Phase 136 Plan 04: Finite Async Evidence

The real runner and a new read-only validator now round-trip complete 25-seed and first-red fixture receipts. Validation derives seed/argv/schema authority from the runner declaration, checks current SHA and accepted Elixir 1.17.3 / OTP 27.3.4.15, and rejects malformed/duplicate JSON keys, changed subjects, reordered or duplicate seeds, unexpected argv, partial all-green runs, invalid exits, unsanitized locations and post-red records.

## Accomplishments

- Complete/open/blocked JSON verdicts include explicit uncertainty and an evidence-based next trigger.
- Runner now records exact OTP patch provenance as well as Elixir version.
- Dangling report symlinks are refused; a physical direct-parent check prevents traversal escape; noclobber reservation holds one descriptor for every write, preserving first bytes across concurrent creation attempts.
- Existing first-red report bytes and invocation log remain exact after a rejected rerun. The fixed 25-seed matrix and stop-first-red behavior are unchanged.

## Task Commits

1. RED 5a8e8bba; GREEN 9fb3102e — first-red receipt tracer and validator.
2. RED 098769bf; GREEN 84017520 — dangling-symlink refusal, atomic reservation and mutation matrix.

## Verification

- Focused suite: 7 tests, 0 failures (1.4 seconds), supported local runtime.
- Both preserved JUnit assertion-failure reports returned RED_EVIDENCE_OK.
- Bash syntax and git diff --check passed.
- All runner test commands and runtime records are synthetic fixtures; no production finite experiment or TEST-08 qualification credit is claimed.

## Deviations

Task 1 also touched the runner's toolchain extraction because its old receipt only identified Elixir and could not prove the required OTP cell. No package additions, historical report edits or CI topology changes.

## Issues Encountered

None outstanding for implementation. TEST-08 stays Pending until Plan 09's final-subject experiment.

## Next Phase Readiness

Continue Wave 1 Plan 05. Real evidence is deferred until source freeze.

## Self-Check: PASSED
