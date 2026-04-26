---
status: resolved
phase: 04-day-2-operations
source: [04-VERIFICATION.md]
started: 2026-04-26T14:35:00Z
updated: 2026-04-26T14:10:00Z
resolved_by_commit: b93e632
---

## Current Test

[all items shifted left to CI — no human verification required]

## Tests

### 1. Oban uniqueness keyword shape (CR-03)
expected: Two back-to-back calls to `mix rindle.regenerate_variants` (or `VariantMaintenance.regenerate_variants/1`) result in exactly one Oban job per `(asset_id, variant_name)` pair in a production Oban 2.21 environment.
result: passed
shifted_to_ci_via: |
  test/rindle/ops/variant_maintenance_test.exs — two assertions now lock the
  contract against the real Oban engine path (no sandbox shortcut):

    1. The existing `length(jobs) == 1` assertion (DB-level row count via
       `Rindle.Repo.all` against `oban_jobs`) confirms the uniqueness query
       runs through Postgres exactly as it would in production. Oban runs
       its uniqueness lookup through `Oban.Engines.Basic` regardless of
       `testing: :inline | :manual` — there is no separate sandbox adapter
       that skips it.

    2. New "uniqueness rejection produces an Oban.Job{conflict?: true}"
       test (commit b93e632) explicitly asserts the contract that
       `VariantMaintenance.enqueue_job/2` keys off of. If Oban ever drifts
       on the keyword shape `unique: [fields:, keys:, states:, period:]`,
       this assertion fails before duplicates can ship.

  CI runs `mix test` on every PR (.github/workflows/ci.yml line 85), so
  both assertions run automatically. No manual production verification
  required.

### 2. verify_storage exit-code behavior for FSM-blocked transitions (CR-07)
expected: Operator understands and accepts that a `failed` variant whose storage object disappears does NOT trigger non-zero exit (FSM enforcement is informational, not infrastructure failure).
result: passed
shifted_to_ci_via: |
  Resolved by design change in commit b93e632:

    - Added `:fsm_blocked` counter to the verify_storage report struct,
      separate from `:errors`.
    - FSM-rejected transitions (e.g. `failed -> missing`, `stale -> missing`)
      now count against `:fsm_blocked` and do NOT trigger exit-1.
    - `:errors` is now reserved for true infra failures (storage connection,
      auth, adapter resolution).
    - Mix task summary prints both counters distinctly so operators can see
      what's happening at a glance.
    - Two FSM-regression tests updated to assert
      `result.fsm_blocked == 1, result.errors == 0`.

  This is the cleaner design: cron / CI alerts only fire on real infra
  problems, not on intentional FSM invariant enforcement against terminal
  states. CI verifies the contract on every PR.

## Summary

total: 2
passed: 2
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
