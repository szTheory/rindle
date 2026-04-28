---
phase: 10-publish-readiness
plan: 02
subsystem: release
tags: [release, hex, exdoc, github-actions, exunit]
requires:
  - phase: 10-publish-readiness
    provides: maintainer release runbook and release-doc parity gate from Plan 10-01
provides:
  - executable package metadata and tarball-content proof against the unpacked Hex artifact
  - shared release preflight script covering package build, release-doc parity, install smoke, and docs warnings
  - release workflow wiring that stays preflight-only while preserving the dry-run publish check
affects: [publish-readiness, release-workflow, hex-release, docs]
tech-stack:
  added: []
  patterns:
    - shared release preflight script invoked both locally and from GitHub Actions
    - package assertions read as-built metadata from a freshly unpacked artifact instead of source-only config
key-files:
  created:
    - test/install_smoke/package_metadata_test.exs
    - scripts/release_preflight.sh
    - .planning/milestones/v1.2-phases/10-publish-readiness/10-02-SUMMARY.md
  modified:
    - .github/workflows/release.yml
    - lib/rindle/live_view.ex
key-decisions:
  - "Keep Phase 10 preflight-only by routing release checks through scripts/release_preflight.sh and leaving live Hex credentials for Phase 11."
  - "Build a fresh temporary unpacked package inside the metadata test so assertions prove the shipped artifact, not a stale repo-local unpack."
patterns-established:
  - "Release preflight pattern: mix hex.build --unpack -> metadata gate -> release-doc parity gate -> install smoke -> mix docs --warnings-as-errors."
requirements-completed: [RELEASE-05]
duration: 8min
completed: 2026-04-28
---

# Phase 10 Plan 02: Publish Readiness Summary

**Shared release preflight now proves the shipped Hex artifact contents, preserves the preflight-only release boundary, and blocks docs warnings before any live publish wiring exists**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-28T19:34:30Z
- **Completed:** 2026-04-28T19:42:52Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added `test/install_smoke/package_metadata_test.exs` to build a fresh unpacked artifact, assert shipped metadata and required packaged files, reject prohibited repo-only paths, and verify the shared preflight command ordering.
- Added `scripts/release_preflight.sh` as the single Phase 10 preflight entrypoint for `mix hex.build --unpack`, package metadata assertions, release-doc parity, Phase 9 install smoke reuse, and `mix docs --warnings-as-errors`.
- Rewired `.github/workflows/release.yml` to use the shared preflight gate and updated `lib/rindle/live_view.ex` docs so ExDoc warnings no longer hide behind a non-public LiveView function reference.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add metadata and tarball-content proof for the unpacked package** - `23cce46` (test), `ba655b2` (feat)
2. **Task 2: Wire workflow preflight and clear the docs-warning blocker** - `e98cbfd` (fix)

## Files Created/Modified

- `test/install_smoke/package_metadata_test.exs` - executable metadata, tarball-content, and preflight-order assertions against a fresh unpacked package
- `scripts/release_preflight.sh` - shared release preflight command used locally and by the release workflow
- `.github/workflows/release.yml` - release lane now runs the shared preflight before the existing dry-run publish check
- `lib/rindle/live_view.ex` - public-facing docs wording no longer references hidden LiveView upload docs
- `.planning/milestones/v1.2-phases/10-publish-readiness/10-02-SUMMARY.md` - execution summary for this plan

## Decisions Made

- Kept the release workflow preflight-only and preserved the existing dry-run publish step after preflight instead of introducing any live `HEX_API_KEY` secret wiring.
- Used a fresh temporary unpack target in the metadata test so `RELEASE-05` is proven from current source output even if `rindle-0.1.0-dev/` already exists in the repo.
- Centralized the package, docs, and install-smoke gates behind `scripts/release_preflight.sh` to prevent workflow drift between local and CI release checks.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The first full docs verification still failed because `.github/workflows/release.yml` contained the exact `${{ secrets.HEX_API_KEY }}` token inside a comment. The comment was rewritten to preserve the Phase 11 guidance without broadening credentials in Phase 10.

## TDD Gate Compliance

- RED commit present: `23cce46`
- GREEN commit present: `ba655b2`

## Self-Check: PASSED

- Verified the plan-owned files exist:
  `test/install_smoke/package_metadata_test.exs`,
  `scripts/release_preflight.sh`,
  `.github/workflows/release.yml`,
  `lib/rindle/live_view.ex`,
  `.planning/milestones/v1.2-phases/10-publish-readiness/10-02-SUMMARY.md`
- Verified the task commit hashes exist:
  `23cce46`, `ba655b2`, `e98cbfd`
- Verified the plan commands pass:
  `mix test test/install_smoke/package_metadata_test.exs`,
  `mix docs --warnings-as-errors`,
  `bash scripts/release_preflight.sh`
- Stub scan across the touched runtime files found no placeholder or TODO markers.

---
*Phase: 10-publish-readiness*
*Completed: 2026-04-28*
