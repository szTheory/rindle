# Phase 25: Rindle Processor AV - Pattern Map

**Mapped:** 2026-05-05
**Files analyzed:** 10
**Analogs found:** 10 / 10

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/rindle/processor/av.ex` | processor adapter | request-response + file-I/O | `lib/rindle/processor/image.ex` + `lib/rindle/processor/ffmpeg.ex` | role-match + low-level delegation match |
| `lib/rindle/processor/waveform.ex` | utility / processor helper | transform + file-I/O | `lib/rindle/processor/ffmpeg.ex` + `lib/rindle/probe/av_probe.ex` test shape via `test/rindle/probe/av_probe_test.exs` | partial |
| `lib/rindle/workers/process_variant.ex` | Oban worker | request-response + file-I/O + event-driven | self + `lib/rindle/workers/promote_asset.ex` | exact + state-machine match |
| `lib/rindle/ops/sweep_orphaned_temp_files.ex` | maintenance worker/service | batch + file-I/O | `lib/rindle/workers/cleanup_orphans.ex` + `lib/rindle/ops/orphan_reaper.ex` | exact role split |
| `test/rindle/processor/av_test.exs` | unit/integration test | file-I/O + subprocess | `test/rindle/processor/ffmpeg_test.exs` + `test/rindle/probe/av_probe_test.exs` | exact fixture/process pattern |
| `test/rindle/processor/waveform_test.exs` | unit/integration test | transform + file-I/O | `test/rindle/probe/av_probe_test.exs` | partial |
| `test/rindle/workers/process_variant_test.exs` | worker test | DB row + storage mock + state transition | self + `test/rindle/workers/promote_asset_test.exs` | exact + fixture enrichment match |
| `test/rindle/ops/sweep_orphaned_temp_files_test.exs` | service/worker test | tmpdir scan + threshold batch | `test/rindle/ops/orphan_reaper_test.exs` + `test/rindle/workers/maintenance_workers_test.exs` | exact |
| `test/rindle/profile/validator_test.exs` | compile-time DSL test | transform / validation | self | exact |
| `test/adopter/canonical_app/lifecycle_test.exs` | adopter parity / integration | end-to-end request-response + jobs | self | exact |

## Pattern Assignments

### `lib/rindle/processor/av.ex` (processor adapter, request-response + file-I/O)

**Analogs:** `lib/rindle/processor/image.ex`, `lib/rindle/processor/ffmpeg.ex`, `lib/rindle/processor.ex`

**Behaviour/import pattern** (`lib/rindle/processor.ex:1-20`, `lib/rindle/processor/image.ex:37-54`, `lib/rindle/processor/ffmpeg.ex:6-28`):

```elixir
@behaviour Rindle.Processor

@impl Rindle.Processor
@spec process(Path.t(), map(), Path.t()) :: {:ok, Path.t()} | {:error, term()}
def process(source_path, variant_spec, destination_path) do
  ...
  with ... do
    {:ok, destination_path}
  else
    {:error, reason} -> {:error, reason}
  end
end
```

**What to mirror:** Keep `Rindle.Processor.AV` as the public adapter boundary implementing the same `process/3` contract as `Image` and `Ffmpeg`. Storage stays out of the module; it only works on local paths.

**Low-level FFmpeg delegation pattern** (`lib/rindle/processor/ffmpeg.ex:13-24`):

```elixir
case build_args(source_path, variant_spec, destination_path) do
  {:ok, args} ->
    full_args = Subprocess.build_args("ffmpeg", args, [])
    command_str = Enum.join(["ffmpeg" | full_args], " ")

    with {:ok, _} <- Argv.validate(command_str) do
      case Subprocess.run("ffmpeg", args) do
        {_output, 0} -> {:ok, destination_path}
        {output, status} -> {:error, {:ffmpeg_failed, status, output}}
      end
    end
```

**What to mirror:** Preserve the `{:error, {:ffmpeg_failed, status, output}}` tuple shape and keep argv assembly/validation delegated down to the FFmpeg seam instead of leaking raw argv into the worker.

**Map-driven recipe normalization pattern** (`lib/rindle/processor/image.ex:41-54`):

```elixir
width = Map.get(variant_spec, :width)
height = Map.get(variant_spec, :height)
mode = Map.get(variant_spec, :mode, :fit)
format = Map.get(variant_spec, :format)

with {:ok, image} <- Image.open(source_path),
     {:ok, processed} <- apply_resize(image, width, height, mode),
     {:ok, _written} <- write_image(processed, destination_path, format, quality) do
  {:ok, destination_path}
end
```

**What to mirror:** Normalize the variant spec into plain locals first, then route by kind/preset with small private helpers. This matches the project’s preference for explicit plain-data transforms.

---

### `lib/rindle/processor/waveform.ex` (utility/helper, transform + file-I/O)

**Analogs:** `lib/rindle/processor/ffmpeg.ex`, `test/rindle/probe/av_probe_test.exs`

**FFmpeg subprocess/error pattern** (`lib/rindle/processor/ffmpeg.ex:13-24`):

```elixir
with {:ok, _} <- Argv.validate(command_str) do
  case Subprocess.run("ffmpeg", args) do
    {_output, 0} -> {:ok, destination_path}
    {output, status} -> {:error, {:ffmpeg_failed, status, output}}
  end
end
```

**Fixture-generation/test oracle pattern** (`test/rindle/probe/av_probe_test.exs:27-63`, `66-103`):

```elixir
path = Path.join(tmp_dir, "sample.mp3")
build_audio_fixture!(path)

assert {:ok, result} = AVProbe.probe(path)
assert result.kind == :audio
assert result.has_audio_track == true
```

**What to mirror:** Keep waveform extraction as a narrow helper that receives a local source path and emits a deterministic payload. Use real FFmpeg-generated fixtures in tests rather than stringly mock outputs where output structure matters.

**Contract guidance from validator analog** (`lib/rindle/profile/validator.ex:155-176`):

```elixir
@waveform_variant_schema [
  format: [type: {:in, [:json]}, default: :json],
  peaks: [type: :pos_integer, default: 1000],
  sample_rate: [type: {:or, [:pos_integer, nil]}, default: nil],
  channels: [type: {:in, [1, 2, nil]}, default: nil]
]
```

**What to mirror:** Phase 25 planning should narrow this public surface to the Phase 25 context contract (`length`, `sample_rate`, `peaks`) even if compatibility normalization remains internal.

---

### `lib/rindle/workers/process_variant.ex` (Oban worker, request-response + file-I/O + event-driven)

**Analogs:** `lib/rindle/workers/process_variant.ex`, `lib/rindle/workers/promote_asset.ex`

**Worker/module shape** (`lib/rindle/workers/process_variant.ex:1-20`):

```elixir
use Oban.Worker, queue: :rindle_process, max_attempts: 5

@impl Oban.Worker
def perform(%Oban.Job{args: %{"asset_id" => asset_id, "variant_name" => variant_name}}) do
  repo = Config.repo()

  with %MediaAsset{} = asset <- repo.get(MediaAsset, asset_id),
       %MediaVariant{} = variant <- get_variant(repo, asset_id, variant_name) do
    process(repo, asset, variant)
  else
    nil -> {:error, :not_found}
  end
end
```

**Core state-flow pattern** (`lib/rindle/workers/process_variant.ex:23-61`):

```elixir
with :ok <- transition_variant(repo, variant, "queued"),
     variant <- repo.get!(MediaVariant, variant.id),
     :ok <- transition_variant(repo, variant, "processing"),
     variant <- repo.get!(MediaVariant, variant.id),
     {:ok, source_tmp} <- download_source(asset),
     {:ok, dest_tmp} <- generate_dest_path(variant),
     {:ok, _} <- Image.process(source_tmp, variant_spec, dest_tmp),
     {:ok, storage_meta} <- upload_variant(asset, variant, dest_tmp) do
  ...
else
  {:error, reason} ->
    handle_failure(repo, variant, reason)
end
```

**What to mirror:** Keep the one-row/one-job lifecycle and `with`-chain sequencing. Phase 25 should extend this existing worker rather than wrapping it in a hidden multi-output pipeline.

**Transition helper pattern** (`lib/rindle/workers/process_variant.ex:74-80`, `lib/rindle/domain/variant_fsm.ex:19-38`):

```elixir
with :ok <- VariantFSM.transition(variant.state, target_state, %{variant_id: variant.id}),
     {:ok, _} <- variant |> MediaVariant.changeset(%{state: target_state}) |> repo.update() do
  :ok
else
  {:error, reason} -> {:error, reason}
end
```

**What to mirror:** Continue to gate every variant state write through `VariantFSM.transition/3`; do not write terminal states directly without FSM validation.

**Temp-root cleanup pattern to borrow from `PromoteAsset`** (`lib/rindle/workers/promote_asset.ex:107-123`, `172`):

```elixir
tmp_path = Path.join(tmp_dir(), "rindle_probe_#{Ecto.UUID.generate()}")

try do
  ...
after
  _ = File.rm(tmp_path)
end

defp tmp_dir, do: Application.get_env(:rindle, :tmp_dir, System.tmp_dir!())
```

**What to mirror:** Phase 25 should replace direct `System.tmp_dir!/0` calls in `download_source/1` and `generate_dest_path/1` with a single sweepable root under configured `tmp_dir()`, and cleanup should live in `try/after` or equivalent guaranteed-finalization paths.

**Failure-write pattern** (`lib/rindle/workers/process_variant.ex:110-115`):

```elixir
variant
|> MediaVariant.changeset(%{state: "failed", error_reason: inspect(reason)})
|> repo.update()

{:error, reason}
```

**What to mirror:** Preserve `inspect(reason)` storage and `{:error, reason}` return semantics so Oban retries and DB error_reason stay aligned.

---

### `lib/rindle/ops/sweep_orphaned_temp_files.ex` (maintenance worker/service, batch + file-I/O)

**Analogs:** `lib/rindle/workers/cleanup_orphans.ex`, `lib/rindle/workers/abort_incomplete_uploads.ex`, `lib/rindle/ops/orphan_reaper.ex`

**Worker delegation/observability pattern** (`lib/rindle/workers/cleanup_orphans.ex:59-133`):

```elixir
use Oban.Worker, queue: :rindle_maintenance, max_attempts: 3

def perform(%Oban.Job{args: args}) do
  dry_run? = Map.get(args, "dry_run", true)

  with {:ok, storage_mod} <- resolve_storage_adapter(args) do
    cleanup_opts = build_cleanup_opts(dry_run?, storage_mod)
    handle_cleanup_result(UploadMaintenance.cleanup_orphans(cleanup_opts), dry_run?, storage_mod)
  else
    {:error, reason} ->
      Logger.error("rindle.workers.cleanup_orphans.failed",
        reason: inspect(reason),
        stage: :resolve_storage_adapter
      )

      {:error, reason}
  end
end
```

**What to mirror:** `SweepOrphanedTempFiles` should stay thin: parse args, call a sweep function/service, log structured completion/failure events, return `:ok | {:error, reason}` for Oban retries.

**Batch scan/report pattern** (`lib/rindle/ops/orphan_reaper.ex:23-42`, `45-56`, `87-109`):

```elixir
report = %{
  files_scanned: 0,
  files_deleted: 0,
  errors: 0
}

if File.exists?(dir) do
  do_reap(dir, threshold_time, dry_run?, report)
else
  report
end
...
Logger.info("rindle.ops.orphan_reaper.deleted", path: path)
...
Application.get_env(:rindle, :tmp_dir, System.tmp_dir!())
```

**What to mirror:** Keep the report-map return style and configured tmp-root resolution, but Phase 25 should recurse through `Rindle.tmp/<uuid>/` directories instead of only top-level regular files.

**Telemetry pattern** (`lib/rindle/workers/cleanup_orphans.ex:100-124`, `lib/rindle/workers/abort_incomplete_uploads.ex:73-88`):

```elixir
:telemetry.execute(
  [:rindle, :cleanup, :run],
  %{sessions_deleted: report.sessions_deleted, objects_deleted: report.objects_deleted},
  %{profile: :unknown, adapter: storage_mod || :unknown, dry_run: dry_run?, worker: __MODULE__}
)
```

**What to mirror:** Emit an explicit cleanup telemetry event from the worker layer after a successful sweep. Use `worker: __MODULE__` metadata so the lane is attributable.

---

### `test/rindle/processor/av_test.exs` (processor test, file-I/O + subprocess)

**Analogs:** `test/rindle/processor/ffmpeg_test.exs`, `test/rindle/probe/av_probe_test.exs`

**Tmp-dir fixture pattern** (`test/rindle/processor/ffmpeg_test.exs:5-13`):

```elixir
@moduletag :tmp_dir

setup %{tmp_dir: tmp_dir} do
  source = Path.join(tmp_dir, "input.mp4")
  dest = Path.join(tmp_dir, "output.mp4")
  File.write!(source, "dummy")
  %{source: source, dest: dest}
end
```

**Real media fixture generation pattern** (`test/rindle/probe/av_probe_test.exs:66-103`):

```elixir
args = [
  "-y",
  "-f", "lavfi",
  "-i", "testsrc=size=16x16:rate=1:duration=0.2",
  "-f", "lavfi",
  "-i", "sine=frequency=1000:duration=0.2",
  "-c:v", "libx264",
  "-c:a", "aac",
  path
]

{_output, 0} = System.cmd("ffmpeg", args, stderr_to_stdout: true)
```

**What to mirror:** Use `@moduletag :tmp_dir` for file tests, but use real short FFmpeg fixtures when asserting AV outputs, poster selection, or normalization outputs. The existing `ffmpeg_test` dummy-file approach is only enough for smoke/error paths.

---

### `test/rindle/processor/waveform_test.exs` (processor/helper test, transform + file-I/O)

**Analog:** `test/rindle/probe/av_probe_test.exs`

**Assertion style** (`test/rindle/probe/av_probe_test.exs:32-41`, `48-55`):

```elixir
assert {:ok, result} = AVProbe.probe(path)
assert is_integer(result.duration_ms)
assert result.duration_ms >= 100
refute Map.has_key?(result, :width)
```

**What to mirror:** Keep assertions on shape and invariants, not exact low-level FFmpeg stderr. For waveform, assert bucket count, normalized float bounds, and deterministic contract keys.

---

### `test/rindle/workers/process_variant_test.exs` (worker test, DB row + storage mock + state transition)

**Analogs:** `test/rindle/workers/process_variant_test.exs`, `test/rindle/workers/promote_asset_test.exs`

**Baseline worker test shape** (`test/rindle/workers/process_variant_test.exs:12-89`):

```elixir
defmodule TestProfile do
  use Rindle.Profile,
    storage: Rindle.StorageMock,
    variants: [
      thumb: [mode: :crop, width: 10, height: 10]
    ],
    allow_mime: ["image/jpeg"],
    max_bytes: 10_485_760
end

assert :ok = perform_job(ProcessVariant, %{"asset_id" => asset.id, "variant_name" => "thumb"})

variant = Rindle.Repo.get!(MediaVariant, variant.id)
assert variant.state == "ready"
assert variant.storage_key =~ asset.id
```

**Tmpdir/env override + fixture helpers** (`test/rindle/workers/promote_asset_test.exs:95-121`, `259-325`):

```elixir
tmp_dir = Path.join(System.tmp_dir!(), "rindle-promote-asset-#{System.unique_integer([:positive])}")
File.mkdir_p!(tmp_dir)
previous_tmp_dir = Application.get_env(:rindle, :tmp_dir)
Application.put_env(:rindle, :tmp_dir, tmp_dir)
...
defp probe_tempfiles(dir) do
  case File.ls(dir) do
    {:ok, files} -> Enum.filter(files, &String.starts_with?(&1, "rindle_probe_"))
    _ -> []
  end
end
```

**What to mirror:** Extend `ProcessVariantTest` the same way for AV jobs: create a temp root via `Application.put_env(:rindle, :tmp_dir, tmp_dir)`, use real FFmpeg-built fixtures, and assert both DB terminal state and tempfile cleanup behavior.

**AV typed-field assertion pattern** (`test/rindle/workers/promote_asset_test.exs:162-195`):

```elixir
asset = Rindle.Repo.get!(MediaAsset, asset.id)
assert asset.kind == "video"
assert asset.width == 16
assert asset.height == 16
assert is_integer(asset.duration_ms)
assert asset.has_audio_track == true
```

**What to mirror:** For AV variant processing, assert typed output columns on `MediaVariant` rows (`output_kind`, `duration_ms`, `width`, `height`, `content_type`) instead of only `storage_key` and `byte_size`.

---

### `test/rindle/ops/sweep_orphaned_temp_files_test.exs` (ops/worker test, tmpdir scan + threshold batch)

**Analogs:** `test/rindle/ops/orphan_reaper_test.exs`, `test/rindle/workers/maintenance_workers_test.exs`

**Tmpdir aging test pattern** (`test/rindle/ops/orphan_reaper_test.exs:5-79`):

```elixir
@moduletag :tmp_dir

setup %{tmp_dir: tmp_dir} do
  now = System.system_time(:second)
  old_file = Path.join(tmp_dir, "old.tmp")
  File.write!(old_file, "old")
  File.touch!(old_file, now - 48 * 3600)
  %{tmp_dir: tmp_dir, old_file: old_file}
end

report = OrphanReaper.reap(dir: tmp_dir, threshold_sec: 24 * 3600, dry_run: true)
assert report.files_deleted == 0
```

**Worker delegation assertions** (`test/rindle/workers/maintenance_workers_test.exs:124-189`):

```elixir
assert :ok =
         perform_job(CleanupOrphans, %{
           "dry_run" => false,
           "storage" => to_string(Rindle.StorageMock)
         })

opts = CleanupOrphans.__opts__()
assert Keyword.get(opts, :queue) == :rindle_maintenance
assert Keyword.get(opts, :max_attempts) >= 1
```

**What to mirror:** Cover both service-level sweep behavior and worker wrapper behavior. For the new AV sweeper, add nested-directory cases (`Rindle.tmp/<uuid>/...`) plus queue/max_attempts/default-dry-run assertions.

---

### `test/rindle/profile/validator_test.exs` (compile-time DSL test, transform / validation)

**Analogs:** `test/rindle/profile/validator_test.exs`, `lib/rindle/profile/validator.ex`

**Compile-time recipe validation pattern** (`test/rindle/profile/validator_test.exs:39-79`, `129-228`):

```elixir
mod = compile_profile("""
storage: Rindle.StorageMock,
variants: [hero: [kind: :video, preset: :web_720p]],
allow_mime: ["video/mp4"],
allow_extensions: [".mp4"]
""")

hero = mod.variants()[:hero]
assert hero[:kind] == :video
assert hero[:preset] == :web_720p
assert hero[:codec] == :h264
```

**Kind-dispatch implementation pattern** (`lib/rindle/profile/validator.ex:293-367`):

```elixir
{kind, kind_explicit?, rest} = pop_kind!(name, normalized)
schema = schema_for_kind(kind)

validated_kw =
  rest
  |> NimbleOptions.validate!(schema)
  |> Keyword.new()

validated_kw
|> Enum.reject(fn {_key, value} -> is_nil(value) end)
|> Map.new()
|> maybe_put_kind(kind, kind_explicit?)
```

**What to mirror:** If Phase 25 narrows the waveform public contract, extend these compile-time tests first. The established pattern is `assert_raise ArgumentError` around `Code.compile_string/1` for rejected keys and direct `mod.variants()[:name]` assertions for normalized defaults.

---

### `test/adopter/canonical_app/lifecycle_test.exs` (adopter parity/integration, end-to-end + jobs)

**Analog:** `test/adopter/canonical_app/lifecycle_test.exs`

**Canonical worker-driving pattern** (`test/adopter/canonical_app/lifecycle_test.exs:126-165`, `229-255`):

```elixir
{:ok, %{session: completed, asset: asset}} = Broker.verify_completion(session.id)
assert_enqueued(worker: PromoteAsset, args: %{"asset_id" => asset.id})

assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})

for variant <- variants do
  assert :ok =
           perform_job(ProcessVariant, %{
             "asset_id" => asset.id,
             "variant_name" => variant.name
           })
end

assert Enum.all?(ready_variants, &(&1.state == "ready"))
```

**Backward-compat parity assertion pattern** (`test/adopter/canonical_app/lifecycle_test.exs:292-312`):

```elixir
thumb = AdopterProfile.variants()[:thumb]
refute Map.has_key?(thumb, :kind)
assert AdopterProfile.recipe_digest(:thumb) == @v13_thumb_digest
```

**What to mirror:** Add Phase 25 adopter parity in this file rather than inventing a separate integration harness. Keep the pattern of running real jobs synchronously and asserting public API-visible outcomes.

## Shared Patterns

### Processor Contract
**Source:** `lib/rindle/processor.ex:1-20`
**Apply to:** `lib/rindle/processor/av.ex`, `lib/rindle/processor/waveform.ex`

```elixir
@callback process(source :: Path.t(), variant_spec :: map(), destination :: Path.t()) ::
            {:ok, Path.t()} | {:error, term()}
```

### Asset/Variant FSM Gating
**Source:** `lib/rindle/domain/asset_fsm.ex:6-19`, `33-52`; `lib/rindle/domain/variant_fsm.ex:4-37`
**Apply to:** `lib/rindle/workers/process_variant.ex` and any aggregate-state recompute helper

```elixir
"available" => ["processing", "transcoding", "quarantined"],
"transcoding" => ["ready", "degraded", "quarantined"]
...
"processing" => ["ready", "failed", "cancelled"]
```

**What to mirror:** AV work must use the already-added `transcoding` asset state and the existing variant terminal states rather than inventing new ad hoc flags.

### Temp Root Resolution
**Source:** `lib/rindle/workers/promote_asset.ex:107-123`, `172`; `lib/rindle/ops/orphan_reaper.ex:108-109`
**Apply to:** AV worker tempfiles and orphan tempfile sweeper

```elixir
tmp_path = Path.join(tmp_dir(), "rindle_probe_#{Ecto.UUID.generate()}")
...
defp tmp_dir, do: Application.get_env(:rindle, :tmp_dir, System.tmp_dir!())
```

**What to mirror:** Resolve all AV tempfiles from configured `:tmp_dir`; Phase 25’s new `Rindle.tmp/<uuid>/` subtree should hang under this same root so cleanup workers can sweep it deterministically.

### Schema Write Pattern
**Source:** `lib/rindle/domain/media_asset.ex:91-115`, `lib/rindle/domain/media_variant.ex:68-90`
**Apply to:** typed AV metadata persisted by worker updates

```elixir
|> cast(attrs, [..., :content_type, :byte_size, :error_reason, :output_kind, :duration_ms, :width, :height])
|> validate_required([...])
|> validate_inclusion(:state, @states)
|> validate_inclusion(:output_kind, @output_kinds)
```

**What to mirror:** Persist typed AV output columns through existing changesets; do not bypass them with raw repo updates except where a deliberate `update_all` test setup already does.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| none | - | - | Phase 25 has strong local analogs for all targeted files; only waveform JSON shaping is new, but it still fits existing FFmpeg helper and AV fixture patterns. |

## Metadata

**Analog search scope:** `lib/rindle/workers`, `lib/rindle/processor`, `lib/rindle/ops`, `lib/rindle/domain`, `lib/rindle/profile`, `test/rindle/workers`, `test/rindle/processor`, `test/rindle/ops`, `test/rindle/profile`, `test/adopter/canonical_app`
**Files scanned:** 20+
**Pattern extraction date:** 2026-05-05
