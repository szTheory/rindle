---
created: 2026-10-16T17:45:00.000Z
title: Require landing records for merged lock-changing PRs, and stop counting running jobs as failed
area: ci-tooling
trigger: "A dependency PR merges with a lock delta but the ledger has no landings[] record, or main_ci.failed_jobs lists jobs that are still running"
files:
  - scripts/maintainer/validate_inbox_ledger.sh
  - scripts/maintainer/collect_inbox.sh
---

## Problem

Found by the Phase 134 verifier (134-VERIFICATION.md, warnings 1 and 3):

1. `validate_inbox_ledger.sh` does not require a `landings[]` record for a merged PR that changes a lock. Deleting
   #105's landing record still printed `ok (live)`. The live case is #122: its own main run 38809962966 is a
   `regression`, and its credit rests on a descendant run (38828155392 on dc75ab83) that only a prose rationale
   records.
2. `collect_inbox.sh:306` puts every job whose conclusion is not `success` into `main_ci.failed_jobs`, so in-progress
   jobs appear there (seen on run 38940010020). The validator does not read the field today, so nothing is wrong yet.

## Solution

1. Validator rule: a merged PR item whose PR changed `mix.lock` or `examples/adoption_demo/mix.lock` needs either a
   `landings[]` record or an explicit equivalence record (descendant run id, SHA range, and a check that the range
   touches no `mix.exs`, lock or `lib/` file). Add the equivalence record for #122 when the rule lands.
2. Collector: list a job as failed only when it is completed with a failing conclusion; report running jobs
   separately.

## Verification

Script tests: removing a landing record is rejected; #122 passes only through its equivalence record; a run with
in-progress jobs yields an empty `failed_jobs`.
