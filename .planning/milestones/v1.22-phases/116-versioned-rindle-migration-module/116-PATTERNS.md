# Phase 116: Versioned `Rindle.Migration` Module - Pattern Map

**Mapped:** 2026-07-01  
**Files analyzed:** 25  
**Analogs found:** 25 / 25

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/rindle/migration.ex` | utility / public API | batch DDL | `deps/oban/lib/oban/migration.ex` | exact external-in-repo |
| `lib/rindle/migration/options.ex` | utility | transform / validation | `lib/rindle/profile/validator.ex` | role-match |
| `lib/rindle/migration/v1.ex` | utility | batch DDL | `priv/repo/migrations/*.exs` | role-match |
| `priv/repo/migrations/20260424205942_create_oban_tables.exs` | migration | batch DDL | same file + `deps/oban/lib/oban/migration.ex` | exact |
| `lib/rindle/config.ex` | config | request-response | `lib/rindle/config.ex` | exact |
| `lib/rindle/ops/runtime_checks.ex` | service | request-response / catalog-read | `lib/rindle/ops/runtime_checks.ex` | exact |
| `lib/rindle/ops/runtime_status.ex` | service | request-response / CRUD-read | `lib/rindle/ops/runtime_status.ex` | exact |
| `lib/mix/tasks/rindle.doctor.ex` | controller / CLI task | request-response | `lib/mix/tasks/rindle.doctor.ex` | exact |
| `lib/mix/tasks/rindle.runtime_status.ex` | controller / CLI task | request-response | `lib/mix/tasks/rindle.runtime_status.ex` | exact |
| `README.md` | documentation | reader workflow | `README.md` + `116-UI-SPEC.md` | exact |
| `guides/getting_started.md` | documentation | reader workflow | `guides/getting_started.md` + `116-UI-SPEC.md` | exact |
| `guides/upgrading.md` | documentation | reader workflow | `guides/upgrading.md` + `116-UI-SPEC.md` | exact |
| `guides/operations.md` | documentation | reader workflow | `guides/operations.md` | role-match |
| `guides/troubleshooting.md` | documentation | reader workflow | `guides/troubleshooting.md` | role-match |
| `test/rindle/migration_test.exs` | test | batch DDL / catalog-read | `test/rindle/domain/migration_test.exs` | role-match |
| `test/rindle/domain/migration_test.exs` | test | catalog-read | same file | exact |
| `test/rindle/ops/runtime_checks_test.exs` | test | request-response / catalog-read | same file | exact |
| `test/rindle/doctor_test.exs` | test | request-response / CLI | same file | exact |
| `test/rindle/ops/runtime_status_test.exs` | test | CRUD-read | same file | exact |
| `test/rindle/runtime_status_task_test.exs` | test | request-response / CLI | same file | exact |
| `test/install_smoke/docs_parity_test.exs` | test | file-I/O / transform | same file | exact |
| `test/install_smoke/support/generated_app_helper.ex` | test utility | file-I/O / batch | same file | exact |
| `test/install_smoke/generated_app_smoke_test.exs` | test | batch / request-response | same file | exact |
| `test/rindle/api_surface_boundary_test.exs` | test | transform / docs-boundary | same file | exact |
| `test/install_smoke/package_metadata_test.exs` | test | file-I/O / package proof | same file | role-match |

## Pattern Assignments

### `lib/rindle/migration.ex` (utility / public API, batch DDL)

**Analog:** `deps/oban/lib/oban/migration.ex`

**Public wrapper migration docs pattern** (lines 14-31):

```elixir
defmodule MyApp.Repo.Migrations.AddOban do
  use Ecto.Migration

  def up, do: Oban.Migrations.up()

  def down, do: Oban.Migrations.down()
end
```

**Pinned version wrapper pattern** (lines 52-59):

```elixir
defmodule MyApp.Repo.Migrations.UpgradeObanToV13 do
  use Ecto.Migration

  def up, do: Oban.Migrations.up(version: 13)

  def down, do: Oban.Migrations.down(version: 13)
end
```

**Public API shape** (lines 119-184):

```elixir
use Ecto.Migration

@doc """
Run the `up` changes for all migrations between the initial version and the current version.
"""
def up(opts \\ []) when is_list(opts) do
  migrator().up(opts)
end

@doc """
Run the `down` changes for all migrations between the current version and the initial version.
"""
def down(opts \\ []) when is_list(opts) do
  migrator().down(opts)
end
```

**Copy guidance:** expose `Rindle.Migration.up/1` and `down/1` as a documented public module. Copy Oban's wrapper API shape, but keep Rindle to Postgres/Ecto only unless planning intentionally adds adapter indirection. The planner should include `use Ecto.Migration`, public docs, `opts \\ [] when is_list(opts)`, and dispatch to private versioned DDL helpers.

---

### `lib/rindle/migration/options.ex` (utility, transform / validation)

**Analog:** `lib/rindle/profile/validator.ex`

**NimbleOptions schema pattern** (lines 10-40):

```elixir
@profile_schema [
  storage: [
    type: :atom,
    required: true
  ],
  allow_mime: [
    type: {:list, :string},
    default: []
  ],
  variants: [
    type: :keyword_list,
    required: true
  ]
]
```

**Validation and error wrapping pattern** (lines 202-231):

```elixir
@spec validate!(keyword() | map()) :: profile_options()
def validate!(opts) when is_map(opts) do
  opts
  |> Enum.to_list()
  |> validate!()
end

def validate!(opts) when is_list(opts) do
  validated =
    opts
    |> validate_profile_options!()
    |> Keyword.new()

  %{
    storage: Keyword.fetch!(validated, :storage),
    allow_mime: Keyword.fetch!(validated, :allow_mime)
  }
rescue
  error in NimbleOptions.ValidationError ->
    reraise ArgumentError, Exception.message(error), __STACKTRACE__
end
```

**Private validate helper** (lines 416-430):

```elixir
defp validate_profile_options!(opts) do
  opts
  |> drop_nil_values()
  |> NimbleOptions.validate!(@profile_schema)
end

defp drop_nil_values(opts) when is_list(opts) do
  Enum.reject(opts, fn
    {_key, nil} -> true
    _ -> false
  end)
end
```

**Copy guidance:** validate `:version` and `:prefix` with NimbleOptions. Unknown options should fail through NimbleOptions. Wrap `NimbleOptions.ValidationError` as `ArgumentError` for public-contract errors. If `:create_schema` is included, keep it intentionally scoped and covered by a prefix test.

---

### `lib/rindle/migration/v1.ex` (utility, batch DDL)

**Analog:** `priv/repo/migrations/*.exs`

**Core Rindle table DDL source** (`20260424155129_create_media_assets.exs`, lines 4-20):

```elixir
def change do
  create table(:media_assets) do
    add :state, :string, null: false, default: "staged"
    add :storage_key, :string, null: false
    add :content_type, :string
    add :byte_size, :bigint
    add :filename, :string
    add :metadata, :map, null: false, default: %{}
    add :recipe_digest, :string
    add :profile, :string, null: false

    timestamps()
  end

  create index(:media_assets, [:state])
  create unique_index(:media_assets, [:storage_key])
end
```

**Foreign-key table pattern** (`20260425090000_create_media_attachments.exs`, lines 4-15):

```elixir
def change do
  create table(:media_attachments) do
    add :asset_id, references(:media_assets, type: :binary_id, on_delete: :delete_all), null: false
    add :owner_type, :string, null: false
    add :owner_id, :binary_id, null: false
    add :slot, :string, null: false

    timestamps()
  end

  create unique_index(:media_attachments, [:owner_type, :owner_id, :slot])
end
```

**Explicit binary-id precedent** (`20260506120000_create_media_provider_assets.exs`, lines 15-47):

```elixir
def change do
  create table(:media_provider_assets, primary_key: false) do
    add :id, :binary_id, primary_key: true

    add :asset_id,
        references(:media_assets, type: :binary_id, on_delete: :delete_all),
        null: false

    add :profile, :string, null: false
    add :provider_name, :string, null: false
    add :provider_asset_id, :string
    add :playback_ids, {:array, :string}, null: false, default: []
    add :playback_policy, :string
    add :ingest_mode, :string
    add :state, :string, null: false, default: "pending"
    add :last_event_id, :string
    add :last_event_at, :utc_datetime_usec
    add :last_sync_error, :text
    add :raw_provider_metadata, :map, null: false, default: %{}

    timestamps()
  end

  create unique_index(:media_provider_assets, [:provider_name, :provider_asset_id],
           where: "provider_asset_id IS NOT NULL",
           name: :media_provider_assets_provider_name_provider_asset_id_index
         )
end
```

**Partial index pattern** (`20260507160000_extend_media_upload_sessions_for_resumable.exs`, lines 14-17):

```elixir
create index(:media_upload_sessions, [:session_uri_expires_at],
         where: "upload_strategy = 'resumable'",
         name: :media_upload_sessions_resumable_expiry_idx
       )
```

**Schema contract to match** (`lib/rindle/domain/media_asset.ex`, lines 31-80):

```elixir
@primary_key {:id, :binary_id, autogenerate: true}
@foreign_key_type :binary_id

schema "media_assets" do
  field :state, :string, default: "staged"
  field :storage_key, :string
  field :content_type, :string
  field :byte_size, :integer
  field :filename, :string
  field :metadata, :map, default: %{}
  field :recipe_digest, :string
  field :profile, :string
  field :kind, :string, default: "image"

  timestamps()
end
```

**Copy guidance:** use the packaged migrations as the source of table/column/index truth, but implement Phase 116 in `lib/` with `create_if_not_exists`, `alter table`, catalog guards as needed, `prefix: prefix`, and explicit binary-id table options. Do not call `Ecto.Migrator.run/4` from the new module.

---

### `priv/repo/migrations/20260424205942_create_oban_tables.exs` (migration, batch DDL)

**Analog:** same file

**Current behavior to neutralize** (lines 1-11):

```elixir
defmodule Rindle.Repo.Migrations.CreateObanTables do
  use Ecto.Migration

  def up do
    Oban.Migration.up(version: 12)
  end

  def down do
    Oban.Migration.down(version: 1)
  end
end
```

**Copy guidance:** keep the filename and module for legacy compatibility, but replace authoritative behavior with a no-op compatibility stub or another non-authoritative path. The new code must not create, alter, or drop `oban_jobs`.

---

### `lib/rindle/config.ex` (config, request-response)

**Analog:** same file

**Legacy packaged migration path helper** (lines 64-66):

```elixir
@spec migrations_path() :: String.t()
def migrations_path do
  Application.app_dir(:rindle, "priv/repo/migrations")
end
```

**Copy guidance:** keep `migrations_path/0` available for legacy health inspection unless the plan proves a narrower compatibility helper is safer. New greenfield docs and generated-app proof should not use this as the install path.

---

### `lib/rindle/ops/runtime_checks.ex` (service, request-response / catalog-read)

**Analog:** same file

**Run pipeline and injectable dependencies** (lines 76-139):

```elixir
@spec run([String.t()], keyword()) :: report()
def run(args, opts \\ []) do
  env = Keyword.get(opts, :env, System.get_env())
  probe = Keyword.get(opts, :probe, fn -> Rindle.AV.Probe.check_ffmpeg!() end)
  mix_app = Keyword.get(opts, :mix_app, :rindle)
  resolved = resolve_profiles(args, Keyword.get(opts, :profiles, Config.profile_modules()))
  profiles = resolved.profiles
  oban_config = Keyword.get(opts, :oban_config, Application.get_env(mix_app, Oban))

  migration_statuses =
    Keyword.get_lazy(opts, :migration_statuses, fn -> migration_statuses(opts) end)

  checks =
    ([
       fn -> check_delivery_support(profiles) end,
       fn -> check_migration_pending(migration_statuses) end,
       fn -> check_migration_unresolved(migration_statuses) end,
       fn -> check_resumable_session_schema(resumable_session_schema_catalog) end,
       fn -> check_oban_default_instance(oban_config) end,
       fn -> check_oban_required_queues(profiles, oban_config) end
     ] ++ gcs_extra ++ tus_extra)
    |> Enum.map(&run_check/1)
    |> Enum.sort_by(& &1.id)

  failed = Enum.count(checks, &(&1.status == :error))

  %{checks: checks, failed: failed, success?: failed == 0, total: length(checks)}
end
```

**Migration status checks to adapt** (lines 358-407):

```elixir
defp check_migration_pending(statuses) do
  pending =
    statuses
    |> Enum.filter(fn
      {:down, _version, _name} -> true
      _other -> false
    end)
    |> Enum.map(&migration_version/1)

  if pending == [] do
    ok_result("doctor.migrations.pending", :migrations, "No pending Rindle migrations were found.", "Keep Rindle migrations applied before running the runtime pipeline.")
  else
    error_result("doctor.migrations.pending", :migrations, "Pending Rindle migrations: #{Enum.join(pending, ", ")}.", "Run `mix ecto.migrate` for the repo configured at `config :rindle, :repo` before retrying.")
  end
end

defp check_migration_unresolved(statuses) do
  unresolved =
    statuses
    |> Enum.filter(fn
      {:up, _version, "** FILE NOT FOUND **"} -> true
      _other -> false
    end)
    |> Enum.map(&migration_version/1)

  if unresolved == [] do
    ok_result("doctor.migrations.unresolved", :migrations, "No unresolved applied Rindle migrations were found.", "Keep local Rindle migration files in sync with the database history.")
  else
    error_result("doctor.migrations.unresolved", :migrations, "Applied Rindle migrations missing from local code: #{Enum.join(unresolved, ", ")}.", "Restore the migration files missing from local code, or reconcile the database history before running more Rindle migrations.")
  end
end
```

**Catalog inspection pattern** (lines 524-561):

```elixir
defp resumable_session_schema_catalog do
  case Migrator.with_repo(
         Config.repo(),
         fn started_repo ->
           with {:ok, %{rows: column_rows}} <-
                  started_repo.query(
                    """
                    SELECT column_name, is_nullable, column_default
                    FROM information_schema.columns
                    WHERE table_schema = 'public' AND table_name = 'media_upload_sessions'
                      AND column_name IN ('session_uri', 'session_uri_expires_at', 'last_known_offset', 'region_hint')
                    """,
                    []
                  ),
                {:ok, %{rows: index_rows}} <-
                  started_repo.query(
                    """
                    SELECT indexdef
                    FROM pg_indexes
                    WHERE schemaname = 'public' AND tablename = 'media_upload_sessions'
                    """,
                    []
                  ) do
             %{columns: Map.new(column_rows, fn [name, is_nullable, column_default] -> {name, %{is_nullable: is_nullable, column_default: column_default}} end),
               indexes: Enum.map(index_rows, fn [indexdef] -> indexdef end)}
           end
         end,
         mode: :temporary
       ) do
    {:ok, catalog, _apps} -> catalog
    {:error, reason} -> {:error, reason}
  end
end
```

**Oban config checks** (lines 218-266):

```elixir
defp check_oban_default_instance(nil) do
  error_result(
    "doctor.oban_default_instance",
    :oban,
    "Default `Oban` config is missing.",
    "Configure `config :your_app, Oban, repo: MyApp.Repo, queues: [...]` and start `{Oban, Application.fetch_env!(:your_app, Oban)}` in the host supervision tree."
  )
end

defp check_oban_required_queues(profiles, oban_config) do
  required = required_queues(profiles)
  configured = oban_queue_names(oban_config)
  missing = required -- configured

  if missing == [] do
    ok_result("doctor.oban_required_queues", :oban, "Default `Oban` config declares required queues: #{Enum.map_join(required, ", ", &Atom.to_string/1)}.", "Keep the documented queue list in the default `Oban` config.")
  else
    error_result("doctor.oban_required_queues", :oban, "Default `Oban` config is missing required queues: #{Enum.map_join(missing, ", ", &Atom.to_string/1)}.", "Add the missing queues to `config :your_app, Oban, queues: [...]`. `rindle_media` is only required when your discovered profiles declare AV-capable variants.")
  end
end
```

**Result shape** (lines 1536-1546):

```elixir
defp ok_result(id, component, summary, fix) do
  %{id: id, status: :ok, component: component, summary: summary, fix: fix}
end

defp warn_result(id, component, summary, fix) do
  %{id: id, status: :warn, component: component, summary: summary, fix: fix}
end

defp error_result(id, component, summary, fix) do
  %{id: id, status: :error, component: component, summary: summary, fix: fix}
end
```

**Copy guidance:** preserve stable check IDs where practical. Replace file-history-only migration truth with a hybrid model: new marker, prefix-aware catalog readiness, legacy migration compatibility, and host-owned Oban readiness. Keep keyword injection seams for tests.

---

### `lib/rindle/ops/runtime_status.ex` (service, request-response / CRUD-read)

**Analog:** same file

**Public service shape** (lines 36-63):

```elixir
@spec runtime_status(keyword() | map()) :: {:ok, report()} | {:error, term()}
def runtime_status(opts \\ []) do
  with {:ok, filters} <- normalize_filters(opts) do
    now = DateTime.utc_now()
    cutoff = older_than_cutoff(now, filters.older_than)

    runtime_checks = runtime_checks_report(filters, cutoff, now)
    variants = variant_report(filters, cutoff, now)
    upload_sessions = upload_session_report(filters, cutoff, now)
    provider_assets = provider_assets_report(filters, now)

    {:ok,
     %{
       generated_at: now,
       filters: filters,
       runtime_checks: runtime_checks,
       assets: asset_report(filters),
       variants: variants,
       upload_sessions: upload_sessions,
       provider_assets: provider_assets,
       recommendations: build_recommendations(runtime_checks, variants, upload_sessions, provider_assets)
     }}
  else
    {:error, reason} = error ->
      emit_runtime_refusal(reason)
      error
  end
end
```

**Filter validation and refusal telemetry** (lines 680-768):

```elixir
with {:ok, profile} <- normalize_profile(Map.get(normalized, :profile)),
     {:ok, older_than} <- normalize_older_than(Map.get(normalized, :older_than)),
     {:ok, limit} <- normalize_limit(Map.get(normalized, :limit)),
     {:ok, format} <- normalize_format(Map.get(normalized, :format)),
     {:ok, provider_stuck} <- normalize_provider_stuck(Map.get(normalized, :provider_stuck)) do
  {:ok, %{profile: profile, older_than: older_than, limit: limit, format: format, provider_stuck: provider_stuck}}
end

defp validate_filter_keys(opts) do
  case Map.keys(opts) -- @allowed_filter_keys do
    [] -> :ok
    unknown -> {:error, {:unknown_filters, unknown}}
  end
end

defp emit_runtime_refusal(reason) do
  :telemetry.execute(
    [:rindle, :runtime, :refusal],
    %{system_time: System.system_time()},
    %{surface: :runtime_status, reason: refusal_reason(reason), mode: :api}
  )
end
```

**Copy guidance:** add setup preflight before report queries so missing Rindle tables or host-owned `oban_jobs` return actionable `{:error, reason}` instead of raw DB exceptions. Keep report shape stable on success and emit refusal telemetry on preflight failures.

---

### `lib/mix/tasks/rindle.doctor.ex` (controller / CLI task, request-response)

**Analog:** same file

**Task parser and runtime delegation** (lines 35-82):

```elixir
@impl Mix.Task
def run(args) do
  {parsed, rest, invalid} =
    OptionParser.parse(args, strict: [streaming: :boolean])

  case invalid do
    [] -> :ok
    invalid_flags -> Mix.raise("Unknown options: " <> Enum.map_join(invalid_flags, ", ", fn {flag, _} -> flag end))
  end

  streaming? = Keyword.get(parsed, :streaming, false)

  run_checks(rest, streaming: streaming?)
end

@doc false
def run_checks(args, opts \\ []) do
  shell = Keyword.get(opts, :shell, Mix.shell())
  mix_app = Keyword.get(opts, :mix_app, Mix.Project.config()[:app])
  exit_on_failure? = Keyword.get(opts, :exit_on_failure?, true)

  shell.info("Rindle: running environment checks...")

  report =
    args
    |> RuntimeChecks.run(opts |> Keyword.put(:mix_app, mix_app))
    |> emit_report(shell)

  if exit_on_failure? and not report.success? do
    raise Mix.Error, message: "Rindle.Doctor failed: #{report.failed} check(s) failed"
  end

  report
end
```

**Status rendering pattern** (lines 98-110):

```elixir
defp emit_check(shell, %{status: status, id: id, component: component, summary: summary, fix: fix}) do
  shell.info("[#{String.upcase(to_string(status))}] #{id} (#{component}) #{summary}")

  if status in [:warn, :error] do
    shell.info("  Fix: #{fix}")
  end
end
```

**Copy guidance:** keep doctor as the operator-facing rendering layer. Put hybrid migration semantics in `RuntimeChecks`, not in the Mix task.

---

### `lib/mix/tasks/rindle.runtime_status.ex` (controller / CLI task, request-response)

**Analog:** same file

**Task parser and API delegation** (lines 31-65):

```elixir
@impl Mix.Task
def run(args) do
  {opts, _rest, _invalid} =
    OptionParser.parse(args,
      strict: [
        profile: :string,
        older_than_sec: :integer,
        limit: :integer,
        format: :string,
        provider_stuck: :boolean
      ]
    )

  filters =
    %{}
    |> maybe_put(:profile, Keyword.get(opts, :profile))
    |> maybe_put(:older_than, Keyword.get(opts, :older_than_sec))
    |> maybe_put(:limit, Keyword.get(opts, :limit))
    |> maybe_put(:format, Keyword.get(opts, :format))
    |> maybe_put(:provider_stuck, Keyword.get(opts, :provider_stuck))

  case Rindle.runtime_status(filters) do
    {:ok, report} -> ...
    {:error, reason} ->
      Mix.shell().error("Rindle.RuntimeStatus failed: #{inspect(reason)}")
      exit({:shutdown, 1})
  end
end
```

**Text report shape** (lines 68-90):

```elixir
@doc false
def format_text_report(report) do
  [
    "Rindle: runtime status report...",
    "  generated_at: #{DateTime.to_iso8601(report.generated_at)}",
    "  profile:      #{report.filters.profile || "all"}",
    "  older_than:   #{report.filters.older_than || "any"}",
    "  limit:        #{report.filters.limit}",
    "  format:       text"
  ] ++
    format_section("runtime_checks", report.runtime_checks.counts) ++
    format_section("assets", report.assets.counts) ++
    format_section("variants", report.variants.counts) ++
    format_findings(report.runtime_checks.findings) ++
    format_findings(report.variants.findings) ++
    format_upload_findings(report.upload_sessions.findings) ++
    format_upload_sessions(report.upload_sessions) ++
    format_provider_findings(report.provider_assets.findings) ++
    format_recommendations(report.recommendations) ++ ["Done."]
end
```

**Copy guidance:** keep this task a thin wrapper over `Rindle.runtime_status/1`; add assertions for new setup-error copy in the task test, not branching logic in the task.

---

### `README.md` (documentation, reader workflow)

**Analog:** `README.md` + `116-UI-SPEC.md`

**Current section to replace** (README lines 92-109):

```markdown
## Migrations

Run your host app migrations and the packaged Rindle migrations explicitly:

```elixir
rindle_path = Application.app_dir(:rindle, "priv/repo/migrations")
host_path = Path.join([File.cwd!(), "priv", "repo", "migrations"])

{:ok, _, _} =
  Ecto.Migrator.with_repo(MyApp.Repo, fn repo ->
    for path <- [host_path, rindle_path] do
      Ecto.Migrator.run(repo, path, :up, all: true)
    end
  end)
```
```

**Locked docs contract** (`116-UI-SPEC.md`, lines 130-159):

```markdown
| README `## Migrations` | Replace the raw `Application.app_dir(:rindle, "priv/repo/migrations")` + `Ecto.Migrator.run` install path with a compact adopter-owned migration module that calls `Rindle.Migration.up/1` and `Rindle.Migration.down/1`. |

- Keep the displayed migration module to the minimum copyable shape: `use Ecto.Migration`, `def up`, `def down`.
- Do not show direct calls to private migration modules or instruct users to copy files from `priv/repo/migrations`.
- Do not introduce a public `mix rindle.*` install task in copy or examples.

Existing apps that already applied Rindle's packaged migrations can leave them in place. The new module is the documented install path going forward; it does not require replaying or deleting legacy migration files.
```

**Copy guidance:** replace the old raw package-path snippet with the pinned host migration module from CONTEXT D-05. Add default `public` schema and host-owned Oban note. Keep copy compact.

---

### `guides/getting_started.md` (documentation, reader workflow)

**Analog:** `guides/getting_started.md` + `116-UI-SPEC.md`

**Current section to replace** (lines 111-139):

```markdown
## 3. Run Host-App And Rindle Migrations Explicitly

Your app owns its own migrations, and Rindle ships a second migration path
inside the package:

```elixir
Application.ensure_all_started(:rindle)
{:ok, _pid} = MyApp.Repo.start_link()

host_path = Path.join([File.cwd!(), "priv", "repo", "migrations"])
rindle_path = Application.app_dir(:rindle, "priv/repo/migrations")
...
```

Rindle does not ship a public `mix rindle.*` install task for migrations. The
public install path is this docs snippet.
```

**Locked heading/copy rules** (`116-UI-SPEC.md`, lines 49-54 and 118-126):

```markdown
- Keep the greenfield migration path compact: one short orientation paragraph, one migration module snippet, one Oban ownership note, one verification command.
- Do not nest the migration code snippet inside a numbered list item.
- Keep compatibility notes near the migration snippet.

- `Migration:`
- `Oban ownership:`
- `Upgrade note:`
- `Rollback:`
- `Verification:`
```

**Copy guidance:** rename/rework step 3 around normal host-app migrations. Show separate host-owned `Oban.Migration` and `Rindle.Migration.up(version: 1)` snippets or adjacent copy. Do not keep binary-id repo-default advice as the greenfield contract; Phase 116 migration DDL should own explicit IDs.

---

### `guides/upgrading.md` (documentation, reader workflow)

**Analog:** `guides/upgrading.md`

**Current newest-first structure** (lines 18-37):

```markdown
## Unreleased / Next

### Applies to

Future releases that list adopter action items in
[CHANGELOG.md](https://github.com/szTheory/rindle/blob/main/CHANGELOG.md).

### What changed

No upgrade notes for this version yet.

### Upgrade steps

There are no adopter action items for this version. Review `CHANGELOG.md` before
upgrading, then return here when a release lists migration or behavior changes.

### Verification

Use the release's documented verification steps once an upgrade note exists.
```

**Existing migration upgrade style** (lines 75-111):

```markdown
#### 2. Run explicit host and packaged migrations

Run your host migrations and the packaged Rindle migrations explicitly. The
canonical upgrade path stays on `Application.app_dir(:rindle, "priv/repo/migrations")`:

```elixir
Application.ensure_all_started(:rindle)
{:ok, _pid} = MyApp.Repo.start_link()
...
```

`mix rindle.doctor` validates setup and drift. If it reports FFmpeg, Oban, or
migration issues, fix those before you attempt any repair command.
```

**Copy guidance:** add Phase 116 content under `## Unreleased / Next`, newest-first, with `Applies to`, `What changed`, `Upgrade steps`, and `Verification`. Preserve older legacy package-path upgrade content for historical compatibility, but make fresh installs use `Rindle.Migration`.

---

### `guides/operations.md` and `guides/troubleshooting.md` (documentation, reader workflow)

**Analogs:** same files

**Operations sequencing pattern** (`guides/operations.md`, lines 50-52):

```markdown
For existing-adopter upgrades, keep the sequencing strict: explicit migrations
first, `mix rindle.doctor` second, optional `mix rindle.runtime_status` only
when the upgraded state looks wrong, then the matching repair verb.
```

**Troubleshooting sequencing pattern** (`guides/troubleshooting.md`, lines 11-28):

```markdown
## Diagnostics Split

Start with the read-only surfaces first:

- `mix rindle.doctor` validates setup and drift.
- `mix rindle.runtime_status` reports degraded or stuck work.
- The repair verbs perform change only after diagnostics identify the right lane.

For upgrade troubleshooting, keep the same order: explicit migrations,
`mix rindle.doctor`, optional `mix rindle.runtime_status`, then the repair verb
that matches the actual state.
```

**Copy guidance:** only adjust these if doctor/runtime semantics need new setup-error language. Preserve the split: doctor validates setup, runtime status reports degraded work, repair verbs mutate.

---

### `test/rindle/migration_test.exs` (test, batch DDL / catalog-read)

**Analog:** `test/rindle/domain/migration_test.exs`

**DataCase and catalog assertion pattern** (lines 1-14):

```elixir
defmodule Rindle.Domain.MigrationTest do
  use Rindle.DataCase, async: true

  alias Rindle.Repo

  test "media_assets has the new AV columns" do
    {:ok, %{rows: rows}} =
      Repo.query("""
      SELECT column_name FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'media_assets'
      """)

    column_names = Enum.map(rows, fn [name] -> name end) |> MapSet.new()
  end
end
```

**Index assertion pattern** (lines 114-131):

```elixir
{:ok, %{rows: rows}} =
  Repo.query("""
  SELECT indexdef FROM pg_indexes
  WHERE schemaname = 'public' AND tablename = 'media_upload_sessions'
  """)

index_defs = Enum.map(rows, fn [indexdef] -> indexdef end)

assert Enum.any?(index_defs, fn indexdef ->
         String.contains?(indexdef, "session_uri_expires_at") and
           String.contains?(indexdef, "resumable")
       end)
```

**Sandbox pattern** (`test/support/data_case.ex`, lines 17-26):

```elixir
setup tags do
  Rindle.DataCase.setup_sandbox(tags)
  :ok
end

def setup_sandbox(tags) do
  repo = tags[:sandbox_repo] || Rindle.Repo
  pid = Sandbox.start_owner!(repo, shared: not tags[:async])
  on_exit(fn -> Sandbox.stop_owner(pid) end)
end
```

**Copy guidance:** create this new file for focused `Rindle.Migration` proof. Use `async: false` for tests that run migration DDL or mutate shared DB/schema state. Cover idempotent `up/1`, scoped `down/1`, invalid options, explicit UUID/table options, marker behavior, prefix/default public, and no `oban_jobs` creation.

---

### `test/rindle/domain/migration_test.exs` (test, catalog-read)

**Analog:** same file

**Current catalog checks** (lines 72-100):

```elixir
describe "extend_media_upload_sessions_for_resumable migration (Phase 38)" do
  test "media_upload_sessions has the resumable columns" do
    {:ok, %{rows: rows}} =
      Repo.query("""
      SELECT column_name FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'media_upload_sessions'
      """)

    column_names = Enum.map(rows, fn [name] -> name end) |> MapSet.new()

    for required <- ~w(session_uri session_uri_expires_at last_known_offset region_hint) do
      assert required in column_names
    end
  end

  test "media_upload_sessions.last_known_offset is bigint not null with default 0" do
    {:ok, %{rows: [[data_type, is_nullable, default]]}} =
      Repo.query("""
      SELECT data_type, is_nullable, column_default
      FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'media_upload_sessions'
        AND column_name = 'last_known_offset'
      """)

    assert data_type == "bigint"
    assert is_nullable == "NO"
    assert default =~ "0"
  end
end
```

**Copy guidance:** either extend this file with schema-readiness assertions for new marker/prefix behavior or keep it as legacy migration smoke and put full API DDL tests in `test/rindle/migration_test.exs`.

---

### `test/rindle/ops/runtime_checks_test.exs` (test, request-response / catalog-read)

**Analog:** same file

**Stable check ID pattern** (lines 45-90):

```elixir
test "returns deterministic stable check ids" do
  report =
    run_runtime_checks(
      probe: fn -> :ok end,
      profiles: [ImageProfile],
      oban_config: [repo: Rindle.Repo, queues: [rindle_promote: 1, rindle_process: 1, rindle_purge: 1, rindle_maintenance: 1, rindle_media: 1]],
      migration_statuses: []
    )

  assert Enum.map(report.checks, & &1.id) == [
           "doctor.delivery_support",
           "doctor.ffmpeg_runtime",
           "doctor.local_playback",
           "doctor.migrations.pending",
           "doctor.migrations.unresolved",
           "doctor.oban_default_instance",
           "doctor.oban_required_queues",
           "doctor.profile_runtime_fit",
           "doctor.resumable_session_schema"
         ]

  assert report.success?
end
```

**Migration drift fixture pattern** (lines 202-233):

```elixir
test "distinguishes pending and unresolved migration drift" do
  report =
    run_runtime_checks(
      probe: fn -> :ok end,
      env: %{},
      profiles: [],
      oban_config: [repo: Rindle.Repo, queues: [rindle_promote: 1, rindle_process: 1, rindle_purge: 1, rindle_maintenance: 1]],
      migration_statuses: [
        {:down, 20_260_502_120_000, "extend_media_for_av.exs"},
        {:up, 20_260_425_090_000, "** FILE NOT FOUND **"}
      ]
    )

  pending = fetch_check(report, "doctor.migrations.pending")
  unresolved = fetch_check(report, "doctor.migrations.unresolved")

  assert pending.status == :error
  assert unresolved.status == :error
end
```

**Injected catalog fixture pattern** (lines 259-293 and 1065-1089):

```elixir
report =
  run_runtime_checks(
    migration_statuses: [],
    resumable_session_schema_catalog: %{
      columns: %{
        "session_uri" => %{is_nullable: "YES", column_default: nil},
        "session_uri_expires_at" => %{is_nullable: "YES", column_default: nil},
        "last_known_offset" => %{is_nullable: "YES", column_default: nil}
      },
      indexes: [
        "CREATE INDEX media_upload_sessions_expires_at_index ON public.media_upload_sessions USING btree (expires_at)"
      ]
    }
  )

defp fetch_check(report, id) do
  Enum.find(report.checks, &(&1.id == id)) ||
    flunk("expected check #{inspect(id)} to be present")
end
```

**Copy guidance:** add fixture inputs for marker/catalog/legacy states rather than requiring live migration history in every unit test. Lock new OK/WARN/ERROR semantics explicitly.

---

### `test/rindle/doctor_test.exs` (test, request-response / CLI)

**Analog:** same file

**Capture output and injected checks pattern** (lines 14-43):

```elixir
test "prints success message when ffmpeg is valid" do
  output =
    capture_io(fn ->
      report =
        run_doctor_checks([],
          exit_on_failure?: false,
          probe: fn -> :ok end,
          env: %{},
          profiles: [],
          oban_config: [repo: Rindle.Repo, queues: [rindle_promote: 1, rindle_process: 1, rindle_purge: 1, rindle_maintenance: 1]],
          migration_statuses: []
        )

      assert report.success?
    end)

  assert output =~ "Rindle: running environment checks"
  assert output =~ "doctor.ffmpeg_runtime"
  assert output =~ "Rindle: Environment checks passed"
end
```

**Failure rendering pattern** (lines 79-103):

```elixir
test "prints all checks in stable order and emits a summary before failing" do
  output =
    capture_io(fn ->
      report =
        run_doctor_checks(["Does.Not.Exist"],
          exit_on_failure?: false,
          probe: fn -> raise RuntimeError, "ffmpeg missing" end,
          env: %{},
          oban_config: [repo: Rindle.Repo, queues: [rindle_process: 1]],
          migration_statuses: [{:down, 20_260_502_120_000, "extend_media_for_av.exs"}]
        )

      refute report.success?
    end)

  assert output =~ "doctor.migrations.pending"
  assert output =~ "Rindle: Environment checks failed"
end
```

**Copy guidance:** add CLI-facing assertions for new hybrid migration rows, warning-only legacy drift, missing `oban_jobs`, and actionable fix copy. Keep `run_doctor_checks/2` fixture helper style.

---

### `test/rindle/ops/runtime_status_test.exs` (test, CRUD-read)

**Analog:** same file

**Runtime DB test setup** (lines 1-7):

```elixir
defmodule Rindle.Ops.RuntimeStatusTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo

  alias Rindle.Domain.{MediaAsset, MediaProviderAsset, MediaUploadSession, MediaVariant}
  alias Rindle.Ops.RuntimeStatus
  alias Rindle.Workers.ProcessVariant
end
```

**Host-owned Oban proof style** (lines 56-67):

```elixir
test "does not classify queued work as starved when an active oban job exists" do
  asset = insert_asset(%{profile: to_string(StatusImageProfile)})
  _variant = insert_variant(asset, %{name: "thumb", state: "queued", updated_at: age_ago(601)})

  assert {:ok, _job} =
           ProcessVariant.new(%{"asset_id" => asset.id, "variant_name" => "thumb"})
           |> Oban.insert()

  assert {:ok, report} = RuntimeStatus.runtime_status(limit: 2)

  refute Enum.any?(report.variants.findings, &(&1.class == :queue_starved))
end
```

**Invalid input pattern** (lines 171-193):

```elixir
test "rejects unknown filter keys instead of widening into a query dsl" do
  assert {:error, {:unknown_filters, [:unknown]}} =
           RuntimeStatus.runtime_status(%{unknown: :value})
end

assert {:ok, report} =
         RuntimeStatus.runtime_status(
           profile: to_string(StatusImageProfile),
           older_than: 300,
           limit: 3,
           format: :json
         )
```

**Copy guidance:** add tests for setup preflight errors before normal queries. Make missing Rindle tables and missing host-owned `oban_jobs` return structured errors with setup guidance.

---

### `test/rindle/runtime_status_task_test.exs` (test, request-response / CLI)

**Analog:** same file

**Mix shell process pattern** (lines 15-58):

```elixir
setup do
  previous_shell = Mix.shell()
  Mix.shell(Mix.Shell.Process)

  on_exit(fn -> Mix.shell(previous_shell) end)
  :ok
end

test "emits JSON output when requested" do
  asset = insert_asset()
  _failed = insert_variant(asset, %{state: "failed", updated_at: age_ago(700)})
  _session = insert_resumable_session(asset)

  RuntimeStatusTask.run(["--format", "json", "--limit", "1"])

  assert_received {:mix_shell, :info, [output]}
  assert output =~ "\"variants\""
  refute output =~ "\"session_uri\":"
end

test "exits non-zero on invalid format after surfacing the failure" do
  assert catch_exit(RuntimeStatusTask.run(["--format", "yaml"])) == {:shutdown, 1}

  assert_received {:mix_shell, :error, [message]}
  assert message =~ "Rindle.RuntimeStatus failed"
  assert message =~ "invalid_format"
end
```

**Copy guidance:** add a task-level test for setup preflight failures. Assert non-zero exit plus operator copy that says host app installs Oban with `Oban.Migration` and Rindle no longer manages `oban_jobs`.

---

### `test/install_smoke/docs_parity_test.exs` (test, file-I/O / transform)

**Analog:** same file

**Setup-all file loading pattern** (lines 35-47):

```elixir
setup_all do
  {:ok,
   %{
     readme: File.read!(@readme_path),
     contributing: File.read!(@contributing_path),
     guide: File.read!(@guide_path),
     upgrade: File.read!(@upgrade_path),
     troubleshooting: File.read!(@troubleshooting_path),
     release: File.read!(@release_path),
     running: File.read!(@running_path),
     user_flows: File.read!(@user_flows_path)
   }}
end
```

**Current migration docs assertion to replace** (lines 140-153):

```elixir
test "docs call out adopter-owned Repo, default Oban ownership, and explicit migrations", %{
  readme: readme,
  guide: guide
} do
  for doc <- [readme, guide] do
    assert doc =~ "adopter-owned Repo"
    assert doc =~ "default Oban"
    assert doc =~ ~s(config :rindle, :repo, MyApp.Repo)
    assert doc =~ ~s(config :my_app, Oban)
    assert doc =~ "Application.app_dir(:rindle, \"priv/repo/migrations\")"
    assert doc =~ "docs snippet"
    assert doc =~ "mix rindle.*"
  end
end
```

**Upgrade guide structure assertion** (lines 302-343):

```elixir
assert_in_order!(upgrade, [
  "## Version index",
  "## Unreleased / Next",
  "## 0.1.3 and earlier -> current AV-aware runtime"
])

for snippet <- [
      "CHANGELOG.md",
      "### Applies to",
      "### What changed",
      "### Upgrade steps",
      "### Verification",
      "Application.app_dir(:rindle, \"priv/repo/migrations\")",
      "mix rindle.doctor"
    ] do
  assert upgrade =~ snippet
end
```

**Ordering helper** (lines 658-680):

```elixir
defp assert_in_order!(doc, snippets) do
  normalized_doc = String.downcase(doc)

  Enum.reduce(snippets, {-1, nil}, fn snippet, {last_index, _last_snippet} ->
    index = string_index(normalized_doc, String.downcase(snippet))

    assert index,
           "expected snippet #{inspect(snippet)} to appear in order after index #{last_index}"

    assert index > last_index

    {index, snippet}
  end)
end
```

**Copy guidance:** change docs assertions to require `Rindle.Migration.up(version: 1)`, `Rindle.Migration.down(version: 1)`, `Oban.Migration`, `oban_jobs`, `mix rindle.doctor`, and default `public`. Add refutations for the old greenfield `Application.app_dir(:rindle, "priv/repo/migrations")` plus `Ecto.Migrator.run` path in README/getting-started/unreleased upgrade copy while allowing legacy compatibility sections.

---

### `test/install_smoke/support/generated_app_helper.ex` (test utility, file-I/O / batch)

**Analog:** same file

**Constants and report fields to evolve** (lines 11-13 and 97-113):

```elixir
@host_migration_version "20260428170000"
@legacy_rindle_migration_version 20_260_428_110_000

report = %{
  host_migration_ran?: migration_report["host_migration_ran"] == true,
  migration_resolution: migration_report["resolver"] |> to_existing_atom_safe(),
  rindle_migration_path: migration_report["rindle_migration_path"],
  smoke_output: smoke_result.output
}
```

**Generated app patch flow** (lines 400-417):

```elixir
defp patch_generated_app!(root, app_name, app_module, package_root, network_version, profile_mode) do
  patch_mix_exs!(root, package_root, network_version, profile_mode)
  patch_test_config!(root, app_name, profile_mode)
  patch_test_helper!(root, profile_mode)
  patch_runtime_config!(root, app_name, app_module, profile_mode)
  patch_application!(root, app_name, app_module, profile_mode)
  patch_router!(root, app_name, app_module, profile_mode)
  write_tus_live_view!(root, app_name, app_module, profile_mode)
  write_profile!(root, app_name, app_module, profile_mode)
  write_host_migration!(root)
  write_migration_runner!(root, app_name, app_module)
  write_legacy_upgrade_preparer!(root, app_module)
  write_smoke_test!(root, app_module, profile_mode, network_version)
  write_fixture!(root, profile_mode)
end
```

**Current host migration helper** (lines 926-949):

```elixir
defp write_host_migration!(root) do
  path =
    Path.join(
      root,
      "priv/repo/migrations/#{@host_migration_version}_create_install_smoke_markers.exs"
    )

  File.write!(
    path,
    """
    defmodule RindleSmokeApp.Repo.Migrations.CreateInstallSmokeMarkers do
      use Ecto.Migration

      def change do
        create table(:install_smoke_markers) do
          add :name, :string, null: false

          timestamps()
        end
      end
    end
    """
  )
end
```

**Current package-path runner to replace for greenfield** (lines 951-992):

```elixir
defp write_migration_runner!(root, _app_name, app_module) do
  path = Path.join(root, "priv/install_smoke/migrate.exs")
  File.mkdir_p!(Path.dirname(path))

  File.write!(
    path,
    """
    Application.ensure_all_started(:rindle)
    {:ok, _pid} = #{app_module}.Repo.start_link()

    host_path = Path.join([File.cwd!(), "priv", "repo", "migrations"])
    rindle_path = Application.app_dir(:rindle, "priv/repo/migrations")

    {:ok, _, _} =
      Ecto.Migrator.with_repo(#{app_module}.Repo, fn repo ->
        for path <- [host_path, rindle_path] do
          Ecto.Migrator.run(repo, path, :up, all: true)
        end
      end)

    File.write!(
      "tmp/install_smoke_migration_report.json",
      Jason.encode!(%{
        resolver: "application_app_dir",
        host_migration_ran: result.rows == [["install_smoke_markers"]],
        rindle_migration_path: rindle_path
      })
    )
    """
  )
end
```

**Legacy upgrade preparer may keep package-path history** (lines 994-1012):

```elixir
defp write_legacy_upgrade_preparer!(root, app_module) do
  path = Path.join(root, "priv/install_smoke/prepare_upgrade.exs")
  File.mkdir_p!(Path.dirname(path))

  File.write!(
    path,
    """
    Application.ensure_all_started(:rindle)
    {:ok, _pid} = #{app_module}.Repo.start_link()

    host_path = Path.join([File.cwd!(), "priv", "repo", "migrations"])
    rindle_path = Application.app_dir(:rindle, "priv/repo/migrations")
    legacy_cutoff = #{@legacy_rindle_migration_version}

    {:ok, _, _} =
      Ecto.Migrator.with_repo(#{app_module}.Repo, fn repo ->
        Ecto.Migrator.run(repo, host_path, :up, all: true)
        Ecto.Migrator.run(repo, rindle_path, :up, to: legacy_cutoff)
      end)
    """
  )
end
```

**Generated smoke boot assertion to update** (lines 1162-1166):

```elixir
test "generated app boots with adopter repo ownership and default Oban wiring" do
  assert Application.fetch_env!(:rindle, :repo) == Repo
  assert Application.fetch_env!(:rindle_smoke_app, Oban)[:repo] == Repo
  assert File.dir?(Application.app_dir(:rindle, "priv/repo/migrations"))
end
```

**Copy guidance:** add separate generated host migrations for install-smoke marker, host-owned Oban (`Oban.Migration.up()`), and Rindle (`Rindle.Migration.up(version: 1)`). The migration runner should run host migrations through `mix ecto.migrate` or equivalent host path only. Keep legacy upgrade preparer package-path behavior scoped to legacy upgrade proof.

---

### `test/install_smoke/generated_app_smoke_test.exs` (test, batch / request-response)

**Analog:** same file

**Current greenfield assertions to replace** (lines 148-156):

```elixir
test "generated Phoenix app runs host plus Rindle migrations explicitly and proves the canonical presigned PUT lifecycle",
     %{report: report} do
  assert report.host_migration_ran?
  assert report.migration_resolution == :application_app_dir
  assert String.ends_with?(report.rindle_migration_path, "/priv/repo/migrations")
  refute String.contains?(report.rindle_migration_path, "deps/rindle")
  assert report.smoke_exit_code == 0
  assert report.lifecycle_proved?
end
```

**Legacy upgrade assertions** (lines 319-355):

```elixir
test "generated Phoenix app upgrades a pre-v1.4 image-only adopter through the public migration path",
     %{report: report} do
  assert_install_source!(report)
  assert report.host_migration_ran?
  assert report.migration_resolution == :application_app_dir
  assert report.legacy_migration_cutoff == "20260428110000"
  assert String.ends_with?(report.rindle_migration_path, "/priv/repo/migrations")
  refute String.contains?(report.rindle_migration_path, "deps/rindle")
  assert report.legacy_asset_upgrade_safe?
end

assert Enum.map(report.canonical_upgrade_step_sequence, & &1.proof) == [
       "FFmpeg >= 6.0",
       "Application.app_dir(:rindle, \"priv/repo/migrations\")",
       "mix rindle.doctor",
       "mix rindle.runtime_status",
       "Rindle.requeue_variants/2",
       "mix rindle.regenerate_variants"
     ]
```

**Copy guidance:** greenfield assertions should prove real host migrations installed Oban and Rindle separately, `Rindle.Migration` did not create `oban_jobs`, and old package-path resolver is absent from fresh install proof. Legacy upgrade proof can still mention package-path history when intentionally scoped.

---

### `test/rindle/api_surface_boundary_test.exs` (test, transform / docs-boundary)

**Analog:** same file

**Public module allowlist pattern** (lines 4-40):

```elixir
@public_modules [
  Rindle,
  Rindle.Error,
  Rindle.Profile,
  Rindle.Profile.Presets.Web,
  Rindle.Upload.Broker,
  Rindle.Delivery,
  Rindle.Storage,
  Rindle.Storage.Local,
  Rindle.Storage.S3,
  Rindle.Storage.GCS,
  Rindle.Streaming,
  Rindle.Streaming.Provider,
  Rindle.Upload.TusPlug,
  Rindle.LiveView,
  Rindle.Admin.Router,
  Rindle.HTML,
  Rindle.Authorizer,
  Rindle.Analyzer,
  Rindle.Scanner,
  Rindle.Processor,
  Rindle.Processor.Image
]
```

**Visibility assertion pattern** (lines 74-87):

```elixir
describe "compiled docs boundary" do
  test "D-03 reconciliation keeps storage adapters public alongside the facade allowlist" do
    for module <- @public_modules do
      assert visible_module?(module),
             "#{inspect(module)} should stay visible in compiled docs"
    end
  end

  test "D-05 helper modules resolve to hidden module docs" do
    for module <- @helper_hidden_modules do
      assert hidden_module?(module),
             "#{inspect(module)} should be hidden from compiled docs"
    end
  end
end
```

**Copy guidance:** add `Rindle.Migration` to the public module boundary and assert `up/1` and `down/1` docs are visible. Keep helper modules like `Rindle.Migration.Options` and `Rindle.Migration.V1` hidden.

---

### `test/install_smoke/package_metadata_test.exs` (test, file-I/O / package proof)

**Analog:** same file + `mix.exs`

**Package file inclusion pattern** (`mix.exs`, lines 279-289):

```elixir
defp package do
  [
    licenses: ["MIT"],
    links: %{
      "GitHub" => @source_url,
      "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md",
      "Docs" => "https://hexdocs.pm/rindle"
    },
    files:
      ~w(lib priv/repo/migrations priv/static/rindle_admin mix.exs README.md RUNNING.md CHANGELOG.md LICENSE guides)
  ]
end
```

**Package metadata test pattern** (lines 23-35 and 63-85):

```elixir
@required_paths [
  "mix.exs",
  "README.md",
  "CHANGELOG.md",
  "LICENSE",
  "priv/static/rindle_admin/rindle-admin.css",
  "guides/getting_started.md",
  "guides/release_publish.md"
]
@prohibited_paths ["_build", ".planning", "test", ".github", "coveralls.json"]

for rel_path <- @required_paths do
  assert metadata =~ ~s(<<"#{rel_path}">>)
  assert File.exists?(Path.join(package_root, rel_path))
end
```

**Copy guidance:** if package tests change, assert `priv/repo/migrations/20260424205942_create_oban_tables.exs` still ships as a legacy compatibility artifact. Do not remove `priv/repo/migrations` from package files in this phase.

## Shared Patterns

### Public Migration Wrapper

**Source:** `deps/oban/lib/oban/migration.ex` lines 14-31, 52-59, 119-184  
**Apply to:** `lib/rindle/migration.ex`, README/getting-started/upgrading snippets, generated-app host migration files.

Use a normal host Ecto migration that wraps `Rindle.Migration.up(version: 1)` and `down(version: 1)`. Docs should not teach unpinned `up()` even if implementation permits latest-by-default.

### Option Validation

**Source:** `lib/rindle/profile/validator.ex` lines 202-231, 416-430  
**Apply to:** `lib/rindle/migration.ex`, optional `lib/rindle/migration/options.ex`, migration API tests.

Use NimbleOptions for unknown option rejection, defaults, and allowed-version validation. Convert validation errors to `ArgumentError`.

### Rindle-Owned DDL

**Source:** `priv/repo/migrations/*.exs`, especially:

- `20260424155129_create_media_assets.exs` lines 4-20
- `20260425090000_create_media_attachments.exs` lines 4-15
- `20260506120000_create_media_provider_assets.exs` lines 15-47
- `20260507160000_extend_media_upload_sessions_for_resumable.exs` lines 14-17

**Apply to:** `lib/rindle/migration/v1.ex`, `test/rindle/migration_test.exs`, runtime catalog readiness checks.

Copy schema intent, not legacy execution strategy. Make primary keys, foreign key types, timestamps, indexes, and `prefix` explicit.

### Hybrid Health Checks

**Source:** `lib/rindle/ops/runtime_checks.ex` lines 76-139, 358-407, 524-561, 1536-1546  
**Apply to:** runtime checks, doctor tests, generated-app upgrade proof.

Keep stable result maps and stable check IDs. Add marker/catalog/legacy/Oban inputs as injectable fixtures for tests.

### Runtime Status Preflight

**Source:** `lib/rindle/ops/runtime_status.ex` lines 36-63, 680-768  
**Apply to:** runtime status service and task.

Return `{:error, reason}` before normal report queries when required Rindle tables or host-owned `oban_jobs` are absent. Preserve success report shape.

### Docs Parity Contract

**Source:** `test/install_smoke/docs_parity_test.exs` lines 35-47, 140-153, 302-343, 658-680; `116-UI-SPEC.md` lines 130-159  
**Apply to:** README, getting-started, upgrading, operations/troubleshooting copy.

Assert required snippets and explicit ordering. Add refutations for old greenfield package-path snippets. Allow old package path only in intentionally scoped legacy upgrade content.

### Generated-App Proof

**Source:** `test/install_smoke/support/generated_app_helper.ex` lines 400-417, 926-992, 994-1012; `test/install_smoke/generated_app_smoke_test.exs` lines 148-156, 319-355  
**Apply to:** generated smoke helper and generated app smoke tests.

The helper already writes migrations and scripts into a generated Phoenix app. Update that same seam to write separate host-owned Oban and Rindle migrations, and change reports/assertions away from `:application_app_dir` for greenfield installs.

## No Analog Found

No planned file lacks an analog. The weakest match is optional helper decomposition under `lib/rindle/migration/`; use `lib/rindle/profile/validator.ex`, packaged migrations, and Oban's migration wrapper as the combined pattern.

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| _none_ | - | - | All new or modified files have an exact, role-match, or partial analog. |

## Metadata

**Analog search scope:** `lib/`, `priv/repo/migrations/`, `test/`, `guides/`, `README.md`, `mix.exs`, `deps/oban/lib/oban/migration.ex`, `.planning/phases/116-versioned-rindle-migration-module/116-UI-SPEC.md`  
**Files scanned:** 160+ repo files via `rg --files`; 25 target files classified; 18 analog files read with concrete excerpts.  
**Pattern extraction date:** 2026-07-01  
**Project guidance read:** `AGENTS.md`; local skill index `.codex/skills/gsd-milestone-next-step/SKILL.md`  
**Read-only constraint:** Only this `116-PATTERNS.md` artifact was written.
