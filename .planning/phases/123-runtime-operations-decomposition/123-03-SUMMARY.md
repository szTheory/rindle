---
phase: 123-runtime-operations-decomposition
plan: "03"
subsystem: runtime status operations
tags: [elixir, runtime-status, operations, formatter]
requires:
  - phase: 123-02
    provides: migration preflight decomposition and SAFE-01 proof
provides:
  - RuntimeStatus façade-owned filter/readiness/refusal/telemetry boundary
  - Internal bounded status collector and command formatter seams
affects: [runtime status, operator CLI, SAFE-01]
tech-stack:
  added: []
  patterns: [readiness-gated collector, façade-owned telemetry, pure formatter]
key-files:
  created:
    - lib/rindle/ops/runtime_status/collector.ex
    - lib/mix/tasks/rindle/runtime_status/formatter.ex
  modified:
    - lib/rindle/ops/runtime_status.ex
    - lib/mix/tasks/rindle.runtime_status.ex
    - test/rindle/ops/runtime_status_test.exs
    - test/rindle/runtime_status_task_test.exs
decisions:
  - RuntimeStatus.runtime_status/1 remains the only filter validation, readiness, report composition, recommendation, and refusal-telemetry boundary.
  - The Mix task retains parsing, one façade call, output channel, and exit behavior while Formatter owns bounded rendering.
metrics:
  completed: 2026-08-23
  tasks_completed: 2
  files_changed: 11
status: complete
---

# Phase 123 Plan 03: Runtime Operations Decomposition Summary

Runtime status now delegates bounded database collection and command presentation to internal collaborators while the public façade and CLI transport retain their safety and compatibility boundaries.

## Tasks Completed

1. **Gate readiness once and delegate bounded status collection** — `a510440` (`chore(123-03)`)
   - Added `RuntimeStatus.Collector.collect/4` for bounded report queries, row classification, samples, counts, and redaction.
   - Kept filter normalization, readiness-before-query refusal, report/recommendation composition, and refusal telemetry in `RuntimeStatus.runtime_status/1`.
   - Added a RED-then-GREEN collector seam test.

2. **Delegate presentation and preserve command transport** — `dca15c5` (`chore(123-03)`) and `d419c08` follow-up formatting commit
   - Added the internal formatter and routed task success/error output through it.
   - Preserved the task’s direct-tested helpers and existing shell/exit transport.
   - Added a RED-then-GREEN formatter parity test and formatted the extracted collaborators.
   - Removed the temporary duplicated collector implementation from the façade in `575cc7c`; the façade now contains only its retained orchestration, readiness, recommendation, and telemetry responsibilities.
   - Marked the internal collaborator entry points explicitly non-public for the strict Doctor contract in `e0f40bc`.
   - Restored the exact pre-extraction text/error/JSON/provider presentation in `9bc6913`, made all task compatibility helpers pure delegates, and added populated sample/recommendation parity proof.

## Verification

- `MIX_ENV=test mix compile --force --warnings-as-errors` — PASS (139 files).
- Complete focused aggregate — PASS (121 tests, 19 excluded): runtime checks, migration, runtime status, task, and telemetry contract suites.
- `bash scripts/maintainer/refactor_contract.sh` — PASS (87 tests).
- `mix ci` — PASS (3 doctests and 1,364 tests, 0 failures, 4 skipped, 85 excluded; Doctor 100% docs/specs).
- `./scripts/maintainer/repo_hygiene_check.sh` — PASS (11 PASS, 0 WARN, 0 BLOCK).
- Forbidden-surface audit (`git diff --quiet main...HEAD -- .github/workflows mix.exs mix.lock priv/repo/migrations lib/rindle/admin .planning/milestones`) — PASS.
- Supported exact-SHA PR CI remains external/root-owned and was not invoked here.

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 3 - Blocking issue] Scoped formatting correction**
   - **Found during:** final `mix ci` gate.
   - **Issue:** plan-owned files needed formatting before the merge-equivalent formatter check could advance.
   - **Fix:** formatted only plan-owned files in `d419c08`.
   - **Files modified:** runtime status façade, collector, task, formatter, migration snapshot/preflight, and runtime-check ownership collaborator.

2. **[Rule 1 - Bug] Removed a duplicated collector implementation**
   - **Found during:** final Credo quality gate.
   - **Issue:** the first extraction retained more than 400 lines of dead private collection code behind an artificial function-reference list, defeating the decomposition and adding a second complexity finding.
   - **Fix:** deleted the dead copy and moved the reviewed Credo identities to the actual owning collaborators.
   - **Files modified:** `lib/rindle/ops/runtime_status.ex`, `scripts/maintainer/credo_complexity_baseline.json`.

3. **[Rule 3 - Blocking issue] Declared internal collaborator seams non-public**
   - **Found during:** final Doctor gate.
   - **Issue:** three new internal collaborator modules exposed callable seams without `@doc false`, reducing strict documentation coverage.
   - **Fix:** marked every internal entry point `@doc false`; Doctor returned to 100% docs/specs.

4. **[Rule 1 - Bug] Restored command formatter parity**
   - **Found during:** independent code review.
   - **Issue:** the first formatter implementation omitted generated/filter fields, finding samples, and recommendation summaries from actual CLI output.
   - **Fix:** moved the retained task formatter into the internal formatter unchanged, reduced task helpers to delegates, and added behavior-backed populated-report parity coverage.

## Known Stubs

None.

## Self-Check: PASSED

- Created collector and formatter files exist.
- Task and repair commits `a510440`, `dca15c5`, `d419c08`, `575cc7c`, `e0f40bc`, and `9bc6913` exist in git history.
