# Phase 120: Adoption Proof & Release Truth - Pattern Map

**Mapped:** 2026-08-09  
**Files analyzed:** 15 anticipated changed/created files  
**Analogs found:** 15 / 15

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `test/install_smoke/support/generated_app_helper.ex` | utility / fixture harness | file-I/O, request-response | itself: `prove_package_install!/1`, host migration writers, runner | exact extension |
| `test/install_smoke/generated_app_smoke_test.exs` | test | request-response | `GeneratedAppSmokeAssertions` + image/video modules in same file | exact extension |
| `examples/adoption_demo/priv/repo/migrations/<timestamp>_install_rindle.exs` | migration | CRUD / request-response | generated fixture `InstallRindle` writer | exact role/data-flow |
| `examples/adoption_demo/priv/repo/migrations/20260528120100_add_oban.exs` | migration | CRUD / request-response | generated fixture `InstallHostOwnedOban` writer | exact role/data-flow |
| `examples/adoption_demo/priv/rindle_migrate.exs` | utility / migration runner | batch | existing script, replaced by normal host migration flow | exact responsibility |
| `examples/adoption_demo/mix.exs` | config | batch | existing `ecto.setup`/`test` aliases | exact extension |
| `examples/adoption_demo/test/rindle_migration_contract_test.exs` (new) | test | CRUD / request-response | `test/rindle/migration_test.exs` and demo `readme_walkthrough_test.exs` | role-match |
| `README.md` | documentation | transform | existing Migrations section | exact section |
| `guides/getting_started.md` | documentation | transform | existing step 3 migration section | exact section |
| `guides/upgrading.md` | documentation | transform | existing populated-public-install section | exact section |
| `guides/troubleshooting.md` | documentation | transform | existing missing-table/Oban guidance | role-match |
| `lib/rindle/migration.ex` | API documentation | request-response | existing moduledoc and public function docs | exact extension |
| `CHANGELOG.md` | release documentation | transform | current top Unreleased/release-note structure | exact role |
| `test/install_smoke/docs_parity_test.exs` | test | transform | migration and bounded-move parity tests | exact extension |
| `test/install_smoke/release_docs_parity_test.exs` | test | transform | release-guide parity tests | exact extension |

## Pattern Assignments

### `test/install_smoke/support/generated_app_helper.ex` (fixture utility, file-I/O/request-response)

**Analog:** its package proof entrypoint and generated host migration runner.

**Entrypoint and cleanup pattern** ([lines 21-79](test/install_smoke/support/generated_app_helper.ex:21)):

```elixir
ensure_package!(workspace_root, package_root)
generate_phoenix_app!(workspace_root, generated_app_root)
patch_generated_app!(generated_app_root, app_name, app_module, package_root, network_version, profile_mode)
fetch_deps!(generated_app_root, shared_env, network_version)
... = run_cmd!(generated_app_root, ["mix", "run", "--no-start", "priv/install_smoke/migrate.exs"], shared_env)
migration_report = read_json!(Path.join(generated_app_root, "tmp/install_smoke_migration_report.json"))
boot_result = boot_app!(generated_app_root, app_module, shared_env)
```

Extend this report-first interface; create separate, named default, public-compatibility, and populated-move scenarios instead of mutating compile-time routing in one generated app. Add JSON-safe facts to the report, then assert policy in the repository test.

**Host-owned migration writer pattern** ([lines 964-1001](test/install_smoke/support/generated_app_helper.ex:964)):

```elixir
defmodule RindleSmokeApp.Repo.Migrations.InstallHostOwnedOban do
  use Ecto.Migration
  def up, do: Oban.Migration.up()
  def down, do: Oban.Migration.down(version: 1)
end

defmodule RindleSmokeApp.Repo.Migrations.InstallRindle do
  use Ecto.Migration
  def up, do: Rindle.Migration.up(version: 1)
  def down, do: Rindle.Migration.down(version: 1)
end
```

Copy this public-API handoff. For compatibility, write a distinct explicitly public fixture; for upgrade, write a host migration calling the directional helper with the documented `SET LOCAL lock_timeout` before it. Do not replay `Application.app_dir(:rindle, ...)` for a greenfield/default proof.

**Runner/report pattern and required correction** ([lines 1004-1053](test/install_smoke/support/generated_app_helper.ex:1004)):

```elixir
Ecto.Migrator.run(repo, host_path, :up, to: ...)
host_oban_migration_ran? = regclass_exists?.(repo, "oban_jobs")
Ecto.Migrator.run(repo, host_path, :up, to: ...)
rindle_migration_ran? = regclass_exists?.(repo, "rindle_migration_versions")
```

The analog's `regclass_exists?/2` currently hardcodes `"public.#{table_name}"` ([lines 1019-1024](test/install_smoke/support/generated_app_helper.ex:1019)). Replace/extend it with a schema argument and report all `Rindle.Migration.V1.owned_relations/0` in the expected schema, absence from `public` for default routing, `public.oban_jobs` before/after, and `public.schema_migrations`. A bare or public-only lookup is not isolation proof.

### `test/install_smoke/generated_app_smoke_test.exs` (ExUnit consumer proof, request-response)

**Analog:** `GeneratedAppSmokeAssertions` and the image profile case.

**Assertion-template pattern** ([lines 3-42](test/install_smoke/generated_app_smoke_test.exs:3)):

```elixir
defp assert_host_owned_migrations!(report) do
  assert report.host_migration_ran?
  assert report.host_oban_migration_ran?
  assert report.rindle_migration_ran?
  refute report.rindle_created_oban_jobs?
  assert report.migration_resolution == :host_migrations
  refute String.contains?(report.rindle_migration_path || "", "deps/rindle")
end
```

Keep common transport/package assertions in this template and add schema/ownership assertions beside them. Tests should call a helper once in `setup_all`, register `on_exit` cleanup, and consume the stable report map; see the image case ([lines 154-175](test/install_smoke/generated_app_smoke_test.exs:154)). Retain package/no-checkout checks, compile, boot, and a real persistence lifecycle result.

### `examples/adoption_demo/priv/repo/migrations/<timestamp>_install_rindle.exs` (host migration, CRUD)

**Analog:** generated app `InstallRindle` migration above; public API contract in [`lib/rindle/migration.ex`](lib/rindle/migration.ex:5).

```elixir
defmodule AdoptionDemo.Repo.Migrations.InstallRindle do
  use Ecto.Migration

  def up, do: Rindle.Migration.up(version: 1)
  def down, do: Rindle.Migration.down(version: 1)
end
```

Use one ordinary checked-in host migration. The default has no prefix option and therefore proves `rindle`; no migration should create, move, configure, or prefix Oban or the host Ecto ledger.

### `examples/adoption_demo/priv/repo/migrations/20260528120100_add_oban.exs` (host migration, CRUD)

**Analog:** helper's `InstallHostOwnedOban` migration ([lines 974-979](test/install_smoke/support/generated_app_helper.ex:974)).

Normalize the demo's existing `Oban.Migrations` spelling to the documented public `Oban.Migration` form only after verifying the resolved dependency exports it. Keep this separate from Rindle's migration and retain down behavior.

### `examples/adoption_demo/priv/rindle_migrate.exs` and `examples/adoption_demo/mix.exs` (migration runner/config, batch)

**Analog:** current aliases ([lines 60-82](examples/adoption_demo/mix.exs:60)).

```elixir
"ecto.setup": ["ecto.create", "ecto.migrate", "rindle.migrate", "run priv/repo/seeds.exs"],
"rindle.migrate": ["cmd mix run --no-start priv/rindle_migrate.exs"]
```

Once the host Rindle migration is checked in, fold it into normal `ecto.migrate` and retire the raw runner/alias rather than leave a second source of truth. The current runner resolves `Application.app_dir(:rindle, "priv/repo/migrations")` and calls `Ecto.Migrator.run` directly; that is precisely the legacy path Phase 120 must not preserve for fresh setup. Update CI use consistently: the demo lane currently runs `mix ecto.migrate` then `mix rindle.migrate` ([`.github/workflows/ci.yml` lines 859-866](.github/workflows/ci.yml:859)).

### `examples/adoption_demo/test/rindle_migration_contract_test.exs` (new ExUnit boundary/persistence test, CRUD)

**Analog:** `test/rindle/migration_test.exs` for catalog assertions, with demo tests' normal `ConnCase`/`DataCase` support.

Use the existing fixed relation source rather than a duplicated table list:

```elixir
for relation <- Rindle.Migration.V1.owned_relations() do
  assert table_exists?("rindle", relation)
  refute table_exists?("public", relation)
end

assert table_exists?("public", "oban_jobs")
assert table_exists?("public", "schema_migrations")
```

Add a focused real Rindle write/read using the demo's configured `AdoptionDemo.Repo`, after normal migration and application boot. Keep it database-oriented rather than LiveView-oriented; the Cohort migration contract test is a UI contract and is not the right place for migration ownership assertions.

### Documentation surfaces — `README.md`, `guides/getting_started.md`, `guides/upgrading.md`, `guides/troubleshooting.md`, `lib/rindle/migration.ex`, and `CHANGELOG.md` (documentation/API docs, transform)

**Analogs:** current matching sections and the docs parity suite.

**Canonical host migration wording** ([`README.md` lines 95-117](README.md:95)):

```elixir
defmodule MyApp.Repo.Migrations.InstallHostOwnedOban do
  use Ecto.Migration
  def up, do: Oban.Migration.up()
end

defmodule MyApp.Repo.Migrations.InstallRindle do
  use Ecto.Migration
  def up, do: Rindle.Migration.up(version: 1)
end
```

**Bounded populated move wording** ([`guides/upgrading.md` lines 89-103](guides/upgrading.md:89)):

```elixir
def up do
  execute("SET LOCAL lock_timeout = '5s'")
  Rindle.Migration.move_public_to_rindle(version: 1)
end
```

Use calm operator language and retain the exact sequence: backup and maintenance window; stop/drain Rindle writers and Oban workers; host migration under lock timeout; deploy the `rindle`-compiled build; doctor/runtime verification; reverse only if quiesced and exactly reversible, otherwise restore backup. State required permissions/lock behavior without claiming online or automatic migration.

The migration API docs already establish the allowed default and compatibility pairing ([`lib/rindle/migration.ex` lines 15-20](lib/rindle/migration.ex:15)) and directional ownership boundary ([lines 58-64](lib/rindle/migration.ex:58)); extend those facts, not the API. Changelog content should follow the existing top release-note structure and be parity-tested without manually bumping `mix.exs`.

### `test/install_smoke/docs_parity_test.exs` and `release_docs_parity_test.exs` (documentation contract tests, transform)

**Analog:** migration docs parity loop ([lines 140-199](test/install_smoke/docs_parity_test.exs:140)) and bounded-move test ([lines 202-260](test/install_smoke/docs_parity_test.exs:202)).

```elixir
for {name, section} <- migration_sections do
  assert section =~ "Rindle.Migration.up(version: 1)"
  assert section =~ "Oban.Migration"
  assert section =~ "schema_migrations"
  refute section =~ "Application.app_dir(:rindle, \"priv/repo/migrations\")"
  refute section =~ "Ecto.Migrator.run"
end
```

Extend this source-section approach: load the public docs/API moduledoc/release-note draft once in `setup_all`, check required phrases and ordered steps, and refute forbidden scope expansion (`search_path`, generic mover, arbitrary prefixes, automatic/online claims). Keep maintainer release-process tests in `release_docs_parity_test.exs`; migration/adopter truth belongs in `docs_parity_test.exs`.

## Shared Patterns

### Package authority and cleanup

**Source:** `test/install_smoke/support/generated_app_helper.ex:21-79`, `test/install_smoke/generated_app_smoke_test.exs:154-175`.

The authority is the unpacked `mix hex.build --unpack` artifact (or existing explicit network mode), never a repo-local path dependency. Generate fresh apps, return a report map, register `on_exit` cleanup, and assert package-source facts before schema facts.

### Host ownership boundary

**Source:** `test/install_smoke/support/generated_app_helper.ex:974-999`; `lib/rindle/migration.ex:15-20,58-64`.

Use distinct host migrations: `Oban.Migration` owns `public.oban_jobs`; `Rindle.Migration` owns its fixed relation set; host Ecto retains `public.schema_migrations`. No code in Phase 120 may create/move/configure/prefix the two host-owned relations.

### Schema-qualified proof

**Source:** `test/rindle/migration_test.exs:276-317,617-646` (catalog/ownership test style).

Derive the Rindle relation list from `Rindle.Migration.V1.owned_relations/0`; query every relation with explicit `rindle` or `public`, not `search_path`. Fresh default must prove all fixed relations in `rindle` and none in `public`; compatibility must intentionally prove public only; populated move must prove data/integrity survives and default runtime persistence works afterward.

### Documentation as executable contract

**Source:** `test/install_smoke/docs_parity_test.exs:140-260`.

Parsers remain simple source-section helpers plus direct `assert`/`refute` statements. Assert concrete public API snippets, migration ordering, host ownership, destructive/guarded rollback, and verification commands; keep legacy package replay only inside explicitly historical upgrade copy.

## No Analog Found

None. Phase 120 extends established package-smoke, host-migration, Cohort, and docs-parity surfaces; it should not introduce a parallel proof framework.

## Planning Pitfalls

- Do not overload `prove_upgrade_install!/0`: it is a legacy AV adopter proof with a separate package-directory history. Add an isolation-move scenario with its own report and lifecycle assertions.
- Do not test default routing with `public.rindle_migration_versions`; this is the known blind spot in the helper's current runner.
- Do not put generated-app policy assertions inside generated fixture strings. Fixtures provision/report; repository ExUnit tests assert policy.
- Do not keep `mix rindle.migrate` merely as a convenience after its behavior becomes obsolete; it risks CI/demo proving the wrong handoff.
- Do not invent a third prefix/runtime selection mode. `prefix: "public"` is compatibility paired with a public-compiled fixture, not dynamic routing.
- Avoid broad-suite cleanup unrelated to this phase. Run focused package-consumer/proof/adoption checks named in `RUNNING.md`, then retain the release-train lanes.

## Metadata

**Analog search scope:** `test/install_smoke/`, `test/rindle/`, `examples/adoption_demo/`, `guides/`, root documentation, CI workflow  
**Files scanned:** 24  
**Pattern extraction date:** 2026-08-09
