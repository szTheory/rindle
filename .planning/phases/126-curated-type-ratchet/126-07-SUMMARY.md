---
phase: 126-curated-type-ratchet
plan: "07"
subsystem: uploads-and-streaming
tags: [dialyzer, tus, mux, crypto, nightly, safe-01]
requires:
  - phase: 126-06
    provides: exact E38-E40-only intermediate Nightly receipt
provides:
  - exact supported Tus/Mux probe with historical and emitted identities separated
  - opacity-safe Tus stream state and truthful concatenation result boundary
  - zero-warning exact-head Nightly Dialyzer receipt
affects: [126-08, 126-09]
tech-stack:
  added: []
  patterns: [tagged opaque state, exact provider-union clauses, deterministic exact-head receipt]
key-files:
  created: [.planning/phases/126-curated-type-ratchet/126-07-SUMMARY.md]
  modified: [.dialyzer_ignore.exs, .planning/phases/126-curated-type-ratchet/126-TYPE-EVIDENCE.md, lib/rindle/upload/broker.ex, lib/rindle/upload/tus_stream.ex, lib/rindle/workers/mux_ingest_variant.ex, lib/rindle/workers/mux_sync_provider_asset.ex]
key-decisions:
  - "E38-E40 retain tus_plug.ex as immutable filter history while their supported warning owners remain tus_creation.ex and tus_stream.ex."
  - "Tus checksum state is tagged rather than truth-tested, so crypto opacity remains intact."
  - "Mux clauses are removed only where exact normalized result unions make them unreachable."
requirements-completed: []
coverage:
  - id: D1
    description: Tus creation, concatenation, PATCH checksum, offsets, Local stream state, and Mux lifecycle/redaction behavior remain intact while the supported Dialyzer slice becomes green.
    requirement: SAFE-01
    verification:
      - kind: integration
        ref: MIX_ENV=test mix test test/rindle/upload/tus_plug_test.exs test/rindle/storage/local_tus_test.exs test/rindle/workers/mux_ingest_variant_test.exs test/rindle/workers/mux_sync_provider_asset_test.exs --seed 0
        status: pass
      - kind: other
        ref: bash scripts/maintainer/refactor_contract.sh
        status: pass
      - kind: other
        ref: Exact-head Nightly run 32647429343
        status: pass
    human_judgment: false
metrics:
  tasks_completed: 2
  files_modified: 6
  supported_probe_run: 32645321210
  supported_final_run: 32647429343
  duration: 47min
  completed: 2026-08-23
status: complete
---

# Phase 126 Plan 07: Tus and Mux Boundaries Summary

Tus checksum opacity, concatenation result typing, and normalized Mux response boundaries are truthful without changing protocol, lifecycle, telemetry, redaction, or error behavior.

## Completed Tasks

1. **Probe Tus and Mux filters on supported 1.17/27**
   - Removed only E38-E40's historical `tus_plug.ex` tuples and the two Mux strict descriptions on source-unchanged owners.
   - Exact-head Nightly run 32645321210 reproduced exactly five owned warnings, preserving E38-E40's starting filter identity separately from their actual emitted owner paths.
2. **Correct Tus creation/stream and Mux response-pattern boundaries**
   - Corrected the concatenation result spec, used an explicit tagged checksum-state boundary without observing opaque crypto state, eliminated an always-true parts branch, and removed only unreachable Mux fallback clauses.
   - Exact-head Nightly run 32647429343 is globally successful, with Dialyzer and Nightly Summary both successful and zero warning annotations.

## Verification

- Focused TusPlug, Local-TUS, Mux ingest, and Mux sync suites: 78 tests passed.
- `bash scripts/maintainer/refactor_contract.sh`: 92 contract tests passed.
- Probe [Nightly run 32645321210](https://github.com/szTheory/rindle/actions/runs/32645321210), exact SHA `f2c56d0702f4365d94eeb36b1d952e48649f6dd9`: Dialyzer failed only with the three extracted TUS and two Mux candidates; Nightly Summary succeeded.
- Final [Nightly run 32647429343](https://github.com/szTheory/rindle/actions/runs/32647429343), exact SHA `f0081e22f635ebfe6b2372d200d1975a5cb6babb`: overall, [Dialyzer 97213716124](https://github.com/szTheory/rindle/actions/runs/32647429343/job/97213716124), and [Nightly Summary 97214118173](https://github.com/szTheory/rindle/actions/runs/32647429343/job/97214118173) all succeeded; exhaustive warnings were empty.

## Task Commits

1. **Task 1: expose and record Tus/Mux supported probe** — `f2c56d0`, `a8454f4`
2. **Task 2: correct and record Tus/Mux boundaries** — `f0081e2`, `fdc33c1`

## Files Created/Modified

- `.dialyzer_ignore.exs` — removes obsolete historical TUS paths and strict Mux entries.
- `lib/rindle/upload/broker.ex` — advertises the actual concatenation result map.
- `lib/rindle/upload/tus_stream.ex` — keeps opaque checksum state tagged and makes parts merging explicit.
- `lib/rindle/workers/mux_ingest_variant.ex` and `lib/rindle/workers/mux_sync_provider_asset.ex` — remove only unreachable union fallbacks.
- `126-TYPE-EVIDENCE.md` — retains the complete supported probe/final receipts and the starting-versus-emitted identity distinction.

## Decisions Made

- The immutable E38-E40 starting tuples at `tus_plug.ex` are obsolete only at those historical paths; the actual extracted owner dispositions remain separate ledger facts.
- No ignore was restored: all five supported candidates were actionable and are absent from the final supported annotation set.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Type specification] Corrected Broker's concatenation result type**
- **Found during:** Task 2
- **Issue:** `concatenate_tus_sessions/3` returned `{:ok, %{session: session}}` but advertised a bare-session result, causing TusCreation's established pattern to appear unreachable.
- **Fix:** Updated the private API boundary to its existing truthful `initiate_tus_result/0` shape.
- **Files modified:** `lib/rindle/upload/broker.ex`
- **Verification:** Focused TUS behavior suites, SAFE-01, and the zero-warning supported Dialyzer receipt.
- **Committed in:** `f0081e2`

**Total deviations:** 1 auto-fixed (Rule 1).

## TDD Gate Compliance

This behavior-preserving analyzer correction had no valid failing behavioral RED case: all required protocol, checksum, offset, lifecycle, telemetry, redaction, and error tests already passed before the private type/pattern changes. The same focused suites and SAFE-01 passed after the corrections.

## Known Stubs

None.

## Next Phase Readiness

Plan 126-08 can start from a globally green supported Nightly baseline; no TUS/Mux warning remains and the evidence ledger records all five final dispositions.

## Self-Check: PASSED

Verified all four task commits, the evidence ledger, the curated ignore list, and the final supported receipt are present and reachable.
