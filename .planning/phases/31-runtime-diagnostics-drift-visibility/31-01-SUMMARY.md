---
phase: 31-runtime-diagnostics-drift-visibility
plan: 01
subsystem: diagnostics
tags: [doctor, runtime, oban, ffmpeg, migrations]
requires: []
provides:
  - Deterministic `mix rindle.doctor` registry and check IDs
  - Runtime, queue, delivery, and migration drift detection with actionable fixes
affects: [doctor, runtime-checks, operator-diagnostics]
tech-stack:
  added: []
  patterns: [summary-first diagnostics, stable check ids, read-only drift audit]
requirements-completed: [DIAG-01]
completed: 2026-05-06
---

# Phase 31 Plan 31-01 Summary

## Implemented

- Rebuilt `mix rindle.doctor` around a hidden `Rindle.Ops.RuntimeChecks` registry.
- Added stable doctor check IDs with structured `status`, `component`, `summary`, and `fix` fields.
- Expanded checks to cover:
  - FFmpeg/runtime drift
  - profile/runtime capability fit
  - default `Oban` ownership sanity
  - required queue presence, with `rindle_media` only required for AV-capable profiles
  - delivery capability drift
  - local playback route drift for local AV profiles
  - pending and unresolved Rindle migration drift
- Kept doctor read-only, deterministic, and summary-first before non-zero exit.

## Tests

- `mix test test/rindle/doctor_test.exs test/rindle/ops/runtime_checks_test.exs --warnings-as-errors`
- Result: 10 tests, 0 failures

## Notes

- The focused tests inject migration status for deterministic doctor coverage because the local test environment may not always have a ready migration table.
- No file ownership expansion was required beyond the allowed files plus this summary.
