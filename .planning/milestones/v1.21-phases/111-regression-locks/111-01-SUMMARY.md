---
phase: 111-regression-locks
plan: 01
subsystem: ci-meta-tests
tags: [regression-lock, meta-test, install-smoke, planning-hygiene, quality-lane]
requires: []
provides:
  - "LOCK-01: install_smoke.sh phx.new self-install preflight meta-test"
  - "LOCK-05: .planning/ path hygiene meta-test over test/**/*.exs"
affects:
  - test/install_smoke/install_smoke_preflight_test.exs
  - test/planning_path_hygiene_test.exs
tech-stack:
  added: []
  patterns:
    - "SHIPPED-artifacts-only meta-test (read scripts/ or test/, never .planning/)"
    - ":binary.match order-index assertion (install-before-smoke)"
    - "Path.wildcard glob + assert files != [] anti-vacuous guard + sorted offender list"
    - "runtime-assembled detection regex so the scanner does not flag itself"
key-files:
  created:
    - test/install_smoke/install_smoke_preflight_test.exs
    - test/planning_path_hygiene_test.exs
  modified: []
decisions:
  - "D-01: LOCK-01 ships as a new sibling install_smoke_preflight_test.exs (self-documenting lock) rather than folding into package_metadata_test.exs"
  - "LOCK-01 order index uses the bare 'mix archive.install hex phx_new' substring (no MIX_ENV=dev prefix, no --force suffix) so cosmetic line edits do not break the order check (RESEARCH Anti-Pattern #1)"
  - "LOCK-05 globs the broader test/**/*.exs (superset of *_test.exs) to catch support/helper files (RESEARCH Anti-Pattern #4)"
  - "LOCK-05 assembles its .planning detection regex at runtime from interpolated parts so the test file itself contains no line that both calls a read fn AND names the planning dir (would otherwise self-flag)"
metrics:
  duration_min: 1
  completed: 2026-06-28
  tasks_completed: 2
  files_created: 2
status: complete
---

# Phase 111 Plan 01: Regression Locks (LOCK-01, LOCK-05) Summary

Two standalone shipped-artifact meta-tests in the merge-blocking `quality` lane that make the 2026-06-26 phx.new self-install fix and the `.planning/`-path decoupling fix undeletable: a future edit that removes the install-smoke guard or re-couples any test to a `.planning/` path now REDs on the PR instead of silently on `main`.

## What Was Built

- **LOCK-01** — `test/install_smoke/install_smoke_preflight_test.exs` (`Rindle.InstallSmoke.InstallSmokePreflightTest`): one test asserting `scripts/install_smoke.sh` contains the `mix phx.new --version` probe and the `mix archive.install hex phx_new --force` self-install, and that the install precedes the `generated_app_smoke_test.exs` invocation by `:binary.match` order index. `:binary.match` RAISES on an absent substring — the intended loud failure for a deleted guard.
- **LOCK-05** — `test/planning_path_hygiene_test.exs` (`Rindle.PlanningPathHygieneTest`): globs `test/**/*.exs`, asserts `files != []` (anti-vacuous), and fails with a sorted `file:line` offender list if any test reads a planning path via `File.read!`, `File.exists?`, or `Path.expand`. The detection regex is assembled at runtime so the test does not flag itself.

Both modules use `use ExUnit.Case, async: true` with no exclude tag → default suite → merge-blocking `quality` lane. Neither reads a `.planning/` path. Zero `lib/` change.

## Verification

- `mix test test/install_smoke/install_smoke_preflight_test.exs test/planning_path_hygiene_test.exs` → 2 tests, 0 failures (GREEN on `main`).
- **Anti-theater RED proof (LOCK-01):** deleting the `mix archive.install hex phx_new --force` line from `scripts/install_smoke.sh` → LOCK-01 REDs (1 failure); reverted → GREEN. `scripts/install_smoke.sh` confirmed byte-clean (no drift).
- **Anti-theater RED proof (LOCK-05):** adding a throwaway `test/scratch_planning_read.exs` that calls `File.exists?(Path.expand("../.planning/STATE.md", …))` → LOCK-05 REDs naming the offender at `:4`; scratch deleted → GREEN.
- **Self-flag check:** LOCK-05 is GREEN on arrival, confirming the runtime-assembled regex prevents the test from matching its own source.
- **OBS-02 content-drift guard:** no other test's literals were changed; this plan creates two NEW files only and modifies no shipped artifact, so no `test/install_smoke/` literal is at risk.

## Threat Mitigations Applied

- **T-111-01** (Tampering, LOCK-05 glob): `assert files != []` so an empty/mis-rooted glob fails loudly instead of vacuously passing. Applied.
- **T-111-02** (Repudiation, LOCK-01 order-index): `:binary.match` RAISES on an absent substring and the order index proves sequencing, not just presence. Applied.
- **T-111-03** (Tampering, the new meta-tests themselves): both read SHIPPED paths only (`scripts/`, `test/`); LOCK-05 would catch a `.planning/` coupling introduced by either new test in the same run (verified — LOCK-05 GREEN with both new files present). Applied.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

- FOUND: test/install_smoke/install_smoke_preflight_test.exs
- FOUND: test/planning_path_hygiene_test.exs
- FOUND commit 7556c2c (LOCK-01)
- FOUND commit 249acd2 (LOCK-05)
