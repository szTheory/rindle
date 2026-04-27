# Operations

Rindle ships five Mix tasks for Day-2 operational maintenance. Each task
has a detailed `@moduledoc` describing its arguments, options, exit codes,
and expected output — that `@moduledoc` is the canonical reference. This
guide is a cross-link directory: it tells you which task to reach for in
which situation, and which underlying `@moduledoc` block to read for the
full command-line contract.

This page is intentionally a thin index, per Phase 5 decision D-18.
Re-authoring the task documentation here would create drift between the
guide and the `@moduledoc` block. Click through to the module docs for
the authoritative reference.

## Task Reference

### `mix rindle.cleanup_orphans`

Removes upload sessions in the `expired` state and the storage objects
they reference.

- **Module:** `Mix.Tasks.Rindle.CleanupOrphans`
- **Worker equivalent:** `Rindle.Workers.CleanupOrphans` (cron-schedulable)
- **Underlying service:** `Rindle.Ops.UploadMaintenance.cleanup_orphans/1`
- **Defaults:** dry-run is the safe default. Pass `--no-dry-run` or
  `--live` to perform destructive deletions.

Run `mix rindle.abort_incomplete_uploads` first to mark timed-out sessions
as `expired`. Then `mix rindle.cleanup_orphans` removes them.

### `mix rindle.regenerate_variants`

Re-enqueues variants in `stale` or `missing` state so the variant pipeline
regenerates them. Optionally filter by profile or variant name.

- **Module:** `Mix.Tasks.Rindle.RegenerateVariants`
- **Worker equivalent:** `Rindle.Workers.ProcessVariant` (the underlying
  job; this task only enqueues — it does not process synchronously)
- **Underlying service:** `Rindle.Ops.VariantMaintenance.regenerate_variants/1`
- **Targeting rules:** only `stale` and `missing` variants are eligible.
  `queued`, `processing`, and `ready` variants are counted as skipped.

Use this after changing a variant spec — the recipe digest changes,
existing variants flip to `stale`, and this task re-enqueues them.

### `mix rindle.verify_storage`

Reconciles `MediaVariant` rows against storage by HEAD-checking each
variant's storage object. Variants whose object is gone flip to
`missing`; other errors are counted but do not mutate state.

- **Module:** `Mix.Tasks.Rindle.VerifyStorage`
- **Underlying service:** `Rindle.Ops.VariantMaintenance.verify_storage/1`
- **Output counters:** `checked`, `present`, `missing`, `fsm_blocked`,
  `errors`. Non-`:not_found` errors (auth failures, network issues)
  cause exit-1; missing objects do not.

Run periodically (weekly for large catalogs) to catch storage-side
drift — out-of-band deletions, lifecycle policy expirations, multi-region
replication gaps.

### `mix rindle.abort_incomplete_uploads`

Transitions upload sessions in `signed` or `uploading` state past their
TTL into the `expired` state. This is the prerequisite to
`mix rindle.cleanup_orphans`.

- **Module:** `Mix.Tasks.Rindle.AbortIncompleteUploads`
- **Worker equivalent:** `Rindle.Workers.AbortIncompleteUploads`
  (cron-schedulable)
- **Underlying service:** `Rindle.Ops.UploadMaintenance.abort_incomplete_uploads/1`

Sessions already in terminal states (`completed`, `expired`, `aborted`,
`failed`) are not touched.

### `mix rindle.backfill_metadata`

Re-runs the configured analyzer for assets in `ready`, `available`, or
`degraded` states and persists updated metadata. The recovery path when
analyzer output changes (new fields added, bug fixes in analysis logic,
or assets that were promoted before analysis ran).

- **Module:** `Mix.Tasks.Rindle.BackfillMetadata`
- **Underlying service:** `Rindle.Ops.MetadataBackfill.backfill_metadata/1`
- **Filtering:** `--profile` restricts to a single profile;
  `--storage`/`--analyzer` override the default modules.

Typically run as a one-shot operation after a schema migration or analyzer
upgrade — not on a recurring schedule.

## Recommended Schedule

For a typical adopter:

| Task                                  | Cadence              | Notes                                              |
| ------------------------------------- | -------------------- | -------------------------------------------------- |
| `mix rindle.abort_incomplete_uploads` | Daily                | Flips timed-out sessions to `expired`              |
| `mix rindle.cleanup_orphans`          | Daily (after abort)  | Removes `expired` sessions and storage objects     |
| `mix rindle.verify_storage`           | Weekly–monthly       | Detects out-of-band storage deletions              |
| `mix rindle.regenerate_variants`      | On demand            | After recipe changes; or manually after `verify_storage` flips variants to `missing` |
| `mix rindle.backfill_metadata`        | One-shot             | After analyzer upgrade or schema migration         |

Both `abort_incomplete_uploads` and `cleanup_orphans` have Oban cron-worker
equivalents — schedule them through Oban rather than `mix` in production:

```elixir
config :my_app, Oban,
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       {"0 1 * * *", Rindle.Workers.AbortIncompleteUploads},
       {"0 2 * * *", Rindle.Workers.CleanupOrphans, args: %{"dry_run" => false}}
     ]}
  ]
```

The Mix task variants are kept primarily for one-off operator use and
for CI lanes that need a deterministic command-line entry point.

## Telemetry

Cleanup workers emit `[:rindle, :cleanup, :run]` with numeric measurements
(`sessions_deleted`, `objects_deleted`, `errors`, etc.) and `worker`
metadata identifying which worker fired. Wire your telemetry handler to
surface cleanup throughput in your observability stack — see
[Background Processing](background_processing.html#telemetry-surface-public-contract)
for the full event surface.

A typical handler stanza for the cleanup family:

```elixir
def handle_event([:rindle, :cleanup, :run], measurements, meta, _) do
  MyApp.Metrics.gauge("rindle.cleanup.sessions_deleted",
    measurements.sessions_deleted, tags: [worker: meta.worker])
  MyApp.Metrics.gauge("rindle.cleanup.errors",
    measurements.errors, tags: [worker: meta.worker])
end
```

## Operational Tips

- **Always start in dry-run.** `mix rindle.cleanup_orphans` defaults to
  dry-run; the worker variant takes `dry_run: true` by default. The first
  time you wire a new environment, run dry-run for a week and inspect the
  counts before enabling destructive mode.
- **Monitor `errors` and `fsm_blocked`.** Non-zero values indicate
  something the routine maintenance pass cannot resolve on its own.
  `errors` typically means storage auth or network problems;
  `fsm_blocked` typically means a variant is in a terminal state that
  forbids the transition the maintenance pass would have taken.
- **Run `verify_storage` after disaster recovery.** If you restore a
  storage bucket from backup or fail over to a different region, run
  `verify_storage` to detect any objects that were not in the snapshot.
- **`regenerate_variants` is enqueue-only.** It enqueues Oban jobs; the
  actual processing happens in `rindle_process` queue workers. If you
  see jobs piling up, scale that queue (see [Background Processing](background_processing.html#scaling-variant-processing)).
- **`backfill_metadata` can be expensive.** It downloads each asset's
  source bytes and re-runs the analyzer. For large catalogs, restrict
  by profile (`--profile`) and run during off-peak hours.

## When to Escalate

The Mix tasks handle routine maintenance. The following situations are
not what these tasks are for, and need direct database / storage
intervention:

- A `quarantined` asset that legitimately needs to be unquarantined
  (manual DB update; document the audit trail).
- A `failed` variant whose underlying source is corrupt — fix the source,
  flip the variant back to `queued`, then `regenerate_variants` picks it
  up.
- A `degraded` asset where some variants succeeded and others failed
  permanently — decide whether to delete or leave degraded based on
  product policy.

See [Troubleshooting](troubleshooting.html) for recovery playbooks for
each of these states.
