---
phase: 42-tus-protocol-edge-bare-plug
plan: 01
subsystem: storage
tags: [tus, capability, ecto-migration, plug, resumable-upload, local-storage, broker]

# Dependency graph
requires:
  - phase: v1.7 (Phases 37-41) GCS Resumable Adapter
    provides: resumable-session substrate (broker resumable entrypoints, "resuming" FSM lane, media_upload_sessions session_uri/last_known_offset/expires_at, redacting Inspect, ResumableTelemetry, UploadMaintenance reaper)
provides:
  - ":tus_upload capability atom registered in both type unions + @known, advertised by Local only"
  - "additive resumable_protocol column on media_upload_sessions + covering index; schema field + cast"
  - "Broker.initiate_tus_upload/2 sibling entrypoint stamping signed/resumable/resumable_protocol:tus sessions"
  - "Local tmp-append (tus_append/3) + atomic-rename (tus_complete/3) backing helpers + tus_part_path/2"
  - "unit test proving capability honesty, broker stamping, file-append growth, atomic-rename size, migration round-trip"
affects: [42-02 TusPlug edge, 42-03 TusPlug PATCH/completion, 43 S3 multipart backing, 44 auth-hardening/docs/telemetry]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Capability honesty as a hard gate: require_upload/2 returns {:error, {:upload_unsupported, cap}}; broker propagates via with, Plug edge (42-02) wraps into init/1 raise"
    - "tus session reuses the v1.7 resumable lane (upload_strategy: resumable) with one resumable_protocol discriminator column — no new table, no new FSM states"
    - "Local tmp-append + atomic same-filesystem File.rename; :exdev surfaces as error, never a silent copy+delete fallback (Pitfall 5)"
    - "Compensation-on-persist-failure: best-effort File.rm_rf of the tus tmp part, log-and-:ok (mirrors resumable compensation)"

key-files:
  created:
    - priv/repo/migrations/20260522120000_add_resumable_protocol_to_media_upload_sessions.exs
    - test/rindle/storage/local_tus_test.exs
  modified:
    - lib/rindle/storage/capabilities.ex
    - lib/rindle/storage.ex
    - lib/rindle/storage/local.ex
    - lib/rindle/domain/media_upload_session.ex
    - lib/rindle/upload/broker.ex
    - test/rindle/storage/storage_adapter_test.exs

key-decisions:
  - "D-09: exactly one :tus_upload atom added to Capabilities.@type/@known + Storage.@type union; Local advertises it, GCS/S3 do not (no silent downgrade)"
  - "D-10: exactly one additive migration — nullable resumable_protocol (nil=legacy, no backfill) + covering index [:upload_strategy, :resumable_protocol, :state]; last_known_offset IS the tus Upload-Offset"
  - "D-11: initiate_tus_upload/2 reuses persist + compensation pattern; sets resumable_protocol: tus, keeps upload_strategy: resumable and state: signed"
  - "D-02: initiate_tus_upload/2 makes NO adapter.initiate_* call (Local has no multipart); S3-multipart initiation is Phase 43"
  - "Pitfall 7: tus sessions persist in signed so the completion edge signed -> verifying stays legal (never park in resuming)"

patterns-established:
  - "tus backing seam: Local.tus_part_path/2 (root/1-anchored, UUID-only path, traversal-proof), tus_append/3 (append-open + IO.binwrite per chunk), tus_complete/3 (atomic File.rename to final key)"
  - "broker tus entrypoint: capability-gated, no remote initiation, persist-then-emit-start, returns {:ok, %{session: session}}"

requirements-completed: [TUS-01, TUS-02, TUS-05]

# Metrics
duration: 10min
completed: 2026-05-22
---

# Phase 42 Plan 01: tus Protocol Edge Foundation Summary

**The non-HTTP tus foundation: a `:tus_upload` capability (Local-only), one additive `resumable_protocol` column + covering index, `Broker.initiate_tus_upload/2` stamping signed/resumable tus sessions with no S3-multipart initiation, and Local tmp-append + atomic-rename backing helpers — all proven by a unit test.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-05-22T14:08:21Z
- **Completed:** 2026-05-22T14:18:59Z
- **Tasks:** 4
- **Files modified:** 8 (2 created, 6 modified)

## Accomplishments

- Registered exactly one `:tus_upload` capability atom across `Capabilities.@type capability`, `Capabilities.@known`, and `Storage.@type capability`; `Local.capabilities/0` advertises it, GCS/S3 do not (capability honesty, no silent downgrade — D-09).
- Added the single additive migration: a nullable `resumable_protocol` column (nil = legacy, no backfill) plus a covering index `[:upload_strategy, :resumable_protocol, :state]` with an explicit name to avoid PostgreSQL's 63-char auto-name truncation; wired the schema field + cast (not `validate_required`) and left the redacting `Inspect` untouched (D-10).
- Added `Broker.initiate_tus_upload/2` as a sibling to `initiate_resumable_session/2`: it gates on `require_upload(adapter, :tus_upload)`, persists via `persist_tus_session/3` with `state: "signed"`, `upload_strategy: "resumable"`, `resumable_protocol: "tus"`, `last_known_offset: 0`, emits `[:rindle, :upload, :start]`, and makes NO `adapter.initiate_*` call (Local has no multipart — D-02/D-11). `compensate_failed_tus_persist/3` best-effort removes the tus tmp part on persist failure.
- Added Local backing helpers `tus_part_path/2` (root-anchored, UUID-only, traversal-proof), `tus_append/3` (append-open + `IO.binwrite` per chunk), and `tus_complete/3` (atomic same-filesystem `File.rename` to the final key; `:exdev` surfaces as an error, never a silent copy+delete — Pitfall 5).
- Wrote `test/rindle/storage/local_tus_test.exs` (7 tests) proving capability honesty, broker stamping + fail-closed, file-append growth, atomic-rename final size, and the `resumable_protocol` round-trip (tus persisted; nil for legacy rows).

## Task Commits

Each task was committed atomically:

1. **Task 1: Register :tus_upload capability, advertise from Local only** — `9118878` (feat)
2. **Task 2: Additive resumable_protocol migration, schema field, cast** — `5771ece` (feat)
3. **Task 3: Broker.initiate_tus_upload/2 + Local tmp-append/atomic-rename helpers** — `ef14dfa` (feat)
4. **Task 4: Backing + capability + broker-entrypoint unit test** — `5dcfa1c` (test)

**Plan metadata:** committed separately (docs: complete plan).

_Note: Task 4 is `tdd="true"`. The foundation (Tasks 1-3) already existed when its proving test was written, so it landed as a single `test(...)` commit rather than a RED→GREEN pair. The test was run and confirmed green (7/7) against the existing implementation — see TDD Gate Compliance below._

## Files Created/Modified

- `lib/rindle/storage/capabilities.ex` — `:tus_upload` added to `@type capability` and `@known`.
- `lib/rindle/storage.ex` — `:tus_upload` added to the `@type capability` union (kept in sync).
- `lib/rindle/storage/local.ex` — `capabilities/0` advertises `:tus_upload`; new `tus_part_path/2`, `tus_append/3`, `tus_complete/3` helpers.
- `lib/rindle/domain/media_upload_session.ex` — `field :resumable_protocol, :string` + cast entry (not validate_required); redacting `Inspect` untouched.
- `priv/repo/migrations/20260522120000_add_resumable_protocol_to_media_upload_sessions.exs` — additive column + named covering index.
- `lib/rindle/upload/broker.ex` — `initiate_tus_upload/2` + `initiate_tus_result` type + `persist_tus_session/3` + `compensate_failed_tus_persist/3`; added `Local` to the storage alias.
- `test/rindle/storage/local_tus_test.exs` — the foundation proof test (NEW).
- `test/rindle/storage/storage_adapter_test.exs` — capability-honesty assertions updated for `:tus_upload`.

## Decisions Made

- Gave the new covering index an explicit name (`media_upload_sessions_resumable_protocol_idx`) instead of relying on Ecto's auto-generated name, which PostgreSQL truncates past 63 chars — the auto-name `media_upload_sessions_upload_strategy_resumable_protocol_state_index` was being silently truncated. Explicit naming keeps create/drop deterministic and matches the resumable analog migration's `name:` convention.
- Dropped the unused `adapter` parameter from `persist_tus_session/3` — for the Local sink there is no remote multipart to abort, so the helper signature stays honest (`compensate_failed_tus_persist/3` cleans the Local tmp part directly).
- `compensate_failed_tus_persist/3` keys the tmp-part cleanup off the seed `asset_id` (the only server-issued identifier available before the session row exists), mirroring the resumable compensation's log-and-`:ok` discipline.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Updated capability-honesty assertions broken by the new atom**
- **Found during:** Task 4 (running the storage suite after Task 1)
- **Issue:** `test/rindle/storage/storage_adapter_test.exs` asserted `Local.capabilities() == [:local, :presigned_put]` (exact list), which Task 1's `:tus_upload` addition correctly broke.
- **Fix:** Updated the exact-list assertion to `[:local, :presigned_put, :tus_upload]` and added `assert :tus_upload in known` to the known-capabilities test.
- **Files modified:** test/rindle/storage/storage_adapter_test.exs
- **Verification:** `mix test test/rindle/storage/` — 54 pass, 0 failures.
- **Committed in:** `5dcfa1c` (Task 4 commit)

**2. [Rule 3 - Blocking] Explicit index name to avoid >63-char truncation**
- **Found during:** Task 2 (`mix ecto.migrate`)
- **Issue:** The auto-generated index name exceeded PostgreSQL's 63-char identifier limit and was silently truncated, producing a fragile/nondeterministic name that could collide and complicate rollback.
- **Fix:** Added `name: :media_upload_sessions_resumable_protocol_idx` to the `create index` call.
- **Files modified:** priv/repo/migrations/20260522120000_add_resumable_protocol_to_media_upload_sessions.exs
- **Verification:** `mix ecto.migrate` / `mix ecto.rollback` apply and reverse cleanly with no truncation warning.
- **Committed in:** `5771ece` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking)
**Impact on plan:** Both are correctness/robustness fixes directly caused by the planned changes. No scope creep — the public contract is exactly what the plan specified.

## Issues Encountered

- A formatter/linter touched `lib/rindle/upload/broker.ex` mid-edit (one Edit had to re-Read first); resolved by re-reading and re-applying. No content impact.
- The full `mix test` run surfaces environmental, pre-existing failures unrelated to this plan: `Rindle.Processor.AVTest` (`:epipe` FFmpeg subprocess flakiness, nondeterministic count across runs), `Rindle.Ops.RuntimeChecksTest` / `Rindle.DoctorTest` (the `doctor.ffmpeg_runtime` probe is non-pass in this dev env), and `Rindle.Upload.LifecycleIntegrationTest` MinIO tests (`:econnrefused` to `localhost:9000` — no MinIO daemon). None reference the tus/capability/migration/broker surface changed here. Logged to `42-tus-protocol-edge-bare-plug/deferred-items.md` per the SCOPE BOUNDARY rule; not fixed.

## TDD Gate Compliance

Task 4 is `tdd="true"`. Because Tasks 1-3 built the foundation first (the plan's intent — Task 4 is the per-task sampling/proving target for Wave 1), the test was written against an existing implementation and committed as a single `test(...)` commit (`5dcfa1c`) rather than a RED→GREEN pair. The test was executed and is green (7/7) before commit. No unexpected-pass-during-RED fail-fast condition applies, since this is an explicit prove-the-foundation test, not a new-feature RED gate. Plan-level type is `execute` (not `tdd`), so the plan-level RED/GREEN gate sequence is not mandated.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The downstream `TusPlug` (Plans 42-02/42-03) now receives concrete contracts: the `:tus_upload` capability gate, the `resumable_protocol` column, `Broker.initiate_tus_upload/2`, and the Local `tus_append/3` / `tus_complete/3` backing helpers — no scavenger hunt.
- Verification gates green: `mix compile --warnings-as-errors` clean; `mix test test/rindle/storage/local_tus_test.exs` 7/7; `mix test test/rindle/storage/` 54 pass / 1 skip / 0 failures; migration additive + reversible (`mix ecto.migrate` / `mix ecto.rollback`).
- The session_uri (signed tus URL) minting/storage is intentionally deferred to the Plug edge (42-02), which owns `secret_key_base` — the broker returns the unsigned session. POLISH-01 (the D-13 selective Mux code-review fixes) is part of Phase 42 scope but was NOT in this plan's task list; it remains for a later 42 plan.

---
*Phase: 42-tus-protocol-edge-bare-plug*
*Completed: 2026-05-22*
