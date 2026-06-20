# Phase 103 — OBS-03 CI Baseline (pre-restructuring reference)

> **Internal `.planning/` document — NOT shipped.** This file is not in the Hex
> `files:` allowlist nor the HexDocs `extras` list (mix.exs:154-172, :278-279), so
> it never enters the published package (D-10, threat T-103-11).
>
> **This is the frozen pre-restructuring OBS-03 baseline (D-11).** It is the
> load-bearing input to the **Phase 105** aggregate-required-check flip and the
> **Phase 107** regression-vs-baseline check. It is captured **before any v1.20
> pipeline restructuring change**. Live drift below is **recorded verbatim, not
> fixed** (D-09 / D-14, threat T-103-10).

## Capture Header

| Field | Value |
|-------|-------|
| Repo | `szTheory/rindle` |
| Branch | `main` |
| Captured (UTC) | 2026-06-20 |
| Captured by | maintainer authed `gh` session (account `szTheory`, scopes incl. `repo`) |
| `gh` version | 2.94.0 |
| Run window (N) | last 50 `ci.yml` runs (`BASELINE_RUNS=50`, `BASELINE_BRANCH=main`) |
| Collectors | `scripts/ci/collect_ci_baseline.sh`, `scripts/ci/check_required_checks.sh` (Plan 02, read-only) |

Both collectors are the read-only Plan 02 scripts. The required-check read was
re-run **immediately before** this capture per `103-VALIDATION.md` §
"Manual-Only Verifications" (branch protection can drift between runs).

---

## 1. Per-job timing baseline (avg + p95) + rerun rate

Captured via `bash scripts/ci/collect_ci_baseline.sh` (defaults: `main`, last 50
runs). Durations are derived from each job's `started_at`/`completed_at`; the
rerun rate is derived from `run_attempt`/`previous_attempt_url` (no `rerun_count`
field exists — 103-RESEARCH.md Pitfall 2).

**Rerun rate (last 50 `main` runs): 8/50**

| Job | runs | avg(s) | p95(s) |
| --- | ---: | ---: | ---: |
| Package Consumer GCS Live Proof | 47 | 20 | 31 |
| brandbook-tokens | 7 | 36 | 59 |
| Cohort Demo Smoke | 8 | 105 | 176 |
| Contract | 47 | 38 | 61 |
| Quality (1.15, 26) | 47 | 140 | 184 |
| ADMIN-06 Optional Dependencies (1.15, 26) | 12 | 70 | 134 |
| Adopter | 47 | 58 | 105 |
| Adoption Demo E2E | 23 | 160 | 318 |
| Proof | 47 | 36 | 58 |
| Package Consumer Proof Matrix + Release Preflight | 47 | 550 | 887 |
| Adoption Demo Unit | 8 | 92 | 154 |
| GCS Soak (real bucket) | 47 | 19 | 29 |
| Integration | 46 | 60 | 96 |
| Mux Soak (real API) | 47 | -252 | 0 |
| ADMIN-06 Optional Dependencies (1.17, 27) | 12 | 70 | 120 |
| Quality (1.17, 27) | 47 | 130 | 166 |

### Data-quality notes (recorded verbatim, not smoothed)

These are **real artifacts of the live capture** and are kept as-is so Phase 107's
regression check reads against an honest reference, not a hand-cleaned one:

- **`Mux Soak (real API)` avg(s) = -252 / p95(s) = 0.** Negative duration means some
  sampled job records have `completed_at < started_at` — the live "real API soak"
  jobs include cancelled/skipped attempts whose GitHub timestamps invert. Treat
  this row as **non-meaningful for timing**; it documents the soak job's presence
  in the window, not a real duration. (Phase 107 should exclude inverted-timestamp
  rows or floor at 0 when comparing.)
- **Variable `runs` per job (7–47, not a flat 50).** Some jobs are matrix/conditional
  legs (e.g. `ADMIN-06 …` 12, `Cohort Demo Smoke` 8, `Adoption Demo Unit` 8,
  `brandbook-tokens` 7) and only fire on a subset of the 50 runs. This is expected.
- **Transient `gh: Bad credentials (HTTP 401)` during one earlier pagination pass.**
  The per-jobs loop tolerates per-call failures (`|| true`), so one transient 401
  briefly leaked GitHub error-JSON rows into a prior table. The capture above is a
  **clean re-run** with no such rows. (The collector's `--paginate` per-page slice
  bug was also fixed under this plan — see Plan 04 SUMMARY deviations.)
- **`brandbook-tokens` ran 7 times** here yet is **absent from the live required
  checks** (§2) — it executes as a non-required job today. This corroborates the
  recorded drift below.

---

## 2. Live branch-protection required checks (verbatim)

Captured via `bash scripts/ci/check_required_checks.sh main`. This is a **read-only**
GET of `.../branches/main/protection/required_status_checks` `.contexts[]` (legacy
flat shape, 103-RESEARCH.md Pitfall 3). **No mutation occurred** (D-09 / D-14,
threat T-103-10).

### Live required status checks (`szTheory/rindle@main`)

```
  - ADMIN-06 Optional Dependencies (1.15, 26)
  - ADMIN-06 Optional Dependencies (1.17, 27)
  - Adopter
  - Adoption Demo E2E
  - Adoption Demo Unit
  - Cohort Demo Smoke
  - Contract
  - Integration
  - Package Consumer Proof Matrix + Release Preflight
  - Proof
  - Quality (1.15, 26)
  - Quality (1.17, 27)
```

(12 live required contexts.)

---

## 3. Expected-vs-live diff + recorded drift

The expected list is sourced (not re-encoded) from
`scripts/setup_branch_protection.sh --print-expected-json` (single source of
truth, D-09). Verbatim `diff <(expected) <(live)` output:

```
## Diff vs setup_branch_protection.sh expected (< expected-only / > live-only):
13d12
< brandbook-tokens
```

### Recorded drift (NOT fixed)

- **`brandbook-tokens` — expected-only, absent from live `.contexts[]`.**
  It is listed in `scripts/setup_branch_protection.sh` (the expected required-check
  set, line 30) but is **not** a live required status check on `main` today. This is
  the known live drift identified in 103-RESEARCH.md § "OBS-03 live required-check
  diff". Per D-09 / D-14 it is **recorded here verbatim and deliberately NOT
  re-applied** — capturing it is the whole point of OBS-03. The corollary (§1) is
  that `brandbook-tokens` still **runs** as a job (7 runs in the window) but does not
  **gate** merges.
- No live-only checks (no `>` lines): every live required context is in the expected
  set.

---

## 4. Downstream consumers of this baseline

| Phase | What it reads from here |
|-------|-------------------------|
| **Phase 105** (aggregate required check flip) | The verbatim live `.contexts[]` in §2 — the exact pre-change required gate to preserve/replace. The `brandbook-tokens` drift (§3) must be reconciled deliberately, not silently. |
| **Phase 107** (regression vs baseline) | The avg/p95 table in §1 as the frozen pre-restructuring timing reference (excluding the inverted `Mux Soak` row per the data-quality notes). |

This baseline is captured **before any restructuring change** (D-11). No
branch-protection mutation occurred; this document lives only in `.planning/` and
is excluded from the shipped Hex package.
