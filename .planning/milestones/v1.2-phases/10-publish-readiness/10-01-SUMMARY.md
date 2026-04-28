---
phase: 10-publish-readiness
plan: 01
subsystem: docs
tags: [docs, release, hex, exdoc, exunit]
requires:
  - phase: 09-install-release-confidence
    provides: executable docs parity patterns and adopter-doc boundary discipline
provides:
  - maintainer-only first-publish runbook for Hex versioning, auth, and ownership
  - ExDoc extras wiring for the release guide
  - executable parity coverage for release-doc contract drift
affects: [publish-readiness, docs, hex-release, maintainer-operations]
tech-stack:
  added: []
  patterns:
    - maintainer-only release guidance kept out of adopter onboarding docs
    - executable markdown parity checks for release policy drift
key-files:
  created:
    - guides/release_publish.md
    - test/install_smoke/release_docs_parity_test.exs
    - .planning/milestones/v1.2-phases/10-publish-readiness/10-01-SUMMARY.md
  modified:
    - mix.exs
    - guides/operations.md
key-decisions:
  - "Keep first-publish guidance in guides/release_publish.md and only cross-link it from maintainer-facing operations docs."
  - "Use ExUnit markdown assertions to gate the 0.1.0 versioning sequence, owner commands, and adopter-doc separation contract."
patterns-established:
  - "Release-doc parity gate: read maintainer and adopter markdown directly in ExUnit and assert the publish contract plus boundary rules."
requirements-completed: [RELEASE-04]
duration: 3min
completed: 2026-04-28
---

# Phase 10 Plan 01: Publish Readiness Summary

**Maintainer-facing Hex publish guidance now ships with the docs, states the `0.1.0` first-release and personal-first owner model explicitly, and is guarded by an executable parity test**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-28T19:34:08Z
- **Completed:** 2026-04-28T19:36:39Z
- **Tasks:** 1
- **Files modified:** 4

## Accomplishments

- Added `guides/release_publish.md` with explicit sections for versioning, Hex auth check, first-publish owner model, package metadata review, preflight commands, and post-publish follow-up.
- Wired the release guide into `mix.exs` ExDoc extras and added a maintainer-facing cross-link from `guides/operations.md` without moving release-owner or auth steps into adopter onboarding docs.
- Added `test/install_smoke/release_docs_parity_test.exs` to enforce the `0.1.0` release sequence, `mix hex.user` / `mix hex.owner` command contract, metadata checklist wording, and adopter-doc contamination guard.

## Task Commits

Each task was committed atomically:

1. **Task 1: Author the maintainer release runbook, wire it into ExDoc, and add the parity gate** - `cd30492` (test), `0005e5b` (feat)

## Files Created/Modified

- `guides/release_publish.md` - maintainer-only first-publish runbook for versioning, auth, owner follow-up, and metadata review
- `mix.exs` - ExDoc extras now include the release guide
- `guides/operations.md` - maintainer-facing cross-link to the release runbook
- `test/install_smoke/release_docs_parity_test.exs` - executable parity gate for release-doc contract drift
- `.planning/milestones/v1.2-phases/10-publish-readiness/10-01-SUMMARY.md` - execution summary for this plan

## Decisions Made

- Kept the release contract out of `README.md` and `guides/getting_started.md` so adopter onboarding stays separate from maintainer publish policy.
- Recorded the first public cut as `@version "0.1.0-dev"` -> `0.1.0` -> `v0.1.0` -> publish -> next `-dev` on `main`, matching the plan's resolved release posture.
- Treated the release-doc boundary as executable policy by asserting both required maintainer commands and forbidden adopter-doc leakage in ExUnit.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The first GREEN run failed because the guide heading used `Package Metadata Review` instead of the exact `Package metadata review` phrase expected by the parity gate. The guide wording was tightened and the targeted test then passed.

## TDD Gate Compliance

- RED commit present: `cd30492`
- GREEN commit present: `0005e5b`

## Self-Check: PASSED

- Verified the plan-owned files exist:
  `guides/release_publish.md`,
  `mix.exs`,
  `guides/operations.md`,
  `test/install_smoke/release_docs_parity_test.exs`,
  `.planning/milestones/v1.2-phases/10-publish-readiness/10-01-SUMMARY.md`
- Verified the task commit hashes exist:
  `cd30492`, `0005e5b`
- Verified the plan command passes:
  `mix test test/install_smoke/release_docs_parity_test.exs`
- Stub scan across the touched files found no placeholder or TODO markers.

---
*Phase: 10-publish-readiness*
*Completed: 2026-04-28*
