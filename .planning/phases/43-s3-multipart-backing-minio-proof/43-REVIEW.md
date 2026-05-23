---
phase: 43-s3-multipart-backing-minio-proof
reviewed: 2026-05-23T00:00:00Z
depth: standard
files_reviewed: 14
files_reviewed_list:
  - lib/rindle/storage.ex
  - lib/rindle/storage/s3.ex
  - lib/rindle/storage/local.ex
  - lib/rindle/ops/upload_maintenance.ex
  - lib/rindle/upload/tus_plug.ex
  - config/test.exs
  - test/support/s3_multipart_request_stub.ex
  - test/rindle/storage/s3_tus_test.exs
  - test/rindle/storage/storage_adapter_test.exs
  - test/rindle/storage/local_tus_test.exs
  - test/rindle/storage/s3_test.exs
  - test/rindle/ops/upload_maintenance_test.exs
  - test/rindle/upload/tus_plug_test.exs
  - test/rindle/upload/tus_s3_integration_test.exs
findings:
  critical: 4
  warning: 6
  info: 4
  total: 14
status: issues_found
---

# Phase 43: Code Review Report

**Reviewed:** 2026-05-23
**Depth:** standard
**Files Reviewed:** 14
**Status:** issues_found

## Summary

Phase 43 adds S3 multipart backing for tus resumable uploads: a behaviour contract
(`upload_part_stream/5` + `complete_part_stream/4`), S3 + Local implementations, a
storage-agnostic Plug dispatch, and a reaper branch that aborts orphaned S3
multipart uploads. The slice/accumulate math in `S3.upload_part_stream` and the
Local path are sound, and the offset/409 contract in the Plug is correct.

However, the load-bearing **cost-leak mitigation — the stated headline of this
phase — has multiple holes that defeat its own purpose.** The two cleanup paths
the design relies on for residual S3 tail files and orphaned multipart uploads are
both broken: (1) the reaper's tail-file removal computes the wrong path and never
deletes the real file; (2) the generic `Rindle.tmp/` sweeper only deletes
*directories*, so the `tus/*.tail` and `tus/*.part` files it is claimed to "sweep
regardless" accumulate forever; and (3) a tus `DELETE` (Termination) sets the
session to `aborted` but never aborts the S3 multipart upload, and **no reaper
query ever picks up an aborted tus session** — so explicitly-cancelled S3-backed
uploads leak their multipart upload permanently. There is also an undocumented
node-local-disk assumption in the S3 tail buffer that silently corrupts a resume
routed to a different node.

These are the exact cost/correctness leaks the phase exists to close. The MinIO
integration test (`tus_s3_integration_test.exs`) only proves the *expired* reaper
path on a single node, so it does not catch any of CR-01..CR-04.

## Critical Issues

### CR-01: tus `DELETE` (Termination) leaks the S3 multipart upload permanently

**File:** `lib/rindle/upload/tus_plug.ex:385-403`, `lib/rindle/ops/upload_maintenance.ex:135-175,692-698`
**Issue:**
`handle_delete/2` transitions the session to `state: "aborted"` and returns 204,
but performs NO backing-store cleanup (no `abort_multipart_upload`). The comment
claims "the Rindle.tmp/ reaper sweeps the abandoned per-session backing files
regardless," but that only addresses local temp files, not the *remote* S3
multipart upload — which is the cost leak.

For the S3 multipart upload to ever be aborted, the session must be re-fetched by
`UploadMaintenance.abort_incomplete_uploads/1`. Trace the query set:

- `fetch_incomplete_timed_out_sessions/0` matches `state in ["signed","uploading"]`,
  resuming-resumable, or initialized-multipart. An `"aborted"` tus session matches
  none of these.
- `fetch_retryable_abort_sessions/0` matches `state == "aborted"` **but only when**
  `failure_reason LIKE "resumable_cancel_failed:%"`. A DELETEd tus session has
  `failure_reason: nil`, so it does NOT match.

Therefore a tus `DELETE` on an S3-backed upload **permanently orphans the S3
multipart upload** — the precise cost leak TUS-09 exists to close. (`resumable_abort_session?/1`
also returns `false` for `resumable_protocol: "tus"`, so even routing-wise it is
excluded.)

**Fix:** Abort the backing store inside `handle_delete/2` before/after the state
transition, polymorphically, e.g.:
```elixir
defp handle_delete(conn, opts) do
  with {:ok, payload} <- verify_token(conn, opts),
       {:ok, session} <- load_active_session(payload) do
    # Abort the S3 multipart (or remove Local tmp) so DELETE does not leak.
    _ = abort_backing(session, opts)

    session
    |> MediaUploadSession.changeset(%{state: "aborted"})
    |> Config.repo().update()
    # ... 204
  end
end
```
Reuse `Rindle.Ops.UploadMaintenance.abort_tus_backing/1` (extract it to a shared
helper). Alternatively, make `fetch_abortable_sessions/0` also pick up
`state == "aborted" and resumable_protocol == "tus" and multipart_upload_id not nil`
so the reaper compensates. Add a regression test asserting `abort_multipart_upload`
is invoked for a DELETEd tus session.

### CR-02: reaper's `remove_tus_tail/1` computes the wrong path — S3 tail file is never deleted

**File:** `lib/rindle/ops/upload_maintenance.ex:516-520` vs `lib/rindle/storage/s3.ex:405-413`
**Issue:**
The S3 adapter writes its tail buffer at a **base64-url-encoded** filename:
```elixir
# s3.ex
defp tail_path(key, opts) do
  base = Keyword.get(opts, :root) || Rindle.AV.TempRunDir.root_dir()
  id = Keyword.get(opts, :session_id) || key
  Path.join([base, "tus", tail_filename(id)])     # <base>/tus/<Base.url_encode64(id)>.tail
end
```
But the reaper removes a **raw, unencoded** path:
```elixir
# upload_maintenance.ex
defp remove_tus_tail(%MediaUploadSession{id: session_id}) do
  tail_path = Path.join([Rindle.AV.TempRunDir.root_dir(), "tus", session_id <> ".tail"])
  _ = File.rm(tail_path)   # never matches the real <Base.url_encode64(session_id)>.tail
  :ok
end
```
The reaper deletes `<root>/tus/<uuid>.tail`; the real file is
`<root>/tus/<Base.url_encode64(uuid)>.tail`. They never match, so the tail buffer
is never reaped here. Combined with CR-03 (the generic sweeper skips files), the S3
tail file is leaked on every reaped session.

**Fix:** Compute the path through the same encoding the adapter uses, or expose a
public helper on `Rindle.Storage.S3` and call it:
```elixir
# s3.ex
def tus_tail_path(session_id, opts \\ []),
  do: tail_path(session_id, Keyword.put_new(opts, :session_id, session_id))

# upload_maintenance.ex
defp remove_tus_tail(%MediaUploadSession{id: session_id}) do
  _ = File.rm(Rindle.Storage.S3.tus_tail_path(session_id))
  :ok
end
```

### CR-03: the `Rindle.tmp/` sweeper only deletes directories — `tus/*.tail` and `tus/*.part` files leak forever

**File:** `lib/rindle/ops/sweep_orphaned_temp_files.ex:74-92` (depended on by `s3.ex:184`, `tus_plug.ex:392-394`, `upload_maintenance.ex:491-492,507-514`)
**Issue:**
Multiple sites in this phase justify "best-effort" cleanup with the claim that the
`Rindle.tmp/` reaper "sweeps any residue." It does not. `process_run_dir/4` only
acts on entries whose `lstat` reports `type: :directory`:
```elixir
case File.lstat(path) do
  {:ok, %File.Stat{type: :directory, mtime: mtime}} -> ...   # only dirs are eligible
  {:ok, _stat} -> acc                                        # FILES are ignored, never deleted
  ...
end
```
The S3 tail files and Local part files live at `<Rindle.tmp>/tus/<id>.tail` and
`<Rindle.tmp>/tus/<id>.part`. The sweeper iterates the entries directly under
`<Rindle.tmp>` and sees `tus` as a single directory. It will `rm_rf` the *entire*
`tus/` directory only once its mtime crosses the age threshold — but `tus/`'s mtime
is bumped every time any session writes a new tail/part file, so on any active
system the `tus/` directory mtime is perpetually fresh and is never swept. The
backing files inside therefore accumulate without bound. This invalidates the
cleanup guarantee that S3 `complete_part_stream` (`s3.ex:184` best-effort `File.rm`
only covers the happy path), the tus `DELETE` handler, and the reaper all rely on.

**Fix:** Either (a) sweep aged regular files under `Rindle.tmp/` (and recurse into
`tus/`), or (b) make all backing-file cleanup explicit at end-of-life (CR-01 +
CR-02) and stop relying on the sweeper for `tus/*` files. Recommend both: explicit
cleanup as primary, plus extending the sweeper to age out individual files in
`tus/` as a safety net. Add a test that creates an aged `tus/<id>.tail` file and
asserts the sweeper removes it.

### CR-04: S3 tail buffer is node-local disk state but session state is shared — resume on another node corrupts the object

**File:** `lib/rindle/storage/s3.ex:140-191,405-413`; `lib/rindle/upload/tus_plug.ex:264-270,317-325`
**Issue:**
The cross-PATCH multipart bookkeeping (`offset`, `multipart_upload_id`, `parts`) is
persisted in the shared DB (`persist_offset/2`), but the **sub-5-MiB tail remainder
is held only on local disk** at `<Rindle.tmp>/tus/<encoded_session_id>.tail`. There
is no node-affinity guard and no documentation of a single-node assumption anywhere
in the adapter, the Plug, or the moduledocs.

In any multi-node deployment behind a load balancer, a resumed PATCH can land on a
different BEAM node. That node reads the authoritative `offset`/`parts`/`upload_id`
from the DB (so the 409 offset gate passes), then `append_to_tail/2` opens a fresh
empty tail file and `drain_tail_parts` slices parts from the wrong byte boundary.
The leftover bytes from the previous node's tail are silently lost, and the
assembled object is corrupted — with no error surfaced to the client (HEAD reports
the committed offset, completion succeeds, `verify_completion` only checks size via
HEAD which can still match if byte counts coincidentally align, or fails opaquely
otherwise).

This is a silent data-integrity failure on the resume path, which is the entire
point of tus. At minimum it must be guarded or documented; ideally the residual
tail should be reconstructable from shared state.

**Fix:** Pick one and make it explicit:
- Document and enforce a single-node (sticky-session) deployment constraint for the
  S3 tus backing, and fail loudly when a PATCH arrives with `parts`/`upload_id` in
  the DB but no tail file present at the expected offset boundary (instead of
  silently re-slicing from zero).
- Or persist the residual tail bytes in shared storage (e.g. a dedicated S3 object
  or DB blob) so any node can resume correctly.
Add a test that simulates a resume with the tail file absent and asserts a loud
error rather than a corrupted assembly.

## Warnings

### WR-01: tus reaper bypasses the `UploadSessionFSM` gate that the standard path enforces

**File:** `lib/rindle/ops/upload_maintenance.ex:464-487` vs `lib/rindle/ops/upload_maintenance.ex:414-431`
**Issue:**
`expire_standard_session/2` deliberately gates the state change on
`UploadSessionFSM.transition(session.state, "expired", ...)` and the comment
(lines 414-417) states this exists "so any future expansion of the query set ... is
caught at the invariant boundary instead of silently violating the FSM contract."
`do_expire_tus_session/2` (and the resumable path) skip this gate and call
`MediaUploadSession.changeset(session, %{state: "expired"})` directly. Today
`signed → expired` is legal, but the tus path loses the same forward-compatibility
guard the standard path is documented to provide, so a future query-set expansion
could silently flip a tus session from a state the FSM forbids.

**Fix:** Route `do_expire_tus_session/2` through the FSM gate as
`expire_standard_session/2` does, or extract a shared gated-expire helper used by
all three branches.

### WR-02: `handle_delete/2` ignores the result of the session `update`

**File:** `lib/rindle/upload/tus_plug.ex:388-390`
**Issue:**
```elixir
session
|> MediaUploadSession.changeset(%{state: "aborted"})
|> Config.repo().update()    # result discarded
```
If the update fails (validation error, DB error, stale row), the client still
receives `204` and believes the upload was terminated, while the row remains in its
prior state. The session can then be re-PATCHed or mis-reaped. Other persist sites
in this module (`persist_offset/2`, `sign_and_persist/4`) handle the `{:error, _}`
branch; this one does not.

**Fix:** Match on the update result and return a 5xx (or log) when it fails:
```elixir
case session |> MediaUploadSession.changeset(%{state: "aborted"}) |> Config.repo().update() do
  {:ok, _} -> conn |> put_tus_resumable() |> send_resp(204, "") |> halt()
  {:error, _} -> tus_error(conn, 500, "")
end
```

### WR-03: partial-failure between `UploadPart` and tail-truncate can duplicate a part on retry

**File:** `lib/rindle/storage/s3.ex:261-288`
**Issue:**
In `drain_tail_parts/7`, a part is uploaded (`upload_one_part`) and only then is the
tail truncated (`truncate_tail_head`). If `truncate_tail_head/2` fails (or the node
crashes between the two), the part is already committed to S3 but the 5 MiB slice
remains at the head of the tail file. `upload_part_stream/5` returns `{:error, _}`,
so the Plug does not advance the offset; the tus client retries the same PATCH at
the same offset (200, offset matches), `append_to_tail` re-appends, and
`drain_tail_parts` re-slices and re-uploads the same byte range as a *new* part
number — duplicating data in the assembled object.

**Fix:** Make the slice idempotent: truncate the tail to a staging file first and
upload from the staged slice, only committing the truncation after a confirmed
`UploadPart`, and on retry detect/skip an already-uploaded byte range (e.g. by
recording bytes-consumed alongside `parts`). At minimum, document the failure mode
and add a test that injects a truncate failure and asserts no duplicate part.

### WR-04: `:next_part_number` is computed and returned but never persisted — dead/misleading bookkeeping

**File:** `lib/rindle/storage/s3.ex:154-159,397-399`; `lib/rindle/upload/tus_plug.ex:317-325`
**Issue:**
`upload_part_stream/5` puts `:next_part_number` into the returned state, and
`next_part_number/1` prefers it. But `persist_offset/2` in the Plug only persists
`last_known_offset`, `multipart_upload_id`, and `multipart_parts`; `prior_state/1`
rebuilds state without `:next_part_number`. So across PATCHes the persisted-counter
clause (`s3.ex:397`) is never reached — the value always falls through to
`length(parts) + 1`. The persisted counter is dead code that implies a durability
guarantee it does not have. It happens to be correct only because `length(parts)+1`
coincides; if part accounting ever diverges from list length the two disagree
silently.

**Fix:** Remove `:next_part_number` from the returned state and the
persisted-counter clause, deriving the next number solely from `length(parts) + 1`;
or actually persist it through `persist_offset/2`/`prior_state/1`. Do not keep a
phantom counter.

### WR-05: `upload_one_part/6` `with/else` cannot match a non-binary, non-nil ETag

**File:** `lib/rindle/storage/s3.ex:376-393`
**Issue:**
```elixir
with {:ok, response} <- request(...),
     etag when is_binary(etag) <- etag_from_headers(response) do
  {:ok, %{part_number: part_number, etag: etag}}
else
  nil -> {:error, :missing_etag}
  {:error, reason} -> {:error, reason}
end
```
`etag_from_headers/1` returns whatever `Map.get(headers_map, "etag")` yields. If a
provider returns a list-valued or otherwise non-binary, non-nil ETag header, the
guard fails but the value is neither `nil` nor `{:error, _}`, so no `else` clause
matches and the `with` raises `WithClauseError` (a 500 crash rather than a tagged
error). Robustness gap at an S3-provider boundary.

**Fix:** Add a catch-all else clause: `other -> {:error, {:unexpected_etag, other}}`,
and/or normalize header values to a binary in `etag_from_headers/1`.

### WR-06: `normalize_parts/1` has no fallback clause and crashes on a malformed part entry

**File:** `lib/rindle/storage/s3.ex:426-432`
**Issue:**
```elixir
defp normalize_parts(parts) do
  Enum.map(parts, fn
    %{part_number: pn, etag: e} -> {pn, e}
    %{"part_number" => pn, "etag" => e} -> {pn, e}
    {pn, e} -> {pn, e}
  end)
end
```
The accumulated parts come from `multipart_parts` (a `:map` column) round-tripped
through the DB and unwrapped by `decode_parts/1`. JSON serialization can return
string keys/values that don't match either map shape (e.g. a part missing `etag`,
or numeric `part_number` decoded as a string), producing a `FunctionClauseError`
that crashes completion instead of returning a tagged error. The data crosses a
serialization boundary (DB `:map`), so the input shape is not fully controlled.

**Fix:** Add a fallback clause that returns/raises a tagged error
(`other -> raise ... ` is still a crash; prefer surfacing `{:error, {:invalid_part, other}}`
by validating before `complete_multipart_upload`), and assert the persisted/decoded
part shape in a unit test.

## Info

### IN-01: `read_leading_part/1` can return `{:ok, ""}` and upload an empty part

**File:** `lib/rindle/storage/s3.ex:313-329,263-267`
**Issue:** The `:eof -> {:ok, ""}` branch can, under a TOCTOU shrink between
`File.stat` and the read, feed an empty body into `upload_one_part`, issuing a
zero-byte `UploadPart`. Low likelihood (single-process tail writer), but the empty
slice should be guarded rather than uploaded.
**Fix:** Treat `{:ok, ""}` / `:eof` in `drain_tail_parts` as "no part this pass"
and stop recursing.

### IN-02: `next_part_number/1` clause ordering relies on map-key precedence, not documented

**File:** `lib/rindle/storage/s3.ex:397-399`
**Issue:** The three-clause function silently depends on `:next_part_number` taking
precedence over `:parts`. With WR-04's dead persisted counter, this ordering is a
latent footgun if both keys ever disagree.
**Fix:** Collapse to a single derivation (see WR-04) and drop the multi-clause
ambiguity.

### IN-03: Local `abort_tus_backing/1` resolves the wrong root when removing the part file

**File:** `lib/rindle/ops/upload_maintenance.ex:510-514`
**Issue:** `File.rm(Rindle.Storage.Local.tus_part_path(session.id, []))` passes empty
opts, so the part path resolves against the *default/app-env* Local root rather than
the root the upload actually used. In production with a configured app-env root this
happens to align, but tests and any per-profile root override will miss the file.
This mirrors the encoding mismatch class of CR-02.
**Fix:** Resolve the Local root from the session's profile/adapter config (the same
resolution `resolve_tus_adapter/1` performs) rather than `[]`.

### IN-04: integration coverage does not exercise the broken cleanup paths

**File:** `test/rindle/upload/tus_s3_integration_test.exs:189-208`
**Issue:** The "zero multipart leak" assertion only covers a session expired via
`expires_at` then reaped through `abort_incomplete_uploads/1` — the one path that
works. It does not cover (a) tus `DELETE` (CR-01), (b) tail-file removal after
reaping (CR-02/CR-03), or (c) a resume across nodes (CR-04). The test gives false
confidence that the cost leak is closed.
**Fix:** Add `:minio` cases for the DELETE-then-list-multipart-uploads path and for
asserting the `tus/*.tail` file is gone after a reap, and a unit-level guard for the
cross-node resume.

---

_Reviewed: 2026-05-23_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
