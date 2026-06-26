---
phase: 103-observability-baseline
verified: 2026-06-20T23:40:00Z
status: passed
score: 19/19 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification: # none — initial verification
---

# Phase 103: Observability / Baseline Verification Report

**Phase Goal:** Make the existing pipeline self-reporting and capture a committed baseline so every later restructuring decision is evidence-backed — with ZERO gate-behavior change and ZERO topology change.
**Verified:** 2026-06-20T23:40:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

This phase is observability/tooling only — its goal is satisfied by (a) the pipeline becoming self-reporting and (b) a real committed baseline, while honoring four hard cross-cutting constraints (no rename, no gate change, no topology change, no shipped-package change). All four ROADMAP success criteria, all plan-level must-have truths, and every cross-cutting constraint were verified against the actual files and git history (not SUMMARY claims). The most behavior-sensitive risk — piping the gating `mix coveralls` through `tee` masking its exit code — was specifically checked and found correctly guarded by `set -o pipefail`.

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC1 | Baseline table (avg/p95/rerun) AND verbatim live required-check names captured & committed before any restructuring (OBS-03) | ✓ VERIFIED | `103-BASELINE.md` §1 (16-job avg/p95 + 8/50 rerun), §2 (12 verbatim live contexts), §3 (diff). Committed 2488a04; no restructuring commits exist. |
| SC2 | PR run summary shows per-job + per-step timing + cache hit/miss, with no change to which checks pass/fail (OBS-01) | ✓ VERIFIED | `ci-observability` job: per-job duration table + `\| Job \| Step \| Duration (s) \|` per-step table for 3 long-poles from one `actions/runs/${RUN_ID}/jobs` call; cache hit/miss tables in quality/integration/package-consumer. Gate set unchanged (see constraints). |
| SC3 | Summary surfaces `--slowest 20`, compile time profile, `schedulers_online()`, ExUnit seed; JUnit + coverage artifacts uploaded (OBS-02) | ✓ VERIFIED | ci.yml: `slowest 20` (5×), `compile --profile time` (4×), `schedulers_online` (6×), seed grep `Randomized with seed`, `upload-artifact@v4` (5×) shipping `_build/test/junit/rindle-junit.xml` + `cover/excoveralls.json`. Behavioral check: `CI=1 mix test` produced real JUnit XML. |
| SC4 | Gate behavior provably unchanged: same checks required, same PRs pass/fail | ✓ VERIFIED | Workflow `permissions` stays `{contents: read}`; `ci-observability` not in required checks (advisory, `if: always()`); gating step still `mix coveralls` (now `mix coveralls --slowest 20 \| tee` under `set -o pipefail` — failures still propagate); no `path:/key:/restore-keys:` altered; `name: CI` + filename byte-unchanged. |

### Plan-level Must-Have Truths

| Truth | Plan | Status | Evidence |
|-------|------|--------|----------|
| `CI=1 mix test` writes JUnit XML the upload step ships | 01 | ✓ VERIFIED | Behavioral: ran `CI=1 mix test test/rindle/api_surface_boundary_test.exs` → exit 0, real `_build/test/junit/rindle-junit.xml` with testsuite/testcase data. |
| `mix coveralls.json` writes `cover/excoveralls.json` | 01 | ✓ VERIFIED | test_helper wiring + ci.yml `mix coveralls.json` sibling steps; `git check-ignore` lists path. |
| junit_formatter is test-only, never ships | 01 | ✓ VERIFIED | mix.exs:127 `only: :test`; `files:` allowlist = `lib priv/repo/migrations priv/static/rindle_admin mix.exs README RUNNING CHANGELOG LICENSE guides` (no test/deps/_build/junit_formatter). |
| Local `mix test` (no CI) emits no JUnit XML | 01 | ✓ VERIFIED | Behavioral: ran `env -u CI mix test ...` → exit 0, no XML produced. |
| Committed script computes per-job avg+p95+rerun over ci.yml runs | 02 | ✓ VERIFIED | `collect_ci_baseline.sh` wires `actions/workflows/ci.yml/runs` + `run_attempt`; `bash -n` PASS; produced real `103-BASELINE.md` table. |
| Committed script diffs live required-check names vs expected | 02 | ✓ VERIFIED | `check_required_checks.sh` wires `required_status_checks` + `--print-expected-json` + `contexts`; `bash -n` PASS. |
| Both scripts are read-only | 02 | ✓ VERIFIED | No `gh api -X PUT/POST/PATCH/DELETE` in either file. |
| Both scripts pass `bash -n` | 02 | ✓ VERIFIED | Probe run: both PASS. |
| Cache hit/miss surfaced for deps/build/PLT in 3 D-04 jobs | 03 | ✓ VERIFIED | 7× `cache-hit \|\| 'false'`, 3× `Cache hit/miss` tables; 6 new `deps/build-cache` ids + existing `plt-cache`. |
| Summary shows slowest 20 / compile profile / schedulers / seed | 03 | ✓ VERIFIED | All four patterns present in ci.yml D-04 jobs. |
| JUnit + coverage uploaded every run (pass or fail) | 03 | ✓ VERIFIED | `upload-artifact@v4` steps are `if: always()`. |
| ci-observability writes per-job native-duration table | 03 | ✓ VERIFIED | Job present; single `gh api .../runs/${RUN_ID}/jobs` read → duration table. |
| Same job writes per-step table for 3 long-poles from same response | 03 | ✓ VERIFIED | `.steps[]` jq path + `\| Job \| Step \| Duration (s) \|` heading; no second API call. |
| Required checks / PR pass-fail unchanged from baseline | 03 | ✓ VERIFIED | See SC4 evidence. |
| Committed internal doc records avg/p95/rerun before restructuring | 04 | ✓ VERIFIED | `103-BASELINE.md` §1; committed; no restructuring commits. |
| Doc records verbatim live required-check names + diff | 04 | ✓ VERIFIED | §2 (12 contexts), §3 (verbatim `13d12 / < brandbook-tokens` diff). |
| brandbook-tokens drift recorded verbatim, not fixed | 04 | ✓ VERIFIED | §3 "Recorded drift (NOT fixed)"; no branch-protection mutation. |
| Baseline doc lives only in .planning/, never ships | 04 | ✓ VERIFIED | `grep 103-BASELINE mix.exs` = 0; not in `files:`/`extras`. |
| junit_formatter test-only / lib unchanged (prohibitions) | 01-04 | ✓ VERIFIED | Zero lib/ change across all 9 phase-103 source commits. |

**Score:** 19/19 truths verified (0 present, behavior-unverified)

### Cross-Cutting Constraint Verification (the whole point of the phase)

| Constraint | Status | Evidence |
|-----------|--------|----------|
| `ci.yml` filename + `name: CI` byte-unchanged (D-13) | ✓ VERIFIED | `name: CI` not present in any phase-103 ci.yml diff; `git diff --name-status` shows `M` (modify), not rename. |
| ci-observability NOT a required check; required-check names unchanged (D-14) | ✓ VERIFIED | Advisory job (`if: always()`, never added to branch protection); live required-check set captured unchanged in baseline. |
| ZERO topology change — no existing job/step logic/gating/trigger altered | ✓ VERIFIED | Only additive `id:` keys + `if: always()` summary/upload steps; no `path:/key:/restore-keys:` removed; only gate `run:` change is `mix coveralls` → `mix coveralls --slowest 20 \| tee` under `set -o pipefail`. |
| ZERO lib/ change | ✓ VERIFIED | `git diff --name-only` per each of 9 phase-103 commits → only mix.exs, mix.lock, test_helper.exs, scripts/ci/*.sh, ci.yml. No lib/. |
| junit_formatter test-only, not in Hex `files:` allowlist | ✓ VERIFIED | mix.exs commit 41fccf8 diff = single additive dep line; allowlist byte-unchanged. |
| No fabricated metrics in 103-BASELINE.md | ✓ VERIFIED | Real capture artifacts present (Mux Soak avg -252 inverted timestamps, transient 401, variable 7–47 run counts, verbatim `gh diff` output) — characteristic of genuine data, not hand-cleaned. |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `mix.exs` | test-only junit_formatter dep | ✓ VERIFIED | :127 `{:junit_formatter, "~> 3.4", only: :test}`; mix.lock 3.4.0. |
| `test/test_helper.exs` | CI-gated JUnitFormatter wiring | ✓ VERIFIED | CI-gated formatters + put_env + mkdir; exclude_tags/Oban/Mock intact. |
| `scripts/ci/collect_ci_baseline.sh` | read-only avg/p95/rerun collector | ✓ VERIFIED | executable, lint-clean, wired, no mutation. |
| `scripts/ci/check_required_checks.sh` | read-only required-check diff | ✓ VERIFIED | executable, lint-clean, wired, no mutation. |
| `.github/workflows/ci.yml` | cache ids, summary steps, upload, aggregator | ✓ VERIFIED | All patterns present; YAML parses; structural asserts pass. |
| `103-BASELINE.md` | committed internal baseline + drift | ✓ VERIFIED | Real data, internal-only, not in Hex package. |

### Key Link Verification

| From | To | Status | Details |
|------|----|--------|---------|
| test_helper.exs | `_build/test/junit/rindle-junit.xml` | ✓ WIRED | put_env report_dir/report_file; behaviorally produced under CI. |
| ci.yml upload-artifact | `_build/test/junit/rindle-junit.xml` | ✓ WIRED | `path:` references the exact Plan-01 wired path. |
| ci-observability | GitHub Actions jobs API | ✓ WIRED | `gh api .../runs/${RUN_ID}/jobs`, job-scoped `actions: read`. |
| check_required_checks.sh | setup_branch_protection.sh | ✓ WIRED | invokes `--print-expected-json`, diffs `.contexts[]`. |
| collect_ci_baseline.sh | Actions API | ✓ WIRED | `actions/workflows/ci.yml/runs` + `run_attempt`. |
| 103-BASELINE.md | both collectors | ✓ WIRED | doc is the captured output (real table + diff). |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| JUnit XML emitted under CI | `CI=1 mix test <file>` | exit 0; real testsuite XML written | ✓ PASS |
| Local run stays quiet | `env -u CI mix test <file>` | exit 0; no XML | ✓ PASS |
| Gate not masked by tee | inspect `set -o pipefail` before pipe | present (ci.yml:139, :371) | ✓ PASS |
| collector lint | `bash -n collect_ci_baseline.sh` | PASS | ✓ PASS |
| check lint | `bash -n check_required_checks.sh` | PASS | ✓ PASS |
| ci.yml structure | python yaml + assertions | name/perms/needs/omit all correct | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|-------------|----------------|-------------|--------|----------|
| OBS-01 | 103-03 | per-job + per-step timing + cache hit/miss in run summary | ✓ SATISFIED | ci-observability per-job + per-step tables; cache hit/miss tables. |
| OBS-02 | 103-01, 103-03 | slowest 20 / compile profile / schedulers / seed + JUnit+coverage artifacts | ✓ SATISFIED | All evidence steps + behaviorally-produced JUnit XML + upload steps. |
| OBS-03 | 103-02, 103-04 | committed baseline table + live required-check names | ✓ SATISFIED | Both collectors + committed `103-BASELINE.md` with real data + drift. |

All three declared requirement IDs (OBS-01, OBS-02, OBS-03) are present in PLAN frontmatter, map to Phase 103 in REQUIREMENTS.md (lines 133-135, marked Complete), and are satisfied. No orphaned requirements.

### Anti-Patterns Found

None attributable to Phase 103. Two grep hits are false positives confirmed pre-existing via `git log -S`:
- `mix.exs` "HACK" substrings = the `hackney` HTTP-client dependency (pre-existing, commit 5d5ab2c and earlier).
- `ci.yml` `HEX_API_KEY: dryrun-placeholder` = pre-existing dry-run publish env (commit 52abcf6, Phase 11).

No TBD/FIXME/XXX debt markers in any phase-103-modified file. No stubs.

### Gaps Summary

None. Every ROADMAP success criterion, every plan must-have truth, every key link, every requirement, and all six cross-cutting constraints are verified against the actual codebase and git history. The phase is purely additive/observational: zero lib/ change, zero gate-behavior change (the one gate-step edit is exit-code-safe under `set -o pipefail`), zero topology change, zero shipped-package change, and the committed baseline contains genuine (un-smoothed) captured data. The single most subtle risk (tee masking the coveralls gate exit code) was specifically inspected and found correctly mitigated.

---

_Verified: 2026-06-20T23:40:00Z_
_Verifier: Claude (gsd-verifier)_
