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
  - Release public verification for the Hex owner-derived maintainer signal
  - Package metadata smoke coverage for order-independent link assertions and release verifier wiring
affects: [phase-114, phase-115, release-publish, hex-package]

tech-stack:
  added: []
  patterns:
    - "Install-smoke metadata checks assert individual generated metadata tuples instead of whole-list link equality."
    - "Hex owner/maintainer display is verified from the public Hex API after publish, not from unsupported mix.exs package keys."

key-files:
  created:
    - .planning/phases/114-oss-trust-governance/114-02-SUMMARY.md
    - scripts/verify_hex_package_metadata.sh
  modified:
    - .github/workflows/release.yml
    - guides/release_publish.md
    - mix.exs
    - test/install_smoke/package_metadata_test.exs

key-decisions:
  - "Use @source_url interpolation for the Changelog link and a latest-version HexDocs URL for Docs."
  - "Verify package links from unpacked Hex metadata with whitespace-compacted tuple checks so pretty-printed long URLs do not make the test brittle."
  - "Do not use mix.exs :maintainers; Hex owner/maintainer display is owner-derived and checked from the public Hex API during release verification."

patterns-established:
  - "Package metadata tests should assert individual metadata entries, not exact whole-map ordering."

requirements-completed: [META-01, META-02]

duration: 4 min
completed: 2026-06-30
status: complete
---

# Phase 114 Plan 02: Hex Package Metadata Summary

**Hex package metadata now exposes GitHub, Changelog, and HexDocs links, and release public verification checks the Hex owner-derived maintainer signal.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-06-30T14:53:03Z
- **Completed:** 2026-06-30T14:57:10Z
- **Tasks:** 1
- **Files modified:** 6

## Accomplishments

- Added `Changelog` and `Docs` entries to `package.links` while preserving the existing `GitHub` link.
- Replaced the GitHub-only whole-list metadata assertion with order-independent link tuple checks.
- Added `scripts/verify_hex_package_metadata.sh` and wired release public verification to check GitHub/Changelog/Docs links plus the `sztheory` Hex owner after publish.
- Left `files:`, `@required_paths`, and `@prohibited_paths` unchanged.

## Task Commits

1. **Task 1: mix.exs links + maintainers, paired with meta-test update** - `c55f2e0` (feat)
2. **Post-review fix: owner-derived maintainer verification** - pending commit

## Files Created/Modified

- `mix.exs` - Added `Changelog` and `Docs` package links.
- `test/install_smoke/package_metadata_test.exs` - Added order-independent generated metadata checks for all three links and assertions that release public verification checks Hex API links/owner.
- `scripts/verify_hex_package_metadata.sh` - Checks the public Hex package/release APIs for package links, release existence, owner, and publisher.
- `.github/workflows/release.yml` - Runs the public metadata verifier after Hex indexing and before HexDocs/artifact smoke.
- `guides/release_publish.md` - Documents the owner-derived maintainer verification path.
- `.planning/phases/114-oss-trust-governance/114-02-SUMMARY.md` - Captures plan outcome and verification.

## Checks Run

- `mix test test/install_smoke/package_metadata_test.exs` - PASS, 16 tests, 0 failures.
- `mix ci` - PASS, 3 doctests and 1222 tests, 0 failures, 4 skipped, 77 excluded.
- Acceptance greps - PASS for `GitHub`, `Changelog`, `Docs`, and release public metadata verifier wiring.
- Path-list unchanged check - PASS; no diff touched `files:`, `@required_paths`, or `@prohibited_paths`.

## Decisions Made

- Used `@source_url` interpolation for the Changelog URL, matching the plan and avoiding duplicated owner/repo literals in `mix.exs`.
- Kept generated metadata assertions order-independent by asserting each link tuple after whitespace compaction.
- Corrected the META-02 implementation after code review: Hex does not serialize `:maintainers` from `mix.exs`; package owner/maintainer display is verified from the public Hex API after publish.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Made link metadata assertions robust to Hex pretty-printing**
- **Found during:** Task 1
- **Issue:** The unpacked `hex_metadata.config` split the long Changelog tuple across lines, so a direct substring assertion failed despite correct generated metadata.
- **Fix:** Added `compact_metadata = String.replace(metadata, ~r/\s+/, "")` for tuple-presence assertions.
- **Files modified:** `test/install_smoke/package_metadata_test.exs`
- **Verification:** `mix test test/install_smoke/package_metadata_test.exs` and `mix ci` pass.
- **Committed in:** `c55f2e0`

**2. [Rule 1 - Bug] Replaced unsupported maintainer package key with public owner verification**
- **Found during:** Task 1
- **Issue:** The plan expected a top-level serialized `{<<"maintainers">>, ...}` tuple in unpacked Hex metadata, but Hex 2.5 did not emit that tuple for this Mix package.
- **Fix:** Removed the unsupported `maintainers:` key from `mix.exs`; added `scripts/verify_hex_package_metadata.sh`; wired release public verification to check the public Hex API for `sztheory` in `owners[]` and for GitHub/Changelog/Docs links.
- **Files modified:** `mix.exs`, `test/install_smoke/package_metadata_test.exs`, `.github/workflows/release.yml`, `guides/release_publish.md`, `scripts/verify_hex_package_metadata.sh`
- **Verification:** `mix test test/install_smoke/package_metadata_test.exs` passes; `mix ci` re-run after this fix.
- **Committed in:** pending commit

---

**Total deviations:** 2 auto-fixed (Rule 1).
**Impact on plan:** META-01 stays a local package metadata check. META-02 is corrected to the actual Hex model: maintainer display is owner-derived and verified from the public API after publish.

## Issues Encountered

The first two smoke-test runs exposed formatting and serialization assumptions in the planned assertions. Code review then caught that `maintainers:` is not a published Hex metadata key; the fix moved META-02 to public owner verification.

`mix ci` also printed the repo's existing dependency advisory list and an expired Hex authentication-session warning, but the command completed successfully.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None. Stub-pattern scan hits in `test/install_smoke/package_metadata_test.exs` were existing test literals / guards (`dryrun-placeholder`, `package_root != ""`), not product or UI stubs.

## Next Phase Readiness

Phase 114 metadata scope is complete. Phase 115 can build on the package page trust signals and move to versioning / README positioning after `mix ci`, code review, and phase verification pass.

## Self-Check: PASSED

- Summary file exists at `.planning/phases/114-oss-trust-governance/114-02-SUMMARY.md`.
- Task commit `c55f2e0` exists in git history.
- Created/modified files listed in this summary exist.
- Verification commands passed: `mix test test/install_smoke/package_metadata_test.exs`; `mix ci` re-run after the post-review fix.

---
*Phase: 114-oss-trust-governance*
*Completed: 2026-06-30*
