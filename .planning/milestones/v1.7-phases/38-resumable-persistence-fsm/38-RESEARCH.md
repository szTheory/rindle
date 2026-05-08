# Phase 38: Resumable Persistence + FSM - Research

**Researched:** 2026-05-07
**Domain:** Additive upload-session persistence, durable FSM extension, secret redaction, telemetry-contract freeze, and narrow doctor schema-drift validation
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Migration Posture

- **D-01:** Ship the Phase 38 schema change as the normal packaged Rindle
  migration template under `priv/repo/migrations`, consistent with the
  existing adopter-owned Repo/migration handoff.
- **D-02:** `session_uri` uses `:text` in the packaged migration template, not
  `:string`, because GCS resumable session URIs can exceed 255 characters.
- **D-03:** Add `session_uri_expires_at :utc_datetime_usec`,
  `last_known_offset :bigint, default: 0, null: false`, and
  `region_hint :string, size: 64, null: true`.
- **D-04:** Add the partial expiry index filtered to
  `upload_strategy = 'resumable'` for maintenance/expiry sweeps.
- **D-05:** Widen `upload_strategy` to include `"resumable"` in the schema and
  migration posture, but Phase 38 does **not** add resumable runtime semantics
  beyond persistence/FSM groundwork.

### Secret Handling And At-Rest Posture

- **D-06:** `session_uri` is a bearer credential, not routine metadata. Treat
  it as a secret in logs, telemetry, inspect output, and persistence
  discussions.
- **D-07:** Rindle does **not** force `cloak_ecto`, a Vault, or an encrypted
  column type into the packaged migration. The install-default path stays plain
  and dependency-light.
- **D-08:** Phase 38 context must explicitly call out the adopter off-ramp:
  teams with stricter at-rest requirements may replace the packaged
  `session_uri` column with an app-local encrypted-field posture
  (`:binary` column plus `Cloak.Ecto.Binary` or equivalent) before rollout.
- **D-09:** Phase 41 docs must include the full optional encrypted-at-rest
  recipe and the caveat that switching from plain `:text` to encrypted
  `:binary` later is a deliberate follow-on migration/backfill.

### FSM Semantics

- **D-10:** `Rindle.Domain.UploadSessionFSM` gains a new durable state
  `"resuming"` with the locked lane:
  `"signed" -> "resuming" -> "uploading"`.
- **D-11:** `"resuming"` has a **narrow** meaning: the session has entered an
  explicit recovery/resume path after interruption or uncertain completion. It
  is **not** a generic "someone asked for status" state.
- **D-12:** Status polling and offset discovery alone must not mutate durable
  lifecycle state. The explicit footgun to avoid is: harmless status probes
  must not make rows look more progressed than they are.
- **D-13:** Maintenance and operator surfaces should treat `"resuming"` as a
  real in-flight state only when recovery is actually underway, not whenever a
  client or operator checks offset/status.

### MediaUploadSession Schema And Inspect

- **D-14:** `Rindle.Domain.MediaUploadSession.changeset/2` casts the four new
  fields and preserves the coarse durable-session posture already used by the
  broker and maintenance layers.
- **D-15:** Add a custom `Inspect` implementation for
  `Rindle.Domain.MediaUploadSession` that always redacts populated
  `session_uri` values to `"[REDACTED]"`.
- **D-16:** The redaction rule is absolute across operator surfaces:
  `inspect/2`, logger metadata, test failures, and telemetry metadata must
  never contain raw `session_uri`.

### Telemetry Contract

- **D-17:** Phase 38 freezes exactly two new **public** resumable telemetry
  events:
  - `[:rindle, :upload, :resumable, :status]`
  - `[:rindle, :upload, :resumable, :cancel]`
- **D-18:** Do **not** publish a broader resumable public family in Phase 38.
  `:start`, `:stop`, or richer GCS-specific events can be added later only if
  they are truly needed and only additively.
- **D-19:** Required metadata follows Rindle's existing telemetry posture:
  `:profile` and `:adapter` are required. Allowed low-cardinality metadata keys
  for resumable events are `:state`, `:outcome`, `:reason`, and `:source`.
  `:session_id` may be present as correlation metadata but is not the public
  contract focus.
- **D-20:** Measurements stay numeric and boring:
  - `:status` uses `:committed_bytes`, optional `:offset_delta`, and
    `:system_time`
  - `:cancel` uses `:duration_us` and `:system_time`
- **D-21:** `session_uri`, raw GCS session identifiers, headers, storage keys,
  and response bodies are forbidden in telemetry metadata and failure strings.
- **D-22:** Add a parity/redaction test mirroring the Phase 34 Mux pattern:
  every resumable emit site must prove that `session_uri` never crosses the
  telemetry boundary.
- **D-23:** Phase 39 may extend the resumable telemetry family only
  additively, reusing the same metadata vocabulary rather than renaming it.

### Doctor Check Style

- **D-24:** Phase 38 adds one narrow schema-drift check to
  `mix rindle.doctor`, e.g. `doctor.resumable_session_schema`, implemented via
  direct DB introspection against the adopter-owned table.
- **D-25:** This check confirms the presence of:
  - `session_uri`
  - `session_uri_expires_at`
  - `last_known_offset`
  - `region_hint`
  - the resumable expiry partial index
- **D-26:** One extra structural guard is acceptable if cheap and stable:
  verify `last_known_offset` is `NOT NULL DEFAULT 0`.
- **D-27:** Phase 38 doctor stays **schema-only**. It must not inspect
  profile capability advertisement, GCS runtime config, CORS posture, or
  resumable usage semantics yet.
- **D-28:** More opinionated resumable/GCS checks remain Phase 41 work and
  must be profile-gated so unrelated adopters see zero new noise.

### Decision-Making Preference (Carried Forward, Tightened)

- **D-29:** Carry forward and tighten the standing project preference:
  downstream researchers, planners, and executors should front-load research,
  produce coherent one-shot recommendation sets, decide by default, and avoid
  escalating low-blast-radius design choices back to the user.
- **D-30:** Escalate only for genuinely high-blast-radius decisions such as
  semver-significant public API reshapes, destructive or irreversible
  operations, security/compliance boundary changes, real-cost surprises, or
  milestone/scope reshapes. Phase 38 has no unresolved item that crosses that
  bar.

### Claude's Discretion (Planner / Executor)

- Exact migration filename timestamp and whether the Phase 38 artifact is a
  literal migration file or a generator-template-styled packaged migration file,
  so long as it preserves the adopter-owned migration handoff.
- Whether the doctor schema check validates index name exactly or validates the
  effective partial-index shape through catalog introspection.
- Exact helper organization for resumable redaction and telemetry emit helpers,
  so long as the redaction invariant remains centralized and parity-tested.
- Exact phrasing of doctor PASS/FAIL summaries and fix text.

### Deferred Ideas (OUT OF SCOPE)

- This phase does **not** ship adapter resumable callbacks, broker resumable
  entrypoints, GCS session initiation/status/cancel behavior, or
  resumable-aware runtime-status/CORS diagnostics. Those land in Phases 39-41.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| RESUMABLE-01 | Migration adds resumable columns and widens `upload_strategy`; reversible packaged migration under `priv/repo/migrations`. | Migration posture, schema analogs, doctor schema-introspection pattern, and runtime-state inventory below. `[VERIFIED: .planning/REQUIREMENTS.md, priv/repo/migrations/*.exs, lib/rindle/ops/runtime_checks.ex]` |
| RESUMABLE-02 | `MediaUploadSession.changeset/2` casts new fields; FSM gains `"resuming"`; custom `Inspect` redacts `session_uri`. | Existing schema/FSM/Inspect analogs and redaction invariants below. `[VERIFIED: .planning/REQUIREMENTS.md, lib/rindle/domain/media_upload_session.ex, lib/rindle/domain/upload_session_fsm.ex, lib/rindle/domain/media_provider_asset.ex]` |
| RESUMABLE-03 | Freeze resumable public telemetry contract and prevent `session_uri` leakage in telemetry/logs/inspect; document logger recipe later. | Existing telemetry contract lane, Mux parity-test pattern, and doctor/output boundaries below. `[VERIFIED: .planning/REQUIREMENTS.md, test/rindle/contracts/telemetry_contract_test.exs, test/rindle/streaming/provider/mux/telemetry_test.exs]` |
</phase_requirements>

## Summary

Phase 38 should be planned as an additive, low-blast-radius extension of existing upload-session infrastructure rather than as the start of full resumable runtime behavior. The repo already has the right ownership seams: packaged adopter-run migrations under `priv/repo/migrations`, a coarse durable upload FSM, a `MediaUploadSession` schema that the broker/maintenance path already trusts, a public telemetry allowlist test, and a doctor framework that appends narrow checks without restructuring the command. `[VERIFIED: priv/repo/migrations/20260425090200_create_media_upload_sessions.exs, priv/repo/migrations/20260428110000_extend_media_upload_sessions_for_multipart.exs, lib/rindle/domain/media_upload_session.ex, lib/rindle/domain/upload_session_fsm.ex, lib/rindle/ops/runtime_checks.ex, test/rindle/contracts/telemetry_contract_test.exs]`

The practical planning split is: 1. packaged migration plus schema-drift coverage, 2. schema/FSM/redaction changes, 3. telemetry-contract freeze plus parity tests and the narrow doctor check. Reusing existing patterns matters more than inventing new abstractions here. The repo already demonstrates the right analogs: multipart extended `media_upload_sessions` additively, `MediaProviderAsset` centralizes secret redaction with `defimpl Inspect`, `LifecycleFSMTest` locks state matrices, `MigrationTest` uses direct catalog introspection, and `RuntimeChecks` appends small profile-aware checks rather than building a second diagnostics subsystem. `[VERIFIED: priv/repo/migrations/20260428110000_extend_media_upload_sessions_for_multipart.exs, lib/rindle/domain/media_provider_asset.ex, test/rindle/domain/lifecycle_fsm_test.exs, test/rindle/domain/migration_test.exs, lib/rindle/ops/runtime_checks.ex, test/rindle/ops/runtime_checks_test.exs]`

The only meaningful planning ambiguity is telemetry timing. The phase boundary freezes `[:rindle, :upload, :resumable, :status]` and `[:rindle, :upload, :resumable, :cancel]`, but the natural public status/cancel entrypoints are explicitly deferred to Phases 39-41. The planner should avoid manufacturing broad resumable APIs just to create emit sites in Phase 38; keep the contract, helper organization, and redaction-proofing narrow enough that later phases can attach real emits additively. `[VERIFIED: .planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md, .planning/ROADMAP.md] [ASSUMED: actual first emit sites may land in Phase 39/40 rather than Phase 38 if scope is kept strict]`

**Primary recommendation:** Plan three slices in this order: packaged migration + schema test + doctor drift check, then `MediaUploadSession`/FSM/Inspect changes, then telemetry contract/parity coverage with no Phase-39 broker or adapter behavior pulled forward. `[VERIFIED: .planning/ROADMAP.md, .planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md]`

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Packaged migration under `priv/repo/migrations` | Database / Storage | API / Backend | The adopter-owned database schema changes first; app code only consumes the new columns after migration. `[VERIFIED: guides/getting_started.md, guides/upgrading.md, priv/repo/migrations/*.exs]` |
| `MediaUploadSession` field widening and `upload_strategy = "resumable"` | API / Backend | Database / Storage | The Ecto schema and changeset define the writable surface while the DB stores the additive columns and default. `[VERIFIED: lib/rindle/domain/media_upload_session.ex, priv/repo/migrations/20260428110000_extend_media_upload_sessions_for_multipart.exs]` |
| Durable `"resuming"` state | API / Backend | Database / Storage | `UploadSessionFSM` is the contract boundary for legal state mutation; the DB just persists the chosen state string. `[VERIFIED: lib/rindle/domain/upload_session_fsm.ex, test/rindle/domain/lifecycle_fsm_test.exs]` |
| `session_uri` redaction in inspect/log/test surfaces | API / Backend | — | Redaction belongs at the domain boundary before values reach logs, telemetry, or failure output. `[VERIFIED: lib/rindle/domain/media_provider_asset.ex, test/rindle/domain/media_provider_asset_test.exs]` |
| Public resumable telemetry vocabulary | API / Backend | — | Public telemetry is emitted by backend lifecycle code and frozen by contract tests. `[VERIFIED: test/rindle/contracts/telemetry_contract_test.exs, lib/rindle/upload/broker.ex]` |
| Narrow doctor schema-drift check | API / Backend | Database / Storage | `mix rindle.doctor` owns the check orchestration, but the check itself introspects adopter DB catalog state. `[VERIFIED: lib/rindle/ops/runtime_checks.ex, test/rindle/ops/runtime_checks_test.exs]` |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `ecto_sql` | `3.13.5` locked in repo; latest `3.13.5` on Hex | Packaged migrations and schema-drift introspection | Phase 38 is primarily Ecto migration work; no new migration framework is needed. `[VERIFIED: mix.lock, mix hex.info ecto_sql, https://hexdocs.pm/ecto_sql/Ecto.Migration.html]` |
| `ecto` | `3.13.5` locked in repo; latest `3.13.6` on Hex | Changesets and schema casting for `MediaUploadSession` | The phase only needs existing changeset/schema features; no Ecto upgrade is justified by scope. `[VERIFIED: mix.lock, mix hex.info ecto]` |
| `postgrex` | `0.22.0` locked in repo | Direct catalog queries in migration and doctor tests | Existing migration-smoke tests and doctor behavior already assume PostgreSQL catalog access. `[VERIFIED: mix.lock, test/rindle/domain/migration_test.exs, lib/rindle/ops/runtime_checks.ex]` |
| `telemetry` | `1.4.1` locked in repo | Public event family and parity assertions | The public contract already uses `:telemetry` directly and Phase 38 extends that contract additively. `[VERIFIED: mix.lock, test/rindle/contracts/telemetry_contract_test.exs, lib/rindle/upload/broker.ex]` |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ExUnit | bundled with Elixir `1.19.5` in this environment | FSM matrix, inspect redaction, doctor output, and migration smoke coverage | Use for all Phase 38 verification lanes; no new test framework is needed. `[VERIFIED: elixir --version, mix --version, test/**/*.exs]` |
| `oban` | `2.21.1` locked in repo | Regression boundary only | Use only to confirm existing maintenance/cleanup paths remain unaffected by the new state vocabulary. `[VERIFIED: mix.lock, lib/rindle/ops/upload_maintenance.ex]` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Existing `media_upload_sessions` table | New resumable-specific table | Adds persistence split, new ownership rules, and extra joins for no Phase-38 benefit. `[VERIFIED: lib/rindle/domain/media_upload_session.ex, .planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md]` |
| Custom `Inspect` implementation | `@derive {Inspect, only: ...}` | `@derive` cannot express absolute redaction semantics as clearly as a dedicated `defimpl` that rewrites fields. `[CITED: https://hexdocs.pm/elixir/Inspect.html] [VERIFIED: lib/rindle/domain/media_provider_asset.ex]` |
| Direct catalog introspection for doctor/migration tests | New schema-diff abstraction | The repo already uses `information_schema`, `pg_indexes`, and `Ecto.Migrator.migrations/2`; another layer would be churn without value. `[VERIFIED: test/rindle/domain/migration_test.exs, lib/rindle/ops/runtime_checks.ex]` |
| Plain packaged `:text` column with documented adopter off-ramp | Forced encrypted column dependency now | Contradicts locked Phase 38 posture and would impose new deps on all adopters. `[VERIFIED: .planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md]` |

**Installation:**
```bash
# No new dependencies are required for Phase 38.
mix deps.get
```

**Version verification:** `ecto_sql 3.13.5`, `ecto 3.13.6 latest / 3.13.5 locked`, `goth 1.4.5`, `finch 0.21.0`, and `gcs_signed_url 0.4.6` were verified on Hex on 2026-05-07; the repo lock already contains the current Phase-37 GCS stack. `[VERIFIED: mix hex.info ecto_sql, mix hex.info ecto, mix hex.info goth, mix hex.info finch, mix hex.info gcs_signed_url, mix.lock]`

## Architecture Patterns

### System Architecture Diagram

```text
Adopter Repo migration runner
  -> host app `Ecto.Migrator.run/4`
  -> packaged `priv/repo/migrations/*_phase38_*.exs`
  -> `media_upload_sessions` gains resumable columns + partial index

Runtime upload/session code
  -> `MediaUploadSession.changeset/2` casts new fields
  -> `UploadSessionFSM.transition/3` permits `signed -> resuming -> uploading`
  -> `defimpl Inspect` redacts `session_uri`
  -> existing broker / maintenance paths keep coarse durable semantics

Operator / verification surfaces
  -> `TelemetryContractTest` allowlist widens additively
  -> resumable parity test proves `session_uri` never reaches metadata
  -> `RuntimeChecks` appends `doctor.resumable_session_schema`
  -> doctor introspects DB columns/index/defaults only
```

### Recommended Project Structure

```text
priv/repo/migrations/
├── <timestamp>_extend_media_upload_sessions_for_resumable.exs  # packaged additive migration

lib/rindle/domain/
├── media_upload_session.ex   # new fields + custom Inspect impl
└── upload_session_fsm.ex     # add "resuming" lane only

lib/rindle/ops/
└── runtime_checks.ex         # one narrow schema-drift check

test/rindle/
├── domain/
│   ├── media_upload_session_test.exs   # new schema/Inspect coverage
│   ├── lifecycle_fsm_test.exs          # extend upload-session matrix
│   └── migration_test.exs              # new table/index/default checks
├── contracts/telemetry_contract_test.exs
├── streaming/provider/mux/telemetry_test.exs  # mirror pattern only
└── ops/runtime_checks_test.exs
```

### Pattern 1: Extend The Existing Packaged Migration Handoff

**What:** Add one new packaged migration beside the existing `create_media_upload_sessions` and multipart-extension migrations. `[VERIFIED: priv/repo/migrations/20260425090200_create_media_upload_sessions.exs, priv/repo/migrations/20260428110000_extend_media_upload_sessions_for_multipart.exs]`

**When to use:** Any additive upload-session schema change that adopters must run in their own Repo. `[VERIFIED: guides/getting_started.md, guides/upgrading.md]`

**Example:**
```elixir
# Source pattern: priv/repo/migrations/20260428110000_extend_media_upload_sessions_for_multipart.exs
def change do
  alter table(:media_upload_sessions) do
    add :session_uri, :text
    add :session_uri_expires_at, :utc_datetime_usec
    add :last_known_offset, :bigint, null: false, default: 0
    add :region_hint, :string, size: 64
  end

  create index(:media_upload_sessions, [:session_uri_expires_at],
           where: "upload_strategy = 'resumable'",
           name: :media_upload_sessions_resumable_expiry_idx
         )
end
```
[CITED: https://hexdocs.pm/ecto_sql/Ecto.Migration.html] [VERIFIED: .planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md]

### Pattern 2: Centralize Secret Redaction In The Domain Struct

**What:** Follow the `MediaProviderAsset` model: one canonical redaction rule in the domain module plus one `defimpl Inspect` that uses it. `[VERIFIED: lib/rindle/domain/media_provider_asset.ex, test/rindle/domain/media_provider_asset_test.exs]`

**When to use:** Any field whose raw value must never appear in logs, failures, or telemetry-adjacent debugging output. `[VERIFIED: .planning/PROJECT.md, .planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md]`

**Example:**
```elixir
# Source pattern: lib/rindle/domain/media_provider_asset.ex
defimpl Inspect, for: Rindle.Domain.MediaUploadSession do
  def inspect(session, opts) do
    redacted = %{session | session_uri: if(session.session_uri, do: "[REDACTED]", else: nil)}
    Inspect.Any.inspect(redacted, opts)
  end
end
```
[CITED: https://hexdocs.pm/elixir/Inspect.html] [VERIFIED: lib/rindle/domain/media_provider_asset.ex]

### Pattern 3: Keep FSM States Coarse And Durable

**What:** Extend `UploadSessionFSM` by one durable edge instead of making it a transcript of every storage RPC. `[VERIFIED: lib/rindle/domain/upload_session_fsm.ex, .planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md]`

**When to use:** Lifecycle milestones that operators and maintenance jobs need to understand later. `[VERIFIED: lib/rindle/ops/upload_maintenance.ex, guides/operations.md]`

**Example:**
```elixir
# Source pattern: lib/rindle/domain/upload_session_fsm.ex
@allowed_transitions %{
  "signed" => ["resuming", "uploading", "uploaded", "verifying", "aborted", "expired", "failed"],
  "resuming" => ["uploading", "aborted", "expired", "failed"]
}
```
[VERIFIED: lib/rindle/domain/upload_session_fsm.ex, .planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md]

### Anti-Patterns to Avoid

- **Do not add Phase-39 broker or adapter APIs now:** the phase boundary explicitly defers resumable initiation/status/cancel semantics. `[VERIFIED: .planning/ROADMAP.md, .planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md]`
- **Do not make status polling mutate durable state:** `"resuming"` means explicit recovery, not passive observation. `[VERIFIED: .planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md]`
- **Do not scatter `session_uri` scrubbing across emit sites:** centralize redaction in the schema/Inspect helper and prove parity by test. `[VERIFIED: lib/rindle/domain/media_provider_asset.ex, test/rindle/streaming/provider/mux/telemetry_test.exs]`
- **Do not add a DB enum/check constraint to `upload_strategy` in this phase:** the existing column is a plain string today, so retrofitting a stricter storage contract would exceed the additive posture. `[VERIFIED: priv/repo/migrations/20260428110000_extend_media_upload_sessions_for_multipart.exs]`

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Resumable session persistence | Separate resumable table or bespoke persistence service | Existing `media_upload_sessions` schema plus additive columns | The broker and maintenance layers already depend on this table and state model. `[VERIFIED: lib/rindle/upload/broker.ex, lib/rindle/ops/upload_maintenance.ex]` |
| Secret-safe inspect/log behavior | Per-callsite `Map.drop` / `inspect` wrappers | `defimpl Inspect` on `MediaUploadSession` | One rule protects logs, ExUnit failures, and `IEx` output consistently. `[CITED: https://hexdocs.pm/elixir/Inspect.html] [VERIFIED: lib/rindle/domain/media_provider_asset.ex]` |
| Telemetry surface definition | Informal comments or ad-hoc tests | Extend `TelemetryContractTest` plus parity test | The repo already freezes public telemetry via an allowlist test. `[VERIFIED: test/rindle/contracts/telemetry_contract_test.exs, test/rindle/streaming/provider/mux/telemetry_test.exs]` |
| Schema drift detection | New schema-diff framework | Direct SQL catalog queries in migration tests and one `RuntimeChecks` row | Existing repo patterns are simpler and already trusted. `[VERIFIED: test/rindle/domain/migration_test.exs, lib/rindle/ops/runtime_checks.ex]` |

**Key insight:** Phase 38 is strongest when it reuses the already-shipped upload-session, doctor, and telemetry patterns byte-for-byte where possible; custom infrastructure would enlarge scope without reducing future Phase-39/40 work. `[VERIFIED: repo files cited above]`

## Runtime State Inventory

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | Existing adopter `media_upload_sessions` rows may already exist; current migration history shows the table and multipart extension already ship. The new columns are additive and nullable except `last_known_offset default 0 not null`, so no backfill is required by the locked schema shape. `[ASSUMED: adopter row counts are unknown at planning time] [VERIFIED: priv/repo/migrations/20260425090200_create_media_upload_sessions.exs, priv/repo/migrations/20260428110000_extend_media_upload_sessions_for_multipart.exs, .planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md]` | Packaged schema migration only; no separate data migration task should be planned. |
| Live service config | None in Phase 38. GCS runtime config, CORS, and profile capability checks are explicitly deferred. `[VERIFIED: .planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md, .planning/ROADMAP.md]` | None. |
| OS-registered state | None found in repo scope. Phase 38 changes no system services, schedulers, or registered process names. `[VERIFIED: repo scope and phase description]` | None. |
| Secrets/env vars | No new Phase-38 env vars or secret names are introduced. `session_uri` is data stored in the DB row, not a new config key. `[VERIFIED: .planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md, lib/rindle/domain/media_upload_session.ex]` | Code edit only: redact `session_uri` everywhere it can surface. |
| Build artifacts | None specific to Phase 38. No generated code, compiled assets, or install artifacts need renaming or refresh beyond normal recompilation/test. `[VERIFIED: repo structure and phase scope]` | None. |

## Common Pitfalls

### Pitfall 1: Treating `"resuming"` As A Generic Status Probe State
**What goes wrong:** harmless status checks make rows look more advanced than they are. `[VERIFIED: .planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md]`
**Why it happens:** the new state is mistaken for “adapter knows something” instead of “explicit recovery has begun.” `[VERIFIED: .planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md]`
**How to avoid:** only persist `"resuming"` on an intentional recovery path; keep read-only probes non-mutating. `[VERIFIED: .planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md]`
**Warning signs:** tests start allowing `"signed" -> "resuming"` from passive lookups, or maintenance starts counting every probed session as in-flight recovery. `[ASSUMED]`

### Pitfall 2: Redacting Telemetry But Forgetting `inspect/2` Or Failure Output
**What goes wrong:** `session_uri` stays out of telemetry metadata but leaks through ExUnit diffs, logger metadata, or `inspect(session)`. `[VERIFIED: .planning/PROJECT.md, .planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md]`
**Why it happens:** redaction is implemented at emit sites only, not at the domain boundary. `[VERIFIED: lib/rindle/domain/media_provider_asset.ex, test/rindle/streaming/provider/mux/telemetry_test.exs]`
**How to avoid:** give `MediaUploadSession` its own `defimpl Inspect` and reuse one helper for any future telemetry metadata normalization. `[CITED: https://hexdocs.pm/elixir/Inspect.html] [VERIFIED: lib/rindle/domain/media_provider_asset.ex]`
**Warning signs:** tests assert only “telemetry has no `session_uri` key” but never inspect the struct or failure messages. `[VERIFIED: test/rindle/domain/media_provider_asset_test.exs, test/rindle/streaming/provider/mux/telemetry_test.exs]`

### Pitfall 3: Overbuilding The Doctor Check
**What goes wrong:** Phase 38 starts checking GCS runtime, capabilities, or CORS instead of schema drift. `[VERIFIED: .planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md]`
**Why it happens:** `RuntimeChecks` already has richer GCS probes from Phase 37, so it is tempting to extend them. `[VERIFIED: lib/rindle/ops/runtime_checks.ex, test/rindle/ops/runtime_checks_test.exs]`
**How to avoid:** add one independent `doctor.resumable_session_schema` row that only introspects columns, partial index presence/shape, and `last_known_offset` default/nullability. `[VERIFIED: .planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md, test/rindle/domain/migration_test.exs]`
**Warning signs:** the check mentions Goth, bucket reachability, profile DSL, or resumable behavior semantics. `[VERIFIED: .planning/ROADMAP.md, .planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md]`

### Pitfall 4: Tightening `upload_strategy` Storage Semantics Accidentally
**What goes wrong:** a new DB check constraint or enum is introduced for `upload_strategy`, creating an unexpected rollout hazard for adopters. `[VERIFIED: priv/repo/migrations/20260428110000_extend_media_upload_sessions_for_multipart.exs]`
**Why it happens:** the requirement says “allowed values widen,” which can be misread as “enforce new allowed values in storage.” `[VERIFIED: .planning/REQUIREMENTS.md]`
**How to avoid:** keep the migration additive and string-based like the existing multipart extension; widen application/schema acceptance only. `[VERIFIED: priv/repo/migrations/20260428110000_extend_media_upload_sessions_for_multipart.exs, lib/rindle/domain/media_upload_session.ex]`
**Warning signs:** the migration introduces raw SQL constraint DDL unrelated to the existing pattern. `[VERIFIED: current migrations]`

## Code Examples

Verified patterns from official sources and local analogs:

### Additive Ecto Migration With Partial Index
```elixir
# Source pattern: Ecto.Migration docs + existing multipart extension migration
def change do
  alter table(:media_upload_sessions) do
    add :session_uri, :text
    add :session_uri_expires_at, :utc_datetime_usec
    add :last_known_offset, :bigint, null: false, default: 0
    add :region_hint, :string, size: 64
  end

  create index(:media_upload_sessions, [:session_uri_expires_at],
           where: "upload_strategy = 'resumable'",
           name: :media_upload_sessions_resumable_expiry_idx
         )
end
```
[CITED: https://hexdocs.pm/ecto_sql/Ecto.Migration.html] [VERIFIED: priv/repo/migrations/20260428110000_extend_media_upload_sessions_for_multipart.exs]

### Custom `Inspect` Redaction
```elixir
# Source pattern: lib/rindle/domain/media_provider_asset.ex
defimpl Inspect, for: Rindle.Domain.MediaUploadSession do
  def inspect(session, opts) do
    redacted = %{
      session
      | session_uri: if(session.session_uri, do: "[REDACTED]", else: nil)
    }

    Inspect.Any.inspect(redacted, opts)
  end
end
```
[CITED: https://hexdocs.pm/elixir/Inspect.html] [VERIFIED: lib/rindle/domain/media_provider_asset.ex]

### Migration/Doctor Catalog Introspection
```elixir
# Source pattern: test/rindle/domain/migration_test.exs
{:ok, %{rows: rows}} =
  Repo.query("""
  SELECT indexdef FROM pg_indexes
  WHERE tablename = 'media_upload_sessions'
    AND indexname = 'media_upload_sessions_resumable_expiry_idx'
  """)
```
[VERIFIED: test/rindle/domain/migration_test.exs]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `media_upload_sessions` tracked presigned-PUT and multipart only | Add resumable persistence fields to the same table | Planned for v1.7 Phase 38 | Keeps one durable session model for all direct-upload families. `[VERIFIED: lib/rindle/domain/media_upload_session.ex, .planning/ROADMAP.md]` |
| Upload-session FSM had no explicit recovery lane | Add `"resuming"` as a durable recovery milestone | Planned for v1.7 Phase 38 | Later resumable flows can distinguish recovery from nominal upload progress. `[VERIFIED: lib/rindle/domain/upload_session_fsm.ex, .planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md]` |
| Public upload telemetry exposed only `:start` and `:stop` at the upload family level | Freeze resumable `:status` and `:cancel` names additively | Planned for v1.7 Phase 38 | Protects future API stability before broader resumable semantics land. `[VERIFIED: test/rindle/contracts/telemetry_contract_test.exs, .planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md]` |

**Deprecated/outdated:**
- Broad resumable public families (`:start`, `:stop`, GCS-specific event names) in Phase 38 are explicitly out of scope; only `:status` and `:cancel` are frozen now. `[VERIFIED: .planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md]`

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The first real emit sites for `[:rindle, :upload, :resumable, :status]` and `[:cancel]` may land in Phase 39/40 even if Phase 38 freezes the contract and parity scaffolding now. | Summary / Open Questions | The planner could otherwise create synthetic Phase-38 runtime APIs that blur milestone boundaries. |
| A2 | Existing adopter databases may contain upload-session rows, but the additive nullable-column design means no backfill is required. | Runtime State Inventory | If a hidden DB constraint or custom adopter fork exists, rollout instructions may need an extra migration note. |

## Open Questions (RESOLVED)

1. **Should the doctor check validate exact index name or effective index shape?**
   - Resolution: lock exact index name in the packaged migration and migration smoke tests, but validate effective index shape in `RuntimeChecks`. This preserves a stable Rindle artifact while keeping `mix rindle.doctor` tolerant of adopter-local naming or recreated indexes that still satisfy the schema contract. `[RESOLVED from CONTEXT D-24..D-26 + existing migration/introspection patterns]`
   - Execution impact: Plan 38-01 should assert `media_upload_sessions_resumable_expiry_idx` in the packaged migration artifact and `test/rindle/domain/migration_test.exs`, while `doctor.resumable_session_schema` checks `session_uri_expires_at` plus `WHERE upload_strategy = 'resumable'` and `last_known_offset NOT NULL DEFAULT 0` through catalog introspection.

2. **How much real telemetry emission belongs in Phase 38?**
   - Resolution: Phase 38 should add a centralized internal helper plus contract/parity tests, but must not add new broker, adapter, or public status/cancel entrypoints. A narrow docs note for logger metadata filtering is in scope because `RESUMABLE-03` requires it; the broader GCS onboarding guide remains Phase 41 work. `[RESOLVED from REQUIREMENTS.md + ROADMAP phase boundary + CONTEXT deferred scope]`
   - Execution impact: Plan 38-03 should create `lib/rindle/upload/resumable_telemetry.ex`, widen the public telemetry contract to exactly `:status` and `:cancel`, add parity/redaction tests, and create a minimal `guides/storage_gcs.md` recipe section for `Logger.add_translator` / logger metadata filtering without expanding into full GCS onboarding.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Build, tests, Mix tasks | ✓ | `1.19.5` | — |
| Mix | Tests, doctor, migration verification | ✓ | `1.19.5` | — |
| PostgreSQL client (`psql`) | Manual catalog inspection if needed | ✓ | `14.17` | Use `Repo.query/2` in tests/doctor |

**Missing dependencies with no fallback:**
- None for planning. Phase 38 introduces no new external runtime/service dependency beyond the existing Elixir/Postgres toolchain. `[VERIFIED: phase scope, local environment probes]`

**Missing dependencies with fallback:**
- None. `[VERIFIED: local environment probes]`

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit on Elixir `1.19.5` `[VERIFIED: elixir --version, test/**/*.exs]` |
| Config file | none dedicated; repo uses `mix test` + `Rindle.DataCase` patterns `[VERIFIED: mix.exs, test/support]` |
| Quick run command | `mix test test/rindle/domain/lifecycle_fsm_test.exs test/rindle/domain/migration_test.exs test/rindle/domain/media_provider_asset_test.exs test/rindle/ops/runtime_checks_test.exs test/rindle/contracts/telemetry_contract_test.exs -x` `[VERIFIED: existing test files]` |
| Full suite command | `mix test` `[VERIFIED: standard repo test posture]` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| RESUMABLE-01 | packaged migration adds four columns, partial index, and `last_known_offset` default/nullability | integration | `mix test test/rindle/domain/migration_test.exs test/rindle/ops/runtime_checks_test.exs -x` | ✅ existing files, but new cases required |
| RESUMABLE-02 | schema casts new fields, FSM accepts `signed -> resuming -> uploading`, `Inspect` redacts `session_uri` | unit | `mix test test/rindle/domain/lifecycle_fsm_test.exs test/rindle/domain/media_upload_session_test.exs -x` | ❌ `media_upload_session_test.exs` needed |
| RESUMABLE-03 | public telemetry allowlist widens and `session_uri` never crosses telemetry boundary | contract / integration | `mix test test/rindle/contracts/telemetry_contract_test.exs test/rindle/upload/resumable_telemetry_test.exs -x` | ❌ `resumable_telemetry_test.exs` needed |

### Sampling Rate

- **Per task commit:** targeted ExUnit files for the touched seam. `[VERIFIED: repo test structure]`
- **Per wave merge:** `mix test` for all Phase-38-adjacent suites. `[VERIFIED: repo test structure]`
- **Phase gate:** full suite green plus manual `mix rindle.doctor` smoke when the local DB has the new migration applied. `[VERIFIED: guides/getting_started.md, guides/upgrading.md, guides/operations.md]`

### Wave 0 Gaps

- [ ] `test/rindle/domain/media_upload_session_test.exs` — changeset casting + `Inspect` redaction coverage for RESUMABLE-02.
- [ ] `test/rindle/upload/resumable_telemetry_test.exs` — parity/redaction contract for RESUMABLE-03 without borrowing Mux-specific fixtures.
- [ ] `test/rindle/domain/migration_test.exs` — new `media_upload_sessions` column/index/default assertions for RESUMABLE-01.
- [ ] `test/rindle/ops/runtime_checks_test.exs` — `doctor.resumable_session_schema` row presence, pass, and failure cases.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Phase 38 does not add auth flows. `[VERIFIED: phase scope]` |
| V3 Session Management | yes | Durable upload-session FSM plus additive schema controls resumable session lifecycle state. `[VERIFIED: lib/rindle/domain/media_upload_session.ex, lib/rindle/domain/upload_session_fsm.ex]` |
| V4 Access Control | no | No permission model changes in this phase. `[VERIFIED: phase scope]` |
| V5 Input Validation | yes | `MediaUploadSession.changeset/2` and FSM allowlists remain the validation boundary. `[VERIFIED: lib/rindle/domain/media_upload_session.ex, lib/rindle/domain/upload_session_fsm.ex]` |
| V6 Cryptography | partial | Packaged migration does not enforce encryption-at-rest; the only mandatory control in Phase 38 is redaction and non-disclosure of `session_uri`. `[VERIFIED: .planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md]` |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| `session_uri` leaks through inspect/log/telemetry | Information Disclosure | Central `Inspect` redaction, low-cardinality telemetry metadata, and parity tests. `[VERIFIED: .planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md, lib/rindle/domain/media_provider_asset.ex, test/rindle/streaming/provider/mux/telemetry_test.exs]` |
| Passive status probe mutates durable state | Tampering | Keep `"resuming"` transitions explicit and FSM-guarded. `[VERIFIED: .planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md, lib/rindle/domain/upload_session_fsm.ex]` |
| Adopter runs code without packaged migration | Tampering / DoS | Add `doctor.resumable_session_schema` and migration smoke tests to surface drift early. `[VERIFIED: lib/rindle/ops/runtime_checks.ex, test/rindle/domain/migration_test.exs]` |
| Overly verbose doctor failure output echoes secrets | Information Disclosure | Follow current `RuntimeChecks` pattern of summary/fix text that never prints token/credential material. `[VERIFIED: lib/rindle/ops/runtime_checks.ex, test/rindle/ops/runtime_checks_test.exs]` |

## Sources

### Primary (HIGH confidence)
- `.planning/phases/38-resumable-persistence-fsm/38-CONTEXT.md` - locked phase boundary, decisions, and canonical refs.
- `.planning/REQUIREMENTS.md` - `RESUMABLE-01..03` acceptance criteria.
- `.planning/ROADMAP.md` - phase success criteria and out-of-scope boundaries.
- `.planning/PROJECT.md` and `.planning/STATE.md` - milestone posture and security invariant continuity.
- `.planning/research/v1.6-CANDIDATE-GCS.md` - locked candidate shape carried into v1.7.
- `priv/repo/migrations/20260425090200_create_media_upload_sessions.exs` and `20260428110000_extend_media_upload_sessions_for_multipart.exs` - existing migration posture analogs.
- `lib/rindle/domain/media_upload_session.ex`, `lib/rindle/domain/upload_session_fsm.ex`, `lib/rindle/upload/broker.ex`, `lib/rindle/ops/upload_maintenance.ex`, `lib/rindle/ops/runtime_checks.ex`, `lib/rindle/domain/media_provider_asset.ex` - implementation seams.
- `test/rindle/domain/lifecycle_fsm_test.exs`, `test/rindle/domain/migration_test.exs`, `test/rindle/domain/media_provider_asset_test.exs`, `test/rindle/contracts/telemetry_contract_test.exs`, `test/rindle/streaming/provider/mux/telemetry_test.exs`, `test/rindle/ops/runtime_checks_test.exs`, `test/rindle/doctor_test.exs` - analog test patterns.
- `https://hexdocs.pm/ecto_sql/Ecto.Migration.html` - migration reversibility, `:text` guidance, and partial-index `:where` option.
- `https://hexdocs.pm/elixir/Inspect.html` - custom `Inspect` and `@derive` behavior.

### Secondary (MEDIUM confidence)
- Hex package metadata from `mix hex.info ecto`, `ecto_sql`, `goth`, `finch`, `gcs_signed_url` - current package versions and release dates.

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - existing repo lockfile plus official Hex metadata confirm no new dependency choice is needed.
- Architecture: HIGH - the repo already contains direct analogs for migrations, FSM allowlists, custom Inspect redaction, telemetry contract tests, and doctor check insertion.
- Pitfalls: MEDIUM - most are strongly implied by locked context and current patterns, but telemetry timing still requires planner judgment.

**Research date:** 2026-05-07
**Valid until:** 2026-06-06
