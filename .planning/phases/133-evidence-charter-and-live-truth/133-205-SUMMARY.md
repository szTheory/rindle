---
phase: 133-evidence-charter-and-live-truth
plan: "205"
status: complete
subsystem: tooling
tags: [reconciliation, roadmap-parity, historical-snapshot, lock-05, gap-closure]
requires:
  - phase: 133-201
    provides: Committed focused reconciliation suite baseline
provides:
  - Phase133Plan160RoadmapParityTest rebuilt on a disposable historical snapshot (historical_snapshot!/0)
  - Committed (git show HEAD:) immutable-history dependency check for Plans 159/160/164-168
  - Fully green focused supported-toolchain ExUnit file (first time since Plan 202 recorded the parity failure)
affects: [133-203, 133-204, 133-206, 133-209]
requirements-completed: []
requirements_completed: []
requirements_pending: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
unresolved_edge_rows: 11
qualification_credit: 0
baseline_test_count: 127
baseline_failures: 1
final_test_count: 128
final_failures: 0
tasks_completed: 2
tasks_total: 2
plan_head_before: 2868eea3e1470a67780f505a9857afcd99e49dcd
actuals:
  tokens: 3800
  tasks: 2
  commits: 2
tech-stack:
  added: []
  patterns: [disposable tmp-dir planning snapshot, git show HEAD immutable-history read]
key-files:
  created: [.planning/phases/133-evidence-charter-and-live-truth/133-205-SUMMARY.md]
  modified: [test/install_smoke/phase_133_reconciliation_test.exs]
decisions:
  - "Plan 160 route parity is validated against an in-test historical snapshot; the live orchestrator-owned ROADMAP.md is no longer read by this test."
  - "133-169 is excluded from the committed immutable-history check because its active dependency route belongs to the Plan 204 retirement."
metrics:
  completed: 2026-10-13
---

# Phase 133 Plan 205: Historical Plan 160 Roadmap Snapshot Summary

The Plan 160 roadmap-parity test now validates the finished 159–169 recovery route against a disposable snapshot it builds itself under System.tmp_dir!/0, instead of the live ROADMAP.md. All six rejection mutations still reject, and a new test reads the committed dependency history with `git show HEAD:`. With those changes the focused reconciliation file passes in full: 128 tests, 0 failures.

## What changed

- `historical_snapshot!/0` (private, `on_exit` cleanup) writes three things: a literal historical ROADMAP excerpt with a `**Plans**` line and Recovery DAG Wave headings 18, 19, 20, 21, 22, 22, 23 and 26, each followed by one row for its route plan; stub PLAN.md files for the route plans with waves and `depends_on` taken from `@dependencies`; and completed stubs (PLAN plus `status: complete` SUMMARY) for 133-155/156/157/170. `validate_route`/`parse_route`/`plan_records!`/`effective_wave` are unchanged.
- The test was renamed to "historical Plan 160 recovery snapshot matches its dependency DAG and rejects stale or reordered rows". It asserts `{:ok, route}` with route ids equal to `@route` and effective waves `[18, 19, 20, 21, 22, 22, 23, 26]`.
- Rejections kept: renaming 168 to 158, removing the row, duplicating the row, relabeling Wave 20 as 22, and replacing the id with 133-121. Added: a second snapshot whose 168 stub has `depends_on: ["133-166"]`, which returns `{:error, _}`.
- New test "committed Plan 160 route history declares exactly the historical dependency map". It runs `git show HEAD:` on Plans 159, 160, 164, 165, 166, 167 and 168, flunks on a non-zero exit, parses the result with the existing `dependency_value/1`, and asserts it equals `@dependencies`.
- Both tests are tagged `:plan205_roadmap_snapshot`, and the module keeps `@moduletag :plan127_transaction`.

## Verification

- Baseline at plan start (HEAD 2868eea3, `--seed 0`, full focused file): **127 tests, 1 failure**, the expected Plan 160 parity match failure.
- RED (tag added, `--only plan205_roadmap_snapshot`): 1 failure, `validate_route(roadmap, @repo_root)` returned `{:error, "active recovery roadmap differs..."}`.
- Task 1 verify (`--only plan205_roadmap_snapshot`): 2 tagged tests (snapshot plus immutable history), 0 failures, 126 excluded by the filter.
- Task 2 verify chain, exit 0:
  - `mix test test/install_smoke/phase_133_reconciliation_test.exs --seed 0`: **128 tests, 0 failures**, no skips (127 + 1 new test). The Plan 202 writer-boundary diagnostic test still passes unchanged.
  - `mix format --check-formatted` on the test file passes.
  - `mix test test/planning_path_hygiene_test.exs --seed 0` (inherited working-tree guard, read only): 2 tests, 0 failures.
  - `./scripts/maintainer/automation_first_contract.sh` passes.
- Greps on the module: `Path.join(@repo_root, ".planning/ROADMAP.md")` appears 0 times, and no line pairs a File.read!/File.exists?/Path.expand with the planning directory without fixture.root.
- Inherited dirt: the `git diff` sha256 for all 10 inherited modified paths, plus the sha256 of the untracked milestone.lock, match the values captured at plan start. None of these paths were staged.
- `git diff --name-only 2868eea3..HEAD` also lists 133-203-PLAN.md, 133-204-PLAN.md and 133-208-SUMMARY.md. Those come from the concurrent Plan 208 commits (c4d77101, dc74d148, fb48d266), not from this plan. Plan 205's own commits touch only the test file and this SUMMARY.

## Deviations from Plan

- Task 1's acceptance text expected "1 test" for the targeted run. Task 2 added the immutable-history test under the same tag, so the final targeted run reports 2 tests, 0 failures. This is the shape the plan intends.
- Both tasks went into one test-file commit (the plan says to commit only the test file, then the SUMMARY).
- No STATE/ROADMAP/REQUIREMENTS updates, per the orchestrator constraint (Plan 209 owns those inherited files).

## Edge rows

All 11 rows stay unresolved, and this test repair adjudicates none of them. All five requirement IDs stay Pending, and qualification credit is 0.

## Commits

- c2f3b8b4 test(133-205): validate Plan 160 route against a historical snapshot
- (this SUMMARY) docs(133-205): complete historical Plan 160 snapshot plan

## Self-Check: PASSED

- FOUND: test/install_smoke/phase_133_reconciliation_test.exs (commit c2f3b8b4 is an ancestor of HEAD)
- FOUND: .planning/phases/133-evidence-charter-and-live-truth/133-205-SUMMARY.md
