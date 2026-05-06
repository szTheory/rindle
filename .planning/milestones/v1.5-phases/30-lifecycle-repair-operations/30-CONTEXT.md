# Phase 30: Lifecycle Repair Operations - Context

**Gathered:** 2026-05-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Operators get explicit, auditable repair operations for failed, cancelled, or
drifted lifecycle state in the media model Rindle already owns.

In scope:
- Re-probe an asset and persist refreshed probe-derived fields
- Requeue failed or cancelled variants for a specific asset through an
  idempotent public repair surface
- Regenerate derivative sets after preset/profile drift through explicit
  operator maintenance flows
- Sweep repairable residue such as AV temp-run-dir orphans through on-demand
  and scheduled maintenance surfaces
- Tagged, operator-readable failure output for repair operations

Out of scope:
- Admin UI or dashboard surfaces
- Generic `repair(filters)` or "fix everything" orchestration APIs
- Persisted repair audit tables/history models
- New runtime diagnostics beyond what Phase 31 will cover
- Broad cleanup/refactor work unrelated to explicit repair outcomes
</domain>

<decisions>
## Implementation Decisions

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

### the agent's Discretion

- Exact function names/arity for the new asset-scoped repair facade, so long as
  the boundary and targeting rules above remain intact
- Exact report struct/map shapes, provided counters, typed failures, and stable
  reason/message semantics are preserved
- Exact worker/task split for AV temp sweeping, so long as dry-run defaults and
  on-demand/scheduled parity are preserved
- Exact telemetry event names and metadata keys, provided they remain stable,
  low-cardinality, and additive
</decisions>

<specifics>
## Specific Ideas

- The least-surprise contract is:
  asset-scoped repair on `Rindle`, broad maintenance on `mix rindle.*`,
  internal mechanics in `Rindle.Ops.*`.
- Re-probe should feel like FFprobe/Image probe rerun semantics:
  discover and persist fresh probe facts, nothing more.
- Broad regeneration should remain clearly operator-shaped, similar to current
  `mix rindle.regenerate_variants`, rather than turning the facade into a
  maintenance query language.
- Favor the same DX posture as the current maintenance tasks:
  deterministic summaries, dry-run-first destructive lanes, and explicit
  operator intent.
- Successful patterns worth learning from:
  Active Storage/Shrine keeping focused maintenance actions separate from broad
  app APIs; Oban/Ecto exposing durable programmatic contracts with CLI wrappers
  rather than CLI-only behavior.
- Footguns to avoid:
  generic repair filters, hidden broad mutation behind "re-probe", logs-only
  failure visibility, telemetry-only operator feedback, and umbrella cleanup
  commands that mix different cadences and safety profiles.
</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Source of truth
- `.planning/ROADMAP.md` — Phase 30 goal, requirements, and success criteria
- `.planning/REQUIREMENTS.md` — REPAIR-01 through REPAIR-05
- `.planning/PROJECT.md` — v1.5 hardening scope, lifecycle philosophy, security invariants, and out-of-scope boundaries
- `.planning/STATE.md` — current milestone state and decision-making preference

### Milestone research
- `.planning/research/v1.5-ADOPTER-HARDENING-MEMO.md` — lifecycle-repair milestone rationale, naming guidance, and scope guardrails
- `.planning/research/v1.4/FOOTGUNS.md` — concurrency, drift, and repair footguns the ops surfaces must avoid
- `.planning/research/v1.4/LIFECYCLE.md` — variant lifecycle semantics and operator-query motivations Phase 30 must preserve

### Prior phase decisions this phase must honor
- `.planning/phases/25-rindle-processor-av/25-CONTEXT.md` — one-variant-per-job contract, partial-failure semantics, ready-sibling preservation, AV temp sweep posture
- `.planning/phases/26-delivery-surface/26-CONTEXT.md` — research-first decision-making preference carry-forward
- `.planning/phases/27-html-helpers-liveview-integration/27-CONTEXT.md` — asset-scoped public cancellation boundary and additive public API philosophy
- `.planning/phases/28-onboarding-docs-ci-proof/28-CONTEXT.md` — operations-doc posture and explicit task/documentation contract

### Existing code seams
- `lib/rindle.ex` — public facade boundary and existing `cancel_processing/1`
- `lib/rindle/workers/process_variant.ex` — current cancellation semantics, variant job model, and aggregate recomputation
- `lib/rindle/workers/promote_asset.ex` — existing probe/persist path to reuse for re-probe semantics
- `lib/rindle/ops/variant_maintenance.ex` — current regeneration and storage-verification internals
- `lib/mix/tasks/rindle.regenerate_variants.ex` — current broad-regeneration CLI contract
- `lib/mix/tasks/rindle.verify_storage.ex` — current deterministic verification/reporting contract
- `lib/rindle/ops/metadata_backfill.ex` — explicit rerun-analysis pattern and per-item failure accumulation
- `lib/mix/tasks/rindle.backfill_metadata.ex` — existing one-shot analysis refresh CLI contract
- `lib/rindle/ops/upload_maintenance.ex` — dry-run-first destructive cleanup pattern and residue sequencing
- `lib/mix/tasks/rindle.cleanup_orphans.ex` — existing destructive maintenance CLI safety posture
- `lib/rindle/ops/sweep_orphaned_temp_files.ex` — AV temp sweep service/worker seam
- `guides/operations.md` — current operator guidance that Phase 30 should replace/extend
- `guides/troubleshooting.md` — current failure-recovery guidance and current manual gaps
- `test/rindle/api_surface_boundary_test.exs` — public/internal boundary expectations
- `test/rindle/ops/variant_maintenance_test.exs` — current regeneration/verification report semantics
- `test/rindle/workers/process_variant_test.exs` — cancellation and variant-state contract coverage

### Discussion and synthesis artifact
- `.planning/phases/30-lifecycle-repair-operations/30-DISCUSSION-LOG.md` — research-backed discuss-phase audit trail and locked recommendation rationale
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Rindle.Ops.VariantMaintenance` already provides idempotent enqueue and
  report-based storage verification; Phase 30 should reuse its selector/report
  patterns rather than inventing a second maintenance style.
- `Rindle.Ops.MetadataBackfill` already demonstrates the preferred per-item
  failure accumulation pattern for explicit repair-style runs.
- `Rindle.Ops.UploadMaintenance` already codifies dry-run-first destructive
  maintenance and explicit sequencing for residue cleanup.
- `Rindle.Ops.SweepOrphanedTempFiles` already exists as the AV temp residue
  seam; Phase 30 should give it a clearer public/operator contract rather than
  replacing it.
- `Rindle.cancel_processing/1` and `ProcessVariant.cancel_processing/1` already
  lock the public repair style around asset scope, visible state transition, and
  aggregate recomputation.

### Established Patterns
- Public lifecycle control belongs on `Rindle`; batch/global maintenance belongs
  in Mix tasks over hidden services.
- Repair work is enqueue-first and state-explicit, not synchronous hidden work.
- Failure surfaces should be deterministic, scriptable, and typed.
- Destructive maintenance defaults should stay safe-first with explicit opt-in.
- Existing lifecycle/FSM discipline must remain visible; repair lanes should not
  bypass it with ad hoc row mutation.

### Integration Points
- New asset-scoped repair APIs should land on `lib/rindle.ex` and delegate to a
  focused internal repair service.
- Re-probe should reuse the existing promote/probe normalization path rather
  than creating a second incompatible probe implementation.
- Broad regeneration should continue building on `VariantMaintenance` and the
  current `mix rindle.regenerate_variants` task contract.
- Sweep work should extend the temp-sweep and upload-maintenance lanes rather
  than collapsing them behind a new umbrella service.
- Docs and tests should replace the current manual "flip DB row then retry"
  guidance with supported repair commands and stable contracts.
</code_context>

<deferred>
## Deferred Ideas

- Admin UI for repair history, dashboards, or one-click remediation
- Persisted repair audit tables/history records
- Generic `Rindle.repair(filters)` or similar broad public filter DSL
- Destructive umbrella cleanup commands that mix unrelated residue types by
  default
- Profile-wide or fleet-wide public regeneration APIs on the `Rindle` facade
- Broader runtime diagnostics/reporting beyond the explicit repair surfaces in
  this phase (belongs to Phase 31)
</deferred>

---
*Phase: 30-lifecycle-repair-operations*
*Context gathered: 2026-05-06*
