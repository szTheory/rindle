---
phase: 43-s3-multipart-backing-minio-proof
verified: 2026-05-23T00:00:00Z
status: gaps_found
score: 3/5
overrides_applied: 0
gaps:
  - truth: "tus sessions expire AND DELETE terminates; the reaper branches on resumable_protocol (tus -> abort the S3 multipart or remove the local tmp; gcs_native -> existing session-URI cancel)"
    status: failed
    reason: "handle_delete/2 in tus_plug.ex sets state: aborted but never calls abort_multipart_upload or any backing-store cleanup. No reaper query ever re-selects an aborted tus session (fetch_incomplete_timed_out_sessions requires state in [signed, uploading] or resuming/initialized; fetch_retryable_abort_sessions requires failure_reason LIKE resumable_cancel_failed:% which is nil for a DELETEd session). The S3 multipart upload is permanently orphaned on the DELETE path — the precise cost leak TUS-09 exists to close."
    artifacts:
      - path: "lib/rindle/upload/tus_plug.ex"
        issue: "handle_delete/2 at line 385-403 performs no backing-store abort. Comment at line 392-394 incorrectly claims Rindle.tmp/ reaper sweeps the abandonment; that claim only covers local temp files, not the remote S3 multipart upload."
      - path: "lib/rindle/ops/upload_maintenance.ex"
        issue: "fetch_retryable_abort_sessions/0 at line 158-175 requires failure_reason LIKE resumable_cancel_failed:% — nil for DELETE-terminated sessions. fetch_incomplete_timed_out_sessions/0 at line 135-155 requires state in [signed, uploading] or specific resumable/multipart combos — never aborted. No query selects a tus session in state aborted with multipart_upload_id set."
      - path: "test/rindle/upload/tus_plug_test.exs"
        issue: "DELETE test at line 390-408 only asserts session state == aborted and conn.status == 204. It does NOT assert abort_multipart_upload is invoked. Integration test (tus_s3_integration_test.exs) covers only the timeout-expiry reaper path, not the DELETE path."
    missing:
      - "abort_tus_backing/1 (or equivalent) must be called inside handle_delete/2 before or alongside the state transition"
      - "Alternatively: fetch_abortable_sessions/0 must be extended to also select (state == aborted AND resumable_protocol == tus AND multipart_upload_id NOT NULL) so the reaper compensates"
      - "Regression test asserting abort_multipart_upload is invoked for a DELETEd S3-backed tus session"

  - truth: "S3 tail buffer written under Rindle.tmp/tus/<Base.url_encode64(session_id)>.tail is reliably removed by the reaper"
    status: failed
    reason: "remove_tus_tail/1 in upload_maintenance.ex constructs path as <root>/tus/<session_id>.tail (raw UUID). S3 adapter writes the tail at <root>/tus/<Base.url_encode64(session_id, padding: false)>.tail via tail_filename/1 in s3.ex. The paths never match. The reaper always attempts to remove a file that does not exist at that path; the actual tail file is never deleted by the reaper."
    artifacts:
      - path: "lib/rindle/ops/upload_maintenance.ex"
        issue: "remove_tus_tail/1 at line 516-519: path = Path.join([root, tus, session_id <> .tail]) — raw unencoded UUID."
      - path: "lib/rindle/storage/s3.ex"
        issue: "tail_filename/1 at line 411-413: Base.url_encode64(id, padding: false) <> .tail — base64-url-encoded id. The two path computations are inconsistent."
    missing:
      - "remove_tus_tail/1 must apply Base.url_encode64 (matching tail_filename/1 in s3.ex), or delegate to a public S3.tus_tail_path/2 helper"
      - "Unit test asserting that remove_tus_tail/1 deletes the file created by the S3 adapter"

  - truth: "Rindle.tmp/ sweeper cleans up residual tus/*.tail and tus/*.part files"
    status: failed
    reason: "sweep_orphaned_temp_files.ex process_run_dir/4 at line 74-92 matches only {:ok, %File.Stat{type: :directory, mtime: mtime}} — the {:ok, _stat} arm at line 86 returns acc unchanged (files are silently skipped, never deleted). tus/*.tail and tus/*.part are regular files under Rindle.tmp/tus/. The tus/ directory itself is never swept because its mtime is refreshed on every write (any active system always has a fresh tus/ mtime). Residual tail/part files accumulate without bound."
    artifacts:
      - path: "lib/rindle/ops/sweep_orphaned_temp_files.ex"
        issue: "process_run_dir/4 at line 74-92: only type: :directory entries are eligible for deletion. Regular files (type: :regular) fall into the {:ok, _stat} -> acc branch and are never removed."
    missing:
      - "Either recurse into tus/ and age-out individual regular files, or ensure explicit per-path cleanup in abort_tus_backing/1 and complete_part_stream/4 is reliable enough without the sweeper as backstop"
      - "Test asserting the sweeper removes an aged tus/<id>.tail file"

  - truth: "Sub-5 MiB S3 tail buffer node-local disk state is safe in multi-node deployments or is explicitly guarded"
    status: failed
    reason: "upload_part_stream/5 in s3.ex writes the tail remainder to local disk at <Rindle.tmp>/tus/<encoded_session_id>.tail. The offset/upload_id/parts cross-PATCH state is persisted in shared DB via persist_offset/2 in tus_plug.ex. There is no node-affinity guard, no detection of a missing tail file on resume, and no documentation of a single-node constraint anywhere in the adapter, plug, or moduledocs. A resumed PATCH routed to a different node opens a fresh empty tail file and re-slices from the wrong byte boundary, silently corrupting the assembled object without surfacing an error to the client."
    artifacts:
      - path: "lib/rindle/storage/s3.ex"
        issue: "upload_part_stream/5 at line 140-163: tail_path keyed on node-local Rindle.tmp/; no guard when tail file is absent but DB offset/parts indicate a mid-multipart state."
      - path: "lib/rindle/upload/tus_plug.ex"
        issue: "prior_state/1 at line 264-270 rebuilds state from DB correctly but does not detect tail-file absence before delegating to upload_part_stream/5."
    missing:
      - "Either: fail loudly when PATCH arrives with multipart_upload_id in DB but no tail file at the expected path (guard missing tail = cross-node resume), or persist tail bytes in shared storage"
      - "Or: document and enforce sticky-session deployment constraint; add an explicit check in upload_part_stream/5 or the Plug that surfaces a loud error rather than a silent corruption"
      - "Unit test simulating resume with tail file absent asserting a tagged error rather than corrupted assembly"
---

# Phase 43: S3 Multipart Backing + MinIO Proof — Verification Report

**Phase Goal:** An S3-compatible adapter can serve tus by streaming each PATCH into an S3 multipart upload, completing through the existing verify lane, and abandoned tus sessions are reliably reaped — proven against MinIO with a >= 1 GiB drop-and-resume and a zero-leak abort assertion.

**Verified:** 2026-05-23
**Status:** gaps_found
**Re-verification:** No — initial verification
**Requirements verified:** TUS-06, TUS-07, TUS-08, TUS-09

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `upload_part_stream/5` on `Rindle.Storage`, implemented by S3 as one `UploadPart` per PATCH >= 5 MiB, buffering a sub-5-MiB final chunk under `Rindle.tmp/tus/` and flushing it as the final part on completion | VERIFIED | `lib/rindle/storage/s3.ex:140-191` implements the tail-buffer slice/accumulate pattern; `complete_part_stream/4` at line 166-191 flushes tail as final part then calls `complete_multipart_upload/4`. S3 capabilities include `:tus_upload` at line 216. |
| 2 | Adapters advertise `:tus_upload` honestly (S3 + Local yes; GCS no); mounting `TusPlug` against an adapter without `:tus_upload` raises at `init/1` | VERIFIED | `lib/rindle/storage/s3.ex:216` — `:tus_upload` in capabilities. `lib/rindle/storage/local.ex:130` — `:tus_upload` in capabilities. GCS adapter does not include `:tus_upload` (grep returns no results). `lib/rindle/upload/tus_plug.ex:78-85` — `Capabilities.require_upload(adapter, :tus_upload)` raises `ArgumentError` at `init/1` when capability absent. |
| 3 | tus completion calls `complete_multipart_upload/4` then converges into the existing `verify_completion/2` lane with zero new completion vocabulary | VERIFIED | `lib/rindle/upload/tus_plug.ex:351-368` — `complete_upload/3` calls `adapter.complete_part_stream/4` then `Broker.verify_completion/2` unchanged. `lib/rindle/storage/s3.ex:181` — `complete_part_stream/4` calls `S3.complete_multipart_upload/4`. |
| 4 | tus sessions expire AND `DELETE` terminates; the reaper branches on `resumable_protocol` ("tus" -> abort the S3 multipart or remove the local tmp; "gcs_native" -> existing session-URI cancel) | FAILED (BLOCKER) | Timeout/expiry reaper path works: `expire_session/2` at line 386-404 branches on `tus_session?/1` first, routing to `expire_tus_session/2` which calls `abort_tus_backing/1` (S3 multipart abort). DELETE path is broken: `handle_delete/2` at line 385-403 sets `state: "aborted"` but performs no backing-store abort. No reaper query selects `state == "aborted"` tus sessions (CR-01). Additionally: `remove_tus_tail/1` constructs the wrong path (raw UUID vs base64url-encoded), so tail files are never deleted (CR-02). `sweep_orphaned_temp_files.ex` only sweeps directories, skipping `tus/*.tail` files entirely (CR-03). |
| 5 | A MinIO integration proof completes a >= 1 GiB tus upload with a mid-flight drop + resume, and asserts that after abandonment + reaper, `list_multipart_uploads` returns empty | PARTIAL (BLOCKER) | `test/rindle/upload/tus_s3_integration_test.exs:139-209` — the test exists and covers: (a) >= 1 GiB synthetic upload with mid-flight drop + resume, (b) verify_completion convergence, (c) abandonment via timeout expiry + reaper + `list_multipart_uploads` empty assertion. However: the test is `@tag :minio` (excluded from default suite; CI-only); it covers only the timeout-expiry reaper path, NOT the DELETE termination path (CR-01). The "ZERO LEAK" claim holds only for the timeout path. Node-local tail state (CR-04) is also not covered. |

**Score:** 3/5 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/rindle/storage.ex` | `upload_part_stream/5` + `complete_part_stream/4` @callback decls, `@type tus_part_state`, `@optional_callbacks` entries | VERIFIED | Callbacks declared per plan; behaviour contract established |
| `lib/rindle/storage/s3.ex` | `upload_part_stream/5` + `complete_part_stream/4` impls, `:tus_upload` capability, tail-buffer logic | VERIFIED | All implemented; tail-buffer encoding is correct (base64url). Note: `remove_tus_tail/1` in upload_maintenance.ex uses a different (unencoded) path — see CR-02 gap |
| `lib/rindle/storage/local.ex` | `upload_part_stream/5` + `complete_part_stream/4` wrapping tus_append/tus_complete | VERIFIED | Confirmed in capabilities grep and plan 04 summary |
| `lib/rindle/upload/tus_plug.ex` | Polymorphic adapter dispatch in handle_patch/complete_upload; multipart state persistence; DELETE termination | PARTIAL | PATCH and completion dispatch are correct. DELETE termination sets `state: "aborted"` but performs no backing-store abort (CR-01) |
| `lib/rindle/ops/upload_maintenance.ex` | tus_session?/1, expire_tus_session/2, abort_tus_backing/1, resolve_tus_adapter/1 | PARTIAL | Timeout-expiry reaper path implemented correctly. DELETE path never selected. `remove_tus_tail/1` uses wrong path encoding (CR-02) |
| `test/rindle/upload/tus_s3_integration_test.exs` | >= 1 GiB drop+resume + list_multipart_uploads-empty MinIO proof | PARTIAL | Test exists and covers timeout-expiry path. DELETE path, tail-file cleanup, and multi-node resume are not covered (IN-04) |
| `lib/rindle/ops/sweep_orphaned_temp_files.ex` | Sweeps tus/*.tail and tus/*.part residual files | FAILED | `process_run_dir/4` only acts on `type: :directory` entries; regular files are silently skipped (CR-03) |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `tus_plug.ex handle_patch/2` | `adapter.upload_part_stream/5` | drain PATCH to temp file then dispatch | VERIFIED | Line 248-255: polymorphic dispatch through `opts[:adapter].upload_part_stream/5` |
| `tus_plug.ex complete_upload/3` | `Broker.verify_completion/2` | `adapter.complete_part_stream/4` then verify_completion | VERIFIED | Lines 351-368 |
| `tus_plug.ex handle_delete/2` | `abort_tus_backing/1` or backing-store abort | Should call backing cleanup before state transition | NOT WIRED | handle_delete/2 at line 385-403 only does DB state update; no backing-store abort called (CR-01) |
| `upload_maintenance.ex remove_tus_tail/1` | actual tail file written by s3.ex | `Path.join([root, "tus", session_id <> ".tail"])` | NOT WIRED | s3.ex writes `Base.url_encode64(session_id, padding: false) <> ".tail"`; remove_tus_tail uses raw session_id — paths never match (CR-02) |
| `sweep_orphaned_temp_files.ex process_run_dir/4` | `tus/*.tail` and `tus/*.part` files | `File.rm_rf` on aged entries | NOT WIRED | Only directories are eligible; regular files fall to `{:ok, _stat} -> acc` (CR-03) |
| `upload_maintenance.ex fetch_abortable_sessions/0` | aborted tus sessions with multipart_upload_id | Query selection | NOT WIRED | fetch_retryable_abort_sessions requires `failure_reason LIKE "resumable_cancel_failed:%"` — nil for DELETE-terminated sessions; fetch_incomplete_timed_out_sessions requires state in [signed, uploading] — never aborted (CR-01) |

---

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| TUS-06 | 43-01, 43-02, 43-04, 43-05 | `upload_part_stream/5` OPTIONAL callback; S3 one UploadPart per PATCH >= 5 MiB; sub-5-MiB tail buffer | SATISFIED | `s3.ex:140-191` implements correctly; `local.ex` implements wrapping existing helpers |
| TUS-07 | 43-01, 43-02 | Adapters advertise `:tus_upload` honestly; TusPlug init/1 raises without capability | SATISFIED | S3 + Local advertise `:tus_upload`; GCS does not; `tus_plug.ex:78-85` raises at init/1 |
| TUS-08 | 43-01, 43-04, 43-05 | Completion calls `complete_multipart_upload/4` then `verify_completion/2`; zero new completion vocabulary | SATISFIED | `tus_plug.ex:351-368` + `s3.ex:166-191` confirmed |
| TUS-09 | 43-01, 43-03, 43-05 | tus sessions expire via expires_at; DELETE terminates; reaper branches on resumable_protocol | BLOCKED | Timeout-expiry reaper path works. DELETE path leaks S3 multipart permanently (CR-01). Tail file removal path mismatch (CR-02). Sweeper skips regular files (CR-03). Node-local tail state has no affinity guard (CR-04). |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/rindle/upload/tus_plug.ex` | 385-403 | `handle_delete/2` sets state "aborted" with no backing-store abort; comment at 392-394 incorrectly claims reaper sweeps backing files | BLOCKER | S3 multipart upload permanently orphaned on DELETE path (CR-01) |
| `lib/rindle/ops/upload_maintenance.ex` | 516-519 | `remove_tus_tail/1` constructs raw `session_id <> ".tail"` path; S3 adapter uses `Base.url_encode64(id, padding: false) <> ".tail"` | BLOCKER | Tail file is never deleted by the reaper (CR-02) |
| `lib/rindle/ops/sweep_orphaned_temp_files.ex` | 74-92 | `process_run_dir/4` matches only `type: :directory`; `{:ok, _stat}` arm returns `acc` unchanged (regular files silently skipped) | BLOCKER | `tus/*.tail` and `tus/*.part` files accumulate without bound (CR-03) |
| `lib/rindle/storage/s3.ex` | 140-191 | Sub-5-MiB tail buffer held on node-local disk; no node-affinity guard or missing-tail detection | BLOCKER | Silent data corruption on cross-node resume in multi-node deployment (CR-04) |
| `test/rindle/upload/tus_plug_test.exs` | 390-408 | DELETE test does not assert `abort_multipart_upload` was invoked; comment at 396 incorrectly claims zero-leak proof in integration test | WARNING | False confidence that DELETE path is safe |
| `test/rindle/upload/tus_s3_integration_test.exs` | 189-208 | Zero-leak assertion only covers timeout-expiry path; does not cover DELETE path, tail-file cleanup, or cross-node resume | WARNING | Integration test gives incomplete coverage of the cost-leak mitigation (IN-04) |

---

### Gaps Summary

Four blockers prevent phase goal achievement. All four were independently confirmed against the source code:

**CR-01 — DELETE leaks S3 multipart permanently (defeats SC4 and TUS-09)**

`handle_delete/2` (`lib/rindle/upload/tus_plug.ex:385-403`) transitions the session to `state: "aborted"` and returns 204 but performs no backing-store cleanup. The reaper never re-selects this session: `fetch_incomplete_timed_out_sessions/0` requires `state in ["signed", "uploading"]` or specific resuming/initialized combos; `fetch_retryable_abort_sessions/0` requires `failure_reason LIKE "resumable_cancel_failed:%"` which is nil for a DELETE-terminated session. An S3-backed tus session terminated via DELETE permanently orphans its S3 multipart upload. This is the headline cost-leak (`T-43-cost-leak`) the phase exists to close, unresolved for the DELETE path.

**CR-02 — `remove_tus_tail/1` path encoding mismatch (tail file never deleted)**

`remove_tus_tail/1` (`lib/rindle/ops/upload_maintenance.ex:516-519`) constructs `<root>/tus/<session_id>.tail` using the raw UUID. `tail_filename/1` (`lib/rindle/storage/s3.ex:411-413`) produces `Base.url_encode64(id, padding: false) <> ".tail"`. The paths never match. The reaper's tail-cleanup call is a no-op on every invocation.

**CR-03 — Sweeper skips regular files (unbounded accumulation of tus/*.tail and tus/*.part)**

`process_run_dir/4` (`lib/rindle/ops/sweep_orphaned_temp_files.ex:74-92`) matches only `{:ok, %File.Stat{type: :directory, mtime: mtime}}`. The `{:ok, _stat}` arm returns `acc` unchanged — regular files are never deleted. The `tus/` directory mtime is refreshed on every write, so it is never swept on any active system. Multiple code sites justify "best-effort cleanup" by citing this sweeper as the safety net; that claim is false.

**CR-04 — Node-local tail state has no affinity guard (silent corruption on multi-node resume)**

`upload_part_stream/5` (`lib/rindle/storage/s3.ex:140-163`) writes the sub-5-MiB tail to local disk. Cross-PATCH state (offset, upload_id, parts) is in the shared DB. No guard exists for the case where a PATCH arrives with DB multipart state but no local tail file. A resumed PATCH routed to a different node re-slices from the wrong boundary, silently corrupting the assembled object with no error returned to the client. No documentation of a single-node constraint appears anywhere in the adapter, plug, or moduledocs.

The MinIO integration test (`tus_s3_integration_test.exs:139-209`) covers the timeout-expiry reaper path on a single node, which passes. It does not exercise the DELETE termination path, tail-file removal, or cross-node resume. The automated test suite being green gives false confidence that the cost-leak mitigation is complete.

---

_Verified: 2026-05-23_
_Verifier: Claude (gsd-verifier)_
