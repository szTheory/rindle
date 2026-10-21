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

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) is the source of truth for job wiring;
the required-check identity is repository-structured as described under Release train, while the
applied GitHub branch-protection state remains remote. The `name: CI` and `ci.yml` filename are
**invariant** because release automation selects that workflow by name and filename.

> CI work is split by trigger so only representative signal stays on the PR critical
> path (≤7 min target):
> - The `package-consumer` lane is split. A **lean representative `image`-only
>   `package-consumer`** runs on PR (stays merge-blocking via `CI Summary`); a new
>   **`package-consumer-full`** runs on `push:main`/release with the full 5-profile matrix
>   + release preflight + `hex.publish --dry-run` and is **NOT** a required PR check.
> - The broad OTP×Elixir **`compat-matrix`**, **`dialyzer`**, **`gcs-soak`**, and
>   **`package-consumer-gcs-live`** lanes live in the separate **`nightly.yml`**
>   (`name: Nightly`). They are not required PR checks because Nightly has no PR trigger,
>   but are all **Nightly-gating** inputs to the strict `Nightly Summary`.
>   Any applicable lane that fails, is cancelled, is unexpected, is missing, or is
>   impermissibly skipped makes Nightly red.
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
| `optional-dependencies` | merge-blocking | Every PR/push; Elixir 1.15/OTP 26 and 1.17/OTP 27 matrix | Optional-dependency proof: `mix deps.get --no-optional-deps` and `mix compile --no-optional-deps --warnings-as-errors` |
| `integration` | merge-blocking | Starts independently; `CI Summary` waits for it | Lifecycle + MinIO adapter tests plus the disposable-database migration E2E suite (documented Ecto.Migrator path, lock contention, and real-role privilege refusals) |
| `contract` — Run AV hygiene gate, contract tests, preservation contract | merge-blocking | Starts independently; installs FFmpeg before its proof | AV hygiene plus deterministic `--only contract` tests and `scripts/maintainer/refactor_contract.sh`; the telemetry contract exercises the real AV path |
| `proof` | merge-blocking | `needs: [quality, optional-dependencies]` | docs-parity install/migrations, onboarding/capabilities, operations, and product/admin domain suites; adoption proof matrix drift gate; `batch_owner_erasure_task_test.exs`; Postgres only; Elixir 1.17/OTP 27 |
| `package-consumer-full` — repo hygiene gate | off-critical-path | `push:main`/release (`if: github.event_name != 'pull_request'`) | `scripts/maintainer/repo_hygiene_check.sh --ci`; release/main gate, not merge-blocking on PRs |
| `package-consumer` (lean, PR) | merge-blocking | Starts independently; `CI Summary` waits for it | Representative `image`-only install-smoke + version alignment; full profile breadth remains on main/release |
| `package-consumer-full` | off-critical-path | `push:main`/release (`if: github.event_name != 'pull_request'`) | Full 5-profile matrix + release preflight + `hex.publish --dry-run`; **NOT** a required PR check (omitted from `CI Summary.needs`); release proof is the push:main run conclusion |
| `adoption-demo-unit` | merge-blocking | `needs: [quality, optional-dependencies]`; Postgres only | Fast ExUnit proof for `examples/adoption_demo`: brand mark/wordmark, admin-console mount, lifecycle-state display, README walkthrough parity (storage-free, direct-insert seeds) |
| `adoption-demo-e2e-smoke` | merge-blocking | Every PR; starts independently with Postgres + MinIO-local | Lean Chromium smoke (`e2e/smoke.spec.js` + `e2e/admin-console.spec.js` only, no screenshot spec) in the pinned Playwright container. No secrets or repo/event gate, so it runs on forks and is included in `CI Summary.needs`. |
| `adoption-demo-e2e` | off-critical-path | `push:main` only (repo `szTheory/rindle` + `if: github.event_name != 'pull_request'`); `needs: [quality, optional-dependencies]` | Full Playwright browser proof for `examples/adoption_demo` (image, tus, stretch journeys, admin lifecycle render, homepage cold-start smoke + screenshot specs). **NOT** in `CI Summary.needs`; its PR-side proxy is the lean `adoption-demo-e2e-smoke` lane above. |
| `cohort-demo-smoke` | off-critical-path | `push:main` only (repo `szTheory/rindle` + `if: github.event_name != 'pull_request'`); `needs: [quality, optional-dependencies]` | Docker-compose cold-start gate (`scripts/ci/cohort_demo_smoke.sh`) that builds the demo image, boots the stack, and asserts the seeded homepage and admin console serve 200. **NOT** in `CI Summary.needs`; it is a push:main/release signal. |
| `brandbook-tokens` | merge-blocking | `needs: [quality, optional-dependencies]`; repo `szTheory/rindle` only | Generated-artifact drift gate: regenerates brandbook token CSS, admin CSS, gallery proof, and shipped priv/ CSS copy, then fails on any generated-artifact diff |
| `adopter` | merge-blocking | `needs: [quality, optional-dependencies, integration, contract]` | Canonical adopter lifecycle only (doc parity in `proof` job) |
| `mux-soak` | secret-gated soak (label-gated PR lane) | Label `streaming` on PR; `needs: quality` | Not in branch protection required checks; fails closed when secrets are absent. |
| `compat-matrix` | nightly (gating) | `nightly.yml`: schedule 07:27 UTC / `workflow_dispatch` | Broad OTP×Elixir compatibility; not a required PR check, but every matrix cell feeds strict `Nightly Summary`. |
| `dialyzer` | nightly (gating) | `nightly.yml`: schedule 07:27 UTC / `workflow_dispatch` | Owned type-contract lane; not a required PR check, but a failure makes Nightly red. |
| `gcs-soak` | nightly (gating) | `nightly.yml`: schedule 07:27 UTC / `workflow_dispatch`; no `needs:`; repo `szTheory/rindle` + secrets | Skipped when secrets are absent; a live-GCS regression makes Nightly red. |
| `package-consumer-gcs-live` | nightly (gating) | `nightly.yml`: schedule 07:27 UTC / `workflow_dispatch`; no `needs:`; repo `szTheory/rindle` + secrets | Live GCS install-smoke when secrets are present (skipped otherwise); failures make Nightly red. |

Nightly Dialyzer proves fresh and restored PLT modes independently on the supported Elixir 1.17 / OTP
27 cell. `Nightly Summary` applies the strict Nightly verdict: failed, cancelled, unexpected, missing,
or impermissibly skipped gating work is red. For the two live GCS jobs, the bounded upstream-repository
and required-secrets rule records secret-absent work as not-run rather than passed. Local runs on a
newer toolchain are diagnostic only. The current supported-cell acceptance authority is the exact-subject
Nightly evidence receipt committed with the maintainer evidence, authenticated against live GitHub
run/job/log state and detached local authorities by the repository's
`bash scripts/ci/verify_nightly_run.sh verify-receipt` contract.

### Reproducing the coverage step locally

The full CI coverage step — the `quality` — Run tests with coverage row above — is
reproduced locally with a single command:

```sh
mix coveralls.multiple --type local --type json
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

When collecting finite evidence, follow the active maintainer procedure for a
new report path. The runner rejects existing report files and paths outside the
maintainer-managed evidence location.

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

Active planning acceptance is also executable. After changing a current PLAN or VALIDATION artifact,
run:

```sh
./scripts/maintainer/automation_first_contract.sh
```

The contract rejects manual-only verification/UAT while permitting checkpoints whose sole purpose is
credential bootstrap or irreversible-action authorization. Repository hygiene runs the same check.

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

### Repository craft gates

These commands are the supported way to check repository craft locally. The test suite runs
the residue scan and the public surface snapshot, CI Script Tests runs the artifact ledger
and readability trace checks, and `repo_hygiene_check.sh --ci` runs on main. Maintainers run
the refactor boundary check and the evidence collector by hand; their harnesses run in
CI Script Tests.

| Gate | Command | What it enforces |
|------|---------|------------------|
| Live residue scan | `MIX_ENV=test mix run --no-start scripts/maintainer/scan_live_residue.exs --check --require-no-pending all` | Every planning-era identifier or craft residue hit in shipped files has an allowlist entry, no entry is stale, and no `pending-removal` entry remains. |
| Residue baseline refresh | `MIX_ENV=test mix run --no-start scripts/maintainer/scan_live_residue.exs --regen-baseline` | Only after an approved change to a `contract`, `policy`, `immutable-receipt` or `fixture` entry. Never use it to add `pending-removal` entries: remove the residue instead. |
| Artifact ledger | `bash scripts/maintainer/validate_artifact_ledger.sh --offline --require-settled` | Every tracked path belongs to exactly one class in `scripts/maintainer/artifact_ledger.json`, and no class still has disposition `delete`. A new tracked path needs a matching class pattern. The retained evidence receipt directory is a `retain` class and must not be archived; moving it fails with a `retained receipt` message. |
| Readability trace | `bash scripts/maintainer/validate_readability_trace.sh --offline --trace scripts/maintainer/readability_changes.json --baseline scripts/maintainer/credo_complexity_baseline.json` | Every readability refactor cites a frozen candidate id, a removed complexity-baseline identity and its proof commands. On the refactor branch, `--base origin/main` also checks that each removed identity existed in the base baseline. |
| Refactor boundary | `bash scripts/maintainer/craft_boundary_check.sh origin/main` | A readability refactor leaves release, migration, lock, telemetry-contract and public-surface files untouched. |
| Public surface snapshot | `mix test test/rindle/public_surface_snapshot_test.exs` | Public exports match `test/fixtures/public_surface.txt`. The fixture is pinned to the canonical Elixir 1.17 / OTP 27 lane; regenerate it there with the command the test prints, and only for an intended public API change. |
| Repository hygiene | `./scripts/maintainer/repo_hygiene_check.sh --ci`, `--release-prep`, `--release-prep --with-mix-ci` | `--ci` runs repo-owned checks, the artifact ledger and tracked junk. `--release-prep` adds fetch, branch, behind/ahead, generated drift and post-verification residue checks. `--with-mix-ci` also runs `mix ci` and requires its completion sentinel. |
| Phase gate evidence | `bash scripts/maintainer/collect_phase_gate_evidence.sh --repo szTheory/rindle --shas-file FILE --hygiene-log FILE --hygiene-exit N [--nightly-after SHA]` | Read-only. For each listed squash SHA it records the main push CI run and its `CI Summary` job, rejects `fix:` and `feat:` subjects, parses a release-prep hygiene log, and records the next scheduled Nightly as a non-blocking follow-up. Exit 0 means every check passed. |

### Release train

[`.github/workflows/release.yml`](.github/workflows/release.yml) `gate-ci-green` waits for
`ci.yml` on the release SHA to finish with conclusion `success`. When the latest run is
not green, or the wait times out, publish **fails closed** — there is no bypass path.

`config/ci_required_checks.json` is the sole structured authority for branch protection's required
status-check identity. Its workflow tuple maps `ci.yml` / `CI` / `ci-summary` to the sole required
context `CI Summary`. `scripts/setup_branch_protection.sh` loads its contexts when rendering or
applying branch protection, and `scripts/maintainer/validate_live_truth.exs` cross-checks the same
workflow, job, and context identity against parsed CI topology. None of the individual lanes are
required contexts; they gate merges transitively through `CI Summary.needs`, which lists
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

## Contributor verification commands

[CONTRIBUTING.md](CONTRIBUTING.md#clean-supported-setup) owns the clean supported
setup and the focused/full/nightly/measurement/release command map. Select the
accepted Elixir 1.17.3 / OTP 27.3.4.15 cell and CI's Node 20 before using it; the
older checked-in OTP hint is not a reason to change `.tool-versions` locally.

`bash scripts/maintainer/verify_contributor_bootstrap.sh --validate` checks the
ordered bootstrap contract without installing dependencies. `--run --full`
executes it and `mix ci` in a clean detached copy with private Mix/Hex homes,
300-second setup/focused command bounds, a 600-second full `mix ci` bound, and a
1200-second overall bound, writing a new receipt. Started commands that time out
remain terminal failed records with their argv, output digest and exit 124.
It is local contributor evidence, not a new CI coverage lane. The one canonical
coverage-floor measurement remains `mix coveralls.multiple --type local --type json`.

Source-bound measurement collectors retain numbered command output as `.txt`
artifacts so evidence can be committed without relaxing the tracked-junk policy.
Historical receipts keep their original `.log` references: when that path is absent,
the verifier accepts the same-basename `.txt` relocation after the existing size,
symlink and digest checks. An existing original path is never bypassed. The retained
output relocation manifest records the exact original paths, new paths and hashes.
