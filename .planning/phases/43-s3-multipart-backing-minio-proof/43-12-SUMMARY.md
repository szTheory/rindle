---
phase: 43-s3-multipart-backing-minio-proof
plan: 12
subsystem: storage
tags: [s3, tus, multipart, minio, cross-node, data-integrity, security]

# Dependency graph
requires:
  - phase: 43-s3-multipart-backing-minio-proof
    provides: "guard_local_tail_present/2 cross-node tail guard (43-06) — the parts != [] mid-multipart signal this plan strengthens"
provides:
  - "CR-04 closed: pre-first-part cross-node resume (upload_id set, parts: [], offset > 0, tail absent) fails loudly with {:error, :tus_tail_missing} instead of silently corrupting the assembled object"
  - "Offset-aware guard signal: committed_part_bytes = length(parts) * @s3_min_part_size; tail required whenever offset > committed_part_bytes (OR'd with the existing parts != [] signal)"
  - "Unit proof of the pre-first-part hole (RED pre-fix) plus a same-node-tail-present no-regression test"
affects: [44-auth-hardening-dx-docs-telemetry-ci-proof, tus-s3-backing, minio-proof]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Offset-vs-committed-bytes signal: derive 'a tail is expected' from offset > length(parts) * @s3_min_part_size rather than only from a committed-part list — covers the buffered-but-not-yet-sliced window"

key-files:
  created: []
  modified:
    - lib/rindle/storage/s3.ex
    - test/rindle/storage/s3_tus_test.exs

key-decisions:
  - "CR-04 cross-node guard fires on (parts != [] OR offset > committed_part_bytes) where committed_part_bytes = length(parts) * @s3_min_part_size — closing the sub-5-MiB-first-chunk pre-first-part corruption window while preserving the brand-new FIRST PATCH happy path (offset 0) and the already-covered committed-part case"

patterns-established:
  - "Pattern: thread the resume base_offset into adapter guards so DB-implied buffered-bytes signals are available offline (no network needed to detect a misrouted cross-node resume)"

requirements-completed: [TUS-09, TUS-06]

# Metrics
duration: 2min
completed: 2026-05-23
---

# Phase 43 Plan 12: S3 Cross-Node Tail Guard (CR-04) Summary

**Strengthened the S3 tus cross-node tail guard to fire on `offset > committed_part_bytes`, closing the sub-5-MiB-first-chunk window where a misrouted resume silently corrupted the assembled object instead of failing loudly with `{:error, :tus_tail_missing}`.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-05-23T13:21:28Z
- **Completed:** 2026-05-23T13:23:02Z
- **Tasks:** 1 (TDD)
- **Files modified:** 2

## Accomplishments

- Closed **CR-04** completely: a cross-node resume in the pre-first-part window (`upload_id` set, `parts: []`, `offset > 0`, tail file absent on this node) now fails loudly with `{:error, :tus_tail_missing}` instead of opening a fresh empty tail and silently dropping the originating node's buffered bytes.
- Added the offset-aware signal: `committed_part_bytes = length(parts) * @s3_min_part_size`; the guard treats a resume as mid-multipart (tail required) when `upload_id` is set AND `(parts != [] OR offset > committed_part_bytes)`.
- Threaded `base_offset` from `upload_part_stream/5` into the guard (arity 2 -> 3) so the offset-vs-committed-bytes signal is available — the guard fires offline, no network needed.
- Preserved all prior coverage: the committed-part case (offset == committed_part_bytes at a sliced boundary) still fires via the `parts != []` clause; a brand-new FIRST PATCH (`offset == 0`) is never falsely guarded; the same-node pre-first-part resume (tail present) still returns `{:ok, ...}`.
- Kept the bare-atom error surface (`:tus_tail_missing` only — no tail path / session_uri disclosure across the adapter boundary) and reused `@s3_min_part_size` (no new hardcoded 5 MiB literal in the guard).

## Task Commits

Each task was committed atomically:

1. **Task 1: Strengthen guard_local_tail_present to fire on offset > committed_part_bytes (CR-04) + pre-first-part + same-node tests** - `90f70ea` (feat)

_TDD note: the RED step (new pre-first-part test failing with `{:ok, ...}` pre-fix) was verified before the implementation, then test + impl were committed together as the single gap-closure task._

**Plan metadata:** (final docs commit below)

## Files Created/Modified

- `lib/rindle/storage/s3.ex` - Threaded `base_offset` into `guard_local_tail_present/3`; added the `committed_part_bytes = length(parts) * @s3_min_part_size` signal so the guard fires when `offset > committed_part_bytes` (OR `parts != []`); refreshed the guard comment and the moduledoc "tus single-node constraint" section to describe the now-covered pre-first-part window.
- `test/rindle/storage/s3_tus_test.exs` - Added two tests to the "cross-node resume guard (CR-04)" describe: the pre-first-part hole (upload_id set, parts: [], offset > 0, tail absent -> `:tus_tail_missing`; RED pre-fix) and the same-node-tail-present no-regression case (tail present -> `{:ok, ...}`).

## Decisions Made

- CR-04 cross-node guard fires on `(parts != [] OR offset > committed_part_bytes)`. The offset signal closes the silent-corruption window where a first PATCH under 5 MiB sets `upload_id` and buffers a node-local tail but commits no part (`parts: []`, `committed_part_bytes == 0`, `offset > 0`). The `parts != []` clause is kept as an OR so the freshly-sliced-boundary case (offset exactly == committed_part_bytes) stays covered. `offset == 0` keeps the brand-new FIRST PATCH unguarded (no false positive).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. The RED test failed exactly as the plan predicted (returning `{:ok, %{offset: 4194304, parts: [], upload_id: "uid-existing", ...}}` — the silent-corruption path), and the strengthened guard turned it GREEN with no regressions across the storage suite.

## Verification

- `mix test test/rindle/storage/s3_tus_test.exs` — 11 tests, 0 failures (pre-first-part-hole -> `:tus_tail_missing`; same-node-tail-present -> `{:ok, ...}`; the two pre-existing CR-04 tests still green).
- `mix test test/rindle/storage/` — 71 tests, 0 failures, 1 skipped (MinIO/integration tags excluded), no regression across the adapter surface.
- `mix compile --warnings-as-errors` — succeeds.
- Acceptance greps: `committed_part_bytes` appears 2x in code (comments stripped); the only `5 * 1024 * 1024` literal is the `@s3_min_part_size` definition (no new hardcoded literal in the guard); `guard_local_tail_present` is arity-3 and `upload_part_stream/5` threads `base_offset` into it.

## Threat Model Coverage

- **T-43-12-01 (Tampering / silent data integrity):** mitigated — the guard now requires the node-local tail whenever `offset > committed_part_bytes`, proven by the pre-first-part unit test (parts: [], offset > 0, tail absent -> error).
- **T-43-12-02 (Information disclosure):** mitigated — bare `:tus_tail_missing` atom only; no path/offset/session_uri in the error.
- **T-43-12-03 (DoS / false positive):** mitigated — `offset > committed_part_bytes` is false for a brand-new FIRST PATCH (offset 0), and the guard does not fire when the expected tail is present (same-node test), so legitimate single-node uploads are not broken.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- CR-04 is closed at the adapter layer (the integrity half of TUS-09). The S3 tus backing now fails loudly on any misrouted cross-node resume — both the committed-part case and the pre-first-part window — preserving the single-node/sticky-session operator contract documented in the S3 moduledoc.
- The MinIO `@tag :minio` integration proofs (43-10) remain CI-only (no MinIO in this environment); they exercise the live UploadPart round-trip and are unaffected by this offline-firing guard change.

## Self-Check: PASSED

- `lib/rindle/storage/s3.ex` — FOUND
- `test/rindle/storage/s3_tus_test.exs` — FOUND
- `.planning/phases/43-s3-multipart-backing-minio-proof/43-12-SUMMARY.md` — FOUND
- Task commit `90f70ea` — FOUND in git log

---
*Phase: 43-s3-multipart-backing-minio-proof*
*Completed: 2026-05-23*
