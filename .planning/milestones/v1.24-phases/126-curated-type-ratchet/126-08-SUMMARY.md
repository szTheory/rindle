---
phase: 126-curated-type-ratchet
plan: "08"
subsystem: type-contracts
tags: [dialyzer, nightly, facade, broker, oban, safe-01]
requires:
  - phase: 126-07
    provides: zero-warning Tus/Mux supported baseline
provides:
  - source-unchanged supported probe for facade, Broker, and PromoteAsset atoms
  - complete 45-entry curated type disposition ledger
  - zero-warning exact-head Nightly Dialyzer receipt
affects: [126-09, type-baseline]
tech-stack:
  added: []
  patterns: [supported-source-unchanged-probe, private-producer-consumer-patterns, exact-head-receipts]
key-files:
  created: [.planning/phases/126-curated-type-ratchet/126-08-SUMMARY.md]
  modified: [.dialyzer_ignore.exs, .planning/phases/126-curated-type-ratchet/126-TYPE-EVIDENCE.md, lib/rindle/workers/promote_asset.ex, test/install_smoke/dialyzer_ignore_policy_test.exs]
key-decisions:
  - "E01-E03 are obsolete only after their supported source-unchanged probe emitted no matching warnings."
  - "E08 is corrected by removing only the unreachable private map fallback; public facade, Broker lifecycle, telemetry, errors, and opaque values remain untouched."
  - "The policy keeps the four retained supported analyzer-noise atom filters while all 45 starting tuples receive a disposition."
requirements-completed: [TYPE-01, TYPE-02, SAFE-01]
coverage:
  - id: D1
    description: "Facade, Broker, and PromoteAsset historical filters are supported-probed and reconciled without lifecycle or public-contract drift."
    requirement: SAFE-01
    verification:
      - kind: integration
        ref: MIX_ENV=test mix test test/rindle/convenience_api_test.exs test/rindle/upload/broker_test.exs test/rindle/workers/promote_asset_test.exs --seed 0
        status: pass
      - kind: other
        ref: bash scripts/maintainer/refactor_contract.sh
        status: pass
      - kind: other
        ref: Exact-head Nightly run 32648274668
        status: pass
    human_judgment: false
metrics:
  tasks_completed: 2
  files_modified: 4
  supported_probe_run: 32647835411
  supported_final_run: 32648274668
  duration: 15min
  completed: 2026-08-23
status: complete
---

# Phase 126 Plan 08: Final Atom Boundaries Summary

Facade/Broker historical atom filters are retired only where absent on the supported cell, while PromoteAsset removes one unreachable private fallback and the 45-entry ledger closes on a zero-warning exact-head Nightly.

## Completed Tasks

1. **Probe facade, Broker, and PromoteAsset atoms on supported 1.17/27**
   - Removed only E01-E03 and E08 historical atom filters with all source owners unchanged.
   - Exact-head Nightly run 32647835411 reproduced only E08 at PromoteAsset's private fallback; facade and Broker emitted nothing.
2. **Reconcile facade, Broker, and PromoteAsset and close the 45-entry ledger**
   - Removed the unreachable `normalized_av_spec?/1` fallback and aligned the policy's retained atom inventory to E04-E07.
   - Exact-head Nightly run 32648274668 is globally successful; Dialyzer and Nightly Summary both succeeded with zero warning annotations.

## Verification

- Focused convenience facade, Broker, and PromoteAsset suites: 60 tests passed (3 skipped).
- Ignore policy: 2 tests passed.
- `bash scripts/maintainer/refactor_contract.sh`: 92 contract tests passed.
- Probe [Nightly run 32647835411](https://github.com/szTheory/rindle/actions/runs/32647835411), exact SHA `a064b87e93728ca7a5343a9df7f734baadaa3d55`: Dialyzer failed only on E08; Nightly Summary succeeded.
- Final [Nightly run 32648274668](https://github.com/szTheory/rindle/actions/runs/32648274668), exact SHA `34a97267199dc69b86aca1f51054a92957ed0c85`: overall, [Dialyzer 97215815600](https://github.com/szTheory/rindle/actions/runs/32648274668/job/97215815600), and [Nightly Summary 97216143803](https://github.com/szTheory/rindle/actions/runs/32648274668/job/97216143803) all succeeded; exhaustive Dialyzer annotations were empty.

## Task Commits

1. **Task 1: expose and record final atom probe** — `a064b87`, `2906981`
2. **Task 2: reconcile final atom boundary and close ledger** — `34a9726`, `ad17cd1`

## Files Created/Modified

- `.dialyzer_ignore.exs` — removes obsolete and actionable final atom filters.
- `lib/rindle/workers/promote_asset.ex` — removes the unsupported private non-map fallback.
- `test/install_smoke/dialyzer_ignore_policy_test.exs` — preserves the exact four-item retained atom policy.
- `126-TYPE-EVIDENCE.md` — records probe/final receipts and all 45 dispositions.

## Decisions Made

- Retain only E04-E07 as atom-form analyzer noise; every other starting atom filter is obsolete or actionable-fixed.
- Do not add facade/Broker source changes: the supported probe proved their historical warnings absent.
- Keep normalization map-only because callers transform keyword variants before the private predicate, eliminating the unreachable fallback without behavior drift.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking policy drift] Aligned the exact atom inventory assertion**
- **Found during:** Task 1/2
- **Issue:** The source-unchanged probe intentionally removed four final atom filters, but the policy test still required the historical count of eight, causing the non-Dialyzer compatibility jobs to fail.
- **Fix:** Reduced the allowlist and expected count to the four supported retained atom filters.
- **Files modified:** `test/install_smoke/dialyzer_ignore_policy_test.exs`
- **Verification:** Policy suite passed locally and the final exact-head Nightly was globally successful.
- **Committed in:** `34a9726`

**Total deviations:** 1 auto-fixed (Rule 3).

## TDD Gate Compliance

The policy test produced the required RED signal against the obsolete eight-atom count before the final policy update. No additional public behavior test was needed for the private unreachable fallback: the owner suites already cover both keyword-to-map normalization and promotion lifecycle behavior.

## Known Stubs

None.

## Next Phase Readiness

Plan 126-09 can run aggregate authority and release-train validation from a complete 45-of-45 disposition ledger and a zero-warning supported Nightly receipt.

## Self-Check: PASSED

Verified the four task commits, policy test, complete 45-row ledger, and final supported receipt.
