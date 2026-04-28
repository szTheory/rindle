---
phase: 05-ci-1-0-readiness
plan: 01
subsystem: telemetry
tags: [telemetry, fsm, broker, delivery, oban-worker, contract-emission]

# Dependency graph
requires:
  - phase: 03-delivery-observability
    provides: Locked TEL-01..08 public event family contract (D-07/D-08/D-09)
  - phase: 04-day-2-operations
    provides: CleanupOrphans + AbortIncompleteUploads worker scaffolding
provides:
  - Real :telemetry.execute/3 emissions at all six contract sites (asset/variant state_change, upload start/stop, delivery signed, cleanup run × 2 workers)
  - ExUnit emission proofs using :telemetry_test.attach_event_handlers/2 with unique-ref handlers
  - Worker-layer-only invariant for [:rindle, :cleanup, :run] (Rindle.Ops.UploadMaintenance does not emit, locked by refute_received tests)
affects:
  - 05-02-PLAN (telemetry contract test — can now attach handlers and observe events firing)
  - Adopter dashboards/alerts that consume the public event family
  - Future phases adding new emission sites (must follow additive tap/2 pattern)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Additive telemetry emission via tap/2 (preserves :ok return)"
    - "Post-transaction emission only (Pitfall 1: never inside Repo.transaction or Ecto.Multi steps)"
    - ":unknown atom fallback for missing profile/adapter context"
    - "Worker-layer-only emission boundary for batch operations"

key-files:
  created:
    - test/rindle/telemetry/emission_test.exs
    - .planning/phases/05-ci-1-0-readiness/deferred-items.md
  modified:
    - lib/rindle/domain/asset_fsm.ex
    - lib/rindle/domain/variant_fsm.ex
    - lib/rindle/upload/broker.ex
    - lib/rindle/delivery.ex
    - lib/rindle/workers/cleanup_orphans.ex
    - lib/rindle/workers/abort_incomplete_uploads.ex
    - test/rindle/upload/broker_test.exs
    - test/rindle/delivery_test.exs
    - test/rindle/workers/maintenance_workers_test.exs
    - test/rindle/ops/upload_maintenance_test.exs

key-decisions:
  - "Use tap/2 for additive emission so the original :ok return value is preserved verbatim"
  - "Emit AFTER Repo.transaction/Ecto.Multi returns {:ok, ...} — never inside the transaction body (Pitfall 1)"
  - "Worker-layer-only emission for [:rindle, :cleanup, :run]; UploadMaintenance service does not emit (D-02, prevents double-counting)"
  - "Failed FSM transitions and broker/delivery error branches do NOT emit (D-03 invariant: success-only events)"
  - "Profile/adapter fall back to the :unknown atom (not nil) when absent from context, matching the locked metadata-key contract"
  - "Inline broker/delivery telemetry tests directly in their existing unit-test files rather than scaffolding flunk placeholders (Warning 3)"

patterns-established:
  - "Additive emission with tap/2: `:ok |> tap(fn _ -> :telemetry.execute(...) end)` keeps the public return contract intact"
  - "Post-transaction emission: pattern-match {:ok, ...} on the transaction result and emit only in the success branch"
  - "Worker-layer-only emission: cron worker emits :cleanup :run after Logger.info; the service it wraps does not emit"
  - "Telemetry test pattern: `:telemetry_test.attach_event_handlers(self(), [...])` per test, asserted with `assert_received`/`refute_received`"

requirements-completed:
  - TEL-01
  - TEL-02
  - TEL-03
  - TEL-04
  - TEL-05
  - TEL-06
  - TEL-07
  - TEL-08

# Metrics
duration: 6min
completed: 2026-04-26
---

# Phase 05 Plan 01: Telemetry Public-Contract Backfill Summary

**Wired real `:telemetry.execute/3` calls at all six locked event-family sites (asset/variant state_change, upload start/stop, delivery signed, cleanup run × 2 workers) so the Phase 3 TEL-01..08 contract is observable, not hypothetical.**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-04-26T21:42:00Z
- **Completed:** 2026-04-26T21:48:39Z
- **Tasks:** 3 / 3 complete
- **Files modified:** 10 (6 lib, 4 test) + 1 deferred-items doc + 1 new emission test file

## Accomplishments

- All six emission sites now fire `:telemetry.execute/3` with `profile` + `adapter` metadata and numeric measurements per the locked Phase 3 contract.
- Six new emission proofs (FSM tests + broker/delivery/worker telemetry describe blocks) demonstrate `assert_received` succeeds via `:telemetry_test.attach_event_handlers/2`.
- Three negative-path proofs (`refute_received`) lock in the success-only invariant: failed FSM transitions, missing storage objects, denied authorizers, and storage-adapter resolution failures do NOT emit.
- Worker-layer-only invariant locked by two `refute_received` tests against `Rindle.Ops.UploadMaintenance`, preventing future double-counting.

## Task Commits

Each task followed the TDD RED → GREEN cycle and committed atomically:

1. **Task 1 RED: failing FSM emission tests** — `cb36235` (test)
2. **Task 1 GREEN: emit state_change from AssetFSM and VariantFSM** — `746d1bc` (feat)
3. **Task 2 RED: failing broker + delivery emission tests** — `2e98304` (test)
4. **Task 2 GREEN: emit upload start/stop and delivery signed** — `40df389` (feat)
5. **Task 3 RED: failing cleanup-worker emission tests** — `9ccdceb` (test)
6. **Task 3 GREEN: emit cleanup run from worker layer** — `9a312d6` (feat)
7. **Deferred-items log (out-of-scope notes)** — `53722de` (chore)

No `refactor` commits were needed — the additive `tap/2` and post-transaction case-branch patterns were implemented cleanly the first time.

## Files Created/Modified

### Library code (six emission sites wired)

- `lib/rindle/domain/asset_fsm.ex` — `transition/3` emits `[:rindle, :asset, :state_change]` via `tap/2` on the success branch.
- `lib/rindle/domain/variant_fsm.ex` — `transition/3` emits `[:rindle, :variant, :state_change]`; third arg renamed `_context` → `context` (now used).
- `lib/rindle/upload/broker.ex` — `initiate_session/2` emits `[:rindle, :upload, :start]` AFTER `Repo.transaction/1` returns `{:ok, session}`; `verify_completion/2` emits `[:rindle, :upload, :stop]` AFTER the `Ecto.Multi` returns `{:ok, %{session, asset}}`.
- `lib/rindle/delivery.ex` — `url/3` emits `[:rindle, :delivery, :signed]` inside the `with` success arm before returning `{:ok, url}` (covers both `:public` and `:private` modes).
- `lib/rindle/workers/cleanup_orphans.ex` — `perform/1` emits `[:rindle, :cleanup, :run]` after `Logger.info` on the `{:ok, report}` branch with numeric `sessions_deleted` + `objects_deleted` measurements.
- `lib/rindle/workers/abort_incomplete_uploads.ex` — `perform/1` emits `[:rindle, :cleanup, :run]` after `Logger.info` on the `{:ok, report}` branch with numeric `sessions_aborted` measurement.

### Tests (proofs of emission and non-emission)

- `test/rindle/telemetry/emission_test.exs` (NEW) — FSM emission test scaffold; six tests covering AssetFSM/VariantFSM happy paths, `:unknown` fallback, and invalid-transition non-emission.
- `test/rindle/upload/broker_test.exs` — Added `telemetry emission (Plan 05-01 / TEL-01)` describe block: three tests for `:upload :start`, `:upload :stop`, and missing-object non-emission.
- `test/rindle/delivery_test.exs` — Added `telemetry emission (Plan 05-01 / TEL-04)` describe block: four tests for private-mode emission, public-mode emission, denied-auth non-emission, and missing-capability non-emission.
- `test/rindle/workers/maintenance_workers_test.exs` — Added `telemetry emission (Plan 05-01 / TEL-05)` describe block: five tests for both workers' success and dry-run paths plus storage-resolution non-emission.
- `test/rindle/ops/upload_maintenance_test.exs` — Added `telemetry emission boundary (Plan 05-01 / D-02)` describe block: two `refute_received` tests locking in worker-layer-only emission.

## Decisions Made

- Honored the existing `:telemetry_test.attach_event_handlers/2` pattern from `references/tdd.md` and Phase 3 research; auto-generates unique refs and avoids handler-id collisions in async tests (Pitfall 2 from 05-RESEARCH.md).
- Inlined broker/delivery telemetry tests inside their existing `Rindle.DataCase` test files rather than creating new orphan files. Matches Plan Step 4 Warning 3 (no `flunk` placeholders) and reuses the working Mox expectations.
- For `verify_completion/2`'s `:upload :stop` event, used `asset.profile` (the persisted profile name) for the `profile` metadata key — keeping the metadata aligned with what was stored at session creation.
- For `delivery.ex`, emitted for BOTH `:public` and `:private` modes per the locked contract (mode is metadata, not a separate event name). Confirmed by the public-mode emission test at `test/rindle/delivery_test.exs`.

## Deviations from Plan

The plan was executed substantively as written. Two minor adaptations:

### Adaptation A (Task 3): test file consolidation

- **Plan said:** create `test/rindle/workers/cleanup_orphans_test.exs` and `test/rindle/workers/abort_incomplete_uploads_test.exs` if absent.
- **Reality:** the project already has `test/rindle/workers/maintenance_workers_test.exs` covering both workers comprehensively (delegation, return-shape, cron contract). Creating new orphan files would duplicate setup and split coverage.
- **Action:** added a `telemetry emission (Plan 05-01 / TEL-05)` describe block inside the existing `maintenance_workers_test.exs`. The acceptance criteria (event count, attach-handler count, mix test exit code) are still met.
- **Rationale:** Rule 1 (single source of truth for worker tests) — splitting tests is a maintainability bug.

### Adaptation B (Task 2): test pattern simplified

- **Plan said:** include an inline `DenyingProfile` definition with a fallback `Rindle.Telemetry.EmissionTest.DenyingAuthorizer` if the existing test file didn't already provide one.
- **Reality:** `test/rindle/delivery_test.exs` already uses `Mox`-mocked `AuthorizerMock` and `StorageMock`. A denying-authorizer test is trivially expressed via `expect(Rindle.AuthorizerMock, :authorize, fn _, _, _ -> {:error, :forbidden} end)`.
- **Action:** used Mox to express the denying-auth scenario instead of defining a new profile module. Simpler, consistent with existing tests, and `refute_received` still proves no emission.

Both adaptations preserve all acceptance criteria.

## Authentication Gates

None — purely library code changes; no external auth required.

## Verification Results

- `grep -n ":telemetry.execute" lib/rindle/domain/asset_fsm.ex` → 1 match for `[:rindle, :asset, :state_change]` ✓
- `grep -n ":telemetry.execute" lib/rindle/domain/variant_fsm.ex` → 1 match for `[:rindle, :variant, :state_change]` ✓
- `grep -c "_context" lib/rindle/domain/variant_fsm.ex` → 0 ✓
- `grep -n ":telemetry.execute" lib/rindle/upload/broker.ex` → 2 matches (`:start`, `:stop`) ✓
- `grep -n ":telemetry.execute" lib/rindle/delivery.ex` → 1 match for `[:rindle, :delivery, :signed]` ✓
- `grep -n ":telemetry.execute" lib/rindle/workers/cleanup_orphans.ex` → 1 match for `[:rindle, :cleanup, :run]` ✓
- `grep -n ":telemetry.execute" lib/rindle/workers/abort_incomplete_uploads.ex` → 1 match for `[:rindle, :cleanup, :run]` ✓
- `grep -c ":telemetry.execute" lib/rindle/ops/upload_maintenance.ex` → 0 (worker-layer-only) ✓
- `grep -c "flunk" test/rindle/telemetry/emission_test.exs` → 0 ✓
- `:telemetry_test.attach_event_handlers` present in all four test files ✓
- `mix test --exclude integration` → 161 tests, 0–1 failures, 1 skipped (the 1 occasional failure is a pre-existing flake in `function_exported?(AbortIncompleteUploads, :perform, 1)` at base, NOT introduced by this plan; documented in `deferred-items.md`)
- `mix test test/rindle/telemetry/emission_test.exs test/rindle/upload/broker_test.exs test/rindle/delivery_test.exs test/rindle/workers/maintenance_workers_test.exs test/rindle/ops/upload_maintenance_test.exs` → 62 tests, stable across seeds 100/300/500 (the 1 occasional failure on seeds 200/400 is the pre-existing `cron scheduling contract` flake, untouched by this plan)
- `mix compile --warnings-as-errors` → clean ✓
- `mix format --check-formatted` on all source files this plan modified → clean ✓

## Deferred Issues

See `.planning/phases/05-ci-1-0-readiness/deferred-items.md`:

- Pre-existing format violations (trailing whitespace, long `expect` lines) in `test/rindle/upload/broker_test.exs`, `test/rindle/delivery_test.exs`, and `test/rindle/upload/proxied_test.exs` — none introduced by this plan; will be addressed when Plan 05-02 wires the format job.
- Pre-existing flaky test on seeds 200/400 in `maintenance_workers_test.exs` line 167 (`function_exported?` without `Code.ensure_loaded`) — same flake on base commit; chore fix.

## Threat Flags

None. The threat surface introduced by this plan is captured by `<threat_model>` items T-05-01-01..03 in the plan; mitigations T-05-01-02 and T-05-01-03 are enforced in implementation:

- T-05-01-02 (metadata leakage): every emission site lists exact metadata keys — `profile`, `adapter`, `from`/`to`, `session_id`/`asset_id`, `mode`, `dry_run`, `worker`. No file paths, byte content, or credentials are emitted.
- T-05-01-03 (rolled-back emissions): all emissions live AFTER the relevant `Repo.transaction/1` or `Ecto.Multi` resolves to `{:ok, ...}`; FSM emissions live outside any caller's transaction; delivery emission is in a non-transactional `with` chain.
- T-05-01-01 (DoS via adopter handlers): accepted per `:telemetry`'s auto-detach-on-raise behavior (no library-level mitigation needed).

## TDD Gate Compliance

This plan is `type: execute` (not `type: tdd`), but each task carried `tdd="true"`. The git log shows the expected RED → GREEN sequence per task:

- Task 1: `cb36235` (test, RED) → `746d1bc` (feat, GREEN)
- Task 2: `2e98304` (test, RED) → `40df389` (feat, GREEN)
- Task 3: `9ccdceb` (test, RED) → `9a312d6` (feat, GREEN)

No REFACTOR commits were needed (additive emission was clean on first pass).

## Self-Check: PASSED

All six emission sites verified via grep + tests; all created files exist on disk; all seven commits exist in `git log`:

- File: `test/rindle/telemetry/emission_test.exs` → FOUND
- File: `.planning/phases/05-ci-1-0-readiness/deferred-items.md` → FOUND
- Commit `cb36235` → FOUND
- Commit `746d1bc` → FOUND
- Commit `2e98304` → FOUND
- Commit `40df389` → FOUND
- Commit `9ccdceb` → FOUND
- Commit `9a312d6` → FOUND
- Commit `53722de` → FOUND
