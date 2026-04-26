---
phase: 04-day-2-operations
verified: 2026-04-26T14:30:00Z
status: human_needed
score: 5/5 roadmap success criteria verified
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 4/5
  gaps_closed:
    - "OPS-02 / SC-1: `--dry-run` flag now registered in OptionParser strict mode (`dry_run: :boolean`); `--dry-run`, `--no-dry-run`, and `--live` all work; default remains safe (dry-run when no flag given)"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Oban uniqueness keyword shape (CR-03)"
    expected: "Two back-to-back calls to `mix rindle.regenerate_variants` (or `VariantMaintenance.regenerate_variants/1`) result in exactly one Oban job per `(asset_id, variant_name)` pair in a production Oban 2.21 environment, not just in the sandbox test adapter."
    why_human: "The `unique: [fields: [:args, :worker, :queue], keys: [:asset_id, :variant_name], ...]` shape is tested under Oban.Testing's sandbox adapter, which may not exercise the real uniqueness plugin. The `keys:` sub-option needs validation against Oban 2.21 community edition — this option exists in Oban Pro and Oban 2.17+ community, but the exact field names can vary by patch release."
  - test: "verify_storage exit-code behavior for FSM-blocked transitions (CR-07)"
    expected: "Operator understands and accepts that a `failed` variant whose storage object disappears is counted as `:errors` (not `:missing`) by `mix rindle.verify_storage`, which then exits non-zero under the CR-05 contract. Confirm whether a separate `:fsm_blocked` counter is desired to distinguish real storage-connection errors from FSM-rejected transitions."
    why_human: "This is a design decision about observable exit semantics, not a correctness bug. The current behavior is internally consistent but may surprise operators who expect `verify_storage` to only exit non-zero on infrastructure failures, not on FSM invariant enforcement."
---

# Phase 4: Day-2 Operations Verification Report

**Phase Goal:** Production systems can be maintained without manual SQL — orphans cleaned, stale variants regenerated, storage reconciled, and incomplete uploads aborted — all scriptable and CI-friendly
**Verified:** 2026-04-26T14:30:00Z
**Status:** human_needed
**Re-verification:** Yes — after gap closure (commit `2b09dbc`)

## Re-verification Summary

**Previous status:** gaps_found (4/5 SC verified)
**Current status:** human_needed (5/5 SC verified)

**Gap closed:** OPS-02 / SC-1 — `dry_run: :boolean` added to `OptionParser strict` list in commit `2b09dbc`. The `--dry-run` and `--no-dry-run` flags now work as documented. `--live` is retained as a backward-compatible alias. Default behavior (no flag given) remains safe/non-destructive.

**Regressions:** None. Test suite: 144 tests, 0 failures, 1 skipped on seed 0 (unchanged from pre-fix baseline).

## Goal Achievement

### Observable Truths (from ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC-1 | `mix rindle.cleanup_orphans --dry-run` logs without deleting; without it, deletes expired sessions and objects | VERIFIED | `strict: [dry_run: :boolean, live: :boolean, storage: :string]` — `--dry-run` now registered; `Keyword.fetch(opts, :dry_run)` returns `{:ok, true}`; `--no-dry-run` returns `{:ok, false}`; no-flag default is `not Keyword.get(opts, :live, false)` = `true` |
| SC-2 | `mix rindle.regenerate_variants --profile Avatar --variant thumbnail` enqueues jobs only for matching stale/missing variants | VERIFIED | `--profile` and `--variant` flags parsed; `maybe_filter_profile/2` and `maybe_filter_variant_name/2` compose query; tests confirm filtering |
| SC-3 | `mix rindle.verify_storage` outputs summary (total checked, missing, present, errors) and marks absent variants as `missing` | VERIFIED | Four-field summary output confirmed in source; `mark_missing/2` via FSM gate and changeset; tests confirm |
| SC-4 | `mix rindle.abort_incomplete_uploads` transitions `signed`/`uploading` sessions past TTL to `expired` | VERIFIED | `abort_incomplete_uploads` delegates to `UploadMaintenance.abort_incomplete_uploads/1` which gates on FSM before changeset; tests confirm |
| SC-5 | All Mix tasks exit non-zero on errors | VERIFIED | All five tasks use `exit({:shutdown, 1})` or `System.halt(1)` on `{:error, reason}` and on per-item error counts |

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
| 2 | `mix rindle.verify_storage` compares DB to storage and marks missing variants | VERIFIED | HEAD-check loop with FSM-gated `mark_missing/2`; FSM-blocked transitions counted as `:errors` |
| 3 | `mix rindle.verify_storage` prints checked/missing/present/errors summary | VERIFIED | Four `Mix.shell().info` lines emit each field; exits non-zero when `errors > 0` |
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
| `lib/rindle/ops/variant_maintenance.ex` | 140 | 344 | VERIFIED | Exports `regenerate_variants/1`, `verify_storage/1` |
| `lib/mix/tasks/rindle.regenerate_variants.ex` | 90 | 104 | VERIFIED | Contains `regenerate_variants` delegation |
| `lib/mix/tasks/rindle.verify_storage.ex` | 90 | 118 | VERIFIED | Contains `verify_storage` delegation |
| `test/rindle/ops/variant_maintenance_test.exs` | 140 | 310 | VERIFIED | Contains `verify_storage` tests; substantive coverage |
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
| `rindle.abort_incomplete_uploads.ex` | `media_upload_session.ex` | `abort_incomplete_uploads/1` queries signed/uploading; FSM transition in service | WIRED | expires_at/state terms verified in docs; FSM gates in upload_maintenance.ex:283 |
| `upload_maintenance.ex` | `Rindle.Storage` | `attempt_storage_delete/2` calls `storage_mod.delete/2` | WIRED | Lines 248–264 |
| `rindle.regenerate_variants.ex` | `variant_maintenance.ex` | `alias + VariantMaintenance.regenerate_variants/1` | WIRED | Lines 65/83 |
| `rindle.verify_storage.ex` | `Rindle.Storage` | `check_object/1` calls `storage_adapter.head/2` | WIRED | Line 246 in variant_maintenance.ex |
| `variant_maintenance.ex` | `media_variant.ex` | `from v in MediaVariant` queries, `MediaVariant.changeset` in mark_missing | WIRED | Lines 86, 311 |
| `rindle.backfill_metadata.ex` | `metadata_backfill.ex` | `alias + MetadataBackfill.backfill_metadata/1` | WIRED | Lines 62/98 |
| `workers/cleanup_orphans.ex` | `upload_maintenance.ex` | `alias + UploadMaintenance.cleanup_orphans/1` | WIRED | Lines 63/76 |
| `workers/abort_incomplete_uploads.ex` | `upload_maintenance.ex` | `alias + UploadMaintenance.abort_incomplete_uploads/1` | WIRED | Lines 69/73 |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|---------------------|--------|
| `upload_maintenance.ex` | `sessions` | `Repo.all(from s in MediaUploadSession ...)` | Yes — DB query | FLOWING |
| `variant_maintenance.ex` | `rows` | `Repo.all(from v in MediaVariant, join: a in MediaAsset ...)` | Yes — DB query | FLOWING |
| `metadata_backfill.ex` | `assets` | `Repo.all(from a in MediaAsset where a.state in ...)` | Yes — DB query | FLOWING |
| `rindle.cleanup_orphans.ex` | `report` | Delegates to `UploadMaintenance.cleanup_orphans/1` | Yes — via service | FLOWING |
| `rindle.verify_storage.ex` | summary fields | Delegates to `VariantMaintenance.verify_storage/1` which HEAD-checks storage | Yes — storage + DB | FLOWING |

### Behavioral Spot-Checks

| Behavior | Result | Status |
|----------|--------|--------|
| Full project test suite (`mix test --seed 0`) | 144 tests, 0 failures, 1 skipped | PASS |
| `--dry-run` registered in OptionParser strict list | `strict: [dry_run: :boolean, live: :boolean, storage: :string]` line 69 | PASS |
| `--dry-run` sets `dry_run? = true` | `Keyword.fetch(opts, :dry_run)` returns `{:ok, true}` | PASS |
| `--no-dry-run` sets `dry_run? = false` | `Keyword.fetch(opts, :dry_run)` returns `{:ok, false}` | PASS |
| `--live` sets `dry_run? = false` | `:error` branch: `not Keyword.get(opts, :live, false)` = `not true` = `false` | PASS |
| no flags sets `dry_run? = true` | `:error` branch: `not Keyword.get(opts, :live, false)` = `not false` = `true` | PASS |
| `cleanup_orphans/1` dry_run default is `true` | `Keyword.get(opts, :dry_run, true)` — confirmed in service | PASS |
| `abort_incomplete_uploads/1` FSM gate active | `UploadSessionFSM.transition/3` called before changeset — confirmed | PASS |
| Oban uniqueness regression test passes | `second.enqueued == 0`, `length(jobs) == 1` — test passes seed 0 | PASS |
| `verify_storage` exits 1 on errors > 0 | `if errors > 0 do ... System.halt(1)` — confirmed | PASS |

### Requirements Coverage

| Requirement | Plan | Description | Status | Evidence |
|-------------|------|-------------|--------|----------|
| OPS-01 | 04-01 | `mix rindle.cleanup_orphans` deletes expired sessions and staged objects | SATISFIED | `UploadMaintenance.cleanup_orphans/1` with `dry_run: false` via `--no-dry-run` or `--live` flag |
| OPS-02 | 04-01 | `mix rindle.cleanup_orphans` accepts `--dry-run` flag | SATISFIED | `dry_run: :boolean` in `strict` list (commit `2b09dbc`); `Keyword.fetch(opts, :dry_run)` honors the flag |
| OPS-03 | 04-02 | `mix rindle.regenerate_variants` enqueues jobs for stale/missing variants matching filters | SATISFIED | `@regeneration_states`, filter composition, Oban insert with uniqueness |
| OPS-04 | 04-02 | `--profile` and `--variant` flags accepted | SATISFIED | `strict: [profile: :string, variant: :string]` in OptionParser |
| OPS-05 | 04-02 | `mix rindle.verify_storage` reconciles DB records against storage and marks missing | SATISFIED | HEAD-check loop, FSM-gated `mark_missing/2`, changeset update |
| OPS-06 | 04-02 | `mix rindle.verify_storage` outputs summary (checked, missing, present, errors) | SATISFIED | Four-field `Mix.shell().info` output confirmed |
| OPS-07 | 04-01 | `mix rindle.abort_incomplete_uploads` aborts signed/uploading sessions past TTL | SATISFIED | Query targets signed+uploading past `expires_at`; FSM gate; changeset update |
| OPS-08 | 04-03 | `mix rindle.backfill_metadata` reruns analyzer and updates metadata | SATISFIED | Download→analyze→persist chain in `MetadataBackfill`; per-asset failure accumulation |
| OPS-09 | 04-01/02/03 | All Mix tasks exit non-zero on errors | SATISFIED | `exit({:shutdown, 1})` and `System.halt(1)` paths verified in all 5 tasks |

### Anti-Patterns Found

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| `lib/rindle/ops/metadata_backfill.ex:215-217` | `File.rm(path)` return value discarded | INFO | Benign; cleanup failure invisible but non-fatal (noted as IN-04 in review, not in scope) |

No blockers. The previously-blocking `--dry-run` anti-pattern is closed.

### Human Verification Required

#### 1. Oban Uniqueness Keyword Shape (CR-03)

**Test:** Run `mix rindle.regenerate_variants` twice in a row against a real PostgreSQL + Oban 2.21 instance (not sandbox). Verify that the second invocation enqueues 0 new jobs for the same `(asset_id, variant_name)` pairs.

**Expected:** Second call returns `enqueued: 0, skipped: N` where N equals the number of variants that had jobs from the first call. Only one Oban job row exists per `(asset_id, variant_name)` pair.

**Why human:** The `unique: [fields: [:args, :worker, :queue], keys: [:asset_id, :variant_name], ...]` shape is tested under `Oban.Testing`'s sandbox adapter, which may not exercise the real uniqueness plugin. The `keys:` sub-option specifically needs validation against Oban 2.21 community edition — this option exists in Oban Pro and Oban 2.17+ community, but the exact field names can vary by patch release.

#### 2. FSM-blocked Variants in verify_storage Exit Code (CR-07)

**Test:** Seed a `failed` variant with a `storage_key`. Run `mix rindle.verify_storage`. Verify the exit code and summary output match operator expectations.

**Expected:** When `VariantFSM.transition("failed", "missing")` is rejected, the variant is counted as `:errors` (not `:missing`), and the task exits non-zero. Confirm whether this is the desired UX or whether a separate `:fsm_blocked` counter should be introduced to distinguish FSM rejections from genuine storage-connection errors.

**Why human:** This is a design decision about observable exit semantics. The current behavior is internally consistent and the test suite confirms it, but it means `mix rindle.verify_storage` exits non-zero for `failed` variants with missing storage objects — a condition that may be expected rather than exceptional in production.

### Gaps Summary

No gaps remain. The single blocker from the initial verification (OPS-02 / SC-1 — `--dry-run` silently ignored by OptionParser strict mode) was closed in commit `2b09dbc`. The fix:

1. Adds `dry_run: :boolean` to `strict: [...]` so OptionParser accepts `--dry-run` and `--no-dry-run`
2. Preserves `--live` as a backward-compatible destructive alias
3. Uses `Keyword.fetch(opts, :dry_run)` with a fallback to `not Keyword.get(opts, :live, false)` so explicit `--dry-run` wins, and the no-flag default remains safe

All 5 ROADMAP success criteria are now satisfied. All 9 OPS-XX requirements are satisfied. Two items remain for human verification (Oban uniqueness plugin in production, and FSM-blocked exit-code semantics) — neither is a code correctness issue.

---

_Verified: 2026-04-26T14:30:00Z_
_Verifier: Claude (gsd-verifier)_
