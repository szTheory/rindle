---
phase: 103
slug: observability-baseline
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-20
validated: 2026-06-22
---

# Phase 103 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `103-RESEARCH.md` § Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.15/OTP26 + 1.17/OTP27 matrix) |
| **Config file** | `test/test_helper.exs` (no lib-level `config/test.exs`) |
| **Quick run command** | `CI=1 mix test test/<targeted>_test.exs` |
| **Full suite command** | `mix coveralls` (the merge-blocking gate, `ci.yml:118`) |
| **Estimated runtime** | quick ~seconds; full suite ~ existing `ci.yml` quality-job duration |

Note: this phase's deliverables are mostly **workflow YAML + shell scripts + test-harness config**, not `lib/` code. Several acceptance checks are observed on the phase's own CI run (`$GITHUB_STEP_SUMMARY` content) rather than via ExUnit; those are routed to Wave 0 smoke/lint checks below.

---

## Sampling Rate

- **After every task commit:** `bash -n` on any new/edited `scripts/ci/*.sh`; for any `test/test_helper.exs` change, run `CI=1 mix test test/<one>_test.exs` to confirm the JUnit XML appears and the suite still passes.
- **After every plan wave:** `mix coveralls` (full gating suite) green; confirm the phase PR's own CI run renders the new summary sections.
- **Before `/gsd-verify-work`:** Full `ci.yml` green on the phase PR with **identical required-check pass/fail vs the pre-phase baseline** (OBS-03 diff empty against the captured pre-phase snapshot), and `103-BASELINE.md` committed.
- **Max feedback latency:** quick check < ~30s; full suite within existing CI job time.

---

## Per-Task Verification Map

| Req | Behavior | Test Type | Automated Command | File Exists | Status |
|-----|----------|-----------|-------------------|-------------|--------|
| OBS-01 | Summary shows per-job + per-step timing + cache hit/miss; gate unchanged | smoke (structural regression lock on `ci.yml` + setup-elixir composite) | `CI=1 mix test test/install_smoke/ci_observability_test.exs` (asserts `ci-observability` job `if: always()` + job-level `actions: read`; composite `id: deps_cache`/`id: build_cache` + 3×3 output refs; `Summarize cache hit/miss` → `$GITHUB_STEP_SUMMARY` with `\|\| 'false'`; gate-unchanged: `name: CI` line 1 + workflow-level `permissions: contents: read`) | ✅ `test/install_smoke/ci_observability_test.exs` | ✅ green |
| OBS-02 | `--slowest 20`, compile profile, `schedulers_online`, seed surfaced; JUnit + coverage uploaded | smoke (structural lock on `ci.yml` + `test_helper.exs` + `mix.exs`) | `CI=1 mix test test/install_smoke/ci_observability_test.exs` (asserts `--slowest 20`, `mix compile --profile time`, `schedulers_online`, `Randomized with seed`, `mix coveralls.json`, `upload-artifact@`, JUnit path; gating step stays `mix coveralls --slowest 20`; test_helper CI-gated `JUnitFormatter` + `File.mkdir_p!` + `_build/test/junit`; `{:junit_formatter, "~> 3.4", only: :test}`) | ✅ `test/install_smoke/ci_observability_test.exs` | ✅ green |
| OBS-03 | Baseline (avg+p95+rerun/flake) + live required-check names committed before any restructuring; live-vs-expected diff runs | smoke (read-only invariant + structural lock on the two collectors + baseline doc) | `CI=1 mix test test/install_smoke/ci_observability_test.exs` (asserts both scripts `set -euo pipefail`; READ-ONLY `refute gh api -X PUT/POST/PATCH/DELETE` (T-103-03); `actions/workflows/ci.yml/runs` + `run_attempt`; `required_status_checks` + `.contexts` + `print-expected`; `103-BASELINE.md` exists) | ✅ `test/install_smoke/ci_observability_test.exs` | ✅ green |
| OBS gate-unchanged | Same required checks pass/fail as pre-phase | manual-only (live `gh` admin read) | `check_required_checks.sh` diff empty vs pre-phase live snapshot — see Manual-Only | ✅ live read works | 🟡 manual-only |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky · 🟡 manual-only*

> **Automated coverage:** `test/install_smoke/ci_observability_test.exs` (module `Rindle.InstallSmoke.CiObservabilityTest`) — 13 structural regression-lock tests, no exclude tag, runs in the default merge-blocking `mix test` suite alongside the Phase 104 (`ci_cache_hygiene_test.exs`) / Phase 106 (`ci_lane_split_test.exs`) siblings. Added by `/gsd-validate-phase 103` on 2026-06-22.
> **Scope note:** the OBS-01 cache `id:`s ship underscored (`id: deps_cache`/`id: build_cache`) inside the `setup-elixir` composite (post-Phase-104 extraction) and are consumed in `ci.yml` only via the `deps-cache-hit`/`build-cache-hit` outputs (3+3 refs). The test asserts that real contract, not the literal `id: deps-cache` in `ci.yml`.

---

## Wave 0 Requirements

- [x] `scripts/ci/collect_ci_baseline.sh` — new; OBS-03 (avg/p95/rerun via `run_attempt`). `bash -n` clean; read-only + endpoint shape locked by `ci_observability_test.exs`.
- [x] `scripts/ci/check_required_checks.sh` — new; OBS-03 live-vs-`--print-expected` diff (diff on `.contexts[]`). `bash -n` clean; read-only + endpoint shape locked by `ci_observability_test.exs`.
- [x] Assertion that `CI=1 mix test` produces the JUnit XML and `mix coveralls.json` produces `cover/excoveralls.json` (OBS-02) — JUnitFormatter wiring (`test_helper.exs`) + `mix coveralls.json`/artifact-upload wiring (`ci.yml`) locked by `ci_observability_test.exs`; live XML emission re-confirmed on this run (`Wrote JUnit report to: _build/test/junit/rindle-junit.xml`).
- [x] Confirm `cover/` and `_build/test/junit/` are gitignored (no artifact leakage into commits or the Hex package `files:` allowlist) — verified in Plan 01 (`git check-ignore`), `files:` allowlist byte-unchanged.
- [x] `mix deps.get` after adding `{:junit_formatter, "~> 3.4", only: :test}` (no new framework — ExUnit already present) — test-only dep present in `mix.exs`/`mix.lock`, locked by `ci_observability_test.exs`.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `$GITHUB_STEP_SUMMARY` renders per-job/per-step timing + cache hit/miss | OBS-01 | No automated harness reads the rendered GitHub summary; only observable on a real PR run | Open the phase PR's CI run → confirm summary sections present; confirm no change to which checks are required/pass/fail |
| Live branch-protection required-check capture is accurate | OBS-03 | Reads live GitHub state via maintainer `gh` admin session; can drift between runs | Maintainer runs `check_required_checks.sh main` immediately before capture; record verbatim `.contexts[]` and the diff vs `--print-expected` (known live drift: `brandbook-tokens`) |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (the two new scripts + artifact-produced assertions)
- [x] No watch-mode flags
- [x] Feedback latency < 30s (quick) / full suite within CI job time — `ci_observability_test.exs` runs in 0.02s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-06-22 (`/gsd-validate-phase 103`)

---

## Validation Audit 2026-06-22
| Metric | Count |
|--------|-------|
| Gaps found | 3 (OBS-01, OBS-02, OBS-03) |
| Resolved | 3 (automated via `test/install_smoke/ci_observability_test.exs`, 13 tests green) |
| Escalated | 0 |
| Manual-only (out of scope) | 1 (OBS gate-unchanged — live `gh` admin required-check diff) |

OBS-01/02/03 were MISSING automated coverage (deliverables shipped, but no ExUnit regression lock unlike sibling Phases 104/106). Filled by generating `test/install_smoke/ci_observability_test.exs` — structural `File.read!` + `=~`/`refute =~`/count assertions against the shipped `ci.yml`, `setup-elixir` composite, `test_helper.exs`, `mix.exs`, the two read-only baseline collectors, and `103-BASELINE.md`. No exclude tag → merge-blocking. Zero implementation files modified.
