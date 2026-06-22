---
phase: 106-trigger-split-matrix-lane-refinement
verified: 2026-06-22T00:00:00Z
status: passed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 106: Trigger Split + Matrix/Lane Refinement Verification Report

**Phase Goal:** Deliver the headline wall-clock win — now that only `CI Summary` is required, split work by trigger so the PR lane carries representative signal and release-readiness breadth moves to main/nightly/release.

**Verified:** 2026-06-22
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

This is a CI/CD-infrastructure phase with intentionally ZERO application/lib change. Verification confirms the GitHub Actions topology, triggers, concurrency, matrix, needs-graph, A–E classification, and release-gate coupling are correct — not that a test suite runs.

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 (LANE-01) | Fast PR lane with `concurrency` group cancelling stale PR runs; main/release serialize and never cancel | ✓ VERIFIED | ci.yml:27-29 top-level `concurrency: group: ${{ github.workflow }}-${{ github.ref }}` (per-workflow+per-ref), `cancel-in-progress: ${{ github.event_name == 'pull_request' }}` → true only on PR, false on push:main/dispatch. Demo-lane moves (adoption-demo-e2e/cohort-demo-smoke → push:main, dropped from needs) take the ~502s chain off PR so p95 lands under ≤7 min. |
| 2 (LANE-02) | `package-consumer` long pole scoped by trigger: one representative `image` smoke on PR; full 5-profile matrix + release_preflight + hex.publish --dry-run off-PR; release gate provably satisfied only by a full-matrix run | ✓ VERIFIED | Lean `package-consumer` (ci.yml:515) runs `install_smoke.sh image` only + version-alignment, stays in CI Summary.needs. `package-consumer-full` (ci.yml:654) `if: github.event_name != 'pull_request'`, `fail-fast: false`, `profile: [video,image,tus,mux,gcs]`, runs release_preflight + repo_hygiene --ci + hex.publish --dry-run, NO continue-on-error (0 occurrences in block). Omitted from CI Summary/observability needs (D-09). release.yml:202 gate-ci-green reads `latest.conclusion !== 'success'` on the push:main ci.yml run → full-verification gate provably satisfied only by a full-matrix run (D-11). |
| 3 (LANE-03) | Nightly lane carries broad OTP×Elixir matrix, gcs-soak, package-consumer-gcs-live, owned Dialyzer off the PR critical path | ✓ VERIFIED | nightly.yml `name: Nightly`, `schedule: cron '27 7 * * *'` + workflow_dispatch, NO pull_request/push. compat-matrix: 6 diagonal cells (1.15/26, 1.15/25, 1.16/26, 1.17/27, 1.18/27, 1.18/28) fail-fast:false straddling OTP<27 polyfill. Owned gating Dialyzer (literal `otp27-elixir1.17` PLT key, `hashFiles('mix.exs', '.dialyzer_ignore.exs')`, no continue-on-error). gcs-soak + package-consumer-gcs-live moved from ci.yml; gcs-live continue-on-error dropped. nightly-summary + nightly-failure-issue (`failure() && schedule`, `issues: write` only). |
| 4 (LANE-04) | Documented A–E classification backs every lane placement; coverage off critical path; trust/speed tradeoff labeled in CONTRIBUTING and PR | ✓ VERIFIED | 106-LANE-CLASSIFICATION.md (176 lines) places every ci.yml job in exactly one bucket; mux-soak explicitly label-gated PR lane (NOT nightly); quarantine(D)/delete(E) explicitly EMPTY; coverage off-critical-path (advisory telemetry, mix coveralls stays gating). CONTRIBUTING.md carries copy-pasteable trust/speed label with on-PR vs after-merge/nightly split, ≤7-min target, expensive/flaky/live-3rd-party rationale, "caught within one merge / blocks the next merge not the author" framing, and `/gsd-ship`-time PR-paste handoff reminder. |
| 5 | ci.yml keeps file name + `name: CI` on push:main; release gate not weakened | ✓ VERIFIED | ci.yml line 1 == `name: CI`; filename `.github/workflows/ci.yml` unchanged. nightly is a SEPARATE file named `Nightly` (no schedule on ci.yml, no PR trigger) → invisible to release-please-automerge `workflow_run:[CI]`. scripts/ci/eval_ci_summary.sh + scripts/setup_branch_protection.sh byte-unchanged (REQUIRED_CHECKS still only `CI Summary`). |

**Score:** 5/5 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `.github/workflows/ci.yml` | concurrency block + split package-consumer + extracted Dialyzer/gcs lanes + demo-lane moves; `name: CI` | ✓ VERIFIED | 1307 lines; parses as valid YAML; line 1 `name: CI`. All required jobs present, all removed jobs absent. |
| `.github/workflows/nightly.yml` | NEW `name: Nightly` with compat-matrix + owned Dialyzer + moved soak/live + summary + issue | ✓ VERIFIED | 488 lines; parses as valid YAML; all 6 jobs present and correctly wired. |
| `CONTRIBUTING.md` | NEW trust/speed label (LANE-04) | ✓ VERIFIED | 100 lines; "after merge", ≤7-min, `image` smoke, PR-handoff all present. NOT in Hex files allowlist (correct). |
| `RUNNING.md` | lane-severity forward-reference | ✓ VERIFIED | §"Maintainer: CI lane severity" describes package-consumer split, package-consumer-full, separate nightly.yml, mux-soak label-gated, name:CI invariant; corrected to shipped reality in commit 5c30b7f (WR-01..04). |
| `106-LANE-CLASSIFICATION.md` | A–E buckets backing every placement | ✓ VERIFIED | 176 lines; every ci.yml job placed exactly once; D-E empty; mux-soak label-gated; cites D-01..D-20. NOT in Hex allowlist. |

### Key Link Verification

| From | To | Via | Status |
|------|-----|-----|--------|
| ci.yml concurrency.cancel-in-progress | github.event_name | `== 'pull_request'` → false on push:main | ✓ WIRED |
| ci.yml package-consumer-full | release.yml gate-ci-green | `if: != pull_request` + no continue-on-error → feeds push:main run conclusion (release.yml:202 reads `conclusion !== 'success'`) | ✓ WIRED |
| ci-summary.needs / ci-observability.needs | package-consumer (lean only) | full lane intentionally absent from both needs lists (D-09) | ✓ WIRED |
| nightly.yml Dialyzer PLT cache | mix.exs + .dialyzer_ignore.exs | `hashFiles('mix.exs', '.dialyzer_ignore.exs')` with literal otp27-elixir1.17 prefix (no bare matrix.* ref) | ✓ WIRED |
| nightly.yml nightly-failure-issue | github issues | inline `gh issue` find-open-else-create, `issues: write` only, `failure() && schedule` | ✓ WIRED |
| adoption-demo-e2e + cohort-demo-smoke | ci-summary/observability needs | `if: repo && != pull_request` (repo gate preserved AND composed), removed from both needs lists | ✓ WIRED |

### Release-Coupling Invariants (load-bearing for SC5)

| Invariant | Status | Evidence |
|-----------|--------|----------|
| ci.yml line 1 `name: CI`, filename unchanged | ✓ | head -1 == `name: CI` |
| eval_ci_summary.sh byte-unchanged | ✓ | `git diff --quiet` exits 0 |
| setup_branch_protection.sh byte-unchanged; REQUIRED_CHECKS = only `CI Summary` | ✓ | `git diff --quiet` exits 0; REQUIRED_CHECKS=("CI Summary") |
| nightly.yml structurally invisible to release consumers | ✓ | separate file, `name: Nightly`, no schedule on ci.yml, no PR/push trigger |
| gate-ci-green reads ci.yml push:main run conclusion | ✓ | release.yml:180 `workflow_id: 'ci.yml'`, :202 conclusion check |

### D-03 Non-Negotiable PR Guardrail

| Job | In ci-summary.needs | Push:main event gate | Status |
|-----|--------------------|--------------------|--------|
| integration | ✓ yes | ✗ none (only `if: always()` step-result) | ✓ PR-gating |
| contract | ✓ yes | ✗ none | ✓ PR-gating |
| proof | ✓ yes | ✗ none | ✓ PR-gating |
| adopter | ✓ yes | ✗ none | ✓ PR-gating |
| adoption-demo-unit | ✓ yes (D-02 PR-side proxy stays) | ✗ none | ✓ PR-gating |

### Prohibitions (must-NOT checks — all verified absent)

| Prohibition | Status | Evidence |
|-------------|--------|----------|
| mux-soak classified/moved to nightly | ✓ NOT VIOLATED | Classified label-gated PR lane in doc; mux-soak: job still in ci.yml, not in nightly.yml |
| quarantine(D)/delete(E) entries invented | ✓ NOT VIOLATED | Doc explicitly states "EMPTY", coverage table shows none |
| per-PR coverage-% gate added | ✓ NOT VIOLATED | Coverage classified advisory telemetry; mix coveralls stays the gating test invocation |
| cancel-in-progress true for push:main | ✓ NOT VIOLATED | Expression false for non-pull_request |
| continue-on-error on package-consumer-full | ✓ NOT VIOLATED | 0 occurrences in block |
| continue-on-error on nightly Dialyzer / gcs-live | ✓ NOT VIOLATED | 0 actual YAML keys (the 5 grep hits are all comment text documenting their removal) |
| package-consumer-full in any needs list | ✓ NOT VIOLATED | absent from ci-summary.needs and ci-observability.needs |
| nightly.yml pull_request trigger | ✓ NOT VIOLATED | 0 occurrences |
| nightly-failure-issue permissions beyond issues:write | ✓ NOT VIOLATED | job-scoped `permissions: issues: write` only |
| eval_ci_summary.sh / setup_branch_protection.sh edited | ✓ NOT VIOLATED | both byte-unchanged |
| repo gate dropped from moved demo lanes | ✓ NOT VIOLATED | both retain `github.repository == 'szTheory/rindle' &&` composed with event gate |
| CONTRIBUTING/classification doc in Hex files allowlist | ✓ NOT VIOLATED | neither appears in mix.exs files: list |

### Requirements Coverage

| Requirement | Source Plan | Status | Evidence |
|-------------|-------------|--------|----------|
| LANE-01 | 106-02, 106-04 | ✓ SATISFIED | concurrency block (106-02) + demo-lane off-PR moves (106-04); REQUIREMENTS.md:64 [x], :143 Complete |
| LANE-02 | 106-03 | ✓ SATISFIED | package-consumer lean/full split; REQUIREMENTS.md:68 [x], :144 Complete |
| LANE-03 | 106-04 | ✓ SATISFIED | nightly.yml compat-matrix + Dialyzer + moved soak/live; REQUIREMENTS.md:72 [x], :145 Complete |
| LANE-04 | 106-01 | ✓ SATISFIED | classification doc + CONTRIBUTING label; REQUIREMENTS.md:75 [x], :146 Complete |

No orphaned requirements: all 4 IDs appear in PLAN frontmatter and are mapped to Phase 106 in REQUIREMENTS.md.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| ci.yml valid YAML | python3 yaml.safe_load | OK | ✓ PASS |
| nightly.yml valid YAML | python3 yaml.safe_load | OK | ✓ PASS |
| ci.yml line 1 | head -1 | `name: CI` | ✓ PASS |
| nightly.yml line 1 | head -1 | `name: Nightly` | ✓ PASS |
| release-coupling scripts unchanged | git diff --quiet | exit 0 | ✓ PASS |

GitHub Actions runtime execution (actual cancellation behavior, actual matrix fan-out, actual nightly schedule firing) cannot be exercised without pushing to GitHub — but all topology, triggers, concurrency expressions, needs-graph, and gate-coupling are statically correct and the expressions read only trusted contexts. This is the correct verification surface for a CI-topology phase.

### Anti-Patterns Found

None. No TBD/FIXME/XXX debt markers in any phase-modified file. The 5 `continue-on-error` grep hits in nightly.yml are all comment text documenting the removal of continue-on-error (gating semantics), not actual YAML keys.

### Prior Review Note

106-REVIEW.md: 0 Critical / 4 Warning (all RUNNING.md doc-accuracy, fixed in commit 5c30b7f "correct RUNNING.md CI-topology tables to match shipped trigger split (WR-01..04)") / 3 Info. All warnings confirmed resolved in the shipped RUNNING.md.

### Gaps Summary

No gaps. All 5 ROADMAP success criteria are observably true in the shipped workflows and docs. The trigger-split topology, concurrency semantics, package-consumer lean/full split, nightly lane, A–E classification, and every release-coupling invariant are correct. The headline wall-clock win is structurally delivered: representative signal stays on PR (lean image smoke, demo-unit proxy, deterministic MinIO-local proofs) while breadth (5-profile matrix + preflight + dry-run, Playwright E2E, Docker cold-start, compat matrix, Dialyzer, GCS/Mux soak) moves to push:main/nightly, with the release full-verification gate provably satisfied only by a push:main run that ran the full matrix.

---

_Verified: 2026-06-22_
_Verifier: Claude (gsd-verifier)_
