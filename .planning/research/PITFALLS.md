# Pitfalls Research

**Domain:** CI/CD pipeline restructuring for an Elixir/Phoenix/Ecto Hex library (Rindle, v1.20 CI/CD Performance)
**Researched:** 2026-06-20
**Confidence:** HIGH — every pitfall below was cross-checked against the seed's `[DARK CORNERS]` list AND verified against the actual repo files (`.github/workflows/ci.yml`, `release.yml`, `config/test.exs`, `test/test_helper.exs`, `test/support/data_case.ex`, `examples/adoption_demo/playwright.config.js`, `mix.exs`). Where a generic dark corner does NOT apply to THIS repo (e.g., `set_mox_global` in async tests, `pull_request_target`), that is stated explicitly so the roadmap does not spend effort on a non-problem.

## How To Read This

Each pitfall states: the failure mode, **whether it is LIVE in this repo or already mitigated**, the warning sign, the exact prevention (cache key dim / async check / repro mechanism), and the **owning phase/PR** in the SEED-003 stepwise plan:

- **PR1 — Observability/baseline** (instrument, measure, do not change behavior)
- **PR2 — Cache + version cleanup** (cache keys, restore breadth, `.tool-versions`)
- **PR3 — Test concurrency / partitioning** (async-safety, `--partitions`)
- **PR4 — Matrix/trigger refinement** (fast-PR vs nightly split, required-check aggregator, lint dedup)
- **PR5 — Release/security polish** (permissions, action pinning, publish gating)
- **PR6 — DX** (`mix ci`, faithful Linux-Chromium local repro, job summaries)

Repo facts that anchor everything below:
- ExUnit discipline is already strong: every global-state mutator (`Application.put_env` in `capability_test`, `doctor_test`, `application_test`, `config_test`, `telemetry_contract_test`) and every `set_mox_global()` caller (`admin/live_update_test`, `admin/live/home_assets_upload_test`, `admin/live/variants_runtime_actions_test`) is already `async: false`. The async footguns are therefore mostly **forward-looking guardrails**, not existing fires.
- `MIX_TEST_PARTITION` is **already wired** into `config/test.exs` (`database: "rindle_test#{MIX_TEST_PARTITION}"`, `pool_size: System.schedulers_online() * 2`) but **no CI job invokes `mix test --partitions`** — the substrate exists, partitioning is unused.
- `config :oban, Oban, testing: :inline` (config/test.exs) + `Oban.start_link(testing: :manual, queues: false)` (test_helper) — two different Oban testing postures coexist.
- All third-party actions are tag-pinned (`@v4`, `@v1`, `@v2`), none SHA-pinned.
- There is **no `.tool-versions`** — Elixir/OTP versions live only in YAML, hard-coded per job.
- There is **no `mix ci` alias** — `precommit: ["test"]` is the only proxy.

---

## Critical Pitfalls

### Pitfall 1: `_build` cache restored across an incompatible OTP/Elixir/MIX_ENV → silent miscompile or "works in CI, broken on publish"

**What goes wrong:**
`_build` contains BEAM bytecode compiled for a specific OTP major. Restoring a `_build` produced under OTP 27 into an OTP 26 runner (or `MIX_ENV=test` build into a `MIX_ENV=dev` job) yields stale/invalid `.beam` files. Mix may not recompile everything, masking warnings-as-errors regressions or producing subtly wrong artifacts.

**Repo status — PARTIALLY MITIGATED, ONE LIVE GAP.**
The `quality` and `optional-dependencies` jobs key `_build` on `${{ matrix.elixir }}-${{ matrix.otp }}` — good. BUT:
- The cache key does **not** include `MIX_ENV`. The whole workflow sets `env: MIX_ENV: test`, yet `package-consumer` runs several steps with `MIX_ENV: dev` (release preflight, `hex.publish --dry-run`, version alignment) while restoring a `_build` cache keyed without the env dim. The dev-env steps can read a `_build/test` tree.
- `release.yml`'s `publish` job restores `deps-${{ runner.os }}-1.17-27-${{ hashFiles('**/mix.lock') }}` and immediately runs under `MIX_ENV: dev` over a **git worktree at a different ref** (`steps.release_source.outputs.project_root`) while the cache path points at the default checkout's `deps`. Cross-tree cache reuse here is a correctness hazard.

**Why it happens:** `_build` keys are usually copied from a tutorial that only ever uses one MIX_ENV; the dim is invisible until a job introduces a second env.

**How to avoid (exact key dims):** Cache key MUST be `${os}-${arch}-otp${OTP}-elixir${ELIXIR}-${MIX_ENV}-${hashFiles('**/mix.lock')}-v${CACHE_VERSION}` for `_build`, and the same minus `MIX_ENV` for `deps`. Add a manual `CACHE_VERSION` buster env var documented in CONTRIBUTING. Never share one `_build` cache between `test` and `dev` jobs — either separate keys or do not cache `_build` for the short dev-env preflight steps. For `release.yml`, the worktree build should use its own key (or no `_build` cache at all, since it is a one-shot trusted build).

**Warning signs:** A warnings-as-errors step that passes on a cache hit but fails on a cold cache; `mix hex.publish --dry-run` packaging stale `.beam`; "recompiling dependency" log noise inconsistent between runs.

**Phase to address:** **PR2** (cache key dims). Verify in **PR1** by printing cache hit/miss + resolved versions to `$GITHUB_STEP_SUMMARY`.

---

### Pitfall 2: Broad `restore-keys` → stale `deps` after a `mix.lock` change; `deps.get` masks it, `--check-locked` is absent

**What goes wrong:**
Every cache step in `ci.yml` uses a `restore-keys` prefix that drops the `hashFiles('**/mix.lock')` segment (e.g. `restore-keys: deps-${{ runner.os }}-1.17-27-`). When `mix.lock` changes, the exact key misses but the prefix matches an **older** `deps` tree. The job then runs plain `mix deps.get`, which will add missing deps but does **not** guarantee the restored tree matches the lock — and crucially CI never runs `mix deps.get --check-locked`, so a drifted lock can pass.

**Repo status — LIVE.** No job runs `mix deps.get --check-locked` or `mix deps.unlock --check-unused`. Restore-key breadth is present on every cache step.

**Why it happens:** Broad restore-keys are the canonical "improve cache hit rate" advice; the cost (stale deps surviving a lock bump) is invisible until a dependency upgrade behaves differently in CI than locally.

**How to avoid:**
- Add `mix deps.get --check-locked` as a fast, merge-blocking step right after `mix deps.get` in the PR fast lane (fails if the lock is out of date with `mix.exs`).
- Add `mix deps.unlock --check-unused` (fast) to catch orphaned lock entries.
- Keep restore-keys for hit rate, but the `--check-locked` step makes a stale restore **fail loud** instead of silently compiling old deps.

**Warning signs:** A dependency bump PR is green in CI but the committed `mix.lock` differs from a fresh `mix deps.get`; "Unused dependencies" never caught.

**Phase to address:** **PR2** (add `--check-locked` / `--check-unused`; keep restore breadth but make drift fail-loud). Belongs in `mix ci` too (**PR6**).

---

### Pitfall 3: PLT cache not saved on Dialyzer FAILURE → every red Dialyzer run pays full PLT rebuild (~minutes)

**What goes wrong:**
The PLT (persistent lookup table) is expensive to build (minutes). The standard `actions/cache` save-on-success-only behavior means: if the *build-PLT* step or any earlier step errors before the post-job cache save, the PLT is lost and the next run rebuilds from scratch.

**Repo status — MOSTLY OK because Dialyzer is advisory, but pre-empt the merge-blocking future.** The repo already uses the restore/build split correctly (`id: plt-cache`, build PLT only on cache miss, Dialyzer step is `continue-on-error: true` so the job still succeeds and the post-job cache save fires). The classic "PLT lost on failure" footgun is largely neutralized **because Dialyzer is `continue-on-error`**.

**Why it matters anyway:** If a future phase makes Dialyzer merge-blocking (removes `continue-on-error`), a failing analysis on a job where the PLT step also failed would drop the PLT. Pre-empt it.

**How to avoid:** Use the explicit `actions/cache/restore` + `actions/cache/save` split with `save` placed **immediately after PLT build, before analysis**, so the PLT is persisted the moment it is built, independent of whether `mix dialyzer` later finds errors. Never couple PLT persistence to analysis success.

**Warning signs:** Dialyzer-containing job duration spikes by minutes whenever the analysis is red.

**Phase to address:** **PR2** (split restore/save, persist PLT before analysis). Revisit if a later milestone promotes Dialyzer to merge-blocking.

---

### Pitfall 4: PLT cache key missing the optional-deps/app-list dim; cross-matrix PLT poisoning

**What goes wrong:**
A PLT built for one OTP/Elixir pair is invalid for another. The repo's PLT key includes OTP/Elixir/lock — good — but does NOT include the analyzed apps/deps config. Adding/removing an optional dep (`mux`/`jose`) changes PLT contents in a way that may not invalidate the `mix.lock` hash cleanly, leading to stale-symbol Dialyzer noise.

**Repo status — LOW-RISK while Dialyzer is advisory; tighten the key opportunistically.**

**How to avoid:** PLT key should be `plt-${os}-otp${OTP}-elixir${ELIXIR}-${hashFiles('mix.lock')}-${hashFiles('.dialyzer_ignore.exs','mix.exs')}-v${CACHE_VERSION}`. Hashing `mix.exs` captures optional-dep / app-list changes that affect PLT contents.

**Warning signs:** Dialyzer reports "unknown function" / "callback info missing" for symbols that exist — classic stale-PLT signature.

**Phase to address:** **PR2**.

---

### Pitfall 5: Caching build artifacts that mask `--warnings-as-errors` / stale compile

**What goes wrong:**
If `_build` is restored and Mix decides not to recompile a module whose warning status changed (e.g., a new `--warnings-as-errors` violation in a transitively-cached module), the compile step can pass on a warm cache and fail only on cold cache (or vice-versa). This makes the warnings-as-errors gate non-deterministic w.r.t. cache state.

**Repo status — LATENT.** `quality` runs `mix compile --warnings-as-errors` over a restored `_build`. Mix's incremental compiler is generally correct here, but cross-MIX_ENV restores (Pitfall 1) and broad restore-keys (Pitfall 2) widen the window.

**How to avoid:** On the dedicated warnings-as-errors lane, compile from a `_build` that is keyed exactly (no cross-env reuse) OR run `mix compile --warnings-as-errors --force` once in a fast lint-only job on a single matrix entry (see Pitfall 11 — lint should run once, not per-matrix). A `--force` warnings check on one runner is cheap and removes cache-dependence of the gate.

**Warning signs:** A warnings-as-errors failure that disappears on rerun-with-cache-cleared, or appears only on the first PR push.

**Phase to address:** **PR4** (consolidate lint/warnings to a single non-matrix lane) + **PR2** (key correctness).

---

### Pitfall 6: Fork PRs leave required checks PENDING forever because heavy lanes are `if: github.repository == 'szTheory/rindle'`

**What goes wrong:**
GitHub branch protection that **requires** a check by name will block a PR until that check reports a conclusion. A job gated with `if: github.repository == 'szTheory/rindle'` is **skipped** on fork PRs (the condition is false). A skipped required job does NOT auto-report success on `pull_request` from a fork — the required check sits PENDING and the PR cannot merge, with no actionable error for the contributor.

**Repo status — LIVE and HIGH-RISK.** Five jobs are repo-gated: `cohort-demo-smoke`, `adoption-demo-e2e`, `gcs-soak`, `package-consumer-gcs-live`, `brandbook-tokens` all carry `if: github.repository == 'szTheory/rindle'`. If any of these names is in branch protection's required list, **every external contributor PR hangs**. (The `mux-soak` lane is label-gated, not repo-gated, so it does not fire unless labeled — different failure mode, see Pitfall 12.)

**Why it happens:** Repo-gating is the correct way to keep secret-dependent lanes off forks, but it interacts badly with required-check branch protection.

**How to avoid (the single most important matrix/trigger fix):**
1. Introduce a final aggregator job `ci-required` (`needs: [all merge-blocking jobs]`) that uses `if: always()` and fails unless every dependency `result` is `success` **or** `skipped`. Make **only `ci-required`** the required check in branch protection. Then fork-skipped jobs (reporting `skipped`) do not block, but a real failure in any does.
2. Document in CONTRIBUTING which lanes are upstream-only and why a contributor will see them skipped.
3. Audit the actual branch-protection required-check list (the seed flags this) — capture the current required names in **PR1**.

**Warning signs:** External contributor PRs stuck "Expected — Waiting for status to be reported"; maintainer has to push the branch to upstream to get a green.

**Phase to address:** **PR4** (aggregator job + branch-protection rename). Capture current required-check names in **PR1**.

---

### Pitfall 7: Branch protection requires unstable per-matrix child names (`Quality (1.15 / 26)`)

**What goes wrong:**
If branch protection requires the matrix-expanded job names, then changing the matrix (dropping 1.15, adding 1.18) **renames** the check, and the old required name is never reported → PRs hang PENDING. This directly blocks the milestone's own matrix-refinement work.

**Repo status — LIVE RISK for this milestone specifically.** The milestone WILL reshape the matrix (kill lint redundancy, split fast/nightly). Any required check pinned to a current matrix child name will break the moment the matrix changes.

**How to avoid:** Same aggregator pattern as Pitfall 6 — require only the stable `ci-required` summary job, never matrix children. Then matrix reshaping is invisible to branch protection.

**Warning signs:** A green-looking PR that cannot merge after a matrix edit; "required check X not found".

**Phase to address:** **PR4** (aggregator must land BEFORE matrix reshaping in the same or prior PR).

---

### Pitfall 8: The long-pole `package-consumer` lane runs full install-smoke matrix + `hex.publish --dry-run` on every PR

**What goes wrong:**
The ~15m critical-path lane (`Package Consumer Proof Matrix + Release Preflight`) runs on every PR: `release_preflight.sh`, repo-hygiene, **five** `install_smoke.sh` variants (video/image/tus/mux-cassette/gcs-structural), version-alignment with a mocked tag, and `mix hex.publish --dry-run`. Much of this is **release-readiness**, not regression-likely-on-a-feature-PR signal. Running it every PR is the dominant cause of the 15–17m wall-clock.

**Repo status — LIVE; this is the stated milestone target.**

**Why it happens:** "Prove the published artifact works" is high-value, so it got wired into the always-on path. But the marginal regression-catching value per PR is low compared to its cost.

**How to avoid (do NOT just delete — classify and move, per the seed's North Star):**
- Keep a **representative** install-smoke subset on PR (e.g., one `image` smoke = fastest real-package proof) as merge-blocking.
- Move the full 5-variant matrix + `hex.publish --dry-run` + release-preflight to **push-to-main** and **release/tag** lanes (where it is exactly the right gate).
- Label-gate the heavy variants (`release-readiness` label) so a maintainer can opt a PR into the full matrix on demand.
- This is a **trust-for-speed tradeoff** and MUST be labeled as such in the PR description and CONTRIBUTING (the seed forbids hiding it): "Full package-consumer proof runs on main + release, not every PR."

**Warning signs:** PR wall-clock dominated by one lane; contributors waiting 15m for a one-line doc fix.

**Phase to address:** **PR4** (split fast-PR vs main vs release). Baseline the lane's per-step timings in **PR1** to justify exactly which variants move.

---

### Pitfall 9: ExUnit async-safety regressions (forward-looking guardrail — the repo is currently clean)

**What goes wrong:**
A test marked `async: true` that mutates `Application.env`, registers a named process, writes global ETS, sets Mox to global mode, captures `Logger`, attaches a telemetry handler, or binds a fixed port will race against other async tests → intermittent CI-only failures that "pass on rerun."

**Repo status — CURRENTLY CLEAN, verified.** Cross-checked every dark-corner trigger:
- `Application.put_env` appears in 21 test files — the global-mutating ones inspected (`capability_test`, `doctor_test`, `application_test`, `config_test`, `telemetry_contract_test`) are explicitly `async: false` with `on_exit` restore.
- `set_mox_global()` is called in exactly 3 files (`admin/live_update_test`, `admin/live/home_assets_upload_test`, `admin/live/variants_runtime_actions_test`) — **all 3 are `use Rindle.DataCase, async: false`**. Correct: global Mox + async is the classic deadlock/race, and the repo avoids it.
- `Process.sleep`/`:timer.sleep` appears in only 2 files (`processor/waveform_test`, `install_smoke/support/generated_app_helper`) — minimal sleep-as-race-mask surface.
- The async-true tests that `import Mox` (`delivery_test`, `html_test`, `live_view_test`, `behaviour_contract_test`, `upload/proxied_test`) use `set_mox_from_context` / private mode (34 files), which IS async-safe.

**Why it still needs a guardrail:** The milestone will **convert more modules to async** to speed the suite. Each conversion is a fresh opportunity to introduce a race. Without an automated check, the discipline erodes.

**How to avoid (exact check):** Add a CI/`mix ci` static guard (small Elixir script or grep gate) that **fails** if any file containing `async: true` also contains any of: `Application.put_env`, `Application.put_all_env`, `set_mox_global`, `Process.register`, `:ets.new(` with a named/`:public` table, `attach_many`/`:telemetry.attach`, or a hard-coded `port:` integer. This codifies the existing convention so async conversions cannot regress it. Run ExUnit with a **fixed `--seed`** in one lane for deterministic triage, and a **random seed** in another to surface order-dependence.

**Warning signs:** A test that fails ~1/30 runs and passes on rerun; failures only under higher `max_cases` / partition count.

**Phase to address:** **PR3** (async-safety static guard lands BEFORE any async conversions; conversions then ride behind it). Also baked into `mix ci` (**PR6**).

---

### Pitfall 10: SQL Sandbox ownership across processes (LiveView/Oban/Task) breaks when a module is flipped to async

**What goes wrong:**
`Rindle.DataCase` does `Sandbox.start_owner!(repo, shared: not tags[:async])`. When `async: false`, the sandbox runs in **shared mode** — any process (LiveView, spawned `Task`, Oban inline worker) can see the connection. When a module is flipped to `async: true`, shared mode turns OFF, and any DB work done in a **different process** (a LiveView process, an Oban job, a `Task.async`) raises `DBConnection.OwnershipError` ("cannot find ownership process") unless that process is explicitly `Sandbox.allow`-ed.

**Repo status — LATENT, becomes LIVE on async conversion.** The admin LiveView tests use `set_mox_global()` + `async: false` (shared sandbox) precisely because LiveView runs in a separate process and needs shared-mode DB access. With `config :oban, testing: :inline`, Oban jobs run **in the test process** (so they share the connection in async mode) — but lifecycle/direct-upload tests that spawn real Tasks or use `testing: :manual` Oban (per `test_helper`'s `Oban.start_link(testing: :manual)`) can cross process boundaries.

**Why it happens:** The async flip looks free (no global state mutated) but silently removes shared-mode sandbox, and the cross-process DB access only shows up when the spawned process touches the Repo.

**How to avoid:**
- Document the rule in `DataCase`: a module may go `async: true` **only if** all DB access happens in the test process. Any module exercising LiveView, channels, or non-inline Oban/Tasks that hit the Repo must stay `async: false` (shared) OR explicitly `Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), child_pid)` for each child.
- For LiveView tests, prefer the `Phoenix.Ecto.SQL.Sandbox` plug + `on_mount` allowance pattern over global shared mode where possible.
- Reconcile the two Oban testing modes (see Pitfall 17).

**Warning signs:** `DBConnection.OwnershipError`, `cannot find ownership process for #PID`, or tests that pass `async: false` and fail the instant they are flipped.

**Phase to address:** **PR3** (codify the sandbox-ownership rule in DataCase docs + the async-safety guard; reconcile Oban testing mode).

---

### Pitfall 11: Lint/static analysis runs redundantly on every matrix entry

**What goes wrong:**
`mix format --check-formatted`, `mix credo --strict`, `mix compile --warnings-as-errors`, `mix doctor`, and Dialyzer run inside the `quality` job **for both** matrix entries (1.15/26 AND 1.17/27). Formatting and Credo results are version-independent — running them twice doubles the cost for zero added signal. Dialyzer per-matrix is defensible (type results can differ per OTP), but format/credo/doctor are pure waste.

**Repo status — LIVE.** The `quality` job's full lint stack runs per matrix entry.

**How to avoid:** Split a single-entry `lint` job (latest pair only, ubuntu-pinned) doing `format --check-formatted`, `deps.get --check-locked`, `deps.unlock --check-unused`, `compile --warnings-as-errors --force`, and (advisory) Credo/Doctor. The matrix `test` job then only compiles + runs tests + coverage per version. Dialyzer can stay matrixed or move to nightly.

**Warning signs:** Two near-identical green lint logs per PR; format failures reported twice.

**Phase to address:** **PR4** (extract single-entry lint lane). Mirror it in `mix ci` (**PR6**).

---

### Pitfall 12: `labeled` trigger / fork-PR secret semantics — correctly mitigated; protect against regression

**What goes wrong:**
`ci.yml` correctly enumerates `types: [opened, synchronize, reopened, labeled]` so that applying the `streaming` label fires `mux-soak`. Two dark corners:
1. Adding `types:` overrides the defaults — if a future edit drops `synchronize`, pushes to an open PR stop triggering CI (silent). The current file documents this; keep the comment.
2. `mux-soak` is `if: contains(labels, 'streaming')` and uses the **safe `pull_request`** trigger (NOT `pull_request_target`). On a fork PR labeled `streaming`, the lane fires but `${{ secrets.RINDLE_MUX_* }}` resolve to **empty strings**, so the real-Mux step fails closed (no fork-secret leak). This is correct and intentional (Key Decision, v1.6). The footgun would be "fixing" this by switching to `pull_request_target` to make fork soak work — that would expose secrets to untrusted fork code.

**Repo status — CORRECTLY MITIGATED; "do not regress" item.**

**How to avoid:** Add a CONTRIBUTING note: never convert `mux-soak`/`gcs-soak` to `pull_request_target`; secrets fail-closed on forks by design. If a contributor reports "soak doesn't run on my fork," the answer is "correct, maintainer runs it upstream," not "elevate the trigger." Keep the `types:` enumeration comment.

**Warning signs:** A PR proposing `pull_request_target` to "fix" fork soak; secrets appearing in a fork-triggered run.

**Phase to address:** **PR5** (security posture doc + comments). No code change beyond comments.

---

### Pitfall 13: Real network in PR-blocking tests (live Mux/GCS) — flake + cost + nondeterminism

**What goes wrong:**
Tests that hit `api.mux.com` or real GCS in the PR-blocking path flake on provider rate limits, outages, and latency, cost money/quota, and leak assets if cleanup fails.

**Repo status — WELL MITIGATED; verify it stays so.** PR runs `install_smoke.sh mux` in **cassette mode** (no real API) and `gcs` **structural-only**; real-Mux is the label-gated `mux-soak`; real-GCS is the repo-gated `gcs-soak` / `package-consumer-gcs-live` (both `continue-on-error` with `if: always()` cleanup sweeps and per-run unique GCS prefixes `gcs-${run_id}-${run_attempt}`). The `S3MultipartRequestStub` provides offline-deterministic S3 for tus unit specs.

**Residual footgun:** PR-blocking `integration` and `package-consumer` lanes start real **MinIO via `docker run`** with a 30×2s curl readiness poll. Local (not internet), so acceptable, but the poll is a sleep-loop readiness mask — see Pitfall 16.

**How to avoid:** Keep real-network lanes out of the merge-blocking required set (only `ci-required` aggregator gates merge; soak lanes advisory/label-gated). Ensure cassette mode is the PR default and is asserted (a test that fails if a "cassette" run accidentally hit the network). Keep per-run unique prefixes + `if: always()` cleanup for any real-bucket lane.

**Warning signs:** A green-then-red flip with no code change; Mux/GCS quota alerts from CI; leaked `rindle_soak`-tagged assets.

**Phase to address:** **PR4** (confirm soak lanes excluded from `ci-required`). **PR5** (cleanup-sweep audit).

---

### Pitfall 14: Linux-Chromium font-metric / headless rendering differences vs macOS — the milestone's recurring bite, with no faithful local repro

**What goes wrong:**
The Playwright/contrast gates (`adoption-demo-e2e`'s `cohort-contrast.mjs` + Playwright suite, and `brandbook-tokens`'s `admin-contrast.mjs` + `admin-gallery-check.mjs`) render under **Linux Chromium on freetype**. Atkinson-on-freetype produced a 3px overflow, and the runtime contrast gate was stricter than the token-pair gate — failures that **only reproduce in CI**, not on the maintainer's macOS. A contributor cannot reproduce the exact failing pixels locally, so debugging is guess-and-push.

**Repo status — LIVE; named in the seed as the recurring bite.** Playwright config is `fullyParallel: false, workers: 1` (good for determinism) but pins `@playwright/test` with a **caret** `^1.57.0` (drift risk — see Pitfall 19), and Chromium is installed via `npx playwright install --with-deps chromium` (version follows whatever Playwright resolves). Font rendering depends on the runner's installed fonts/freetype, which are not pinned.

**Why it happens:** macOS CoreText and Linux freetype hint/rasterize fonts differently; headless Chromium font fallback differs by installed font packages. A gate computed on rendered pixels/contrast is therefore platform-dependent.

**How to avoid (exact local-repro mechanism):**
1. **Provide a pinned Docker image (devcontainer) that mirrors the CI runner's Chromium + fonts**: use the official `mcr.microsoft.com/playwright:v1.57.0-jammy` image (jammy = Ubuntu 22.04, matching the `ubuntu-22.04` runner), pinned to the **exact Playwright version** used in CI. Add `scripts/ci/e2e_local.sh` that runs the Playwright + contrast gates inside that container so macOS contributors get byte-identical freetype rendering. This is the highest-DX fix in the milestone.
2. **Pin the exact Playwright version** (drop the caret — see Pitfall 19) so the bundled Chromium revision is reproducible.
3. **Pin fonts**: install a fixed font package set in the image (the specific Atkinson Hyperlegible build the brand uses) and disable subpixel hinting variance (fontconfig / `FREETYPE_PROPERTIES`) so rasterization is deterministic.
4. Make the contrast gate's tolerance explicit and identical between the token-pair gate and the runtime gate (the seed notes they diverged) — a single shared threshold constant consumed by both `*-contrast.mjs` scripts.

**Warning signs:** A gate green on macOS, red in CI; "3px overflow" / contrast-ratio deltas that vanish locally; contributors pushing repeatedly to debug a visual gate.

**Phase to address:** **PR6** (faithful Linux-Chromium devcontainer + `e2e_local.sh` + pinned Playwright/fonts) — the milestone's marquee DX deliverable. The shared-threshold reconciliation can land in **PR4** with gate consolidation.

---

### Pitfall 15: `ubuntu-latest` drift (and `ubuntu-22.04` eventual EOL)

**What goes wrong:**
`ubuntu-latest` silently migrates (20.04→22.04→24.04), changing preinstalled tools, freetype/font packages, and Docker behavior — turning a green pipeline red overnight with no repo change. Conversely, pinning `ubuntu-22.04` is correct for reproducibility but the image eventually gets deprecated.

**Repo status — GOOD, with a watch item.** Every job already pins `runs-on: ubuntu-22.04` (no `ubuntu-latest`). The watch item: 22.04 will eventually retire, and font/freetype determinism (Pitfall 14) is tied to this exact image.

**How to avoid:** Keep the explicit pin. Centralize the runner image in one workflow-level `env`/anchor so a future bump is one line. When bumping, re-baseline the font/contrast gates in the same PR (font packages change across Ubuntu majors → the recurring bite resurfaces).

**Warning signs:** A GitHub deprecation notice for `ubuntu-22.04`; gates shifting after a runner-image change.

**Phase to address:** **PR2** (centralize the runner image). Coordinate any future bump with **PR6**'s font pinning.

---

### Pitfall 16: `Process.sleep` / curl-poll loops as readiness/race masks (MinIO startup, waveform test)

**What goes wrong:**
Every MinIO-using job starts MinIO with `docker run -d` then a `for _ in seq 1 30; do curl .../health/ready; sleep 2; done` loop. Sleep-based readiness is slow (up to 60s worst-case per lane × many lanes) and can still race (health-ready ≠ bucket-ready). In tests, `processor/waveform_test` uses `Process.sleep`.

**Repo status — LIVE but low-severity (duplicated cost).** The curl poll is a real health check (not a blind sleep), so the main problem is **duplication**: MinIO is booted independently in `integration`, `package-consumer`, `adoption-demo-e2e`, `adopter`, `mux-soak`, and `release.yml`'s `publish`/`public_verify` — six+ copies of the same ~40-line boot.

**How to avoid:**
- Factor the MinIO boot into a **composite action** (`.github/actions/minio`) — removes the sleep-loop duplication.
- For `processor/waveform_test`, replace `Process.sleep` with a deterministic wait on a telemetry/Oban signal or a polling assertion with a deadline.
- Keep the curl health check (correct) but consolidate it.

**Warning signs:** Lanes that occasionally fail at the `mc mb` step; per-lane minutes in MinIO boot; flaky waveform test timing.

**Phase to address:** **PR2/PR4** (composite action for MinIO boot). **PR3** (waveform sleep → deterministic wait).

---

### Pitfall 17: `Oban.Testing` posture mismatch — `:inline` config vs `:manual` started instance

**What goes wrong:**
`config/test.exs` sets `config :oban, Oban, testing: :inline` (jobs perform synchronously on `insert`), while `test_helper.exs` starts `Oban.start_link(repo: Rindle.Repo, queues: false, testing: :manual)`. Inline makes jobs run in-process (good for unit determinism + sandbox sharing); manual requires `Oban.Testing.assert_enqueued` / `drain_queue`. Mixing them per-test without a clear convention causes "job didn't run" (expected inline, got manual) or "job ran when I wanted to assert enqueue" surprises — and inline jobs that spawn cross-process DB work re-trigger the sandbox-ownership pitfall (10).

**Repo status — LIVE ambiguity.** Both postures configured. `use Oban.Testing, repo: Rindle.Repo` appears in tests (e.g., `telemetry_contract_test`).

**How to avoid:** Pick one default (recommend `:inline` for the bulk unit suite — most deterministic and sandbox-friendly) and reserve `:manual` + `assert_enqueued`/`drain_queue` for explicit enqueue-contract tests, documented in test conventions. Make the started-instance mode and the config mode agree, or document precisely why they differ.

**Warning signs:** Tests asserting on job side-effects that pass/fail depending on Oban mode; `assert_enqueued` finding nothing because inline already ran it.

**Phase to address:** **PR3** (reconcile + document Oban testing posture alongside the async/sandbox guard).

---

### Pitfall 18: Overprivileged `GITHUB_TOKEN` / write permissions broader than needed

**What goes wrong:**
A workflow with `permissions: contents: write` (or default-all) at top level grants every job write to the repo, expanding blast radius if any action is compromised.

**Repo status — GOOD, minor tightening.** `ci.yml` is `permissions: contents: read` at top level (correct, least-privilege). `release.yml` is `contents: read` at top level and elevates **per-job** (`release-please`: contents/issues/pull-requests write; `publish`: contents write; `gate-ci-green`: actions/contents read). This is the correct pattern. Residual: `update-release-train-baseline` uses `--admin` on `gh pr merge` with a PAT (`RELEASE_PLEASE_TOKEN`/`BRANCH_PROTECTION_PAT`) — an admin-merge bypass to scope/audit.

**How to avoid:** Keep top-level `contents: read`; keep per-job elevation. Audit the `--admin` merge PAT's scope (it bypasses branch protection); ensure it is a fine-grained token and document why it is needed. No `id-token: write` is present (no OIDC publish) — fine for Hex API-key publishing, but consider OIDC/Hex provenance as future hardening.

**Warning signs:** A job with write perms it never uses; a broad PAT where only `contents: write` is needed.

**Phase to address:** **PR5** (permissions audit + PAT scope review).

---

### Pitfall 19: Unpinned third-party actions (tag-pinned, not SHA-pinned) + caret-pinned Playwright + lingering abandoned ffmpeg action

**What goes wrong:**
All actions are pinned to mutable tags: `actions/checkout@v4`, `erlef/setup-beam@v1`, `actions/cache@v4`, `actions/setup-node@v4`, `actions/upload-artifact@v4`, `googleapis/release-please-action@v4`, `actions/github-script@v7`, `google-github-actions/auth@v2`, `FedericoCarboni/setup-ffmpeg@v3`. A tag can be force-moved by a compromised maintainer → supply-chain risk. Separately, `@playwright/test: ^1.57.0` (caret) lets the resolved version (and bundled Chromium revision) drift, feeding the font-metric nondeterminism (Pitfall 14). And `FedericoCarboni/setup-ffmpeg@v3` — which already burned the repo with intermittent failures and was replaced by `scripts/ci/install_ffmpeg.sh` everywhere else — **still lingers in `release.yml`'s `public_verify`**.

**Repo status — LIVE.** No action is SHA-pinned; Playwright caret-pinned; abandoned ffmpeg action lingers in `release.yml`.

**How to avoid:**
- Pin every third-party action to an immutable **commit SHA** (with a trailing `# v4.x.x` comment) and add Dependabot (`package-ecosystem: github-actions`) to bump them safely. First-party `actions/*` and `erlef/setup-beam` are lower-risk but SHA-pinning them too is the OSS-library norm (Phoenix/Ecto do this).
- Drop the Playwright caret → exact `1.57.0`, matching the devcontainer image tag (Pitfall 14).
- Replace the remaining `FedericoCarboni/setup-ffmpeg@v3` in `release.yml`'s `public_verify` with `scripts/ci/install_ffmpeg.sh` (the chosen reliable path everywhere else).
- Run `mix hex.audit` + `mix deps.audit` (mix_audit) in the nightly/security lane.

**Warning signs:** A CI break with no repo change after an action retag; Chromium revision changing between runs; the ffmpeg-download action failing intermittently again.

**Phase to address:** **PR5** (SHA-pin + Dependabot + remove stray ffmpeg action + exact Playwright pin + hex.audit/mix_audit nightly).

---

### Pitfall 20: Release not strictly depending on full CI / publishing without dry-run + metadata + docs checks

**What goes wrong:**
A release that publishes to Hex without first proving the exact published SHA passed full CI, ran `hex.publish --dry-run`, verified version alignment, and confirmed docs build → can ship a broken/mismatched package.

**Repo status — EXEMPLARY; protect it.** `release.yml` already does this correctly: `gate-ci-green` polls `ci.yml` for `conclusion === 'success'` on the **exact release SHA** before `publish` runs; `publish` runs `release_preflight.sh`, `assert_version_match.sh`, a Hex-already-published idempotency check, `hex.publish --dry-run`, then live publish from a **frozen git worktree** at the immutable ref; `public_verify` then proves the public artifact + HexDocs reachability on a fresh runner; publish runs in a protected `environment: release` with `concurrency: release-publish-rindle, cancel-in-progress: false` (serialized, never cancelled). Gold-standard pattern.

**Residual footguns to guard:** (a) `gate-ci-green` matches `ci.yml` runs by `head_sha` and `workflow_id: 'ci.yml'` — if the milestone **renames the workflow file**, the gate lookup breaks (keep the filename `ci.yml`). (b) the live publish step explicitly rejects the `dryrun-placeholder` key — keep that guard.

**How to avoid:** Do not rename `ci.yml`. Keep `cancel-in-progress: false`. Keep the frozen-worktree publish. **Critically:** when splitting fast/nightly lanes (PR4, Pitfall 8), ensure `gate-ci-green` is satisfied by a workflow run that DID include the full verification (the push-to-main / tag run that ran the full package-consumer matrix), not a fast-PR-only run — otherwise the split silently weakens the release gate.

**Warning signs:** A release publishing after a fast-PR-only green; `gate-ci-green` finding no `ci.yml` run after a workflow rename.

**Phase to address:** **PR4** (ensure fast/nightly split does not weaken the release gate's "full verification"). **PR5** (lock `ci.yml` filename + concurrency).

---

### Pitfall 21: Shell injection from untrusted PR metadata in inline `run:` blocks

**What goes wrong:**
Interpolating `${{ github.event.pull_request.title }}`, branch names, or label names directly into a `run:` shell block lets an attacker craft a PR title/branch that executes arbitrary shell on the runner.

**Repo status — LOW RISK, verified.** The workflows interpolate mostly trusted values (`runner.os`, `matrix.*`, `hashFiles`, `github.repository`, `github.run_id`). `inputs.recovery_reason`/`recovery_ref` in `release.yml` are `workflow_dispatch` inputs (maintainer-supplied) and validated (`recovery_ref` must match a 40-hex SHA or existing tag before use). No `pull_request.title`/`body`/branch-name is interpolated into a `run:` block in the inspected files. The `mux-soak` label check uses `contains(...)` in an `if:` expression (not shell) — safe.

**How to avoid:** Keep the rule: never interpolate untrusted PR metadata into `run:`; pass through `env:` and quote, or use `actions/github-script` with the context object. Add a review-checklist item.

**Warning signs:** Any new step doing `run: echo "${{ github.event.pull_request.title }}"` or building a command from a branch name.

**Phase to address:** **PR5** (CONTRIBUTING/security note + review checklist; no current fire).

---

## Moderate Pitfalls

### Pitfall 22: No `.tool-versions` — local/CI Elixir-OTP drift; versions hard-coded per job

**What goes wrong:** Elixir/OTP versions live only in YAML, repeated in ~10 jobs as `"1.17"`/`"27"` literals. A contributor's local toolchain can differ from CI silently, and bumping the version is a multi-site edit prone to missing a job.

**Repo status — LIVE.** No `.tool-versions` / `.mise.toml`. `setup-beam` reads literals.

**How to avoid:** Add `.tool-versions` (asdf/mise) as the single source of truth; have `setup-beam` read it (`version-file: .tool-versions`). Then `mix ci` and CI share the exact toolchain, and a bump is one line. Compat matrix entries (1.15/26) stay explicit, but the primary pair comes from `.tool-versions`.

**Phase to address:** **PR2** (add `.tool-versions`, point `setup-beam` at it). Enables **PR6**'s `mix ci` parity.

---

### Pitfall 23: No `mix ci` alias — local commands diverge from CI (`precommit: ["test"]` only)

**What goes wrong:** The only local proxy is `precommit: ["test"]`. A contributor cannot run "what CI runs" locally; they discover format/credo/warnings/lock failures only after pushing.

**Repo status — LIVE.** `aliases/0` has `precommit: ["test"]`, no `ci`.

**How to avoid:** Add `ci: ["deps.get --check-locked", "deps.unlock --check-unused", "format --check-formatted", "compile --warnings-as-errors", "test"]` (+ optional `credo`, `dialyzer`, `mix_audit` behind a flag). Document in CONTRIBUTING that `mix ci` mirrors the PR fast lane, and provide `scripts/ci/e2e_local.sh` (devcontainer) for the visual gates (Pitfall 14). The fast PR lane should literally run `mix ci` so parity cannot drift.

**Phase to address:** **PR6** (the DX deliverable). Depends on **PR2** (`--check-locked`) and **PR4** (lint consolidation).

---

### Pitfall 24: Matrix explosion when compat dims multiply

**What goes wrong:** The current matrix is small (2 Elixir/OTP pairs on `quality` + `optional-dependencies`; everything else single-pair). The risk is the milestone ADDING dims (DB version × adapter × partition × OS) and exploding the job count.

**Repo status — NOT YET a problem; guard against it.**

**How to avoid:** Keep one **primary** pair (latest) for the full PR test+lint; keep one **min-supported** pair for compat. Put any broad OTP×Elixir×adapter matrix on **nightly/schedule**, never every PR. Use `fail-fast: false` only for compat matrices (already done on `quality`); default fail-fast for homogeneous shards. Justify each dim against a real historical bug before adding it.

**Phase to address:** **PR4** (matrix shape) — explicitly resist adding partitions to the matrix until evidence (Pitfall 25).

---

### Pitfall 25: Partitioning oversubscribes a 2–4 core runner (substrate exists, unused)

**What goes wrong:** `mix test --partitions N` duplicates compile + setup + service contention per partition. On a standard GitHub runner (2 vCPU), many partitions can be **slower** (duplicated compile dominates) and starve Postgres/MinIO. The repo already sets `pool_size: System.schedulers_online() * 2` and `database: rindle_test#{MIX_TEST_PARTITION}` — partitions would each need their **own DB** (suffix handles naming, but `ecto.create` must run per partition).

**Repo status — SUBSTRATE READY, partitioning UNUSED; do not cargo-cult it.**

**How to avoid:** Measure first (PR1: `mix test --slowest 20`, total suite wall-clock, `System.schedulers_online()` printed in CI). Only partition if (a) the suite is genuinely long after async maximization, and (b) the runner has cores to spare. If partitioning, each partition gets its own `rindle_test{PARTITION}` DB (create per partition), and coverage must be merged. **Prefer maximizing `async: true`** (Pitfall 9/10) over partitioning on small runners — async uses cores within one BEAM without duplicating compile.

**Phase to address:** **PR1** (measure), then **PR3** (async first; partition only if evidence supports + runner has cores).

---

### Pitfall 26: Coverage (`mix coveralls`) slows every PR without a gate that adds value

**What goes wrong:** `quality` runs `mix coveralls` (instrumented, slower than plain `mix test`) on **both** matrix entries every PR. With no coverage threshold gate, the extra instrumentation cost buys nothing on the PR path.

**Repo status — LIVE.** `mix coveralls` runs per matrix entry; no coverage-threshold gate visible in the workflow.

**How to avoid:** Run plain `mix test` on the PR fast lane; run `mix coveralls` (with a threshold or report upload) on **one** entry on push-to-main or nightly. If a coverage floor matters, set `minimum_coverage` in coveralls config so it is a real gate.

**Phase to address:** **PR4** (move coverage off the per-matrix PR path).

---

### Pitfall 27: Heavy demo/e2e lanes on the PR path; doctests/docs-parity boot cost

**What goes wrong:** `adoption-demo-e2e` (Playwright, ~5–7m) is merge-blocking on every PR; `adoption-demo-unit` boots a full Phoenix app for ExUnit; `proof` runs docs-parity + link + matrix-drift gates. These can dominate if visual regression is gated on every PR.

**Repo status — moderate.** `adoption-demo-unit` is storage-free/fast (Postgres only) — reasonable to keep merge-blocking. The heavy `adoption-demo-e2e` is the decision point.

**How to avoid:** Keep the cheap docs-parity gate on PR (fast, catches real drift). Decide explicitly whether brand/visual regression is a PR gate or a main gate — if demoted to main, label it as a trust/speed tradeoff (Pitfall 8 pattern). The faithful local repro (Pitfall 14) lowers the cost of demoting it because contributors can still run the visual gate locally.

**Phase to address:** **PR4** (classify e2e PR-vs-main).

---

## Minor Pitfalls

### Pitfall 28: Duplicated dependency installs (libvips/ffmpeg/MinIO) across many lanes — with live ffmpeg-version drift

**What goes wrong:** `libvips-dev`, ffmpeg, MinIO boot, and `mc` install are copy-pasted across `quality`, `integration`, `package-consumer`, `adopter`, `adoption-demo-e2e`, `mux-soak`, and `release.yml`. Drift already exists: `adoption-demo-unit` and `adoption-demo-e2e` use `apt-get install -y ffmpeg` (4.4) while everything else uses `scripts/ci/install_ffmpeg.sh` (static ≥6, to satisfy the boot probe in `lib/rindle/av/probe.ex` and security invariant 12).

**Repo status — LIVE drift.** Mixed ffmpeg provisioning across lanes.

**How to avoid:** Factor a composite action (`.github/actions/setup-rindle-system-deps`) for libvips + ffmpeg(≥6) + (optional) MinIO. Standardize on the ≥6 static ffmpeg everywhere (the demo's runtime doctor probes ffmpeg; confirm whether apt 4.4 only passes because the demo doesn't hit the ≥6 gate, and unify). DRY removes the drift class.

**Phase to address:** **PR2/PR4** (composite action).

### Pitfall 29: Random test data without a recorded seed → unreproducible flakes

**What goes wrong:** ExUnit randomizes order by seed; data generated with `:rand`/`Enum.random` without seeding makes a flake unreproducible.

**Repo status — low, verify.** No widespread unseeded `Enum.random` observed. Guard forward.

**How to avoid:** Surface the ExUnit seed in the job summary so a contributor can `mix test --seed <N>` to reproduce. Forbid unseeded randomness in fixtures (use `StreamData` with a fixed seed for property tests).

**Phase to address:** **PR1** (surface seed in job summary) / **PR6** (`mix ci` echoes seed).

### Pitfall 30: Opaque logs — failures without actionable guidance

**What goes wrong:** A red gate (contrast, drift, version-mismatch) that prints a stack trace but not "run X locally to fix" forces contributors to guess.

**Repo status — partially good.** `brandbook-tokens` prints `::error::Generated CSS is out of sync... Run the brandbook generators and commit the result.` — exactly the right pattern. Not all gates do this.

**How to avoid:** Every merge-blocking gate emits a `::error::` annotation with the exact local command to reproduce/fix (`mix ci`, `bash scripts/ci/e2e_local.sh`, "run the brandbook generators"). Add per-job `$GITHUB_STEP_SUMMARY` with versions, cache hit/miss, slowest tests, and the seed.

**Phase to address:** **PR1** (job summaries + actionable annotations) / **PR6** (documented in CONTRIBUTING).

---

## Process Pitfalls (the seed's explicit "do not" list)

- **Do NOT delete slow tests merely for being slow.** Classify (keep / optimize / move-to-nightly / quarantine / delete) with evidence from PR1 baseline. The long-pole `package-consumer` lane is a *move-to-main/release* candidate (Pitfall 8), not a delete. — owner: **PR1 classify → PR4 move**.
- **Do NOT "just retry flaky."** A flake is a determinism bug (sandbox ownership, sleep race, font metric). Fix the cause (Pitfalls 9/10/14/16); never add blanket `retries:` to the Playwright config or rerun-until-green CI. — owner: **PR3/PR6**.
- **Do NOT trade gate trust for speed without labeling it.** Moving package-consumer/e2e off the PR path is a real trust-for-speed tradeoff; it MUST be stated in CONTRIBUTING + the PR description, and the release gate must still require full verification (Pitfall 20). — owner: **PR4** (with explicit tradeoff note).
- **Do NOT let local commands diverge from CI.** `mix ci` must run the same steps as the PR fast lane; the devcontainer must mirror the runner for visual gates. — owner: **PR6**.

---

## Cross-Reference: Dark-Corner Coverage Map

| Seed dark corner | Pitfall | Status in repo |
|---|---|---|
| required checks pending from path/branch/repo skip | 6, 7 | **LIVE** (repo-gated jobs + matrix names) |
| matrix explosion | 24 | guard (not yet) |
| lint redundant across matrix | 11 | **LIVE** |
| ubuntu-latest drift | 15 | mitigated (pinned 22.04) |
| _build across incompatible OTP/Elixir/MIX_ENV | 1 | **LIVE gap** (MIX_ENV dim) |
| broad restore keys → stale deps | 2 | **LIVE** (no --check-locked) |
| skipping deps.get after partial restore | 2 | **LIVE** (no --check-locked) |
| PLT not saved on Dialyzer failure | 3 | mitigated (advisory) |
| PLT key missing OTP/Elixir/lock dims | 4 | low (has OTP/Elixir/lock; add mix.exs) |
| tests async while mutating Application env/global | 9 | **CLEAN** (all async:false) — guard fwd |
| Mox global mode blocking async | 9, 12 | **CLEAN** (global only in async:false) |
| DB sandbox ownership across processes | 10 | latent on async conversion |
| partitions sharing a DB | 25 | substrate ready, unused |
| fixed ports in async tests | 9 | none found — guard fwd |
| Process.sleep as readiness/race mask | 16 | **LIVE** (MinIO poll, waveform test) |
| real network in PR tests | 13 | mitigated (cassette/structural) |
| random data without seed | 29 | low — surface seed |
| huge modules limiting concurrency | 9, 25 | measure in PR1 |
| coverage slowing PR without gate | 26 | **LIVE** |
| doctests/docs compiling too much | 27 | moderate |
| integration containers dominating PR | 8, 16 | **LIVE** (package-consumer ~15m) |
| security scans hitting network/flaking | 13, 19 | add mix_audit nightly |
| stale action versions | 19 | **LIVE** (tag-pinned; ffmpeg action in release.yml) |
| overprivileged GITHUB_TOKEN | 18 | GOOD (least-priv) |
| secrets to untrusted PR contexts | 12 | mitigated (fail-closed) |
| release not depending on CI | 20 | EXEMPLARY |
| publish without dry-run/metadata/docs | 20 | EXEMPLARY |
| branch protection on unstable matrix names | 7 | **LIVE risk** |
| local commands diverging from CI | 23 | **LIVE** (no mix ci) |
| opaque logs | 30 | partial |
| Linux-Chromium font/render nondeterminism | 14 | **LIVE** (the recurring bite) |

---

## Sources

- **Repo files (primary, HIGH confidence):** `.github/workflows/ci.yml`, `.github/workflows/release.yml`, `config/test.exs`, `test/test_helper.exs`, `test/support/data_case.ex`, `examples/adoption_demo/playwright.config.js`, `examples/adoption_demo/package.json`, `mix.exs`, `scripts/ci/adoption_demo_e2e.sh`, plus `grep`/`async`/`Mox`/`Process.sleep` audits across `test/`.
- **Seed (authoritative spec):** `.planning/seeds/SEED-003-ci-cd-performance-audit.md` — `[DARK CORNERS]`, `[ELIXIR-SPECIFIC]`, `[SECURITY/SUPPLY-CHAIN/RELEASE]`.
- **Project invariants:** `.planning/PROJECT.md` (security invariants 8–14, Oban-required constraint, Key Decision on `mux-soak` fork-safety / `pull_request` not `pull_request_target`).
- **Ecosystem norms (MEDIUM confidence, idiomatic-Elixir grounding):** Ecto SQL Sandbox ownership/shared-mode semantics; `erlef/setup-beam` `version-file` support; `Oban.Testing` `:inline` vs `:manual`; `mcr.microsoft.com/playwright:vX-jammy` images for faithful Linux Chromium; GitHub Actions required-check aggregator (`needs:` + `if: always()`) pattern (Phoenix/Ecto/Plug CI conventions).
