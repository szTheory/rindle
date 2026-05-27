---
phase: 72
plan: 01
status: complete
requirements: [PROOF-06]
---

# Plan 72-01 Summary

## Outcome

PROOF-06 closed: integration test proves `mix rindle.batch_owner_erasure --execute` prints partial stdout report before `batch_owner_failed` error copy and exits with shutdown code 1 on mid-batch txn failure.

## Key changes

- Added `describe "PROOF-06: partial failure"` to `batch_owner_erasure_task_test.exs`
- Uses `CountingFailingTxnRepo.with_counting_repo(2, ...)` so owner 1 commits and owner 2 txn fails
- Asserts info lines (partial report) precede error line via sequential `assert_received`
- Asserts exit `{:shutdown, 1}` and error copy includes failing owner, completed count, and `partial_report` guidance

## Commits

- `269fcd7` test(phase-72-01): PROOF-06 partial-failure Mix task integration test

## Self-Check: PASSED

- `mix test test/rindle/batch_owner_erasure_task_test.exs` — 7 tests, 0 failures
- No production files modified
- `rg 'PROOF-06: partial failure'` — found
