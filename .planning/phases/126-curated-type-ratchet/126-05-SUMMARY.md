---
phase: 126-curated-type-ratchet
plan: "05"
subsystem: storage
tags: [dialyzer, gcs, local-storage, streaming, nightly, safe-01]
requires:
  - phase: 126-04
    provides: exact TUS-only intermediate Nightly receipt
provides:
  - supported GCS and Local analyzer-noise dispositions
  - truthful GCS URL and auth-boundary precision
  - exact E38-E40-only intermediate Nightly receipt
affects: [126-06, 126-07, 126-08, 126-09]
tech-stack:
  added: []
  patterns: [source-unchanged supported probe, exact stream-boundary filter rationale]
key-files:
  created: [.planning/phases/126-curated-type-ratchet/126-05-SUMMARY.md]
  modified: [.dialyzer_ignore.exs, .planning/phases/126-curated-type-ratchet/126-TYPE-EVIDENCE.md, lib/rindle/storage/gcs/client.ex]
key-decisions:
  - "GCS and Local stream warnings remain description-strict only when preserving bounded streams, tagged errors, cleanup, and opaque dependency terms requires it."
  - "GCS collapses its duplicate private auth-error patterns into a truthful normalization boundary; resumable URL-mode analyzer noise remains exact and supported."
requirements-completed: []
coverage:
  - id: D1
    description: GCS and Local storage preserve upload, stream, resumable, concatenate, cleanup, capability, and tagged-error behavior while adapter type boundaries are reconciled.
    requirement: SAFE-01
    verification:
      - kind: unit
        ref: MIX_ENV=test mix test test/rindle/storage/gcs/client_test.exs test/rindle/storage/gcs_test.exs test/rindle/storage/gcs_concatenate_test.exs test/rindle/storage/local_test.exs test/rindle/storage/local_tus_test.exs test/install_smoke/dialyzer_ignore_policy_test.exs --seed 0
        status: pass
      - kind: other
        ref: bash scripts/maintainer/refactor_contract.sh
        status: pass
      - kind: other
        ref: Exact-head Nightly run 32644122207 annotation multiset
        status: pass
    human_judgment: false
metrics:
  tasks_completed: 2
  files_modified: 3
  supported_probe_run: 32643457947
  supported_final_run: 32644122207
  duration: 19min
  completed: 2026-08-23
status: complete
---

# Phase 126 Plan 05: GCS and Local Adapter Boundary Summary

GCS and Local retain only supported, exact analyzer-noise filters while bounded streams, tagged errors, concatenation cleanup, resumable behavior, and adapter capabilities remain unchanged.

## Completed Tasks

1. **Probe GCS and Local adapter warnings on the supported cell**
   - Removed only E25-E30 from the curated baseline while leaving both adapter sources unchanged.
   - Exact-head Nightly run 32643457947 reproduced seven owned GCS/Local annotations plus only E38-E40; no earlier or unowned warning appeared.
2. **Reconcile GCS and Local stream boundaries and prove the slice**
   - Added a complete, truthful GCS URL-mode spec and collapsed the duplicate private auth-error pattern without changing its `:goth_unconfigured` result.
   - Retained exact E25, E26, and E28-E30 filters with supported stream/opaque rationale; E27 is absent after the private pattern correction.
   - Exact-head Nightly run 32644122207 emitted exactly E38-E40; Dialyzer failed while Nightly Summary succeeded and recorded `DIALYZER: failure`.

## Verification

- Focused GCS/Local and policy suites: 44 tests passed, with one existing skipped test.
- `bash scripts/maintainer/refactor_contract.sh`: 92 contract tests passed.
- Final supported [Nightly run 32644122207](https://github.com/szTheory/rindle/actions/runs/32644122207), exact head `e4bcd1194205a447c9de21f814c9f42c4e1f210e`:
  - [Dialyzer job 97205599179](https://github.com/szTheory/rindle/actions/runs/32644122207/job/97205599179) failed with exactly E38 at `tus_creation.ex:35` and E39-E40 at `tus_stream.ex:163` and `:66`.
  - [Nightly Summary job 97206185744](https://github.com/szTheory/rindle/actions/runs/32644122207/job/97206185744) succeeded and logged `DIALYZER: failure`.

## Task Commits

1. **Task 1: expose GCS and Local filters** — `634e817`
2. **Task 1: record supported probe receipt** — `b38ff0e`
3. **Task 2: tighten GCS adapter type boundaries** — `7ecbb4e`
4. **Task 2: retain GCS resumable analyzer noise** — `e4bcd11`
5. **Task 2: record final receipt** — `0ff0a34`

## Decisions Made

- GCS multipart and Local tus/concatenation streams stay opaque and bounded; analyzer appeasement must not inspect stream state, buffer uploads, raise tagged errors, or weaken cleanup semantics.
- The broker-exercised GCS resumable URL mode remains an exact, supported E26 filter after its complete spec still triggers the supported analyzer's false-unreachable inference.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Verification/type-boundary correction] Retained E26 after the truthful URL-mode spec did not remove its supported warning**
- **Found during:** Task 2 final supported receipt verification.
- **Issue:** The first final exact-head receipt contained E26 in addition to the permitted E38-E40 multiset.
- **Fix:** Restored only E26 with the exact supported-run rationale; retained the truthful complete URL-mode spec and the E27 pattern correction.
- **Files modified:** `.dialyzer_ignore.exs`
- **Verification:** Focused adapter suites, SAFE-01, and exact-head Nightly run 32644122207 passed the three-warning predicate.
- **Committed in:** `e4bcd11`

**Total deviations:** 1 auto-fixed (Rule 1).
**Impact on plan:** No contract or behavior drift; the final emitted set is exactly the later-owned E38-E40 findings.

## Known Stubs

None.

## Next Phase Readiness

Plan 126-06 can rely on a truthful GCS/Local receipt: all GCS/Local warnings have supported dispositions, no unowned annotation is emitted, and only Plan 126-07's E38-E40 findings remain.

## Self-Check: PASSED

Verified the summary, evidence ledger, curated ignore list, and GCS client source exist; all task commits are reachable.
