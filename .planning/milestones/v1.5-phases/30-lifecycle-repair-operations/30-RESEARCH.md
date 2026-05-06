# Phase 30: Lifecycle Repair Operations - Research

**Researched:** 2026-05-05
**Domain:** Explicit lifecycle repair operations for asset-scoped recovery, batch maintenance, and operator-facing repair reporting in Rindle.
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Repair Surface Shape

- **D-01:** Use a hybrid public-surface model. Asset-scoped repair operations
  are first-class public `Rindle` facade APIs; batch/global maintenance remains
  Mix-task-first over hidden `Rindle.Ops.*` services.
- **D-02:** Do not make `Rindle.Ops.*` modules public. They remain internal
  implementation seams behind facade APIs, workers, and Mix tasks.
- **D-03:** Preserve the existing public-boundary rule from Phase 27:
  asset-targeted lifecycle control is asset-scoped, not variant-id/job-id
  public API design.
- **D-04:** Keep batch maintenance command-shaped and explicit. Profile-wide or
  catalog-wide repair/regeneration should stay in `mix rindle.*` surfaces, not
  on the `Rindle` facade.

### Re-Probe Semantics

- **D-05:** `re-probe` means refresh probe-derived asset fields only. It is not
  a metadata backfill, variant regeneration, or state-repair umbrella.
- **D-06:** Re-probe may update only probe-derived asset fields such as
  `content_type`, `kind`, `width`, `height`, `duration_ms`,
  `has_video_track`, `has_audio_track`, and `updated_at`.
- **D-07:** Re-probe must explicitly clear probe fields that are no longer
  applicable after detection, rather than silently leaving stale values behind.
- **D-08:** Re-probe must not change unrelated lifecycle or ownership fields:
  asset state, error_reason, metadata, profile, storage_key, byte_size,
  filename, variants, upload sessions, or aggregate lifecycle state.
- **D-09:** If operators need analyzer-driven metadata refresh, that remains a
  separate operation through the existing metadata backfill lane. Do not hide
  metadata rewrites behind re-probe.

### Requeue and Regenerate Targeting

- **D-10:** Split targeted repair from broad regeneration. They are related but
  not the same surface.
- **D-11:** The public repair API is asset-scoped and may optionally accept an
  explicit list of variant names for narrower repair within that asset.
- **D-12:** Asset-scoped repair targets `failed` and `cancelled` variants only.
  Ready, queued, processing, stale, and missing siblings are not implicitly
  pulled into the repair lane.
- **D-13:** Unknown variant names in targeted repair are loud errors, not
  silent skips. Empty/no-op selections should produce deterministic report data.
- **D-14:** Targeted repair remains enqueue-only. It creates or re-creates the
  appropriate variant-processing jobs; it does not process variants
  synchronously in the caller.
- **D-15:** Repairing one failed/cancelled derivative must not invalidate,
  purge, or requeue already-ready siblings.
- **D-16:** Broad regeneration after preset/profile changes stays in the
  maintenance lane via `mix rindle.regenerate_variants`, with profile-wide
  targeting and optional variant-name narrowing.
- **D-17:** Do not expand the public `Rindle` facade into a generic filter DSL
  for profile-wide or fleet-wide regeneration.

### Sweep Scope and Scheduling

- **D-18:** Keep sweep surfaces focused by residue type. Do not introduce a
  destructive umbrella "repair sweep" command in Phase 30.
- **D-19:** Treat AV temp-run-dir orphan sweeping as its own explicit
  maintenance surface with on-demand + scheduled parity.
- **D-20:** Scheduled maintenance should reuse the same service contract as the
  on-demand lane. Mix task, direct function, and Oban worker behavior must stay
  aligned.
- **D-21:** Dry-run is the safe default for destructive sweep operations
  everywhere. Scheduled live deletion must require explicit opt-in.
- **D-22:** Upload residue cleanup remains a distinct maintenance lane with its
  existing abort-before-cleanup sequencing; Phase 30 should compose existing
  maintenance surfaces rather than collapsing them.
- **D-23:** If a future umbrella task exists at all, it must be preview-first
  and dispatch only explicitly selected focused sweeps. It is not a Phase 30
  default.

### Audit and Failure Output

- **D-24:** Public repair APIs should return structured `{:ok, report}` results
  for completed runs, even when partial failures occurred. Reserve
  `{:error, reason}` for run-level failure that prevented a meaningful report.
- **D-25:** Repair reports should include deterministic counters plus typed
  failure entries with stable reason atoms, human-readable messages, and
  low-cardinality failure classes.
- **D-26:** Mix tasks remain human-friendly and deterministic: summary counters
  first, bounded tagged failure lines after the summary only when needed.
- **D-27:** Per-item repair failures must also emit structured log events with
  stable event names and metadata keys. Logs are a breadcrumb surface, not the
  only contract.
- **D-28:** Add run-level repair telemetry as additive instrumentation. Keep
  telemetry low-cardinality and do not use it as the sole operator-facing
  failure surface.
- **D-29:** Do not add persisted repair audit rows/history tables in Phase 30.
  Revisit only if a later phase adds admin/history/compliance requirements.

### Naming and Contract Hygiene

- **D-30:** Keep repair naming explicit and unsurprising: `reprobe`, `requeue`,
  `regenerate`, `cleanup`, and `sweep` each keep their own scope. Do not blur
  these into one overloaded verb.
- **D-31:** Phase 30 should resolve the current public-contract mismatch where
  user-facing messaging refers to `Rindle.regenerate_variant/2` even though no
  such public function exists yet.

### Decision-Making Preference

- **D-32:** Carry forward the standing project preference now recorded in
  `.planning/STATE.md`: front-load research, prefer coherent one-shot
  recommendations, decide by default, and escalate only for very impactful
  decisions such as semver-significant public reshapes, destructive
  irreversibility, or security/compliance boundaries.

### Claude's Discretion

- Exact function names/arity for the new asset-scoped repair facade, so long as
  the boundary and targeting rules above remain intact
- Exact report struct/map shapes, provided counters, typed failures, and stable
  reason/message semantics are preserved
- Exact worker/task split for AV temp sweeping, so long as dry-run defaults and
  on-demand/scheduled parity are preserved
- Exact telemetry event names and metadata keys, provided they remain stable,
  low-cardinality, and additive

### Deferred Ideas (OUT OF SCOPE)

- Admin UI for repair history, dashboards, or one-click remediation
- Persisted repair audit tables/history records
- Generic `Rindle.repair(filters)` or similar broad public filter DSL
- Destructive umbrella cleanup commands that mix unrelated residue types by
  default
- Broader runtime diagnostics/reporting beyond the explicit repair surfaces in
  Phase 30
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REPAIR-01 | Operator can re-probe an asset and persist refreshed probe fields without mutating unrelated lifecycle state. | Existing probe download/dispatch/write logic lives in `Rindle.Workers.PromoteAsset`; Phase 30 should extract or reuse that logic behind a new asset-scoped public repair facade instead of reimplementing probe rules. [VERIFIED: lib/rindle/workers/promote_asset.ex, test/rindle/workers/promote_asset_test.exs] |
| REPAIR-02 | Operator can requeue failed or cancelled variants for a specific asset through an idempotent public repair surface. | Existing asset-scoped public control already exists via `Rindle.cancel_processing/1`, while idempotent queue insertion already exists via Oban uniqueness in `VariantMaintenance`; Phase 30 should combine those patterns for failed/cancelled repair only. [VERIFIED: lib/rindle.ex, lib/rindle/workers/process_variant.ex, lib/rindle/ops/variant_maintenance.ex, test/rindle/ops/variant_maintenance_test.exs, test/rindle/workers/process_variant_test.exs] [CITED: https://hexdocs.pm/oban/2.18.3/Oban.html] |
| REPAIR-03 | Operator can regenerate a variant set after preset or profile changes through an auditable, explicit operation. | The batch regeneration lane already exists as `mix rindle.regenerate_variants` over `Rindle.Ops.VariantMaintenance`; Phase 30 should preserve that maintenance-first boundary and tighten the operator contract rather than inventing a broad facade API. [VERIFIED: lib/mix/tasks/rindle.regenerate_variants.ex, lib/rindle/ops/variant_maintenance.ex, guides/operations.md] |
| REPAIR-04 | Operator can sweep orphaned temp files, stale lifecycle rows, and other repairable residue on demand as well as through scheduled maintenance. | Upload cleanup already has Mix-task and worker parity, while AV temp sweeping already has a service and worker but no explicit on-demand Mix task; Phase 30 should close that parity gap without collapsing residue types into one destructive command. [VERIFIED: lib/rindle/ops/upload_maintenance.ex, lib/mix/tasks/rindle.cleanup_orphans.ex, lib/rindle/workers/cleanup_orphans.ex, lib/rindle/ops/sweep_orphaned_temp_files.ex, test/rindle/workers/maintenance_workers_test.exs, test/rindle/ops/sweep_orphaned_temp_files_test.exs] |
| REPAIR-05 | Repair operations emit tagged, operator-readable failure reasons and do not silently hide partial failure. | Existing maintenance lanes already use deterministic counters, per-item logging, and partial-failure reports; Phase 30 should standardize that posture across the new repair APIs and any new Mix task surfaces. [VERIFIED: lib/rindle/ops/variant_maintenance.ex, lib/rindle/ops/metadata_backfill.ex, lib/rindle/ops/upload_maintenance.ex, lib/mix/tasks/rindle.verify_storage.ex, lib/mix/tasks/rindle.cleanup_orphans.ex] [CITED: https://hexdocs.pm/oban/Oban.Telemetry.html] |
</phase_requirements>

## Summary

Rindle already has the internal mechanics for most of Phase 30, but they are split across hidden `Rindle.Ops.*` services, Mix tasks, and workers rather than exposed as one coherent repair contract. The public facade currently exposes asset-scoped cancellation through `Rindle.cancel_processing/1`, compiled-doc boundary tests keep `Rindle.Ops.*` hidden, and the maintenance lanes already cover regeneration, storage verification, metadata backfill, upload cleanup, and AV temp sweeping. [VERIFIED: lib/rindle.ex, test/rindle/api_surface_boundary_test.exs, lib/rindle/ops/variant_maintenance.ex, lib/rindle/ops/metadata_backfill.ex, lib/rindle/ops/upload_maintenance.ex, lib/rindle/ops/sweep_orphaned_temp_files.ex]

The implementation opportunity is therefore not “build a repair system from scratch.” It is to standardize the repair boundary: asset-scoped public repair on `Rindle`, broad catalog maintenance through `mix rindle.*`, and internal orchestration kept in hidden services. The highest-risk seam is re-probe, because the only existing probe/persist logic is embedded in `Rindle.Workers.PromoteAsset` and currently couples probe refresh with lifecycle advancement to `available` or quarantine on failure. [VERIFIED: lib/rindle/workers/promote_asset.ex, test/rindle/workers/promote_asset_test.exs]

The second high-risk seam is targeted requeue for failed or cancelled variants. Current bulk regeneration only targets `stale` and `missing`, while the public operator story and even `Rindle.Error.message/1` already imply a variant repair surface that does not exist yet. That mismatch should be resolved deliberately in Phase 30, with idempotency implemented through Oban uniqueness and failure reporting returned as structured reports plus tagged logs and additive telemetry. [VERIFIED: lib/rindle/ops/variant_maintenance.ex, lib/rindle/error.ex, test/rindle/error_test.exs] [CITED: https://hexdocs.pm/oban/2.18.3/Oban.html] [CITED: https://hexdocs.pm/oban/Oban.Telemetry.html]

**Primary recommendation:** add two public asset-scoped repair APIs on `Rindle` for reprobe and targeted failed/cancelled requeue, keep regeneration and residue cleanup Mix-task-first, and split Phase 30 into four plans so public-boundary work, idempotent requeueing, sweep parity, and operator reporting/docs can be verified independently. [VERIFIED: lib/rindle.ex, lib/mix/tasks/rindle.regenerate_variants.ex, lib/mix/tasks/rindle.cleanup_orphans.ex, test/rindle/api_surface_boundary_test.exs]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Asset-scoped reprobe API | API / Backend | Database / Storage | The call should execute as a library API on `Rindle`, download the source object, rerun probe logic, and persist only probe-derived fields. [VERIFIED: lib/rindle.ex, lib/rindle/workers/promote_asset.ex] |
| Targeted failed/cancelled variant requeue | API / Backend | Database / Storage | The public surface should validate asset scope and variant-name selection, while job insertion and variant state transitions remain database-backed and Oban-backed. [VERIFIED: lib/rindle.ex, lib/rindle/workers/process_variant.ex, lib/rindle/ops/variant_maintenance.ex] [CITED: https://hexdocs.pm/oban/2.18.3/Oban.html] |
| Broad regeneration after profile drift | API / Backend | Database / Storage | This is already a Mix-task-first maintenance operation that queries lifecycle rows and enqueues work; Phase 30 should preserve that ownership model. [VERIFIED: lib/mix/tasks/rindle.regenerate_variants.ex, lib/rindle/ops/variant_maintenance.ex] |
| Residue sweeping and scheduled maintenance | API / Backend | Database / Storage | Cleanup workers and tasks orchestrate deletion policy, while actual residue lives in storage objects, temp dirs, and lifecycle rows. [VERIFIED: lib/rindle/ops/upload_maintenance.ex, lib/rindle/ops/sweep_orphaned_temp_files.ex, lib/rindle/workers/cleanup_orphans.ex] |
| Operator reporting, logs, and telemetry | API / Backend | — | Reports, log events, and telemetry all originate in library code and workers rather than in a separate UI or service tier. [VERIFIED: lib/mix/tasks/rindle.verify_storage.ex, lib/rindle/ops/upload_maintenance.ex, lib/rindle/ops/sweep_orphaned_temp_files.ex] [CITED: https://hexdocs.pm/oban/Oban.Telemetry.html] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir | 1.19.5 | Core implementation/runtime for the repair surface. | The local workspace and existing code paths already run on Elixir 1.19.5, and Phase 30 is strictly inside the existing Elixir library boundary. [VERIFIED: local toolchain, mix.exs] |
| Ecto SQL | 3.13.5 | Querying and persisting asset, variant, and upload-session repair state. | All existing repair seams and lifecycle mutations already use Ecto queries, changesets, and transactions. [VERIFIED: mix.lock, lib/rindle.ex, lib/rindle/ops/*.ex] |
| Oban | 2.21.1 | Background job insertion, cancellation, cron scheduling, and uniqueness-backed idempotency. | The current lifecycle already depends on Oban workers for variant processing and maintenance scheduling, and Oban’s unique-job conflict contract matches the required idempotent requeue behavior. [VERIFIED: mix.lock, lib/rindle/workers/process_variant.ex, test/rindle/ops/variant_maintenance_test.exs] [CITED: https://hexdocs.pm/oban/2.18.3/Oban.html] |
| Telemetry | 1.4.1 | Additive repair and maintenance instrumentation. | Existing cleanup and sweep paths already emit Telemetry events, and Phase 30 needs additive run-level instrumentation rather than a new observability stack. [VERIFIED: mix.lock, lib/rindle/ops/sweep_orphaned_temp_files.ex, test/rindle/workers/maintenance_workers_test.exs] [CITED: https://hexdocs.pm/oban/Oban.Telemetry.html] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Postgrex | 0.22.0 | Postgres adapter for Ecto-backed lifecycle rows and Oban job storage. | Needed for verification and any repair test that exercises real Oban uniqueness or lifecycle-row mutation. [VERIFIED: mix.lock, test/rindle/ops/variant_maintenance_test.exs] |
| FFmpeg / FFprobe | 8.0.1 | Runtime capability for AV probe refresh and AV-derived repair flows. | Required when `reprobe` or regeneration touches video/audio assets. Image-only repair flows do not need it. [VERIFIED: local toolchain, lib/rindle/workers/promote_asset.ex, test/rindle/workers/promote_asset_test.exs] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Public `Rindle` facade for asset-scoped repair | Public `Rindle.Ops.*` modules | Rejected because boundary tests and prior phase decisions keep ops modules hidden and public lifecycle control asset-scoped. [VERIFIED: test/rindle/api_surface_boundary_test.exs, .planning/phases/30-lifecycle-repair-operations/30-CONTEXT.md] |
| Mix-task-first broad maintenance | Generic `Rindle.repair(filters)` facade | Rejected because it would blur asset-scoped API guarantees with catalog-wide destructive maintenance. [VERIFIED: .planning/phases/30-lifecycle-repair-operations/30-CONTEXT.md, guides/operations.md] |
| Structured reports + logs + telemetry | Logs-only or telemetry-only repair feedback | Rejected because existing maintenance lanes already depend on deterministic counts and per-item logging, and Phase 30 explicitly forbids telemetry as the sole operator-facing contract. [VERIFIED: lib/mix/tasks/rindle.verify_storage.ex, lib/rindle/ops/metadata_backfill.ex, .planning/phases/30-lifecycle-repair-operations/30-CONTEXT.md] |

**Installation:** No new dependency is recommended for Phase 30; use the repo-locked stack already present in `mix.exs` and `mix.lock`. [VERIFIED: mix.exs, mix.lock]

## Project Constraints (from CLAUDE.md)

No project-local `CLAUDE.md` exists in the workspace root, so there are no additional project-specific directives beyond the planning artifacts and locked phase context. [VERIFIED: workspace root file check]

## Architecture Patterns

### System Architecture Diagram

```text
Operator call / mix task
        |
        v
Public facade (`Rindle`) or Mix task wrapper
        |
        +--> validate scope / options / variant names
        |
        v
Hidden repair service (`Rindle.Ops.*`)
        |
        +--> read lifecycle rows via Ecto
        +--> optionally download source object / inspect temp dirs / HEAD storage
        +--> enforce FSM + idempotency + dry-run rules
        |
        +--> enqueue Oban jobs when repair is asynchronous
        |
        v
Persist report + emit logs + emit telemetry
        |
        v
Operator-readable summary / structured result
```

The current system already follows this shape for cleanup, verification, and regeneration; Phase 30 should extend the same pattern rather than introduce a second operational style. [VERIFIED: lib/mix/tasks/rindle.cleanup_orphans.ex, lib/mix/tasks/rindle.verify_storage.ex, lib/mix/tasks/rindle.regenerate_variants.ex]

### Recommended Project Structure

```text
lib/
├── rindle.ex                         # public asset-scoped repair facade additions
├── rindle/ops/                       # hidden repair orchestration and shared report helpers
├── rindle/workers/                   # scheduled/on-demand worker parity
└── mix/tasks/                        # batch/global maintenance entrypoints

test/rindle/
├── api_surface_boundary_test.exs     # public/internal contract lock
├── ops/                              # report and service semantics
└── workers/                          # scheduling, telemetry, and repair execution behavior
```

### Pattern 1: Public Asset-Scoped Repair Over Hidden Ops Service

**What:** Add public `Rindle` entrypoints for asset-scoped repair only, while the orchestration stays in hidden modules. [VERIFIED: lib/rindle.ex, test/rindle/api_surface_boundary_test.exs]

**When to use:** For reprobe and targeted failed/cancelled requeue, where callers should not need variant ids, job ids, or direct `Rindle.Ops.*` access. [VERIFIED: lib/rindle.ex, .planning/phases/30-lifecycle-repair-operations/30-CONTEXT.md]

**Example:**

```elixir
# Source: lib/rindle.ex, lib/rindle/workers/process_variant.ex
@spec cancel_processing(MediaAsset.t() | binary()) :: :ok | {:error, :not_processing}
def cancel_processing(asset_or_id) do
  asset_or_id
  |> get_asset_id()
  |> Rindle.Workers.ProcessVariant.cancel_processing()
end
```

### Pattern 2: Enqueue-Only Repair With Oban Uniqueness

**What:** Treat targeted repair and broad regeneration as enqueue-only operations, then use `%Oban.Job{conflict?: true}` to classify no-op duplicate requests as skipped instead of errors. [VERIFIED: lib/rindle/ops/variant_maintenance.ex, test/rindle/ops/variant_maintenance_test.exs] [CITED: https://hexdocs.pm/oban/2.18.3/Oban.html]

**When to use:** For failed/cancelled requeue and stale/missing regeneration where duplicate inserts must not produce duplicate work. [VERIFIED: lib/rindle/ops/variant_maintenance.ex, test/rindle/ops/variant_maintenance_test.exs]

**Example:**

```elixir
# Source: lib/rindle/ops/variant_maintenance.ex
case enqueue_job(asset_id, variant_name) do
  {:ok, %Oban.Job{conflict?: true}} -> {enq, skip + 1, err}
  {:ok, _job} -> {enq + 1, skip, err}
  {:error, _reason} -> {enq, skip, err + 1}
end
```

### Pattern 3: Focused Sweep Lanes With Dry-Run-First Destructive Semantics

**What:** Keep upload residue cleanup and AV temp sweeps as separate maintenance surfaces, each with an auditable report and explicit dry-run/live behavior. [VERIFIED: lib/rindle/ops/upload_maintenance.ex, lib/rindle/ops/sweep_orphaned_temp_files.ex, lib/mix/tasks/rindle.cleanup_orphans.ex]

**When to use:** For periodic maintenance, scheduled cron jobs, and one-off operator remediation where residue types have different safety and cadence profiles. [VERIFIED: guides/operations.md, lib/rindle/workers/cleanup_orphans.ex, lib/rindle/ops/sweep_orphaned_temp_files.ex]

**Example:**

```elixir
# Source: lib/rindle/ops/upload_maintenance.ex
cond do
  dry_run? -> base_report
  is_nil(storage_mod) and sessions != [] -> %{base_report | storage_skipped: length(sessions)}
  true -> Enum.reduce(sessions, base_report, &delete_session_and_object(&1, &2, storage_mod))
end
```

### Anti-Patterns to Avoid

- **Reusing `PromoteAsset.promote/2` for reprobe:** it advances lifecycle state to `available` and quarantines probe failures, which violates the locked “probe fields only” boundary for REPAIR-01. [VERIFIED: lib/rindle/workers/promote_asset.ex]
- **Broadening `VariantMaintenance.regenerate_variants/1` to include failed/cancelled without a separate asset-scoped facade:** it would blur targeted repair and broad regeneration, and it would silently widen existing Mix-task semantics. [VERIFIED: lib/rindle/ops/variant_maintenance.ex, .planning/phases/30-lifecycle-repair-operations/30-CONTEXT.md]
- **Introducing a single destructive “repair sweep everything” task:** current residue lanes have different sequencing and default-safety requirements. [VERIFIED: lib/rindle/ops/upload_maintenance.ex, lib/rindle/ops/sweep_orphaned_temp_files.ex, .planning/phases/30-lifecycle-repair-operations/30-CONTEXT.md]

## REPAIR-01..REPAIR-05 Mapping

| Requirement | Code Seams | What Exists Today | Primary Risk To Encode |
|-------------|------------|-------------------|------------------------|
| REPAIR-01 | `lib/rindle.ex`, `lib/rindle/workers/promote_asset.ex`, `test/rindle/workers/promote_asset_test.exs`, `lib/rindle/ops/metadata_backfill.ex` | Probe dispatch, probe-field normalization, and persistence already exist inside `PromoteAsset`; metadata refresh is already separate. [VERIFIED: lib/rindle/workers/promote_asset.ex, lib/rindle/ops/metadata_backfill.ex] | Extract probe logic without reusing lifecycle transitions or quarantine behavior; explicitly clear obsolete probe fields while leaving asset state, metadata, variants, and ownership untouched. [VERIFIED: lib/rindle/workers/promote_asset.ex, .planning/phases/30-lifecycle-repair-operations/30-CONTEXT.md] |
| REPAIR-02 | `lib/rindle.ex`, `lib/rindle/workers/process_variant.ex`, `lib/rindle/ops/variant_maintenance.ex`, `test/rindle/workers/process_variant_test.exs`, `test/rindle/ops/variant_maintenance_test.exs` | Asset-scoped public control and uniqueness-backed enqueue are both present, but not combined for failed/cancelled repair. [VERIFIED: lib/rindle.ex, lib/rindle/workers/process_variant.ex, lib/rindle/ops/variant_maintenance.ex] | Unknown variant names must error loudly, ready siblings must remain untouched, and duplicate repair requests must report skipped/conflict rather than enqueue duplicates. [VERIFIED: test/rindle/ops/variant_maintenance_test.exs, .planning/phases/30-lifecycle-repair-operations/30-CONTEXT.md] [CITED: https://hexdocs.pm/oban/2.18.3/Oban.html] |
| REPAIR-03 | `lib/rindle/ops/variant_maintenance.ex`, `lib/mix/tasks/rindle.regenerate_variants.ex`, `guides/operations.md`, `guides/troubleshooting.md` | Batch regeneration already exists for `stale` and `missing`, with deterministic summary output. [VERIFIED: lib/rindle/ops/variant_maintenance.ex, lib/mix/tasks/rindle.regenerate_variants.ex, guides/operations.md] | Preserve the maintenance-lane boundary while resolving the misleading `Rindle.regenerate_variant/2` messaging already shipped in `Rindle.Error`. [VERIFIED: lib/rindle/error.ex, test/rindle/error_test.exs] |
| REPAIR-04 | `lib/rindle/ops/upload_maintenance.ex`, `lib/mix/tasks/rindle.cleanup_orphans.ex`, `lib/rindle/workers/cleanup_orphans.ex`, `lib/rindle/ops/sweep_orphaned_temp_files.ex`, `test/rindle/workers/maintenance_workers_test.exs`, `test/rindle/ops/sweep_orphaned_temp_files_test.exs` | Upload cleanup already has on-demand and scheduled parity with dry-run defaults; AV temp sweep already has service + worker + telemetry, but no operator-facing Mix task and worker defaults to live deletion. [VERIFIED: lib/mix/tasks/rindle.cleanup_orphans.ex, lib/rindle/workers/cleanup_orphans.ex, lib/rindle/ops/sweep_orphaned_temp_files.ex, test/rindle/ops/sweep_orphaned_temp_files_test.exs] | Normalize on-demand/scheduled parity for temp sweeps and make dry-run the default everywhere without breaking existing cleanup sequencing. [VERIFIED: lib/rindle/ops/upload_maintenance.ex, lib/rindle/ops/sweep_orphaned_temp_files.ex, .planning/phases/30-lifecycle-repair-operations/30-CONTEXT.md] |
| REPAIR-05 | `lib/rindle/ops/variant_maintenance.ex`, `lib/rindle/ops/metadata_backfill.ex`, `lib/rindle/ops/upload_maintenance.ex`, `lib/mix/tasks/rindle.verify_storage.ex`, `lib/rindle/ops/sweep_orphaned_temp_files.ex` | Deterministic counters, per-item logging, and some telemetry already exist, but report shapes differ and the new public repair APIs do not exist yet. [VERIFIED: lib/rindle/ops/variant_maintenance.ex, lib/rindle/ops/metadata_backfill.ex, lib/rindle/ops/upload_maintenance.ex, lib/rindle/ops/sweep_orphaned_temp_files.ex] | Standardize stable reason atoms/messages and bounded output across API, Mix, logs, and telemetry so partial failures are visible without creating a new audit table. [VERIFIED: .planning/phases/30-lifecycle-repair-operations/30-CONTEXT.md] [CITED: https://hexdocs.pm/oban/Oban.Telemetry.html] |

## Recommended Plan Split

| Plan | Scope | Why This Boundary | Verification Commands |
|------|-------|-------------------|-----------------------|
| `30-01-PLAN.md` | Add public asset-scoped reprobe API plus hidden probe-refresh service, with strict field-refresh boundaries and boundary-test coverage. | REPAIR-01 is the riskiest semantic change because current probe logic is entangled with promotion/quarantine. Isolating it first keeps state-mutation regressions small. [VERIFIED: lib/rindle/workers/promote_asset.ex, test/rindle/workers/promote_asset_test.exs] | `mix test test/rindle/api_surface_boundary_test.exs test/rindle/workers/promote_asset_test.exs` |
| `30-02-PLAN.md` | Add public targeted failed/cancelled requeue API with variant-name targeting, idempotent enqueue semantics, and typed repair reports. | REPAIR-02 and the `Rindle.regenerate_variant/2` messaging mismatch are the main public-contract changes and need isolated API, error-message, and worker tests. [VERIFIED: lib/rindle/error.ex, test/rindle/error_test.exs, test/rindle/workers/process_variant_test.exs] | `mix test test/rindle/api_surface_boundary_test.exs test/rindle/workers/process_variant_test.exs test/rindle/ops/variant_maintenance_test.exs test/rindle/error_test.exs` |
| `30-03-PLAN.md` | Preserve and tighten batch/global maintenance: explicit regeneration contract, AV temp sweep on-demand parity, and dry-run-default destructive sweep behavior. | REPAIR-03 and REPAIR-04 should stay Mix-task-first and residue-specific; this plan isolates maintenance posture from facade API work. [VERIFIED: lib/mix/tasks/rindle.regenerate_variants.ex, lib/rindle/ops/sweep_orphaned_temp_files.ex, lib/mix/tasks/rindle.cleanup_orphans.ex] | `mix test test/rindle/ops/sweep_orphaned_temp_files_test.exs test/rindle/ops/upload_maintenance_test.exs test/rindle/workers/maintenance_workers_test.exs test/rindle/ops/variant_maintenance_test.exs` |
| `30-04-PLAN.md` | Unify operator-facing reporting, logging, telemetry, and docs/troubleshooting guidance across all repair surfaces. | REPAIR-05 crosses every surface and should land after the repair APIs and sweep contracts are real, otherwise docs and telemetry will freeze around guesswork. [VERIFIED: guides/operations.md, guides/troubleshooting.md, lib/rindle/ops/*.ex] [CITED: https://hexdocs.pm/oban/Oban.Telemetry.html] | `mix test test/rindle/contracts/telemetry_contract_test.exs test/rindle/error_test.exs` and `mix test test/rindle/api_surface_boundary_test.exs` |

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Idempotent requeue deduplication | Custom repair-lock table or ad hoc “SELECT then INSERT” mutex | Oban unique jobs plus `%Oban.Job{conflict?: true}` handling | Oban already guarantees transactional uniqueness and exposes a conflict contract that matches repair skip semantics. [VERIFIED: test/rindle/ops/variant_maintenance_test.exs] [CITED: https://hexdocs.pm/oban/2.18.3/Oban.html] |
| Probe refresh implementation | Second probe pipeline unrelated to promotion | Extract/reuse the `dispatch_probe` + `write_probe_result` path from `PromoteAsset` | A second implementation would drift on MIME dispatch, AV/image normalization, and stale-field clearing semantics. [VERIFIED: lib/rindle/workers/promote_asset.ex, test/rindle/workers/promote_asset_test.exs] |
| Sweep orchestration | One catch-all “repair all residue” runner | Focused cleanup/sweep services with dedicated reports | Existing residue types already have different sequencing, safety defaults, and scheduling cadences. [VERIFIED: lib/rindle/ops/upload_maintenance.ex, lib/rindle/ops/sweep_orphaned_temp_files.ex, guides/operations.md] |

**Key insight:** the repo already has the durable primitives; the planner should compose and standardize them instead of inventing new persistence or scheduling infrastructure. [VERIFIED: lib/rindle/ops/*.ex, lib/mix/tasks/rindle.*.ex]

## Common Pitfalls

### Pitfall 1: Reprobe Accidentally Changes Lifecycle State

**What goes wrong:** Reusing `PromoteAsset.promote/2` or `advance_to_promoting/2` for reprobe will move assets toward `available` or `quarantined`, violating the “probe-derived fields only” contract. [VERIFIED: lib/rindle/workers/promote_asset.ex]

**Why it happens:** The current probe logic is embedded in promotion rather than in a standalone repair service. [VERIFIED: lib/rindle/workers/promote_asset.ex]

**How to avoid:** Extract or wrap only the download, MIME dispatch, probe, normalization, and field-persist steps; do not call promotion state transitions from reprobe. [VERIFIED: lib/rindle/workers/promote_asset.ex, .planning/phases/30-lifecycle-repair-operations/30-CONTEXT.md]

**Warning signs:** Asset `state` or `error_reason` changes during a reprobe test, or reprobe failures produce quarantine outcomes. [VERIFIED: test/rindle/workers/promote_asset_test.exs]

### Pitfall 2: Targeted Repair Broadens Into Catalog-Wide Regeneration

**What goes wrong:** A single API ends up reusing the batch regeneration query path and starts touching stale/missing/ready variants outside the failed/cancelled asset scope. [VERIFIED: lib/rindle/ops/variant_maintenance.ex, .planning/phases/30-lifecycle-repair-operations/30-CONTEXT.md]

**Why it happens:** Existing regeneration already exists and is tempting to widen rather than separate. [VERIFIED: lib/rindle/ops/variant_maintenance.ex]

**How to avoid:** Keep targeted repair on a new asset-scoped surface and leave profile-wide regeneration on `mix rindle.regenerate_variants`. [VERIFIED: lib/mix/tasks/rindle.regenerate_variants.ex, .planning/phases/30-lifecycle-repair-operations/30-CONTEXT.md]

**Warning signs:** Public APIs accept profile filters, unknown variant names are silently ignored, or ready siblings are requeued during failed/cancelled repair. [VERIFIED: .planning/phases/30-lifecycle-repair-operations/30-CONTEXT.md]

### Pitfall 3: Destructive Sweep Parity Drifts Between On-Demand and Scheduled Paths

**What goes wrong:** Mix tasks, direct function calls, and workers default to different `dry_run` behavior or produce different counts, making scheduled maintenance harder to trust. [VERIFIED: lib/mix/tasks/rindle.cleanup_orphans.ex, lib/rindle/workers/cleanup_orphans.ex, lib/rindle/ops/sweep_orphaned_temp_files.ex]

**Why it happens:** Upload cleanup already enforces dry-run parity, while AV temp sweep currently only has service/worker entrypoints and the worker defaults to live deletion. [VERIFIED: lib/rindle/ops/upload_maintenance.ex, lib/rindle/ops/sweep_orphaned_temp_files.ex]

**How to avoid:** Introduce a single temp-sweep contract used by service, Mix task, and worker, with dry-run defaulted everywhere and explicit live opt-in. [VERIFIED: .planning/phases/30-lifecycle-repair-operations/30-CONTEXT.md]

**Warning signs:** Scheduled temp-sweep jobs delete files without a matching dry-run rehearsal path, or operator docs describe different defaults for task vs worker. [VERIFIED: lib/rindle/ops/sweep_orphaned_temp_files.ex, guides/operations.md]

## Code Examples

### Oban-Backed Idempotent Enqueue

```elixir
# Source: lib/rindle/ops/variant_maintenance.ex
%{"asset_id" => asset_id, "variant_name" => variant_name}
|> ProcessVariant.new(
  unique: [
    fields: [:args, :worker, :queue],
    keys: [:asset_id, :variant_name],
    states: [:available, :scheduled, :executing, :retryable],
    period: :infinity
  ]
)
|> Oban.insert()
```

This is the existing pattern Phase 30 should reuse for targeted requeue idempotency. [VERIFIED: lib/rindle/ops/variant_maintenance.ex, test/rindle/ops/variant_maintenance_test.exs] [CITED: https://hexdocs.pm/oban/2.18.3/Oban.html]

### Probe-Derived Field Normalization

```elixir
# Source: lib/rindle/workers/promote_asset.ex
defp normalize_probe_attrs_for_storage(%{kind: "audio"} = result) do
  Map.drop(result, [:width, :height, :has_video_track])
end
```

This is the current proof that reprobe must explicitly clear non-applicable probe fields rather than leave stale width/height/video flags behind. [VERIFIED: lib/rindle/workers/promote_asset.ex, test/rindle/workers/promote_asset_test.exs]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual row edits and ad hoc operator knowledge for some failed/cancelled states | Explicit public repair APIs plus deterministic Mix maintenance contracts | Phase 30 target, based on current gaps in guides and error messaging as of 2026-05-05. [VERIFIED: guides/troubleshooting.md, lib/rindle/error.ex] | Reduces unsupported “flip DB row and hope” recovery paths. |
| Logs-only breadcrumbs | Structured reports, bounded Mix output, and additive telemetry | Already partially present before Phase 30. [VERIFIED: lib/rindle/ops/metadata_backfill.ex, lib/mix/tasks/rindle.verify_storage.ex, lib/rindle/ops/sweep_orphaned_temp_files.ex] [CITED: https://hexdocs.pm/oban/Oban.Telemetry.html] | Makes cron, tests, and operators all consume the same repair outcomes. |
| Unscoped cleanup buckets | Focused residue-type maintenance lanes | Already present before Phase 30. [VERIFIED: lib/rindle/ops/upload_maintenance.ex, lib/rindle/ops/sweep_orphaned_temp_files.ex, guides/operations.md] | Keeps destructive operations auditable and schedulable by cadence. |

**Deprecated/outdated:**

- Manual guidance that tells operators to “flip the variant back to `queued`” or to rely on the nonexistent `Rindle.regenerate_variant/2` public API is now a contract liability and should be replaced in Phase 30. [VERIFIED: guides/operations.md, guides/troubleshooting.md, lib/rindle/error.ex, test/rindle/error_test.exs]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The final public names should be a small asset-scoped pair: `Rindle.reprobe/1` for probe refresh and `Rindle.requeue_variants/2` for targeted failed/cancelled requeue. [RESOLVED] | Open Questions | Medium — docs, error text, and boundary tests would freeze the wrong public API names. |
| A2 | New dedicated test files such as `test/rindle/repair_api_test.exs` or a dedicated repair-report contract test will probably be the cleanest Wave 0 additions, though equivalent coverage could also land in existing files. [ASSUMED] | Validation Architecture | Low — file naming can change without altering the underlying verification strategy. |

## Open Questions (RESOLVED)

1. **What exact public names should the two new asset-scoped repair APIs use?**
   - Decision: use `Rindle.reprobe/1` for probe-field refresh and `Rindle.requeue_variants/2` for targeted failed/cancelled variant repair. [RESOLVED]
   - Why: these names keep the verbs explicit, stay asset-scoped, and avoid implying a broad generic repair DSL. `reprobe/1` matches the locked naming guidance directly, while `requeue_variants/2` makes the enqueue-only behavior explicit and avoids overloading `repair`. [VERIFIED: .planning/phases/30-lifecycle-repair-operations/30-CONTEXT.md, test/rindle/api_surface_boundary_test.exs]
   - Consequence: boundary tests, `Rindle.Error` messaging, docs, and plan files should freeze these names immediately so the operator surface does not drift. [VERIFIED: .planning/phases/30-lifecycle-repair-operations/30-02-PLAN.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | All phase implementation and verification | ✓ | 1.19.5 | — |
| OTP | All phase implementation and verification | ✓ | 28 | — |
| PostgreSQL CLI | Local DB-backed test and verification flows | ✓ | 14.17 | — |
| FFmpeg | AV reprobe/regeneration tests and operator parity for AV assets | ✓ | 8.0.1 | Image-only repair work can still proceed without exercising AV fixtures. |
| FFprobe | AV probe refresh tests and operator parity for AV assets | ✓ | 8.0.1 | Same fallback as FFmpeg. |

Step 2.6 was not skipped because Phase 30 verification depends on the local Elixir/Postgres/FFmpeg toolchain even though no new external service is being introduced. [VERIFIED: local toolchain, test/rindle/workers/promote_asset_test.exs]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit via Mix test on Elixir 1.19.5. [VERIFIED: mix.exs, local toolchain] |
| Config file | none — Mix/ExUnit defaults via `mix.exs`. [VERIFIED: workspace file scan, mix.exs] |
| Quick run command | `mix test test/rindle/api_surface_boundary_test.exs test/rindle/ops/variant_maintenance_test.exs test/rindle/workers/process_variant_test.exs` [VERIFIED: local test run] |
| Full suite command | `mix test` [VERIFIED: mix.exs] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REPAIR-01 | Reprobe refreshes probe-derived fields only | unit/integration | `mix test test/rindle/workers/promote_asset_test.exs test/rindle/api_surface_boundary_test.exs` | ❌ Wave 0 for dedicated reprobe tests |
| REPAIR-02 | Failed/cancelled asset-scoped requeue is idempotent and narrow | unit/integration | `mix test test/rindle/workers/process_variant_test.exs test/rindle/ops/variant_maintenance_test.exs test/rindle/api_surface_boundary_test.exs` | ❌ Wave 0 for dedicated public repair API tests |
| REPAIR-03 | Broad regeneration remains explicit and auditable | unit | `mix test test/rindle/ops/variant_maintenance_test.exs test/rindle/error_test.exs` | ✅ plus doc/error-message extensions |
| REPAIR-04 | Upload cleanup and temp sweep support on-demand and scheduled parity | unit/integration | `mix test test/rindle/ops/upload_maintenance_test.exs test/rindle/ops/sweep_orphaned_temp_files_test.exs test/rindle/workers/maintenance_workers_test.exs` | ✅ plus new temp-sweep task tests |
| REPAIR-05 | Repair surfaces emit stable reports/logs/telemetry and visible partial failures | unit/contract | `mix test test/rindle/contracts/telemetry_contract_test.exs test/rindle/error_test.exs` | ❌ Wave 0 for dedicated repair-report contract tests |

### Sampling Rate

- **Per task commit:** run the plan-local command listed in the plan split table. [VERIFIED: recommended plan split above]
- **Per wave merge:** `mix test` for the touched repair, worker, and contract suites. [VERIFIED: mix.exs]
- **Phase gate:** full `mix test` green before `/gsd-verify-work`. [VERIFIED: planning workflow policy, mix.exs]

### Wave 0 Gaps

- [ ] `test/rindle/repair_api_test.exs` — public facade contract for reprobe and targeted failed/cancelled requeue. [ASSUMED]
- [ ] `test/rindle/ops/reprobe_test.exs` or equivalent — proves probe-field refresh and stale-field clearing without lifecycle-state mutation. [ASSUMED]
- [ ] `test/rindle/mix/tasks/sweep_orphaned_temp_files_test.exs` or equivalent — locks task/worker dry-run parity for AV temp sweep. [ASSUMED]
- [ ] `test/rindle/contracts/repair_report_contract_test.exs` or equivalent — freezes report keys, failure reason atoms, and bounded partial-failure output. [ASSUMED]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Host application owns authentication; Phase 30 adds no auth system. [VERIFIED: .planning/PROJECT.md] |
| V3 Session Management | no | Host application owns session policy; repair APIs are library functions and Mix tasks. [VERIFIED: .planning/PROJECT.md] |
| V4 Access Control | yes | Keep destructive/batch operations Mix-task-first and asset-scoped public APIs narrow so host applications can wrap them explicitly. [VERIFIED: .planning/phases/30-lifecycle-repair-operations/30-CONTEXT.md, test/rindle/api_surface_boundary_test.exs] |
| V5 Input Validation | yes | Reuse existing filter validation, explicit variant-name validation, and `String.to_existing_atom/1` module resolution discipline. [VERIFIED: lib/rindle/ops/variant_maintenance.ex, lib/mix/tasks/rindle.cleanup_orphans.ex, lib/mix/tasks/rindle.backfill_metadata.ex] |
| V6 Cryptography | no | Phase 30 introduces no new crypto boundary. [VERIFIED: phase scope] |

### Known Threat Patterns for Repair Ops

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Broad accidental mutation from typoed filters or unknown variant names | Tampering | Reject unknown filters and unknown variant names loudly instead of silently widening scope. [VERIFIED: lib/rindle/ops/variant_maintenance.ex, .planning/phases/30-lifecycle-repair-operations/30-CONTEXT.md] |
| Duplicate job insertion from repeated repair requests | Denial of service | Use Oban unique jobs and classify conflicts as skipped/no-op outcomes. [VERIFIED: test/rindle/ops/variant_maintenance_test.exs] [CITED: https://hexdocs.pm/oban/2.18.3/Oban.html] |
| Silent partial failure in cleanup or repair runs | Repudiation | Return structured reports, emit tagged logs, and add low-cardinality telemetry so operators can prove what happened. [VERIFIED: lib/rindle/ops/metadata_backfill.ex, lib/rindle/ops/upload_maintenance.ex, .planning/phases/30-lifecycle-repair-operations/30-CONTEXT.md] [CITED: https://hexdocs.pm/oban/Oban.Telemetry.html] |
| Unsafe module resolution from CLI/operator input | Elevation of privilege | Keep `String.to_existing_atom/1` and callback validation on module arguments; do not accept arbitrary atoms or shell execution. [VERIFIED: lib/mix/tasks/rindle.cleanup_orphans.ex, lib/mix/tasks/rindle.backfill_metadata.ex] |

## Sources

### Primary (HIGH confidence)

- Local codebase seam review:
  - `lib/rindle.ex`
  - `lib/rindle/workers/process_variant.ex`
  - `lib/rindle/workers/promote_asset.ex`
  - `lib/rindle/ops/variant_maintenance.ex`
  - `lib/rindle/ops/metadata_backfill.ex`
  - `lib/rindle/ops/upload_maintenance.ex`
  - `lib/rindle/ops/sweep_orphaned_temp_files.ex`
  - `lib/mix/tasks/rindle.regenerate_variants.ex`
  - `lib/mix/tasks/rindle.verify_storage.ex`
  - `lib/mix/tasks/rindle.backfill_metadata.ex`
  - `lib/mix/tasks/rindle.cleanup_orphans.ex`
  - `guides/operations.md`
  - `guides/troubleshooting.md`
  - `test/rindle/api_surface_boundary_test.exs`
  - `test/rindle/ops/variant_maintenance_test.exs`
  - `test/rindle/workers/process_variant_test.exs`
  - `test/rindle/workers/promote_asset_test.exs`
  - `test/rindle/ops/upload_maintenance_test.exs`
  - `test/rindle/ops/sweep_orphaned_temp_files_test.exs`
  - `test/rindle/workers/maintenance_workers_test.exs`
- Planning inputs:
  - `.planning/ROADMAP.md`
  - `.planning/REQUIREMENTS.md`
  - `.planning/PROJECT.md`
  - `.planning/STATE.md`
  - `.planning/research/v1.5-ADOPTER-HARDENING-MEMO.md`
  - `.planning/research/v1.4/FOOTGUNS.md`
  - `.planning/research/v1.4/LIFECYCLE.md`
  - `.planning/phases/25-rindle-processor-av/25-CONTEXT.md`
  - `.planning/phases/26-delivery-surface/26-CONTEXT.md`
  - `.planning/phases/27-html-helpers-liveview-integration/27-CONTEXT.md`
  - `.planning/phases/28-onboarding-docs-ci-proof/28-CONTEXT.md`
  - `.planning/phases/30-lifecycle-repair-operations/30-CONTEXT.md`
  - `.planning/phases/30-lifecycle-repair-operations/30-DISCUSSION-LOG.md`

### Secondary (MEDIUM confidence)

- Oban unique jobs official docs: https://hexdocs.pm/oban/2.18.3/Oban.html
- Oban telemetry official docs: https://hexdocs.pm/oban/Oban.Telemetry.html

### Tertiary (LOW confidence)

- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all recommended pieces already exist in the repo and local environment; no dependency expansion is proposed. [VERIFIED: mix.exs, mix.lock, local toolchain]
- Architecture: HIGH - the hidden ops/public facade/Mix-task split is directly evidenced by code seams, tests, and locked phase context. [VERIFIED: lib/rindle.ex, test/rindle/api_surface_boundary_test.exs, .planning/phases/30-lifecycle-repair-operations/30-CONTEXT.md]
- Pitfalls: HIGH - the main failure modes are already visible in current code coupling, docs mismatches, and maintenance-default inconsistencies. [VERIFIED: lib/rindle/workers/promote_asset.ex, lib/rindle/error.ex, lib/rindle/ops/sweep_orphaned_temp_files.ex, guides/troubleshooting.md]

**Research date:** 2026-05-05
**Valid until:** 2026-06-04
