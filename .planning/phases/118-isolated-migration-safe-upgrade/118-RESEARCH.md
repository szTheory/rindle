# Phase 118: Isolated Migration & Safe Upgrade - Research

**Researched:** 2026-08-09
**Domain:** PostgreSQL schema provisioning and Ecto host-owned migrations
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Migration API and ownership

- **D-118-01:** Keep the established host-migration wrapper model. Fresh installs call `Rindle.Migration.up(version: 1)`, which defaults to `rindle`; the only explicit compatibility pairing is `prefix: "public"`. Align migration option validation with the Phase 117 two-value compile-time authority (`"rindle" | "public"`), removing the prior arbitrary-prefix contract. — **Reversibility:** one-way — changing the supported configuration/migration pairing after 0.4.0 would break adopter migration and runtime contracts.
- **D-118-02:** Add a deliberately narrow, version-pinned public upgrade primitive such as `Rindle.Migration.move_public_to_rindle(version: 1)`, invoked from an adopter-owned Ecto migration. Rindle owns the exact seven-relation allowlist, preflight, identifier quoting, and move behavior; the host owns when it runs, deployment order, its Ecto ledger, and operational rollback choice. Do not expose a generic `move(from:, to:)` schema-management API. — **Reversibility:** costly — widening or replacing this public upgrade API would expand its support and migration compatibility surface.
- **D-118-03:** Extend the existing `Rindle.Migration.V1` authority rather than creating a parallel migration manager. Reuse its authoritative owned-table list, idempotent DDL, marker behavior, and identifier-quoting boundary.

### Safe move preflight and execution

- **D-118-04:** Allow the public-to-`rindle` move only when all six Rindle tables and `rindle_migration_versions` are present in `public` and none are present in `rindle`. Treat a complete source plus complete/partial target, partial source, invalid/misplaced marker, unexpected Rindle-owned relation, unusable target schema, or inadequate privileges as a bounded failure before issuing any move. A complete `rindle` set with no public set may be an idempotent already-upgraded result; neither complete set is a fresh-install case and must not be guessed at.
- **D-118-05:** Provision `rindle` idempotently before fresh table DDL; use one internal validated-and-quoted identifier boundary for DDL and bound values for catalog checks. Never rely on `search_path`, permissive arbitrary prefixes, `IF EXISTS` to mask mixed state, or dynamically interpolated unvalidated identifiers.
- **D-118-06:** Use `ALTER TABLE ... SET SCHEMA` for the fixed Rindle relation set inside the host migration transaction. It is the narrow data-preserving route because PostgreSQL moves owned indexes, constraints, and sequences with the table. Never enumerate, create, move, drop, or configure `oban_jobs` or the host `schema_migrations` ledger. — **Reversibility:** one-way — the database move changes an adopter's persisted layout and published 0.4.0 migration path.

### Operations, rollback, and developer experience

- **D-118-07:** Document and enforce a maintenance-window posture: operators back up, stop/drain Rindle writers and workers, run the host migration with a transaction-local lock timeout, deploy the compile-time `rindle` build, then verify. Ecto's migration lock serializes migrators but does not quiesce application traffic; PostgreSQL `ALTER TABLE` can require `ACCESS EXCLUSIVE` locking.
- **D-118-08:** Provide a separately guarded reverse primitive such as `move_rindle_to_public(version: 1)` for the host migration's `down`, only while the app is quiesced and state remains exactly reversible. It must not drop the `rindle` schema. `Rindle.Migration.down/1` remains destructive and must never be presented as an upgrade rollback. — **Reversibility:** one-way — safe use depends on backup, no post-move writes/later migrations, and redeploying the prior public-compiled release.
- **D-118-09:** Make error and docs copy calm, concrete, and operator-directed: state what was found, what Rindle will not touch, and the one next action. Use verbs such as “prepare maintenance window,” “move Rindle tables,” and “verify Rindle schema”; do not promise a seamless or automatic live migration. The adopter job is a safe, copy-pasteable host migration—not a migration DSL or hidden library state.

### Proof boundary and handoffs

- **D-118-10:** Prove fresh `rindle` provisioning, explicit `public` compatibility, populated relational move integrity (rows, foreign keys, indexes, marker), all refusal-state categories, injected transaction failure, lock contention/timeout, and untouched `public.oban_jobs` plus host ledger. Keep the normal public-compiled test suite stable and use an isolated/default-build proof for fresh default provisioning.
- **D-118-11:** Update migration API documentation and the migration snippets/parity expectations made false by the default flip in this phase. Phase 120 retains packed generated-app/Cohort proof, complete release-facing documentation parity, and 0.4.0 release notes; Phase 119 retains separate-prefix diagnostics and raw-SQL/Oban boundary hardening.

### the agent's Discretion

- Pick exact function/module names, internal catalog-query shape, lock-timeout value/configuration pattern, and bounded error wording, provided they preserve the locked narrow API, state machine, and ownership boundary above.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MIGRATE-01 | Versioned migration provisions the selected schema before idempotently creating Rindle tables and marker state. | Default `rindle` validation, qualified idempotent `CREATE SCHEMA IF NOT EXISTS`, then existing V1 DDL. |
| MIGRATE-02 | Host-owned public-to-`rindle` upgrade moves exactly seven owned relations without data/integrity loss. | Fixed allowlist, catalog preflight, transaction-local lock timeout, ordered `ALTER TABLE … SET SCHEMA`. |
| MIGRATE-03 | Mixed/incomplete/privilege-inadequate states fail with bounded guidance and truthful operations. | Explicit state classifier, privilege preflight, no `IF EXISTS` masking, maintenance and guarded-down documentation. |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- Keep edits focused and run the checks named by `RUNNING.md` for the change. [VERIFIED: codebase grep]
- Maintain merge-blocking CI health (Quality/coveralls, Integration, Proof, Package Consumer, Adopter) and use PR-first execution for serious feature work. [VERIFIED: codebase grep]
- Update `.planning/PROJECT.md` only when intentionally changing product scope or shipped claims. [VERIFIED: codebase grep]
- Do not change the release-train CI invariants, and run `./scripts/maintainer/repo_hygiene_check.sh` before release preparation. [VERIFIED: codebase grep]

## Summary

Phase 118 is an extension of the already-public `Rindle.Migration` wrapper, not a new migrator. The codebase already centralizes the six domain-table names and marker in `Rindle.Migration.V1`; its current default and permissive arbitrary-prefix validation are the exact seams to change. Make `up(version: 1)` validate the Phase 117 authority and default to `rindle`, create that schema idempotently with the existing internal quoting boundary, then reuse the current V1 DDL/marker path. [VERIFIED: codebase grep]

The upgrade must remain a host Ecto migration that invokes a pinned Rindle helper. PostgreSQL documents that `ALTER TABLE … SET SCHEMA` moves a table together with its associated indexes, constraints, and column-owned sequences; it also requires table ownership and `CREATE` on the target schema. A complete catalog/privilege preflight followed by a transaction-contained fixed seven-table move is therefore the narrow safe design. [CITED: https://www.postgresql.org/docs/current/sql-altertable.html]

The main planning risk is treating Ecto's migrator serialization as traffic quiescence. The migration lock prevents simultaneous migrators, but `ALTER TABLE` normally takes `ACCESS EXCLUSIVE`; deploy/runbook copy must require a backup and drained Rindle application/worker traffic, use `SET LOCAL lock_timeout`, and explain that `Rindle.Migration.down/1` is destructive rather than an upgrade rollback. [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html] [CITED: https://www.postgresql.org/docs/current/sql-altertable.html]

**Primary recommendation:** Implement a V1-owned, version-pinned state-machine helper with preflight-before-DDL, fixed validated identifiers, and real PostgreSQL integration tests; never generalize it beyond public ↔ rindle.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Fresh schema provisioning | Database / Storage | API / Backend | PostgreSQL creates the namespace; the library only emits fixed qualified DDL. [CITED: https://www.postgresql.org/docs/current/ddl-schemas.html] |
| Versioned migration dispatch | API / Backend | Database / Storage | `Rindle.Migration` validates/version-dispatches while the host Ecto migration owns execution and ledger. [VERIFIED: codebase grep] |
| Legacy data move | Database / Storage | API / Backend | PostgreSQL performs transactional table relocation; V1 owns the fixed allowlist/preflight. [CITED: https://www.postgresql.org/docs/current/sql-altertable.html] |
| Maintenance/rollback operation | API / Backend | Database / Storage | The host chooses timing and deployment order; the database supplies locking and transaction rollback. [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html] |
| User-facing operator guidance | API / Backend | — | Errors and docs must expose known state and one corrective action without managing host infrastructure. [VERIFIED: 118-CONTEXT.md] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| PostgreSQL | server-dependent; local CLI 14.17 | Schema/catalog DDL and transactional move | `ALTER TABLE … SET SCHEMA` is the native table relocation primitive. [CITED: https://www.postgresql.org/docs/current/sql-altertable.html] |
| Ecto SQL | 3.13.5 lockfile | Host migration execution and transactional DDL | Existing project migration DSL/harness; PostgreSQL migrations run transactionally and support migration callbacks. [VERIFIED: codebase grep] [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html] |
| Postgrex | 0.22.2 lockfile | Bound catalog queries through `Repo.query!` | Existing PostgreSQL adapter for the project. [VERIFIED: codebase grep] |
| NimbleOptions | 1.1.1 lockfile | Public option boundary | Existing `Migration.Options` implementation; narrow its prefix enum rather than adding a validator. [VERIFIED: codebase grep] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ExUnit / Ecto SQL Sandbox | project test stack | Live PostgreSQL integration proof | Serial migration tests and isolated schemas only. [VERIFIED: codebase grep] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Fixed V1 public-to-rindle helper | Generic `move(from:, to:)` API | Rejected by locked scope: generic schemas create an unbounded support/security surface. [VERIFIED: 118-CONTEXT.md] |
| `ALTER TABLE … SET SCHEMA` | Copy/dual-write cutover | Rejected by locked scope: it adds cutover/data-divergence risk and is unnecessary for a bounded maintenance operation. [VERIFIED: 118-CONTEXT.md] |
| Schema-qualified DDL and bound catalog values | `search_path` routing | Rejected: `search_path` selects the first matching schema and writable schemas on it can influence query behavior. [CITED: https://www.postgresql.org/docs/current/ddl-schemas.html] |

**Installation:** No new external package is needed. [VERIFIED: codebase grep]

## Architecture Patterns

### System Architecture Diagram

```text
Fresh host migration                         Legacy host upgrade migration
--------------------                         -----------------------------
Rindle.Migration.up(version: 1)              prepare maintenance window + backup
        |                                               |
        v                                               v
Options: only "rindle" | "public"              SET LOCAL lock_timeout
        |                                               |
        v                                               v
V1: CREATE SCHEMA IF NOT EXISTS                  V1 preflight catalog + privileges
    (only selected prefix)                                |
        |                                       unsafe/mixed? --yes--> bounded error, no ALTER
        v                                                       |
existing idempotent V1 table + marker DDL                    no
        |                                                       v
        v                                          fixed 7× ALTER TABLE … SET SCHEMA
selected Rindle state only                                  |
                                                          commit
                                                            |
                                                            v
                                                   deploy `rindle`-compiled build; verify

Never traverses: public.oban_jobs, host schema_migrations, arbitrary schemas.
```

### Recommended Project Structure

```text
lib/rindle/
├── migration.ex           # public pinned up/down/move API and module docs
└── migration/
    ├── options.ex         # two-prefix public validation boundary
    └── v1.ex              # fixed relation authority, quoted SQL, preflight and moves
test/rindle/
└── migration_test.exs     # serial live-Postgres DDL, move, refusal, lock/transaction tests
```

### Pattern 1: V1 as the sole owned-relation authority

**What:** Keep `@rindle_tables`, `marker_table/0`, and the ordered move list in `Rindle.Migration.V1`; derive all catalog preflight and DDL targets from them. [VERIFIED: codebase grep]

**When to use:** Every fresh install, forward move, reverse move, catalog assertion, and test fixture in this phase. [VERIFIED: 118-CONTEXT.md]

**Implementation guidance:** Add an internal `owned_relations/0` returning the six tables plus marker in dependency-safe move order (marker can be moved after tables; every foreign-key-dependent Rindle table must move as part of the one transaction). Do not duplicate a string list in `migration.ex`, tests, or docs. [VERIFIED: codebase grep] [ASSUMED]

### Pattern 2: Classify all state before mutation

**What:** Use one bound-value catalog query (for `public` and `rindle`) to return presence/count for every allowlisted relation, marker location/version, target schema existence/usability, and ownership/privilege signals. Classify it to an explicit result before creating/moving anything. [VERIFIED: 118-CONTEXT.md]

**When to use:** `move_public_to_rindle/1` and `move_rindle_to_public/1`; fresh `up/1` only provisions the selected schema and continues with its existing idempotent DDL contract. [VERIFIED: 118-CONTEXT.md]

**State outcomes to encode:**

| Observed state | Result | Next action |
|----------------|--------|-------------|
| Full public owned set; empty rindle owned set; valid public marker | movable | Perform fixed transaction move. [VERIFIED: 118-CONTEXT.md] |
| Full rindle owned set; empty public owned set; valid rindle marker | already upgraded | Return idempotent success without move. [VERIFIED: 118-CONTEXT.md] |
| Public and rindle both contain any owned relation | refuse | Tell operator to restore/resolve mixed state; do not guess. [VERIFIED: 118-CONTEXT.md] |
| Partial source or partial target | refuse | Tell operator which expected relation set is incomplete. [VERIFIED: 118-CONTEXT.md] |
| Missing/misplaced/invalid marker or unexpected Rindle-owned relation | refuse | Tell operator to inspect/restore state before migration. [VERIFIED: 118-CONTEXT.md] |
| Target schema unavailable or role cannot create/move | refuse | Tell operator to grant required ownership/target-schema `CREATE` privilege or run as appropriate owner. [CITED: https://www.postgresql.org/docs/current/sql-altertable.html] |

### Pattern 3: One internal identifier boundary

**What:** Prefix options must be constrained to exactly `"rindle"` and `"public"`; only the V1 quoting helper may interpolate these fixed identifiers into DDL. Catalog predicates use `$1`, `$2`, etc. bound values. [VERIFIED: codebase grep] [VERIFIED: 118-CONTEXT.md]

**When to use:** `CREATE SCHEMA`, qualified `ALTER TABLE`, marker insert/read, and catalog validation. [VERIFIED: 118-CONTEXT.md]

**Why:** PostgreSQL schema-qualified names choose exact objects; unqualified names follow `search_path`, whose writable schemas can change query behavior. [CITED: https://www.postgresql.org/docs/current/ddl-schemas.html]

### Pattern 4: Host migration controls operations

**What:** Document a copy-pasteable host migration that sets a transaction-local lock timeout then calls the narrow Rindle helper. The Rindle module does not create its own migration ledger or lock policy. [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html] [VERIFIED: 118-CONTEXT.md]

```elixir
# Source: https://ecto-sql.hexdocs.pm/Ecto.Migration.html (transaction callbacks/query use)
defmodule MyApp.Repo.Migrations.MoveRindleToSchema do
  use Ecto.Migration

  def up do
    execute(fn -> repo().query!("SET LOCAL lock_timeout = '5s'") end)
    execute(fn -> Rindle.Migration.move_public_to_rindle(version: 1) end)
  end

  def down do
    execute(fn -> repo().query!("SET LOCAL lock_timeout = '5s'") end)
    execute(fn -> Rindle.Migration.move_rindle_to_public(version: 1) end)
  end
end
```

The exact `5s` value is a planner/executor choice: keep it configurable in the host migration example or pick a documented bounded default, but use `SET LOCAL` so it expires at transaction end. The source documents Ecto transaction callbacks as the supported place to set `lock_timeout`; transaction-local scope is a PostgreSQL behavior to verify in the live test. [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html] [ASSUMED]

### Anti-Patterns to Avoid

- **Create target tables before classifying legacy state:** could leave a source+target mixed state; preflight first. [VERIFIED: 118-CONTEXT.md]
- **`IF EXISTS` around the move:** suppresses a missing relation and converts an unsafe partial move into an apparent success. [VERIFIED: 118-CONTEXT.md]
- **Move `oban_jobs` or the Ecto ledger “for consistency”:** violates host ownership. [VERIFIED: 118-CONTEXT.md]
- **Use `Rindle.Migration.down/1` in upgrade `down`:** it destroys Rindle tables rather than restoring their schema. [VERIFIED: codebase grep] [VERIFIED: 118-CONTEXT.md]
- **Disable Ecto DDL transactions to avoid locks:** loses all-or-nothing safety; no concurrent-index feature is needed by this move. [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Table/data relocation | Copy loop, ETL, or dual-write coordinator | PostgreSQL `ALTER TABLE … SET SCHEMA` | Native move retains associated indexes, constraints, and column-owned sequences. [CITED: https://www.postgresql.org/docs/current/sql-altertable.html] |
| Migration serialization/ledger | Rindle migration table or distributed lock | Host `Ecto.Migrator` / existing `schema_migrations` | Ecto locks its migration source; the host owns deployment/ledger policy. [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html] |
| Arbitrary schema API | Configurable generic mover | Two allowed prefix values plus pinned direction helpers | Limits identifier trust and the library's support surface. [VERIFIED: 118-CONTEXT.md] |
| Identifier interpolation helper | New generic SQL builder | Existing V1 `quote_ident/1` behind narrowed validation | Prevents multiple inconsistent identifier boundaries. [VERIFIED: codebase grep] |

**Key insight:** This phase is safe because PostgreSQL owns relocation mechanics and the host owns operation timing; Rindle's responsibility is deliberately limited to recognizing and moving its fixed relation set. [CITED: https://www.postgresql.org/docs/current/sql-altertable.html] [VERIFIED: 118-CONTEXT.md]

## Runtime State Inventory

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | The six Rindle tables and `rindle_migration_versions` can contain legacy public data. | Data migration: move exactly these seven relations when complete source/empty target preflight passes. [VERIFIED: 118-CONTEXT.md] |
| Live service config | Rindle compile-time `:rindle_prefix` selects `rindle` or `public`; host Oban configuration is independent. | Code/deployment edit: compile/deploy the `rindle` build after a successful move; do not alter Oban. [VERIFIED: codebase grep] |
| OS-registered state | None — verified by codebase grep; this library phase has no scheduler/service registration path. | None. [VERIFIED: codebase grep] |
| Secrets/env vars | No Rindle schema-move secret/environment key was found. Database role privileges are externally provisioned and must be checked, not renamed. | Operational check: role owns each source table and has `CREATE` on target schema. [CITED: https://www.postgresql.org/docs/current/sql-altertable.html] |
| Build artifacts | Compiled schema metadata bakes the selected prefix; old public-compiled releases remain incompatible with post-move `rindle` data. | Redeploy/recompile with `:rindle_prefix, "rindle"`; reverse only while state is exactly reversible. [VERIFIED: codebase grep] [VERIFIED: 118-CONTEXT.md] |

## Common Pitfalls

### Pitfall 1: Confusing a migration lock with a maintenance window

**What goes wrong:** A host migration serializes another migrator but application writers/workers still hold or request table locks, so the `ALTER TABLE` waits or times out. [CITED: https://ecto-sql.hexdocs.pm/Ecto.Migration.html] [CITED: https://www.postgresql.org/docs/current/sql-altertable.html]

**How to avoid:** Back up and quiesce Rindle request/worker traffic before migration; set a transaction-local timeout and fail with an operator action instead of waiting indefinitely. [VERIFIED: 118-CONTEXT.md]

**Warning signs:** `lock_timeout`/Postgres lock errors, active Rindle workers, or a migration that cannot acquire table locks. [ASSUMED]

### Pitfall 2: Partial success hidden by idempotent syntax

**What goes wrong:** `IF EXISTS`, `CREATE IF NOT EXISTS`, or per-table “best effort” logic makes a partial state look successful. [VERIFIED: 118-CONTEXT.md]

**How to avoid:** Preflight the exact full state, then issue no move until every invariant passes; use idempotence only for the explicit full-target already-upgraded result. [VERIFIED: 118-CONTEXT.md]

### Pitfall 3: Losing the routing/deployment pairing

**What goes wrong:** Rows move to `rindle` while the running/compiled library still targets `public`, or vice versa. [VERIFIED: codebase grep] [VERIFIED: 118-CONTEXT.md]

**How to avoid:** The runbook sequence is quiesce → host move → deploy compiled `rindle` config → verify; public compatibility remains the explicit alternative rather than a dynamic runtime switch. [VERIFIED: 118-CONTEXT.md]

### Pitfall 4: Claiming the destructive API is rollback

**What goes wrong:** An operator uses `Rindle.Migration.down/1`, which drops Rindle-owned data. [VERIFIED: codebase grep]

**How to avoid:** Offer a separately guarded reverse move only in the host migration's `down`; state that backup, no post-move writes/later migrations, and prior public build are prerequisites. [VERIFIED: 118-CONTEXT.md]

## Code Examples

### Fixed, quoted move after classified preflight

```elixir
# Source: https://www.postgresql.org/docs/current/sql-altertable.html
# identifiers are fixed by V1 after Options validates the two supported prefixes
for relation <- owned_relations_in_move_order() do
  repo.query!(
    "ALTER TABLE #{qualified(\"public\", relation)} SET SCHEMA #{quote_ident(\"rindle\")}",
    []
  )
end
```

This is illustrative internal V1 shape, not a generic SQL API. The preflight must run first, and reverse uses the same fixed list in the opposite schema direction only after equivalent checks. [VERIFIED: 118-CONTEXT.md]

### Bound catalog values, not bound identifiers

```elixir
# Source: project established Repo.query!/catalog pattern
Repo.query!(
  """
  SELECT table_schema, table_name
  FROM information_schema.tables
  WHERE table_schema = ANY($1::text[])
    AND table_name = ANY($2::text[])
  ORDER BY table_schema, table_name
  """,
  [["public", "rindle"], Rindle.Migration.V1.owned_relations()]
)
```

Use returned state only to classify; never build a relation name from catalog data. PostgreSQL qualified names are required for deterministic resolution, while placeholders are appropriate for values. [CITED: https://www.postgresql.org/docs/current/ddl-schemas.html] [ASSUMED]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Default migration prefix `public` and arbitrary non-empty prefix acceptance | Compile-time routing supports only `rindle` or `public`; Phase 118 pairs migration validation/default with it | Phase 117 completed 2026-08-08; Phase 118 scope | Fresh installs will consistently provision the selected compile-time schema. [VERIFIED: codebase grep] [VERIFIED: 118-CONTEXT.md] |
| Rindle migration helper only creates/drops its current prefix tables | Version-pinned forward and guarded reverse schema moves | Phase 118 | Gives legacy public data a bounded host-owned upgrade route. [VERIFIED: 118-CONTEXT.md] |

**Deprecated/outdated:** Documentation that says the default remains `public` or permits `tenant_media`/arbitrary prefixes is false after this phase and needs scoped migration API/snippet updates; broad release-facing parity stays Phase 120. [VERIFIED: codebase grep] [VERIFIED: 118-CONTEXT.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The fixed allowlisted Rindle tables have no non-table owned database objects (for example triggers/functions) that require separate move/recreate handling. | Architecture Patterns | Data path could need an additional, explicitly-owned object audit. |
| A2 | `SET LOCAL lock_timeout = '5s'` is a suitable example/default for adopters; exact timeout needs repository/operator confirmation. | Code Examples | Timeout may be too short for a valid maintenance operation or too long for local policy. |
| A3 | The proposed `information_schema.tables` array-query shape is compatible with the project's supported PostgreSQL/adapter matrix. | Code Examples | Planner may need a `pg_catalog` query instead. |

## Open Questions

1. **What is the exact error/result contract for an already-upgraded full `rindle` set?**
   - What we know: It may be idempotent success; all other mixed/partial states must refuse. [VERIFIED: 118-CONTEXT.md]
   - Recommendation: Return `:ok` with a clear “already in rindle; nothing moved” message and test it explicitly. [ASSUMED]
2. **How should privilege refusal be integration-tested under the local PostgreSQL setup?**
   - What we know: PostgreSQL requires source-table ownership and target-schema `CREATE`; the normal test role likely owns test schemas. [CITED: https://www.postgresql.org/docs/current/sql-altertable.html] [ASSUMED]
   - Recommendation: Use a dedicated test role only if CI permits role creation; otherwise inject the catalog/privilege seam for unit coverage and retain a documented manual privilege proof. [ASSUMED]
3. **Should docs use a fixed timeout or an explicit placeholder?**
   - What we know: transaction-local timeout is required by the locked decision, but the value is discretionary. [VERIFIED: 118-CONTEXT.md]
   - Recommendation: Choose and document one bounded value in the host migration snippet, with a comment that operators may adapt it to policy. [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir/Mix | Library/test execution | ✓ | Mix 1.19.5 / OTP 28 | — [VERIFIED: local command] |
| PostgreSQL client | Live schema/move inspection | ✓ | psql 14.17 | Existing Ecto/Postgrex test Repo for automated test path. [VERIFIED: local command] |
| PostgreSQL server | Migration integration tests | Unknown (not probed to avoid changing DB state) | — | Existing `mix test` harness, if local configured. [ASSUMED] |
| Docker | Optional local database workflow | ✓ | 29.5.2 | Native PostgreSQL service. [VERIFIED: local command] |

**Missing dependencies with no fallback:** None identified; server reachability must be established before integration execution. [ASSUMED]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit + Ecto SQL Sandbox + live PostgreSQL. [VERIFIED: codebase grep] |
| Config file | `config/test.exs`; it currently compiles explicit `public` compatibility. [VERIFIED: codebase grep] |
| Quick run command | `mix test test/rindle/migration_test.exs --seed 0` |
| Full suite command | `mix coveralls.multiple --type local --type json` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MIGRATE-01 | Default `rindle` provisioning, schema creation before all seven relations, idempotent rerun; explicit `public` compatibility. | PostgreSQL integration + isolated default-build proof | `mix test test/rindle/migration_test.exs --seed 0` plus default-build targeted command | ✅ extend existing; default-build probe is Wave 0. [VERIFIED: codebase grep] |
| MIGRATE-02 | Populated seven-relation move retains rows, FKs, indexes, marker and leaves `public.oban_jobs`/host ledger unchanged. | Serial PostgreSQL integration | `mix test test/rindle/migration_test.exs --seed 0` | ✅ extend existing. [VERIFIED: codebase grep] |
| MIGRATE-03 | Every refusal state happens before ALTER; injected transaction error rolls back; lock contention reports bounded timeout. | Unit + serial PostgreSQL integration | `mix test test/rindle/migration_test.exs --seed 0` | ✅ extend existing; role/lock fixture may be Wave 0. [VERIFIED: codebase grep] |

### Sampling Rate

- **Per task commit:** `mix test test/rindle/migration_test.exs --seed 0`
- **Per wave merge:** `mix test test/rindle/migration_test.exs test/rindle/schema_prefix_contract_test.exs --seed 0`
- **Phase gate:** `mix coveralls.multiple --type local --type json` green before `$gsd-verify-work`.

### Wave 0 Gaps

- [ ] Extend `test/rindle/migration_test.exs` with reusable qualified catalog, populated-data, index/FK, host-ledger, and explicit `public.oban_jobs` assertions. [VERIFIED: codebase grep]
- [ ] Add a temporary default-compiled test/probe path; `config/test.exs` intentionally remains public compatibility to preserve normal suite stability. [VERIFIED: codebase grep]
- [ ] Decide/test safe injection seam for transaction failure and lock contention; do not rely on timing-only lock tests. [ASSUMED]
- [ ] Decide privilege testing strategy compatible with CI role permissions. [ASSUMED]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Database connection role is host-provisioned; no end-user auth surface is added. [ASSUMED] |
| V3 Session Management | No | No session state is added. [ASSUMED] |
| V4 Access Control | Yes | PostgreSQL ownership + target-schema `CREATE` preflight; fail before move. [CITED: https://www.postgresql.org/docs/current/sql-altertable.html] |
| V5 Input Validation | Yes | Two-value prefix allowlist; only fixed identifiers are quoted; catalog values remain bound. [VERIFIED: 118-CONTEXT.md] |
| V6 Cryptography | No | No cryptographic operation is added. [ASSUMED] |

### Known Threat Patterns for PostgreSQL/Ecto migration helpers

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Identifier injection / schema confusion | Tampering | Reject arbitrary prefixes; centralize identifier quoting; bind catalog values. [VERIFIED: 118-CONTEXT.md] |
| `search_path` object shadowing | Elevation of privilege | Use fixed schema-qualified names; do not mutate or rely on `search_path`. [CITED: https://www.postgresql.org/docs/current/ddl-schemas.html] |
| Unsafe partial migration | Tampering / Denial of service | Complete preflight, one transaction, refusal before `ALTER`, and transaction failure proof. [VERIFIED: 118-CONTEXT.md] |
| Host infrastructure takeover | Tampering | Fixed owned-relation allowlist excludes `oban_jobs` and `schema_migrations`; assert untouched state. [VERIFIED: 118-CONTEXT.md] |

## Sources

### Primary (HIGH confidence)

- [PostgreSQL ALTER TABLE](https://www.postgresql.org/docs/current/sql-altertable.html) — `SET SCHEMA` behavior, moved associated objects, permissions, lock default.
- [PostgreSQL schemas](https://www.postgresql.org/docs/current/ddl-schemas.html) — qualified naming, `search_path` security, schema privileges.
- [Ecto SQL `Ecto.Migration`](https://ecto-sql.hexdocs.pm/Ecto.Migration.html) — migration transactions, source locking, callbacks and execution patterns.
- Repository source: `lib/rindle/migration.ex`, `lib/rindle/migration/options.ex`, `lib/rindle/migration/v1.ex`, `lib/rindle/schema.ex`, `test/rindle/migration_test.exs`, and `test/support/schema_prefix_case.ex`. [VERIFIED: codebase grep]

### Secondary (MEDIUM confidence)

- Research-plan seam digests from authoritative PostgreSQL/Ecto documentation, cross-checked through official URLs. [VERIFIED: research cache]

### Tertiary (LOW confidence)

- No external community source is relied on for a design decision. [VERIFIED: research log]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — existing lockfile/test harness plus official Ecto/PostgreSQL docs.
- Architecture: HIGH — locked phase decisions align with native PostgreSQL move semantics.
- Pitfalls: MEDIUM — operational lock/role proof details still need exact CI fixture design.

**Research date:** 2026-08-09
**Valid until:** 2026-09-08
