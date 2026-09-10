---
phase: 133-evidence-charter-and-live-truth
plan: "08"
subsystem: release-engineering
tags: [elixir, package-provenance, generated-consumer, fail-closed-validation]
requires:
  - phase-133-plan-05
  - phase-133-plan-07
provides:
  - One package-claim normalization path that rejects caller-controlled validation markers
  - Adversarial coverage for inline and CLI receipts with nonexistent provenance paths
affects: [phase-133-verification, phase-139, release-truth, adoption-proof]
actuals:
  tokens: 974
  tasks: 1
  commits: 3
tech-stack:
  added: []
  patterns:
    - Keep caller package receipts raw until claim-boundary provenance validation
    - Never encode normalized authority as a caller-replayable discriminator
key-files:
  created: []
  modified:
    - scripts/maintainer/validate_live_truth.exs
    - test/install_smoke/live_truth_parity_test.exs
key-decisions:
  - "Normalize every inline or model-held package receipt at validate_package_claim!/2, regardless of caller-supplied map fields."
  - "Remove the validated marker from normalized proof data so normalized authority cannot be replayed as public input."
patterns-established:
  - "Claim-boundary provenance: package and adoption claims always recheck origin, filesystem, lifecycle, source, and fallback facts."
requirements-completed: [TRUTH-08]
coverage:
  - id: D1
    description: "Reject caller-forged package authority through both validate_claims!/2 and --package-receipt input while preserving real generated-consumer acceptance."
    requirement: TRUTH-08
    verification:
      - kind: integration
        ref: "test/install_smoke/live_truth_parity_test.exs#package_authority"
        status: pass
    human_judgment: false
duration: 11min
completed: 2026-09-10
status: complete
---

# Phase 133 Plan 08: Package-Proof Authority Closure Summary

**Package and adoption claims now revalidate generated-consumer provenance at the call boundary, making caller-forged validation markers and nonexistent evidence paths non-authoritative.**

## Performance

- **Duration:** 11 min
- **Started:** 2026-09-10T15:00:48Z
- **Completed:** 2026-09-10T15:11:46Z
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments

- Removed the caller-controlled `validated: true` shortcut from package claim validation.
- Kept `--package-receipt` data raw until the same claim-boundary normalizer used by inline receipts.
- Added executable negative coverage for minimal forged maps and fully shaped reports with nonexistent unpacked/generated-consumer roots while retaining the fresh generated-package lifecycle proof.

## Task Commits

1. **Task 1 RED: expose forged package authority bypass** - `fe76157` (test)
2. **Task 1 GREEN: require provenance normalization at claim boundary** - `b934c90` (fix)
3. **Task 1 fixture hardening: prove forged provenance paths fail closed** - `6bb3f56` (test)

## Files Created/Modified

- `scripts/maintainer/validate_live_truth.exs` - Routes every package receipt through generated-consumer normalization at claim validation and removes the replayable validation marker.
- `test/install_smoke/live_truth_parity_test.exs` - Exercises forged inline/CLI receipts, nonexistent provenance paths, fallback mutations, adoption scope, and fresh unpacked package acceptance.

## Decisions Made

- Model-held CLI receipts remain untrusted raw input until a package or adoption claim is evaluated; the public and CLI paths therefore cannot diverge.
- Normalized proof data contains only facts needed for source and fallback validation, not a boolean or sentinel that can impersonate authority.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The repository-pinned Elixir 1.17.3/OTP 27 toolchain is not installed locally. Verification used the installed Elixir 1.19.5/OTP 28 diagnostic cell; Plan 07 remains the authoritative exact supported-cell evidence.
- The first local package-authority attempt lacked the `phx.new` archive under the installed OTP-27 diagnostic environment. Switching to the already-installed Elixir 1.19.5/OTP 28 environment provided the existing archive without installing dependencies.
- The generated image consumer initially could not reach MinIO after a short-lived bootstrap process exited. Holding the repository-provided MinIO binary live for the verification session restored the real upload lifecycle proof.

## Known Stubs

None.

## Authentication Gates

None.

## User Setup Required

None - no external service configuration required.

## Verification

- `mix test test/install_smoke/live_truth_parity_test.exs --only package_authority` under installed Elixir 1.19.5/OTP 28 - 5 tests, 0 failures, including the fresh built/unpacked generated image consumer.
- `mix test test/install_smoke/live_truth_parity_test.exs:253` under installed Elixir 1.19.5/OTP 28 - 1 adversarial test, 0 failures; covers inline and `--package-receipt` inputs.
- `mix format --check-formatted scripts/maintainer/validate_live_truth.exs test/install_smoke/live_truth_parity_test.exs` - passed.
- `./scripts/maintainer/automation_first_contract.sh` - passed.
- Source assertion confirmed no `field(receipt, :validated)` or normalized `validated: true` marker remains and every package claim calls `normalize_package_receipt!/1`.

## Next Phase Readiness

- TRUTH-08's caller-owned package receipt gap is closed with executable negative evidence.
- Plans 09 and 10 can close the remaining exact-receipt and supported-toolchain verifier gaps without changing package, API, schema, workflow, dependency, telemetry, or error-vocabulary surfaces.

## TDD Gate Compliance

- RED commit `fe76157` demonstrated the forged receipt was accepted before implementation.
- GREEN commit `b934c90` removed the shortcut and made the focused package-authority suite pass.
- Test-hardening commit `6bb3f56` proves fully shaped forged receipts reach the filesystem provenance checks.

## Self-Check: PASSED

- Both declared modified files exist, and commits `fe76157`, `b934c90`, and `6bb3f56` are present in Git history.
- Every plan verification command passed with non-zero test counts after the final change.
- No known stub, skipped Plan 08 test, deleted tracked file, unrun plan verification, or unplanned threat surface remains.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-09-10*
