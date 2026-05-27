---
phase: 67-bulk-erasure-policy-contract
plan: 01
subsystem: api
tags: [elixir, contract, owner-erasure, batch]

requires: []
provides:
  - Batch erasure types and @specs on Rindle facade
  - preview_batch_owner_erasure/2 and erase_batch_owner_erasure/2 stub entrypoints
  - Boundary validation for empty batch and batch_too_large
affects: [68-batch-planner]

tech-stack:
  added: []
  patterns:
    - "Batch boundary validation on public facade before internal planner calls"
    - "Contract freeze via Code.fetch_docs type export tests"

key-files:
  created:
    - test/rindle/owner_erasure_batch_contract_test.exs
    - test/rindle/owner_erasure_batch_boundary_test.exs
  modified:
    - lib/rindle.ex

key-decisions:
  - "Valid in-limit batches return {:error, :not_implemented} until Phase 68 wires planner"
  - "Default max batch size 100 via Application.get_env(:rindle, :max_batch_erasure_owners, 100)"

patterns-established:
  - "owner_ref tuple shape matches OwnerErasure internal owner_info/1"
  - "batch_too_large_detail map mirrors streaming not_cancellable_detail pattern"

requirements-completed: [BULK-01, BULK-02]

duration: 8min
completed: 2026-05-27
---

# Phase 67 Plan 01 Summary

**Batch owner-erasure public contract frozen on Rindle with types, boundary stubs, and contract tests**

## Performance

- **Duration:** 8 min
- **Started:** 2026-05-27T17:00:00Z
- **Completed:** 2026-05-27T17:08:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Added batch erasure types (`owner_ref`, `owner_erasure_batch_report`, etc.) and stub entrypoints on `Rindle`
- Implemented boundary validation: empty batch, dedupe-aware size limit, `max_owners` opt override
- Updated moduledoc to position batch preview/execute as supported multi-owner path
- Contract and boundary tests lock type exports and validation behavior

## Task Commits

1. **Task 1: Add batch erasure types and stub entrypoints on Rindle** - `49cca5b` (feat)
2. **Task 2: Contract and boundary tests for batch entrypoints** - `4c45181` (test)

**Plan metadata:** pending (docs: complete plan)

## Files Created/Modified
- `lib/rindle.ex` - Batch types, @specs, moduledoc, stub entrypoints, validate_batch_owners
- `test/rindle/owner_erasure_batch_contract_test.exs` - Type/export freeze tests
- `test/rindle/owner_erasure_batch_boundary_test.exs` - Empty/over-limit/dedupe boundary tests

## Decisions Made
None - followed plan as specified

## Deviations from Plan

None - plan executed exactly as written

## Issues Encountered
None

## Next Phase Readiness
- Plan 67-02 can add error vocabulary and api_surface_boundary updates
- Phase 68 can wire OwnerErasure planner behind validated entrypoints

---
*Phase: 67-bulk-erasure-policy-contract*
*Completed: 2026-05-27*
