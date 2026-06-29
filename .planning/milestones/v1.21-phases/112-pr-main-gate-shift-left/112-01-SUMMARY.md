---
phase: 112-pr-main-gate-shift-left
plan: 01
subsystem: infra
tags: [ci, github-actions, playwright, e2e, gate, ci-yml, shift-left]

# Dependency graph
requires:
  - phase: 111-regression-locks
    provides: "shipped-artifact regression locks (LOCK-01..05) — de-flake/lock foundation that must land before the PR↔main gate shift-left"
  - phase: 106-trigger-split-matrix-lane-refinement
    provides: "the live adoption-demo-e2e push:main lane + e2e_local.sh pinned-container wrapper this plan clones/threads"
provides:
  - "Lean adoption-demo-e2e-smoke ci.yml job (Chromium-only, MinIO-local, no secrets, pinned Playwright container, no if: gate) — exists and runs on every PR but NOT yet in any needs:"
  - "ADOPTION_DEMO_E2E_SPECS env var threaded through scripts/ci/e2e_local.sh (unset -> full suite, byte-equivalent; set -> only the listed specs)"
  - "scripts/ci/test_e2e_specs_scoping.sh — static unset->full-suite / set->two-specs assertion (no docker/playwright invocation)"
  - "RUNNING.md lean-lane severity row + pre-existing merge-blocking drift correction on adoption-demo-e2e / cohort-demo-smoke"
affects: [112-02, gate-04, ci-summary-needs, branch-protection]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Lean PR-side browser-render proxy: clone the slow push:main demo-e2e lane, scope it to a deterministic spec subset via an env var, run it on every PR with no if: gate (skip==pass safety)"
    - "Job-exists-before-gate-wired split: a new lane must exist and run green on PRs BEFORE it is added to CI Summary.needs (load-bearing GATE-04 ordering, behind an operator checkpoint)"
    - "Back-compatible CI env-var scoping: unset expands to empty so the command stays byte-equivalent to its prior form; static string-assertion test proves both branches without running the container"

key-files:
  created:
    - scripts/ci/test_e2e_specs_scoping.sh
    - .planning/phases/112-pr-main-gate-shift-left/deferred-items.md
  modified:
    - scripts/ci/e2e_local.sh
    - .github/workflows/ci.yml
    - RUNNING.md

key-decisions:
  - "adoption-demo-e2e-smoke has NO if: gate — runs on every PR incl forks; a repo/event-gated lane would resolve to skipped on forks and skip==pass would emit a green lie for the exact regression class this lane catches (T-112-02)"
  - "Cohort-contrast step dropped from the lean clone — redundant with the brandbook-tokens PR gate; not a browser-render check"
  - "ADOPTION_DEMO_E2E_SPECS left UNQUOTED in the playwright command so word-splitting yields one positional arg per spec; quoting would collapse two specs into one bogus path"
  - "Smoke job placed AFTER adoption-demo-e2e (before adopter), NOT before adoption-demo-unit — inserting before adoption-demo-unit would silently widen the package_consumer_full_block isolator in ci_lane_split_test.exs"
  - "Pre-existing actionlint findings (7, in unrelated jobs) left unfixed and logged to deferred-items.md — out of scope; the smoke job introduces ZERO new findings"

patterns-established:
  - "Lean PR browser smoke as the proxy for a slow push:main demo-e2e lane"
  - "Env-var spec scoping with a pure static assertion test (no container)"

requirements-completed: [GATE-01, GATE-02, GATE-03]

coverage:
  - id: D1
    description: "e2e_local.sh honors ADOPTION_DEMO_E2E_SPECS: unset -> full suite (byte-equivalent), set -> only the two listed specs"
    requirement: "GATE-01"
    verification:
      - kind: unit
        ref: "bash scripts/ci/test_e2e_specs_scoping.sh (5/5 assertions, exit 0)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Lean adoption-demo-e2e-smoke ci.yml job exists: no if: gate, ADOPTION_DEMO_E2E_SPECS set to the 2-spec subset, pinned Playwright container, MinIO-local, no secrets, Cohort-contrast dropped, renamed failure artifact; NOT in ci-summary/ci-observability needs"
    requirement: "GATE-01"
    verification:
      - kind: automated
        ref: "actionlint .github/workflows/ci.yml introduces 0 new findings (7 pre-existing, byte-identical before/after); grep: job present, no 'if: github.repository' in block, ADOPTION_DEMO_E2E_SPECS env set, not in any needs:"
        status: pass
    human_judgment: false
  - id: D3
    description: "Lean lane runs as a parallel chain off [quality, optional-dependencies] with a minimal step list (Cohort-contrast dropped) to keep it lean (GATE-02)"
    requirement: "GATE-02"
    verification:
      - kind: automated
        ref: "grep: needs: [quality, optional-dependencies] on the smoke job; step list excludes 'Cohort contrast + literal gate'"
        status: pass
    human_judgment: false
  - id: D4
    description: "RUNNING.md documents the lean-lane merge-blocking-PR row, fixes the pre-existing merge-blocking drift on adoption-demo-e2e / cohort-demo-smoke (-> off-critical-path push:main-only), and documents the 3 off-PR lane rationales; eval_ci_summary.sh + setup_branch_protection.sh byte-unchanged (GATE-03)"
    requirement: "GATE-03"
    verification:
      - kind: automated
        ref: "grep: adoption-demo-e2e-smoke present; no '| `adoption-demo-e2e` | merge-blocking' and no '| `cohort-demo-smoke` | merge-blocking'; git diff --exit-code on the two frozen scripts returns 0"
        status: pass
    human_judgment: false

# Metrics
duration: 4min
completed: 2026-06-28
status: complete
---

# Phase 112 Plan 01: PR↔main gate shift-left (job half) Summary

**Lean `adoption-demo-e2e-smoke` Chromium PR job (MinIO-local, no secrets, pinned Playwright container, no `if:` gate, deterministic 2-spec subset) stood up and wired into `e2e_local.sh` via a back-compatible `ADOPTION_DEMO_E2E_SPECS` env var — without yet adding it to the merge gate.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-06-28T21:58:37Z
- **Completed:** 2026-06-28T22:03Z (approx)
- **Tasks:** 3
- **Files modified:** 3 (+ 2 created: the assertion test and deferred-items.md)

## Accomplishments
- Threaded `ADOPTION_DEMO_E2E_SPECS` through the active container wrapper `scripts/ci/e2e_local.sh`: passed into the container via `-e` and appended (unquoted) to the `npx playwright test` command. Unset -> empty -> byte-equivalent to the prior full-suite invocation; set -> only the listed specs run as positional arguments.
- Added `scripts/ci/test_e2e_specs_scoping.sh`: a pure static assertion (no docker/playwright) proving (1) the var is referenced in both the `-e` pass-through and the playwright command, (2) unset resolves to the exact full-suite command with no positional spec, and (3) the two-spec string resolves to exactly those two positional specs. 5/5 assertions pass.
- Added the lean `adoption-demo-e2e-smoke` ci.yml job immediately after `adoption-demo-e2e` (before `adopter`): cloned env/services/composite-step path, **no `if:` gate** (runs on every PR incl forks), `ADOPTION_DEMO_E2E_SPECS` scoped to `e2e/smoke.spec.js e2e/admin-console.spec.js`, Cohort-contrast step dropped, failure artifact renamed to `adoption-demo-e2e-smoke-report`. Reuses existing SHA pins; introduces no new/unpinned `uses:`. NOT in `ci-summary.needs` / `ci-observability.needs`.
- Updated RUNNING.md: added the lean-lane merge-blocking-PR row, corrected the pre-existing stale "merge-blocking" label on `adoption-demo-e2e` and `cohort-demo-smoke` (now off-critical-path push:main-only with rationale), and extended the needs-narrative to note the lane is wired in Plan 02 behind the operator checkpoint (with GATE-A9 alerting noted as deferred).

## Task Commits

Each task was committed atomically:

1. **Task 1: Thread ADOPTION_DEMO_E2E_SPECS through e2e_local.sh + add its assertion** - `046a579` (feat)
2. **Task 2: Add the lean adoption-demo-e2e-smoke job to ci.yml (not yet in any needs:)** - `0cb6b93` (feat)
3. **Task 3: Update RUNNING.md CI-lane-severity table (lean row + drift fix + off-PR rationale)** - `b33e2f6` (docs)

_Plan metadata commit follows this SUMMARY._

## Files Created/Modified
- `scripts/ci/e2e_local.sh` - `-e ADOPTION_DEMO_E2E_SPECS` pass-through + unquoted positional spec append to the playwright command (back-compatible scoping)
- `scripts/ci/test_e2e_specs_scoping.sh` (created) - static unset->full-suite / set->two-specs assertion
- `.github/workflows/ci.yml` - new `adoption-demo-e2e-smoke` job (no `if:`, SPECS env, pinned container, MinIO-local, no secrets, Cohort-contrast dropped, renamed failure artifact); NOT in any `needs:`
- `RUNNING.md` - lean-lane row + merge-blocking drift correction + off-PR rationales + needs-narrative update
- `.planning/phases/112-pr-main-gate-shift-left/deferred-items.md` (created) - logs the 7 pre-existing actionlint findings (out of scope)

## Decisions Made
- **No `if:` gate on the smoke lane** — runs on every PR including forks; a gated lane would `skipped`-as-pass on forks (T-112-02). Uses no secrets, so fork exposure is nil (T-112-01).
- **Cohort-contrast step dropped** from the lean clone — redundant with the `brandbook-tokens` PR gate; not a browser-render check.
- **`ADOPTION_DEMO_E2E_SPECS` left unquoted** in the playwright command so word-splitting yields one positional arg per spec.
- **Job placement after `adoption-demo-e2e`** (not before `adoption-demo-unit`) to avoid widening the `package_consumer_full_block/1` isolator in `ci_lane_split_test.exs`.

## Deviations from Plan

None — plan executed exactly as written. No Rule 1-4 deviations were required.

The only out-of-scope discovery (7 pre-existing `actionlint` findings in unrelated `ci.yml` jobs) was correctly NOT fixed per the SCOPE BOUNDARY rule and logged to `deferred-items.md`. The smoke job introduces zero new findings — verified by running actionlint against both the pre-Task-2 base and the final `ci.yml` (identical 7 findings, identical exit 1, none in the 998-1107 smoke-job line range).

## Issues Encountered
- **Test extraction picked up a comment line.** The first `test_e2e_specs_scoping.sh` draft used `grep 'npx playwright test' | head -n1`, which matched the explanatory comment block I added to `e2e_local.sh` (which spells out the command in prose) instead of the real `sh -c "..."` line. Resolved by anchoring the extraction on `^\s*sh -c ".*npx playwright test`. This is normal test-authoring iteration, not a plan deviation — the wrapper change itself was correct on the first edit.

## Next Phase Readiness
- Plan 02 (GATE-04) wires `adoption-demo-e2e-smoke` into `ci-summary.needs` + `ci-observability.needs` and adds the GATE meta-test in `ci_lane_split_test.exs`, behind the operator green-run checkpoint (N=3 consecutive green push:main `adoption-demo-e2e` runs).
- The lane exists and is structured correctly but is NOT yet observable as green-on-PR (CI must actually run it once on a PR). The operator checkpoint in Plan 02 is the gate that confirms non-flakiness before wiring it into the required gate.
- `name: CI`, the `ci.yml` filename, `eval_ci_summary.sh`, and `setup_branch_protection.sh` are byte-unchanged. Zero `lib/` change.

## Self-Check: PASSED

- Files: all 5 created/modified files confirmed present on disk.
- Commits: `046a579`, `0cb6b93`, `b33e2f6` all confirmed in git log.

---
*Phase: 112-pr-main-gate-shift-left*
*Completed: 2026-06-28*
