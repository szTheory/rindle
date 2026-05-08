---
phase: 41-onboarding-docs-doctor-package-consumer-proof
plan: 02
subsystem: doctor
tags: [doctor, runtime-checks, gcs, resumable-uploads, warnings]
requires:
  - phase: 37
    provides: GCS doctor foundation checks and profile-aware gating
  - phase: 39
    provides: shipped GCS resumable capability semantics
provides:
  - Warning-capable runtime-check report items
  - Profile-aware `doctor.gcs_resumable_cors` advisory check for resumable GCS adopters
  - `[WARN]` rendering in `mix rindle.doctor` without changing error-only exit behavior
affects: [operator-output, onboarding, GCS-resumable-adopters]
key-files:
  modified:
    - lib/rindle/ops/runtime_checks.ex
    - lib/mix/tasks/rindle.doctor.ex
    - test/rindle/ops/runtime_checks_test.exs
    - test/rindle/doctor_test.exs
  unchanged:
    - test/rindle/ops/runtime_checks_streaming_test.exs
requirements-completed: [RESUMABLE-13]
completed: 2026-05-07
---

# Phase 41 Plan 02 Summary

Implemented both Plan 41-02 tasks in the owned doctor/runtime-check surface.

## Accomplishments

- Widened `Rindle.Ops.RuntimeChecks` report semantics from `:ok | :error` to `:ok | :warn | :error` while preserving the existing failure contract that only `:error` increments `report.failed` and flips `report.success?`.
- Added the profile-aware `doctor.gcs_resumable_cors` check. It is emitted only when at least one discovered profile is GCS-backed and advertises `:resumable_upload_session`, keeping zero new noise for non-GCS adopters.
- Implemented resumable CORS inspection against bucket CORS metadata or equivalent injected bucket-config shape, rather than generic response headers.
- Made incomplete or uninspectable resumable bucket CORS posture advisory with `status: :warn`. The warning fix text explicitly calls out app origins, `PUT`, `PATCH`, `Content-Range`, `x-goog-resumable`, `session_uri` secrecy, one-week expiry, and region pinning.
- Updated `Mix.Tasks.Rindle.Doctor` to render warning rows as `[WARN]` and print warning fixes, while leaving `[OK]`, `[ERROR]`, and error-only exit semantics unchanged.
- Added targeted tests proving the new row is absent when irrelevant, appears as `:warn` when CORS shape is incomplete, warnings do not count as failures, and warning-only doctor runs do not raise.

## Files Changed

- `lib/rindle/ops/runtime_checks.ex`
- `lib/mix/tasks/rindle.doctor.ex`
- `test/rindle/ops/runtime_checks_test.exs`
- `test/rindle/doctor_test.exs`

## Verification

- Ran `mix test test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_checks_streaming_test.exs test/rindle/doctor_test.exs`
- Result: PASS (`49 tests, 0 failures`)

## Acceptance Criteria

- Met. `doctor.gcs_resumable_cors` exists, warning-capable report items exist, warning output renders as `[WARN]`, non-GCS adopters stay quiet, warning-only runs do not fail, and error exit behavior is unchanged.

## Deviations / Blockers

- No scope deviations in the shipped code.
- `test/rindle/ops/runtime_checks_streaming_test.exs` did not require edits; it remained part of the requested verification run and passed unchanged.
