---
phase: 121-truthful-quality-signals-mechanical-hygiene
plan: 03
subsystem: documentation-quality
tags: [doctor, exdoc, typespecs, documentation, regression-test]
requires: []
provides:
  - "A measured dev Doctor ratchet over the curated public lib surface"
  - "Report-object regression coverage for the Doctor policy"
affects: [quality-gates, public-documentation, SIGNAL-02]
tech-stack:
  added: []
  patterns:
    - "Measure compiled Doctor report objects rather than asserting configuration literals alone."
key-files:
  created: []
  modified:
    - .doctor.exs
    - mix.exs
    - lib/rindle/processor/av.ex
    - test/rindle/doctor_thresholds_test.exs
key-decisions:
  - "Doctor ignores only named or established internal ownership boundaries; new modules remain checked by default."
  - "The ExUnit contract filters test-support paths and checks the same curated lib surface that dev Doctor measures."
requirements-completed: [SIGNAL-02]
coverage:
  - id: D1
    description: "The curated public dev surface satisfies the unchanged Doctor coverage ratchet."
    requirement: SIGNAL-02
    verification:
      - kind: other
        ref: "MIX_ENV=dev mix doctor --full --raise"
        status: pass
    human_judgment: false
  - id: D2
    description: "Doctor regression coverage evaluates compiled report objects, totals, and ExDoc-grouped public modules."
    requirement: SIGNAL-02
    verification:
      - kind: unit
        ref: "test/rindle/doctor_thresholds_test.exs#the compiled public surface satisfies the Doctor ratchet"
        status: pass
    human_judgment: false
duration: 4min
completed: 2026-08-22
status: complete
---

# Phase 121 Plan 03: Measured Doctor Public-Surface Ratchet Summary

**Doctor now measures a curated public `lib/` surface at 100% docs, moduledocs, and specs, with a report-driven regression contract.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-08-22T22:01:03Z
- **Completed:** 2026-08-22T22:05:06Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Curated Doctor exclusions to explicit internal ownership boundaries while preserving the 100/100/100/95/95 ratchet and checking ExDoc-grouped modules plus `Rindle.Processor.AV`.
- Added complete public docs/spec metadata to the AV processor boundary and the two measured public modules that lacked metadata.
- Replaced threshold-only assertions with direct `Doctor.CLI` and `Doctor.ReportUtils` report checks.

## Task Commits

1. **Task 1: Make the public Doctor report pass for measured reasons** — `9c15315` (docs)
2. **Task 2: Replace threshold-literal confidence with measured Doctor proof** — `5508511` (test)

## Files Created/Modified

- `.doctor.exs` — explicit internal module ownership exclusions with no broad public namespace catch-all.
- `mix.exs` — lists `Rindle.Processor.AV` in the public ExDoc adapter group.
- `lib/rindle/processor/av.ex` — documents all public functions on the AV processor boundary.
- `lib/rindle/admin/router.ex` — adds the missing spec for the checked public router validation entry point.
- `lib/rindle/domain/media_upload_session.ex` — documents the checked URI-redaction helper.
- `test/rindle/doctor_thresholds_test.exs` — validates compiled Doctor reports and aggregate health.

## Decisions Made

- Keep internal exclusions ownership-scoped and explicit so unclassified new modules are measured by default.
- Exercise report generation inside ExUnit, then filter test-only paths; `MIX_ENV=dev` remains the authoritative command for the production `lib/` report.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Completed metadata for two existing ExDoc-grouped modules**
- **Found during:** Task 1
- **Issue:** `Rindle.Admin.Router` lacked a spec and `Rindle.Domain.MediaUploadSession` lacked a public doc, so both required checked modules failed the unchanged ratchet.
- **Fix:** Added only accurate `@spec`/`@doc` metadata; no function bodies, signatures, routes, schema, behavior, or UI changed.
- **Files modified:** `lib/rindle/admin/router.ex`, `lib/rindle/domain/media_upload_session.ex`
- **Verification:** focused router/schema tests and `MIX_ENV=dev mix doctor --full --raise` passed.
- **Committed in:** `9c15315`

**2. [Rule 3 - Blocking] Replaced invalid dev ExUnit invocation with a two-command proof**
- **Found during:** Task 2
- **Issue:** `MIX_ENV=dev mix test ...` cannot boot this repository's test helper because the deliberate dev compilation surface excludes host migration fixtures under `test/support`.
- **Fix:** The report-object test runs under normal `MIX_ENV=test` and filters test-support paths, while `MIX_ENV=dev mix doctor --full --raise` independently verifies the authoritative production `lib/` surface.
- **Files modified:** `test/rindle/doctor_thresholds_test.exs`
- **Verification:** both replacement commands passed.
- **Committed in:** `5508511`

**Total deviations:** 2 auto-fixed (2 Rule 3 blocking fixes).

## Verification

- `MIX_ENV=test mix test test/rindle/doctor_thresholds_test.exs --seed 0` — passed (2 tests).
- `MIX_ENV=dev mix doctor --full --raise` — passed: 68 modules, 0 failed, 100.0% docs/moduledocs/specs.

## Known Stubs

None.

## Next Phase Readiness

SIGNAL-02 has a measured public-documentation gate; future public doc/spec regressions fail both the direct Doctor command and the report-object contract.

## Self-Check: PASSED

- Summary file exists and both task commits (`9c15315`, `5508511`) are present in git history.
