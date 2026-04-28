# Background Processing

Rindle uses **Oban** for all background work — variant processing, asset
promotion, async storage purges, and scheduled cleanup. Oban is a hard
dependency: it is SQL-backed, persistent, observable, and supports
**transactional job enqueueing**, which is load-bearing for Rindle's
atomic-promote and async-purge patterns.

This guide covers:

- Oban setup and queue configuration
- The Rindle worker modules and what each one does
- Why transactional enqueueing matters and how Rindle uses it
- Retry behavior and per-job overrides
- Telemetry surface (the locked public contract)
- Scaling variant processing

## Oban Ownership

**Rindle ships Oban workers but does not start or supervise Oban itself.**
Adopters own the Oban supervision tree, queue topology, reliability
settings, and the **default Oban Repo** that backs those jobs. In Phase 6,
Rindle enqueues through the default `Oban` module path, so your app is
responsible for running Oban against the same repo you configured with
`config :rindle, :repo, MyApp.Repo`. This avoids hidden runtime ownership and
lets adopters tune queue concurrency to their host environment.

In plain terms: adopters own Oban supervision, adopters own queue config, and
adopters own the default Oban Repo.

Phase 6 does **not** add named-instance support. If your app uses a
named-instance or custom `:oban_name`, treat that as out of scope for the
current release: the delivered contract is compatibility with the default
`Oban` path only.

Add Oban to your application:

```elixir
# mix.exs (in your application's deps, NOT inside Rindle)
{:oban, "~> 2.21"}
```

Configure Oban with the queues Rindle's workers use:

```elixir
# config/config.exs (or runtime.exs)
config :my_app, Oban,
  repo: MyApp.Repo,
  queues: [
    rindle_promote: 5,        # PromoteAsset — usually fast
    rindle_process: 10,       # ProcessVariant — CPU-bound; tune for cores
    rindle_purge: 2,          # PurgeStorage — IO-bound; rate-limit if needed
    rindle_maintenance: 1     # CleanupOrphans / AbortIncompleteUploads cron
  ],
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron,
     crontab: [
       {"0 1 * * *", Rindle.Workers.AbortIncompleteUploads},
       {"0 2 * * *", Rindle.Workers.CleanupOrphans, args: %{"dry_run" => false}}
     ]}
  ]
```

Then add Oban to your application supervisor:

```elixir
# lib/my_app/application.ex
children = [
  MyApp.Repo,
  {Oban, Application.fetch_env!(:my_app, Oban)},
  # ...
]
```

That supervisor setup is the contract Rindle proves today: adopters own Oban
startup, adopters own queue config, and Rindle relies on the default `Oban`
instance being available for enqueueing. Named-instance routing via
`:oban_name` is intentionally deferred from this phase.

## Worker Modules

Rindle ships five Oban workers; you do not invoke them directly except
in tests. They are enqueued automatically by the public API:

| Worker                                | Queue                | Triggered By                                      | Job Args                              |
| ------------------------------------- | -------------------- | ------------------------------------------------- | ------------------------------------- |
| `Rindle.Workers.PromoteAsset`         | `rindle_promote`     | `Broker.verify_completion/2` (transactional)      | `%{"asset_id" => uuid}`               |
| `Rindle.Workers.ProcessVariant`       | `rindle_process`     | `PromoteAsset.enqueue_variants/2` (post-promotion) | `%{"asset_id" => uuid, "variant_name" => name}` |
| `Rindle.Workers.PurgeStorage`         | `rindle_purge`       | `Rindle.detach/3` (post-commit)                   | `%{"asset_id" => uuid, "profile" => mod_name}` |
| `Rindle.Workers.CleanupOrphans`       | `rindle_maintenance` | Cron / `mix rindle.cleanup_orphans`               | `%{"dry_run" => bool, "storage" => mod_name}` |
| `Rindle.Workers.AbortIncompleteUploads` | `rindle_maintenance` | Cron / `mix rindle.abort_incomplete_uploads`      | (none)                                |

Each worker has `@max_attempts` configured for its expected failure profile:

- `PromoteAsset` — 3 attempts (mostly fast DB transitions)
- `ProcessVariant` — 5 attempts (network/IO; processor occasionally retries
  on transient libvips/storage errors)
- `PurgeStorage` — 3 attempts (idempotent — safe to retry)
- Cron workers — 3 attempts (maintenance jobs retry transient failures, then
  fall back to the next scheduled run)

## Transactional Enqueueing

The most important thing to know about Rindle's Oban use is that jobs are
enqueued **inside the same Ecto transaction** as the state change that
triggers them. This is why Oban is required and not optional — Rindle
relies on `Oban.insert/3` working inside an `Ecto.Multi`:

```elixir
# from lib/rindle/upload/broker.ex (verify_completion/2)
Ecto.Multi.new()
|> Ecto.Multi.update(:session, MediaUploadSession.changeset(session, %{state: "completed"}))
|> Ecto.Multi.update(:asset,   MediaAsset.changeset(asset,     %{state: "validating"}))
|> Oban.insert(:promote_job,   Rindle.Workers.PromoteAsset.new(%{asset_id: asset.id}))
|> Repo.transaction()
```

If the transaction commits, the job is durably queued. If the transaction
rolls back, the job was never inserted. There is no window where the asset
is `validating` but no `PromoteAsset` job exists, and there is no window
where a job runs against a state that the database never committed.

The same pattern applies on the detach path:

```elixir
# detach: delete the attachment row and enqueue the purge job in one repo-owned unit of work
Ecto.Multi.new()
|> Ecto.Multi.delete(:attachment, attachment)
|> Oban.insert(:purge, Rindle.Workers.PurgeStorage.new(%{
  "asset_id" => asset.id,
  "profile" => asset.profile
}))
|> MyApp.Repo.transaction()
```

The database change and job insert stay atomic, but the actual storage I/O
still happens later in `Rindle.Workers.PurgeStorage`. That keeps storage side
effects out of the DB transaction while preserving the guarantee that a
successful detach already has a purge job durably queued.

## Retry Behavior

Oban retries failed jobs with exponential backoff. The `@max_attempts`
above caps the total tries; after that, the job sits in the `discarded`
state. You can override per-job at the call site:

```elixir
Rindle.Workers.ProcessVariant.new(args, max_attempts: 10)
```

For variant processing failures, the worker also transitions the
`MediaVariant` row to `failed` after the retry budget is exhausted.
Failed variants are queryable (`MediaVariant.state == "failed"`) and
can be re-enqueued via `mix rindle.regenerate_variants` once the
underlying issue (corrupt source, insufficient memory, recipe bug) is
resolved.

For idempotent operations (`PurgeStorage`, `CleanupOrphans`), retries
are safe by design — repeated deletion of an already-deleted object
is a no-op (the Storage adapter swallows `not_found` errors during
purge).

## Telemetry Surface (Public Contract)

Rindle emits telemetry events at the locked event-family boundaries
defined in Phase 3. The contract test
(`test/rindle/telemetry/contract_test.exs`) asserts these are stable;
breaking the surface requires a major version bump.

| Event                                    | Triggered By                                   | Required Metadata Keys             |
| ---------------------------------------- | ---------------------------------------------- | ---------------------------------- |
| `[:rindle, :upload, :start]`             | `Broker.initiate_session/2` (post-commit)      | `:profile`, `:adapter`             |
| `[:rindle, :upload, :stop]`              | `Broker.verify_completion/2` (post-commit)     | `:profile`, `:adapter`             |
| `[:rindle, :asset, :state_change]`       | Every `AssetFSM.transition/3` success          | `:profile`, `:adapter`, `:from`, `:to` |
| `[:rindle, :variant, :state_change]`     | Every `VariantFSM.transition/3` success        | `:profile`, `:adapter`, `:from`, `:to` |
| `[:rindle, :delivery, :signed]`          | `Delivery.url/3` success                       | `:profile`, `:adapter`, `:mode`    |
| `[:rindle, :cleanup, :run]`              | Every cleanup worker run                       | `:worker`, plus numeric measurements |

All measurements are numeric (counts, byte sizes, durations in microseconds,
or `system_time`). All metadata maps include `:profile` and `:adapter`
where applicable so dashboards can group by either.

The contract test attaches `:telemetry.attach_many/4` handlers, exercises
minimal in-process flows, and asserts the exact event-name allowlist plus
required metadata keys. Any change to event names, metadata keys, or
measurement types breaks the contract lane.

## Wiring a Telemetry Handler

A typical adopter handler that pipes Rindle events into their observability
stack:

```elixir
defmodule MyApp.Telemetry do
  def attach do
    :telemetry.attach_many(
      "myapp-rindle-handler",
      [
        [:rindle, :upload, :start],
        [:rindle, :upload, :stop],
        [:rindle, :asset, :state_change],
        [:rindle, :variant, :state_change],
        [:rindle, :delivery, :signed],
        [:rindle, :cleanup, :run]
      ],
      &handle_event/4,
      nil
    )
  end

  def handle_event([:rindle, :variant, :state_change], _measurements, meta, _) do
    MyApp.Metrics.increment("rindle.variant.state_change",
      tags: [profile: meta.profile, from: meta.from, to: meta.to])
  end

  def handle_event([:rindle, :cleanup, :run], measurements, meta, _) do
    MyApp.Metrics.gauge("rindle.cleanup.sessions_deleted",
      measurements.sessions_deleted, tags: [worker: meta.worker])
  end

  def handle_event(_, _, _, _), do: :ok
end
```

Attach the handler from your application's `start/2` callback:

```elixir
def start(_type, _args) do
  MyApp.Telemetry.attach()
  Supervisor.start_link(children, opts)
end
```

## Scaling Variant Processing

`ProcessVariant` is CPU-bound (libvips). The right concurrency is
roughly the number of CPU cores available to the BEAM VM, minus 1 for
headroom. On a 4-core node:

```elixir
queues: [rindle_process: 3]
```

For workloads with very large images, watch memory: libvips streams
where it can but holds whole tiles in memory. If you see OOM kills,
reduce `rindle_process` concurrency before increasing memory. For
truly large images (> 100 MP), consider a dedicated worker pool with
its own resource limits.

For burst protection, pair Oban with a rate-limiting plugin
(`Oban.Pro` rate-limits, or external tooling) — Rindle does not
rate-limit internally because the right strategy is adopter-specific.

## Storage I/O Ordering

Two ordering invariants Rindle enforces:

1. **Storage I/O never happens inside a DB transaction.** The Storage
   behaviour is only invoked from worker `perform/1` callbacks or
   from `Broker.sign_url/2` (which calls `presigned_put/3` *outside*
   the transaction that updates the session row).
2. **Purge is async and idempotent.** Detach commits the DB row
   change; purge runs in `Rindle.Workers.PurgeStorage` post-commit.
   If the purge fails (transient network error, etc.), Oban retries
   it. Storage failures cannot leave the DB in an inconsistent state.

These two invariants are why Rindle requires Oban (not "supports" Oban
optionally) — without transactional enqueueing on the upload path and
post-commit enqueueing on the detach path, Rindle would have to
reinvent these patterns less robustly.
