# Phase 123: Runtime Operations Decomposition - Pattern Map

**Mapped:** 2026-08-22
**Scope source:** `.planning/ROADMAP.md` Phase 123 and `OPS-01`, `OPS-02`, `OPS-03`, `SAFE-01` in `.planning/REQUIREMENTS.md`. No Phase 123 `CONTEXT.md` or `RESEARCH.md` existed when this map was produced.
**Files analyzed:** 11 implementation and preservation-test surfaces
**Analogs found:** 11 / 11

Phase 123 is an internal, behavior-preserving extraction. The public entrypoints
`Rindle.Ops.RuntimeChecks.run/2`, `Rindle.runtime_status/1`,
`Mix.Tasks.Rindle.RuntimeStatus.run/1`, and `Rindle.Migration` must retain their
signatures and observable results. New collaborators should be internal (`@moduledoc false`)
and accept already-resolved data/dependencies rather than independently reading application
configuration or changing query ownership.

## File Classification

| New/Modified File | Role | Data flow | Closest analog | Match quality |
|---|---|---|---|---|
| `lib/rindle/ops/runtime_checks.ex` | orchestration service | request-response / event-driven | current `RuntimeChecks.run/2` | exact |
| `lib/rindle/ops/runtime_checks/migration_checks.ex` | diagnostic service | request-response / database inspection | `Rindle.Ops.OwnershipSnapshot` | role + flow |
| `lib/rindle/ops/runtime_checks/profile_checks.ex` | diagnostic service | request-response / transform | current profile/delivery/Tus functions in `RuntimeChecks` | extraction seam |
| `lib/rindle/ops/runtime_checks/streaming_checks.ex` | diagnostic service | request-response / external probe | `test/rindle/ops/runtime_checks_streaming_test.exs` contract grouping | extraction seam |
| `lib/rindle/ops/runtime_checks/gcs_checks.ex` | diagnostic service | request-response / external probe | current GCS section in `RuntimeChecks` | extraction seam |
| `lib/rindle/migration/v1.ex` | migration / façade | transaction / database DDL | current move + preflight state machine | exact |
| `lib/rindle/migration/v1/preflight.ex` | migration validator | database inspection / transform | `Rindle.Ops.OwnershipSnapshot` | role + flow |
| `lib/rindle/ops/runtime_status.ex` | collection orchestration service | request-response / CRUD | current `RuntimeStatus.runtime_status/1` | exact |
| `lib/rindle/ops/runtime_status/collector.ex` | reporting service | CRUD / transform | current report/query helpers in `RuntimeStatus` | extraction seam |
| `lib/mix/tasks/rindle.runtime_status.ex` | command / presenter | command / request-response | current Mix-task `run/1` and formatter functions | exact |
| `lib/rindle/ops/runtime_status/formatter.ex` | formatter utility | transform | current task text/error formatting | extraction seam |
| `test/rindle/ops/runtime_checks_test.exs` | behavior + contract test | request-response / event-driven | current stable-ID and ownership tests | exact |
| `test/rindle/ops/runtime_checks_streaming_test.exs` | behavior test | request-response / external-probe boundary | current per-domain streaming tests | exact |
| `test/rindle/migration_test.exs` | migration integration test | transaction / database DDL | current preflight, reversal, and privilege tests | exact |
| `test/rindle/ops/runtime_status_test.exs` | report integration test | CRUD / request-response | current setup tripwire and report-shape tests | exact |
| `test/rindle/runtime_status_task_test.exs` | command/presentation test | command / transform | current flag and output-order tests | exact |

The listed collaborator names are the recommended file boundaries, not a mandate to make every
extraction. Keep the parent entrypoints as façades; do not add another public API.

## Pattern Assignments

### `lib/rindle/ops/runtime_checks.ex` (orchestrator, event-driven)

**Analog:** current [`lib/rindle/ops/runtime_checks.ex`](../../../lib/rindle/ops/runtime_checks.ex),
lines 79-172.

Keep `run/2` as the only composition root: it resolves injected dependencies/configuration once,
selects conditional checks, runs every closure through one telemetry wrapper, then sorts by `id`.
Collaborators should return a complete check map; the orchestration layer must remain responsible
for `Enum.map(&run_check/1)`, sorting, failure counting, and the locked telemetry event.

```elixir
checks =
  ([fn -> check_delivery_support(profiles) end, ...] ++ gcs_extra ++ tus_extra)
  |> Enum.map(&run_check/1)
  |> Enum.sort_by(& &1.id)

failed = Enum.count(checks, &(&1.status == :error))
%{checks: checks, failed: failed, success?: failed == 0, total: length(checks)}
```

**Preserve exactly:** option injection seams (`:env`, `:probe`, `:profiles`, catalog/snapshot
fixtures), deterministic check IDs/order, `:warn` not contributing to `failed`, and
`[:rindle, :runtime, :check, :stop]` measurements/metadata. The source currently makes GCS and
Tus rows *absent*, rather than silent OK rows, when their relevant profiles are absent (lines
113-139); retain that conditional list construction.

**Tests to retain:** `test/rindle/ops/runtime_checks_test.exs:72-180` locks stable IDs,
ownership redaction, and per-check telemetry. `test/rindle/contracts/telemetry_contract_test.exs:213-236`
locks the event name and metadata shape.

### `lib/rindle/ops/runtime_checks/{migration_checks,profile_checks,streaming_checks,gcs_checks}.ex`

**Closest analog:** [`lib/rindle/ops/ownership_snapshot.ex`](../../../lib/rindle/ops/ownership_snapshot.ex),
lines 19-57, 105-166, and 219-327.

That module is the project’s best cohesive diagnostic pattern: one public internal entrypoint,
injected readers/configuration for tests, bounded classification atoms, and normalized map results
that include ownership and next-action data. Extraction should mirror that shape: parent builds a
context map; each domain returns checks without reaching back into `Application`.

**Exact existing seams in `RuntimeChecks`:**

- **Migration/ownership:** `check_migration_pending/2` through
  `check_resumable_session_schema/1` (lines 381-592), catalog reads
  `migration_statuses/1` through `resumable_session_schema_catalog/0` (lines 649-799), and
  their fixed result constructors. Keep legacy-history downgrade logic, host-owned `oban_jobs`
  wording, bounded failed inspection text, and `ownership_boundary` map key.
- **Profiles/delivery/Oban/Tus:** `check_profile_runtime_fit/2`,
  `check_oban_default_instance/1`, `check_oban_required_queues/2`,
  `check_tus_capability/1`, `check_delivery_support/1`, and `check_local_playback/2`
  (lines 206-380), with profile resolution/capability helpers (594-945). Return the same
  `id`, `component`, `status`, `summary`, and `fix` shape.
- **Streaming:** `streaming_profiles/1` through smoke-ping timeout helpers
  (lines 965-1250). Preserve the no-streaming-profile vacuous-OK behavior and the explicit
  `--streaming` gate; never place secret values in summaries.
- **GCS:** `gcs_profiles/1` through `format_gcs_cors_reason/1` (lines 1252-1783), while
  leaving public test hooks `probe_gcs_bucket/4` and `do_probe/4` either delegated unchanged
  from `RuntimeChecks` or explicitly retained as documented internal test hooks. Preserve
  200/403, 404, 500, precondition, and bearer-token-redaction semantics.

**Result construction pattern** (lines 1785-1803): keep one shared result builder or a pure,
identical equivalent across collaborators. Do not let independently extracted domains invent
their own map shape or telemetry.

**Tests to retain:**

- `runtime_checks_test.exs:306-547` for migration catalog, ownership, resumable-schema, and
  Tus outcomes.
- `runtime_checks_test.exs:550-1248` for conditional GCS rows, external-probe status mapping,
  and secret redaction.
- `runtime_checks_streaming_test.exs:62-246` for streaming profile gates, credentials, PEM,
  webhook, smoke-ping, and queue behavior.

### `lib/rindle/migration/v1.ex` and `lib/rindle/migration/v1/preflight.ex` (migration state machine)

**Analog:** current [`lib/rindle/migration/v1.ex`](../../../lib/rindle/migration/v1.ex), lines
65-200 (public move façade plus state classification), 444-627 (ordered move/snapshot helpers),
and 631-704 (bounded errors and DDL helpers).

The extraction should be pure preflight classification around a single immutable snapshot. The
existing façade calls preflight *before* provisioning or moving; preserve this order and return
atoms exactly as today:

```elixir
case preflight_public_to_rindle() do
  :already_upgraded -> :ok
  {:provisionable_absent_target, _snapshot} ->
    provision_schema(@rindle_schema)
    move_owned_relations(@public_schema, @rindle_schema, failure_point)
  {:movable_existing_target, _snapshot} ->
    move_owned_relations(@public_schema, @rindle_schema, failure_point)
  {:refusal, reason} -> raise_preflight_error!(reason)
end
```

**Preserve, do not relocate into a generic migrator:**

- `@rindle_tables`, `marker_table/0`, `owned_relations/0`, and the fixed catalog exactness
  check. No dynamic table discovery and no host-table inclusion.
- the directional preflight return vocabulary, complete-source/target predicates, marker validity,
  ownership/privilege checks, and bounded `raise_preflight_error!/2` messages;
- `move_owned_relations/3` iteration order, `move_relation!/3` DDL, test-only failure injection,
  transaction behavior, and the safe reverse move. No split that starts its own transaction or
  provisions before successful preflight.

`test/rindle/migration_test.exs:194-579` is the nearest test pattern: preflight tests assert no
DDL before a refusal, then integration tests prove exact owned relation movement, rollback after
injected failure, lock handling, denied privilege behavior, and reversal. Keep this one cohesive
integration module rather than testing private extracted helpers by source inspection.

### `lib/rindle/ops/runtime_status.ex` and `runtime_status/collector.ex` (collection, CRUD)

**Analog:** current [`lib/rindle/ops/runtime_status.ex`](../../../lib/rindle/ops/runtime_status.ex),
lines 38-67 and 180-392.

Retain `runtime_status/1` as a small façade with this ordering: normalize filters, collect one
ownership snapshot, refuse before any report query when not ready, then collect the four report
sections and recommendations. A collector receives normalized filters, `now`, cutoff, and the
already-approved Oban prefix; it must not repeat readiness checks or normalize filters again.

```elixir
with {:ok, filters} <- normalize_filters(opts),
     {:ok, snapshot} <- ready_snapshot() do
  now = DateTime.utc_now()
  cutoff = older_than_cutoff(now, filters.older_than)
  runtime_checks = runtime_checks_report(filters, cutoff, now)
  assets = asset_report(filters)
  variants = variant_report(filters, cutoff, now, snapshot.oban.observed_prefix)
  ...
end
```

**Extraction seams:** report sections are already isolated by function:
`runtime_checks_report/3` (180-191), `asset_report/1` (193-204), `variant_report/4`
(206-231), `upload_session_report/3` (233-300), `provider_assets_report/2` (302-390), and
`build_recommendations/4` (392-405). Keep the Ecto query helpers with the collection layer:
they rely on `rindle_all/1`, `oban_all/2`, and `report_query/0` error behavior (lines 407-555).

**Preserve exactly:** allowed filter keys/default limit/format handling (809-905), report map
keys including `provider_assets`, samples and redaction, limits, recommendation action/surface,
and refusal telemetry `[:rindle, :runtime, :refusal]`. The setup check must remain query-first
as a guard: `runtime_status_test.exs:49-176` has a report-query tripwire and compiled-prefix proof.

### `lib/mix/tasks/rindle.runtime_status.ex` and `runtime_status/formatter.ex` (command/presentation)

**Analog:** current [`lib/mix/tasks/rindle.runtime_status.ex`](../../../lib/mix/tasks/rindle.runtime_status.ex),
lines 31-68 (command), 70-176 (bounded errors/JSON), and 178-275 (text formatter).

Keep the Mix task as a thin transport adapter: parse the exact five flags, omit nil values via
`maybe_put/3`, call the facade once, choose `report.filters.format` for success, print JSON with
`Jason.encode!/2`, and exit `{:shutdown, 1}` only after the locked error rendering path.

```elixir
case Rindle.runtime_status(filters) do
  {:ok, report} ->
    case report.filters.format do
      :json -> Mix.shell().info(Jason.encode!(report, pretty: true))
      :text -> print_text_report(report)
    end
  {:error, reason} ->
    print_error(reason, json?)
    exit({:shutdown, 1})
end
```

Formatter extraction can make `format_error/1`, `format_json_error/1`, and `format_text_report/1`
delegates from the task, because those functions are `@doc false` but directly tested. Preserve
their current callable task-module surface unless all callers/tests are deliberately updated in
one slice. Text ordering is a contract: provider findings follow upload-session output and precede
recommendations (lines 189-197), and every list is deterministically sorted before rendering.

**Tests to retain:** `test/rindle/runtime_status_task_test.exs:177-247` locks
`--provider-stuck`, redacted output, and provider-section placement. Earlier task tests lock
option parsing, text/JSON selection, non-zero errors, and setup guidance. Keep renderer tests as
pure maps; no database fixture is needed for formatting.

## Shared Patterns

### Bounded diagnostic dependencies and configuration

**Source:** `lib/rindle/ops/ownership_snapshot.ex:19-57, 105-166`.

Pass fakes/readers via keywords from the entrypoint, normalize them once, and collapse unknown
inspection failures into a safe classification. This makes tests deterministic without exposing
credentials, arbitrary query errors, or application state from a collaborator.

### Error and result vocabulary

**Sources:** `runtime_checks.ex:1785-1803`, `runtime_status.ex:135-178`, and
`rindle.runtime_status.ex:70-176`.

Keep failure terms, check IDs, map keys, safe-prefix validation, owner classifications, and user
guidance byte-compatible in meaning. New modules should return structured values to the façade;
only the task renders strings/JSON.

### Telemetry boundary

**Sources:** `runtime_checks.ex:174-185`, `runtime_status.ex:895-905`, and
`test/rindle/contracts/telemetry_contract_test.exs:205-236`.

Emit from the same top-level wrapper/facade. Do not emit one event per delegated substep, change
event names, or add high-cardinality/secret metadata.

### Database ownership and transaction safety

**Sources:** `migration/v1.ex:74-200, 444-627` and `ops/ownership_snapshot.ex:137-217`.

Rindle owns its fixed catalog; the host owns `oban_jobs` and `schema_migrations`. Preflight is
read-only and must happen before DDL; the parent migration holds all side-effect ordering and
reversal behavior.

### SAFE-01

**Source:** `scripts/maintainer/refactor_contract.sh:1-16`, enforced by
`test/install_smoke/refactor_contract_test.exs:6-58`.

Run the preservation command for every extraction slice. It compiles, fails on compile-connected
cycles, then runs the API/schema/migration/telemetry/error/release selected suites in one
foreground `mix test --include contract --seed 0` process. Phase 123 must not weaken that runner.

## Anti-Patterns to Avoid

- Moving public functions or test hooks without a delegate: keep
  `RuntimeChecks.run/2`, `RuntimeChecks.probe_gcs_bucket/4`, `RuntimeChecks.do_probe/4`,
  `RuntimeStatus.runtime_status/1`, task formatter functions, and migration façade exports
  callable where current tests/consumers expect them.
- Having a diagnostic collaborator read app config or emit telemetry on its own. This duplicates
  injected/testable entrypoint concerns and can create extra events.
- Altering conditional diagnostic row absence, sort order, check IDs, `:warn` accounting, report
  keys, sample limits, or CLI line order as a byproduct of file movement.
- Generalizing the fixed migration catalog into dynamic discovery, moving host relations, changing
  preflight-before-DDL order, or starting nested transactions.
- Turning refusal/error output into an exception from the API or into a successful CLI exit; the
  error atoms/shapes and `{:shutdown, 1}` behavior are contract surfaces.
- Unit-testing only newly extracted private functions. Retain the existing façade-level tests,
  database migration integration proof, and contract telemetry suite as the behavior boundary.

## Plan Mapping Guidance

1. **OPS-01:** First extract `RuntimeChecks` diagnostic domains behind an unchanged `run/2`
   orchestration/telemetry wrapper. Add only focused collaborator tests if an existing façade test
   cannot exercise a new pure edge; otherwise keep the current tests as the proof.
2. **OPS-02:** Next isolate snapshot/preflight classification from `Migration.V1` while leaving
   the move façade, constants, transaction, ordered DDL, and reversal in `V1`. Execute the
   existing migration integration suite after this slice.
3. **OPS-03:** Split runtime-status readiness/collection/formatting in that order: API façade
   guards snapshot and telemetry; collector owns Ecto report/query helpers; formatter owns text
   and safe CLI error presentation; Mix task remains command-only.
4. **SAFE-01 for each slice:** run its focused test module(s), then
   `bash scripts/maintainer/refactor_contract.sh`; final phase verification additionally runs the
   three primary focused suites together:
   `MIX_ENV=test mix test test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_checks_streaming_test.exs test/rindle/migration_test.exs test/rindle/ops/runtime_status_test.exs test/rindle/runtime_status_task_test.exs`.

## Metadata

**Analog search scope:** `lib/rindle/ops`, `lib/rindle/migration`, `lib/mix/tasks`, `test/rindle/ops`,
`test/rindle`, `test/install_smoke`, and `scripts/maintainer`.
**Primary live analogs:** `RuntimeChecks`, `RuntimeStatus`, `Migration.V1`, `OwnershipSnapshot`,
the runtime-status Mix task, and their behavior/contract suites.
**Pattern extraction date:** 2026-08-22
