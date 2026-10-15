---
phase: 133-evidence-charter-and-live-truth
plan: "130"
subsystem: package-provenance
tags: [hex, registry, package-provenance, offline-cache]
requires:
  - phase: 133-128
    provides: exact offline registry-miss diagnostic for mux
provides:
  - Frozen zero-credit preflight binding the mux registry candidate to committed source, lock, Hex, and cache evidence
affects: [133-129, EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
actuals:
  tokens: 14310
  tasks: 1
  commits: 3
  plan_head_before: 7f1ed19a57ef703b4e67367cc465f50901c53b0e
  plan_head_after: 18316ee773f7c7ad7bbc4e632726c0e729dde6d0
tech-stack:
  added: []
  patterns:
    - No-clobber JSON preflight with a canonical report digest
    - Fail-closed CLI paths when the supported runtime cannot load Hex
key-files:
  created:
    - scripts/maintainer/phase_133_registry_supply.mjs
    - test/install_smoke/phase_133_registry_supply_test.mjs
    - .planning/phases/133-evidence-charter-and-live-truth/133-130-REGISTRY-PREFLIGHT.json
  modified: []
key-decisions:
  - "Stop before authorization because installed Hex 2.5.1 cannot load on the pinned Elixir 1.17.3 / OTP 27 runtime."
  - "Preserve all five requirements as Pending and assign zero qualification credit."
requirements-completed: []
coverage:
  - id: D1
    description: Read-only, immutable zero-credit preflight for the mux 3.2.2 registry record and cache candidate, with a pinned-runtime blocker.
    verification:
      - kind: unit
        ref: "node --test test/install_smoke/phase_133_registry_supply_test.mjs"
        status: pass
      - kind: other
        ref: "node scripts/maintainer/phase_133_registry_supply.mjs verify-preflight --report .planning/phases/133-evidence-charter-and-live-truth/133-130-REGISTRY-PREFLIGHT.json"
        status: fail
      - kind: other
        ref: "node scripts/maintainer/phase_133_registry_supply.mjs verify-halted --preflight .planning/phases/133-evidence-charter-and-live-truth/133-130-REGISTRY-PREFLIGHT.json"
        status: fail
    human_judgment: true
    rationale: "After the preflight artifact was committed, both verifier commands reject its source identity because they require the recorded code commit to remain current HEAD. The frozen-source rule prevents changing the implementation or replacing the no-clobber report in this plan."
duration: 8min
completed: 2026-10-08
status: halted
---

# Phase 133 Plan 130: Evidence Charter and Live Truth Summary

**A fail-closed Hex mux 3.2.2 preflight freezes registry and cache provenance, then halts on OTP 27 incompatibility with zero request credit.**

## Performance

- **Duration:** At least 8 minutes from the first recorded task commit; the executor start timestamp was not retained in the resumed context.
- **Started:** 2026-10-08T13:31:58-04:00 (first recorded task activity)
- **Completed:** 2026-10-08T17:40:06Z
- **Tasks:** 1 of 3; Task 1 completed with its designed terminal stop.
- **Files modified:** 3

## Accomplishments

- Added focused tests and a read-only preflight that records committed source identity, mux lock checksums, installed Hex module hashes, cached archive and ETS cache digests, candidate registry URL/cache keys, and the exact Plan 128 diagnostic.
- Froze a no-clobber preflight report with SHA-256 `7b90732cd17d31561c637aa906da89ab28974f5b85c0fd31b2fa87915c1b82af`.
- Verified the terminal halt path before committing the report. A post-commit verification repeat exposed a source-identity mismatch in both verifier commands; the frozen source/test files remain unchanged.

## Task Commits

1. **Task 1 RED tests** - `c6a19d8f` (`test(133-130): add failing tests for registry preflight`)
2. **Task 1 implementation and passing tests** - `f15cbef6` (`feat(133-130): add guarded registry preflight and terminal stop`)
3. **Task 1 frozen preflight** - `18316ee7` (`docs(133-130): freeze terminal preflight stop`)

## Files Created/Modified

- `scripts/maintainer/phase_133_registry_supply.mjs` - Read-only preflight, evidence validation, and disabled fail-closed authorization/request routes.
- `test/install_smoke/phase_133_registry_supply_test.mjs` - Tests lock parsing, pinned-runtime failure classification, stale evidence rejection, and no-clobber publication.
- `.planning/phases/133-evidence-charter-and-live-truth/133-130-REGISTRY-PREFLIGHT.json` - Immutable preflight and terminal stop evidence.

## Frozen Candidate Tuple and Stop

- **Package:** `mux` `3.2.2`, repository `hexpm`.
- **Candidate URL:** `https://repo.hex.pm/packages/mux`.
- **Candidate cache destination/key:** `/Users/jon/.hex/cache.ets`, `versions/hexpm/mux`; related cache keys are `timestamp/hexpm/mux` and `registry_etag/hexpm/mux`.
- **Lock checksums:** inner `3d5f86a173b646f4c675bf7cc817bb010a1fde4fdb3ecfdd56a374a039e8db58`; outer `103a8dd092066eae17b0116cac87fbbb9cf60574f88387bf030500503dc64be9`.
- **Committed source:** SHA `f15cbef6da6eb8ba41fcab8320228b10842fd4b6`; tree `fe93a3db87a25c3fa9d5439e294806894a8645c4`.
- **Installed Hex:** `2.5.1`; installation SHA-256 `727ad8ff0d6ec5dcca50c41ab2c05317eb3a9d67fd990ea007446454f68299c4`.
- **Pinned runtime:** Elixir `1.17.3`, OTP `27.3.4.15`. A read-only runtime probe exited `78` with `HEX_REGISTRY_SERVER_UNAVAILABLE`; Hex `Registry.Server` could not be loaded.
- **Authorization state:** ineligible; candidate not finalized; no authorization or request was created. The old Plan 126 authorization remains consumed.
- **Requirements:** EVID-01, EVID-02, EVID-03, EVID-04, and TRUTH-08 remain Pending.

Static BEAM inspection identified the candidate package-record route, Hex signature decoder, repo-origin defaults, cache destination API, and cache keys. The pinned runtime could not load the cache implementation, so supported-runtime authenticated staging was not established. Task 2's fresh decision gate was therefore not reached; Task 3 was not started.

## Decisions Made

- Stop before authorization or network access because the installed Hex Registry.Server cannot be loaded by the pinned project runtime.
- Preserve the exact inspected candidate tuple as diagnostic evidence without treating it as authorization.
- Leave project STATE.md, ROADMAP.md, and REQUIREMENTS.md unchanged; no requirements were completed.

## Deviations from Plan

None - the plan's designed terminal zero-credit stop was recorded when supported-runtime authenticated cache staging could not be established.

## Issues Encountered

The installed Hex 2.5.1 modules are present and their bytes were inspected read-only, but the pinned Elixir 1.17.3 / OTP 27 runtime could not load `Hex.Registry.Server`. After the preflight report commit advanced HEAD, `verify-preflight` and `verify-halted` both failed with `preflight source mismatch`: `currentExpected()` compares the report's code commit against current HEAD, which now contains the report commit. The required no-edit-after-freeze boundary prevents repairing that verifier or replacing the no-clobber report in Plan 130. No external request, Mix child, package installation, or qualification child was started.

## User Setup Required

None.

## Next Phase Readiness

Plan 129 remains blocked. A future plan must establish a compatible supported-runtime Hex cache path and repair the source-identity verification contract without weakening the freeze boundary; only then can a fresh literal decision be requested for an exact preflight tuple. This halted plan has no active continuation at Task 2.

## Self-Check: FAILED

- Required implementation, test, preflight files, and three task commits exist.
- The focused test suite and automation-first contract pass.
- The latest `verify-preflight` and `verify-halted` runs fail with `preflight source mismatch` after the report commit advanced HEAD; the frozen source/test files were not edited.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-10-08*
