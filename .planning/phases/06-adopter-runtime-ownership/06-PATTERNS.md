# Phase 6: Adopter Runtime Ownership - Pattern Map

**Mapped:** 2026-04-28
**Files analyzed:** 11
**Analogs found:** 11 / 11

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/rindle.ex` | utility | request-response | `lib/rindle/ops/metadata_backfill.ex` for opts injection; `lib/rindle.ex` existing facade for public API shape | partial |
| `lib/rindle/upload/broker.ex` | service | request-response | `lib/rindle/upload/broker.ex` existing transaction + `Oban.insert/3` pattern | exact |
| `lib/rindle/repo.ex` | config | CRUD | `test/adopter/canonical_app/repo.ex` | role-match |
| `config/config.exs` | config | request-response | `config/config.exs` existing app-key defaults | exact |
| `config/runtime.exs` | config | request-response | `config/runtime.exs` existing runtime env resolution | exact |
| `config/test.exs` | config | request-response | `config/test.exs` existing adopter repo fixture wiring | exact |
| `test/support/data_case.ex` | test | CRUD | `test/support/data_case.ex` sandbox owner pattern | exact |
| `test/test_helper.exs` | test | event-driven | `test/test_helper.exs` repo + Oban boot pattern | exact |
| `test/adopter/canonical_app/repo.ex` | test | CRUD | `lib/rindle/repo.ex` | role-match |
| `test/adopter/canonical_app/lifecycle_test.exs` | test | request-response | `test/rindle/upload/lifecycle_integration_test.exs` plus existing canonical adopter lane | exact |
| `test/rindle/**/*` representative integration tests | test | request-response | `test/rindle/upload/lifecycle_integration_test.exs`, `test/rindle/upload/broker_test.exs`, `test/rindle/attach_detach_test.exs`, `test/rindle/workers/maintenance_workers_test.exs`, `test/rindle/config/config_test.exs` | exact |

## Ownership Leak Map

### Q1. `Rindle.Repo` hard-coded in public runtime paths vs internal/test-only paths

**Public runtime paths with direct ownership leaks**

`lib/rindle.ex` lines 125-174:

```elixir
def attach(asset_or_id, owner, slot, _opts \\ []) do
  ...
  |> Ecto.Multi.run(:purge_old, fn _repo, %{existing: existing} ->
    if existing do
      old_asset = Rindle.Repo.get!(MediaAsset, existing.asset_id)
      ...
      Oban.insert(job)
    else
      {:ok, nil}
    end
  end)
  |> Rindle.Repo.transaction()
end
```

Leakage:
- `Rindle.Repo.get!/2` inside the multi callback ignores the transaction repo arg.
- `Rindle.Repo.transaction/1` fixes transaction ownership to library repo.
- `Oban.insert/1` uses global `Oban`, not adopter-owned instance.

`lib/rindle.ex` lines 191-221:

```elixir
def detach(owner, slot, _opts \\ []) do
  ...
  |> Ecto.Multi.run(:purge, fn _repo, %{existing: existing} ->
    old_asset = Rindle.Repo.get!(MediaAsset, existing.asset_id)
    ...
    Oban.insert(job)
  end)
  |> Rindle.Repo.transaction()
end
```

Same two ownership leaks: hard-coded repo and global Oban insert.

`lib/rindle.ex` lines 318-352:

```elixir
def upload(profile_module, upload, opts \\ []) do
  ...
  Ecto.Multi.new()
  |> Ecto.Multi.insert(:asset, ...)
  |> Oban.insert(:promote_job, PromoteAsset.new(%{asset_id: asset_id}))
  |> Rindle.Repo.transaction()
end
```

Leakage:
- proxied upload path always persists through `Rindle.Repo`
- job enqueue is coupled to the multi executed by `Rindle.Repo.transaction/1`

`lib/rindle/upload/broker.ex` lines 42-64, 100-119, 140-185:

```elixir
case Repo.transaction(fn ->
  ...
  |> Repo.insert()
end) do
```

```elixir
with %MediaUploadSession{} = session <- Repo.get(MediaUploadSession, session_id),
     asset <- Repo.preload(session, :asset).asset,
...
  Repo.transaction(fn ->
    ...
    |> Repo.update()
  end)
end
```

```elixir
with %MediaUploadSession{} = session <- Repo.get(MediaUploadSession, session_id),
     asset <- Repo.preload(session, :asset).asset,
...
  |> Oban.insert(:promote_job, PromoteAsset.new(%{asset_id: asset.id}))
  |> Repo.transaction()
```

Leakage:
- all broker entry points alias `Rindle.Repo` and use it directly
- direct-upload lifecycle is still library-owned, not adopter-owned
- `Oban.insert/3` runs in a multi tied to library repo

**Internal/test-only paths where hard-coding exists but is not the Phase 6 public-contract blocker**

`test/support/data_case.ex` lines 7-25:

```elixir
using do
  quote do
    alias Rindle.Repo
  end
end

def setup_sandbox(tags) do
  pid = Sandbox.start_owner!(Rindle.Repo, shared: not tags[:async])
  on_exit(fn -> Sandbox.stop_owner(pid) end)
end
```

This is test harness ownership, not adopter runtime API ownership.

`test/test_helper.exs` lines 1-3:

```elixir
{:ok, _} = Rindle.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(Rindle.Repo, :manual)
{:ok, _} = Oban.start_link(repo: Rindle.Repo, queues: false, testing: :manual)
```

This is the root of test-wide coupling: tests boot Oban against `Rindle.Repo`.

`test/adopter/canonical_app/lifecycle_test.exs` lines 11-20, 23-25, 56-65:

```elixir
# TODO(adopter-repo): `Rindle.Repo` is hard-coded inside `lib/rindle.ex`
# ...
# introduce `config :rindle, :repo` runtime resolution
```

```elixir
use Oban.Testing, repo: Rindle.Repo
```

```elixir
case start_supervised(Rindle.Adopter.CanonicalApp.Repo) do
  {:ok, _pid} -> :ok
  {:error, {:already_started, _}} -> :ok
end

Sandbox.checkout(Rindle.Adopter.CanonicalApp.Repo)
Sandbox.mode(Rindle.Adopter.CanonicalApp.Repo, {:shared, self()})
```

This test explicitly documents the current gap: the adopter repo exists, but the public flow still runs through `Rindle.Repo`.

## Repo Resolution Patterns To Reuse

### Q2. Existing config/helper patterns that can support adopter-owned repo resolution with minimal churn

**Best existing analog: central config accessor module**

`lib/rindle/config.ex` lines 1-19:

```elixir
defmodule Rindle.Config do
  @spec queue_name() :: atom()
  def queue_name do
    Application.fetch_env!(:rindle, :queue)
  end

  @spec signed_url_ttl_seconds() :: pos_integer()
  def signed_url_ttl_seconds do
    Application.get_env(:rindle, :signed_url_ttl_seconds, 900)
  end
end
```

Why this matters:
- runtime lookup already lives behind a tiny accessor module
- adding `repo/0` and likely `oban_name/0` here is the lowest-churn project-consistent seam

**Best existing analog: option-first dependency injection in service code**

`lib/rindle/ops/metadata_backfill.ex` lines 83-100:

```elixir
def backfill_metadata(opts) when is_list(opts) do
  storage_mod = Keyword.fetch!(opts, :storage)
  analyzer_mod = Keyword.fetch!(opts, :analyzer)
  profile_filter = Keyword.get(opts, :profile)
  ...
end
```

`lib/rindle/ops/upload_maintenance.ex` lines 68-76:

```elixir
def cleanup_orphans(opts \\ []) do
  dry_run? = Keyword.get(opts, :dry_run, true)
  storage_mod = Keyword.get(opts, :storage, nil)

  case fetch_expired_sessions() do
    {:ok, sessions} ->
      report = process_cleanup(sessions, dry_run?, storage_mod)
```

Why this matters:
- existing internal APIs already accept injected runtime dependencies via `opts`
- planner can preserve public signatures and thread `repo` / `oban` through opts first, then back it with `Rindle.Config`

**Best existing analog: runtime fallback to application env**

`lib/mix/tasks/rindle.backfill_metadata.ex` lines 116-124:

```elixir
defp resolve_module(opts, opt_key, app_config_key) do
  case Keyword.get(opts, opt_key) do
    nil -> Application.get_env(:rindle, app_config_key)
    module_str -> load_module(module_str, opt_key)
  end
end
```

`lib/rindle/workers/cleanup_orphans.ex` lines 162-164:

```elixir
defp resolve_storage_adapter(_args) do
  {:ok, Application.get_env(:rindle, :default_storage)}
end
```

Why this matters:
- repo resolution can follow the same pattern: explicit opt override, else `Application.get_env(:rindle, :repo, Rindle.Repo)` or strict `fetch_env!`
- this is already the house style for runtime-owned dependencies

**Existing config seam already documents target direction**

`config/test.exs` lines 17-35:

```elixir
# Adopter Repo for CI-08 lane ...
# ...
# introduce `config :rindle, :repo` runtime resolution
config :rindle, Rindle.Adopter.CanonicalApp.Repo,
  username: db_user,
  ...
```

Planner should treat that comment as the canonical migration target, not invent a new key shape.

## Oban Ownership Patterns And Seams

### Q3. How Oban is currently coupled to `Rindle.Repo`, and what seams already exist

**Current coupling**

`test/test_helper.exs` lines 1-3:

```elixir
{:ok, _} = Rindle.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(Rindle.Repo, :manual)
{:ok, _} = Oban.start_link(repo: Rindle.Repo, queues: false, testing: :manual)
```

Effects:
- the only started Oban instance in tests is pinned to `Rindle.Repo`
- `Oban.insert/1` and `Oban.insert/3` currently assume default/global Oban state

`lib/rindle/upload/broker.ex` lines 157-184:

```elixir
Ecto.Multi.new()
...
|> Oban.insert(:promote_job, PromoteAsset.new(%{asset_id: asset.id}))
|> Repo.transaction()
```

`lib/rindle.ex` lines 155-170 and 205-216:

```elixir
job = PurgeStorage.new(%{...})
Oban.insert(job)
...
|> Rindle.Repo.transaction()
```

Effects:
- enqueue paths are coupled both to the default Oban API and the repo owning the transaction
- attach/detach do not pass repo into enqueue helpers, so there is no transaction-local ownership seam yet

**Seams already present**

`test/rindle/ops/variant_maintenance_test.exs` lines 190-227 proves code already relies on normal Oban insert semantics:

```elixir
{:ok, second_job} =
  ProcessVariant.new(args,
    unique: [
      fields: [:args, :worker, :queue],
      keys: [:asset_id, :variant_name],
      states: [:available, :scheduled, :executing, :retryable],
      period: :infinity
    ]
  )
  |> Oban.insert()

assert second_job.conflict?
```

Meaning:
- uniqueness behavior is contract-tested at the Oban boundary already
- planner should preserve real `Oban.insert` behavior, not replace with ad hoc wrappers that change conflict semantics

`test/rindle/workers/maintenance_workers_test.exs` lines 63-67 and 173-181:

```elixir
assert :ok =
  perform_job(CleanupOrphans, %{
    "dry_run" => false,
    "storage" => to_string(Rindle.StorageMock)
  })
```

```elixir
assert {:ok, _job} = Oban.insert(CleanupOrphans.new(job_args))
```

Meaning:
- job construction and execution are already tested separately
- a future adopter-owned Oban seam can keep worker contracts stable if enqueue callsites change

`config/config.exs` lines 10-12 and `lib/rindle/config.ex` lines 6-9:

```elixir
config :rindle, :queue, :rindle
```

```elixir
def queue_name do
  Application.fetch_env!(:rindle, :queue)
end
```

Meaning:
- there is already a centralized runtime config precedent for queue-related ownership
- Phase 6 can extend config ownership without broad architectural change

## Canonical Adopter Test Patterns To Reuse

### Q4. Test patterns the planner should reuse to prove the canonical adopter path

**Pattern 1: explicit adopter repo bootstrap beside shared sandbox**

`test/adopter/canonical_app/lifecycle_test.exs` lines 56-65:

```elixir
case start_supervised(Rindle.Adopter.CanonicalApp.Repo) do
  {:ok, _pid} -> :ok
  {:error, {:already_started, _}} -> :ok
end

Sandbox.checkout(Rindle.Adopter.CanonicalApp.Repo)
Sandbox.mode(Rindle.Adopter.CanonicalApp.Repo, {:shared, self()})
```

Reuse this shape when Phase 6 switches the public path from “adopter repo exists” to “public API actually uses adopter repo”.

**Pattern 2: per-test runtime env override with restore-on-exit**

`test/rindle/upload/lifecycle_integration_test.exs` lines 33-43:

```elixir
previous_local = Application.get_env(:rindle, Rindle.Storage.Local)
Application.put_env(:rindle, Rindle.Storage.Local, root: root)

on_exit(fn ->
  case previous_local do
    nil -> Application.delete_env(:rindle, Rindle.Storage.Local)
    value -> Application.put_env(:rindle, Rindle.Storage.Local, value)
  end
end)
```

`test/adopter/canonical_app/lifecycle_test.exs` lines 78-102 repeats the same pattern for S3/ExAws config.

Planner should reuse this for `:repo` and any Oban-owner config key to keep tests isolated.

**Pattern 3: lock the config accessor contract with focused tests**

`test/rindle/config/config_test.exs` lines 4-23:

```elixir
assert :rindle == Rindle.Config.queue_name()
...
previous_queue = Application.get_env(:rindle, :queue)
...
Application.put_env(:rindle, :queue, :rindle_override)
```

Reuse this pattern for new config accessors like repo/Oban resolution.

**Pattern 4: full lifecycle integration with real job assertions**

`test/adopter/canonical_app/lifecycle_test.exs` lines 107-177:

```elixir
{:ok, session} = Broker.initiate_session(AdopterProfile, filename: "adopter.png")
{:ok, %{session: signed, presigned: presigned}} = Broker.sign_url(session.id)
:ok = put_to_presigned_url(presigned.url, @png_1x1)
{:ok, %{session: completed, asset: asset}} = Broker.verify_completion(session.id)
assert_enqueued(worker: PromoteAsset, args: %{"asset_id" => asset.id})
...
{:ok, _attachment} = Rindle.attach(asset.id, owner, "primary")
assert :ok = Rindle.detach(owner, "primary")
assert_enqueued(worker: PurgeStorage, args: %{"asset_id" => asset.id})
```

This is the canonical proof path. Keep it end-to-end and change assertions so reads happen through the adopter-owned repo where relevant.

**Pattern 5: keep focused unit tests around individual ownership-sensitive entrypoints**

`test/rindle/upload/broker_test.exs` and `test/rindle/attach_detach_test.exs` are the smallest high-signal regression suites for broker and facade ownership changes.

## Concrete Pattern Assignments

### `lib/rindle.ex` (public facade, request-response)

**Copy repo/config injection style from:** `lib/rindle/config.ex` and `lib/rindle/ops/metadata_backfill.ex`

**Current hard-coded runtime pattern to replace**: [lib/rindle.ex]( /Users/jon/projects/rindle/lib/rindle.ex:125 )

```elixir
def attach(asset_or_id, owner, slot, _opts \\ []) do
  ...
  |> Rindle.Repo.transaction()
end
```

**Config accessor pattern to copy**: [lib/rindle/config.ex]( /Users/jon/projects/rindle/lib/rindle/config.ex:1 )

```elixir
defmodule Rindle.Config do
  def queue_name do
    Application.fetch_env!(:rindle, :queue)
  end
end
```

**Opts injection pattern to copy**: [lib/rindle/ops/metadata_backfill.ex]( /Users/jon/projects/rindle/lib/rindle/ops/metadata_backfill.ex:83 )

```elixir
def backfill_metadata(opts) when is_list(opts) do
  storage_mod = Keyword.fetch!(opts, :storage)
  analyzer_mod = Keyword.fetch!(opts, :analyzer)
end
```

**Planner note**
- Add the ownership seam here first because `attach/4`, `detach/3`, and `upload/3` are the public adopter-facing leakage points called out by the canonical adopter test.

### `lib/rindle/upload/broker.ex` (service, request-response)

**Copy minimal-churn transaction pattern from existing file, but replace repo ownership source**

**Current pattern**: [lib/rindle/upload/broker.ex]( /Users/jon/projects/rindle/lib/rindle/upload/broker.ex:42 )

```elixir
case Repo.transaction(fn ->
  ...
  |> Repo.insert()
end) do
```

**Current Oban-in-multi pattern**: [lib/rindle/upload/broker.ex]( /Users/jon/projects/rindle/lib/rindle/upload/broker.ex:157 )

```elixir
Ecto.Multi.new()
...
|> Oban.insert(:promote_job, PromoteAsset.new(%{asset_id: asset.id}))
|> Repo.transaction()
```

**Closest seam to copy from worker/runtime resolution style**: [lib/rindle/workers/cleanup_orphans.ex]( /Users/jon/projects/rindle/lib/rindle/workers/cleanup_orphans.ex:66 )

```elixir
with {:ok, storage_mod} <- resolve_storage_adapter(args) do
  cleanup_opts = build_cleanup_opts(dry_run?, storage_mod)
  UploadMaintenance.cleanup_orphans(cleanup_opts)
end
```

**Planner note**
- Broker is the right place to centralize direct-upload repo ownership.
- Keep function signatures stable and resolve repo/Oban near function entry, as `CleanupOrphans` resolves runtime dependencies before executing core logic.

### `config/*.exs` + `lib/rindle/config.ex` (runtime ownership config)

**Copy from existing runtime/env patterns**

`config/config.exs` lines 3-12:

```elixir
config :rindle,
  ecto_repos: [Rindle.Repo]

config :rindle, :queue, :rindle
config :rindle, :signed_url_ttl_seconds, 900
```

`config/runtime.exs` lines 3-13:

```elixir
if config_env() == :prod do
  database_url = System.get_env("DATABASE_URL") || raise ...

  config :rindle, Rindle.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
end
```

**Planner note**
- The repo owner key should live alongside these app-level knobs.
- Avoid changing `ecto_repos` first unless Phase 6 explicitly needs supervision behavior; current tests show adopter repo is presently runtime-only, not application-supervised.

### `test/adopter/canonical_app/*` (canonical adopter proof lane)

**Copy from existing file itself plus `test/rindle/upload/lifecycle_integration_test.exs`**

`test/adopter/canonical_app/lifecycle_test.exs` is already the canonical acceptance lane and contains the TODO that defines the target state.

`test/rindle/upload/lifecycle_integration_test.exs` lines 58-79 gives the smaller direct-upload assertion pattern:

```elixir
{:ok, session} = Broker.initiate_session(LocalProfile, filename: "direct.png")
{:ok, %{session: signed, presigned: presigned}} = Broker.sign_url(session.id)
...
{:ok, %{session: completed, asset: asset}} = Broker.verify_completion(session.id)
assert Rindle.Repo.get!(MediaUploadSession, session.id).state == "completed"
assert_enqueued worker: PromoteAsset, args: %{"asset_id" => asset.id}
```

**Planner note**
- Convert these assertions to prove ownership, not just behavior: reads should verify rows through adopter repo where the runtime contract says adopter owns persistence.

## Shared Patterns

### Runtime dependency resolution
**Sources:** `lib/rindle/config.ex:1-19`, `lib/mix/tasks/rindle.backfill_metadata.ex:116-124`, `lib/rindle/workers/cleanup_orphans.ex:162-164`

Use this shape:

```elixir
case Keyword.get(opts, :dependency_key) do
  nil -> Application.get_env(:rindle, :dependency_key)
  value -> value
end
```

This is the strongest existing low-churn pattern for adopter-owned runtime dependencies.

### Safe per-test config override
**Sources:** `test/rindle/upload/lifecycle_integration_test.exs:33-43`, `test/adopter/canonical_app/lifecycle_test.exs:78-102`, `test/rindle/config/config_test.exs:10-23`

Use this shape:

```elixir
previous = Application.get_env(:rindle, some_key)
Application.put_env(:rindle, some_key, new_value)

on_exit(fn ->
  case previous do
    nil -> Application.delete_env(:rindle, some_key)
    value -> Application.put_env(:rindle, some_key, value)
  end
end)
```

### Real Oban contract assertions
**Sources:** `test/rindle/ops/variant_maintenance_test.exs:147-231`, `test/rindle/workers/maintenance_workers_test.exs:173-181`

Use this shape:

```elixir
{:ok, second_job} = ProcessVariant.new(args, unique: [...]) |> Oban.insert()
assert second_job.conflict?
```

and

```elixir
assert {:ok, _job} = Oban.insert(CleanupOrphans.new(job_args))
```

These preserve actual Oban behavior instead of stubbing queue semantics away.

## Canonical Answers

### Q1. Public vs internal hard-coding summary

- Public runtime leaks are concentrated in `lib/rindle.ex` and `lib/rindle/upload/broker.ex`.
- Internal/test-only coupling is concentrated in `test/support/data_case.ex`, `test/test_helper.exs`, and the current canonical adopter lane.
- The canonical adopter test already documents the runtime contract breach explicitly.

### Q2. Minimal-churn repo-resolution path

- Extend `Rindle.Config` with repo accessor(s); this matches current app-config style.
- Resolve repo/Oban near function entry with `opts` override then app-env fallback; this matches ops service + worker patterns.
- Keep public API signatures stable and thread ownership via optional opts/internal helpers first.

### Q3. Oban coupling and seams

- Today Oban is coupled through global `Oban.insert` and a test helper that starts Oban with `repo: Rindle.Repo`.
- Existing seams are config accessors, option injection, and worker tests that already validate real Oban behavior.
- The strongest non-invasive seam is likely “resolve owner once, then pass it into enqueue/transaction helpers”.

### Q4. Test patterns to reuse

- Start adopter repo explicitly with `start_supervised/1` and sandbox it.
- Override runtime env per test with restore-on-exit.
- Keep focused config accessor tests.
- Keep full lifecycle acceptance plus smaller broker/facade regression tests.
- Keep real Oban assertions (`assert_enqueued`, `perform_job`, conflict checks).

### Q5. File clusters likely to change together

**Cluster A: public runtime ownership**
- `lib/rindle.ex`
- `lib/rindle/upload/broker.ex`
- `lib/rindle/config.ex`
- `config/config.exs`
- `config/runtime.exs`

Reason:
- these are the direct repo/Oban owner resolution points

**Cluster B: repo module and adopter fixture alignment**
- `lib/rindle/repo.ex`
- `test/adopter/canonical_app/repo.ex`
- `config/test.exs`

Reason:
- any change to repo ownership/config shape will need the canonical adopter fixture updated in lockstep

**Cluster C: global test harness / Oban ownership**
- `test/test_helper.exs`
- `test/support/data_case.ex`
- `test/rindle/config/config_test.exs`

Reason:
- if tests need a configurable repo/Oban owner instead of a hard-coded library repo, these files are the harness choke points

**Cluster D: behavioral proof suites**
- `test/adopter/canonical_app/lifecycle_test.exs`
- `test/rindle/upload/broker_test.exs`
- `test/rindle/upload/lifecycle_integration_test.exs`
- `test/rindle/attach_detach_test.exs`
- `test/rindle/workers/maintenance_workers_test.exs`

Reason:
- these tests cover the public API, direct upload, proxied upload, attach/detach, and real Oban scheduling contracts that Phase 6 can regress

## Metadata

**Analog search scope:** `lib/rindle*`, `config/*.exs`, `test/support/*`, `test/adopter/canonical_app/*`, representative `test/rindle/**/*`
**Files scanned:** 20+
**Pattern extraction date:** 2026-04-28
