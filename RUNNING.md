# Running Rindle Image and AV Profiles

Use this guide for host-runtime dependencies before Rindle background jobs process
variants. Image processing uses libvips (via Vix). AV processing uses FFmpeg.

## Image runtime (libvips)

Image-only adopters need libvips on the host before `ProcessVariant` jobs run:

1. install libvips for the target platform
2. run `mix rindle.doctor`
3. only then start background jobs that generate image variants

| Platform | Install |
|----------|---------|
| macOS (Homebrew) | `brew install vips` |
| Ubuntu / Debian (apt) | `sudo apt-get update && sudo apt-get install -y libvips-dev` |
| Alpine (apk) | `apk add --no-cache vips-dev` |
| GitHub Actions | `sudo apt-get install -y libvips-dev` (same as CI `quality` job) |

## AV runtime (FFmpeg)

Use this section when your adopter app enables video or audio processing. The AV
runtime contract is small and explicit:

1. install `FFmpeg >= 6.0` for the target platform
2. run `mix rindle.doctor`
3. only then start background jobs that process AV variants

[README](readme.html) stays the narrow quickstart. [Getting Started](getting_started.html)
is the canonical deep onboarding guide. This file is the shared install/runtime
matrix both of those entrypoints link to.

## Maintainer: CI lane severity

> Adopters can skip this section. It documents how this repository gates merges and releases.

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) is the source of truth for job wiring; GitHub branch protection and required-check settings live outside the repo. The `name: CI` and `ci.yml` filename are **invariant** (release-train coupling) and are not renamed by the Phase-106 split.

> **Phase 106 trigger split (forward reference).** Phase 106 splits CI work by *trigger*
> so only representative signal stays on the PR critical path (≤7 min target):
> - The `package-consumer` lane is split. A **lean representative `image`-only
>   `package-consumer`** runs on PR (stays merge-blocking via `CI Summary`); a new
>   **`package-consumer-full`** runs on `push:main`/release with the full 5-profile matrix
>   + release preflight + `hex.publish --dry-run` and is **NOT** a required PR check.
> - The broad OTP×Elixir **compat matrix**, **`gcs-soak`**, **`package-consumer-gcs-live`**,
>   and an owned gating **Dialyzer** lane move to a separate **`nightly.yml`** (`name:
>   Nightly`), advisory and never a required PR check.
> - **`mux-soak` stays here** in `ci.yml` as a **label-gated PR lane** (not moved to
>   nightly).
>
> The `name: CI` / `ci.yml` filename invariant and the merge-blocking PR lanes (`quality`,
> `integration`, `contract`, `proof`, `adopter`) are unchanged. Full rationale:
> [`106-LANE-CLASSIFICATION.md`](.planning/phases/106-trigger-split-matrix-lane-refinement/106-LANE-CLASSIFICATION.md).

| Job / step | Severity | When it runs | Notes |
|------------|----------|--------------|-------|
| `quality` — Compile, Check formatting | merge-blocking | Every PR/push; Elixir 1.15/OTP 26 and 1.17/OTP 27 matrix | Both matrix cells must pass |
| `quality` — Credo (strict) | advisory | Same job | Step-level `continue-on-error` |
| `quality` — Doctor (full, raise) | advisory | Same job | Step-level `continue-on-error` |
| `quality` — Verify AV runtime with public doctor task | advisory | Same job | Step-level `continue-on-error` |
| `quality` — Run tests with coverage | merge-blocking | Same job | Default `mix test` suite via Coveralls; both matrix cells must pass |
| `quality` — Dialyzer | advisory (until Phase 106) | Same job | Step-level `continue-on-error`. Phase 106 extracts this into an owned, **gating** `Dialyzer` job in `nightly.yml` (removed from PR runs) |
| `optional-dependencies` | merge-blocking | Every PR/push; Elixir 1.15/OTP 26 and 1.17/OTP 27 matrix | ADMIN-06 proof: `mix deps.get --no-optional-deps` and `mix compile --no-optional-deps --warnings-as-errors` |
| `integration` | merge-blocking | `needs: [quality, optional-dependencies]` | Lifecycle + MinIO adapter tests |
| `contract` — Run AV hygiene gate | merge-blocking | `needs: [quality, optional-dependencies]` | `scripts/assert_av_hygiene.sh` |
| `contract` — Run contract tests | advisory | Same job | Step-level `continue-on-error`; job still required in graph |
| `proof` | merge-blocking | `needs: [quality, optional-dependencies]` | `docs_parity_test.exs`, adoption proof matrix drift gate, `batch_owner_erasure_task_test.exs`; Postgres only; Elixir 1.17/OTP 27 |
| `package-consumer` — repo hygiene gate | merge-blocking | Same job | `scripts/maintainer/repo_hygiene_check.sh --ci` |
| `package-consumer` (lean, PR) | merge-blocking | `needs: [quality, optional-dependencies]` | Phase 106: representative `image`-only install-smoke + version alignment; stays in `CI Summary.needs` |
| `package-consumer-full` | off-critical-path | `push:main`/release (`if: github.event_name != 'pull_request'`) | Phase 106: full 5-profile matrix + release preflight + `hex.publish --dry-run`; **NOT** a required PR check (omitted from `CI Summary.needs`); release proof is the push:main run conclusion |
| `adoption-demo-unit` | merge-blocking | `needs: [quality, optional-dependencies]`; Postgres only | Fast ExUnit proof for `examples/adoption_demo`: brand mark/wordmark, admin-console mount, lifecycle-state display, README walkthrough parity (storage-free, direct-insert seeds) |
| `adoption-demo-e2e` | merge-blocking | `needs: [quality, optional-dependencies]`; repo `szTheory/rindle` only | Playwright browser proof for `examples/adoption_demo` (image, tus, stretch journeys, admin lifecycle render, homepage cold-start smoke) |
| `cohort-demo-smoke` | merge-blocking | `needs: [quality, optional-dependencies]`; repo `szTheory/rindle` only | Docker-compose cold-start gate (`scripts/ci/cohort_demo_smoke.sh`): builds the demo image, boots the full stack, asserts homepage + admin console serve 200 with seeded data — the boot path human UAT used to cover |
| `brandbook-tokens` | merge-blocking | `needs: [quality, optional-dependencies]`; repo `szTheory/rindle` only | PIPE-01 drift gate: regenerates brandbook token CSS, admin CSS, gallery proof, and shipped priv/ CSS copy, then fails on any generated-artifact diff |
| `adopter` | merge-blocking | `needs: [quality, optional-dependencies, integration, contract]` | Canonical adopter lifecycle only (doc parity in `proof` job) |
| `mux-soak` | secret-gated soak (label-gated PR lane) | Label `streaming` on PR; `needs: quality` | Not in branch protection required checks; fails closed when secrets absent. Phase 106: **stays in `ci.yml`** as a label-gated PR lane (NOT moved to nightly) |
| `gcs-soak` | secret-gated soak | `needs: quality`; repo + secrets | Skipped when secrets absent; test step advisory when it runs. Phase 106: **moves to `nightly.yml`** (advisory, off the PR critical path) |
| `package-consumer-gcs-live` | secret-gated soak | `needs: quality`; repo + secrets | Job-level `continue-on-error`; live GCS install-smoke when secrets present. Phase 106: **moves to `nightly.yml`** and drops `continue-on-error` so it becomes a real nightly signal |

### Static analysis policy (CI-04)

**Decision:** Credo (strict) and Dialyzer remain **advisory** in the `quality`
job. Wiring uses step-level `continue-on-error: true` in
[`.github/workflows/ci.yml`](.github/workflows/ci.yml).
Making either tool merge-blocking is explicitly rejected for the current release train.

**Rationale:**

- **Signal value:** Static analysis catches style and typespec drift; failures remain
  visible in CI logs for maintainers without blocking adopter-critical merge lanes.
- **Fork latency:** Dialyzer PLT build is slow; merge-blocking would raise contributor
  and fork PR cost disproportionate to adopter impact.
- **Green-main honesty:** Adopter-critical lanes are already merge-blocking (`mix coveralls`,
  `proof`, `package-consumer`, `adopter`, `integration`, contract AV hygiene). Static
  analysis is maintainer hygiene, not adopter contract.

Doctor and AV doctor steps remain advisory without a separate CI-04 decision record
(CI-04 names Credo and Dialyzer only). See matrix rows above.

### Release train

[`.github/workflows/release.yml`](.github/workflows/release.yml) `gate-ci-green` waits for
`ci.yml` on the release SHA to finish with conclusion `success`. When the latest run is
not green, or the wait times out, publish **fails closed** — there is no bypass path.

Branch protection required checks (enforced via `scripts/setup_branch_protection.sh`) include
Quality (both matrix cells), ADMIN-06 Optional Dependencies (both matrix cells), Integration,
Contract, Proof, Package Consumer Proof Matrix + Release Preflight, Adopter, Adoption Demo Unit,
Adoption Demo E2E, Cohort Demo Smoke, and brandbook-tokens.

## Verify The Runtime

Run this in the adopter app after `mix deps.get` and after installing FFmpeg:

```bash
mix rindle.doctor
```

The command must pass before you debug Oban workers, variant failures, or
delivery URLs.

## FFmpeg Install Matrix

### macOS (Homebrew)

```bash
brew install ffmpeg
mix rindle.doctor
```

### Ubuntu / Debian (apt)

```bash
sudo apt-get update
sudo apt-get install -y ffmpeg
mix rindle.doctor
```

### Alpine (apk)

```bash
apk add --no-cache ffmpeg
mix rindle.doctor
```

### Fly.io Dockerfile

Add FFmpeg to the image build:

```dockerfile
RUN apt-get update \
 && apt-get install -y ffmpeg \
 && rm -rf /var/lib/apt/lists/*
```

Run `mix rindle.doctor` during build or release validation before the app
starts workers.

### Heroku Aptfile

Add an `Aptfile` at the app root with:

```text
ffmpeg
```

Then run `mix rindle.doctor` as part of release validation.

### Render Dockerfile

Add FFmpeg to the Render image build:

```dockerfile
RUN apt-get update \
 && apt-get install -y ffmpeg \
 && rm -rf /var/lib/apt/lists/*
```

Run `mix rindle.doctor` in the build or pre-deploy command.

### GitHub Actions

Use `FedericoCarboni/setup-ffmpeg` so CI exercises the same runtime posture:

```yaml
- name: Install FFmpeg
  uses: FedericoCarboni/setup-ffmpeg@v3
  with:
    ffmpeg-version: 6.0

- name: Verify Rindle runtime
  run: mix rindle.doctor
```

## Canonical AV Profile Shape

The onboarding story stays on the stock `web_720p` plus `poster` surface. The
explicit variant declarations are:

```elixir
variants: [
  web_720p: [kind: :video, preset: :web_720p],
  poster: [kind: :image, preset: :video_poster_scene]
]
```

That is the same public posture taught in [README](readme.html) and
[Getting Started](getting_started.html).
