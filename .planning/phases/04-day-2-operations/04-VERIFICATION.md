---
phase: 04-day-2-operations
verified: 2026-04-26T14:10:00Z
status: passed
score: 5/5 roadmap success criteria verified
overrides_applied: 0
re_verification:
  previous_status: human_needed
  previous_score: 5/5
  gaps_closed:
    - "CR-03 (Oban uniqueness): new CI test explicitly asserts conflict?: true on duplicate insert — real engine path, no sandbox shortcut"
    - "CR-07 (FSM-blocked exit code): :fsm_blocked counter separated from :errors; mark_missing/2 returns :fsm_blocked not :error on FSM rejection; Mix task only exits non-zero on :errors > 0"
  gaps_remaining: []
  regressions: []
---

# Phase 4: Day-2 Operations Verification Report

**Phase Goal:** Production systems can be maintained without manual SQL — orphans cleaned, stale variants regenerated, storage reconciled, and incomplete uploads aborted — all scriptable and CI-friendly
**Verified:** 2026-04-26T14:10:00Z
**Status:** passed
**Re-verification:** Yes — after human-UAT items shifted left to CI (commit `b93e632`, UAT resolved in `178ee3d`)

## Re-verification Summary

**Previous status:** human_needed (5/5 SC verified)
**Current status:** passed (5/5 SC verified, 0 human items remaining)

**Items closed:**

1. **CR-03 — Oban uniqueness keyword shape:** New test `"uniqueness rejection produces an Oban.Job{conflict?: true} (real engine path)"` (lines 180–221 of `variant_maintenance_test.exs`) directly invokes `Oban.insert/1` twice with the identical `unique: [fields: [:args, :worker, :queue], keys: [:asset_id, :variant_name], ...]` shape used by `enqueue_job/2` and asserts `second_job.conflict?`. Combined with the existing `length(jobs) == 1` DB-row-count assertion, both the keyword-shape contract and the deduplication behavior are locked under CI.

2. **CR-07 — verify_storage FSM-blocked exit code:** Design change in `b93e632` adds a dedicated `:fsm_blocked` field to `verify_result` type and accumulator. `mark_missing/2` returns `:fsm_blocked` (not `:error`) when `VariantFSM.transition/3` rejects the transition. The Mix task prints both counters and gates exit-1 exclusively on `errors > 0`. Two FSM regression tests assert `result.fsm_blocked == 1, result.errors == 0` for both `failed` and `stale` source states.

**Regressions:** None. Test suite: 145 tests, 0 failures, 1 skipped on seed 0 (was 144 — +1 is the new Oban contract test).

## Goal Achievement

### Observable Truths (from ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC-1 | `mix rindle.cleanup_orphans --dry-run` logs without deleting; without it, deletes expired sessions and objects | VERIFIED | `strict: [dry_run: :boolean, live: :boolean, storage: :string]` — `Keyword.fetch(opts, :dry_run)` honors flag; `--no-dry-run` sets `false`; no-flag default is `not Keyword.get(opts, :live, false)` = `true` |
| SC-2 | `mix rindle.regenerate_variants --profile Avatar --variant thumbnail` enqueues jobs only for matching stale/missing variants | VERIFIED | `@regeneration_states ["stale", "missing"]`; `maybe_filter_profile/2` and `maybe_filter_variant_name/2` compose query; `validate_filters/1` guards unknown keys; tests confirm filtering |
| SC-3 | `mix rindle.verify_storage` outputs summary (total checked, missing, present, errors) and marks absent variants as `missing` | VERIFIED | Five-field summary now includes `fsm_blocked`; `mark_missing/2` via FSM gate and changeset; Mix task prints all fields; exits non-zero only on `errors > 0` |
| SC-4 | `mix rindle.abort_incomplete_uploads` transitions `signed`/`uploading` sessions past TTL to `expired` | VERIFIED | `abort_incomplete_uploads` delegates to `UploadMaintenance.abort_incomplete_uploads/1` which gates on FSM before changeset; tests confirm |
| SC-5 | All Mix tasks exit non-zero on errors | VERIFIED | All five tasks use `exit({:shutdown, 1})` or `System.halt(1)` on `{:error, reason}` and on per-item error counts; `fsm_blocked` correctly excluded from non-zero exit trigger |

**Score:** 5/5 roadmap success criteria verified

### Plan Must-Have Truths

#### Plan 01 Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `mix rindle.cleanup_orphans` deletes expired sessions and staged objects on live run | VERIFIED | `--no-dry-run` / `--live` each set `dry_run? = false`; service deletes via `Repo.delete` after storage delete |
| 2 | `mix rindle.cleanup_orphans --dry-run` reports without deleting | VERIFIED | `dry_run: :boolean` in strict list; `Keyword.fetch(opts, :dry_run)` yields `{:ok, true}`; `[DRY RUN]` prefix printed, no deletions occur |
| 3 | `mix rindle.abort_incomplete_uploads` transitions timed-out sessions to `expired` | VERIFIED | `UploadMaintenance.abort_incomplete_uploads/1` queries signed/uploading past TTL, transitions via FSM+changeset |
| 4 | Both tasks exit non-zero when a step fails | VERIFIED | `exit({:shutdown, 1})` on `{:error, reason}` and on error counts |

#### Plan 02 Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `mix rindle.regenerate_variants` targets only stale/missing variants matching filters | VERIFIED | `@regeneration_states ["stale", "missing"]`; filter composition confirmed; `validate_filters/1` guards unknown keys |
| 2 | `mix rindle.verify_storage` compares DB to storage and marks missing variants | VERIFIED | HEAD-check loop with FSM-gated `mark_missing/2`; FSM-blocked transitions counted as `:fsm_blocked`, not `:errors` |
| 3 | `mix rindle.verify_storage` prints checked/missing/present/errors summary | VERIFIED | Five `Mix.shell().info` lines emit each field (checked, present, missing, fsm_blocked, errors); exits non-zero when `errors > 0` |
| 4 | Both tasks fail loudly on query/storage failures | VERIFIED | `{:error, reason}` returned on `safe_all` failure; `System.halt(1)` in both tasks |

#### Plan 03 Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `mix rindle.backfill_metadata` reruns analyzer and persists updated metadata | VERIFIED | `MetadataBackfill.backfill_metadata/1` iterates eligible assets, downloads, analyzes, persists via changeset |
| 2 | Backfill reports failures and exits non-zero when analysis or persistence fails | VERIFIED | `failures` field accumulated per asset; `maybe_exit_nonzero/1` halts on non-zero count |
| 3 | Cron-capable workers exist for orphan cleanup and incomplete-upload abortion | VERIFIED | `Rindle.Workers.CleanupOrphans` and `Rindle.Workers.AbortIncompleteUploads` on `rindle_maintenance` queue |
| 4 | Worker entrypoints reuse shared maintenance logic without duplicating behavior | VERIFIED | Both workers `alias` and call `UploadMaintenance`; no cleanup logic in worker modules |

### Required Artifacts

| Artifact | Min Lines | Actual | Status | Details |
|----------|-----------|--------|--------|---------|
| `lib/rindle/ops/upload_maintenance.ex` | 120 | 330 | VERIFIED | Exports `cleanup_orphans/1`, `abort_incomplete_uploads/1` |
| `lib/mix/tasks/rindle.cleanup_orphans.ex` | 80 | 173 | VERIFIED | `dry_run: :boolean` registered; all three invocation forms work |
| `lib/mix/tasks/rindle.abort_incomplete_uploads.ex` | 80 | 81 | VERIFIED | Contains `abort_incomplete_uploads` delegation |
| `test/rindle/ops/upload_maintenance_test.exs` | 120 | 262 | VERIFIED | Contains `cleanup_orphans` tests; substantive coverage |
| `lib/rindle/ops/variant_maintenance.ex` | 140 | 359 | VERIFIED | Exports `regenerate_variants/1`, `verify_storage/1`; `verify_result` type includes `fsm_blocked`; `mark_missing/2` returns `:fsm_blocked` on FSM rejection |
| `lib/mix/tasks/rindle.regenerate_variants.ex` | 90 | 104 | VERIFIED | Contains `regenerate_variants` delegation |
| `lib/mix/tasks/rindle.verify_storage.ex` | 90 | 135 | VERIFIED | Prints five-field summary including `fsm_blocked`; exits non-zero only on `errors > 0` |
| `test/rindle/ops/variant_maintenance_test.exs` | 140 | 371 | VERIFIED | Two new FSM regression tests assert `fsm_blocked == 1, errors == 0`; new Oban contract lock test asserts `conflict?: true`; existing `length(jobs) == 1` DB-count test retained |
| `lib/rindle/ops/metadata_backfill.ex` | 120 | 218 | VERIFIED | Exports `backfill_metadata/1` |
| `lib/mix/tasks/rindle.backfill_metadata.ex` | 90 | 185 | VERIFIED | Contains `backfill_metadata` delegation |
| `lib/rindle/workers/cleanup_orphans.ex` | 80 | 141 | VERIFIED | Contains `CleanupOrphans`; `:rindle_maintenance` queue |
| `lib/rindle/workers/abort_incomplete_uploads.ex` | 80 | 91 | VERIFIED | Contains `AbortIncompleteUploads`; `:rindle_maintenance` queue |
| `test/rindle/ops/metadata_backfill_test.exs` | 120 | 218 | VERIFIED | Contains `backfill_metadata` tests |
| `test/rindle/workers/maintenance_workers_test.exs` | 120 | 182 | VERIFIED | Contains `CleanupOrphans` tests |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `rindle.cleanup_orphans.ex` | `upload_maintenance.ex` | `alias + UploadMaintenance.cleanup_orphans/1` | WIRED | Line 56/78 |
| `rindle.abort_incomplete_uploads.ex` | `media_upload_session.ex` | `abort_incomplete_uploads/1` queries signed/uploading; FSM transition in service | WIRED | expires_at/state terms verified; FSM gates in upload_maintenance.ex:283 |
| `upload_maintenance.ex` | `Rindle.Storage` | `attempt_storage_delete/2` calls `storage_mod.delete/2` | WIRED | Lines 248–264 |
| `rindle.regenerate_variants.ex` | `variant_maintenance.ex` | `alias + VariantMaintenance.regenerate_variants/1` | WIRED | Lines 65/83 |
| `rindle.verify_storage.ex` | `variant_maintenance.ex` | `alias + VariantMaintenance.verify_storage/1` | WIRED | Destructures `fsm_blocked` from report (lines 104–108); prints five fields |
| `variant_maintenance.ex` | `Rindle.Storage` | `check_object/1` calls `storage_adapter.head/2` | WIRED | Line 260 |
| `variant_maintenance.ex` | `media_variant.ex` | `from v in MediaVariant` queries, `MediaVariant.changeset` in mark_missing | WIRED | Lines 87, 327 |
| `rindle.backfill_metadata.ex` | `metadata_backfill.ex` | `alias + MetadataBackfill.backfill_metadata/1` | WIRED | Lines 62/98 |
| `workers/cleanup_orphans.ex` | `upload_maintenance.ex` | `alias + UploadMaintenance.cleanup_orphans/1` | WIRED | Lines 63/76 |
| `workers/abort_incomplete_uploads.ex` | `upload_maintenance.ex` | `alias + UploadMaintenance.abort_incomplete_uploads/1` | WIRED | Lines 69/73 |
| `enqueue_job/2` | `Oban.Job` | `conflict?` field pattern match on `{:ok, %Oban.Job{conflict?: true}}` | WIRED | variant_maintenance.ex line 120; locked by test line 217 |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|---------------------|--------|
| `upload_maintenance.ex` | `sessions` | `Repo.all(from s in MediaUploadSession ...)` | Yes — DB query | FLOWING |
| `variant_maintenance.ex` | `rows` | `Repo.all(from v in MediaVariant, join: a in MediaAsset ...)` | Yes — DB query | FLOWING |
| `variant_maintenance.ex` | `result` (verify) | `check_object/1` HEAD-checks storage per row | Yes — storage + DB | FLOWING |
| `metadata_backfill.ex` | `assets` | `Repo.all(from a in MediaAsset where a.state in ...)` | Yes — DB query | FLOWING |
| `rindle.cleanup_orphans.ex` | `report` | Delegates to `UploadMaintenance.cleanup_orphans/1` | Yes — via service | FLOWING |
| `rindle.verify_storage.ex` | `report` (five fields) | Delegates to `VariantMaintenance.verify_storage/1` | Yes — storage + DB | FLOWING |

### Behavioral Spot-Checks

| Behavior | Result | Status |
|----------|--------|--------|
| Full project test suite (`mix test --seed 0`) | 145 tests, 0 failures, 1 skipped | PASS |
| `verify_result` type includes `fsm_blocked` field | `fsm_blocked: non_neg_integer()` at line 47 of variant_maintenance.ex | PASS |
| `mark_missing/2` returns `:fsm_blocked` on FSM rejection | `{:error, {:invalid_transition, _, _}} -> :fsm_blocked` at line 350 | PASS |
| `do_verify_storage` accumulates `fsm_blocked` separately | `Map.update!(acc, :fsm_blocked, &(&1 + 1))` at line 205 | PASS |
| Mix task prints `fsm_blocked` counter | `Mix.shell().info("  fsm_blocked:  #{fsm_blocked}")` at line 113 of verify_storage.ex | PASS |
| Mix task exits non-zero on `errors > 0` only (not `fsm_blocked`) | `if errors > 0 do ... System.halt(1)` at line 117; `fsm_blocked` not in condition | PASS |
| FSM regression test: `failed` variant counted as `fsm_blocked` not `errors` | `assert result.fsm_blocked == 1; assert result.errors == 0` at lines 323–325 | PASS |
| FSM regression test: `stale` variant counted as `fsm_blocked` not `errors` | `assert result.fsm_blocked == 1; assert result.errors == 0` at lines 344–346 | PASS |
| Oban uniqueness contract test: second insert yields `conflict?: true` | `assert second_job.conflict?` at line 217 | PASS |
| Oban uniqueness DB-row-count test: `length(jobs) == 1` | `assert length(jobs) == 1` at line 177 | PASS |
| `--dry-run` registered in OptionParser strict list | `strict: [dry_run: :boolean, live: :boolean, storage: :string]` | PASS |
| `abort_incomplete_uploads/1` FSM gate active | `UploadSessionFSM.transition/3` called before changeset | PASS |
| `verify_storage` exits 1 on errors > 0 | `if errors > 0 do ... System.halt(1)` confirmed | PASS |

### Requirements Coverage

| Requirement | Plan | Description | Status | Evidence |
|-------------|------|-------------|--------|----------|
| OPS-01 | 04-01 | `mix rindle.cleanup_orphans` deletes expired sessions and staged objects | SATISFIED | `UploadMaintenance.cleanup_orphans/1` with `dry_run: false` via `--no-dry-run` or `--live` flag |
| OPS-02 | 04-01 | `mix rindle.cleanup_orphans` accepts `--dry-run` flag | SATISFIED | `dry_run: :boolean` in `strict` list (commit `2b09dbc`); `Keyword.fetch(opts, :dry_run)` honors the flag |
| OPS-03 | 04-02 | `mix rindle.regenerate_variants` enqueues jobs for stale/missing variants matching filters | SATISFIED | `@regeneration_states`, filter composition, Oban insert with uniqueness; contract locked by CI tests |
| OPS-04 | 04-02 | `--profile` and `--variant` flags accepted | SATISFIED | `strict: [profile: :string, variant: :string]` in OptionParser |
| OPS-05 | 04-02 | `mix rindle.verify_storage` reconciles DB records against storage and marks missing | SATISFIED | HEAD-check loop, FSM-gated `mark_missing/2`, changeset update; `fsm_blocked` classified separately |
| OPS-06 | 04-02 | `mix rindle.verify_storage` outputs summary (checked, missing, present, errors) | SATISFIED | Five-field `Mix.shell().info` output (checked, present, missing, fsm_blocked, errors) confirmed |
| OPS-07 | 04-01 | `mix rindle.abort_incomplete_uploads` aborts signed/uploading sessions past TTL | SATISFIED | Query targets signed+uploading past `expires_at`; FSM gate; changeset update |
| OPS-08 | 04-03 | `mix rindle.backfill_metadata` reruns analyzer and updates metadata | SATISFIED | Download→analyze→persist chain in `MetadataBackfill`; per-asset failure accumulation |
| OPS-09 | 04-01/02/03 | All Mix tasks exit non-zero on errors | SATISFIED | `exit({:shutdown, 1})` and `System.halt(1)` paths verified in all 5 tasks; `fsm_blocked` correctly excluded from exit-1 trigger in `verify_storage` |

### Anti-Patterns Found

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| `lib/rindle/ops/metadata_backfill.ex:215-217` | `File.rm(path)` return value discarded | INFO | Benign; cleanup failure invisible but non-fatal (IN-04, not in scope) |

No blockers. No new anti-patterns introduced by `b93e632`.

### Human Verification Required

None. Both previously-flagged items were shifted left to CI in commit `b93e632` and confirmed resolved in `178ee3d`.

### Gaps Summary

No gaps. All 5 ROADMAP success criteria verified. All 9 OPS-XX requirements satisfied. The two human verification items from the previous cycle are now covered by automated CI tests:

- **CR-03 (Oban uniqueness):** Two complementary tests lock the contract — a `conflict?: true` assertion on the raw Oban API, and a `length(jobs) == 1` DB-row-count check. Both exercise the real `Oban.Engines.Basic` path. CI runs `mix test` on every PR (`.github/workflows/ci.yml:85`).

- **CR-07 (FSM-blocked exit code):** The `:fsm_blocked` counter is a design-level separation: FSM invariant enforcement on terminal states is informational (no exit-1), while true infrastructure failures (storage connection, auth, adapter resolution) remain exit-1. Two regression tests pin the contract. The Mix task's `moduledoc` documents the exit-code semantics for operators.

Test suite baseline: **145 tests, 0 failures, 1 skipped** (seed 0, confirmed by live run).

---

_Verified: 2026-04-26T14:10:00Z_
_Verifier: Claude (gsd-verifier)_
