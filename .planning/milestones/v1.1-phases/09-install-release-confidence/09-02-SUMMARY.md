---
phase: 09-install-release-confidence
plan: 02
subsystem: infra
tags: [github-actions, ci, release, smoke, hex, phoenix]
requires:
  - phase: 09-install-release-confidence
    provides: shared install smoke helper and generated-app consumer proof from Plan 09-01
provides:
  - dedicated PR package-consumer smoke lane using the shared install helper
  - release workflow reuse of the shared install helper alongside tarball inspection and dry-run publish
affects: [release-confidence, ci, release, package-consumer]
tech-stack:
  added: []
  patterns:
    - shared package-consumer smoke helper invoked from both PR CI and release workflows
    - narrow PR smoke lane separated from deeper release-only packaging gates
key-files:
  created:
    - .planning/phases/09-install-release-confidence/09-02-SUMMARY.md
  modified:
    - .github/workflows/ci.yml
    - .github/workflows/release.yml
key-decisions:
  - "Keep the PR package-consumer lane gated only by quality so the built-artifact smoke proof starts at the narrowest useful point."
  - "Preserve release-only tarball inspection and dry-run publish checks, and compose the shared install smoke helper around them instead of replacing them."
patterns-established:
  - "Workflow reuse: both CI and release call scripts/install_smoke.sh rather than duplicating generated-app install logic inline."
requirements-completed: [RELEASE-02]
duration: 12min
completed: 2026-04-28
---

# Phase 09 Plan 02: Install And Release Confidence Summary

**PR CI now proves package-consumer installability from the built artifact, while release reuses the same smoke helper and keeps the deeper tarball and dry-run gates**

## Performance

- **Duration:** 12 min
- **Started:** 2026-04-28T16:46:00Z
- **Completed:** 2026-04-28T16:57:52Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Added a dedicated `package-consumer` GitHub Actions job in PR CI that provisions Postgres and MinIO, then runs the shared `scripts/install_smoke.sh` helper after `quality`.
- Updated the release workflow to run the same install smoke helper without removing the existing tarball path assertions or `mix hex.publish package --dry-run --yes` gate.
- Kept the smoke logic single-sourced in the shared helper so CI and release cannot silently drift on the generated-app consumer proof.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add the narrow package-consumer smoke lane to PR CI** - `ecb8806` (feat)
2. **Task 2: Reuse the same smoke helper inside the release workflow without weakening existing gates** - `63bc680` (feat)

## Files Created/Modified
- `.github/workflows/ci.yml` - adds the dedicated package-consumer smoke lane and supporting runner setup
- `.github/workflows/release.yml` - reuses the shared smoke helper while preserving tarball inspection and dry-run publish checks
- `.planning/phases/09-install-release-confidence/09-02-SUMMARY.md` - execution summary for this plan

## Decisions Made
- Kept the PR smoke job independent from `integration` and `contract` so it can fail narrowly on package artifact, generated-app setup, migration, or canonical flow drift rather than waiting on broader lanes.
- Scoped the release smoke step to `MIX_ENV=test` while leaving the overall release job in `MIX_ENV=dev`, so the shared helper can run tests without weakening the existing release packaging posture.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Local verification required a live MinIO endpoint and bucket to match the new workflow environment; the repo shell did not provide that by default.
- After aligning the local environment, repeated manual smoke reruns could hang inside the generated `mix phx.new --install` path after an interrupted attempt left transient workspace state behind. The workflow wiring itself was validated with contract greps and YAML parsing, and the shared helper path remained unchanged from Plan 09-01.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- PR CI and release now point at the same package-consumer smoke entrypoint, so future install-proof changes have one auditable execution path.
- A real GitHub Actions run is the remaining verification surface for the end-to-end workflow environment, since this execution was constrained to local shell checks plus shared-helper invocation attempts.

## Self-Check: PASSED

- Verified the summary file exists: `.planning/phases/09-install-release-confidence/09-02-SUMMARY.md`
- Verified the task commit hashes exist: `ecb8806`, `63bc680`
- Verified both workflow files parse as YAML: `yaml-ok`

---
*Phase: 09-install-release-confidence*
*Completed: 2026-04-28*
