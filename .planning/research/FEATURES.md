# Feature Research

**Domain:** CI/CD pipeline capabilities for an Elixir/Phoenix/Ecto OSS Hex library (Rindle) — DX-infrastructure milestone v1.20, framed as shippable deliverables
**Researched:** 2026-06-20
**Confidence:** HIGH (grounded in this repo's real 14-job `ci.yml`, `mix.exs`, `test_helper.exs`, `RUNNING.md` severity matrix, and 124 test files; cross-ecosystem patterns verified against current Mix/ExUnit + GitHub Actions docs)

> "Features" here = **target CI capabilities** ("what good CI looks like") expressed as the deliverables this milestone could ship. The north-star hierarchy from SEED-003 governs every classification: **(1) gate trust > (2) determinism > (3) fast PR feedback > (4) runner/cache efficiency > (5) simple YAML > (6) contributor DX > (7) security > (8) presentation.** Nothing in Table Stakes trades trust for speed.

---

## Repo grounding (what exists today — do not re-derive)

| Real artifact | State |
|---|---|
| **14 jobs** in `ci.yml` | `quality` (2-cell 1.15/26 + 1.17/27 matrix), `optional-dependencies` (same 2-cell matrix), `integration`, `contract`, `proof`, `package-consumer` (**long pole ~15m**), `adoption-demo-unit`, `cohort-demo-smoke`, `adoption-demo-e2e` (~5–7m Playwright), `adopter`, `mux-soak` (label-gated), `gcs-soak` (secret-gated), `package-consumer-gcs-live` (secret-gated), `brandbook-tokens` |
| **Triggers** | `push: [main]`, `pull_request: [main]` (+`labeled`), `workflow_dispatch`. **Same workflow for PR and main — no lane separation.** |
| **`mix ci` / local equivalent** | **Does not exist.** `precommit: ["test"]` only. `test` alias = `ecto.create --quiet`, `ecto.migrate --quiet`, `test`. |
| **CONTRIBUTING.md** | **Does not exist.** Severity policy lives in `RUNNING.md ## Maintainer: CI lane severity`. |
| **Test concurrency** | 60 modules `async: true`, **64 not async** (DB sandbox, MinIO, global app env, Oban). Shared `Rindle.Repo` + `Rindle.Adopter.CanonicalApp.Repo`, both `Sandbox.mode :manual`. Oban `testing: :manual`. |
| **Tags** | `@tag`/`@moduletag`: `:minio` (15), `:integration` (9), `:gcs` (4), `:contract`, `:adopter`, `skip` (9). `test_helper.exs` excludes `[:integration, :minio, :contract, :adopter]` by default. |
| **Concurrency control** | **None.** No `concurrency:` block → stale PR runs are not cancelled; redundant compute. |
| **Caching** | `actions/cache@v4` for `deps`, `_build`, `priv/plts`; keys include OS+elixir+otp+`mix.lock` hash. PLT restore/build split exists. **No cache hit/miss surfaced in summaries.** |
| **Static analysis** | Credo/Dialyzer/Doctor advisory (CI-04, locked v1.17) — **out of scope to flip.** |
| **Known CI-only gate surprises** | Linux-Chromium font metrics (Atkinson-on-freetype 3px overflow) + runtime contrast stricter than token-pair gate. Reproduces only in CI. |

---

## Feature Landscape

### Table Stakes (A trustworthy fast OSS Elixir CI is expected to have these)

Missing these = the pipeline feels slow, opaque, or unfriendly. None sacrifice quality signal.

| Capability (deliverable) | Why Expected | Complexity | Notes / repo grounding |
|---|---|---|---|
| **Baseline metrics table** (per-job avg + p95 wall-clock, cold vs warm cache, rerun rate) captured before any change | You cannot classify or optimize what you haven't measured; SEED-003 `[BASELINE FIRST]` mandates it | LOW | One-time artifact (`.planning/research/` or a `BASELINE.md`). Prereq for *every* other deliverable. |
| **Per-job + per-step timing surfaced in run summary** | Contributors and maintainer must see where the 15–17 min goes without spelunking logs | LOW–MED | GitHub renders step durations natively; add a `$GITHUB_STEP_SUMMARY` block per job for at-a-glance. |
| **Cache hit/miss reporting in summary** | Caching is "correctness-sensitive" (SEED-003 6.6); a silent cold cache masks 3-min dep recompiles | LOW | `actions/cache` exposes `outputs.cache-hit`; echo into `$GITHUB_STEP_SUMMARY`. Already have `id: plt-cache`; extend to deps/_build. |
| **`mix test --slowest N` report** in the unit lane summary | Names the concrete slow tests so classification has evidence, not guesses | LOW | One flag on the existing `mix coveralls`/`mix test` step. |
| **`System.schedulers_online()` printed in CI** | Confirms actual runner core count (ubuntu-22.04 = 2–4 vCPU) before tuning `max_cases`/partitions — avoids oversubscription | LOW | One `mix run -e` line; gates the partitioning decision. |
| **Single local `mix ci` alias** that runs the exact merge-blocking checks | A contributor must reproduce the green check locally without reading YAML; `precommit: ["test"]` is not it | MED | deps.get `--check-locked`, `format --check-formatted`, `compile --warnings-as-errors`, `deps.unlock --check-unused`, `mix coveralls`. Mirror the *merge-blocking* set only. |
| **CONTRIBUTING.md documenting lanes + `mix ci` + required checks** | OSS table stakes; the severity matrix is currently buried in `RUNNING.md` (maintainer-only) | LOW | New file; link the existing severity matrix; explain fast-PR vs nightly promise. |
| **Concurrency group cancelling stale PR runs** (never main/release) | Pushing twice should not burn two 15-min runs; pure waste with zero trust cost | LOW | `concurrency: { group: ci-${{ github.ref }}, cancel-in-progress: ${{ github.event_name == 'pull_request' }} }`. |
| **Clear, stable job names** mapped to required checks | Branch protection references names; renames break protection (`scripts/setup_branch_protection.sh`) | LOW | Names are mostly good; `Package Consumer Proof Matrix + Release Preflight` is doing two jobs — see lane split. |
| **JUnit + coverage artifacts** uploaded from trusted runs | Standard for failure triage; pytest/Java parity; ExCoveralls already wired | LOW–MED | `mix coveralls.json` + a JUnit formatter; upload via `actions/upload-artifact` (already used for Playwright report on failure). |
| **Deterministic gates — no `Process.sleep` readiness, seeded randomness, no "just retry"** | North-star #1–2; SEED-003 explicitly bans retry-as-fix | MED | MinIO/Postgres already poll health (good). Audit for `Process.sleep` race-masks; ensure `ExUnit` seed is logged so a flake is reproducible. |
| **Faithful local repro of the Linux-Chromium gates** | The felt pain this milestone: gates that only fail in CI (font/contrast). A documented container/Docker path to run `adoption_demo_e2e.sh` + `cohort-contrast.mjs` on Linux locally | MED–HIGH | The repeated surprise. A `mix`/`make`/script target that runs the Playwright + contrast gate in the same Linux Chromium image. |

### Differentiators (Move the needle on speed/trust beyond baseline; align with "fast, deterministic, contributor-friendly")

These are where v1.20 actually cuts the 15–17 min and hardens trust. Not strictly expected of every OSS lib, but high-leverage here.

| Capability (deliverable) | Value Proposition | Complexity | Notes / repo grounding |
|---|---|---|---|
| **Lane separation: fast PR gate / push-to-main / scheduled-nightly / release-publish / docs** | The single biggest win. A representative **fast PR gate targeting <5 min** instead of one 15-min monolith | HIGH | See "Lane promises" below. Heavy `package-consumer` install-smoke matrix + release preflight is the prime candidate to move to **main/nightly/release**, not every PR. |
| **Fast PR gate (<5 min target)** — format, `compile --warnings-as-errors`, deps locked/unused, async unit suite on the *latest* pair, the cheap merge-blocking proofs | Sub-5-min feedback on likely regressions is the contributor-DX prize | MED | Compose from existing cheap lanes: `quality` (latest cell), `optional-dependencies`, `proof`, `adoption-demo-unit`. Demote/move the 15-min lane. |
| **Test-value classification pass (buckets A–E), documented** | Turns "we have 124 test files across 6 lanes" into an evidence-based keep/optimize/move/quarantine/delete decision | MED | **Depends on observability landing first** (slowest-tests + timings). See classification section below. The deliverable is the *documented decision*, not just edits. |
| **ExUnit async-safety audit + `async: true` conversions where safe** | 64 non-async modules cap parallelism on 2–4 cores; converting genuinely-isolated modules cuts unit wall-clock | MED | Never async if mutating `Application` env, named ETS, registered procs, Mux global Mox, shared sandbox. Evidence-gated. |
| **`mix test --partitions N` (+ `MIX_TEST_PARTITION`) for the non-async-dominated lanes** | OS-level parallelism for the integration/proof/package lanes where `async` is impossible (DB sandbox shared mode, MinIO, ports). Verified ~31% on Ecto-heavy suites | MED–HIGH | **DB-per-partition + coverage merge required** (see Rails parallel-tests pattern below). Only after `schedulers_online` evidence; don't oversubscribe a 2-vCPU runner. |
| **Lint/static-analysis de-duplication across the matrix** | Today `format`/`compile`/Credo/Doctor/Dialyzer run on **both** matrix cells (1.15/26 *and* 1.17/27). Lint is version-invariant → run once on latest | LOW | SEED-003 `[DARK CORNERS]`: "lint redundant across every matrix entry." Pure waste removal. |
| **Scope the `package-consumer` long pole** — split install-smoke *matrix* (image/video/tus/mux/gcs) from *release preflight* + dry-run publish | The ~15m job bundles 5 install-smoke profiles + preflight + hex dry-run. Most belongs to push-to-main/nightly/release, not every PR | MED | Single most impactful critical-path cut. Keep one representative smoke on PR (e.g. `image`), move the full matrix to main/nightly. |
| **Cache-correctness hardening** (per-MIX_ENV/OTP keys, restore breadth audit, restore/save split, documented cache-bust) | Prevents the silent stale-`_build`-across-OTP and broad-restore-key footguns | MED | Keys already include OS+elixir+otp+lock; audit `restore-keys` breadth and never restore `_build` across incompatible MIX_ENV. |
| **Flaky-test quarantine lane with logged repro seed** (tag-gated, *visible*, not silent-retry) | When a test is genuinely flaky, quarantine + fix-before-trust beats reruns; the `skip` (9) tag already exists informally | MED | A `@tag :quarantine` excluded from the gate but run (non-blocking) in nightly with seed logged. Honest, not hidden. |
| **Compile-time profile** (`mix compile --profile time`, `mix xref graph --label compile-connected`) captured | Names macro-heavy recompile chains; the 3-min dep+compile cost is the real floor | LOW–MED | Diagnostic deliverable feeding cache + partition decisions; not a permanent gate. |
| **README badge that reflects the meaningful required check** (the fast PR gate / a final summary job) | Badge currently points at the whole `CI` workflow; a `ci-summary` aggregate job gives an honest single signal | LOW | Pairs with a final `needs: [...]`-gated summary job that branch protection requires (stable name survives matrix churn). |
| **Release/security posture polish** — pin third-party actions to SHAs (or tag+Dependabot), per-job least-privilege `permissions`, dry-run publish gating | Supply-chain hardening; `mux-soak` fork-secret fail-closed pattern is already exemplary and should be the documented model | MED | `permissions: contents: read` is set top-level (good). Audit per-job writes; `release.yml` already gates on green CI (good). |

### Anti-Features (Tempting CI "optimizations" that betray the north-star — explicitly OUT of scope)

| Anti-capability | Why it's requested | Why problematic (north-star violated) | Better approach |
|---|---|---|---|
| **Auto-retry flaky tests** (`nextest --retries`, rerun-on-fail) | Makes red turn green; quick "fix" | Hides non-determinism; trades trust (#1–2) for green. SEED-003 bans it explicitly | Quarantine + log seed + fix root cause before trusting |
| **Deleting slow tests merely for being slow** | Cuts wall-clock fast | Drops quality signal; "never delete slow tests merely for being slow — classify first" (SEED-003) | Classify (A–E); move slow-but-valuable to nightly/main, optimize fixtures, partition |
| **Moving correctness-critical tests to schedule-only to make PR green** | PR feels fast | A regression merges before nightly catches it — trust loss masquerading as speed | Keep representative coverage on PR; broad matrix/soak on nightly |
| **SaaS visual-regression / pixel-diff service (Percy/Chromatic) as a merge gate** | "Catch the 3px Chromium overflow automatically" | External dependency, cost, flake, secrets-to-forks; the existing `cohort-contrast.mjs` + deterministic Playwright assertions already gate it | Faithful *local* Linux-Chromium repro + the deterministic in-repo contrast/literal gates |
| **Making Credo/Dialyzer merge-blocking** | "Stricter is better" | Reverses locked CI-04 decision; Dialyzer PLT build punishes fork PRs disproportionate to adopter impact | Keep advisory; visible in logs (locked v1.17) |
| **OS × OTP × Elixir × adapter × partition matrix explosion** | "Test every combination on every PR" | Combinatorial runner waste; SEED-003 top dark corner | Latest pair on PR; min-supported + broad matrix on nightly/main |
| **Larger/self-hosted runners to brute-force speed** | "Just throw cores at it" | Cost + complexity + security surface; `schedulers_online` shows ubuntu-22.04 is fine once partitioned | Right-size: lane split + async + partitions on standard runners |
| **Caching build *artifacts* that can mask stale compile/warnings** | "Cache everything" | Stale `_build` across MIX_ENV/OTP hides warnings-as-errors regressions | Cache deps/`_build`/PLT/asset-PM only, with precise keys; never cache to hide a rebuild |
| **`pull_request_target` to give fork PRs secrets / run heavy lanes** | "Let fork PRs run the soak lanes" | Untrusted-code-with-secrets RCE; the repo already deliberately uses safe `pull_request` so fork secrets resolve empty (fail-closed) | Keep label-gated soak on `pull_request`; maintainer-initiated only |
| **Rube-Goldberg dynamic matrix / clever bash to shave seconds** | "Elegant" | Hard-to-debug, fragile, violates "simple YAML" (#5); high cleverness, small payoff | Boring, explicit, least-surprise YAML |
| **Animate-everything / fancy presentation dashboards** | Looks impressive | Presentation is north-star #8 (lowest); effort better spent on #1–4 | Plain `$GITHUB_STEP_SUMMARY` tables |

---

## Test-value classification — the deliverable (buckets A–E)

The *deliverable* is a **documented keep/optimize/move/quarantine/delete decision** per lane, with evidence. "High-value" for THIS repo = catches an adopter-facing bug class (lifecycle, install-from-artifact, docs/API parity, security invariants 1–14), is deterministic, and gives actionable failure. "Low-value" = redundant across the matrix, implementation-trivia, over-broad integration for a unit concern, or flaky/global-state-dependent without isolation.

| Bucket | Meaning | Candidate lanes/checks in THIS repo (hypotheses to confirm with timing evidence) |
|---|---|---|
| **A — keep in PR gate** | High-value, deterministic, fast enough | `quality` async unit suite (latest pair) + `mix coveralls`; `optional-dependencies` `--no-optional-deps` compile (cheap, catches a real adopter break); `proof` (docs parity, adoption-matrix drift — fast, Postgres-only); `adoption-demo-unit` (storage-free, direct-insert) |
| **B — keep in PR but optimize** | Valuable but slow/serial → async-convert, partition, cheaper fixtures, run-once | `quality` lint steps (run **once** on latest, not per matrix cell); `integration` MinIO lifecycle (partition or trim); `adoption-demo-e2e` Playwright (~5–7m — trim specs / shard) |
| **C — move to push-to-main / nightly / release** | High-value but heavy/broad; not needed on *every* PR | The bulk of `package-consumer` (5-profile install-smoke matrix + release preflight + hex dry-run) → main/nightly/release; min-supported 1.15/26 matrix cell of `quality`/`optional-dependencies` → main/nightly compat lane; `cohort-demo-smoke` Docker cold-start (heavy build) candidate for main |
| **D — quarantine / fix before trusting** | Flaky / global-state / CI-only-failing until isolated | Anything reproducing only in Linux-Chromium (font/contrast) until the faithful local repro exists; the 9 `@tag skip` tests (audit: fix-or-delete, don't leave silently skipped); any `Process.sleep`-gated test |
| **E — delete or rewrite** | Redundant, implementation-trivia, or superseded | Duplicate assertions across the matrix cells; advisory steps that never produce actionable signal. **Conservative — evidence required before any deletion** (SEED-003). |

Already-correct posture to preserve (do NOT "optimize"): `mux-soak`/`gcs-soak` are already correctly **soak/secret-gated, not on every PR**; `contract` ExUnit + Credo/Dialyzer/Doctor are intentionally **advisory**; security-invariant and install-from-artifact proofs are high-value and stay merge-blocking.

---

## Lane separation — what each lane promises (capability contract)

| Lane | Trigger | Promise | What goes in it |
|---|---|---|---|
| **Fast PR gate** | `pull_request` | "Likely regressions caught in <5 min" | format, `compile --warnings-as-errors`, deps locked/unused, async unit suite on latest pair, cheap proofs (`proof`, `optional-dependencies`, `adoption-demo-unit`), one representative install-smoke |
| **Push-to-main** | `push: main` | "main stays green against the broader contract" | Fast gate + broader compat (min-supported cell) + coverage/JUnit artifact; can include heavier proofs the PR demoted |
| **Scheduled nightly** | `schedule:` | "Full breadth catches slow/rare regressions" | Full install-smoke matrix (image/video/tus/mux/gcs), full OTP/Elixir matrix, `cohort-demo-smoke`, quarantine lane (seed-logged), optional Dialyzer-if-too-slow, exhaustive/property |
| **Release / publish** | tag / `release.yml` | "Never publish unverified" | Depends on green CI on the SHA (already enforced, fail-closed), release preflight, `hex.publish --dry-run`, version-match, docs build; secrets only in publish job |
| **Docs** | path-filtered (optional) | "Docs build + link hygiene without blocking code PRs" | `check_docs_links.sh`, ExDoc build; the `brandbook-tokens` drift gate is docs/asset-adjacent |

**Required-check trap to avoid:** path-filtered *required* checks leave PRs stuck "pending." If introducing path filters, pair with a final aggregate `ci-summary` job that always reports and is the single required check.

---

## Capability Dependencies

```
Baseline metrics + Observability (timings, cache hit/miss, --slowest, schedulers_online, compile-profile)
        └──enables──> Test-value classification (A–E)  [cannot classify without evidence]
                          ├──enables──> Lane separation (fast PR / main / nightly / release / docs)
                          │                  └──enables──> Fast PR gate <5 min  [the headline win]
                          └──enables──> ExUnit async audit + --partitions  [needs schedulers_online + slowest report]

Cache-correctness hardening ──underpins──> all lanes (stale cache = false signal)

Determinism (no sleep, seeded, faithful Linux-Chromium repro) ──gates──> trust of every lane
        └── faithful-Linux repro ──unblocks──> quarantine→fix of the CI-only Chromium gates

mix ci alias + CONTRIBUTING.md ──documents──> the fast PR gate's exact checks  [DX layer, last]
Clear job names + ci-summary aggregate ──stabilizes──> README badge + branch protection
```

### Dependency notes (roadmap-ordering constraints)

- **Observability MUST precede confident test-classification.** SEED-003 `[BASELINE FIRST]`. Classifying/deleting tests without `--slowest` + timing evidence violates "conservative on deletion." → **Phase 1 = observability/baseline.**
- **`schedulers_online` print precedes async/partition tuning.** Don't oversubscribe a 2-vCPU runner. → partition/async work comes *after* the core count is known.
- **Classification precedes lane separation.** You cannot decide what moves to nightly without the A–E buckets.
- **Faithful Linux-Chromium repro unblocks quarantine→fix** of the font/contrast gates — the felt-pain item; can proceed in parallel with observability.
- **`mix ci` + CONTRIBUTING come last** — they document the *settled* fast-PR check set, so they follow lane separation.
- **Cache hardening + lint-dedup are independent quick wins** — low-risk, can land early as standalone stepwise PRs.

---

## MVP Definition (stepwise PRs — SEED-003 sequence)

### Launch With (the milestone's must-ship)

- [ ] **PR 1 — Observability/baseline:** per-job+step timing in `$GITHUB_STEP_SUMMARY`, cache hit/miss, `mix test --slowest`, `schedulers_online` print, compile profile, JUnit/coverage artifacts — *why: prerequisite for every downstream decision.*
- [ ] **PR 2 — Cache/version cleanup + lint de-dup:** audit keys/restore breadth, run lint once on latest cell — *why: low-risk waste removal, independent.*
- [ ] **PR 3 — Test concurrency/partitioning:** async-safety audit + safe conversions; `--partitions` with DB-per-partition where evidence supports — *why: cuts unit/integration wall-clock.*
- [ ] **PR 4 — Matrix/trigger refinement (the headline):** split lanes (fast PR <5 min / main / nightly / release / docs); scope the `package-consumer` long pole; add `concurrency:` cancel-stale; add `ci-summary` aggregate + stable required check — *why: the actual 15→<5 min cut.*
- [ ] **PR 5 — Release/security polish + DX:** pin actions, per-job permissions, then `mix ci` alias + CONTRIBUTING.md + README badge + faithful-Linux-Chromium repro path — *why: documents the settled pipeline.*

### Add After Validation (v1.20.x / follow-on)

- [ ] Flaky-quarantine lane with seed logging — *trigger: a test proves intermittently flaky.*
- [ ] Dependabot/Renovate for pinned actions — *trigger: action SHAs go stale.*

### Future Consideration (defer)

- [ ] Self-hosted/larger runners — *defer: only if post-partition `schedulers_online` evidence shows core starvation.*
- [ ] property/exhaustive nightly expansion — *defer: until a class of rare regression is observed.*

---

## Capability Prioritization Matrix

| Capability | Trust/Quality Value | Runtime/DX Value | Impl Cost | Reversibility | Priority |
|---|---|---|---|---|---|
| Baseline + observability | HIGH (enables all) | MEDIUM | LOW | easy | **P1** |
| Lane separation + fast PR <5m | MEDIUM (preserve) | **HIGH** | HIGH | medium | **P1** |
| Scope `package-consumer` long pole | MEDIUM | **HIGH** | MED | easy | **P1** |
| Cache-correctness hardening | HIGH | MEDIUM | MED | easy | **P1** |
| Lint de-dup across matrix | NEUTRAL | MEDIUM | LOW | easy | **P1** |
| `concurrency:` cancel stale PR runs | NEUTRAL | MEDIUM | LOW | easy | **P1** |
| Test-value classification (A–E) | HIGH | HIGH (enables cuts) | MED | n/a (doc) | **P1** |
| Faithful Linux-Chromium local repro | HIGH (felt pain) | HIGH (DX) | MED–HIGH | easy | **P1** |
| ExUnit async audit + `--partitions` | MEDIUM | HIGH | MED–HIGH | medium | **P2** |
| `mix ci` + CONTRIBUTING.md | NEUTRAL | **HIGH** | MED | easy | **P2** |
| JUnit/coverage artifacts | LOW | MEDIUM | LOW–MED | easy | **P2** |
| Release/security pinning + permissions | HIGH (security) | LOW | MED | easy | **P2** |
| `ci-summary` aggregate + badge | LOW | MEDIUM | LOW | easy | **P2** |
| Flaky-quarantine lane | HIGH | LOW | MED | easy | **P3** |

**Priority key:** P1 = ship this milestone (core measure→classify→restructure); P2 = should ship, sequence after P1 deps; P3 = follow-on / demand-gated.

---

## Cross-ecosystem capability analysis (adopt ONLY where it maps cleanly to Elixir)

| Pattern (origin) | What they do right | Footgun avoided | Maps to Elixir? | Rindle adaptation |
|---|---|---|---|---|
| **cargo-nextest sharding** (Rust) | Partition tests across machines/cores; per-test process isolation | Slow serial suites | **Partially** — Elixir's native equivalent is `mix test --partitions N` + `MIX_TEST_PARTITION` (verified ~31% faster on Ecto-heavy suites) | Use `--partitions` on the **non-async-dominated** lanes (integration/proof/package), NOT nextest. Skip nextest's auto-retry (anti-feature). |
| **Rails parallel tests, DB-per-worker** (Ruby) | Each parallel worker gets its own DB → safe concurrency for non-async DB tests | Cross-test data leak in shared sandbox | **Yes, directly** | When partitioning, give each partition its **own Postgres database** (or use Ecto SQL Sandbox per-partition); merge coverage after. This is the unlock for the 64 non-async DB modules. |
| **pytest-xdist + flaky quarantine + JUnit** (Python) | `-n auto` parallelism, quarantine flaky, JUnit artifacts | Flaky tests blocking merge | **Yes** | `--partitions` ≈ xdist; `@tag :quarantine` ≈ quarantine (seed-logged, nightly, non-blocking); add JUnit formatter. |
| **Go test caching + small package tests** (Go) | Per-package result cache skips unchanged tests | Re-running unchanged tests | **No (cleanly)** — ExUnit has **no per-test result cache**; the Elixir analogue is incremental `_build` compile caching (already have) | Don't chase a Go-style test cache. Invest in correct `_build`/deps cache keys instead. |
| **Node PM-cache vs node_modules** (JS) | Cache the package-manager cache, not built `node_modules` | Stale built artifacts | **Yes** | Already cache `deps`/`_build`; for the Playwright/`adoption_demo` lanes cache the npm PM cache, not built artifacts; `npx playwright install` is a cost worth caching. |
| **Java integration-test separation + test reports** (JVM) | Unit vs integration split; published reports | Integration dominating PR | **Yes** | Already lane-separated (`integration`, `proof`, `package-consumer`); finish the job by moving heavy integration to main/nightly + publish JUnit. |
| **Toolchain pinning** (Rust `rust-toolchain.toml`) | Exact, reproducible toolchain | Drift / `latest` surprises | **Yes** | `erlef/setup-beam` with exact versions (already pinned 1.15/26, 1.17/27); avoid `ubuntu-latest` drift — repo already uses `ubuntu-22.04` (good). |

**Does NOT apply:** nextest's retry-as-default (banned); Go's test-result cache (no ExUnit equivalent); SaaS visual-regression as a gate (anti-feature). Adopt: native `--partitions`, DB-per-partition, quarantine-with-seed, JUnit artifacts, PM-cache for Node lanes.

---

## Sources

- This repo (authoritative): `.github/workflows/ci.yml` (14 jobs), `mix.exs` (`precommit: ["test"]`, no `mix ci`), `test/test_helper.exs` (sandbox `:manual`, default tag excludes), `RUNNING.md ## Maintainer: CI lane severity` + CI-04 static-analysis policy, `scripts/ci/adoption_demo_e2e.sh`, `scripts/install_smoke.sh`, 124 test files (60 async / 64 non-async; tag census)
- `.planning/seeds/SEED-003-ci-cd-performance-audit.md` (authoritative spec: north-star hierarchy, `[BASELINE FIRST]`, `[TEST VALUE CLASSIFICATION]`, `[DARK CORNERS]`, `[IDEAL SHAPE]`, stepwise-PR sequence)
- Mix `--partitions` / `MIX_TEST_PARTITION` semantics and ~31% Ecto-heavy speedup — [Mix.Tasks.Test (HexDocs)](https://hexdocs.pm/mix/Mix.Tasks.Test.html), [elixir-lang/elixir#10853](https://github.com/elixir-lang/elixir/issues/10853), [elixir-ecto/ecto#3599](https://github.com/elixir-ecto/ecto/issues/3599)
- Ecto sandbox shared-mode cannot be async — [Elixir Forum: test partition + shared sandbox](https://elixirforum.com/t/does-test-partition-fasten-ecto-sandbox-shared-mode-test/50272)
- GitHub Actions Elixir CI cache-key (OS+Elixir+OTP+lock) + cache-hit output + step-ordering for fail-fast — [Fly.io Phoenix Files: GitHub Actions for Elixir CI](https://fly.io/phoenix-files/github-actions-for-elixir-ci/), [Hashrocket: Build the Ultimate Elixir CI](https://hashrocket.com/blog/posts/build-the-ultimate-elixir-ci-with-github-actions)

---
*Feature research for: CI/CD pipeline capabilities (Elixir/Phoenix/Ecto OSS Hex library — Rindle v1.20)*
*Researched: 2026-06-20*
