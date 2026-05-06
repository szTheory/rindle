---
phase: 24-domain-model-dsl-extension
plan: 05
subsystem: integration
tags: [probe, ffprobe, libvips, worker, backward-compat, adopter]
requires:
  - phase: 24-01
    provides: probe behaviour scaffold and metadata sanitizer
  - phase: 24-02
    provides: AV domain columns for persisted probe results
  - phase: 24-03
    provides: analyzing -> quarantined and transcoding lifecycle edges
  - phase: 24-04
    provides: digest-stable per-kind profile validation
provides:
  - MIME-dispatched image/video/audio probe adapters
  - PromoteAsset probe step with typed-column persistence, quarantine on failure, and tempfile cleanup
  - Canonical adopter parity gate proving image-only digest and lifecycle compatibility on v1.4
affects: [phase-24, phase-25, adopter-lifecycle, backward-compat]
tech-stack:
  added: []
  patterns: [behaviour-adapter, mime-dispatch, idempotent-probe-persistence, parity-gate]
key-files:
  created:
    - lib/rindle/probe/image.ex
    - lib/rindle/probe/av_probe.ex
    - test/rindle/probe/image_test.exs
    - test/rindle/probe/av_probe_test.exs
  modified:
    - lib/rindle/workers/promote_asset.ex
    - test/rindle/workers/promote_asset_test.exs
    - test/adopter/canonical_app/lifecycle_test.exs
key-decisions:
  - "Dispatch probes by MIME in PromoteAsset, preferring AVProbe before Image to keep video/audio handling explicit."
  - "Persist probe output through typed media_asset columns while sanitizing FFprobe metadata before storage."
patterns-established:
  - "Wrap probe tempfiles in try/after cleanup even when quarantine paths fire."
  - "Prove backward compatibility at the adopter boundary with digest and validated-map parity assertions."
requirements-completed: [AV-02-05, AV-02-06, AV-02-09, AV-02-10, AV-02-11]
duration: 10 min
completed: 2026-05-05
---

# Phase 24 Plan 05: Domain Model DSL Extension Summary

**The promotion pipeline now probes image, video, and audio assets before promotion, persists typed probe data safely, quarantines probe failures, and proves canonical image-only adopters remain byte-for-byte compatible on v1.4.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-05-05T11:38:33-04:00
- **Completed:** 2026-05-05T11:48:30-04:00
- **Tasks:** 3
- **Files modified:** 8

## Accomplishments

- Added `Rindle.Probe.Image` and `Rindle.Probe.AVProbe` as `Rindle.Probe` behaviour adapters, including FFprobe result reshaping plus metadata sanitization.
- Inserted the MIME-dispatched probe step into `Rindle.Workers.PromoteAsset`, persisting `kind`, dimensions, duration, track flags, and sanitized metadata while quarantining failures with `error_reason`.
- Added end-to-end regression coverage proving the canonical adopter profile still omits `:kind` for `:thumb`, keeps the v1.3 recipe digest, and passes the MinIO-backed lifecycle flow.

## Task Commits

1. **Task 1: Implement `Rindle.Probe.Image` and `Rindle.Probe.AVProbe` with tests** - `2e80dad` (`test`), `783aeec` (`feat`)
2. **Task 2: Insert MIME-dispatched probe step into `PromoteAsset` with persistence and quarantine coverage** - `37dbf5b` (`test`), `698f1a1` (`feat`)
3. **Task 3: Add canonical adopter parity gate for image-only backward compatibility** - `5525595` (`test`)

## Files Created/Modified

- `lib/rindle/probe/image.ex` - Added the libvips-backed image probe adapter returning `kind`, `width`, and `height`.
- `lib/rindle/probe/av_probe.ex` - Added the FFprobe-backed audio/video probe adapter with duration parsing, track flags, dimension extraction, and metadata sanitization.
- `lib/rindle/workers/promote_asset.ex` - Added MIME-based probe dispatch, temp-download cleanup, typed probe persistence, and quarantine-on-failure wiring in the analyzing path.
- `test/rindle/probe/image_test.exs` - Added behaviour coverage for image MIME acceptance and probed dimensions.
- `test/rindle/probe/av_probe_test.exs` - Added fixture-driven coverage for audio/video FFprobe reshaping and metadata sanitization.
- `test/rindle/workers/promote_asset_test.exs` - Added persistence, retry, quarantine, and tempfile cleanup coverage for the new probe step.
- `test/adopter/canonical_app/lifecycle_test.exs` - Added the load-bearing canonical adopter parity assertions for `:kind` omission and v1.3 digest stability.
- `.planning/phases/24-domain-model-dsl-extension/24-05-SUMMARY.md` - Recorded the final integration outcomes for Phase 24.

## Decisions Made

- Kept probe dispatch local to `PromoteAsset` so Oban retries from `analyzing` re-run the probe idempotently and overwrite typed probe columns safely.
- Sanitized persisted FFprobe metadata with `Rindle.AV.MetadataSanitizer` instead of storing raw tags, matching the Phase 24 safety contract.
- Verified backward compatibility at the adopter boundary rather than only in lower-level unit tests, making the parity gate reflect real consumer behavior.

## Deviations from Plan

### Auto-fixed Issues

None - the implementation matched the planned probe integration and parity scope without requiring out-of-scope changes.

---

**Total deviations:** 0 auto-fixed
**Impact on plan:** The final integration stayed within the declared Plan 05 files and delivered the required AV probe and parity behavior.

## Issues Encountered

None after the wave-level prerequisites were in place.

## User Setup Required

None - verification passed with the existing local test environment.

## Next Phase Readiness

- Phase 25 can build on the persisted probe data and transcoding-ready lifecycle.
- Phase 27 can rely on the canonical adopter profile still exposing image variants without a `:kind` key.
- Phase 24 is functionally complete and ready for phase-level verification/closeout.

## Verification

- `mix test --warnings-as-errors --exclude integration --exclude adopter`
- `mix test test/adopter/canonical_app/lifecycle_test.exs --warnings-as-errors`
- `mix test test/adopter/canonical_app/lifecycle_test.exs --include adopter --warnings-as-errors`
- `mix compile --warnings-as-errors`

## Self-Check: PASSED
