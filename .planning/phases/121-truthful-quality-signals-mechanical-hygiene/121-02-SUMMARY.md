---
phase: 121-truthful-quality-signals-mechanical-hygiene
plan: 02
subsystem: testing
tags: [telemetry, contract-tests, ffmpeg, ffprobe, vix, libvips, documentation]
requires: []
provides:
  - "Truthful public telemetry allowlist prose tied to the deterministic contract test"
  - "Fresh evidence that focused real AV and image tests pass with installed prerequisites"
affects: [contract-ci, phase-121]
tech-stack:
  added: []
  patterns:
    - "Treat shipped telemetry prose as contract evidence and keep it aligned with the test-owned allowlist."
key-files:
  created: []
  modified:
    - guides/background_processing.md
key-decisions:
  - "Document the existing @public_events registry and link to its contract test; runtime telemetry remains unchanged."
patterns-established:
  - "Use focused AV probe and image tests only after FFmpeg/ffprobe and Vix/libvips prerequisites are present."
requirements-completed: [SIGNAL-01]
coverage:
  - id: D1
    description: "Public telemetry allowlist prose matches the test-owned registry and preserves the AV transcode triplet."
    requirement: SIGNAL-01
    verification:
      - kind: unit
        ref: "mix test --only contract --seed 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "Real FFmpeg/ffprobe fixture creation and Vix/libvips image transformations remain executable when prerequisites are installed."
    requirement: SIGNAL-01
    verification:
      - kind: integration
        ref: "mix test test/rindle/probe/av_probe_test.exs test/rindle/processor/image_test.exs --seed 0"
        status: pass
    human_judgment: false
duration: 5min
completed: 2026-08-22
status: complete
---

# Phase 121 Plan 02: Restore Deterministic Contract Path Summary

**Public telemetry documentation now names the locked `@public_events` registry and links directly to its deterministic Contract proof, with fresh real AV prerequisite evidence.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-08-22T22:00:00Z
- **Completed:** 2026-08-22T22:05:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Reconciled the shipped telemetry allowlist prose with `Rindle.Contracts.TelemetryContractTest` without changing runtime events, metadata, or emitters.
- Restored the deterministic Contract command to 15 passing tests.
- Confirmed the selected real AV proof passes: FFmpeg 8.0.1/ffprobe create and inspect fixtures, and Vix/libvips executes image transformations (7 passing tests).

## Task Commits

1. **Task 1: Restore the real deterministic Contract path** — `1ca9f2e` (docs)

## Files Created/Modified

- `guides/background_processing.md` — Identifies the locked `@public_events` registry and links it to the enforcing contract test.

## Decisions Made

- Used `Rindle.Contracts.TelemetryContractTest` as the sole source of truth and made only the planned shipped-prose correction.
- Treated FFmpeg/ffprobe and Vix/libvips as verified prerequisites for focused AV behavior evidence, rather than weakening any contract or product test.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The initial Contract run failed only because the guide omitted the literal `@public_events` registry reference and test path. The planned documentation reconciliation resolved it.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The deterministic Contract suite is green and ready for CI severity wiring.
- The selected AV tests are green with locally available FFmpeg 8.0.1/ffprobe and Vix/libvips; CI must continue running them after its existing install steps.

## Self-Check: PASSED

- Found `guides/background_processing.md` and this summary on disk.
- Confirmed task commit `1ca9f2e` exists in git history.

---
*Phase: 121-truthful-quality-signals-mechanical-hygiene*
*Completed: 2026-08-22*
