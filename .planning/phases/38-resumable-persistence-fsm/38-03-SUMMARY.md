---
phase: 38-resumable-persistence-fsm
plan: 03
subsystem: telemetry
tags: [telemetry, contract-tests, gcs, resumable-uploads]
requires:
  - phase: 38-02
    provides: MediaUploadSession session_uri redaction and resumable lifecycle vocabulary
provides:
  - Internal resumable telemetry emit helpers for status and cancel
  - Public telemetry allowlist entries for resumable status and cancel
  - Narrow GCS log-hygiene note for session_uri redaction
affects: [phase-39, operator-surfaces, observability]
tech-stack:
  added: []
  patterns: [locked-telemetry-allowlist, helper-enforced-metadata-filtering, narrow-guide-stub]
key-files:
  created: [lib/rindle/upload/resumable_telemetry.ex, test/rindle/upload/resumable_telemetry_test.exs, guides/storage_gcs.md]
  modified: [test/rindle/contracts/telemetry_contract_test.exs]
key-decisions:
  - "Reserved exactly two public resumable events: status and cancel."
  - "Kept resumable telemetry helper scope internal and reusable without wiring broker entrypoints in Phase 38."
  - "Documented session_uri log redaction as a narrow Phase 38 defense-in-depth note, not full GCS onboarding."
patterns-established:
  - "Telemetry helpers drop forbidden metadata keys and derive session_id only from the durable session struct."
  - "Contract tests for excluded-by-default suites must be verified with the equivalent included-tag invocation."
requirements-completed: [RESUMABLE-03]
duration: 10 min
completed: 2026-05-07
---

# Phase 38 Plan 03: Resumable telemetry contract, parity tests, and GCS log-hygiene note

**Rindle now freezes the public resumable telemetry family to `:status` and `:cancel`, enforces session-uri redaction in helper-driven emissions, and documents the interim GCS logger-filter recipe.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-05-07T16:06:10-04:00
- **Completed:** 2026-05-07T16:16:00-04:00
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments

- Added `Rindle.Upload.ResumableTelemetry` with internal `emit_status/5` and `emit_cancel/5` helpers that enforce allowed metadata and numeric measurements.
- Extended the public telemetry contract to include exactly `[:rindle, :upload, :resumable, :status]` and `[:rindle, :upload, :resumable, :cancel]`, with contract coverage proving both events are emitted.
- Added a narrow `guides/storage_gcs.md` note showing how to redact `:session_uri` via `Logger.add_translator` until broader GCS onboarding lands in Phase 41.

## Task Commits

1. **Task 1: Add internal resumable telemetry emit helpers with locked metadata and measurements**
   - `2c3e1ce` `test(38-03): add failing resumable telemetry coverage`
   - `c9d3e29` `feat(38-03): add resumable telemetry helpers`
2. **Task 2: Freeze the public telemetry allowlist to exactly the two resumable events per D-17..D-23**
   - `9a1677e` `test(38-03): freeze resumable telemetry contract`
3. **Task 3: Add the narrow session_uri logger-filter recipe required by RESUMABLE-03**
   - `fab2308` `docs(38-03): add resumable session uri logging note`

## Files Created/Modified

- `lib/rindle/upload/resumable_telemetry.ex` - Centralized resumable status/cancel emit helpers with metadata filtering.
- `test/rindle/upload/resumable_telemetry_test.exs` - Helper parity tests proving session-uri redaction and measurement shape.
- `test/rindle/contracts/telemetry_contract_test.exs` - Public allowlist expansion and contract-level emission coverage.
- `guides/storage_gcs.md` - Narrow log-hygiene recipe for redacting `:session_uri`.

## Decisions Made

- Exposed exactly two resumable public events and explicitly avoided resumable start/stop or GCS-specific event families.
- Allowed optional `:session_id` in metadata, but only when derived from the session struct’s durable ID.
- Kept the guide limited to bearer-credential log hygiene and deferred all broader GCS onboarding to Phase 41.

## Verification

- `mix test test/rindle/upload/resumable_telemetry_test.exs` -> PASS
- `mix test test/rindle/contracts/telemetry_contract_test.exs --include contract` -> PASS
- Guide acceptance greps for `Logger.add_translator`, `:session_uri`, `bearer credential`, and `Phase 41` -> PASS

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Replaced the plan’s default contract-test invocation with the equivalent included-tag form**
- **Found during:** Task 2 verification
- **Issue:** `test/rindle/contracts/telemetry_contract_test.exs` is tagged `:contract` and excluded by default in this repo, so the plan’s plain `mix test ...` command exercised zero contract assertions for that file.
- **Fix:** Verified the file with `mix test test/rindle/contracts/telemetry_contract_test.exs --include contract` while keeping the test scope identical.
- **Files modified:** `.planning/phases/38-resumable-persistence-fsm/38-03-SUMMARY.md`
- **Verification:** `mix test test/rindle/contracts/telemetry_contract_test.exs --include contract`
- **Committed in:** summary metadata commit

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** No scope change. The contract remained exactly as planned; only the repo-specific test invocation needed correction so the assertions actually ran.

## Issues Encountered

- The worktree already contained unrelated `.planning/` changes outside this plan’s ownership set. They were left untouched.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 39 can reuse the internal telemetry helpers without redefining event names or re-solving session-uri redaction.
- The public telemetry contract is now locked against premature resumable family expansion.

## Self-Check

PASSED

- Confirmed `.planning/phases/38-resumable-persistence-fsm/38-03-SUMMARY.md` exists.
- Confirmed task commits `2c3e1ce`, `c9d3e29`, `9a1677e`, and `fab2308` exist in git history.

---
*Phase: 38-resumable-persistence-fsm*
*Completed: 2026-05-07*
