---
phase: 70-proof-adopter-guidance
plan: 02
subsystem: docs
tags: [elixir, docs, guides, parity, owner-erasure, batch]

requires:
  - phase: 70-proof-adopter-guidance
    plan: 01
    provides: PROOF-05 batch proof infrastructure and verification baseline
provides:
  - Batch owner erasure canonical narrative in user_flows.md Story 5
  - Thin batch pointers in operations.md and getting_started.md
  - TRUTH-03 docs parity freeze for batch vocabulary
affects: [v1.14-closure, TRUTH-03]

tech-stack:
  added: []
  patterns:
    - "user_flows.md canonical batch narrative; operations/getting_started thin pointers only"
    - "docs_parity_test.exs refutes bulk orchestration and ops CLI contract duplication"

key-files:
  created: []
  modified:
    - guides/user_flows.md
    - guides/operations.md
    - guides/getting_started.md
    - test/install_smoke/docs_parity_test.exs

key-decisions:
  - "Batch terminology in adopter-facing prose; bulk reserved for planning only"
  - "operations.md links to user_flows batch subsection without --owners-file or owner_type"

patterns-established:
  - "TRUTH-03 parity flip atomic with guide prose: refute bulk orchestration in same change"
  - "Mix task @moduledoc remains canonical CLI contract; ops guide is thin index only"

requirements-completed: [TRUTH-03]

duration: 1min
completed: 2026-05-27
---

# Phase 70 Plan 02: Batch Erasure Adopter Guidance Summary

**Batch owner erasure documented as the supported multi-owner surface in guides with TRUTH-03 docs parity freeze refuting stale bulk-orchestration deferral**

## Performance

- **Duration:** 1 min
- **Started:** 2026-05-27T17:28:49Z
- **Completed:** 2026-05-27T17:29:30Z
- **Tasks:** 3 completed
- **Files modified:** 4

## Accomplishments

- Added **Batch owner erasure** subsection to `user_flows.md` Story 5 with API, 2-owner example, mix task pointer, sequential transaction semantics, `partial_report`, and idempotent rerun guidance
- Replaced stale "bulk orchestration remains deferred" with shipped batch API truth; admin UI, force-delete, and scheduler/cron jobs remain deferred
- Extended `operations.md` and `getting_started.md` with thin batch pointers linking to canonical narrative without duplicating CLI flag contract
- Extended `docs_parity_test.exs` to freeze batch vocabulary and refute `bulk orchestration`, `--owners-file`, and `owner_type` in operations guide

## Task Commits

Each task was committed atomically:

1. **Task 1: Add batch erasure subsection to user_flows.md Story 5** - `3e28c4e` (docs)
2. **Task 2: Add thin batch pointers to operations.md and getting_started.md** - `1696038` (docs)
3. **Task 3: Extend docs_parity_test.exs for batch TRUTH-03** - `3c526c9` (test)

**Plan metadata:** `9e91b3e` (docs)

## Files Created/Modified

- `guides/user_flows.md` - Batch owner erasure subsection, shipped-batch deferral update
- `guides/operations.md` - Thin batch API and mix task pointer to user_flows
- `guides/getting_started.md` - One-sentence forward link to batch subsection
- `test/install_smoke/docs_parity_test.exs` - TRUTH-03 batch vocabulary freeze and ops contract refutes

## Decisions Made

None beyond plan — followed D-13 through D-21 as specified

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

Postgres `too_many_connections` warnings appeared during verification runs; all 46 tests passed.

## User Setup Required

None - no external service configuration required.

## Verification

```
mix test test/install_smoke/docs_parity_test.exs
# 17 tests, 0 failures

mix test test/rindle/owner_erasure_batch_test.exs test/rindle/owner_erasure_batch_proof_test.exs test/rindle/owner_erasure_batch_boundary_test.exs test/rindle/owner_erasure_batch_error_test.exs test/rindle/owner_erasure_batch_contract_test.exs test/rindle/owner_erasure_test.exs test/rindle/batch_owner_erasure_task_test.exs test/install_smoke/docs_parity_test.exs
# 46 tests, 0 failures
```

## Self-Check: PASSED

- All 3 tasks executed and committed individually
- All acceptance criteria verified
- Plan-level verification suite green

## Next Phase Readiness

Phase 70 complete (plans 01 and 02). v1.14 proof and adopter guidance closed. Orchestrator should update STATE.md and ROADMAP.md.

---
*Phase: 70-proof-adopter-guidance*
*Completed: 2026-05-27*
