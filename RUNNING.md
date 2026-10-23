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

CI compiles Vix against the runner's installed `libvips-dev` using its supported
`PLATFORM_PROVIDED_LIBVIPS` mode. This avoids precompiled-asset redirects exceeding
the Erlang HTTP client's header limit. Dependency versions and test gates remain
the same; cold generated-consumer proof exercises the native build.

After public verification, the baseline ledger update opens an ordinary PR with
CI enabled and requests squash auto-merge for its exact head. The release job
observes the configured required GitHub Actions checks and actual merged state
for up to 45 minutes. A queued request, failed check, changed head or timeout
does not confirm landing. Inspect the linked PR on failure; auto-merge may still
be pending. CI observation uses the job token's read-only Checks permission;
PR operations retain their existing selected credential. No administrator merge
bypass is used. The offline behavior harness
is `python3 scripts/ci/test_land_release_train_baseline.py`.

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

Proof runs its four isolated Nightly evidence harnesses concurrently within the
existing job. It waits for every harness and fails if any harness fails; the
15-minute job ceiling and merge-blocking `CI Summary` authority are unchanged.

### Built-package synthetic twin

Maintainers can exercise six isolated recovery cases against one freshly built
Hex archive with:

```sh
python3 scripts/maintainer/built_package_twin.py check
python3 scripts/maintainer/built_package_twin.py run \
  --evidence-dir /absolute/new-or-empty/evidence --cleanup
python3 scripts/maintainer/built_package_twin.py verify \
  --inputs /absolute/new-or-empty/evidence/inputs.json \
  --receipt /absolute/new-or-empty/evidence/receipt.json
```

Use the supported Elixir 1.17.3 / OTP 27.3.4.15 toolchain overrides above. The cases
cover tus resume, purge after object absence, AV failure and repair, provider event
ordering/replay, promotion across host death and interrupted maintenance cleanup.
`run --case CASE` and `verify --case CASE --inputs ... --receipt ...` are focused
diagnostics; default verification requires all six cases. Explicit `--legacy`
preserves the earlier image/purge scenario and its narrower evidence.

See [Built-package twin](built_package_twin.html) for prerequisites, retained
private inputs/archive/receipts, JSON results and exact descriptor cleanup.
Cleanup refuses active hosts and foreign resources and can be repeated after
disposal. Historical twin receipts exclude Doctor; exact-head readiness separately
exercises the corrected public Doctor.
This is maintainer-operated synthetic evidence with `independent_pilot_credit: false`.
Default tests remain Docker-free; the real run is explicit and grants no independent
adoption, cloud-provider parity, Doctor, readiness or CI-speed credit. Existing CI
lanes and required contexts stay unchanged.

## Maintainer: exact-head readiness evidence

Readiness is an observation of one merged main SHA over a recorded interval. The
maintainer-operated synthetic twin grants no independent Phoenix pilot or 1.0
release authority. PILOT-01 and PILOT-02 stay open. The exact-ten median/p95 speed
target remains `deferred_unfinished`, with zero acceptance credit; its original
blocked receipt and the recorded follow-up remain unchanged.

Use the pinned OTP 27.3.4.15, Elixir 1.17.3-otp-27 and Node 20.18.1 toolchain,
Docker Compose, PostgreSQL client, libvips, FFmpeg and the normal contributor tools.
Authenticate `gh` for the selected repository. Read access must cover complete
private advisory states, Dependabot, effective protection, Actions and all inbox
sources. Missing authorization fails closed. The producer requires a
`READINESS_READ_TOKEN` secret; provisioning it or changing repository security policy
is a separate authorized maintainer operation.

Every output below must be a **new external directory**. Run from a clean checkout
of the authenticated current main after all implementation, workflow, documentation
and planning changes have merged. Choose an absolute durable evidence location on
a restricted maintainer host, outside temporary directories and Actions runners.
Keep the parent directory mode 0700. A runner directory or artifact URL earns no
READY credit. The controller restricts files to 0600 and directories to 0700.
On a maintainer Mac, the recommended parent is
`$HOME/Library/Application Support/Rindle/readiness`; use a distinct child for each
attempt and include the folder in an encrypted backup. See
[storage and credential decisions](readiness_evidence.html) for the tradeoffs
and exact producer token permissions. Creating the folder does not configure a backup.

```bash
# Set these to distinct new absolute directories outside the checkout.
export READINESS_SUBJECT_DIR=/durable/maintainer/readiness/subject-UNIQUE
export READINESS_EVIDENCE_DIR=/durable/maintainer/readiness/accept-UNIQUE
bash scripts/maintainer/exact_head_readiness.sh verify-subject \
  --repo szTheory/rindle --output "$READINESS_SUBJECT_DIR"
bash scripts/maintainer/exact_head_readiness.sh accept \
  --repo szTheory/rindle --output "$READINESS_EVIDENCE_DIR"
```

`verify-subject` compares clean local HEAD to authenticated remote main and checks
all declared source paths and all eight plans at that SHA. `accept` repeats that
check, dispatches `readiness-retention.yml` on main with a unique request nonce,
and waits at most 200 minutes for the matching successful first attempt. The
producer runs `close` and uploads two uniquely named, immutable artifacts: the
redacted archive and a separate producer run/attempt-bound digest sidecar. It
does not retrieve its own output. Each upload has missing-file errors, no overwrite
and 30-day retention. The workflow exposes both artifact IDs and transport digests.

The durable controller authenticates the completed run and current attempt,
downloads the sidecar first, then verifies downloaded archive and manifest bytes
against the producer's separate digests. It atomically stores the bundle and
locator, collects a new same-subject mutable refresh, runs the immutable graph
validator and rechecks main and authoritative adoption parity. Only its execution
`terminal-verdict.json` with `verdict: ready` grants subject- and interval-qualified
historical READY credit. `candidate_ready`, `fixture_ready`, an upload, a human
approval, or any fixture pass grants none. Inspect `attempt.json` and the terminal
reason on failure; private API bodies and command logs stay under `restricted/`.

The underlying operations are also callable independently:

```bash
bash scripts/maintainer/exact_head_readiness.sh qualify \
  --repo szTheory/rindle --subject EXACT_MAIN_SHA --output NEW_EXTERNAL_LOCAL
bash scripts/maintainer/exact_head_readiness.sh close \
  --repo szTheory/rindle --output NEW_EXTERNAL_CANDIDATE
mix run --no-start scripts/maintainer/validate_exact_head_readiness.exs \
  --manifest CANDIDATE/portable/manifest.json --root CANDIDATE/portable \
  --verdict NEW_OFFLINE_VERDICT.json
bash scripts/maintainer/exact_head_readiness.sh refresh \
  --repo szTheory/rindle --manifest CANDIDATE/portable/manifest.json \
  --output NEW_EXTERNAL_REFRESH
# prepare is for the authenticated maintainer-dispatched producer environment.
bash scripts/maintainer/retain_readiness_bundle.sh prepare \
  --manifest CANDIDATE/portable/manifest.json --output NEW_EXTERNAL_UPLOAD
# retrieve is for the durable host after that producer run completes.
bash scripts/maintainer/retain_readiness_bundle.sh retrieve \
  --repo szTheory/rindle --run-id PRODUCER_RUN_ID --attempt PRODUCER_ATTEMPT \
  --destination NEW_DURABLE_DIRECTORY
bash scripts/maintainer/exact_head_readiness.sh claim-status \
  --repo szTheory/rindle --verdict "$READINESS_EVIDENCE_DIR/terminal-verdict.json" \
  --output NEW_EXTERNAL_CLAIM_OBSERVATION
```

The retained layout is `durable/locator.json`, `durable/readiness-digest.json`,
`durable/readiness-evidence.tar.gz` and `durable/bundle/manifest.json`. Refreshed
receipts and the original unchanged manifest live in `refresh/portable/`.
`terminal-verdict.json` hashes those references and the final validator result.
Keep the complete directory together. `claim-status` rechecks referenced bytes
and the stored refresh graph. If main advanced, it reports `historical_ready`
without current readiness. If main still matches, it requires a clean matching
checkout and a new complete mutable refresh before reporting `current_ready`.
An omitted claim output creates a new sibling observation directory. Later READY
completion metadata must include the accepted SHA, interval, terminal locator and
explicit historical scope; unqualified checked requirements or completion rows fail.

| Reason | Repair / next observation |
|---|---|
| `closing_subject_not_checked_out`, `dirty_closing_checkout`, `phase_inventory_missing` | Land the complete PR train, obtain a clean main checkout, then rerun `verify-subject` into a new directory. |
| `main_changed` | Select the new current main and rerun `accept`; never splice old-subject receipts. |
| `scheduled_run_missing`, failed newest scheduled run | Wait for the next successful scheduled Nightly on that same SHA, then rerun `accept`; dispatching Nightly grants no scheduled credit. |
| `pull_undispositioned`, remote inventory drift | Reconcile the executable inbox ledger with every current item, merge it through the PR train, then collect the new main. |
| `remote_unauthorized`, `remote_forbidden`, unavailable protection/security source | Restore authorized complete source visibility; do not substitute an empty inventory. |
| `producer_failed`, `producer_wait_timeout`, absent sidecar/archive | Inspect the matching producer run and its bounded failure; rerun `accept` with a new request and output after repair. |
| `producer_identity`, `producer_sidecar_identity`, digest mismatch, expired artifact | Retrieve the exact completed run/current attempt's intact artifact pair or produce a new candidate. Never recompute expected digests from downloaded bytes. |
| `ephemeral_destination`, `durable_host_required`, storage failure | Use restricted persistent maintainer storage and rerun retrieval into a new directory. |
| `adoption_inflation`, `one_point_zero_authority`, `adoption_authority` | Restore honest synthetic-only authoritative claims and matching input bytes; independent pilot acceptance needs its own automated evidence. |
| `unqualified_readiness_metadata` | Qualify historical completion with SHA, interval and terminal locator; rerun `claim-status`. |
| local gate / cleanup failure | Inspect restricted diagnostics; `exact_head_readiness.sh cleanup --output ORIGINAL_LOCAL_OUTPUT` retries only owned resources and preserves the original failed attempt. Start a new qualification after repair. |

Historical prerequisite reports are checked as committed delivery records. Their
old covered fingerprints and original timing debt are preserved; they provide no
current READY credit. The current qualifier reruns all eighteen local gates and
the six-case package twin recovery matrix. It needs neither a local GSD install
nor another machine's temporary matrix directory.

Run `bash scripts/ci/test_readiness_fixtures.sh` for the cheap implementation
fixtures. CI Script Tests uses only the already locked Jason/yamerl parser runtime;
it does not run native qualification. CI awaits three independent groups (existing
contracts, Nightly incident fixtures, readiness fixtures) under a shared four-minute
bound within the unchanged five-minute job. Any group failure fails the job.
`bash scripts/ci/test_script_test_groups.sh`
checks failure propagation and owned timeout disposal. Existing CI/CI Summary topology
and release automation authority remain the release train gates.
