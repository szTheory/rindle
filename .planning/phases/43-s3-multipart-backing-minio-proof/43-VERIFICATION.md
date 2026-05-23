---
phase: 43-s3-multipart-backing-minio-proof
verified: 2026-05-23T15:42:00Z
status: human_needed
score: 5/5
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 3/5
  gaps_closed:
    - "CR-01 (abort-failure path): abort_delete_backing/2 now returns %{failure_reason: 'tus_abort_failed:<reason>'} on abort failure; handle_delete/2 folds it into the aborted changeset; fetch_retryable_tus_abort_sessions/0 re-selects the row; settle_tus_abort_success/2 + persist_tus_abort_retry_success/2 settle WITHOUT FSM-forbidden aborted->expired; false comment removed and replaced with accurate description"
    - "CR-04 (pre-first-part guard hole): guard_local_tail_present/3 now fires when (parts != [] OR offset > committed_part_bytes); upload_part_stream/5 threads base_offset into the guard; the pre-first-part cross-node resume (upload_id set, parts: [], offset > 0, tail absent) now fails loudly with {:error, :tus_tail_missing}"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Run the MinIO integration test suite against a live MinIO endpoint"
    expected: "All three @moduletag :minio tests pass: (1) >= 1 GiB drop+resume completes to 'ready' asset with byte_size == 1 GiB and list_multipart_uploads returns empty after reaper; (2) tus DELETE on S3-backed session returns 204 and list_multipart_uploads returns empty for deleted key; (3) post-reap on-disk tail file is removed"
    why_human: "MinIO is not available in this environment. Tests require a running MinIO endpoint at RINDLE_MINIO_URL with the RINDLE_MINIO_* env vars set. Tests are tagged @moduletag :minio and excluded from the default mix test run (mix test --include minio test/rindle/upload/tus_s3_integration_test.exs)."
---

# Phase 43: S3 Multipart Backing + MinIO Proof — Verification Report (Re-verification 3)

**Phase Goal:** An S3-compatible adapter can serve tus by streaming each PATCH into an S3 multipart upload, completing through the existing verify lane, and abandoned tus sessions are reliably reaped — proven against MinIO with a >= 1 GiB drop-and-resume and a zero-leak abort assertion.

**Verified:** 2026-05-23T15:42:00Z
**Status:** human_needed
**Re-verification:** Yes — after gap-closure plans 43-11 (CR-01) + 43-12 (CR-04)
**Requirements verified:** TUS-06, TUS-07, TUS-08, TUS-09

---

## Re-Verification Summary

**Previous status:** gaps_found (3/5)
**Current status:** human_needed (5/5 automated truths verified; 1 human verification item remains)

**Gaps closed since prior verification:**

- **CR-01 (abort-failure path permanently orphans S3 multipart):** CLOSED. Plan 43-11 (commits 6a4cd1c + 9f3fe75) implemented both halves:
  - Plug half: `abort_delete_backing/2` (`tus_plug.ex:459-477`) now returns `%{failure_reason: "tus_abort_failed:<short_reason>"}` on abort failure (and `%{failure_reason: nil}` on success). `handle_delete/2` folds the attrs into the aborted changeset. The false comment is removed and replaced with an accurate description of the real compensation.
  - Reaper half: `fetch_retryable_tus_abort_sessions/0` (`upload_maintenance.ex:188-205`) selects `state=="aborted" AND resumable_protocol=="tus" AND not is_nil(multipart_upload_id) AND like(failure_reason, "tus_abort_failed:%")`, unioned into `fetch_abortable_sessions/0`. `settle_tus_abort_success/2` (`upload_maintenance.ex:516-537`) branches on the inbound failure_reason marker — aborted rows with the `tus_abort_failed:` marker settle via `persist_tus_abort_retry_success/2` (`upload_maintenance.ex:543-566`) with a direct repo update (no FSM gate, WR-03 reconciled); non-terminal rows keep `gated_expire/2` (WR-01 preserved).

- **CR-04 (pre-first-part cross-node guard hole):** CLOSED. Plan 43-12 (commit 90f70ea) strengthened `guard_local_tail_present/3` (`s3.ex:312-327`):
  - Guard arity raised from /2 to /3; `upload_part_stream/5` at line 164 now threads `base_offset` into the guard.
  - `committed_part_bytes = length(parts) * @s3_min_part_size`; `mid_multipart?` fires when `is_binary(upload_id) and upload_id != "" and (parts != [] or offset > committed_part_bytes)`.
  - Pre-first-part window (upload_id set, parts: [], offset > 0, tail absent) now returns `{:error, :tus_tail_missing}` instead of silently opening a fresh empty tail.

**No regressions detected across the broader test suite (291 tests, 0 failures, 4 skipped).**

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `upload_part_stream/5` on `Rindle.Storage` implemented by S3 as one `UploadPart` per PATCH >= 5 MiB, buffering a sub-5 MiB final chunk under `Rindle.tmp/tus/` and flushing it as the final part on completion | VERIFIED | `s3.ex:162-186` — tail-buffer accumulate/drain pattern; `complete_part_stream/4` at lines 189-209 flushes tail as final part then calls `complete_multipart_upload`. `:tus_upload` in capabilities at line 234. |
| 2 | Adapters advertise `:tus_upload` honestly (S3 + Local yes; GCS no); mounting `TusPlug` against an adapter without `:tus_upload` raises at `init/1` | VERIFIED | `s3.ex:234` — `:tus_upload` in capabilities. `tus_plug.ex:100-108` — `Capabilities.require_upload(adapter, :tus_upload)` raises `ArgumentError` at `init/1`. GCS adapter verified not to include `:tus_upload`. |
| 3 | tus completion (final PATCH, offset == length) calls `complete_multipart_upload/4` then converges into the existing `verify_completion/2` lane — zero new completion vocabulary | VERIFIED | `tus_plug.ex:373-390` — `complete_upload/3` calls `adapter.complete_part_stream/4` then `Broker.verify_completion/2`. `s3.ex:189-209` — `complete_part_stream/4` calls `S3.complete_multipart_upload`. |
| 4 | tus sessions expire AND DELETE terminates; the reaper branches on resumable_protocol (tus -> abort S3 multipart or remove local tmp; gcs_native -> existing session-URI cancel); zero orphaned-multipart leak after abandonment + DELETE | VERIFIED | Timeout/expiry path: `expire_tus_session/2` (upload_maintenance.ex:485-502) calls `abort_tus_backing/1` then `settle_tus_abort_success/2`. DELETE happy-path: `handle_delete/2` calls `abort_delete_backing/2` before state transition. DELETE abort-failure: `abort_delete_backing/2` returns `%{failure_reason: "tus_abort_failed:<reason>"}` (NOT `:ok`); `fetch_retryable_tus_abort_sessions/0` re-selects; `persist_tus_abort_retry_success/2` settles WITHOUT FSM-forbidden `aborted->expired`. False comment removed. 44 tests green (including 4 new CR-01/WR-03 regression tests + 2 new Plug marker tests). |
| 5 | A MinIO integration proof completes a >= 1 GiB tus upload with a mid-flight drop + resume, and asserts that after abandonment + reaper, `list_multipart_uploads` returns empty | HUMAN NEEDED | `test/rindle/upload/tus_s3_integration_test.exs` exists with `@moduletag :minio`. Three test cases: (1) >= 1 GiB drop+resume + zero-leak after timeout-reap (line 148); (2) DELETE-then-list_multipart_uploads-empty (line 230); (3) post-reap tail-file removed (line 280). MinIO not available in this environment. |

**Score:** 5/5 truths verified (all automated truths; SC5 requires human MinIO execution)

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/rindle/storage/s3.ex` | `upload_part_stream/5` + `complete_part_stream/4` + `:tus_upload` cap + tail-buffer logic + `tus_tail_path/2` + strengthened cross-node guard (offset > committed_part_bytes OR parts != []) | VERIFIED | `guard_local_tail_present/3` at lines 312-327: `committed_part_bytes = length(parts) * @s3_min_part_size`; fires on `(parts != [] or offset > committed_part_bytes)`. `upload_part_stream/5` threads `base_offset` at line 164. Accepted greps: `committed_part_bytes` appears 2x in code (comments stripped); `@s3_min_part_size` reused (no new hardcoded literal). |
| `lib/rindle/upload/tus_plug.ex` | `handle_delete/2` calls backing abort BEFORE state transition; `abort_delete_backing/2` persists retryable marker on abort failure; false comment corrected; single-node moduledoc | VERIFIED | `handle_delete/2` (lines 412-444): calls `abort_delete_backing/2` at line 424, folds attrs into changeset at line 432. `abort_delete_backing/2` (lines 459-477): returns `%{failure_reason: nil}` on `:ok`, `%{failure_reason: tus_abort_marker(reason)}` on `{:error, reason}`. `tus_abort_marker/1` (lines 486-490): atom verbatim/transport, bounded to 64 chars, always starts `tus_abort_failed:`. False comment removed — replacement at lines 416-423 accurately describes the marker + reaper compensation. |
| `lib/rindle/ops/upload_maintenance.ex` | FSM-gated tus expiry; reaper query for DELETE-abort-failure retry rows; WR-03 settle WITHOUT FSM gate; `persist_tus_abort_retry_success/2` | VERIFIED | `fetch_retryable_tus_abort_sessions/0` (lines 188-205): all four predicates present. Unioned in `fetch_abortable_sessions/0` (lines 207-218). `settle_tus_abort_success/2` (lines 516-537): branches on `tus_abort_failed:` marker — marker path calls `persist_tus_abort_retry_success/2` (no FSM gate); non-terminal path calls `gated_expire/2` (WR-01 preserved). `persist_tus_abort_retry_success/2` (lines 543-566): direct repo update to `{state: "expired", failure_reason: nil}`, no `UploadSessionFSM.transition`. |
| `lib/rindle/ops/sweep_orphaned_temp_files.ex` | Sweeps aged tus/*.tail and tus/*.part regular files | VERIFIED | Unchanged since CR-03 closure (prior verification). `process_run_dir/4` routes `Path.basename(path) == "tus"` to `sweep_tus_dir/4`; ages out regular files by mtime. |
| `test/rindle/ops/upload_maintenance_test.exs` | 4 CR-01/WR-03 regression tests | VERIFIED | `describe "tus DELETE-time abort-failure recovery (CR-01 reaper half / WR-03)"` at line 1027: recovery (re-abort + settle, abort_errors==0, WR-03 proof); idempotent `:not_found`; still-failing-stays-recoverable (marker intact, abort_errors==1); no-false-retry (clean aborted row never selected, sessions_found==0). 44 tests, 0 failures. |
| `test/rindle/upload/tus_plug_test.exs` | 2 marker regression tests | VERIFIED | Lines 551-567 + 570+: marker-on-failure (204 + `failure_reason` starts with `tus_abort_failed:`); no-marker-on-clean-abort (`failure_reason == nil`). WR-02 and tampered-token tests still green. 28 tests, 0 failures. |
| `test/rindle/storage/s3_tus_test.exs` | pre-first-part hole test + same-node-tail-present no-regression test | VERIFIED | Lines 226-251: pre-first-part (upload_id set, parts: [], offset > 0, tail absent) -> `{:error, :tus_tail_missing}`. Lines 254-279: same-node-tail-present -> `{:ok, ...}`. Both pre-existing CR-04 tests still green. 11 tests, 0 failures. |
| `test/rindle/upload/tus_s3_integration_test.exs` | `@moduletag :minio`, >= 1 GiB drop+resume + zero-leak + DELETE zero-leak | VERIFIED (structure) | File exists; `@moduletag :minio` at line 31; three test cases. Live MinIO execution is a human verification item. |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `tus_plug.ex abort_delete_backing/2` | `%{failure_reason: "tus_abort_failed:<reason>"}` on abort failure | Returns attrs dict; `handle_delete/2` folds into changeset | WIRED | Lines 459-477: `{:error, reason}` branch returns `%{failure_reason: tus_abort_marker(reason)}` — NOT `:ok`. `handle_delete/2` at line 432: `Map.put(abort_attrs, :state, "aborted")` merges the marker into the changeset. |
| `upload_maintenance.ex fetch_retryable_tus_abort_sessions/0` | aborted tus sessions with `tus_abort_failed:%` marker | Query predicate on `state=="aborted" AND resumable_protocol=="tus" AND not is_nil(multipart_upload_id) AND like(failure_reason, "tus_abort_failed:%")` | WIRED | Lines 188-205: all four WHERE clauses confirmed present. Unioned into `fetch_abortable_sessions/0` at line 213. |
| `upload_maintenance.ex settle_tus_abort_success/2` | `persist_tus_abort_retry_success/2` for marker rows | Branch on `failure_reason` starting with `"tus_abort_failed:"` | WIRED | Lines 516-530: pattern-matches `state: "aborted"` + binary `failure_reason`; `String.starts_with?(failure_reason, "tus_abort_failed:")` routes to `persist_tus_abort_retry_success/2`. Other clauses route to `gated_expire/2`. |
| `upload_maintenance.ex persist_tus_abort_retry_success/2` | settled row `{state: "expired", failure_reason: nil}` WITHOUT FSM gate | Direct `repo.update()` with the changeset, no `UploadSessionFSM.transition` | WIRED | Lines 543-566: `MediaUploadSession.changeset(session, %{state: "expired", failure_reason: nil})` followed by `repo.update()`. No `gated_expire/2` call. WR-03 verified by test asserting `abort_errors == 0` (no FSM-rejected invalid_transition). |
| `s3.ex upload_part_stream/5` | `guard_local_tail_present/3` with `base_offset` | `guard_local_tail_present(tail_path(key, opts), base_offset, state)` at line 164 | WIRED | `base_offset` (3rd positional arg of `upload_part_stream/5`) threaded as 2nd arg to `guard_local_tail_present/3`. Guard arity confirmed at line 312. |
| `s3.ex guard_local_tail_present/3` | `{:error, :tus_tail_missing}` on pre-first-part cross-node resume | `offset > committed_part_bytes` with `committed_part_bytes = length(parts) * @s3_min_part_size` | WIRED | Lines 316-320: `committed_part_bytes = length(parts) * @s3_min_part_size`; `mid_multipart? = is_binary(upload_id) and upload_id != "" and (parts != [] or offset > committed_part_bytes)`. Bare atom returned at line 323. |
| `upload_maintenance.ex remove_tus_tail/2` | `S3.tus_tail_path/2` | Delegate path computation (CR-02) | WIRED | Lines 560-561 (unchanged from prior verification, CR-02 CLOSED). |

---

### Data-Flow Trace (Level 4)

Not applicable — this phase delivers adapter callbacks and a reaper, not user-facing rendering components.

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `upload_maintenance.ex` CR-01 regression: aborted tus session with marker is re-selected and re-aborted | `mix test test/rindle/ops/upload_maintenance_test.exs` | 44 tests, 0 failures | PASS |
| `tus_plug.ex` CR-01 marker written on abort failure | `mix test test/rindle/upload/tus_plug_test.exs` | 28 tests, 0 failures | PASS |
| `s3.ex` CR-04 pre-first-part guard fires loudly | `mix test test/rindle/storage/s3_tus_test.exs` | 11 tests, 0 failures | PASS |
| Acceptance grep: `tus_abort_failed` in upload_maintenance.ex (non-comment lines) | `grep -v '^[[:space:]]*#' lib/rindle/ops/upload_maintenance.ex \| grep -c 'tus_abort_failed'` | 3 (>= 1) | PASS |
| Acceptance grep: `tus_abort_failed` in tus_plug.ex (non-comment lines) | `grep -v '^[[:space:]]*#' lib/rindle/upload/tus_plug.ex \| grep -c 'tus_abort_failed'` | 1 (>= 1) | PASS |
| Acceptance grep: `committed_part_bytes` in s3.ex (non-comment lines) | `grep -v '^[[:space:]]*#' lib/rindle/storage/s3.ex \| grep -c 'committed_part_bytes'` | 2 (>= 1) | PASS |
| False comment removed | `grep -n 'reaper compensates on the next cron' lib/rindle/upload/tus_plug.ex` | (no output) | PASS |
| Compile clean | `mix compile --warnings-as-errors` | (no output / clean) | PASS |
| Broader suite: ops + upload + storage | `mix test test/rindle/ops/ test/rindle/upload/ test/rindle/storage/` | 291 tests, 0 failures, 4 skipped | PASS |

---

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| TUS-06 | 43-01, 43-02, 43-06, 43-12 | `upload_part_stream/5` OPTIONAL callback; S3 one UploadPart per PATCH >= 5 MiB; sub-5-MiB tail buffer; `tus_tail_path/2` public helper | SATISFIED | `s3.ex:162-186` implements tail-buffer accumulate/drain; `tus_tail_path/2` at lines 253-255 is public and encoding-correct. CR-12 strengthened the guard (also credits TUS-06 by improving the data-integrity guarantee of `upload_part_stream/5`). |
| TUS-07 | 43-01, 43-02 | Adapters advertise `:tus_upload` honestly; `TusPlug init/1` raises without capability | SATISFIED | S3 (line 234) + Local advertise `:tus_upload`; GCS does not; `tus_plug.ex:100-108` raises at `init/1`. |
| TUS-08 | 43-01, 43-04 | Completion calls `complete_multipart_upload/4` then `verify_completion/2`; zero new completion vocabulary | SATISFIED | `tus_plug.ex:373-390` + `s3.ex:189-209` confirmed (unchanged since prior verification). |
| TUS-09 | 43-01, 43-03, 43-05, 43-06..12 | tus sessions expire; DELETE terminates; reaper branches on resumable_protocol; MinIO zero-leak proof | SATISFIED (pending human MinIO run) | Timeout-expiry reaper: `expire_tus_session/2` + `settle_tus_abort_success/2` + `gated_expire/2`. DELETE happy-path: abort before state transition (43-09). DELETE abort-failure: `tus_abort_failed:` marker + `fetch_retryable_tus_abort_sessions/0` + `persist_tus_abort_retry_success/2` (CR-01 CLOSED, 43-11). Cross-node guard: `offset > committed_part_bytes` OR `parts != []` (CR-04 CLOSED, 43-12). MinIO integration tests exist with correct structure; live execution requires human. |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None | — | No blockers, no false comments, no swallowed errors | — | All prior blockers resolved |

Prior BLOCKER anti-patterns from the previous verification are confirmed resolved:

- `tus_plug.ex:419-420` false comment: REMOVED. The replacement comment at lines 416-423 accurately describes the `tus_abort_failed:` marker and `fetch_retryable_tus_abort_sessions/0` compensation.
- `tus_plug.ex abort_delete_backing/2` swallowing `{:error, _}`: FIXED. Now returns `%{failure_reason: tus_abort_marker(reason)}` instead of `:ok`.
- `upload_maintenance.ex fetch_retryable_abort_sessions/0` missing tus predicate: FIXED. `fetch_retryable_tus_abort_sessions/0` added and unioned.
- `s3.ex guard_local_tail_present` `parts != []` hole: FIXED. Now fires on `(parts != [] or offset > committed_part_bytes)`.

---

### Human Verification Required

#### 1. MinIO Integration Test Suite

**Test:** Set up a MinIO endpoint with `RINDLE_MINIO_URL`, `RINDLE_MINIO_ACCESS_KEY`, `RINDLE_MINIO_SECRET_KEY` env vars. Run:
```
mix test test/rindle/upload/tus_s3_integration_test.exs --include minio
```

**Expected:**
- Test 1 (line 148): A >= 1 GiB tus upload over S3 backing survives drop+resume, converges into `verify_completion/2` with correct byte_size, and `list_multipart_uploads` returns empty for the abandoned session after reaper runs.
- Test 2 (line 230): A tus DELETE on an S3-backed session returns 204 and `list_multipart_uploads` returns empty for the deleted key.
- Test 3 (line 280): After reaping an abandoned tus session, the on-disk tail file is removed.

**Why human:** MinIO is not available in this verification environment. Tests are tagged `@moduletag :minio` and excluded from the default `mix test` run. All automated checks pass. The abort-failure compensation (CR-01) is regression-tested via `StorageMock` injection in the default suite — the live MinIO run validates the happy-path plumbing end-to-end.

---

### Gaps Summary

No gaps remain. All 5 observable truths are now verified at the code level. The only remaining item is SC5's live MinIO execution, which is structural requirement for the phase's "proven against MinIO" claim and cannot be completed without a running MinIO endpoint — this is the expected human_needed gate, not a code deficiency.

**CR-01 (CLOSED by 43-11):** The DELETE abort-failure branch now persists a `tus_abort_failed:<reason>` marker and the reaper re-aborts the orphaned multipart on the next cron. WR-03 is reconciled: the retry-success path settles without an FSM-forbidden `aborted -> expired` transition. Regression-tested in the default suite.

**CR-04 (CLOSED by 43-12):** The cross-node guard now fires on `offset > committed_part_bytes` (OR `parts != []`), closing the pre-first-part silent-corruption window. A sub-5-MiB-first-chunk cross-node resume now fails loudly with `{:error, :tus_tail_missing}` instead of producing a corrupted object. Regression-tested in the default suite.

---

_Verified: 2026-05-23T15:42:00Z_
_Verifier: Claude (gsd-verifier)_
_Re-verification 3 of prior gaps_found (3/5); CR-01 and CR-04 confirmed CLOSED; all 5 automated truths verified; status: human_needed pending live MinIO execution_
