---
phase: 136-measured-quality-and-ci-ratchets
plan: 03
status: complete
subsystem: testing
tags: [coverage, exact-counts, source-freeze]
requires:
  - phase: 136
    provides: Plans 01/02/04/05/06/08/10 source owners
provides:
  - Source-bound exact coverage receipt writer and verifier
  - Conservative ExCoveralls minimum with empirical precision tests
affects: [136-11, 136-qualification]
tech-stack:
  added: []
  patterns: [integer ratio validation, new-only same-run receipts]
key-files:
  created: [scripts/maintainer/verify_coverage_floor.exs, test/install_smoke/coverage_floor_policy_test.exs]
  modified: [scripts/maintainer/phase136_evidence.py, scripts/maintainer/phase136_evidence_contract.json, coveralls.json, test/install_smoke/phase136_qualification_test.exs]
key-decisions:
  - Delegate the Elixir entrypoint to the shared standard-library evidence owner.
  - Require observed supported Elixir/OTP and Node20 in coverage provenance.
  - Keep minimum82.2 with explicit flooring because ExCoveralls exposes only one decimal.
requirements-completed: [COV-06]
coverage:
  - id: exact-coverage
    description: Same-run source-bound count and local-gate proof with malformed and mutation rejection
    verification:
      - kind: unit
        ref: mix test test/install_smoke/coverage_floor_policy_test.exs --seed 0
        status: pass
    human_judgment: false
completed: 2026-10-20
---

# Phase 136 Plan 03: Exact Coverage Gate

The new-only writer preserves canonical argv, supported runtime, source SHA/tree, exact covered/relevant counts and raw artifact/local-output digests and payloads. Verification recomputes counts and integer floor comparison without running a suite, and rejects altered history, missing fields, foreign subjects, changed payloads and fabricated success. Writer inputs must postdate the declared run start. Existing receipts cannot be overwritten.

## Task commits

- Task1 RED22f9f849; GREEN9b80ecb1.
- Task2 RED8616fb45; GREEN6f0d9627.
- Both initial failing assertions have preserved JUnit evidence accepted as RED_EVIDENCE_OK.

## Verification

- Receipt and qualification regression: 10 tests, zero failures.
- Combined Phase136 owners: 138 tests, 137 passed and one precision-fixture failure retained in 136-03-PRECISION-OBSERVATION.json. ExCoveralls floors the floating result for exact82.2 to82.1; the corrected fixture explicitly proves that behavior and uses82.21 as the stable passing input.
- After that correction the full coverage policy file passed5/5 in13.1seconds, including actual ExCoveralls minimum enforcement, exact equality/one-line-below, malformed/stale input, source/runtime/local-output/digest mutations and no-clobber behavior.
- Live Credo, formatting, Python compilation, whitespace and automation-first passed. Schema/UI gates do not block; codebase drift skipped without STRUCTURE.md.
- Changed risk behavior is covered by the owner suites for Credo, Dialyzer matcher/runner, async runner/validator, CI consumers/topology, bootstrap and timing. No product source or skip_files changed.

## Deviations and readiness

The shared Python helper/contract and matching qualification fixture were explicitly added to the plan scope before implementation. No package addition or runtime-file edit occurred. Empirical one-decimal flooring requires a conservative82.2 minimum; exact count acceptance remains82.1343. No canonical coverage suite has run. COV-06 remains Pending until Plan11 measures the committed subject. Source/config implementation is finished; Plan11 must make only planning evidence changes and run the canonical local+JSON command once.

## Self-Check: PASSED
