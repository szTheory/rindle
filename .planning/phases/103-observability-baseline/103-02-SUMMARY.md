---
phase: 103-observability-baseline
plan: 02
subsystem: ci-tooling
tags: [ci, observability, baseline, gh-api, branch-protection, shell]
requires:
  - scripts/setup_branch_protection.sh (--print-expected-json — expected required-check list)
  - GitHub Actions API (workflows/ci.yml/runs + runs/{id}/jobs)
  - GitHub branch-protection API (.../required_status_checks)
provides:
  - scripts/ci/collect_ci_baseline.sh (OBS-03 historical avg/p95/rerun collector)
  - scripts/ci/check_required_checks.sh (OBS-03 live-vs-expected required-check diff)
affects:
  - Plan 04 (runs both scripts to author 103-BASELINE.md)
  - Phase 105 (aggregate-check flip depends on the captured live required-check list)
  - Phase 107 (regression-vs-baseline check references the committed baseline)
tech-stack:
  added: []
  patterns:
    - "scripts/ci/ house style: shebang + WHY block + set -euo pipefail + repo_root resolution + command -v guards"
    - "rerun rate derived from run_attempt/previous_attempt_url (no rerun_count field)"
    - "live required-check read prefers legacy .contexts[] over .checks[].context"
    - "expected list reused via setup_branch_protection.sh --print-expected-json (single source of truth)"
key-files:
  created:
    - scripts/ci/collect_ci_baseline.sh
    - scripts/ci/check_required_checks.sh
  modified: []
decisions:
  - "Reworded the check script's WHY comment to avoid the literal string 'gh api -X PUT' — the plan's acceptance gate greps the WHOLE file (comments included) for mutation verbs, so even documentation prose tripped it. Meaning preserved ('any write request to /protection')."
  - "Printed live contexts with a bash while-read loop instead of `sed 's/^/  - /'` to satisfy the shellcheck SC2001 hook (the plan requires passing shellcheck); behavior identical."
metrics:
  duration: 4 min
  completed: 2026-06-20
status: complete
---

# Phase 103 Plan 02: OBS-03 Baseline Collector Scripts Summary

Two read-only maintainer-local `gh api` collector scripts under `scripts/ci/` that capture the v1.20 [BASELINE FIRST] reference before any pipeline restructuring: a per-job avg/p95/rerun timing baseline over recent `ci.yml` runs, and a live-vs-expected branch-protection required-check diff that surfaces the known `brandbook-tokens` drift.

## What Was Built

- **`scripts/ci/collect_ci_baseline.sh`** (Task 1) — pulls the last N (`BASELINE_RUNS`, default 50) `ci.yml` runs on a branch (`BASELINE_BRANCH`, default `main`) via `gh api .../actions/workflows/ci.yml/runs`, derives the rerun rate from `run_attempt`/`previous_attempt_url` (no nonexistent `rerun_count` field; RESEARCH Pitfall 2), then per run pulls `.../actions/runs/{id}/jobs` and reduces `started_at`/`completed_at` to a per-job `avg(s)` + `p95(s)` Markdown table via the awk block. Read-only, executable, `BASELINE_*` parameterized.

- **`scripts/ci/check_required_checks.sh`** (Task 2) — reads the live `.../branches/{branch}/protection/required_status_checks` `.contexts[]` (legacy flat shape, RESEARCH Pitfall 3), obtains the expected list by invoking `setup_branch_protection.sh --print-expected-json` (reuse, not re-encode; D-09), prints the live list, and `diff`s expected-vs-live (tolerating the expected nonzero exit since `brandbook-tokens` drift is real today). Read-only — no `/protection` mutation (D-14, threat T-103-03).

Both open with the `scripts/ci/` house style (shebang, multi-line WHY block, `set -euo pipefail`, `repo_root` resolution, `command -v gh`/`command -v jq` fail-loud guards), are `chmod +x`, pass `bash -n`, and pass `shellcheck` clean.

## Verification

| Gate | collect_ci_baseline.sh | check_required_checks.sh |
|------|------------------------|--------------------------|
| `bash -n` | PASS | PASS |
| house-style `set -euo pipefail` (non-comment) | PASS | PASS |
| required endpoints present | `actions/workflows/ci.yml/runs`, `run_attempt` | `required_status_checks`, `print-expected-json`, `contexts` |
| no mutation verb (`gh api -X PUT/POST/PATCH/DELETE`) | PASS | PASS |
| executable | PASS | PASS |
| shellcheck | CLEAN | CLEAN |

Full acceptance gates from both tasks' `<verify><automated>` blocks ran green. LIVE runs (a real `gh` session emitting the avg/p95 table and the live `.contexts[]` diff) are routed to Plan 04 per the plan — statically, all `gh api` shapes are present and lint-clean here.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Acceptance gate tripped on a literal mutation verb inside a comment**
- **Found during:** Task 2 verification
- **Issue:** The plan's acceptance grep `! grep -qE 'gh api -X (PUT|POST|PATCH|DELETE)'` scans the entire file. My WHY comment documented the prohibition with the literal phrase ``a `gh api -X PUT` to `/protection` ``, which matched the pattern and failed the read-only assertion.
- **Fix:** Reworded the comment to "any write request to `/protection`" — same meaning, no literal mutation verb. The script issues zero mutating calls.
- **Files modified:** scripts/ci/check_required_checks.sh
- **Commit:** 41cfa3a

**2. [Rule 2 - Critical] shellcheck SC2001 on `sed 's/^/  - /'`**
- **Found during:** Task 2 verification (plan constraint: "ensure they pass any shellcheck hook")
- **Issue:** Printing the live contexts via `echo "${live}" | sed 's/^/  - /'` raised shellcheck SC2001, which would fail the shellcheck hook.
- **Fix:** Replaced with a `while IFS= read -r ctx; do printf '  - %s\n' "${ctx}"; done <<<"${live}"` loop. Output is byte-identical.
- **Files modified:** scripts/ci/check_required_checks.sh
- **Commit:** 41cfa3a

Both adjustments were applied inline before the Task 2 commit; the committed file reflects the fixed form.

## Threat Surface

No new threat surface beyond the plan's `<threat_model>`. T-103-03 (accidental branch-protection mutation) is mitigated: both scripts are GET-only and the acceptance grep asserting no `gh api -X PUT/POST/PATCH/DELETE` passes. T-103-05 (new CI surface) is mitigated: these are committed maintainer-LOCAL scripts, not CI jobs — zero new required checks. No `lib/` source changed.

## Known Stubs

None — both scripts are complete and runnable; their LIVE output is intentionally consumed by Plan 04 (this plan delivers the lint-clean, read-only tooling, not the captured baseline document).

## Self-Check: PASSED

- FOUND: scripts/ci/collect_ci_baseline.sh (executable)
- FOUND: scripts/ci/check_required_checks.sh (executable)
- FOUND: commit c9ad492 (Task 1)
- FOUND: commit 41cfa3a (Task 2)
