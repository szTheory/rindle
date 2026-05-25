---
phase: 43-s3-multipart-backing-minio-proof
reviewed: 2026-05-23T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - lib/rindle/storage/s3.ex
  - lib/rindle/ops/upload_maintenance.ex
  - lib/rindle/upload/tus_plug.ex
findings:
  critical: 0
  warning: 2
  info: 3
  total: 5
status: issues_found
---

# Phase 43: Code Review Report (Gap-Closure Re-Execution)

**Reviewed:** 2026-05-23
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Adversarial re-review of the gap-closure diff `03ad287..HEAD` (commits 90f70ea,
6a4cd1c, 9f3fe75) closing CR-04 (s3.ex cross-node tail guard) and CR-01
(upload_maintenance.ex reaper re-abort + tus_plug.ex DELETE abort-failure
marker). Scope was strictly the changed regions of the three source files; the
prior round's CR-02/CR-03 findings and the unrelated
`sweep_orphaned_temp_files.ex` file are out of scope and not re-reviewed.

The gap-closure logic is largely sound. I traced the three core mechanisms end
to end:

1. **CR-04 (s3.ex `guard_local_tail_present/3`)** — The new
   `offset > committed_part_bytes` signal is logically correct. Because
   `drain_tail_parts/7` slices exactly `@s3_min_part_size` per non-final part,
   `committed_part_bytes = length(parts) * @s3_min_part_size` is an exact account
   of bytes covered by committed parts, so `offset > committed_part_bytes` is
   equivalent to "a non-empty tail was buffered." The pre-first-part hole
   (`parts: []`, `offset > 0`) is correctly closed and the `offset == 0` first
   PATCH is correctly NOT guarded. `base_offset` is threaded from
   `session.last_known_offset` (pre-PATCH offset), which is the correct value for
   this check. No false positive on the freshly-sliced boundary
   (`offset == committed_part_bytes`).

2. **CR-01 reaper half (upload_maintenance.ex)** — The new
   `fetch_retryable_tus_abort_sessions/0` query, the `settle_tus_abort_success/2`
   dispatch, and `persist_tus_abort_retry_success/2` correctly avoid the
   FSM-forbidden `aborted -> expired` infinite-retry trap. The changeset only
   does `validate_inclusion(:state, @states)` (no FSM gate), so the deliberate
   FSM-bypass on the retry-success path works and clears the marker, removing the
   row from re-selection. `{:error, :not_found}` re-abort is treated as
   idempotent success. Compiles clean with `--warnings-as-errors`.

3. **CR-01 marker half (tus_plug.ex)** — `abort_delete_backing/2` now returns
   `%{failure_reason: nil | "tus_abort_failed:<reason>"}` folded into the aborted
   changeset. The marker prefix matches the reaper's
   `like(..., "tus_abort_failed:%")` predicate byte-for-byte. `tus_abort_marker/1`
   correctly bounds the reason (atom verbatim, else `transport`) and
   `not is_nil(reason)` correctly excludes `nil` (which is an atom in Elixir).

No BLOCKER-tier defects were found in the gap-closure diff. Two WARNING-tier and
three INFO-tier findings follow.

## Warnings

### WR-01: Local-backed tus abort failures stamp a marker the reaper can never re-select

**File:** `lib/rindle/ops/upload_maintenance.ex:188-205` (query) and
`lib/rindle/upload/tus_plug.ex:459-477` (marker write)
**Issue:** The reaper's re-discovery query requires
`where: not is_nil(s.multipart_upload_id)`. For a **Local-backed** tus session
`multipart_upload_id` is `nil`, so a Local-backed row stamped with a
`tus_abort_failed:%` marker can never be re-selected by
`fetch_retryable_tus_abort_sessions/0`.

In current code this is benign because `abort_tus_backing/2`'s Local branch does
`File.rm(...)` and unconditionally returns `:ok`
(`lib/rindle/ops/upload_maintenance.ex:639-640`), so the DELETE handler never
writes a marker for a Local session and the reaper's `abort_tus_backing/1` Local
clause also returns `:ok`. The orphan condition is presently unreachable. The
risk is latent: if a future change makes the Local abort path return
`{:error, _}` (e.g. surfacing a real `File.rm` failure to enforce cleanup), the
marker would be written but the row would be permanently invisible to the
reaper — exactly the silent-orphan failure mode CR-01 set out to eliminate,
reintroduced for the Local backing.
**Fix:** Either document the coupling at the marker write site (the marker is only
recoverable when `multipart_upload_id` is non-nil), or broaden the re-discovery
predicate so Local-backed retry rows stay re-selectable:
```elixir
from(s in MediaUploadSession,
  where: s.state == "aborted",
  where: s.resumable_protocol == "tus",
  where: like(s.failure_reason, "tus_abort_failed:%"),
  # drop the multipart_upload_id NOT NULL filter (or OR-branch a Local case)
  # so a future failing Local abort stays recoverable
  select: s
)
```

### WR-02: `guard_local_tail_present/3` drops the prior `is_list(parts)` defense before `length/1`

**File:** `lib/rindle/storage/s3.ex:312-320`
**Issue:** The pre-diff guard tested `is_list(parts) and parts != []`. The new
guard computes `committed_part_bytes = length(parts) * @s3_min_part_size`
unconditionally. `length/1` raises `ArgumentError` on a non-list argument. The
current callers (`prior_state/1` via `decode_parts/1`, and
`Map.get(state, :parts, [])`) always yield a list, so this is not currently
triggerable, but the guard lost the defensive type check it previously carried
while simultaneously taking on a list-only operation (`length/1`). A malformed
persisted `multipart_parts` map reaching this path would now crash with an opaque
`ArgumentError` instead of falling through safely.
**Fix:** Restore the list guard before computing the byte count:
```elixir
parts = Map.get(state, :parts, [])
parts = if is_list(parts), do: parts, else: []
committed_part_bytes = length(parts) * @s3_min_part_size
```

## Info

### IN-01: GCS retryable-abort query can cross-route a tus session (pre-existing, adjacent to diff)

**File:** `lib/rindle/ops/upload_maintenance.ex:159-176`
**Issue:** `fetch_retryable_abort_sessions/0` (the GCS path) filters on
`upload_strategy == "resumable"` and `like(failure_reason, "resumable_cancel_failed:%")`
but does NOT exclude `resumable_protocol == "tus"`. tus sessions are
`upload_strategy: "resumable"` and DO carry a non-nil `session_uri` (the signed
Location). The new `settle_tus_abort_success/2` first clause already defends
against this (a non-`tus_abort_failed:` marker routes to FSM-gated `gated_expire`,
correctly rejecting `aborted -> expired`), so no infinite retry results. Not
introduced by this diff and not currently reachable (tus paths only ever write
`tus_abort_failed:%`). Notably the NEW tus retry query at line 188 deliberately
adds the `resumable_protocol == "tus"` filter — worth mirroring the exclusion
symmetrically on the GCS side for defense in depth.
**Fix:** Add `where: s.resumable_protocol != "tus" or is_nil(s.resumable_protocol)`
to `fetch_retryable_abort_sessions/0` to keep tus rows out of the GCS lane.

### IN-02: Clean DELETE unconditionally clears a pre-existing `failure_reason`

**File:** `lib/rindle/upload/tus_plug.ex:424,432,465-466`
**Issue:** A clean DELETE abort returns `%{failure_reason: nil}`, folded into the
aborted changeset, clearing any previously-persisted `failure_reason` (e.g. a
marker left by a prior failed PATCH). Semantically acceptable for an explicit
client cancel (the session is terminating), but the behavior is implicit — the
diff comment explains the nil-on-clean rationale for reaper re-selection but not
that it also wipes unrelated prior failure context.
**Fix:** No code change required; consider a one-line comment at line 466 noting
that a clean cancel intentionally clears any prior `failure_reason`.

### IN-03: `tus_abort_marker/1` admits boolean atoms verbatim

**File:** `lib/rindle/upload/tus_plug.ex:486-490`
**Issue:** The atom clause matches any atom except `nil`, including `true`/`false`,
producing markers like `tus_abort_failed:true`. Harmless (still matches the
reaper predicate and is length-bounded), but the intent is clearly "a real error
atom."
**Fix:** Optional; if stricter normalization is desired, collapse non-error atoms
to `transport` alongside the catch-all clause. Low priority.

---

_Reviewed: 2026-05-23_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
