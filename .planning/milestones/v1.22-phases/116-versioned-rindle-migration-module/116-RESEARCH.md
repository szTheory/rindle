# Phase 116: Versioned Rindle.Migration Module - Research

**Researched:** 2026-07-01 [VERIFIED: init.phase-op]
**Domain:** Elixir/Ecto migration API, Oban migration ownership, Postgres catalog health checks [VERIFIED: 116-CONTEXT.md] [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html] [CITED: https://oban.hexdocs.pm/Oban.Migration.html]
**Confidence:** MEDIUM - core direction is locked and codebase-backed; exact marker-table decomposition remains planner discretion. [VERIFIED: 116-CONTEXT.md] [VERIFIED: codebase grep]

<user_constraints>
## User Constraints (from CONTEXT.md)

All bullets in this section are copied from `.planning/phases/116-versioned-rindle-migration-module/116-CONTEXT.md`; treat them as locked planning constraints. [VERIFIED: 116-CONTEXT.md]

### Locked Decisions

## Implementation Decisions

### Discussion Outcome

- **D-01:** The user requested one-shot research-backed recommendations for every gray area. No further user questions are needed before planning. Four subagents researched the gray areas independently, and their recommendations converged.
- **D-02:** Treat `116-UI-SPEC.md` as a locked documentation UX/design contract. It governs Markdown hierarchy, terminology, callout copy, rollback language, docs dependency boundaries, and the "no frontend UI/component dependency" constraint.
- **D-03:** Treat Phase 115's context as load-bearing. `guides/upgrading.md` is already the newest-first upgrade home; Phase 116 must add its migration note there instead of inventing another upgrade surface.

### Migration API Surface

- **D-04:** Expose an Oban-style `Rindle.Migration.up/1` and `Rindle.Migration.down/1` as the public migration API. This is the only public migration surface authorized for Phase 116.
- **D-05:** Public docs and generated-app proof must pin the migration version:

  ```elixir
  defmodule MyApp.Repo.Migrations.InstallRindle do
    use Ecto.Migration

    def up, do: Rindle.Migration.up(version: 1)
    def down, do: Rindle.Migration.down(version: 1)
  end
  ```

  This keeps host migrations deterministic if a project runs old generated migration code after upgrading the `rindle` dependency.
- **D-06:** The implementation may allow omitted `:version` to mean latest for developer ergonomics, but the greenfield docs must not teach the unpinned form. Deterministic adopter migrations matter more than saving a few characters.
- **D-07:** Accept a small validated keyword option schema. Required shape for planning: `:version` and `:prefix`, with `prefix: "public"` as the default. Consider `:create_schema` only if planning confirms it is needed to prepare v1.23 prefix work without widening Phase 116.
- **D-08:** Unknown options and invalid versions must fail loudly with clear `ArgumentError` or existing local validation-pattern errors. Prefer `NimbleOptions` because this repo already uses it as a public-contract validator.
- **D-09:** Do not add a public `mix rindle.*` install task, Igniter installer, or migration generator in Phase 116. Those are valid future onboarding ideas, but the approved UI-SPEC explicitly rejects a new public install task for this phase.
- **D-10:** `Rindle.Migration.up/1` must create or upgrade only Rindle-owned tables. It must not call `Oban.Migration`, create `oban_jobs`, or mutate host-owned Oban state.
- **D-11:** `Rindle.Migration.down/1` is destructive but scoped. It may drop only Rindle-owned tables and marker objects, in reverse dependency order, and must not drop `oban_jobs`. Docs must pair it with backup language from the UI-SPEC.
- **D-12:** Idempotency means the migration module can run against a database that already has the current Rindle-owned schema without failing or duplicating objects. Use Ecto helpers and/or catalog guards intentionally; do not wrap or invoke `Ecto.Migrator.run/4` over `priv/repo/migrations` from inside the new module.
- **D-13:** Keep public API perspective consumer-first: adopters should think "create a normal migration in my app" rather than "learn Rindle's internal migration file layout."

### Packaged Migration History

- **D-14:** Freeze the existing `priv/repo/migrations/*.exs` filenames in the Hex package for legacy compatibility and historical inspection. Do not delete or move them in this non-breaking phase.
- **D-15:** The legacy packaged migration directory is no longer the greenfield install path. README, getting-started, upgrading, and generated-app proof must stop teaching raw `Application.app_dir(:rindle, "priv/repo/migrations")` plus `Ecto.Migrator.run/4` for fresh installs.
- **D-16:** Convert `priv/repo/migrations/20260424205942_create_oban_tables.exs` into a no-op compatibility stub or otherwise make it non-authoritative so fresh Phase 116 installs no longer create `oban_jobs` on Rindle's behalf. Do not remove the filename, because existing adopters may have that version in `schema_migrations`.
- **D-17:** Preserve all other legacy packaged migration files as compatibility artifacts unless planning discovers a test or Hex package constraint that requires a narrower stub approach. They remain for already-applied legacy history and old package-path inspection, not as the recommended new path.
- **D-18:** Implement Rindle-owned schema changes in `lib/` behind `Rindle.Migration`, not by teaching adopters to copy or run package migration files. This mirrors Oban's successful pattern while avoiding a new generator support surface.
- **D-19:** The new module should make primary key and table options explicit. Do not depend on host Repo migration defaults such as binary-id settings, because this is a library-owned schema contract.
- **D-20:** Include an internal Rindle migration version marker so doctor/runtime can distinguish a fresh `Rindle.Migration` install from legacy file-history installs. Keep marker/query helpers private unless planning finds a strong reason to expose them.

### Doctor And Runtime Compatibility

- **D-21:** Replace "packaged migration file status is authoritative" with a hybrid health model:
  - Rindle migration version marker for fresh installs.
  - Postgres catalog/table/column/index checks for actual Rindle-owned schema readiness.
  - Legacy Ecto packaged migration compatibility for existing adopters.
  - Oban preflight that checks host-owned Oban configuration and `oban_jobs` readiness without claiming Rindle owns that table.
- **D-22:** `mix rindle.doctor` should return `OK` when either the new `Rindle.Migration` path or the legacy 15-file path yields a current, healthy Rindle-owned schema.
- **D-23:** `mix rindle.doctor` should return `ERROR` for incomplete/missing Rindle-owned tables, failed migration inspection, missing default Oban config where required, or missing `oban_jobs` when the runtime needs Oban.
- **D-24:** Healthy legacy file-history drift should be downgraded from hard failure to a warning/history-only diagnostic when catalog checks prove the Rindle-owned schema is complete. Existing adopters must not be told to delete or replay legacy migrations.
- **D-25:** `runtime_status` should preflight required Rindle-owned tables and host-owned `oban_jobs`, then return actionable setup failures rather than raw `undefined_table` crashes or empty reports. The user-facing message should say, in substance: install Oban with a host-owned `Oban.Migration`; Rindle no longer manages `oban_jobs`.
- **D-26:** Prefix-aware catalog query design should be prepared now, even though the default remains `public`, so v1.23 can build on this substrate instead of replacing it.
- **D-27:** Keep existing stable doctor check IDs where practical. If a status taxonomy changes, tests must lock the new semantics rather than simply weakening current assertions.

### Documentation And Proof Depth

- **D-28:** Use a full contract lock, not docs-only proof. Required proof surfaces: README, `guides/getting_started.md`, `guides/upgrading.md`, docs parity tests, generated Phoenix app smoke helpers/tests, doctor/runtime tests, and focused migration API tests.
- **D-29:** README `## Migrations` must show a compact host-owned migration module calling `Rindle.Migration.up/1` and `down/1`. It must also state that the default schema remains `public`.
- **D-30:** `guides/getting_started.md` step 3 must be renamed/reworked around normal host-app migration ownership, `Rindle.Migration`, separate host-owned `Oban.Migration`, and `mix rindle.doctor` verification.
- **D-31:** `guides/upgrading.md` `## Unreleased / Next` must add the Phase 116 note newest-first with `Applies to`, `What changed`, `Upgrade steps`, and `Verification`. Fresh installs use `Rindle.Migration`; existing legacy installs remain valid.
- **D-32:** Docs must explicitly separate Rindle-owned tables from `oban_jobs`. `Oban.Migration` is the host app's responsibility, and Rindle must not create `oban_jobs` for adopters going forward.
- **D-33:** Docs parity must reject the old greenfield raw package-path snippet in README/getting-started/upgrading while still allowing legacy compatibility copy where intentionally scoped.
- **D-34:** Generated-app smoke proof should create and run real host migrations: one for host app proof data, one for host-owned Oban setup, and one for Rindle setup calling `Rindle.Migration`. It should assert Rindle's path does not create `oban_jobs`.
- **D-35:** Add migration API tests for idempotent `up/1`, scoped/destructive `down/1`, invalid options, explicit UUID/schema choices, version marker behavior, and absence of Oban table creation.
- **D-36:** Verification should stay focused: run docs parity and migration/runtime focused tests during plan execution; phase gate remains the repo checks named in `RUNNING.md` / `CONTRIBUTING.md`.

### Developer Experience And Copy

- **D-37:** Optimize for the adopter's job to be done: "install Rindle tables in my Phoenix/Ecto app without losing control of my Repo, Oban, migrations, or rollback." Avoid exposing internal package migration layout unless explaining legacy compatibility.
- **D-38:** Copy tone should follow the brand system: calm, explicit, production-aware, no magic, no fear. Use the UI-SPEC labels `Migration:`, `Oban ownership:`, `Upgrade note:`, `Rollback:`, and `Verification:` when callouts are useful.
- **D-39:** Use portable Markdown only. Do not add docs CSS, shadcn/Radix/Tailwind, JS, custom admonition plugins, icons, or rendered documentation styling in this phase.
- **D-40:** If rendered docs styling is touched unexpectedly, use the current `brandbook/` tokens over older prompt material: Atkinson Hyperlegible for body, Space Grotesk for headings, JetBrains Mono for code, WCAG AA pairs, status labels paired with color, and no Rindle Green as small text on light surfaces.

### Rejected Alternatives And Footguns

- **D-41:** Reject deleting legacy packaged migration files in Phase 116. That would make existing applied versions look unresolved and turns a non-breaking phase into a breaking cleanup.
- **D-42:** Reject keeping `CreateObanTables` as normal greenfield behavior. It fails MIGRATE-02 by preserving the host-Oban collision.
- **D-43:** Reject keeping `Ecto.Migrator.migrations/2` as the sole doctor source of truth. Fresh `Rindle.Migration` installs will not mark all legacy package versions as applied.
- **D-44:** Reject hiding setup behind a public install task. It contradicts the UI-SPEC and adds generator drift as a new contract surface.
- **D-45:** Reject unpinned docs snippets (`Rindle.Migration.up()` only) for greenfield migration files. They are convenient but make old host migrations change meaning after dependency upgrades.

### the agent's Discretion

- Exact internal module decomposition under `Rindle.Migration` and helper modules.
- Exact marker table name, as long as it is clearly Rindle-owned, prefix-aware, not Ecto's `schema_migrations`, and covered by tests.
- Exact warning/error struct shape in doctor/runtime, as long as the semantics above are locked and existing stable IDs are preserved where practical.
- Exact prose transitions in docs, as long as the UI-SPEC terminology, labels, ordering, and safety copy are preserved.

### Deferred Ideas (OUT OF SCOPE)

- Public `mix rindle.*` or Igniter install generator - potentially good future onboarding DX, but out of scope for Phase 116 and explicitly rejected by the UI-SPEC for this phase.
- Breaking default Postgres schema isolation (`rindle` schema default, `prefix: "public"` opt-out, table move migration) - v1.23 / 0.4.0.
- Release/public HexDocs proof lock beyond source docs parity and generated-app smoke - useful if package/source drift reappears, but not required for this phase unless planning discovers release packaging risk.

### Reviewed Todos (not folded)

- `2026-06-19-fix-docker-demo-startup-warnings.md` - deferred as unrelated tooling/Docker demo polish. It matched Phase 116 only through broad `yml`/`lib` keywords and does not clarify migration API, Oban ownership, docs, or runtime compatibility.
</user_constraints>

## Summary

Phase 116 should be planned as a backend/library migration substrate plus documentation-proof phase, not as a generator, Mix-task, or UI phase. [VERIFIED: 116-CONTEXT.md] The right implementation path is to add a public `Rindle.Migration` module under `lib/`, implemented with Ecto migration primitives, validating a small option schema, creating/upgrading only Rindle-owned tables, and recording an internal Rindle migration version marker. [VERIFIED: 116-CONTEXT.md] [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html] [VERIFIED: deps/ecto_sql source]

The planner must preserve the legacy `priv/repo/migrations` filenames, but stop using that directory as the fresh-install path. [VERIFIED: 116-CONTEXT.md] The local test database currently has all 15 legacy versions marked `up`, including `20260424205942_create_oban_tables`, and `public.oban_jobs` exists because the bundled Oban migration already ran in this repo. [VERIFIED: mix ecto.migrations] [VERIFIED: Repo catalog probe] That is exactly why doctor/runtime checks need a hybrid model: new marker, catalog readiness, legacy `schema_migrations` compatibility, and host-owned Oban readiness. [VERIFIED: 116-CONTEXT.md] [VERIFIED: lib/rindle/ops/runtime_checks.ex]

**Primary recommendation:** Implement `Rindle.Migration.up(version: 1, prefix: "public")` / `down(version: 1, prefix: "public")` with explicit binary-id DDL, private marker helpers, prefix-aware catalog health, and generated-app proof that Rindle does not create `oban_jobs`. [VERIFIED: 116-CONTEXT.md] [VERIFIED: priv/repo/migrations/*.exs] [CITED: https://oban.hexdocs.pm/Oban.Migration.html]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| `Rindle.Migration` DDL API | API / Backend [VERIFIED: 116-CONTEXT.md] | Database / Storage [ASSUMED] | The module is called from adopter Ecto migrations and emits Postgres DDL for Rindle-owned persistence. [VERIFIED: 116-CONTEXT.md] |
| Rindle-owned table creation/upgrades | Database / Storage [VERIFIED: priv/repo/migrations/*.exs] | API / Backend [ASSUMED] | The durable outcome is table/column/index state; Ecto migration code is the execution tier. [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html] |
| Host-owned Oban installation | API / Backend [CITED: https://oban.hexdocs.pm/Oban.Migration.html] | Database / Storage [ASSUMED] | Host apps wrap `Oban.Migration` in their own Ecto migration, and `oban_jobs` is shared host state. [VERIFIED: 116-CONTEXT.md] |
| Doctor migration health | API / Backend [VERIFIED: lib/rindle/ops/runtime_checks.ex] | Database / Storage [VERIFIED: test/rindle/ops/runtime_checks_test.exs] | Runtime checks query migration status and Postgres catalogs, then render stable doctor check IDs. [VERIFIED: lib/rindle/ops/runtime_checks.ex] |
| Runtime status setup preflight | API / Backend [VERIFIED: lib/rindle/ops/runtime_status.ex] | Database / Storage [ASSUMED] | `runtime_status/1` reads Rindle and Oban-backed data and should fail with setup guidance before undefined-table crashes. [VERIFIED: 116-CONTEXT.md] |
| README/getting-started/upgrading copy | Static / Documentation [VERIFIED: 116-UI-SPEC.md] | API / Backend [ASSUMED] | The docs teach host migration files and verification commands, but no browser UI or docs styling is authorized. [VERIFIED: 116-UI-SPEC.md] |
| Generated-app smoke proof | Test / CI [VERIFIED: test/install_smoke/support/generated_app_helper.ex] | API / Backend [ASSUMED] | The proof creates a Phoenix app, runs migrations, boots, and exercises the install contract. [VERIFIED: test/install_smoke/generated_app_smoke_test.exs] |

## Project Constraints (from AGENTS.md)

- Keep edits focused and run checks named by `RUNNING.md` for the change. [VERIFIED: AGENTS.md]
- Follow `guides/release_publish.md` and `RUNNING.md` for CI lanes and release gates. [VERIFIED: AGENTS.md]
- Update `.planning/PROJECT.md` only when product scope or shipped claims intentionally change; Phase 116 research does not itself require that edit. [VERIFIED: AGENTS.md]
- For UI/admin-console work, follow `guides/ui_principles.md`; Phase 116 is not UI/admin-console work and the UI-SPEC forbids frontend dependencies. [VERIFIED: AGENTS.md] [VERIFIED: 116-UI-SPEC.md]
- Preserve the green-main release train posture: do not rename `.github/workflows/ci.yml`, do not change `name: CI`, do not weaken `CI Summary`, and do not weaken the full release-verification gate. [VERIFIED: AGENTS.md] [VERIFIED: RUNNING.md]
- Prefer PR-first execution for serious milestone or feature-depth work. [VERIFIED: AGENTS.md]
- Before release prep, run `./scripts/maintainer/repo_hygiene_check.sh`. [VERIFIED: AGENTS.md]
- Repo-local GSD model routing expects planning/research agents on `auto` and execution/verify agents on `composer-2.5`; this affects orchestration, not implementation design. [VERIFIED: AGENTS.md] [VERIFIED: .planning/config.json]
- No root `CLAUDE.md`, `.claude/CLAUDE.md`, `.codex/skills/*/SKILL.md`, `.agents/skills/*/SKILL.md`, or `.claude/skills/*/SKILL.md` was found during research. [VERIFIED: `rg --files` + `find`]

## Graph Context

No `.planning/graphs/graph.json` exists in this repo, so no graphify semantic context was available for Phase 116. [VERIFIED: `ls .planning/graphs`]

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MIGRATE-01 | Adopters install Rindle tables through versioned, idempotent `Rindle.Migration.up/1` + `down/1`; docs show the compact migration; default schema remains `public`; existing applied migrations remain valid. [VERIFIED: .planning/REQUIREMENTS.md] | Use Ecto migration helpers, explicit version validation, a private marker table, and hybrid legacy/catalog health checks. [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html] [VERIFIED: 116-CONTEXT.md] |
| MIGRATE-02 | Rindle no longer creates `oban_jobs`; adopter owns `Oban.Migration`; docs explain host Oban ownership. [VERIFIED: .planning/REQUIREMENTS.md] | Stub or neutralize the bundled Oban migration, keep filename compatibility, and make generated-app proof install Oban separately from Rindle. [VERIFIED: 116-CONTEXT.md] [CITED: https://oban.hexdocs.pm/Oban.Migration.html] |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `ecto_sql` | Locked `3.13.5`; Hex latest `3.14.0` published 2026-05-19. [VERIFIED: mix.lock] [VERIFIED: `mix hex.info ecto_sql`] | Host-app migration context, Ecto DDL helpers, `schema_migrations`, and catalog-friendly Repo queries. [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html] | Ecto is already the repo's migration and persistence foundation. [VERIFIED: mix.exs] |
| `oban` | Locked `2.21.1`; Hex latest `2.23.0` published 2026-05-27. [VERIFIED: mix.lock] [VERIFIED: `mix hex.info oban`] | Background jobs and the ecosystem analog for versioned migration wrappers. [CITED: https://oban.hexdocs.pm/Oban.Migration.html] | Phase 116 explicitly mirrors Oban's host-migration wrapper pattern while leaving `oban_jobs` host-owned. [VERIFIED: 116-CONTEXT.md] |
| `nimble_options` | Locked/latest `1.1.1`. [VERIFIED: mix.lock] [VERIFIED: `mix hex.info nimble_options`] | Validates `Rindle.Migration` keyword options and raises clear errors. [VERIFIED: deps/nimble_options source] | Rindle already uses NimbleOptions for public-contract validation in `Rindle.Profile.Validator`. [VERIFIED: lib/rindle/profile/validator.ex] |
| `postgrex` | Locked/latest stable `0.22.2`; Hex also lists retired `1.0.0-rc.*`. [VERIFIED: mix.lock] [VERIFIED: `mix hex.info postgrex`] | Postgres adapter used by Ecto for DDL and catalog probes. [VERIFIED: mix.exs] | Rindle's migrations and runtime checks are Postgres-oriented. [VERIFIED: priv/repo/migrations/*.exs] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| ExUnit / Mix test | Elixir/Mix `1.19.5` locally; project supports Elixir `~> 1.15`. [VERIFIED: `elixir --version`] [VERIFIED: mix.exs] | Focused unit, docs parity, migration, doctor, and runtime tests. [VERIFIED: test/test_helper.exs] | Use for all Phase 116 proof. [VERIFIED: RUNNING.md] |
| Phoenix installer archive | `mix phx.new --version` reports `1.8.8`. [VERIFIED: execution] | Generated Phoenix app install smoke. [VERIFIED: scripts/install_smoke.sh] | Use through `scripts/install_smoke.sh`; the script installs the archive if missing. [VERIFIED: scripts/install_smoke.sh] |
| MinIO helper | Script-managed local service. [VERIFIED: scripts/ensure_minio.sh] | Generated-app package consumer smoke for non-GCS profiles. [VERIFIED: scripts/install_smoke.sh] | Use `bash scripts/install_smoke.sh image` or broader profiles when storage proof is needed. [VERIFIED: scripts/install_smoke.sh] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `Rindle.Migration` wrapper | Keep raw `Application.app_dir(:rindle, "priv/repo/migrations")` + `Ecto.Migrator.run/4` | Rejected because fresh installs would still depend on internal file layout and bundled Oban history. [VERIFIED: 116-CONTEXT.md] |
| Ecto helpers plus catalog guards | Hand-written SQL for every table/index | Rejected because Ecto already provides prefix-aware DDL and idempotent helpers, while custom SQL raises adapter/version risk. [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html] |
| Host-owned `Oban.Migration` | Rindle calling `Oban.Migration` internally | Rejected because Phase 116 must stop owning `oban_jobs`. [VERIFIED: 116-CONTEXT.md] |
| NimbleOptions | Manual `Keyword` parsing | Rejected because the repo already uses NimbleOptions for public validation and clear errors. [VERIFIED: lib/rindle/profile/validator.ex] |

**Installation:**

No new external packages are recommended for Phase 116; use existing locked dependencies. [VERIFIED: mix.exs] [VERIFIED: mix.lock]

**Version verification:**

Verified with `mix hex.info ecto_sql`, `mix hex.info oban`, `mix hex.info nimble_options`, and `mix hex.info postgrex` on 2026-07-01. [VERIFIED: execution]

## Package Legitimacy Audit

Phase 116 should not install new external packages. [VERIFIED: mix.exs] The `package-legitimacy` seam did not emit a Hex verdict for `--ecosystem hex`, so this audit is limited to "no new install" plus Hex registry and lockfile verification. [VERIFIED: execution]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| `ecto_sql` | Hex [VERIFIED: `mix hex.info ecto_sql`] | Active recent release 2026-05-19. [VERIFIED: `mix hex.info ecto_sql`] | 256,376 last 7 days. [VERIFIED: `mix hex.info ecto_sql`] | `github.com/elixir-ecto/ecto_sql`. [VERIFIED: `mix hex.info ecto_sql`] | OK for existing dependency. [VERIFIED: mix.lock] | Approved; no install task. [VERIFIED: mix.exs] |
| `oban` | Hex [VERIFIED: `mix hex.info oban`] | Active recent release 2026-05-27. [VERIFIED: `mix hex.info oban`] | 156,765 last 7 days. [VERIFIED: `mix hex.info oban`] | `github.com/oban-bg/oban`. [VERIFIED: `mix hex.info oban`] | OK for existing dependency. [VERIFIED: mix.lock] | Approved; no install task. [VERIFIED: mix.exs] |
| `nimble_options` | Hex [VERIFIED: `mix hex.info nimble_options`] | Latest release 2024-05-25. [VERIFIED: `mix hex.info nimble_options`] | 286,480 last 7 days. [VERIFIED: `mix hex.info nimble_options`] | `github.com/dashbitco/nimble_options`. [VERIFIED: `mix hex.info nimble_options`] | OK for existing dependency. [VERIFIED: mix.lock] | Approved; no install task. [VERIFIED: mix.exs] |
| `postgrex` | Hex [VERIFIED: `mix hex.info postgrex`] | Active recent release 2026-05-12. [VERIFIED: `mix hex.info postgrex`] | 242,921 last 7 days. [VERIFIED: `mix hex.info postgrex`] | `github.com/elixir-ecto/postgrex`. [VERIFIED: `mix hex.info postgrex`] | OK for existing dependency. [VERIFIED: mix.lock] | Approved; no install task. [VERIFIED: mix.exs] |

**Packages removed due to [SLOP] verdict:** none. [VERIFIED: no new package recommendation]
**Packages flagged as suspicious [SUS]:** none. [VERIFIED: no new package recommendation]

## Architecture Patterns

### System Architecture Diagram

```text
Host app developer
  |
  v
mix ecto.gen.migration install_oban
  |
  v
Host migration calls Oban.Migration.up/down
  |
  v
Host-owned oban_jobs table

Host app developer
  |
  v
mix ecto.gen.migration install_rindle
  |
  v
Host migration calls Rindle.Migration.up(version: 1, prefix: "public")
  |
  v
Validate opts with NimbleOptions
  |
  v
Apply Rindle-owned DDL only
  |
  +--> create/upgrade media_assets, media_attachments, media_variants
  |
  +--> create/upgrade media_upload_sessions, media_processing_runs, media_provider_assets
  |
  +--> write private Rindle migration marker
  |
  v
mix rindle.doctor / runtime_status
  |
  +--> marker check for fresh installs
  +--> catalog checks for actual schema readiness
  +--> legacy schema_migrations compatibility
  +--> host-owned Oban config + oban_jobs readiness
  |
  v
actionable OK/WARN/ERROR output
```

This diagram reflects the locked split: Rindle owns Rindle tables; the host owns Oban and `oban_jobs`. [VERIFIED: 116-CONTEXT.md]

### Recommended Project Structure

```text
lib/
├── rindle/
│   ├── migration.ex              # public Rindle.Migration API
│   ├── migration/
│   │   ├── options.ex            # private NimbleOptions schema, if decomposition helps
│   │   └── v1.ex                 # private version-1 DDL body, if decomposition helps
│   └── ops/
│       ├── runtime_checks.ex     # hybrid migration health
│       └── runtime_status.ex     # setup preflight before report queries
priv/
└── repo/migrations/              # frozen legacy filenames; Oban migration stubbed/non-authoritative
test/
├── rindle/migration_test.exs     # new focused migration API tests
├── rindle/ops/runtime_checks_test.exs
├── rindle/ops/runtime_status_test.exs
└── install_smoke/                # docs parity + generated app proof
```

The exact helper split is discretionary, but the public module should live at `Rindle.Migration`. [VERIFIED: 116-CONTEXT.md]

### Pattern 1: Host-Owned Wrapper Migration

**What:** Adopters create normal host-app Ecto migrations that call `Rindle.Migration` with a pinned version. [VERIFIED: 116-CONTEXT.md]

**When to use:** Every fresh install and every future versioned Rindle schema upgrade. [VERIFIED: 116-CONTEXT.md]

**Example:**

```elixir
# Source: 116-CONTEXT.md and Oban.Migration docs
defmodule MyApp.Repo.Migrations.InstallRindle do
  use Ecto.Migration

  def up, do: Rindle.Migration.up(version: 1)
  def down, do: Rindle.Migration.down(version: 1)
end
```

Oban documents the same wrapper-migration shape and versioned up/down API, including prefix support. [CITED: https://oban.hexdocs.pm/Oban.Migration.html]

### Pattern 2: Explicit Library-Owned DDL

**What:** `Rindle.Migration` should define table options explicitly instead of inheriting adopter Repo migration defaults. [VERIFIED: 116-CONTEXT.md] Ecto table options support explicit primary key settings and prefixes. [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html]

**When to use:** Every Rindle-owned table and index in the version-1 migration body. [VERIFIED: priv/repo/migrations/*.exs]

**Example:**

```elixir
# Source: Ecto.Migration docs + existing Rindle schema modules
create_if_not_exists table(:media_assets,
                       primary_key: [name: :id, type: :binary_id],
                       prefix: prefix
                     ) do
  add :state, :string, null: false, default: "staged"
  add :storage_key, :string, null: false
  add :metadata, :map, null: false, default: %{}
  add :profile, :string, null: false
  timestamps(type: :utc_datetime_usec)
end

create_if_not_exists unique_index(:media_assets, [:storage_key], prefix: prefix)
```

The planner should verify the final DDL against all legacy Rindle-owned migrations, not just the first table file. [VERIFIED: priv/repo/migrations/*.exs]

### Pattern 3: Hybrid Migration Health

**What:** Doctor/runtime checks should combine marker, catalog, legacy `schema_migrations`, and host Oban readiness. [VERIFIED: 116-CONTEXT.md]

**When to use:** `mix rindle.doctor` and `Rindle.runtime_status/1` setup preflight. [VERIFIED: lib/rindle/ops/runtime_checks.ex] [VERIFIED: lib/rindle/ops/runtime_status.ex]

**Example:**

```elixir
# Source: PostgreSQL information_schema docs + existing RuntimeChecks catalog pattern
SELECT column_name, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = $1
  AND table_name = $2
  AND column_name = ANY($3)
```

Postgres docs recommend information_schema for stable object metadata, while PostgreSQL-specific details require system catalogs or views. [CITED: https://www.postgresql.org/docs/current/information-schema.html]

### Pattern 4: Docs Parity as Contract Lock

**What:** README/getting-started/upgrading claims should be asserted in `test/install_smoke/docs_parity_test.exs`. [VERIFIED: test/install_smoke/docs_parity_test.exs]

**When to use:** Any migration snippet or Oban ownership copy change. [VERIFIED: 116-CONTEXT.md]

**Example:**

```elixir
# Source: existing DocsParityTest helper style
assert doc =~ "Rindle.Migration.up(version: 1)"
assert doc =~ "Oban.Migration"
refute doc =~ "Application.app_dir(:rindle, \"priv/repo/migrations\")"
```

Allow legacy copy only in the upgrade/compatibility context, not in greenfield sections. [VERIFIED: 116-CONTEXT.md]

### Anti-Patterns to Avoid

- **Invoking `Ecto.Migrator.run/4` inside `Rindle.Migration`:** This preserves the internal file-layout install path and violates the locked API direction. [VERIFIED: 116-CONTEXT.md]
- **Deleting legacy packaged migration files:** Existing adopter `schema_migrations` rows would become unresolved/missing-file history. [VERIFIED: 116-CONTEXT.md]
- **Letting Rindle create `oban_jobs`:** That keeps the host-Oban collision alive and fails MIGRATE-02. [VERIFIED: .planning/REQUIREMENTS.md]
- **Relying on host Repo binary-id defaults:** Existing early migration files did not explicitly set all primary keys even though schemas use `:binary_id`; Phase 116 must make the library contract explicit. [VERIFIED: priv/repo/migrations/*.exs] [VERIFIED: lib/rindle/domain/*.ex]
- **Treating marker presence as sufficient:** A marker can lie if DDL drift exists; catalog checks must still prove table/column/index readiness. [VERIFIED: 116-CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Migration DDL runner | Custom SQL runner or internal file replay | `Ecto.Migration` helpers. [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html] | Ecto already handles migration callbacks, DDL command collection, prefixes, and rollback conventions. [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html] |
| Oban installation | Rindle-owned `oban_jobs` creation | Host app migration calling `Oban.Migration`. [CITED: https://oban.hexdocs.pm/Oban.Migration.html] | Oban documents host wrapper migrations and versioned idempotent migrations. [CITED: https://oban.hexdocs.pm/Oban.Migration.html] |
| Option validation | Manual `Keyword.fetch`/unknown-key parsing | `NimbleOptions.validate!/2`, wrapped as `ArgumentError`. [VERIFIED: deps/nimble_options source] [VERIFIED: lib/rindle/profile/validator.ex] | Existing Rindle public validation already uses this pattern and tests clear errors. [VERIFIED: test/rindle/profile/validator_test.exs] |
| Schema readiness inspection | String matching `schema_migrations` only | Prefix-aware information_schema plus `pg_indexes` for partial indexes. [CITED: https://www.postgresql.org/docs/current/information-schema.html] [VERIFIED: lib/rindle/ops/runtime_checks.ex] | Fresh installs via `Rindle.Migration` will not have all legacy file versions in `schema_migrations`. [VERIFIED: 116-CONTEXT.md] |
| Install generator | New `mix rindle.install` task | Normal host `mix ecto.gen.migration` and docs snippet. [VERIFIED: 116-UI-SPEC.md] | The UI-SPEC rejects a new public install task for this phase. [VERIFIED: 116-UI-SPEC.md] |

**Key insight:** The hard part is not writing DDL once; it is keeping old file-history installs, new marker installs, and host-owned Oban installs all healthy without rewriting adopter history. [VERIFIED: 116-CONTEXT.md]

## Runtime State Inventory

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | Local `schema_migrations` has all 15 legacy versions marked `up`, including `20260424205942_create_oban_tables`; local `public.oban_jobs` and all six Rindle-owned tables exist. [VERIFIED: `mix ecto.migrations`] [VERIFIED: Repo catalog probe] | Code must preserve legacy history compatibility and add a new marker path without requiring data migration for existing adopters. [VERIFIED: 116-CONTEXT.md] |
| Live service config | Host Oban config is read from `Application.get_env(mix_app, Oban)` and doctor checks default Oban repo/queues. [VERIFIED: lib/rindle/ops/runtime_checks.ex] No external UI service config was found in repo for migration ownership. [VERIFIED: codebase grep] | Update doctor copy/checks so Oban readiness is host-owned and `oban_jobs` missing is an actionable setup error. [VERIFIED: 116-CONTEXT.md] |
| OS-registered state | None found; Phase 116 touches Elixir source/docs/tests/package migrations, not launchd/systemd/pm2/task scheduler registration. [VERIFIED: codebase grep] | None. [VERIFIED: codebase grep] |
| Secrets/env vars | No migration-specific secret or env var key is being renamed. Rindle repo ownership is config-based (`config :rindle, :repo, MyApp.Repo`), and generated app smoke uses MinIO/GCS/Mux env vars unrelated to migration naming. [VERIFIED: README.md] [VERIFIED: test/install_smoke/support/generated_app_helper.ex] | No secret migration. Keep docs focused on Repo/Oban ownership. [VERIFIED: 116-CONTEXT.md] |
| Build artifacts | `mix.exs` package files include `priv/repo/migrations`, so legacy files remain in Hex package artifacts. [VERIFIED: mix.exs] Generated install-smoke workspaces are temporary under `/tmp`. [VERIFIED: test/install_smoke/support/generated_app_helper.ex] | Do not remove legacy migration files from package contents; run package/install smoke after changing packaged migration behavior. [VERIFIED: 116-CONTEXT.md] |

**Nothing found in category:** OS-registered state has no phase-relevant registrations. [VERIFIED: codebase grep]

## Common Pitfalls

### Pitfall 1: Marker-Only False Green

**What goes wrong:** A database has the new Rindle marker but is missing a table, column, or partial index. [VERIFIED: 116-CONTEXT.md]
**Why it happens:** Marker writes can drift from actual DDL readiness if a migration partially fails or a manual edit mutates schema. [ASSUMED]
**How to avoid:** Treat marker as one signal and keep catalog checks for all Rindle-owned tables/columns/indexes. [VERIFIED: 116-CONTEXT.md] [CITED: https://www.postgresql.org/docs/current/infoschema-columns.html]
**Warning signs:** Doctor returns OK while runtime queries later raise `undefined_table` or `undefined_column`. [VERIFIED: 116-CONTEXT.md]

### Pitfall 2: Fresh Installs Still Create `oban_jobs`

**What goes wrong:** Generated-app smoke remains green because it still runs the old package path and bundled `CreateObanTables`. [VERIFIED: test/install_smoke/support/generated_app_helper.ex] [VERIFIED: priv/repo/migrations/20260424205942_create_oban_tables.exs]
**Why it happens:** Existing helper scripts run `Ecto.Migrator.run/4` across `Application.app_dir(:rindle, "priv/repo/migrations")`. [VERIFIED: test/install_smoke/support/generated_app_helper.ex]
**How to avoid:** Rewrite generated-app proof to create real host migrations for host marker data, Oban, and Rindle. [VERIFIED: 116-CONTEXT.md]
**Warning signs:** Reports still assert `migration_resolution == :application_app_dir` or `String.ends_with?(rindle_migration_path, "/priv/repo/migrations")`. [VERIFIED: test/install_smoke/generated_app_smoke_test.exs]

### Pitfall 3: Legacy File-History Becomes a Hard Error

**What goes wrong:** Existing adopters get a failing doctor report because fresh module installs do not line up with old packaged file statuses, or old apps have healthy schema but missing local files. [VERIFIED: 116-CONTEXT.md]
**Why it happens:** `RuntimeChecks` currently filters `Ecto.Migrator.migrations/2` statuses into pending/unresolved checks. [VERIFIED: lib/rindle/ops/runtime_checks.ex]
**How to avoid:** Keep stable check IDs but change semantics to hybrid readiness: current marker or healthy legacy catalog should be OK; healthy legacy file drift should be warning/history-only. [VERIFIED: 116-CONTEXT.md]
**Warning signs:** Tests only assert `migration_statuses: []` instead of schema readiness and legacy drift branches. [VERIFIED: test/rindle/ops/runtime_checks_test.exs]

### Pitfall 4: Prefix Readiness Is Deferred Too Far

**What goes wrong:** v1.23 must replace the new migration substrate because Phase 116 hard-coded `public` into new catalog checks. [VERIFIED: 116-CONTEXT.md]
**Why it happens:** Existing catalog queries hard-code `table_schema = 'public'` and `schemaname = 'public'`. [VERIFIED: lib/rindle/ops/runtime_checks.ex] [VERIFIED: test/rindle/domain/migration_test.exs]
**How to avoid:** Parameterize prefix now while keeping the documented default as `public`. [VERIFIED: 116-CONTEXT.md]
**Warning signs:** New helper functions accept `prefix` but tests still only query literal `public` internally. [VERIFIED: codebase grep]

### Pitfall 5: Async-Safety Regression in New Tests

**What goes wrong:** A new `async: true` migration test mutates app env, shared sandbox mode, or global repo state and introduces a CI flake. [VERIFIED: test/async_safety_guard_test.exs]
**Why it happens:** Migration tests often need Repo/database state; Rindle's `DataCase` only uses shared sandbox for non-async tests. [VERIFIED: test/support/data_case.ex]
**How to avoid:** Use `Rindle.DataCase, async: true` only for isolated DB assertions; use `async: false` for generated app, global env mutation, Oban shared processes, or spawned DB work. [VERIFIED: test/support/data_case.ex] [VERIFIED: test/async_safety_guard_test.exs]
**Warning signs:** The async-safety guard reports `application_put_env`, `shared_sandbox`, `global_repo_swap`, or file mutation offenders. [VERIFIED: test/async_safety_guard_test.exs]

## Code Examples

Verified patterns from official and local sources:

### Validate Migration Options

```elixir
# Source: deps/nimble_options + lib/rindle/profile/validator.ex
@schema NimbleOptions.new!(
  version: [type: {:in, [1]}, required: true],
  prefix: [type: :string, default: "public"]
)

defp validate_opts!(opts) when is_list(opts) do
  NimbleOptions.validate!(opts, @schema)
rescue
  error in NimbleOptions.ValidationError ->
    reraise ArgumentError, Exception.message(error), __STACKTRACE__
end
```

NimbleOptions supports `validate!/2`, schema defaults, type validation, and `ValidationError.message/1`. [VERIFIED: deps/nimble_options source]

### Prefix-Aware Table and Index

```elixir
# Source: Ecto.Migration docs
create_if_not_exists table(:media_upload_sessions,
                       primary_key: [name: :id, type: :binary_id],
                       prefix: prefix
                     ) do
  add :state, :string, null: false, default: "initialized"
  add :upload_key, :string, null: false
  add :expires_at, :utc_datetime_usec, null: false
  timestamps(type: :utc_datetime_usec)
end

create_if_not_exists index(:media_upload_sessions, [:expires_at], prefix: prefix)
```

Ecto migration docs state table and index prefixes target a Postgres schema, and indexes on prefixed tables must use the same prefix. [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html]

### Host-Owned Oban Migration

```elixir
# Source: Oban.Migration docs and 116-CONTEXT.md
defmodule MyApp.Repo.Migrations.AddObanJobs do
  use Ecto.Migration

  def up, do: Oban.Migration.up()
  def down, do: Oban.Migration.down(version: 1)
end
```

Rindle docs should show this adjacent to the Rindle migration so ownership is unmistakable. [VERIFIED: 116-UI-SPEC.md]

### Runtime Catalog Preflight

```elixir
# Source: existing RuntimeChecks pattern
started_repo.query(
  """
  SELECT indexdef
  FROM pg_indexes
  WHERE schemaname = $1 AND tablename = $2
  """,
  [prefix, table_name]
)
```

Existing Rindle checks use `pg_indexes` because partial index definitions matter for resumable session readiness. [VERIFIED: lib/rindle/ops/runtime_checks.ex]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Rindle docs teach raw package migration path with `Application.app_dir(:rindle, "priv/repo/migrations")` and `Ecto.Migrator.run/4`. [VERIFIED: README.md] [VERIFIED: guides/getting_started.md] | Oban-style host migration wrapper calling `Rindle.Migration.up/1` / `down/1`. [VERIFIED: 116-CONTEXT.md] | Phase 116. [VERIFIED: .planning/ROADMAP.md] | Removes internal file-layout coupling and prepares future versioned upgrades. [VERIFIED: 116-CONTEXT.md] |
| Rindle bundled migration creates `oban_jobs` through `Oban.Migration.up(version: 12)`. [VERIFIED: priv/repo/migrations/20260424205942_create_oban_tables.exs] | Host app owns `Oban.Migration` and `oban_jobs`; Rindle does not create it. [VERIFIED: 116-CONTEXT.md] | Phase 116. [VERIFIED: .planning/ROADMAP.md] | Removes latent collision with host Oban installations. [VERIFIED: .planning/REQUIREMENTS.md] |
| Doctor treats packaged migration statuses as authoritative. [VERIFIED: lib/rindle/ops/runtime_checks.ex] | Hybrid marker/catalog/legacy/Oban health model. [VERIFIED: 116-CONTEXT.md] | Phase 116. [VERIFIED: .planning/ROADMAP.md] | Fresh `Rindle.Migration` installs and legacy file-history installs can both be healthy. [VERIFIED: 116-CONTEXT.md] |
| Runtime/catalog checks hard-code `public`. [VERIFIED: lib/rindle/ops/runtime_checks.ex] | Prefix-aware query design with default `public`. [VERIFIED: 116-CONTEXT.md] | Phase 116 substrate, v1.23 builds on it. [VERIFIED: .planning/REQUIREMENTS.md] | Avoids replacing the substrate during schema isolation. [VERIFIED: .planning/STATE.md] |

**Deprecated/outdated:**

- Greenfield raw package-path snippets in README/getting-started/upgrading are outdated for fresh installs. [VERIFIED: 116-CONTEXT.md]
- Bundled `CreateObanTables` as authoritative greenfield behavior is outdated and must become non-authoritative/stubbed. [VERIFIED: 116-CONTEXT.md]
- `Ecto.Migrator.migrations/2` as sole health source is outdated for the new marker path. [VERIFIED: 116-CONTEXT.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Architectural tier labels such as API / Backend and Database / Storage are planning taxonomy judgments. [ASSUMED] | Architectural Responsibility Map | Low; task ownership might be worded differently, but implementation files stay the same. |
| A2 | A marker can drift from actual DDL if a migration partially fails or manual schema edits occur. [ASSUMED] | Common Pitfalls | Medium; this justifies catalog checks even when marker exists. |
| A3 | ASVS/STRIDE applicability classifications are security research judgments, not project decisions. [ASSUMED] | Security Domain | Low; mitigations still map to validation, scoped DDL, and actionable errors. |
| A4 | The suggested marker table name `rindle_migration_versions` is a recommendation, not an existing artifact. [ASSUMED] | Open Questions | Low; planner may choose another Rindle-owned name if tests and docs are updated consistently. |
| A5 | Keeping `:create_schema` undocumented unless a focused prefix test needs it is a scope judgment. [ASSUMED] | Open Questions | Medium; v1.23 prefix work may benefit from earlier explicit support. |
| A6 | Shell alternatives can replace `rg`/`git` if those tools are absent. [ASSUMED] | Environment Availability | Low; both tools are available locally. |
| A7 | The 2026-07-31 validity window is a maintenance estimate. [ASSUMED] | Metadata | Low; planner should re-check HexDocs and Hex versions if delayed. |

## Open Questions

1. **Exact marker table name**
   - What we know: Context requires a private Rindle-owned marker that is prefix-aware and not `schema_migrations`. [VERIFIED: 116-CONTEXT.md]
   - What's unclear: The exact name is intentionally left to implementation discretion. [VERIFIED: 116-CONTEXT.md]
   - Recommendation: Use a clearly Rindle-owned private name such as `rindle_migration_versions` and cover it with migration API tests. [ASSUMED]

2. **Whether to accept `:create_schema` in Phase 116**
   - What we know: Context requires `:version` and `:prefix`; it allows considering `:create_schema` only if it prepares v1.23 without widening scope. [VERIFIED: 116-CONTEXT.md]
   - What's unclear: v1.22 default remains `public`, so schema creation is not required for the documented path. [VERIFIED: 116-CONTEXT.md]
   - Recommendation: Keep public docs to `version` only, implement `prefix` support now, and add `create_schema` only if the plan includes a focused prefix test and keeps it undocumented. [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir / Mix | Compile and ExUnit tests. [VERIFIED: mix.exs] | yes [VERIFIED: execution] | Elixir/Mix `1.19.5`, OTP 28. [VERIFIED: execution] | Project supports Elixir `~> 1.15`; CI covers supported cells. [VERIFIED: mix.exs] [VERIFIED: RUNNING.md] |
| PostgreSQL server | Ecto migrations/tests. [VERIFIED: CONTRIBUTING.md] | yes [VERIFIED: `pg_isready`] | Server accepting connections on `/tmp:5432`; `psql` client `14.17`. [VERIFIED: execution] | None for DB tests. [VERIFIED: CONTRIBUTING.md] |
| Node / npm | Brandbook drift gates in `mix ci`. [VERIFIED: mix.exs] | yes [VERIFIED: execution] | Node `20.18.1`, npm `10.8.2`. [VERIFIED: execution] | CI provides Node. [VERIFIED: RUNNING.md] |
| Phoenix installer | Generated-app smoke. [VERIFIED: scripts/install_smoke.sh] | yes [VERIFIED: execution] | `Phoenix installer v1.8.8`. [VERIFIED: execution] | `scripts/install_smoke.sh` installs archive if missing. [VERIFIED: scripts/install_smoke.sh] |
| MinIO | Generated-app package consumer smoke for non-GCS profiles. [VERIFIED: scripts/install_smoke.sh] | not currently responding on port 9000. [VERIFIED: curl probe] | local service absent. [VERIFIED: curl probe] | `scripts/ensure_minio.sh` downloads/starts local MinIO for localhost. [VERIFIED: scripts/ensure_minio.sh] |
| Docker | Optional local service/test support. [VERIFIED: RUNNING.md] | yes [VERIFIED: execution] | Docker `29.5.2`. [VERIFIED: execution] | `scripts/ensure_minio.sh` can bootstrap without Docker. [VERIFIED: scripts/ensure_minio.sh] |
| libvips (`vips`) | Full image processing smoke. [VERIFIED: RUNNING.md] | no [VERIFIED: execution] | missing. [VERIFIED: execution] | Install via RUNNING.md matrix, or run focused migration/docs tests without image variant processing. [VERIFIED: RUNNING.md] |
| FFmpeg | AV/generated smoke when video paths run. [VERIFIED: RUNNING.md] | yes [VERIFIED: execution] | FFmpeg `8.0.1`. [VERIFIED: execution] | Install per RUNNING.md if absent. [VERIFIED: RUNNING.md] |
| ripgrep / git | Research/planning inspection. [VERIFIED: execution] | yes [VERIFIED: execution] | `rg 15.1.0`, git `2.41.0`. [VERIFIED: execution] | Use shell alternatives if absent. [ASSUMED] |

**Missing dependencies with no fallback:**

- None for focused Phase 116 planning and unit/docs proof. [VERIFIED: environment audit]

**Missing dependencies with fallback:**

- MinIO is not live, but `scripts/ensure_minio.sh` bootstraps it for generated install smoke. [VERIFIED: scripts/ensure_minio.sh]
- `vips` is missing locally; focused migration/docs tests do not require it, while full image smoke should install libvips per `RUNNING.md`. [VERIFIED: execution] [VERIFIED: RUNNING.md]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit through Mix; local Mix `1.19.5`. [VERIFIED: `mix help test`] [VERIFIED: execution] |
| Config file | `test/test_helper.exs`; Ecto sandbox manual mode for `Rindle.Repo` and canonical adopter repo. [VERIFIED: test/test_helper.exs] |
| Quick run command | `mix test test/install_smoke/docs_parity_test.exs test/rindle/domain/migration_test.exs test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_status_test.exs test/rindle/doctor_test.exs test/rindle/runtime_status_task_test.exs --seed 0` [VERIFIED: existing test files] |
| Full suite command | `mix ci` for PR gate parity; `bash scripts/install_smoke.sh image` for generated-app package proof. [VERIFIED: CONTRIBUTING.md] [VERIFIED: scripts/install_smoke.sh] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| MIGRATE-01 | `Rindle.Migration.up/1` creates/upgrades Rindle-owned schema idempotently with pinned version and default `public` prefix. [VERIFIED: .planning/REQUIREMENTS.md] | unit/integration | `mix test test/rindle/migration_test.exs --seed 0` | no - Wave 0. [VERIFIED: `rg --files`] |
| MIGRATE-01 | `Rindle.Migration.down/1` drops only Rindle-owned tables/marker in reverse order and leaves `oban_jobs`. [VERIFIED: 116-CONTEXT.md] | unit/integration | `mix test test/rindle/migration_test.exs --seed 0` | no - Wave 0. [VERIFIED: `rg --files`] |
| MIGRATE-01 | Docs show compact host migration and reject raw greenfield package path. [VERIFIED: 116-UI-SPEC.md] | docs parity | `mix test test/install_smoke/docs_parity_test.exs --seed 0` | yes. [VERIFIED: test/install_smoke/docs_parity_test.exs] |
| MIGRATE-01 | Doctor accepts new marker/catalog healthy install and legacy file-history healthy install. [VERIFIED: 116-CONTEXT.md] | unit | `mix test test/rindle/ops/runtime_checks_test.exs test/rindle/doctor_test.exs --seed 0` | yes. [VERIFIED: test/rindle/ops/runtime_checks_test.exs] [VERIFIED: test/rindle/doctor_test.exs] |
| MIGRATE-01 | Runtime status preflights missing Rindle tables with actionable setup error. [VERIFIED: 116-CONTEXT.md] | unit | `mix test test/rindle/ops/runtime_status_test.exs test/rindle/runtime_status_task_test.exs --seed 0` | yes. [VERIFIED: test/rindle/ops/runtime_status_test.exs] [VERIFIED: test/rindle/runtime_status_task_test.exs] |
| MIGRATE-02 | Fresh generated-app install has separate Oban migration and Rindle migration; Rindle path does not create `oban_jobs`. [VERIFIED: 116-CONTEXT.md] | smoke/integration | `bash scripts/install_smoke.sh image` | yes helper/test; needs update. [VERIFIED: scripts/install_smoke.sh] [VERIFIED: test/install_smoke/support/generated_app_helper.ex] |
| MIGRATE-02 | Bundled Oban migration file stays packaged but is non-authoritative/no-op. [VERIFIED: 116-CONTEXT.md] | unit/package proof | `mix test test/install_smoke/package_metadata_test.exs test/rindle/migration_test.exs --seed 0` | package test exists; migration test Wave 0. [VERIFIED: test/install_smoke/package_metadata_test.exs] |

### Sampling Rate

- **Per task commit:** Run the focused file touched plus docs parity when docs change. [VERIFIED: RUNNING.md]
- **Per wave merge:** Run the quick run command above. [VERIFIED: existing tests]
- **Phase gate:** Run `mix ci`; run `bash scripts/install_smoke.sh image` after generated-app helper changes; run broader profiles only if touched surfaces require them. [VERIFIED: CONTRIBUTING.md] [VERIFIED: scripts/install_smoke.sh]

### Wave 0 Gaps

- [ ] `test/rindle/migration_test.exs` - covers MIGRATE-01/MIGRATE-02 migration API, idempotency, version validation, marker behavior, prefix/default public, `down/1`, and no `oban_jobs` creation. [VERIFIED: no file found]
- [ ] Update `test/install_smoke/docs_parity_test.exs` - covers README/getting-started/upgrading new snippets and rejects raw greenfield package path. [VERIFIED: existing file]
- [ ] Update `test/install_smoke/support/generated_app_helper.ex` - writes host Oban migration and Rindle migration instead of package-path runner. [VERIFIED: existing file]
- [ ] Extend `test/rindle/ops/runtime_checks_test.exs`, `test/rindle/doctor_test.exs`, `test/rindle/ops/runtime_status_test.exs`, and `test/rindle/runtime_status_task_test.exs` for hybrid migration health and setup failures. [VERIFIED: existing files]

**Baseline verification already run during research:**

- `mix test test/install_smoke/docs_parity_test.exs --seed 0` -> 29 tests, 0 failures. [VERIFIED: execution]
- `mix test test/rindle/domain/migration_test.exs --seed 0` -> 11 tests, 0 failures. [VERIFIED: execution]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no [ASSUMED] | No auth boundary changes; keep migration commands host-admin/operator scoped. [VERIFIED: 116-CONTEXT.md] |
| V3 Session Management | no [ASSUMED] | No web session or browser workflow. [VERIFIED: 116-UI-SPEC.md] |
| V4 Access Control | limited [ASSUMED] | Destructive `down/1` must be explicit and scoped to Rindle-owned tables only; do not drop host-owned `oban_jobs`. [VERIFIED: 116-CONTEXT.md] |
| V5 Input Validation | yes [ASSUMED] | Validate `version`, `prefix`, and unknown options with NimbleOptions and raise clear errors. [VERIFIED: 116-CONTEXT.md] [VERIFIED: deps/nimble_options source] |
| V6 Cryptography | no [ASSUMED] | No new crypto; do not alter signed delivery, webhook HMAC, or storage-secret flows. [VERIFIED: codebase grep] |

### Known Threat Patterns for Elixir/Ecto Migration Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Wrong schema/prefix mutates host tables. [ASSUMED] | Tampering [ASSUMED] | Validate `prefix`, pass it consistently to table/reference/index/catalog calls, and default to `public`. [VERIFIED: 116-CONTEXT.md] [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html] |
| Rollback drops `oban_jobs` or unrelated host tables. [VERIFIED: 116-CONTEXT.md] | Tampering / Denial of Service [ASSUMED] | `down/1` drops only Rindle-owned tables and marker objects in reverse dependency order. [VERIFIED: 116-CONTEXT.md] |
| Doctor/runtime emits raw DB exceptions instead of setup guidance. [VERIFIED: 116-CONTEXT.md] | Information Disclosure / Repudiation [ASSUMED] | Preflight table readiness and return bounded actionable error copy. [VERIFIED: 116-CONTEXT.md] |
| Legacy history repair instructions cause data loss. [VERIFIED: 116-CONTEXT.md] | Tampering [ASSUMED] | Warn/history-only for healthy legacy drift; never tell adopters to delete/replay applied legacy migrations. [VERIFIED: 116-CONTEXT.md] |
| Invalid migration options silently pick latest or wrong version. [VERIFIED: 116-CONTEXT.md] | Tampering [ASSUMED] | Docs pin `version: 1`; invalid/unknown options raise loudly. [VERIFIED: 116-CONTEXT.md] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/116-versioned-rindle-migration-module/116-CONTEXT.md` - locked user decisions, scope, canonical refs, and rejected alternatives. [VERIFIED: file read]
- `.planning/phases/116-versioned-rindle-migration-module/116-UI-SPEC.md` - locked documentation UX/copy contract and no-frontend/no-generator boundary. [VERIFIED: file read]
- `.planning/REQUIREMENTS.md` - MIGRATE-01 and MIGRATE-02 requirements. [VERIFIED: file read]
- `.planning/STATE.md` and `.planning/ROADMAP.md` - current phase status, release-train invariants, and Phase 116 success criteria. [VERIFIED: file read]
- Codebase files: `priv/repo/migrations/*.exs`, `lib/rindle/ops/runtime_checks.ex`, `lib/rindle/ops/runtime_status.ex`, `test/install_smoke/docs_parity_test.exs`, `test/install_smoke/support/generated_app_helper.ex`, `test/rindle/ops/runtime_checks_test.exs`, `test/async_safety_guard_test.exs`. [VERIFIED: codebase grep]

### Secondary (MEDIUM confidence)

- Ecto.Migration official docs - idempotent DDL helpers, prefixes, primary keys, `execute/2`, migration callbacks. [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html]
- Oban.Migration official docs - host wrapper migration, idempotent versioned migrations, prefix and `create_schema` options. [CITED: https://oban.hexdocs.pm/Oban.Migration.html]
- NimbleOptions official docs/source - option schema validation and `ValidationError`. [CITED: https://nimble-options.hexdocs.pm/] [VERIFIED: deps/nimble_options source]
- PostgreSQL current docs - information_schema overview, `columns`, and `tables` views. [CITED: https://www.postgresql.org/docs/current/information-schema.html] [CITED: https://www.postgresql.org/docs/current/infoschema-columns.html] [CITED: https://www.postgresql.org/docs/current/infoschema-tables.html]
- Hex registry metadata from `mix hex.info` for `ecto_sql`, `oban`, `nimble_options`, and `postgrex`. [VERIFIED: execution]

### Tertiary (LOW confidence)

- ASVS/STRIDE applicability classifications and architecture tier labels are researcher judgments. [ASSUMED]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - all packages are existing locked dependencies and were checked against Hex metadata. [VERIFIED: mix.lock] [VERIFIED: `mix hex.info`]
- Architecture: HIGH for codebase seams and locked direction; MEDIUM for exact internal helper decomposition. [VERIFIED: 116-CONTEXT.md] [VERIFIED: codebase grep]
- Pitfalls: HIGH for legacy/Oban/docs/runtime pitfalls; MEDIUM for marker-drift risk mechanics. [VERIFIED: 116-CONTEXT.md] [ASSUMED]
- Validation: HIGH for existing test infrastructure; MEDIUM for generated-app smoke local availability because MinIO/libvips are not currently live/installed. [VERIFIED: execution] [VERIFIED: scripts/ensure_minio.sh]

**Research date:** 2026-07-01 [VERIFIED: current_date]
**Valid until:** 2026-07-31 for Ecto/Oban/NimbleOptions guidance; re-check HexDocs and Hex versions if planning starts after that. [ASSUMED]
