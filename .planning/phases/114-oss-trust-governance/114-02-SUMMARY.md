---
phase: 114-oss-trust-governance
plan: 02
subsystem: package-metadata
tags: [hex, mix, install-smoke, metadata]

requires:
  - phase: 114-oss-trust-governance
    provides: governance files from Plan 01 remain repo-only and outside Hex package files
provides:
  - Hex package links for GitHub, Changelog, and Docs
  - Hex package maintainer declaration for szTheory
  - Package metadata smoke coverage for order-independent link assertions and maintainer config
affects: [phase-114, phase-115, release-publish, hex-package]

tech-stack:
  added: []
  patterns:
    - "Install-smoke metadata checks assert individual generated metadata tuples instead of whole-list link equality."
    - "Mix package maintainer declarations are locked against Mix.Project package config when Hex build output does not serialize them."

key-files:
  created:
    - .planning/phases/114-oss-trust-governance/114-02-SUMMARY.md
  modified:
    - mix.exs
    - test/install_smoke/package_metadata_test.exs

key-decisions:
  - "Use @source_url interpolation for the Changelog link and a latest-version HexDocs URL for Docs."
  - "Verify package links from unpacked Hex metadata with whitespace-compacted tuple checks so pretty-printed long URLs do not make the test brittle."
  - "Verify maintainers from Mix.Project package config because Hex 2.5 does not serialize the Mix package :maintainers key into this package's unpacked hex_metadata.config."

patterns-established:
  - "Package metadata tests should assert individual metadata entries, not exact whole-map ordering."

requirements-completed: [META-01, META-02]

duration: 4 min
completed: 2026-06-30
status: complete
---

# Phase 114 Plan 02: Hex Package Metadata Summary

**Hex package metadata now declares szTheory as maintainer and exposes GitHub, Changelog, and HexDocs links with install-smoke coverage.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-06-30T14:53:03Z
- **Completed:** 2026-06-30T14:57:10Z
- **Tasks:** 1
- **Files modified:** 3

## Accomplishments

- Added `maintainers: ["szTheory"]` to `mix.exs` `package/0`.
- Added `Changelog` and `Docs` entries to `package.links` while preserving the existing `GitHub` link.
- Replaced the GitHub-only whole-list metadata assertion with order-independent link tuple checks and a maintainer package-config assertion.
- Left `files:`, `@required_paths`, and `@prohibited_paths` unchanged.

## Task Commits

1. **Task 1: mix.exs links + maintainers, paired with meta-test update** - `c55f2e0` (feat)

## Files Created/Modified

- `mix.exs` - Added `maintainers: ["szTheory"]`; added `Changelog` and `Docs` package links.
- `test/install_smoke/package_metadata_test.exs` - Added order-independent generated metadata checks for all three links and a maintainer package-config check.
- `.planning/phases/114-oss-trust-governance/114-02-SUMMARY.md` - Captures plan outcome and verification.

## Checks Run

- `mix test test/install_smoke/package_metadata_test.exs` - PASS, 15 tests, 0 failures.
- `mix ci` - PASS, 3 doctests and 1222 tests, 0 failures, 4 skipped, 77 excluded.
- Acceptance greps - PASS for `maintainers: ["szTheory"]`, `GitHub`, `Changelog`, and `Docs`.
- Path-list unchanged check - PASS; no diff touched `files:`, `@required_paths`, or `@prohibited_paths`.

## Decisions Made

- Used `@source_url` interpolation for the Changelog URL, matching the plan and avoiding duplicated owner/repo literals in `mix.exs`.
- Kept generated metadata assertions order-independent by asserting each link tuple after whitespace compaction.
- Asserted `maintainers` through `Mix.Project.config()[:package]`; the local Hex 2.5 unpacked metadata did not serialize the Mix package `:maintainers` key for this package.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Made link metadata assertions robust to Hex pretty-printing**
- **Found during:** Task 1
- **Issue:** The unpacked `hex_metadata.config` split the long Changelog tuple across lines, so a direct substring assertion failed despite correct generated metadata.
- **Fix:** Added `compact_metadata = String.replace(metadata, ~r/\s+/, "")` for tuple-presence assertions.
- **Files modified:** `test/install_smoke/package_metadata_test.exs`
- **Verification:** `mix test test/install_smoke/package_metadata_test.exs` and `mix ci` pass.
- **Committed in:** `c55f2e0`

**2. [Rule 1 - Bug] Corrected maintainer assertion target**
- **Found during:** Task 1
- **Issue:** The plan expected a top-level serialized `{<<"maintainers">>, ...}` tuple in unpacked Hex metadata, but Hex 2.5 did not emit that tuple for this Mix package.
- **Fix:** Kept `mix.exs` `package/0` as planned and asserted `Mix.Project.config()[:package][:maintainers] == ["szTheory"]` in the package metadata smoke test.
- **Files modified:** `test/install_smoke/package_metadata_test.exs`
- **Verification:** `mix test test/install_smoke/package_metadata_test.exs` and `mix ci` pass.
- **Committed in:** `c55f2e0`

---

**Total deviations:** 2 auto-fixed (Rule 1).
**Impact on plan:** The shipped metadata and META-01/META-02 checks are complete; the only change was making the smoke test match actual Hex build output.

## Issues Encountered

The first two smoke-test runs exposed formatting and serialization assumptions in the planned assertions. Both were resolved in the implementation commit.

`mix ci` also printed the repo's existing dependency advisory list and an expired Hex authentication-session warning, but the command completed successfully.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None. Stub-pattern scan hits in `test/install_smoke/package_metadata_test.exs` were existing test literals / guards (`dryrun-placeholder`, `package_root != ""`), not product or UI stubs.

## Next Phase Readiness

Phase 114 metadata scope is complete. Phase 115 can build on the package page trust signals and move to versioning / README positioning.

## Self-Check: PASSED

- Summary file exists at `.planning/phases/114-oss-trust-governance/114-02-SUMMARY.md`.
- Task commit `c55f2e0` exists in git history.
- Created/modified files listed in this summary exist.
- Verification commands passed: `mix test test/install_smoke/package_metadata_test.exs` and `mix ci`.

---
*Phase: 114-oss-trust-governance*
*Completed: 2026-06-30*
