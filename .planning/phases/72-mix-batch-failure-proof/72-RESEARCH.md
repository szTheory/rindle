# Phase 72: Mix Batch Failure Proof — Research

**Researched:** 2026-05-27
**Status:** Complete

## Summary

PROOF-06 is a **test-only** closure of the v1.14 operator gap: prove `mix rindle.batch_owner_erasure --execute` surfaces partial stdout report then `batch_owner_failed` error copy and exit 1 when the second owner’s transaction fails mid-batch.

All production wiring already exists (`lib/mix/tasks/rindle.batch_owner_erasure.ex` lines 105–108). API-layer partial failure is proven in `owner_erasure_batch_proof_test.exs` via `CountingFailingTxnRepo.with_counting_repo(2, ...)`. Phase 72 mirrors that scenario through the Mix task shell boundary.

## Technical Findings

### Failure injection (recommended)

| Approach | Verdict | Rationale |
|----------|---------|-----------|
| `CountingFailingTxnRepo.with_counting_repo(2, ...)` | **Use** | Same harness as PROOF-05; real `repo.transaction/1` counting; no prod flags |
| Mox on `OwnerErasure` | Reject | No behaviour seam; skips txn partial-commit semantics |
| `--simulate-failure` CLI flag | Reject | OSS DNA: lock modes in tests, not shipped CLI |
| `System.cmd("mix", ...)` | Reject | In-process `Task.run/1` is hermetic and matches existing task tests |

### Scenario shape

- **Owners file:** two entries (`owner1`, `owner2`) with distinct attachments.
- **`fail_after: 2`:** first owner commits, second txn fails → non-empty `partial_report`.
- **`--execute`:** required; dry-run never calls `repo.transaction/1`.
- **`async: false`:** mandatory when swapping `:repo` via `Application.put_env`.

### Shell assertion contract

Mix task control flow on `{:error, {:batch_owner_failed, detail}}`:

1. `print_report(detail.partial_report, format, dry_run?)` → multiple `{:mix_shell, :info, ...}` lines
2. `Mix.shell().error(Error.message(...))` → `{:mix_shell, :error, ...}`
3. `exit({:shutdown, 1})`

Harness: `Mix.shell(Mix.Shell.Process)` in setup; `catch_exit(Task.run(...)) == {:shutdown, 1}`; ordered `assert_received`.

**Partial report strings** (from `format_text_report/2`, `dry_run? = false`):

- `"Batch owner erasure report:"` (no `[DRY RUN]` prefix)
- `"owners:"` with count **1**
- `"attachments_to_detach"`
- Owner line: `"  - #{owner_type}:#{owner1.id}"`

**Error strings** (from `lib/rindle/error.ex` `batch_owner_failed` clause):

- `"Batch owner erasure stopped because owner"`
- failing `owner2` ref (`#{owner_type}:#{owner2.id}`)
- `"1 owner(s) completed successfully"`
- `"partial_report"`
- `"Completed owners remain committed"`

### Out of scope (confirmed)

- Production code changes unless test exposes a real bug.
- `fail_after: 1` CLI test (PROOF-05 covers API).
- `--format json` partial-failure path.
- `guides/operations.md` edits (Phase 74 / TRUTH-04).

## Validation Architecture

| Dimension | Strategy |
|-----------|----------|
| **Primary verify** | `mix test test/rindle/batch_owner_erasure_task_test.exs` |
| **Scope guard** | Single new test under `describe "PROOF-06: partial failure"` |
| **Regression** | Full file green; no changes to `owner_erasure_batch_proof_test.exs` |
| **Nyquist** | Every plan task has `<verify>` with exact mix command; no watch mode |
| **Manual** | None — fully automated |

### Wave structure

Single wave, single plan: add PROOF-06 test → run targeted file → optional full `mix test` if planner adds regression task.

## Risks

| Risk | Mitigation |
|------|------------|
| Flaky `assert_received` ordering | Assert partial info lines before error line in sequence |
| Global `:repo` leak | Always use `with_counting_repo/2`, keep `async: false` |
| Copy drift vs `error.ex` | Reuse substrings already asserted in `owner_erasure_batch_error_test.exs` |

## RESEARCH COMPLETE
