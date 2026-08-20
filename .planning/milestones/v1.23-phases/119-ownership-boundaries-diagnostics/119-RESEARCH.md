# Phase 119: Ownership Boundaries & Diagnostics - Research

**Researched:** 2026-08-09
**Domain:** PostgreSQL schema ownership, Ecto catalog inspection, Oban host integration, and bounded operator diagnostics
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-119-01:** Retain `Rindle.Schema` as the only authority for Rindle's compile-time `"rindle" | "public"` schema selection. Do not derive Rindle routing from Oban, `search_path`, or a runtime application-env override.
- **D-119-02:** Resolve the host's default Oban binding as the canonical source for Oban diagnostic and runtime query prefixing. Retain existing `:rindle, :oban_prefix` only as a compatibility expectation/override during transition; report bounded binding drift if it disagrees. Never infer Oban's prefix from Rindle's prefix.
- **D-119-03:** Support only the default host `Oban` instance aligned with the Rindle-configured repo. Alternate named instance, alternate repo, `prefix: false`, unavailable binding, or invalid identifier is a setup/configuration refusal.
- **D-119-04:** Factor prefix-sensitive catalog inspection into one internal data-only snapshot shared by `mix rindle.doctor` and `Rindle.runtime_status/1`. Inspect only the seven Rindle-owned relations in `rindle` and `public`, plus `oban_jobs` in the resolved host Oban prefix.
- **D-119-05:** Bind catalog predicate values; permit dynamic identifiers only through one internal validated-and-quoted boundary. Catalog/permission failures are explicit `:inspection_failed`, never missing/incomplete.
- **D-119-06:** Infer only an exact two-schema mismatch: expected Rindle prefix incomplete and the other supported prefix complete with a valid v1 marker. Partial, invalid-marker, both-complete, and ambiguous states remain bounded incomplete/inspection failures.
- **D-119-07:** Preserve `doctor.rindle_schema.ready` and `doctor.oban_jobs.ready`; enrich their data/rendering rather than introduce a third prefix checker or parallel subsystem.
- **D-119-08:** Report Rindle and Oban independently on every doctor run. A Rindle mismatch names expected/observed prefixes and directs the host-owned maintenance-window move plus matching deploy. An Oban fault says the host owns `Oban.Migration`. State that Rindle never manages `oban_jobs` or `schema_migrations`.
- **D-119-09:** Make deterministic IDs/statuses and JSON fields the contract, with concise accessible text. Do not expose Postgrex errors, SQL, credentials, broad schema inventories, or color-only meaning.
- **D-119-10:** Run the shared snapshot before every runtime report query. Preserve `{:setup_incomplete, :rindle_schema}` and `{:setup_incomplete, :oban_jobs}`; add detailed tagged errors only for known mismatch, binding-drift, and catalog-unavailable states.
- **D-119-11:** Mix task, API-adjacent rendering, and adoption-demo presentation use the same bounded diagnostic family, not `inspect(reason)` or adapter exception leakage.
- **D-119-12:** Prove shared interpretation, both directional prefix mismatch, partial/invalid-marker non-mismatches, invalid/drifted Oban binding, inspection failure, bounded text/JSON/non-zero output, early refusal, and no mutation of `public.oban_jobs`, `schema_migrations`, or host Oban configuration.
- **D-119-13:** Diagnosis remains separate from remediation: host migration → doctor → runtime status → explicit lifecycle repair. No auto-migration/deploy, arbitrary schema discovery, queue changes, dashboard redesign, packed-adopter/Cohort proof, or broad connectivity tooling.

### the agent's Discretion

- Choose internal names, snapshot shape, telemetry fields, validation implementation, and concise microcopy while preserving stable IDs, ownership, and bounded public errors.
- Reuse focused test seams and real database fixtures; do not add a public diagnostic snapshot API merely for convenience.

### Deferred Ideas (OUT OF SCOPE)

- Generic arbitrary-schema discovery/configuration/migration/repair.
- Automatic migration/deploy/restart, Oban queue/configuration changes, or lifecycle repair from doctor/runtime status.
- Dashboard redesign, new diagnostics API version, broad credential diagnostics, and full packed-adopter/Cohort/release-documentation proof.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|---|---|---|
| BOUNDARY-01 | Rindle does not manage host `oban_jobs` or `schema_migrations`; Oban prefix is independent. | Fixed allowlists, resolved-default-Oban binding, AST/DB mutation regression proof. |
| BOUNDARY-02 | Prefix-sensitive SQL/catalog/Oban queries resolve the correct schemas with safe binding/quoting. | Shared snapshot, bound catalog predicates, validated identifier boundary, two-prefix-only classifier. |
| OPS-01 | Doctor/runtime status independently report prefixes and diagnose mismatch without raw DB errors. | Stable check IDs, shared refusal family, JSON/text rendering, early preflight tests. |
</phase_requirements>

## Summary

[VERIFIED: codebase inspection] Rindle already has the necessary ownership primitives: `Rindle.Schema` fixes normal Rindle routing at compile time; `Rindle.Migration.V1` owns exactly six media tables plus `rindle_migration_versions`; and its migration snapshot uses bound catalog predicates plus a local identifier quoting helper. The remaining gap is operational duplication: `RuntimeChecks` and `RuntimeStatus` independently inspect readiness, while both currently source Oban from `Rindle.Config.oban_prefix/0` rather than the host's default `Oban` configuration.

[CITED: https://oban.hexdocs.pm/Oban.Migration.html] Oban supports a host-selected PostgreSQL prefix and requires the migration and Oban configuration to agree on it. [CITED: https://hexdocs.pm/oban/isolation.html] Named instances are separately configured and called explicitly. Therefore Phase 119 must resolve only the default `Oban` binding, verify it uses Rindle's configured repo and a valid string prefix, and refuse unsupported binding shapes instead of widening Rindle's support contract.

**Primary recommendation:** Introduce one internal `Rindle.Ops` inspection snapshot that resolves the host default Oban binding, reads only the fixed ownership allowlist, classifies Rindle/Oban readiness deterministically, and feeds both stable doctor checks and runtime-status refusal before any report query runs.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Compile-time Rindle schema choice | API / Backend | Database / Storage | `Rindle.Schema` fixes only Rindle's `rindle`/`public` routing; it is not a host database-discovery mechanism. [VERIFIED: codebase inspection] |
| Host Oban binding resolution | API / Backend | Database / Storage | Application config under the default `Oban` module identifies repo/prefix; its tables/migrations remain host-owned. [VERIFIED: codebase inspection] [CITED: https://hexdocs.pm/oban/isolation.html] |
| Catalog snapshot and mismatch classification | API / Backend | Database / Storage | The library performs constrained, read-only catalog queries and returns a data model; PostgreSQL owns visibility/permissions. [CITED: https://www.postgresql.org/docs/current/infoschema-tables.html] |
| Doctor and runtime CLI rendering | API / Backend | — | Mix tasks render stable structured results; they neither move tables nor reconfigure Oban. [VERIFIED: codebase inspection] |
| Host migration/remediation | Database / Storage | API / Backend | The operator chooses the maintenance window and host Ecto migration; Oban's migration is host-owned. [CITED: https://oban.hexdocs.pm/Oban.Migration.html] |

## Standard Stack

### Core

| Library | Locked Version | Purpose | Why Standard |
|---|---:|---|---|
| Elixir/Ecto SQL | `ecto_sql 3.13.5` | Existing Repo query and schema-prefix access | Already the library's SQL abstraction; raw query parameters are passed separately from SQL. [VERIFIED: codebase inspection] [CITED: https://hexdocs.pm/ecto_sql/3.13.1/Ecto.Adapters.SQL.Connection.html] |
| PostgreSQL | host-provided | `information_schema` / catalog visibility | Existing project database and source of truth for relation existence and privileges. [VERIFIED: codebase inspection] [CITED: https://www.postgresql.org/docs/current/infoschema-tables.html] |
| Oban | `2.21.1` | Host-owned jobs binding | Existing dependency and host integration contract; supports explicit prefix configuration. [VERIFIED: codebase inspection] [CITED: https://oban.hexdocs.pm/Oban.Migration.html] |

### Supporting

| Library | Purpose | When to Use |
|---|---|---|
| `:telemetry` (existing transitive/direct runtime use) | One bounded event per doctor check/runtime refusal | Extend existing diagnostic telemetry only with non-sensitive classification/prefix fields. [VERIFIED: codebase inspection] |

**Installation:** None. [VERIFIED: codebase inspection] Phase 119 uses existing dependencies only, so no package legitimacy audit or dependency install task belongs in the plan.

## Architecture Patterns

### System Architecture Diagram

```text
mix rindle.doctor ───────┐
                         ├─> internal ownership snapshot
Rindle.runtime_status/1 ─┘       │
                                 ├─ resolve default Oban config (repo + prefix)
                                 ├─ validate supported binding / compatibility override
                                 ├─ catalog-read only: seven owned relations in {rindle, public}
                                 └─ catalog-read only: oban_jobs in resolved Oban prefix
                                           │
               ┌───────────────────────────┴──────────────────────────┐
               v                                                      v
 stable doctor.rindle_schema.ready / doctor.oban_jobs.ready      runtime preflight
 structured summary/fix + text renderer                          :ok -> report queries
                                                                   :error -> bounded refusal
```

[VERIFIED: codebase inspection] The snapshot belongs in an internal operations module (not `Config`, not `Schema`, and not `Migration.V1`) because it consumes existing authorities but does not define routing or mutate state.

### Recommended Project Structure

```text
lib/rindle/ops/
├── ownership_snapshot.ex       # new internal read-only resolver/classifier
├── runtime_checks.ex           # consumes snapshot for existing stable doctor checks
└── runtime_status.ex           # consumes snapshot before all report queries

lib/mix/tasks/
├── rindle.doctor.ex            # deterministic text rendering of enriched checks
└── rindle.runtime_status.ex    # text/JSON bounded refusal rendering
```

### Pattern 1: Resolve Then Inspect Then Classify

**What:** First resolve the default host `Oban` config and validate `{repo, prefix}`; then execute a single constrained catalog snapshot; then map snapshot state to stable check data/public runtime errors. [VERIFIED: codebase inspection]

**When to use:** Every doctor or runtime-status call, before any Rindle report query. [VERIFIED: codebase inspection]

**Required classifier order:**

1. Binding unavailable/unsupported/invalid or `:oban_prefix` compatibility drift → bounded Oban binding refusal.
2. Catalog query failure → `:inspection_failed`, retaining no raw database reason in public output.
3. Expected Rindle complete plus marker `[1]` → ready.
4. Expected Rindle incomplete and the *other* supported prefix complete with marker `[1]` → `:rindle_prefix_mismatch` with expected and observed prefixes.
5. All other Rindle states (partial, marker invalid, both complete) → existing incomplete state, never inferred as an upgrade.
6. Resolved host Oban prefix contains `oban_jobs` → ready; absence → existing `:setup_incomplete, :oban_jobs` shape. [VERIFIED: context decision D-119-06]

### Pattern 2: Data-First Diagnostics

**What:** Checks should carry data such as `expected_prefix`, `observed_prefix`, `owner`, `classification`, and `next_action`; Mix and LiveView/adoption-demo render those fields. [VERIFIED: context decision D-119-07]

**Why:** Stable check IDs and JSON are the contract; text must remain concise, ordered, and safe. [VERIFIED: context decision D-119-09]

### Pattern 3: One Identifier Boundary, Bound Values Everywhere Else

**What:** Keep the Phase 118 `quote_ident` pattern for the one marker-table read that needs schema-qualified SQL, but admit only supported schemas and fixed relation names. Use `$1`/`ANY($2::text[])` for catalog predicates. [VERIFIED: codebase inspection]

**Why:** PostgreSQL catalog views reflect only objects accessible to the current user, so query errors must remain inspection failure rather than missing state. [CITED: https://www.postgresql.org/docs/current/infoschema-tables.html]

### Anti-Patterns to Avoid

- **Oban prefix derived from `Rindle.Schema.prefix/0`:** violates independent host ownership. [VERIFIED: context decision D-119-02]
- **Fallback to `:rindle, :oban_prefix` when host config disagrees:** silently masks drift; compare it only as a compatibility expectation. [VERIFIED: context decision D-119-02]
- **Generic `schemas()` / relation discovery helper:** expands authority beyond the exact two Rindle schemas and one host Oban relation. [VERIFIED: context decision D-119-04]
- **`inspect(reason)` / `Exception.message` in new public failures:** can leak connection/SQL details; map to a fixed diagnostic family. [VERIFIED: context decision D-119-09]
- **Treating query/permission failures as missing:** can direct an operator to run the wrong migration. [CITED: https://www.postgresql.org/docs/current/infoschema-tables.html]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Rindle relation authority | Another table list | `Rindle.Migration.V1.owned_relations/0` / catalog requirements | Phase 118's exact seven-relation ownership authority already exists. [VERIFIED: codebase inspection] |
| Rindle prefix selection | Runtime routing or `search_path` inspection | `Rindle.Schema.prefix/0` | Compile-time two-value authority is already proven. [VERIFIED: codebase inspection] |
| Oban migration/setup | Rindle migration/configuration wrapper | Host `Oban.Migration` and default host `Oban` config | Oban documents prefix-specific host migration/configuration. [CITED: https://oban.hexdocs.pm/Oban.Migration.html] |
| SQL identifier escaping | A second ad-hoc quoting implementation | Reuse/extract Phase 118's validated quoting boundary | Keeps the attack surface and code-path count bounded. [VERIFIED: codebase inspection] |
| User-facing database-error output | Raw Postgrex/adapter messages | Fixed classifications and action strings | Required safe, stable operator contract. [VERIFIED: context decision D-119-09] |

## Common Pitfalls

### Pitfall 1: Resolving Oban from the wrong config owner

**What goes wrong:** Doctor sees `public.oban_jobs` through `:rindle, :oban_prefix` while the host default `Oban` config points elsewhere, yielding a false healthy result. [VERIFIED: codebase inspection]

**How to avoid:** Resolve `Application.get_env(mix_app, Oban)` once; require its repo to equal `Rindle.Config.repo/0`, its prefix to be a non-empty binary, and any compatibility override to agree. [VERIFIED: context decision D-119-02]

### Pitfall 2: Converting ambiguous catalog state into a migration recommendation

**What goes wrong:** A partial/invalid/both-complete state is called a public→rindle mismatch and prompts an unsafe move. [VERIFIED: context decision D-119-06]

**How to avoid:** Infer mismatch only from complete marker-backed source state in the other one of two supported schemas; otherwise report incomplete or inspection failure. [VERIFIED: context decision D-119-06]

### Pitfall 3: Runtime status queries before refusal

**What goes wrong:** Ecto report queries hit an absent/mis-prefixed relation and raise before the operator gets a useful diagnosis. [VERIFIED: codebase inspection]

**How to avoid:** Make the common snapshot the first `with` condition in `runtime_status/1`; assertion tests must make a report-query seam fail if invoked after a refused snapshot. [VERIFIED: context decision D-119-10]

### Pitfall 4: Rendering raw reasons in adjacent operator surfaces

**What goes wrong:** `Mix.Tasks.Rindle.RuntimeStatus.format_error/1` and the adoption demo's current `inspect(reason)` fallback can reveal adapter internals. [VERIFIED: codebase inspection]

**How to avoid:** Centralize error-to-diagnostic rendering and have Mix, admin query callers, and the demo consume it. [VERIFIED: context decision D-119-11]

## Code Examples

### Catalog predicate discipline

```elixir
# Values are bound. This query is restricted by caller-supplied fixed allowlists.
repo.query(
  """
  SELECT table_schema, table_name
  FROM information_schema.tables
  WHERE table_schema = ANY($1::text[])
    AND table_name = ANY($2::text[])
  ORDER BY table_schema, table_name
  """,
  [["rindle", "public"], Rindle.Migration.V1.owned_relations()]
)
```

[VERIFIED: codebase inspection] This follows the project’s existing `$1`/`ANY` catalog pattern. [CITED: https://www.postgresql.org/docs/current/infoschema-tables.html]

### Bounded runtime refusal shape

```elixir
with {:ok, snapshot} <- OwnershipSnapshot.inspect(),
     :ok <- OwnershipSnapshot.runtime_ready?(snapshot) do
  # existing report queries only
else
  {:error, reason} ->
    emit_runtime_refusal(reason)
    {:error, reason}
end
```

[VERIFIED: codebase inspection] Preserve existing two setup-incomplete tuples for legacy cases; add structured tagged tuples only for new known classifications.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | No assumptions required. | — | All implementation guidance is constrained by inspected code, locked decisions, or official PostgreSQL/Oban documentation. |

## Open Questions (RESOLVED)

1. **Exact default-Oban configuration shape in all supported host apps — resolved by D-119-03**
   - Current code reads `Application.get_env(mix_app, Oban)` and validates `:repo`; Oban documents a default config with `:repo` and optional `:prefix`. [VERIFIED: codebase inspection] [CITED: https://hexdocs.pm/oban/isolation.html]
   - The supported contract is deliberately bounded: an absent prefix on an otherwise valid default binding may resolve to `"public"`, and an explicit non-empty valid binary prefix is accepted.
   - `prefix: false` is an unsupported setup/configuration and must return the fixed bounded Oban-binding refusal before catalog I/O. It is never normalized, inferred, queried, or treated as legacy support. Nil config, named/alternate repo shapes, invalid identifiers, and compatibility drift follow their corresponding bounded refusal paths with no raw payload. [VERIFIED: context decision D-119-03]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---:|---|---|
| Elixir/Mix | existing tests and tasks | ✓ | project runtime | — |
| PostgreSQL test repo | catalog and ownership proof | ✓ | project test integration | existing DataCase fixtures |
| Oban | host binding/test fixtures | ✓ | `2.21.1` locked | — |

[VERIFIED: codebase inspection] This is code/test work against existing in-repo dependencies; no external service setup is newly required.

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | ExUnit with Ecto SQL Sandbox / project `DataCase` [VERIFIED: codebase inspection] |
| Config file | `test/test_helper.exs` [VERIFIED: codebase inspection] |
| Quick run command | `mix test test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_status_test.exs test/rindle/doctor_test.exs test/rindle/runtime_status_task_test.exs` |
| Full suite command | `mix test` (CI runs coverage through `mix coveralls.multiple --type local --type json`) [VERIFIED: RUNNING.md] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| BOUNDARY-01 | Fixed inspection cannot mutate/route `oban_jobs` or `schema_migrations`; Oban stays host-owned | integration + static contract | focused command above | ✅ extend migration/runtime tests |
| BOUNDARY-02 | Only allowlisted Rindle schemas/relations and resolved Oban prefix are queried; invalid binding safely refuses | unit + integration | focused command above | ✅ extend runtime checks/status tests |
| OPS-01 | Shared classification renders deterministic doctor text/data and bounded runtime text/JSON/non-zero refusal | unit + task integration | focused command above | ✅ extend doctor/task/adoption demo tests |

### Sampling Rate

- **Per task commit:** focused command above.
- **Per wave merge:** `mix test`.
- **Phase gate:** full suite and the release-train checks named in `RUNNING.md` are green. [VERIFIED: AGENTS.md]

### Wave 0 Gaps

- [ ] Add a dedicated snapshot test seam/fixture model before production refactor so doctor and runtime consume exactly the same classifications.
- [ ] Add a real selected/decoy-schema integration case proving both expected-`public` and expected-`rindle` mismatch classification.
- [ ] Add task/demo rendering assertions that raw sentinel Postgrex/SQL/credential-like reasons never appear.
- [ ] Add a report-query tripwire proving no `rindle_all`/`oban_all` query is reached after any snapshot refusal.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V4 Access Control | yes | Scope catalog reads to the fixed ownership allowlist; preserve permission denial as inspection failure. [CITED: https://www.postgresql.org/docs/current/infoschema-tables.html] |
| V5 Input Validation | yes | Validate only accepted schema/prefix forms before identifier construction; bind catalog predicate values. [VERIFIED: context decision D-119-05] |
| V7 Error Handling and Logging | yes | Stable classifications/actions; no adapter error/SQL/credential leakage to user-facing output. [VERIFIED: context decision D-119-09] |
| V6 Cryptography | no | Phase handles no cryptographic material. [VERIFIED: codebase inspection] |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Config-derived identifier injection | Tampering | Fixed supported prefix set for Rindle; validated host binding; one quoted-identifier boundary; no arbitrary discovery. [VERIFIED: context decision D-119-05] |
| Permission error misreported as absent table | Denial of service | Classify catalog failure separately; do not prescribe migration from an untrusted absence signal. [CITED: https://www.postgresql.org/docs/current/infoschema-tables.html] |
| Sensitive adapter/connection diagnostics shown to operators | Information disclosure | Render fixed text/JSON diagnostic fields, not raw exceptions/reasons. [VERIFIED: context decision D-119-09] |
| Rindle changes host job storage/ledger | Tampering | Fixed seven-relation Rindle ownership list; Oban is query-only at one `oban_jobs` relation; no DDL/config writes. [VERIFIED: codebase inspection] |

## Sources

### Primary (HIGH confidence)

- Rindle codebase: `lib/rindle/schema.ex`, `config.ex`, `migration/v1.ex`, `ops/runtime_checks.ex`, `ops/runtime_status.ex`, Mix tasks, admin query/live view, adoption demo, and focused tests — current seams and behavior. [VERIFIED: codebase inspection]
- [PostgreSQL `information_schema.tables`](https://www.postgresql.org/docs/current/infoschema-tables.html) — visibility is privilege-scoped, supporting separate inspection-failure handling.
- [Oban Migration docs](https://oban.hexdocs.pm/Oban.Migration.html) and [Oban isolation docs](https://hexdocs.pm/oban/isolation.html) — host-owned prefix migration/configuration and named-instance behavior.

### Secondary (MEDIUM confidence)

- [Ecto SQL connection documentation](https://hexdocs.pm/ecto_sql/3.13.1/Ecto.Adapters.SQL.Connection.html) — existing Ecto SQL context for raw query execution.

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — all dependencies/version locks are present in `mix.lock`; no new package is proposed. [VERIFIED: codebase inspection]
- Architecture: HIGH — phase decisions specify the legal boundary and inspected code identifies exact duplication/integration seams. [VERIFIED: codebase inspection]
- Pitfalls: HIGH — derived from the explicit mismatch/refusal contract and current raw-reason renderers. [VERIFIED: context decision D-119-06 through D-119-11]

**Research date:** 2026-08-09
**Valid until:** 2026-09-08 (stable dependency/API domain; revisit if Oban/Ecto version or host-binding contract changes).
