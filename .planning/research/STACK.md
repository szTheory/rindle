# Stack Research

**Domain:** Fast, deterministic CI/CD tooling for an Elixir/Phoenix/Ecto Hex library (v1.20 — DX/infra milestone, ZERO `lib/` public API change)
**Researched:** 2026-06-20
**Confidence:** HIGH on versions and idioms (verified against Hex.pm + official docs + Phoenix/Dashbit prior art on 2026-06-20); MEDIUM on partitioning payoff for *this* suite (depends on measured async-safety, not yet inspected) and on exact runner core counts (must be printed from CI logs).

> This is a **tooling-and-versions** dossier, not a greenfield stack pick. Rindle already has a 14-job `ci.yml`. Everything below is framed as **what to ADD / PIN / SPLIT / NOT add** against that real file. Every recommendation names the existing job it touches and its **PR-vs-nightly** placement.

---

## Headline Recommendations (the locked set)

1. **Pin `erlef/setup-beam` to a release SHA + add `version-type: strict`**, and align the version *matrix* to `mix.exs` (`elixir: "~> 1.15"`). The min-supported pair stays `1.15/OTP 26`; the primary lint/test pair should move to a current pair (`1.18/OTP 27`) — see the matrix note. Capture resolved versions via the action's `steps.*.outputs`.
2. **Split the PLT cache into `actions/cache/restore` + `actions/cache/save` (always-save)** so the PLT persists even when Dialyzer fails. Add OTP+Elixir+lockfile+config dims to the PLT key. Leave deps/_build on the single-step `actions/cache@v4` (their save-on-success behavior is correct).
3. **Add a real `mix ci` alias** (currently `precommit: ["test"]` only) mirroring the Phoenix-1.8 `precommit` idiom, so local == PR gate. This is the single highest-DX, lowest-risk change.
4. **Run lint/static ONCE on the latest pair, not per matrix entry.** Today `format`/`credo`/`doctor`/`dialyzer` run inside the 2-entry `quality` matrix → redundant. Hoist them to a single `lint` job on the latest pair.
5. **Enable `mix test --warnings-as-errors` and `mix test --slowest 20`** in the PR test lane (Elixir ≥1.12 supports the flag; you no longer need `compile --warnings-as-errors` *and* a separate compile of test files for warning signal).
6. **Add supply-chain hygiene**: `:mix_audit` dep + `mix deps.audit` and `mix hex.audit` as a fast PR step; pin ALL third-party actions to SHAs; add `dependabot.yml` for `github-actions`; keep top-level `permissions: contents: read` (already present) and grant `write` only per-job (release.yml already does this well).
7. **Partitioning (`--partitions`) is a MAYBE, gated on measurement** — add `mix test --slowest`/`--profile-require` + `mix xref graph` observability FIRST; only shard if the suite is genuinely long after async-safety conversion. Do **not** shard a 2-minute unit suite.

---

## Recommended Stack

### Core Technologies (CI runner toolchain)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| `erlef/setup-beam` | **v1 → pin to a release SHA** (latest tag is **v1.20.x**; `@v1` is a moving major tag) | Installs Erlang/OTP + Elixir on the runner; emits resolved versions | The ecosystem-standard BEAM installer. `@v1` floats; for a release lib pin to an immutable SHA + Dependabot. Exposes `outputs.otp-version`, `outputs.elixir-version`, `outputs.setup-beam-version` — capture these in the job summary so a green run records exactly what ran. Use `version-type: strict` so a bad/ambiguous version string fails fast instead of resolving fuzzily. |
| `actions/checkout` | **v4 → pin to SHA** | Checkout | Already on `@v4`; pin to SHA for supply-chain. |
| `actions/cache` | **v4** (+ `cache/restore` & `cache/save` sub-actions for PLT) | deps / `_build` / PLT / asset PM caching | v4 is the current generation (v1–v3 deprecated; the old `set-output`/Node16 generations are gone). The **restore/save split** is the idiomatic way to persist a cache even when a later step fails — essential for PLT. |
| `actions/setup-node` | **v4** (Node **20 LTS** → consider **22 LTS**) | Node for Playwright/brandbook lanes | Already `@v4`/Node 20. Node 20 goes EOL 2026-04; **bump to Node 22 LTS** during this milestone. Add `cache: npm` + `cache-dependency-path` to cache the npm cache (NOT `node_modules`). |
| `actions/upload-artifact` | **v4** | Playwright report on failure | Already `@v4`; pin to SHA. Note v3 was retired Jan-2025, so v4 is mandatory. |
| `googleapis/release-please-action` | **v4** | Release PR automation | Already `@v4` in `release.yml`; pin to SHA. |
| Ubuntu runner | **`ubuntu-24.04`** (currently `ubuntu-22.04`) | Job host | Pin explicitly (you already avoid `ubuntu-latest` — good). `ubuntu-22.04` is fine but `ubuntu-24.04` is GA and the default `ubuntu-latest` migrated to it; standard hosted Linux runner = **4 vCPU**. Print `nproc` / `System.schedulers_online/0` once to confirm before tuning `--max-cases`/partitions. |

### Supporting Libraries (Mix dev/test tools — versions verified on Hex.pm 2026-06-20)

| Library | Version (current) | In `mix.exs` now | Purpose | PR vs Nightly |
|---------|-------------------|------------------|---------|---------------|
| `credo` | **1.7.19** (rel. 2026-06-05) | `~> 1.7` ✓ | Style/consistency lint | **PR**, fast (<10s). Currently `continue-on-error: true` (advisory per CI-04). Keep advisory unless you want to flip to blocking — that's a policy call, not a version call. |
| `dialyxir` | **1.4.7** (rel. 2025-11-06) | `~> 1.4` ✓ | Dialyzer wrapper | **Nightly + main** (not every PR). PLT build is the cost; advisory today (CI-04). Keep PLT split-cached. A poorly-spec'd 0.x lib should not hard-gate PRs on Dialyzer. |
| `mix_audit` (`:mix_audit`) | **2.1.5** (rel. 2025-06-09) | **ABSENT — ADD** | `mix deps.audit` — scans deps for known CVEs (advisory DB) | **PR**, fast. Add `{:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}`. |
| `sobelow` | **0.14.1** (rel. 2025-10-14) | **ABSENT** | Phoenix-app security scanner | **DO NOT ADD to core.** Sobelow targets *Phoenix applications* (router/controller/config sinks), not pure libraries. Rindle's `lib/` is a library; Sobelow would mostly no-op or false-positive. Could run it on `examples/adoption_demo` (a real Phoenix app) in **nightly** only. Maintenance cadence is slow — verify before relying on it. |
| `excoveralls` | **0.18.5** (rel. 2025-01-26) | `~> 0.18` ✓ | Coverage (`mix coveralls`) | **Keep on main/nightly; reconsider on every PR.** `mix coveralls` instruments the whole suite and slows it; if there's no coverage *gate* (min %), running it on every PR buys little. Replace PR test step with plain `mix test --warnings-as-errors --slowest 20`; keep `coveralls` on push-to-main. |
| `doctor` | `0.22.0` ✓ | `0.22.0` ✓ | `@doc`/`@spec` coverage gate | **PR** (already advisory). Cheap. Fine as-is. |
| `mix hex.audit` | built into Hex | n/a | Flags retired deps | **PR**, free, instant. Add to `mix ci`. |
| `mix deps.unlock --check-unused` | built into Mix | n/a | Rejects stale `mix.lock` entries | **PR**, instant. Add to `mix ci`. |
| `mix deps.get --check-locked` | built into Mix | n/a | Fails if lock would change | **PR**, instant. Add to `mix ci` (replaces bare `mix deps.get` in the gate). |

### Development / Determinism Tools (built-in Mix + ExUnit — no new deps)

| Tool / Flag | Purpose | Notes & PR-vs-nightly |
|------|---------|-------|
| `mix test --warnings-as-errors` | Compile-warning gate folded into the test run | Elixir ≥1.12. **PR.** Lets you drop the *separate* compile-of-test-files just for warnings. Keep `mix compile --warnings-as-errors` for `lib/` in the lint job. |
| `mix test --slowest 20` | Prints 20 slowest tests/modules | **PR (observability) + emit to `$GITHUB_STEP_SUMMARY`.** Zero added runtime beyond reporting. This is the data needed to decide partitioning. |
| `mix test --slowest-modules N` | Per-module slow report (Elixir 1.17+) | Available on your 1.17 lane; better signal than per-test for async planning. |
| `mix test --partitions N` + `MIX_TEST_PARTITION` | Shard the suite across N parallel matrix jobs | **MAYBE — measure first.** Each partition needs its **own DB** (`rindle_test${MIX_TEST_PARTITION}`) and re-compiles + re-boots services → real per-shard overhead. Only worth it if the suite is long *after* async conversion. Merge coverage if you keep coveralls. Don't oversubscribe a 4-vCPU runner with >2-3 partitions. |
| `--max-cases` | Concurrency within one `mix test` (default = `2 * schedulers_online`) | Tune **only after** printing `System.schedulers_online/0`. Default is usually right on a 4-vCPU runner; raising it without measurement just thrashes the DB pool. |
| `--profile-require` | Profiles `test_helper`/`require` time | **Local/nightly diagnostic**, not a gate. Use once to find slow test-helper compilation. |
| `MIX_ENV=test mix compile --profile time` | Per-module compile-time profile | **Local/nightly diagnostic.** Finds macro-heavy / recompile-thrashing modules. |
| `mix xref graph --label compile-connected` (+ `--format cycles`) | Compile-time dependency fan-out / cycles | **Local/nightly diagnostic.** Use to spot a module whose change recompiles half the tree (a cache-thrash and incremental-compile killer). |
| ExUnit `async: true` | Per-module test parallelism | **The single biggest test-speed lever** and it's free. Audit which modules are safe (no `Application` env mutation, no global Mox, no named ETS/registered procs, no fixed ports, Ecto SQL Sandbox in `:manual`/per-test checkout). Convert safe modules; never async modules that mutate global state. This precedes any `--partitions` decision. |

---

## The `mix ci` Alias (canonical pattern — ADD this)

Today `mix.exs` has only `precommit: ["test"]` and a `test:` alias that does `ecto.create/migrate`. There is **no `mix ci`**, so local ≠ CI (a documented DX gap in SEED-003). Adopt the Phoenix-1.8 `precommit` idiom (the community-canonical shape; Phoenix's generated `mix.exs` ships exactly this group):

```elixir
defp aliases do
  [
    # ... existing setup / ecto.* / test aliases ...

    # Single local == PR gate. Mirrors the fast PR lane exactly.
    ci: [
      "deps.get --check-locked",
      "deps.unlock --check-unused",
      "format --check-formatted",
      "compile --warnings-as-errors",
      "hex.audit",
      "deps.audit",        # requires {:mix_audit, "~> 2.1"}
      "test --warnings-as-errors --slowest 20"
    ]
  ]
end
```

Notes:
- Phoenix 1.8 generates `precommit: ["compile --warning-as-errors", "deps.unlock --check-unused", "format", "test --warnings-as-errors"]`. The `ci` alias above is that pattern hardened for a *published library* (adds `--check-locked`, `--check-formatted`, `hex.audit`, `deps.audit`).
- `mix test --warnings-as-errors` is valid on Elixir ≥1.12 (per Dashbit "Warnings as errors and tests"), so warning enforcement lives in the one test run.
- Keep `precommit` as an alias *to* `ci` (or leave the lighter `precommit` for fast inner-loop) — but the **PR `quality`/`lint` job should literally run `mix ci`** so the gate and local command can never drift. Document `mix ci` in `RUNNING.md`/`CONTRIBUTING`.

---

## Caching: exact key recipes (correctness-sensitive)

Rindle's current keys are decent but miss two dims (**arch** and **MIX_ENV**) and the PLT cache is **single-step** (lost on Dialyzer failure). Recommended:

```yaml
# deps — single-step actions/cache@v4 is correct (save-on-success is fine; deps.get re-runs anyway)
- uses: actions/cache@v4
  with:
    path: deps
    key: deps-${{ runner.os }}-${{ runner.arch }}-otp${{ steps.beam.outputs.otp-version }}-ex${{ steps.beam.outputs.elixir-version }}-${{ env.MIX_ENV }}-v1-${{ hashFiles('**/mix.lock') }}
    restore-keys: deps-${{ runner.os }}-${{ runner.arch }}-otp${{ steps.beam.outputs.otp-version }}-ex${{ steps.beam.outputs.elixir-version }}-${{ env.MIX_ENV }}-v1-

# _build — same dims; NEVER restore _build across incompatible OTP/Elixir/MIX_ENV
- uses: actions/cache@v4
  with:
    path: _build
    key: build-${{ runner.os }}-${{ runner.arch }}-otp${{ steps.beam.outputs.otp-version }}-ex${{ steps.beam.outputs.elixir-version }}-${{ env.MIX_ENV }}-v1-${{ hashFiles('**/mix.lock') }}
    restore-keys: build-${{ runner.os }}-${{ runner.arch }}-otp${{ steps.beam.outputs.otp-version }}-ex${{ steps.beam.outputs.elixir-version }}-${{ env.MIX_ENV }}-v1-
```

**PLT — split restore/save so it persists on Dialyzer failure:**

```yaml
- name: Restore PLT cache
  id: plt-cache
  uses: actions/cache/restore@v4
  with:
    path: priv/plts
    key: plt-${{ runner.os }}-${{ runner.arch }}-otp${{ steps.beam.outputs.otp-version }}-ex${{ steps.beam.outputs.elixir-version }}-v1-${{ hashFiles('mix.lock', '.dialyzer_ignore.exs') }}
    restore-keys: plt-${{ runner.os }}-${{ runner.arch }}-otp${{ steps.beam.outputs.otp-version }}-ex${{ steps.beam.outputs.elixir-version }}-v1-

- name: Build PLT
  if: steps.plt-cache.outputs.cache-hit != 'true'
  run: mix dialyzer --plt

# CRITICAL: save AFTER building the PLT but BEFORE running dialyzer,
# so a Dialyzer *finding* (non-zero exit) does not discard the expensive PLT.
- name: Save PLT cache
  if: steps.plt-cache.outputs.cache-hit != 'true'
  uses: actions/cache/save@v4
  with:
    path: priv/plts
    key: ${{ steps.plt-cache.outputs.cache-primary-key }}

- name: Dialyzer
  run: mix dialyzer --format github
```

Key-dimension rules (the audit's [6.6] dark corners):
- **Cache-version buster** (`-v1-`): bump to invalidate the whole class without editing every key.
- **Separate caches** for `deps`, `_build`, `priv/plts`, and the npm cache — never one mega-key.
- **PLT key includes OTP + Elixir + lockfile + `.dialyzer_ignore.exs`** (config hash) — the current PLT key omits the ignore file and arch.
- The `deps-no-optional-*` keys in the `optional-dependencies` job are correctly distinct — keep that separation (an optional-pruned `deps` tree must not collide with the full one).
- Restore-keys give warm-but-stale fallback; `mix deps.get` after restore reconciles — **never skip `deps.get` after a partial restore.**

---

## Playwright-in-CI determinism (the `adoption-demo-e2e` lane)

The lane runs `npx playwright install --with-deps chromium` every run and `npm ci`. Determinism tooling that's idiomatic and worth adopting:

| Lever | Recommendation |
|-------|----------------|
| **Pin browser via Playwright version** | The Chromium build is pinned by the `@playwright/test` version in `package-lock.json`. Keep `npm ci` (clean, lockfile-exact) — you already do. Cache the Playwright browser dir keyed on the **resolved Playwright version**, not on lockfile alone. |
| **Cache browser binaries** | Add `actions/cache@v4` for `~/.cache/ms-playwright` keyed on the Playwright version hash; then `npx playwright install --with-deps chromium` is a fast no-op on cache hit. Saves ~30–60s/run. |
| **`workers: 1` in CI** | Set `workers: process.env.CI ? 1 : undefined` in `playwright.config` for stability/determinism on a shared runner (sequential = full resources per test; fewer races). Trade-off: slower, but this lane is already the determinism-sensitive one (the Atkinson/freetype 3px and contrast-gate flakes cited in SEED-003). |
| **`reuseExistingServer: !process.env.CI`** | Always start a fresh server in CI; never reuse a stale dev server. Removes a class of "works locally, flakes in CI" bugs. |
| **`forbidOnly: !!process.env.CI`** | Fail the build if a stray `test.only` is committed. |
| **`retries`** | Allow `retries: 1–2` **only** for genuinely non-deterministic external waits, and surface retried tests in the report — never as a blanket flake-masking knob (the audit's "never just retry flaky tests"). |
| **Deterministic readiness** | The `adoption_demo_e2e.sh` MinIO/server readiness already polls health endpoints (good — no `sleep` masking). Keep that pattern; do not introduce `Process.sleep`-style waits. |

**Do NOT add** a SaaS visual-regression service (Percy/Chromatic/Argos) — SEED-003 explicitly warns against SaaS visual-regression. The existing in-repo contrast/literal gate (`brandbook/src/cohort-contrast.mjs`) + Playwright screenshot specs are the right altitude.

---

## Security / Supply-chain Action Tooling

| Practice | Current state | Recommendation |
|----------|---------------|----------------|
| **Pin third-party actions to SHAs** | All actions use moving tags (`@v4`, `@v1`, `@v2`) | **PIN every third-party action to an immutable commit SHA** with a `# vX.Y.Z` comment. Highest-value: `erlef/setup-beam`, `googleapis/release-please-action`, `google-github-actions/*`, `FedericoCarboni/setup-ffmpeg`. (`actions/*` are first-party/lower-risk but pin for consistency.) |
| **Dependabot for actions** | No `.github/dependabot.yml` observed | **ADD** `dependabot.yml` with a `github-actions` ecosystem (and optionally `mix`) so pinned SHAs get automated bump PRs — pinning without Dependabot rots. |
| **Minimal `permissions:`** | `ci.yml` top-level `contents: read` ✓; `release.yml` grants `write` per-job ✓ | **Already idiomatic.** Keep `contents: read` default; grant `contents/issues/pull-requests: write` only on the `release-please` job; `actions: read` only on `gate-ci-green`. No change needed beyond keeping it tight. |
| **OIDC vs long-lived creds** | `HEX_API_KEY` long-lived secret in `release` environment; GCS via `GOOGLE_APPLICATION_CREDENTIALS_JSON` | **Hex.pm has no OIDC trusted-publishing path today** (npm/PyPI do; Hex does not as of 2026-06) — so a scoped `HEX_API_KEY` in the protected `release` environment is the correct, idiomatic choice. Keep it environment-scoped, not repo-wide. For GCS, `google-github-actions/auth@v2` already supports **Workload Identity Federation (OIDC)** — prefer WIF over the JSON key if the soak lanes are kept; otherwise leave as-is (advisory soak lanes, low blast radius). |
| **Fork-PR secret safety** | Uses `pull_request` (not `pull_request_target`); secrets resolve empty on forks; soak lanes fail-closed ✓ | **Already correct and well-documented** (Phase 36 notes). Do not regress to `pull_request_target`. |
| **Dry-run publish before live** | `mix hex.publish --dry-run --yes` before live ✓; release gated on exact-SHA green CI ✓ | **Already best-in-class.** No change. |

---

## Installation (the concrete adds)

```elixir
# mix.exs deps/0 — ADD (supply-chain):
{:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
```

```bash
# Local DX (after adding mix ci alias):
mix deps.get
mix ci            # == the PR fast gate, runnable locally

# Diagnostics to run ONCE to gather the baseline the audit demands:
mix test --slowest 20
mix test --slowest-modules 20          # Elixir 1.17 lane
MIX_ENV=test mix compile --profile time
mix xref graph --label compile-connected --format cycles
elixir -e 'IO.puts(System.schedulers_online())'   # confirm runner cores
```

```yaml
# .github/dependabot.yml — ADD:
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule: { interval: "weekly" }
  - package-ecosystem: "mix"
    directory: "/"
    schedule: { interval: "weekly" }
```

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `mix ci` Mix alias | `ex_check` (`mix check`, v0.16.0) | `ex_check` runs all linters in parallel with one command and aggregates output — attractive, but it adds a dep and an abstraction layer. For a library that wants local==CI transparency, a plain `mix ci` alias is more boring/legible (audit's "delete cleverness" lens). Use `ex_check` only if you later want parallel-linter aggregation badly. |
| `mix_audit` (`mix deps.audit`) | `mix hex.audit` alone | `hex.audit` only flags *retired* Hex packages; `mix_audit` checks a CVE advisory DB. Run **both** — they catch different things, both are fast. |
| `--partitions` matrix sharding | Single `mix test` with high `async: true` coverage | Prefer async-conversion first (free, no DB-per-shard overhead). Reach for `--partitions` only when async-maxed suite is still the wall-clock pole — which the baseline says it is NOT (unit ~2m; the pole is the Package-Consumer lane, a *scope* problem, not a *parallelism* problem). |
| `ubuntu-24.04` pinned | GitHub larger runners (8/16-vCPU) | Only if a measured CPU-bound lane (e.g. PLT build, full install-smoke matrix) is the pole AND a 4-vCPU runner is saturated. SEED-003: "larger/exotic runners only with justification." Don't pre-buy cores. |
| `FedericoCarboni/setup-ffmpeg` removed in favor of `scripts/ci/install_ffmpeg.sh` | Keep the action | The repo already abandoned the action in `ci.yml` (it flaked: "Failed to get latest johnvansickle ffmpeg") but `release.yml`'s `public_verify` job **still uses `FedericoCarboni/setup-ffmpeg@v3`**. **Unify on the script** for consistency/determinism, or pin the action to a SHA. Flagged as an inconsistency to fix. |

---

## What NOT to Use / NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Sobelow gating the **library** PR | Sobelow scans Phoenix *app* sinks; `lib/` is a library — mostly noise/no-ops | If wanted, run on `examples/adoption_demo` in **nightly** only |
| SaaS visual-regression (Percy/Chromatic/Argos) | SEED-003 explicit exclusion; cost + external dep + flake surface | In-repo `cohort-contrast.mjs` + Playwright screenshot specs |
| `pull_request_target` for fork CI | Runs untrusted fork code with secrets — classic exfil vector | Keep `pull_request`; secrets fail-closed on forks (already done) |
| Blanket Playwright `retries: 3+` to hide flakes | Masks real determinism bugs (audit's hard "never") | Fix root cause (`workers:1`, fresh server, resilient locators); allow ≤2 retries only for genuine external waits, surfaced in report |
| `--max-cases`/partition tuning before measuring | Oversubscribes a 4-vCPU runner, thrashes the Ecto pool | Print `schedulers_online`, `--slowest` first; tune from evidence |
| Caching `_build` across OTP/Elixir/MIX_ENV without those dims in the key | Stale-artifact corruption, masked recompiles | Include OTP+Elixir+MIX_ENV+arch in every `_build`/`deps` key |
| Single-step cache for PLT | PLT discarded whenever Dialyzer finds an issue → cold rebuild every red run | `actions/cache/restore` + `actions/cache/save` split (save after PLT build, before dialyzer run) |
| Running `mix coveralls` on every PR with no coverage gate | Instrumentation slows the suite for zero gate value | `mix test` on PR; `mix coveralls` on push-to-main/nightly |
| Lint/format/credo/doctor inside the 2-entry `quality` matrix | Runs each linter twice (once per Elixir version) for no extra signal | One `lint` job on the latest pair only |
| Exotic runners (macOS/Windows/ARM) | No compatibility promise requires them for a Linux-deployed library | `ubuntu-24.04`; matrix only OTP/Elixir dims |

---

## Stack Patterns by Variant (placement)

**PR fast gate (target < 5 min):**
- `setup-beam` (SHA-pinned) on **latest pair only** for lint/test; min pair as a separate compat test job
- `mix ci` (deps checks, format, compile-warnings-as-errors, hex.audit, deps.audit, `mix test --warnings-as-errors --slowest 20`)
- deps/_build cache (full keys); **no** coveralls, **no** Dialyzer, **no** broad OTP×Elixir matrix
- The heavy `Package Consumer Proof Matrix + Release Preflight` (the ~15m pole) → **demote most of it to push-to-main/nightly**; keep only a single representative install-smoke on PR. (This is the biggest wall-clock win and is a *scope/trigger* change, not a tooling version.)

**Push-to-main:**
- Same as PR + `mix coveralls` + maybe the broader install-smoke matrix

**Nightly (`schedule:`):**
- Full OTP/Elixir compat matrix (1.15/26 … 1.18/27), Dialyzer (split-cached PLT), full install-smoke matrix, MinIO/GCS/Mux soak, optional Sobelow on the demo app, `mix deps.audit`/`hex.audit`

**Release/tag:**
- Already excellent: exact-SHA green-CI gate → preflight → version-match → `hex.publish --dry-run` → live publish from frozen worktree → public verify. Only change: SHA-pin actions + unify ffmpeg install.

---

## Version Compatibility

| Component | Pin / Constraint | Notes |
|-----------|------------------|-------|
| `mix.exs` `elixir:` | `~> 1.15` | Min-supported pair = **Elixir 1.15 / OTP 26** (keep as a compat matrix entry). Valid combos: 1.15↔OTP 24–26; 1.16↔OTP 24–26; 1.17↔OTP 25–27; 1.18↔OTP 25–27. Current `quality` matrix is `1.15/26` + `1.17/27` — **add `1.18/OTP 27` as the primary lint/test pair** (1.18 is current stable; verify the latest minor on hex before pinning). |
| `setup-beam` resolved capture | `steps.beam.outputs.{otp,elixir}-version` | Feed into cache keys AND a job summary line so green runs are self-documenting. `version-type: strict`. |
| `json_polyfill` | OTP < 27 only (already conditional in `mix.exs`) | OTP 27+ has built-in `:json`; the conditional dep is correct — keep it. This means **OTP 27 lanes don't pull `json_polyfill`** → cache keys must include OTP version (they will, per recipe above). |
| Node | 20 → **22 LTS** | Node 20 EOL 2026-04; bump `setup-node` to 22 for Playwright/brandbook lanes. |
| Postgres service | `postgres:16-alpine` | Current and fine; pin major (16) — already done. |
| `actions/cache` | v4 | v1–v3 deprecated; v4 mandatory. |
| `actions/upload-artifact` | v4 | v3 retired Jan-2025; v4 mandatory (already used). |

---

## Things I could NOT inspect (stated, not guessed)

- **`mix.lock` contents** — not read; exact resolved versions of `credo`/`dialyxir`/`excoveralls` *in the lock* may trail the Hex latest reported above. The `~>` constraints in `mix.exs` are what I verified against.
- **Actual runner core count / `schedulers_online`** — not measurable from files; must be printed in a CI run. All `--max-cases`/partition advice is conditioned on that measurement.
- **Per-test async-safety** — I did not read `test/` modules; the async-conversion lever is real but its *magnitude* requires reading test files + `test_helper.exs` + Ecto Sandbox config (`config/test.exs`).
- **Whether a `dependabot.yml` exists** — not found in the files I was given; if one exists it just needs the `github-actions` ecosystem added.
- **Exact latest Elixir minor (1.18.x vs a newer 1.19)** — Mix docs referenced 1.19/1.20; confirm the current stable minor on hex.pm before pinning the new primary matrix pair.
- **`scripts/release_preflight.sh` / `install_smoke.sh` internals** — only their invocation in YAML was read; the ~15m Package-Consumer pole's internal step breakdown needs `--slowest`/per-step timing from real run logs to classify keep/move-to-nightly precisely.

---

## Sources

- [erlef/setup-beam — Marketplace + README (outputs, version-type strict)](https://github.com/erlef/setup-beam/blob/main/README.md) — MEDIUM-HIGH
- [actions/cache restore/save split for PLT persistence — alanvardy "How to cache Dialyzer on CI"](http://alanvardy.com/post/caching-dialyzer) — MEDIUM
- [dialyxir GitHub Actions split-cache discussion (#497)](https://github.com/jeremyjh/dialyxir/issues/497) — MEDIUM
- [Hex.pm — credo 1.7.19 (2026-06-05)](https://hex.pm/packages/credo) — HIGH
- [Hex.pm — dialyxir 1.4.7 (2025-11-06)](https://hex.pm/packages/dialyxir) — HIGH
- [Hex.pm — mix_audit 2.1.5 (2025-06-09)](https://hex.pm/packages/mix_audit) — HIGH
- [Hex.pm — sobelow 0.14.1 (2025-10-14)](https://hex.pm/packages/sobelow) — HIGH
- [Hex.pm — excoveralls 0.18.5 (2025-01-26)](https://hex.pm/packages/excoveralls) — HIGH
- [Dashbit — "Warnings as errors and tests" (mix test --warnings-as-errors, Elixir ≥1.12)](https://dashbit.co/blog/tests-with-warnings-as-errors) — HIGH
- [Phoenix — Up and Running / phx.new mix.exs precommit alias (1.8.x)](https://hexdocs.pm/phoenix/up_and_running.html) — MEDIUM
- [mix deps.unlock --check-unused / deps.get --check-locked — Mix docs](https://hexdocs.pm/mix/Mix.Tasks.Deps.Unlock.html) — HIGH
- [elixir-ecto/ecto #3599 — mix test --partitions overhead in Ecto-heavy suites](https://github.com/elixir-ecto/ecto/issues/3599) — MEDIUM
- [Playwright — Continuous Integration (workers:1, reuseExistingServer, browser cache by version)](https://playwright.dev/docs/ci) — HIGH
- [Fly.io — GitHub Actions for Elixir CI (matrix/cache idioms)](https://fly.io/docs/elixir/advanced-guides/github-actions-elixir-ci-cd/) — MEDIUM
