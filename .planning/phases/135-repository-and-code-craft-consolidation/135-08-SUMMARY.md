---
phase: 135-repository-and-code-craft-consolidation
plan: 08
subsystem: examples-docs-residue
tags: [craft, residue, comments, docs, examples]
status: complete
requires: ["135-01", "135-04"]
provides:
  - "examples/adoption_demo, test/adopter, test/brandbook, guides and root docs free of flagged planning-era ids; examples_docs shard has zero pending-removal entries"
affects: [scripts/maintainer/live_residue_allowlist/examples_docs.json]
tech-stack:
  added: []
  patterns: ["comment/prose-only residue tranche; shard shrinks in the same commit as the edit"]
key-files:
  created: []
  modified:
    - examples/adoption_demo/test/adoption_demo_web/live/cohort_migration_contract_test.exs
    - examples/adoption_demo/test/adoption_demo_web/admin_lifecycle_display_test.exs
    - examples/adoption_demo/test/adoption_demo_web/admin_mount_test.exs
    - examples/adoption_demo/test/adoption_demo_web/brand_test.exs
    - examples/adoption_demo/test/readme_walkthrough_test.exs
    - examples/adoption_demo/e2e/admin-console.spec.js
    - examples/adoption_demo/e2e/admin-destructive-ux.spec.js
    - examples/adoption_demo/e2e/admin-screenshots.spec.js
    - examples/adoption_demo/e2e/cohort-pages.spec.js
    - examples/adoption_demo/e2e/cohort-styleguide.spec.js
    - examples/adoption_demo/e2e/post-image.spec.js
    - examples/adoption_demo/e2e/support/admin-polish.js
    - examples/adoption_demo/lib/adoption_demo_web/components/cohort_components.ex
    - examples/adoption_demo/lib/adoption_demo_web/live/styleguide_live.ex
    - examples/adoption_demo/priv/static/assets/cohort.css
    - examples/adoption_demo/priv/static/assets/js/app.js
    - examples/adoption_demo/README.md
    - test/adopter/canonical_app/lifecycle_test.exs
    - test/adopter/canonical_app/profile.ex
    - test/brandbook/admin_design_system_validation_test.exs
    - RUNNING.md
    - CONTRIBUTING.md
    - brandbook/README.md
    - guides/admin_console.md
    - guides/admin_console_architecture.md
    - guides/rindle_admin_css.md
    - scripts/maintainer/live_residue_allowlist/examples_docs.json
decisions:
  - "cohort.css and priv/static/assets/js/app.js are hand-authored (no generator; ci.yml documents cohort.css as hand-authored), so their comments were edited directly"
  - "The two 'Phoenix v1.8' lines in the phx.new-generated examples/adoption_demo/AGENTS.md name the framework version, not a milestone; reclassified policy with a reason instead of rewritten"
  - "SAFE-01 / ADMIN-06 / PIPE-01 in RUNNING/CONTRIBUTING/guides prose were rewritten to what the gate does; the CI step and check-run names that carry those ids are untouched (contract, D-135-05)"
metrics:
  duration: "about 55 min"
  completed: 2026-10-19
estimate:
  tokens: 95000
actuals:
  tokens: 18400
  tasks: 3
  commits: 3
plan_head_before: d8bf703db1b5ffcf683f17ca242fef12ee26921f
plan_head_after: 7aede7c0
---

# Phase 135 Plan 08: examples and docs residue tranche (D2) Summary

Comment, test-name and prose rewrite of the 148 pending-removal residue sites in the example app, its Playwright specs and cohort CSS, the adopter and brandbook tests, the admin guides and the root docs. The examples_docs shard went from 148 pending-removal entries to 0 (155 -> 9 entries: 7 pre-existing AGENTS.md policy entries plus the 2 reclassified demo AGENTS.md lines).

## Tasks

| Task | Name | Commit | Shard entries removed |
|------|------|--------|-----------------------|
| 1 (tracer) | cohort_migration_contract_test.exs | 857e37ae | 14 |
| 2 | remaining examples, test/adopter, test/brandbook | e436c192 | 119 (+2 reclassified policy) |
| 3 | guides and root docs | 7aede7c0 | 13 |

14 + 119 + 2 + 13 = 148. `--regen-baseline` was run after each task; each time only `examples_docs.json` changed (no other shard, `install_smoke.json` untouched because no `test/install_smoke/` file was edited).

Tracer gate: after Task 1, the scanner `--check` and the tracer test file (25 tests, 0 failures) both passed before expanding.

## Verification

- `scan_live_residue.exs --check --require-no-pending examples_docs`: ok (618 files, 1103 hits, 1069 allowlist entries)
- examples_docs pending-removal count (jq): 0
- Adoption-demo ExUnit (separate deps/build paths `$S/deps-demo`, `$S/build-demo-08`, fresh DB `adoption_demo_test_p135_08`): **44 tests, 0 failures** before and after (pre-plan count 44)
- `node --check` on all 8 edited JS files: ok
- `mix test test/brandbook test/adopter --include integration`: 33 tests, 0 failures, 8 excluded (the `:minio`-tagged adopter lifecycle tests; MinIO not running locally, so those were compiled but not executed)
- `mix test` on test/install_smoke/docs_parity, live_residue_scan_test, ci_lane_split_test, release_docs_parity_test, live_truth_parity_test, evidence_census_test: 173 tests, 0 failures, 1 excluded
- `mix format --check-formatted` (root): clean
- `check_docs_links.sh`: OK. `automation_first_contract.sh`: passed. `! grep -rn ".planning/phases/135" scripts test .github lib`: clean
- `MIX_ENV=dev mix docs`: exits 0
- CSS comment-only filter: prints 3 lines, all continuation lines inside `/* ... */` block comments (the filter only exempts lines starting with `/*` or `*`). No selector or declaration changed.

Not run locally: the main-only `adoption-demo-e2e` Playwright lane (post-merge main push run is the gate per the plan).

## Deviations from Plan

**1. [Rule 2 - accuracy] Unflagged planning-era text in the same comments rewritten.** Beyond the scanner worklist: `Wave-0` banner and test name, `RESEARCH Runtime State Inventory`, `Pitfall 2/6`, `HIGHEST-RISK swap in the phase` (cohort migration test); the `phase-98 computed-style backstops` Playwright test name (now `admin computed-style backstops ...`); `Discharges UAT checkpoint` line in admin_mount_test; `DOC-01`, `§E/§F`, `98-01 §B`, `R4/R5` in adopter/brandbook comments and names; `b1.0`, `phases 81-85`, `D-b1.0-04/05` in brandbook/README provenance. None were shard entries, so no shard impact.

**2. [Scope] Assertion-message strings.** Two failure-message strings carried decision ids (`D-98-12` in the brandbook display:grid assertion, `D-14` in the adopter :kind assertion) and were rewritten; the assertions themselves are unchanged. `@v13_thumb_digest` was renamed `@image_only_thumb_digest` (module attribute, same value). One cohort test string (`T-99-01-02` in a raw/1 refute message, not flagged) was left as is.

**3. [Environment] Local test-run issues, none caused by this plan:**
- The shared `adoption_demo_test` DB had stale public tables (rindle_migration_contract_test failed on it at baseline); a fresh `ADOPTION_DEMO_TEST_DB` fixed it.
- Postgres hit `too_many_connections` from concurrent agents; runs were retried until a slot was free.
- Running `mix docs` (dev) into the same `MIX_BUILD_PATH` as test broke LazyHTML protocol consolidation; test and dev now use separate build paths.
- The DS-02 gallery check needs Playwright from `examples/adoption_demo/node_modules`, which this worktree lacks; `NODE_PATH` was pointed at the main checkout's node_modules. One run failed on a theme-color read under load; the same script passed on an origin/main archive and on rerun in the worktree, and the suite then passed.
- `live_truth_parity_test` package-authority tests fail while the tree is dirty; they pass on the committed tree.

**4. Pre-existing format drift in the demo (out of scope).** `mix format --check-formatted` inside examples/adoption_demo flags code lines (not touched here) in `cohort_migration_contract_test.exs` and `styleguide_live.ex`. CI does not run the demo formatter; left alone.

## Notes for the orchestrator

- The branch is built on d8bf703d. origin/main has since moved to c23f287e (135-03); it touches only `automation_workflows.json` among the files this plan's area scans, so a rebase should be clean.
- PR subject from the plan: `test: replace planning-era identifiers in examples, adopter tests and docs`

## Known Stubs

None.

## Self-Check: PASSED

- Commits 857e37ae, e436c192 and 7aede7c0 are on `docs/135-08-examples-docs-residue`.
- examples_docs.json has 0 pending-removal entries.
