---
phase: 09-install-release-confidence
plan: 01
subsystem: testing
tags: [elixir, phoenix, oban, minio, smoke, release]
requires:
  - phase: 06-adopter-runtime-ownership
    provides: adopter-owned Repo and default Oban runtime contract
  - phase: 08-storage-capability-confidence
    provides: MinIO-backed direct-upload capability proof used by the smoke lane
provides:
  - generated-app package-consumer smoke proof from a built Rindle artifact
  - explicit host plus Rindle migration runner using Application.app_dir/2
  - shared shell entrypoint for local, CI, and release install smoke execution
affects: [release-confidence, ci, release, docs]
tech-stack:
  added: []
  patterns:
    - generated Phoenix consumer apps as outside-in package smoke harnesses
    - explicit package-root handoff from shell runner to ExUnit helper
key-files:
  created:
    - .planning/phases/09-install-release-confidence/09-01-SUMMARY.md
    - scripts/install_smoke.sh
  modified:
    - test/install_smoke/generated_app_smoke_test.exs
    - test/install_smoke/support/generated_app_helper.ex
key-decisions:
  - "Run the real consumer proof inside a generated Phoenix app's own ExUnit test so adopter Repo and Oban test helpers stay honest."
  - "Resolve Rindle migrations via Application.app_dir(:rindle, \"priv/repo/migrations\") and execute host plus library paths explicitly before smoke tests."
  - "Let the shell runner pass an unpacked package root into the helper so packaging work is single-sourced instead of rebuilt implicitly."
patterns-established:
  - "Generated consumer smoke: build or receive an unpacked package, generate a fresh Phoenix app, patch only adopter-owned seams, and run an in-app ExUnit lifecycle proof."
  - "Explicit migration proof: use a generated migration script plus report file to assert host migration execution and Application.app_dir/2 resolution."
requirements-completed: [RELEASE-01]
duration: 18min
completed: 2026-04-28
---

# Phase 09 Plan 01: Install Smoke Summary

**Fresh `mix phx.new` install smoke for the built Rindle artifact, with explicit host plus library migrations and a shared runner for presigned PUT verification**

## Performance

- **Duration:** 18 min
- **Started:** 2026-04-28T16:26:14Z
- **Completed:** 2026-04-28T16:44:43Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Added a repo-level smoke lane that generates a real Phoenix adopter app, installs Rindle from an unpacked package artifact, and runs the canonical public upload lifecycle inside that app.
- Added a helper that patches only the adopter-owned seams, runs explicit host-app plus Rindle migrations, and reports migration-path resolution through `Application.app_dir/2`.
- Added `scripts/install_smoke.sh` as the shared entrypoint that builds and unpacks the package, passes the artifact path into the smoke helper, and runs the same MinIO-backed proof end to end.

## Task Commits

Each task was committed atomically:

1. **Task 1: Build the generated-app smoke harness and contract surface** - `b1a91d0` (test), `630af09` (feat)
2. **Task 2: Add the shared smoke runner used by local, CI, and release flows** - `b54f37e` (feat)

## Files Created/Modified
- `test/install_smoke/generated_app_smoke_test.exs` - repo-level contract for built-artifact install, explicit migrations, and canonical presigned PUT proof
- `test/install_smoke/support/generated_app_helper.ex` - generated-app workspace builder, patcher, migration runner, and smoke executor
- `scripts/install_smoke.sh` - shared shell entrypoint that builds and unpacks the package before invoking the smoke lane

## Decisions Made
- Used a generated app's own ExUnit test rather than only shell commands so the proof can exercise adopter-owned Repo wiring and default Oban test helpers without repo-local shortcuts.
- Kept the smoke lane narrow to the presigned PUT canonical path and excluded multipart from this package-consumer proof.
- Accepted an explicit package-root env seam between the script and the helper to avoid duplicated packaging logic.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Pinned the generated consumer app's Oban dependency to the repo-locked supported version**
- **Found during:** Task 1 and Task 2 verification
- **Issue:** A fresh generated app resolved `oban` to `2.22.x`, which required a newer Oban schema than the migrations currently shipped in the Rindle package, causing the consumer app to fail boot before the smoke path could run.
- **Fix:** Read the locked Oban version from `mix.lock` and inject a matching `~>` requirement into the generated app so the install smoke proves the supported default Oban path rather than an unintended newer contract.
- **Files modified:** `test/install_smoke/support/generated_app_helper.ex`
- **Verification:** `mix test test/install_smoke/generated_app_smoke_test.exs --include minio`; `bash scripts/install_smoke.sh`
- **Committed in:** `b54f37e`

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** The auto-fix was required to make the generated consumer app exercise the package's actual supported Oban contract. No scope creep beyond the smoke harness.

## Issues Encountered
- A stock Phoenix repo defaulted to integer migration keys, which broke Rindle's UUID-based migration set. The generated app test config now sets binary-id migration defaults before running host and library migrations.
- Boot verification initially ran before database creation and migration, which caused false negatives around Repo and Oban startup. The helper now boots only after explicit schema setup.

## User Setup Required

None - no external service configuration required beyond the existing MinIO/Postgres test environment already used by the repo.

## Next Phase Readiness
- The built-artifact consumer smoke path is ready for CI and release workflow reuse through `scripts/install_smoke.sh`.
- Phase 09 Plan 02 can wire this runner into workflow automation without changing the generated-app proof surface.

## Self-Check: PASSED

- Verified the created files exist:
  `test/install_smoke/generated_app_smoke_test.exs`,
  `test/install_smoke/support/generated_app_helper.ex`,
  `scripts/install_smoke.sh`,
  `.planning/phases/09-install-release-confidence/09-01-SUMMARY.md`
- Verified the task commit hashes exist:
  `b1a91d0`, `630af09`, `b54f37e`
- Stub scan across the touched files found no placeholder or TODO markers.

---
*Phase: 09-install-release-confidence*
*Completed: 2026-04-28*
