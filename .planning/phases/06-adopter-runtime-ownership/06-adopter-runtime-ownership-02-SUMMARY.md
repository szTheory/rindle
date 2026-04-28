---
phase: 06-adopter-runtime-ownership
plan: 02
subsystem: testing
tags: [ecto, oban, runtime-repo, upload-broker, adopter]
requires:
  - phase: 06-adopter-runtime-ownership
    provides: facade repo seam from 06-01 for broker and lifecycle proof execution
provides:
  - broker persistence paths resolved through the configured runtime repo
  - canonical adopter lifecycle proof that runs against the adopter repo contract
  - dedicated adopter-repo proof for proxied `Rindle.upload/3`
  - sandbox repo selection for targeted adopter lanes
affects: [adopter-runtime-ownership, multipart-uploads, guides]
tech-stack:
  added: []
  patterns: [runtime repo resolution in broker and workers, sandbox_repo test ownership, transaction-owned Oban enqueue]
key-files:
  created: []
  modified: [lib/rindle/upload/broker.ex, test/rindle/upload/broker_test.exs, test/adopter/canonical_app/lifecycle_test.exs, test/rindle/upload/lifecycle_integration_test.exs, test/support/data_case.ex, test/test_helper.exs, lib/rindle.ex, lib/rindle/workers/promote_asset.ex, lib/rindle/workers/process_variant.ex, lib/rindle/workers/purge_storage.ex, config/test.exs]
key-decisions:
  - "Keep adopter proof scope on the default Oban instance and fix enqueue callsites rather than introducing named-instance ownership in Phase 6."
  - "Use per-test `sandbox_repo` ownership plus targeted-file tag unblocking so adopter proofs fail on repo leaks instead of being silently excluded."
patterns-established:
  - "Broker and Worker Repo Resolution: direct-upload entrypoints and follow-up workers resolve persistence through `Rindle.Config.repo/0`."
  - "Adopter Proof Isolation: tests opt into `@moduletag sandbox_repo: ...` and override `:rindle, :repo` for the duration of the proof."
requirements-completed: [ADOPT-02, ADOPT-03, ADOPT-04]
duration: 6 min
completed: 2026-04-28
---

# Phase 06 Plan 02: Adopter Runtime Ownership Summary

**Direct-upload broker flows, canonical adopter lifecycle coverage, and proxied `Rindle.upload/3` now execute against the configured adopter repo instead of relying on shared `Rindle.Repo` leakage.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-28T09:28:17Z
- **Completed:** 2026-04-28T09:34:44Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments
- Moved broker transactions, reads, and updates onto `Rindle.Config.repo/0` and removed adopter-facing broker docs that still required `Rindle.Repo`.
- Added real adopter-lane proofs for direct upload, attach/detach, and proxied `Rindle.upload/3`, all asserting through `Rindle.Adopter.CanonicalApp.Repo`.
- Extended the runtime repo seam into promotion, variant processing, and purge enqueue paths so lifecycle jobs stay on the same repo boundary as the initiating request.

## Task Commits

Each task was committed atomically:

1. **Task 1: Move broker persistence paths onto the runtime Repo seam**
   - `48a5a13` (`test`): failing broker runtime repo probe tests
   - `8726d45` (`feat`): broker repo resolution and adopter-facing doc cleanup
2. **Task 2: Add adopter-repo proofs for both the canonical lane and proxied `Rindle.upload/3`**
   - `2f1a9c4` (`test`): adopter lifecycle proofs, sandbox repo harness, targeted test execution
   - `051386b` (`feat`): runtime repo worker resolution and transaction-owned purge enqueue paths

## Files Created/Modified
- `lib/rindle/upload/broker.ex` - resolves broker persistence through the configured runtime repo and updates adopter-facing examples.
- `test/rindle/upload/broker_test.exs` - proves broker entrypoints hit the configured repo contract.
- `test/adopter/canonical_app/lifecycle_test.exs` - canonical adopter proof now overrides `:rindle, :repo` and reads entirely through the adopter repo.
- `test/rindle/upload/lifecycle_integration_test.exs` - adds a dedicated adopter-repo `Rindle.upload/3` proof.
- `test/support/data_case.ex` - adds per-test sandbox repo ownership selection.
- `test/test_helper.exs` - allows targeted adopter/integration files to run while keeping blanket exclusions for default suite runs.
- `lib/rindle.ex` - keeps attach/detach purge enqueue inside the transaction-owned repo path.
- `lib/rindle/workers/promote_asset.ex` - resolves promotion persistence through `Rindle.Config.repo/0`.
- `lib/rindle/workers/process_variant.ex` - resolves variant processing persistence through `Rindle.Config.repo/0`.
- `lib/rindle/workers/purge_storage.ex` - resolves purge cleanup persistence through `Rindle.Config.repo/0`.
- `config/test.exs` - updates adopter repo test harness commentary to reflect the live runtime contract.

## Decisions Made

- Stayed within the documented Phase 6 scope by keeping Oban ownership on the default instance and fixing enqueue sites to remain repo-coherent, rather than introducing a new named-instance seam.
- Treated targeted adopter/integration file execution as test harness behavior, not a product feature, so the proof files can run directly without turning on all excluded suites globally.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Extended runtime repo resolution into follow-up workers and purge enqueue paths**
- **Found during:** Task 2 (Add adopter-repo proofs for both the canonical lane and proxied `Rindle.upload/3`)
- **Issue:** The new adopter proofs exposed that promotion, variant processing, and attach/detach purge enqueue paths still leaked back to the default repo/Oban path, leaving assets stuck in `validating` or `analyzing` and causing ownership errors during detach.
- **Fix:** Switched `PromoteAsset`, `ProcessVariant`, and `PurgeStorage` to resolve persistence through `Rindle.Config.repo/0`, and reworked `attach/4` and `detach/3` to enqueue purge jobs through transaction-owned `Oban.insert` multi operations.
- **Files modified:** lib/rindle.ex, lib/rindle/workers/promote_asset.ex, lib/rindle/workers/process_variant.ex, lib/rindle/workers/purge_storage.ex
- **Verification:** `mix test test/adopter/canonical_app/lifecycle_test.exs` and `mix test test/rindle/upload/lifecycle_integration_test.exs`
- **Committed in:** `051386b`

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Necessary for the adopter-owned runtime contract to hold through the full lifecycle. No named-instance scope creep was added.

## Issues Encountered

- The global test helper excluded the exact adopter and integration files this plan needed to prove. The harness was narrowed so targeted-file runs execute while the default suite still excludes those tags.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 6 now has executable adopter-owned runtime proof for broker, facade, and follow-up job paths.
- Plan 06-03 can update guides against a live adopter contract instead of TODO-era caveats.

## Self-Check: PASSED
