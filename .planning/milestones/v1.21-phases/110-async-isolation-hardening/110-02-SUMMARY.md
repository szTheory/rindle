---
phase: 110-async-isolation-hardening
plan: 02
subsystem: testing
tags: [async-isolation, repo-override, process-dictionary, test-double, counting-failing-txn-repo]

requires:
  - phase: 110-01
    provides: "Rindle.Config.put_repo_override/1 + delete_repo_override/0 (process-local repo override setters)"
provides:
  - "Process-scoped Rindle.Test.CountingFailingTxnRepo.with_counting_repo/2 (no global :rindle,:repo swap)"
  - "Process-dict fail-config (@config_key) backing fail_after/0 + fail_reason/0"
  - "StreamingDispatchTest, OwnerErasureBatchProofTest, BatchOwnerErasureTaskTest restored to async: true"
affects: [110-04]

tech-stack:
  added: []
  patterns:
    - "test double scoped via Config.put_repo_override/1 + process-dict config (Mox/Sandbox idiom) instead of Application.put_env global swap"

key-files:
  created: []
  modified:
    - test/support/counting_failing_txn_repo.ex
    - test/rindle/delivery/streaming_dispatch_test.exs
    - test/rindle/owner_erasure_batch_proof_test.exs
    - test/rindle/batch_owner_erasure_task_test.exs

key-decisions:
  - "with_counting_repo/2 installs the double via Config.put_repo_override/1 and clears it in after; no global :rindle,:repo swap remains (D-03)"
  - "fail-after/fail-reason config moved to the process dictionary under @config_key {__MODULE__, :fail_config}; restore_env/2 save/restore dance deleted (D-04)"
  - "Three modules demoted SOLELY for the repo-swap reason re-promoted to async: true with root-caused (not deferred) header comments (D-05)"
  - "TestRepoProbe/FailingTransactionRepo modules (maintenance_workers/upload_maintenance/broker) left async: false (D-06, out of scope)"
  - "Test-only change: commits use refactor:/test: (NOT fix:) so release-please does not re-trigger the 0.3.2 patch publish — the only lib/ touch was 110-01"

patterns-established:
  - "Pattern: a force-failing repo double is process-scoped via Config.put_repo_override/1 + process-dict config so it can never pollute a concurrent async reader"

requirements-completed: [ISO-03]

coverage:
  - id: D1
    description: "with_counting_repo/2 is fully process-scoped: repo via Config.put_repo_override/1, fail-config via process dict, both cleared in after; no Application.put_env/delete_env of :rindle,:repo or :rindle,:counting_failing_txn_repo remains; passthrough generator intact"
    requirement: "ISO-03"
    verification:
      - kind: other
        ref: "grep gate: ! Application.(put_env|delete_env)(:rindle, :repo|:counting_failing_txn_repo) && Config.put_repo_override present && Rindle.Repo.__info__(:functions) present"
        status: pass
      - kind: other
        ref: "mix compile --warnings-as-errors (exit 0)"
        status: pass
    human_judgment: false
  - id: D2
    description: "StreamingDispatchTest, OwnerErasureBatchProofTest, BatchOwnerErasureTaskTest run under async: true with passing suites; root-caused header comments; D-06 modules untouched"
    requirement: "ISO-03"
    verification:
      - kind: integration
        ref: "mix test test/rindle/delivery/streaming_dispatch_test.exs test/rindle/owner_erasure_batch_proof_test.exs test/rindle/batch_owner_erasure_task_test.exs => 28 tests, 0 failures (0.2s async)"
        status: pass
    human_judgment: false

duration: 6min
completed: 2026-06-28
status: complete
---

# Phase 110 Plan 02: Process-scoped CountingFailingTxnRepo + async re-promotion Summary

**`Rindle.Test.CountingFailingTxnRepo.with_counting_repo/2` migrated off ALL global state (repo via `Config.put_repo_override/1`, fail-config to the process dict), enabling the three repo-swap-demoted suites back to `async: true` — 28 tests green, serialization tax recovered.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-06-28T18:47:23Z
- **Completed:** 2026-06-28T18:53:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- `with_counting_repo/2` now installs the double via the process-local `Rindle.Config.put_repo_override(__MODULE__)` (from Plan 01) instead of `Application.put_env(:rindle, :repo, __MODULE__)`, clearing it via `Config.delete_repo_override/0` in `after`.
- The fail-after/fail-reason config moved into the process dictionary under `@config_key {__MODULE__, :fail_config}`; `fail_after/0` and `fail_reason/0` read `Process.get(@config_key, [])`. The entire `previous_repo`/`previous_cfg` capture and `restore_env/2` save/restore dance is deleted (no global to save/restore).
- The `Rindle.Repo.__info__(:functions)` passthrough generator (proxy completeness guarantee) is untouched; the head comment was rewritten to describe the process-local override rather than a global swap.
- `StreamingDispatchTest`, `OwnerErasureBatchProofTest`, and `BatchOwnerErasureTaskTest` flipped from `async: false` → `async: true` with root-caused (not deferred) header comments; their combined 28 tests pass under async (0.2s, 0.2s async / 0.00s sync).

## Task Commits

Each task was committed atomically:

1. **Task 1: Migrate with_counting_repo/2 + fail config to the process dictionary** - `d9078bd` (refactor)
2. **Task 2: Revert the 3 repo-swap-demoted modules to async: true with root-caused comments** - `6c03cf0` (test)

_TDD note: both tasks carried `tdd="true"`, but the phase config has `tdd_mode: false` and the plan's `done` criteria specify the gate as the negative-grep + `mix compile --warnings-as-errors` + the three suites passing (no standalone RED test file is created in this plan — Plan 04 supplies the concurrency proof). No RED test commit was created — consistent with the plan's stated gate, matching Plan 01's handling, not a gap._

## Files Created/Modified
- `test/support/counting_failing_txn_repo.ex` - process-scoped `with_counting_repo/2` (Config.put_repo_override/1 + process-dict `@config_key`); `fail_after/0`/`fail_reason/0` read the process dict; `restore_env/2` removed; passthrough generator + transaction overrides untouched.
- `test/rindle/delivery/streaming_dispatch_test.exs` - `async: true` + root-caused header comment.
- `test/rindle/owner_erasure_batch_proof_test.exs` - `async: true` + rewritten rationale comment.
- `test/rindle/batch_owner_erasure_task_test.exs` - `async: true` (flag only; no rationale comment existed).

## Decisions Made
- Followed plan exactly: repo override via `Config.put_repo_override/1` (D-03), fail-config to process dict (D-04), three modules re-promoted (D-05), D-06 modules left alone.
- Commit types: `refactor(110-02)` for the test-support change and `test(110-02)` for the async flip — deliberately NOT `fix:`, so release-please does not re-bundle these into a publish; the phase's only `lib/` touch (the 0.3.2 trigger) was Plan 01.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None. The asdf `gsd-tools` shim required invoking via the explicit Node 22 binary path; the Elixir toolchain resolved via homebrew. Neither affected the plan's deliverables.

## Verification
- `! grep Application.(put_env|delete_env)(:rindle, :repo` and `! grep ...:counting_failing_txn_repo` → both clean (no global mutation remains).
- `grep Config.put_repo_override` → present; `grep Rindle.Repo.__info__(:functions)` → present (generator intact).
- `mix compile --warnings-as-errors` → exit 0.
- `grep -c 'use Rindle.DataCase, async: true'` over the three modules → 1 each.
- `mix test` over the three suites → **28 tests, 0 failures** (Finished in 0.2s; 0.2s async, 0.00s sync).
- D-06 modules (`workers/maintenance_workers_test.exs`, `ops/upload_maintenance_test.exs`, `upload/broker_test.exs`) still `async: false` and unmodified by this plan.

## Next Phase Readiness
- ISO-03 satisfied: the counting double is fully process-scoped (no global mutation) and the three demoted modules are back to `async: true` with passing suites.
- Plan 04's concurrency/isolation proof test can now exercise the process-scoped double under genuine async contention. Plan 03's `:global_repo_swap` guard rule can point at the sanctioned setter knowing the last `:rindle,:repo` global swap in the test double is gone.

## Self-Check: PASSED

- FOUND: test/support/counting_failing_txn_repo.ex (process-scoped, compiles clean)
- FOUND: test/rindle/delivery/streaming_dispatch_test.exs (async: true)
- FOUND: test/rindle/owner_erasure_batch_proof_test.exs (async: true)
- FOUND: test/rindle/batch_owner_erasure_task_test.exs (async: true)
- FOUND: .planning/phases/110-async-isolation-hardening/110-02-SUMMARY.md
- FOUND commit d9078bd (Task 1)
- FOUND commit 6c03cf0 (Task 2)

---
*Phase: 110-async-isolation-hardening*
*Completed: 2026-06-28*
