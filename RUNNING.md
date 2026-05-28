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

`README.md` stays the narrow quickstart. [`guides/getting_started.md`](guides/getting_started.md)
is the canonical deep onboarding guide. This file is the shared install/runtime
matrix both of those entrypoints link to.

## CI lane severity

This section is maintainer-facing. [`.github/workflows/ci.yml`](.github/workflows/ci.yml)
is the source of truth for job wiring; GitHub branch protection and required-check
settings live outside the repo.

| Job / step | Severity | When it runs | Notes |
|------------|----------|--------------|-------|
| `quality` — Compile, Check formatting | merge-blocking | Every PR/push; Elixir 1.15/OTP 26 and 1.17/OTP 27 matrix | Both matrix cells must pass |
| `quality` — Credo (strict) | advisory | Same job | Step-level `continue-on-error` |
| `quality` — Doctor (full, raise) | advisory | Same job | Step-level `continue-on-error` |
| `quality` — Verify AV runtime with public doctor task | advisory | Same job | Step-level `continue-on-error` |
| `quality` — Run tests with coverage | merge-blocking | Same job | Default `mix test` suite via Coveralls; both matrix cells must pass |
| `quality` — Dialyzer | advisory | Same job | Step-level `continue-on-error` |
| `integration` | merge-blocking | `needs: quality` | Lifecycle + MinIO adapter tests |
| `contract` — Run AV hygiene gate | merge-blocking | `needs: quality` | `scripts/assert_av_hygiene.sh` |
| `contract` — Run contract tests | advisory | Same job | Step-level `continue-on-error`; job still required in graph |
| `proof` | merge-blocking | `needs: quality` | `docs_parity_test.exs` + `batch_owner_erasure_task_test.exs`; Postgres only; Elixir 1.17/OTP 27 |
| `package-consumer` | merge-blocking | `needs: quality` | Install-smoke matrix + release preflight |
| `adopter` | merge-blocking | `needs: [quality, integration, contract]` | Canonical adopter lifecycle only (doc parity in `proof` job) |
| `mux-soak` | secret-gated soak | Label `streaming` on PR; `needs: quality` | Blocking when the job runs (no `continue-on-error`) |
| `gcs-soak` | secret-gated soak | `needs: quality`; repo + secrets | Test step advisory; skips when secrets empty |
| `package-consumer-gcs-live` | secret-gated soak | `needs: quality`; repo + secrets | Job-level `continue-on-error`; live GCS install-smoke when secrets present |

### Static analysis policy (CI-04)

**Decision (v1.17):** Credo (strict) and Dialyzer remain **advisory** in the `quality`
job. Wiring uses step-level `continue-on-error: true` in
[`.github/workflows/ci.yml`](.github/workflows/ci.yml) (Credo L97–99, Dialyzer L131–133).
Making either tool merge-blocking is explicitly rejected for this milestone.

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
`ci.yml` on the release SHA. When the latest run conclusion is not `success`, or the wait
times out, the step logs `(BYPASSED)` and publish continues anyway. Tightening that bypass
is out of scope for v1.15.

### Post-merge checklist

After merging CI proof honesty changes, verify GitHub branch protection required checks
include `Proof`, `package-consumer`, and `adopter` if green-main honesty should hold in practice.

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

That is the same public posture taught in `README.md` and
`guides/getting_started.md`.
