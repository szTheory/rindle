---
phase: 04-day-2-operations
fixed_at: 2026-04-26T13:46:00Z
review_path: .planning/phases/04-day-2-operations/04-REVIEW.md
iteration: 1
findings_in_scope: 17
fixed: 17
skipped: 0
status: all_fixed
---

# Phase 04: Code Review Fix Report

**Fixed at:** 2026-04-26T13:46:00Z
**Source review:** `.planning/phases/04-day-2-operations/04-REVIEW.md`
**Iteration:** 1

**Summary:**

- Findings in scope (Critical + Warning): 17
- Fixed: 17
- Skipped: 0

All 8 Critical and all 9 Warning findings were applied. WR-04 was resolved
implicitly by the CR-03 implementation (both sub-issues are addressed in the
same code region) and is documented below as `fixed-via-CR-03`.

**Test status after all fixes:** 140 tests, 0 failures, 1 skipped on seed 0
(+7 regression tests added over the 133-test baseline). Two pre-existing flaky
tests (`Rindle.LiveViewTest` `function_exported?` checks and one
`Rindle.Workers.MaintenanceWorkersTest` Oban-worker check) intermittently fail
on certain seeds in BOTH the pre-fix baseline AND the post-fix tree — they are
unrelated to the changes in this report. See "Pre-existing flake" note at
the bottom.

## Fixed Issues

### CR-01: Cleanup deletes DB row before storage object — orphans on transient storage failure

**Files modified:** `lib/rindle/ops/upload_maintenance.ex`, `test/rindle/ops/upload_maintenance_test.exs`
**Commit:** `d21d780`
**Applied fix:** Reversed the order in `delete_session_and_object/3`. The new
`attempt_storage_delete/2` runs FIRST, returning `{:ok, n}` for success or
already-`:not_found`, and `:storage_error` (with a warning log carrying
`upload_key`) for transient failures. Only after a clean storage outcome does
`Repo.delete/1` run. The result: a transient storage failure leaves the DB row
in place so the next cron cycle can retry using the still-persisted
`upload_key`. Replaced the misleading "DB row gone, storage error counted"
test with a stronger assertion that the row IS preserved on storage failure,
and added a separate test that `:not_found` from storage still allows DB
cleanup (no orphan to retry).

### CR-02: `mix rindle.cleanup_orphans` defaults to destructive run

**Files modified:** `lib/mix/tasks/rindle.cleanup_orphans.ex`
**Commit:** `da0abef`
**Applied fix:** Inverted the flag semantics from `--dry-run` (default false)
to `--live` (default false), so the bare `mix rindle.cleanup_orphans`
invocation is now non-destructive. This matches the existing safe defaults
in the service (`dry_run: true`) and the worker (`"dry_run" => true`). Added
a "Safety default" section to the `@moduledoc` documenting the unified contract
across CLI / service / worker (T-04-01 mitigation).

### CR-03: `regenerate_variants` enqueues duplicate jobs — cron idempotency is broken

**Files modified:** `lib/rindle/ops/variant_maintenance.ex`, `test/rindle/ops/variant_maintenance_test.exs`
**Commit:** `53ef3cb`
**Applied fix:** Added Oban uniqueness opts to `enqueue_job/2` scoped to
`(worker, queue, asset_id, variant_name)` over states
`[:available, :scheduled, :executing, :retryable]` with `period: :infinity`.
Also restructured the result tuple to `{enqueued, skipped, errors}`,
classifying `%Oban.Job{conflict?: true}` returns as `:skipped` (uniqueness
rejection) and other `{:error, _}` as `:errors` (real insertion failures).
Moved the skipped-count query BEFORE the enqueue loop (so a downstream query
failure cannot strand half-enqueued work in Oban — a partial WR-04 fix at
the same time) and narrowed the "non-regeneratable states" filter to
`["queued", "processing", "ready"]` (instead of the open-ended
`not in @regeneration_states`) so it no longer over-counts purged/failed/planned
variants. Added regression test that asserts the second consecutive
`regenerate_variants/1` call enqueues nothing AND that exactly one job exists
in the queue per `(asset, variant)` pair. **Requires human verification** of
the Oban uniqueness opts against the project's Oban version (`uniqueness`
arg shape can drift between versions).

### CR-04: `mix rindle.regenerate_variants` exits 0 on Oban insertion failure

**Files modified:** `lib/mix/tasks/rindle.regenerate_variants.ex`
**Commit:** `1de8edf`
**Applied fix:** Print the new `:errors` field in the summary and `System.halt(1)`
when `errors > 0` after printing. Updated `@moduledoc` "Output" section to
document the new field and the exit-code behavior. Now matches the documented
"Exit codes: 1 — Query or job-insertion error" contract.

### CR-05: `mix rindle.verify_storage` exits 0 on storage connection failure

**Files modified:** `lib/mix/tasks/rindle.verify_storage.ex`
**Commit:** `fe1a1b2`
**Applied fix:** Added an `if errors > 0` block after the summary print that
emits a shell error and `System.halt(1)`. Updated the `@moduledoc` exit-codes
section to clarify that missing variants do NOT affect the exit code (they
are an expected, recoverable outcome) but non-`:not_found` storage errors
DO trigger exit 1.

### CR-06: `String.to_atom` enables atom-table DoS from CLI

**Files modified:** `lib/mix/tasks/rindle.cleanup_orphans.ex`, `lib/mix/tasks/rindle.backfill_metadata.ex`
**Commit:** `0878a21`
**Applied fix:** Replaced `String.to_atom/1` with `String.to_existing_atom/1`
guarded by `try/rescue ArgumentError` in BOTH Mix tasks. Added a behaviour
check after `Code.ensure_loaded/1` so the loaded module must export the
expected callback (`delete/2` for storage, `download/3`/`analyze/1` for
backfill) before being accepted. Mirrors the pattern already correctly used
in `Rindle.Workers.CleanupOrphans.resolve_storage_adapter/1`. Closes the
T-04-09 bypass.

### CR-07: `expire_session/2` and `mark_missing/1` bypass the FSM

**Files modified:** `lib/rindle/ops/upload_maintenance.ex`, `lib/rindle/ops/variant_maintenance.ex`, `test/rindle/ops/upload_maintenance_test.exs`, `test/rindle/ops/variant_maintenance_test.exs`
**Commit:** `d0e66e0`
**Applied fix:**
- `UploadMaintenance.expire_session/2` now calls
  `UploadSessionFSM.transition(session.state, "expired", %{...})` first.
  Forbidden transitions are logged and counted as `:abort_errors`; only
  allowed transitions reach the changeset+update path.
- `VariantMaintenance.mark_missing/1` was changed to take both `variant_id`
  AND `current_state`, gates on `VariantFSM.transition/3`, and uses a
  per-row changeset (so `validate_inclusion` runs) instead of the previous
  `Repo.update_all`. When the FSM forbids the transition (e.g. a `failed`
  variant whose object goes missing), the variant is left untouched and
  the verify_storage report counts it as `:errors` (not `:missing`),
  surfacing the situation to the operator.
- Added two regression tests: `failed -> missing` is rejected, `stale ->
  missing` is rejected. Plus a unit-style assertion that
  `UploadSessionFSM.transition("uploaded", "expired", _)` returns
  `{:error, {:invalid_transition, ...}}` — the invariant gate.
- **Requires human verification:** the verify_storage report counts a
  forbidden transition as `:errors`, which now triggers the new CR-05
  exit-1 behavior. Confirm this is the desired behavior — an alternative
  is to add a separate `:fsm_blocked` counter so true storage-connection
  errors stay distinct from FSM rejections.

### CR-08: `expires_at < now` predicate blocks cleanup of administratively-expired rows

**Files modified:** `lib/rindle/ops/upload_maintenance.ex`, `test/rindle/ops/upload_maintenance_test.exs`
**Commit:** `56efe02`
**Applied fix:** Removed the `expires_at < ^now` predicate from
`fetch_expired_sessions/0`. The state column is the source of truth.
Added a regression test that creates a session in `state: "expired"` with
`expires_at` 2 hours in the future and asserts cleanup still removes it.

### WR-01: Tmp files leak when analyzer raises

**Files modified:** `lib/rindle/ops/metadata_backfill.ex`
**Commit:** `0758e6b`
**Applied fix:** Wrapped per-asset work in `try/rescue/after`. Raised
exceptions are now logged separately (`asset_raised` event including the
exception module and message) and counted as `:failed`; the original
`{:error, _}` path keeps its existing `asset_failed` event. `cleanup_temp/1`
is in the `after` block so the tmp file is removed even on a raise. Honors
the moduledoc promise that per-asset failures are accumulated rather than
aborting the run.

### WR-02: BackfillMetadata Mix task lacks `{:error, _}` clause

**Files modified:** `lib/mix/tasks/rindle.backfill_metadata.ex`, `lib/rindle/ops/metadata_backfill.ex`
**Commit:** `4472aa6`
**Applied fix:** Added defensive `{:error, reason}` clause to the Mix task's
`case` and widened the service `@spec` to
`{:ok, backfill_report()} | {:error, term()}`. (The defensive clause
became fully reachable after WR-05's commit, which adds the actual
`{:error, _}` return path — at WR-02 commit time the compiler emits a
"clause will never match" typing warning, which is silenced by the
WR-05 commit later.)

### WR-03: `cleanup_orphans` silently no-ops when storage adapter is nil

**Files modified:** `lib/rindle/ops/upload_maintenance.ex`, `lib/mix/tasks/rindle.cleanup_orphans.ex`, `lib/rindle/workers/cleanup_orphans.ex`
**Commit:** `25205c0` (combined with WR-06)
**Applied fix:** Added a `:storage_skipped` counter to `cleanup_report`. When
`cleanup_orphans/1` runs without a storage adapter AND there are sessions to
clean, it emits a one-time `Logger.warning("rindle.upload_maintenance.storage_adapter_missing", ...)`
and increments `:storage_skipped` for every session whose object delete was
bypassed. The Mix task prints the new field in its summary AND emits a
follow-up shell error so the misconfiguration is loud. The worker logger
also includes the new field in its `…completed` event.

### WR-04: `RegenerateVariants` skipped tally double-counts and can lose enqueue work

**Files modified:** `lib/rindle/ops/variant_maintenance.ex`
**Commit:** `53ef3cb` (resolved as part of CR-03)
**Applied fix:** Both sub-issues were addressed in the CR-03 commit:
1. The skipped-count query now runs BEFORE the enqueue loop (`with {:ok, [count]} <- safe_all(skipped_query) do ...`),
   so a downstream query failure cannot strand half-enqueued work in Oban.
2. The skipped query is narrowed from `state not in @regeneration_states` to
   `state in ["queued", "processing", "ready"]` so it no longer over-counts
   `purged` / `failed` / `planned` variants as "skipped".
Marking as `fixed-via-CR-03` (no separate commit).

### WR-05: `MetadataBackfill.fetch_eligible_assets/1` swallows query errors

**Files modified:** `lib/rindle/ops/metadata_backfill.ex`
**Commit:** `0d8598f`
**Applied fix:** Changed both `fetch_eligible_assets/1` clauses to return
`{:ok, [MediaAsset.t()]} | {:error, term()}` (instead of swallowing rescued
errors and returning `[]`). `backfill_metadata/1` propagates `{:error, _}`
on infrastructure failure; the Mix task's WR-02 defensive clause now halts
non-zero. Side benefit: silenced the WR-02 typing warning.

### WR-06: Worker `CleanupOrphans` does not emit the documented `failed` event when adapter resolution errors

**Files modified:** `lib/rindle/workers/cleanup_orphans.ex`
**Commit:** `25205c0` (combined with WR-03)
**Applied fix:** Added an `else` clause to the worker's `with` that emits
`Logger.error("rindle.workers.cleanup_orphans.failed", ..., stage: :resolve_storage_adapter)`
on adapter-resolution failure. Updated the moduledoc Observability section
to enumerate every event the worker emits (`…completed`, `…failed`,
`…storage_load_failed`, `…storage_not_found`).

### WR-07: `Mix.Task.run("app.start")` invoked at runtime instead of via `@requirements`

**Files modified:** `lib/mix/tasks/rindle.regenerate_variants.ex`, `lib/mix/tasks/rindle.verify_storage.ex`
**Commit:** `45dd4c4`
**Applied fix:** Replaced the in-body `Mix.Task.run("app.start")` call with
`@requirements ["app.start"]` for both tasks, matching the other three
Phase-04 Mix tasks.

### WR-08: `regenerate_variants` accepts unknown filter keys silently

**Files modified:** `lib/rindle/ops/variant_maintenance.ex`, `test/rindle/ops/variant_maintenance_test.exs`
**Commit:** `f7951bb`
**Applied fix:** Added `@allowed_filter_keys [:profile, :variant_name]` and
a `validate_filters/1` helper that returns `{:error, {:unknown_filters, list}}`
for any key outside the whitelist. Both `regenerate_variants/1` AND
`verify_storage/1` now run the guard before any DB or Oban work. Added a
regression test covering both functions and both possible typos (`:prof`,
`:variant`).

### WR-09: `resolve_storage_adapter/1` raises and aborts the verify walk

**Files modified:** `lib/rindle/ops/variant_maintenance.ex`
**Commit:** `b8aa785`
**Applied fix:** Replaced the `rescue _e -> raise "Cannot resolve ..."`
pattern with a tagged-tuple return: `{:ok, adapter} | {:error, atom()}`.
Specifically rescues `ArgumentError` only (so unrelated exceptions surface),
validates `Code.ensure_loaded?/1` AND `function_exported?(mod, :storage_adapter, 0)`
explicitly, and never interpolates the raw profile string into a
RuntimeError message. `check_object/1` now handles `{:error, _}` by
incrementing the `:errors` counter and logging — the verify walk continues
past malformed profile strings instead of aborting.

## Skipped Issues

None — all in-scope findings were applied.

## Pre-existing test flake (not caused by this fix run)

Three tests intermittently fail on certain seeds in BOTH the pre-fix baseline
AND the post-fix tree:

- `test/rindle/live_view_test.exs:91` — `function_exported?(Rindle.LiveView, :allow_upload, 4)`
- `test/rindle/live_view_test.exs:81` and `:95` — `function_exported?(Rindle.LiveView, :consume_uploaded_entries, 3)`
- `test/rindle/workers/maintenance_workers_test.exs:167` — `function_exported?(AbortIncompleteUploads, :perform, 1)`

These are runtime module-availability checks that race with parallel test
compilation. Verified with checkout of HEAD-15 (`5f0f6a9`, the pre-fix doc
commit): the same tests fail on seeds 1, 2, and 1000 with 1–3 failures
matching the post-fix behavior. No fix is in scope here; orchestrator should
either accept seed 0 as the deterministic baseline, mark these tests with
`@tag :flaky`, or refactor the live_view conditional-compilation pattern.

---

_Fixed: 2026-04-26T13:46:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
