# Phase 120: Adoption Proof & Release Truth - Research

**Researched:** 2026-08-09
**Domain:** packaged Phoenix consumer proof, schema-isolation migration contract, Cohort adoption demo, and release documentation
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Proof topology
- **D-120-01:** Treat the packed Hex-equivalent artifact as the release authority. Generated-app proof must install the packed artifact, run a host-owned `Oban.Migration` in `public`, run `Rindle.Migration` with its default `rindle` prefix, boot, and exercise a real Rindle persistence path. — **Reversibility:** costly — weakening this proof would allow checkout-only behavior to ship.
- **D-120-02:** Keep an explicit compatibility proof for `Rindle.Migration.up(version: 1, prefix: "public")`; do not turn compatibility into a third routing mode or imply arbitrary schema support.
- **D-120-03:** Reuse the existing generated-app helper, install-smoke conventions, Cohort/adoption-demo migration harnesses, and docs-parity tests. Extend their assertions instead of creating a competing release test system.

### Documentation and release truth
- **D-120-04:** Make README, getting-started, migration API docs, upgrading guidance, troubleshooting, generated-app fixtures, and release notes agree: `rindle` is the 0.4.0 default; `public` is the intentional compatibility escape hatch; populated upgrades require a host-owned maintenance-window migration; Oban and the host Ecto ledger remain host-owned in `public`.
- **D-120-05:** Documentation must be operationally honest: name the required ordering (backup/quiesce, host migration, matching deploy, doctor/runtime verification), required permissions and lock behavior, and the narrow guarded rollback truth. Do not promise online or automatic migration.

### Scope fences
- **D-120-06:** Do not alter Phase 117 routing authority, Phase 118 move semantics, or Phase 119 diagnostic classification except where a proof exposes an actual defect. Do not create, move, configure, or prefix `oban_jobs` or host `schema_migrations`.

### the agent's Discretion
- Split proof and documentation work into dependency-safe vertical slices, select focused command invocations, and use existing fixture conventions while retaining real packed-artifact coverage.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within Phase 120 proof and release-truth scope.
</user_constraints>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PROOF-01 | Automated isolation proof verifies fresh default installs, explicit public compatibility, a populated public-to-rindle upgrade, runtime routing, and the public Oban boundary. | Extend the existing generated-app helper/report and migration smoke assertions with schema-qualified catalog checks, a default persistence write/read, an explicit-`public` fixture, and a real populated-move fixture. [VERIFIED: codebase] |
| PROOF-02 | Packed-artifact generated-app smoke and the Cohort adoption demo provision and run end-to-end with Rindle in `rindle` and Oban in `public`. | Make both migration harnesses use host migration files calling the public APIs; retain tarball install smoke and demo boot/unit coverage. [VERIFIED: codebase] |
| DOCS-01 | README, getting-started, upgrade, migration API docs, docs-parity tests, and the 0.4.0 release notes agree on the breaking default, compatibility escape hatch, upgrade order, permissions, downtime expectations, and Oban ownership. | Add one docs-parity contract spanning public docs, `Rindle.Migration` moduledocs, generated fixture text, and the release-note draft. [VERIFIED: codebase] |

## Summary

Phase 120 is a verification-and-truth phase, not a new migration subsystem. The package already ships `priv/repo/migrations`, README, guides, and `Rindle.Migration`, while the generated-app helper already builds and installs an unpacked Hex artifact into a fresh Phoenix app. Its host migration fixture calls `Oban.Migration.up/0` and `Rindle.Migration.up(version: 1)`, but its report only checks unqualified `public` relations. That can falsely pass while the default Rindle relations belong in the `rindle` schema. [VERIFIED: codebase]

The Cohort demo currently has the inverse historical path: `mix rindle.migrate` runs `Ecto.Migrator` directly over `Application.app_dir(:rindle, "priv/repo/migrations")`, even though the public greenfield contract is a host-owned migration calling `Rindle.Migration`. Convert the demo to checked-in host migration files and keep the existing host-owned Oban migration; then prove `rindle` Rindle relations, `public.oban_jobs`, and real demo persistence after boot. [VERIFIED: codebase]

The required release-facing copy mostly exists in README/getting-started/upgrading, but Phase 120 must make that contract complete and mechanically coupled to the migration API moduledocs, troubleshooting, release notes, generated fixtures, and parity tests. Ecto documents that the host repository owns `schema_migrations`, serializes migrators with its migration lock, and can apply a transaction-local lock timeout; that serialization does not itself drain application traffic. [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html]

**Primary recommendation:** Add three vertical slices: packed generated-app/default-and-compatibility proof, Cohort host-migration/boot proof, then one shared documentation-and-release parity contract; wire only focused existing CI lanes.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Packed consumer installation and migration proof | API / Backend | Database / Storage | A generated Phoenix host executes its own migrations and verifies the unpacked artifact's public API against PostgreSQL catalogs. [VERIFIED: codebase] |
| Rindle relation routing | Database / Storage | API / Backend | `Rindle.Schema` fixes the supported compile-time prefix and `Rindle.Migration` creates/moves only its fixed relation set. [VERIFIED: codebase] |
| Oban and Ecto-ledger ownership | Database / Storage | API / Backend | The host migration owns `Oban.Migration`, `public.oban_jobs`, and its `schema_migrations` ledger. [VERIFIED: codebase] |
| Cohort proof | API / Backend | Browser / Client | Host migration aliases, application boot, seed/lifecycle operations, and existing browser/unit demo surfaces are the proof boundary. [VERIFIED: codebase] |
| Release truth | CDN / Static | API / Backend | HexDocs/README/guides and the package changelog communicate the executable database contract. [VERIFIED: codebase] |

## Project Constraints (from AGENTS.md)

- Keep changes focused; run the applicable checks named in `RUNNING.md`; update `.planning/PROJECT.md` only when intentionally changing product scope or shipped claims. [VERIFIED: AGENTS.md]
- Keep `main` green on merge-blocking Quality/coveralls, Integration, Proof, Package Consumer, and Adopter lanes; prefer PR-first delivery for serious feature-depth work. [VERIFIED: AGENTS.md]
- Follow `guides/release_publish.md` and `RUNNING.md` for CI/release gates; run `./scripts/maintainer/repo_hygiene_check.sh` before release preparation. [VERIFIED: AGENTS.md]
- For any adoption-demo UI work, follow its Phoenix rules: use `mix precommit` at completion, use the existing `Req` dependency rather than alternative HTTP clients, and retain Phoenix/LiveView/Ecto conventions. This phase should avoid UI changes unless an actual proof defect requires one. [VERIFIED: examples/adoption_demo/AGENTS.md]
- Do not reopen speculative milestone work during the demand-gated pause; Phase 120 is already approved work. [VERIFIED: AGENTS.md]

## Standard Stack

### Core

| Library / Surface | Version | Purpose | Why Standard |
|-------------------|---------|---------|--------------|
| Existing `Rindle.Migration` public API | in-repo | Host-owned fixed-prefix schema install and directional move calls | It is the already-published migration authority, validates only `rindle`/`public`, and owns the seven fixed Rindle relations. [VERIFIED: codebase] |
| Existing generated-app install-smoke helper | in-repo | Fresh Phoenix app + unpacked Hex-equivalent artifact proof | It already builds with `mix hex.build --unpack`, patches a generated Phoenix app, compiles, migrates, boots, and runs an app-local smoke test. [VERIFIED: codebase] |
| Existing Cohort adoption demo | in-repo | Persistent host/demo proof | It already owns an Ecto repo, Oban configuration, seed paths, unit lane, E2E lane, and Docker boot lane. [VERIFIED: codebase] |
| Existing docs-parity suite | in-repo | Mechanically enforce migration/documentation statements | It already reads README/guides/release material and tests required/forbidden migration wording. [VERIFIED: codebase] |

### Supporting

| Library / Surface | Version | Purpose | When to Use |
|-------------------|---------|---------|-------------|
| `Ecto.Migrator` / host migration ledger | existing Ecto SQL dependency | Run host migrations under normal migration locking | Use in generated-app and Cohort harnesses only to run the host's checked-in migration directory; do not replay Rindle's packaged migration directory for new setup. [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html] |
| `Oban.Migration` | existing dependency | Host-owned `public.oban_jobs` provisioning | Keep it in an explicit host migration before/alongside Rindle's host migration; do not add Oban behavior to Rindle. [VERIFIED: codebase] |
| PostgreSQL catalog queries | existing Postgrex/Ecto stack | Schema-qualified proof assertions | Restrict to fixed Rindle relations, `public.oban_jobs`, and the host ledger; use bound values/known names like the prior migration and snapshot tests. [VERIFIED: codebase] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Extend generated-app smoke | New standalone release test suite | Rejected: it would duplicate the established tarball/package source, cleanup, and CI integration rather than test the release authority. [VERIFIED: 120-CONTEXT.md] |
| Host migration files in Cohort | Raw `Application.app_dir` replay | Rejected for greenfield/demo proof: it bypasses the documented public migration API and fails to demonstrate the adopter-owned ledger handoff. [VERIFIED: codebase] |
| Schema-qualified catalog assertions | `search_path`-dependent checks | Rejected: a default/public lookup cannot prove separation; the phase's two-prefix contract is explicit. [VERIFIED: 118-CONTEXT.md] |

**Installation:** No new packages. [VERIFIED: codebase]

## Architecture Patterns

### System Architecture Diagram

```text
mix hex.build --unpack
        |
        v
Generated Phoenix host (fresh temp app) -------------------------------+
  host migration: Oban.Migration -> public.oban_jobs                   |
  host migration: Rindle.Migration.up(version: 1) -> rindle.<7 rels>  |
  explicit fixture: Rindle.Migration.up(version: 1, prefix: "public")|
  populated fixture: move_public_to_rindle(version: 1)                 |
        |                                                              |
        v                                                              |
boot + actual Rindle write/read -> schema-qualified report/assertions  |
        |                                                              |
        +--> public.oban_jobs unchanged; public.schema_migrations host-owned

Cohort checked-in host
  priv/repo/migrations: Oban migration + Rindle host migration
        -> mix ecto.migrate -> boot/seeds/real Rindle persistence
        -> rindle relations + public Oban boundary assertions

Public docs + `Rindle.Migration` moduledocs + 0.4.0 release notes
        -> docs-parity tests -> Proof/package-consumer/release lanes
```

### Recommended Project Structure

```text
test/install_smoke/
├── generated_app_smoke_test.exs      # report assertions for package/default/compat/upgrade
└── support/generated_app_helper.ex   # fixture generation, migration runner, schema report
examples/adoption_demo/
├── priv/repo/migrations/             # host-owned Oban and Rindle migration files
├── priv/rindle_migrate.exs           # retire or reduce to a compatibility/error guard
└── test/                             # migration-boundary and persistence tests
guides/ + README.md + CHANGELOG.md    # one operator contract
```

### Pattern 1: Host migration as the only greenfield install handoff

**What:** Generate or check in ordinary host migration modules. One calls `Oban.Migration`; a separate one calls `Rindle.Migration.up(version: 1)` using the default prefix. The runner applies the host directory through the host repo's normal ledger. [VERIFIED: codebase]

**When to use:** Fresh install/package proof and the Cohort demo. [VERIFIED: 120-CONTEXT.md]

**Example:**

```elixir
defmodule MyApp.Repo.Migrations.InstallRindle do
  use Ecto.Migration

  def up, do: Rindle.Migration.up(version: 1)
  def down, do: Rindle.Migration.down(version: 1)
end
```

Source: `lib/rindle/migration.ex`. [VERIFIED: codebase]

### Pattern 2: Report facts from the generated app; assert facts in the repository suite

**What:** Keep helper-generated code focused on provisioning, real persistence, and JSON-safe observed facts. Keep ExUnit policy assertions in `generated_app_smoke_test.exs`. [VERIFIED: codebase]

**When to use:** All temporary generated-app scenarios, to retain cleanup/report diagnostics and avoid test policy embedded in generated fixture strings. [VERIFIED: codebase]

**Required report facts:** `rindle` schema exists; every `Migration.V1.owned_relations/0` relation is in the selected expected schema; `public.oban_jobs` exists before and after the Rindle migration; host `schema_migrations` remains in `public`; a facade/Broker persistence operation succeeds after boot. For public compatibility, exactly the public fixture relations are present and default routing is not claimed. For populated upgrade, seed public relations and a row, run the directional helper in a host migration, then verify row/foreign-key/index integrity plus default runtime persistence. [VERIFIED: 118-CONTEXT.md]

### Pattern 3: One docs truth table, enforced by focused parity tests

**What:** Define required phrases/ordered steps and forbidden claims in one or a few explicit docs-parity tests. Use source sections rather than whole-document substring checks when wording belongs to migration/upgrade guidance. [VERIFIED: codebase]

**Required ordered operator story:** backup and prepare maintenance window; stop/drain Rindle writers and workers; run host migration with lock timeout; deploy the matching `rindle`-compiled build; run doctor/runtime verification; use reverse move only if quiesced and exactly reversible, otherwise restore backup. [VERIFIED: 118-CONTEXT.md]

### Anti-Patterns to Avoid

- **Public-only catalog proof:** Checking `to_regclass('public.rindle_migration_versions')` as the Rindle proof makes a default isolation failure invisible. Query each expected schema explicitly. [VERIFIED: codebase]
- **Raw packaged migration replay:** Retaining `Application.app_dir(:rindle, "priv/repo/migrations")` in Cohort's fresh setup proves an obsolete handoff rather than the host migration API. [VERIFIED: codebase]
- **Compatibility treated as runtime selection:** The `prefix: "public"` proof must use an explicitly public-compiled fixture and must not add a runtime selector, arbitrary prefix, or third routing mode. [VERIFIED: 120-CONTEXT.md]
- **Docs claim an online/automatic move:** Ecto's migration lock serializes migrators, but the contract requires application quiescence and a maintenance window. [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html]
- **Test only checkout dependencies:** The proof must use unpacked package output (and the existing network mode when release verification invokes it), never a repo-local `path: ../..` fallback. [VERIFIED: codebase]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Package-consumer fixture framework | New release test runner | `GeneratedAppHelper` and `scripts/install_smoke.sh` | They already build/unpack package artifacts, generate Phoenix hosts, clean temporary state, select profiles, and support network mode. [VERIFIED: codebase] |
| Schema-move algorithm | Generic `move(from:, to:)` or SQL in demo/docs | `Rindle.Migration.move_public_to_rindle(version: 1)` | Phase 118 locks the exact seven-relation allowlist, preflight, quoting, transaction behavior, and bounded reverse. [VERIFIED: 118-CONTEXT.md] |
| Host migration serialization | Custom lock subsystem | Ecto host migrations and transaction-local `lock_timeout` | Ecto owns the migration ledger/lock and supports transaction-scoped migration behavior. [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html] |
| Documentation validation | New documentation parser | Existing `docs_parity_test.exs` and `release_docs_parity_test.exs` | These already establish the project convention for exact public/maintainer release claims. [VERIFIED: codebase] |

**Key insight:** The highest-risk regression is not missing DDL; it is a proof that passes against the repository checkout or `public` namespace while the packaged default consumer routes into `rindle`. Reuse the tested harness and add schema-qualified observable facts. [VERIFIED: codebase]

## Common Pitfalls

### Pitfall 1: Fresh default test checks the wrong schema

**What goes wrong:** The helper reports a Rindle migration as successful because `public.rindle_migration_versions` exists or because no schema is specified. [VERIFIED: codebase]

**Why it happens:** The current migration report's `regclass_exists?/2` hardcodes `public.` and was written for the historical packaged-migration layout. [VERIFIED: codebase]

**How to avoid:** Make catalog checks take `(schema, relation)` and assert the full fixed relation list in `rindle`, no Rindle relation in `public` for default proof, and independently preserve `public.oban_jobs`/host ledger. [VERIFIED: 118-CONTEXT.md]

**Warning signs:** A test passes before asserting `rindle.rindle_migration_versions`; a generated app has only `public` catalog assertions. [VERIFIED: codebase]

### Pitfall 2: Cohort masks a packaging/API regression

**What goes wrong:** The demo boots after replaying private package migrations, but no adopter-owned migration calls the public API. [VERIFIED: codebase]

**Why it happens:** `mix rindle.migrate` currently resolves the package migration directory and uses `Ecto.Migrator.run/4`. [VERIFIED: codebase]

**How to avoid:** Check in a demo host Rindle migration next to its host Oban migration; remove the alias's dependency on raw packaged migration replay and test the new migration source/contents. [VERIFIED: codebase]

**Warning signs:** `Application.app_dir(:rindle, "priv/repo/migrations")` remains in setup scripts, aliases, or demo docs. [VERIFIED: codebase]

### Pitfall 3: Upgrade proof does not exercise the 0.4.0 path

**What goes wrong:** The existing upgrade helper seeds legacy data then replays packaged migrations, which is not the new populated public-to-`rindle` move. [VERIFIED: codebase]

**Why it happens:** `prove_upgrade_install!/0` is an AV-era upgrade proof with a legacy migration cutoff. [VERIFIED: codebase]

**How to avoid:** Add a narrowly named isolation-upgrade scenario: install public compatibility under a public-compiled fixture, seed real Rindle relationships, change to the default package/runtime, run an adopter host migration calling the directional helper, then boot and persist through default routing. Preserve the existing AV upgrade proof rather than overloading its semantics. [VERIFIED: 118-CONTEXT.md]

**Warning signs:** The scenario never calls `move_public_to_rindle(version: 1)` or cannot prove data survives the schema change. [VERIFIED: codebase]

### Pitfall 4: Release notes are detached from package truth

**What goes wrong:** A guide says 0.4.0 is breaking while release notes omit ordering, compatibility, permissions/locks, downgrade limits, or Oban ownership. [VERIFIED: 120-CONTEXT.md]

**How to avoid:** Add an Unreleased/0.4.0 release-note draft at the current changelog release surface, retain Release Please as the authority that creates the exact versioned heading, and parity-test the required contract statements. Do not manually bump `mix.exs` merely to make documentation read 0.4.0. [ASSUMED]

### Pitfall 5: Broader suite failures are misattributed to Phase 120

**What goes wrong:** Planner/executor changes unrelated migration/test support to make a broad suite pass. [VERIFIED: codebase]

**Why it happens:** Phase 119 verification records the dirty workspace's missing `public.media_assets` fixture as an existing environmental failure. [VERIFIED: 119-VERIFICATION.md]

**How to avoid:** First run focused Phase 120 commands. Treat the existing broken-window state as a separate diagnosis unless the new proof itself demonstrates a direct defect. [VERIFIED: 119-VERIFICATION.md]

## Code Examples

### Default/compatibility fixture migration pair

```elixir
defmodule RindleSmokeApp.Repo.Migrations.InstallHostOwnedOban do
  use Ecto.Migration
  def up, do: Oban.Migration.up()
end

defmodule RindleSmokeApp.Repo.Migrations.InstallRindle do
  use Ecto.Migration
  def up, do: Rindle.Migration.up(version: 1)
end

defmodule RindleSmokeApp.Repo.Migrations.InstallRindlePublicCompatibility do
  use Ecto.Migration
  def up, do: Rindle.Migration.up(version: 1, prefix: "public")
end
```

Source: existing generated-app fixture pattern plus `Rindle.Migration` public API. [VERIFIED: codebase]

### Populated upgrade host migration

```elixir
defmodule MyApp.Repo.Migrations.MoveRindleToSchema do
  use Ecto.Migration

  def up do
    execute("SET LOCAL lock_timeout = '5s'")
    Rindle.Migration.move_public_to_rindle(version: 1)
  end

  def down do
    execute("SET LOCAL lock_timeout = '5s'")
    Rindle.Migration.move_rindle_to_public(version: 1)
  end
end
```

Source: `guides/upgrading.md`; Ecto documents transaction-scoped lock-timeout patterns. [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Replay package migration directory from an app script | Host migration calls versioned `Rindle.Migration` API | Phase 118/0.4.0 contract | Fresh setup proves the adopter owns timing and ledger while Rindle owns only its relations. [VERIFIED: 118-CONTEXT.md] |
| Rindle/default proof implicitly accepts public tables | Compile-time default `rindle` plus explicit public compatibility only | Phase 117/118 contract | Proof must distinguish selected-schema routing from the one escape hatch. [VERIFIED: 117/118 phase artifacts] |
| Diagnosis and remediation blur together | Doctor/runtime-status inspect; host migration remediates | Phase 119 contract | Phase 120 validates the funnel without adding auto-remediation. [VERIFIED: 119-CONTEXT.md] |

**Deprecated/outdated:**

- Greenfield raw `Application.app_dir(:rindle, "priv/repo/migrations")` replay: retain only for historical upgrade documentation, not new generated-app/Cohort setup. [VERIFIED: codebase]
- `Oban.Migrations`: Cohort's current migration uses this spelling, while the locked 0.4.0 docs and generated fixture use `Oban.Migration`; normalize the demo to the documented contract if the installed dependency exports it, and prove it with the existing demo migration test. [ASSUMED]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Release Please will transform the prepared Unreleased release-note draft into the final `0.4.0` heading; `mix.exs` should not be manually version-bumped in this phase. | Common Pitfalls | The plan could place the 0.4.0 notes in the wrong changelog location or conflict with release automation. |
| A2 | `Oban.Migration` is exported by the exact demo-resolved Oban version and can replace its current `Oban.Migrations` spelling. | State of the Art | The demo migration could fail to compile; verify with `mix help`/compile before editing. |

## Resolved Planning Preconditions

1. **Release-note staging:** use a manifest-aware `## Unreleased / 0.4.0` staging section. Plan 120-06 verifies the Release Please configuration/manifest and requires the generated `[0.4.0]` heading to consume the staging marker after release automation advances it; it does not manually bump `mix.exs`.

2. **Generated-app isolation:** run explicit-public compatibility and populated public-to-`rindle` upgrade as separate named temporary apps, databases, reports, and compile stages. This prevents a compile-time prefix pairing or seeded legacy state from leaking between scenarios.

3. **Cohort Oban API:** the locked demo dependency is Oban 2.23.0. Plan 120-03 adds a blocking export precheck for `Oban.Migration.up/0` and `down/0` before normalizing the checked-in host migration, so the migration source and actual resolved dependency cannot diverge.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir/Mix + OTP | generated app and Cohort test harnesses | ✓ | OTP 28; Mix available | — [VERIFIED: local environment] |
| PostgreSQL CLI/server tooling | schema-qualified migration proof | ✓ CLI | psql 14.17 | CI supplies PostgreSQL 16 service. [VERIFIED: local environment; codebase] |
| Docker | Cohort cold-start verification | ✓ | 29.5.2 | Focused demo ExUnit proof if Docker-only lane is unavailable. [VERIFIED: local environment] |
| Node/npm | existing Playwright/demo lane | ✓ | Node 20.18.1; npm 10.8.2 | Focused ExUnit migration/persistence proof; do not descope package proof. [VERIFIED: local environment] |

**Missing dependencies with no fallback:** None identified. [VERIFIED: local environment]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (root and Phoenix demo) plus existing Playwright supplemental browser suite. [VERIFIED: codebase] |
| Config file | `test/test_helper.exs`; `examples/adoption_demo/test/test_helper.exs`; Playwright config at `examples/adoption_demo/playwright.config.js`. [VERIFIED: codebase] |
| Quick run command | `mix test test/install_smoke/docs_parity_test.exs --seed 0` and focused generated/demo test modules. [VERIFIED: codebase] |
| Full suite command | `mix ci`; plus the CI-owned package-consumer/adoption-demo commands in `RUNNING.md`. [VERIFIED: codebase] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PROOF-01 | Default `rindle`, explicit `public`, populated public-to-rindle move, runtime persistence, preserved public Oban/ledger | generated-app PostgreSQL integration | `RINDLE_INSTALL_SMOKE_PROFILE=image mix test test/install_smoke/generated_app_smoke_test.exs --include minio --seed 0` (extend with distinct default/compat/upgrade modules) | ✅ extend |
| PROOF-02 | Packed artifact installs/boots with host Oban public and Rindle rindle; Cohort provisions and persists | package smoke + demo integration | `bash scripts/install_smoke.sh image`; `cd examples/adoption_demo && mix test` | ✅ extend |
| DOCS-01 | Public docs, API moduledocs, fixture text, release draft agree on order/ownership/rollback limits | docs parity/unit | `mix test test/install_smoke/docs_parity_test.exs test/install_smoke/release_docs_parity_test.exs --seed 0` | ✅ extend |

### Sampling Rate

- **Per task commit:** focused affected ExUnit command and `mix format --check-formatted` for touched Elixir. [VERIFIED: AGENTS.md]
- **Per wave merge:** package smoke for generated-app work; `cd examples/adoption_demo && mix precommit` for demo work; docs-parity/release-parity for docs work. [VERIFIED: AGENTS.md; examples/adoption_demo/AGENTS.md]
- **Phase gate:** CI `proof`, lean `package-consumer`, `adoption-demo-unit`, `adopter`, and push:main `package-consumer-full`/Cohort smoke are green before release verification. [VERIFIED: RUNNING.md]

### Wave 0 Gaps

- [ ] Extend `test/install_smoke/generated_app_smoke_test.exs` with isolation-specific default/public/populated-upgrade assertions and update helper report fields. [VERIFIED: codebase]
- [ ] Add a focused adoption-demo migration/persistence boundary test near the demo's existing test support; update its setup alias/migration harness. [VERIFIED: codebase]
- [ ] Extend docs and release docs parity to cover `lib/rindle/migration.ex` moduledocs and 0.4.0 release-note content. [VERIFIED: codebase]
- [ ] Reconcile or explicitly quarantine the pre-existing dirty-workspace missing-table failure before using a broad `mix test` result as Phase 120 proof. [VERIFIED: 119-VERIFICATION.md]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | This phase changes proof/docs, not authentication. [VERIFIED: 120-CONTEXT.md] |
| V3 Session Management | no | This phase changes proof/docs, not session behavior. [VERIFIED: 120-CONTEXT.md] |
| V4 Access Control | yes | Document and prove required database ownership/`CREATE` privileges; do not turn catalog visibility into generic schema authority. [VERIFIED: 118-CONTEXT.md] |
| V5 Input Validation | yes | Keep all prefix proof at the two-value `Rindle.Schema`/migration-options boundary; no arbitrary prefix fixtures. [VERIFIED: codebase] |
| V6 Cryptography | no | No cryptographic behavior changes. [VERIFIED: 120-CONTEXT.md] |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Schema confusion makes host tables appear Rindle-owned | Tampering / Elevation | Assert exact schema-qualified fixed relation set and public Oban/ledger preservation; never use `search_path` as proof. [VERIFIED: 118-CONTEXT.md] |
| Misleading docs cause unsafe live migration | Denial of service / Tampering | Require backup, quiescence, lock timeout, matching deploy, doctor/runtime verification, and guarded rollback wording. [VERIFIED: 120-CONTEXT.md] |
| Package proof silently uses checkout source | Tampering | Assert package root/network source and reject repo-local dependency fallback. [VERIFIED: codebase] |

## Sources

### Primary (HIGH confidence)

- `120-CONTEXT.md` — locked proof topology, documentation, and scope boundaries. [VERIFIED: codebase]
- `test/install_smoke/generated_app_smoke_test.exs` and `support/generated_app_helper.ex` — package-building, host migration, report, boot, and current public-only assertion seams. [VERIFIED: codebase]
- `examples/adoption_demo/mix.exs`, `priv/rindle_migrate.exs`, and `priv/repo/migrations/20260528120100_add_oban.exs` — raw package replay and existing host Oban ownership. [VERIFIED: codebase]
- `README.md`, `guides/getting_started.md`, `guides/upgrading.md`, `guides/troubleshooting.md`, `lib/rindle/migration.ex`, `CHANGELOG.md`, `RUNNING.md`, and release/package workflows — current public/release contract and CI wiring. [VERIFIED: codebase]
- Phase 118/119 context, summaries, and verification — fixed relation ownership, migration safety, and bounded diagnostics handoff. [VERIFIED: codebase]

### Secondary (MEDIUM confidence)

- [Ecto.Migration documentation](https://ecto-sql.hexdocs.pm/Ecto.Migration.html) — host migration ledger/lock, Postgres migration transaction behavior, and lock-timeout pattern. [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html]

### Tertiary (LOW confidence)

- No external community recommendation was used for the selected implementation. The two assumptions above require confirmation against release configuration and installed Oban API. [ASSUMED]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — all selected surfaces already exist in this repository. [VERIFIED: codebase]
- Architecture: HIGH — locked phase context and Phase 118/119 artifacts define ownership/prefix boundaries. [VERIFIED: codebase]
- Pitfalls: HIGH — directly observed generated-app/Cohort seams and recorded Phase 119 environment caveat. [VERIFIED: codebase]

**Research date:** 2026-08-09
**Valid until:** 2026-09-08, except release-note heading convention which must be checked immediately before release planning. [ASSUMED]
