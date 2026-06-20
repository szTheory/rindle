# Architecture Research — CI/CD Pipeline Topology

**Domain:** GitHub Actions CI/CD for an Elixir/Phoenix/Ecto Hex library (Rindle)
**Researched:** 2026-06-20
**Confidence:** HIGH (mapped against the real `ci.yml` / `release.yml` / `release-please-automerge.yml` / `branch-protection-apply.yml` / `setup_branch_protection.sh`, line-by-line)

> Scope note: this is the **pipeline topology / architecture** research artifact for the v1.20 "CI/CD Performance" milestone (SEED-003). It answers *what the target lane structure should be and how the new lanes integrate with / refactor the existing 14-job `ci.yml`*. Test-value classification, ExUnit async/partitioning specifics, and exact cache-key tuning are companion artifacts; this file owns the **graph, the lane split, concurrency, required-checks topology, runner/matrix shape, and the stepwise build order**.

---

## Standard Architecture

### Current Pipeline (as-built, 2026-06-20)

`ci.yml` is a **single workflow, 14 top-level jobs**, all gated on `push: [main]` + `pull_request: [main]` (types `opened, synchronize, reopened, labeled`) + `workflow_dispatch`. There is **no `concurrency:` block** and **no aggregate summary job**. Branch protection requires **13 named contexts** directly (the matrix children plus the singletons). Each job is self-contained: every job re-runs `checkout → setup-beam → restore caches → install system deps → mix deps.get` from scratch — there is no shared compile/artifact handoff between jobs.

```
on: push[main] + pull_request[main]{labeled} + workflow_dispatch     (NO concurrency:)
│
├── quality (MATRIX 1.15/26 + 1.17/27)  pg svc · libvips · ffmpeg     ~2m  REQUIRED ×2
│      compile -W0e · format · credo* · doctor* · coveralls · dialyzer*   (*advisory)
├── optional-dependencies (MATRIX 1.15/26 + 1.17/27) no-optional compile ~1m REQUIRED ×2
│
│   ── all below: needs:[quality, optional-dependencies] ──
├── integration            pg + MinIO(docker) · ffmpeg                <3m  REQUIRED
├── contract               pg · AV hygiene gate(block) + contract*    <2m  REQUIRED
├── proof                  pg · docs-parity + link/matrix gates       <2m  REQUIRED
├── package-consumer       pg + MinIO + node + ffmpeg + libvips      ~15m  REQUIRED  ◄ LONG POLE
│      release_preflight · 5× install_smoke (image/video/tus/mux/gcs) · version · hex --dry-run
├── adoption-demo-unit     pg · examples/adoption_demo ExUnit         ~2m  REQUIRED
├── cohort-demo-smoke      docker compose cold-start boot             ~2-3m REQUIRED
├── adoption-demo-e2e      pg + MinIO + node · Playwright/Chromium    ~5-7m REQUIRED
├── adopter                needs:+[integration,contract] · MinIO      <3m  REQUIRED
├── brandbook-tokens       node/Playwright · token→CSS drift gate     ~2m  REQUIRED
│
│   ── gated lanes (not required) ──
├── mux-soak               if: label 'streaming'   · needs:quality    label-gated
├── gcs-soak               if: repo==szTheory · secret-detect skip    secret-gated (advisory)
└── package-consumer-gcs-live  continue-on-error · secret-detect skip secret-gated (job soft-fail)
```

**Critical-path math (the felt 15-17 min):**
`quality` (~2m) + `optional-dependencies` (~1m, parallel with quality) form a **gate barrier** because every heavy lane has `needs: [quality, optional-dependencies]`. Then the longest dependent lane, `package-consumer` (~15m), dominates. So PR wall-clock ≈ `max(quality, optional-deps)` **+** `package-consumer` ≈ 2 + 15 = **~17m**. `adoption-demo-e2e` (~5-7m) is the *second* pole but is hidden under the package-consumer shadow. **One lane gates the entire PR.**

### Target Pipeline (recommended)

Split one workflow into **lane-scoped triggers** with a single required **summary gate**. The PR fast path keeps only the *minimal representative* signal; the heavy compatibility/release-preflight work moves to `push:main` + nightly + release.

```
┌──────────────────────────────────────────────────────────────────────────┐
│  ci-pr (PR fast gate)   on: pull_request[main]{+labeled}  concurrency: cancel old │
├──────────────────────────────────────────────────────────────────────────┤
│  quality (1.17/27 ONLY)  optional-deps (1.17/27)  brandbook-tokens         │
│  integration  contract  proof  adoption-demo-unit  cohort-demo-smoke       │
│  adoption-demo-e2e   package-consumer-pr (1 profile: image)   [mux-soak*]  │
│                              ↓ needs: (all of the above)                   │
│                    ┌──────────────────────────┐                            │
│                    │  ci-summary  (REQUIRED)   │  ← the ONLY required check │
│                    └──────────────────────────┘     fail if any needs!=ok  │
│  target PR wall-clock: ~5-7m (e2e becomes the pole; pkg lane is image-only)│
└──────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────┐
│  ci-main      on: push[main]            concurrency: serialize, NO cancel  │
├──────────────────────────────────────────────────────────────────────────┤
│  everything in ci-pr  +  package-consumer FULL (image/video/tus/mux/gcs)   │
│  +  quality MATRIX (1.15/26 + 1.17/27)   +  coverage upload                │
│           main is allowed to be slower; it's not blocking a human          │
└──────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────┐
│  ci-nightly   on: schedule(cron) + workflow_dispatch                       │
├──────────────────────────────────────────────────────────────────────────┤
│  broad OTP×Elixir compat matrix  ·  gcs-soak  ·  package-consumer-gcs-live │
│  ·  dialyzer (promoted from advisory inline → owned nightly lane)          │
│  ·  release_preflight + hex --dry-run (rehearse the release continuously)  │
└──────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────┐
│  release.yml (UNCHANGED topology) — already correct: gate-ci-green on SHA  │
│  concurrency: release-publish-rindle, cancel-in-progress: false            │
└──────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities (lane → purpose mapping)

| Lane (current job) | Catches | PR / main / nightly / release | Notes |
|---|---|---|---|
| `quality` | compile warnings, format, unit regressions, coverage | **PR (1.17/27 only)** + main (full matrix) | Today runs 2× matrix on every PR — redundant lint/compile. Pin PR to one entry. |
| `optional-dependencies` | optional-dep compile breakage (`--no-optional-deps`) | **PR (1.17/27 only)** + main (matrix) | Same matrix-redundancy fix as `quality`. |
| `integration` | MinIO/S3 + Postgres lifecycle | **PR** | Keep — fast, high-signal, real adapter. |
| `contract` | AV hygiene (block) + contract suite (advisory) | **PR** | Keep. |
| `proof` | docs-parity, link hygiene, adoption-matrix drift, batch-erasure | **PR** | Keep — merge-blocking truth gate. |
| `package-consumer` | install-from-built-artifact across 5 profiles + release preflight + hex dry-run | **PR (image only) → main/nightly (full 5)** | **The move.** See below. |
| `adoption-demo-unit` | demo ExUnit (brand/console/lifecycle parity) | **PR** | Keep — storage-free, fast. |
| `cohort-demo-smoke` | docker-compose cold-start boot (the path that broke twice) | **PR** | Keep — it gates the boot path that actually regressed (MEMORY: "gate the boot path that actually broke"). |
| `adoption-demo-e2e` | Playwright/Chromium console behavior + contrast | **PR** | Keep but becomes the new pole (~5-7m) → optimize later, not move. |
| `adopter` | canonical adopter lifecycle proof | **PR** | Keep. `needs:` chain (`+integration,contract`) is currently serialized — reconsider. |
| `brandbook-tokens` | token→CSS drift (merge-blocking) | **PR** | Keep — pure Node, cheap, deterministic gate. |
| `mux-soak` | real Mux API soak | label `streaming` (PR) + nightly | Keep label-gating; no change to fork-secret posture. |
| `gcs-soak` | real GCS bucket | **nightly + secret-gated** | Move off PR — already advisory, already secret-detect-skips. |
| `package-consumer-gcs-live` | live GCS resumable install-smoke | **nightly + secret-gated** | Already `continue-on-error`; move off PR. |

---

## Recommended Project Structure (workflow files)

```
.github/workflows/
├── ci.yml             # KEEP NAME "CI" — the workflow release/automerge gate on (becomes main/full)
├── ci-pr.yml          # NEW PR fast gate — minimal representative signal + ci-summary
├── ci-nightly.yml     # NEW schedule + dispatch — broad compat, soaks, gcs-live, dialyzer, preflight
├── release.yml        # UNCHANGED — recovery-validation → gate-ci-green → publish → public_verify
├── release-please-automerge.yml   # UNCHANGED — workflow_run on "CI"  ⚠️ SEE MIGRATION RISK
└── branch-protection-apply.yml    # MODIFIED — required contexts list updated to ci-summary
```

### Structure Rationale

- **Split by trigger, not by concern.** The single-`ci.yml`-with-`if:`-everywhere pattern is the source of the matrix-redundancy and the "one heavy lane gates everything" problem. Separate files make each trigger's job set legible and let `concurrency:` differ per file (PR cancels; main serializes).
- **`ci-pr.yml` owns the contributor experience.** Everything in it must be fast, deterministic, and representative. The heavy `package-consumer` full matrix and broad OTP matrix do **not** belong here.
- **Keep `ci.yml` named `CI` as the release-gated workflow.** `release.yml`'s `gate-ci-green` polls `workflow_id: 'ci.yml'` on `push:main`, and `release-please-automerge.yml` triggers on `workflow_run: workflows: [CI]`. The cheapest, lowest-risk path is to keep `ci.yml` as the **main/full** workflow (what release trusts) and *add* `ci-pr.yml` as the fast PR path. Renaming the gated workflow is the single most dangerous move in this milestone (see Anti-Pattern 3).
- **One reusable composite action** (`.github/actions/setup-elixir/`) should absorb the duplicated `checkout → setup-beam → restore-deps → restore-build → libvips → ffmpeg → deps.get` block that appears verbatim in ~9 jobs. This is the highest-leverage de-duplication and the precondition for safe cache-key changes (change the key in one place).

---

## Architectural Patterns

### Pattern 1: Summary / aggregate required job ("the one required check")

**What:** A final `ci-summary` job with `needs: [<every other PR job>]` and `if: always()`, whose only logic is to fail if any dependency did not succeed. Branch protection requires **only `ci-summary`** instead of 13 individual contexts.

**When to use:** Always, for any matrixed or evolving pipeline. This is the canonical GitHub Actions pattern (used by Phoenix, Ecto, Nx, Ash) to decouple branch-protection from job names.

**Trade-offs:** One indirection layer; you read the summary job's log to see *which* dependency failed (mitigate by printing a per-`needs` status table in the summary step). Massively reduces branch-protection churn — adding/removing/renaming a lane no longer requires a branch-protection PUT.

**Example:**
```yaml
ci-summary:
  name: CI Summary            # ← the ONLY required status check
  if: ${{ always() }}
  needs:
    - quality
    - optional-dependencies
    - integration
    - contract
    - proof
    - package-consumer-pr
    - adoption-demo-unit
    - cohort-demo-smoke
    - adoption-demo-e2e
    - adopter
    - brandbook-tokens
  runs-on: ubuntu-22.04
  steps:
    - name: Verify all required lanes succeeded
      run: |
        results='${{ join(needs.*.result, ",") }}'
        echo "lane results: $results"
        # 'skipped' counts as pass (skipped-required-must-report-success);
        # only 'failure'/'cancelled' fail the gate.
        if echo "$results" | grep -qE 'failure|cancelled'; then
          echo "::error::one or more required lanes failed"; exit 1
        fi
```

**Critical correctness rule (the trap):** a job that is **skipped** (e.g. `if: github.repository == 'szTheory/rindle'` on a fork, or a path-filtered lane) reports `result == 'skipped'`. If branch protection required that job *directly*, a skipped lane leaves the PR **pending forever**. With the summary pattern, you decide in *one* place that `skipped` == pass. This is exactly why several current jobs (`cohort-demo-smoke`, `adoption-demo-e2e`, `brandbook-tokens`, `gcs-soak`) carry `if: github.repository == 'szTheory/rindle'` — on fork PRs they skip, and they are currently **required by name**, which is a latent fork-PR "pending forever" trap today.

### Pattern 2: Trigger-scoped concurrency (cancel PRs, serialize main/release)

**What:** Per-workflow `concurrency:` groups so superseded PR runs auto-cancel while main/release runs never cancel.

**When to use:** Always. `ci.yml` currently has **none** — every push to a PR branch spins a full parallel run and old runs keep burning runner minutes to completion.

**Trade-offs:** None meaningful. The only nuance is keying main by SHA (not branch) so concurrent main merges don't cancel each other.

**Example:**
```yaml
# ci-pr.yml — cancel outdated PR runs
concurrency:
  group: ci-pr-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true

# ci.yml (main/full) — never cancel a post-merge run; serialize per commit
concurrency:
  group: ci-main-${{ github.sha }}
  cancel-in-progress: false

# release.yml — ALREADY CORRECT, do not touch
#   group: release-publish-rindle
#   cancel-in-progress: false
```

### Pattern 3: PR-samples / main-exhausts the heavy lane

**What:** The `package-consumer` lane runs **all 5 install-smoke profiles + release_preflight + hex --dry-run (~15m)** on every PR today. Split it: PR runs **one representative profile** (`image`, the wedge) as `package-consumer-pr`; the full 5-profile matrix + release preflight + dry-run runs on `push:main` and nightly.

**When to use:** When one lane provably dominates wall-clock and most of its work is *compatibility breadth* rather than *regression likelihood per PR*. install_smoke builds a Hex artifact and runs a full generated-app proof per profile — `video`/`tus`/`mux`/`gcs` rarely regress on a typical PR but cost ~3m each.

**Trade-offs:** A profile-specific break (e.g. a tus-only install regression) is caught on main rather than on the PR. Mitigation: (1) keep `image` on PR; (2) make the full matrix a **required check on `ci.yml` (main)** so a bad merge is loud immediately; (3) allow `package-consumer` label opt-in on PRs touching `tus`/`mux`/`gcs` paths (mirror the existing `mux-soak` label pattern). This is the **single biggest wall-clock win**: PR drops from ~17m toward ~5-7m.

**Example (PR lane, image only):**
```yaml
package-consumer-pr:
  name: Package Consumer (PR sample)
  needs: [quality]
  steps:
    - run: bash scripts/install_smoke.sh image   # 1 profile, no release_preflight on PR
# full matrix + preflight + dry-run live in ci.yml (main) / ci-nightly.yml
```

### Pattern 4: Matrix collapse (lint/static on ONE entry; compat on nightly)

**What:** `quality` and `optional-dependencies` run the full `1.15/26 × 1.17/27` matrix on every PR. Lint, format, compile-warnings, doctor, dialyzer, and coveralls do **not** need two Elixir/OTP pairs on a PR — they catch the *same* issue twice. Run static/lint/unit on the **latest supported pair (1.17/27)** on PR; run the **min-supported pair (1.15/26)** for compatibility on `push:main` + nightly only.

**When to use:** Always for homogeneous lint/static checks. Keep `fail-fast: false` for genuine compat matrices (you want to see all failures), default fail-fast for shards.

**Trade-offs:** A 1.15/26-only compile break (rare; usually a new-stdlib API) is caught on main not PR. Acceptable for a 0.x lib; min-supported breaks are infrequent and main catches them within minutes.

### Pattern 5: Reusable composite setup action (cache-key single source of truth)

**What:** Extract the repeated 7-step Elixir bootstrap into `.github/actions/setup-elixir/action.yml`. Cache keys then live in ONE place, which is the precondition for the cache-correctness work (changing a key shape across 9 inlined jobs by hand is how stale-cache bugs ship).

**When to use:** Before any cache-key change. Order matters: **composite-action extraction → cache-key tuning → partitioning** (correctness before speed).

---

## Data Flow

### PR critical path (current vs target)

```
CURRENT (~17m):
  push → [quality 2m ‖ optional-deps 1m]  (gate barrier)
                    ↓ needs satisfied
       → package-consumer 15m  ────────────────────────►  green
         (adoption-demo-e2e 5-7m finishes inside this shadow)

TARGET (~5-7m):
  PR → [quality(1.17) ‖ optional-deps(1.17) ‖ integration ‖ contract ‖ proof
        ‖ adoption-demo-unit ‖ cohort-demo-smoke ‖ adoption-demo-e2e
        ‖ package-consumer-pr(image) ‖ brandbook-tokens ‖ adopter]
                    ↓ needs: *
       → ci-summary (seconds)  ─────────────────────────►  green
         pole is now adoption-demo-e2e (~5-7m)
```

### Release flow (already correct — document, don't change)

```
push:main → release-please opens/updates release PR (skip-github-release)
release-please-automerge.yml (workflow_run on "CI" success, head_branch==main)
  → squash-merge release PR  → dispatch release.yml with recovery_ref = exact merge SHA
release.yml: recovery-validation → gate-ci-green (waits for ci.yml green on SHA)
  → publish (hex.publish from frozen worktree) → public_verify → update RELEASE-TRAIN
```

The release path **gates on `ci.yml` by workflow name** via `release-please-automerge.yml` (`workflows: - CI`) and via `gate-ci-green` polling `workflow_id: 'ci.yml'`, `head_sha: <SHA>`. **This is the highest-blast-radius coupling in the migration** (see Integration Points).

---

## Scaling Considerations

| Concern | Today | Target adjustment |
|---|---|---|
| Runner minutes per PR | ~14 jobs × full bootstrap, no cancel-in-progress; superseded runs run to completion | `cancel-in-progress: true` on PR; matrix collapse halves `quality`/`optional-deps`; pkg-consumer image-only cuts the 15m lane to ~3m on PR |
| Wall-clock | ~15-17m, single-lane-dominated | ~5-7m, e2e-dominated |
| Larger runners (4-core/8-core)? | All `ubuntu-22.04` (2-core) | **Not yet justified.** Only consider a larger runner for `adoption-demo-e2e` *after* it's the proven pole AND ExUnit partitioning / `mix test --partitions` is proven not to help. Larger runners cost more $/min — buy them only against a measured, partition-resistant pole. Print `System.schedulers_online()` first. |
| Service-container overhead | Postgres as a GHA service container (fast); MinIO started via `docker run` + 30×2s poll loop in 4 lanes (slower, redundant) | Consider MinIO as a declared `services:` container with a healthcheck instead of the inline `docker run` + sleep-poll; removes a Process.sleep-style readiness pattern. Lower priority than the lane split. |

### Scaling Priorities

1. **First bottleneck — `package-consumer` 15m lane.** Fix by sampling on PR (image), exhausting on main/nightly. ~10m off PR wall-clock.
2. **Second bottleneck — `adoption-demo-e2e` 5-7m.** After it becomes the pole: ExUnit/Playwright shard or `mix test --partitions`; only then evaluate a larger runner.
3. **Third — bootstrap duplication.** Composite action + cache-key dedup; modest per-job savings but unlocks safe cache tuning.

---

## Anti-Patterns

### Anti-Pattern 1: Requiring matrix-child names directly in branch protection

**What people do:** `setup_branch_protection.sh` currently lists **13 literal contexts** including matrix children `Quality (1.15, 26)`, `Quality (1.17, 27)`, `ADMIN-06 Optional Dependencies (1.15, 26)`, etc.
**Why it's wrong:** Any matrix-shape change (collapsing to one PR entry, renaming, splitting `ci.yml` into `ci-pr.yml`) **renames the contexts**, so the old required names go permanently *pending* and block every PR until a branch-protection PUT lands. Worse, `branch-protection-apply.yml` re-asserts the *old* list nightly via cron — it will **fight** the migration.
**Do this instead:** Require only **`CI Summary`** (Pattern 1). Migrate the required-checks list and the workflow split **in the same PR**, and update `setup_branch_protection.sh`'s `REQUIRED_CHECKS` array in that PR so the nightly re-assert can't revert it.

### Anti-Pattern 2: One workflow, `if:`-gate everything

**What people do:** Keep all PR/main/nightly/soak logic in one `ci.yml` differentiated by `if:` conditions.
**Why it's wrong:** Forces a single `concurrency:` policy (can't both cancel PRs and never-cancel main), makes the matrix-redundancy invisible, and entangles fork-skip `if:` guards with required-check names.
**Do this instead:** Split by trigger into a fast `ci-pr.yml`, the full `ci.yml` (main), and `ci-nightly.yml`.

### Anti-Pattern 3: Renaming the workflow that `release.yml` and automerge depend on by name

**What people do:** Rename `ci.yml`'s `name: CI` or its filename while refactoring.
**Why it's wrong:** `release-please-automerge.yml` triggers on `workflow_run: workflows: [CI]` (matches the **`name:` field**, not the filename), and `gate-ci-green` in `release.yml` polls `workflow_id: 'ci.yml'` (matches the **filename**). Rename either and **the release train silently stops** — releases never auto-merge or never gate.
**Do this instead:** Keep the **release-gated workflow named `CI` at `ci.yml`**, running on `push:main`. Introduce the fast path as a *new* `ci-pr.yml`; do not move the `push:main` gate out of `ci.yml`. If you must rename, update the automerge `workflows:` list AND the `gate-ci-green` `workflow_id` in the **same PR**.

### Anti-Pattern 4: Restoring `_build` across incompatible OTP/Elixir (cache poisoning)

**What people do:** Broad `restore-keys` that drop the OTP/Elixir dimension.
**Why it's wrong:** Restoring a `_build` compiled under 1.15/26 into a 1.17/27 job yields stale-BEAM heisenbugs.
**Do this instead:** The current keys already pin `${{ runner.os }}-${{ matrix.elixir }}-${{ matrix.otp }}-${{ hashFiles('mix.lock') }}` — **keep that discipline**, and add a cache-version buster prefix (`v1-deps-...`) so a deliberate bust is one-line. PLT cache should stay separate with its own restore/save split (so a Dialyzer failure still persists the PLT — the current `quality` job already conditionally builds PLT on cache miss, which is close, but note Dialyzer is `continue-on-error` so the PLT save path is preserved).

---

## Integration Points

### How new lanes integrate with the existing 14 jobs (explicit new-vs-modified)

| Existing job | Action | Target home |
|---|---|---|
| `quality` (matrix×2) | **MODIFY** — PR runs 1.17/27 only; matrix moves to main/nightly | ci-pr (single) + ci.yml/main (matrix) |
| `optional-dependencies` (matrix×2) | **MODIFY** — same collapse | ci-pr (single) + ci.yml/main (matrix) |
| `integration` | **COPY to ci-pr (unchanged body)** | ci-pr + ci.yml/main |
| `contract` | **COPY to ci-pr (unchanged body)** | ci-pr + ci.yml/main |
| `proof` | **COPY to ci-pr (unchanged body)** | ci-pr + ci.yml/main |
| `package-consumer` | **SPLIT** — new `package-consumer-pr` (image only) on PR; full 5-profile + preflight + dry-run stays on ci.yml(main)/nightly | ci-pr (sample) + ci.yml/main + nightly (full) |
| `adoption-demo-unit` | **COPY to ci-pr (unchanged)** | ci-pr + ci.yml/main |
| `cohort-demo-smoke` | **COPY to ci-pr (unchanged)** — keep on PR (boot-path-that-broke gate) | ci-pr + ci.yml/main |
| `adoption-demo-e2e` | **COPY to ci-pr (unchanged for now)** — later: shard | ci-pr + ci.yml/main |
| `adopter` | **COPY to ci-pr** — reconsider `needs:[integration,contract]` serialization | ci-pr + ci.yml/main |
| `brandbook-tokens` | **COPY to ci-pr (unchanged)** | ci-pr + ci.yml/main |
| `mux-soak` | **KEEP** label-gated on PR; **ADD** nightly schedule | ci-pr (label) + ci-nightly |
| `gcs-soak` | **MOVE** off PR → nightly (already advisory/secret-gated) | ci-nightly |
| `package-consumer-gcs-live` | **MOVE** off PR → nightly (already continue-on-error) | ci-nightly |
| — | **NEW** `ci-summary` aggregate required job | ci-pr |
| — | **NEW** composite action `.github/actions/setup-elixir` | shared |
| — | **NEW** `ci-nightly.yml` (broad OTP×Elixir matrix + dialyzer-owned-lane + soaks) | ci-nightly |
| — | **NEW** `ci-pr.yml` (fast path) | ci-pr |

> Pragmatic alternative to full duplication: keep one `ci.yml` but make the *heavy bits* (full pkg matrix, the 1.15/26 leg, soaks) conditional on `github.event_name != 'pull_request'`, and add the `ci-summary` + `concurrency` in place. This avoids copy-drift between `ci-pr.yml` and `ci.yml` at the cost of a denser file. Decide at plan time; the topology (what runs on PR vs main vs nightly) is the same either way and is the load-bearing decision here.

### External / cross-workflow boundaries (the high-blast-radius ones)

| Boundary | Coupling | Migration risk |
|---|---|---|
| `release-please-automerge.yml` → CI | `workflow_run: workflows: [CI]` matches `name: CI` | **HIGH.** Renaming the workflow `name:` breaks auto-merge silently. Keep `CI` as the gated workflow name. |
| `release.yml` `gate-ci-green` → ci.yml | polls `workflow_id: 'ci.yml'` on exact `head_sha` | **HIGH.** Rename the file → release publish never gates → either hangs or the resolve logic mis-fires. The gated workflow MUST keep running on `push:main` and produce a single success conclusion for the SHA. |
| `branch-protection-apply.yml` (cron `17 7 * * *` + dispatch) | runs `setup_branch_protection.sh main`, re-asserting `REQUIRED_CHECKS` nightly | **HIGH.** It will **revert** any required-checks change not also made in the script. Migration MUST update the script's array and the workflow split in the same PR, then run `setup_branch_protection.sh --print-expected` to confirm. Note `strict: true` (require branches up to date) is set — be aware this re-queues runs on base updates. |
| MinIO startup (4 lanes) | `docker run` + 30×2s poll | LOW — refactor opportunity, not a blocker. |

---

## Suggested Stepwise Build Order (PRs)

Honors **observability before classification, cache-correctness before partitioning, and "never rename the release-gated workflow without updating both consumers in the same PR."**

1. **PR-1 Observability / baseline (no behavior change).**
   Add per-job timing + `System.schedulers_online()` + cache hit/miss to `$GITHUB_STEP_SUMMARY`; add `mix test --slowest 20` and `mix compile --profile time` reporting (non-gating). Establishes the before/after numbers SEED-003 demands. **Zero topology change → zero branch-protection risk.**

2. **PR-2 Cache + version cleanup (correctness).**
   Extract the composite `setup-elixir` action; centralize cache keys; add a `v1-` cache-version buster; ensure every runner is the explicit `ubuntu-22.04` (note `release.yml public_verify` still uses `FedericoCarboni/setup-ffmpeg@v3` where the rest of the repo deliberately moved to `scripts/ci/install_ffmpeg.sh` — align it; pin third-party actions to SHAs per security posture). Still single-workflow shape → **no required-check rename yet.**

3. **PR-3 Add `ci-summary` aggregate + flip branch protection (the risky-but-isolated step).**
   Add the `CI Summary` job to `ci.yml` with `needs: [all current jobs]`; update `setup_branch_protection.sh` `REQUIRED_CHECKS` to **only `CI Summary`** (optionally keep legacy names for one transitional cycle as belt-and-suspenders); run the branch-protection apply and confirm with `--print-expected`. **Do this BEFORE any matrix/lane change** so subsequent renames don't touch branch protection again. This isolates the high-blast-radius branch-protection migration into one reviewable PR.

4. **PR-4 Trigger split + matrix/lane refinement.**
   Now that only `CI Summary` is required: add `ci-pr.yml` (fast path) and make `ci.yml`'s heavy legs `push:main`-only; collapse `quality`/`optional-dependencies` to 1.17/27 on PR; split `package-consumer` → `package-consumer-pr` (image) on PR + full matrix on main/nightly; move `gcs-soak` + `package-consumer-gcs-live` to a new `ci-nightly.yml`; add `concurrency:` groups (cancel PR / serialize main). **Keep `ci.yml` named `CI` on the `push:main` gate** so `release.yml`/automerge are untouched. This is the PR that delivers the ~5-7m wall-clock.

5. **PR-5 Test concurrency / partitioning + release/security polish.**
   Only after PR-4's numbers: ExUnit async-safety audit + `mix test --partitions` on the proven pole (`adoption-demo-e2e` or the unit suite); evaluate a larger runner *only if* partitioning doesn't help. Fold in remaining security posture (action SHA pinning everywhere, per-job `permissions:` least-privilege, confirm `release.yml`'s already-good `environment: release` + dry-run gating). Promote inline advisory Dialyzer to an owned nightly lane.

**Dependency rule the order enforces:** PR-1 (measure) → PR-2 (cache correctness) → PR-3 (summary gate, so PR-4 is branch-protection-free) → PR-4 (split/matrix) → PR-5 (partition/polish). Reversing PR-3 and PR-4 would force a second branch-protection migration when lanes get renamed — avoid that.

---

## Sources

- Real repo files (HIGH confidence, read line-by-line 2026-06-20): `.github/workflows/ci.yml` (14 jobs), `release.yml`, `release-please-automerge.yml`, `branch-protection-apply.yml`, `scripts/setup_branch_protection.sh` (13 required contexts), `scripts/ci/adoption_demo_e2e.sh`, `scripts/install_smoke.sh`, `scripts/ci/cohort_demo_smoke.sh`, `scripts/release_preflight.sh`.
- SEED-003 embedded maintainer prompt (`[GITHUB ACTIONS]` 6.1-6.8, `[IDEAL SHAPE]`, `[OUTPUT FORMAT]` §6/§7, `[DARK CORNERS]`) — authoritative spec.
- GitHub Actions canonical patterns: summary/aggregate required job; `concurrency` cancel-in-progress; `workflow_run` name-coupling; skipped-required-must-report-success (community-standard, used by Phoenix/Ecto/Nx/Ash CI). MEDIUM-HIGH confidence (well-established, not re-verified against live docs this pass).
- Project MEMORY: "gate the boot path that actually broke" (cohort-demo-smoke stays on PR); "automate UAT, shift-left" (keep merge-blocking gates, don't quietly move quality signal to nightly-only).

---
*Architecture research for: GitHub Actions CI/CD topology — Rindle v1.20 CI/CD Performance*
*Researched: 2026-06-20*
