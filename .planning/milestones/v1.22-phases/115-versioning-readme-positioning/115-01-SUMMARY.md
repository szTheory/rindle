---
phase: 115-versioning-readme-positioning
plan: 01
subsystem: docs
tags: [versioning, readme, upgrading, docs-parity]

requires:
  - phase: 113-evaluation-baseline-release-hygiene
    provides: "EVAL-01 scored-weakness rows for versioning, README positioning, and host-respect boundaries"
provides:
  - "VERSION-01: README and CONTRIBUTING pre-1.0 SemVer stability contract"
  - "VERSION-02: reusable newest-first upgrading guide home"
  - "README-01: image-first original attachment path before AV setup"
  - "README-02: When Not to Use Rindle product-fit boundary"
  - "Docs parity locks for Phase 115 claims"
affects:
  - "Phase 116 migration docs should build on the versioned upgrade-guide structure"
  - "README/HexDocs adopter onboarding"

tech-stack:
  added: []
  patterns:
    - "Docs parity tests lock README and guide ordering for adopter-contract prose"
    - "Upgrade guide separates CHANGELOG release history from adopter action steps"

key-files:
  created:
    - .planning/phases/115-versioning-readme-positioning/115-01-SUMMARY.md
  modified:
    - README.md
    - CONTRIBUTING.md
    - guides/upgrading.md
    - test/install_smoke/docs_parity_test.exs

key-decisions:
  - "Kept Phase 115 docs-only; no lib/, priv/, release-version, dependency, CSS, JS, or migration API changes."
  - "README first-run path is original-only image attachment with variants: [] before AV setup."
  - "guides/upgrading.md is now the reusable action-oriented upgrade home while CHANGELOG.md owns release history."

patterns-established:
  - "Use one exact shared stability sentence across adopter and contributor surfaces."
  - "Use docs parity assertions for documentation claims that affect adopter behavior."

requirements-completed: [VERSION-01, VERSION-02, README-01, README-02]

duration: 6 min
completed: 2026-07-01
status: complete
---

# Phase 115 Plan 01: Versioning & README Positioning Summary

**Pre-1.0 stability contract, versioned upgrade guide, image-first README onboarding, and parity tests for the docs claims**

## Performance

- **Duration:** 6 min
- **Started:** 2026-07-01T15:32:02Z
- **Completed:** 2026-07-01T15:38:10Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments

- Added the exact shared SemVer/pre-1.0 stability sentence to README and CONTRIBUTING near the top of each document.
- Reworked `guides/upgrading.md` into a newest-first upgrade home with Version index, Unreleased / Next, and the preserved 0.1.3-and-earlier AV-aware upgrade path.
- Repositioned README around `## First Attachment in ~2 Minutes` with an original-only image profile before the heavier `## AV Quickstart`.
- Added `## When Not to Use Rindle` with the Phoenix/Ecto library boundary and explicit non-goals from `guides/user_flows.md`.
- Extended `test/install_smoke/docs_parity_test.exs` to lock the stability, upgrade-guide, README ordering, and product-fit contracts.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add stability contract and versioned upgrade home** - `64d0560` (docs)
2. **Task 2: Reposition README around image-first onboarding and the product-fit boundary** - `476a66f` (docs)
3. **Task 3: Lock Phase 115 docs claims in docs parity tests** - `55c0a31` (test)

## Files Created/Modified

- `README.md` - Adds the versioning contract, original-only image-first first attachment section, demoted AV quickstart, and When Not to Use Rindle boundary.
- `CONTRIBUTING.md` - Adds the same contributor-facing versioning and stability contract before CI detail.
- `guides/upgrading.md` - Converts the single runbook into a reusable versioned upgrade guide while preserving generated-app migration, doctor, runtime_status, requeue, and regenerate proof paths.
- `test/install_smoke/docs_parity_test.exs` - Adds regression locks for the Phase 115 stability, upgrade-guide, README ordering, and product-fit contracts.

## Decisions Made

- Kept Phase 115 to docs and proof only; no runtime, migration API, release-version, package, dependency, styling, CSS, or JS files changed.
- Used the exact required D-03 stability sentence once in README and once in CONTRIBUTING.
- Kept current raw packaged-migration guidance in README and upgrading; Phase 116 still owns `Rindle.Migration` docs.
- Kept runtime dependency detail in `RUNNING.md` and linked `running.html` from README instead of adding a long matrix.

## Verification

- `MIX_ENV=test mix test test/install_smoke/docs_parity_test.exs --trace` - PASS (28 tests, 0 failures).
- `mix format --check-formatted test/install_smoke/docs_parity_test.exs` - PASS.
- Task 1 Node stability/upgrade-guide source checks - PASS.
- Task 2 Node README ordering/boundary source check - PASS.
- `grep -R 'Rindle\.Migration\.' README.md CONTRIBUTING.md guides/upgrading.md` - PASS, no Phase 116 migration API docs introduced.
- `mix ci` - PASS (3 doctests, 1227 tests, 0 failures, 4 skipped).

## Deviations from Plan

None - plan scope executed as written. Final committed source changes are limited to `README.md`, `CONTRIBUTING.md`, `guides/upgrading.md`, and `test/install_smoke/docs_parity_test.exs`.

## Issues Encountered

- The Task 3 `read_first` list referenced `test/support/generated_app_helper.ex`, which does not exist. The actual helper used by the test suite is `test/install_smoke/support/generated_app_helper.ex`; that file was read before editing the parity test.
- The first Task 3 test run found a local assertion issue with repeated upgrade-guide subsection labels and `assert_in_order!/2`; the assertion was narrowed to each version section, formatted, and re-run successfully before commit.

## Authentication Gates

None.

## Known Stubs

None. The "No upgrade notes for this version yet" copy in `guides/upgrading.md` is the intentional UI-SPEC empty state for `## Unreleased / Next`.

## User Setup Required

None - no external service configuration required.

## Threat Flags

None - this plan introduced no new network endpoints, auth paths, file access patterns, schema changes, or trust-boundary code. Threat mitigations from the plan are covered by docs parity assertions.

## Next Phase Readiness

Phase 116 can now build its migration install/upgrade docs on the versioned `guides/upgrading.md` structure. The Phase 115 scope guardrails are preserved: README, CONTRIBUTING, and upgrading still do not document `Rindle.Migration.up/1` or `down/1`.

## Self-Check: PASSED

- FOUND: README.md
- FOUND: CONTRIBUTING.md
- FOUND: guides/upgrading.md
- FOUND: test/install_smoke/docs_parity_test.exs
- FOUND: commit `64d0560`
- FOUND: commit `476a66f`
- FOUND: commit `55c0a31`

---
*Phase: 115-versioning-readme-positioning*
*Completed: 2026-07-01*
