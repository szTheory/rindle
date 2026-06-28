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
| `quality` — Run tests with coverage | merge-blocking | Same job | Default `mix test` suite run **once** via `mix coveralls.multiple --type local --type json` (single run → console gate + `cover/excoveralls.json`); both matrix cells must pass |
| `quality` — Dialyzer | advisory (until Phase 106) | Same job | Step-level `continue-on-error`. Phase 106 extracts this into an owned, **gating** `Dialyzer` job in `nightly.yml` (removed from PR runs) |
| `optional-dependencies` | merge-blocking | Every PR/push; Elixir 1.15/OTP 26 and 1.17/OTP 27 matrix | ADMIN-06 proof: `mix deps.get --no-optional-deps` and `mix compile --no-optional-deps --warnings-as-errors` |
| `integration` | merge-blocking | `needs: [quality, optional-dependencies]` | Lifecycle + MinIO adapter tests |
| `contract` — Run AV hygiene gate | merge-blocking | `needs: [quality, optional-dependencies]` | `scripts/assert_av_hygiene.sh` |
| `contract` — Run contract tests | advisory | Same job | Step-level `continue-on-error`; job still required in graph |
| `proof` | merge-blocking | `needs: [quality, optional-dependencies]` | `docs_parity_test.exs`, adoption proof matrix drift gate, `batch_owner_erasure_task_test.exs`; Postgres only; Elixir 1.17/OTP 27 |
| `package-consumer-full` — repo hygiene gate | off-critical-path | `push:main`/release (`if: github.event_name != 'pull_request'`) | `scripts/maintainer/repo_hygiene_check.sh --ci` — Phase 106: runs **only** inside `package-consumer-full`, so it is no longer on the PR lane (release/main gate, not merge-blocking on PRs) |
| `package-consumer` (lean, PR) | merge-blocking | `needs: [quality, optional-dependencies]` | Phase 106: representative `image`-only install-smoke + version alignment; stays in `CI Summary.needs` |
| `package-consumer-full` | off-critical-path | `push:main`/release (`if: github.event_name != 'pull_request'`) | Phase 106: full 5-profile matrix + release preflight + `hex.publish --dry-run`; **NOT** a required PR check (omitted from `CI Summary.needs`); release proof is the push:main run conclusion |
| `adoption-demo-unit` | merge-blocking | `needs: [quality, optional-dependencies]`; Postgres only | Fast ExUnit proof for `examples/adoption_demo`: brand mark/wordmark, admin-console mount, lifecycle-state display, README walkthrough parity (storage-free, direct-insert seeds) |
| `adoption-demo-e2e-smoke` | merge-blocking | Every PR (no repo/event gate); `needs: [quality, optional-dependencies]`; Postgres + MinIO-local | Phase 112: lean Chromium smoke (`e2e/smoke.spec.js` + `e2e/admin-console.spec.js` only, no screenshot spec) in the pinned Playwright container; the browser render-regression PR proxy. No secrets (MinIO-local literal creds), so it runs on forks too (skip==pass safety). Enters `CI Summary.needs` in Plan 02 after N=3 green push:main `adoption-demo-e2e` runs (GATE-04, operator checkpoint) |
| `adoption-demo-e2e` | off-critical-path | `push:main` only (repo `szTheory/rindle` + `if: github.event_name != 'pull_request'`); `needs: [quality, optional-dependencies]` | Phase 106: full Playwright browser proof for `examples/adoption_demo` (image, tus, stretch journeys, admin lifecycle render, homepage cold-start smoke + screenshot specs). **NOT** in `CI Summary.needs` — it is the release/main render signal, not a PR-required check; its PR-side proxy is the lean `adoption-demo-e2e-smoke` lane above |
| `cohort-demo-smoke` | off-critical-path | `push:main` only (repo `szTheory/rindle` + `if: github.event_name != 'pull_request'`); `needs: [quality, optional-dependencies]` | Phase 106: Docker-compose cold-start gate (`scripts/ci/cohort_demo_smoke.sh`): builds the demo image, boots the full stack, asserts homepage + admin console serve 200 with seeded data — the boot path human UAT used to cover. **NOT** in `CI Summary.needs`; it stays off the PR gate because the full docker-compose boot is too slow for the ≤7-min PR budget — it is the push:main/release signal, not a PR-required check |
| `brandbook-tokens` | merge-blocking | `needs: [quality, optional-dependencies]`; repo `szTheory/rindle` only | PIPE-01 drift gate: regenerates brandbook token CSS, admin CSS, gallery proof, and shipped priv/ CSS copy, then fails on any generated-artifact diff |
| `adopter` | merge-blocking | `needs: [quality, optional-dependencies, integration, contract]` | Canonical adopter lifecycle only (doc parity in `proof` job) |
| `mux-soak` | secret-gated soak (label-gated PR lane) | Label `streaming` on PR; `needs: quality` | Not in branch protection required checks; fails closed when secrets absent. Phase 106: **stays in `ci.yml`** as a label-gated PR lane (NOT moved to nightly) |
| `gcs-soak` | nightly (gating) | `nightly.yml`: schedule 07:27 UTC / `workflow_dispatch`; no `needs:`; repo `szTheory/rindle` + secrets | Skipped when secrets absent. Phase 106: **moved to `nightly.yml`** and **gating** — `continue-on-error` dropped, so a live-GCS regression is real nightly red |
| `package-consumer-gcs-live` | nightly (gating) | `nightly.yml`: schedule 07:27 UTC / `workflow_dispatch`; no `needs:`; repo `szTheory/rindle` + secrets | Live GCS install-smoke when secrets present (skipped otherwise). Phase 106: **moved to `nightly.yml`** and **gating** — `continue-on-error` dropped, so a live-GCS regression is real nightly red |

### Reproducing the coverage step locally (COV-04)

The full CI coverage step — the `quality` — Run tests with coverage row above — is
reproduced locally with a single command:

```sh
mix coveralls.multiple --type local --type json --slowest 20
```

One suite run emits both the console coverage gate and `cover/excoveralls.json`.
`--type local` runs the same `local` analyzer / `ensure_minimum_coverage` as the
gate; `--type json` is a side-artifact only and **never** decides pass/fail.

To reproduce the merge-blocking **gate alone** (no JSON artifact), `mix coveralls`
is unchanged — it runs the identical `local` analyzer and produces the same
pass/fail verdict.

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

Branch protection enforces a **single** required status check, `CI Summary` (enforced via
`scripts/setup_branch_protection.sh`, `REQUIRED_CHECKS=("CI Summary")`). None of the individual
lanes are required contexts; they gate merges transitively through `CI Summary.needs`, which lists
`quality`, `optional-dependencies`, `integration`, `contract`, `proof`, `package-consumer` (lean),
`adoption-demo-unit`, `adopter`, `brandbook-tokens`, and `ci-script-tests`. As of Phase 106,
`cohort-demo-smoke` and `adoption-demo-e2e` run **only on `push:main`** and are **NOT** in
`CI Summary.needs` — their regressions are caught on main (and block release via the push:main run
conclusion), not on the PR merge gate. `package-consumer-full` is likewise omitted from
`CI Summary.needs` (it is `if: github.event_name != 'pull_request'`).

Phase 112 adds the lean `adoption-demo-e2e-smoke` lane as the PR-side browser-render proxy for the
push:main-only `adoption-demo-e2e` lane. It runs on every PR today but is **not yet** in
`CI Summary.needs` — it is wired into the list above in Plan 02 (GATE-04), behind an operator
green-run checkpoint, only after N=3 consecutive green push:main `adoption-demo-e2e` runs confirm
the lane is non-flaky. Wiring it before that would risk importing a live flake into the required
gate. (GATE-A9 push:main issue-on-failure alerting is explicitly deferred — out of scope for
Phase 112.)

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
