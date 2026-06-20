# Project Research Summary

**Project:** Rindle — v1.20 "CI/CD Performance" milestone (SEED-003)
**Domain:** CI/CD pipeline performance + reliability for an Elixir/Phoenix/Ecto OSS Hex library (DX/infra milestone; ZERO `lib/` public-API change)
**Researched:** 2026-06-20
**Confidence:** HIGH

## Executive Summary

This is a **measure → classify → restructure** infrastructure pass on Rindle's existing 14-job `ci.yml`, not a greenfield build. All four research lenses (stack, features, architecture, pitfalls) converge on one diagnosis: PR wall-clock is ~15–17 min and is dominated by a **single lane** — `package-consumer` (`Package Consumer Proof Matrix + Release Preflight`, ~15m), which bundles a 5-profile install-smoke matrix (image/video/tus/mux/gcs) + `release_preflight` + `hex.publish --dry-run`. Every heavy lane `needs: [quality, optional-dependencies]`, so wall-clock ≈ `max(quality, optional-deps) + package-consumer` ≈ 2 + 15 ≈ 17m, with `adoption-demo-e2e` (~5–7m) hidden in its shadow. The pole is a **SCOPE/TRIGGER problem, not a parallelism problem**: most of that work is release-readiness breadth, not per-PR regression signal. The headline fix is to keep ONE representative install-smoke (`image`) on PR and move the full matrix + preflight + dry-run to `push:main`/nightly/release — cutting PR feedback toward ~5–7m (e2e becomes the new pole).

The single highest-blast-radius risk is **required-check / branch-protection coupling**. `scripts/setup_branch_protection.sh` hard-requires 13 literal contexts (including matrix children like `Quality (1.15, 26)`); `branch-protection-apply.yml` re-asserts that list nightly via cron (it will *fight* any migration); and the release train couples to the CI workflow by name/filename (`release-please-automerge.yml` triggers on `workflow_run: workflows: [CI]`, `release.yml`'s `gate-ci-green` polls `workflow_id: 'ci.yml'` on the exact SHA). Therefore a single `CI Summary` / `ci-required` aggregate job must become the **ONLY** required check, landed BEFORE any matrix/lane rename, and the script's `REQUIRED_CHECKS` array must change in the same PR. There is also a latent **fork-PR pending trap**: 5 jobs gated `if: github.repository == 'szTheory/rindle'` skip on forks and, if individually required, hang external-contributor PRs forever.

The mitigation is a strict **dependency-ordered stepwise-PR sequence** all four agents independently agree on: (1) observability/baseline FIRST — you cannot classify or delete anything without `--slowest`, per-step timing, cache hit/miss, and `System.schedulers_online()` evidence; (2) cache + version cleanup + lint de-dup (low-risk waste removal); (3) async-safety guard + partitioning (substrate already wired, currently unused); (4) the headline matrix/trigger lane split behind the aggregate required check (the 15→<5min cut); (5) release/security polish + `mix ci` + CONTRIBUTING + faithful-Linux-Chromium repro. Concrete wins are well-scoped and low-risk. The honest unknowns (runner cores, real p95/rerun rates, which non-async modules are truly unsafe, actual branch-protection names) are exactly what PR-1's baseline must resolve.

## Key Findings

### Recommended Stack

This is a **tooling-and-versions hardening** dossier against the real `ci.yml`, not a stack pick. Confidence is HIGH on versions/idioms (verified on Hex.pm + official docs 2026-06-20) and MEDIUM on partitioning payoff (depends on unmeasured async-safety + runner core count). See [STACK.md](./STACK.md).

**Core technologies / locked adds:**
- **`erlef/setup-beam`** (pin to release SHA + `version-type: strict`) — capture resolved OTP/Elixir via `outputs.*` into cache keys and the job summary; `@v1` floats and must be SHA-pinned for a published lib.
- **`actions/cache@v4` with a PLT `restore`/`save` split** — persist the expensive PLT *after build, before analysis* so a Dialyzer finding does not discard it; add OTP+Elixir+MIX_ENV+arch+lockfile dims (current keys miss MIX_ENV and arch).
- **`mix ci` alias** (Phoenix-1.8 `precommit` idiom, hardened for a lib) — the single highest-DX, lowest-risk change; today only `precommit: ["test"]` exists, so local ≠ PR gate. Includes `deps.get --check-locked` (absent today), `deps.unlock --check-unused`, `format --check-formatted`, `compile --warnings-as-errors`, `hex.audit`, `deps.audit`, `test --warnings-as-errors --slowest 20`.
- **`{:mix_audit, "~> 2.1"}`** (ABSENT — add) + `dependabot.yml` (`github-actions` + `mix`) + **SHA-pin all third-party actions** — supply-chain hygiene; pinning without Dependabot rots.
- **Built-in ExUnit/Mix levers** — `async: true` (the biggest free test-speed lever), `--slowest`, `--partitions`+`MIX_TEST_PARTITION` (MAYBE, measure first), `--warnings-as-errors`. Bump Node 20→22 LTS; `ubuntu-22.04` is fine (24.04 optional).

**Explicitly NOT to add:** Sobelow gating the library PR (scans Phoenix app sinks, not libs); SaaS visual-regression (Percy/Chromatic); `pull_request_target` for fork secrets; `--max-cases`/partition tuning before measuring; flipping Credo/Dialyzer to blocking (reverses locked CI-04).

### Expected Features

"Features" = target CI capabilities expressed as shippable deliverables, governed by the SEED-003 north-star hierarchy (trust > determinism > fast PR feedback > runner/cache efficiency > simple YAML > DX > security > presentation). Nothing in table stakes trades trust for speed. See [FEATURES.md](./FEATURES.md).

**Must have (table stakes):**
- Baseline metrics table (per-job avg + p95, cold vs warm cache, rerun rate) captured before any change — `[BASELINE FIRST]`.
- Per-job/per-step timing + cache hit/miss + `mix test --slowest N` + `System.schedulers_online()` surfaced in `$GITHUB_STEP_SUMMARY`.
- Single local `mix ci` alias mirroring the merge-blocking checks; CONTRIBUTING.md documenting lanes + required checks (severity matrix is currently buried in `RUNNING.md`).
- `concurrency:` group cancelling stale PR runs (never main/release); stable job names mapped to required checks.
- Deterministic gates (no `Process.sleep` race-mask, no "just retry"); faithful local repro of the Linux-Chromium font/contrast gates.

**Should have (the needle-movers):**
- **Lane separation** (fast PR / push-to-main / nightly / release / docs) — the single biggest win; target a <5-min representative PR gate.
- **Scope the `package-consumer` long pole** — image-only on PR; full 5-profile matrix + preflight + dry-run on main/nightly/release.
- Lint/static de-duplication across the matrix (runs twice today for zero added signal).
- Test-value classification (buckets A–E) as a *documented decision*; ExUnit async-safety audit + safe conversions; `--partitions` with DB-per-partition where evidence supports.
- Cache-correctness hardening; `ci-summary` aggregate + README badge pointing at the meaningful check; action SHA-pinning + per-job least-privilege.

**Defer (v1.20.x / later):** flaky-quarantine lane with seed logging (trigger: a test proves flaky); self-hosted/larger runners (only if post-partition core-starvation is measured); property/exhaustive nightly expansion.

**Anti-features (explicitly OUT):** auto-retry flaky; deleting slow tests merely for being slow; moving correctness-critical tests to schedule-only to fake a green PR; SaaS visual-regression gate; making Credo/Dialyzer merge-blocking; `pull_request_target` for fork secrets; OS×OTP×Elixir×adapter×partition matrix explosion; Rube-Goldberg dynamic-matrix cleverness; presentation dashboards.

### Architecture Approach

Split one `if:`-everything workflow into **trigger-scoped lanes** behind a single aggregate required check, refactoring (not rewriting) the 14-job `ci.yml`. Split by trigger, not by concern. See [ARCHITECTURE.md](./ARCHITECTURE.md).

**Major components:**
1. **`ci-pr.yml` (fast PR gate)** — minimal representative signal (quality 1.17/27 only, optional-deps, integration, contract, proof, demo-unit, cohort-smoke, e2e, `package-consumer-pr` image-only, brandbook-tokens) + `concurrency: cancel-in-progress` → target ~5–7m.
2. **`ci.yml` (main/full, KEEP name `CI`)** — everything in PR + full package-consumer matrix + min-supported compat cell + coverage; serialize, never cancel. **This is the release-gated workflow — do not rename the file or `name:`.**
3. **`ci-nightly.yml`** — broad OTP×Elixir matrix, gcs-soak, package-consumer-gcs-live, owned Dialyzer lane, continuous release-preflight rehearsal.
4. **`ci-summary` / `ci-required` aggregate job** — `needs: [all PR jobs]`, `if: always()`, fails only on `failure`/`cancelled` (skipped == pass); the ONLY required branch-protection check.
5. **`.github/actions/setup-elixir` composite action** — absorbs the duplicated checkout→setup-beam→restore-caches→system-deps→deps.get block (~9 jobs); single source of truth for cache keys (precondition for safe cache tuning); a sibling MinIO composite removes the 6× `docker run` + sleep-poll duplication.

`release.yml` topology is **exemplary and unchanged** (gate-ci-green on exact SHA → preflight → version-match → `hex.publish --dry-run` → frozen-worktree publish → public_verify).

### Critical Pitfalls

Cross-checked against `[DARK CORNERS]` and the actual repo files; non-applicable corners (e.g. `set_mox_global` in async tests) are stated as clean so the roadmap spends zero effort on non-problems. See [PITFALLS.md](./PITFALLS.md).

1. **Required-check / branch-protection coupling (highest blast radius)** — require ONLY a stable `CI Summary`/`ci-required` aggregate; land it BEFORE any matrix/lane rename; update `setup_branch_protection.sh` `REQUIRED_CHECKS` in the SAME PR (cron re-assert will otherwise revert). Never rename `ci.yml`'s file or `name: CI` (breaks `release-please-automerge.yml` + `gate-ci-green`).
2. **Fork-PR "pending forever" trap** — 5 jobs (`cohort-demo-smoke`, `adoption-demo-e2e`, `gcs-soak`, `package-consumer-gcs-live`, `brandbook-tokens`) skip on forks via `if: github.repository ==`; if individually required they hang external PRs. The aggregate job treating `skipped` as pass fixes this.
3. **`package-consumer` ~15m lane on every PR** — classify-and-MOVE (not delete): one `image` smoke on PR, full matrix + dry-run + preflight to main/release; label-gate heavy variants. Ensure the fast/nightly split does NOT weaken the release gate's full verification (`gate-ci-green` must be satisfied by a run that ran the full matrix).
4. **Cache correctness** — `_build` key missing MIX_ENV (the `package-consumer` dev-env steps can read a `_build/test` tree); broad `restore-keys` + absent `mix deps.get --check-locked` lets a drifted lock pass; PLT `restore`/`save` split must persist on Dialyzer failure; PLT key should add `mix.exs`/`.dialyzer_ignore.exs`; add a `v1-` cache-version buster.
5. **Linux-Chromium font-metric / contrast nondeterminism (the recurring bite)** — gates that only fail in CI freetype. Provide a pinned `mcr.microsoft.com/playwright:vX-jammy` devcontainer + `scripts/ci/e2e_local.sh`, drop the `^` caret on `@playwright/test` to an exact pin, pin fonts, and reconcile the divergent token-pair vs runtime contrast thresholds to one shared constant.

Also worth carrying: lint runs redundantly on both matrix cells (pure waste); `coveralls` slows every PR with no gate; ExUnit suite is currently async-clean (forward-looking guard only — add a static check before any async conversion); SQL-sandbox ownership becomes live the instant a LiveView/Oban/Task module is flipped to async; Oban `:inline` (config) vs `:manual` (test_helper) posture mismatch; lingering `FedericoCarboni/setup-ffmpeg@v3` in `release.yml`'s `public_verify` (abandoned elsewhere); no `.tool-versions` (versions hard-coded per job).

## Implications for Roadmap

Based on combined research, the suggested phase structure mirrors the stepwise-PR sequence all four agents independently converged on. The dependency ordering is **load-bearing** — reversing PR-3 (aggregate check) and PR-4 (lane split) would force a second branch-protection migration.

### Phase 1: Observability / Baseline (no behavior change)
**Rationale:** `[BASELINE FIRST]` — you cannot classify, delete, async-convert, or partition without evidence. Zero topology change → zero branch-protection risk. Must also resolve the honest unknowns.
**Delivers:** per-job/per-step timing + cache hit/miss + `mix test --slowest 20` + `System.schedulers_online()` + `mix compile --profile time` + ExUnit seed surfaced in `$GITHUB_STEP_SUMMARY`; JUnit/coverage artifacts; captured baseline table (avg + p95 + rerun rate) AND the **actual current branch-protection required-check names** (live in GitHub settings).
**Addresses:** baseline metrics, observability table stakes.
**Avoids:** blind deletion/partitioning; resolves the runner-core and slow-test unknowns.

### Phase 2: Cache + Version Cleanup + Lint De-dup (correctness, low-risk)
**Rationale:** Independent waste removal that underpins every later lane; cache correctness must precede partitioning; composite-action extraction is the precondition for safe single-source cache-key changes. Still single-workflow shape → no required-check rename yet.
**Delivers:** `.github/actions/setup-elixir` (+ MinIO) composite; cache keys with OTP+Elixir+MIX_ENV+arch + `v1-` buster; PLT `restore`/`save` split; `mix deps.get --check-locked` + `deps.unlock --check-unused`; lint/format/credo/doctor run ONCE on latest pair; `.tool-versions`; align stray `setup-ffmpeg` action to `install_ffmpeg.sh`.
**Uses:** `actions/cache@v4` split, `setup-beam` `version-file`.
**Avoids:** Pitfalls 1, 2, 3 (PLT), 4, 5 (warnings cache-dependence), 11 (lint redundancy).

### Phase 3: Aggregate Required Check + Branch-Protection Flip (risky-but-isolated)
**Rationale:** The high-blast-radius migration isolated into ONE reviewable PR, landed BEFORE any matrix/lane rename so subsequent renames never touch branch protection again.
**Delivers:** `CI Summary` (`needs: [all jobs]`, `if: always()`, skipped==pass) added to `ci.yml`; `setup_branch_protection.sh` `REQUIRED_CHECKS` → only `CI Summary`; confirm with `--print-expected`; (optionally keep legacy names one transitional cycle).
**Avoids:** Pitfalls 6 (fork pending trap) and 7 (unstable matrix-child names) — the prerequisite for safely reshaping the matrix.

### Phase 4: Trigger Split + Matrix/Lane Refinement (the headline 15→<5min cut)
**Rationale:** Now that only `CI Summary` is required, lanes can be renamed/split freely. Delivers the actual wall-clock win.
**Delivers:** `ci-pr.yml` fast path; `package-consumer` split (image-only PR + full matrix on main/nightly); quality/optional-deps collapsed to 1.17/27 on PR; `gcs-soak` + `package-consumer-gcs-live` moved to `ci-nightly.yml`; `concurrency:` groups (cancel PR / serialize main); documented test-value classification (A–E); shared contrast-threshold reconciliation. KEEP `ci.yml` named `CI` on `push:main`.
**Addresses:** lane separation, fast PR gate, scope-the-pole differentiators.
**Avoids:** Pitfalls 8 (long pole — labeled trust/speed tradeoff in CONTRIBUTING + PR), 20 (release gate must still see full verification), 24 (resist matrix explosion), 26 (coverage off PR path).

### Phase 5: Test Concurrency / Partitioning + Release/Security Polish + DX
**Rationale:** Only after PR-4's numbers; async-first before partitioning; DX docs the settled pipeline.
**Delivers:** ExUnit async-safety static guard (before any conversion) + safe conversions; `--partitions` on the proven pole only if evidence + cores support (DB-per-partition, merge coverage); SHA-pin all actions + Dependabot + per-job least-privilege + PAT-scope audit; `mix ci` + CONTRIBUTING.md + README badge; faithful-Linux-Chromium devcontainer + `e2e_local.sh` + exact Playwright/font pin; reconcile Oban `:inline`/`:manual`.
**Avoids:** Pitfalls 9/10 (async + sandbox ownership), 12/18/19/21 (security/supply-chain), 14 (font nondeterminism), 25 (partition oversubscription).

### Phase Ordering Rationale

- **Observability strictly first** — SEED-003 `[BASELINE FIRST]`; every downstream classification/deletion/partition decision needs PR-1 evidence (this is unanimous across all four files).
- **Cache correctness + composite action before partitioning** — changing a cache key across 9 inlined jobs by hand is how stale-cache bugs ship.
- **Aggregate required check before lane split** — the ONE ordering that prevents a second branch-protection migration; the most-emphasized risk in ARCHITECTURE.md and PITFALLS.md.
- **Lane split before partitioning** — you cannot decide what moves to nightly without the A–E buckets, and the pole is scope, not parallelism, so the cheap win comes first.
- **DX/docs last** — `mix ci` + CONTRIBUTING document the *settled* fast-PR check set.

### Research Flags

Phases likely needing deeper research / measurement during planning:
- **Phase 1:** must produce the missing data (runner vCPU/`schedulers_online`, real p95/rerun rates, per-step `package-consumer` timing, slowest tests) AND read live GitHub branch-protection required-check names — these are unknowns, not patterns.
- **Phase 5 (partitioning + async conversion):** which of the 64 non-async modules are *genuinely* unsafe vs conservatively-marked requires reading `test/` modules + sandbox/Oban config; partitioning payoff is evidence-gated, not assumed.

Phases with standard patterns (skip research-phase):
- **Phase 2 (cache/version/lint):** well-documented Elixir-CI idioms; STACK.md gives exact key recipes.
- **Phase 3 (aggregate check + branch protection):** canonical GitHub Actions pattern (Phoenix/Ecto/Nx/Ash); ARCHITECTURE.md gives the exact YAML and the script-update rule.
- **Phase 4 (trigger split):** topology fully specified in ARCHITECTURE.md's integration table (new-vs-modified per job).

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Versions/idioms verified on Hex.pm + official docs 2026-06-20; framed against the real `ci.yml`/`mix.exs`. MEDIUM only on partitioning payoff (unmeasured) and exact runner cores. |
| Features | HIGH | Grounded in the real 14-job `ci.yml`, `mix.exs`, `test_helper.exs`, `RUNNING.md`, and 124 test files; classification buckets are hypotheses pending PR-1 timing evidence. |
| Architecture | HIGH | Mapped line-by-line against `ci.yml`/`release.yml`/`release-please-automerge.yml`/`branch-protection-apply.yml`/`setup_branch_protection.sh`. Aggregate-job pattern is MEDIUM-HIGH (established, not re-verified live this pass). |
| Pitfalls | HIGH | Every pitfall cross-checked against `[DARK CORNERS]` AND the actual repo; non-applicable corners explicitly marked clean (async suite, `pull_request_target`, shell-injection). |

**Overall confidence:** HIGH

### Gaps to Address

These are the honest unknowns PR-1's baseline MUST resolve — they are not blockers, but downstream decisions depend on them:

- **Runner vCPU / `System.schedulers_online()`**: not derivable from files; print in CI before any `--max-cases`/partition tuning. Handle in Phase 1.
- **Real p95 wall-clock + failure/rerun rates + per-step `package-consumer` timing**: only the ~15m headline number is measured; need the breakdown to justify exactly which install-smoke variants move. Handle in Phase 1.
- **Which of the 64 non-async test modules are genuinely unsafe**: requires reading `test/` + `config/test.exs` sandbox/Oban config; the async lever's magnitude is unknown until then. Handle in Phase 5 (behind the async-safety static guard).
- **Actual branch-protection required-check names**: live in GitHub repo settings, not in-repo. Capture in Phase 1; required before the Phase 3 flip.
- **`mix.lock` resolved versions** (may trail Hex latest) and exact current stable Elixir minor: confirm before pinning the new primary matrix pair. Handle in Phase 2.

## Sources

### Primary (HIGH confidence)
- This repo, read line-by-line 2026-06-20 — `.github/workflows/ci.yml` (14 jobs), `release.yml`, `release-please-automerge.yml`, `branch-protection-apply.yml`, `scripts/setup_branch_protection.sh`, `mix.exs`, `config/test.exs`, `test/test_helper.exs`, `test/support/data_case.ex`, `examples/adoption_demo/playwright.config.js`, install/preflight scripts, 124 test files (60 async / 64 non-async, tag census).
- `.planning/seeds/SEED-003-ci-cd-performance-audit.md` — authoritative spec: north-star hierarchy, `[BASELINE FIRST]`, `[TEST VALUE CLASSIFICATION]`, `[DARK CORNERS]`, `[IDEAL SHAPE]`, stepwise-PR sequence, measured baseline table.
- Hex.pm package pages (credo 1.7.19, dialyxir 1.4.7, mix_audit 2.1.5, sobelow 0.14.1, excoveralls 0.18.5) — verified 2026-06-20.
- Official docs — Mix `--partitions`/`MIX_TEST_PARTITION`, Dashbit "Warnings as errors and tests", Playwright CI (workers:1, browser cache by version), `erlef/setup-beam` README, `actions/cache` restore/save split.

### Secondary (MEDIUM confidence)
- GitHub Actions canonical patterns — summary/aggregate required job, `concurrency` cancel-in-progress, `workflow_run` name-coupling, skipped-required-must-report-success (Phoenix/Ecto/Nx/Ash conventions).
- Cross-ecosystem analogues — Rails DB-per-worker, pytest-xdist + quarantine + JUnit, cargo-nextest sharding, Node PM-cache vs node_modules; Ecto SQL Sandbox shared-mode semantics; `mcr.microsoft.com/playwright:vX-jammy` for faithful Linux Chromium.

### Tertiary (LOW confidence)
- Partitioning payoff for *this* suite — extrapolated from ~31% Ecto-heavy speedups; needs PR-1 measurement before commitment.

---
*Research completed: 2026-06-20*
*Ready for roadmap: yes*
