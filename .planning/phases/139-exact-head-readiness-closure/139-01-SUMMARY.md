---
phase: 139-exact-head-readiness-closure
plan: "01"
subsystem: maintainer-evidence
tags: [readiness, receipts, integrity, pure-policy]
requires:
  - phase: 133-evidence-charter-and-live-truth
    provides: Versioned receipt and live-truth policy patterns
provides:
  - Offline CLI and pure validate_contract/2 for a finite 23-proof evidence graph
  - Subject-preserving refresh envelope validation with original and refreshed byte bindings
affects: [139-02, 139-03, 139-04, 139-05, 139-06]
actuals:
  tasks: 2
  commits: 3
tech-stack:
  added: []
  patterns: [pure policy with bounded confined CLI loader, immutable byte graph]
key-files:
  created: [scripts/maintainer/validate_exact_head_readiness.exs, scripts/ci/test_exact_head_readiness.sh]
  modified: []
key-decisions:
  - Scope fixture verdicts explicitly and grant no requirements credit from offline validation.
  - Require separate fresh mutable receipt objects bound to the unchanged original manifest digest.
requirements-completed: [READY-04, READY-05]
evidence_scope: implementation_only
coverage:
  - id: readiness-graph
    description: Complete fixture enters real CLI; malformed proof, identity, source, command, cleanup and adoption states fail
    requirement: READY-04
    verification:
      - kind: integration
        ref: bash scripts/ci/test_exact_head_readiness.sh
        status: pass
    human_judgment: false
completed: 2026-10-22
status: complete
---

# Immutable readiness evidence graph

A complete byte-bound fixture returns ready with explicit fixture scope and zero
requirements credit. The finite registry includes supported local gates, full main CI,
scheduled Nightly, effective protection, remote inventory and adoption parity. All
receipts bind repository, subject, tool/input identity, artifact digest kinds and interval.

## Task Commits

1. Task 1: `229673ab` implements CLI, pure policy, confined byte loader and complete fixture.
2. Task 2 RED: `a7ab660b` exposes three false-ready paths in registered commands,
   cache exceptions and source-observation intervals.
3. Task 2 GREEN: `13772cd9` enforces command suffixes, permitted residue classes and source intervals.

## Verification

`bash scripts/ci/test_exact_head_readiness.sh`: 54 tests, zero failures, about 1.2 seconds.
The suite includes the actual subprocess CLI, byte corruption/missing objects, escape and
symlink rejection, missing/duplicate/unknown proofs, wrong SHA/repository/package/event,
forged success, skipped/timeout work, source visibility, run/attempt changes, omitted jobs,
protection drift, Hex identity and synthetic-credit inflation. Bound-source mutations
rewrite their observation digests before policy assertions, so failures exercise semantic
policy rather than stopping incidentally on a stale digest. Refresh tests reject changed
original identity, missing/corrupt new receipts, stale intervals and forged verdicts.

`mix format --check-formatted` passed for the validator; artifact-ledger offline validation
passed for all 3278 tracked files/46 classes; automation-first contract passed.

## Deviations from Plan

None. Source-specific acquisition and topology derivation remain in Plans 03/04; this
plan validates their normalized byte-bound contract. Digests establish byte identity,
not independent authenticity. Actual same-subject execution remains necessary.

## Next Phase Readiness

Plans 02/03/04 can consume this contract. READY-01–05 remain pending until actual Plan 07
acceptance; the requirements array records implementation coverage only.

## Self-Check: PASSED

Both created files and all three task commits exist. All final fixture, format and
repository contract checks passed after the last implementation change.
