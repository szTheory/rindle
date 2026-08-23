---
phase: 126-curated-type-ratchet
plan: "06"
subsystem: storage
tags: [dialyzer, s3, multipart, tus, nightly, safe-01]
requires:
  - phase: 126-05
    provides: exact E38-E40-only intermediate Nightly receipt
provides:
  - supported S3 stream and tail analyzer-noise dispositions
  - exact S3 source-unchanged probe receipt
  - E38-E40-only final intermediate Nightly receipt
affects: [126-07, 126-08, 126-09]
tech-stack:
  added: []
  patterns: [source-unchanged supported probe, exact bounded-stream filter rationale]
key-files:
  created: [.planning/phases/126-curated-type-ratchet/126-06-SUMMARY.md]
  modified: [.dialyzer_ignore.exs, .planning/phases/126-curated-type-ratchet/126-TYPE-EVIDENCE.md]
key-decisions:
  - "S3 stream and tail warnings remain description-strict because the supported cell proves their active bounded-stream, tagged-error, ordered-slicing, and cleanup paths."
  - "Intermediate Nightly acceptance remains exactly E38-E40, with Dialyzer failure honestly surfaced by a successful Nightly Summary."
requirements-completed: []
coverage:
  - id: D1
    description: S3 upload, multipart/tus tail streaming, public endpoint, cleanup, and tagged errors retain behavior while exact supported filters are reconciled.
    requirement: SAFE-01
    verification:
      - kind: unit
        ref: MIX_ENV=test mix test test/rindle/storage/s3_test.exs test/rindle/storage/s3_tus_test.exs test/rindle/storage/s3_public_endpoint_test.exs test/install_smoke/dialyzer_ignore_policy_test.exs --seed 0
        status: pass
      - kind: other
        ref: bash scripts/maintainer/refactor_contract.sh
        status: pass
      - kind: other
        ref: Exact-head Nightly run 32644884559 annotation multiset
        status: pass
    human_judgment: false
metrics:
  tasks_completed: 2
  files_modified: 2
  supported_probe_run: 32644554878
  supported_final_run: 32644884559
  duration: 13min
  completed: 2026-08-23
status: complete
---

# Phase 126 Plan 06: S3 Adapter Boundary Summary

S3 retains only seven exact supported analyzer-noise filters while bounded multipart/tus tail streaming, tagged errors, endpoint behavior, and cleanup remain unchanged.

## Completed Tasks

1. **Probe S3 adapter warnings on the supported cell**
   - Removed only E31-E37 for a source-unchanged probe.
   - Exact-head Nightly run 32644554878 reproduced every S3 warning alongside only later-owned E38-E40 annotations.
2. **Reconcile S3 stream/tail helpers and prove the slice**
   - Restored E31-E37 with adjacent, supported evidence: they preserve runtime tagged errors, bounded `File.stream!/3` tail writes, ordered multipart slicing, bounded remainder copying, and cleanup.
   - Exact-head Nightly run 32644884559 emitted exactly E38-E40; Dialyzer failed and Nightly Summary succeeded while recording `DIALYZER: failure`.

## Verification

- Focused S3, S3 TUS-tail, public-endpoint, and ignore-policy suites: 19 tests passed, with four intentional MinIO exclusions.
- `bash scripts/maintainer/refactor_contract.sh`: 92 contract tests passed.
- Final supported [Nightly run 32644884559](https://github.com/szTheory/rindle/actions/runs/32644884559), exact head `d2107e6445680bf0d172230d01f3639fa946d1ec`:
  - [Dialyzer job 97207519962](https://github.com/szTheory/rindle/actions/runs/32644884559/job/97207519962) failed with exactly E38 at `tus_creation.ex:35` and E39-E40 at `tus_stream.ex:163` and `:66`.
  - [Nightly Summary job 97208026544](https://github.com/szTheory/rindle/actions/runs/32644884559/job/97208026544) succeeded and logged `DIALYZER: failure`.

## Task Commits

1. **Task 1: expose S3 filters** — `d21607f`
2. **Task 1: record supported probe receipt** — `78bc68f`
3. **Task 2: retain supported S3 analyzer noise** — `d2107e6`
4. **Task 2: record final receipt** — `498d826`

## Files Created/Modified

- `.dialyzer_ignore.exs` — keeps seven description-strict S3 filters with supported rationale.
- `.planning/phases/126-curated-type-ratchet/126-TYPE-EVIDENCE.md` — records probe and final S3 dispositions.

## Decisions Made

- No private S3 helper was removed: the source-unchanged accepted-cell probe proves E33-E37 against active multipart tail behavior.
- No source-level typespec/pattern change was justified: E31-E32 protect reachable tagged-error and bounded stream boundaries.

## Deviations from Plan

None - plan executed exactly as written. Existing S3 tests supplied the behavior proof, so no artificial RED/GREEN source change was warranted for the retained-noise disposition.

## TDD Gate Compliance

No new behavior was introduced: the supported probe established that every private helper is reachable, so the task retained exact analyzer-noise filters and verified the existing behavior suites instead of adding a synthetic RED/GREEN implementation change.

## Known Stubs

None.

## Next Phase Readiness

Plan 126-07 can rely on a supported S3 receipt: no S3, earlier, or unowned warning is emitted, and the only intermediate annotations are exactly E38-E40.

## Self-Check: PASSED

Verified the summary, evidence ledger, curated ignore list, and all four task commits are reachable.
