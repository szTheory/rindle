---
phase: 09-install-release-confidence
plan: 03
subsystem: docs
tags: [docs, install, smoke, release, exunit]
requires:
  - phase: 09-install-release-confidence
    provides: built-artifact install smoke and explicit migration-path proof from Plan 09-01
provides:
  - layered README quickstart aligned to the smoke-proven presigned PUT path
  - canonical getting-started guide with explicit adopter Repo, default Oban, and Application.app_dir migration setup
  - executable ExUnit parity gate for install-path docs drift
affects: [release-confidence, docs, package-consumer, ci]
tech-stack:
  added: []
  patterns:
    - executable docs parity checks under test/install_smoke
    - layered README-to-guide handoff for narrow quickstart plus deep canonical setup
key-files:
  created:
    - .planning/phases/09-install-release-confidence/09-03-SUMMARY.md
    - test/install_smoke/docs_parity_test.exs
  modified:
    - README.md
    - guides/getting_started.md
key-decisions:
  - "Keep README narrow to the presigned PUT first-run path and push deeper operational detail into guides/getting_started.md."
  - "Enforce install-doc honesty with ExUnit assertions over lifecycle calls, Repo ownership, default Oban ownership, explicit migration setup, and multipart wording."
patterns-established:
  - "Docs drift gate: read public markdown directly in ExUnit and assert the smoke-proven install contract instead of relying on CI greps alone."
requirements-completed: [RELEASE-03]
duration: 19min
completed: 2026-04-28
---

# Phase 09 Plan 03: Install Release Confidence Summary

**README and getting-started docs now teach the exact smoke-proven presigned PUT install path, and RELEASE-03 is enforced by an executable ExUnit parity gate**

## Performance

- **Duration:** 19 min
- **Completed:** 2026-04-28T17:03:08Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Rewrote `README.md` into a layered quickstart with dependency setup, S3 HTTP-client guidance, adopter-owned Repo setup, default Oban ownership, explicit `Application.app_dir(:rindle, "priv/repo/migrations")` migration setup, and the canonical presigned PUT lifecycle.
- Tightened `guides/getting_started.md` into the canonical deep adopter path for the same first-run story, including the explicit host-app plus packaged-migration handoff and the Phase 9 decision not to add a public install Mix task.
- Added `test/install_smoke/docs_parity_test.exs` so docs drift now fails in ExUnit when lifecycle calls, Repo/Oban ownership, migration setup, README-to-guide handoff, or multipart posture diverge from the proven install path.

## Task Commits

Each task was committed atomically:

1. **Task 1: Rewrite README as the layered quickstart and tighten the deep guide** - `f8af66a` (docs)
2. **Task 2: Add an executable docs parity gate for install-path drift** - `0816b55` (test), `15d4b68` (feat)

## Files Created/Modified

- `README.md` - narrow install quickstart aligned to the smoke-proven presigned PUT path
- `guides/getting_started.md` - canonical deep guide covering adopter Repo, default Oban, and explicit migration-path ownership
- `test/install_smoke/docs_parity_test.exs` - executable parity gate for lifecycle calls, ownership wording, migration setup, and multipart honesty
- `.planning/phases/09-install-release-confidence/09-03-SUMMARY.md` - execution summary for this plan

## Decisions Made

- Kept multipart in the advanced lane and made presigned PUT the only first-run onboarding path in both public docs.
- Required the docs to use the explicit adopter-owned Repo and default Oban wording the runtime contract already depends on.
- Kept install migration setup as a docs snippet built on `Application.app_dir/2`, while leaving the checked-in automation private to the smoke harness.

## Deviations from Plan

None - plan executed as intended.

## Issues Encountered

- The first red test run failed on a delimiter mistake in the new test file; that was corrected before evaluating the docs contract.
- The initial multipart-negative regex was too broad and matched unrelated README text. The final assertion now targets actual multipart-as-default claims.

## TDD Gate Compliance

- RED commit present: `0816b55`
- GREEN commit present: `15d4b68`

## Self-Check: PASSED

- Verified the plan-owned files exist:
  `README.md`,
  `guides/getting_started.md`,
  `test/install_smoke/docs_parity_test.exs`,
  `.planning/phases/09-install-release-confidence/09-03-SUMMARY.md`
- Verified the task commit hashes exist:
  `f8af66a`, `0816b55`, `15d4b68`
- Verified the parity gate passes:
  `mix test test/install_smoke/docs_parity_test.exs`
- Stub scan across the touched files found no placeholder or TODO markers.

---
*Phase: 09-install-release-confidence*
*Completed: 2026-04-28*
