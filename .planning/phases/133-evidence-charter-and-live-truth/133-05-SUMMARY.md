---
phase: 133-evidence-charter-and-live-truth
plan: "05"
subsystem: release-engineering
tags: [elixir, yaml, github-actions, package-provenance, evidence]
requires:
  - phase-133-plan-04
provides:
  - Derived version authority requiring equality between mix.exs and the release manifest
  - Parsed CI and Nightly topology model with fail-closed mutation checks
  - Built/unpacked generated-consumer package proof gate with no-fallback enforcement
affects: [phase-133-plan-06, phase-139, release-truth, adoption-proof]
actuals:
  tokens: 8651
  tasks: 2
  commits: 4
tech-stack:
  added: []
  patterns:
    - Derive release and lane claims from authoritative files before validating consumers
    - Accept package claims only from normalized generated-consumer provenance
key-files:
  created:
    - scripts/maintainer/validate_live_truth.exs
    - test/install_smoke/live_truth_parity_test.exs
  modified: []
key-decisions:
  - "Keep workflow topology authoritative through YamlElixir maps while preserving exact CI, required-check, fork-safety, and release-coupling identities."
  - "Require generated-app compile, boot, smoke, lifecycle, unpacked metadata, exact source, and explicit no-fallback facts before accepting package evidence."
  - "Keep TRUTH-08 open until Plan 06 reconciles every active claim surface against this authority."
patterns-established:
  - "Bounded history: only .planning/milestones/** and balanced non-nested historical receipt markers are exempt from active version checks."
  - "Package authority: prose, checkout compilation, mocks, repository paths, and prebuilt output cannot substitute for a fresh generated consumer."
requirements-completed: []
coverage:
  - id: D1
    description: "Derive current release and CI/Nightly topology from equal release authorities and parsed workflow structure."
    requirement: TRUTH-08
    verification:
      - kind: unit
        ref: "test/install_smoke/live_truth_parity_test.exs#derived_authority"
        status: pass
    human_judgment: false
  - id: D2
    description: "Require real unpacked generated-consumer provenance with exact source and no repository or prebuilt fallback."
    requirement: TRUTH-08
    verification:
      - kind: integration
        ref: "test/install_smoke/live_truth_parity_test.exs#package_authority"
        status: pass
    human_judgment: false
duration: 21min
completed: 2026-09-09
status: complete
---

# Phase 133 Plan 05: Derived Live-Truth Authority Summary

**Release, workflow, and package claims now share one fail-closed authority derived from equal version sources, parsed lane topology, and fresh unpacked consumer evidence.**

## Performance

- **Duration:** 21 min
- **Started:** 2026-09-10T01:17:07Z
- **Completed:** 2026-09-10T01:38:16Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Added `Rindle.ValidateLiveTruth.run/1`, `derive!/2`, and `validate_claims!/2` with CLI support for root, JSON output, repeatable claim paths, package receipts, and bounded historical markers.
- Locked release `0.4.6`, `ci.yml` / workflow `CI` / sole `CI Summary`, exact needs, off-critical-path lanes, fork-safe PR representatives, exact-SHA release coupling, and strict Nightly applicability from authoritative files.
- Required generated-consumer compile, boot, smoke, lifecycle, unpacked metadata, exact install source, and explicit no-repository/no-prebuilt facts before package or adoption evidence can pass.
- Preserved the distinction between maintainer-operated synthetic evidence and a named independent adopter; synthetic proof cannot authorize 1.0.

## Task Commits

1. **Task 1 RED: failing live authority contract** - `ff13b49` (test)
2. **Task 1 GREEN: derived release and workflow authority** - `6bda307` (feat)
3. **Task 2 RED: failing package provenance contract** - `3438d85` (test)
4. **Task 2 GREEN: unpacked package provenance gate** - `7fcb175` (feat)

## Files Created/Modified

- `scripts/maintainer/validate_live_truth.exs` - Derives authoritative release/workflow state and validates active, package, and adoption claims.
- `test/install_smoke/live_truth_parity_test.exs` - Exercises authority mutations, bounded history, real generated-package proof, provenance failures, and adoption scope.

## Decisions Made

- Workflow lane claims are classified only from parsed triggers, conditions, needs, outputs, and job identities; prose and substring assertions remain non-authoritative.
- Package receipts must originate at the existing generated-app helper and prove the unpacked artifact still exists with package metadata at validation time.
- TRUTH-08 remains pending until Plan 06 changes and validates the currently contradictory active claim surfaces. Closing it in this plan would violate the repository's automation-first acceptance contract.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The first direct package-authority run found no local MinIO process. The repository-owned `scripts/ensure_minio.sh` prepared the expected service, after which the fresh unpack/build/generated-app proof passed.
- An initial diagnostic `MIX_ENV=dev mix quality_signals` invocation used the wrong environment for the contract suite and failed to load test support. The maintained gate was rerun as `MIX_ENV=test mix quality_signals` and passed.
- Full `mix ci` reached the default suite but remained red on four pre-existing `file_mutation` findings in `test/install_smoke/evidence_census_test.exs`. The focused Phase 133 Plan 05 suites pass, and this plan did not change that Plan 01 test owner.
- Local Hex authentication is expired, but dependency resolution needed no private resources and all requested verification completed without an authentication gate.

## Known Stubs

None.

## Authentication Gates

None.

## User Setup Required

None - no external service configuration required.

## Verification

- `mix test test/install_smoke/live_truth_parity_test.exs --only derived_authority` - 5 tests, 0 failures.
- `mix test test/install_smoke/live_truth_parity_test.exs --only package_authority` - 4 tests, 0 failures, including the fresh generated image consumer.
- `mix test test/install_smoke/package_metadata_test.exs test/install_smoke/generated_app_smoke_test.exs` - 34 tests, 0 failures.
- Focused parity/policy/package aggregate - 96 tests, 0 failures.
- `mix format --check-formatted` - passed.
- `MIX_ENV=test mix quality_signals` - passed Credo policy, Doctor, cycle, contract, and 97 contract tests.
- `mix ci` - 1459 tests, 1 pre-existing async-safety failure, 4 skipped; not an acceptance substitute for the passing focused contracts.

## Next Phase Readiness

- Plan 06 can feed active planning, support, adoption, and guide surfaces into the derived model and replace the stale substring-only adoption gate with this package authority.
- TRUTH-08 intentionally remains open until those active surfaces pass the validator.
- No public API, package contents, generated helper contract, schema/migration, telemetry/error, dependency, workflow, or adoption scope changed.

## TDD Gate Compliance

- Each planned task has a RED test commit followed by its GREEN implementation commit.

## Self-Check: PASSED

- Both declared files exist and all four task commits are present in Git history.
- Every plan-level command passed with non-zero test counts; the real package case used a freshly built and unpacked artifact.
- No known stub, skipped Plan 05 test, deleted tracked file, unrun plan verification, or unplanned threat surface blocks Plan 06.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-09-09*
