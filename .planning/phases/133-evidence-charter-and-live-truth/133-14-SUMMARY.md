---
phase: 133-evidence-charter-and-live-truth
plan: 14
subsystem: testing
tags: [elixir, package-provenance, generated-consumer, evidence-receipts, adoption]
requires:
  - phase: 133-11
    provides: fail-closed evidence-path containment and immutable authority patterns
provides:
  - Canonical rindle-package-consumer-v1 receipts from the real generated-app package path
  - Independent reconstruction of Git, package, tree, dependency, argv, and result evidence
  - Distinct rindle-independent-adopter-v1 schema backed by an empty repository-owned allowlist
affects: [phase-137-twin-foundation, phase-139-exact-head-closure, TRUTH-08]
actuals:
  tokens: 10690
  tasks: 2
  commits: 5
tech-stack:
  added: []
  patterns: [content-addressed evidence receipts, untrusted locator context, repository-owned authorization]
key-files:
  created: []
  modified:
    - test/install_smoke/support/generated_app_helper.ex
    - scripts/maintainer/validate_live_truth.exs
    - test/install_smoke/live_truth_parity_test.exs
key-decisions:
  - "Keep filesystem paths outside the canonical receipt as untrusted locator context; authority comes from independently recomputed bytes and exact receipt fields."
  - "Treat maintainer package-consumer evidence as intrinsically non-authorizing and reserve independent adoption/1.0 scope for a separate repository-owned allowlist that remains empty."
patterns-established:
  - "Exact receipt schemas reject missing and additional fields before evaluating evidence."
  - "Command evidence records exact argv, exit status, bounded merged-output digest metadata, and a persisted canonical result receipt."
requirements-completed: [TRUTH-08]
coverage:
  - id: D1
    description: Real generated-package consumers emit and satisfy an immutable package evidence receipt.
    requirement: TRUTH-08
    verification:
      - kind: integration
        ref: "test/install_smoke/live_truth_parity_test.exs#fresh unpacked generated image consumer report authorizes package proof"
        status: pass
    human_judgment: false
  - id: D2
    description: Forged receipt fields and substituted evidence locations fail independent validation.
    requirement: TRUTH-08
    verification:
      - kind: unit
        ref: "mix test test/install_smoke/live_truth_parity_test.exs --only package_authority"
        status: pass
    human_judgment: false
  - id: D3
    description: Independent adopter authority uses a separate exact schema and remains false with the empty owned allowlist.
    requirement: TRUTH-08
    verification:
      - kind: unit
        ref: "test/install_smoke/live_truth_parity_test.exs#independent adopter authority is repository-owned and empty until a pilot is approved"
        status: pass
      - kind: other
        ref: "./scripts/maintainer/check_adoption_proof_matrix.sh"
        status: pass
    human_judgment: false
duration: 21min
completed: 2026-09-10
status: complete
---

# Phase 133 Plan 14: Immutable Package and Adopter Authority Summary

**Real generated consumers now emit content-addressed package receipts that are independently reconstructed, while independent adopter and 1.0 authority remain locked behind a distinct empty repository-owned allowlist.**

## Performance

- **Duration:** 21 min
- **Started:** 2026-09-10T21:09:18Z
- **Completed:** 2026-09-10T21:29:54Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Replaced the arbitrary-directory positive oracle with a receipt emitted by the real built/unpacked generated-app package path.
- Bound package acceptance to the exact Git subject, package metadata and tree, generated source tree, dependency lock/source, command argv, and persisted bounded command-result digests.
- Split independent-adopter evidence into its own exact schema; caller names, labels, paths, copied receipts, and authorization booleans cannot grant independent adoption or 1.0 status.

## Task Commits

1. **Task 1 RED: require canonical package evidence interfaces** - `f8367fd` (test)
2. **Task 1 GREEN: authenticate generated package receipts** - `55b290e` (feat)
3. **Task 2 RED: require independent adopter authority** - `1872cde` (test)
4. **Task 2 GREEN: isolate independent adopter authority** - `a54cb6d` (feat)
5. **Task 2 hardening: reject substituted evidence locations** - `bdfecc1` (test)

## Files Created/Modified

- `test/install_smoke/support/generated_app_helper.ex` - Produces canonical receipts and content/result digests from the real generated consumer.
- `scripts/maintainer/validate_live_truth.exs` - Reconstructs package authority and validates the distinct independent-adopter schema against the owned allowlist.
- `test/install_smoke/live_truth_parity_test.exs` - Exercises the real producer, every canonical field class, substituted locator contexts, copied receipts, and caller-controlled adoption mutations.

## Decisions Made

- Receipt schemas contain only canonical authority facts; package/app/result filesystem paths are supplied as untrusted context and never authenticate themselves.
- The generated helper records stderr as merged into stdout because the existing command runner deliberately captures one bounded stream; the receipt makes that capture mode explicit rather than inventing separate output evidence.
- Maintainer-operated package success derives `authorizes_independent_adoption: false` and `authorizes_1_0: false`; only a future reviewed entry in `@independent_adopter_authorities` can change those outcomes.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added valid-receipt locator substitution coverage**
- **Found during:** Overall trust-boundary verification after Task 2
- **Issue:** Canonical field mutations were exhaustive, but no test paired a valid receipt with arbitrary package, generated-app, or result-receipt locations.
- **Fix:** Added failures for substituted directories and filenames, proving locators cannot substitute for matching bytes.
- **Files modified:** `test/install_smoke/live_truth_parity_test.exs`
- **Verification:** Focused package-authority suite passed with 4 tests and 0 failures.
- **Committed in:** `bdfecc1`

---

**Total deviations:** 1 auto-fixed (1 missing critical)
**Impact on plan:** The additional cases strengthen the planned T-133-53/T-133-54 mitigations without expanding product scope.

## Issues Encountered

- The pinned Elixir 1.17/OTP 27 pair is not installed locally. Verification used installed Elixir 1.19.5/OTP 28 as a diagnostic cell; Plan 07 remains Phase 133's supported-toolchain authority.
- The generated image lifecycle requires MinIO to remain live in the same verification shell. The repository bootstrap script supplied that service for each real-producer run.

## Known Stubs

None.

## Authentication Gates

None.

## User Setup Required

None - no external service configuration required.

## Verification

- `mix test test/install_smoke/live_truth_parity_test.exs --only package_authority --timeout 1200000` - 4 tests, 0 failures, including the real generated-package consumer.
- `./scripts/maintainer/check_adoption_proof_matrix.sh` - derived authority 6/6, package authority 4/4, matrix result `OK`.
- `./scripts/maintainer/automation_first_contract.sh` - passed for Phase 133.
- `mix format --check-formatted` on all three modified files - passed.

## TDD Gate Compliance

- Task 1 RED commit `f8367fd` failed because the canonical producer/verifier interfaces did not exist; GREEN commit `55b290e` made the real producer and mutation suite pass.
- Task 2 RED commit `1872cde` failed because independent-adopter verification did not exist; GREEN commit `a54cb6d` introduced the separate schema and empty owned authority registry.
- Hardening commit `bdfecc1` retained GREEN while extending the adversarial locator matrix.

## Next Phase Readiness

- TRUTH-08 package authority is suitable for the later maintainer-operated twin and exact-head closure phases.
- Independent adoption and 1.0 graduation intentionally remain open until a named external pilot receives a repository-reviewed authority entry.

## Self-Check: PASSED

- All three declared modified files exist.
- Commits `f8367fd`, `55b290e`, `1872cde`, `a54cb6d`, and `bdfecc1` exist in Git history.
- Every plan verification command passed after the final change; no stubs, skipped tests, deleted tracked files, unrun verification, or unplanned threat surface remains.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-09-10*
