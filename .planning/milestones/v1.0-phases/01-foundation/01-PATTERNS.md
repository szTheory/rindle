# Phase 1 Pattern Mapping

## Reader and Action
- **Reader:** engineer planning/implementing Phase 1 foundation work.
- **Post-read action:** add/modify Phase 1 modules without drifting from existing repository conventions.

## File/Module Family Map (Phase 1)

### 1) Data migrations (`SCHEMA`)
- **Likely files/modules to add/modify**
  - `priv/repo/migrations/*_create_media_attachments.exs`
  - `priv/repo/migrations/*_create_media_variants.exs`
  - `priv/repo/migrations/*_create_media_upload_sessions.exs`
  - `priv/repo/migrations/*_create_media_processing_runs.exs`
  - Possible amendments to existing migration set for indexes/constraints.
- **Closest existing analog**
  - `Rindle.Repo.Migrations.CreateMediaAssets` (`priv/repo/migrations/20260424155129_create_media_assets.exs`)
- **Conventions/signatures to follow**
  - One migration module per file: `defmodule Rindle.Repo.Migrations.<Name> do`.
  - Always `use Ecto.Migration` and prefer `def change do`.
  - Use explicit null/default/index decisions on lifecycle fields.
  - Keep state queryability first-class (`:state` columns + indexes), not metadata-only.
  - Keep `timestamps()` style consistent with repo defaults.

### 2) Domain schemas + changesets (`SCHEMA`, `ERR`, `STALE`)
- **Likely files/modules to add/modify**
  - `lib/rindle/domain/media_asset.ex`
  - `lib/rindle/domain/media_attachment.ex`
  - `lib/rindle/domain/media_variant.ex`
  - `lib/rindle/domain/media_upload_session.ex`
  - `lib/rindle/domain/media_processing_run.ex`
- **Closest existing analog**
  - **none yet** (greenfield); schema behavior should align with Repo + migration conventions.
- **Conventions/signatures to follow**
  - Module naming: `Rindle.Domain.<Entity>` with singular entity name.
  - Define `schema/2` and a single canonical changeset:
    - `@spec changeset(t() | Ecto.Schema.t(), map()) :: Ecto.Changeset.t()`
  - Changesets should use Ecto pipeline style (`cast` -> `validate_required` -> targeted validators/constraints).
  - Expected domain failures return data/changesets or tagged tuples at boundaries, not implicit raises.

### 3) Lifecycle transition modules (`ASM`, `VSM`, `USM`)
- **Likely files/modules to add/modify**
  - `lib/rindle/domain/asset_fsm.ex`
  - `lib/rindle/domain/variant_fsm.ex`
  - `lib/rindle/domain/upload_session_fsm.ex`
- **Closest existing analog**
  - **none yet** (greenfield)
- **Conventions/signatures to follow**
  - Module naming by bounded context: `Rindle.Domain.AssetFSM`, `Rindle.Domain.VariantFSM`, `Rindle.Domain.UploadSessionFSM` (or consistent `...Fsm` casing project-wide).
  - Transition API should be explicit and tuple-based:
    - `@spec transition(struct(), atom(), keyword()) :: {:ok, struct()} | {:error, term()}`
  - Use allowlist transition maps; invalid jumps return tagged errors (no silent coercion).

### 4) Behavior contracts (`BHV`)
- **Likely files/modules to add/modify**
  - `lib/rindle/storage.ex`
  - `lib/rindle/processor.ex`
  - `lib/rindle/analyzer.ex`
  - `lib/rindle/scanner.ex`
  - `lib/rindle/authorizer.ex`
- **Closest existing analog**
  - `Rindle.Repo` is the closest convention for concise contract modules (minimal, clear, explicit `use`/callbacks).
- **Conventions/signatures to follow**
  - Keep behavior modules focused and typed:
    - `@callback capabilities() :: [atom()]`
    - Action callbacks return `{:ok, value}` or `{:error, reason}`.
  - Capability declaration is mandatory where provider differences matter.
  - Contracts must keep storage side effects outside DB transactions by design.

### 5) Storage adapters (`STOR`)
- **Likely files/modules to add/modify**
  - `lib/rindle/storage/local.ex`
  - `lib/rindle/storage/s3.ex`
- **Closest existing analog**
  - **none yet** (greenfield); shape should mirror behavior contracts and tuple error semantics already used in project direction.
- **Conventions/signatures to follow**
  - Adapter module naming: `Rindle.Storage.Local`, `Rindle.Storage.S3`.
  - `@behaviour Rindle.Storage` with complete callback implementation.
  - Never hide adapter failures with raises in domain-facing paths; return tagged tuples.

### 6) Profile DSL and digest (`PROF`, `STALE`)
- **Likely files/modules to add/modify**
  - `lib/rindle/profile.ex`
  - `lib/rindle/profile/validator.ex`
  - `lib/rindle/profile/digest.ex`
- **Closest existing analog**
  - **none yet** (greenfield)
- **Conventions/signatures to follow**
  - Public DSL module `Rindle.Profile` should expose stable compile-time contract.
  - Canonical functions expected by research/context:
    - `variants/0`
    - `validate_upload/1`
  - Recipe digest should be deterministic for equivalent variant definitions.

### 7) Security primitives (`SEC`)
- **Likely files/modules to add/modify**
  - `lib/rindle/security/mime.ex`
  - `lib/rindle/security/upload_validation.ex`
  - `lib/rindle/security/storage_key.ex`
  - `lib/rindle/security/filename.ex`
- **Closest existing analog**
  - **none yet** (greenfield)
- **Conventions/signatures to follow**
  - Module naming under `Rindle.Security.*`.
  - Security validators should be pure and tuple-returning:
    - `@spec validate(map(), keyword()) :: :ok | {:error, term()}`
  - Keep filename sanitization separate from storage key generation.
  - Storage keys are deterministic and never user-path-controlled.

### 8) Public facade and app wiring (`CONF`, `ERR`)
- **Likely files/modules to add/modify**
  - `lib/rindle.ex` (minimal public facade additions)
  - `lib/rindle/application.ex` (only if Phase 1 requires supervised infrastructure)
- **Closest existing analog**
  - Existing `Rindle` and `Rindle.Application` modules.
- **Conventions/signatures to follow**
  - Keep facade minimal and documented with `@doc` + `@spec`.
  - Avoid broad public API expansion before domain invariants settle.
  - Supervisor children list should stay explicit and readable.

### 9) Configuration (`CONF`)
- **Likely files/modules to add/modify**
  - `config/config.exs`
  - `config/runtime.exs`
  - Potentially `config/test.exs` for test-only behavior defaults.
- **Closest existing analog**
  - Existing `config/config.exs` and `config/runtime.exs`.
- **Conventions/signatures to follow**
  - Compile-time defaults in `config/config.exs`.
  - Runtime env extraction and fail-fast checks in `config/runtime.exs` (`System.get_env` + `raise` in prod when required).
  - Preserve adopter-owned runtime credentials model (no library-owned secret management model).

### 10) Tests and support harness (`ERR`, `SEC`, `BHV`, `ASM`, `VSM`, `USM`)
- **Likely files/modules to add/modify**
  - `test/support/*`
  - `test/rindle/domain/*_test.exs`
  - `test/rindle/storage/*_test.exs`
  - `test/rindle/profile/*_test.exs`
  - `test/rindle/security/*_test.exs`
- **Closest existing analog**
  - `test/test_helper.exs`
  - `test/rindle_test.exs`
- **Conventions/signatures to follow**
  - Use `ExUnit.Case`; keep test names behavior-focused strings.
  - Default to `async: true` for pure unit tests; use sandbox-aware setup for DB-integrated tests.
  - Assertions should be explicit and deterministic, especially for transition matrices and security rejects.

## Cross-Cutting Conventions to Lock In

### Module naming
- Top-level namespace is always `Rindle`.
- Domain modules live under `Rindle.Domain.*`; adapter families under `Rindle.<Family>.*`.
- Use singular entity names for schemas (`MediaAsset`, `MediaVariant`, etc.).

### Changeset style
- Canonical pipeline:
  - `cast/3`
  - `validate_required/2`
  - domain validators (`validate_inclusion`, size, transitions, etc.)
  - DB-backed constraints (`unique_constraint`, `foreign_key_constraint`, `check_constraint`) where applicable.
- Keep one primary `changeset/2` per schema; add narrowly named variants only when materially different.

### Migration style
- Prefer `def change do`.
- Create table, then create indexes/unique indexes explicitly.
- Keep lifecycle fields queryable (`state`, expiry timestamps, polymorphic lookup columns) with dedicated indexes.
- Rely on repo migration defaults already set (`:binary_id`, `:utc_datetime_usec`) instead of ad hoc timestamp/PK divergence.

### Config style
- `import Config` at top; group `config :rindle` and component configs clearly.
- Compile-time defaults in `config/config.exs`; runtime and env-sensitive values in `config/runtime.exs`.
- Required production env vars must fail fast with clear raise messages.

### Test style
- Bootstrapping pattern mirrors existing `test/test_helper.exs` (repo start + SQL sandbox mode + `ExUnit.start()`).
- Keep tests small, direct, and explicit; prefer deterministic fixtures/factories over implicit state.
- For adapter contracts and transition matrices, include both happy path and invalid/failure path assertions.

## Mirror These Existing Snippets

```elixir
defmodule Rindle do
  @moduledoc """
  Phoenix/Ecto-native media lifecycle library.
  """
end
```

```elixir
@doc """
Returns the current version of Rindle.
"""
@spec version :: String.t()
def version do
  Application.spec(:rindle, :vsn) |> to_string()
end
```

```elixir
config :rindle, Rindle.Repo,
  migration_primary_key: [type: :binary_id],
  migration_timestamps: [type: :utc_datetime_usec]
```

```elixir
if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """
end
```

```elixir
def change do
  create table(:media_assets) do
    add :state, :string, null: false, default: "staged"
    add :storage_key, :string, null: false
    timestamps()
  end

  create index(:media_assets, [:state])
  create unique_index(:media_assets, [:storage_key])
end
```

## Do Not Repeat
- Do not put lifecycle-critical state only inside `:metadata` maps; keep states as indexed/queryable columns.
- Do not perform storage side effects inside DB transactions; transactional DB state and storage side effects must remain decoupled.
- Do not mix `raise` and tuple-returning error semantics for expected domain failures; use tagged tuples consistently at contract boundaries.
- Do not let user input directly shape storage key paths; sanitize filenames separately and generate deterministic keys independently.
- Do not bypass compile-time/profile validation by deferring all checks to runtime.
- Do not bloat `Rindle` public facade before Phase 1 invariants (schema, transitions, contracts, security) are stable.
