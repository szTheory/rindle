---
phase: 103-observability-baseline
plan: 04
subsystem: ci-tooling
tags: [ci, observability, baseline, branch-protection, drift, internal-doc, gh-api]

requires:
  - phase: 103-02
    provides: scripts/ci/collect_ci_baseline.sh + scripts/ci/check_required_checks.sh (read-only OBS-03 collectors)
provides:
  - .planning/phases/103-observability-baseline/103-BASELINE.md (committed internal OBS-03 baseline)
  - Frozen pre-restructuring per-job avg/p95 + rerun-rate table over last 50 main ci.yml runs
  - Verbatim live branch-protection required-check .contexts[] (12 contexts) + expected-vs-live diff
  - Recorded brandbook-tokens drift (expected-only, absent live) — recorded, not fixed
affects: [Phase 105 (aggregate-check flip), Phase 107 (regression-vs-baseline check)]

tech-stack:
  added: []
  patterns:
    - "gh api --paginate inline --jq applies filters/slices PER PAGE; use --paginate --slurp + a single flatten/slice jq pass for window-bounded results"
    - "OBS-03 capture is read-only: live drift is recorded verbatim, never re-applied (D-09/D-14)"
    - "Internal baseline docs live in .planning/ only; never added to mix.exs files:/extras (D-10)"

key-files:
  created:
    - .planning/phases/103-observability-baseline/103-BASELINE.md
  modified:
    - scripts/ci/collect_ci_baseline.sh

key-decisions:
  - "Fixed a real --paginate per-page slice bug in the Plan 02 collector (Rule 1) before capturing — the rerun rate was rendering as a malformed multi-array stream (8\\n0/50\\n20) on live >1-page data; switched to --paginate --slurp + single jq pass (now 8/50)."
  - "Recorded the Mux Soak inverted-timestamp row (avg -252) and the transient gh 401 verbatim as data-quality notes rather than smoothing them away — Phase 107 reads an honest reference."
  - "brandbook-tokens drift recorded verbatim (expected per setup_branch_protection.sh:30, absent from live .contexts[]); NOT fixed (D-09/D-14)."

patterns-established:
  - "Pattern: capture OBS-03 baseline before ANY restructuring (D-11); the doc is the input to the Phase 105 flip + Phase 107 regression check."
  - "Pattern: live required-check read re-run immediately before capture (no stale snapshot) per 103-VALIDATION.md Manual-Only."

requirements-completed: [OBS-03]

duration: 9min
completed: 2026-06-20
status: complete
---

# Phase 103 Plan 04: OBS-03 CI Baseline Capture Summary

**Committed internal `103-BASELINE.md` freezing the pre-restructuring CI reference: per-job avg/p95 + 8/50 rerun rate over the last 50 `main` runs, the verbatim 12 live branch-protection required-check contexts, and the recorded (not fixed) `brandbook-tokens` expected-only drift.**

## Performance

- **Duration:** ~9 min
- **Started:** 2026-06-20T19:22:00Z (approx)
- **Completed:** 2026-06-20T19:31:00Z (approx)
- **Tasks:** 2
- **Files modified:** 2 (1 created, 1 fixed)

## Accomplishments

- Ran both Plan 02 read-only collectors live against `szTheory/rindle@main` using the maintainer's authed `gh` session (account `szTheory`, scope `repo`).
- Captured the verbatim 12 live required-check `.contexts[]` and the expected-vs-live diff (`brandbook-tokens` expected-only) immediately before authoring — re-verified per 103-VALIDATION.md.
- Authored and committed `103-BASELINE.md` (internal `.planning/` only) with the timing table, rerun rate, live required checks, recorded drift, and the Phase 105/107 consumer map.
- Fixed a real pagination bug in `collect_ci_baseline.sh` (Rule 1) that corrupted the rerun rate on live multi-page data.
- Confirmed zero `lib/` change and that `103-BASELINE.md` is excluded from the Hex `files:` allowlist and HexDocs `extras` (mix.exs byte-unchanged).

## Task Commits

1. **Task 1: Re-verify live state + capture required-check + timing baseline** (collector fix) — `83f224b` (fix)
2. **Task 2: Author and commit 103-BASELINE.md (internal-only)** — `2488a04` (docs)

**Plan metadata:** (this SUMMARY + STATE/ROADMAP) — committed separately as the final docs commit.

## Files Created/Modified

- `.planning/phases/103-observability-baseline/103-BASELINE.md` — NEW internal OBS-03 baseline: capture header, per-job avg/p95 + 8/50 rerun table, data-quality notes, verbatim live required checks, expected-vs-live diff with recorded `brandbook-tokens` drift, and the Phase 105/107 consumer map.
- `scripts/ci/collect_ci_baseline.sh` — fixed `--paginate` per-page slice bug (see deviations).

## Decisions Made

- **Honest capture over clean numbers.** The live data has two real artifacts: a `Mux Soak (real API)` row with a negative avg (`-252`, inverted `completed_at`/`started_at` on cancelled soak attempts) and a one-time transient `gh: Bad credentials (HTTP 401)` during an earlier pagination pass. Both are recorded verbatim in the baseline's data-quality notes (with guidance for Phase 107 to exclude inverted rows), rather than smoothed away. This honors the milestone constraint: do not fabricate metrics.
- **Drift recorded, not fixed.** `brandbook-tokens` is in the expected list (`setup_branch_protection.sh:30`) but absent from the live required `.contexts[]`. Per D-09/D-14 it is captured verbatim and deliberately left unreconciled — that capture is the point of OBS-03 and the input to the Phase 105 flip.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `--paginate` per-page `--jq` slice corrupted the rerun rate on live data**
- **Found during:** Task 1 (running `collect_ci_baseline.sh` live)
- **Issue:** `gh api --paginate` with an inline `--jq "[...] | .[:N]"` applies the filter and the `.[:N]` slice **per page**, emitting one JSON array per page. With `main` having >1 page of `ci.yml` runs, `jq 'length'` and the rerun selector ran over a stream of two arrays — the rerun rate rendered as the malformed `8\n0/50\n20` (page-1 then page-2 counts), and per-job `runs` counts exceeded the 50-run window (e.g. 67).
- **Fix:** Switched the runs listing to `gh api --paginate --slurp` (one array-of-pages) piped to a separate `jq "[.[].workflow_runs[] | {...}] | .[:N]"` pass that flattens and slices exactly once. Rerun rate now renders correctly as `8/50`; the window is bounded to 50 runs.
- **Files modified:** `scripts/ci/collect_ci_baseline.sh`
- **Verification:** `bash -n` PASS, `shellcheck` CLEAN; live re-run produced `Rerun rate (last 50 main runs): 8/50` and exactly 50 run ids. Read-only, no `lib/` change.
- **Committed in:** `83f224b` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug).
**Impact on plan:** The fix was necessary for OBS-03 correctness — the baseline's rerun rate would otherwise be a malformed multi-line artifact and Phase 107's regression reference would read garbage. The fix is read-only tooling under `scripts/ci/` (not `lib/`), staying within the v1.20 ZERO-lib-change constraint. No scope creep.

## Issues Encountered

- **Transient `gh: Bad credentials (HTTP 401)` mid-pagination (once).** The per-jobs loop tolerates per-call failures (`|| true`), so one transient 401 briefly leaked GitHub error-JSON rows into an earlier table render. A clean re-run produced the authoritative table with no such rows; the incident is recorded in the baseline's data-quality notes. No fabricated values were used.
- **`gh` auth was available** (account `szTheory`, scope `repo`) so the VALIDATION.md "maintainer-local manual run" fallback was not needed — the live capture ran in this environment.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- OBS-03 is captured and committed **before any restructuring** (D-11). Phase 105 (aggregate-required-check flip) can read the verbatim live `.contexts[]` and must deliberately reconcile the recorded `brandbook-tokens` drift. Phase 107 (regression-vs-baseline) has a frozen avg/p95 reference (excluding the inverted `Mux Soak` row per the recorded data-quality guidance).
- No blockers. Zero `lib/` change; the baseline doc stays internal to `.planning/` (excluded from the shipped Hex package; mix.exs byte-unchanged).

## Self-Check: PASSED

- FOUND: .planning/phases/103-observability-baseline/103-BASELINE.md
- FOUND: commit 83f224b (Task 1 — collector fix)
- FOUND: commit 2488a04 (Task 2 — baseline doc)
- VERIFIED: mix.exs does not reference 103-BASELINE (Hex files:/extras byte-unchanged)
- VERIFIED: no lib/ change in this plan

---
*Phase: 103-observability-baseline*
*Completed: 2026-06-20*
