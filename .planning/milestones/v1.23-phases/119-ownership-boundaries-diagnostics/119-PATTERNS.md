# Phase 119: Ownership Boundaries & Diagnostics - Pattern Map

**Mapped:** 2026-08-09  
**Files analyzed:** 14 anticipated files  
**Analogs found:** 13 / 14

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/rindle/ops/ownership_snapshot.ex` | service / internal model | request-response, transform | `lib/rindle/ops/runtime_status.ex` + `lib/rindle/migration/v1.ex` | composite exact |
| `lib/rindle/ops/runtime_checks.ex` | service | request-response | same file's catalog checks | exact |
| `lib/rindle/ops/runtime_status.ex` | service | request-response | same file's setup preflight | exact |
| `lib/mix/tasks/rindle.doctor.ex` | CLI controller | request-response | same task's `run_checks/2` + `emit_check/2` | exact |
| `lib/mix/tasks/rindle.runtime_status.ex` | CLI controller / renderer | request-response | same task's `format_error/1` | exact |
| `lib/rindle/admin/queries.ex` | query façade | request-response | `runtime_doctor/1` | exact |
| `lib/rindle/admin/live/runtime_doctor_live.ex` | LiveView component | request-response | same LiveView's doctor-table rendering | exact |
| `examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex` | LiveView component | request-response | `runtime_status_output/0` | exact |
| `test/rindle/ops/ownership_snapshot_test.exs` | test | request-response, integration | `test/rindle/ops/runtime_checks_test.exs` | role-match |
| `test/rindle/ops/runtime_checks_test.exs` | test | request-response | existing catalog-fixture tests | exact |
| `test/rindle/ops/runtime_status_test.exs` | test | request-response | existing early-refusal tests | exact |
| `test/rindle/doctor_test.exs` | test | request-response | `run_checks/2` output tests | exact |
| `test/rindle/runtime_status_task_test.exs` | test | request-response | task non-zero/error copy tests | exact |
| `test/rindle/migration_test.exs` | integration test | database I/O | host-relation preservation tests | exact |
| `examples/adoption_demo/e2e/ops-surfaces.spec.js` | E2E test | request-response | existing output visibility assertions | exact |

## Pattern Assignments

### `lib/rindle/ops/ownership_snapshot.ex` (internal service, request-response / transform)

**Analog:** [`lib/rindle/ops/runtime_status.ex`](../../../lib/rindle/ops/runtime_status.ex) lines 72-146 and [`lib/rindle/migration/v1.ex`](../../../lib/rindle/migration/v1.ex) lines 62-70, 557-700.

Use a private, data-only `inspect/1` entry point and injected option seams, then return tagged data rather than formatting errors. Keep all report queries below the preflight; the snapshot owns only catalog reads and classification.

**Existing preflight shape** (`runtime_status.ex` lines 72-91):

```elixir
setup_readiness =
  opts
  |> Keyword.get(:setup_readiness, :inspect)
  |> case do
    :inspect -> inspect_setup_readiness()
    readiness -> readiness
  end

case setup_readiness do
  %{rindle_schema: %{ready?: true}, oban_jobs: %{ready?: true}} -> :ok
  %{rindle_schema: %{ready?: false}} -> {:error, {:setup_incomplete, :rindle_schema}}
  %{oban_jobs: %{ready?: false}} -> {:error, {:setup_incomplete, :oban_jobs}}
end
```

**Allowlist and bound catalog-predicate pattern** (`migration/v1.ex` lines 62-70, 558-576):

```elixir
def owned_relations, do: rindle_tables() ++ [marker_table()]

repo().query!(
  """
  SELECT namespace.nspname, relation.relname
  FROM pg_class AS relation
  JOIN pg_namespace AS namespace ON namespace.oid = relation.relnamespace
  WHERE namespace.nspname = ANY($1)
    AND relation.relname = ANY($2)
    AND relation.relkind IN ('r', 'p')
  ORDER BY namespace.nspname, relation.relname
  """,
  [[@public_schema, @rindle_schema], owned_relations()]
)
```

**Identifier boundary** (`migration/v1.ex` lines 630-700):

```elixir
defp qualified(prefix, table), do: "#{quote_ident(prefix)}.#{quote_ident(table)}"

defp quote_ident(identifier) do
  escaped = identifier |> to_string() |> String.replace(~s("), ~s(""))
  ~s("#{escaped}")
end
```

Do not generalize this to arbitrary configuration input. Snapshot validation must admit the two fixed Rindle prefixes, the one fixed `oban_jobs` relation, and only a valid resolved default-Oban prefix.

### `lib/rindle/ops/runtime_checks.ex` (service, request-response)

**Analog:** same module lines 86-151, 448-535, 667-740.

Replace its two independently supplied/lazy catalogs with one snapshot option/seam, and preserve the existing stable check IDs and sorted check list.

```elixir
checks =
  ([
     fn -> check_rindle_schema_ready(rindle_schema_catalog) end,
     fn -> check_oban_default_instance(oban_config) end,
     fn -> check_oban_jobs_ready(oban_jobs_catalog) end
   ] ++ gcs_extra ++ tus_extra)
  |> Enum.map(&run_check/1)
  |> Enum.sort_by(& &1.id)
```

**Telemetry envelope** (`runtime_checks.ex` lines 156-167):

```elixir
:telemetry.execute(
  [:rindle, :runtime, :check, :stop],
  %{duration_us: elapsed_us(started_at)},
  %{check: result.id, status: result.status, component: result.component}
)
```

Enrich result maps additively (`expected_prefix`, `observed_prefix`, `owner`, `classification`, `next_action`); continue emitting the stable `doctor.rindle_schema.ready` and `doctor.oban_jobs.ready` checks.

### `lib/rindle/ops/runtime_status.ex` (service, request-response)

**Analog:** same module lines 64-146, 500-510, 846-856.

Snapshot interpretation must precede all existing report helpers. On refusal, preserve the two existing setup tuples and emit only a bounded classification for new states.

```elixir
with :ok <- validate_filters(opts),
     {:ok, setup} <- setup_readiness(opts),
     :ok <- ensure_setup_ready(setup) do
  # only after the above: runtime_checks_report/3, asset_report/1, etc.
end

defp rindle_all(query), do: Config.repo().all(query, prefix: Config.rindle_prefix())
defp oban_all(query), do: Config.repo().all(query, prefix: Config.oban_prefix())
```

When the snapshot succeeds, pass the resolved host Oban prefix into the existing Oban query helper instead of calling `Config.oban_prefix/0`; Rindle report queries remain tied to `Config.rindle_prefix/0` / `Rindle.Schema.prefix/0`.

### `lib/mix/tasks/rindle.doctor.ex` (CLI controller, request-response)

**Analog:** same module lines 60-110.

```elixir
report =
  args
  |> RuntimeChecks.run(opts |> Keyword.put(:mix_app, mix_app))
  |> emit_report(shell)

shell.info("[#{String.upcase(to_string(status))}] #{id} (#{component}) #{summary}")
if status in [:warn, :error], do: shell.info("  Fix: #{fix}")
```

Continue rendering deterministic sorted checks in line-oriented text. Render the new additive diagnostic fields only from check data; do not add a parallel doctor command/check ID family or raw database reason.

### `lib/mix/tasks/rindle.runtime_status.ex` (CLI controller / renderer, request-response)

**Analog:** same module lines 52-80.

```elixir
{:error, reason} ->
  Mix.shell().error(format_error(reason))
  exit({:shutdown, 1})

def format_error({:setup_incomplete, :oban_jobs}) do
  "Rindle.RuntimeStatus failed: setup_incomplete oban_jobs. Run `mix rindle.doctor`. " <>
    "Install Oban through a host-owned migration using `Oban.Migration`. " <>
    "Rindle no longer manages `oban_jobs`."
end
```

Replace the generic `inspect(reason)` fallback (line 77) with explicit clauses or a shared bounded-renderer delegation. JSON errors should be deterministic, structured fields—not a serialized exception/reason.

### `lib/rindle/admin/queries.ex` and `lib/rindle/admin/live/runtime_doctor_live.ex` (query façade + LiveView, request-response)

**Analogs:** [`lib/rindle/admin/queries.ex`](../../../lib/rindle/admin/queries.ex) lines 214-235 and [`lib/rindle/admin/live/runtime_doctor_live.ex`](../../../lib/rindle/admin/live/runtime_doctor_live.ex) lines 35-120.

```elixir
with {:ok, runtime_status} <- RuntimeStatus.runtime_status(runtime_opts) do
  {:ok, %{generated_at: runtime_status.generated_at, doctor: RuntimeChecks.run([], doctor_opts),
          runtime_status: runtime_status}}
end
```

```heex
<td data-label="Check"><code>{check.id}</code></td>
<td data-label="Status"><.status_chip state={to_string(check.status)} label={to_string(check.status)} /></td>
<td data-label="Summary">{check.summary}</td>
<td data-label="Fix">{check.fix}</td>
```

Keep the façade read-only. If a bounded error must be shown in this surface, expose the shared safe diagnostic text/data rather than assigning/rendering the raw `reason` currently stored by `load/1`.

### `examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex` (LiveView component, request-response)

**Analog:** same module lines 126-164.

```elixir
defp runtime_status_output do
  case Rindle.runtime_status([]) do
    {:ok, report} ->
      report |> Mix.Tasks.Rindle.RuntimeStatus.format_text_report() |> Enum.join("\n")

    {:error, reason} ->
      "Rindle.RuntimeStatus failed: #{inspect(reason)}"
  end
end
```

Use `Mix.Tasks.Rindle.RuntimeStatus.format_error/1` (or the extracted shared renderer) for the error branch. The demo must continue presenting text in the existing `<pre data-testid="runtime-status-output">` element, but never leak sentinel SQL/Postgrex/credential content.

### Test files (tests, request-response / database I/O)

**Analogs:**

- [`test/rindle/ops/runtime_checks_test.exs`](../../../test/rindle/ops/runtime_checks_test.exs) lines 263-370 and 1203-1270: map-like injected catalog fixtures and `fetch_check/2` assertions.
- [`test/rindle/ops/runtime_status_test.exs`](../../../test/rindle/ops/runtime_status_test.exs) lines 48-101: preflight refusal before report queries, using `setup_readiness` test configuration.
- [`test/rindle/runtime_status_task_test.exs`](../../../test/rindle/runtime_status_task_test.exs) lines 72-90: captured task error output and non-zero exit behavior.
- [`test/rindle/migration_test.exs`](../../../test/rindle/migration_test.exs) lines 92-116 and 521-560: snapshot `oban_jobs` / `schema_migrations`, exercise the operation, then assert exact host relation preservation.
- [`test/support/schema_prefix_case.ex`](../../../test/support/schema_prefix_case.ex) lines 18-56: selected/decoy schema fixtures based solely on `Rindle.Config.rindle_prefix/0` and `other_prefix/1`.

```elixir
schema = fetch_check(report, "doctor.rindle_schema.ready")
assert schema.status == :error
assert schema.summary =~ "catalog"

put_setup_readiness(%{rindle_schema: %{ready?: false}, oban_jobs: %{ready?: true}})
assert {:error, {:setup_incomplete, :rindle_schema}} = RuntimeStatus.runtime_status([])
```

Create the dedicated snapshot test module only for classifier/binding behavior. Keep end-to-end consumers tested through the existing doctor/runtime test modules, including a report-query tripwire. Extend `migration_test.exs` for read-side/no-mutation assertions; do not use migration code as a diagnostic implementation dependency beyond its authoritative allowlist.

## Shared Patterns

### Prefix authority and configuration boundary

**Sources:** [`lib/rindle/schema.ex`](../../../lib/rindle/schema.ex) lines 4-30; [`lib/rindle/config.ex`](../../../lib/rindle/config.ex) lines 18-30.

```elixir
@supported_prefixes ["rindle", "public"]
@rindle_prefix Application.compile_env(:rindle, :rindle_prefix, "rindle")

@spec prefix() :: String.t()
def prefix, do: @rindle_prefix

@spec rindle_prefix() :: String.t()
def rindle_prefix, do: Rindle.Schema.prefix()
```

Apply to Rindle-owned routing only. Phase 119 deliberately stops treating `Config.oban_prefix/0` as the canonical runtime source; it becomes a compatibility expectation checked against the resolved host `Oban` binding.

### Data-first checks and safe text

**Source:** [`lib/rindle/ops/runtime_checks.ex`](../../../lib/rindle/ops/runtime_checks.ex) lines 77-84 and 156-167.

```elixir
@type check_result :: %{
  id: String.t(), status: check_status(), component: atom(),
  summary: String.t(), fix: String.t()
}
```

Add fields to the result model; render from those fields in Mix and LiveView. No raw reasons cross this boundary.

### Read-only host ownership proof

**Source:** [`test/rindle/migration_test.exs`](../../../test/rindle/migration_test.exs) lines 92-116.

```elixir
oban_jobs_before = relation_snapshot(prefix, "oban_jobs")
# exercise Rindle operation
assert relation_snapshot(prefix, "oban_jobs") == oban_jobs_before
assert table_exists?(prefix, "oban_jobs")
```

Apply this before/after proof to snapshot/doctor/runtime reads for both `oban_jobs` and `schema_migrations`, and assert that host Oban application configuration is unchanged.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `lib/rindle/ops/ownership_snapshot.ex` | internal service / data model | request-response, transform | No current shared snapshot module exists; compose the two exact existing catalog/preflight patterns above. |

## Metadata

**Analog search scope:** `lib/rindle/ops`, `lib/rindle/migration`, Mix tasks, admin LiveView/query code, adoption demo, focused tests, schema fixtures.  
**Files scanned:** 16  
**Pattern extraction date:** 2026-08-09
