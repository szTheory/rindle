# Phase 09: Install & Release Confidence - Research

**Researched:** 2026-04-28
**Domain:** Phoenix package-consumer install proof, release gating, adopter onboarding docs
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
Source: `.planning/phases/09-install-release-confidence/09-CONTEXT.md` [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md]

- **D-01:** Phase 9 uses a **hybrid install-proof model**: keep the existing
  in-repo adopter fixture for deep lifecycle assertions, but add a
  truly-generated fresh Phoenix app smoke path that installs Rindle from the
  built package artifact.
- **D-02:** The generated-app smoke path is the trust signal for
  `RELEASE-01/02`; the long-lived fixture is supporting proof, not the primary
  installability guarantee.
- **D-03:** The generated-app path may reuse checked-in helper fragments or
  harness scripts for deterministic setup, but those helpers must support a
  real `mix phx.new` app shape rather than replacing it with a repo-local
  pseudo-app.
- **D-04:** Installability from the built artifact is validated in a **hybrid
  pipeline**: a slim PR CI smoke lane catches package-consumer regressions
  before merge, and the release workflow keeps the heavier tarball/release
  checks.
- **D-05:** The PR smoke lane should stay intentionally narrow: build the
  package, install it into a clean consumer app, prove the canonical flow, and
  fail loudly on packaging/setup drift. Do not turn it into a second copy of
  the full integration suite.
- **D-06:** The release workflow remains the place for deeper package-focused
  gates such as tarball inspection and `hex.publish --dry-run` posture. Shared
  helper logic is preferred so PR and release checks do not silently diverge.
- **D-07:** The package-consumer smoke path proves the **presigned PUT**
  canonical flow, not multipart. Multipart remains verified in the deeper
  MinIO-backed capability/integration proofs already established in earlier
  phases.
- **D-08:** Rindle's first-run story must optimize for least surprise: the
  first path taught in docs is the first path proven from the built artifact.
  Advanced capability-gated flows should remain clearly documented and
  explicitly verified elsewhere, not overloaded into smoke.
- **D-09:** Capability honesty still applies in docs: Phase 9 must make clear
  that multipart is supported and proven, but not the default install/onboarding
  path for a brand-new adopter.
- **D-10:** `README.md` becomes a **layered quickstart** document: package
  pitch, dependency snippet, short install path, and prominent callouts for the
  adopter-owned Repo contract, Oban expectations, and capability constraints.
- **D-11:** `guides/getting_started.md` remains the **canonical deep guide**
  with the fuller lifecycle walkthrough and operational detail. README should
  hand off to it explicitly rather than duplicating all nuance.
- **D-12:** Some duplication between README and the guide is acceptable for the
  install snippet and quickstart, but there must be one declared canonical path
  that planning can keep drift-tested.
- **D-13:** Phase 9 planning should bias toward **agent-decided defaults** for
  implementation details, tradeoffs, and document structure unless a choice
  materially affects public API/semver, security posture, irreversible
  infrastructure/cost, or product scope.
- **D-14:** When a decision does not cross that bar, prefer the option that
  strengthens least surprise, outside-in proof, and developer ergonomics rather
  than escalating it for user approval.

### Claude's Discretion
Source: `.planning/phases/09-install-release-confidence/09-CONTEXT.md` [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md]

- Exact helper-script/template organization for the generated-app smoke lane.
- Exact CI job names, artifact handoff mechanics, and caching strategy.
- Exact README section ordering and wording, as long as the layered quickstart
  structure and required constraints remain explicit.
- Exact boundary between smoke assertions and deeper adopter/integration
  assertions, as long as the smoke path stays narrow and package-consumer-first.

### Deferred Ideas (OUT OF SCOPE)
Source: `.planning/phases/09-install-release-confidence/09-CONTEXT.md` [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md]

- A full multipart package-consumer smoke lane remains out of scope for Phase 9
  unless the canonical first-run path itself changes to make multipart the
  primary onboarding flow.
- A separate external example repo remains unnecessary for this phase; the
  stronger outside-in signal is a generated fresh app consuming the built
  artifact inside CI.
- Broader changes to global GSD workflow defaults are outside this phase’s code
  scope, but the planning preference above should be treated as operative for
  Phase 9 work.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| RELEASE-01 | A fresh Phoenix adopter can install Rindle from the built package and complete the canonical upload-to-delivery path | Use `mix phx.new` to generate the host app, install Rindle from the unpacked Hex artifact as a path dependency, resolve dependency migrations via `Application.app_dir/2` plus Ecto multi-path migration support, and run a narrow public-API smoke test for the presigned PUT flow. [VERIFIED: .planning/REQUIREMENTS.md] [CITED: https://hexdocs.pm/phoenix/Mix.Tasks.Phx.New.html] [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html] [CITED: https://hexdocs.pm/elixir/main/Application.html] [CITED: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html] [VERIFIED: mix phx.new /tmp/rindle-phase9-HMRDua/app --no-assets --no-dashboard --no-mailer --no-gettext --install (2026-04-28)] [VERIFIED: fresh consumer `mix deps.get && mix compile` with `{:rindle, path: \"/Users/jon/projects/rindle/rindle-0.1.0-dev\"}` (2026-04-28)] |
| RELEASE-02 | CI includes a package-consumer smoke path that validates installability from the built artifact rather than only from the repo source | Add a slim PR job that builds and unpacks the package, generates a Phoenix app, wires only the minimum adopter-owned runtime pieces, and runs the canonical smoke test. Keep existing tarball inspection and dry-run publish posture in the release workflow. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .github/workflows/ci.yml] [VERIFIED: .github/workflows/release.yml] [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md] |
| RELEASE-03 | README and getting-started guidance match the canonical adopter path, including Repo ownership and upload capability constraints | Make `README.md` the layered quickstart and keep `guides/getting_started.md` as the canonical deep guide, with both pointing to the same presigned PUT first-run path and explicit callouts for adopter-owned Repo, default Oban ownership, and multipart as advanced. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: README.md] [VERIFIED: guides/getting_started.md] [VERIFIED: guides/background_processing.md] [VERIFIED: guides/storage_capabilities.md] [CITED: https://hexdocs.pm/ex_doc/ExDoc.html] |
</phase_requirements>

## Summary

Phase 9 should be planned as an outside-in proof phase, not a new feature phase. The repo already has deep behavioral proof in the long-lived adopter fixture, existing MinIO-backed integration coverage, and a release workflow that builds and inspects the Hex artifact; what is missing is a true consumer-shaped install path generated from `mix phx.new` and fed from the built package artifact instead of the repo checkout. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] [VERIFIED: .github/workflows/release.yml] [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md]

The main technical gap is not dependency fetching. A fresh Phoenix app generated locally on 2026-04-28 successfully compiled against the unpacked `rindle-0.1.0-dev` artifact as a path dependency after adding `oban`, `hackney`, and `rindle`, which proves the built artifact is structurally consumable. The higher-risk gap is installation ergonomics: the current docs tell adopters to run `mix ecto.migrate`, but official Ecto tooling only migrates the current app’s migration directory by default, while Rindle’s package ships its own migrations under `priv/repo/migrations`. Phase 9 therefore needs a deliberate migration-install story in both the smoke harness and the public quickstart. [VERIFIED: fresh consumer `mix deps.get && mix compile` with unpacked artifact (2026-04-28)] [VERIFIED: guides/getting_started.md] [VERIFIED: mix.exs] [VERIFIED: rindle-0.1.0-dev/priv/repo/migrations/*] [CITED: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html] [CITED: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrations.html]

The strongest planner-level recommendation is to keep the smoke lane narrow and API-level. Generate a fresh Phoenix app, install Rindle from the unpacked artifact, wire adopter-owned Repo plus default Oban plus S3 config, run both host-app and Rindle migrations through explicit paths, and exercise the canonical presigned PUT lifecycle via public APIs and a real HTTP PUT to the presigned URL. That aligns with the locked first-path-first decision, with Phoenix’s own direct-to-S3-compatible upload guidance, and with the existing canonical adopter proof style already in the repo. [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md] [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] [CITED: https://hexdocs.pm/phoenix_live_view/external-uploads.html] [CITED: https://hexdocs.pm/phoenix/Mix.Tasks.Phx.New.html]

**Primary recommendation:** plan Phase 9 around one shared consumer-smoke helper that both PR CI and release workflow reuse, with migration-path resolution based on `Application.app_dir(:rindle, "priv/repo/migrations")` so the same logic works for an unpacked path dependency and for a fetched package under normal adopter installs. [CITED: https://hexdocs.pm/elixir/main/Application.html] [CITED: https://hexdocs.pm/ecto_sql/Ecto.Migrator.html] [VERIFIED: `mix run -e 'IO.puts(Application.app_dir(:rindle, \"priv/repo/migrations\"))'` in fresh consumer app (2026-04-28)]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Built artifact packaging and unpack inspection | API / Backend | CDN / Static | `mix hex.build --unpack` and package file selection are build-time concerns owned by the library project, not by the adopter runtime. [VERIFIED: mix.exs] [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html] |
| Fresh consumer app generation | Frontend Server (SSR) | API / Backend | The install proof must target a real Phoenix host-app shape generated by `mix phx.new`, because the consumer runtime contract lives inside the adopter application, not inside a repo-local test harness. [CITED: https://hexdocs.pm/phoenix/Mix.Tasks.Phx.New.html] [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md] |
| Repo ownership and migration application | Database / Storage | API / Backend | The adopter-owned Repo and the migration paths determine whether any runtime flow can persist state; the smoke harness must prove both host and library schema installation. [VERIFIED: guides/getting_started.md] [VERIFIED: guides/background_processing.md] [VERIFIED: rindle-0.1.0-dev/priv/repo/migrations/*] [CITED: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html] |
| Canonical upload-to-delivery smoke path | API / Backend | Database / Storage | `Rindle.Upload.Broker`, `Rindle.Delivery`, and the default `Oban` path own the first-run lifecycle proof; storage and DB back them, but the public API boundary is what the adopter consumes. [VERIFIED: lib/rindle.ex] [VERIFIED: lib/rindle/upload/broker.ex] [VERIFIED: guides/background_processing.md] |
| Layered onboarding docs | CDN / Static | API / Backend | README and HexDocs are static surfaces, but they must mirror the same runtime path the smoke test exercises. [VERIFIED: README.md] [VERIFIED: guides/getting_started.md] [CITED: https://hexdocs.pm/ex_doc/ExDoc.html] |

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Phoenix installer | 1.8.5 | Generate the fresh adopter app with the canonical Phoenix host shape. [VERIFIED: `mix phx.new --version` (2026-04-28)] | Official Phoenix generator output is the least-assumption starting point for a “fresh adopter” proof. [CITED: https://hexdocs.pm/phoenix/Mix.Tasks.Phx.New.html] |
| Hex build tooling | 2.2.1 | Build and unpack the package artifact that the consumer app installs from. [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html] | `--unpack` is the official inspection path for checking that the tarball contains what a consumer actually receives. [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html] |
| Ecto SQL migrator/tasks | 3.13.4 / 3.13.5 | Apply host-app migrations plus library migrations from explicit paths. [CITED: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html] [CITED: https://hexdocs.pm/ecto_sql/Ecto.Migrator.html] | Official Ecto migration tooling already supports explicit migration directories and multiple paths; Phase 9 should reuse that instead of inventing a migration engine. [CITED: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrations.html] |
| Oban | 2.22.0 | Provide the adopter-owned default job backend that Rindle requires for promote, variant, purge, and maintenance flows. [VERIFIED: `mix hex.info oban` (2026-04-28)] [VERIFIED: guides/background_processing.md] | The canonical lifecycle depends on transactional enqueueing through the default `Oban` path. [VERIFIED: guides/background_processing.md] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| ExDoc | 0.40.1 | Keep README plus deeper guides layered through `extras` and `groups_for_extras`. [VERIFIED: `mix hex.info ex_doc` (2026-04-28)] [CITED: https://hexdocs.pm/ex_doc/ExDoc.html] | Use for README/guide structure changes and HexDocs navigation coherence. [CITED: https://hexdocs.pm/ex_doc/ExDoc.html] |
| Erlang `:httpc` / `:inets` | OTP 28 runtime | Perform the real presigned PUT in smoke without adding browser automation or extra dependencies. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] [VERIFIED: Erlang/OTP 28 from `mix --version` (2026-04-28)] | Use inside the generated-app smoke test for the actual upload byte PUT. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] |
| `Application.app_dir/2` | Elixir 1.19.5 runtime feature | Resolve the installed library’s migration directory without assuming `deps/rindle` exists. [CITED: https://hexdocs.pm/elixir/main/Application.html] [VERIFIED: fresh consumer `Application.app_dir(:rindle, \"priv/repo/migrations\")` output (2026-04-28)] | Use in smoke helpers or migration runner code that must work for both path deps and fetched deps. [CITED: https://hexdocs.pm/elixir/main/Application.html] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Generated Phoenix app smoke | Existing in-repo adopter fixture only | Reusing only the long-lived fixture misses the core trust gap because it never proves `mix phx.new` plus package-consumer setup from the artifact. [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md] |
| Explicit multi-path migrations | Copying Rindle migrations manually into the consumer app | Copying works, but it adds more mutable setup and more drift surface than official multi-path migration support. [CITED: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrations.html] |
| API-level smoke with real PUT | Browser/UI-driven smoke | Browser automation is broader than the locked narrow lane and does not increase confidence proportionally for this phase. [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md] [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] |

**Installation / verification commands:** [CITED: https://hexdocs.pm/phoenix/Mix.Tasks.Phx.New.html] [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html]

```bash
mix hex.build --unpack
mix phx.new /tmp/rindle_smoke --no-assets --no-dashboard --no-mailer --no-gettext --install
cd /tmp/rindle_smoke
mix deps.get
mix compile
```

**Version verification:** [VERIFIED: `mix hex.info phoenix` (2026-04-28)] [VERIFIED: `mix hex.info oban` (2026-04-28)] [VERIFIED: `mix hex.info ex_doc` (2026-04-28)]

- Phoenix latest release observed: `1.8.5`. [VERIFIED: `mix hex.info phoenix` (2026-04-28)]
- Oban latest release observed: `2.22.0`. [VERIFIED: `mix hex.info oban` (2026-04-28)]
- ExDoc latest release observed: `0.40.1`. [VERIFIED: `mix hex.info ex_doc` (2026-04-28)]

## Architecture Patterns

### System Architecture Diagram

```text
Repo checkout
  -> mix hex.build --unpack
    -> unpacked rindle artifact
      -> generate fresh Phoenix app with mix phx.new
        -> inject Rindle dependency from artifact
          -> configure adopter-owned Repo + default Oban + storage env
            -> resolve host migrations path + Rindle migrations path
              -> migrate database
                -> run generated-app smoke test
                  -> initiate session
                    -> sign presigned PUT URL
                      -> real HTTP PUT to storage
                        -> verify completion
                          -> promote + variant jobs via Oban
                            -> signed delivery URL
                              -> pass/fail PR smoke lane

Release workflow
  -> reuses shared consumer-smoke helper
  -> keeps tarball presence/absence checks
  -> keeps hex.publish --dry-run posture

README quickstart
  -> points to same canonical presigned PUT path
    -> guides/getting_started.md deep guide
      -> storage/background guides for advanced constraints
```

### Recommended Project Structure

```text
test/install_smoke/
├── templates/         # generated-app patches or file fragments reused by CI/release
├── helpers/           # migration-path resolution, config injection, smoke assertions
└── generated_app/     # optional transient workspace created at runtime, not committed

.github/workflows/
├── ci.yml             # slim package-consumer smoke job
└── release.yml        # tarball inspection + shared heavier release checks

guides/
├── getting_started.md # canonical deep path
└── storage_capabilities.md
```

### Pattern 1: Generated-App Consumer Smoke

**What:** Build the package, generate a clean Phoenix app, install Rindle from the unpacked artifact, then exercise the canonical public API path in that host app. [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md] [CITED: https://hexdocs.pm/phoenix/Mix.Tasks.Phx.New.html] [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html]

**When to use:** Use in PR CI and release workflow whenever the phase is proving installability or onboarding from the built artifact. [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md]

**Example:**

```elixir
# Source: repo experiment + official Phoenix/Hex docs
defp deps do
  [
    {:oban, "~> 2.22"},
    {:hackney, "~> 1.20"},
    {:rindle, path: "/abs/path/to/rindle-0.1.0-dev"}
  ]
end
```

This path-dependency shape compiled successfully in a fresh Phoenix app on 2026-04-28. [VERIFIED: fresh consumer `mix deps.get && mix compile` with unpacked artifact (2026-04-28)]

### Pattern 2: Resolve Library Migrations from the Installed App Path

**What:** Resolve Rindle’s migration directory from the installed application path and feed it into official Ecto migration tooling beside the host app’s own migrations. [CITED: https://hexdocs.pm/elixir/main/Application.html] [CITED: https://hexdocs.pm/ecto_sql/Ecto.Migrator.html]

**When to use:** Use whenever the smoke harness or helper task needs to migrate both the consumer app and the installed Rindle package without assuming a `deps/rindle` directory exists. [VERIFIED: `mix deps` in fresh consumer shows path deps do not materialize under `deps/rindle` (2026-04-28)] [VERIFIED: fresh consumer `Application.app_dir(:rindle, \"priv/repo/migrations\")` output (2026-04-28)]

**Example:**

```elixir
# Source: official Elixir + Ecto docs
rindle_migrations = Application.app_dir(:rindle, "priv/repo/migrations")

Ecto.Migrator.with_repo(App.Repo, fn repo ->
  Ecto.Migrator.run(repo, ["priv/repo/migrations", rindle_migrations], :up, all: true)
end)
```

### Pattern 3: Layered Quickstart + Canonical Deep Guide

**What:** Keep `README.md` short and executable, then hand off to `guides/getting_started.md` for the full lifecycle. [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md] [VERIFIED: README.md] [VERIFIED: guides/getting_started.md] [CITED: https://hexdocs.pm/ex_doc/ExDoc.html]

**When to use:** Use for every top-level docs change in Phase 9 so the quickstart remains the first proven path and advanced capability nuance stays in the guides. [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md]

**Example:**

```elixir
# Source: official ExDoc docs
docs: [
  main: "Rindle",
  extras: ["README.md", "guides/getting_started.md"],
  groups_for_extras: [Guides: ~r/guides\/.*/]
]
```

### Anti-Patterns to Avoid

- **Repo-local proof masquerading as install proof:** The existing adopter fixture is valuable, but it is not the primary installability guarantee for this phase. [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md]
- **Hardcoding `deps/rindle` in the generated-app smoke:** That breaks for path dependencies from the unpacked artifact. [VERIFIED: fresh consumer `mix deps` plus missing `deps/rindle` for path dep (2026-04-28)]
- **Teaching multipart first in README:** Locked scope says presigned PUT is the canonical first-run story and multipart stays advanced. [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md]
- **Turning PR smoke into a second integration suite:** The narrow smoke lane should fail on packaging/setup drift, not re-prove every advanced capability. [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Fresh adopter app scaffold | A fake repo-local consumer skeleton | `mix phx.new` generated app | The phase explicitly needs a real Phoenix host shape. [CITED: https://hexdocs.pm/phoenix/Mix.Tasks.Phx.New.html] [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md] |
| Package artifact inspection | Custom tar extraction logic | `mix hex.build --unpack` | Hex already provides the official build-and-unpack flow. [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html] |
| Migration runner | A bespoke schema installer | Official `mix ecto.migrate --migrations-path` or `Ecto.Migrator.run/4` | Ecto already supports explicit and multiple migration directories. [CITED: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html] [CITED: https://hexdocs.pm/ecto_sql/Ecto.Migrator.html] |
| Upload smoke transport | Browser automation for the canonical PUT | OTP `:httpc` or equivalent direct HTTP PUT | The repo already proves the critical network hop with real PUTs and no browser layer. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] |
| Docs sidebar structure | Ad hoc README-only prose growth | ExDoc `extras` + `groups_for_extras` | ExDoc already supports the layered quickstart/deep-guide structure the phase wants. [CITED: https://hexdocs.pm/ex_doc/ExDoc.html] |

**Key insight:** the deceptive complexity in Phase 9 is installation choreography, not media logic. The public APIs and storage flows already exist; the hard part is proving that a consumer app can discover and wire every required runtime piece without repo-local tribal knowledge. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: guides/getting_started.md] [VERIFIED: guides/background_processing.md]

## Common Pitfalls

### Pitfall 1: Treating compilation as installation proof

**What goes wrong:** The generated app compiles against the unpacked artifact, but the runtime path still fails because repo config, Oban, migrations, or storage wiring is incomplete. [VERIFIED: fresh consumer compile experiment (2026-04-28)] [VERIFIED: guides/background_processing.md]

**Why it happens:** Mix path dependencies prove code loadability, not full adopter runtime readiness. [CITED: https://hexdocs.pm/mix/Mix.Tasks.Deps.html]

**How to avoid:** Require the smoke lane to migrate, initiate, sign, upload, verify, and request delivery, not just compile. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs]

**Warning signs:** A plan slice that ends at `mix compile` or `mix deps.get` for `RELEASE-01`. [VERIFIED: .planning/REQUIREMENTS.md]

### Pitfall 2: Assuming `mix ecto.migrate` will discover Rindle’s migrations automatically

**What goes wrong:** The host app migrates only its own `priv/repo/migrations`, leaving Rindle tables absent. [VERIFIED: guides/getting_started.md] [VERIFIED: rindle-0.1.0-dev/priv/repo/migrations/*] [CITED: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html]

**Why it happens:** Official Ecto defaults to the current app’s repo migration directory unless another path is configured or passed. [CITED: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html]

**How to avoid:** Resolve the installed Rindle migration path explicitly and run Ecto with both paths. [CITED: https://hexdocs.pm/elixir/main/Application.html] [CITED: https://hexdocs.pm/ecto_sql/Ecto.Migrator.html]

**Warning signs:** Docs that say only “run `mix ecto.migrate`” without any Rindle-specific migration path or helper. [VERIFIED: guides/getting_started.md]

### Pitfall 3: Hardcoding `deps/rindle` in smoke helpers

**What goes wrong:** The smoke harness works for fetched Hex deps but breaks for the unpacked-artifact path dependency used to prove the built package locally. [VERIFIED: fresh consumer `mix deps` plus missing `deps/rindle` for path dep (2026-04-28)]

**Why it happens:** Mix path dependencies are resolved directly from the provided path rather than materialized under `deps/`. [VERIFIED: fresh consumer `mix deps` plus filesystem inspection (2026-04-28)] [CITED: https://hexdocs.pm/mix/Mix.Tasks.Deps.html]

**How to avoid:** Resolve the installed app directory with `Application.app_dir/2` instead of assuming a filesystem layout. [CITED: https://hexdocs.pm/elixir/main/Application.html]

**Warning signs:** Scripts that interpolate `deps/rindle/priv/repo/migrations` literally in the generated-app smoke lane. [VERIFIED: fresh consumer filesystem inspection (2026-04-28)]

### Pitfall 4: Letting README over-promise advanced capability parity

**What goes wrong:** The top-level quickstart implies multipart or broader provider parity is part of the default first-run story. [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md] [VERIFIED: guides/storage_capabilities.md]

**Why it happens:** Teams try to make the README exhaustive instead of layered. [VERIFIED: README.md] [VERIFIED: guides/getting_started.md]

**How to avoid:** Keep presigned PUT first in README, then link to getting-started and storage-capability guides for multipart and provider nuance. [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md] [VERIFIED: guides/storage_capabilities.md]

**Warning signs:** README examples that mention multipart before the base presigned PUT path. [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md]

## Code Examples

Verified patterns from official sources and repo evidence:

### Generate the fresh adopter app

```bash
# Source: https://hexdocs.pm/phoenix/Mix.Tasks.Phx.New.html
mix phx.new /tmp/rindle_smoke --no-assets --no-dashboard --no-mailer --no-gettext --install
```

### Build and unpack the install artifact

```bash
# Source: https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html
mix hex.build --unpack
```

### Run migrations from host-app and library paths

```elixir
# Source: https://hexdocs.pm/elixir/main/Application.html
# Source: https://hexdocs.pm/ecto_sql/Ecto.Migrator.html
rindle_migrations = Application.app_dir(:rindle, "priv/repo/migrations")

Ecto.Migrator.with_repo(App.Repo, fn repo ->
  Ecto.Migrator.run(repo, ["priv/repo/migrations", rindle_migrations], :up, all: true)
end)
```

### Direct-to-S3-compatible first-run posture

```elixir
# Source: https://hexdocs.pm/phoenix_live_view/external-uploads.html
{:ok, url} =
  ExAws.S3.presigned_url(config, :put, bucket, key,
    expires_in: 3600,
    query_params: [{"Content-Type", entry.client_type}]
  )
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Repo-local CI and tarball inspection imply installability | Generate a real Phoenix consumer app and install from the built artifact in CI | Phoenix/Hex/Ecto toolchain currently supports this shape; Rindle locked it in Phase 9 context on 2026-04-28. [CITED: https://hexdocs.pm/phoenix/Mix.Tasks.Phx.New.html] [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html] [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md] | Confidence moves from inferred packaging correctness to proven adopter success. [VERIFIED: .planning/ROADMAP.md] |
| Thin README with most onboarding in guides | Layered quickstart in README plus canonical deep guide | Locked by Phase 9 context on 2026-04-28. [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md] | The first path users read becomes the same path CI proves. [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md] |
| Multipart and provider nuance can leak into first-run discussion | Presigned PUT stays first-run; multipart remains advanced and separately proven | Locked by Phase 9 context and reinforced by current Phoenix S3-compatible direct-upload docs. [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md] [CITED: https://hexdocs.pm/phoenix_live_view/external-uploads.html] | Docs and smoke stay narrow while still honest about capability boundaries. [VERIFIED: guides/storage_capabilities.md] |

**Deprecated/outdated:**

- Relying on `mix ecto.migrate` alone for the quickstart is outdated for this phase because it omits the library-migration installation step Rindle needs. [VERIFIED: guides/getting_started.md] [CITED: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html]
- Treating the in-repo adopter fixture as the primary install proof is outdated for this phase because the locked trust signal is the generated-app consumer smoke path. [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md]

## Assumptions Log

All material claims in this research were verified against the repo, local tool output, or official documentation in this session. No user confirmation is required for core planning decisions. [VERIFIED: this file’s source tags]

## Open Questions

1. **Should Phase 9 ship a public Rindle install helper for migrations, or only document a host-app helper?**
   - What we know: official Ecto tooling already supports the needed multi-path migration behavior, and `Application.app_dir/2` resolves the installed Rindle migration path correctly in a fresh consumer app. [CITED: https://hexdocs.pm/ecto_sql/Ecto.Migrator.html] [CITED: https://hexdocs.pm/elixir/main/Application.html] [VERIFIED: fresh consumer `Application.app_dir(:rindle, \"priv/repo/migrations\")` output (2026-04-28)]
   - What's unclear: whether the project wants a new public `mix rindle.*` installation task or prefers to avoid expanding the public operational surface in this phase. [VERIFIED: current `lib/mix/tasks/` contains ops tasks but no install task]
   - Recommendation: plan the smoke harness around a checked-in helper first, and only promote it to a public Mix task if the README would otherwise need brittle host-app boilerplate. [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir / Mix | Package build, generated-app compile, smoke execution | ✓ | Elixir 1.19.5 / Mix 1.19.5 [VERIFIED: `mix --version` (2026-04-28)] | — |
| Phoenix installer archive | Fresh consumer app generation | ✓ | 1.8.5 [VERIFIED: `mix phx.new --version` (2026-04-28)] | Install with `mix archive.install hex phx_new` if missing. [CITED: https://hexdocs.pm/phoenix/Mix.Tasks.Phx.New.html] |
| Docker | MinIO-backed smoke environment | ✓ | 29.4.0 [VERIFIED: `docker --version` (2026-04-28)] | Use GitHub Actions service/container setup as current CI already does. [VERIFIED: .github/workflows/ci.yml] |
| PostgreSQL CLI | Local DB setup/debug | ✓ | 14.17 [VERIFIED: `psql --version` (2026-04-28)] | CI service container can still provide DB even if local CLI is absent. [VERIFIED: .github/workflows/ci.yml] |
| `curl` | MinIO readiness/bootstrap and optional smoke diagnostics | ✓ | 8.7.1 [VERIFIED: `curl --version | head -1` (2026-04-28)] | OTP `:httpc` covers the actual upload smoke. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] |
| `mc` (MinIO client) | Bucket bootstrap in CI | ✗ | — [VERIFIED: `command -v mc` missing on 2026-04-28] | Current CI already installs `mc` in-line before bucket creation. [VERIFIED: .github/workflows/ci.yml] |
| `vips` CLI / libvips | Variant processing in canonical lifecycle | ✗ locally via CLI | no `vips` CLI found [VERIFIED: `command -v vips` missing on 2026-04-28] | CI already installs `libvips-dev`; local smoke can document it as a prerequisite. [VERIFIED: .github/workflows/ci.yml] [VERIFIED: guides/getting_started.md] |

**Missing dependencies with no fallback:**

- None for planning. The CI workflow already documents how to install the two missing phase-relevant tools (`mc`, `libvips-dev`) in automation. [VERIFIED: .github/workflows/ci.yml]

**Missing dependencies with fallback:**

- `mc` missing locally; install ad hoc in CI as current workflow does. [VERIFIED: .github/workflows/ci.yml]
- `vips` CLI missing locally; rely on documented system dependency installation and CI apt install. [VERIFIED: guides/getting_started.md] [VERIFIED: .github/workflows/ci.yml]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit via Mix test runner. [VERIFIED: test/ directory] [VERIFIED: mix.exs] |
| Config file | none; conventions live in `mix.exs`, `test/test_helper.exs`, and workflow commands. [VERIFIED: mix.exs] [VERIFIED: test/test_helper.exs] |
| Quick run command | `mix test test/adopter/canonical_app/lifecycle_test.exs --include minio` today; Phase 9 should add a new targeted generated-app smoke command. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] [VERIFIED: .github/workflows/ci.yml] |
| Full suite command | `mix test` locally; CI fans out by lane in `.github/workflows/ci.yml`. [VERIFIED: mix.exs] [VERIFIED: .github/workflows/ci.yml] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| RELEASE-01 | Fresh Phoenix app installs Rindle from built artifact and completes canonical presigned PUT lifecycle | integration / smoke | `mix test test/install_smoke/generated_app_smoke_test.exs --include minio` | ❌ Wave 0 |
| RELEASE-02 | PR CI validates package-consumer installability from the built artifact | CI smoke | GitHub Actions job that runs build + generate-app + smoke helper | ❌ Wave 0 |
| RELEASE-03 | README and getting-started docs match the proven path | docs drift / contract | `mix test test/install_smoke/docs_parity_test.exs` or equivalent narrow parity check | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** targeted generated-app smoke command once it exists. [VERIFIED: Phase 9 needs a narrow smoke lane per locked context]
- **Per wave merge:** generated-app smoke plus existing adopter test. [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md] [VERIFIED: .github/workflows/ci.yml]
- **Phase gate:** PR CI smoke, release workflow shared helper, and docs parity must all be green before verification. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/ROADMAP.md]

### Wave 0 Gaps

- [ ] `test/install_smoke/generated_app_smoke_test.exs` — proves RELEASE-01 from the built artifact.
- [ ] `test/install_smoke/support/*` — helper(s) for generated app patching, migration-path resolution, and presigned PUT smoke setup.
- [ ] `.github/workflows/ci.yml` job addition — proves RELEASE-02 on PRs from the built artifact.
- [ ] `.github/workflows/release.yml` helper reuse — keeps PR and release checks from silently diverging.
- [ ] README / guide drift check — locks RELEASE-03 to the same first-run path the smoke test executes.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | This phase does not introduce user-auth flows; keep focus on install proof. [VERIFIED: .planning/ROADMAP.md] |
| V3 Session Management | no | No browser/auth session design changes are in scope. [VERIFIED: .planning/ROADMAP.md] |
| V4 Access Control | yes | Preserve signed/private delivery defaults and do not make quickstart docs imply public or downgraded delivery. [VERIFIED: .planning/PROJECT.md] [VERIFIED: guides/secure_delivery.md] |
| V5 Input Validation | yes | Canonical flow still depends on Rindle’s existing magic-byte and MIME validation invariants after verification. [VERIFIED: .planning/PROJECT.md] [VERIFIED: lib/rindle.ex] [VERIFIED: lib/rindle/upload/broker.ex] |
| V6 Cryptography | yes | Use storage-provider signed URLs and never hand-roll signing in the smoke harness or docs. [CITED: https://hexdocs.pm/phoenix_live_view/external-uploads.html] [VERIFIED: lib/rindle/storage/s3.ex] |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Docs teaching an unverified or downgraded upload path | Tampering | Make README and guide parity a testable contract tied to the smoke path. [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md] |
| Install smoke bypassing actual signed PUT | Tampering | Require a real HTTP PUT to the presigned URL, as the current adopter proof already does. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] |
| Missing Oban/runtime ownership setup causing silent post-verify failure | Repudiation / Availability | Quickstart and smoke must configure adopter-owned default Oban plus Repo explicitly. [VERIFIED: guides/background_processing.md] [VERIFIED: guides/getting_started.md] |
| Missing library migrations causing runtime table errors | Denial of Service | Use explicit multi-path migration execution before smoke runs. [CITED: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html] [CITED: https://hexdocs.pm/ecto_sql/Ecto.Migrator.html] |

## Sources

### Primary (HIGH confidence)

- `https://hexdocs.pm/phoenix/Mix.Tasks.Phx.New.html` - current Phoenix installer shape and options.
- `https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html` - current Hex build/unpack workflow.
- `https://hexdocs.pm/mix/Mix.Tasks.Deps.html` - official Mix dependency forms, including path dependencies.
- `https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html` - official migration-path defaults and override behavior.
- `https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrations.html` - multiple `--migrations-path` support.
- `https://hexdocs.pm/ecto_sql/Ecto.Migrator.html` - programmatic multi-path migration runner.
- `https://hexdocs.pm/elixir/main/Application.html` - `Application.app_dir/2`.
- `https://hexdocs.pm/ex_doc/ExDoc.html` - `extras` and `groups_for_extras`.
- `https://hexdocs.pm/phoenix_live_view/external-uploads.html` - direct-to-S3-compatible signed PUT guidance.
- Local repo artifacts: `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/PROJECT.md`, `.planning/STATE.md`, `.planning/phases/09-install-release-confidence/09-CONTEXT.md`, `README.md`, `guides/getting_started.md`, `guides/background_processing.md`, `guides/storage_capabilities.md`, `.github/workflows/ci.yml`, `.github/workflows/release.yml`, `mix.exs`, `test/adopter/canonical_app/lifecycle_test.exs`.
- Local verification runs on 2026-04-28: `mix hex.info phoenix`, `mix hex.info oban`, `mix hex.info ex_doc`, `mix phx.new --version`, fresh consumer `mix deps.get && mix compile`, fresh consumer `Application.app_dir(:rindle, "priv/repo/migrations")`.

### Secondary (MEDIUM confidence)

- None.

### Tertiary (LOW confidence)

- None.

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - Phoenix, Hex, Ecto, ExDoc, and Oban behavior were verified from official docs and local tool output. [VERIFIED: sources above]
- Architecture: MEDIUM - the recommended smoke/helper shape is strongly supported by repo context and local compilation proof, but full generated-app end-to-end execution has not been implemented yet. [VERIFIED: fresh consumer compile experiment (2026-04-28)] [VERIFIED: .planning/phases/09-install-release-confidence/09-CONTEXT.md]
- Pitfalls: HIGH - each pitfall is grounded in current repo docs/workflows or official task behavior. [VERIFIED: sources above]

**Research date:** 2026-04-28
**Valid until:** 2026-05-28
