---
phase: 43-s3-multipart-backing-minio-proof
plan: 11
subsystem: api
tags: [tus, plug, s3-multipart, reaper, termination, cost-leak, fsm, mox, elixir, gap-closure]

# Dependency graph
requires:
  - phase: 43-s3-multipart-backing-minio-proof (plan 09)
    provides: "tus DELETE aborts the backing store BEFORE the aborted transition (CR-01 happy-path ordering); abort_delete_backing/2 swallowed {:error,_} and returned :ok (the abort-FAILURE orphan this plan closes)"
  - phase: 43-s3-multipart-backing-minio-proof (plan 08)
    provides: "PUBLIC Rindle.Ops.UploadMaintenance.abort_tus_backing/2 — arity-2 polymorphic backing abort (S3 multipart abort / Local tmp removal), re-used by the reaper retry path"
provides:
  - "A DELETE-time backing-abort failure leaves a reaper-recoverable row (retryable tus_abort_failed:<reason> marker) instead of a permanent orphaned S3 multipart — closes the abort-FAILURE branch of CR-01 (TUS-09 cost leak)"
  - "fetch_retryable_tus_abort_sessions/0: a reaper query that re-selects aborted+tus+multipart_upload_id+tus_abort_failed:% rows and re-aborts the orphaned multipart on the next cron"
  - "WR-03 reconciliation: the aborted-tus retry-success path settles the row WITHOUT the FSM-forbidden aborted->expired transition (mirrors persist_resumable_abort_success/3), so a recovered row never loops in a silent infinite retry"
  - "tus DELETE persists the retryable marker on abort failure while still returning 204 (client-facing cancel semantics preserved; reaper compensates)"
  - "The false comment at tus_plug.ex handle_delete/2 (claiming the reaper compensated without any marker) is corrected to describe the now-real tus_abort_failed marker + fetch_retryable_tus_abort_sessions compensation"
affects: [43-verification, cr-01, tus-delete, sc4-delete-no-leak, sc5-minio-delete-proof]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Marker + reaper-query compensation for a transient remote abort failure (mirrors the GCS resumable_cancel_failed:% pattern): on failure the row carries a retryable failure_reason marker and a dedicated reaper query re-selects it for re-abort — TTL-independent, eligible on the very next cron"
    - "Marker-discriminated FSM-gate bypass: settle_tus_abort_success/2 branches on the failure_reason marker so an aborted-tus DELETE-failure retry row settles directly (no FSM gate), while the GCS resumable_cancel_failed:% marker and the non-terminal timeout-expiry path keep the FSM-gated gated_expire (WR-01/WR-03 reconciled in one helper)"
    - "Bounded failure-reason marker: an atom reason verbatim (else collapsed to transport), truncated to 64 chars, never embedding an inspected term / path / session_uri (security invariant 14)"
    - "abort_delete_backing/2 returns failure_reason attrs folded into the aborted changeset rather than signalling via a return-vs-discard side effect — the abort outcome deterministically influences the persisted row"

key-files:
  created: []
  modified:
    - lib/rindle/ops/upload_maintenance.ex
    - lib/rindle/upload/tus_plug.ex
    - test/rindle/ops/upload_maintenance_test.exs
    - test/rindle/upload/tus_plug_test.exs

key-decisions:
  - "Locked remediation: marker + reaper-query (VERIFICATION.md missing: option 2) over leave-the-row + return 5xx — consistent with the existing GCS retryable-abort architecture, keeps DELETE returning 204 (operator-friendly per STATE.md), and is TTL-independent (re-selectable next cron, not gated on expires_at)"
  - "WR-03: the aborted-tus retry-success path settles via persist_tus_abort_retry_success/2 (direct repo update to state=expired, marker cleared) WITHOUT UploadSessionFSM.transition — the FSM declares aborted=>[] terminal, so routing through gated_expire would attempt the forbidden aborted->expired, log invalid_transition, increment abort_errors, and re-select forever (silent infinite retry)"
  - "settle_tus_abort_success/2 keys the bypass on the tus_abort_failed: marker, NOT merely state==aborted: a GCS resumable_cancel_failed:% marker surfaced into the tus branch still routes through the FSM gate (preserves the existing WR-01 test), and a clean aborted row (failure_reason nil) is never re-selected at all"
  - "The DELETE marker string starts with exactly tus_abort_failed: so it matches the reaper's like(failure_reason, \"tus_abort_failed:%\") predicate byte-for-byte; the reason is bounded (atom verbatim/transport, truncated) to avoid leaking internal detail"

patterns-established:
  - "Transient remote-abort failure on a termination path is recorded as a retryable marker and compensated by the reaper, not surfaced to the client (204 preserved) — telemetry/metadata-driven compensation over expanding the error surface"
  - "One coherent reaper-compensation model: the tus retry query and settle path mirror the GCS resumable pattern rather than introducing a divergent second one"

metrics:
  duration: ~9min
  completed: 2026-05-23
  tasks: 2
  files: 4
---

# Phase 43 Plan 11: CR-01 Reaper-Recoverable DELETE Abort Failure Summary

Make a tus DELETE's failed backing-abort reaper-recoverable: on a transient
`abort_multipart_upload` failure the DELETE now stamps a retryable
`tus_abort_failed:<reason>` marker (still returning 204), and a new reaper query
re-selects + re-aborts the orphaned S3 multipart on the next cron — settling the
row without the FSM-forbidden `aborted -> expired` transition (WR-03). Closes the
abort-FAILURE branch of CR-01 that 43-09 left a permanent orphan.

## What This Closes

CR-01 had two halves. 43-09 fixed the happy-path ordering (abort the backing
BEFORE the `aborted` transition). The abort-FAILURE branch remained a permanent
orphan: `abort_delete_backing/2` swallowed `{:error, _}`, the row moved to
`aborted` with `failure_reason: nil`, and NO reaper query ever re-selected it
(`fetch_incomplete_timed_out_sessions/0` never matches `aborted`;
`fetch_retryable_abort_sessions/0` requires the GCS `resumable_cancel_failed:%`
marker `nil` never satisfies). A transient blip therefore orphaned the S3
multipart forever — the exact TUS-09 cost leak. This plan makes that branch
reaper-recoverable.

## Tasks

### Task 1 — Reaper re-selects + re-aborts aborted tus sessions (CR-01 reaper half + WR-03)
Commit `6a4cd1c` — `feat(43-11)`

- Added `fetch_retryable_tus_abort_sessions/0` selecting `state == "aborted"` AND
  `resumable_protocol == "tus"` AND `not is_nil(multipart_upload_id)` AND
  `like(failure_reason, "tus_abort_failed:%")`; unioned into
  `fetch_abortable_sessions/0` with the existing `Enum.uniq_by(& &1.id)` dedupe.
- WR-03: replaced the unconditional `gated_expire/2`-on-success in
  `expire_tus_session/2` with `settle_tus_abort_success/2`, which branches on the
  inbound `failure_reason` marker. An aborted-tus row carrying the
  `tus_abort_failed:` marker settles via the new `persist_tus_abort_retry_success/2`
  (direct repo update to `state: "expired"`, marker cleared — mirrors
  `persist_resumable_abort_success/3`, no FSM gate). A GCS
  `resumable_cancel_failed:%` marker and the non-terminal timeout-expiry path keep
  the FSM-gated `gated_expire` (WR-01 preserved).
- On a re-abort that still fails, the row stays `aborted` with the marker intact
  (re-selectable next cron) and `abort_errors` increments — no new permanent orphan.
- 4 regression tests (new describe block): recovery (re-abort + settle, marker
  cleared, `abort_errors == 0` proving no FSM-forbidden transition), idempotent
  `:not_found`, still-failing-stays-recoverable, and no-false-retry (a clean
  aborted row with `failure_reason: nil` is never selected — `sessions_found == 0`).

### Task 2 — DELETE persists the retryable marker on abort failure (CR-01 Plug half) + fix the false comment
Commit `9f3fe75` — `feat(43-11)`

- Rewrote `abort_delete_backing/2`: instead of swallowing `{:error, _}` and
  returning `:ok`, it returns `%{failure_reason: nil}` on a clean abort or
  `%{failure_reason: "tus_abort_failed:<short_reason>"}` on a transient failure.
  `handle_delete/2` folds those attrs into the `aborted` changeset.
- The DELETE still returns 204 on a successful row update even when the backing
  abort failed (client-facing cancel semantics preserved; reaper compensates).
  WR-02 (5xx on a failed DB update) remains in force from 43-09.
- `tus_abort_marker/1` bounds the reason (atom verbatim, else `transport`),
  truncates to 64 chars, and embeds no path/session_uri/inspected term
  (invariant 14 / T-43-11-04). The marker always starts with exactly
  `tus_abort_failed:` to match the reaper predicate byte-for-byte.
- Fixed the false comment at `handle_delete/2`: it no longer claims the reaper
  compensates without any marker; it now references the real `tus_abort_failed`
  marker + `fetch_retryable_tus_abort_sessions/0` compensation.
- 2 regression tests added to the Plan 09 describe block: marker-on-failure
  (204 + `failure_reason` starts with `tus_abort_failed:`) and no-marker-on-clean-abort
  (`failure_reason == nil`). The WR-02 update-failure and tampered-token tests stay green.

## Deviations from Plan

None — plan executed exactly as written. The marker-discrimination in
`settle_tus_abort_success/2` (keying the FSM-gate bypass on the
`tus_abort_failed:` marker rather than bare `state == "aborted"`) is the plan's
explicit WR-01/WR-03 reconciliation, not a deviation: it preserves the existing
WR-01 GCS-marker test (which still routes an aborted GCS row through the FSM gate
and increments `abort_errors`).

## Verification

- `mix test test/rindle/ops/upload_maintenance_test.exs` — 44 tests, 0 failures
  (4 new CR-01/WR-03 reaper tests + the retained WR-01 GCS-marker test).
- `mix test test/rindle/upload/tus_plug_test.exs` — 28 tests, 0 failures
  (2 new marker tests + the retained WR-02 and tampered-token tests).
- `mix test test/rindle/ops/ test/rindle/upload/` — 220 tests, 0 failures,
  3 skipped (pre-existing MinIO-tagged cases), 0 regressions.
- `mix compile --warnings-as-errors` — succeeds.
- The aborted-tus retry-success path does NOT route through `gated_expire/2`
  (no FSM-forbidden transition) — proven by the recovery test asserting
  `state == "expired"`, `abort_errors == 0`, `failure_reason == nil`.

## Acceptance Criteria

- Task 1: `grep -v '^[[:space:]]*#' lib/rindle/ops/upload_maintenance.ex | grep -c 'tus_abort_failed'` = 3 (>= 1).
- Task 1: `fetch_retryable_tus_abort_sessions/0` selects the four predicates and is unioned into `fetch_abortable_sessions/0`. ✓
- Task 1: the SUCCESS path settles WITHOUT `UploadSessionFSM.transition` (no `gated_expire` on the marker branch). ✓
- Task 2: `grep -v '^[[:space:]]*#' lib/rindle/upload/tus_plug.ex | grep -c 'tus_abort_failed'` = 1 (>= 1).
- Task 2: `grep -n 'reaper compensates on the next cron' lib/rindle/upload/tus_plug.ex` returns nothing. ✓
- Task 2: the marker written by `handle_delete/2` starts with exactly `tus_abort_failed:`. ✓

## Threat Surface

No new trust-boundary surface beyond the plan's `<threat_model>`. T-43-11-01
(orphaned-multipart cost DoS) and T-43-11-02 (silent infinite retry) are
mitigated and regression-guarded; T-43-11-04 (marker info disclosure) is bounded
by `tus_abort_marker/1`. No threat flags.

## Known Stubs

None. Both halves wire real behavior end-to-end (Plug marker write -> reaper
re-select -> re-abort -> settle), proven by inject-failure-then-reaper-re-aborts
regression tests in the default `mix test` lane.

## Self-Check: PASSED

- Files verified present: 43-11-SUMMARY.md, lib/rindle/ops/upload_maintenance.ex,
  lib/rindle/upload/tus_plug.ex, test/rindle/ops/upload_maintenance_test.exs,
  test/rindle/upload/tus_plug_test.exs.
- Commits verified in log: 6a4cd1c (Task 1), 9f3fe75 (Task 2), e60abdf (docs).
