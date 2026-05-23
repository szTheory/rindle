---
phase: 43-s3-multipart-backing-minio-proof
plan: 05
subsystem: testing
tags: [minio, s3, multipart, tus, ex_aws, oban, integration-test]

# Dependency graph
requires:
  - phase: 43-02
    provides: live S3.upload_part_stream/5 + complete_part_stream/4 tail-buffer callbacks
  - phase: 43-03
    provides: reaper resumable_protocol="tus" branch (abort_multipart_upload)
  - phase: 43-04
    provides: TusPlug PATCH dispatch into the polymorphic adapter tus sink
provides:
  - ">= 1 GiB drop+resume + zero-leak MinIO proof wired against the live S3 spine (tus_s3_integration_test.exs)"
  - "@tag :minio S3 upload_part_stream/complete_part_stream per-callback round-trip (s3_test.exs)"
  - "executable proof of the T-43-cost-leak HIGH threat mitigation (list_multipart_uploads-empty after reaper)"
affects: [43-verify-work, phase-44-ci-proof, v1.8-milestone-audit]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "MinIO-backed @tag :minio integration tests excluded from the default suite; gated to the CI integration/minio lane"
    - "lazy synthetic byte stream (Stream.cycle/take) so a >= 1 GiB body never materializes as one binary in the test process"
    - "per-callback tus sink driving (upload_part_stream/5 -> complete_part_stream/4) with :root + :session_id tail-buffer isolation"

key-files:
  created: []
  modified:
    - test/rindle/upload/tus_s3_integration_test.exs
    - test/rindle/storage/s3_test.exs

key-decisions:
  - "Used the completion contract complete_part_stream/4 (key, temp_path, state, opts) — the established Plans 01/02/04 signature; the plan body's stale /3 note was treated as obsolete."
  - "assert_enqueued targets Rindle.Repo (Config.repo default in test) where verify_completion's Oban.insert lands the PromoteAsset job under testing: :manual — finds the enqueued job rather than racing inline execution."
  - "s3_test callback round-trip isolates the server-mediated tail buffer with explicit :root + :session_id opts so the per-test tail file never collides with the global Rindle.tmp/ root."

patterns-established:
  - "Convergence proof pattern: assert the verify_completion EFFECTS (session completed, asset validating, byte_size, PromoteAsset enqueued) instead of touching the frozen Broker function (D-08)."
  - "Zero-leak proof pattern: abandon a session, expire it, run the reaper, then assert ExAws.S3.list_multipart_uploads returns no entry for the abandoned key."

requirements-completed: [TUS-06, TUS-08, TUS-09]

# Metrics
duration: 9min
completed: 2026-05-23
---

# Phase 43 Plan 05: MinIO >= 1 GiB Drop+Resume + Zero-Leak Proof Summary

**Wired the headline >= 1 GiB tus-over-S3-multipart drop+resume + zero-leak (`list_multipart_uploads`-empty) MinIO proof against the live spine, plus a focused per-callback `upload_part_stream`/`complete_part_stream` round-trip — both `@tag :minio`, excluded from the default suite, pending the CI integration-lane human-verify gate.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-05-23T10:06:54Z
- **Completed:** 2026-05-23T10:16:15Z
- **Tasks:** 2 of 3 executed autonomously; Task 3 is a blocking human-verify checkpoint (see below)
- **Files modified:** 2 (both test-only)

## Accomplishments

- **Task 1 (TUS-06/08/09):** Filled the Plan-01 scaffold in `tus_s3_integration_test.exs` against the LIVE S3 dispatch. Added the two assertions the scaffold was missing for the plan's 7-step contract: (a) `multipart_parts["parts"]` has >= 1 persisted entry after the ~600 MiB PATCH (real UploadParts crossed the wire before the drop), and (b) `assert_enqueued(worker: Rindle.Workers.PromoteAsset, args: %{asset_id: asset.id})` proving the final PATCH converged into the UNCHANGED `Broker.verify_completion/2` lane (D-08). The existing scaffold already wired the POST -> 600 MiB PATCH -> drop -> HEAD -> resume -> completion-effects -> abandon -> expire -> reaper -> zero-leak `list_multipart_uploads` flow.
- **Task 2 (TUS-06):** Added a `@tag :minio` test to `s3_test.exs` driving the NEW `S3.upload_part_stream/5` + `S3.complete_part_stream/4` callbacks directly (server-mediated, NOT presigned): a > 5 MiB head chunk slices part 1 with a real ETag; a sub-5-MiB tail buffers and flushes as the final part on completion; head size == total streamed bytes. Covers the sub-5-MiB tail-as-last-part case the plan called out.
- Verified the D-08 review gate: `git diff` of `lib/rindle/upload/broker.ex` against the base is empty (byte-for-byte unchanged).

## Task Commits

Each task was committed atomically:

1. **Task 1: Wire the >= 1 GiB drop+resume + zero-leak MinIO proof** - `209fc5a` (test)
2. **Task 2: Add the @tag :minio S3 upload_part_stream-via-callback round-trip** - `0bb118b` (test)
3. **Task 3: Confirm the MinIO proof green in CI** - PENDING (checkpoint:human-verify, blocking — see below)

_Note: Both tasks are TDD-`test`-typed; they add `@tag :minio` tests that are RED-by-design without a MinIO server (excluded from the default suite). GREEN is established in the CI integration/minio lane — that is Task 3's gate._

## Files Created/Modified

- `test/rindle/upload/tus_s3_integration_test.exs` - Added the `multipart_parts >= 1 entry` assertion (step 2) and the `assert_enqueued PromoteAsset` convergence assertion (step 5) to the >= 1 GiB drop+resume + zero-leak proof.
- `test/rindle/storage/s3_test.exs` - Added the `@tag :minio` `upload_part_stream`/`complete_part_stream` callback round-trip (5 MiB+ head part + sub-5-MiB tail flush).

## Decisions Made

- **Completion contract `/4`:** Used `complete_part_stream/4` (key, temp_path, state, opts) per the live module and the autonomous-scope directive; the plan body's stale `/3` reference was treated as obsolete.
- **`assert_enqueued` over inline-run race:** Oban runs `testing: :manual` (test_helper start_link), so the PromoteAsset job inserted by `verify_completion/2`'s Multi is enqueued, not executed — `assert_enqueued` finds it. The job lands in `Rindle.Repo` (= `Config.repo()` default in test), which is the repo the test's `use Oban.Testing` and `Rindle.DataCase` sandbox target.
- **Tail-buffer isolation:** The s3_test callback round-trip passes explicit `:root` + `:session_id` opts so the server-mediated tail file is per-test and never collides with the global `Rindle.tmp/` root or sibling runs.

## Deviations from Plan

None requiring a deviation rule. The integration scaffold was largely pre-filled by Plan 01; Plan 05's autonomous work was completing the two contractually-required assertions (multipart_parts non-empty; PromoteAsset enqueue) that the acceptance criteria mandate, plus authoring the s3_test callback round-trip. No source (`lib/`) changes were made — `broker.ex` is byte-for-byte unchanged (D-08).

## Issues Encountered

- **Out-of-scope flaky AV/ffmpeg failures under full-suite load:** The final full `mix test` run surfaced 1–4 non-deterministic failures in `Rindle.Processor.FfmpegTest` / `Rindle.Processor.AVTest` (different tests each run). These are pre-existing resource-contention flakes in the ffmpeg-bound processor suite, NOT caused by this plan: Plan 05's only changes are two `@tag :minio` test files that are excluded from the default suite and cannot execute, and the processor tests pass 0 failures when run in isolation. Logged to `.planning/phases/43-s3-multipart-backing-minio-proof/deferred-items.md` per the SCOPE BOUNDARY rule; not fixed.

## Verification Performed (local, MinIO-free)

- `mix compile --warnings-as-errors` — clean (dev and `MIX_ENV=test`).
- `mix test test/rindle/storage/ test/rindle/upload/ test/rindle/ops/` — **266 tests, 0 failures** (4 skipped, 13 `@tag :minio`/integration excluded). The new tests are correctly excluded; the suite is unbroken.
- D-08 review gate: `git diff <base> -- lib/rindle/upload/broker.ex` is empty (verify_completion/2 unchanged).
- Source-grep acceptance assertions all hold:
  - `tus_s3_integration_test.exs`: `list_multipart_uploads` x4 (>=1), 1-GiB floor x1 (>=1), `assert_enqueued|PromoteAsset` x2 (>=1).
  - `s3_test.exs`: `upload_part_stream` x3 (>=1).

## Pending Human-Verify Checkpoint (Task 3, BLOCKING)

**Type:** checkpoint:human-verify (gate="blocking")
**Status:** awaiting CI confirmation — NOT resolvable in this sandbox.

The >= 1 GiB MinIO proof is `@tag :minio` and **cannot run locally here** (no MinIO server in the sandbox; the >= 1 GiB transfer + real S3 multipart round-trip is the load-bearing proof). It runs in the CI integration/minio lane. Confirm it green there before `/gsd:verify-work`:

1. Push the branch / trigger the integration workflow; open the CI run for the integration/minio lane (`.github/workflows/ci.yml` integration job with the MinIO service).
2. Verify `mix test ... --include integration --include minio` is GREEN — specifically that `tus_s3_integration_test.exs` passed (the >= 1 GiB drop+resume completed and the zero-leak `list_multipart_uploads`-empty assertion held) and the `s3_test.exs` MinIO tests passed.
3. (Optional local) With Docker: `docker run -p 9000:9000 -p 9001:9001 minio/minio server /data` + `mc mb local/rindle-test`, export `RINDLE_MINIO_*`, then `mix test test/rindle/upload/tus_s3_integration_test.exs --include minio` (expect green within the 600s timeout).

**Resume signal:** Type "approved" once the CI integration/minio lane is green, or describe the failure (which assertion, which step of the 7-step flow).

This gate proves T-43-cost-leak (HIGH) is actually mitigated — no orphaned multipart upload remains after the reaper aborts an abandoned session.

## User Setup Required

None - no external service configuration required for the autonomous tasks. The Task-3 CI gate uses the existing CI MinIO service; local-optional Docker MinIO steps are documented above.

## Next Phase Readiness

- The full Phase-43 spine is now end-to-end-provable: Plug PATCH -> S3 multipart -> verify lane -> reaper, plus the per-callback round-trip. All non-MinIO unit/integration surface is green.
- **Blocker before `/gsd:verify-work`:** the Task-3 human-verify gate (CI integration/minio lane GREEN). Control returned to the orchestrator with this gate pending — not blocked-waiting, not fabricated.

---
*Phase: 43-s3-multipart-backing-minio-proof*
*Completed: 2026-05-23*
