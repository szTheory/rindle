---
phase: 05-ci-1-0-readiness
plan: 03
subsystem: ci
tags: [excoveralls, mix-coveralls, libvips, ex_doc, github-actions, ci-quality]

requires:
  - phase: 05-ci-1-0-readiness
    provides: Plan baseline (PROJECT.md, STATE.md, 05-CONTEXT.md, 05-RESEARCH.md, 05-PATTERNS.md)
provides:
  - excoveralls 0.18 dep with ExCoveralls test_coverage tool wiring
  - coveralls.json with 80% minimum_coverage and conventional skip_files
  - ex_doc bumped to ~> 0.40 (unblocks Plan 06 groups_for_extras + before_closing_head_tag)
  - CI quality job: libvips-dev installed before deps.get; mix coveralls replaces mix test
  - All CI-01..05 gates wired in quality job (format, compile-warnings, coverage 80%, credo --strict, dialyzer --format github)
affects: [05-01-telemetry, 05-04-adopter, 05-06-ex_doc, 05-release]

tech-stack:
  added: [excoveralls ~> 0.18]
  patterns:
    - "Coverage gate via mix coveralls reading coveralls.json minimum_coverage (Pitfall 3 prevention)"
    - "test_coverage: [tool: ExCoveralls] in mix.exs project/0 so mix test dispatches to ExCoveralls"
    - "preferred_cli_env mappings keep coveralls tasks in :test environment"
    - "libvips system dep installed before mix deps.get on CI runner"

key-files:
  created:
    - coveralls.json
    - .planning/phases/05-ci-1-0-readiness/05-03-SUMMARY.md
  modified:
    - mix.exs (test_coverage + preferred_cli_env + :excoveralls dep + ex_doc 0.34→0.40)
    - mix.lock (excoveralls + transitive deps)
    - .github/workflows/ci.yml (quality job: libvips step + mix coveralls replacing mix test)

key-decisions:
  - "coveralls.json minimum_coverage=80 with conventional skip_files (test/support, test/adopter, repo.ex, application.ex, priv/repo/migrations) plus lib/mix/tasks added at Claude's discretion (Mix tasks exercised via integration/adopter lanes, not unit tests)"
  - "treat_no_relevant_lines_as_covered=true to prevent @moduledoc/@type/defstruct-only files from being penalized as 0%"
  - "Used mix coveralls (local threshold gate) instead of mix coveralls.github (external coveralls.io service requires token + network egress)"
  - "ex_doc bumped 0.34 → 0.40 to unlock groups_for_extras and before_closing_head_tag for Plan 06 before any other plan touches docs config"
  - "Held the 80% threshold (not lowered) — current local coverage is 71.5%; Plan 01 telemetry tests + Plan 04 adopter lane will close the 8.5pt gap"

patterns-established:
  - "Pattern 1: Coverage threshold lives in coveralls.json minimum_coverage; mix.exs only wires the tool. Single source of truth for the gate value."
  - "Pattern 2: System deps (libvips-dev) install BEFORE mix deps.get so :image NIF compilation can find the headers/libs deterministically."
  - "Pattern 3: Replace mix test with mix coveralls in CI; do not keep both — duplicates suite execution and preferred_cli_env makes mix test → mix coveralls equivalent locally anyway."

requirements-completed: [CI-01, CI-02, CI-03, CI-04, CI-05]

duration: 4min
completed: 2026-04-26
---

# Phase 05 Plan 03: CI Quality Lane Hardening Summary

**Wired excoveralls 0.18 with an 80% minimum_coverage gate (coveralls.json), bumped ex_doc to 0.40, and rewired the CI quality job to install libvips-dev before deps fetch and run `mix coveralls` instead of `mix test` — preserving CI-01/02/04/05 gates and the matrix on 1.15/26 + 1.17/27.**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-04-26T21:38:30Z
- **Completed:** 2026-04-26T21:42:30Z
- **Tasks:** 2
- **Files modified:** 3 (mix.exs, mix.lock, .github/workflows/ci.yml)
- **Files created:** 2 (coveralls.json, 05-03-SUMMARY.md)

## Accomplishments

- `:excoveralls ~> 0.18` is in deps; `test_coverage: [tool: ExCoveralls]` and `preferred_cli_env` are in `mix.exs` project/0 (Pitfall 3 prevention — without `test_coverage`, `mix coveralls` would silently bypass the threshold gate)
- `coveralls.json` declares `minimum_coverage: 80` plus `treat_no_relevant_lines_as_covered: true` and the conventional `skip_files` allowlist (test/support, test/adopter, lib/rindle/repo.ex, lib/rindle/application.ex, priv/repo/migrations, lib/mix/tasks)
- `ex_doc` bumped from `~> 0.34` to `~> 0.40` (Plan 06 unblocked — `groups_for_extras` and `before_closing_head_tag` are 0.40+ features)
- CI `quality` job installs `libvips-dev` via `sudo apt-get install -y libvips-dev` immediately before `mix deps.get` (D-14 satisfied; resolves STATE.md pending todo "Add libvips system dependency note to CI config")
- CI `quality` job runs `mix coveralls` instead of bare `mix test` (D-13; CI-03)
- All other gates preserved in their original order: format check, compile warnings-as-errors, credo --strict, PLT cache + dialyzer --format github
- Quality matrix preserved (1.15/26 + 1.17/27) — both variants execute every step (Blocker 4)
- Integration job is byte-for-byte unchanged (Blocker 7)
- Local `mix coveralls` executes successfully and the threshold gate triggers correctly (currently fails with 71.5% < 80%, exactly as designed)

## Task Commits

Each task was committed atomically with `--no-verify` (parallel worktree mode):

1. **Task 1: Add excoveralls dep, mix.exs project config, and coveralls.json** — `093170a` (feat)
2. **Task 2: Wire libvips install + replace `mix test` with `mix coveralls` in CI quality job** — `5662230` (feat)

## Files Created/Modified

- `mix.exs` — Added `test_coverage: [tool: ExCoveralls]` and `preferred_cli_env` block in `project/0`; added `{:excoveralls, "~> 0.18", only: [:test, :dev], runtime: false}` to deps; bumped `:ex_doc` from `~> 0.34` to `~> 0.40`
- `mix.lock` — Regenerated with excoveralls 0.18.5 and the upgraded ex_doc + transitive deps (makeup_elixir, makeup_erlang, makeup, nimble_parsec, etc. fetched as part of doc/coverage chain)
- `coveralls.json` — New repo-root config: `coverage_options.minimum_coverage: 80`, `treat_no_relevant_lines_as_covered: true`, `skip_files` allowlist
- `.github/workflows/ci.yml` — Quality job: inserted "Install libvips" step before "Install dependencies"; replaced "Run tests" / `mix test` with "Run tests with coverage" / `mix coveralls`. Integration job untouched.

## Decisions Made

1. **`treat_no_relevant_lines_as_covered: true`** — Files containing only `@moduledoc`, `@type`, or `defstruct` declarations have no executable lines; without this flag they would be scored as 0% and tank the total. Standard excoveralls convention; documented in Pattern 1 of 05-RESEARCH.md.
2. **Added `lib/mix/tasks` to `skip_files`** (Claude's Discretion per CONTEXT.md) — Mix tasks have detailed `@moduledoc` blocks (D-18) but their bodies do shell I/O that is impractical to unit test; they're exercised via integration / adopter lanes. Excluding them keeps the 80% threshold achievable for production library code without lowering the bar.
3. **Held 80% threshold (no temporary lowering)** per Warning 6 calibration logic — Current local measured coverage is 71.5%, an 8.5pt gap from 80%. Plan 01 (telemetry emission tests) and Plan 04 (adopter lane integration) will both add covered code and tests; the gap is expected to close within Wave 1 + Wave 2. The CI quality lane will RED on first run (this is documented expected behavior per Plan 03 done block + Warning 6). If after Plan 01 + Plan 04 land the measured coverage is still materially below 80%, calibrate downward at that point — not now.
4. **`mix coveralls` (not `mix coveralls.github`)** — `coveralls.github` posts to coveralls.io requiring a token and network egress; `mix coveralls` is a self-contained local threshold gate reading `coveralls.json`. RESEARCH.md Anti-Patterns line 536 + Alternatives Considered line 138 endorse the local gate.

## Coverage Window Calibration (Warning 6)

| Question | Answer |
|----------|--------|
| Was the 80% threshold held or temporarily lowered? | **Held at 80%** |
| Current locally measured coverage | **71.5%** |
| Gap from threshold | **−8.5pt** |
| Expected closure path | Plan 01 (telemetry emission tests on event surface) + Plan 04 (adopter lane integration tests covering S3/MinIO + delivery + LiveView paths) — both directly increase covered relevant lines |
| Is CI quality lane RED on first run? | **Yes (expected)** — documented in Plan 03 done block as "Coverage window note (Warning 6)" |
| Re-evaluation trigger | After Plan 01 + Plan 04 land in the same merge window. If still < 80%, set threshold to floor(actual / 5) * 5 with documented ratchet plan. |

Per-file lowest-coverage files (candidates for Plan 01 / Plan 04 to lift):
- `lib/rindle/storage/s3.ex` — 13.8% (Plan 04 adopter lane via MinIO will exercise this)
- `lib/rindle/live_view.ex` — 15.0% (LiveView helpers; Plan 04 or future tests)
- `lib/rindle/workers/abort_incomplete_uploads.ex` — 33.3% (Plan 04 integration coverage)
- `lib/rindle/profile/digest.ex` — 52.3% (Plan 01 telemetry-adjacent edge tests can lift)
- `lib/rindle/processor/image.ex` — 64.2% (libvips now available on CI; extended-format paths can run)

## Deviations from Plan

None. Plan executed exactly as written.

The acceptance criterion `grep -B1 "mix deps.get" .github/workflows/ci.yml | grep -c "libvips"` returns 0 due to YAML structure (the `name: Install dependencies` step header sits between the libvips `run:` line and the `mix deps.get` `run:` line). The libvips step IS placed immediately before the deps.get step in the job's logical flow — confirmed by `grep -B3 "mix deps.get"` showing `run: sudo apt-get install -y libvips-dev` in the leading context, and by direct read of the file (lines 72-76). The grep check itself is a YAML-formatting artifact, not a placement defect; the spirit of the criterion (libvips-dev installs before mix deps.get fetches the :image dep) is fully satisfied.

## Issues Encountered

None. `mix deps.get` fetched excoveralls and the upgraded ex_doc cleanly. `mix coveralls` ran the full suite (145 tests, 0 failures, 1 skipped) and reported the per-file breakdown plus the expected `FAILED: Expected minimum coverage of 80%, got 71.5%.` line — exactly the gate behavior the plan calls for.

## Threat Flags

None — this plan only adds developer-time gates (CI quality lane); no production attack surface introduced. The two STRIDE entries in the plan's `<threat_model>` (T-05-03-01 compromised libvips package; T-05-03-02 excoveralls report leakage) are both `accept` dispositions with the original mitigations standing (Ubuntu apt trust model; `mix coveralls` does not post externally).

## Next Phase Readiness

- **Plan 01 (telemetry emission tests):** Ready to land — coverage tooling is in place, so Plan 01's new test files will directly contribute to the measured coverage number.
- **Plan 04 (adopter lane):** Ready — coveralls.json `skip_files` already excludes `test/adopter` so Plan 04's adopter test infra won't be measured against the library code threshold (conventional).
- **Plan 06 (ex_doc / docs):** Unblocked — ex_doc 0.40 is now the floor, so `groups_for_extras` and `before_closing_head_tag` can be used.
- **Quality lane will be RED on first CI run after Wave 1 merges** — this is documented expected behavior; do not panic-revert. Wait until Plan 01 + Plan 04 land before re-evaluating.

## Self-Check: PASSED

Created/modified files exist:

- FOUND: mix.exs (modified)
- FOUND: mix.lock (modified)
- FOUND: coveralls.json (created)
- FOUND: .github/workflows/ci.yml (modified)
- FOUND: .planning/phases/05-ci-1-0-readiness/05-03-SUMMARY.md (this file — being written now)

Commits exist:

- FOUND: 093170a (Task 1: feat(05-03): add excoveralls and 80% coverage gate)
- FOUND: 5662230 (Task 2: feat(05-03): wire libvips and coverage into CI quality job)

Acceptance criteria results:

- Task 1: 9/9 explicit greps pass; `mix coveralls` executes; gate triggers at 71.5% < 80% (expected)
- Task 2: 13/14 explicit greps pass as written; the 1 grep check that returned 0 (`grep -B1 "mix deps.get" | grep -c libvips`) is a YAML-formatting artifact (logical placement is correct — verified via `grep -B3`)

---
*Phase: 05-ci-1-0-readiness*
*Plan: 03*
*Completed: 2026-04-26*
