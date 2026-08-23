---
phase: 121-truthful-quality-signals-mechanical-hygiene
plan: "07"
subsystem: ci-quality
tags: [github-actions, mix, credo, doctor, av, safe-01, regression-contract]
requires:
  - phase: 121-01
    provides: Deterministic SAFE-01 preservation runner.
  - phase: 121-02
    provides: Verified focused real AV behavior tests.
  - phase: 121-03
    provides: Measured public Doctor ratchet.
  - phase: 121-04
    provides: Actionable Credo aggregate.
provides:
  - Blocking Quality and Contract carriers for deterministic Phase 121 signals.
  - Faithful local Mix aliases and maintainer reproduction guidance.
affects: [ci-release-topology, green-main, future-refactors]
tech-stack:
  added: []
  patterns:
    - Preserve the existing CI Summary carrier while changing only step severity.
    - Keep host-readiness-dependent runtime checks visibly advisory.
key-files:
  created:
    - test/install_smoke/quality_signal_policy_test.exs
  modified:
    - .github/workflows/ci.yml
    - mix.exs
    - RUNNING.md
key-decisions:
  - "Use existing Quality and Contract jobs as the blocking carriers; CI Summary needs and skip-as-pass semantics remain unchanged."
  - "Keep DB/Oban/profile-dependent runtime doctor and full-tree Credo style advisory while actionable Credo, dev Doctor, focused AV, Contract, and SAFE-01 block."
requirements-completed: [SIGNAL-01, SIGNAL-02, SIGNAL-03, SIGNAL-04, SAFE-01]
coverage:
  - id: D1
    description: Existing Quality and Contract jobs block deterministic quality and preservation regressions without changing CI Summary or release coupling.
    requirement: SIGNAL-01
    verification:
      - kind: unit
        ref: test/install_smoke/quality_signal_policy_test.exs
        status: pass
      - kind: unit
        ref: test/install_smoke/ci_lane_split_test.exs
        status: pass
      - kind: unit
        ref: test/install_smoke/release_guard_meta_test.exs
        status: pass
    human_judgment: false
  - id: D2
    description: Local aliases reproduce actionable Credo, measured Doctor, and SAFE-01 before a single default suite execution.
    requirement: SAFE-01
    verification:
      - kind: integration
        ref: mix ci
        status: pass
    human_judgment: false
duration: 16min
completed: 2026-08-22
status: complete
---

# Phase 121 Plan 07: Truthful Quality Signal Integration Summary

**Existing Quality and Contract jobs now block deterministic Credo, Doctor, AV, Contract, and SAFE-01 regressions while retaining the sole CI Summary and full-release verification topology.**

## Performance

- **Duration:** 16 min
- **Completed:** 2026-08-22T22:28:15Z
- **Tasks:** 2/2
- **Files modified:** 4

## Accomplishments

- Routed the actionable Credo aggregate, static dev Doctor, and post-install focused FFmpeg/ffprobe plus Vix/libvips tests through the existing Quality carrier with no failure masking.
- Made deterministic Contract tests and SAFE-01 block the existing Contract carrier; CI Summary, its needs, skip-as-pass evaluation, workflow identity, and release gate remain unchanged.
- Added `mix credo_quality`, `mix refactor_contract`, and `mix quality_signals`, then composed the deterministic checks into `mix ci` before its single default suite.
- Documented the blocking/advisory split, AV host prerequisites, and why the DB/Oban/profile runtime doctor remains advisory.

## Task Commits

1. **Task 1: Wire truthful gates through Quality and Contract to CI Summary** — `9511085` (`test` RED), `5ead03e` (`ci` GREEN)
2. **Task 2: Publish faithful local reproduction and run the full phase contract** — `5f47805` (`chore`)

## Files Created/Modified

- `.github/workflows/ci.yml` — blocking Quality/Contract steps and explicit advisory dispositions.
- `mix.exs` — local deterministic-quality aliases composed into `mix ci`.
- `RUNNING.md` — current severity, prerequisite, and local reproduction policy.
- `test/install_smoke/quality_signal_policy_test.exs` — durable structural lock for carriers, ordering, masking, local aliases, default-suite count, and topology.

## Decisions Made

- Reused the existing `quality` and `contract` job results already consumed by `CI Summary`; no required-check name, workflow trigger, permission, dependency, or release change was needed.
- Focused AV behavior is blocking only after the existing FFmpeg and libvips installs. The public runtime doctor remains advisory because Quality does not create its required DB, Oban, and profile-host state.
- `mix ci` deliberately excludes environment-dependent runtime doctor and push-main/full-verification-only lanes, while retaining exactly one default suite execution.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected the nested Doctor alias environment invocation**
- **Found during:** Task 2
- **Issue:** Mix's `cmd` alias executes its command directly, so `MIX_ENV=dev mix doctor ...` attempted to run a binary named `MIX_ENV=dev`.
- **Fix:** Used `env MIX_ENV=dev mix doctor --full --raise`, preserving the documented command and intended dev-only Doctor measurement.
- **Files modified:** `mix.exs`, `test/install_smoke/quality_signal_policy_test.exs`
- **Verification:** `mix quality_signals` and `mix ci` passed.
- **Committed in:** `5f47805`

**Total deviations:** 1 auto-fixed (Rule 1).

## Verification

- `mix test test/install_smoke/quality_signal_policy_test.exs test/install_smoke/ci_lane_split_test.exs test/install_smoke/release_guard_meta_test.exs --seed 0` — 33 tests, 0 failures.
- `bash scripts/maintainer/credo_quality.sh` — passed.
- `MIX_ENV=dev mix doctor --full --raise` — 68 modules, 0 failed, 100% docs/moduledocs/specs.
- `mix test --only contract --seed 0` — 15 tests, 0 failures.
- `bash scripts/maintainer/refactor_contract.sh` — 86 tests, 0 failures.
- `mix test test/rindle/probe/av_probe_test.exs test/rindle/processor/image_test.exs --seed 0` — 7 tests, 0 failures.
- `mix ci` — passed, including one default test suite.
- `./scripts/maintainer/repo_hygiene_check.sh` — local tree/release configuration clean; external latest-main CI status remained non-green.

## Issues Encountered

- Repository hygiene's only remaining block is external to this branch: the latest CI run on `main` was not green. The current working tree was clean and all local release-train invariants passed.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Future refactor plans can use `mix ci` and `bash scripts/maintainer/refactor_contract.sh` for deterministic local preservation proof; CI now blocks the matching quality regressions through its existing required carrier topology.

## Self-Check: PASSED

- All four declared implementation artifacts and this summary exist on disk.
- Task commits `9511085`, `5ead03e`, and `5f47805` exist in git history.
