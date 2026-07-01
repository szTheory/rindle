---
phase: 116-versioned-rindle-migration-module
plan: 06
subsystem: docs
tags: [migrations, docs-parity, generated-app-smoke, oban, install]

requires:
  - phase: 116-03
    provides: "RED docs parity and generated-app migration ownership proof"
  - phase: 116-04
    provides: "Public Rindle.Migration.up/1 and down/1 implementation"
  - phase: 116-05
    provides: "Doctor/runtime readiness for Rindle schema and host-owned Oban setup"
provides:
  - "README and Getting Started greenfield install docs for pinned Rindle.Migration host migrations"
  - "Newest-first Phase 116 upgrade note preserving legacy packaged migration compatibility"
  - "Operations/troubleshooting setup copy for host-owned Oban.Migration and oban_jobs"
  - "Generated Phoenix app image smoke proof for host-owned Oban plus Rindle migrations"
affects:
  - "README migration onboarding"
  - "Getting Started step 3"
  - "Upgrade guide Unreleased / Next note"
  - "Generated-app install smoke"

tech-stack:
  added: []
  patterns:
    - "Portable Markdown migration callouts with pinned Rindle.Migration snippets"
    - "Docs parity locks greenfield docs while allowing legacy package-path copy only in historical upgrade guidance"
    - "Generated-app smoke remains the package-consumer proof for documented install paths"

key-files:
  created:
    - .planning/phases/116-versioned-rindle-migration-module/116-06-SUMMARY.md
  modified:
    - README.md
    - guides/getting_started.md
    - guides/upgrading.md
    - guides/operations.md
    - guides/troubleshooting.md

key-decisions:
  - "Public install docs now teach normal host migrations: host-owned Oban.Migration for oban_jobs and pinned Rindle.Migration for Rindle-owned tables."
  - "Legacy package-directory migration replay remains documented only in the historical 0.1.3-and-earlier upgrade path."
  - "Troubleshooting treats missing oban_jobs as host-owned Oban setup, not as a Rindle migration responsibility."

patterns-established:
  - "Fresh install sections must reject Application.app_dir(:rindle, \"priv/repo/migrations\") and Ecto.Migrator.run as greenfield setup."
  - "Rollback copy for Rindle.Migration.down/1 must pair destructive language with backup guidance and oban_jobs non-ownership."

requirements-completed: [MIGRATE-01, MIGRATE-02]

duration: 10 min
completed: 2026-07-01
status: complete
---

# Phase 116 Plan 06: Migration Install Documentation Summary

**Pinned host migrations for Rindle-owned tables and host-owned Oban setup are now documented and proven through generated-app smoke.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-07-01T20:35:00Z
- **Completed:** 2026-07-01T20:45:31Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments

- Replaced README and Getting Started greenfield package-directory migration copy with normal host-app migrations using `Oban.Migration` and pinned `Rindle.Migration.up(version: 1)` / `down(version: 1)`.
- Added the Phase 116 newest-first upgrade note under `guides/upgrading.md` with `### Applies to`, `### What changed`, `### Upgrade steps`, and `### Verification`.
- Preserved the historical 0.1.3-and-earlier package-directory upgrade path while rejecting it in fresh install docs.
- Added operations/troubleshooting setup guidance that treats missing `oban_jobs` as host-owned Oban setup.
- Proved the documented path with focused Phase 116 tests and the generated Phoenix image install smoke.

## Task Commits

Each task was committed atomically:

1. **Task 1: Update README and getting-started migration workflow** - `44ef697` (docs)
2. **Task 2: Add newest-first upgrade note and align troubleshooting copy** - `af36ae2` (docs)
3. **Task 3: Run generated-app proof for the documented install path** - `ea22839` (test, empty verification commit)

## Files Created/Modified

- `README.md` - Teaches host-owned `Oban.Migration`, pinned `Rindle.Migration`, `mix ecto.migrate`, `mix rindle.doctor`, rollback backup guidance, and legacy compatibility.
- `guides/getting_started.md` - Reworks step 3 around host migration ownership, `Oban.Migration`, pinned `Rindle.Migration`, and doctor verification.
- `guides/upgrading.md` - Adds the Phase 116 migration note under `## Unreleased / Next` while preserving legacy package-directory replay only for historical upgrades.
- `guides/operations.md` - Points missing `oban_jobs` setup to host-owned `Oban.Migration`.
- `guides/troubleshooting.md` - Adds setup-failure guidance for host-owned `oban_jobs` and Rindle-owned table boundaries.
- `.planning/phases/116-versioned-rindle-migration-module/116-06-SUMMARY.md` - Records this plan execution.

## Decisions Made

- Public docs use pinned `version: 1` snippets even though the implementation can default to the latest supported version.
- The old `Application.app_dir(:rindle, "priv/repo/migrations")` / `Ecto.Migrator.run` path remains only in the scoped legacy upgrade section.
- Verification-only Task 3 uses an empty commit because the task intentionally changed no source files.

## Verification

- `mix test test/install_smoke/docs_parity_test.exs --seed 0` - PASS, 30 tests.
- `mix test test/install_smoke/docs_parity_test.exs test/rindle/migration_test.exs test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_status_test.exs test/rindle/doctor_test.exs test/rindle/runtime_status_task_test.exs --seed 0` - PASS, 111 tests.
- `bash scripts/install_smoke.sh image` - PASS, 3 generated-app smoke tests.
- `git diff -- .github/workflows/ci.yml .github/workflows/release.yml` - PASS, no release-train invariant changes.
- Source checks - PASS: README, Getting Started, and Unreleased upgrade sections include pinned migration snippets, host-owned `Oban.Migration` / `oban_jobs`, default `public`, `mix ecto.migrate`, `mix rindle.doctor`, backup/destructive rollback language, and no greenfield package-path runner.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Reset stale local MinIO state for generated-app smoke**
- **Found during:** Task 3 (Run generated-app proof for the documented install path)
- **Issue:** The first `bash scripts/install_smoke.sh image` attempt failed during local MinIO setup with `Resource requested is unwritable`; the embedded temp MinIO data directory was in a broken healing/unformatted state.
- **Fix:** Stopped the stale temp MinIO process, moved the broken temp data aside, started MinIO as a foreground verification session so it stayed alive under the executor harness, reran `scripts/ensure_minio.sh`, and reran the smoke command unchanged.
- **Files modified:** None.
- **Verification:** `bash scripts/install_smoke.sh image` passed with 3 tests, 0 failures.
- **Committed in:** `ea22839`

---

**Total deviations:** 1 auto-fixed (Rule 3).
**Impact on plan:** Verification environment repair only. No source scope or acceptance criteria changed.

## Issues Encountered

- A final parallel rerun of the docs parity and focused suite produced transient Postgres `too_many_connections` log noise, but both commands still passed. The earlier focused suite was also run sequentially and passed cleanly.

## Authentication Gates

None.

## Known Stubs

None. Stub-pattern scan found no TODO/FIXME/placeholder or hardcoded empty UI data in plan-modified files. The scan's only match was the existing `:unsupported_codec` troubleshooting row mentioning `ffmpeg -codecs`, which is not a stub.

## User Setup Required

None - no external service configuration required.

## Threat Flags

None - this plan changed documentation only and introduced no new runtime endpoints, auth paths, file access paths, or schema-changing code.

## Next Phase Readiness

Plan 116-07 can perform final phase closure on top of green docs parity, green focused migration/runtime tests, and a passing generated-app image smoke. The remaining Phase 116 surface is verification/closeout, not implementation.

## Self-Check: PASSED

- FOUND: `.planning/phases/116-versioned-rindle-migration-module/116-06-SUMMARY.md`
- FOUND: `README.md`
- FOUND: `guides/getting_started.md`
- FOUND: `guides/upgrading.md`
- FOUND: `guides/operations.md`
- FOUND: `guides/troubleshooting.md`
- FOUND: commit `44ef697`
- FOUND: commit `af36ae2`
- FOUND: commit `ea22839`

---
*Phase: 116-versioned-rindle-migration-module*
*Completed: 2026-07-01*
