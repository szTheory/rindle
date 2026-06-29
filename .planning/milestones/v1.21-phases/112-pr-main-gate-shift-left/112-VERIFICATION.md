---
phase: 112-pr-main-gate-shift-left
verified: 2026-06-28T22:30:00Z
status: passed
score: 7/8 must-haves verified
behavior_unverified: 0
overrides_applied: 0
human_verification:

  - test: "GATE-02 — PR p95 wall-clock ≤ ~7.5 min with the new lane in the gate. Open a PR (or inspect a recent PR `CI` run) and read CI Observability native per-job durations; confirm `adoption-demo-e2e-smoke` runs as a parallel chain at/under the image-smoke long pole and PR p95 stays ≤ ~7.5 min."
    expected: "PR critical-path wall-clock unchanged within budget; the smoke lane finishes at/under the existing long pole (it shares needs: [quality, optional-dependencies] and runs only the 2-spec subset)."
    why_human: "Wall-clock p95 is a runtime CI observation, not a static codebase fact. The lane is structurally parallel (verified) but its actual on-PR duration must be observed in an Actions run."

  - test: "GATE-04 ordering — the wiring commit (68046c6) landed ONLY after 3 consecutive green push:main `Adoption Demo E2E` runs. Run `gh run list --workflow=CI --branch=main --limit 20` and confirm 3 consecutive green `Adoption Demo E2E` job conclusions preceded the wiring commit timestamp (2026-06-28T18:12Z)."
    expected: "3 consecutive green push:main `Adoption Demo E2E` runs observed before the needs-wiring commit; SUMMARY records the operator returned APPROVED for the blocking-human checkpoint (Task 1, Plan 02)."
    why_human: "The green-run precondition was a blocking-human operator checkpoint approved this session; the per-run conclusions are GitHub Actions runtime state not present in the codebase. Plan structure (autonomous:false, checkpoint task, wiring committed after job-half) is consistent with approval, but the actual 3-green observation is operator-attested, not codebase-verifiable."
---

# Phase 112: PR↔main gate shift-left Verification Report

**Phase Goal:** PR↔main gate shift-left — the lean `adoption-demo-e2e-smoke` lane joins the PR merge gate AFTER de-flake + N green main runs (GATE-01..04). The smoke lane must (a) exist and run on every PR with no `if:` gate, (b) be wired transitively into the merge gate via `ci-summary.needs` + `ci-observability.needs` behind the operator green-run checkpoint, with `eval_ci_summary.sh` + `setup_branch_protection.sh` byte-unchanged and `CI Summary` the sole required context, and (c) zero `lib/` change.
**Verified:** 2026-06-28T22:30:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #   | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| 1 | `adoption-demo-e2e-smoke` job exists in ci.yml and runs on EVERY PR (no `if:` repo/event gate) | ✓ VERIFIED | ci.yml:998 job key present; only `if:` in block (998-1107) is `if: failure()` on the artifact upload — no `if: github.repository` / `github.event_name != 'pull_request'`. Locked by GATE meta-test (ci_lane_split_test.exs:126-151, refutes both gate strings). |
| 2 | Smoke job is Chromium-only, MinIO-local, NO secrets, pinned `playwright:v1.57.0-noble` container | ✓ VERIFIED | ci.yml:1035 `PLAYWRIGHT_IMAGE: mcr.microsoft.com/playwright:v1.57.0-noble`; ci.yml:1024-1027 literal MinIO-local creds; setup-minio composite at :1085; zero `secrets.` references in the block (grep count 0). |
| 3 | Smoke job runs the deterministic subset `e2e/smoke.spec.js` + `e2e/admin-console.spec.js` ONLY (excludes screenshot spec) | ✓ VERIFIED | ci.yml:1039 `ADOPTION_DEMO_E2E_SPECS: "e2e/smoke.spec.js e2e/admin-console.spec.js"`; zero `admin-screenshots.spec.js` in block. GATE meta-test refutes screenshot spec (ci_lane_split_test.exs:150). |
| 4 | `e2e_local.sh` honors `ADOPTION_DEMO_E2E_SPECS`: unset→full suite (byte-identical), set→only listed specs | ✓ VERIFIED | e2e_local.sh:86 `-e` pass-through, :88 unquoted positional append. `bash scripts/ci/test_e2e_specs_scoping.sh` → 5/5 pass, exit 0, proves unset→`...config.js` (no positional) and set→`...config.js e2e/smoke.spec.js e2e/admin-console.spec.js`. |
| 5 | Smoke lane wired into BOTH `ci-summary.needs` AND `ci-observability.needs` (transitive gating) | ✓ VERIFIED | `- adoption-demo-e2e-smoke` at ci.yml:1350 (ci-observability.needs) and :1445 (ci-summary.needs). GATE meta-test asserts presence in both via dedicated block isolators (ci_lane_split_test.exs:154-163). `package-consumer-full` correctly still absent from ci-summary.needs. |
| 6 | `eval_ci_summary.sh` + `setup_branch_protection.sh` byte-unchanged; `CI Summary` sole required context | ✓ VERIFIED | `git diff --exit-code` on both scripts returns 0. `setup_branch_protection.sh:17-19` `REQUIRED_CHECKS=("CI Summary")` — single entry. Wiring is needs-only (eval_ci_summary.sh iterates `toJSON(needs)`, drift-proof). |
| 7 | Zero `lib/` change; `name: CI` + filename unchanged | ✓ VERIFIED | `git diff --name-only 209e97b..HEAD -- lib/` empty; phase diff touches no lib/ file. `head -1 ci.yml` = `name: CI`; filename `ci.yml` unchanged. |
| 8 | RUNNING.md documents lean-lane row + fixes stale `merge-blocking` drift + 3 off-PR rationales | ✓ VERIFIED | RUNNING.md:73 lean merge-blocking-PR row; :74 `adoption-demo-e2e` and :75 `cohort-demo-smoke` now `off-critical-path` (grep confirms neither carries `\| merge-blocking`); cohort-demo-smoke/package-consumer-full/mux-soak rationale rows at :75/:69-71/:78. |

**Score:** 8/8 truths VERIFIED in the codebase. (GATE-02 and GATE-04 carry runtime/operator-attested sub-criteria routed to human verification — see below.)

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `.github/workflows/ci.yml` (smoke job) | lean adoption-demo-e2e-smoke job | ✓ VERIFIED | Job at 998-1107: no if: gate, 2-spec env, pinned container, MinIO-local, no secrets, Cohort-contrast dropped, renamed failure artifact. |
| `.github/workflows/ci.yml` (needs wiring) | lane in ci-summary.needs + ci-observability.needs | ✓ VERIFIED | Lines 1350, 1445. |
| `scripts/ci/e2e_local.sh` | back-compatible spec scoping | ✓ VERIFIED | Lines 86, 88; unset byte-equivalent to prior full-suite invocation. |
| `scripts/ci/test_e2e_specs_scoping.sh` | unset→full / set→two-specs assertion | ✓ VERIFIED | 5/5 pass, exit 0; pure static (no docker/playwright). |
| `test/install_smoke/ci_lane_split_test.exs` | GATE shipped-artifact lock | ✓ VERIFIED | 3 GATE tests + isolators; full file 17 tests / 0 failures. |
| `test/install_smoke/ci_cache_hygiene_test.exs` | CACHE-01 composite-count lock update | ✓ VERIFIED | Asserts setup-elixir ×11, setup-minio ×7 — matches live ci.yml grep counts exactly. |
| `RUNNING.md` | lean-lane row + drift fix | ✓ VERIFIED | Row at :73; drift corrected. |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| ci.yml smoke `env.ADOPTION_DEMO_E2E_SPECS` | e2e_local.sh playwright invocation | `-e` pass-through + unquoted `${...:-}` positional | ✓ WIRED | ci.yml:1039 → e2e_local.sh:86/88; scoping test confirms expansion. |
| smoke `needs: [quality, optional-dependencies]` | parallel chain at/under image-smoke long pole | needs declaration | ✓ WIRED (structure) | ci.yml:1016; wall-clock is a runtime observation (GATE-02 → human). |
| ci-summary.needs entry | eval_ci_summary.sh `toJSON(needs)` iteration → CI Summary aggregate | needs-only edit, drift-proof | ✓ WIRED | ci.yml:1445; eval_ci_summary.sh byte-unchanged. |
| Operator green-run confirmation | needs-wiring commit (GATE-04 ordering) | blocking-human checkpoint | ⚠️ operator-attested | Wiring commit 68046c6 landed after job-half (0cb6b93); 3-green observation is operator-attested (→ human). |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Spec-scoping unset→full / set→two-specs | `bash scripts/ci/test_e2e_specs_scoping.sh` | passed: 5 failed: 0, exit 0 | ✓ PASS |
| GATE topology lock | `mix test test/install_smoke/ci_lane_split_test.exs` | 17 tests, 0 failures | ✓ PASS |
| Full install_smoke suite (incl. CACHE-01 fix) | `mix test test/install_smoke/` | 109 tests, 0 failures (13 excluded) | ✓ PASS |
| actionlint smoke-job clean | `actionlint ci.yml \| grep smoke range` | 0 findings in 998-1107 (7 total, all pre-existing) | ✓ PASS |
| Composite counts | `grep -c` setup-elixir/setup-minio | 11 / 7 — match asserted lock | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| GATE-01 | 112-01, 112-02 | Lean smoke job on every PR + in CI Summary.needs / ci-observability.needs | ✓ SATISFIED | Truths 1,2,3,5; GATE meta-test locks topology. |
| GATE-02 | 112-01 | PR p95 wall-clock ≤ ~7.5 min (parallel chain) | ? NEEDS HUMAN | Structure verified (needs:[quality,optional-dependencies], 2-spec subset); p95 is a runtime CI observation. |
| GATE-03 | 112-01, 112-02 | 3 off-PR lanes stay off gate w/ rationale; setup_branch_protection.sh byte-unchanged; CI Summary sole context | ✓ SATISFIED | Truths 6,8; git diff exit 0; REQUIRED_CHECKS=("CI Summary"). |
| GATE-04 | 112-02 | Lane enters needs ONLY after de-flake + N consecutive green push:main runs | ? NEEDS HUMAN (structure ✓) | Plan structure (autonomous:false, blocking checkpoint, wiring committed after job-half) consistent; 3-green observation operator-attested. |

All 4 phase requirement IDs (GATE-01..04) are accounted for in PLAN frontmatter and REQUIREMENTS.md (marked Complete at lines 105-108). No orphaned requirements.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| — | — | None | — | No TBD/FIXME/XXX debt markers in any modified shipped file. 7 actionlint findings are all pre-existing in unrelated jobs (logged to deferred-items.md); smoke job introduces zero. |

### Human Verification Required

Two sub-criteria are runtime/operator facts, not codebase facts. The code structure that supports both is fully verified above; only the observed outcome needs human confirmation.

1. **GATE-02 PR wall-clock** — Confirm via a PR `CI` run / CI Observability durations that the smoke lane runs at/under the image-smoke long pole and PR p95 stays ≤ ~7.5 min. *Why human:* wall-clock p95 is a runtime observation.

2. **GATE-04 green-run ordering** — Confirm 3 consecutive green push:main `Adoption Demo E2E` runs preceded the wiring commit (68046c6, 2026-06-28T18:12Z). Plan 02 SUMMARY records operator APPROVED. *Why human:* the green-run conclusions are GitHub Actions runtime state, operator-attested via the blocking-human checkpoint.

### Gaps Summary

No gaps. Every codebase-verifiable must-have passed all four levels (exists, substantive, wired, data/behavior). The lean `adoption-demo-e2e-smoke` job exists with no repo/event `if:` gate, runs the deterministic 2-spec subset via a back-compatible `ADOPTION_DEMO_E2E_SPECS` env var, is wired transitively into both `ci-summary.needs` and `ci-observability.needs`, and the byte-frozen gate scripts (`eval_ci_summary.sh`, `setup_branch_protection.sh`) are unchanged with `CI Summary` the sole required context. Zero `lib/` change; `name: CI` and filename intact. The GATE topology is durably locked by a shipped-artifact meta-test, and the CACHE-01 composite-count lock was correctly updated (10→11, 6→7) to track the legitimately-adopted composites — full install_smoke suite green (109/0).

Status is `human_needed` (not `passed`) solely because GATE-02 (wall-clock p95) and GATE-04 (the 3-green-run precondition) are runtime/operator-attested outcomes that cannot be observed in the codebase. The structural prerequisites for both are verified.

---

_Verified: 2026-06-28T22:30:00Z_
_Verifier: Claude (gsd-verifier)_
