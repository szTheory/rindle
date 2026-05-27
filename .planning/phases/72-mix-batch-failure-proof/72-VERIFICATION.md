---
phase: 72
slug: mix-batch-failure-proof
status: passed
verified: 2026-05-27
requirements: [PROOF-06]
---

# Phase 72 Verification

## Must-haves

| Truth | Status | Evidence |
|-------|--------|----------|
| `mix rindle.batch_owner_erasure --execute` with mid-batch txn failure prints partial text report on stdout before the error line | ✓ | `batch_owner_erasure_task_test.exs` — sequential `assert_received` for info lines before `:error` |
| Mix task exits with shutdown code 1 when `batch_owner_failed` is returned | ✓ | `catch_exit(Task.run(...)) == {:shutdown, 1}` |
| Error line includes `batch_owner_failed` copy: failing owner ref, completed count, `partial_report` guidance | ✓ | Asserts on `error_msg` match owner2, "1 owner(s) completed successfully", `partial_report`, "Completed owners remain committed" |

## Artifacts

| Path | Status |
|------|--------|
| `test/rindle/batch_owner_erasure_task_test.exs` | ✓ — `describe "PROOF-06: partial failure"` present |

## Key links

| From | To | Via | Status |
|------|-----|-----|--------|
| `batch_owner_erasure_task_test.exs` | `lib/mix/tasks/rindle.batch_owner_erasure.ex` | `Task.run/1` | ✓ |
| `batch_owner_erasure_task_test.exs` | `test/support/counting_failing_txn_repo.ex` | `with_counting_repo(2, ...)` | ✓ |

## Automated checks

```
mix test test/rindle/batch_owner_erasure_task_test.exs
# 7 tests, 0 failures (2026-05-27)
```

## Requirements traceability

- **PROOF-06** — satisfied by plan 72-01 integration test; no production code changes (test-only per CONTEXT D-06).

## Human verification

None required.

## Self-Check: PASSED
