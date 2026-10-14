---
phase: 133-evidence-charter-and-live-truth
plan: 13
subsystem: evidence-census
tags: [elixir, exunit, evidence, provenance, path-safety, tdd]

requires:
  - phase: 133-11
    provides: Immutable pending-validation reconciliation and physical containment precedent
provides:
  - Per-dimension repository-owned detector authority under mixed applicability
  - Exact repository-owned inapplicability dimension and reason allowlist
  - Canonical repository-relative observation locations with lexical and physical containment
affects: [133-14, 133-15, 133-16, 133-17, EVID-01]

actuals:
  tokens: 7303
  tasks: 2
  commits: 4

tech-stack:
  added: []
  patterns:
    - Per-row authority validation independent of neighboring applicability
    - Lexical normalization plus component-wise symlink containment
    - Bounded diagnostics that omit externally resolved paths

key-files:
  created: []
  modified:
    - scripts/maintainer/evidence_census.exs
    - scripts/maintainer/validate_evidence_census.exs
    - test/install_smoke/evidence_census_test.exs

key-decisions:
  - "Permit only the performance dimension to be inapplicable, and only with the exact repository-owned minimal-tracer reason."
  - "Authenticate each applicable taxonomy row against its exact detector ID, dimension, command, and normalized input set before candidate assignment checks."
  - "Canonicalize observation locations after lexical and component-wise symlink containment, while returning one bounded diagnostic for every escape family."

patterns-established:
  - "Mixed applicability: an allowed exemption never disables authority checks for any applicable neighbor."
  - "Evidence provenance: repository-relative text is insufficient until its existing symlink components resolve inside the inspected root."

requirements-completed: [EVID-01]

coverage:
  - id: D1
    description: One allowed inapplicable dimension coexists with independently authenticated applicable detectors.
    requirement: EVID-01
    verification:
      - kind: integration
        ref: mix test test/install_smoke/evidence_census_test.exs
        status: pass
    human_judgment: false
  - id: D2
    description: Collector and validator reject lexical, absolute, and symlink observation escapes and canonicalize contained aliases.
    requirement: EVID-01
    verification:
      - kind: integration
        ref: mix test test/install_smoke/evidence_census_test.exs
        status: pass
      - kind: other
        ref: ./scripts/maintainer/automation_first_contract.sh
        status: pass
    human_judgment: false

duration: 10min
completed: 2026-09-10
status: complete
---

# Phase 133 Plan 13: Mixed Census Authority and Observation Containment Summary

**Every applicable census dimension now retains exact repository-owned authority beside a bounded exemption, and every observation location is canonicalized only after lexical and physical repository containment.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-09-10T20:55:37Z
- **Completed:** 2026-09-10T21:05:32Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Replaced the all-dimensions-applicable detector gate with independent exact authority checks for every applicable taxonomy row.
- Restricted inapplicability to the repository-owned performance exemption and its byte-exact bounded reason.
- Canonicalized accepted dot-segment aliases to stable repository-relative locations at both collection and validation boundaries.
- Rejected parent traversal, multi-level traversal, absolute paths, and child symlinks resolving outside the inspected repository without disclosing the external target.
- Preserved candidate bijection, dispositions, transition identity, deterministic ordering, and precision contracts across mixed applicability.

## Task Commits

Each task used a fail-first test commit followed by its verified implementation:

1. **Task 1: Validate one applicable detector beside one allowed inapplicable dimension**
   - `5bdea89` — mixed-applicability authority and exact-reason RED cases
   - `d1d7a78` — per-dimension registry authentication and bounded allowlist
2. **Task 2: Contain every observation location within the repository**
   - `9d66832` — traversal, canonical-alias, absolute-path, and symlink RED cases
   - `aeb1da1` — collector and validator lexical/physical containment

## Files Created/Modified

- `scripts/maintainer/evidence_census.exs` — canonicalizes and physically contains observation locations while building receipts.
- `scripts/maintainer/validate_evidence_census.exs` — enforces exact per-dimension authority, bounded inapplicability, and independent location containment.
- `test/install_smoke/evidence_census_test.exs` — covers mixed authority mutations and collector/validator provenance escape families.

## Decisions Made

- Used one exact performance exemption rather than allowing the ledger to invent dimensions or rationales.
- Compared applicable detector authority before candidate bijection so a substituted detector identity is diagnosed at the trust boundary that rejected it.
- Walked existing path components and resolved symlinks instead of trusting lexical normalization alone; nonexistent contained paths remain valid evidence labels.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The repository-pinned Elixir 1.17.3/OTP 27 toolchain is not installed locally. Verification ran on the already-installed diagnostic Elixir 1.19.5/OTP 28.4.1 toolchain; supported-cell authority remains owned by Phase 133 Nightly evidence.
- An initial OTP 27 diagnostic run overlapped dependency compilation and produced incompatible BEAM artifacts. Re-running on the established local OTP 28 diagnostic toolchain rebuilt cleanly; no source or dependency changes were needed.

## Known Stubs

None. Empty-value checks found by the scan are validation predicates, not UI/data placeholders.

## Authentication Gates

None.

## User Setup Required

None - no external service configuration required.

## Verification

- `mix test test/install_smoke/evidence_census_test.exs` — 15 tests, 0 failures.
- `./scripts/maintainer/automation_first_contract.sh` — passed for the active Phase 133 planning artifacts.
- `mix format --check-formatted scripts/maintainer/evidence_census.exs scripts/maintainer/validate_evidence_census.exs test/install_smoke/evidence_census_test.exs` — passed.

## Next Phase Readiness

- The Plan 11 append-only pending-validation records remain byte-preserved and their two exact Plan 13 commands now pass without being rewritten as retrospective acceptance.
- Later census freezes can mix the one explicit exemption with applicable dimensions without weakening detector, candidate, disposition, ordering, precision, or provenance authority.
- No public API, schema/migration, telemetry, error vocabulary, dependency, CI topology, or release coupling changed.

## TDD Gate Compliance

- Both task RED commits precede their GREEN implementation commits.
- The Task 1 tracer verification was rerun end to end before Task 2 expansion.

## Self-Check: PASSED

- All three declared modified artifacts exist.
- All four TDD commits resolve in Git history.
- Both plan verification commands passed with 15 nonzero ExUnit tests.
- No known stub, skipped test, or unrun verification blocks the plan goal.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-09-10*
