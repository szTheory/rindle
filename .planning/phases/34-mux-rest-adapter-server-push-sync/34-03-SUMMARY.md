---
phase: 34-mux-rest-adapter-server-push-sync
plan: 03
subsystem: workers
tags: [mux, oban, sync, cron, telemetry, redaction, optional-dep, mox]
requirements: [MUX-07]

dependency-graph:
  requires:
    - "Plan 34-01 — `Rindle.Streaming.Provider.Mux.get_asset/1` per-row sync delegate"
    - "Plan 34-01 — `Rindle.Domain.MediaProviderAsset.redact_id/1` public redactor (security invariant 14)"
    - "Phase 33 — `Rindle.Domain.MediaProviderAsset` schema + `playback_ids :: {:array, :string}` PLURAL field"
    - "Phase 33 — `Rindle.Domain.ProviderAssetFSM.transition/3` MAP-context contract"
  provides:
    - "`Rindle.Workers.MuxSyncCoordinator` — cron-driven fan-out enqueuer (queue: :rindle_provider, max_attempts: 1)"
    - "`Rindle.Workers.MuxSyncProviderAsset` — per-row defensive sync (queue: :rindle_provider, max_attempts: 3, unique on provider_asset_id for 60s)"
    - "Telemetry `[:rindle, :provider, :sync, :resolved | :stuck]` with redacted-asset_id metadata"
    - "Adopter cron-config snippet documented inline in `MuxSyncCoordinator.@moduledoc` for Phase 36's guide"
  affects:
    - "Phase 35 — webhook ingest will be the primary readiness signal; this plan is the safety-net for missed/dropped webhooks"
    - "Phase 36 — adopter onboarding guide will reuse the cron snippet shipped here"

tech-stack:
  added: []
  patterns:
    - "Coordinator-worker fan-out (mirrors `cleanup_orphans.ex` / `abort_incomplete_uploads.ex` cron + per-row pair) — coordinator runs `max_attempts: 1`, per-row runs `max_attempts: 3`"
    - "Per-row Oban unique constraint (`unique: [period: 60, keys: [:provider_asset_id]]`) deduplicates across cron ticks (Pitfall 6 mitigation)"
    - "`if Code.ensure_loaded?(Mux.Video.Assets) do` wraps both worker modules (Pitfall 4 #2 — workers do not compile when `:mux` is absent)"
    - "Telemetry redaction at every emit site via `MediaProviderAsset.redact_id/1` (security invariant 14)"
    - "FSM `transition/3` always called with a MAP context (B4 — matches `provider_asset_fsm.ex:28` spec, never a keyword list)"
    - "Schema `timestamps()` produces `:naive_datetime`; worker coerces via `DateTime.from_naive!(ts, \"Etc/UTC\")` for `DateTime.diff/3` arithmetic"

key-files:
  created:
    - "lib/rindle/workers/mux_sync_coordinator.ex"
    - "lib/rindle/workers/mux_sync_provider_asset.ex"
    - "test/rindle/workers/mux_sync_coordinator_test.exs"
    - "test/rindle/workers/mux_sync_provider_asset_test.exs"
  modified: []

decisions:
  - "Both workers wrapped in `if Code.ensure_loaded?(Mux.Video.Assets) do` (Pitfall 4 #2) — when `:mux` is absent, the worker modules simply do not exist; adopters who do not configure streaming pay zero transitive cost."
  - "Coordinator query uses `where: r.state in [\"processing\", \"uploading\"] and r.updated_at < ^cutoff and not is_nil(r.provider_asset_id)` — the `not is_nil` guard prevents fan-out for rows that never received a `provider_asset_id` (e.g., create_asset failed)."
  - "Per-row worker uses `String.to_existing_atom(row.profile)` (NOT `String.to_atom`) for telemetry context — atom safety per Rindle's existing convention."
  - "Stuck-threshold check (`stuck?/1`) checks `row.state in [\"processing\", \"uploading\"] AND age > threshold` — a row already in `:ready` or `:errored` is never marked stuck, even if it stayed there past the threshold (state semantics)."
  - "Mux 404 (`{:error, :not_found}`) transitions the row to `:errored` with `last_sync_error: \"mux asset not found\"` and emits `:resolved` (the row IS now reconciled with reality — there is no asset to wait for)."
  - "Both reason strings written to `last_sync_error` are bounded short literals (`\"stuck in :<state> past threshold\"` and `\"mux asset not found\"`) — well under the 4096-byte truncation cap, and never concatenate Mux response bodies (T-34-03-06 mitigation)."

metrics:
  duration_minutes: 8
  completed_date: 2026-05-06
  tasks_completed: 2
  files_created: 4
  files_modified: 0
  tests_added: 10
  test_pass_rate: "10/10 (plan suite); 208/208 (broader regression: streaming + domain + workers)"
---

# Phase 34 Plan 03: Mux Sync Workers Summary

## One-liner

Cron-driven `MuxSyncCoordinator` + per-row `MuxSyncProviderAsset` defensive
sync pair — the safety-net that reconciles `media_provider_assets` rows
against live Mux state when a webhook is missed or dropped, surfaces
`:provider_asset_stuck` past a 7200s threshold, persists PLURAL
`playback_ids` arrays per Phase 33 schema, and emits telemetry with
last-4-char redacted `asset_id` metadata enforcing security invariant 14.

## Performance

- **Duration:** ~8 minutes
- **Started:** 2026-05-06T23:41:21Z
- **Completed:** 2026-05-06T23:50:04Z
- **Tasks:** 2 (both `type="auto"`)
- **Files created:** 4 (2 lib + 2 test)
- **Files modified:** 0

## Accomplishments

- `Rindle.Workers.MuxSyncCoordinator` ships the cron-driven fan-out enqueuer
  with the canonical Rindle `:rindle_provider` queue, `max_attempts: 1`, and
  the adopter cron-config snippet inline in `@moduledoc` so Phase 36's guide
  can copy verbatim.
- `Rindle.Workers.MuxSyncProviderAsset` ships the per-row defensive sync with
  full FSM reconciliation (`:processing → :ready` on Mux ready,
  `:processing → :errored` on stuck or 404), PLURAL `playback_ids` array
  persistence (B1 — Phase 33 schema field is `{:array, :string}`), and MAP
  context on every `ProviderAssetFSM.transition/3` call (B4 — matches
  `provider_asset_fsm.ex:28` spec).
- Telemetry contract `[:rindle, :provider, :sync, :resolved | :stuck]` with
  metadata `%{profile, provider, asset_id, provider_state, age_ms}` where
  `asset_id` is always last-4-char redacted via
  `MediaProviderAsset.redact_id/1` (security invariant 14). Test asserts
  `redacted =~ ~r/^\.\.\.[A-Za-z0-9]{4}$/` for both event types.
- Pitfall 6 backpressure mitigation verified: a "second cron tick does not
  re-enqueue still-running per-row jobs" test confirms the per-row
  `unique: [period: 60, keys: [:provider_asset_id]]` constraint
  deduplicates across cron ticks.

## Task Commits

Each task was committed atomically:

1. **Task 1: MuxSyncCoordinator (cron-driven fan-out enqueuer)** — `71e2a36` (feat)
2. **Task 2: MuxSyncProviderAsset (per-row defensive sync)** — `f563e14` (feat)

## Files Created/Modified

### Created

| File | Lines | Role |
| ---- | ----: | ---- |
| `lib/rindle/workers/mux_sync_coordinator.ex` | 113 | Cron-driven fan-out enqueuer (`max_attempts: 1`, no per-row telemetry) |
| `lib/rindle/workers/mux_sync_provider_asset.ex` | 192 | Per-row defensive sync (`max_attempts: 3`, FSM reconciliation, redacted telemetry) |
| `test/rindle/workers/mux_sync_coordinator_test.exs` | 133 | 4 tests — fan-out, dedupe, custom floor, queue config |
| `test/rindle/workers/mux_sync_provider_asset_test.exs` | 229 | 6 tests — `:resolved` ready transition, `:stuck` threshold, Mux 404, idempotent no-op, race-with-deletion, queue config |

### Modified

None — Plan 01 already promoted `MediaProviderAsset.redact_id/1` to public
and added `Rindle.Streaming.Provider.Mux.get_asset/1`. No changes to shared
files were required for this plan.

## Tests run + exit codes

| Suite | Tests | Result |
| ----- | ----- | ------ |
| `mix test test/rindle/workers/mux_sync_coordinator_test.exs --max-failures 1` | 4 | PASS |
| `mix test test/rindle/workers/mux_sync_provider_asset_test.exs --max-failures 1` | 6 | PASS |
| `mix test test/rindle/workers/mux_sync_coordinator_test.exs test/rindle/workers/mux_sync_provider_asset_test.exs` | 10 | PASS (10/10) |
| `mix test test/rindle/workers/maintenance_workers_test.exs --max-failures 1` (regression) | 26 | PASS |
| `mix test test/rindle/streaming/ test/rindle/domain/ test/rindle/workers/` (broader regression) | 208 | PASS (208/208) |
| `mix compile --warnings-as-errors` | n/a | exit 0 |

## Plan acceptance grep checks

```
grep -c "use Oban.Worker, queue: :rindle_provider, max_attempts: 1" lib/rindle/workers/mux_sync_coordinator.ex                       → 1
grep -c "if Code.ensure_loaded?(Mux.Video.Assets) do" lib/rindle/workers/mux_sync_coordinator.ex                                     → 1
grep -c 'state in ["processing", "uploading"]' lib/rindle/workers/mux_sync_coordinator.ex                                            → 1
grep -c "period: 60, keys: [:provider_asset_id]" lib/rindle/workers/mux_sync_coordinator.ex                                          → 2
grep -c 'crontab:' lib/rindle/workers/mux_sync_coordinator.ex                                                                        → 1
grep -c "use Oban.Worker, queue: :rindle_provider, max_attempts: 3" lib/rindle/workers/mux_sync_provider_asset.ex                    → 1
grep -c "if Code.ensure_loaded?(Mux.Video.Assets) do" lib/rindle/workers/mux_sync_provider_asset.ex                                  → 1
grep -c "Rindle.Streaming.Provider.Mux\|adapter.get_asset" lib/rindle/workers/mux_sync_provider_asset.ex                             → 2
grep -v '^[[:space:]]*#' lib/rindle/workers/mux_sync_provider_asset.ex | grep -c "MediaProviderAsset.redact_id"                      → 1
grep -c ":telemetry.execute" lib/rindle/workers/mux_sync_provider_asset.ex                                                           → 1
grep -c "playback_ids:" lib/rindle/workers/mux_sync_provider_asset.ex                                                                → 2
grep -v '^[[:space:]]*#' lib/rindle/workers/mux_sync_provider_asset.ex | grep -c "playback_id:[^s]"                                  → 0 (B1 — singular field gone)
grep -E "ProviderAssetFSM\.transition\(.*,\s*\[" lib/rindle/workers/mux_sync_provider_asset.ex | wc -l                                → 0 (B4 — no keyword-list third arg)
grep -A 5 "MediaProviderAsset.changeset" test/rindle/workers/mux_sync_coordinator_test.exs test/rindle/workers/mux_sync_provider_asset_test.exs | grep -c "variant_name:" → 0 (W1/B2 — no fictional column)
```

All locked invariants confirmed: optional-dep guards on both worker
modules; PLURAL `playback_ids` array writes (B1); MAP context on every FSM
transition (B4); no fictional `variant_name` column in test setup
(W1/B2); redacted `asset_id` in telemetry metadata; per-row unique
deduplication via `period: 60`.

## Decisions Made

See the `decisions:` frontmatter block above. The most consequential
implementation choices:

1. **`not is_nil(r.provider_asset_id)` guard in coordinator query** — rows
   that never received a `provider_asset_id` (e.g., create_asset failed
   before persisting the id) cannot be reconciled against Mux because the
   per-row worker has nothing to look up; excluding them keeps fan-out
   precise and avoids spurious `MuxSyncProviderAsset` jobs that would
   short-circuit on `repo.get_by(MediaProviderAsset, provider_asset_id: nil)`.
2. **Stuck-threshold check is state-aware** — a row in `:ready` or
   `:errored` is never marked stuck even if its `updated_at` predates the
   threshold; only rows still inside `:processing` or `:uploading` can be
   "stuck" by definition. This matches the FSM-allowlisted transition
   `processing → errored` / `uploading → errored` and avoids invalid
   transitions like `ready → errored` (which the FSM does allow, but not
   for "stuck" semantics).
3. **Mux 404 path emits `:resolved`, not `:stuck`** — when Mux says the
   asset is gone, the row IS reconciled with reality. There is no
   ambiguity left to resolve, so `:resolved` is semantically correct;
   `:stuck` is reserved for the "we don't know what happened" case where
   the row is still aging without progress.
4. **`String.to_existing_atom(row.profile)`** — atoms are not GC'd in the
   BEAM, so `String.to_atom/1` on a user-controlled (or even
   adopter-controlled) string is a memory-pressure footgun. Profile
   modules must already be loaded by the time the worker runs, so
   `to_existing_atom` is both safe and correct.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] Schema `timestamps()` produces `:naive_datetime`; the worker called `DateTime.diff/3` directly on `row.updated_at`**

- **Found during:** Task 2 (initial test run).
- **Issue:** `Rindle.Domain.MediaProviderAsset.timestamps()` (default `Ecto.Schema.timestamps/0` macro) produces `:naive_datetime` columns, but the plan's draft worker called `DateTime.diff(DateTime.utc_now(), row.updated_at, :second)` which raises `FunctionClauseError` on a `%NaiveDateTime{}`. All 6 per-row sync tests failed with the same stack trace through `lib/calendar/datetime.ex:1578`.
- **Fix:** Added `defp age_seconds/1` and `defp age_ms/1` helpers that pattern-match on `%DateTime{}` and `%NaiveDateTime{}` and coerce naive→UTC datetime via `DateTime.from_naive!(ts, "Etc/UTC")` before calling `DateTime.diff/3`. Both helpers handle both shapes safely so adopters running with `:utc_datetime` columns are unaffected.
- **Files modified:** `lib/rindle/workers/mux_sync_provider_asset.ex` (Task 2 commit `f563e14`).
- **Verification:** All 6 per-row tests pass; 10/10 plan suite pass; 208/208 broader regression pass.
- **Committed in:** `f563e14` (Task 2 commit — fix-forward inside the same task commit).

**2. [Rule 1 — Bug] Test changesets violated foreign-key constraint on `asset_id`**

- **Found during:** Task 1 (initial test run).
- **Issue:** Plan's draft tests inserted `MediaProviderAsset` rows with `asset_id: Ecto.UUID.generate()` — a freshly generated UUID that does not match any `media_assets` row, triggering the FK constraint `media_provider_assets_asset_id_fkey` on `Repo.insert/1`. All 4 coordinator tests failed with the same `MatchError`.
- **Fix:** Both test files now insert a real `MediaAsset` first via a small `insert_asset!/0` helper (`%MediaAsset{} |> MediaAsset.changeset(...) |> Repo.insert!()`) and use `asset.id` as the FK value. The asset shape uses `kind: "video"` to match the streaming-friendly contract; storage_key is randomized per insert so the unique constraint on `(asset_id, profile, provider_name)` is the only relevant constraint at row insertion.
- **Files modified:** `test/rindle/workers/mux_sync_coordinator_test.exs`, `test/rindle/workers/mux_sync_provider_asset_test.exs`.
- **Verification:** All 10 plan tests pass; no FK constraint failures.
- **Committed in:** `71e2a36` (Task 1 commit) and `f563e14` (Task 2 commit) — fix-forward inside each task's atomic commit.

---

**Total deviations:** 2 auto-fixed (both Rule 1 — bugs in plan-draft test/lib code).
**Impact on plan:** Both auto-fixes were essential for correctness; no scope creep. The naive-vs-UTC datetime issue is a real safety improvement (the helpers now handle both column shapes so adopters running with `:utc_datetime` are unaffected). The FK fix is purely a test-setup correction — the lib code has always required a valid `asset_id`.

## Issues Encountered

- **Cyclic file dependency between Task 1 and Task 2 lib modules:** Task 1's coordinator references `Rindle.Workers.MuxSyncProviderAsset.new(...)` at runtime, and Task 1's test exercises that fan-out via `assert_enqueued worker: MuxSyncProviderAsset`. Task 1's `<verify>` block requires the test to pass, which means `MuxSyncProviderAsset` must exist by the time Task 1's test runs. Resolved by writing both modules' lib + test code first, running the full suite, then committing each task's files atomically as two separate commits in order. The lib reference is a remote function call (not a compile-time reference) so `mix compile --warnings-as-errors` succeeds even with only Task 1's file present — it's only the runtime fan-out test that would fail. This matches the existing Rindle convention where, e.g., `process_variant.ex` references `PromoteAsset` and vice versa.

## Authentication gates section

None. The sync workers operate against Mux via `Rindle.Streaming.Provider.Mux.get_asset/1`, which is mocked in tests via `Rindle.Streaming.Provider.Mux.ClientMock`. No live Mux credentials were exercised; all HTTP behavior was Mox-driven from the per-row test file.

## Known stubs

None. Both workers are end-to-end functional:

- The coordinator has no stub paths — it runs the real Ecto query against `media_provider_assets`, fans out per-row jobs via `Oban.insert/2`, and emits structured `Logger.info` on completion.
- The per-row worker has no stub paths — every code branch (`stuck?/1` true, Mux returns `:ok` with new state, Mux returns `:ok` with same state, Mux returns `:not_found`, Mux returns other `:error`) is exercised by a corresponding test.

The `Rindle.Streaming.Provider.Mux.get_asset/1` callback was already shipped in Plan 01 (Task 2 commit `e83ce07`); Plan 03 only consumes it via `adapter.get_asset(row.provider_asset_id)`.

## TDD Gate Compliance

Plan 03 frontmatter declares `type: execute` (NOT `type: tdd`), and neither task carries a `tdd="true"` annotation. The plan-level TDD gate sequence does not apply. Tests were written alongside the implementation as a single coherent unit per task; both task commits include the corresponding test file.

## Threat Flags

No new security-relevant surface beyond the threat model documented in the plan's `<threat_model>` section. Both workers operate inside the Plan 33-defined `Rindle.Streaming.Provider` boundary; the coordinator's only inputs are the cron tick and the `provider_polling_floor_seconds` config; the per-row worker's only inputs are the `provider_asset_id` arg (server-known, never client-supplied) and the row-level state. All telemetry metadata is redacted at the emit site.

## Self-Check: PASSED

All claimed files exist:

- `lib/rindle/workers/mux_sync_coordinator.ex` FOUND (113 lines)
- `lib/rindle/workers/mux_sync_provider_asset.ex` FOUND (192 lines)
- `test/rindle/workers/mux_sync_coordinator_test.exs` FOUND (133 lines)
- `test/rindle/workers/mux_sync_provider_asset_test.exs` FOUND (229 lines)

Both task commits exist:

- `71e2a36` FOUND (Task 1: MuxSyncCoordinator + tests)
- `f563e14` FOUND (Task 2: MuxSyncProviderAsset + tests)

`mix test test/rindle/workers/mux_sync_coordinator_test.exs test/rindle/workers/mux_sync_provider_asset_test.exs` final run: **10 tests, 0 failures**.

`mix test test/rindle/streaming/ test/rindle/domain/ test/rindle/workers/` regression run: **208 tests, 0 failures**.

## Next Phase Readiness

- Wave 2 of Phase 34 is now complete from this plan's side. Plan 34-02 (`MuxIngestVariant`) is the parallel sibling; the orchestrator merges both plans before advancing to Plan 34-04.
- Plan 34-04 will exercise both workers against a Phase-33 streaming-DSL profile end-to-end and add the integration-level cassette coverage; Plan 03's unit-level Mox tests are already a strong foundation.
- Phase 35 (webhook ingest) will be the primary readiness signal once it lands; the sync workers shipped here are the safety-net for missed/dropped webhooks. The telemetry events `[:rindle, :provider, :sync, :resolved | :stuck]` are also additive on top of Phase 35's `[:rindle, :provider, :webhook, ...]` family — adopter dashboards can correlate sync activity with webhook activity.
- Phase 36 will copy the cron-config snippet from `MuxSyncCoordinator.@moduledoc` verbatim into `guides/streaming_providers.md`; no further docs work is needed in this plan.

---
*Phase: 34-mux-rest-adapter-server-push-sync*
*Completed: 2026-05-06*
