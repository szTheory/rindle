---
phase: 43-s3-multipart-backing-minio-proof
plan: 08
subsystem: infra
tags: [tus, s3-multipart, upload-reaper, fsm, ecto, oban, cost-leak]

# Dependency graph
requires:
  - phase: 43-s3-multipart-backing-minio-proof (43-06)
    provides: "Rindle.Storage.S3.tus_tail_path/2 — the canonical base64url tail-path source of truth (CR-02)"
provides:
  - "Encoding-correct remove_tus_tail/2 routed through S3.tus_tail_path/2 (CR-02 wiring closed)"
  - "FSM-gated tus expiry via a shared gated_expire/2 helper used by BOTH the standard and tus branches (WR-01 closed)"
  - "IN-03 Local-root resolution: Local abort removes the part file at the resolved upload root, not the bare empty-opts default"
  - "PUBLIC reusable abort_tus_backing(session, opts) arity-2 polymorphic abort helper (CR-01 prerequisite for 43-09)"
  - "PUBLIC remove_tus_tail(session, root) arity-2 helper"
affects: [43-09, tus-delete-handler, tus-plug, upload-maintenance, reaper]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Shared gated_expire/2 helper centralizes the UploadSessionFSM.transition gate for all expiry branches"
    - "Polymorphic abort exposed as a PUBLIC arity-2 helper callable with an explicit adapter/root keyword list — no DB profile re-resolution on the hot DELETE path"
    - "Tail/part path computation delegated to the adapter's own canonical source of truth (S3.tus_tail_path/2, Local.tus_part_path/2) — no re-derived encoding in the reaper"

key-files:
  created: []
  modified:
    - "lib/rindle/ops/upload_maintenance.ex — CR-02 wiring, WR-01 FSM gate, IN-03 root resolution, PUBLIC abort_tus_backing/2 + remove_tus_tail/2"
    - "test/rindle/ops/upload_maintenance_test.exs — 5 regression tests across 2 describe blocks"

key-decisions:
  - "Extracted a shared gated_expire/2 helper used by both the standard and tus expiry branches so the FSM gate cannot diverge (WR-01 fix-sketch option chosen)"
  - "abort_tus_backing/2 is the single polymorphic abort: the reaper resolves adapter+root from the session and delegates to it; 43-09 calls the SAME helper with an explicit adapter+root it already holds"
  - "Local-root resolution computes Rindle.Storage.Local.root([]) directly (the adapter owns its own root resolution) rather than probing the storage adapter capability — a Local-only abort has no remote backing to abort"

patterns-established:
  - "Reaper delete-path root == write-path root, proven by pinning an explicit root through S3.tus_tail_path/2 in the CR-02 regression test (no false green)"
  - "FSM-forbidden expiry transitions increment :abort_errors and leave the row in place rather than silently flipping state"

requirements-completed: [TUS-06, TUS-09]

# Metrics
duration: 5min
completed: 2026-05-23
---

# Phase 43 Plan 08: Upload Reaper Gap Fixes (CR-02 / WR-01 / IN-03 / CR-01) Summary

**Wired the tus reaper's tail removal through the S3 adapter's canonical base64url tail path, FSM-gated tus expiry via a shared gated-expire helper, resolved the Local abort's actual upload root, and exposed a PUBLIC reusable `abort_tus_backing(session, opts)` polymorphic abort for the 43-09 DELETE path.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-05-23T12:25:44Z
- **Completed:** 2026-05-23T12:31:03Z
- **Tasks:** 2 (TDD)
- **Files modified:** 2

## Accomplishments

- **CR-02 wiring closed:** `remove_tus_tail/2` now delegates the path computation to `Rindle.Storage.S3.tus_tail_path/2` (the adapter's own canonical, single-`Base.url_encode64`-site source of truth added in 43-06), threading an explicit root. The reaper now deletes the REAL adapter-written tail file instead of a raw-UUID path at a fixed root that never matched — closing the residual-file cost leak (T-43-08-01).
- **WR-01 closed:** Extracted a shared `gated_expire/2` helper that gates persistence on `UploadSessionFSM.transition(state, "expired", ...)`; BOTH the standard and tus expiry branches route through it, so a future query-set expansion can never silently flip a tus session from an FSM-forbidden state (T-43-08-02).
- **IN-03 closed:** The Local backing abort resolves the upload's actual Local root and removes the part file at `Local.tus_part_path(session.id, root: resolved_root)` instead of the bare empty-opts default.
- **CR-01 prerequisite shipped:** `abort_tus_backing(session, opts)` is now a PUBLIC arity-2 polymorphic abort (opts carries `:adapter`, `:root`, `:upload_id`). 43-09's DELETE handler can invoke the SAME abort with an explicit adapter/root it already holds — no DB profile re-resolution on the hot DELETE path. The reaper's existing resolve-from-session mode is preserved and delegates to the same helper.

## Task Commits

Each task was committed atomically (TDD: test → feat):

1. **Task 1 (RED): failing CR-02/WR-01 tests** — `a3dcb74` (test)
2. **Task 1 (GREEN): S3.tus_tail_path wiring + shared FSM-gated gated_expire/2 + PUBLIC abort_tus_backing/2** — `82ee44f` (feat)
3. **Task 2 (test+impl): IN-03 Local-root + PUBLIC abort_tus_backing/2 reuse tests + resolve_local_root simplification** — `276454a` (test)
4. **Formatting:** `fc6ad26` (style — mix format the new tests)

RED for Task 2's three tests was proven by reverting `upload_maintenance.ex` to the pre-fix commit (`8a755e3`) and observing all three fail (`abort_tus_backing/2 undefined` for the two shared-helper tests; part/tail not removed at the resolved root for the IN-03 test), then restoring the fixed implementation.

## Files Created/Modified

- `lib/rindle/ops/upload_maintenance.ex` — Added `alias Rindle.Storage.S3`. Promoted `remove_tus_tail/1` → PUBLIC `remove_tus_tail/2` (delegates to `S3.tus_tail_path/2` with a threaded root, `root_opt/1` helper for the nil-default case). Replaced the two private `abort_tus_backing/1` clauses with thin clauses that resolve adapter/root from the session and delegate to a new PUBLIC `abort_tus_backing/2` polymorphic abort. Removed the ungated `do_expire_tus_session/2`; extracted shared `gated_expire/2` (FSM gate) used by `expire_standard_session/2` and `expire_tus_session/2`. Added `resolve_local_root/1` (IN-03).
- `test/rindle/ops/upload_maintenance_test.exs` — Two new describe blocks: `"tus reaper cleanup (CR-02/WR-01 regression)"` (CR-02 tail-removal-at-same-root test; WR-01 FSM-gate-refuses-forbidden-transition test) and `"tus backing abort root resolution + shared helper (IN-03/CR-01 regression)"` (IN-03 Local-part-at-resolved-root test; two PUBLIC `abort_tus_backing/2` shared-helper tests exercising the exact 43-09 call shape for S3 and Local).

## Decisions Made

- **Shared gated-expire helper (WR-01):** Chose the fix-sketch's "extract a shared gated-expire helper used by all branches" option over duplicating the FSM gate in the tus branch — single invariant site, no divergence. The standard branch's log key (`session_expired`) is now also used by tus expiry; report-counter behaviour (`sessions_aborted` + `increment_abort_strategy`) is identical to before.
- **Local-root resolution computes `Local.root([])` directly** rather than calling `resolve_tus_adapter/1` first. A Local-only abort has no remote backing, so the adapter/capability probe is unnecessary; calling it dragged a `StorageMock.capabilities()` Mox interaction into the Local reaper path that broke `verify_on_exit!`. The Local adapter owns its own profile/app-env root resolution.
- **`abort_tus_backing/2` signature** is `def abort_tus_backing(%MediaUploadSession{} = session, opts) when is_list(opts)` — callable byte-for-byte as 43-09 invokes it: `abort_tus_backing(session, adapter: ..., root: ..., upload_id: ...)`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Local abort path triggered an unexpected Mox `capabilities()` call**
- **Found during:** Task 2 (IN-03 Local-root resolution)
- **Issue:** The first implementation of `resolve_local_root/1` called `resolve_tus_adapter/1` (per the plan's "resolve the same way `resolve_tus_adapter/1` does" wording), which invokes `Capabilities.require_upload/2 → StorageMock.capabilities()`. With no Mox expectation set in the Local IN-03 test, this surfaced as a `verify_on_exit!` failure (`protocol Enumerable not implemented for Atom`).
- **Fix:** Simplified `resolve_local_root/1` to compute `Rindle.Storage.Local.root([])` directly — the Local adapter owns its root resolution and a Local-only abort has no remote backing to capability-probe. Same resolved root, no spurious adapter interaction.
- **Files modified:** lib/rindle/ops/upload_maintenance.ex
- **Verification:** `mix test test/rindle/ops/upload_maintenance_test.exs` 40/40 green.
- **Committed in:** 276454a (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** The fix is faithful to the IN-03 intent (resolve the actual upload root, drop the bare empty-opts call) while removing an incorrect dependency on the remote-adapter resolution for a Local-only path. No scope creep.

## Issues Encountered

- **CR-02 / WR-01 / IN-03 RED determinism:** The query set only surfaces FSM-legal `signed`/`uploading`/`resuming` tus states (all legal → `expired`), so a behavioral WR-01 RED required a tus session in an FSM-forbidden state. Resolved by using an `aborted` tus session surfaced by the retryable-abort query (`aborted → expired` is forbidden), which routes to the tus branch first (`tus_session?/1`) — a clean RED→GREEN. IN-03 is structurally indistinguishable from the empty-opts default in the reaper's resolve-from-session mode (both resolve `Local.root([])`); the genuine RED is carried by the PUBLIC shared-helper tests (no arity-2 existed pre-fix) plus the IN-03 reaper test asserting removal at the resolved root.

## Verification

- `mix test test/rindle/ops/upload_maintenance_test.exs` — 40 tests, 0 failures (35 pre-existing + 5 new).
- `mix test` across related suites (`s3_tus_test.exs`, `upload/`, `local_test.exs`) — 105 tests, 0 failures, 3 skipped/excluded (integration tags).
- `mix compile --warnings-as-errors` — clean.
- `mix format --check-formatted` on both files — clean.
- Acceptance greps: `S3.tus_tail_path` present in `remove_tus_tail/2`; `session_id <> ".tail"` count 0; `tus_part_path(session.id, [])` count 0; PUBLIC `def abort_tus_backing(session, opts)` present alongside the private reaper clauses; `UploadSessionFSM.transition` gates the shared `gated_expire/2`.

## Next Phase Readiness

- **43-09 unblocked:** The DELETE handler in `lib/rindle/upload/tus_plug.ex` (`handle_delete/2`) can now call `Rindle.Ops.UploadMaintenance.abort_tus_backing(session, adapter: opts[:adapter], root: opts[:root], upload_id: session.multipart_upload_id)` to perform the same polymorphic backing abort (S3 multipart abort / Local tmp+tail removal) the reaper does — without re-resolving the profile from the DB.
- No blockers. CR-02 wiring, WR-01 FSM gate, IN-03 root resolution, and the CR-01 PUBLIC helper prerequisite are all closed with fail-pre-fix regression tests.

---
*Phase: 43-s3-multipart-backing-minio-proof*
*Completed: 2026-05-23*
