---
phase: 103
slug: observability-baseline
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-20
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
| OBS-01 | Summary shows per-job + per-step timing + cache hit/miss; gate unchanged | workflow self-check (PR observation) + shellcheck/`bash -n` | `bash -n scripts/ci/*.sh`; phase PR run shows summary | ❌ W0 | ⬜ pending |
| OBS-02 | `--slowest 20`, compile profile, `schedulers_online`, seed surfaced; JUnit + coverage uploaded | integration (artifacts produced) | `CI=1 mix test` → assert `_build/test/junit/*.xml` exists; `mix coveralls.json` → assert `cover/excoveralls.json` | ❌ W0 | ⬜ pending |
| OBS-03 | Baseline (avg+p95+rerun/flake) + live required-check names committed before any restructuring; live-vs-expected diff runs | smoke (scripts run, emit table) | `bash scripts/ci/check_required_checks.sh main`; `bash scripts/ci/collect_ci_baseline.sh` | ❌ W0 | ⬜ pending |
| OBS gate-unchanged | Same required checks pass/fail as pre-phase | regression | `check_required_checks.sh` diff empty vs pre-phase live snapshot | ✅ live read works | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/ci/collect_ci_baseline.sh` — new; OBS-03 (avg/p95/rerun via `run_attempt`). Add `bash -n` lint.
- [ ] `scripts/ci/check_required_checks.sh` — new; OBS-03 live-vs-`--print-expected` diff (diff on `.contexts[]`). Add `bash -n` lint.
- [ ] Assertion that `CI=1 mix test` produces the JUnit XML and `mix coveralls.json` produces `cover/excoveralls.json` (OBS-02) — small smoke check or documented Wave 0 verification.
- [ ] Confirm `cover/` and `_build/test/junit/` are gitignored (no artifact leakage into commits or the Hex package `files:` allowlist).
- [ ] `mix deps.get` after adding `{:junit_formatter, "~> 3.4", only: :test}` (no new framework — ExUnit already present).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `$GITHUB_STEP_SUMMARY` renders per-job/per-step timing + cache hit/miss | OBS-01 | No automated harness reads the rendered GitHub summary; only observable on a real PR run | Open the phase PR's CI run → confirm summary sections present; confirm no change to which checks are required/pass/fail |
| Live branch-protection required-check capture is accurate | OBS-03 | Reads live GitHub state via maintainer `gh` admin session; can drift between runs | Maintainer runs `check_required_checks.sh main` immediately before capture; record verbatim `.contexts[]` and the diff vs `--print-expected` (known live drift: `brandbook-tokens`) |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (the two new scripts + artifact-produced assertions)
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s (quick) / full suite within CI job time
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
