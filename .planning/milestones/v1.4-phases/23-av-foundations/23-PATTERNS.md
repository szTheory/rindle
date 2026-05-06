# Phase 23: AV Foundations - Pattern Map

**Mapped:** 2024-05-02
**Files analyzed:** 6
**Analogs found:** 5 / 6

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/mix/tasks/rindle.doctor.ex` | mix task | command execution | `lib/mix/tasks/rindle.verify_storage.ex` | exact |
| `lib/rindle/processor/ffmpeg.ex` | adapter | file I/O | `lib/rindle/processor/image.ex` | exact |
| `lib/rindle/security/argv.ex` | security utility | validation | `lib/rindle/security/filename.ex` | exact |
| `lib/rindle/av/probe.ex` | ops utility | synchronous check | `lib/rindle/ops/upload_maintenance.ex` | role-match |
| `lib/rindle/av/capability.ex` | domain | configuration | `lib/rindle/processor.ex` | partial |
| `lib/rindle/av/subprocess.ex` | utility | subprocess execution | None | none |

## Pattern Assignments

### `lib/mix/tasks/rindle.doctor.ex` (mix task, command execution)

**Analog:** `lib/mix/tasks/rindle.verify_storage.ex`

**Imports pattern** (lines 47-52):
```elixir
  use Mix.Task

  alias Rindle.Ops.VariantMaintenance

  @requirements ["app.start"]
```

**Core Execution pattern** (lines 54-68):
```elixir
  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [profile: :string, variant: :string]
      )

    filters =
      %{}
      |> maybe_put(:profile, Keyword.get(opts, :profile))
      |> maybe_put(:variant_name, Keyword.get(opts, :variant))

    Mix.shell().info("Rindle: verifying storage for variants...")
```

**Output and Exit pattern** (lines 79-96):
```elixir
        Mix.shell().info("  checked:      #{checked}")
        Mix.shell().info("  present:      #{present}")
        # ...
        Mix.shell().info("Done.")

        if errors > 0 do
          Mix.shell().error("#{errors} storage error(s) during verification")
          System.halt(1)
        end

      {:error, reason} ->
        Mix.shell().error("Rindle.VerifyStorage failed: #{inspect(reason)}")
        System.halt(1)
    end
```

---

### `lib/rindle/processor/ffmpeg.ex` (adapter, file I/O)

**Analog:** `lib/rindle/processor/image.ex`

**Behaviour pattern** (lines 33-36):
```elixir
  @behaviour Rindle.Processor

  @impl Rindle.Processor
  @spec process(Path.t(), map(), Path.t()) :: {:ok, Path.t()} | {:error, term()}
```

**Core processing pattern** (lines 37-47):
```elixir
  def process(source_path, variant_spec, destination_path) do
    width = Map.get(variant_spec, :width)
    height = Map.get(variant_spec, :height)
    mode = Map.get(variant_spec, :mode, :fit)
    format = Map.get(variant_spec, :format)
    quality = Map.get(variant_spec, :quality, 80)

    with {:ok, image} <- Image.open(source_path),
         {:ok, processed} <- apply_resize(image, width, height, mode),
         {:ok, _written} <- write_image(processed, destination_path, format, quality) do
      {:ok, destination_path}
    else
      {:error, reason} -> {:error, reason}
    end
  end
```

---

### `lib/rindle/security/argv.ex` (security utility, validation)

**Analog:** `lib/rindle/security/filename.ex`

**Module structure pattern** (lines 1-7):
```elixir
defmodule Rindle.Security.Filename do
  @moduledoc false

  @default_filename "upload"

  @spec sanitize(String.t()) :: String.t()
  def sanitize(filename) do
```

**Core validation pattern** (lines 7-14):
```elixir
  def sanitize(filename) do
    filename
    |> Path.basename()
    |> String.replace(~r/[\x00-\x1F\x7F]/u, "")
    |> String.replace(~r{[/\\]+}u, "_")
    |> String.replace(~r/[^A-Za-z0-9._-]/u, "_")
    |> String.replace(~r/_+/u, "_")
    |> String.trim("_")
    |> fallback_filename()
  end
```

---

### `lib/rindle/av/probe.ex` (ops utility, synchronous check)

**Analog:** `lib/rindle/ops/upload_maintenance.ex`

**Module definition pattern** (lines 1-7):
```elixir
defmodule Rindle.Ops.UploadMaintenance do
  @moduledoc false

  require Logger

  import Ecto.Query
```

**API returning generic success/error** (lines 37-45):
```elixir
  @spec cleanup_orphans(keyword()) :: {:ok, cleanup_report()} | {:error, term()}
  def cleanup_orphans(opts \\ []) do
    dry_run? = Keyword.get(opts, :dry_run, true)
    storage_mod = Keyword.get(opts, :storage, Application.get_env(:rindle, :default_storage))

    case fetch_expired_sessions() do
      {:ok, sessions} ->
        report = process_cleanup(sessions, dry_run?, storage_mod)
        {:ok, report}
```

---

### `lib/rindle/av/capability.ex` (domain, configuration)

**Analog:** `lib/rindle/processor.ex`

**Domain structure pattern** (lines 1-8):
```elixir
defmodule Rindle.Processor do
  @moduledoc """
  Behaviour contract for media processors that generate variants.

  Implementations may read from and write to storage paths, but storage I/O
  must never occur inside database transactions.
  """
```

## Shared Patterns

### Error Handling
**Source:** `lib/mix/tasks/rindle.verify_storage.ex`
**Apply to:** All mix tasks and ops
```elixir
        if errors > 0 do
          Mix.shell().error("#{errors} storage error(s) during verification")
          System.halt(1)
        end
```

## No Analog Found

Files with no close match in the codebase (planner should use RESEARCH.md patterns instead):

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `lib/rindle/av/subprocess.ex` | utility | subprocess execution | First usage of MuonTrap in the codebase. Requires strict resource capping which has no prior equivalent. |

## Metadata

**Analog search scope:** `lib/mix/tasks/`, `lib/rindle/processor/`, `lib/rindle/security/`, `lib/rindle/ops/`
**Files scanned:** 9
**Pattern extraction date:** 2024-05-02
