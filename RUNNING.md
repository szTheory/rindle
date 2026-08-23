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

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) is the source of truth for job wiring; GitHub branch protection and required-check settings live outside the repo. The `name: CI` and `ci.yml` filename are **invariant** because release automation selects that workflow by name and filename.

> CI work is split by trigger so only representative signal stays on the PR critical
> path (≤7 min target):
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
> The `name: CI` / `ci.yml` filename invariant and the merge-blocking PR lanes remain
> unchanged. The table below is the maintained public classification.

| Job / step | Severity | When it runs | Notes |
|------------|----------|--------------|-------|
| `quality` — Compile, Check formatting | merge-blocking | Every PR/push; Elixir 1.15/OTP 26 and 1.17/OTP 27 matrix | Both matrix cells must pass |
| `quality` — Credo quality | merge-blocking | Canonical lint cell (Elixir 1.17/OTP 27) | `scripts/maintainer/credo_quality.sh`: reviewed warnings, public-contract checks, and complexity inventory |
| `quality` — Doctor (full, raise) | merge-blocking | Canonical lint cell (Elixir 1.17/OTP 27) | Measured public `lib/` report under `MIX_ENV=dev` |
| `quality` — Credo (strict, advisory style) | advisory | Canonical lint cell | Full-tree style output remains visible with step-level `continue-on-error` |
| `quality` — Verify AV runtime with public doctor task | advisory | Same job | Requires DB, Oban, and canonical profile readiness that this job intentionally does not prepare |
| `quality` — Run focused AV behavior tests | merge-blocking | Same job, after FFmpeg/libvips installation | Real FFmpeg/ffprobe fixture and Vix/libvips behavior proof; no `vips` CLI is required |
| `quality` — Run tests with coverage | merge-blocking | Same job | Default `mix test` suite run **once** via `mix coveralls.multiple --type local --type json` (single run → console gate + `cover/excoveralls.json`); both matrix cells must pass |
| `optional-dependencies` | merge-blocking | Every PR/push; Elixir 1.15/OTP 26 and 1.17/OTP 27 matrix | ADMIN-06 proof: `mix deps.get --no-optional-deps` and `mix compile --no-optional-deps --warnings-as-errors` |
| `integration` | merge-blocking | `needs: [quality, optional-dependencies]` | Lifecycle + MinIO adapter tests plus the disposable-database migration E2E suite (documented Ecto.Migrator path, lock contention, and real-role privilege refusals) |
| `contract` — Run AV hygiene gate, contract tests, SAFE-01 | merge-blocking | `needs: [quality, optional-dependencies]`; after FFmpeg installation | AV hygiene plus deterministic `--only contract` tests and `scripts/maintainer/refactor_contract.sh`; the telemetry contract exercises the real AV path |
| `proof` | merge-blocking | `needs: [quality, optional-dependencies]` | `docs_parity_test.exs`, adoption proof matrix drift gate, `batch_owner_erasure_task_test.exs`; Postgres only; Elixir 1.17/OTP 27 |
| `package-consumer-full` — repo hygiene gate | off-critical-path | `push:main`/release (`if: github.event_name != 'pull_request'`) | `scripts/maintainer/repo_hygiene_check.sh --ci`; release/main gate, not merge-blocking on PRs |
| `package-consumer` (lean, PR) | merge-blocking | `needs: [quality, optional-dependencies]` | Representative `image`-only install-smoke + version alignment; stays in `CI Summary.needs` |
| `package-consumer-full` | off-critical-path | `push:main`/release (`if: github.event_name != 'pull_request'`) | Full 5-profile matrix + release preflight + `hex.publish --dry-run`; **NOT** a required PR check (omitted from `CI Summary.needs`); release proof is the push:main run conclusion |
| `adoption-demo-unit` | merge-blocking | `needs: [quality, optional-dependencies]`; Postgres only | Fast ExUnit proof for `examples/adoption_demo`: brand mark/wordmark, admin-console mount, lifecycle-state display, README walkthrough parity (storage-free, direct-insert seeds) |
| `adoption-demo-e2e-smoke` | merge-blocking | Every PR (no repo/event gate); `needs: [quality, optional-dependencies]`; Postgres + MinIO-local | Lean Chromium smoke (`e2e/smoke.spec.js` + `e2e/admin-console.spec.js` only, no screenshot spec) in the pinned Playwright container. No secrets, so it runs on forks and is included in `CI Summary.needs`. |
| `adoption-demo-e2e` | off-critical-path | `push:main` only (repo `szTheory/rindle` + `if: github.event_name != 'pull_request'`); `needs: [quality, optional-dependencies]` | Full Playwright browser proof for `examples/adoption_demo` (image, tus, stretch journeys, admin lifecycle render, homepage cold-start smoke + screenshot specs). **NOT** in `CI Summary.needs`; its PR-side proxy is the lean `adoption-demo-e2e-smoke` lane above. |
| `cohort-demo-smoke` | off-critical-path | `push:main` only (repo `szTheory/rindle` + `if: github.event_name != 'pull_request'`); `needs: [quality, optional-dependencies]` | Docker-compose cold-start gate (`scripts/ci/cohort_demo_smoke.sh`) that builds the demo image, boots the stack, and asserts the seeded homepage and admin console serve 200. **NOT** in `CI Summary.needs`; it is a push:main/release signal. |
| `brandbook-tokens` | merge-blocking | `needs: [quality, optional-dependencies]`; repo `szTheory/rindle` only | PIPE-01 drift gate: regenerates brandbook token CSS, admin CSS, gallery proof, and shipped priv/ CSS copy, then fails on any generated-artifact diff |
| `adopter` | merge-blocking | `needs: [quality, optional-dependencies, integration, contract]` | Canonical adopter lifecycle only (doc parity in `proof` job) |
| `mux-soak` | secret-gated soak (label-gated PR lane) | Label `streaming` on PR; `needs: quality` | Not in branch protection required checks; fails closed when secrets are absent. |
| `dialyzer` | nightly (gating) | `nightly.yml`: schedule 07:27 UTC / `workflow_dispatch` | Owned type-contract lane; not a required PR check, but a failure makes Nightly red. |
| `gcs-soak` | nightly (gating) | `nightly.yml`: schedule 07:27 UTC / `workflow_dispatch`; no `needs:`; repo `szTheory/rindle` + secrets | Skipped when secrets are absent; a live-GCS regression makes Nightly red. |
| `package-consumer-gcs-live` | nightly (gating) | `nightly.yml`: schedule 07:27 UTC / `workflow_dispatch`; no `needs:`; repo `szTheory/rindle` + secrets | Live GCS install-smoke when secrets are present (skipped otherwise); failures make Nightly red. |

### Reproducing the coverage step locally (COV-04)

The full CI coverage step — the `quality` — Run tests with coverage row above — is
reproduced locally with a single command:

```sh
mix coveralls.multiple --type local --type json --slowest 20
```

One suite run emits both the console coverage gate and `cover/excoveralls.json`.
`--type local` runs the same `local` analyzer / `ensure_minimum_coverage` as the
gate; `--type json` is a side-artifact only and **never** decides pass/fail.

### Local async-isolation evidence (issue #42)

The issue-evidence matrix is a maintainer-only local command, not a CI job and not
a replacement for the single Quality coverage invocation. First inspect its fixed
25-seed plan without running coverage:

```sh
bash scripts/maintainer/async_isolation_evidence.sh --validate
```

When you are ready to collect the finite evidence, choose a new explicit report
path under the Phase 125 directory:

```sh
bash scripts/maintainer/async_isolation_evidence.sh \
  --report .planning/phases/125-behavioral-test-support/async-isolation-evidence.jsonl
```

The runner starts one fresh foreground `mix coveralls.multiple --type local --type
json --seed SEED --slowest 20` process per fixed seed, stops at the first nonzero
exit, and records only the seed, revision, toolchain, argv, exit, and a bounded
sanitized failure location. Do not add this loop to CI or run a second coverage
command for any one seed.

To reproduce the merge-blocking **gate alone** (no JSON artifact), `mix coveralls`
is unchanged — it runs the identical `local` analyzer and produces the same
pass/fail verdict.

### Truthful quality policy

The reviewed Credo aggregate and measured public Doctor report are merge-blocking on the
canonical Quality lint cell. Reproduce them locally with:

```sh
mix credo_quality
MIX_ENV=dev mix doctor --full --raise
mix refactor_contract
```

`mix quality_signals` runs those three deterministic checks in that order, and `mix ci`
includes it before the repository's one default test-suite execution. The full-tree
`mix credo --strict --format oneline` style report remains intentionally advisory in CI;
it is visible for maintainer review but is not the reviewed actionable policy.

For focused real AV behavior, first install the host prerequisites described above
(FFmpeg >= 6 and libvips for Vix), then run:

```sh
mix test test/rindle/probe/av_probe_test.exs test/rindle/processor/image_test.exs --seed 0
```

This test command exercises FFmpeg/ffprobe and Vix/libvips directly; it does not require
a standalone `vips` CLI. The public `mix rindle.doctor` remains a separate, advisory
runtime readiness command in Quality because that job intentionally lacks the adopter's
DB, Oban, and profile-host setup. Run it only from a DB/Oban/profile-ready adopter host.

Dialyzer remains an owned, gating Nightly signal, outside the PR-local alias and critical
path. Push-main/full-verification-only lanes likewise remain outside `mix ci`; the release
workflow still relies on the complete `ci.yml` run for the exact release SHA.

### Release train

[`.github/workflows/release.yml`](.github/workflows/release.yml) `gate-ci-green` waits for
`ci.yml` on the release SHA to finish with conclusion `success`. When the latest run is
not green, or the wait times out, publish **fails closed** — there is no bypass path.

Branch protection enforces a **single** required status check, `CI Summary` (enforced via
`scripts/setup_branch_protection.sh`, `REQUIRED_CHECKS=("CI Summary")`). None of the individual
lanes are required contexts; they gate merges transitively through `CI Summary.needs`, which lists
`quality`, `optional-dependencies`, `integration`, `contract`, `proof`, `package-consumer` (lean),
`adoption-demo-unit`, `adoption-demo-e2e-smoke`, `adopter`, `brandbook-tokens`, and
`ci-script-tests`.
`cohort-demo-smoke` and `adoption-demo-e2e` run **only on `push:main`** and are **NOT** in
`CI Summary.needs` — their regressions are caught on main (and block release via the push:main run
conclusion), not on the PR merge gate. `package-consumer-full` is likewise omitted from
`CI Summary.needs` (it is `if: github.event_name != 'pull_request'`). The lean
`adoption-demo-e2e-smoke` lane is the merge-blocking PR-side browser-render proxy for the
push:main-only full E2E lane.

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

Use the repository installer so CI resolves a stable static build and validates
the required FFmpeg major version:

```yaml
- name: Install FFmpeg
  run: bash scripts/ci/install_ffmpeg.sh

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
