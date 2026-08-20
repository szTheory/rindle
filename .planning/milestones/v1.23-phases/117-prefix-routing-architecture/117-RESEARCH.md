# Phase 117: Prefix Routing Architecture - Research

**Researched:** 2026-08-08  
**Domain:** Ecto/PostgreSQL schema routing for Rindle domain data  
**Confidence:** HIGH

## User Constraints

No `117-*-CONTEXT.md` exists. The following scope is locked by the approved roadmap and requirements:

### Locked Decisions

- Rindle's fresh-install default is the Postgres `rindle` schema; callers must not add prefixes. [VERIFIED: .planning/REQUIREMENTS.md]
- `prefix: "public"` is the one explicit legacy-compatibility opt-out, paired with the matching Rindle migration. [VERIFIED: .planning/REQUIREMENTS.md]
- Phase 117 must choose exactly one public routing model: a compile-time schema macro or a runtime helper; mixed semantics are not acceptable. [VERIFIED: .planning/ROADMAP.md]
- Oban remains host-owned and independently configured; Phase 117 does not route or manage `oban_jobs`. [VERIFIED: .planning/REQUIREMENTS.md]

### the agent's Discretion

- Select the lower-risk routing model and describe the exact configuration, test, and code-boundary implications. [VERIFIED: phase assignment]

### Deferred Ideas (OUT OF SCOPE)

- `search_path` routing, arbitrary/per-tenant schemas, Oban schema changes, and copy/dual-write migration are out of scope. [VERIFIED: .planning/REQUIREMENTS.md]

## Project Constraints (from AGENTS.md)

- Keep changes focused and preserve green-main merge-blocking lanes (Quality/coveralls, Integration, Proof, Package Consumer, and Adopter). [VERIFIED: AGENTS.md]
- Run the relevant checks named by `RUNNING.md`; use PR-first execution for serious milestone work. [VERIFIED: AGENTS.md]
- Update `.planning/PROJECT.md` only when intentionally changing product scope or shipped claims. [VERIFIED: AGENTS.md]
- Run `./scripts/maintainer/repo_hygiene_check.sh` before release preparation. [VERIFIED: AGENTS.md]

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PREFIX-01 | Fresh installs default all Rindle-owned state to `rindle`, without caller query prefixes. | A `Rindle.Schema` macro sets `@schema_prefix` for all six domain schemas, so built structs and schema-backed queries carry `rindle`. |
| PREFIX-02 | A documented `public` compatibility configuration retains normal behavior. | The same compile-time config key drives both `Rindle.Schema` and the host migration call; `"public"` is an explicit build/release choice. |
| PREFIX-03 | Facades, workers, Multi steps, and loaded/new structs never silently fall back to `public`. | Schema metadata covers ordinary queries, `Ecto.Multi` changesets, loaded/new structs, and associations/preloads; decoy-public integration proof detects escapes. |
</phase_requirements>

## Summary

**Primary recommendation:** Use a compile-time `Rindle.Schema` macro that sets `@schema_prefix` from one compile-time `:rindle_prefix` setting (default `"rindle"`), and make the host migration use that same resolved prefix. Do **not** create a runtime per-query routing helper. [CITED: https://ecto.hexdocs.pm/Ecto.Schema.html] [VERIFIED: codebase grep]

This is the lowest-risk architecture because Rindle has six mutually-associated Ecto schemas and many direct Repo calls spread across the public facade, upload broker, streaming surface, admin queries, operations, and Oban workers. Ecto documents that `@schema_prefix` is used by every struct built from that schema and by schema-backed `from`/`join` queries. That supplies a single invariant at the schema boundary rather than depending on every call site to remember an option. [CITED: https://ecto.hexdocs.pm/Ecto.Schema.html] [VERIFIED: codebase grep]

The cost is intentional: `:rindle_prefix` becomes a compile/release configuration decision, not a mutable runtime knob. An adopter choosing legacy `public` must set it in compile-time application config and rebuild/release with a migration using the same prefix; changing only runtime environment configuration is invalid. The configuration should accept only the two supported values, `"rindle"` and `"public"`, which keeps v1.23 out of arbitrary-schema/tenancy territory. [VERIFIED: .planning/REQUIREMENTS.md] [ASSUMED]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Route six Rindle Ecto schemas | API / Backend | Database / Storage | Ecto schema metadata owns the source qualification for Rindle rows. [CITED: https://ecto.hexdocs.pm/Ecto.Schema.html] |
| Create/move Rindle tables | Database / Storage | API / Backend | Host migrations create or move tables with the same selected prefix. [VERIFIED: lib/rindle/migration/v1.ex] |
| Execute facade, worker, and Multi operations | API / Backend | Database / Storage | Those paths should use schema-backed queries/changesets rather than manually select schemas. [VERIFIED: codebase grep] |
| Configure Oban prefix | Host infrastructure | Database / Storage | Oban is independent host-owned infrastructure, not a Rindle routing concern. [VERIFIED: .planning/REQUIREMENTS.md] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Ecto / Ecto SQL | 3.13.5 locked (3.14.1 latest) | Schema metadata, queries, changesets, `Ecto.Multi`, and Postgres access | Existing project dependency; Ecto natively supports schema prefixes and base-schema macros. [VERIFIED: mix.lock; mix hex.info ecto] [CITED: https://ecto.hexdocs.pm/Ecto.Schema.html] |
| PostgreSQL | 14.17 available | Explicit schemas and qualified relation resolution | Existing adapter/runtime; no new DB product is needed. [VERIFIED: `psql --version`; lib/rindle/repo.ex] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Oban | 2.21.1 locked | Existing background execution | Workers query Rindle schemas through their Ecto schemas; Oban jobs retain the host's own configuration. [VERIFIED: mix.lock; lib/rindle/workers/process_variant.ex] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Compile-time `Rindle.Schema` macro | Runtime `Rindle.Repo`/query helper passing `prefix: Config.rindle_prefix()` | Runtime switching is attractive, but every `Repo.get/all/one/preload`, direct changeset write, `Ecto.Multi` callback, and raw query must be wrapped correctly; one omission silently reaches `public`. [CITED: https://ecto.hexdocs.pm/Ecto.Repo.html] [VERIFIED: codebase grep] |

**Installation:** None. Phase 117 must not add dependencies. [VERIFIED: mix.exs]

## Architecture Patterns

### System Architecture Diagram

```text
Host compile-time config
  :rindle_prefix => "rindle" | "public"
                 |
                 v
      Rindle.Schema __using__/1
                 |
       @schema_prefix in all six schemas
                 |
      +----------+-----------+-----------+
      v          v           v           v
 Facade/Broker  Workers    Admin/Ops  Ecto.Multi changesets
      \          |           |           /
       \---------+-----------+----------/
                 v
          Ecto Repo / PostgreSQL
                 |
        selected.rindle_* tables

Host Oban config ----------------------> independently configured oban_jobs
```

The selected prefix is attached before data-path code runs; no request, job, or transaction option is responsible for propagating it. The migration and schema config must be asserted equal by documentation and tests. [CITED: https://ecto.hexdocs.pm/Ecto.Schema.html] [VERIFIED: lib/rindle/migration.ex]

### Recommended Project Structure

```text
lib/rindle/
├── schema.ex                  # new compile-time Ecto base macro and prefix validation
├── config.ex                  # one resolved Rindle prefix; independent Oban prefix remains runtime diagnostics input
└── domain/
    ├── media_asset.ex         # use Rindle.Schema
    ├── media_attachment.ex    # use Rindle.Schema
    ├── media_variant.ex       # use Rindle.Schema
    ├── media_upload_session.ex# use Rindle.Schema
    ├── media_processing_run.ex# use Rindle.Schema
    └── media_provider_asset.ex# use Rindle.Schema
```

### Pattern 1: Prefix-bearing base-schema macro

**What:** Add an internal `Rindle.Schema` `__using__/1` macro which calls `use Ecto.Schema`, preserves the existing binary primary/foreign-key defaults, and assigns `@schema_prefix` from `Application.compile_env(:rindle, :rindle_prefix, "rindle")`. Every one of the six Rindle domain schemas uses it. [CITED: https://ecto.hexdocs.pm/Ecto.Schema.html] [VERIFIED: lib/rindle/domain/media_asset.ex]

**When to use:** Any schema that maps a Rindle-owned table. Do not use it for host-owned schemas, test fixtures that intentionally model host tables, or Oban. [VERIFIED: .planning/REQUIREMENTS.md]

**Example:**

```elixir
# Source: https://ecto.hexdocs.pm/Ecto.Schema.html
defmodule Rindle.Schema do
  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
      @schema_prefix Application.compile_env(:rindle, :rindle_prefix, "rindle")
    end
  end
end

defmodule Rindle.Domain.MediaAsset do
  use Rindle.Schema
  schema "media_assets" do
    has_many :variants, Rindle.Domain.MediaVariant, foreign_key: :asset_id
  end
end
```

The implementation must validate this compile-time value early and fail with a bounded message unless it is `"rindle"` or `"public"`; do not silently coerce blank/invalid values to `public`. This validation recommendation is an inference from the approved two-option product contract. [VERIFIED: .planning/REQUIREMENTS.md] [ASSUMED]

### Pattern 2: Make migration and schema configuration one decision

**What:** Document a single setting and host migration pairing:

```elixir
# config/config.ex -- chosen before compilation/release
config :rindle, :rindle_prefix, "rindle" # default; explicit "public" is compatibility mode

# host migration
def up, do: Rindle.Migration.up(version: 1, prefix: "rindle")
```

The public mode changes both values to `"public"`. Phase 118 owns changing the migration default/provisioning behavior; Phase 117 defines the runtime schema contract it must match. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: lib/rindle/migration.ex]

**Release implication:** release-time `runtime.exs` alone cannot switch the prefix for already-compiled schemas. An attempted mismatch must be a documented unsupported deployment state and later diagnosed rather than silently routed. [CITED: https://ecto.hexdocs.pm/Ecto.Schema.html] [ASSUMED]

### Pattern 3: Let schema metadata route normal data paths

**What:** Retain existing direct `repo.get(MediaAsset, id)`, `from(v in MediaVariant, ...)`, `repo.preload(session, :asset)`, `Multi.insert(changeset)`, and `repo.update(changeset)` calls once the six schemas carry the prefix. [CITED: https://ecto.hexdocs.pm/Ecto.Schema.html] [VERIFIED: lib/rindle.ex; lib/rindle/upload/broker.ex; lib/rindle/workers/promote_asset.ex]

**Coverage rationale:**

| Path | Why macro routing covers it | Concrete existing seam |
|------|-----------------------------|-----------------------|
| Ordinary reads and joins | Ecto applies schema prefix to schema-backed `from` and `join` sources. | `AssetAggregate.recompute/2`, owner-erasure planner, admin queries. [CITED: https://ecto.hexdocs.pm/Ecto.Schema.html] [VERIFIED: lib/rindle/domain/asset_aggregate.ex; lib/rindle/internal/owner_erasure.ex] |
| Loaded structs and writes | Built/loaded structs carry schema metadata; Repo updates/deletes use that struct metadata. | `repo.get` then `repo.update/delete` in broker and workers. [CITED: https://ecto.hexdocs.pm/Ecto.Schema.html] [VERIFIED: lib/rindle/upload/broker.ex; lib/rindle/workers/purge_storage.ex] |
| Newly created structs | `%MediaAsset{}`, `%MediaVariant{}`, `%MediaAttachment{}`, and analogous changesets are born with the schema prefix. | Broker initiation, facade attach, streaming direct upload, worker variant planning. [CITED: https://ecto.hexdocs.pm/Ecto.Schema.html] [VERIFIED: lib/rindle.ex; lib/rindle/streaming.ex; lib/rindle/workers/promote_asset.ex] |
| Associations and preloads | Both associated schemas declare the same selected prefix, so Ecto has explicit sources rather than `search_path` resolution. | `repo.preload(session, :asset)` and `MediaAsset` has-many associations. [CITED: https://ecto.hexdocs.pm/Ecto.Schema.html] [VERIFIED: lib/rindle/domain/media_asset.ex; lib/rindle/upload/broker.ex] |
| `Ecto.Multi` | Multi inserts/updates receive prefix-bearing changesets, and callbacks use prefix-bearing schema queryables. | `Rindle.attach/4`, `Rindle.detach/3`, broker verification, streaming creation, owner erasure. [CITED: https://ecto.hexdocs.pm/Ecto.Schema.html] [VERIFIED: lib/rindle.ex; lib/rindle/upload/broker.ex; lib/rindle/streaming.ex; lib/rindle/internal/owner_erasure.ex] |
| Background work | Oban worker code gets/updates the same domain schema modules. | Process, promote, purge, Mux-sync workers. [VERIFIED: lib/rindle/workers] |

### Anti-Patterns to Avoid

- **Runtime helper plus schema macro:** `Repo` options only apply where a source has no existing prefix; combining a runtime query prefix with schema metadata creates priority-dependent behavior rather than one model. [CITED: https://ecto.hexdocs.pm/Ecto.Repo.html]
- **Implicit `search_path`:** an unqualified relation resolves to the first matching table, and a schema in `search_path` trusts principals with `CREATE` privilege there. Use Ecto-qualified schema sources instead. [CITED: https://www.postgresql.org/docs/current/ddl-schemas.html]
- **Leaving `Config.rindle_prefix/0` as a runtime fallback to `public`:** this conflicts with the new default and allows diagnostics/migration config to disagree with compiled schema metadata. [VERIFIED: lib/rindle/config.ex] [ASSUMED]
- **Passing transaction-level `prefix:` and expecting it to propagate:** explicit query and schema prefixes have their own resolution semantics; transaction scopes do not make all existing calls safe by themselves. [CITED: https://ecto.hexdocs.pm/Ecto.Repo.html] [ASSUMED]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Prefix propagation | Custom wrapper around every Repo function/Multi callback | `@schema_prefix` in a shared Ecto base-schema macro | Ecto owns query, struct, association, and preload metadata; a wrapper has a large omission surface in this codebase. [CITED: https://ecto.hexdocs.pm/Ecto.Schema.html] [VERIFIED: codebase grep] |
| Schema lookup | Connection-level `search_path` mutation | Explicit Ecto schema prefixes | PostgreSQL search-path lookup can select like-named decoy tables. [CITED: https://www.postgresql.org/docs/current/ddl-schemas.html] |
| Data-path behavior | A second generic prefix API | One `:rindle_prefix` compile setting, with `"public"` compatibility | One model is a roadmap acceptance criterion; arbitrary schema management is out of scope. [VERIFIED: .planning/ROADMAP.md; .planning/REQUIREMENTS.md] |

**Key insight:** Ecto's schema metadata is the existing framework-level solution to the exact hard case: it reaches newly constructed structs and association loads where a runtime query helper is easiest to omit. [CITED: https://ecto.hexdocs.pm/Ecto.Schema.html]

## Common Pitfalls

### Pitfall 1: Compile/runtime split-brain

**What goes wrong:** schemas compiled for `rindle` but `Config.rindle_prefix/0`, a host migration, or diagnostics read `public` from runtime config.  
**Why it happens:** current `Config.rindle_prefix/0` resolves at runtime and defaults to `public`, while `@schema_prefix` is a schema attribute evaluated while compiling. [VERIFIED: lib/rindle/config.ex] [CITED: https://ecto.hexdocs.pm/Ecto.Schema.html]  
**How to avoid:** centralize the resolved supported prefix in `Rindle.Schema`; make `Config.rindle_prefix/0` reflect the same compile-time decision or retire it from normal routing; update migration/docs in the following phase.  
**Warning signs:** `MediaAsset.__schema__(:prefix)` differs from config/doctor expected prefix, or a test only changes `Application.put_env/3` and expects compiled schemas to follow. [CITED: https://ecto.hexdocs.pm/Ecto.Schema.html] [ASSUMED]

### Pitfall 2: Decoy `public` tables mask missing coverage

**What goes wrong:** a test passes because the public copy of a table is queried after a routing omission.  
**Why it happens:** PostgreSQL resolves unqualified relations through `search_path`, normally including `public`. [CITED: https://www.postgresql.org/docs/current/ddl-schemas.html]  
**How to avoid:** create conflicting/decoy public Rindle tables with distinguishable fixtures in prefix integration tests; assert results and structs originate from the configured schema.  
**Warning signs:** tests create only `rindle` tables or use fixtures whose data is identical in both schemas. [ASSUMED]

### Pitfall 3: Testing compile-time public compatibility by mutating runtime config

**What goes wrong:** tests claim public mode works, but only runtime diagnostic config changed; domain schema modules remain compiled for another prefix.  
**Why it happens:** Ecto reads `@schema_prefix` during schema compilation. [CITED: https://ecto.hexdocs.pm/Ecto.Schema.html]  
**How to avoid:** test the compile-time macro value directly in focused tests, and prove public compatibility in a separately compiled generated/consumer app (Phase 120) or controlled compile environment.  
**Warning signs:** `Application.put_env(:rindle, :rindle_prefix, "public")` without recompiling before a `%MediaAsset{}` assertion. [ASSUMED]

### Pitfall 4: Accidentally prefixing Oban

**What goes wrong:** a broad Repo wrapper or global Repo prefix routes Oban operations into `rindle`.  
**Why it happens:** Rindle workers share the repo with host Oban, but the tables have different owners. [VERIFIED: test/test_helper.exs; .planning/REQUIREMENTS.md]  
**How to avoid:** schema-level prefixing only for the six Rindle schemas; do not alter `Rindle.Repo` defaults or Oban configuration.  
**Warning signs:** changes to `Rindle.Repo`, `{Oban, ...}` setup, or any `oban_jobs` migration in Phase 117. [VERIFIED: lib/rindle/repo.ex; test/test_helper.exs]

## Code Examples

Verified patterns from official sources:

### Assert schema metadata and built-struct routing

```elixir
# Source: https://ecto.hexdocs.pm/Ecto.Schema.html
assert Rindle.Domain.MediaAsset.__schema__(:prefix) == "rindle"
assert %Rindle.Domain.MediaAsset{}.__meta__.prefix == "rindle"
assert %Rindle.Domain.MediaUploadSession{}.__meta__.prefix == "rindle"
```

### Decoy-public end-to-end test shape

```elixir
# Test setup creates distinguishable rows in both schemas; runtime code gets no prefix argument.
insert_fixture(prefix: "public", storage_key: "decoy-public")
asset = insert_fixture(prefix: "rindle", storage_key: "selected-rindle")

assert {:ok, returned} = Rindle.attach(asset.id, owner, "avatar")
assert returned.__meta__.prefix == "rindle"
assert selected_storage_key_from_rindle_path() == "selected-rindle"
```

The fixture helper is illustrative; planner work must reuse the repository's migration/sandbox fixture patterns rather than introduce a generic production routing helper. [VERIFIED: test/rindle/migration_test.exs; test/test_helper.exs] [ASSUMED]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Runtime `Config.rindle_prefix/0`, default `public`, used primarily by runtime-status queries | One compile-time domain-schema prefix, default `rindle`; runtime diagnostics must reflect it | Phase 117 recommendation | Normal domain paths become explicit and prefix-correct by construction. [VERIFIED: lib/rindle/config.ex; lib/rindle/ops/runtime_status.ex] [ASSUMED] |

**Deprecated/outdated:**

- Runtime-only Rindle prefix configuration as the normal data-path router: it cannot provide the same automatic coverage for built structs and associations as schema metadata. [CITED: https://ecto.hexdocs.pm/Ecto.Schema.html] [ASSUMED]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Restrict the v1.23 configuration value to exactly `"rindle"` and `"public"` rather than allow arbitrary safe identifiers. | Summary / Pattern 1 | A later requirement may need a broader configuration API or validation policy. |
| A2 | `Config.rindle_prefix/0` should resolve the compile-time selection (or cease to govern routing) so diagnostics cannot drift. | Architecture Patterns / Pitfall 1 | Phase 119 diagnostics could need an additional explicit runtime expected-prefix input. |
| A3 | Public-mode full behavioral proof is best run in separately compiled consumer/generated-app coverage because runtime mutation cannot change compiled schema metadata. | Pitfall 3 | Test architecture could be more complex than necessary if the suite can safely recompile isolated schemas. |

## Open Questions (RESOLVED)

1. **RESOLVED — Where should the shared compile-time prefix validator live?**
   - What we know: `Rindle.Schema` is the natural single compilation boundary, and `Rindle.Migration.Options` currently permits any non-empty non-NUL string. [VERIFIED: lib/rindle/migration/options.ex]
   - What's unclear: whether Phase 117 should make the setting strict immediately or Phase 118 should own the migration validator change.
   - Resolution: Phase 117 validates the schema macro setting and documents the two values; Phase 118 aligns migration validation/defaulting in the same release sequence.

2. **RESOLVED — How should public compatibility be proved before Phase 120?**
   - What we know: normal unit tests compile Rindle once, and runtime test setup already mutates config for runtime-status tests. [VERIFIED: test/rindle/ops/runtime_status_test.exs]
   - What's unclear: whether the repository has an existing additional Mix environment for isolated compile configuration.
   - Resolution: Phase 117 adds metadata/default-routing proof plus a decoy-table integration path; Phase 120 owns packaged/compiled public consumer proof.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir / Mix | Compile and test Ecto schemas | ✓ | Elixir 1.19.5 / OTP 28 | — [VERIFIED: `elixir --version`; `mix --version`] |
| PostgreSQL | Prefix integration and decoy-schema tests | ✓ | 14.17; local server accepts connections | — [VERIFIED: `psql --version`; `pg_isready`] |
| Ecto / Ecto SQL | Schema-prefix implementation | ✓ | 3.13.5 locked | Existing dependency [VERIFIED: mix.lock] |

**Missing dependencies with no fallback:** None. [VERIFIED: environment audit]

**Missing dependencies with fallback:** None. [VERIFIED: environment audit]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit with Ecto SQL Sandbox [VERIFIED: test/test_helper.exs] |
| Config file | `test/test_helper.exs` and `config/test.exs` [VERIFIED: repository files] |
| Quick run command | `mix test test/rindle/domain/media_schema_test.exs test/rindle/migration_test.exs` |
| Full suite command | `mix coveralls.multiple --type local --type json --slowest 20` [VERIFIED: RUNNING.md] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PREFIX-01 | Six schemas and new structs resolve `rindle` by default; facade round-trip ignores public decoys. | unit + Postgres integration | `mix test test/rindle/domain/media_schema_test.exs test/rindle/prefix_routing_test.exs` | ❌ Wave 0 |
| PREFIX-02 | Compile-configured public mode gives all six schema modules/public migration pairing the public prefix. | compile-config unit + migration integration | `mix test test/rindle/config/prefix_config_test.exs test/rindle/migration_test.exs` | ❌ Wave 0 |
| PREFIX-03 | Facade, broker, workers, Multi, loaded/new structs, preloads and associations hit selected schema with decoy public tables. | Postgres integration | `mix test test/rindle/prefix_routing_test.exs` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** targeted prefix-routing tests plus affected existing module tests.
- **Per wave merge:** `mix test`.
- **Phase gate:** `mix coveralls.multiple --type local --type json --slowest 20` green before verification. [VERIFIED: RUNNING.md]

### Wave 0 Gaps

- [ ] `test/rindle/prefix_routing_test.exs` — decoy-public end-to-end coverage for PREFIX-01 and PREFIX-03.
- [ ] `test/rindle/config/prefix_config_test.exs` — compile-time prefix contract and invalid-value behavior for PREFIX-02.
- [ ] Focused assertions in `test/rindle/domain/media_schema_test.exs` — all six `__schema__(:prefix)` and built-struct metadata values.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No authentication behavior changes in this phase. [VERIFIED: phase scope] |
| V3 Session Management | no | No session mechanism changes; upload-session rows are domain data. [VERIFIED: phase scope] |
| V4 Access Control | yes | Preserve host/Oban separation; Rindle does not broaden access by routing into host schemas. [VERIFIED: .planning/REQUIREMENTS.md] |
| V5 Input Validation | yes | Validate supported prefix configuration at the compile boundary; never construct schema identifiers from per-request input. [ASSUMED] |
| V6 Cryptography | no | No cryptographic operation changes. [VERIFIED: phase scope] |

### Known Threat Patterns for Ecto/Postgres routing

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Search-path shadowing by a like-named public table | Tampering / Elevation of Privilege | Use explicit schema metadata, not `search_path`; create decoy-table tests. [CITED: https://www.postgresql.org/docs/current/ddl-schemas.html] |
| Prefix mismatch routes data to legacy public schema | Tampering / Information Disclosure | One compile-time setting for every domain schema, matching migration config, and mismatch diagnostics in Phase 119. [VERIFIED: .planning/ROADMAP.md] [ASSUMED] |
| Broad prefixing captures host Oban data | Tampering / Denial of Service | Do not set a global Repo prefix or alter Oban config; only Rindle schemas use the macro. [VERIFIED: .planning/REQUIREMENTS.md] |

## Sources

### Primary (HIGH confidence)

- [Ecto.Schema](https://ecto.hexdocs.pm/Ecto.Schema.html) - `@schema_prefix` behavior, built structs, schema-backed queries, and base-schema macro pattern. [CITED: https://ecto.hexdocs.pm/Ecto.Schema.html]
- [Ecto.Repo](https://ecto.hexdocs.pm/Ecto.Repo.html) - Repo `:prefix` precedence and its application only to sources not already prefixed. [CITED: https://ecto.hexdocs.pm/Ecto.Repo.html]
- [PostgreSQL schemas](https://www.postgresql.org/docs/current/ddl-schemas.html) - `search_path` resolution and trusted-schema consequences. [CITED: https://www.postgresql.org/docs/current/ddl-schemas.html]
- Rindle source/config/tests - existing default, six schemas, direct Repo/Multi/worker surfaces, migrations, and test stack. [VERIFIED: codebase grep]

### Secondary (MEDIUM confidence)

- [v1.23 schema-isolation synthesis](../../research/v1.23-SCHEMA-ISOLATION-SYNTHESIS.md) - phase boundary and earlier architecture decision framing. [VERIFIED: .planning/research/v1.23-SCHEMA-ISOLATION-SYNTHESIS.md]

### Tertiary (LOW confidence)

- None; all external factual claims above are cited to primary documentation. [VERIFIED: research audit]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - existing locked Ecto/Postgres/Oban dependencies were inspected and Ecto behavior was checked against official docs.
- Architecture: HIGH - official Ecto prefix semantics directly explain the recommendation, and the repo has a large verified runtime-helper omission surface.
- Pitfalls: MEDIUM - compile/runtime test implications follow Ecto semantics and current test design; exact future test isolation choice remains open.

**Research date:** 2026-08-08  
**Valid until:** 2026-09-07
