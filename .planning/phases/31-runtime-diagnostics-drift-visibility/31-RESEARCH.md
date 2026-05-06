# Phase 31: Runtime Diagnostics & Drift Visibility - Research

**Researched:** 2026-05-06  
**Domain:** Elixir/Phoenix runtime diagnostics, Oban queue inspection, Ecto migration drift, and telemetry contract design [VERIFIED: mix.exs]  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

Copied verbatim from `.planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md`. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md]

### Locked Decisions
- **D-01:** Keep `mix rindle.doctor` as a deterministic prerequisite and drift
  checker, not a broad runtime-inspection or auto-remediation command.
- **D-02:** `mix rindle.doctor` should expand beyond the current FFmpeg and
  profile-capability checks to cover:
  - runtime capability drift
  - profile-to-capability fit
  - required Oban queue presence and default-`Oban` ownership sanity
  - delivery/local-playback misconfiguration
  - stale migration state
- **D-03:** `mix rindle.doctor` must stay read-only. No queue creation, no
  cleanup, no repair, no migration mutation, and no “auto-fix” mode.
- **D-04:** `mix rindle.doctor` must not become the stuck-work report surface.
  Keep DIAG-01 and DIAG-02 separate so `doctor` remains fast, low-surprise,
  and CI-friendly.
- **D-05:** Use stable, documented check IDs plus actionable fix guidance for
  each failing check. The check contract should feel closer to Django-style
  system checks than ad-hoc stderr strings.
- **D-06:** DIAG-02 should ship as a public structured report API on `Rindle`
  plus a Mix-task wrapper, not as CLI-only output and not as dashboard-first
  UX.
- **D-07:** The canonical shape is:
  - public function on `Rindle`, such as `runtime_status/1` or
    `status_report/1`, returning `{:ok, report}`
  - `mix rindle.runtime_status` as the operator entrypoint
  - text and JSON output modes on the Mix task
- **D-08:** Keep any implementation/query modules under internal
  `Rindle.Ops.*`; the public contract is the `Rindle` facade plus the Mix
  wrapper, consistent with Phase 30’s “asset-scoped public surface, broad
  operator flows command-shaped” boundary.
- **D-09:** The report should be a status/reporting contract, not a new control
  plane. It may point to the right repair verb, but it must not itself mutate
  lifecycle state.
- **D-10:** The report should expose bounded, operator-shaped filters only,
  such as `profile`, `older_than`, `limit`, and `format`. Do not introduce a
  generic public query DSL in v1.5.
- **D-11:** Preserve the current lifecycle vocabulary split:
  - `failed` and `cancelled` are repairable work items
  - `stale` and `missing` are drift classes with different operator verbs
  Phase 31 extends that vocabulary; it does not replace it.
- **D-12:** Use a hybrid classification model:
  - persisted Rindle lifecycle state is the user-facing truth
  - Oban/runtime evidence corroborates whether work is healthy, starved, or
    orphan-suspect
  - migration state is derived from Ecto migration versions, not full schema
    diffing
- **D-13:** Define `stuck lifecycle work` as non-terminal work that exceeded a
  conservative age threshold and lacks healthy corroboration from Oban/runtime.
  Age alone is not enough.
- **D-14:** Lock these diagnostic classes for v1.5:
  - `failed_work`
  - `cancelled_work`
  - `queue_starved`
  - `orphan_suspect`
  - `recipe_drift`
  - `storage_drift`
  - `probe_drift`
  - `runtime_misconfiguration`
  - `migration_pending`
  - `migration_unresolved`
- **D-15:** Suggested default thresholds:
  - `queue_starved`: variant remains `queued` for more than 5 minutes with no
    active corroborating Oban job
  - `orphan_suspect`: `processing`/executing work older than 20 minutes for AV,
    15 minutes for image, or more than 2x the configured timeout when a per-job
    timeout is available
  These are status-report defaults, not hard alert contracts.
- **D-16:** Do not classify `retryable` or first-failure work as “stuck”.
  Exhausted `failed` work is immediately actionable; healthy retry behavior is
  not.
- **D-17:** `stale migration state` in v1.5 means one of:
  - local Rindle migration file exists but is not applied
  - DB reports an applied Rindle migration version that is missing from local
    code
  Do not add checksum/content validation or full schema-diff posture in v1.5.
- **D-18:** Status/report output should favor counts, oldest age, and a bounded
  sample of IDs/examples. Do not emit unbounded per-row output by default and
  do not encourage one-alert-per-row semantics.
- **D-19:** Treat Phase 31 telemetry as a small public contract reset, not a
  broad observability expansion.
- **D-20:** Keep the existing public telemetry allowlist intact; add a narrow
  additive Phase 31 layer rather than redesigning the entire event catalog.
- **D-21:** Use a split telemetry model:
  - `[:rindle, :repair, :start|:stop|:exception]`
  - `[:rindle, :runtime, :refusal]`
  - `[:rindle, :runtime, :check, :stop]`
  - optional `[:rindle, :runtime, :check, :exception]` only if check failures
    need alertable distinction
- **D-22:** Keep new telemetry metadata strictly low-cardinality:
  - repair: `operation`, `scope`, `result`, `dry_run`
  - runtime refusal: `surface`, `reason`, `mode`
  - runtime check: `check`, `status`, `component`
- **D-23:** Do not include `asset_id`, `variant_id`, `storage_key`, raw error
  text, actor identifiers, or similar high-cardinality data in the public
  Phase 31 telemetry contract.
- **D-24:** Do not model cancellation as an error in the new telemetry
  families. For operator semantics, intentional cancellation is a terminal
  lifecycle outcome, not an exception-class failure.
- **D-25:** Do not bless ad-hoc one-off event families such as the current temp
  sweep event as separate public contracts. Fold sweep into the repair
  telemetry contract or keep it internal.
- **D-26:** Do not make a Phoenix dashboard or LiveDashboard integration the
  primary Phase 31 deliverable. A future UI may layer on top of the report and
  telemetry contracts, but the primary surface remains `Rindle` + `mix`.
- **D-27:** `mix rindle.doctor` and `mix rindle.runtime_status` should have
  human-friendly text output first, with deterministic summary ordering and
  optional JSON output for machine use.
- **D-28:** Diagnostics should always point operators to the existing explicit
  repair verbs (`reprobe`, `requeue`, `regenerate`, `cleanup`, `sweep`) rather
  than inventing new overlapping operator language.
- **D-29:** Strengthen the standing project preference: downstream agents should
  decide by default and present one coherent recommendation set unless the
  decision has genuinely high blast radius. Escalate only for:
  - public semver-significant API reshapes
  - destructive or irreversible operations
  - security/compliance boundary changes
  - similarly high-impact architectural commitments

### Claude's Discretion
- Exact public naming between `runtime_status/1` and `status_report/1`, so long
  as one structured report API exists on `Rindle` and one matching Mix wrapper
  exists.
- Exact report struct/map layout, provided the report keeps clear sections for
  lifecycle findings and runtime checks and remains stable enough for docs,
  tests, and automation.
- Exact check ID naming convention, provided it is stable, documented, and
  actionable.
- Exact measurement keys for new telemetry events, provided they remain
  backend-agnostic and low-cardinality.

### Deferred Ideas (OUT OF SCOPE)
- LiveDashboard or first-party UI over the status report
- Adopter-extensible custom doctor checks
- Full checksum/content validation for migration drift
- Generic public query DSL for status inspection
- Metrics-backend-specific integration packages
</user_constraints>

<phase_requirements>
## Phase Requirements

Copied from `.planning/REQUIREMENTS.md` and mapped to the research recommendations below. [VERIFIED: .planning/REQUIREMENTS.md]

| ID | Description | Research Support |
|----|-------------|------------------|
| DIAG-01 | `mix rindle.doctor` detects runtime capability drift, missing queues, delivery plug misconfiguration, and stale migration state with actionable fix guidance. [VERIFIED: .planning/REQUIREMENTS.md] | Doctor check registry, queue inspection via `Oban.check_queue/2`, migration drift via `Ecto.Migrator`, and explicit fix guidance patterns. [CITED: https://hexdocs.pm/oban/Oban.html#check_queue/2] [CITED: https://hexdocs.pm/ecto_sql/3.13.1/Ecto.Migrator.html#migrations/1] |
| DIAG-02 | Rindle exposes a documented runtime status report or equivalent operator query path for stuck or failed assets, variants, and upload sessions. [VERIFIED: .planning/REQUIREMENTS.md] | `Rindle.runtime_status/1` over internal `Rindle.Ops.RuntimeStatus`, bounded filters, state-first classification, and Oban corroboration heuristics. [VERIFIED: lib/rindle.ex] [VERIFIED: lib/rindle/workers/process_variant.ex] |
| DIAG-03 | Telemetry for repair flows, runtime refusals, and operational drift is frozen with documented measurements and metadata. [VERIFIED: .planning/REQUIREMENTS.md] | Additive telemetry family extension on top of the locked contract, plus docs and contract-test parity. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs] [VERIFIED: guides/background_processing.md] |
</phase_requirements>

## Summary

Phase 31 should build on three existing seams instead of inventing a new operational subsystem: `Mix.Tasks.Rindle.Doctor` already owns fast prerequisite checks, the `Rindle` facade already owns public operator-facing functions, and the Phase 30 repair/report services already established deterministic counters plus typed failure reporting. [VERIFIED: lib/mix/tasks/rindle.doctor.ex] [VERIFIED: lib/rindle.ex] [VERIFIED: lib/rindle/ops/lifecycle_repair.ex] [VERIFIED: lib/rindle/ops/variant_maintenance.ex]

The key implementation choice is to keep DIAG-01 and DIAG-02 separate. `mix rindle.doctor` should become a read-only check runner with stable check IDs and fix text, while `Rindle.runtime_status/1` should become the single structured report API for bounded lifecycle findings. That split matches the locked phase context and avoids turning setup validation into an expensive state-report command. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md] [VERIFIED: lib/mix/tasks/rindle.doctor.ex]

The main risk is overfitting diagnostics to data that Rindle does not currently maintain. In particular, `media_processing_runs` exists as a schema and migration, but current runtime flows do not populate it, so DIAG-02 should derive truth from `media_assets`, `media_variants`, `media_upload_sessions`, and `oban_jobs` rather than treating `media_processing_runs` as authoritative. [VERIFIED: lib/rindle/domain/media_processing_run.ex] [VERIFIED: priv/repo/migrations/20260425090300_create_media_processing_runs.exs] [VERIFIED: codebase grep]

**Primary recommendation:** implement `Rindle.runtime_status/1` plus `mix rindle.runtime_status`, expand `mix rindle.doctor` into a stable check registry, and freeze one additive telemetry layer for repair/runtime events without widening the repair verb set. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Doctor prerequisite and drift checks | API / Backend | Database / Storage | The checks execute inside Mix/runtime and inspect repo, Oban, storage capability, and local config rather than browser state. [VERIFIED: lib/mix/tasks/rindle.doctor.ex] |
| Runtime status aggregation | API / Backend | Database / Storage | The report is a public Elixir API on `Rindle` backed by DB queries plus Oban corroboration. [VERIFIED: lib/rindle.ex] [VERIFIED: lib/rindle/workers/process_variant.ex] |
| Queue presence and starvation evidence | API / Backend | Database / Storage | Queue health comes from Oban runtime producers and `oban_jobs`, not from static docs alone. [CITED: https://hexdocs.pm/oban/Oban.html#check_queue/2] [VERIFIED: guides/background_processing.md] |
| Migration drift visibility | API / Backend | Database / Storage | The source of truth is repo migration status and migrated versions. [CITED: https://hexdocs.pm/ecto_sql/3.13.1/Ecto.Migrator.html#migrations/1] [CITED: https://hexdocs.pm/ecto_sql/3.13.1/Ecto.Migrator.html#migrated_versions/2] |
| Telemetry contract freeze | API / Backend | — | Telemetry is emitted from runtime services/workers and contract-tested in-process. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir | `1.19.5` locally, project constraint `~> 1.15` [VERIFIED: mix.exs] [VERIFIED: `elixir --version`] | Public API, Mix tasks, telemetry, Ecto/Oban integration. [VERIFIED: mix.exs] | The repo already implements all operator surfaces as Elixir/Mix modules. [VERIFIED: lib/mix/tasks/rindle.doctor.ex] |
| `ecto_sql` | `3.13.5` locked, `~> 3.13` configured. [VERIFIED: mix.lock] [VERIFIED: mix.exs] | Migration status inspection and repo-backed queries. [VERIFIED: mix.exs] | `Ecto.Migrator.migrations/1` and `migrated_versions/2` provide the exact drift posture Phase 31 needs without schema diffing. [CITED: https://hexdocs.pm/ecto_sql/3.13.1/Ecto.Migrator.html#migrations/1] [CITED: https://hexdocs.pm/ecto_sql/3.13.1/Ecto.Migrator.html#migrated_versions/2] |
| `oban` | `2.21.1` locked, `~> 2.21` configured. [VERIFIED: mix.lock] [VERIFIED: mix.exs] [VERIFIED: `mix hex.info oban`] | Queue presence checks, active-job corroboration, runtime queue inspection. [VERIFIED: guides/background_processing.md] | `Oban.check_queue/2` and `check_all_queues/1` expose queue producer state directly. [CITED: https://hexdocs.pm/oban/Oban.html#check_queue/2] |
| `telemetry` | `1.3.0` locked, `~> 1.2` configured. [VERIFIED: mix.lock] [VERIFIED: mix.exs] | Frozen event contract for repair/runtime additions. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs] | The repo already treats telemetry as a public contract with allowlist tests and guide parity. [VERIFIED: guides/background_processing.md] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `jason` | `1.4.4` locked, `~> 1.4` configured. [VERIFIED: mix.lock] [VERIFIED: mix.exs] | JSON output mode for `mix rindle.runtime_status --format json`. [VERIFIED: mix.exs] | Use only in the Mix wrapper or docs examples; keep the core report as plain Elixir maps/structs. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md] |
| `ffmpeg` | `8.0.1` available locally. [VERIFIED: `ffmpeg -version`] | Existing AV capability checks and runtime-fit validation in doctor. [VERIFIED: lib/mix/tasks/rindle.doctor.ex] | Keep as an input to doctor checks, not as part of runtime status queries. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `Rindle.runtime_status/1` + Mix wrapper | CLI-only SQL/report task | Rejected because the phase locks a public API plus Mix wrapper and Phase 30 already set the public/internal boundary on `Rindle`. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md] [VERIFIED: lib/rindle.ex] |
| `Ecto.Migrator` version inspection | Manual `schema_migrations` SQL or full schema diff | Rejected because Phase 31 explicitly locks version-based pending/unresolved drift only. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md] [CITED: https://hexdocs.pm/ecto_sql/3.13.1/Ecto.Migrator.html#migrations/1] |
| `Oban.check_queue/2` + bounded `oban_jobs` queries | Static config-only queue validation | Rejected because config does not prove a producer is actually running. [CITED: https://hexdocs.pm/oban/Oban.html#check_queue/2] [VERIFIED: guides/background_processing.md] |

**Installation:** existing project dependencies already include the required runtime stack. [VERIFIED: mix.exs]

```bash
mix deps.get
```

**Version verification:** the repo is pinned to `oban 2.21.1` and `ecto_sql 3.13.5`; current upstream releases as of 2026-05-06 are `oban 2.22.1` and `ecto_sql 3.13.5`. Phase 31 should target the locked repo versions unless a separate upgrade phase is planned. [VERIFIED: `mix hex.info oban`] [VERIFIED: `mix hex.info ecto_sql`]

## Architecture Patterns

### System Architecture Diagram

```text
mix rindle.doctor / mix rindle.runtime_status
                |
                v
        Mix task wrapper layer
                |
                v
      Rindle facade public surface
      |                         |
      v                         v
Rindle.Ops.RuntimeChecks   Rindle.Ops.RuntimeStatus
      |                         |
      |---- profiles ---------->| uses Rindle.Config.profile_modules/0
      |---- repo migration ---->| uses Ecto.Migrator.{migrations,migrated_versions}
      |---- Oban producers ---->| uses Oban.check_queue/2
      |---- lifecycle rows ---->| queries media_assets / media_variants / upload_sessions
      |---- job evidence ------>| queries oban_jobs for available/scheduled/executing/retryable
      |                         |
      v                         v
   check results            bounded report sections
      |                         |
      v                         v
 actionable fix text       recommendations -> existing verbs only
```

The report and doctor flows should remain read-only end to end. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md]

### Recommended Project Structure

```text
lib/
├── mix/tasks/
│   ├── rindle.doctor.ex                # expanded deterministic check runner
│   └── rindle.runtime_status.ex        # text/json wrapper over Rindle.runtime_status/1
├── rindle.ex                           # public runtime_status/1 facade entrypoint
├── rindle/ops/
│   ├── runtime_checks.ex               # doctor check registry + result formatter
│   └── runtime_status.ex               # bounded lifecycle/Oban aggregation
└── rindle/contracts/                   # optional internal structs/types for report/check results
test/
├── rindle/ops/runtime_checks_test.exs
├── rindle/ops/runtime_status_test.exs
├── rindle/runtime_status_task_test.exs
└── rindle/contracts/telemetry_contract_test.exs
```

This preserves the established public/internal split already used by repair flows. [VERIFIED: lib/rindle.ex] [VERIFIED: lib/rindle/ops/lifecycle_repair.ex]

### Pattern 1: Check Registry For `mix rindle.doctor`

**What:** model doctor as a list of stable check definitions that each return `%{id, status, component, summary, fix}` rather than raising free-form strings immediately. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md]  
**When to use:** every DIAG-01 check, including queue presence, delivery/runtime fit, and migration drift. [VERIFIED: .planning/REQUIREMENTS.md]

**Recommended check IDs:** `doctor.ffmpeg.available`, `doctor.profile.capability_fit`, `doctor.oban.default_instance`, `doctor.oban.queue.rindle_promote`, `doctor.oban.queue.rindle_process`, `doctor.oban.queue.rindle_media`, `doctor.oban.queue.rindle_purge`, `doctor.oban.queue.rindle_maintenance`, `doctor.delivery.private_support`, `doctor.delivery.local_playback`, `doctor.migration.pending`, `doctor.migration.unresolved`. [VERIFIED: guides/background_processing.md] [VERIFIED: priv/repo/migrations/]

**Example:**

```elixir
# Source: lib/mix/tasks/rindle.doctor.ex + Oban/Ecto docs
def run_checks(args, opts \\ []) do
  results =
    Rindle.Ops.RuntimeChecks.run(
      profiles: resolve_profiles!(args),
      env: System.get_env()
    )

  Enum.each(results, &print_check(&1, opts[:shell] || Mix.shell()))

  if Enum.any?(results, &(&1.status == :error)), do: fail!(opts[:shell] || Mix.shell(), "one or more checks failed")
  :ok
end
```

The current doctor implementation already centralizes profile resolution and failure handling, so a registry is an additive refactor rather than a new UX shape. [VERIFIED: lib/mix/tasks/rindle.doctor.ex]

### Pattern 2: State-First Runtime Status With Oban Corroboration

**What:** derive candidate findings from persisted lifecycle rows first, then corroborate them with bounded Oban evidence. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md]  
**When to use:** `queue_starved` and `orphan_suspect` classification, plus report summaries by state class. [VERIFIED: .planning/REQUIREMENTS.md]

**Recommended report shape:** `%{runtime_checks: [...], assets: %{counts: ...}, variants: %{counts: ..., findings: [...]}, upload_sessions: %{counts: ..., findings: [...]}, recommendations: [...]}`. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md]

**Example:**

```elixir
# Source: lib/rindle/workers/process_variant.ex + phase context
def classify_variant(row, now, oban_index) do
  cond do
    row.state == "failed" -> :failed_work
    row.state == "cancelled" -> :cancelled_work
    row.state == "stale" -> :recipe_drift
    row.state == "missing" -> :storage_drift
    row.state == "queued" and older_than?(row.updated_at, now, 300) and not job_present?(oban_index, row, [:available, :scheduled, :executing, :retryable]) ->
      :queue_starved
    row.state == "processing" and exceeded_processing_threshold?(row, now) and not job_present?(oban_index, row, [:executing, :retryable]) ->
      :orphan_suspect
    true ->
      nil
  end
end
```

The queue/time thresholds should come from constants in `Rindle.Ops.RuntimeStatus`, not from the Mix task, so API and CLI remain aligned. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md]

### Pattern 3: Additive Telemetry Wrapper Around Existing Repair Services

**What:** wrap Phase 30 repair entrypoints and maintenance workers with one new public telemetry family instead of emitting separate per-surface event names. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md]  
**When to use:** `reprobe`, `requeue`, `regenerate`, `cleanup`, and `sweep` surfaces. [VERIFIED: guides/operations.md]

**Example:**

```elixir
# Source: lib/rindle/ops/lifecycle_repair.ex + guides/operations.md
:telemetry.execute(
  [:rindle, :repair, :stop],
  %{duration_us: duration_us, selected: report.selected, errors: report.errors},
  %{operation: :requeue, scope: :asset, result: result_class(report), dry_run: false}
)
```

This replaces the currently ad hoc public temp-sweep event family as a long-term contract candidate. [VERIFIED: lib/rindle/ops/sweep_orphaned_temp_files.ex] [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md]

### Anti-Patterns to Avoid

- **Using `media_processing_runs` as truth:** the table exists, but current runtime code does not populate it, so it will under-report real stuck work. [VERIFIED: lib/rindle/domain/media_processing_run.ex] [VERIFIED: codebase grep]
- **Static config-only queue checks:** queue declarations in docs or config do not prove that an Oban producer is running. [VERIFIED: config/config.exs] [CITED: https://hexdocs.pm/oban/Oban.html#check_queue/2]
- **Age-only stuck heuristics:** queued or processing age alone will misclassify healthy retry behavior and long AV jobs. [VERIFIED: lib/rindle/workers/process_variant.ex] [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md]
- **Public telemetry with IDs or raw errors:** the phase explicitly forbids high-cardinality telemetry metadata. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md]
- **Embedding mutations in diagnostics:** the locked posture is read-only doctor and read-only status. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md]

## Current Seams

- `Mix.Tasks.Rindle.Doctor.run_checks/2` already accepts injectable `shell`, `probe`, and `env` options and currently performs FFmpeg plus profile-capability checks only. That makes it the correct seam for a check-runner refactor. [VERIFIED: lib/mix/tasks/rindle.doctor.ex]
- `Rindle.Config.profile_modules/0` already discovers configured and loaded profile modules, which is enough for profile-scoped capability and delivery checks without inventing another registry. [VERIFIED: lib/rindle/config.ex]
- `Rindle.Workers.ProcessVariant` already defines the runtime queue split (`rindle_process` for image-like work and `rindle_media` for AV), per-variant timeout derivation, and active uniqueness states. Those constants should be reused by diagnostics instead of duplicated in docs or task strings. [VERIFIED: lib/rindle/workers/process_variant.ex]
- The public repair surface is already explicit on `Rindle.reprobe/1` and `Rindle.requeue_variants/2`, while broad maintenance remains Mix-task-first. Phase 31 should point findings back to those verbs rather than expose new mutators. [VERIFIED: lib/rindle.ex] [VERIFIED: guides/operations.md]
- Delivery misconfiguration already appears through `:streaming_not_configured` and signed-delivery capability checks in `Rindle.Delivery`; doctor should validate those preconditions before adopters hit runtime errors. [VERIFIED: lib/rindle/delivery.ex] [VERIFIED: lib/rindle/error.ex]
- Cleanup and sweep telemetry is currently inconsistent: cleanup workers emit the locked `[:rindle, :cleanup, :run]` event, while temp sweep emits `[:rindle, :media, :sweep_orphans, :stop]`, which the phase context explicitly does not want to bless as a public family. [VERIFIED: lib/rindle/workers/cleanup_orphans.ex] [VERIFIED: lib/rindle/workers/abort_incomplete_uploads.ex] [VERIFIED: lib/rindle/ops/sweep_orphaned_temp_files.ex]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Queue presence detection | Custom producer-process registry or config parsing | `Oban.check_queue/2` and `check_all_queues/1` plus bounded `oban_jobs` queries. [CITED: https://hexdocs.pm/oban/Oban.html#check_queue/2] | Oban already exposes local producer state including `paused`, `running`, and `started_at`. [CITED: https://hexdocs.pm/oban/Oban.html#check_queue/2] |
| Migration drift visibility | Manual SQL over `schema_migrations` or schema diffing | `Ecto.Migrator.migrations/1` and `migrated_versions/2`. [CITED: https://hexdocs.pm/ecto_sql/3.13.1/Ecto.Migrator.html#migrations/1] [CITED: https://hexdocs.pm/ecto_sql/3.13.1/Ecto.Migrator.html#migrated_versions/2] | The phase only needs pending vs unresolved version drift, and Ecto already models that directly. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md] |
| Status query DSL | Generic filter AST or arbitrary SQL pass-through | Narrow options: `profile`, `older_than`, `limit`, `format`. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md] | The phase explicitly forbids a generic public query language. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md] |
| New audit or status tables | Persisted diagnostic snapshots | Live queries over existing lifecycle rows and Oban evidence. [VERIFIED: lib/rindle/domain/media_asset.ex] [VERIFIED: lib/rindle/domain/media_variant.ex] [VERIFIED: lib/rindle/domain/media_upload_session.ex] | Phase 31 is visibility only and should not widen persistence or repair verbs. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md] |

**Key insight:** the repo already has the right sources of truth; Phase 31 mainly needs stable aggregation and presentation contracts, not new storage models. [VERIFIED: lib/rindle.ex] [VERIFIED: guides/operations.md]

## Ordering And Implementation Plan

1. Refactor `mix rindle.doctor` into a check registry first, because CI and docs already teach doctor as the prerequisite runtime gate and the new checks are independent of DIAG-02 report formatting. [VERIFIED: guides/getting_started.md] [VERIFIED: lib/mix/tasks/rindle.doctor.ex]
2. Add internal `Rindle.Ops.RuntimeStatus` next, because DIAG-02 depends on shared lifecycle queries, Oban corroboration, and recommendation mapping that should be testable before the Mix wrapper exists. [VERIFIED: lib/rindle/workers/process_variant.ex] [VERIFIED: guides/troubleshooting.md]
3. Add `Rindle.runtime_status/1` and `mix rindle.runtime_status` together once the internal report exists, so text and JSON output are both thin projections of the same struct/map. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md]
4. Freeze the new telemetry family last, because the final event names and metadata keys should match the implemented repair/runtime surfaces rather than a speculative design. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs]
5. Update `guides/background_processing.md`, `guides/operations.md`, and `guides/troubleshooting.md` after the API/task contracts are final so docs remain a projection of the real runtime surface. [VERIFIED: guides/background_processing.md] [VERIFIED: guides/operations.md] [VERIFIED: guides/troubleshooting.md]

## Edge Cases And Risks

### Edge Case 1: Default `Oban` Ownership Check

`guides/background_processing.md` explicitly documents the default `Oban` module as the supported ownership model, and the repo enqueues through bare `Oban.insert`. Doctor should therefore fail loudly when required queues are absent on the default instance instead of trying to infer named-instance compatibility. [VERIFIED: guides/background_processing.md] [VERIFIED: lib/rindle.ex] [VERIFIED: lib/rindle/ops/lifecycle_repair.ex]

### Edge Case 2: `rindle_media` Is Required Even Though The Guide Example Omits It

`ProcessVariant.job_opts_for_variant/1` routes AV work to `:rindle_media`, while the guide’s example queue list currently documents `rindle_process`, `rindle_promote`, `rindle_purge`, and `rindle_maintenance` only. Doctor expansion should treat `rindle_media` as required when AV-capable profiles exist, and docs need correction so the runtime contract matches the code. [VERIFIED: lib/rindle/workers/process_variant.ex] [VERIFIED: guides/background_processing.md]

### Edge Case 3: Local Playback Misconfiguration Is Profile/Callsite Specific

`Rindle.Delivery.streaming_url/3` only requires `local_route` for the local adapter path; non-local adapters only need signed/public delivery support. Doctor should therefore validate delivery support in two layers: adapter-level signed delivery for private mode, and local playback route completeness only for local playback expectations. [VERIFIED: lib/rindle/delivery.ex]

### Edge Case 4: `processing` Work Can Be Healthy Without A Queued Job Row

A `processing` variant may correspond to an executing Oban job rather than an available/scheduled one, and AV timeouts can be 10 minutes or per-job overrides based on variant spec. Orphan heuristics must therefore combine state age, queue class, and job presence in executing/retryable states. [VERIFIED: lib/rindle/workers/process_variant.ex]

### Edge Case 5: Migration Drift Must Stay Version-Only

Phase 31 explicitly limits stale migration state to pending local versions or unresolved applied versions. Avoid adding content checksums, schema introspection, or auto-application logic in this phase. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md] [CITED: https://hexdocs.pm/ecto_sql/3.13.1/Ecto.Migrator.html#migrations/1]

## Common Pitfalls

### Pitfall 1: Raising On First Doctor Failure

**What goes wrong:** a single failing check aborts the task before operators see the rest of the drift surface. [VERIFIED: lib/mix/tasks/rindle.doctor.ex]  
**Why it happens:** the current task raises immediately on `RuntimeError`. [VERIFIED: lib/mix/tasks/rindle.doctor.ex]  
**How to avoid:** collect all check results first, print deterministically, then exit non-zero once at the end. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md]  
**Warning signs:** only one failure line appears even when multiple runtime issues exist. [VERIFIED: lib/mix/tasks/rindle.doctor.ex]

### Pitfall 2: Querying Unbounded Runtime Rows

**What goes wrong:** `runtime_status` becomes slow, noisy, and unsuitable for operator use on larger catalogs. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md]  
**Why it happens:** raw per-row output is tempting when adding diagnostics quickly. [ASSUMED]  
**How to avoid:** keep counts plus oldest age and bounded samples under a `limit` default, with `older_than` prefiltering in SQL. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md]  
**Warning signs:** JSON payloads or text output scale linearly with the whole table. [ASSUMED]

### Pitfall 3: Treating Retryable Jobs As Stuck

**What goes wrong:** operators are told to repair healthy retry behavior, creating duplicate pressure and confusion. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md]  
**Why it happens:** job state is read without the lifecycle-state vocabulary split. [VERIFIED: lib/rindle/domain/media_variant.ex] [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md]  
**How to avoid:** classify only exhausted `failed`, terminal `cancelled`, queued-without-corroboration, and long-processing-without-corroboration as actionable findings. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md]  
**Warning signs:** reports label `retryable` or recently queued jobs as stuck. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md]

### Pitfall 4: Freezing Another One-Off Telemetry Family

**What goes wrong:** telemetry contract sprawl makes docs and dashboards drift. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs]  
**Why it happens:** workers emit locally convenient events like `[:rindle, :media, :sweep_orphans, :stop]`. [VERIFIED: lib/rindle/ops/sweep_orphaned_temp_files.ex]  
**How to avoid:** normalize all repair-like flows under `[:rindle, :repair, ...]` and keep runtime diagnostics under `[:rindle, :runtime, ...]`. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md]  
**Warning signs:** docs need a special-case paragraph for one maintenance worker’s unique event name. [VERIFIED: guides/background_processing.md]

## Code Examples

Verified patterns from official sources and the current codebase:

### Queue Presence Check

```elixir
# Source: https://hexdocs.pm/oban/Oban.html#check_queue/2
def check_required_queue(queue) do
  case Oban.check_queue(queue: queue) do
    nil ->
      %{id: "doctor.oban.queue.#{queue}", status: :error, component: :oban}

    %{paused: true} ->
      %{id: "doctor.oban.queue.#{queue}", status: :error, component: :oban}

    _state ->
      %{id: "doctor.oban.queue.#{queue}", status: :ok, component: :oban}
  end
end
```

### Migration Drift Check

```elixir
# Source: https://hexdocs.pm/ecto_sql/3.13.1/Ecto.Migrator.html#migrations/1
def check_migrations(repo) do
  statuses = Ecto.Migrator.migrations(repo)

  pending = for {:down, id, _name} <- statuses, do: id
  unresolved =
    Ecto.Migrator.migrated_versions(repo)
    |> Enum.reject(&Enum.any?(statuses, fn {_status, id, _name} -> id == &1 end))

  %{pending: pending, unresolved: unresolved}
end
```

### Bounded Runtime Status API

```elixir
# Source: lib/rindle.ex + phase context
@spec runtime_status(keyword() | map()) :: {:ok, map()} | {:error, term()}
def runtime_status(opts \\ []) do
  Rindle.Ops.RuntimeStatus.report(opts)
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual operator guidance for drift and recovery | Explicit repair verbs plus command-shaped ops docs. [VERIFIED: guides/operations.md] | Phase 30 on 2026-05-06. [VERIFIED: .planning/ROADMAP.md] | Phase 31 can recommend existing verbs instead of inventing new recovery language. [VERIFIED: guides/operations.md] |
| FFmpeg-only doctor checks | Doctor as the supported runtime prerequisite gate for adopters and CI. [VERIFIED: lib/mix/tasks/rindle.doctor.ex] [VERIFIED: .planning/phases/28-onboarding-docs-ci-proof/28-CONTEXT.md] | Phase 28 on 2026-05-05. [VERIFIED: .planning/ROADMAP.md] | Phase 31 should expand this contract, not replace it. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md] |
| Ad hoc public telemetry family allowlist | Contract-tested telemetry allowlist with guide parity. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs] [VERIFIED: guides/background_processing.md] | Phase 28 on 2026-05-05. [VERIFIED: .planning/ROADMAP.md] | New telemetry must be additive and contract-tested from day one. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md] |

**Deprecated/outdated:**

- Treating `mix rindle.doctor` as FFmpeg-only local convenience is outdated for v1.5 because the phase explicitly upgrades it into a broader runtime drift checker. [VERIFIED: lib/mix/tasks/rindle.doctor.ex] [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md]
- Telling operators to inspect raw Oban state or mutate rows manually for common failed/cancelled/stale/missing cases is outdated because Phase 30 already froze explicit repair verbs. [VERIFIED: guides/operations.md] [VERIFIED: guides/troubleshooting.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Unbounded runtime-status output would become materially noisy on larger catalogs. [ASSUMED] | Common Pitfalls | Low; the bounded-filter design still matches the locked phase context even if current adopter datasets stay small. |
| A2 | Warning signs for unbounded output and age-only heuristics would show up as operator confusion before they show up as hard failures. [ASSUMED] | Common Pitfalls | Low; this changes prioritization, not the core architecture. |

## Open Questions (RESOLVED)

1. **Should `doctor` always require `rindle_media`, or only when AV-capable profiles are present?**  
Resolution: require `rindle_media` only when discovered profiles include AV-capable variants. Image-only adopters should still satisfy `rindle_process`, `rindle_promote`, `rindle_purge`, and `rindle_maintenance`, but they should not fail a doctor run for an unused AV queue. This keeps DIAG-01 truthful to actual runtime needs while preserving the Phase 31 rule that queue checks stay deterministic and actionable. [VERIFIED: lib/rindle/workers/process_variant.ex] [VERIFIED: lib/rindle/config.ex] [VERIFIED: guides/background_processing.md]

2. **Should `probe_drift` be inferred only from explicit mismatch markers, or also from suspicious null probe fields on non-image assets?**  
Resolution: infer `probe_drift` only from bounded, operator-actionable heuristics on persisted rows, not from broad null-field speculation. In Phase 31 that means suggestion-class findings for cases such as kind/content-type inconsistency or missing required probe-owned AV fields on otherwise available/ready assets. Do not treat `probe_drift` as a hard invariant and do not widen it into schema-wide null audits. This keeps DIAG-02 read-only, bounded, and aligned with the existing `reprobe` recovery verb. [VERIFIED: lib/rindle/ops/lifecycle_repair.ex] [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Mix tasks, runtime-status API tests | ✓ [VERIFIED: `elixir --version`] | `1.19.5` [VERIFIED: `elixir --version`] | — |
| Mix | doctor and runtime-status task execution | ✓ [VERIFIED: `mix --version`] | `1.19.5` [VERIFIED: `mix --version`] | — |
| PostgreSQL server | repo-backed diagnostics and tests | ✓ [VERIFIED: `pg_isready`] | accepting on `5432` [VERIFIED: `pg_isready`] | — |
| PostgreSQL client | manual DB inspection during diagnostics work | ✓ [VERIFIED: `psql --version`] | `14.17` [VERIFIED: `psql --version`] | — |
| FFmpeg | existing AV doctor checks and capability-fit tests | ✓ [VERIFIED: `ffmpeg -version`] | `8.0.1` [VERIFIED: `ffmpeg -version`] | image-only checks can still run, but AV-capability checks would become failing diagnostics rather than a true fallback. [VERIFIED: lib/mix/tasks/rindle.doctor.ex] |
| Node.js | existing repo tooling and docs generation helpers | ✓ [VERIFIED: `node --version`] | `v22.14.0` [VERIFIED: `node --version`] | — |

**Missing dependencies with no fallback:** None found. [VERIFIED: command checks]

**Missing dependencies with fallback:** None found. [VERIFIED: command checks]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit + Oban testing helpers on repo-backed Postgres. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs] [VERIFIED: test/rindle/ops/lifecycle_repair_test.exs] |
| Config file | `test/test_helper.exs` plus standard Mix test aliases. [VERIFIED: mix.exs] [VERIFIED: codebase grep] |
| Quick run command | `mix test test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_status_test.exs test/rindle/contracts/telemetry_contract_test.exs --only contract` for contract-sensitive work, or narrower per file during implementation. [ASSUMED] |
| Full suite command | `mix test` [VERIFIED: mix.exs] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DIAG-01 | Doctor reports queue, migration, delivery, and capability drift with stable check IDs and fix guidance. [VERIFIED: .planning/REQUIREMENTS.md] | integration | `mix test test/rindle/ops/runtime_checks_test.exs` | ❌ Wave 0 |
| DIAG-02 | `Rindle.runtime_status/1` classifies failed/cancelled/drift/stuck rows with bounded samples and task projections. [VERIFIED: .planning/REQUIREMENTS.md] | integration | `mix test test/rindle/ops/runtime_status_test.exs test/rindle/runtime_status_task_test.exs` | ❌ created during execution |
| DIAG-03 | Telemetry allowlist and metadata/measurement contract include repair/runtime additions without breaking existing events. [VERIFIED: .planning/REQUIREMENTS.md] | contract | `mix test test/rindle/contracts/telemetry_contract_test.exs --only contract` | ✅ partial |

### Sampling Rate

- **Per task commit:** run the narrowest affected test file plus `mix test test/rindle/contracts/telemetry_contract_test.exs --only contract` when telemetry or docs parity changes. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs]
- **Per wave merge:** run all new runtime diagnostics tests plus the telemetry contract lane. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs]
- **Phase gate:** full `mix test` green before `/gsd-verify-work`. [VERIFIED: mix.exs]

### Execution-Created Test Targets

- [ ] `test/rindle/ops/runtime_checks_test.exs` — will be created during Plan 31-01 task execution to lock DIAG-01 check IDs, aggregated failures, and fix guidance formatting. [ASSUMED]
- [ ] `test/rindle/ops/runtime_status_test.exs` — will be created during Plan 31-02 task execution to lock DIAG-02 classifications, bounded filters, and recommendation mapping. [ASSUMED]
- [ ] `test/rindle/runtime_status_task_test.exs` — will be created during Plan 31-02 task execution to lock text vs JSON task output and exit behavior. [ASSUMED]
- [ ] Extend `test/rindle/contracts/telemetry_contract_test.exs` — Plan 31-03 expands this existing contract suite for DIAG-03 additive allowlist, required metadata keys, and docs parity. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs]

**Current verification evidence:** `mix test test/rindle/contracts/telemetry_contract_test.exs --only contract` passed with `10 tests, 0 failures` on 2026-05-06 in this workspace. [VERIFIED: test run]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no [VERIFIED: phase scope] | Operator diagnostics run inside Mix/API surfaces already owned by the host app. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md] |
| V3 Session Management | no [VERIFIED: phase scope] | Not a session feature phase. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md] |
| V4 Access Control | no [VERIFIED: phase scope] | No new web/dashboard control plane is in scope. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md] |
| V5 Input Validation | yes [VERIFIED: phase scope] | Keep bounded filter validation and explicit option allowlists like the existing repair and maintenance APIs. [VERIFIED: lib/rindle/ops/lifecycle_repair.ex] [VERIFIED: lib/rindle/ops/variant_maintenance.ex] |
| V6 Cryptography | no [VERIFIED: phase scope] | No new crypto primitives; delivery token signing already exists outside this phase. [VERIFIED: lib/rindle/delivery.ex] |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Unbounded diagnostics leaking too much operational detail | Information Disclosure | Keep default output aggregated and bounded; sample IDs only, no raw storage keys or payload dumps. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md] |
| High-cardinality telemetry exploding metrics cost | Denial of Service | Restrict public metadata to `operation`, `scope`, `result`, `dry_run`, `surface`, `reason`, `mode`, `check`, `status`, `component`. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md] |
| Diagnostics accidentally mutating runtime state | Tampering | Keep doctor and runtime-status surfaces read-only and route all fix recommendations back to explicit existing verbs. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md] [VERIFIED: guides/operations.md] |
| Typos in public filters broadening scope silently | Tampering | Reuse explicit option/filter validation patterns already present in repair/maintenance modules. [VERIFIED: lib/rindle/ops/lifecycle_repair.ex] [VERIFIED: lib/rindle/ops/variant_maintenance.ex] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md` — locked decisions, classes, and thresholds. [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md]
- `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/PROJECT.md`, `.planning/STATE.md` — phase scope and milestone posture. [VERIFIED: codebase reads]
- `lib/mix/tasks/rindle.doctor.ex` — current doctor contract and extension seam. [VERIFIED: lib/mix/tasks/rindle.doctor.ex]
- `lib/rindle.ex`, `lib/rindle/ops/lifecycle_repair.ex`, `lib/rindle/ops/variant_maintenance.ex` — public/internal boundary and existing report patterns. [VERIFIED: codebase reads]
- `lib/rindle/workers/process_variant.ex`, `lib/rindle/delivery.ex`, `lib/rindle/config.ex` — queue, timeout, delivery, and profile discovery facts. [VERIFIED: codebase reads]
- `guides/background_processing.md`, `guides/operations.md`, `guides/troubleshooting.md` — documented operator contract and current drift gaps. [VERIFIED: codebase reads]
- `test/rindle/contracts/telemetry_contract_test.exs` — telemetry allowlist and docs parity lock. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs]
- Oban docs: https://hexdocs.pm/oban/Oban.html#check_queue/2 — queue producer inspection and local alternate-instance behavior. [CITED: https://hexdocs.pm/oban/Oban.html#check_queue/2]
- Ecto.Migrator docs: https://hexdocs.pm/ecto_sql/3.13.1/Ecto.Migrator.html#migrations/1 and https://hexdocs.pm/ecto_sql/3.13.1/Ecto.Migrator.html#migrated_versions/2 — migration status and applied-version APIs. [CITED: https://hexdocs.pm/ecto_sql/3.13.1/Ecto.Migrator.html#migrations/1] [CITED: https://hexdocs.pm/ecto_sql/3.13.1/Ecto.Migrator.html#migrated_versions/2]

### Secondary (MEDIUM confidence)

- `mix hex.info oban` and `mix hex.info ecto_sql` — current upstream release dates versus repo-locked versions. [VERIFIED: command output]

### Tertiary (LOW confidence)

- None. All architecture-driving claims above were verified from the codebase or official docs. [VERIFIED: source audit]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — all recommended libraries are already in the repo and the external APIs used for Phase 31 were verified against official docs. [VERIFIED: mix.exs] [CITED: https://hexdocs.pm/oban/Oban.html#check_queue/2] [CITED: https://hexdocs.pm/ecto_sql/3.13.1/Ecto.Migrator.html#migrations/1]
- Architecture: HIGH — the public/internal split and operator posture are already established in code and locked context. [VERIFIED: lib/rindle.ex] [VERIFIED: .planning/phases/31-runtime-diagnostics-drift-visibility/31-CONTEXT.md]
- Pitfalls: MEDIUM — most are directly visible in the current seams, with a small number of operator-scale implications called out as assumptions. [VERIFIED: lib/mix/tasks/rindle.doctor.ex] [VERIFIED: lib/rindle/ops/sweep_orphaned_temp_files.ex] [ASSUMED]

**Research date:** 2026-05-06  
**Valid until:** 2026-06-05 for repo-internal seams; 2026-05-13 for upstream release/version notes. [ASSUMED]
