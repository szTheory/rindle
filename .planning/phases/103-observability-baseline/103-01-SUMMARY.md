---
phase: 103-observability-baseline
plan: 01
subsystem: ci-observability
status: complete
tags: [ci, observability, elixir, junit, coverage, test-harness]
requires: []
provides:
  - "_build/test/junit/rindle-junit.xml (JUnit XML artifact, CI-only)"
  - "cover/excoveralls.json (coverage artifact, confirmed)"
  - "test-only {:junit_formatter, \"~> 3.4\", only: :test} dependency"
affects:
  - "Plan 103-03 ci.yml upload-artifact step (consumes the JUnit XML + coverage JSON paths)"
tech-stack:
  added:
    - "junit_formatter ~> 3.4 (test-only; victorolinasc/junit-formatter, requirements: {})"
  patterns:
    - "CI-gated ExUnit formatters list (JUnitFormatter only when System.get_env(\"CI\") is set)"
    - "Application.put_env(:junit_formatter, ...) report_dir/report_file config in test_helper.exs"
key-files:
  created: []
  modified:
    - mix.exs
    - mix.lock
    - test/test_helper.exs
decisions:
  - "junit_formatter does not create its report_dir; test_helper.exs mkdir_p's _build/test/junit (CI only) before ExUnit.start so the formatter's write! succeeds (Rule 3 blocking fix)"
metrics:
  duration: "2 min"
  completed: 2026-06-20
  tasks: 2
  files: 3
---

# Phase 103 Plan 01: Observability Baseline — Test-Harness Artifacts Summary

Added a test-only `junit_formatter` dependency and CI-gated ExUnit wiring so `CI=1 mix test` emits `_build/test/junit/rindle-junit.xml`, and confirmed `mix coveralls.json` writes `cover/excoveralls.json` — the two upload artifacts Plan 03's `ci.yml` step will reference. Local `mix test` stays quiet; the test-only dep never enters the shipped Hex package; zero `lib/` change.

## What Was Built

### Task 1 — Test-only junit_formatter dependency (mix.exs)
- Added `{:junit_formatter, "~> 3.4", only: :test},` to the Dev/Test deps block (immediately after `{:lazy_html, ">= 0.1.0", only: :test}`), matching existing entry formatting (D-06).
- Ran `mix deps.get`; `mix.lock` now carries `junit_formatter` (3.4.0).
- The Hex `package` `files:` `~w(...)` allowlist (mix.exs:278-279) is byte-unchanged — it lists only `lib priv/repo/migrations priv/static/rindle_admin mix.exs README.md RUNNING.md CHANGELOG.md LICENSE guides`, so the test-only dep cannot ship (T-103-01 mitigation).
- Commit: `41fccf8`

### Task 2 — CI-only JUnit XML wiring (test/test_helper.exs)
- Added a `formatters` binding before the existing `ExUnit.start` call: `[ExUnit.CLIFormatter, JUnitFormatter]` when `System.get_env("CI")` is set, otherwise `[ExUnit.CLIFormatter]` (local runs stay quiet).
- Added `Application.put_env(:junit_formatter, ...)` config: `report_dir` = `_build/test/junit`, `report_file` = `rindle-junit.xml`, `print_report_file: true`, `include_filename?: true`.
- Changed the call to `ExUnit.start(exclude: exclude_tags, formatters: formatters)`.
- `exclude_tags` (test_helper.exs:24-29), the repo/Oban startup (:1-15), and the Mock require (:33-35) are byte-unchanged.
- Commit: `6096944`

## Verification Results

- `CI=1 mix test` → exit 0; `3 doctests, 1158 tests, 0 failures, 4 skipped (76 excluded)`; wrote `_build/test/junit/rindle-junit.xml`. ✅
- `CI=1 mix coveralls.json` → exit 0; wrote `cover/excoveralls.json`. ✅
- `git check-ignore _build/test/junit/rindle-junit.xml cover/excoveralls.json` → both listed (no artifact leakage). ✅
- Plain `mix test` (CI env unset) → exit 0; no `_build/test/junit/rindle-junit.xml` created (local quiet). ✅
- No `lib/` file modified; `files:` allowlist unchanged. ✅

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] junit_formatter does not create its report_dir**
- **Found during:** Task 2 verification (`CI=1 mix test`).
- **Issue:** With `report_dir` set to `_build/test/junit`, junit_formatter crashed on suite finish with `File.Error{reason: :enoent, path: "_build/test/junit/rindle-junit.xml", action: "write to file"}` — it calls `File.write!/3` without first creating the directory, so the run exited non-zero and produced no XML.
- **Fix:** Added `if System.get_env("CI"), do: File.mkdir_p!(junit_report_dir)` in test_helper.exs (CI-gated, immediately after the put_env config and before `ExUnit.start`). Bound the path to a `junit_report_dir` variable to keep the mkdir and the put_env in sync. This stays within the plan's contract: CI-only, no restructuring of the existing startup, same target path. Local runs are unaffected (no mkdir, no formatter).
- **Files modified:** test/test_helper.exs
- **Commit:** `6096944`

The plan's RESEARCH.md wiring snippet (§ junit_formatter wiring) omitted the mkdir; this is the only addition beyond that snippet and is required for the must-have truth "Running `CI=1 mix test` writes a JUnit XML report file" to hold.

## Threat Surface

No new threat surface introduced. Both register mitigations held:
- T-103-01 (test-only dep leaking into Hex package): `only: :test` scope + byte-unchanged `files:` allowlist.
- T-103-02 (artifacts committed/shipped): both paths confirmed under already-gitignored `_build/` and `cover/` via `git check-ignore`.
- T-103-SC (hex install legitimacy): `junit_formatter` pre-approved in RESEARCH.md Package Legitimacy Audit (canonical victorolinasc/junit-formatter, `requirements: {}`); install succeeded cleanly, no checkpoint required.

## Known Stubs

None.

## Self-Check: PASSED
- mix.exs — junit_formatter dep present (`grep` confirmed)
- mix.lock — junit_formatter entry present
- test/test_helper.exs — JUnitFormatter wiring present
- Commit 41fccf8 — found in git log
- Commit 6096944 — found in git log
- _build/test/junit/rindle-junit.xml — produced under CI (gitignored, not committed by design)
- cover/excoveralls.json — produced under CI (gitignored, not committed by design)
