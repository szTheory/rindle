# Phase 118: Isolated Migration & Safe Upgrade - Pattern Map

**Mapped:** 2026-08-09  
**Files analyzed:** 9 modified files (plus one existing test fixture reused as an analog)  
**Analogs found:** 9 / 9

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/rindle/migration.ex` | service / public API | request-response | same file, `up/1` and `down/1` dispatch | exact |
| `lib/rindle/migration/options.ex` | utility / validation | transform | same file, NimbleOptions validation | exact |
| `lib/rindle/migration/v1.ex` | service / migration authority | transactional DDL, CRUD | same file, existing prefix-aware DDL and marker | exact |
| `test/rindle/migration_test.exs` | integration test | transactional DDL | same file, `Ecto.Migration.Runner` harness | exact |
| `README.md` | documentation | request-response / operator runbook | same file, Migrations section | exact |
| `guides/getting_started.md` | documentation | request-response / operator runbook | same file, Step 3 migration section | exact |
| `guides/upgrading.md` | documentation | request-response / upgrade runbook | same file, Unreleased upgrade path | exact |
| `test/install_smoke/docs_parity_test.exs` | documentation-contract test | transform | same file, migration-doc parity loop | exact |
| `test/rindle/api_surface_boundary_test.exs` | API-contract test | transform | same file, documented-function visibility checks | exact |

`test/support/schema_prefix_case.ex` is not currently a target file, but is the fixture analog for selected/decoy `public`/`rindle` isolation and bound-value catalog assertions.

## Pattern Assignments

### `lib/rindle/migration.ex` (service/public API, request-response)

**Analog:** `lib/rindle/migration.ex`

**Public host-owned wrapper and docs** (lines 1-18):

```elixir
defmodule Rindle.Migration do
  @moduledoc """
  Versioned migrations for Rindle-owned database tables.

  Create a normal migration in your Phoenix or Ecto application and call
  `Rindle.Migration` from that host migration:

      defmodule MyApp.Repo.Migrations.InstallRindle do
        use Ecto.Migration

        def up, do: Rindle.Migration.up(version: 1)
        def down, do: Rindle.Migration.down(version: 1)
      end
  """
```

**Validate then version-dispatch** (lines 35-58):

```elixir
def up(opts \\ []) when is_list(opts) do
  opts
  |> Options.validate!()
  |> dispatch(:up)
end

defp dispatch(%{version: 1} = opts, :up), do: V1.up(opts)
defp dispatch(%{version: 1} = opts, :down), do: V1.down(opts)
```

**Apply:** add only the two pinned directional functions (`move_public_to_rindle/1`, `move_rindle_to_public/1`) with their own public docs; validate version through `Options`, then dispatch only to V1. Keep `down/1` described as destructive and do not expose a generic source/target API.

---

### `lib/rindle/migration/options.ex` (utility/validation, transform)

**Analog:** `lib/rindle/migration/options.ex`

**NimbleOptions schema followed by a narrowed post-validation boundary** (lines 6-40):

```elixir
@schema [
  version: [
    type: {:in, @supported_versions},
    default: 1,
    doc: "Versioned Rindle migration to run."
  ],
  prefix: [
    type: :string,
    default: "public",
    doc: "Postgres schema prefix for Rindle-owned tables."
  ]
]

opts
|> NimbleOptions.validate!(@schema)
|> Keyword.new()
|> then(fn validated ->
  %{
    version: Keyword.fetch!(validated, :version),
    prefix: validate_prefix!(Keyword.fetch!(validated, :prefix))
  }
end)
```

**Error normalization** (lines 41-57):

```elixir
rescue
  error in NimbleOptions.ValidationError ->
    reraise ArgumentError, Exception.message(error), __STACKTRACE__
end

defp validate_prefix!(prefix) when is_binary(prefix) do
  if String.contains?(prefix, <<0>>) do
    raise ArgumentError, "expected :prefix to be a valid Postgres identifier prefix"
  end

  prefix
end
```

**Apply:** retain this single validation path but change the default to `"rindle"` and constrain `prefix` to exactly `"rindle"` or `"public"`, with an `ArgumentError` naming those two accepted values. Directional move APIs should not accept arbitrary `:prefix` at all.

---

### `lib/rindle/migration/v1.ex` (service/migration authority, transactional DDL)

**Analog:** `lib/rindle/migration/v1.ex`

**Single fixed ownership authority** (lines 6-17, 50-65):

```elixir
@current_version 1
@marker_table "rindle_migration_versions"

@rindle_tables ~w(
  media_assets
  media_attachments
  media_variants
  media_upload_sessions
  media_processing_runs
  media_provider_assets
)

def catalog_requirements do
  %{
    current_version: current_version(),
    marker_table: marker_table(),
    tables: rindle_tables()
  }
end
```

**Idempotent, prefix-qualified fresh DDL** (lines 19-30):

```elixir
def up(%{prefix: prefix}) do
  create_media_assets(prefix)
  create_media_attachments(prefix)
  create_media_variants(prefix)
  create_media_upload_sessions(prefix)
  create_media_processing_runs(prefix)
  create_media_provider_assets(prefix)
  create_marker(prefix)
  record_marker(prefix)

  :ok
end
```

**Existing marker write and sole identifier quoting boundary** (lines 308-327):

```elixir
defp record_marker(prefix) do
  execute("""
  INSERT INTO #{qualified(prefix, @marker_table)} (version)
  VALUES (#{@current_version})
  ON CONFLICT (version) DO NOTHING
  """)
end

defp qualified(prefix, table), do: "#{quote_ident(prefix)}.#{quote_ident(table)}"

defp quote_ident(identifier) do
  escaped =
    identifier
    |> to_string()
    |> String.replace(~s("), ~s(""))

  ~s("#{escaped}")
end
```

**Apply:** extend this module, not a parallel manager. Make `owned_relations/0` derive the seven fixed relations from the existing table and marker authority. Provision the selected schema before `up/1` DDL, and place catalog classification, privilege checks, and both fixed directional `ALTER TABLE ... SET SCHEMA` loops behind the same validated/quoted identifier boundary. Catalog SQL must bind schema/table values; only the pre-approved identifiers may be interpolated. Classify every state before emitting the first `ALTER`; return idempotent success only for the complete destination/empty source state.

---

### `test/rindle/migration_test.exs` (integration test, transactional DDL)

**Analog:** `test/rindle/migration_test.exs`

**Serial migration runner harness** (lines 1-4, 111-132):

```elixir
defmodule Rindle.MigrationTest do
  use Rindle.DataCase, async: false

  alias Rindle.Repo
end

defp run_migration(direction, opts, fun) do
  {:ok, runner} =
    Ecto.Migration.Runner.start_link(
      {self(), Repo, Repo.config(), __MODULE__, :forward, direction,
       %{level: false, sql: false}}
    )

  Ecto.Migration.Runner.metadata(runner, opts)

  try do
    fun.()
    Ecto.Migration.Runner.flush()
  after
    if Process.alive?(runner), do: Ecto.Migration.Runner.stop()
    Process.delete(:ecto_migration)
  end
end
```

**Isolated schema lifecycle and bound existence check** (lines 135-150):

```elixir
prefix = "rindle_migration_test_#{System.unique_integer([:positive])}"
Repo.query!("CREATE SCHEMA #{quote_ident(prefix)}")

on_exit(fn ->
  Repo.query!("DROP SCHEMA IF EXISTS #{quote_ident(prefix)} CASCADE")
end)

%{rows: [[exists?]]} =
  Repo.query!("SELECT to_regclass($1) IS NOT NULL", ["#{prefix}.#{table}"])
```

**Catalog assertion pattern** (lines 160-183):

```elixir
Repo.query!(
  """
  SELECT key_column.column_name, column_info.udt_name
  FROM information_schema.table_constraints AS constraint_info
  JOIN information_schema.key_column_usage AS key_column
    ON constraint_info.constraint_name = key_column.constraint_name
   AND constraint_info.table_schema = key_column.table_schema
  WHERE constraint_info.constraint_type = 'PRIMARY KEY'
    AND constraint_info.table_schema = $1
    AND constraint_info.table_name = $2
  """,
  [prefix, table]
)
```

**Apply:** preserve `async: false` and expand this one live-Postgres harness with complete/public source fixtures, populated relational data, marker/index/FK catalog assertions, and explicit untouched `public.oban_jobs` plus host ledger assertions. Add refusal-state, injected-failure rollback, and lock-timeout cases here; do not turn these tests into search-path tests.

**Supporting fixture analog:** `test/support/schema_prefix_case.ex` lines 21-37 selects `Rindle.Config.rindle_prefix()` and its opposite, and lines 88-113 use quoted identifiers with `$1` values. Reuse that selected/decoy fixture design for default-compiled `rindle` proof without changing `config/test.exs`, whose lines 13-15 deliberately retain the public compatibility build.

---

### Documentation files (operator runbook, request-response)

**Files:** `README.md`, `guides/getting_started.md`, `guides/upgrading.md`

**Analogs:** the existing host-owned migration snippets in each file.

**Pinned host migration shape** — `README.md` lines 96-117; `guides/getting_started.md` lines 113-136; `guides/upgrading.md` lines 42-62:

```elixir
defmodule MyApp.Repo.Migrations.InstallRindle do
  use Ecto.Migration

  def up, do: Rindle.Migration.up(version: 1)
  def down, do: Rindle.Migration.down(version: 1)
end
```

**Destructive-down warning** — `README.md` lines 128-131; `guides/getting_started.md` lines 150-153; `guides/upgrading.md` lines 70-73:

```markdown
> **Rollback:** `Rindle.Migration.down/1` is destructive. Back up the database
> before running `Rindle.Migration.down(version: 1)`; it removes Rindle-owned
> tables only and does not manage `oban_jobs`.
```

**Apply:** update these in lockstep: fresh installs default to `rindle`; `public` is the one explicit compatibility option; no arbitrary `tenant_media` pairing remains. In `guides/upgrading.md`, add the copy-pasteable host migration that uses `SET LOCAL lock_timeout`, calls the pinned forward/reverse helpers, requires backup and quiescence, says it moves only Rindle's seven relations, and directs deployment of the `rindle`-compiled build plus verification. Do not frame `down/1` as migration rollback and do not make claims reserved for Phase 120.

---

### `test/install_smoke/docs_parity_test.exs` (documentation-contract test, transform)

**Analog:** `test/install_smoke/docs_parity_test.exs` lines 140-188.

**One assertion loop over the three canonical docs:**

```elixir
migration_sections = [
  {"README migrations", section_between!(readme, "## Migrations", "## First Attachment")},
  {"getting-started step 3", section_between!(guide, "## 3.", "## 4.")},
  {"Unreleased upgrade note", section_between!(upgrade, "## Unreleased / Next", "## 0.1.3")}
]

for {name, section} <- migration_sections do
  assert section =~ "Rindle.Migration.up(version: 1)"
  assert section =~ "Oban.Migration"
  assert section =~ "oban_jobs"
  assert section =~ "mix ecto.migrate"
  assert section =~ "mix rindle.doctor"
end
```

**Apply:** alter the existing default-schema regex and add precise upgrade-only requirements for maintenance-window wording, `SET LOCAL lock_timeout`, both directional upgrade helpers, seven-relation/Rindle-only scope, and the explicit non-ownership of `oban_jobs`/host ledger. Keep the three-document loop only for claims genuinely present in all three docs; put legacy-move-specific assertions on the upgrade section.

---

### `test/rindle/api_surface_boundary_test.exs` (API-contract test, transform)

**Analog:** `test/rindle/api_surface_boundary_test.exs` lines 177-185.

```elixir
test "versioned migration API stays publicly documented" do
  assert visible_function_doc?(Rindle.Migration, :up, 1),
         "Rindle.Migration.up/1 should be publicly documented"

  assert visible_function_doc?(Rindle.Migration, :down, 1),
         "Rindle.Migration.down/1 should be publicly documented"
end
```

**Apply:** add the two intentional directional migration APIs to this explicit public-doc contract. Add a negative exported-function assertion for a generic move API so the narrow compatibility surface cannot silently widen.

## Shared Patterns

### Version-pinned, host-owned migration boundary

**Sources:** `lib/rindle/migration.ex` lines 1-18 and 35-58; documentation snippets above.  
**Apply to:** public migration APIs and docs.

Validate options, dispatch only on version, and leave the host Ecto migration responsible for its ledger, transaction and operational timing. Rindle never creates, moves or deletes `oban_jobs` or `schema_migrations`.

### Fixed ownership plus quoted identifiers / bound catalog values

**Sources:** `lib/rindle/migration/v1.ex` lines 6-17 and 308-327; `test/rindle/migration_test.exs` lines 146-183.  
**Apply to:** provisioning, preflight, forward/reverse move, and integration assertions.

Use one seven-relation allowlist and one V1 quoting helper for fixed DDL identifiers. Bind catalog values (`$1`, `$2`) rather than interpolating them. Do not rely on `search_path` or `IF EXISTS` to mask unsafe upgrade states.

### Serial isolated PostgreSQL proof

**Sources:** `test/rindle/migration_test.exs` lines 111-132 and 135-183; `test/support/schema_prefix_case.ex` lines 21-37, 88-113.  
**Apply to:** all state-machine, data-integrity, lock, and rollback tests.

Use the existing migration runner and disposable schemas. Keep the ordinary test suite public-compiled; prove the default `rindle` path with a focused selected/decoy default-build fixture or probe.

### Calm, bounded operator copy

**Sources:** `README.md` lines 96-131; `guides/getting_started.md` lines 113-153; `guides/upgrading.md` lines 42-83.  
**Apply to:** moduledocs, error text, and upgrade documentation.

State observed state, say what Rindle will not touch, and give one next action: prepare a maintenance window, move Rindle tables, deploy the `rindle` build, then verify.

## No Analog Found

| File / concern | Role | Data Flow | Reason |
|---|---|---|---|
| Default-compiled proof command or temporary probe path | test/config | batch | Research requires it but does not name a file; preserve `config/test.exs` public compatibility and select the smallest new focused proof artifact during planning. |
| Privilege-denied integration fixture | test support | transactional DDL | No current test-role/privilege fixture exists; use the migration harness with a safe injected seam or a CI-compatible role fixture. |

## Metadata

**Analog search scope:** `lib/rindle/`, `test/rindle/`, `test/support/`, `test/install_smoke/`, `README.md`, and `guides/`.  
**Files scanned:** 15 relevant source, test, config, and documentation files.  
**Pattern extraction date:** 2026-08-09
