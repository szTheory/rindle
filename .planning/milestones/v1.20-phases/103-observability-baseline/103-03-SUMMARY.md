---
phase: 103-observability-baseline
plan: 03
subsystem: ci-observability
status: complete
tags: [ci, observability, github-actions, timing, cache, artifacts, aggregator]
requires:
  - "_build/test/junit/rindle-junit.xml (Plan 01 — CI-gated JUnit XML)"
  - "cover/excoveralls.json (Plan 01 — coverage JSON)"
provides:
  - ".github/workflows/ci.yml cache id:s (deps-cache/build-cache) in quality/integration/package-consumer"
  - ".github/workflows/ci.yml cache hit/miss + OBS-02 evidence summary steps (D-04 jobs)"
  - ".github/workflows/ci.yml junit-coverage-<job>-<elixir> artifact upload (every run)"
  - ".github/workflows/ci.yml ci-observability aggregator job (per-job + per-step native timing tables)"
affects:
  - "Phase 104 (cache/tooling hygiene) — cache hit/miss now readable to validate key changes"
  - "Phase 105 (aggregate required check) — ci-observability is advisory; must NOT become a required check"
  - "Phase 106 (lane split) — per-job/per-step timing evidence informs the long-pole split"
tech-stack:
  added: []
  patterns:
    - "Job-scoped permissions: actions: read (precedent release.yml gate-ci-green) — workflow default stays contents: read"
    - "Single gh api .../runs/${RUN_ID}/jobs read → per-job table + per-step table (steps[] carried in same response)"
    - "Brace-group { ... } >> \"$GITHUB_STEP_SUMMARY\" append idiom (branch-protection-apply.yml)"
    - "cache-hit coalesced with || 'false' (restore-keys partial hit leaves cache-hit empty)"
    - "Fenced + tail-bounded summary dumps to stay under the 1 MiB $GITHUB_STEP_SUMMARY cap"
key-files:
  created: []
  modified:
    - .github/workflows/ci.yml
decisions:
  - "Per-step table matches display-name prefixes (startswith Quality/Integration/Package Consumer Proof Matrix) not job keys — the jobs API .name carries matrix suffixes (e.g. 'Quality (1.15, 26)')"
  - "package-consumer gets build-profile/schedulers + coveralls.json + artifact upload but no --slowest/seed surfacing (it drives install-smoke/release-preflight scripts, not a direct ExUnit run)"
metrics:
  duration: "9 min"
  completed: 2026-06-20
  tasks: 3
  files: 1
---

# Phase 103 Plan 03: Observability Baseline — CI Self-Reporting Summary

Instrumented `.github/workflows/ci.yml` to be self-reporting — additively and observationally only, with zero gate-behavior and zero topology change. Added cache `id:`s so hit/miss is readable, appended per-step timing / cache hit-miss / OBS-02 evidence (slowest tests, compile profile, schedulers, seed) to `$GITHUB_STEP_SUMMARY` in the three D-04 jobs, upload JUnit + coverage artifacts on every run, and added a single job-scoped `ci-observability` aggregator that reads authoritative native per-job durations once and, from that same response, emits per-step durations for the three D-04 long-pole jobs (OBS-01 per-step). The filename, `name: CI`, the workflow-level `permissions: contents: read`, and every `run:` gate are byte/behaviour-unchanged; only `ci.yml` was touched.

## What Was Built

### Task 1 — Cache id:s + cache hit/miss summary (D-04 jobs)
- Added `id: deps-cache` and `id: build-cache` to the previously-un-id'd `actions/cache@v4` restore steps in `quality`, `integration`, `package-consumer` (6 new `id:`s; the existing `id: plt-cache` in `quality` is untouched). Only the `id:` key was added — `path`/`key`/`restore-keys` are byte-unchanged (D-02).
- Added one `if: always()` "Summarize cache hit/miss" step per D-04 job appending a Markdown table to `$GITHUB_STEP_SUMMARY` via the brace-group append idiom, coalescing each `cache-hit` with `|| 'false'` (Pitfall 1 — a restore-keys partial hit leaves `cache-hit` empty). `quality`'s table includes the PLT cache row.
- Commit: `fec072d`

### Task 2 — OBS-02 evidence steps + JUnit/coverage artifact upload (D-04 jobs)
- `quality` + `integration`: added a "Surface compile profile + schedulers" step appending `System.schedulers_online()` (via `mix run --no-start -e 'IO.puts(System.schedulers_online())'`) and a `tail -20`-bounded `mix compile --profile time` dump inside a code fence.
- `quality`: wrapped the gating test step so it stays `mix coveralls` but adds `--slowest 20`, tees stdout, and greps `Randomized with seed` + slowest-test lines into the summary. The gating step is NOT replaced by `mix coveralls.json` (Anti-Pattern).
- `integration`: added `--slowest 20` + tee to both `mix test` invocations (files/`--include` tags otherwise byte-unchanged); same seed/slowest grep into the summary.
- `package-consumer`: added the build-profile/schedulers evidence step. It drives install-smoke/release-preflight scripts rather than a direct ExUnit run, so the `--slowest`/seed surfacing lives in `quality`/`integration` only (documented in-file).
- All three D-04 jobs: added an additive `if: always()` `mix coveralls.json` sibling + an `actions/upload-artifact@v4` (`if: always()`) step `name: junit-coverage-${{ github.job }}-${{ matrix.elixir || 'na' }}` uploading `_build/test/junit/rindle-junit.xml` + `cover/excoveralls.json`, `if-no-files-found: warn`, `retention-days: 14`. The JUnit path matches Plan 01's `test_helper.exs` wiring exactly.
- Commit: `c056382`

### Task 3 — ci-observability aggregator with job-scoped actions: read
- Added a new top-level `ci-observability` job: `if: always()`, `permissions: { actions: read }` at JOB level ONLY (precedent: `release.yml` `gate-ci-green`). The workflow-level `permissions: contents: read` is untouched (D-03).
- `needs:` the 11 non-skip-prone jobs (`quality`, `optional-dependencies`, `integration`, `contract`, `proof`, `package-consumer`, `adoption-demo-unit`, `cohort-demo-smoke`, `adoption-demo-e2e`, `adopter`, `brandbook-tokens`); OMITS `mux-soak`, `gcs-soak`, `package-consumer-gcs-live` (Pitfall 4 — they `if:`-skip on forks/unlabeled PRs and would block/fail the aggregator).
- A single step reads `gh api --paginate .../actions/runs/${RUN_ID}/jobs?per_page=100` once into `/tmp/ci-jobs.json`, then `jq` produces (1) a per-job native-duration table (`completed_at − started_at` via `fromdateiso8601`, self-excluding `"CI Observability"`) and (2) a per-step timing table (`| Job | Step | Duration (s) |`) for the three D-04 long-pole jobs from the SAME response's `.steps[]` array — no second API call, no extra permission (OBS-01 per-step; Q2 long-poles-only resolution).
- Advisory only — NOT added to any branch-protection required check (D-14, Phase 105 scope).
- Commit: `68ef610`

## Verification Results

- `python3 -c "import yaml; yaml.safe_load(...)"` → exits 0 (valid YAML) after every task. ✅
- `name: CI` (ci.yml:1) and the filename are byte-unchanged; workflow-level `permissions` is exactly `{contents: read}`. ✅
- 6 cache `id:`s (`deps-cache`/`build-cache` across 3 jobs); existing `plt-cache` untouched; `Cache hit/miss` table + `cache-hit || 'false'` present. ✅
- `schedulers_online`, `compile --profile time`, `slowest 20`, `mix coveralls.json`, `_build/test/junit/rindle-junit.xml`, `upload-artifact@v4` all present. ✅
- Gating test step is still `mix coveralls --slowest 20` (ci.yml:140); the three `mix coveralls.json` occurrences are additive siblings only. ✅
- Aggregator structural assert passes: `ci-observability` job exists, `if: always()`, `permissions == {actions: read}`, `needs` (11) disjoint from `{mux-soak, gcs-soak, package-consumer-gcs-live}`, includes quality/package-consumer/brandbook-tokens, workflow perms `{contents: read}`. ✅
- Both `jq` filters validated against a representative sample jobs API response: per-job table self-excludes the aggregator; per-step table matches matrix-suffixed display names (`Quality (1.15, 26)`, `Integration`, `Package Consumer Proof Matrix + Release Preflight`) and emits correct `completed_at − started_at` durations. ✅
- `git diff --name-only fec072d~1 HEAD` → only `.github/workflows/ci.yml`; zero `lib/` changes. ✅

(Manual / on-PR per VALIDATION.md): the rendered run summary showing the cache, slowest-tests, seed, compile-profile, schedulers, per-job and per-step tables, plus the uploaded artifacts, is observable only on a live run and is routed to VALIDATION.md manual-only.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] Per-step jq filter matched job keys instead of display names**
- **Found during:** Task 3.
- **Issue:** The plan's per-step filter text uses `select(.name == "quality" or .name == "integration" or .name == "package-consumer")`. The Actions jobs API `.name` field carries the display `name:` value (and a matrix suffix), e.g. `"Quality (1.15, 26)"`, `"Integration"`, `"Package Consumer Proof Matrix + Release Preflight"` — never the lowercase job key. An exact-equality match on the job keys would have produced an empty per-step table on every run.
- **Fix:** Used `startswith` on the display-name prefixes (`"Quality"`, `"Integration"`, `"Package Consumer Proof Matrix"`) so the matrix-suffixed variants are captured. The per-job table likewise self-excludes by the display name `"CI Observability"` (matching the research's Pattern 1 self-exclusion). Validated both filters against a representative sample response (correct rows, aggregator excluded).
- **Files modified:** .github/workflows/ci.yml
- **Commit:** `68ef610`

## Threat Surface

No new threat surface beyond the plan's `<threat_model>`; all register mitigations held:
- **T-103-06** (`actions: read` creep): declared at the `ci-observability` job level only; workflow-level `permissions` asserted to stay `{contents: read}`.
- **T-103-07** (aggregator turning fork-skips into failures): `mux-soak`/`gcs-soak`/`package-consumer-gcs-live` omitted from `needs:`; `if: always()`; advisory-only.
- **T-103-08** (artifact secret leakage): artifacts are JUnit XML (test names) + coverage JSON (coverage %), no secrets; `retention-days: 14`.
- **T-103-09** (changing a gate / required check): `mix coveralls` stays the gating step; the aggregator is never added to branch protection (Phase 105 scope).
- **T-103-SC** (package installs): none in this plan — only YAML workflow edits.

## Known Stubs

None.

## Self-Check: PASSED
- .github/workflows/ci.yml — exists, valid YAML
- ci-observability job — present (per-job + per-step tables)
- Cache id:s (deps-cache/build-cache) — present in quality/integration/package-consumer
- OBS-02 evidence + upload-artifact — present
- Commit fec072d — found in git log
- Commit c056382 — found in git log
- Commit 68ef610 — found in git log
