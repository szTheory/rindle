---
phase: 108-coverage-single-run
plan: 01
subsystem: infra
tags: [ci, github-actions, excoveralls, coverage, mix, devx]

# Dependency graph
requires:
  - phase: 106-trigger-split-matrix-lane-refinement
    provides: "CI lane classification (quality/integration/adoption merge-blocking lanes), CI Summary aggregate gate, name: CI release coupling, mix ci alias"
  - phase: 107
    provides: "v1.20 CI/CD performance baseline (observability, cache, aggregate-check, lane-split, hardening)"
provides:
  - "Single ExUnit suite run per default-suite lane (quality, integration, adoption) — redundant second full-suite coverage run eliminated"
  - "quality lane single-run dual-output via mix coveralls.multiple --type local --type json (gate + cover/excoveralls.json from ONE execution)"
  - "mix.exs cli/0 preferred_envs entry pinning coveralls.multiple to :test"
  - "RUNNING.md local↔CI coverage reproduction parity (COV-04)"
affects: [109-epipe-hardening, ci, coverage, devx]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Single-run dual-output coverage: mix coveralls.multiple --type local (gate) + --type json (side-artifact) from one suite execution; gate verdict NEVER derived from the Json formatter"
    - "Drop redundant standalone coverage runs on lanes with no artifact consumer (decision 2b / D-07)"

key-files:
  created:
    - .planning/phases/108-coverage-single-run/108-01-SUMMARY.md
  modified:
    - .github/workflows/ci.yml
    - mix.exs
    - RUNNING.md

key-decisions:
  - "Quality gate uses mix coveralls.multiple --type local --type json --slowest 20: --type local runs the same local analyzer / ensure_minimum_coverage as mix coveralls (byte-identical gate), --type json is a non-gating side-artifact (D-01/D-02)."
  - "Integration + adoption lanes drop their standalone mix coveralls.json step entirely (decision 2b / D-04/D-05/D-07) — no artifact consumer exists; integration gate stays plain mix test (not folded)."
  - "mix.exs cli/0 gains coveralls.multiple: :test as additive explicitness (D-08); mix ci / test aliases byte-unchanged."

patterns-established:
  - "Single-run dual-output coverage on the PR gate lane; redundant coverage re-runs removed from non-consuming lanes."

requirements-completed: [COV-01, COV-02, COV-03, COV-04]

coverage:
  - id: D1
    description: "Quality lane runs the suite once and emits both the merge-blocking console gate and cover/excoveralls.json from mix coveralls.multiple --type local --type json --slowest 20 (single execution)."
    requirement: "COV-01"
    verification:
      - kind: automated
        ref: "grep -c 'coveralls.multiple --type local --type json --slowest 20' .github/workflows/ci.yml == 1; python3 yaml.safe_load == OK; tee /tmp/test.out preserved"
        status: pass
    human_judgment: false
  - id: D2
    description: "Gate still runs the local analyzer (ensure_minimum_coverage exercised); pass/fail is never derived from the JSON formatter — enforced by keeping --type local and never reading a JSON exit code."
    requirement: "COV-02"
    verification:
      - kind: automated
        ref: "grep -c 'mix coveralls.json' ci.yml == 0; --type local present in the single gating run; ci.yml invariant comment forbids JSON-derived pass/fail"
        status: pass
    human_judgment: false
  - id: D3
    description: "Redundant standalone coverage step removed from all three lanes (quality Generate coverage JSON artifact, integration + adoption standalone mix coveralls.json); cover/excoveralls.json still produced on quality; all three Upload JUnit + coverage artifacts steps preserved with if-no-files-found: warn."
    requirement: "COV-03"
    verification:
      - kind: automated
        ref: "grep -c 'Generate coverage JSON artifact' ci.yml == 0; grep -cE '^\\s+if-no-files-found: warn' ci.yml == 3"
        status: pass
    human_judgment: false
  - id: D4
    description: "mix.exs cli/0 preferred_envs names coveralls.multiple: :test (CI command inherits MIX_ENV=test); mix ci's final test task byte-unchanged."
    requirement: "COV-04"
    verification:
      - kind: automated
        ref: "grep -c '\"coveralls.multiple\": :test' mix.exs == 1; mix format --check-formatted mix.exs OK; test: alias byte-unchanged"
        status: pass
    human_judgment: false
  - id: D5
    description: "Contributor reproduces the CI coverage step locally with one documented RUNNING.md command; mix coveralls alone still documented as reproducing the gate."
    requirement: "COV-04"
    verification:
      - kind: automated
        ref: "grep -c 'coveralls.multiple --type local --type json --slowest 20' RUNNING.md >= 1; gate-parity note present; lane table header intact (1 occurrence)"
        status: pass
    human_judgment: false

# Metrics
duration: ~6min
completed: 2026-06-28
status: complete
---

# Phase 108 Plan 01: Coverage Single-Run Summary

**Default-suite CI lanes now run ExUnit exactly once per matrix cell — the quality gate emits both the merge-blocking console verdict and cover/excoveralls.json from a single `mix coveralls.multiple --type local --type json --slowest 20` run, and the redundant standalone coverage re-runs were deleted from quality, integration, and adoption.**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-06-28T16:06:43Z
- **Completed:** 2026-06-28
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- Quality lane gating step now runs `mix coveralls.multiple --type local --type json --slowest 20`: one suite execution produces both the merge-blocking gate (`--type local`, identical `ensure_minimum_coverage` semantics to the old `mix coveralls`) and `cover/excoveralls.json` (`--type json`, side-artifact only). The OBS-02 `set -o pipefail` / `tee /tmp/test.out` / `$GITHUB_STEP_SUMMARY` run-timing block is verbatim-preserved.
- Deleted all three redundant standalone coverage steps: `Generate coverage JSON artifact` on quality and integration (`mix coveralls.json`), and on adoption/install-smoke (`MIX_ENV=test mix coveralls.json`). This halves the `:epipe` flake exposure surface on the PR critical path (the milestone v1.21 de-flake foundation).
- Integration gate left as plain `mix test ... --include integration/minio --slowest 20` (NOT folded into coveralls.multiple, D-04). Stale lane comments referencing the deleted steps were repointed; the surviving `Upload JUnit + coverage artifacts` steps (all three) keep `if-no-files-found: warn` so the now-absent coverage JSON on integration/adoption is tolerated (D-06).
- `mix.exs` cli/0 `preferred_envs` gains `"coveralls.multiple": :test` (additive, D-08); `mix ci` / `test` aliases byte-unchanged.
- RUNNING.md documents the exact CI coverage command for local↔CI parity and notes `mix coveralls` still reproduces the gate alone (COV-04).

## Task Commits

Each task was committed atomically:

1. **Task 1: Single-run coverage across all three default-suite lanes in ci.yml** - `d105dd7` (ci)
2. **Task 2: Add coveralls.multiple to mix.exs preferred_envs** - `5a3f3d4` (ci)
3. **Task 3: Document the single-run CI coverage command in RUNNING.md** - `4f9a475` (docs)

## Files Created/Modified
- `.github/workflows/ci.yml` - Quality gate switched to single-run dual-output `coveralls.multiple`; three redundant `Generate coverage JSON artifact` / `mix coveralls.json` steps deleted; stale comments repointed; all three upload steps preserved.
- `mix.exs` - `cli/0` `preferred_envs` gains `"coveralls.multiple": :test`.
- `RUNNING.md` - Coverage table-row Notes updated to reflect the single run; new COV-04 local-reproduction section documenting the command and gate-alone parity.

## Decisions Made
None beyond the plan — followed locked decisions (2b / D-01..D-09) as specified. The exact wording of the ci.yml invariant comment and the RUNNING.md note were authored at Claude's discretion per D-02/D-09.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- De-flake foundation in place: each default-suite lane runs the suite once, halving `:epipe` exposure on the PR critical path. Phase 109 (`:epipe` / broken-pipe hardening) can proceed on this halved surface.
- No `lib/` change — the load-bearing milestone v1.21 invariant (first lib/-touch is reserved for Phase 109's MuonTrap `:epipe` absorb) is preserved by this plan.

## Self-Check: PASSED
- `.github/workflows/ci.yml` — FOUND, contains exactly 1 `coveralls.multiple --type local --type json --slowest 20`, 0 `mix coveralls.json`, 3 `if-no-files-found: warn`; valid YAML.
- `mix.exs` — FOUND, 1 `"coveralls.multiple": :test`, `mix format` clean.
- `RUNNING.md` — FOUND, documents the command + gate-alone parity; table header intact.
- Commits `d105dd7`, `5a3f3d4`, `4f9a475` — all FOUND in git log.
- `git diff --name-only d0d46b9..4f9a475` shows ONLY the three sanctioned files; zero `lib/` change.

---
*Phase: 108-coverage-single-run*
*Completed: 2026-06-28*
