---
phase: 43-s3-multipart-backing-minio-proof
reviewed: 2026-05-23T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - lib/rindle/storage/s3.ex
  - lib/rindle/ops/sweep_orphaned_temp_files.ex
  - lib/rindle/ops/upload_maintenance.ex
  - lib/rindle/upload/tus_plug.ex
findings:
  critical: 2
  warning: 4
  info: 3
  total: 9
status: issues_found
---

# Phase 43: Code Review Report (gap-closure re-review)

**Reviewed:** 2026-05-23
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

This is a re-review verifying the four prior blockers (CR-01 DELETE never aborted
the backing multipart; CR-02 tail-path encoding mismatch; CR-03 tmp sweeper only
deleted directories; CR-04 cross-node resume corruption) and surfacing any NEW
issues introduced by the gap fixes.

Verification result, blocker by blocker:

- **CR-02 (tail-path encoding) — RESOLVED.** `remove_tus_tail/2` now delegates to
  the adapter's own canonical `S3.tus_tail_path/2`, which routes through the same
  private `tail_path/2` + `tail_filename/1` (`Base.url_encode64(id) <> ".tail"`) the
  write path uses. The encoding now matches on both sides, and the root threads
  through consistently for S3 (both write and abort resolve `nil → TempRunDir`).
- **CR-03 (directory-only sweeper) — RESOLVED for `tus/`.** `process_run_dir/4`
  now special-cases `Path.basename(path) == "tus"` and recurses via
  `sweep_tus_dir/4` to age out individual regular files. Symlinks/nested dirs are
  correctly skipped (`type: :regular` guard).
- **CR-01 (DELETE leaks multipart) — PARTIALLY RESOLVED → still a BLOCKER (CR-01
  below).** The happy path is fixed: `handle_delete/2` aborts the backing FIRST,
  then transitions. BUT the handler's own comment promises "the row still moves to
  aborted and the reaper compensates on the next cron" — and **no reaper query ever
  picks up an `aborted` tus session with `failure_reason: nil`**. So when the
  DELETE-time abort fails transiently, the multipart upload is orphaned PERMANENTLY,
  with no compensation. The cost leak the phase exists to close is still open on the
  abort-failure branch.
- **CR-04 (cross-node resume corruption) — PARTIALLY RESOLVED → still a BLOCKER
  (CR-02 below).** A loud `:tus_tail_missing` guard was added, but it only fires
  when `parts != []`. A cross-node resume during the FIRST 5 MiB of an upload (an
  `upload_id` exists but no part has been committed yet, so `parts == []`) bypasses
  the guard entirely and silently re-slices from an empty tail — the exact silent
  data corruption CR-04 was raised to prevent.

New issues introduced by the gap fixes are recorded as WR-01 (tail removed before
the multipart abort — irreversible local-state loss on a recoverable error), WR-02
(reaper Local-root resolution still ignores per-mount root — IN-03 only half
fixed), WR-03 (FSM `aborted` is a terminal state, so the new shared `gated_expire`
silently counts any future-routed aborted tus session as an error), and the sweeper
metric-naming / `.patch`-residue observations.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: DELETE-time backing-abort failure permanently orphans the S3 multipart — the reaper does NOT compensate

**File:** `lib/rindle/upload/tus_plug.ex:412-463`, `lib/rindle/ops/upload_maintenance.ex:158-188`
**Issue:**
`handle_delete/2` now aborts the backing before the state transition (good), but the
abort is best-effort and swallowed:

```elixir
# tus_plug.ex
abort_delete_backing(session, opts)   # logs+returns :ok even on {:error, _}
session
|> MediaUploadSession.changeset(%{state: "aborted"})
|> Config.repo().update()             # → 204 on success
```

`abort_delete_backing/2` returns `:ok` even when `abort_tus_backing/2` returns
`{:error, reason}` (tus_plug.ex:451-462). The handler comment (lines 419-420)
justifies this with "the row still moves to aborted and the reaper compensates on
the next cron." Trace the reaper's query set to confirm whether that compensation
actually exists:

- `fetch_incomplete_timed_out_sessions/0` (upload_maintenance.ex:136-156) matches
  `state in ["signed","uploading"]`, resuming-resumable, or initialized-multipart.
  An `aborted` tus session matches NONE of these.
- `fetch_retryable_abort_sessions/0` (upload_maintenance.ex:159-176) matches
  `state == "aborted"` ONLY when `not is_nil(session_uri)` AND
  `failure_reason LIKE "resumable_cancel_failed:%"`.

A DELETEd tus session has `state: "aborted"` and `failure_reason: nil` (the DELETE
changeset at tus_plug.ex:426-427 sets only `state`). It therefore matches neither
query. The "compensation on the next cron" the comment relies on does not exist:
when the DELETE-time `abort_multipart_upload` call fails for any transient reason
(network blip, throttling, MinIO restart), the S3 multipart upload is orphaned
**permanently** — the precise cost leak this phase exists to close.

This is the same root defect as the prior CR-01 (no reaper query covers aborted tus
sessions), now narrowed to the abort-failure branch instead of every DELETE.

**Fix:** Make the DELETE durable against a failed abort. Either:
1. Honour the abort result — if `abort_tus_backing/2` returns `{:error, _}`, persist
   a retryable marker (e.g. `failure_reason: "tus_abort_failed:..."`) so a reaper
   query can re-find it, AND extend `fetch_abortable_sessions/0` with a clause that
   picks up `state == "aborted" and resumable_protocol == "tus" and
   not is_nil(multipart_upload_id)`; or
2. Do NOT move the row to `aborted` when the abort failed — leave it in its prior
   (signed/uploading) state so the existing `fetch_incomplete_timed_out_sessions/0`
   reaps it once `expires_at` passes, and return a 5xx so the client retries.

Add a regression test that injects an `abort_multipart_upload` failure on DELETE and
asserts the session is later re-found and re-aborted by `abort_incomplete_uploads/1`.

### CR-02: cross-node resume during the first <5 MiB silently corrupts the object — the `tus_tail_missing` guard has a `parts == []` hole

**File:** `lib/rindle/storage/s3.ex:274-299,157-181`
**Issue:**
The new cross-node guard only triggers on a mid-multipart resume that has ALREADY
committed at least one part:

```elixir
mid_multipart? =
  is_binary(upload_id) and upload_id != "" and is_list(parts) and parts != []

if mid_multipart? and not File.exists?(tail_path), do: {:error, :tus_tail_missing}, else: :ok
```

The `parts != []` clause is deliberate (comment lines 282-284: avoid a false
positive on a brand-new first write). But it leaves a real silent-corruption window
whenever an upload's first chunk(s) total LESS than 5 MiB. Trace it:

1. Node A receives the first PATCH (3 MiB). `ensure_upload_id` initiates the
   multipart → `upload_id` is now set and persisted. `append_to_tail` writes 3 MiB
   to the node-local tail. `drain_tail_parts` sees 3 MiB < 5 MiB → returns
   `parts: []`. Persisted state: `upload_id` set, `parts: []`, `offset: 3 MiB`. The
   3 MiB tail lives ONLY on Node A's disk.
2. The resume PATCH (next 3 MiB) is routed to Node B. The DB shows `upload_id` set,
   `parts: []`, `offset: 3 MiB`, so the 409 offset gate passes.
3. `guard_local_tail_present`: `parts == []` ⇒ `mid_multipart?` is `false` ⇒ guard
   returns `:ok` — no loud failure. `append_to_tail` opens a FRESH empty tail on
   Node B and appends the new 3 MiB. Node A's first 3 MiB is silently dropped.
4. Offset is advanced to 6 MiB and persisted; completion later flushes a tail that
   is missing the first 3 MiB. The assembled object is corrupted with no error.

This is exactly the silent re-slice-from-empty-tail corruption CR-04 was raised to
prevent — just confined to the (very common) case where the first node had buffered
less than one full part. The guard closes the leak only AFTER the first 5 MiB
boundary is crossed.

**Fix:** Strengthen the guard so the node-local tail is required whenever the DB
state implies bytes were buffered on another node, not only after a part commits.
A robust signal is "the persisted `offset` is greater than the bytes already
committed as parts" (i.e. there is an expected non-empty tail). For example, treat a
resume as mid-multipart when `is_binary(upload_id) and upload_id != "" and offset >
committed_part_bytes` (where `committed_part_bytes = length(parts) * @s3_min_part_size`),
and fail with `:tus_tail_missing` if the tail file is absent. A simpler conservative
guard: when `upload_id` is set and `base_offset > 0`, require the tail file to exist.
Add a unit test that simulates a resume with `upload_id` set, `parts: []`,
`offset > 0`, and the tail file absent, asserting `{:error, :tus_tail_missing}`
rather than a corrupted assembly.

## Warnings

### WR-01: `abort_tus_backing/2` deletes the node-local tail BEFORE aborting the multipart — recoverable error leaves unrecoverable local-state loss

**File:** `lib/rindle/ops/upload_maintenance.ex:523-548`
**Issue:**
```elixir
def abort_tus_backing(%MediaUploadSession{} = session, opts) when is_list(opts) do
  ...
  remove_tus_tail(session, root)        # (1) tail deleted unconditionally, first
  case upload_id do
    id when is_binary(id) and id != "" ->
      adapter = Keyword.fetch!(opts, :adapter)
      case adapter.abort_multipart_upload(...) do   # (2) may return {:error, _}
        {:error, _reason} = err -> err
        ...
```

The local tail buffer is removed first and unconditionally; only afterward is the
remote multipart abort attempted. When the abort returns `{:error, _}` (the retry
path both the reaper and — per CR-01 — the DELETE handler depend on), the tail file
is already gone. The ordering pairs a recoverable remote failure with an
irreversible local mutation, which is the wrong direction for a best-effort/retry
sequence: the cheap always-safe-to-repeat step (tail `File.rm`) should run last, not
first. If any retry or future reconciliation ever needs the residual tail after a
failed remote abort, it is unavailable. (Today the reaper's expiry path retries the
remote abort fine on the next cron, but the tail is already destroyed.)

**Fix:** Abort the remote multipart FIRST; remove the local tail only after the
remote abort succeeds (or is idempotently `:not_found`). On a remote `{:error, _}`,
leave the tail in place and surface the error so the retry still has it.

### WR-02: reaper's Local-backed cleanup resolves `Local.root([])`, ignoring the per-mount root the upload actually used (IN-03 only half fixed)

**File:** `lib/rindle/ops/upload_maintenance.ex:571-579,497-500`
**Issue:**
`resolve_local_root/1` discards the session and returns `Rindle.Storage.Local.root([])`:

```elixir
defp resolve_local_root(_session) do
  Rindle.Storage.Local.root([])
end
```

`Local.root([])` resolves to the app-env `:root` (or the system tmp fallback), NOT
the per-mount root an adopter may have passed to `TusPlug.init` (`forward ...,
root: "/custom"`). The Local WRITE path uses the Plug's `opts[:root]`
(`call_opts/2` threads `root: opts[:root]` = `Local.root(init_opts)`), and the
DELETE path now correctly threads `opts[:root]` too — but the REAPER path
(`abort_tus_backing/1` for the Local branch → `resolve_local_root/1`) still computes
a root from empty opts. When an adopter mounts with a non-default `:root`, the
reaper's `File.rm` of `tus_part_path(session.id, [root: Local.root([])])` targets the
wrong directory and misses the file. The prior IN-03 asked to "resolve the Local
root from the session's profile/adapter config"; this fix improved the DELETE path
but the reaper path is unchanged. The new `tus/`-recursing sweeper (CR-03) is the
only thing that eventually reaps these, so it is not a permanent leak, but the
explicit end-of-life cleanup the design calls "primary" still misses.

**Fix:** Resolve the Local root from the same source the write path used. If the
per-mount root is not recoverable from the session row, document that Local tus
explicitly relies on the sweeper for part-file cleanup and drop the misleading
explicit `File.rm`; otherwise thread the profile/mount root through so the explicit
delete hits the real file.

### WR-03: `gated_expire/2` routes through the FSM, but `aborted` is a terminal state — a future query-set expansion silently counts aborted tus sessions as errors, never expiring them

**File:** `lib/rindle/ops/upload_maintenance.ex:424-438,455-472`, `lib/rindle/domain/upload_session_fsm.ex:6-17`
**Issue:**
The prior-WR-01 fix correctly routes BOTH the standard and tus expiry branches
through the shared `gated_expire/2`, which gates on
`UploadSessionFSM.transition(session.state, "expired", ...)`. That is the right
invariant boundary. But the FSM declares `"aborted" => []` (a terminal state with no
outgoing transitions). The combined abortable query (`fetch_abortable_sessions/0`)
unions `fetch_retryable_abort_sessions/0`, which selects `state == "aborted"` rows.
Those are routed to `expire_resumable_session/2` today (not `gated_expire`), so they
are safe NOW — but the documented purpose of the FSM gate (comment lines 419-423) is
to catch FUTURE query-set expansions. If a future change ever routes an `aborted`
tus session into `gated_expire` (e.g. a new "retryable aborted tus" query — exactly
what CR-01's fix #1 proposes), the gate will reject `aborted → expired`, log
`session_expiry_invalid_transition`, increment `:abort_errors`, and the session will
be retried forever — never reaching `expired`, never cleaned up by `cleanup_orphans/1`
(which selects `state == "expired"`). The gate converts a silent FSM violation into a
silent infinite-retry. This interacts directly with the recommended CR-01 fix and
must be reconciled.

**Fix:** Decide the lifecycle for an aborted-but-backing-still-present tus session
explicitly. Either add `"aborted" => ["expired"]` to the FSM (if expiring an aborted
session is legitimate), or have the reaper clean up aborted tus sessions WITHOUT a
state transition (abort the backing, then `repo.delete` the row, mirroring
`cleanup_orphans/1`), so `gated_expire` is never asked to perform an illegal
transition. Pair this decision with the CR-01 fix.

### WR-04: `remove_tus_tail/2` is unconditionally invoked for Local-backed sessions, computing an S3-style base64url path that never exists for Local

**File:** `lib/rindle/ops/upload_maintenance.ex:527-528,559-564`
**Issue:**
`abort_tus_backing/2` always calls `remove_tus_tail(session, root)` regardless of
backing type, and `remove_tus_tail/2` computes `S3.tus_tail_path(session_id, ...)`
(the base64url `.tail` path). For a Local-backed tus session there is no `.tail`
file — Local writes a raw `<root>/tus/<session_id>.part` (see `Local.tus_part_path/2`).
So for every Local DELETE/expiry, an extra `File.rm` runs against a non-existent
base64url path. It is harmless (`File.rm` of a missing file is ignored, return
swallowed), but it is dead/misleading work that couples the Local cleanup path to
the S3 adapter's encoding and obscures intent. The actual Local part-file removal
happens separately in the `_ ->` branch (line 545). A reader cannot tell from
`abort_tus_backing/2` that the leading `remove_tus_tail` is a no-op for Local.

**Fix:** Only remove the S3 tail in the S3 (`upload_id` present) branch; in the
Local branch remove only the `.part` file. Keep the tail removal scoped to the
backing that actually creates a tail.

## Info

### IN-01: sweeper reuses `run_dirs_scanned` / `run_dirs_deleted` counters for individual tus FILES — misleading metrics

**File:** `lib/rindle/ops/sweep_orphaned_temp_files.ex:122-167`
**Issue:** `sweep_tus_dir/4` increments `run_dirs_scanned` once for the `tus/`
directory (line 123), and `delete_tus_file/3` increments BOTH `orphan_count` and
`run_dirs_deleted` per aged FILE (line 162). The `run_dirs_deleted` field now
conflates "run directories rm_rf'd" with "individual tus files removed," and the
telemetry/`Logger.info` report (lines 45-63) emits the blended number. An operator
reading `run_dirs_deleted: 7` cannot tell whether 7 run dirs or 7 tus files were
reaped. Observability drift, not a correctness bug.
**Fix:** Add dedicated `tus_files_scanned` / `tus_files_deleted` counters to the
`report` type and telemetry, and stop overloading the run-dir fields for per-file
accounting.

### IN-02: per-PATCH `.patch` temp files live directly under `<root>` (not under `tus/`), so the sweeper still cannot age them out

**File:** `lib/rindle/upload/tus_plug.ex:240-264,397-399`; `lib/rindle/ops/sweep_orphaned_temp_files.ex:89-116`
**Issue:** `stream_append/4` writes `<root>/<session_id>.patch` (via `tus_tmp_dir/1`
= `opts[:root] || TempRunDir.root_dir()`) — directly under the sweep root, NOT under
`tus/`. `process_run_dir/4` only recurses into `tus/`; any other regular file
directly under root hits the `{:ok, _stat} -> acc` clause and is never reaped. The
`.patch` file is normally removed in `stream_append/4`'s `after` block, so this only
matters if that `File.rm` is skipped (hard crash mid-PATCH). Lower likelihood than
the `tus/` leak CR-03 closed, but the same class and uncovered by the sweeper. (Note
`truncate_tail_head/2`'s `<...>.tail.rest` files live INSIDE `tus/` at s3.ex:402,
which the sweeper DOES cover.)
**Fix:** Place the per-PATCH temp file under `<root>/tus/` (so the new recursion
covers it) or have the sweeper also age out aged regular files directly under the
root.

### IN-03: `read_leading_part/1` `:eof -> {:ok, ""}` can still feed an empty body to `upload_one_part` under a TOCTOU shrink

**File:** `lib/rindle/storage/s3.ex:378-395,327-354`
**Issue:** Unchanged from the prior IN-01. `drain_tail_parts/7` enters the slice
branch on `File.stat` size `>= @s3_min_part_size`, then `read_leading_part/1` reads;
if the file shrank between stat and read, the `:eof -> {:ok, ""}` branch yields an
empty binary that `upload_one_part` would `UploadPart` as a zero-byte part. Very low
likelihood (single-process tail writer), but the empty slice is uploaded rather than
skipped.
**Fix:** In `drain_tail_parts/7`, treat an empty/`:eof` read as "no part this pass"
and stop recursing instead of issuing a zero-byte `UploadPart`.

---

_Reviewed: 2026-05-23_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
