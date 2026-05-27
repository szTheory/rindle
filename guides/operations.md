# Operations

Rindle ships six Mix tasks for Day-2 operational maintenance. Each task
has a detailed `@moduledoc` describing its arguments, options, exit codes,
and expected output — that `@moduledoc` is the canonical reference. This
guide is a cross-link directory: it tells you which task to reach for in
which situation, and which underlying `@moduledoc` block to read for the
full command-line contract.

This page is intentionally a thin index, per Phase 5 decision D-18.
Re-authoring the task documentation here would create drift between the
guide and the `@moduledoc` block. Click through to the module docs for
the authoritative reference.

## Package-Consumer Proof Matrix

Phase 29 proves the public install posture from a generated package-consumer
Phoenix app in two lanes: image-only and AV-enabled. Keep the split disciplined:

- [`README.md`](../README.md) stays the narrow adopter quickstart.
- [`getting_started.md`](getting_started.md) is the canonical deep guide for
  the installed-artifact lifecycle, explicit migrations, `mix rindle.doctor`,
  and the image-only plus AV package-consumer matrix.
- [`release_publish.md`](release_publish.md) holds maintainer-only commands for
  `bash scripts/release_preflight.sh` and `bash scripts/public_smoke.sh VERSION`
  when proving a published artifact.

Use the Mix tasks below for day-2 runtime maintenance after the install proof
has passed; do not treat this page as a second install guide.

For owner/account erasure, do not improvise with maintenance tasks. The
supported account-deletion surface is `Rindle.preview_owner_erasure/2` plus
`Rindle.erase_owner/2` as documented in [`user_flows.md`](user_flows.md).
Multi-owner orchestration uses `Rindle.preview_batch_owner_erasure/2` and
`Rindle.erase_batch_owner_erasure/2`; operators can run
`mix rindle.batch_owner_erasure` for the shell entry point. See the
[**Batch owner erasure**](user_flows.md) subsection in [`user_flows.md`](user_flows.md)
for the canonical narrative, and `mix help rindle.batch_owner_erasure` for the
full CLI contract.
`mix rindle.cleanup_orphans` remains maintenance-only for expired upload
residue after `mix rindle.abort_incomplete_uploads`.

## Runtime Diagnostics

Phase 31 keeps the operator split explicit:

- `mix rindle.doctor` validates setup and drift. It checks prerequisite runtime
  and ownership conditions before you guess.
- `mix rindle.runtime_status` reports degraded or stuck work. It is a bounded,
  read-only status report for assets, variants, and upload sessions.
- The repair verbs perform change. Use `reprobe`, `requeue`, `regenerate`,
  `cleanup`, or `sweep` only after diagnostics point you at the right lane.

In short: doctor validates setup and drift, runtime status reports degraded or stuck work, and repair verbs perform change.

The current contract intentionally has no dashboard and no auto-remediation.
Primary operator surfaces remain `Rindle` plus `mix`.

For existing-adopter upgrades, keep the sequencing strict: explicit migrations
first, `mix rindle.doctor` second, optional `mix rindle.runtime_status` only
when the upgraded state looks wrong, then the matching repair verb.

## Supported Repair Verbs

Phase 30 freezes five operator verbs. Use the verb that matches the failure
mode instead of improvising with direct row mutation:

- `reprobe` — `Rindle.reprobe/1` refreshes probe-derived asset fields for one
  asset without mutating unrelated lifecycle state.
- `requeue` — `Rindle.requeue_variants/2` re-enqueues failed or cancelled
  variants for one asset, optionally narrowed with `variant_names: [...]`.
- `regenerate` — `mix rindle.regenerate_variants` is the broad maintenance lane
  for `stale` or `missing` variants after preset/profile drift or
  `verify_storage`.
- `cleanup` — `mix rindle.cleanup_orphans` removes expired upload sessions and
  their staged objects after `mix rindle.abort_incomplete_uploads`.
- `sweep` — `mix rindle.sweep_orphaned_temp_files` previews or deletes orphaned
  AV temp run directories under `Rindle.tmp/`.

Do not treat `regenerate` as a single-asset repair surrogate, and do not
collapse `cleanup` plus `sweep` into one destructive umbrella command. They
have different targets, sequencing, safety defaults, and scheduling cadence.

## Choosing The Right Lane

Use this quick map before reaching for a task or API:

| Symptom | Supported verb | Surface |
| ------- | -------------- | ------- |
| Probe-derived fields drifted or were persisted before better detection shipped | `reprobe` | `Rindle.reprobe/1` |
| One asset has failed or cancelled variants that should run again | `requeue` | `Rindle.requeue_variants/2` |
| Many variants are `stale` after recipe drift, or `missing` after storage verification | `regenerate` | `mix rindle.regenerate_variants` |
| Timed-out direct upload residue is piling up | `cleanup` | `mix rindle.abort_incomplete_uploads` then `mix rindle.cleanup_orphans` |
| AV transcoding left abandoned temp run directories behind | `sweep` | `mix rindle.sweep_orphaned_temp_files` |

## Task Reference

### `mix rindle.cleanup_orphans`

Removes upload sessions in the `expired` state and the storage objects
they reference.

- **Module:** `Mix.Tasks.Rindle.CleanupOrphans`
- **Worker equivalent:** `Rindle.Workers.CleanupOrphans` (cron-schedulable)
- **Implementation note:** the Mix task and cron worker share the same internal cleanup service.
- **Defaults:** dry-run is the safe default. Pass `--no-dry-run` or
  `--live` to perform destructive deletions.

Run `mix rindle.abort_incomplete_uploads` first to mark timed-out sessions
as `expired`. Then `mix rindle.cleanup_orphans` removes them. This is the
supported `cleanup` lane; do not delete upload-session rows manually when this
workflow applies.

### `Rindle.reprobe/1`

Refreshes probe-derived fields for one asset.

- **Verb:** `reprobe`
- **Scope:** asset-scoped only
- **Mutates:** probe-owned fields such as MIME/kind/dimensions/duration/track
  booleans
- **Does not mutate:** asset lifecycle state, variants, upload sessions,
  metadata backfill, or broad regeneration state

Use this when the source object is still authoritative but probe-derived fields
need to be refreshed without changing the rest of the lifecycle record.

### `Rindle.requeue_variants/2`

Re-enqueues failed or cancelled variants for one asset.

- **Verb:** `requeue`
- **Scope:** asset-scoped only
- **Targeting:** defaults to all failed/cancelled variants on the asset; pass
  `variant_names: [...]` to narrow explicitly
- **Boundary:** this is enqueue-only repair. It does not synchronously process
  variants and it does not pull `ready`, `queued`, `processing`, `stale`, or
  `missing` siblings into the run.

Use this when a single asset needs repair after a transient failure,
intentional cancellation, or a corrected one-off issue.

This is also the canonical repair lane for one interrupted upgraded asset after
the pre-v1.4 to current migration path.

### `mix rindle.sweep_orphaned_temp_files`

Previews or deletes orphaned AV temp run directories under `Rindle.tmp/`.

- **Module:** `Mix.Tasks.Rindle.SweepOrphanedTempFiles`
- **Worker equivalent:** `Rindle.Ops.SweepOrphanedTempFiles` (cron-schedulable)
- **Implementation note:** the Mix task and scheduled worker reuse the same
  sweep service contract.
- **Defaults:** dry-run is the safe default. Pass `--no-dry-run` or `--live`
  to perform destructive deletions.

Use this when AV processing leaves behind abandoned temp run directories. This
is distinct from upload-session cleanup: temp sweeping targets local transient
processing residue, not staged upload objects or upload-session rows.

### `mix rindle.regenerate_variants`

Re-enqueues variants in `stale` or `missing` state so the variant pipeline
regenerates them. Optionally filter by profile or variant name.

- **Module:** `Mix.Tasks.Rindle.RegenerateVariants`
- **Execution model:** this task only enqueues internal variant-processing jobs;
  it does not process variants synchronously.
- **Targeting rules:** only `stale` and `missing` variants are eligible.
  `queued`, `processing`, `ready`, `failed`, and `cancelled` variants are not
  part of this broad maintenance lane.
- **Boundary:** use this for broad regeneration, not as a substitute for
  one-off single-asset repair work.

Use this after changing a variant spec — the recipe digest changes,
existing variants flip to `stale`, and this task re-enqueues them.

For upgrade work, keep `regenerate` in this broad lane. Do not replace a single
failed or cancelled upgraded asset with broad regeneration.

### `mix rindle.verify_storage`

Reconciles `MediaVariant` rows against storage by HEAD-checking each
variant's storage object. Variants whose object is gone flip to
`missing`; other errors are counted but do not mutate state.

- **Module:** `Mix.Tasks.Rindle.VerifyStorage`
- **Implementation note:** storage verification runs through an internal maintenance service.
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
- **Implementation note:** the Mix task and cron worker share the same internal expiry service.

Sessions already in terminal states (`completed`, `expired`, `aborted`,
`failed`) are not touched.

### `mix rindle.backfill_metadata`

Re-runs the configured analyzer for assets in `ready`, `available`, or
`degraded` states and persists updated metadata. The recovery path when
analyzer output changes (new fields added, bug fixes in analysis logic,
or assets that were promoted before analysis ran).

- **Module:** `Mix.Tasks.Rindle.BackfillMetadata`
- **Implementation note:** the Mix task fronts an internal metadata backfill service.
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
| `mix rindle.sweep_orphaned_temp_files` | On demand or scheduled dry-run/live | Reaps abandoned AV temp run directories |
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
       {"0 2 * * *", Rindle.Workers.CleanupOrphans, args: %{"dry_run" => false}},
       {"0 3 * * *", Rindle.Ops.SweepOrphanedTempFiles, args: %{"dry_run" => true}}
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

Phase 31 adds a narrow additive diagnostics family:

- `[:rindle, :repair, :start]`
- `[:rindle, :repair, :stop]`
- `[:rindle, :repair, :exception]`
- `[:rindle, :runtime, :refusal]`
- `[:rindle, :runtime, :check, :stop]`

These events keep metadata low-cardinality. Repair metadata is limited to
`operation`, `scope`, `result`, and `dry_run`. Runtime refusal metadata is
limited to `surface`, `reason`, and `mode`. Runtime check metadata is limited
to `check`, `status`, and `component`.

## Release Publishing

Maintainer-only first-publish steps live in
[`guides/release_publish.md`](release_publish.html). Keep release
versioning, Hex owner/auth checks, and package-metadata review there so
adopter onboarding docs stay focused on installation and runtime use.

## Operational Tips

- **Always start in dry-run.** `mix rindle.cleanup_orphans` defaults to
  dry-run; `mix rindle.sweep_orphaned_temp_files` does too; the worker variants
  take `dry_run: true` by default. The first
  time you wire a new environment, run dry-run for a week and inspect the
  counts before enabling destructive mode.
- **Keep residue lanes separate.** Upload cleanup must follow
  `abort_incomplete_uploads`; temp sweeping has no upload-session sequencing
  requirement and should be scheduled independently.
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
- **`regenerate_variants` is broad maintenance only.** It is the right tool
  after profile drift or storage reconciliation, not for a one-off failed or
  cancelled variant on a single asset.
- **Prefer the verb map over manual row edits.** If the failure is a probe
  drift, failed/cancelled asset-scoped variant, broad stale/missing derivative
  drift, expired upload residue, or AV temp residue, use `reprobe`, `requeue`,
  `regenerate`, `cleanup`, or `sweep` respectively before considering manual
  intervention.
- **`backfill_metadata` can be expensive.** It downloads each asset's
  source bytes and re-runs the analyzer. For large catalogs, restrict
  by profile (`--profile`) and run during off-peak hours.

## When to Escalate

The Mix tasks handle routine maintenance. The following situations are
not what these tasks are for, and need direct database / storage
intervention:

- A `quarantined` asset that legitimately needs to be unquarantined
  (manual DB update; document the audit trail).
- A `failed` variant whose underlying source is corrupt — fix the source, then
  use `Rindle.requeue_variants/2` for that asset or `mix rindle.regenerate_variants`
  if the issue is broad preset/profile drift.
- A `degraded` asset where some variants succeeded and others failed
  permanently — decide whether to delete or leave degraded based on
  product policy.

See [Troubleshooting](troubleshooting.html) for recovery playbooks for
each of these states.
