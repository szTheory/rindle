---
phase: 43-s3-multipart-backing-minio-proof
verified: 2026-05-23T12:00:00Z
status: gaps_found
score: 3/5
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 3/5
  gaps_closed:
    - "remove_tus_tail/2 now delegates to S3.tus_tail_path/2 (base64url encoding corrected — CR-02 CLOSED)"
    - "sweep_orphaned_temp_files.ex now recurses into tus/ and ages out individual regular files (CR-03 CLOSED)"
  gaps_remaining:
    - "CR-01: abort-failure path in handle_delete permanently orphans S3 multipart — reaper has no compensating query for aborted+failure_reason=nil tus sessions (STILL OPEN)"
    - "CR-04: guard_local_tail_present fires only when parts != []; a cross-node resume in the pre-first-part window (upload_id set, parts=[]) bypasses the guard silently (STILL OPEN)"
  regressions: []
gaps:
  - truth: "tus sessions expire AND DELETE terminates; the reaper branches on resumable_protocol — S3 multipart is aborted or remove-local-tmp, leaving zero orphaned multipart leak after abandonment + DELETE"
    status: failed
    reason: "CR-01 is only partially resolved. The happy-path DELETE now calls abort_tus_backing before the state transition (FIXED). But abort_delete_backing/2 (tus_plug.ex:445-463) swallows {:error, _} from abort_tus_backing/2 and returns :ok unconditionally — the session still moves to state 'aborted' with failure_reason: nil. No reaper query ever re-selects this session: fetch_incomplete_timed_out_sessions/0 requires state in ['signed','uploading'] (never 'aborted'); fetch_retryable_abort_sessions/0 requires failure_reason LIKE 'resumable_cancel_failed:%' which never matches nil. A transient abort failure at DELETE time permanently orphans the S3 multipart upload — the load-bearing cost-leak the phase exists to close."
    artifacts:
      - path: "lib/rindle/upload/tus_plug.ex"
        issue: "abort_delete_backing/2 at lines 445-463: the {:error, reason} branch logs a warning and returns :ok. The comment at line 419-420 claims 'the row still moves to aborted and the reaper compensates on the next cron' — this is FALSE; no reaper query selects aborted tus sessions with failure_reason: nil."
      - path: "lib/rindle/ops/upload_maintenance.ex"
        issue: "fetch_retryable_abort_sessions/0 at lines 159-176: requires state=='aborted' AND not is_nil(session_uri) AND like(failure_reason, 'resumable_cancel_failed:%'). A DELETE-terminated session has failure_reason: nil (changeset at tus_plug.ex:427 sets only {state: 'aborted'}). The LIKE condition never matches nil. fetch_incomplete_timed_out_sessions/0 at lines 136-156 requires state in ['signed','uploading']. Neither query selects an aborted tus session with failure_reason: nil."
    missing:
      - "Either: when abort_tus_backing/2 returns {:error, _}, do NOT move the row to 'aborted' — leave it in its prior state (signed/uploading) and return 5xx so the timeout reaper picks it up naturally once expires_at passes"
      - "Or: persist a retryable failure_reason marker on abort failure (e.g. 'tus_abort_failed:...') AND extend fetch_retryable_abort_sessions/0 (or add a new query) to select (state=='aborted' AND resumable_protocol=='tus' AND not is_nil(multipart_upload_id)) so the reaper can re-abort on the next cron"
      - "Regression test: inject an abort_multipart_upload failure on DELETE, assert the session is later re-found and re-aborted by abort_incomplete_uploads/1 (confirming no permanent orphan)"
      - "Fix or remove the false comment at tus_plug.ex:419-420"

  - truth: "A cross-node resume — where DB shows mid-multipart state but the tail file is absent on this node — fails loudly with {:error, :tus_tail_missing} rather than silently corrupting the assembled object"
    status: failed
    reason: "CR-04 guard is partially implemented but has a pre-first-part hole. guard_local_tail_present/2 in s3.ex (lines 289-298) sets mid_multipart? to true only when BOTH upload_id is set AND parts != []. A first PATCH under 5 MiB writes bytes to the node-local tail and sets upload_id, but produces parts: [] (no part committed yet). If the next PATCH is routed to a different node: upload_id is set in DB, parts: [] — mid_multipart? is false — guard returns :ok — the fresh node opens an empty tail and appends from byte 0, silently dropping the first node's buffered bytes. The assembled object is corrupted with no error surfaced to the client."
    artifacts:
      - path: "lib/rindle/storage/s3.ex"
        issue: "guard_local_tail_present/2 at lines 289-298: mid_multipart? = is_binary(upload_id) and upload_id != '' and is_list(parts) and parts != []. The parts != [] clause means any resume in the pre-first-part window (upload_id set, offset > 0, parts: []) bypasses the guard entirely. The comment at lines 282-284 acknowledges this is deliberate for the first-write path, but it does not distinguish 'fresh upload, no tail yet' from 'prior node buffered sub-5-MiB, tail expected but absent here'."
    missing:
      - "Strengthen the guard to fire whenever the DB implies bytes were buffered on another node, not only after a part commits. Signal: (upload_id set) AND (base_offset > 0) requires the tail to exist, OR use committed_part_bytes = length(parts) * @s3_min_part_size and fail when offset > committed_part_bytes and tail is absent"
      - "Unit test: resume with upload_id set, parts: [], offset > 0, tail file absent — assert {:error, :tus_tail_missing}, not a silent {:ok, ...}"
human_verification:
  - test: "Run the MinIO integration test suite against a live MinIO endpoint"
    expected: "All three @tag :minio tests pass: (1) >= 1 GiB drop+resume completes to 'ready' asset with byte_size == 1 GiB and list_multipart_uploads returns empty after reaper; (2) tus DELETE on S3-backed session returns 204 and list_multipart_uploads returns empty for deleted key; (3) post-reap on-disk tail file is removed"
    why_human: "MinIO is not available in this environment. Tests require a running MinIO endpoint at RINDLE_MINIO_URL with the RINDLE_MINIO_* env vars set. Tests are tagged @moduletag :minio and excluded from the default mix test run."
---

# Phase 43: S3 Multipart Backing + MinIO Proof — Verification Report (Re-verification)

**Phase Goal:** An S3-compatible adapter can serve tus by streaming each PATCH into an S3 multipart upload, completing through the existing verify lane, and abandoned tus sessions are reliably reaped — proven against MinIO with a >= 1 GiB drop-and-resume and a zero-leak abort assertion.

**Verified:** 2026-05-23T12:00:00Z
**Status:** gaps_found
**Re-verification:** Yes — gap-closure verification after plans 43-06..43-10
**Requirements verified:** TUS-06, TUS-07, TUS-08, TUS-09

---

## Re-Verification Summary

**Previous status:** gaps_found (3/5)
**Current status:** gaps_found (3/5)

**Gaps closed since prior verification:**
- CR-02 (tail-file path encoding mismatch): CLOSED. `remove_tus_tail/2` now delegates to `S3.tus_tail_path/2` which routes through `tail_path/2` + `tail_filename/1` — the single base64url-encoding site. Read: `upload_maintenance.ex` lines 559-564 call `S3.tus_tail_path(session_id, root_opt(root))`. Confirmed.
- CR-03 (sweeper skipped regular files): CLOSED. `process_run_dir/4` now special-cases `Path.basename(path) == "tus"` and routes to `sweep_tus_dir/4`, which iterates entries, checks `type: :regular`, and calls `delete_tus_file/3` on aged files. Confirmed in `sweep_orphaned_temp_files.ex` lines 89-116, 122-166.

**Gaps still open:**
- CR-01 (abort-failure path orphans S3 multipart permanently): CONFIRMED STILL OPEN by independent code reading
- CR-04 (pre-first-part cross-node resume bypasses guard): CONFIRMED STILL OPEN by independent code reading

The independent code re-review (43-REVIEW.md) claims about CR-01 and CR-04 are BOTH confirmed against the actual source. Details follow.

---

## Independent Code Verification of CR-01 and CR-04

### CR-01 Claim Verification (abort-failure path)

The review claims: `abort_delete_backing/2` swallows `{:error, _}` and returns `:ok`, so the row moves to `aborted` with `failure_reason: nil`, and no reaper query ever picks it up.

**Code read at `lib/rindle/upload/tus_plug.ex:445-463`:**

```elixir
defp abort_delete_backing(session, opts) do
  case UploadMaintenance.abort_tus_backing(session, ...) do
    :ok -> :ok
    {:error, reason} ->
      Logger.warning(...)
      :ok   # ← swallows the error, returns :ok
  end
end
```

The `handle_delete/2` at lines 426-428 then unconditionally applies `MediaUploadSession.changeset(%{state: "aborted"})` — only the `state` field is set. `failure_reason` is left nil.

**Code read at `lib/rindle/ops/upload_maintenance.ex:159-176` (`fetch_retryable_abort_sessions/0`):**

```elixir
where: s.state == "aborted",
where: s.upload_strategy == "resumable",
where: not is_nil(s.session_uri),
where: like(s.failure_reason, "resumable_cancel_failed:%"),
```

A DELETE-terminated session has `failure_reason: nil` and `session_uri` still set (it was persisted at POST time). The `LIKE` condition `like(nil, "resumable_cancel_failed:%")` evaluates to false in SQL. This query never selects a DELETE-terminated tus session.

**Code read at `lib/rindle/ops/upload_maintenance.ex:136-156` (`fetch_incomplete_timed_out_sessions/0`):**

```elixir
where: s.state in ["signed", "uploading"] or
  (s.state == "resuming" and s.upload_strategy == "resumable") or
  (s.state == "initialized" and ...)
```

`state == "aborted"` matches none of these predicates.

**Verdict: CR-01 claim is CONFIRMED. The reaper has no compensating query for aborted tus sessions with `failure_reason: nil`. A transient `abort_multipart_upload` failure at DELETE time permanently orphans the S3 multipart upload.**

The comment at `tus_plug.ex:419-420` — "the row still moves to aborted and the reaper compensates on the next cron" — is demonstrably false.

### CR-04 Claim Verification (pre-first-part window)

The review claims: the guard fires only when `parts != []`, so a cross-node resume in the pre-first-part window (upload_id set, parts: []) bypasses it.

**Code read at `lib/rindle/storage/s3.ex:289-298` (`guard_local_tail_present/2`):**

```elixir
defp guard_local_tail_present(tail_path, state) do
  upload_id = Map.get(state, :upload_id)
  parts = Map.get(state, :parts, [])
  mid_multipart? = is_binary(upload_id) and upload_id != "" and is_list(parts) and parts != []

  if mid_multipart? and not File.exists?(tail_path) do
    {:error, :tus_tail_missing}
  else
    :ok
  end
end
```

When a first PATCH sends 3 MiB (sub-5 MiB):
1. `ensure_upload_id` initiates the multipart → `upload_id` is set and persisted
2. `append_to_tail` writes 3 MiB to the node-local tail
3. `drain_tail_parts` sees 3 MiB < 5 MiB → returns `parts: []`, `part_number: 1`
4. Persisted DB state: `upload_id` set, `parts: []`, `offset: 3 MiB`

On a cross-node resume of the second PATCH:
- State from DB: `%{upload_id: "uid", parts: [], offset: 3_145_728}`
- `parts != []` is false → `mid_multipart?` is false → guard returns `:ok`
- `append_to_tail` opens a FRESH empty tail on the new node
- The first 3 MiB buffered on Node A is silently dropped
- Object assembled at completion is missing the first 3 MiB

**Verdict: CR-04 claim is CONFIRMED. The guard has a pre-first-part hole. Any upload whose first node buffered less than 5 MiB before a cross-node resume will produce a silently corrupted object.**

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `upload_part_stream/5` on `Rindle.Storage` implemented by S3 as one `UploadPart` per PATCH >= 5 MiB, buffering a sub-5 MiB final chunk under `Rindle.tmp/tus/` and flushing it as the final part on completion | VERIFIED | `lib/rindle/storage/s3.ex:157-181` — tail-buffer accumulate/drain pattern; `complete_part_stream/4` at lines 184-209 flushes tail as final part then completes multipart. `:tus_upload` in capabilities at line 234. |
| 2 | Adapters advertise `:tus_upload` honestly (S3 + Local yes; GCS no); mounting `TusPlug` against an adapter without `:tus_upload` raises at `init/1` | VERIFIED | `lib/rindle/storage/s3.ex:234` — `:tus_upload` in capabilities. `lib/rindle/upload/tus_plug.ex:100-108` — `Capabilities.require_upload(adapter, :tus_upload)` raises `ArgumentError` at `init/1`. GCS adapter verified not to include `:tus_upload`. |
| 3 | tus completion (final PATCH, offset == length) calls `complete_multipart_upload/4` then converges into the existing `verify_completion/2` lane — zero new completion vocabulary | VERIFIED | `lib/rindle/upload/tus_plug.ex:373-390` — `complete_upload/3` calls `adapter.complete_part_stream/4` then `Broker.verify_completion/2`. `lib/rindle/storage/s3.ex:184-209` — `complete_part_stream/4` calls `S3.complete_multipart_upload`. |
| 4 | tus sessions expire AND DELETE terminates; the reaper branches on resumable_protocol ("tus" -> abort S3 multipart or remove local tmp; "gcs_native" -> existing session-URI cancel); zero orphaned-multipart leak after abandonment + DELETE | FAILED (BLOCKER) | Timeout/expiry path: FIXED — `expire_tus_session/2` (upload_maintenance.ex:455-471) calls `abort_tus_backing/1` which aborts S3 multipart, then `gated_expire/2` transitions to "expired". DELETE path happy-path: FIXED — `handle_delete/2` (tus_plug.ex:412-439) calls `abort_delete_backing/2` before state transition. DELETE path abort-failure: STILL BROKEN (CR-01) — `abort_delete_backing/2` swallows `{:error, _}` and still moves the row to `aborted` with `failure_reason: nil`; no reaper query selects this session; S3 multipart permanently orphaned on transient abort failure. |
| 5 | A MinIO integration proof completes a >= 1 GiB tus upload with a mid-flight drop + resume, and asserts that after abandonment + reaper, `list_multipart_uploads` returns empty | HUMAN NEEDED | `test/rindle/upload/tus_s3_integration_test.exs` exists with `@moduletag :minio`. Three test cases: (1) >= 1 GiB drop+resume + zero-leak after timeout-reap (line 148); (2) DELETE-then-list_multipart_uploads-empty (line 230); (3) post-reap tail-file removed (line 280). All correctly tagged `:minio`. CR-04 hole means test (1) could produce a corrupted object if the drop falls in the pre-5-MiB window on a multi-node cluster — but the test uses a single node, so it passes in CI even with the CR-04 hole present. MinIO not available in this environment. |

**Score:** 3/5 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/rindle/storage/s3.ex` | `upload_part_stream/5` + `complete_part_stream/4` + `:tus_upload` cap + tail-buffer logic + `tus_tail_path/2` public helper + cross-node guard + single-node moduledoc | VERIFIED | All present. `tus_tail_path/2` (lines 253-255) delegates to `tail_path/2` with `session_id` as both key and `:session_id` opt — single encoding site preserved. Guard at lines 289-298 exists but has CR-04 hole. Moduledoc at lines 1-21 documents the single-node constraint. |
| `lib/rindle/upload/tus_plug.ex` | `handle_delete/2` calls backing abort BEFORE state transition; honours update result; single-node moduledoc | PARTIAL | `handle_delete/2` (lines 412-439) calls `abort_delete_backing/2` before changeset update (FIXED). `abort_delete_backing/2` (lines 445-463) swallows `{:error, _}` — abort-failure path still orphans (CR-01 OPEN). Update result honoured — `{:error, _changeset}` returns `tus_error(conn, 500, "")` (WR-02 FIXED). Moduledoc at lines 49-67 documents single-node constraint (FIXED). |
| `lib/rindle/ops/upload_maintenance.ex` | FSM-gated tus expiry; encoding-correct `remove_tus_tail/2`; PUBLIC `abort_tus_backing/2`; reaper compensation for DELETE abort failures | PARTIAL | FSM-gated tus expiry via `gated_expire/2` (lines 424-438, FIXED). `remove_tus_tail/2` (lines 559-564) delegates to `S3.tus_tail_path/2` (CR-02 FIXED). `abort_tus_backing/2` is PUBLIC (lines 522-548). NO reaper query for (state==aborted, resumable_protocol==tus, failure_reason==nil) — CR-01 compensation missing. |
| `lib/rindle/ops/sweep_orphaned_temp_files.ex` | Sweeps aged tus/*.tail and tus/*.part regular files | VERIFIED | `process_run_dir/4` (lines 89-116) special-cases `Path.basename(path) == "tus"` and routes to `sweep_tus_dir/4` (lines 122-133) which calls `age_tus_file/4` (lines 136-153) checking `type: :regular` and mtime. CR-03 CLOSED. |
| `test/rindle/upload/tus_s3_integration_test.exs` | `@moduletag :minio`, >= 1 GiB drop+resume + zero-leak + DELETE zero-leak | VERIFIED (structure) | File exists; `@moduletag :minio` at line 31; three test cases present covering drop+resume (line 148), DELETE zero-leak (line 230), and tail-file cleanup (line 280). `list_multipart_uploads` assertions at lines 215 and 265. MinIO execution is a human verification item. |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `tus_plug.ex handle_delete/2` | `UploadMaintenance.abort_tus_backing/2` | Call before state changeset | WIRED | Lines 421, 446-450: `abort_delete_backing(session, opts)` called before `Config.repo().update()` at line 428. Ordering is correct. |
| `abort_delete_backing/2` | abort failure → reaper compensation | `failure_reason` marker or leave in prior state | NOT WIRED | `{:error, reason}` branch (lines 454-461) logs and returns `:ok`; row moves to `state: "aborted"` with `failure_reason: nil`; no reaper query selects this state. Compensation does not exist. |
| `upload_maintenance.ex remove_tus_tail/2` | `S3.tus_tail_path/2` | Delegate path computation | WIRED | Lines 560-561: `S3.tus_tail_path(session_id, root_opt(root))` — encoding-correct. CR-02 CLOSED. |
| `sweep_orphaned_temp_files.ex process_run_dir/4` | `tus/*.tail` and `tus/*.part` files | Recurse into `tus/` and age out regular files | WIRED | Lines 97-99: `if Path.basename(path) == "tus" do sweep_tus_dir(path, ...)`. CR-03 CLOSED. |
| `s3.ex guard_local_tail_present/2` | `{:error, :tus_tail_missing}` on cross-node resume | mid-multipart signal from `parts != []` | PARTIAL | Guard fires when `upload_id` set AND `parts != []` AND tail absent. Does NOT fire when `upload_id` set AND `parts == []` (pre-first-part window). CR-04 hole: first sub-5-MiB buffered bytes on Node A are silently dropped on Node B resume. |
| `upload_maintenance.ex fetch_abortable_sessions/0` | aborted tus sessions with failed backing abort | Query selection | NOT WIRED | No query selects `(state == "aborted" AND resumable_protocol == "tus" AND not is_nil(multipart_upload_id))` with `failure_reason: nil`. The reaper's compensation path for the CR-01 abort-failure scenario does not exist. |

---

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| TUS-06 | 43-01, 43-02, 43-06 | `upload_part_stream/5` OPTIONAL callback; S3 one UploadPart per PATCH >= 5 MiB; sub-5-MiB tail buffer; `tus_tail_path/2` public helper | SATISFIED | `s3.ex:157-181` implements tail-buffer accumulate/drain; `tus_tail_path/2` at lines 253-255 is public and encoding-correct |
| TUS-07 | 43-01, 43-02 | Adapters advertise `:tus_upload` honestly; `TusPlug init/1` raises without capability | SATISFIED | S3 (line 234) + Local advertise `:tus_upload`; GCS does not; `tus_plug.ex:100-108` raises at `init/1` |
| TUS-08 | 43-01, 43-04 | Completion calls `complete_multipart_upload/4` then `verify_completion/2`; zero new completion vocabulary | SATISFIED | `tus_plug.ex:373-390` + `s3.ex:184-209` confirmed |
| TUS-09 | 43-01, 43-03, 43-05, 43-06..10 | tus sessions expire; DELETE terminates; reaper branches on resumable_protocol; MinIO zero-leak proof | BLOCKED | Timeout-expiry reaper path: FIXED and working. DELETE happy-path: FIXED. DELETE abort-failure path: permanently orphans (CR-01 OPEN). Cross-node resume pre-first-part: silently corrupts (CR-04 OPEN). MinIO proof: tests exist with correct structure but require human execution. |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/rindle/upload/tus_plug.ex` | 419-420 | Comment claims "the row still moves to aborted and the reaper compensates on the next cron" — false; no reaper query selects aborted+failure_reason:nil tus sessions | BLOCKER | False comment masks the unresolved CR-01 abort-failure path; creates false confidence in operators reading the code |
| `lib/rindle/upload/tus_plug.ex` | 445-463 | `abort_delete_backing/2` swallows `{:error, _}` and returns `:ok` unconditionally; row transitions to `aborted` with `failure_reason: nil` | BLOCKER | Any transient `abort_multipart_upload` failure at DELETE time permanently orphans the S3 multipart — the cost leak TUS-09 exists to close |
| `lib/rindle/ops/upload_maintenance.ex` | 158-176 | `fetch_retryable_abort_sessions/0` requires `like(failure_reason, "resumable_cancel_failed:%")`; nil never satisfies a LIKE predicate | BLOCKER | No reaper path re-selects a DELETE-terminated tus session whose abort failed; the orphaned multipart is never cleaned up |
| `lib/rindle/storage/s3.ex` | 289-298 | `guard_local_tail_present/2`: `mid_multipart? = ... and parts != []`; first sub-5-MiB PATCH sets upload_id but produces parts:[] | BLOCKER | A cross-node resume in the pre-first-part window bypasses the guard; first node's buffered bytes silently dropped; assembled object corrupted |

---

### Human Verification Required

#### 1. MinIO Integration Test Suite

**Test:** Set up a MinIO endpoint with RINDLE_MINIO_URL, RINDLE_MINIO_ACCESS_KEY, RINDLE_MINIO_SECRET_KEY env vars. Run: `mix test test/rindle/upload/tus_s3_integration_test.exs --include minio`

**Expected:**
- Test 1 (line 148): A >= 1 GiB tus upload over S3 backing survives drop+resume, converges into `verify_completion/2` with correct byte_size, and `list_multipart_uploads` returns empty for the abandoned session after reaper runs
- Test 2 (line 230): A tus DELETE on an S3-backed session (with a live committed part, not just upload_id) returns 204 and `list_multipart_uploads` returns empty for the deleted key
- Test 3 (line 280): After reaping an abandoned tus session, the on-disk tail file is removed

**Why human:** MinIO not available in this verification environment. Tests are tagged `@moduletag :minio` and excluded from the default `mix test` run. The test structure and assertions are correct, but actual execution against MinIO is required to confirm the happy path. Note: Test 2 directly exercises the CR-01 happy path (abort succeeds) but does not cover the abort-failure branch — that branch still has the open gap documented above.

---

### Gaps Summary

Two blockers prevent full phase goal achievement. CR-02 and CR-03 from the prior verification have been successfully closed. CR-01 and CR-04 were partially resolved but both remain open in their narrowed forms as confirmed by independent code reading.

**CR-01 (abort-failure path permanently orphans S3 multipart — defeats the cost-leak goal)**

`handle_delete/2` (`lib/rindle/upload/tus_plug.ex:412-439`) now correctly calls `abort_delete_backing/2` before the state transition — the happy-path DELETE no longer leaks. However, `abort_delete_backing/2` (lines 445-463) swallows `{:error, _}` from `abort_tus_backing/2` and unconditionally returns `:ok`. The session then moves to `state: "aborted"` with `failure_reason: nil`. The reaper's `fetch_retryable_abort_sessions/0` (upload_maintenance.ex:159-176) requires `like(failure_reason, "resumable_cancel_failed:%")` — nil never satisfies this SQL LIKE. `fetch_incomplete_timed_out_sessions/0` requires `state in ["signed","uploading"]` — never "aborted". The false comment at line 419-420 ("the reaper compensates on the next cron") gives a false assurance that is provably untrue. On any transient failure (network blip, throttling, MinIO restart) of `abort_multipart_upload` at DELETE time, the S3 multipart upload is orphaned permanently.

**CR-04 (pre-first-part cross-node resume silently corrupts the object)**

`guard_local_tail_present/2` (`lib/rindle/storage/s3.ex:289-298`) was added to detect cross-node resumes, but its `parts != []` condition leaves a real corruption window. On a first PATCH where the payload is < 5 MiB: `upload_id` is set and persisted, `parts: []` is persisted, the tail holds N MiB on Node A's disk. If the second PATCH is routed to Node B: the DB state shows `upload_id` set and `parts: []`, so `mid_multipart?` is false, the guard returns `:ok`, Node B opens a fresh empty tail, and Node A's bytes are permanently lost. The assembled object is corrupted with no error returned to the client. This is the exact silent corruption CR-04 was raised to prevent, confined to the (very common) sub-5-MiB first chunk case.

Both open gaps are directly confirmed in source code, not inferred from the review document.

---

_Verified: 2026-05-23T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
_Re-verification of prior gaps_found (3/5); CR-02 and CR-03 confirmed closed; CR-01 and CR-04 confirmed still open_
