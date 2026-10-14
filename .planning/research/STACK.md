# Technology Stack

**Project:** Rindle — v1.26 Pre-Adopter Readiness & Quality Consolidation
**Researched:** 2026-09-09
**Overall confidence:** HIGH for repository facts; MEDIUM for current external-tool facts, which were checked against official sources on the research date

## Recommendation

Keep the product and test stack unchanged. This milestone does not justify a new runtime dependency, a new application, or a general-purpose quality platform. Rindle already has the right primitives for the quality census and digital twin: ExUnit, `Oban.Testing`, Mox, Bypass, Jason, Playwright, the Cohort Phoenix app, generated package-consumer proof, Credo, Dialyzer, Doctor, ExCoveralls, `mix_audit`, and repository-owned Bash/Elixir evidence collectors.

Add one narrowly scoped CI tool: **actionlint 1.7.12**, installed from its exact release asset with the published SHA-256 checksum. `YamlElixir` proves that YAML parses; actionlint proves that GitHub Actions schema, expressions, contexts, matrices, dependencies, permissions, action inputs, and embedded scripts are structurally credible. Everything else should be an extension of existing seams.

The second stack change is not a dependency: replace floating downloads and container tags with committed immutable identities plus checksum/digest verification. This is particularly important for the current BtbN FFmpeg `releases/latest` lookup, the unversioned MinIO `mc` URL, `minio/minio:latest`, and the tag-only Playwright image.

## Recommended Stack

### Core Framework

| Technology | Current version / contract | Purpose in v1.26 | Decision and rationale |
|---|---:|---|---|
| Elixir | Library floor `~> 1.15`; local home `1.17.3-otp-27`; CI compatibility minors 1.15–1.18 | Build, tests, evidence collectors | **Keep.** Do not widen or raise the public support floor in a maintenance milestone. Treat the nightly 1.18 cells as drift warning, not a new support promise. |
| Erlang/OTP | Local home `27.2`; supported CI floor pair OTP 26; home pair OTP 27; nightly warning includes OTP 28 | Runtime/toolchain proof | **Keep.** Preserve the supported 1.15/26 and 1.17/27 gates. Record exact resolved patch versions in receipts. |
| Phoenix | Cohort `~> 1.8.7` | Synthetic adopter host | **Keep Cohort as the twin host.** Do not create a fourth demo or move twin-only orchestration into the library. |
| Ecto SQL | Root `~> 3.11`; Cohort `~> 3.13` | Durable lifecycle and residue assertions | **Keep.** Query the existing Rindle and Oban tables for before/after evidence; do not add an event store. |
| Oban | Root and Cohort `~> 2.21`; locked root `2.21.1` | Real failure, retry, queue, and recovery behavior | **Keep.** Use manual testing mode plus persisted jobs and `Oban.drain_queue/2` for deterministic execution; use `perform_job/3` for worker-unit contracts. A supervised normal-mode subprocess is reserved for the restart/recovery scenario. |

### Database and External Services

| Technology | Current version / seam | Purpose | Decision and integration point |
|---|---|---|---|
| PostgreSQL | CI service `postgres:16-alpine`; Cohort-owned Repo | Domain, Oban, retry, and cleanup truth | **Keep.** Pin service/container references by digest while retaining a human-readable version tag where supported. Receipts should include schema prefix, counts by lifecycle state, Oban attempt/state, and zero-residue checks—not raw database dumps. |
| MinIO | Current CI composite runs `minio/minio` without a tag; demo compose uses `minio/minio:latest` | Hermetic S3-compatible failure/recovery | **Keep, but pin by digest.** Put one committed image reference in `.github/actions/setup-minio/action.yml` and reuse the same value in Cohort compose/templates. |
| MinIO Client (`mc`) | Floating `https://dl.min.io/.../mc` | Bucket setup and cleanup | **Keep, but pin a timestamped release asset and verify its official `.sha256sum`** before installation. No package-manager wrapper is needed. |
| FFmpeg/FFprobe | Runtime contract `>= 6`; CI currently resolves the highest stable BtbN asset from a floating latest release | AV failure/recovery and security-invariant proof | **Keep, but pin an immutable retained monthly BtbN release tuple** (`tag`, exact stable GPL asset name, SHA-256 from `checksums.sha256`). Preserve the `>= 6` runtime assertion. Do not bundle FFmpeg into the Hex package. |
| Mux/GCS | Existing cassette/hermetic seams plus secret-gated real-provider lanes | Provider disorder and live confidence | **Keep.** The deterministic twin uses Mox/Bypass/cassettes. Live provider lanes remain corroborating nightly evidence and must not be required to call the twin deterministic. |

### Quality and Evidence Tooling

| Tool | Current exact version | Purpose | Decision and exact seam |
|---|---:|---|---|
| Credo | locked `1.7.18` | Curated maintainability/complexity inventory | **Keep.** Extend `scripts/maintainer/credo_quality.sh` only when a finding has an agreed removal trigger; do not replace it with a score dashboard. |
| Dialyxir | locked `1.4.7` | Type-contract ratchet | **Keep and repair first.** The nightly home cell remains Elixir 1.17 / OTP 27; the ignore file stays removal-only. Do not add a second type checker. |
| Doctor | locked `0.23.0` | Public documentation/spec/module coverage | **Keep.** It already gates 100/100/100 public coverage; do not use it as a comment-density target. |
| ExCoveralls | locked `0.18.5` | Exact coverage and JSON output | **Keep.** Use `cover/excoveralls.json` as evidence, but only ratchet behaviorally relevant gaps. Do not chase 100% coverage. |
| `mix_audit` | locked `2.1.5` | Hex advisory scan | **Keep.** Disposition live findings; do not add Sobelow/Semgrep merely to increase scanner count. |
| YamlElixir | locked `2.12.2` | Repository-owned YAML parsing/assertions | **Keep.** It remains useful for exact policy/topology tests, but it is not sufficient for GitHub Actions semantics. |
| actionlint | **add 1.7.12**; Linux amd64 archive SHA-256 `8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8` | Semantic validation of workflows and composite actions | Add a checksum-verifying installer/runner under `scripts/ci/`; lint `.github/workflows/*.{yml,yaml}` and local `action.yml` files. Run it in `ci-script-tests`, which already feeds `CI Summary`, and invoke the same repository script from `mix ci` so local and PR gates remain aligned. |
| Jason | locked root `1.4.5`; Cohort `~> 1.2` | Final machine-readable receipt | **Keep.** Emit one canonical JSON document and validate it before upload. No schema library is needed; a repository-owned validator should reject absent/unknown required fields and any skipped scenario. |
| Playwright | exact npm `1.57.0`; image `mcr.microsoft.com/playwright:v1.57.0-noble` | Browser-facing twin assertions | **Keep version; pin image by digest.** Continue `npm ci`. Add twin specs to the existing Cohort suite and shared runner rather than adding Cypress or a browser SaaS. |
| Mox / Bypass | locked `1.2.0` / `2.1.0` | Deterministic adapter and HTTP failures | **Keep.** Inject named failure scripts at existing adapter/HTTP boundaries: timeout, retryable status, disorder, and partial cleanup. Avoid production fault switches. |
| JUnit formatter | locked `3.4.0` | Test failure diagnostics | **Keep.** It complements, but does not replace, the lifecycle receipt. |

## Exact Integration Points

### 1. Quality census

Create one repository-owned maintainer command that orchestrates existing checks and writes a versioned JSON result. It should call existing scripts/tasks rather than parse their prose where a JSON or exit-status seam exists:

- `mix format --check-formatted`, compile with warnings as errors, `scripts/maintainer/credo_quality.sh`, Doctor, SAFE/refactor contracts, Dialyzer on the supported home pair, ExCoveralls JSON, docs/link/proof checks, package dry-run, repository hygiene, and generated-artifact drift checks.
- Record command, exit status, immutable source SHA, exact toolchain, and artifact hashes. Each candidate is `fix`, `retain`, or `defer`, with an evidence reference and owner/removal trigger for retained/deferred debt.
- Keep the census finite and current-head-specific. Do not introduce Code Climate, Sonar, Codecov policy, a maintainability index, or a comment-density score.

### 2. Structural GitHub Actions validation

Add actionlint to the existing pure-script `ci-script-tests` job, not to every BEAM matrix cell. Run the same script from `mix ci`. Keep targeted `YamlElixir`/shell tests for repository-specific invariants such as `CI Summary.needs`, release coupling, skipped-result policy, exact SHA pins, and required timeouts. actionlint complements those contracts; it does not replace them.

### 3. Digital-twin fault injection

Use the existing Cohort application and built-package environment:

- Pack/unpack Rindle first, point Cohort at that artifact, and prohibit a repository path dependency in the acceptance lane.
- Use `Oban.Testing` manual mode and `Oban.drain_queue/2` for persisted retry/attempt/state assertions. Use `perform_job/3` only where the scenario is explicitly a worker-unit proof.
- Use Mox for Rindle behaviours and Bypass/cassettes for HTTP/provider disorder. Failure scripts belong in test support, keyed by a deterministic scenario ID; never add runtime `if fault_injection?` branches to `lib/`.
- Run restart/parent-death recovery in an isolated OS process or compose service using normal supervised Oban, because manual testing mode intentionally suppresses background execution.
- Assert visible failure, bounded retry, recovery, idempotent rerun, cleanup, and zero leaked storage/provider/database residue.

### 4. Machine-readable receipts

Emit a final `application/json` receipt with at least:

```text
schema_version, source_sha, package_sha256, started_at, completed_at,
toolchain, external_inputs, scenarios[], cleanup, overall_status
```

Each scenario should contain stable ID, initial state, injected fault, expected transitions, observed transitions, Oban attempts/states, storage keys represented by redacted/hash-safe identifiers, cleanup result, duration, and `pass|fail`. `skip` must be invalid for a required scenario. Write to a temporary path and rename after validation so interruption cannot leave an apparently complete receipt. If stepwise crash forensics are valuable, JSONL may be an intermediate append log, but the acceptance artifact remains one validated JSON document.

Upload the receipt with the already pinned `actions/upload-artifact` action under `if: always()`, a bounded retention period, and `if-no-files-found: error`. Include the upload action's returned artifact SHA-256 digest in the job summary. A summary is presentation; the JSON artifact is authority.

### 5. Reproducible inputs and supported toolchains

- Keep full-length SHA pins for every action; current workflows already do this well. Dependabot remains the update mechanism.
- Pin Docker/Playwright/MinIO images by digest. Tags alone are not immutable.
- Pin downloaded binaries by exact release asset and verified SHA-256. Never execute a remote installer script.
- Preserve `.tool-versions` as the exact local home (`Elixir 1.17.3-otp-27`, OTP `27.2`, Node `20.18.1`). In CI, minor selectors may continue to resolve current patches for compatibility coverage, but the receipt must capture `erlef/setup-beam`'s resolved `otp-version`, `elixir-version`, and `setup-beam-version` outputs.
- Do not claim the nightly 1.18/OTP 28 warning cell as supported unless documentation, package-consumer proof, and release gates intentionally adopt it.
- Add realistic `timeout-minutes` to every required or nightly job and tighter step-level timeouts around downloads/provider calls. GitHub's default job timeout is 360 minutes, which is not a useful failure bound for this repository.

## Alternatives Considered

| Category | Recommended | Alternative | Why not |
|---|---|---|---|
| Workflow validation | actionlint 1.7.12 binary, checksum-verified | `yamllint`, another YAML parser | Generic YAML syntax cannot validate Actions expressions, contexts, `needs`, matrices, permissions, or action inputs. |
| Fault injection | Oban.Testing + Mox + Bypass + isolated real-mode process | Chaos engineering framework / bespoke runtime switches | Adds machinery and production risk without improving these bounded lifecycle scenarios. |
| Receipt format | Jason-generated, repository-validated JSON | Protobuf, Avro, external JSON Schema library | No cross-language streaming protocol is being published; a small versioned internal schema is clearer and dependency-free. |
| Quality aggregation | Repository-owned command over existing gates | SonarQube, Code Climate, blanket static-analysis suite | Duplicates proven gates, introduces external policy/cost, and encourages metric theater. |
| Twin host | Existing Cohort generated-package consumer | New demo/application | A new host would duplicate setup while proving less about the maintained adopter path. |
| Browser proof | Existing Playwright 1.57.0 | Cypress or SaaS visual regression | Duplicate runtime and maintenance burden; existing deterministic specs already cover the required boundary. |
| Supply-chain pinning | Release SHA/checksum and image digest | Floating `latest` plus version check after download | A post-download version check detects incompatibility, not substitution or run-to-run drift. |
| Dependency security | Existing Dependabot + `mix_audit`; optionally enable GitHub dependency review if repository support is confirmed | Add Semgrep/Sobelow as mandatory gates | New scanners are not justified by a concrete uncovered sink; dependency review is useful only if its GitHub feature prerequisites are available. |

## Installation

No Mix or npm dependency installation is recommended.

The only added tool is an exact actionlint release downloaded by a repository script:

```bash
ACTIONLINT_VERSION=1.7.12
ACTIONLINT_ASSET=actionlint_1.7.12_linux_amd64.tar.gz
ACTIONLINT_SHA256=8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8
```

The implementation must download from the matching `rhysd/actionlint` release URL, verify SHA-256 before extraction, cache only under an ignored tool directory, and run the checked binary. macOS local support should map architecture to the corresponding official asset/checksum or fail with an actionable message; it must not silently install an unverified substitute.

## What Not to Add or Change

- No runtime dependency, database table, public module, telemetry event, error atom, schema/migration change, or new package.
- No blanket comment generator, code formatter beyond `mix format`, AI-written-comment pass, arbitrary line-count split, or 100% coverage target.
- No second job backend, event store, queue simulator, fake Oban implementation, or production fault-injection flag.
- No new demo; Cohort is the maintained twin host, and it still does not count as the named independent Phoenix pilot required for 1.0.
- No floating tool/image input, remote `curl | sh`, or skipped-as-green required scenario.
- No CI topology rename that changes `ci.yml`, workflow `name: CI`, `CI Summary`, or release-gate coupling without a separately proven migration.
- No toolchain-floor or public compatibility expansion hidden inside quality cleanup.

## Sources

- [Rindle `mix.exs`](../../mix.exs) and [`mix.lock`](../../mix.lock) — exact repository dependencies and versions (HIGH)
- [Rindle CI workflow](../../.github/workflows/ci.yml), [Nightly workflow](../../.github/workflows/nightly.yml), [BEAM setup composite](../../.github/actions/setup-elixir/action.yml), and [MinIO setup composite](../../.github/actions/setup-minio/action.yml) — existing integration seams (HIGH)
- [Oban testing introduction](https://hexdocs.pm/oban/testing.html) and [worker testing](https://hexdocs.pm/oban/testing_workers.html) — inline/manual modes and `Oban.Testing` helpers (MEDIUM; official current docs, compatible seam verified in locked 2.21.1)
- [actionlint checks](https://github.com/rhysd/actionlint/blob/v1.7.12/docs/checks.md) and [v1.7.12 release](https://github.com/rhysd/actionlint/releases/tag/v1.7.12) — semantic coverage and release checksums (MEDIUM; official project)
- [GitHub Actions secure use](https://docs.github.com/en/actions/reference/security/secure-use) — full-length commit SHA as immutable action reference (MEDIUM; official)
- [GitHub workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax) — job/step timeout semantics (MEDIUM; official)
- [GitHub workflow artifacts](https://docs.github.com/en/actions/tutorials/store-and-share-data) — retention and artifact digest behavior (MEDIUM; official)
- [erlef/setup-beam README](https://github.com/erlef/setup-beam/blob/main/README.md) — strict/loose version resolution and resolved-version outputs (MEDIUM; official project)
- [BtbN FFmpeg Builds releases](https://github.com/BtbN/FFmpeg-Builds/releases) and [retention policy](https://github.com/BtbN/FFmpeg-Builds) — immutable release assets and published checksums (MEDIUM; official project)
- [MinIO Client releases](https://github.com/minio/mc/releases) — timestamped assets, SHA-256, minisign, and GPG material (MEDIUM; official project)
- [Docker image pull by digest](https://docs.docker.com/reference/cli/docker/image/pull/#pull-an-image-by-digest) — immutable container identity (MEDIUM; official)
- [RFC 8259](https://www.rfc-editor.org/rfc/rfc8259) and [RFC 7464](https://www.rfc-editor.org/rfc/rfc7464.html) — JSON document and JSON text sequence formats (HIGH; standards)

## Open Validation Items for Implementation

- Resolve and commit the exact digest for each MinIO/Postgres/Playwright image on the target runner architecture; do not copy a platform-specific digest without verifying it.
- Select a retained monthly BtbN stable GPL release asset and commit its exact checksum; the current `latest` resolver is intentionally not authoritative.
- Confirm actionlint's repository-specific findings and explicitly configure only evidence-backed exceptions; never blanket-ignore a rule class.
- Verify every receipt scenario against the built package and fail if package provenance, cleanup proof, or any required scenario is absent.
