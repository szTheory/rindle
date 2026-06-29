---
phase: 112
slug: pr-main-gate-shift-left
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-28
---

# Phase 112 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> This phase is CI-topology (zero `lib/` change). Its "tests" are CI structural
> assertions + bash gate-script unit tests + the lean lane itself — NOT new
> ExUnit modules. Derived from `112-RESEARCH.md` §Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | GitHub Actions job assertions + bash gate-script unit tests (`scripts/ci/test_ci_summary_gate.sh`) + Playwright (the lean lane's own specs) |
| **Config file** | `.github/workflows/ci.yml`; `examples/adoption_demo/playwright.config.js` |
| **Quick run command** | `bash scripts/ci/test_ci_summary_gate.sh` (gate logic) + `scripts/setup_branch_protection.sh --print-expected` (sole-required-context assertion) |
| **Full suite command** | Push to a PR branch → observe `CI Summary` aggregates the new lean lane as `success` (not `skipped`); push:main → full `adoption-demo-e2e` lane still green |
| **Estimated runtime** | gate-script units ~seconds; lean lane target ≤ image-smoke long pole (~414s chain), PR p95 ≤ ~7.5 min |

---

## Sampling Rate

- **After every task commit:** YAML validity (`actionlint` if available, else GitHub's parse-on-push); `bash scripts/ci/test_ci_summary_gate.sh`; `git diff --exit-code` on the two byte-frozen scripts.
- **After every plan wave:** A PR run showing the lean lane `success` and present in the `CI Summary` table.
- **Before `/gsd-verify-work`:** Lean lane green on a PR AND full `adoption-demo-e2e` still green on push:main; byte-frozen scripts show no diff.
- **Max feedback latency:** ~one CI run (≤ ~7.5 min PR p95).

---

## Per-Task Verification Map

| Req ID | Behavior | Test Type | Automated Command / Check | File Exists? |
|--------|----------|-----------|---------------------------|-------------|
| GATE-01 | Lean `adoption-demo-e2e-smoke` runs on every PR, deterministic specs only, in `CI Summary.needs` + `ci-observability.needs` | CI structural + live | YAML lint of new job (no `if:` gate; specs env set); a PR run shows the job `success` (not `skipped`) and present in the CI Summary table | ❌ Wave 0: new job |
| GATE-01 | `e2e_local.sh` honors `ADOPTION_DEMO_E2E_SPECS` (unset → full suite) | unit/assertion | Shell assertion: unset env → playwright invocation has no positional spec; set → has exactly the two specs | ❌ Wave 0: add assertion (GATE-A3) |
| GATE-02 | PR p95 ≤ ~7.5 min; lean lane ≤ image-smoke long pole | observational | `ci-observability` per-job timing post-merge; `bash scripts/ci/collect_ci_baseline.sh` over recent runs | ✓ (existing tooling) |
| GATE-03 | `setup_branch_protection.sh` byte-unchanged; only `CI Summary` required | structural | `git diff --exit-code scripts/setup_branch_protection.sh`; `scripts/setup_branch_protection.sh --print-expected` unchanged | ✓ (assert no diff) |
| GATE-03 | `eval_ci_summary.sh` byte-unchanged (drift-proof needs-iteration) | structural | `git diff --exit-code scripts/ci/eval_ci_summary.sh` | ✓ (assert no diff) |
| GATE-03 | 3 lanes (`cohort-demo-smoke`, `package-consumer-full`, `mux-soak`) stay off PR; rationale documented | docs | RUNNING.md CI-lane-severity table includes the 3 off-PR rationales + the new lean row (fix pre-existing "merge-blocking" drift, Pitfall 6) | ✓ (RUNNING.md exists; edit it) |
| GATE-04 | Lane enters `needs:` only after 108/109/110 land + N=3 consecutive green main `adoption-demo-e2e` runs | sequencing + operator | `checkpoint:human-verify` — operator confirms `gh run list --workflow=CI --branch=main` shows 3 consecutive green `Adoption Demo E2E` before the `needs:` wiring commit | ❌ Wave 0: operator checkpoint (not automatable pre-merge) |

---

## Wave 0 Gaps

- [ ] The `adoption-demo-e2e-smoke` job — new YAML in `ci.yml` (covers GATE-01).
- [ ] The `e2e_local.sh` spec-scoping edit + an assertion that unset → full suite (GATE-A3).
- [ ] An operator `checkpoint:human-verify` task encoding GATE-04 (N=3 consecutive green main runs).
- [ ] RUNNING.md CI-lane-severity row for the lean lane + the 3 off-PR rationales (and fix the pre-existing "merge-blocking" drift on the full E2E / cohort rows, Pitfall 6).
- [ ] A `git diff --exit-code` guard (or plan assertion) that `setup_branch_protection.sh` + `eval_ci_summary.sh` are byte-unchanged.

---

## Validation Notes

- **GATE-02 is observational, not pre-merge-certain** (Assumption A1): the 2-spec subset duration is estimated, not measured. The guard is the post-merge `ci-observability` timing + `collect_ci_baseline.sh`; if the subset breaches budget, narrow to `smoke.spec.js` only.
- **GATE-04 is the load-bearing sequencing gate**: the lane MUST exist and run on PRs (green) BEFORE it is wired into `needs:`. The `needs:` wiring is its own commit behind the human-verify checkpoint. Recommended two-wave split: job-exists wave → operator checkpoint → needs-wiring wave.
- **skip==pass safety**: the lean lane has NO `if:` gate, so it always runs on PR → plain success/fail, never `skipped`-as-pass ambiguity.
