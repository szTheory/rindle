---
phase: 29-adopter-proof-matrix
plan: 02
subsystem: testing
tags: [elixir, phoenix, av, ffmpeg, smoke, minio]
requires:
  - phase: 29-01
    provides: mode-explicit generated-app package-consumer baseline
  - phase: 28
    provides: canonical adopter AV contract
provides:
  - generated-app AV package-consumer proof path
  - structured AV smoke evidence for playback-ready outputs
affects: [phase-29, install-smoke, adopter-av, public-smoke]
tech-stack:
  added: []
  patterns: [generated-app profile modes, structured smoke reports]
key-files:
  created: []
  modified:
    - test/install_smoke/support/generated_app_helper.ex
    - test/install_smoke/generated_app_smoke_test.exs
    - test/adopter/canonical_app/lifecycle_test.exs
    - scripts/public_smoke.sh
key-decisions:
  - "Keep AV package-consumer proof inside the generated-app seam instead of adding a second smoke harness."
  - "Persist AV proof facts as JSON from the generated app rather than scraping ExUnit stdout."
patterns-established:
  - "Generated-app smoke may expose multiple profile modes through one helper when the outer assertions stay mode-specific."
  - "AV proof should assert ready variants and playback-ready delivery using structured report fields."
requirements-completed: [PROOF-02]
duration: 19min
completed: 2026-05-06
---

# Phase 29 Plan 02 Summary

**The generated-app package-consumer harness now proves the AV path from an installed artifact, including upload, probe/transcode, ready `poster` plus `web_720p` variants, and signed playback-ready delivery**

## Performance

- **Duration:** 19 min
- **Started:** 2026-05-06T01:29:00Z
- **Completed:** 2026-05-06T01:48:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Extended `GeneratedAppHelper` with profile-aware image/video execution while keeping one outside-in generated-app seam.
- Added a generated-app `VideoProfile` based on the public web preset story and copied the canonical AV lifecycle into the package-consumer smoke lane.
- Switched AV proof assertions from stdout grep to a structured JSON report emitted by the generated app, covering ready variants, playback storage key, and signed delivery path.
- Tightened the canonical adopter AV fixture with explicit playback-ready URL assertions and kept `public_smoke.sh` mode-driven for published-version AV proof.

## Files Created/Modified

- `test/install_smoke/support/generated_app_helper.ex` - adds profile-mode execution, generated-app AV lifecycle proof, and structured AV report capture.
- `test/install_smoke/generated_app_smoke_test.exs` - splits image/video assertions cleanly and verifies structured AV proof facts.
- `test/adopter/canonical_app/lifecycle_test.exs` - strengthens the repo-local AV source pattern with playback-ready URL assertions for `web_720p`.
- `scripts/public_smoke.sh` - accepts `RINDLE_INSTALL_SMOKE_PROFILE` so the published-version smoke can target image, video, or both through the same ExUnit harness.

## Verification

Passed task-level and plan-level commands:

```bash
mix test test/install_smoke/generated_app_smoke_test.exs --include minio
mix test --only adopter test/adopter/canonical_app/lifecycle_test.exs
```

Observed results:

- `mix test test/install_smoke/generated_app_smoke_test.exs --include minio` -> `4 tests, 0 failures`
- `mix test --only adopter test/adopter/canonical_app/lifecycle_test.exs` -> `7 tests, 0 failures`

## Deviations from Plan

None in behavior. One intermediate assertion initially inspected stdout for variant names; it was replaced with structured JSON evidence from the generated app before final verification.

## Issues Encountered

- ExUnit rejected `setup_all` inside `describe` during the first AV smoke draft; the outer smoke file was reshaped into separate image/video modules.
- String-matching AV verification was too weak to be a truthful contract and was replaced with structured report fields.

## Next Phase Readiness

The generated-app harness now carries both image and AV truths, which leaves Phase 29-03 to wire those proofs into CI and release-facing commands without inventing new runtime logic.

## Self-Check

PASSED
