---
phase: 112-pr-main-gate-shift-left
plan: 02
subsystem: infra
tags: [ci, github-actions, e2e, gate, ci-yml, branch-protection, shift-left, gate-04]

# Dependency graph
requires:
  - phase: 112-pr-main-gate-shift-left
    plan: 01
    provides: "the lean adoption-demo-e2e-smoke ci.yml job (exists, runs on every PR, NOT yet in any needs:) + ADOPTION_DEMO_E2E_SPECS scoping"
  - phase: 110
    provides: "async-isolation de-flake (final de-flake phase that had to land before the lane could gate merges, GATE-04 precondition)"
provides:
  - "adoption-demo-e2e-smoke wired into ci-summary.needs + ci-observability.needs — the lean PR browser-render proxy is now merge-blocking TRANSITIVELY via the sole required `CI Summary` check"
  - "GATE shipped-artifact regression lock in ci_lane_split_test.exs (job exists, no repo/event if: gate, 2-spec subset excl screenshot, present in both needs lists)"
affects: [branch-protection, ci-summary-needs, gate-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "needs:-only gate wiring: a lean lane becomes merge-blocking purely by appearing in CI Summary.needs — eval_ci_summary.sh iterates to_entries[] of toJSON(needs), so no gate-script edit is ever needed (drift-proof)"
    - "Transitive single-context gating: a new lane is gated through the sole required `CI Summary` aggregate, never as a second required branch-protection context (setup_branch_protection.sh REQUIRED_CHECKS stays one entry)"
    - "Operator-gated load-bearing ordering (GATE-04): the wiring commit lands ONLY after a human confirms the de-flake phases + N=3 consecutive green push:main runs — preventing import of a live flake into the required gate"

key-files:
  created: []
  modified:
    - .github/workflows/ci.yml
    - test/install_smoke/ci_lane_split_test.exs

key-decisions:
  - "Smoke lane gated TRANSITIVELY via CI Summary.needs only — NOT added as a second required branch-protection context; setup_branch_protection.sh REQUIRED_CHECKS=(\"CI Summary\") stays the sole entry (T-112-06)"
  - "needs:-only edit — eval_ci_summary.sh + setup_branch_protection.sh byte-unchanged (git diff --exit-code returns 0); the drift-proof to_entries[] iteration auto-evaluates the new need (T-112-07)"
  - "Entry placed adjacent to adoption-demo-unit in both needs lists for readability (free placement among needs entries — order is non-semantic)"
  - "GATE meta-test asserts SHIPPED ci.yml topology only — no .planning/ path, no mutable @vX action tag; rides the already-required `quality` lane via default mix test (no new required check)"

patterns-established:
  - "needs:-only gate wiring against a drift-proof aggregate evaluator"
  - "GATE topology shipped-artifact lock (job-exists + no-skip-gate + in-both-needs) on the required quality lane"

requirements-completed: [GATE-01, GATE-03, GATE-04]

coverage:
  - id: D1
    description: "adoption-demo-e2e-smoke present in BOTH ci-summary.needs AND ci-observability.needs — merge-blocking transitively via CI Summary"
    requirement: "GATE-01"
    verification:
      - kind: automated
        ref: "grep both needs blocks; mix test ci_lane_split_test.exs GATE-01/GATE-04 'present in both needs' assertion passes"
        status: pass
    human_judgment: false
  - id: D2
    description: "Byte-frozen gate scripts unchanged: eval_ci_summary.sh + setup_branch_protection.sh git diff --exit-code returns 0; CI Summary remains the sole required context; no second required check"
    requirement: "GATE-03"
    verification:
      - kind: automated
        ref: "git diff --exit-code on both scripts (exit 0); setup_branch_protection.sh --print-expected shows exactly one context `CI Summary`; test_ci_summary_gate.sh 6/6 pass"
        status: pass
    human_judgment: false
  - id: D3
    description: "GATE-04 ordering: the needs wiring landed ONLY after the operator confirmed phases 108/109/110 complete + 3 consecutive green push:main `Adoption Demo E2E` runs"
    requirement: "GATE-04"
    verification:
      - kind: manual
        ref: "blocking-human checkpoint (Task 1) — operator returned APPROVED with both conditions confirmed before Task 2 commit 68046c6"
        status: pass
    human_judgment: true
  - id: D4
    description: "GATE shipped-artifact lock: smoke job exists, no repo/event if: gate (skip==pass safety), 2-spec subset excl screenshot spec, present in both needs lists — locked on the already-required quality lane"
    requirement: "GATE-01"
    verification:
      - kind: unit
        ref: "mix test test/install_smoke/ci_lane_split_test.exs — 17 tests, 0 failures (3 new GATE tests + 14 existing LANE/RELEASE-COUPLING)"
        status: pass
    human_judgment: false

# Metrics
duration: 2min
completed: 2026-06-28
status: complete
---

# Phase 112 Plan 02: PR↔main gate shift-left (needs-wiring half) Summary

**Wired the lean `adoption-demo-e2e-smoke` PR browser-render proxy into `ci-summary.needs` + `ci-observability.needs` — making it merge-blocking TRANSITIVELY through the sole required `CI Summary` check — and locked the GATE topology with a shipped-artifact meta-test, all behind the satisfied GATE-04 operator checkpoint, with both byte-frozen gate scripts proven unchanged.**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-06-28T22:11:25Z
- **Completed:** 2026-06-28T22:13:32Z
- **Tasks:** 3 (Task 1 = GATE-04 checkpoint, no commit; Tasks 2 & 3 committed atomically)
- **Files modified:** 2

## Accomplishments
- **Task 1 (GATE-04 checkpoint) — PASSED via operator approval.** This is the gate itself, not a code change. The operator confirmed (a) phases 108/109/110 landed and (b) accepted the 3+ consecutive green push:main `Adoption Demo E2E` evidence. No commit (the checkpoint is the deliverable).
- **Task 2 — needs wiring.** Added `- adoption-demo-e2e-smoke` to BOTH `ci-summary.needs` (adjacent to `adoption-demo-unit`) and `ci-observability.needs` (timing parity). This single edit makes the lane merge-blocking: `eval_ci_summary.sh` iterates `to_entries[]` of `toJSON(needs)`, so the new need is auto-evaluated (the lane never skips on PR, so it contributes real success/fail). Gated transitively — no second required branch-protection context added.
- **Task 3 — GATE shipped-artifact lock.** Added 3 GATE tests + 2 isolator helpers (`ci_observability_needs_block/1`, `adoption_demo_e2e_smoke_block/1`) to `ci_lane_split_test.exs`: smoke job exists; no `if: github.repository` / event gate (skip==pass safety); `ADOPTION_DEMO_E2E_SPECS` carries the 2-spec subset (`e2e/smoke.spec.js e2e/admin-console.spec.js`) excluding `admin-screenshots.spec.js`; lane present in BOTH needs lists. Rides the already-required `quality` lane (default `mix test`) — no new required check.

## Task Commits

Each task was committed atomically:

1. **Task 1: GATE-04 operator checkpoint** — no commit (the checkpoint is the gate, approved by operator).
2. **Task 2: Wire adoption-demo-e2e-smoke into ci-summary.needs + ci-observability.needs** — `68046c6` (feat)
3. **Task 3: Add the GATE shipped-artifact meta-test** — `ece0b2f` (test)

_Plan metadata commit follows this SUMMARY._

## Files Created/Modified
- `.github/workflows/ci.yml` — `- adoption-demo-e2e-smoke` appended to both `ci-summary.needs` and `ci-observability.needs` (2 insertions, no other change)
- `test/install_smoke/ci_lane_split_test.exs` — GATE section (3 tests) + `ci_observability_needs_block/1` and `adoption_demo_e2e_smoke_block/1` isolators (65 insertions)

## Decisions Made
- **Transitive gating only** — the lane is gated through `CI Summary.needs`, never as a second required branch-protection context. `setup_branch_protection.sh --print-expected` confirms `CI Summary` is still the sole required context (T-112-06).
- **needs:-only edit** — the two byte-frozen gate scripts (`eval_ci_summary.sh`, `setup_branch_protection.sh`) show `git diff --exit-code` = 0. The drift-proof `to_entries[]` iteration means no script edit was ever needed (T-112-07).
- **GATE test asserts shipped topology only** — no `.planning/` path, no mutable `@vX` action tag; the lock survives milestone archiving and rides the existing required `quality` lane.

## Deviations from Plan

None — plan executed exactly as written. No Rule 1-4 deviations were required.

## Verification Results
- `head -1 .github/workflows/ci.yml` is exactly `name: CI`; ci.yml filename untouched.
- `git diff --exit-code scripts/ci/eval_ci_summary.sh scripts/setup_branch_protection.sh` returns 0 (byte-frozen).
- `bash scripts/ci/test_ci_summary_gate.sh` — 6/6 pass (gate logic unchanged).
- `setup_branch_protection.sh --print-expected` — sole required context `CI Summary`.
- `package-consumer-full` still ABSENT from `ci-summary.needs` (existing LANE-02 refute still holds).
- `mix test test/install_smoke/ci_lane_split_test.exs` — 17 tests, 0 failures.
- Zero `lib/` change (`git status --short lib/` empty).
- `actionlint` exit 1 reflects the 7 PRE-EXISTING findings (lines 88/165/293/296/411/679, all in unrelated jobs) already logged to `deferred-items.md` by Plan 01 — the needs edit introduces zero new findings.

## Known Stubs
None.

## Next Phase Readiness
- GATE-01 (wiring half), GATE-03 (byte-frozen scripts / sole required context), and GATE-04 (operator-gated ordering) are complete. Combined with Plan 01's GATE-02, the PR↔main render-regression gap is closed: the lean browser-render proxy now blocks merges transitively via `CI Summary`.
- The lane will be observably green-on-PR on the next PR that runs `CI`; the GATE meta-test durably locks the topology against future drift.
- `name: CI`, the ci.yml filename, and both gate scripts are byte-unchanged. Zero `lib/` change.

## Self-Check: PASSED

- Files: `.github/workflows/ci.yml` and `test/install_smoke/ci_lane_split_test.exs` confirmed modified on disk.
- Commits: `68046c6`, `ece0b2f` confirmed in git log.

---
*Phase: 112-pr-main-gate-shift-left*
*Completed: 2026-06-28*
