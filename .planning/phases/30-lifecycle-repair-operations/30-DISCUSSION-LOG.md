# Phase 30: Lifecycle Repair Operations - Discussion Log

**Date:** 2026-05-06
**Mode:** Research-first discuss-phase with delegated subagent synthesis
**Status:** Complete

## Inputs

- User selected **all** identified gray areas for discussion.
- User requested:
  - parallel subagent research for each area
  - pros/cons/tradeoffs with examples
  - idiomatic Elixir/Phoenix/Plug/Ecto guidance
  - lessons from successful adjacent libraries/frameworks
  - coherent one-shot recommendations with strong DX and least-surprise bias
  - project preference shift toward research-first/default-decide behavior,
    except for very impactful decisions

## Areas Discussed

1. Repair surface shape
2. Re-probe semantics
3. Requeue and regenerate targeting
4. Sweep scope and scheduling
5. Audit and failure output

## Research Inputs Used

- Local codebase analysis of:
  - `lib/rindle.ex`
  - `lib/rindle/workers/process_variant.ex`
  - `lib/rindle/workers/promote_asset.ex`
  - `lib/rindle/ops/variant_maintenance.ex`
  - `lib/rindle/ops/upload_maintenance.ex`
  - `lib/rindle/ops/metadata_backfill.ex`
  - `lib/rindle/ops/sweep_orphaned_temp_files.ex`
  - current Mix tasks and operator guides
- Parallel subagent research for each gray area
- Prior phase context from Phases 25-28 and milestone research memo

## Discussion Outcomes

### 1. Repair surface shape

Options considered:
- Public Elixir API first with Mix-task wrappers
- Mix tasks first with thin internal APIs
- Internal services only
- Hybrid split by operation type

Locked decision:
- Use a **hybrid** model.
- Asset-scoped repair operations are public `Rindle` facade APIs.
- Batch/global maintenance remains Mix-task-first over hidden `Rindle.Ops.*`
  services.

Why this won:
- Best fit for Elixir library norms and Rindle’s existing public boundary.
- Preserves composability from code/tests without turning `Rindle` into a
  maintenance command catalog.
- Aligns with existing `cancel_processing/1` asset-scoped public posture.

Rejected footguns:
- CLI-only repair ownership
- public `Rindle.Ops.*`
- generic maintenance DSL on the top-level facade

### 2. Re-probe semantics

Options considered:
- Strict probe-only refresh
- Probe + analyzer metadata refresh together
- Configurable refresh modes
- Probe-only public API with separate metadata backfill path

Locked decision:
- `re-probe` refreshes **probe-derived fields only**.
- Analyzer metadata refresh stays separate via metadata backfill.

Why this won:
- Satisfies the roadmap’s “without unrelated lifecycle state changing”
  requirement most directly.
- Preserves least surprise and current separation of concerns.
- Keeps audit trails and failure modes narrow and intelligible.

Rejected footguns:
- hidden metadata rewrites
- mode-heavy “smart” reprobe APIs
- piggybacking broader repair on a probe verb

### 3. Requeue and regenerate targeting

Options considered:
- Asset-scoped only
- Asset + selected variant names
- Profile-wide batch only
- Distinct surfaces for repair vs bulk maintenance
- One generic repair API with filters

Locked decision:
- Split targeted repair from broad regeneration.
- Public repair is **asset-scoped**, with optional selected variant names.
- Broad regeneration after preset/profile drift stays in the maintenance lane
  via `mix rindle.regenerate_variants`.

Why this won:
- Gives operators precise per-asset repair without exposing a broad public
  filter API.
- Matches existing public facade vs hidden maintenance split.
- Preserves ready siblings and avoids surprise over-repair.

Rejected footguns:
- profile-wide public facade repair
- one generic `repair(filters)` API
- silently accepting unknown variant names

### 4. Sweep scope and scheduling

Options considered:
- Temp-run-dir sweeps only, scheduled only
- Temp-run-dir sweeps with on-demand + scheduled parity
- Separate focused sweeps per residue type, optional thin umbrella
- Broad destructive umbrella repair sweep

Locked decision:
- Keep sweep surfaces **focused by residue type**.
- Give AV temp-run-dir orphan sweeping on-demand + scheduled parity.
- Keep destructive sweep defaults dry-run-first.
- Do not add a destructive umbrella “repair sweep everything” command.

Why this won:
- Best fit for current Rindle maintenance design.
- Avoids mixed cadences, mixed safety semantics, and vague operator intent.
- Keeps each repair lane schedulable and auditable on its own terms.

Rejected footguns:
- broad cleanup buckets
- live-by-default destructive sweeping
- mixing upload/session cleanup and temp sweeping into one opaque command

### 5. Audit and failure output

Options considered:
- Terse counters only
- Counters + logs only
- Structured public reports + human-friendly Mix output
- Persisted audit rows/events
- Telemetry-only augmentation

Locked decision:
- Public repair APIs return structured reports with counters and typed
  per-item failures.
- Mix tasks keep deterministic summaries and emit bounded tagged failure lines.
- Logs and telemetry are additive, not the only operator-facing failure surface.
- No persisted repair audit tables in Phase 30.

Why this won:
- Best DX/scriptability fit for Elixir libraries.
- Keeps cron/CLI output stable while still exposing actionable failure detail.
- Avoids overbuilding durable audit infrastructure too early.

Rejected footguns:
- logs-only repair visibility
- telemetry-only operator feedback
- persisted audit rows before there is an admin/history requirement

## Cross-Cutting Decisions

- Preserve asset-scoped public lifecycle control.
- Preserve enqueue-only repair where existing regeneration semantics are
  enqueue-based.
- Preserve FSM-visible lifecycle transitions and explicit state discipline.
- Replace current manual operator guidance that instructs direct DB flips with
  supported repair commands.
- Carry forward the project preference:
  research deeply, choose coherent defaults, decide by default, escalate only
  for very impactful decisions.

## Subagent Summaries

- `Repair surface shape`: recommended hybrid public-facade + Mix-task split.
- `Re-probe semantics`: recommended probe-only public boundary with separate
  metadata backfill.
- `Requeue/regenerate targeting`: recommended asset + optional variant names
  for repair, profile/variant filters for broad regeneration.
- `Sweep scope and scheduling`: recommended focused residue-specific sweeps,
  dry-run defaults, no destructive umbrella command.
- `Audit and failure output`: recommended structured public reports, bounded
  Mix output, additive logs + telemetry, no persisted audit rows.
- `Codebase assumptions`: confirmed the recommendations fit current public
  boundary tests, existing ops services, and prior phase decisions.

## Result

The recommendations above were synthesized into:
- `30-CONTEXT.md` — canonical downstream planning input

No unresolved gray areas remain at discuss phase level.
