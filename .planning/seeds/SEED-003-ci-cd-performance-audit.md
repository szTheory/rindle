---
id: SEED-003
status: open
planted: 2026-06-20
planted_during: post-ship Cohort demo polish (#27/#28/#29) — maintainer noticed ~15min PR feedback
trigger_when: "Next `gsd new milestone`, OR sooner if PR CI wall-clock or flakiness becomes a felt drag on contributor/maintainer velocity. Surface whenever scope touches CI/CD, test-suite runtime, release engineering, or developer experience."
scope: Medium-Large
---

# SEED-003: CI/CD pipeline performance + reliability audit

## Why This Matters

PR CI wall-clock is **~15–17 minutes** (measured 2026-06-20 across recent `ci.yml` runs).
The critical path / long pole is the **`Package Consumer Proof Matrix + Release Preflight`**
lane (~15m); **`Adoption Demo E2E`** is ~5–7m; lint/quality/unit jobs finish in ~2m. So a
contributor waits ~15 min for a green check, dominated by one heavy lane. There is real,
unaddressed room to cut feedback time, harden determinism, and use runner cores better —
without dropping quality signal.

We've also been **bitten repeatedly this milestone by gate behaviour that only reproduces in
CI's Linux Chromium** (Atkinson-on-freetype 3px overflow; runtime polish-gate text-contrast
stricter than the token-pair gate). That argues for: faster local reproduction of the exact
gates, and clearer separation of fast-PR vs slow-thorough lanes.

## When to Surface

Next `gsd new milestone`, or sooner if CI time/flakiness is hurting velocity. Good candidate
for a focused **v1.20** (or a dedicated infra slice) — it's self-contained, high-DX-leverage,
and not blocked by feature work.

## Scope Estimate

**Medium-Large.** A measure → classify → restructure pass: baseline metrics, test-value
classification (keep/optimize/move-to-nightly/quarantine/delete), ExUnit async + partitioning,
cache correctness, matrix/trigger refinement (fast PR gate vs nightly compatibility vs
release), security/supply-chain posture, and a single local `mix ci` equivalent. Stepwise PRs,
not one big-bang rewrite.

## Starting Baseline (measured 2026-06-20, for future-me)

| Lane | ~Duration | Notes |
|---|---|---|
| Package Consumer Proof Matrix + Release Preflight | ~15m | **long pole** — gates PR wall-clock |
| Adoption Demo E2E | ~5–7m | Playwright (Chromium 1.60.0); polish + behavior + contrast |
| Quality (1.15/1.17 × OTP) | ~2m each | lint/static — runs per matrix entry (check for redundancy) |
| Adoption Demo Unit | ~2m | ExUnit |
| Cohort Demo Smoke, GCS/Mux soak, ADMIN-06, Integration, Contract, Proof, Adopter | <1–3m | |

PR wall-clock ≈ 15–17m. Dark corners to check first: lint redundancy across the matrix; the
Package-Consumer lane's scope (could most move to nightly/release?); E2E determinism on Linux;
cache keys/restore breadth; whether a fast-PR vs nightly split would cut feedback to <5m.

## How To Run (the maintainer's locked prompt)

When this seed is activated, run the maintainer's full CI/CD performance-audit prompt verbatim
(below). It is the authoritative spec for the pass — research-driven, multi-lens, evidence-based,
stepwise PRs, "keep high-value tests / drop lowest-value", max core utilization without
over-engineering.

<details>
<summary>Embedded prompt — CI/CD performance audit (run verbatim)</summary>

```text
audit our ci/cd pipeline make sure it's as efficient as possible, great DX also important and efficient so like not wasting our time or CI runner time

but yeah we want to keep the high value tests just dropping the lowest quality ones, poorest quality least value. i think it's nice to be able to boil the ocean especially with AI/LLM help nowadays i'm just saying i want to identify bottlenecks and clean them up, make sure things aren't flaky, that they're reliable deterministic as possible gates, consider the hat/lens of someone who is trying to optimize for all this all the things they might come up with be very comrpehensive we want to address each of them systematically

also making sure we're using all of the cpus/cores on our github runners max efficiently while keeping it simple (at least, not overcomplicating it), speedy feedback for developer great DX efficient runtime reliable avoiding pitfalls with caching (caching is fine but do it right), we like fast/deterministic/reliable/bulletproof specs... high quality maintainable

=====

<INFLATED_COMPANION_PROMPT_FOR_CI_CD_PERFORMANCE_AUDIT>

You are acting as a combined principal Elixir maintainer, OSS library maintainer, GitHub Actions expert, SRE/DevOps engineer, test architect, DX-focused staff engineer, release engineer, security/supply-chain reviewer, and practical software economist.

We are auditing the CI/CD pipeline for one or more OSS Elixir libraries/apps. The goal is not "make CI look fancy." The goal is to make the pipeline fast, deterministic, trustworthy, resource-efficient, maintainable, and pleasant for contributors, while preserving or increasing the actual quality signal.

The original human prompt is high-priority taste/context. Preserve its intent:
- fast feedback for developers
- reliable deterministic gates
- no wasting maintainer time or CI runner time
- keep high-value tests
- remove or demote low-signal / redundant / flaky / poorly scoped checks
- use all available runner CPU/core resources intelligently without overcomplicating things
- do not "optimize" by hiding risk
- prefer boring, idiomatic, least-surprise CI
- optimize for OSS contributor DX and maintainer sanity

Do not give generic CI advice. Make concrete, repo-specific recommendations.

[OPERATING MODE] Work as a serious one-shot architecture/research pass. Use subagents if available; else simulate separate expert passes and merge. Minimum lenses: (1) GitHub Actions topology + critical-path analyst, (2) Elixir/Mix/ExUnit performance, (3) Phoenix/Plug/Ecto specialist where applicable, (4) test quality/flakiness/determinism, (5) CI caching/artifact strategy, (6) OSS maintainer DX/onboarding, (7) security/supply-chain/release, (8) lessons-from-successful-libraries researcher, (9) simplicity reviewer who deletes cleverness, (10) final integrator who makes recommendations coherent. Use current official docs (GitHub Actions, Elixir/Mix/ExUnit, Ecto/Phoenix/Plug, setup-beam, Dialyxir/Credo/Sobelow/ExCoveralls) and respected Elixir OSS workflows (Phoenix, Ecto, Plug, Broadway, Nx, Oban, Livebook, Ash, Tesla, Finch). Transfer cross-ecosystem patterns (cargo-nextest, Go test caching, Rails parallel tests, pytest-xdist, Node CI) only when they apply cleanly. If you cannot inspect a file, say so; do not hallucinate.

[INPUTS TO READ] .github/workflows/*, .github/actions/*, dependabot.yml, codeql/*, reusable workflows, branch protection/required checks, recent run history + timings + reruns + cache logs. Elixir: mix.exs, mix.lock, .tool-versions/.mise.toml, .formatter.exs, .credo.exs, dialyzer config, config/test.exs, test/test_helper.exs, test/support/*, Makefile/justfile/scripts/*, umbrella apps/*/mix.exs, assets/package.json+lockfiles+esbuild/tailwind. Project: README/CONTRIBUTING/CHANGELOG, release docs, Hex metadata, docs config, prompts/ + research, existing CI/slow-test/flaky/coverage/Dialyzer TODOs. Historical: 20–50 recent runs, PR vs main vs release timings, cold vs warm cache, common failures, flaky reruns, avg + p95 wall-clock, queue vs exec time, per-step duration, cache size/hit rate, deps install, compile, test, slowest tests, DB/container startup, asset build.

[NORTH STAR hierarchy] 1 correctness/trust of gates, 2 deterministic non-flaky feedback, 3 fast PR feedback on likely regressions, 4 efficient runner/cache use, 5 maintainable simple YAML, 6 contributor friendliness, 7 security posture, 8 presentation. Never trade trust for speed without labeling it a tradeoff in an optional tier. Never "just retry flaky tests" as the fix. Never delete slow tests merely for being slow — classify first. No Rube Goldberg CI.

[BASELINE FIRST] Produce a table (workflow, trigger, job, runner, matrix, services, command, avg dur, p95, failure/rerun rate, cache usage, required?, quality signal, bottleneck, notes). Compute the critical path; distinguish PR fast path / push-to-main / scheduled-nightly / release-publish / docs / security paths. Where data is missing, give exact commands to obtain it. Diagnostics: mix test --slowest 20; mix test --profile-require; MIX_ENV=test mix compile --profile time; mix xref graph --label compile-connected (+ --format cycles); mix deps.unlock --check-unused; mix deps.get --check-locked; mix format --check-formatted; mix compile --warnings-as-errors; mix hex.audit; mix deps.audit / mix dialyzer / mix credo --strict / mix sobelow only where already present or clearly valuable; print System.schedulers_online(); print cache hit/miss in CI summaries; collect top slow tests + slow compile modules.

[TEST VALUE CLASSIFICATION] For every major test/check: what bug class it catches; how often it fails usefully; deterministic?; fast enough for PR?; redundant?; behavior vs implementation-trivia?; over-broad integration for a unit concern?; needs network/time/random/global state?; movable to nightly?; splittable/shardable?; async-safe?; cheaper fixtures?; actionable output? Buckets: A keep in PR gate; B keep in PR but optimize; C move to scheduled/main/release; D quarantine/fix before trusting; E delete or rewrite. Be conservative on deletion — evidence required.

[ELIXIR-SPECIFIC] (5.1) ExUnit concurrency: which modules can be async:true; why non-async (DB sandbox, global app env, named ETS, registered procs, fs paths, ports, time, randomness, process dict, Mox global, Bypass/global HTTP, Application env mutation, Logger capture, telemetry); convert safe modules; never async if mutating global state; split huge modules; tune max_cases only after measuring vs schedulers_online/CPU count. (5.2) Partitioning: mix test --partitions N + MIX_TEST_PARTITION when non-async/integration dominate; explain overhead (dup setup/compile, service contention, coverage merge); isolate DB per partition; merge coverage; pick count from evidence; don't oversubscribe small runners. (5.3) Ecto/Phoenix/Plug: SQL Sandbox correctness for concurrent transactional tests; pool sizes vs async/partitions; shared-sandbox tests must not be async; LiveView/channel/endpoint sandbox allowances + ownership; Plug/Cowboy/Bandit port + registered-process conflicts; separate unit from DB/service/container integration; don't rebuild assets in pure-Elixir test jobs; cache node PM data; deterministic service-readiness (no sleeps). (5.4) Mocks: behaviour-based (Mox), private/async-safe, no global mocks for async; replace real network with local fakes/Bypass/Mox/contract tests; real-service integration -> scheduled/release, labeled. (5.5) Compile perf: mix compile --profile time + xref; compile-connected chains + macro-heavy recompiles; pragmatic cycle guardrails only if a real problem. (5.6) Dialyzer: cache PLT with key incl OS/OTP/Elixir/lockfile/config; split restore/save so failures still persist PLT; place in PR/main/scheduled by runtime+value; useful annotations; don't make it a mandatory PR gate for a poorly-spec'd lib without a real remediation plan. (5.7) format --check-formatted (fast, PR-gated); deps.get --check-locked; deps.unlock --check-unused; compile --warnings-as-errors where it adds signal without dup; hex.audit + mix_audit per security posture.

[GITHUB ACTIONS] (6.1) Triggers: pull_request, push-default, merge_group, workflow_dispatch, schedule, tags/releases, docs-only, path filters. Footguns: path-filtered REQUIRED checks leaving PRs pending; commit-message skip blocking required checks; pull_request_target with untrusted fork code; scheduled-only correctness-critical tests. Model: PR fast representative gate; main same/slightly broader; nightly broad matrix + slow integration + security + coverage + exhaustive; tags/releases full verification before publish. (6.2) Concurrency: cancel outdated PR runs; never cancel main/release; workflow-specific group names; serialize deploy/release. (6.3) Runner selection: explicit Ubuntu vs ubuntu-latest; CPU/mem; avoid ubuntu-slim for heavyweight; larger runners only if justified; service-container + disk overhead; do you actually need macOS/Windows/ARM. Detect actual CPUs in logs and tune. (6.4) Matrix: avoid OS×OTP×Elixir×adapter×partition explosion; latest supported as primary lint/test; min supported for compat; 1–2 intermediates only if needed; broad matrix on scheduled/main not every PR; lint/static on one entry; integration adapter matrix separate from unit; fail-fast:false for compat matrices, default for homogeneous shards; justify each dimension (what compatibility promise, required every PR?, real historical bugs?, schedulable?). (6.5) setup-beam: erlef/setup-beam, exact versions/policy aligned to mix.exs min, valid OTP/Elixir combos, capture resolved versions. (6.6) Caching as correctness-sensitive: audit paths/key specificity/restore breadth/hit rate/stale failure modes/size-eviction/cross-matrix safety/miss-still-runs-correctly. Key dims: OS, arch, OTP, Elixir, MIX_ENV, lockfile hash, cache-version buster, tool-config hash for PLT/assets. Don't restore _build across incompatible OTP/Elixir/MIX_ENV; don't skip deps.get after partial restore; don't cache artifacts masking warnings/stale compile; separate deps cache from PLT; restore/save split for PLT; document cache-bust. Decide what to cache: deps, _build, PLTs, rebar3, asset PM cache, downloaded tools — not cheap/risky build artifacts. (6.7) Artifacts: JUnit/coverage/flaky logs/docs preview/release tarballs from trusted workflows only; avoid value-less slow artifacts. (6.8) Required checks: stable names; don't require every matrix child unless intentional; a final summary/required job depending on matrix jobs; skipped required jobs must report success; avoid path/branch-filter pending traps; document in CONTRIBUTING.

[SECURITY/SUPPLY-CHAIN/RELEASE] Review top-level + per-job permissions, GITHUB_TOKEN, third-party actions + pinning, Dependabot/Renovate, secrets exposure to forks, pull_request_target, shell injection from untrusted PR metadata, release/tag workflows, Hex publishing, docs publishing, provenance/signing, OIDC vs long-lived creds. Recommend: permissions: contents: read default; write only where needed; pin third-party actions to immutable SHAs (or justify tag + Dependabot); OIDC over long-lived creds; release/publish only on trusted refs/tags after tests pass; dry-run publish; never run untrusted fork code with secrets; no random third-party actions for trivial shell. Hex release: verify metadata, docs build, changelog/version/tag semantics, mix hex.publish --dry-run, scoped keys, release job depends on full verification.

[DX] Single local CI equivalent (mix ci / make ci / just ci) documented in CONTRIBUTING; readable grouped logs; warnings as annotations; slowest-tests report; flaky tests labeled with repro seed; service vs test failures distinguishable; observable caches; clear matrix job names; README badge reflects meaningful required checks; new contributor can run the same checks locally. Recommend a mix ci alias (deps check, format, compile warnings-as-errors, unused deps, tests, optional lint/dialyzer/security) + job summaries (versions, cache hits, timing, slowest tests, coverage link) + clear job names (test / elixir 1.19 / otp 28, lint / latest, integration / postgres, compat / min-supported) + minimal YAML comments. Optimize for external contributors hitting a red check.

[LESSONS] Research Phoenix/Ecto/Plug/Broadway/Livebook/Nx/Finch/Tesla/Oban/Ash + same-domain libs: matrix shape, min/latest policy, where lint runs, cache strategy, partitioning, integration isolation, release workflow, action pinning, docs publishing, coverage policy, security checks, contributor docs. Cross-ecosystem (Rust nextest/sharding/toolchain pinning; Go test caching + small package tests; Rails DB parallelization schema-per-worker; pytest xdist + flaky quarantine + JUnit; Node PM-cache vs node_modules; Java test reports + integration separation) — only where applicable. For each: what they do right, footguns avoided, what doesn't apply, how to adapt.

[OUTPUT FORMAT] 1 Executive summary (top 5 changes, impact, risk, first PR). 2 Current pipeline map. 3 Baseline metrics (durations table, critical path, cold/warm cache, flaky history). 4 Findings by category (correctness, perf, determinism, caching, matrix/version, test quality, security, release, DX). 5 Prioritized recommendations (Title, Priority P0–P3, Category, Current issue, Proposed change, Why idiomatic, Pros, Cons/tradeoffs, Expected impact, Risk, How to implement, How to verify, Rollback). 6 Proposed target pipeline (PR/main/nightly/release/docs/security). 7 Concrete patches (minimal coherent YAML/Mix/config; stepwise PRs: 1 observability/baseline, 2 cache/version cleanup, 3 test concurrency/partitioning, 4 matrix/trigger refinement, 5 release/security polish). 8 Test cleanup plan (keep/optimize/fix-or-quarantine/delete-or-rewrite/move-to-nightly). 9 Validation plan (before/after wall-clock, p95 PR runtime, cache hit rate, failure/rerun rate, top slow tests, compile time, mean-time-to-actionable-failure, contributor repro). 10 Final mix ci / local command. 11 Open questions/assumptions (only decision-affecting; don't block).

[PRIORITIZATION RUBRIC] Score 1–5 on runtime impact, reliability/determinism, quality-signal, maintainer complexity, security, contributor DX, reversibility. Prefer high runtime/reliability/DX + low complexity + easy rollback + strong idiomatic fit. Be skeptical of high-cleverness/small-speedup/hard-to-debug/hidden-risk/fragile-cache/hard-repro.

[DARK CORNERS — do not miss] required checks stuck pending from path/branch/commit-message skip; matrix explosion (OS×OTP×Elixir×DB×partition); lint redundant across every matrix entry; ubuntu-latest drift; ubuntu-slim for heavyweight; restoring _build across incompatible OTP/Elixir/MIX_ENV; broad restore keys -> stale deps; skipping deps.get after partial restore; PLT cache not saved on Dialyzer failure; PLT key missing OTP/Elixir/lock dims; tests async while mutating Application env/global; Mox global mode blocking async; DB sandbox ownership across processes; partitions sharing a DB; fixed ports in async tests; Process.sleep as readiness/race mask; real network in PR tests; random data without reproducible seed; huge test modules limiting concurrency; coverage slowing every PR without gate value; doctests compiling too much / unstable docs; integration containers dominating PR; security scans hitting network and flaking; stale action versions; overprivileged GITHUB_TOKEN; secrets to untrusted PR contexts; release not depending on CI; publishing without dry-run/metadata/docs checks; branch protection requiring unstable matrix names; local commands diverging from CI; opaque logs without actionable guidance.

[IDEAL SHAPE — adapt, don't blindly copy] PR: checkout; setup-beam exact Elixir/OTP; restore deps/_build with precise key; deps.get --check-locked; fast lint on latest only (format, unused deps, compile warnings-as-errors); tests on latest pair; tests on min pair if compat matters; partitions only if suite is actually long; no broad integration matrix unless necessary. Main: same as PR + maybe broader compat + coverage/docs artifact. Nightly: full OTP/Elixir matrix + slow integration/adapters + security/dep audit + Dialyzer if too slow for PR + exhaustive/property + coverage. Release/tag: depends on full verification + docs build + package dry-run + publish to Hex from trusted tag only + minimal permissions + secrets only in publish job. Docs/UI: only if relevant; don't block code PRs unless docs are part of the quality contract.

[TONE] Opinionated but evidence-based. Direct ("Do this." / "Do not." / "Not worth it." / "Worth it despite cost because…"). Surface tradeoffs honestly. No generic "use caching" without exact keys/paths/failure modes. No vague "consider optimizing tests" — name concrete categories/files/patterns. Final output = one integrated CI/CD design, not a pile of tips.
</INFLATED_COMPANION_PROMPT_FOR_CI_CD_PERFORMANCE_AUDIT>
```

</details>

## Related

- [[reference_minio_local_test_run]] — local MinIO suite (a known slow/integration lane).
- Lessons banked this milestone: CI Linux Chromium reproduces gate failures macOS doesn't
  (font metrics, runtime contrast) — a fast faithful-Linux local repro path would help DX.
