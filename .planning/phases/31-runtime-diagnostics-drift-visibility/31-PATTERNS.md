# Phase 31: Runtime Diagnostics & Drift Visibility - Pattern Map

**Mapped:** 2026-05-06
**Files analyzed:** 10 planned seams
**Analogs found:** 10 / 10

## File Classification

| Planned File / Seam | Role | Data Flow | Closest Analog | Match Quality |
| --- | --- | --- | --- | --- |
| `lib/mix/tasks/rindle.doctor.ex` | task | request-response | `lib/mix/tasks/rindle.doctor.ex` | exact |
| `lib/mix/tasks/rindle.runtime_status.ex` | task | request-response | `lib/mix/tasks/rindle.verify_storage.ex` | role-match |
| `lib/rindle.ex` | facade | request-response | `lib/rindle.ex` | exact |
| `lib/rindle/ops/runtime_status.ex` | service/query | CRUD + request-response | `lib/rindle/ops/variant_maintenance.ex` | role-match |
| `lib/rindle/ops/runtime_checks.ex` or equivalent check helper | service | transform + request-response | `lib/mix/tasks/rindle.doctor.ex` | partial |
| `test/rindle/api_surface_boundary_test.exs` | test | request-response | `test/rindle/api_surface_boundary_test.exs` | exact |
| `test/rindle/contracts/telemetry_contract_test.exs` | contract test | event-driven | `test/rindle/contracts/telemetry_contract_test.exs` | exact |
| `guides/background_processing.md` | docs | event-driven | `guides/background_processing.md` | exact |
| `guides/operations.md` | docs | request-response | `guides/operations.md` | exact |
| `test/install_smoke/docs_parity_test.exs` | docs test | transform | `test/install_smoke/docs_parity_test.exs` | exact |

## Pattern Assignments

### `lib/mix/tasks/rindle.doctor.ex`

**Analog:** `lib/mix/tasks/rindle.doctor.ex`

Why it fits: Phase 31 explicitly extends the existing doctor surface instead of replacing it.

**Operator-facing wrapper + failure path** (`lib/mix/tasks/rindle.doctor.ex:25-51`)
```elixir
@impl Mix.Task
def run(args) do
  run_checks(args)
end

shell.info("Rindle: running environment checks...")

try do
  probe.()
  shell.info("  FFmpeg: OK")
  ...
  shell.info("Rindle: Environment checks passed.")
  :ok
rescue
  e in RuntimeError ->
    fail!(shell, e.message)
end
```

**Actionable profile-check pattern** (`lib/mix/tasks/rindle.doctor.ex:69-94`)
```elixir
Enum.each(variants, fn {name, spec} ->
  normalized =
    case Rindle.Processor.AV.normalize(spec) do
      {:ok, value} -> value
      {:error, reason} -> raise "profile #{inspect(module)} variant #{inspect(name)} is invalid: #{inspect(reason)}"
    end
  ...
end)

shell.info("  Profile #{inspect(module)}: OK (variants checked: #{length(variants)})")
```

Planner note: keep the read-only posture and deterministic text output; add stable check IDs instead of more freeform strings.

### `lib/mix/tasks/rindle.runtime_status.ex`

**Analog:** `lib/mix/tasks/rindle.verify_storage.ex`, secondarily `lib/mix/tasks/rindle.regenerate_variants.ex`

Why it fits: both are thin Mix wrappers over hidden ops modules, with bounded filters, deterministic summaries, and exit semantics that do not turn every degraded row into a crash.

**Thin task wrapper pattern** (`lib/mix/tasks/rindle.verify_storage.ex:86-130`)
```elixir
{opts, _rest, _invalid} =
  OptionParser.parse(args, strict: [profile: :string, variant: :string])

filters =
  %{}
  |> maybe_put(:profile, Keyword.get(opts, :profile))
  |> maybe_put(:variant_name, Keyword.get(opts, :variant))

case VariantMaintenance.verify_storage(filters) do
  {:ok, report} -> ...
  {:error, reason} ->
    Mix.shell().error("Rindle.VerifyStorage failed: #{inspect(reason)}")
    System.halt(1)
end
```

**Command-shaped maintenance posture** (`lib/mix/tasks/rindle.regenerate_variants.ex:43-67`)
```elixir
Rindle: broad regeneration scan for stale/missing variants...
  enqueued: 12
  skipped:  3
  errors:   0
Done.
```

Planner note: there is no current JSON-output analog. Reuse the wrapper shape, but design `--format text|json` deliberately and keep text summary ordering deterministic per D-27.

### `lib/rindle.ex`

**Analog:** `lib/rindle.ex:427-480`

Why it fits: Phase 30 already established the public facade plus hidden `Rindle.Ops.*` split that Phase 31 wants to preserve.

**Public facade delegation pattern**
```elixir
@spec reprobe(MediaAsset.t() | binary()) ::
        {:ok, LifecycleRepair.reprobe_report()} | {:error, term()}
def reprobe(asset_or_id) do
  LifecycleRepair.reprobe_asset(asset_or_id)
end

@spec requeue_variants(MediaAsset.t() | binary(), keyword() | map()) ::
        {:ok, LifecycleRepair.requeue_report()} | {:error, term()}
def requeue_variants(asset_or_id, opts \\ []) do
  LifecycleRepair.requeue_failed_variants(asset_or_id, opts)
end
```

Use this same seam for `runtime_status/1` or `status_report/1`: public docs/specs on `Rindle`, implementation hidden under `Rindle.Ops.*`.

### `lib/rindle/ops/runtime_status.ex`

**Analog:** `lib/rindle/ops/variant_maintenance.ex`, secondarily `lib/rindle/ops/lifecycle_repair.ex`

Why it fits: the status report is a bounded query/reporting service, not a mutator. `VariantMaintenance.verify_storage/1` already shows the right filter-validation, accumulator, and report-counter style.

**Bounded filter validation** (`lib/rindle/ops/variant_maintenance.ex:150-224`)
```elixir
@allowed_filter_keys [:profile, :variant_name]

def verify_storage(filters) when is_map(filters) do
  with :ok <- validate_filters(filters) do
    do_verify_storage(filters)
  end
end
...
defp validate_filters(filters) do
  case Map.keys(filters) -- @allowed_filter_keys do
    [] -> :ok
    unknown -> {:error, {:unknown_filters, unknown}}
  end
end
```

**Report accumulator pattern** (`lib/rindle/ops/variant_maintenance.ex:157-197`)
```elixir
acc0 = %{checked: 0, present: 0, missing: 0, fsm_blocked: 0, errors: 0}

Enum.reduce(rows, acc0, fn row, acc ->
  process_check_object(row, acc)
end)
```

**Typed failure/report semantics** (`lib/rindle/ops/lifecycle_repair.ex:14-45`, `:209-258`)
```elixir
@type requeue_failure :: %{
  asset_id: binary(),
  variant_id: binary(),
  variant_name: binary(),
  state: binary(),
  failure_class: failure_class(),
  reason: requeue_failure_reason(),
  message: binary()
}
...
%{
  asset_id: asset_id,
  selected: selected_count,
  enqueued: 0,
  skipped: 0,
  errors: 0,
  failures: []
}
```

Planner note: there is no existing analog for a multi-section runtime report with counts, oldest age, and bounded examples. Reuse the counter-and-failure posture, but invent the section schema carefully and lock it in tests/docs.

### `lib/rindle/ops/runtime_checks.ex` or equivalent helper

**Analog:** `lib/mix/tasks/rindle.doctor.ex:54-144`

Why it fits: the current doctor keeps each validation narrowly focused and produces actionable failures. Move that shape behind an internal check module if doctor gains multiple stable check IDs.

**Check unit pattern**
```elixir
defp check_profile!(module, shell, env) do
  ...
  raise "profile #{inspect(module)} variant #{inspect(name)} failed runtime checks: #{inspect(reason)}"
end
```

Planner note: no existing module returns structured `%{id:, status:, message:, guidance:}` checks. That contract is new and must be designed, tested, and documented explicitly.

### `test/rindle/api_surface_boundary_test.exs`

**Analog:** `test/rindle/api_surface_boundary_test.exs:4-140`

Why it fits: Phase 30 already uses this file to freeze public-vs-hidden module visibility and facade exports.

**Boundary allowlist pattern**
```elixir
@public_modules [
  Rindle,
  ...
  Mix.Tasks.Rindle.RegenerateVariants,
  Mix.Tasks.Rindle.VerifyStorage,
  ...
]

@ops_hidden_modules [
  Rindle.Ops.LifecycleRepair,
  Rindle.Ops.MetadataBackfill,
  Rindle.Ops.UploadMaintenance,
  Rindle.Ops.VariantMaintenance,
  ...
]
```

Add `Mix.Tasks.Rindle.RuntimeStatus` to the public allowlist and keep any new `Rindle.Ops.Runtime*` modules hidden.

### `test/rindle/contracts/telemetry_contract_test.exs` + `guides/background_processing.md`

**Analog:** `test/rindle/contracts/telemetry_contract_test.exs:67-110`, `:248-399`; `guides/background_processing.md:163-215`

Why it fits: this is the existing source of truth for public telemetry names, required metadata, and docs linkage.

**Allowlist lock**
```elixir
@public_events [
  [:rindle, :upload, :start],
  ...
  [:rindle, :media, :transcode, :exception]
]
```

**Docs parity lock**
```elixir
guide = File.read!(@background_processing_path)
assert guide =~ "@public_events"
assert guide =~ "test/rindle/contracts/telemetry_contract_test.exs"
```

**No-extra-events guard**
```elixir
for {name, _meas, _meta} <- observed do
  assert name in @public_events
end
```

Planner note: Phase 31 wants additive runtime/repair telemetry with low-cardinality metadata, while the current transcode contract still exposes `asset_id` and `variant_id`. Keep the old allowlist intact, add a narrow new family, and do not silently repurpose existing high-cardinality events.

### `guides/operations.md` + `test/install_smoke/docs_parity_test.exs`

**Analog:** `guides/operations.md:31-62`, `:143-157`; `test/install_smoke/docs_parity_test.exs:94-106`, `:127-180`

Why it fits: operations docs already teach explicit operator verbs and the smoke/docs tests already lock public guidance to exact phrases.

**Explicit operator vocabulary pattern**
```md
- `reprobe` — `Rindle.reprobe/1` ...
- `requeue` — `Rindle.requeue_variants/2` ...
- `regenerate` — `mix rindle.regenerate_variants` ...
- `cleanup` — `mix rindle.cleanup_orphans` ...
- `sweep` — `mix rindle.sweep_orphaned_temp_files` ...
```

**Docs parity assertion pattern**
```elixir
assert doc =~ "mix rindle.doctor"
assert troubleshooting =~ "mix rindle.doctor"
assert troubleshooting =~ "Rindle.Error.message/1"
```

Use the same posture for Phase 31 language: doctor validates setup/drift, runtime status reports degradation, repair verbs mutate state.

### Oban-backed lifecycle corroboration

**Analogs:** `lib/rindle/workers/process_variant.ex`, `guides/background_processing.md`, `test/rindle/ops/upload_maintenance_test.exs`, `test/rindle/workers/maintenance_workers_test.exs`

Why they fit: Phase 31 needs to corroborate persisted lifecycle state with Oban/runtime evidence without making Oban the user-facing truth.

**Worker state + queue reality** (`lib/rindle/workers/process_variant.ex:18-20`, `:39-65`, `:147-163`)
```elixir
@av_queue :rindle_media
@av_timeout_ms :timer.minutes(10)
@unique_states [:available, :scheduled, :executing, :retryable]
...
%{"asset_id" => asset_id, "variant_name" => variant_name}
|> maybe_put_timeout(normalized_spec)
...
where: j.worker == "Rindle.Workers.ProcessVariant"
where: fragment("?->>'asset_id' = ?", j.args, ^asset_id)
```

**Oban ownership constraint** (`guides/background_processing.md:20-34`, `:43-63`, `:81-93`)
```md
Rindle ships Oban workers but does not start or supervise Oban itself.
...
adopters own the default Oban Repo.
```

**Service-vs-worker telemetry boundary** (`test/rindle/ops/upload_maintenance_test.exs:482-510`, `test/rindle/workers/maintenance_workers_test.exs:365-440`)
```elixir
assert {:ok, _report} = UploadMaintenance.cleanup_orphans(dry_run: true)
refute_received {[:rindle, :cleanup, :run], ^ref, _, _}
...
assert_received {[:rindle, :cleanup, :run], ^ref, measurements, metadata}
```

Planner note: keep status-report queries read-only and service-layer only unless a worker is genuinely performing work. Reporting modules should inspect Oban job state, queue names, and timeouts, but should not emit maintenance-worker telemetry as a side effect.

## Shared Patterns

### Facade + hidden ops split
**Source:** `lib/rindle.ex:427-480`, `test/rindle/api_surface_boundary_test.exs:55-140`

Apply to: new public runtime status API plus any internal `Rindle.Ops.Runtime*` modules.

### Deterministic Mix summaries
**Source:** `lib/mix/tasks/rindle.doctor.ex:36-50`, `lib/mix/tasks/rindle.verify_storage.ex:98-125`, `test/rindle/ops/sweep_orphaned_temp_files_test.exs:106-142`

Apply to: `mix rindle.doctor` expansion and `mix rindle.runtime_status` text mode.

### Bounded filter/query contract
**Source:** `lib/rindle/ops/variant_maintenance.ex:150-224`

Apply to: runtime status filters like `profile`, `older_than`, `limit`; reject unknown filters loudly.

### Telemetry contract is test-first and doc-linked
**Source:** `test/rindle/contracts/telemetry_contract_test.exs:67-110`, `guides/background_processing.md:165-215`

Apply to: new `[:rindle, :repair, ...]` and `[:rindle, :runtime, ...]` events.

### Worker evidence corroborates state, but does not replace it
**Source:** `lib/rindle/workers/process_variant.ex:88-139`, `guides/background_processing.md:104-156`

Apply to: stuck-work classification, queue-starved/orphan-suspect heuristics, and queue ownership checks.

## Missing Pattern Coverage

| Area | Gap | Planner caution |
| --- | --- | --- |
| Public runtime report API | No existing `Rindle.runtime_status/1` or equivalent report shape | Lock the report schema in tests before docs; avoid inventing an open-ended query DSL |
| Doctor check IDs | Current doctor emits ad-hoc strings, not stable check IDs | Introduce a structured internal check result contract and keep text rendering deterministic |
| JSON operator output | Existing Mix tasks are text-only | Design one renderer seam for text vs JSON so docs/tests lock both modes |
| Oban corroboration query | No current service joins persisted lifecycle rows to live `oban_jobs` health for read-only reporting | Reuse `ProcessVariant` queue/timeout/args facts, but add fresh query logic carefully |
| Telemetry family reset | Current public allowlist has no `:runtime` or `:repair` families | Extend contract additively; do not break existing allowlist |
| Sweep telemetry mismatch | `lib/rindle/ops/sweep_orphaned_temp_files.ex:37-48` emits `[:rindle, :media, :sweep_orphans, :stop]`, but `test/rindle/contracts/telemetry_contract_test.exs:67-79` does not bless it | Phase 31 should reconcile this under D-25: fold into repair telemetry or keep it internal, but do not let docs/tests drift |

## Metadata

**Analog search scope:** `lib/mix/tasks`, `lib/rindle`, `lib/rindle/ops`, `lib/rindle/workers`, `guides`, `test/rindle`, `test/install_smoke`, prior Phase 30/29 plans

**Key patterns identified:**
- Public adopter APIs live on `Rindle`; broad operator/reporting flows stay command-shaped and `Rindle.Ops.*` remains hidden.
- Query/report services return deterministic counters and typed failures, while Mix tasks stay thin and print stable summaries.
- Public telemetry is locked by contract tests tied directly to docs, and worker-side telemetry must not leak from pure service/reporting layers.
