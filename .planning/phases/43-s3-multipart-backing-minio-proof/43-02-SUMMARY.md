---
phase: 43-s3-multipart-backing-minio-proof
plan: 02
subsystem: storage / s3-multipart
tags: [tus, s3-multipart, tail-buffer, etag-from-headers, capability, tdd-green]
requires:
  - "43-01: @callback upload_part_stream/5 + complete_part_stream/4 (OPTIONAL, :tus_upload-gated) + @type tus_part_state"
  - "43-01 RED specs: test/rindle/storage/s3_tus_test.exs + storage_adapter_test S3-cap assertion"
  - "Existing S3 adapter spine: bucket/1, request/2, normalize_parts/1, object_opts/1, handle_head_response header-normalize"
  - "Rindle.AV.TempRunDir.root_dir/0 (sweepable Rindle.tmp/ root, invariant 13)"
provides:
  - "Rindle.Storage.S3.upload_part_stream/5 (disk tail-buffer, one UploadPart per >= 5 MiB, ETag from response headers)"
  - "Rindle.Storage.S3.complete_part_stream/4 (final-tail flush + complete_multipart_upload/4)"
  - "S3.capabilities/0 advertising :tus_upload (TUS-07)"
  - "etag_from_headers/1 Pitfall-2 helper"
  - "Injectable ExAws request seam (request_module app-env) + offline test stub for deterministic TUS-06 unit math"
affects:
  - "Plan 04 (TusPlug dispatches PATCH -> adapter.upload_part_stream/5, final PATCH -> complete_part_stream/4)"
  - "Plan 03 (reaper tus branch calls the existing abort_multipart_upload/3 — unchanged by this plan)"
  - "Plan 05 (MinIO >= 1 GiB drop+resume proof exercises the live UploadPart round-trip these callbacks issue)"
tech-stack:
  added: []
  patterns:
    - "tusd S3-backend tail-buffer (accumulate < 5 MiB on disk, slice 5 MiB parts, flush remainder as final part)"
    - "ETag-from-response-HEADERS (upload_part has no body parser — Pitfall 2)"
    - "Injectable request seam via Application.get_env defaulting to ExAws (offline-deterministic unit test, real ExAws in prod/MinIO)"
key-files:
  created:
    - test/support/s3_multipart_request_stub.ex
  modified:
    - lib/rindle/storage/s3.ex
    - config/test.exs
decisions:
  - "complete_part_stream is arity 4 (key, temp_path, state, opts), NOT the arity 3 the 43-02 plan body's <interfaces> note stated — the actual storage.ex @optional_callbacks (complete_part_stream: 4) and the RED test S3.complete_part_stream(key, nil, mid, opts) both require /4 (Plan 01's locked contract)"
  - "Injectable ExAws request seam (request_module app-env, default ExAws) + a test-support stub so the un-tagged s3_tus_test slice path is deterministic offline (no MinIO); the stub delegates to real ExAws whenever RINDLE_MINIO_* is present"
  - "Tail file keyed on opts[:session_id] || key, Base.url_encode64'd, under opts[:root] || TempRunDir.root_dir()/tus/ — traversal-proof + per-test isolation via the :root override the unit tests pass"
metrics:
  duration: ~20min
  completed: 2026-05-23
  tasks: 2
  files: 3
---

# Phase 43 Plan 02: S3 Multipart Backing (upload_part_stream/5 + complete_part_stream/4) Summary

Implemented the genuinely-new code of Phase 43 — the bytes->S3-part translation behind tus PATCH dispatch. `Rindle.Storage.S3` now buffers each PATCH on disk under the sweepable `Rindle.tmp/`, emits one `UploadPart` per accumulated >= 5 MiB (ETag read from response HEADERS, never the body), flushes the sub-5-MiB tail as the final part on completion, and advertises `:tus_upload`. The Plan 01 RED tail-buffer specs (s3_tus_test 5/5) and the S3-capability assertion are now GREEN, with zero MinIO dependency for the unit math.

## What Shipped

- **`lib/rindle/storage/s3.ex` — `upload_part_stream/5` (TUS-06 core, Task 1)**
  - `@s3_min_part_size 5 * 1024 * 1024`; per-PATCH bytes streamed from `temp_path` onto `<root>/tus/<id>.tail` in 1 MiB chunks (`append_to_tail/2`) — the body never lands in a single binary on the heap (T-43-03 / RESEARCH anti-pattern line 282).
  - `drain_tail_parts/7`: while the tail file is >= 5 MiB, slices exactly one part (`read_leading_part/1` + `truncate_tail_head/2` rewrite to leftover), `UploadPart`s it, captures the server-issued ETag via `etag_from_headers/1`, and appends `%{part_number:, etag:}` with 1-based strictly-increasing `part_number` persisted in `state.parts` (+ `:next_part_number` counter).
  - Lazy `ensure_upload_id/4` initiates the multipart upload on the first PATCH and threads the same `UploadId` back through `state`; `bucket`/`aws_config` resolve via the existing opts-or-app-env fallback (Pitfall 4 — no new opts plumbing).
- **`lib/rindle/storage/s3.ex` — `complete_part_stream/4` + `:tus_upload` (TUS-06 completion + TUS-07, Task 2)**
  - `flush_final_tail/7` uploads any remaining tail as the final part (any size — the last part has no 5 MiB floor), then `complete_multipart_upload/4` with the full ordered `parts` list from `state` (reusing the existing `normalize_parts/1`, which accepts the persisted `%{part_number:, etag:}` map shape directly); best-effort `File.rm` tail cleanup.
  - `capabilities/0` now `[:presigned_put, :head, :signed_url, :multipart_upload, :tus_upload]` — capability honesty (D-09), advertised only now that both callbacks exist.
- **`lib/rindle/storage/s3.ex` — `etag_from_headers/1` (Pitfall-2 fix)** byte-identical lowercase-header normalize to `handle_head_response`, `Map.get("etag")`, `{:error, :missing_etag}` upstream when nil.
- **Injectable request seam + offline stub** — `request/2` now resolves the ExAws entrypoint through `Application.get_env(:rindle, S3)[:request_module]` (default `ExAws`). `test/support/s3_multipart_request_stub.ex` (NEW) fabricates well-formed responses (server-issued ETag in HEADERS) for the three multipart ops when no MinIO is configured, and DELEGATES to real `ExAws.request/2` whenever `RINDLE_MINIO_*` is present (CI MinIO lane + `@tag :minio` integration tests). Wired in `config/test.exs`. Production resolves the `ExAws` default — no network mock by default.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `complete_part_stream` arity: implemented /4, not the plan body's /3**
- **Found during:** Task 2 (and pre-empted in Task 1 design)
- **Issue:** The 43-02 plan body's `<interfaces>` note (line 94) and the Task 2 action both say `complete_part_stream(key, state, opts)` (arity 3). But the actual `lib/rindle/storage.ex` `@optional_callbacks` declares `complete_part_stream: 4`, the `@callback` is `(key, temp_path, state, opts)`, and the locked RED test calls `S3.complete_part_stream(key, nil, mid, opts)` (arity 4). Implementing /3 would fail `@impl true` (no matching callback) and leave the RED test undefined.
- **Fix:** Implemented `complete_part_stream/4` `(key, _temp_path, state, opts)` to match Plan 01's locked contract (the dominant /4 signal across frontmatter `must_haves`, `key_links`, storage.ex, and the test). `temp_path` is ignored — the bytes were already appended to the tail during the matching `upload_part_stream/5` call, so the residual lives in the tail file.
- **Files modified:** `lib/rindle/storage/s3.ex`
- **Commit:** 43b4470

**2. [Rule 3 - Blocking] s3_tus_test slice path cannot reach a real S3 offline → injectable request seam + stub**
- **Found during:** Task 1
- **Issue:** `test/rindle/storage/s3_tus_test.exs` is NOT `@tag :minio` (it runs in every lane) yet its slice/completion specs assert `{:ok, state}` with populated `parts` — which requires a successful `UploadPart`/`complete_multipart_upload`. With no MinIO and no `aws_config` in the test (only `bucket:` + `root:`), the real `ExAws.request` would hit AWS and fail, leaving the specs permanently RED off-CI. The plan's Task 1 action explicitly licenses this ("make the math reachable — match whatever shape s3_tus_test.exs expects") and 43-VALIDATION line 58 sanctions "a pure buffering helper OR fake `request`".
- **Fix:** Routed `request/2` through `request_module()` (app-env, default `ExAws`) and added `test/support/s3_multipart_request_stub.ex` returning deterministic synthetic responses for the three multipart ops when MinIO is absent, delegating to real `ExAws` when `RINDLE_MINIO_*` is set. Wired in `config/test.exs`. Keeps production + the MinIO proof lane on real ExAws while making the offline unit math deterministic.
- **Files modified:** `lib/rindle/storage/s3.ex`, `config/test.exs`; **created:** `test/support/s3_multipart_request_stub.ex`
- **Commit:** 8b639d7

**3. [Rule 3 - Blocking] `mix deps.get` in fresh worktree (lockfile fetch, not a package install)**
- **Found during:** baseline compile
- **Issue:** The worktree had no `deps/`; `mix compile` errored on missing dependencies.
- **Fix:** Ran `mix deps.get` (fetched from the existing `mix.lock` — no version resolution, no new packages, no `mix.exs` change). A lockfile fetch, NOT a package install, so the package-legitimacy checkpoint does not apply (same as 43-01 deviation 2).
- **Commit:** n/a (no source change; `deps/` is gitignored)

## Verification

- `mix test test/rindle/storage/s3_tus_test.exs` — 5/5 GREEN (sub-5-MiB PATCH -> 0 parts; >= 5 MiB -> exactly one part + buffered remainder; strictly-increasing 1-based part_numbers [1,2,3]; completion flushes the leftover tail).
- `mix test test/rindle/storage/storage_adapter_test.exs` — GREEN: `:tus_upload in S3.capabilities()`, `{upload_part_stream,5}` + `{complete_part_stream,4}` in `optional_callbacks`, `refute :tus_upload in GCS.capabilities()`.
- `mix test test/rindle/storage/` — 60 tests, 0 failures, 1 skipped (`@tag :minio`), 3 excluded.
- `mix compile --warnings-as-errors` — clean.
- Source assertions: `grep -c String.downcase` = 2 (>= 2); `grep -c @s3_min_part_size` = 6 (>= 1); `grep -c S3.upload_part` = 1 (>= 1); `grep -q :tus_upload` matches; `grep -c complete_part_stream` = 1 (>= 1).
- `git diff 22ec984 -- lib/rindle/upload/broker.ex` — empty (broker untouched, D-08 preserved).
- `git status --short priv/repo/migrations/` — no new migration (D-10 budget honored).

## Expected-RED (owned by sibling plans, NOT regressions)

Running the broader surface (`tus_plug_test.exs` + `upload_maintenance_test.exs`) shows 4 failures — all the explicitly-named downstream RED scaffolds authored in Plan 01, untouched by this plan:
- 2 in `tus_plug_test.exs` ("RED until Plan 04 — polymorphic adapter dispatch") — Plan 04 wires `TusPlug` to `adapter.upload_part_stream/5` + `complete_part_stream/4`.
- 2 in `upload_maintenance_test.exs` (tus reaper branch: abort via `abort_multipart_upload`, idempotent `not_found`) — Plan 03 adds the `resumable_protocol` reaper branch.

These are by-design cross-plan TDD RED tests (43-01 SUMMARY: "2 Plug dispatch + 2 reaper"), not introduced or worsened by Plan 02.

## Known Stubs

`test/support/s3_multipart_request_stub.ex` is a TEST-ONLY deterministic substitute for `ExAws.request/2`, gated to test env via `config/test.exs` and self-disabling (delegates to real ExAws) the moment `RINDLE_MINIO_*` is present. It is NOT shipped in the library (`elixirc_paths` includes `test/support` only in `:test`). The production `request_module` default is `ExAws`. No application-runtime stub exists.

## TDD Gate Compliance

This plan is the GREEN half of the cross-plan TDD cycle whose RED was authored in Plan 01. Both tasks are `tdd="true"`: the failing s3_tus_test specs (Plan 01 `test` commits) are turned GREEN here by `feat` commits (8b639d7 RED->GREEN for upload_part_stream's 4 specs; 43b4470 GREEN for the completion-flush spec + cap assertion). The RED gate lives in Plan 01 by design (interface-first phase); the GREEN `feat` gate is satisfied here. No new RED authored.

## Self-Check: PASSED

- Files: `lib/rindle/storage/s3.ex`, `test/support/s3_multipart_request_stub.ex`, `config/test.exs`, `.planning/phases/43-s3-multipart-backing-minio-proof/43-02-SUMMARY.md` — all FOUND.
- Commits: 8b639d7, 43b4470 — both FOUND in `git log 22ec984..HEAD`.
