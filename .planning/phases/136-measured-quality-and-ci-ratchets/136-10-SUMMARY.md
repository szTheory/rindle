---
phase: 136-measured-quality-and-ci-ratchets
plan: 10
status: complete
subsystem: testing
tags: [evidence, source-freeze, qualification, coverage]
requires:
  - phase: 136
    provides: Plans 02/04/05/06/08 owner implementations
provides:
  - Isolated frozen-source collection and receipt verification
  - Exact coverage interface and recomputed seven-authority qualification
affects: [136-coverage-floor, 136-final-measurements]
tech-stack:
  added: []
  patterns: [commit-by-commit source projection, immutable sanitized command artifacts]
key-files:
  created:
    - scripts/maintainer/phase136_evidence.py
    - scripts/maintainer/phase136_measure.sh
    - scripts/maintainer/verify_phase136_qualification.sh
    - scripts/maintainer/phase136_evidence_contract.json
    - test/install_smoke/phase136_measure_test.exs
    - test/install_smoke/phase136_qualification_test.exs
  modified: []
key-decisions:
  - Share source and receipt validation between shell entrypoints through one standard-library Python implementation.
  - Verify every post-pin commit, including mutations later reverted; allow only planning tails and no dirty/untracked source.
  - Receipt verification authenticates truthful open outcomes; qualification completion requires every derived authority complete.
requirements-completed: [TYPE-03, TEST-08, DX-05, COV-06, MAINT-04, CI-15, CI-16]
coverage:
  - id: frozen-collectors
    description: Pinned fresh/restored analysis, finite async and full bootstrap receipts
    verification:
      - kind: unit
        ref: mix test test/install_smoke/phase136_measure_test.exs --seed 0
        status: pass
    human_judgment: false
  - id: qualification
    description: Seven recomputed authorities with exact coverage and authenticated timing interface
    verification:
      - kind: unit
        ref: mix test test/install_smoke/phase136_qualification_test.exs --seed 0
        status: pass
    human_judgment: false
duration: 30min
completed: 2026-10-20
---

# Phase 136 Plan 10: Frozen-Source Evidence and Qualification

The collector validates the immutable SHA/tree, every intervening commit and dirty/untracked non-planning paths before executing the frozen owners in private detached no-hardlink clones. Fresh/restored Dialyzer retains PLT inventory identity across a genuine private save/restore; async preserves the original JSONL and derives its complete/open result through the pinned validator; bootstrap requires the pinned clean full owner receipt.

## Accomplishments

- New-only receipts and sidecar artifact directories preserve bounded command output, digests, exits, argv, supported runtime, PLT provenance and owner payloads. Inherited secret values are redacted from published diagnostics.
- Source mutation followed by revert fails, while planning-only evidence tails pass.
- Qualification derives all seven statuses from same-subject receipts, frozen Credo/CI checks and the existing live timing verifier, retaining open/blocked outcomes instead of trusting booleans.
- Coverage contract fixes the canonical local+JSON argv and exact 821343/1000000 ratio. Artifact-derived counts, local suite output and digests are required. The future coverage validator was neither read nor invoked.

## Task Commits

1. RED 9d0f9a0e; tracer GREEN 57b2698c; expansion GREEN 8fb98d75.
2. RED ff897447; GREEN c7e07a89.

## Verification

- Combined collector/qualification suite: 13 tests, 0 failures (16.3 seconds), Elixir 1.17.3 / OTP 27.3.4.15 with Node 20.18.1 selected.
- Fixtures cover relative paths, unsupported runtime, immutable target reuse, source/tree drift and revert history, missing modes/output, changed PLT provenance, handwritten green manifests, missing/foreign evidence, first-red async and over-envelope timing.
- Exact coverage adjacent counts 821342/821343/821344 over 1000000 yield false/true/true.
- Both preserved JUnit RED reports returned RED_EVIDENCE_OK.
- Live Credo, Bash syntax and whitespace passed; capability gates do not block. Codebase drift is explicitly skipped without STRUCTURE.md.
- All collection and API authority tests used explicit fake command owners. No real final measurement or requirement qualification credit was granted.

## Deviations

Added the focused standard-library phase136_evidence.py helper to the plan's declared scope before implementation, avoiding duplicate policy between entrypoints. Sidecar .artifacts directories are part of each logical receipt and must accompany its evidence commit. A nested filename-selection expression in the qualification fixture was split into named clauses to preserve the complexity ceiling. No package addition or coverage configuration change in this plan.

## Next Phase Readiness

Wave 3 complete. Plan 03 implements the already-defined coverage interface and finishes source/config. Plan 11 alone pins and runs the canonical coverage suite; Plan 09 collects real quality/bootstrap evidence, and Plan 07 owns live exact-ten timing. All seven requirements remain Pending until their final authorities qualify.

## Self-Check: PASSED
