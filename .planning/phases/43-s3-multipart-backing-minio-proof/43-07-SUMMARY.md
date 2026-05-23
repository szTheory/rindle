---
phase: 43-s3-multipart-backing-minio-proof
plan: 07
subsystem: ops
tags: [tus, sweeper, cleanup, maintenance, disk-fill, dos-mitigation, gap-closure]

# Dependency graph
requires:
  - phase: 43-s3-multipart-backing-minio-proof
    provides: "tus backing files under <root>/tus/ (S3 tails at <root>/tus/<id>.tail, Local parts at <root>/tus/<id>.part)"
provides:
  - "Rindle.tmp/ sweeper now recurses into tus/ and ages out individual regular files (per-file mtime), ending unbounded tus/*.tail and tus/*.part accumulation"
  - "Per-file aging backstop behind explicit end-of-life cleanup (S3 best-effort File.rm, tus DELETE handler, reaper)"
affects: [43-08-reaper-wiring, tus-disk-hygiene, scheduled-maintenance-lane]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Special-case a named subdir (tus/) inside the directory-aging sweeper to switch from whole-dir aging to per-file aging where the dir mtime is perpetually refreshed on write"
    - "Confine deletion blast radius strictly to <root>/tus/ regular files; never widen to nested dirs, symlinks, or sibling top-level files"
    - "Per-file deletion mirrors existing dry_run semantics (count via orphan_count, delete via run_dirs_deleted) keeping the report struct shape stable"

key-files:
  created: []
  modified:
    - lib/rindle/ops/sweep_orphaned_temp_files.ex
    - test/rindle/ops/sweep_orphaned_temp_files_test.exs

key-decisions:
  - "Special-case `Path.basename(path) == \"tus\"` in process_run_dir/4 to recurse rather than rm_rf the whole dir — the tus/ dir mtime is bumped on every write so whole-dir aging never fires on an active system"
  - "Only `type: :regular` entries under tus/ are eligible; nested dirs and symlinks are left untouched (no widening of the deletion surface, threat T-43-07-02)"
  - "Reuse existing orphan_count (counts) + run_dirs_deleted (actual deletes) + errors counters instead of adding new report keys, keeping the @type report shape unchanged (AC5)"

patterns-established:
  - "Backstop cleanup: scheduled per-file aging under a single sweepable root closes the disk-fill leak that best-effort/explicit cleanup paths assumed (incorrectly) the sweeper already covered"

requirements-completed: [TUS-09]

# Metrics
duration: 4min
completed: 2026-05-23
---

# Phase 43 Plan 07: tus/ Sweeper Per-File Aging (CR-03) Summary

**The `Rindle.tmp/` sweeper now recurses into the shared `tus/` subdirectory and ages out individual regular files by their own mtime — ending the unbounded accumulation of `tus/*.tail` and `tus/*.part` backing files that the directory-only sweeper silently skipped (the `tus/` dir mtime is perpetually fresh, so it was never reaped as a whole).**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-05-23T12:19:38Z
- **Completed:** 2026-05-23T12:22:34Z
- **Tasks:** 1 (`tdd="true"`, RED → GREEN)
- **Files modified:** 2

## Accomplishments

- **CR-03 closed:** Extended `process_run_dir/4` so that when an entry is the `tus` directory specifically, the sweeper recurses (`sweep_tus_dir/4`) and ages out individual regular files (`age_tus_file/4` → `delete_tus_file/3`) whose own mtime is past the threshold. Whole-directory aging stays untouched for every non-`tus` run dir.
- **Disk-fill leak ended:** The `tus/` directory mtime is refreshed on every tail/part write, so on any active system it never crosses the age threshold and was never `rm_rf`'d — the regular files inside accumulated without bound. Per-file aging is the cleanup backstop the S3 `complete_part_stream` best-effort `File.rm`, the tus DELETE handler, and the reaper all (incorrectly) relied on.
- **Blast radius confined:** Deletion is strictly limited to regular files under `<root>/tus/`. Non-regular entries (nested dirs, symlinks) are left untouched, and the directory-mtime path still never deletes top-level run-dir regular files. A containment test asserts a loose aged file placed directly under `<root>` (a sibling of `tus/`) survives the sweep.
- **Report shape preserved:** Counters reuse the existing `orphan_count` (every eligible file, dry-run or not), `run_dirs_deleted` (actual deletions), and `errors`. The `@type report` map keys (`run_dirs_scanned`, `orphan_count`, `run_dirs_deleted`, `errors`) are unchanged, so the Mix task / worker / telemetry readers keep working.
- **5 new regression tests** (one `describe` block), each RED against the directory-only sweeper then GREEN after the recursion was added.

## Task Commits

Task executed atomically (TDD: test → feat):

1. **Task 1 (RED): failing tests for tus/ regular-file aging** - `ceca01f` (test)
2. **Task 1 (GREEN): recurse into tus/ + age out regular files** - `d2a1fd8` (feat)

_No REFACTOR commit needed — the implementation was minimal and clean on first GREEN._

## Files Created/Modified

- `lib/rindle/ops/sweep_orphaned_temp_files.ex` - Added the `## tus/ regular-file aging (CR-03 safety net)` moduledoc section; special-cased `Path.basename(path) == "tus"` in `process_run_dir/4`; added `sweep_tus_dir/4` (recurse + per-file reduce), `age_tus_file/4` (regular-file mtime check), and `delete_tus_file/3` (dry-run-aware `File.rm`, mirroring `delete_run_dir/3`). Reuses `mtime_to_unix/1`.
- `test/rindle/ops/sweep_orphaned_temp_files_test.exs` - Added a `describe "tus/ regular-file aging (CR-03 safety net)"` block with 5 tests (aged `.tail` removed; fresh `.tail` preserved; aged `.part` removed; dry-run counts but does not delete; containment — file outside `tus/` untouched) plus a `build_tus_file!/3` helper that backdates the file mtime and **refreshes the `tus/` dir mtime to current** so the test proves per-file recursion (not whole-dir aging) is what reaps the file.

## Decisions Made

- **Special-case `tus` by basename, not by config:** The shared `tus/` subdir is the only place backing files live as individual regular entries; matching on `Path.basename(path) == "tus"` keeps the change surgical and leaves all other run-dir aging behaviour identical.
- **Regular files only:** `age_tus_file/4` matches `%File.Stat{type: :regular}` exclusively. Nested directories or symlinks under `tus/` are intentionally skipped so the safety net cannot escalate into a recursive directory delete (threat T-43-07-02 mitigation).
- **No new report keys:** Aged files count toward the existing `orphan_count`/`run_dirs_deleted` rather than introducing a separate `files_deleted` key, satisfying AC5 (report shape unchanged) and keeping the Mix task / telemetry formatters untouched.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Plan said "create a new test file" but `test/rindle/ops/sweep_orphaned_temp_files_test.exs` already existed**
- **Found during:** Task 1 (RED setup)
- **Issue:** The plan's `<action>` instructed creating a new `sweep_orphaned_temp_files_test.exs` mirroring `s3_tus_test.exs` setup with a plain tmp dir + `on_exit rm_rf`. That file already exists (8 tests) and uses the project's established convention: `use Rindle.DataCase` + `Application.put_env(:rindle, :tmp_dir, ...)` + `TempRunDir.root_dir()`. Creating a second file with the same module name would collide.
- **Fix:** Extended the existing file with a new `describe` block (5 tests) reusing its established setup (per-test `<tmp>/rindle-sweep-orphans-N/` root via the app env override, `on_exit` cleanup). Backdated mtimes via `File.touch!(path, now - age_sec)` (no sleeping), exactly per the plan's behavior intent. Added a `build_tus_file!/3` helper alongside the existing `build_run_dir!/3`.
- **Files modified:** `test/rindle/ops/sweep_orphaned_temp_files_test.exs`
- **Commit:** `ceca01f` (RED), `d2a1fd8` (GREEN)

**2. [Rule 1 - Bug] Containment test wrote to `<root>` before it existed**
- **Found during:** Task 1 (GREEN verification)
- **Issue:** The containment test wrote a loose sibling file directly under `<root>` (`Rindle.tmp/`), but in that test path the root dir is only created lazily by `build_tus_file!`'s `mkdir_p` of `tus/`. Writing the loose file first raised `File.Error: no such file or directory`.
- **Fix:** Added `File.mkdir_p!(root_dir)` before writing the loose file in the containment test.
- **Files modified:** `test/rindle/ops/sweep_orphaned_temp_files_test.exs`
- **Commit:** `d2a1fd8`

### Verification-flag note

The plan's `<verify>`/AC referenced `mix test ... -x`. This project's Mix (Elixir 1.19.5) does not accept `-x` (it errored listing valid options). Ran `mix test test/rindle/ops/sweep_orphaned_temp_files_test.exs` (no `-x`) instead — the verification intent (suite green) is fully satisfied. Not a deviation in behaviour, only in the exact flag.

## Threat Model Coverage

- **T-43-07-01 (DoS, unbounded tus/*.tail / *.part accumulation):** mitigated — per-file aging under `tus/` reaps aged backing files, closing the disk-fill leak (CR-03).
- **T-43-07-02 (Tampering, sweeper deletion blast radius):** mitigated — recursion deletes ONLY `type: :regular` files under `<root>/tus/`; the containment test asserts a file outside `tus/` is untouched; non-regular entries are skipped.
- **T-43-07-03 (Tampering, mtime-based false delete):** accepted as planned — a file is deleted only when its own mtime is past the operator-configured threshold (default 4h); in-flight tails are written continuously so their mtime stays fresh within an upload window.

No new threat surface introduced beyond the plan's threat register.

## Verification

- `mix test test/rindle/ops/sweep_orphaned_temp_files_test.exs` → 13 tests, 0 failures (8 existing + 5 new).
- Cross-suite regression: `mix test sweep + upload_maintenance + orphan_reaper` → 51 tests, 0 failures.
- RED proof: against the directory-only code, the aged-`.tail`/`.part` deletion and dry-run-count tests FAILED (regular files silently skipped); PASS after the recursion.
- `grep -n "tus" lib/rindle/ops/sweep_orphaned_temp_files.ex` → sweeper now special-cases / recurses into the `tus` subdir (`Path.basename(path) == "tus"` → `sweep_tus_dir/4`).
- `mix format --check-formatted` on both changed files → exit 0.
- Report `@type` keys (`run_dirs_scanned`, `orphan_count`, `run_dirs_deleted`, `errors`) unchanged.

## Next Phase Readiness

- **43-08 (reaper wiring):** The sweeper backstop is now real; explicit end-of-life cleanup remains the primary path, with the sweeper as the documented safety net (no longer a false claim).
- No change to the tail-buffer slice/accumulate math, the S3 adapter, or the TUS-06 contract; this plan owned only `lib/rindle/ops/sweep_orphaned_temp_files.ex` + its test (no file-ownership conflict with 43-06's S3 changes).

## Self-Check: PASSED

- Files: `lib/rindle/ops/sweep_orphaned_temp_files.ex`, `test/rindle/ops/sweep_orphaned_temp_files_test.exs`, `43-07-SUMMARY.md` all present.
- Commits: `ceca01f`, `d2a1fd8` both in git history.
