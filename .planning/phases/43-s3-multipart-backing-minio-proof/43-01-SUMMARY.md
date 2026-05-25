---
phase: 43-s3-multipart-backing-minio-proof
plan: 01
subsystem: storage / upload
tags: [tus, s3-multipart, behaviour-contract, tdd-red, capability]
requires:
  - "Rindle.Storage behaviour (existing optional-callback block)"
  - "Phase 42 substrate: TusPlug, Broker.initiate_tus_upload/2, UploadMaintenance, MediaUploadSession multipart columns"
provides:
  - "@callback upload_part_stream/5 (OPTIONAL, :tus_upload-gated, temp-path variant)"
  - "@callback complete_part_stream/4 (OPTIONAL, symmetric completion)"
  - "@type tus_part_state (offset + S3 upload_id/parts bookkeeping)"
  - "Wave-0 RED test scaffolds for TUS-06/07/08/09 (Nyquist Dimension 8)"
affects:
  - "Plan 02 (S3 impl turns s3_tus_test.exs + S3-cap assertion GREEN)"
  - "Plan 03 (reaper tus branch turns the 2 abort_multipart_upload tests GREEN)"
  - "Plan 04 (Plug dispatch turns the 2 upload_part_stream/complete_part_stream tests GREEN)"
  - "Plan 05 (fills the @tag :minio >= 1 GiB drop+resume + zero-leak body)"
tech-stack:
  added: []
  patterns:
    - "OPTIONAL @callback gated by a capability atom (mirrors the four resumable callbacks)"
    - "temp-path streaming variant (Plug drains PATCH body to disk first, then dispatches)"
    - "RED-side TDD scaffolds that compile but fail loudly (UndefinedFunctionError / unmet Mox expectation / == mismatch)"
key-files:
  created:
    - test/rindle/storage/s3_tus_test.exs
    - test/rindle/upload/tus_s3_integration_test.exs
  modified:
    - lib/rindle/storage.ex
    - test/rindle/storage/storage_adapter_test.exs
    - test/rindle/ops/upload_maintenance_test.exs
    - test/rindle/upload/tus_plug_test.exs
decisions:
  - "complete_part_stream is arity 4 (key, temp_path, state, opts), resolving the plan's inline-3-arg vs frontmatter-/4 contradiction in favor of the dominant /4 signal"
  - "complete_part_stream's temp_path is String.t() | nil — the final PATCH residual handle, symmetric with upload_part_stream/5"
  - "RED scaffolds use real assertions (no @tag :skip) so downstream plans turn them GREEN unchanged"
metrics:
  duration: ~25min
  completed: 2026-05-23
  tasks: 3
  files: 6
---

# Phase 43 Plan 01: S3 Multipart Backing Wave-0 Foundation Summary

Declared the `:tus_upload`-gated OPTIONAL behaviour contract (`upload_part_stream/5` temp-path variant + symmetric `complete_part_stream/4`) plus `@type tus_part_state`, and wrote all five Wave-0 test scaffolds (2 NEW + 3 extended) so Plans 02-05 have automated verifies pointing at files that already exist (Nyquist Dimension 8).

## What Shipped

- **`lib/rindle/storage.ex`** — `@type tus_part_state` (offset + optional S3 `upload_id`/`parts`), `@callback upload_part_stream/5` (temp-path variant, documented as the tusd PATCH-body→temp-file→UploadPart pattern), `@callback complete_part_stream/4` (symmetric completion, S3 flushes the tail as the final part / Local atomic rename, then converges into the unchanged `verify_completion/2`). Both appended to `@optional_callbacks` so GCS (which never advertises `:tus_upload`) still compiles. Compiles `--warnings-as-errors`; `:tus_upload` was already in the `@type capability` union (no type edit needed).
- **`test/rindle/storage/s3_tus_test.exs` (NEW, unit, async)** — TUS-06 tail-buffer math: sub-5-MiB PATCH produces zero parts, crossing 5 MiB slices exactly one part, strictly-increasing 1-based part_numbers, completion flushes the leftover tail. Drives `S3.upload_part_stream/5` + `complete_part_stream/4` directly (RED via `UndefinedFunctionError` until Plan 02).
- **`test/rindle/storage/storage_adapter_test.exs` (extended)** — TUS-07: new optional-callbacks test asserts `{upload_part_stream,5}` + `{complete_part_stream,4}` in `optional_callbacks` (GREEN now); S3 capability list now expects `:tus_upload` (RED until Plan 02); `refute :tus_upload in GCS.capabilities()`.
- **`test/rindle/upload/tus_s3_integration_test.exs` (NEW, `@tag :minio`)** — TUS-09 headline proof scaffold: POST → 600 MiB PATCH (assert offset + persisted `multipart_upload_id`) → drop → HEAD authoritative offset → resume → final PATCH → `completed`/`validating`/1 GiB byte_size; then a second abandoned session → reaper → `ExAws.S3.list_multipart_uploads` returns NO entry for the abandoned key (ZERO LEAK). Excluded by default, compiles cleanly. Plan 05 fills the live dispatch.
- **`test/rindle/ops/upload_maintenance_test.exs` (extended)** — TUS-09 reaper branch: tus session aborts via `abort_multipart_upload` not `cancel_resumable_upload` (RED until Plan 03), idempotent `{:error, :not_found}` expiry (RED), `gcs_native` + legacy-`nil` sessions keep the existing `cancel_resumable_upload` path (GREEN — proves no regression).
- **`test/rindle/upload/tus_plug_test.exs` (extended)** — TUS-06/08 polymorphic dispatch: a PATCH calls `adapter.upload_part_stream/5` and the final PATCH calls `adapter.complete_part_stream/4` then `verify_completion` (RED until Plan 04; Mox-backed `MockTusProfile`).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `complete_part_stream` arity contradiction in the plan**
- **Found during:** Task 1
- **Issue:** The plan's inline action gave `complete_part_stream(key, state, opts)` (arity 3) but the frontmatter `must_haves`, objective, `@optional_callbacks` entry (`complete_part_stream: 4`), `key_links`, and the storage_adapter_test assertion (`{:complete_part_stream, 4}`) all require arity 4. `mix compile` failed with `unknown callback complete_part_stream/4 given as optional callback` because the 3-arg `@callback` did not match the `: 4` optional entry.
- **Fix:** Adopted the dominant `/4` signal: `complete_part_stream(key, temp_path, state, opts)` where `temp_path :: String.t() | nil` is the final PATCH's residual handle, symmetric with `upload_part_stream/5`. Updated the `@doc` to describe the temp_path argument.
- **Files modified:** `lib/rindle/storage.ex`
- **Commit:** cbeeb1f

**2. [Rule 3 - Blocking] `mix deps.get` required in fresh worktree**
- **Found during:** Task 1 verification
- **Issue:** The worktree had no `deps/`; `mix compile` errored on missing dependencies.
- **Fix:** Ran `mix deps.get` (fetched from the existing `mix.lock` — no version resolution, no new packages added). This is a lockfile fetch, NOT a package install, so the package-legitimacy checkpoint does not apply.
- **Commit:** n/a (no source change)

**3. [Rule 3 - Blocking] Profile DSL rejects arithmetic `max_bytes` at compile time**
- **Found during:** Task 3 (MinIO scaffold)
- **Issue:** `max_bytes: 2 * 1024 * 1024 * 1024` failed `NimbleOptions.validate!` (the Profile DSL validates at compile time and requires a literal positive integer).
- **Fix:** Used the literal `2_147_483_648` for `max_bytes`; kept a `@two_gib` module attr for the runtime `TusPlug.init` `max_size`.
- **Files modified:** `test/rindle/upload/tus_s3_integration_test.exs`
- **Commit:** 5e31fc9

### Note (not a deviation)

The plan's Task 1 acceptance criterion `grep -c 'def capabilities, do: \[:gcs' lib/rindle/storage/gcs.ex` does not match the actual GCS source (it advertises `[:signed_url, :head, :resumable_upload, :resumable_upload_session]`). The substantive requirement — GCS does NOT advertise `:tus_upload` and still compiles without implementing the optional callbacks — is satisfied and verified (`refute :tus_upload in GCS.capabilities()`).

## Verification

- `mix compile --warnings-as-errors` — clean (both callbacks OPTIONAL; GCS unaffected).
- `grep -c upload_part_stream lib/rindle/storage.ex` = 5 (>= 2); `grep -c complete_part_stream` = 2 (>= 2).
- `{upload_part_stream,5}` and `{complete_part_stream,4}` confirmed in `Rindle.Storage.behaviour_info(:optional_callbacks)`.
- All five test files load without CompileError under `mix test --exclude minio`; 10 failures are all the designed RED assertions for Plans 02-05 (5 tail-buffer + 1 S3-cap + 2 Plug dispatch + 2 reaper). gcs_native + legacy-nil reaper tests pass GREEN (no regression).
- `tus_s3_integration_test.exs` is `@tag :minio` (excluded by default — `1 excluded, 0 run`), compiles; `grep -c list_multipart_uploads` = 4 (>= 1).
- `git diff lib/rindle/upload/broker.ex` — empty (broker untouched, D-08 honored).

## Known Stubs

None that block the plan's goal. The five RED assertions are intentional Wave-0 scaffolds (the RED side of the cross-plan TDD cycle), each turned GREEN by a named downstream plan (02/03/04/05). The `@tag :minio` integration test body is a contract scaffold that Plan 05 completes; it is excluded from the default run and documented as such.

## TDD Gate Compliance

This plan's `tdd="true"` tasks are the **RED authoring half** of a cross-plan cycle: Task 1 lands the contract (`feat` — the callbacks must exist for the tests to compile and reference), Tasks 2-3 write the failing specs (`test` commits). The matching GREEN `feat` commits live in Plans 02-05 by design (interface-first plan). No GREEN gate is expected within Plan 01.

## Self-Check: PASSED

- Files: `lib/rindle/storage.ex`, `test/rindle/storage/s3_tus_test.exs`, `test/rindle/upload/tus_s3_integration_test.exs`, `.planning/phases/43-s3-multipart-backing-minio-proof/43-01-SUMMARY.md` — all FOUND.
- Commits: cbeeb1f, b36f418, 5e31fc9, 29f5e0a — all FOUND.
