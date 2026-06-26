# Phase 106 — LANE-04 Test-Value Classification (A–E buckets)

> **Internal `.planning/` document — NOT shipped.** Like the Phase-103 baseline,
> this file is not in the Hex `files:` allowlist nor the HexDocs `extras` list, so
> it never enters the published package. It is a maintainer-facing record.

## What this is

This is the **LANE-04 test-value classification** that backs every lane placement in
Phase 106. The milestone's headline cut (PR CI 15→≤7 min) is achieved by splitting CI
work **by trigger**: only *representative* signal stays on the PR critical path; release
*breadth* moves to `push:main` / nightly / release. To keep that defensible (not a
quality regression), every current `ci.yml` lane is placed into exactly **one** of five
buckets with a one-line rationale citing the governing decision id (D-01..D-20 from
`106-CONTEXT.md`) and, where relevant, the Phase-103 wall-clock evidence
(`103-BASELINE.md` §1).

The classification is the conceptual spine the three workflow-YAML plans implement:
**106-02** (PR-lane concurrency + `package-consumer` split), **106-03** (the new
`nightly.yml`), and **106-04** (Dialyzer ownership + lane-severity reconciliation). This
plan (106-01) touches **no** workflow YAML — it is the "why" record only.

**Governing model (D-01):** the **Tokio model** — a representative gate on PR, breadth
post-merge / nightly — NOT the Ecto/Oban/Phoenix model (full matrix on every PR).
Rindle's lane-cost profile (install-smoke matrix, Playwright browser E2E, Docker
cold-start) is unlike a pure lib's (compile + ExUnit), so the representative-gate
deviation is the right one and is well-precedented at the top of OSS.

**Trust/speed framing (LANE-04):** moving a lane off PR does not delete its signal — it
re-homes the *trigger*. A regression in a moved lane is caught on `main` within **one
merge** (it blocks the *next* merge, not the innocent author), and the full
release-verification gate always runs, provably, before any Hex publish (D-11). The
copy-pasteable contributor statement of this tradeoff lives in `CONTRIBUTING.md`.

**Five buckets used (no quarantine/delete):** A = keep on PR, B = optimize, C =
move-to-nightly, plus a distinct **label-gated PR lane** bucket and an
**off-critical-path** bucket. **No quarantine (D) or delete (E) entries were
identified** — see "Buckets D & E" below; do not invent one.

---

## Bucket A — keep (merge-blocking, stays on every PR)

These are deterministic, MinIO-local (no third-party), highest "expensive-to-discover-
late" value per second. They are the representative gate. Wall-clock note: PR jobs fan
out after `quality` + `optional-dependencies`, so PR wall-clock ≈ the longest single
chain (~7.2 min p95 / ~5 min avg), not the sum (D-02).

| Lane (`ci.yml` job) | Rationale | Decision / baseline |
|---------------------|-----------|---------------------|
| `quality` (both cells: 1.15/26 + 1.17/27) | Compile (warnings-as-errors) + full ExUnit suite via `mix coveralls` on both supported cells — the core behavior gate. | D-02; 140s avg/184s p95 (1.15) · 130s/166s (1.17) |
| `optional-dependencies` (both cells) | ADMIN-06: `deps.get --no-optional` + `compile --no-optional --warnings-as-errors`; cheap, catches optional-dep coupling regressions. | D-02; 70s avg/134s p95 |
| `integration` | Lifecycle + MinIO adapter tests; deterministic, storage-real, no third-party. NON-NEGOTIABLE on PR. | D-03; 60s avg/96s p95 |
| `contract` | AV hygiene gate + contract tests; deterministic. NON-NEGOTIABLE on PR. | D-03; 38s avg/61s p95 |
| `proof` | docs-parity, adoption-proof drift gate, batch-owner-erasure mix proof; Postgres-only, deterministic. NON-NEGOTIABLE on PR. | D-03; 36s avg/58s p95 |
| `adopter` | Canonical adopter lifecycle proof; deterministic, the headline adopter contract. NON-NEGOTIABLE on PR. | D-03; 58s avg/105s p95 |
| `adoption-demo-unit` | Browser-free admin-console mount + brand + lifecycle render — the PR-side proxy for the moved `adoption-demo-e2e` (D-04). | D-02/D-04; 92s avg/154s p95 |
| `brandbook-tokens` | PIPE-01 token→CSS drift gate; fast, deterministic, repo-only. | D-02; 36s avg/59s p95 |
| `package-consumer` (scoped: `image`-only install-smoke + version-alignment) | The single representative consumer path on PR; the 5→1 profile cut is THE load-bearing wall-clock win. | D-02/D-08/D-10; replaces the 550s avg/887s p95 long pole |
| `ci-summary` (`CI Summary`) | The sole required aggregate check (Phase 105); `needs:` all gating PR jobs, skip==pass. | D-02; 105 D-05/D-06 |

> `ci-observability` and `ci-script-tests` are non-gating helper/self-test jobs that
> stay on PR by nature (they observe/test the pipeline itself); they are not
> merge-blocking lanes and are not in `CI Summary.needs`. Listed here for completeness —
> they are kept, unchanged.

---

## Bucket B — optimize (kept, but restructured for parallelism/ownership)

These lanes keep their signal but change *shape* so the heavy work stops sitting on the
PR critical path.

| Lane | Optimization | Decision / baseline |
|------|--------------|---------------------|
| `package-consumer` install-smoke (the 5 profiles: video/image/tus/mux/gcs) | **Matrixify** into a new `package-consumer-full` job (`strategy.matrix.profile`, `fail-fast: false`) so the five proofs run in parallel off-PR (wall-clock ≈ slowest profile, not 5× serial); the lean `image`-only representative stays on PR (Bucket A). No `continue-on-error` anywhere on the full lane (would mask leg failures from the run conclusion). | D-08/D-10; the 550s avg/**887s p95** long pole is the thing being removed from PR |
| Dialyzer (today: advisory step inside `quality`, `continue-on-error`) | **Extract** into a dedicated owned `Dialyzer` job (moves to nightly per Bucket C). Removing it from `quality` shrinks the PR long pole; ownership stops the 11-entry `.dialyzer_ignore.exs` + warning set from rotting. | D-17; quality step at `ci.yml:195-228` |

---

## Bucket C — move-to-nightly (off the PR critical path, into a new `nightly.yml`)

A **separate** `.github/workflows/nightly.yml` with `name: Nightly` (D-12 — a `schedule:`
trigger on `ci.yml` is disqualifying: it would fire `release-please-automerge.yml`'s
`workflows:[CI]` + `head_branch=='main'` listener on a cron tick and could auto-merge a
Release Please PR + dispatch `release.yml`). The nightly lane is **advisory** — it must
never become a required PR check.

| Lane | Rationale | Decision / baseline |
|------|-----------|---------------------|
| broad OTP×Elixir `compat-matrix` (curated ~6-cell diagonal, NOT cartesian) | Breadth confidence across the support window incl. both sides of the OTP-27 polyfill branch (`mix.exs:142-144`); cartesian is an explicit milestone anti-feature. | D-13 |
| `gcs-soak` (real bucket) | Real-API soak; live third-party — a provider outage must never block a merge. Keeps `if: github.repository == 'szTheory/rindle'`. | D-14; 19s avg/29s p95 (timing non-load-bearing; it is secret-gated) |
| `package-consumer-gcs-live` | Live GCS install-smoke; moved to nightly and **drops `continue-on-error`** so it becomes a real signal (the 105 D-04 masking trap, retired). | D-14; 20s avg/31s p95 |
| owned **`Dialyzer`** lane (gating in nightly) | Extracted from `quality` (Bucket B) and run WITHOUT `continue-on-error` in nightly — a real type-contract regression or ignore-file drift fails the nightly lane. Removed from PR entirely; `CI Summary` does NOT `needs:` it. | D-17/D-18; PLT key per D-20 |

---

## Bucket "label-gated PR lane" — `mux-soak` ONLY (explicitly NOT nightly)

| Lane | Rationale | Decision |
|------|-----------|----------|
| `mux-soak` (real Mux API) | **Stays in `ci.yml`** as a label-gated PR lane (`if: contains(...labels..., 'streaming')`). It has **no natural nightly cadence** — there is no PR label on a schedule — so moving it to nightly would silence it. It is already excluded from `CI Summary.needs` (105 D-04). **Classify it as a label-gated PR lane, NOT nightly. Do not silently move it.** | D-14 |

> This bucket exists specifically so `mux-soak` is **not** mis-bucketed into
> move-to-nightly. Plans 106-03/04 must leave `mux-soak` in `ci.yml`.

---

## Bucket "off-critical-path" — runs, but never gates the PR

These run on `push:main` / nightly / release (or are advisory telemetry). They are not
on the PR critical path and not in `CI Summary.needs`.

| Lane / item | Where it runs | Rationale | Decision |
|-------------|---------------|-----------|----------|
| `package-consumer-full` — full 5-profile matrix + `release_preflight.sh` + `hex.publish --dry-run` + `repo_hygiene_check.sh --ci` | `push:main` (`if: github.event_name != 'pull_request'`); optionally also nightly | Release-readiness breadth; the run **conclusion** on push:main is the release proof consumed by `release.yml gate-ci-green` (D-11). OMITTED from `CI Summary.needs` (D-09 — omit-from-needs, not normalize-inside-gate). | D-08/D-09/D-11 |
| `adoption-demo-e2e` (Playwright browser) | `push:main` | 318s p95 ≈ 2× avg — a variance signature / Chromium flake class; fork-skipped today. PR proxy = `adoption-demo-unit` (Bucket A). MTTD = 1 merge. | D-04; 160s avg/318s p95 |
| `cohort-demo-smoke` (Docker-compose cold-start) | `push:main` | Already `if: github.repository == 'szTheory/rindle'` → gives **zero** signal on fork PRs today; its historical breaks were compile/pin failures `quality`+`optional-dependencies` catch on PR independently. MTTD = 1 merge. | D-05; 105s avg/176s p95 |
| coverage **measurement** (the per-PR coverage-% reporting) | advisory telemetry | Coverage measurement is advisory — **`mix coveralls` stays as the gating test invocation** (it IS the `quality` test step), but no per-PR coverage-% gate sits on the critical path. | D-07 |

---

## Buckets D & E — quarantine / delete: EMPTY

**No quarantine (D) and no delete (E) entries were identified.** Every current `ci.yml`
lane has real, current value — the milestone's problem is *trigger placement*
(representative-on-PR vs breadth-elsewhere), not dead/flaky-beyond-repair tests. Do **not**
invent a quarantine or delete entry to fill these buckets. (`106-CONTEXT.md` `<specifics>`:
"No quarantine/delete entries identified.")

---

## Coverage check — every `ci.yml` job is placed exactly once

| `ci.yml` job | Bucket |
|--------------|--------|
| `quality` | A (keep) |
| `optional-dependencies` | A (keep) |
| `integration` | A (keep) |
| `contract` | A (keep) |
| `proof` | A (keep) |
| `adopter` | A (keep) |
| `adoption-demo-unit` | A (keep) |
| `brandbook-tokens` | A (keep) |
| `package-consumer` (scoped `image`-only) | A (keep) — its 5-profile body → B/off-critical-path as `package-consumer-full` |
| `ci-summary` | A (keep) |
| `ci-observability` | A (keep, non-gating helper) |
| `ci-script-tests` | A (keep, non-gating self-test) |
| Dialyzer (currently a `quality` step) | B (optimize: extract) → C (move-to-nightly, owned + gating) |
| `compat-matrix` (new, broad OTP×Elixir) | C (move-to-nightly) |
| `gcs-soak` | C (move-to-nightly) |
| `package-consumer-gcs-live` | C (move-to-nightly) |
| `mux-soak` | label-gated PR lane (NOT nightly) |
| `adoption-demo-e2e` | off-critical-path (`push:main`) |
| `cohort-demo-smoke` | off-critical-path (`push:main`) |
| coverage measurement | off-critical-path (advisory telemetry) |

Quarantine (D): **none.** Delete (E): **none.**

---

## Hard invariants the lane moves must preserve

- Never rename `ci.yml`'s filename or `name: CI` (release-train coupling via
  `release-please-automerge.yml` + `release.yml gate-ci-green`).
- `CI Summary` must treat `skipped` as **pass** (fork-PR safety); `package-consumer-full`
  is OMITTED from its `needs` (D-09), so the gate makes no claim about a conditionally-
  skipped lane.
- Never weaken the release full-verification gate: the full 5-profile matrix +
  `release_preflight` + `hex.publish --dry-run` MUST still run, provably, before publish
  (D-11; proven by the push:main run **conclusion**).
- The nightly lane must **never** become a required check on PRs (D-12/D-16/D-18).

*Phase: 106-trigger-split-matrix-lane-refinement · Plan 01 · LANE-04*
*Authored: 2026-06-22*
