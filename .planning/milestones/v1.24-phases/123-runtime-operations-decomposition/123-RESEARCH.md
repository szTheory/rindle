# Phase 123: Runtime Operations Decomposition - Research

**Researched:** 2026-08-23
**Domain:** behavior-preserving Elixir/Postgres operations refactor
**Confidence:** HIGH

## User Constraints

### Locked Decisions

### Runtime diagnostics
- **D-123-01:** Keep `Rindle.Ops.RuntimeChecks.run/2` as the sole orchestration, aggregation, ordering,
  and telemetry boundary. Extract internal collaborators by diagnostic domain: core profile/delivery
  runtime, migration/ownership/Oban, and optional GCS/tus/streaming integrations.
- **D-123-02:** Keep the shared result constructors, per-check telemetry wrapper, final ID sort, and
  report aggregation together at the orchestration boundary. Do not introduce a configurable registry
  or independently public check APIs.

### Migration preflight
- **D-123-03:** Keep `Rindle.Migration.V1` authoritative for the fixed six-table-plus-marker catalog,
  DDL, directional move order, transactions, and the existing hidden preflight entry points.
- **D-123-04:** Extract only snapshot inspection and directional validation/classification into named
  bounded internals. Prefer one explicit shared classifier parameterized by direction when it preserves
  the current ordered refusal precedence; otherwise use two thin directional validators over shared
  predicates. The relation catalog and move sequence must never become configurable or duplicated.

### Runtime status and command presentation
- **D-123-05:** Keep `Rindle.Ops.RuntimeStatus.runtime_status/1` as the API orchestration boundary for
  filter validation, readiness-before-query refusal, report composition, recommendation composition,
  and refusal telemetry. Extract cohesive internal collectors and classifiers without exposing new
  public APIs.
- **D-123-06:** Separate runtime-status text/JSON and error presentation from
  `Mix.Tasks.Rindle.RuntimeStatus` command parsing and exit behavior. Preserve exact report fields,
  section order, JSON/text shapes, redaction, flags, limits, and non-zero failure semantics.

### Sequencing and proof
- **D-123-07:** Execute one surface at a time: runtime checks, migration preflight, then runtime-status
  API/formatting/task. Each slice must pass its focused behavioral and telemetry contracts plus SAFE-01
  before the next surface begins.
- **D-123-08:** Add objective behavior, telemetry, compiled-boundary, and structural tests only where
  current proof is insufficient. Do not freeze incidental source text, split helpers solely by line
  count, or broaden this phase into upload, test-support, dependency, Admin, or type-baseline work.

### the agent's Discretion
- Exact private module names and the smallest internal data structures, provided responsibility names
  remain domain-readable and the locked orchestration boundaries stay intact.
- Whether migration direction is represented by one shared classifier or two thin directional modules,
  decided from the simplest structure that makes refusal precedence obvious and non-duplicated.
- Test file placement and narrowly scoped structural assertions that prove dependency direction without
  coupling to function-body strings.

### Deferred Ideas (OUT OF SCOPE)

Upload/tus and broker decomposition remains Phase 124; generated-app and documentation test-support work
plus async issue #42 remains Phase 125; Dialyzer baseline retirement remains Phase 126. Public API changes,
schema or migration redesign, telemetry/error changes, dependency upgrades, Admin feature work, archive
normalization, and style-only churn remain out of scope.

## Project Constraints (from AGENTS.md)

- Keep edits focused and run the checks named by `RUNNING.md` for any implementation change. [VERIFIED: `AGENTS.md`]
- Preserve green-main release-train merge carriers; prefer PR-first execution for serious feature-depth work. [VERIFIED: `AGENTS.md`]
- Do not reopen or invent milestone work during demand-gated pause; Phase 123 is already approved roadmap scope. [VERIFIED: `AGENTS.md`; `.planning/ROADMAP.md`]
- Before release preparation, run `./scripts/maintainer/repo_hygiene_check.sh`; this research phase is not release preparation. [VERIFIED: `AGENTS.md`]

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| OPS-01 | `Rindle.Ops.RuntimeChecks` is a small orchestration boundary with cohesive diagnostic collaborators and unchanged result/telemetry contracts. [VERIFIED: `.planning/REQUIREMENTS.md`] | Runtime-check inventory, stable IDs, report shape, and telemetry lock identify the safe extraction seams. [VERIFIED: `lib/rindle/ops/runtime_checks.ex`; `test/rindle/ops/runtime_checks_test.exs`; `test/rindle/contracts/telemetry_contract_test.exs`] |
| OPS-02 | Named, bounded migration preflight components preserve the fixed owned-table catalog, transaction order, and reversal safety. [VERIFIED: `.planning/REQUIREMENTS.md`] | Snapshot, decision, and movement seams are identified together with populated-install regression coverage. [VERIFIED: `lib/rindle/migration/v1.ex`; `test/rindle/migration_test.exs`; `test/rindle/migration_fast_test.exs`] |
| OPS-03 | Runtime-status collection, formatting, and command concerns are separate while flags, output shapes, limits, and failures stay unchanged. [VERIFIED: `.planning/REQUIREMENTS.md`] | API orchestration, report-domain collectors, text/JSON presentation, and Mix parsing are independently bounded. [VERIFIED: `lib/rindle/ops/runtime_status.ex`; `lib/mix/tasks/rindle.runtime_status.ex`; related tests] |
| SAFE-01 | Subsequent refactors preserve public signatures, schema/migration behavior, telemetry names/metadata, error shapes, and CI/release invariants. [VERIFIED: `.planning/REQUIREMENTS.md`] | The existing fail-fast contract runner provides the phase baseline; focused runtime/migration/status tests supplement it. [VERIFIED: `scripts/maintainer/refactor_contract.sh`; Phase 121 verification] |

## Summary

Phase 123 should add no dependency and change no external operator contract. The repository already has a strong preservation baseline: the SAFE-01 runner recompiles, rejects compile cycles, and executes explicit API, schema, migration, telemetry, error, CI, and release contract suites. It does not currently select the heavy runtime-operations behavior tests, so each extraction plan needs a focused test command in addition to the runner. [VERIFIED: `scripts/maintainer/refactor_contract.sh`; `.planning/phases/121-truthful-quality-signals-mechanical-hygiene/121-VERIFICATION.md`]

The three hotspots are large private implementations behind small public faces: `RuntimeChecks.run/2` has one public report contract and per-check telemetry; `Migration.V1` exposes stable helper and directional-preflight contracts through `Rindle.Migration`; `RuntimeStatus.runtime_status/1` feeds the public `Rindle.runtime_status/1` facade, Admin queries, and the Mix task. Extraction should retain those facades and inject/keep dependencies at the existing boundary rather than broadening public APIs. [VERIFIED: `lib/rindle/ops/runtime_checks.ex`; `lib/rindle/migration.ex`; `lib/rindle/migration/v1.ex`; `lib/rindle/ops/runtime_status.ex`; `lib/rindle.ex`; `lib/rindle/admin/queries.ex`]

**Primary recommendation:** plan three sequential, independently testable refactor slices—RuntimeChecks diagnostic collaborators, V1 snapshot/preflight internals while retaining V1 DDL/moves, then RuntimeStatus collection/presentation/CLI—while leaving public entry points and SAFE-01 membership intact. [VERIFIED: current module boundaries, phase requirements, and `123-CONTEXT.md`]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Runtime doctor diagnostics | API / Backend | Database / Storage | `RuntimeChecks` resolves runtime/configuration state, conditionally runs diagnostics, builds a report, and reads migration/catalog state. [VERIFIED: `lib/rindle/ops/runtime_checks.ex`] |
| Populated-install migration preflight and moves | Database / Storage | API / Backend | V1 interrogates PostgreSQL catalogs/privileges and performs ordered `ALTER TABLE ... SET SCHEMA` operations; the public migration facade only validates pinned options. [VERIFIED: `lib/rindle/migration/v1.ex`; `lib/rindle/migration.ex`] |
| Runtime-status data collection | API / Backend | Database / Storage | Status validates filters and readiness, then queries Rindle and host-owned Oban relations using bounded prefixes. [VERIFIED: `lib/rindle/ops/runtime_status.ex`] |
| Operator report presentation | CLI | API / Backend | The Mix task translates flags into existing filters and renders the API report as text or JSON, with nonzero termination on error. [VERIFIED: `lib/mix/tasks/rindle.runtime_status.ex`] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Existing Elixir / Ecto / Postgrex stack | Project pins Elixir `~> 1.15`, `ecto_sql ~> 3.11`, `postgrex ~> 0.18` | Existing runtime, migrations, catalog inspection, and query execution | This phase is an internal decomposition; use the installed stack and do not add packages. [VERIFIED: `mix.exs`] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|
| Existing `:telemetry` | `~> 1.2` | Runtime check and refusal events | Preserve existing execution sites/event payloads during collaborator extraction. [VERIFIED: `mix.exs`; runtime modules] |
| Existing `:jason` | `~> 1.4` | CLI JSON output | Keep rendering in the task/presentation layer; do not change serialized report/error shape. [VERIFIED: `mix.exs`; status task] |

**Installation:** None—no external package is justified by this refactor. [VERIFIED: phase scope and existing dependencies]

## Package Legitimacy Audit

Not applicable: the recommended plan installs no external packages. [VERIFIED: phase scope]

## Architecture Patterns

### System Architecture Diagram

```text
mix rindle.doctor / Admin query
  -> RuntimeChecks.run/2 (argument/config snapshot + check schedule)
  -> diagnostic collaborators (delivery | runtime | migration/schema | Oban | profiles | streaming | GCS | tus)
  -> run_check telemetry wrapper
  -> stable sorted report {checks, failed, success?, total}

host Ecto migration
  -> Rindle.Migration directional validation
  -> V1 snapshot reader -> preflight decision
  -> provision target if allowed -> ordered fixed relation mover
  -> Ecto transaction rollback / bounded lock failure

mix rindle.runtime_status
  -> OptionParser -> Rindle.runtime_status/1 facade -> RuntimeStatus.runtime_status/1
  -> filter normalization -> ownership readiness gate
  -> collectors (assets | variants+Oban | upload sessions | provider assets | probe drift)
  -> stable report -> text formatter or JSON encoder -> shell / exit 1 on error
```

### Recommended Project Structure

```text
lib/rindle/ops/runtime_checks/
├── diagnostics.ex        # private check-domain functions returning existing check maps
├── schedule.ex           # conditional schedule construction only
└── result.ex             # existing result constructors and telemetry wrapper, if extraction clarifies it
lib/rindle/migration/v1/
├── snapshot.ex           # catalog + privilege + marker observation only
└── preflight.ex          # directional snapshot-to-outcome classification only; V1 retains DDL/moves
lib/rindle/ops/runtime_status/
├── readiness.ex          # ownership snapshot and bounded refusal classification
├── collectors.ex         # report-domain collection/query functions
└── filters.ex            # filter normalization and validation only
lib/mix/tasks/rindle/runtime_status/
└── formatter.ex          # text/error formatting only, if public helper exports remain on task facade
```

These are responsibility targets, not a mandate to create every listed file; planners should choose the smallest extraction that makes each owning module cohesive. [ASSUMED]

### Pattern 1: Thin public façade and internal collaborators

**What:** Retain `RuntimeChecks.run/2`, `RuntimeStatus.runtime_status/1`, `Rindle.runtime_status/1`, `Rindle.Migration` directional functions, and the Mix task `run/1` as the contract boundaries; move only private domain logic behind them. [VERIFIED: module public signatures and callers]

**When to use:** Every extraction in this phase, because current external consumers call those facades and current tests assert their output/telemetry. [VERIFIED: `lib/rindle.ex`; `lib/rindle/admin/queries.ex`; runtime/migration/task tests]

**Implementation rule:** collaborators return the exact existing data shape or preflight outcome; the façade owns final report assembly, telemetry sequencing, and externally visible errors. [VERIFIED: current orchestration implementations]

### Pattern 2: Observe → classify → mutate for migrations

**What:** Separate the catalog snapshot reader from a deterministic preflight classifier and from the move executor. [VERIFIED: `migration_snapshot/0`, `preflight_*`, and `move_owned_relations/3` already form these conceptual phases in `lib/rindle/migration/v1.ex`]

**When to use:** Only the populated-install directional move, not fresh `up/1` or destructive `down/1`. [VERIFIED: `lib/rindle/migration.ex`; `lib/rindle/migration/v1.ex`]

**Implementation rule:** the classifier must preserve its ordered condition precedence and exact return atoms; the executor must iterate `owned_relations/0` in the existing order. [VERIFIED: `lib/rindle/migration/v1.ex`; migration tests]

### Pattern 3: Normalize and gate before collecting status

**What:** Validate filter keys/values, then classify ownership readiness, then issue report queries. [VERIFIED: `RuntimeStatus.runtime_status/1`]

**When to use:** All status API and CLI calls, including errors. [VERIFIED: `test/rindle/ops/runtime_status_test.exs`; `test/rindle/runtime_status_task_test.exs`]

**Implementation rule:** keep the existing no-query-on-refusal property; diagnostics/formatters must not expose unsafe prefixes, URIs, or arbitrary adapter error text. [VERIFIED: runtime-status and task tests]

### Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| New report schema or generic query DSL | A refactor-time new abstraction/API | Existing maps, bounded filter allowlist, and public façade | Unknown filters are deliberately rejected and tests preserve shape/limits. [VERIFIED: `RuntimeStatus` filters and tests] |
| New migration catalog or relation list | Dynamic discovery / configurable owned-table set | `Migration.V1.owned_relations/0` and existing snapshot queries | The fixed six-table-plus-marker catalog is a safety contract. [VERIFIED: `lib/rindle/migration/v1.ex`; `test/rindle/migration_fast_test.exs`] |
| Custom transaction/rollback protocol | Application-managed compensation | Existing Ecto migration `execute/1` flow and host migration transaction | Current failure-injection tests prove reversal by transaction rollback. [VERIFIED: `lib/rindle/migration/v1.ex`; `test/rindle/migration_test.exs`] |
| New telemetry adapter/event vocabulary | Wrapper that renames/re-shapes events | Existing `run_check/1` and `emit_runtime_refusal/1` behavior | Telemetry allowlist and metadata tests make this observable public behavior. [VERIFIED: runtime modules; telemetry contract tests] |

## Exact Responsibility Seams

### OPS-01 — `Rindle.Ops.RuntimeChecks`

`run/2` should remain the only public façade and retain option resolution, profile resolution, conditional diagnostic schedule construction, `Enum.map(&run_check/1)`, sort-by-ID, and final count/report assembly. [VERIFIED: `lib/rindle/ops/runtime_checks.ex`]

Extract private checks by existing domain, with each collaborator receiving explicit resolved inputs and returning one existing check-result map:

| Collaborator boundary | Owns | Must not own |
|---|---|---|
| Core/runtime | delivery support, ffmpeg, local playback | telemetry emission or final aggregate. [VERIFIED: current private check functions] |
| Migration/schema | pending/unresolved migration status, resumable schema, Rindle ownership readiness | changing catalog queries, check IDs, or redaction. [VERIFIED: `runtime_checks.ex`; tests] |
| Oban | default binding, jobs ownership readiness, required queues | host migration policy or report aggregation. [VERIFIED: `runtime_checks.ex`; tests] |
| Profiles/streaming | profile loading/fit, credential/key/webhook/smoke checks | execution-order changes that affect per-check telemetry. [VERIFIED: `runtime_checks.ex`; streaming tests] |
| GCS/tus | only conditionally scheduled GCS and tus checks; existing `probe_gcs_bucket/4` and `do_probe/4` exports remain callable | unconditional rows for irrelevant profiles or HTTP behavior changes. [VERIFIED: `runtime_checks.ex`; GCS tests] |

The stable sorted check IDs, report keys, error count calculation, and one `[:rindle, :runtime, :check, :stop]` event per scheduled check with `%{duration_us: ...}` and `%{check, status, component}` are preservation boundaries. [VERIFIED: `runtime_checks.ex`; `test/rindle/ops/runtime_checks_test.exs`; `test/rindle/contracts/telemetry_contract_test.exs`]

### OPS-02 — `Rindle.Migration.V1` populated-install safety

Keep `Rindle.Migration` as the documented public validation façade and keep the V1 public helpers/specs stable: `current_version/0`, `marker_table/0`, `rindle_tables/0`, `owned_relations/0`, `catalog_requirements/0`, directional moves, and directional preflights. [VERIFIED: `lib/rindle/migration.ex`; `lib/rindle/migration/v1.ex`; migration fast/API surface tests]

Use three named internal components:

| Component | Inputs / output | Invariant |
|---|---|---|
| Snapshot reader | PostgreSQL schema/relation/marker/privilege observations → existing snapshot map | Query only `public`/`rindle` and `owned_relations/0`; preserve relation kinds, sort order, ownership checks, marker validation data, and privilege overrides used by tests. [VERIFIED: `migration_snapshot/0`] |
| Preflight classifier | snapshot → current success tuple, idempotence atom, or `{:refusal, reason}` | Preserve condition order and exact reason atoms, because users and tests rely on the bounded refusal path. [VERIFIED: `preflight_public_to_rindle/0`; `preflight_rindle_to_public/0`; migration tests] |
| V1 retained move path | source, destination, failure point → ordered `execute` moves | This remains in `V1`, which iterates fixed `owned_relations/0` order and preserves injected failure points and Postgrex lock translation. [VERIFIED: `move_owned_relations/3`; `move_relation!/3`; `123-CONTEXT.md` D-123-03/D-123-04] |

Move execution remains inside the host-owned Ecto migration transaction. On every injected failure point, database state must roll back; on lock-not-available, retain the existing `ArgumentError` guidance that says host relations were not touched; reverse movement remains separate from destructive `down/1` and does not drop the `rindle` schema. [VERIFIED: `lib/rindle/migration.ex`; `lib/rindle/migration/v1.ex`; `test/rindle/migration_test.exs`]

### OPS-03 — `RuntimeStatus` and `Mix.Tasks.Rindle.RuntimeStatus`

Keep `Rindle.runtime_status/1` as the documented public API façade, `RuntimeStatus.runtime_status/1` as the implementation entry, and Mix task `run/1` as the operator interface. [VERIFIED: `lib/rindle.ex`; `lib/rindle/ops/runtime_status.ex`; task module]

Split status implementation on these seams:

| Unit | Owns | Preserved contract |
|---|---|---|
| Filters | string/atom key normalization, allowlist, default limit, value validation | Allowed keys are exactly `profile`, `older_than`, `limit`, `format`, `provider_stuck`; exact error tuple shapes remain. [VERIFIED: `RuntimeStatus` source and tests] |
| Readiness | configured/legacy ownership snapshot resolution, classification, bounded refusal fields, refusal telemetry | Gate completes before report queries; retain `[:rindle, :runtime, :refusal]` event name/metadata. [VERIFIED: source; runtime-status and telemetry tests] |
| Collectors | probe drift, asset counts, variant+Oban correlation, upload/resumable data, provider assets, recommendations | Preserve query prefix routing, filter application, thresholds, sample limits, finding shape, redaction, and report keys. [VERIFIED: `RuntimeStatus` source and tests] |
| Task parsing | `OptionParser` flag set → existing API filter map | Preserve flags, CLI key translation (`older_than_sec` → `older_than`), JSON selection, and exit status. [VERIFIED: task source/tests] |
| Task formatting | text line ordering and bounded text/JSON error representation | Preserve text section ordering, JSON encoding shape, no raw secret/URI/adapter error leakage, and exit `{:shutdown, 1}` on errors. [VERIFIED: task source/tests] |

Do not move formatting helpers to a new externally visible module unless task helper exports (`format_error/1`, `format_json_error/1`, `format_text_report/1`, and `format_provider_findings/1`) remain available with the same output. [VERIFIED: task module and direct tests]

## Runtime State Inventory

This is a refactor phase, so runtime state was audited.

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | PostgreSQL `public` and `rindle` schemas can contain the fixed owned relation set plus marker version rows; ordinary runtime-status reads query Rindle and configured Oban prefixes. [VERIFIED: migration/status source] | No data migration for decomposition; tests must continue exercising populated moves and prefixed report reads. [VERIFIED: phase scope] |
| Live service config | Application env selects RuntimeChecks inputs, RuntimeStatus ownership snapshot/readiness/report query test seams, profile modules, Oban config/prefix, and optional streaming/GCS behavior. [VERIFIED: runtime source/tests] | Preserve keys and evaluation order; do not rename config contracts. [VERIFIED: phase scope] |
| OS-registered state | None found in the inspected runtime-operation modules or Phase 123 scope. [VERIFIED: codebase grep] | None. [VERIFIED: phase scope] |
| Secrets/env vars | Streaming credentials and GCS configuration are read by diagnostics; status refusal/task tests explicitly guard secret and URI redaction. [VERIFIED: `runtime_checks.ex`; runtime/task tests] | Preserve redaction and avoid moving raw values into report/formatter data. [VERIFIED: tests] |
| Build artifacts | No owned installed-package rename or generated-artifact change is in scope. [VERIFIED: phase scope] | Recompile and run tests after extraction; no artifact migration. [VERIFIED: SAFE-01 runner] |

## Common Pitfalls

### Pitfall 1: Turning the doctor façade into a dispatcher that changes observable scheduling

**What goes wrong:** A collaborator extraction accidentally adds a check for inapplicable profiles, changes conditional GCS/tus inclusion, emits events in a different count/order, or changes stable IDs. [VERIFIED: `RuntimeChecks` schedule and tests]

**How to avoid:** Make schedule construction explicit in the façade, retain sort-by-ID and the existing telemetry wrapper, and execute runtime-check + streaming + GCS focused tests. [VERIFIED: source/tests]

### Pitfall 2: Treating preflight outcomes as interchangeable booleans

**What goes wrong:** A simplified classifier collapses idempotence, provisionable target, usable target, or refusal reasons; a reordered conditional changes the first safe refusal. [VERIFIED: `Migration.V1` preflight code/tests]

**How to avoid:** Represent the existing tuple/atom result exactly and test the full populated-install matrix plus injected rollbacks. [VERIFIED: migration tests]

### Pitfall 3: Letting status helpers query before refusal

**What goes wrong:** Reordering collection ahead of readiness breaks the deliberate "no report queries ran" guarantee and can expose unsafe state. [VERIFIED: `RuntimeStatus.runtime_status/1`; status/task tests]

**How to avoid:** Preserve `normalize_filters → ready_snapshot → collection`; retain report-query tripwire tests. [VERIFIED: source/tests]

### Pitfall 4: Treating CLI presentation as cosmetic

**What goes wrong:** Refactoring formatting changes section order, text/JSON refusal fields, redaction, or exit status. [VERIFIED: task tests]

**How to avoid:** Keep direct formatter tests and assert shell messages / `{:shutdown, 1}` behavior. [VERIFIED: `test/rindle/runtime_status_task_test.exs`]

## Public and Internal Contracts to Preserve

- Public signatures: `Rindle.runtime_status/1`; `Rindle.Migration` fresh, destructive, and directional API; `RuntimeChecks.run/2`; task `run/1` and currently direct-tested formatter helpers. [VERIFIED: respective source/tests]
- Result contracts: doctor report `%{checks, failed, success?, total}` and stable check result fields; runtime status top-level report keys and normalized `filters`; current finding/recommendation structures. [VERIFIED: runtime source/tests]
- Migration contracts: six owned tables plus marker, current version `1`, move ordering, preflight result atoms/tuples, rollback, host relation exclusion, and reverse-move semantics. [VERIFIED: `Migration.V1`; migration tests]
- Telemetry: runtime-check stop and runtime-status refusal event names, measurement keys, and metadata. [VERIFIED: `test/rindle/contracts/telemetry_contract_test.exs`]
- Error/security contracts: exact filter/refusal tuple families; no unsafe prefix, credential, session URI, or provider identifier leakage beyond existing redaction. [VERIFIED: status/task/runtime-check tests]
- Release/CI contracts: keep SAFE-01 runner membership and its compile-cycle/explicit test behavior unchanged; maintain normal repository gates. [VERIFIED: `scripts/maintainer/refactor_contract.sh`; `AGENTS.md`]

## State of the Art

No new framework adoption is warranted. This phase’s current best practice is repository-local: expose thin stable facades, use explicit domain collaborators, and prove behavior through the installed regression suite. [VERIFIED: phase scope; current architecture]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The exact collaborator file layout should be selected minimally during planning rather than implemented verbatim from the suggested structure. | Architecture Patterns | Low—affects file naming only, not required preservation boundaries. |

## Open Questions (RESOLVED)

1. **How far should RuntimeChecks split on its first extraction?**
   - What we know: it spans core, schema/Oban, profile/streaming, GCS, and tus domains in 1,803 lines. [VERIFIED: `lib/rindle/ops/runtime_checks.ex`]
   - **Disposition:** Select exactly three coarse internal domains per D-123-01 and `123-VALIDATION.md` Wave 0: core profile/delivery runtime; migration/ownership/Oban; and optional GCS/tus/streaming integrations. `IntegrationChecks` owns all three optional domains; no one-module-per-check split or configurable registry is planned. [RESOLVED]
2. **Whether task formatter helpers move or delegate.**
   - What we know: tests call several helpers directly on the Mix task. [VERIFIED: `test/rindle/runtime_status_task_test.exs`]
   - **Disposition:** Keep `format_error/1`, `format_json_error/1`, `format_text_report/1`, and `format_provider_findings/1` as task-module compatibility delegates to the internal formatter per D-123-06 and `123-VALIDATION.md` Wave 0. [RESOLVED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir / Mix | compile and ExUnit validation | ✓ | Elixir/Mix 1.19.5; OTP 28 | Project support matrix, not local newest toolchain, defines acceptance. [VERIFIED: local command; `mix.exs`] |
| PostgreSQL client | populated migration inspection/tests | ✓ | psql 14.17 | Existing repo test configuration. [VERIFIED: local command] |
| Docker | broader integration lanes when required | ✓ | 29.5.2 | Not required for focused decomposition proof. [VERIFIED: local command; phase scope] |

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit through Mix. [VERIFIED: `mix.exs`; test tree] |
| Config file | `mix.exs` aliases and repository test support. [VERIFIED: `mix.exs`] |
| Quick run command | `mix test test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_checks_streaming_test.exs test/rindle/migration_fast_test.exs test/rindle/migration_test.exs test/rindle/ops/runtime_status_test.exs test/rindle/runtime_status_task_test.exs` [ASSUMED] |
| Preservation command | `bash scripts/maintainer/refactor_contract.sh` [VERIFIED: script] |
| Full suite command | `mix ci` [VERIFIED: `mix.exs`] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| OPS-01 | Stable runtime-check IDs, conditional domains, result shape, telemetry | unit/contract | `mix test test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_checks_streaming_test.exs test/rindle/contracts/telemetry_contract_test.exs` | ✅ [VERIFIED: test tree] |
| OPS-02 | Fixed catalog, preflight matrix, ordered populated move, rollback/reversal | integration | `mix test test/rindle/migration_fast_test.exs test/rindle/migration_test.exs` | ✅ [VERIFIED: test tree] |
| OPS-03 | status shapes/filters/readiness, CLI flags/text/JSON/redaction/exit | integration/unit | `mix test test/rindle/ops/runtime_status_test.exs test/rindle/runtime_status_task_test.exs` | ✅ [VERIFIED: test tree] |
| SAFE-01 | public/schema/migration/telemetry/error/CI/release preservation | contract | `bash scripts/maintainer/refactor_contract.sh` | ✅ [VERIFIED: script/test tree] |

### Sampling Rate

- **Per task commit:** relevant focused command above plus `bash scripts/maintainer/refactor_contract.sh`. [VERIFIED: existing suites; Phase 121 SAFE-01 contract]
- **Per wave merge:** `mix ci` when the project’s configured services/toolchain permit it. [VERIFIED: `mix.exs`; `AGENTS.md`]
- **Phase gate:** focused runtime-operation tests and SAFE-01 green before verification; retain normal release-train checks. [VERIFIED: phase requirements; AGENTS.md]

### Wave 0 Gaps

None required before implementation: the behavior-bearing test suites and SAFE-01 runner already exist. Add only narrowly targeted regression tests if an extraction reveals an unasserted seam. [VERIFIED: existing test inventory]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | No authentication behavior is in scope. [VERIFIED: phase scope] |
| V3 Session Management | Yes | Preserve session-URI omission/redaction in runtime status output. [VERIFIED: status/task tests] |
| V4 Access Control | Yes | Preserve host-versus-Rindle ownership boundaries and no host-relation moves. [VERIFIED: migration/status source] |
| V5 Input Validation | Yes | Keep runtime-status filter allowlist/type validation and pinned migration options. [VERIFIED: source/tests] |
| V6 Cryptography | No | No cryptographic algorithm or key handling is changed; diagnostics only preserve bounded treatment of configuration. [VERIFIED: phase scope; runtime checks] |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Sensitive runtime data in report/error output | Information disclosure | Gate before queries; safe-prefix allowlist; constant unknown-error copy; URI/provider-ID redaction tests. [VERIFIED: status/task tests] |
| Moving host-owned database relations | Tampering / Elevation of privilege | Fixed Rindle relation catalog, ownership preflight, and host-owned Oban/schema-migrations exclusions. [VERIFIED: migration source/tests] |
| Malformed/unbounded operator filters | Denial of service / Tampering | Explicit filter-key allowlist, positive limit, and typed normalizers. [VERIFIED: `RuntimeStatus` source/tests] |

## Sources

### Primary (HIGH confidence)

- `lib/rindle/ops/runtime_checks.ex` — orchestration, check domains, report/telemetry contracts. [VERIFIED: codebase grep]
- `lib/rindle/migration/v1.ex` and `lib/rindle/migration.ex` — fixed catalog, snapshot/preflight/move contracts. [VERIFIED: codebase grep]
- `lib/rindle/ops/runtime_status.ex`, `lib/mix/tasks/rindle.runtime_status.ex`, and `lib/rindle.ex` — status API, collection, presentation, and CLI contracts. [VERIFIED: codebase grep]
- Runtime, migration, task, telemetry, and SAFE-01 test/script files named in Validation Architecture. [VERIFIED: codebase grep]

### Secondary (MEDIUM confidence)

- Context7 research-plan seam was invoked, but no Context7 MCP tool or `ctx7` CLI was available; no external documentation claim is used. [VERIFIED: local tool availability]

### Tertiary (LOW confidence)

- Suggested internal file layout and the coarse collaborator count are assumptions for planner judgment, not locked architecture. [ASSUMED]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new stack; direct `mix.exs` inspection. [VERIFIED: `mix.exs`]
- Architecture: HIGH — seams derived from current source, callers, and tests. [VERIFIED: codebase grep]
- Pitfalls: HIGH — each is locked by current regression tests or observed source ordering. [VERIFIED: source/tests]

**Research date:** 2026-08-23
**Valid until:** implementation start; re-check only if Phase 123 source/tests change before planning.
