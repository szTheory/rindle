---
phase: 29-adopter-proof-matrix
plan: 04
subsystem: docs
tags: [docs, exunit, hexdocs, install-smoke, package-consumer]
requires:
  - phase: 29-01
    provides: image-only package-consumer proof lane
  - phase: 29-02
    provides: AV-enabled generated-app proof lane
  - phase: 29-03
    provides: CI and release-facing proof-matrix commands
provides:
  - README and getting-started language locked to the image-only plus AV package-consumer proof matrix
  - operations and release-doc parity aligned to the built-artifact and published-artifact proof split
  - strict docs generation fixed for RUNNING.md links and hidden internal probe references
affects: [README, guides, release-publish, docs-parity, release-preflight]
tech-stack:
  added: []
  patterns: [repo-native ExUnit docs parity, narrow README with deep-guide handoff, thin operations index]
key-files:
  created: [.planning/phases/29-adopter-proof-matrix/29-04-SUMMARY.md]
  modified: [README.md, guides/getting_started.md, guides/operations.md, guides/release_publish.md, test/install_smoke/docs_parity_test.exs, test/install_smoke/release_docs_parity_test.exs, mix.exs, lib/rindle/probe.ex]
key-decisions:
  - "Kept README narrow while moving built-vs-published artifact nuance into getting_started and release docs."
  - "Fixed the Wave 3 docs blocker by shipping RUNNING.md in HexDocs/package metadata and removing a hidden-module doc reference."
patterns-established:
  - "Public adopter docs describe the proved package-consumer matrix with exact ExUnit parity assertions."
  - "Operator docs cross-link proof entrypoints instead of duplicating install or release runbooks."
requirements-completed: [PROOF-04]
duration: 10min
completed: 2026-05-05
---

# Phase 29 Plan 04: Adopter Proof Matrix Summary

**Executable docs parity for the image-only and AV-enabled package-consumer proof matrix, plus strict HexDocs fixes for the release preflight surface**

## Performance

- **Duration:** 10 min
- **Started:** 2026-05-06T01:41:00Z
- **Completed:** 2026-05-06T01:51:17Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Updated `README.md` and `guides/getting_started.md` to teach the Phase 29 package-consumer matrix without turning adopter docs into a maintainer runbook.
- Kept `guides/operations.md` as a thin day-2 index while cross-linking the built-artifact and published-artifact proof surfaces.
- Extended ExUnit docs-parity coverage and cleared the Wave 3 release-preflight blocker caused by missing `RUNNING.md` docs metadata and a hidden internal module reference.

## Task Commits

Each task was committed atomically:

1. **Task 1: Teach the proved package-consumer matrix in README and getting-started** - `2480f3f` (`feat`)
2. **Task 2: Keep operations and release-doc parity aligned to the new proof matrix** - `2dc03c6` (`fix`)

## Files Created/Modified

- `README.md` - Narrow adopter quickstart now names the generated-app package-consumer image-only and AV proof posture.
- `guides/getting_started.md` - Canonical deep guide now explains built-artifact versus published-artifact proof and the installed-artifact matrix.
- `guides/operations.md` - Thin operator index now cross-links proof-related install and release docs.
- `guides/release_publish.md` - Maintainer runbook updated for the renamed CI job and the versioned public-smoke command.
- `test/install_smoke/docs_parity_test.exs` - Exact assertions for the package-consumer matrix and public-doc/runbook split.
- `test/install_smoke/release_docs_parity_test.exs` - Exact assertions for the renamed CI job, versioned public-smoke command, and operations proof cross-links.
- `mix.exs` - Added `RUNNING.md` to docs extras and packaged files so strict docs generation can resolve public file links.
- `lib/rindle/probe.ex` - Reworded moduledoc text to avoid linking a hidden internal module during docs generation.

## Decisions Made

- Kept maintainer-only release orchestration in `guides/release_publish.md` and out of README/getting-started even while documenting built-versus-published proof posture.
- Treated the strict-docs failures as Rule 3 adjacent fixes because Phase 29 verification and Wave 3 preflight both depend on `mix docs --warnings-as-errors`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed strict docs generation failures that blocked Wave 3 release preflight**
- **Found during:** Task 2
- **Issue:** `MIX_ENV=dev mix docs --warnings-as-errors` failed because README/getting-started linked `RUNNING.md` outside the configured docs extras, and `lib/rindle/probe.ex` linked hidden module `Rindle.AV.Probe`.
- **Fix:** Added `RUNNING.md` to `mix.exs` docs extras and package files, and rewrote the probe moduledoc to refer to the internal FFmpeg probe descriptively instead of as a hidden module link.
- **Files modified:** `mix.exs`, `lib/rindle/probe.ex`
- **Verification:** `MIX_ENV=dev mix docs --warnings-as-errors`; `bash scripts/release_preflight.sh`
- **Committed in:** `2dc03c6`

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Required to satisfy the plan verification surface and clear the inherited Wave 3 release-preflight blocker. No scope creep beyond docs/build correctness.

## Issues Encountered

- Wave 3 had already renamed the CI job to `Package Consumer Proof Matrix + Release Preflight`, so release docs and parity tests needed to be updated in the same plan to avoid drift.

## Verification Evidence

- `mix test test/install_smoke/docs_parity_test.exs test/install_smoke/release_docs_parity_test.exs`
- `MIX_ENV=dev mix docs --warnings-as-errors`
- `bash scripts/release_preflight.sh`

## Known Stubs

None.

## Next Phase Readiness

- PROOF-04 is satisfied and the docs surface now matches the proved package-consumer matrix enforced by tests and release preflight.
- The remaining dirty files are the pre-existing Wave 3 CI/script edits (`.github/workflows/ci.yml`, `scripts/install_smoke.sh`, `scripts/public_smoke.sh`, `scripts/release_preflight.sh`); they were intentionally preserved and not folded into this plan’s commits.

## Self-Check: PASSED

- Summary file exists.
- Task commits `2480f3f` and `2dc03c6` exist in git history.

---
*Phase: 29-adopter-proof-matrix*
*Completed: 2026-05-05*
