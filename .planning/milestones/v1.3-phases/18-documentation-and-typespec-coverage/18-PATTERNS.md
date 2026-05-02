# Phase 18: Documentation and Typespec Coverage - Pattern Map

**Mapped:** 2026-04-30
**Files analyzed:** 26 (modified) + 4 (created) = 30 total
**Analogs found:** 30 / 30 (every file has a strong in-repo analog)

This phase is a **documentation and typespec sweep** — almost every file change copies a pattern that already exists in the same codebase. The analog set is unusually concentrated:

- `lib/rindle/delivery.ex` is the **gold-standard public-module template** (every public function has `@doc` + `@spec`; module has `@moduledoc` + `@type`). Plans 18-02 / 18-03 / 18-04 are essentially "make every other public module match Delivery's posture."
- `lib/rindle/domain/media_asset.ex` (and the four sibling schemas) are the canonical `@type t :: %__MODULE__{}` analog that Plan 18-02's named-type tightening references.
- `test/rindle/api_surface_boundary_test.exs` is the canonical `Code.fetch_docs/1` analog — Plan 18-03's `behaviour_docs_test.exs` reuses the exact `fetch_docs!/1` helper shape.
- `.credo.exs` is the closest analog for the new `.doctor.exs` (config-as-Elixir, list-of-modules, `:dev/:test`-only tooling).
- `.github/workflows/ci.yml` already has a `mix credo --strict` step that the new `mix doctor --full --raise` step copies structurally.

## File Classification

### New files (created in Plans 18-01 and 18-03)

| File | Role | Data Flow | Closest Analog | Match Quality |
|------|------|-----------|----------------|---------------|
| `.doctor.exs` | config | static-config | `.credo.exs` | role-match (both: Elixir-config, dev/test tooling, ignore-list shape) |
| `mix.lock` | dep-lock | (auto) | (none — auto-managed by `mix deps.get`) | n/a |
| `test/rindle/doctor_thresholds_test.exs` | test | request-response | `test/rindle/config/config_test.exs` | role-match (both: assert config values; small flat ExUnit; reads project config) |
| `test/rindle/behaviour_docs_test.exs` | test | request-response | `test/rindle/api_surface_boundary_test.exs` | exact (both: `Code.fetch_docs/1` introspection; iterate behaviour modules; doc state assertion) |

### Modified files — facade / behaviour / public modules (Plans 18-02, 18-03, 18-04)

| File | Role | Data Flow | Closest Analog | Match Quality |
|------|------|-----------|----------------|---------------|
| `mix.exs` | config | static-config | `mix.exs` lines 89-90 (existing `:credo` / `:dialyxir` deps) | exact (same dep shape) |
| `.github/workflows/ci.yml` | CI | request-response | line 84-85 of itself (`mix credo --strict` step) | exact (same step shape, same matrix) |
| `lib/rindle.ex` | facade | request-response | `lib/rindle/delivery.ex` | exact (both: public facade, every public fn has `@doc` + `@spec`, schema-typed returns) |
| `lib/rindle/upload/broker.ex` | facade | request-response | `lib/rindle/delivery.ex` | exact |
| `lib/rindle/storage.ex` | behaviour | request-response | `lib/rindle/storage.ex` lines 71-76 (existing `capabilities/0` `@doc` + `@callback`) | exact (same module — extend the existing pattern) |
| `lib/rindle/authorizer.ex` | behaviour | request-response | `lib/rindle/storage.ex:71-76` (capabilities `@doc` + `@callback`) | exact |
| `lib/rindle/analyzer.ex` | behaviour | request-response | `lib/rindle/storage.ex:71-76` | exact |
| `lib/rindle/scanner.ex` | behaviour | request-response | `lib/rindle/storage.ex:71-76` | exact |
| `lib/rindle/processor.ex` | behaviour | request-response | `lib/rindle/storage.ex:71-76` | exact |
| `lib/rindle/processor/image.ex` | adapter | request-response | `lib/rindle/storage/local.ex` | exact (both: bundled reference adapter for a behaviour, `@impl true` posture) |
| `lib/rindle/profile.ex` | macro | meta/transform | `lib/rindle/profile.ex:39-67` (existing `@spec`s inside `quote do`) | role-match (`__using__/1` is the macro variant) |
| `lib/rindle/html.ex` | optional integration | request-response | `lib/rindle/delivery.ex` (function `@doc`s with `## Options` / `## Example`) | exact |
| `lib/rindle/live_view.ex` | optional integration | (verify only) | already complete | n/a |
| `lib/rindle/workers/abort_incomplete_uploads.ex` | worker | event-driven | `lib/rindle/workers/abort_incomplete_uploads.ex` itself (already rich `@moduledoc` + `@impl Oban.Worker`) | exact (just add optional `@spec`) |
| `lib/rindle/workers/cleanup_orphans.ex` | worker | event-driven | sibling worker (same posture) | exact |
| `lib/mix/tasks/rindle.abort_incomplete_uploads.ex` | mix task | request-response | itself (already correct `@shortdoc` + `@moduledoc` + `@impl Mix.Task`) | exact (verify only) |
| `lib/mix/tasks/rindle.backfill_metadata.ex` | mix task | request-response | sibling task | exact (verify only) |
| `lib/mix/tasks/rindle.cleanup_orphans.ex` | mix task | request-response | sibling task | exact (verify only) |
| `lib/mix/tasks/rindle.regenerate_variants.ex` | mix task | request-response | sibling task | exact (verify only) |
| `lib/mix/tasks/rindle.verify_storage.ex` | mix task | request-response | sibling task | exact (verify only) |
| `lib/rindle/storage/local.ex` | adapter | (verify only) | already correct `@impl true` posture | n/a |
| `lib/rindle/storage/s3.ex` | adapter | (verify only) | already correct | n/a |
| `lib/rindle/domain/*.ex` (5 schemas) | schema | (verify only) | already complete | n/a |
| `test/rindle/api_surface_boundary_test.exs` | test | request-response | itself (extend `@public_modules`) | exact |
| `README.md` | docs | static | (none — single-line addition under existing structure) | n/a |
| `CHANGELOG.md` | docs | static | existing entries | exact |

## Pattern Assignments

### `lib/rindle.ex` — facade `@spec` tightening + `@deprecated` shim (Plans 18-02 + 18-04)

**Analog:** `lib/rindle/delivery.ex` (the gold-standard reference)

**Moduledoc + alias + type pattern** (`delivery.ex:1-12`):
```elixir
defmodule Rindle.Delivery do
  @moduledoc """
  Delivery policy and URL resolution helpers.

  Private delivery is the default. Public delivery is an explicit profile opt-in,
  and authorization (when configured) runs before any URL is issued.
  """

  alias Rindle.Domain.StalePolicy
  alias Rindle.Storage.Capabilities

  @type delivery_mode :: :public | :private
```

**Per-function `@doc` + `@spec` + Examples block — schema-typed return** (`delivery.ex:81-117`):
```elixir
@doc """
Returns a deliverable URL for an asset's storage key.

Public profiles return the storage adapter's bare URL; private profiles
return a signed URL with the profile's configured TTL. Emits
`[:rindle, :delivery, :signed]` telemetry on success.

## Examples

    # Requires a configured storage adapter and a key that exists in storage.
    iex> {:ok, url} = Rindle.Delivery.url(MyApp.MediaProfile, "uploads/abc.png")
    iex> is_binary(url)
    true

"""
@spec url(module(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
def url(profile, key, opts \\ []) do
  ...
end
```

**Schema-typed return template** (the shape Plan 18-02 copies into 8 `@spec`s in `lib/rindle.ex`):
- Replace `{:ok, map()}` / `{:ok, struct()}` with `{:ok, MediaAsset.t()}` / `{:ok, MediaUploadSession.t()}` / `{:ok, MediaAttachment.t()}` / `{:ok, Broker.verify_result()}` etc.
- Schema struct types are already declared at `lib/rindle/domain/media_asset.ex:47` (`@type t :: %__MODULE__{}`) and the four sibling schemas — no new declarations needed.
- **Keep** `{:error, term()}` on the error branch (per CONTEXT.md `<specifics>` — narrowing is a Dialyzer-breaking change).

**`@deprecated` shim pattern (D-16, Plan 18-04 — existing analog at `rindle.ex:102` for `@doc deprecated:`):**

The current `@doc deprecated: "Use verify_completion/2"` at `rindle.ex:102` (D-17 / visible-shim) is the **soft** deprecation. The new `@deprecated "..."` attribute (D-16 / hidden-shim) is the **compiler-warning** deprecation. They coexist on different shims:

Existing (visible) at `lib/rindle.ex:102-103`:
```elixir
@doc deprecated: "Use verify_completion/2"
@doc """
Verifies a direct upload completion through the broker.
...
```

New (hidden, to add at `lib/rindle.ex:482`, one line above the existing `@doc false`):
```elixir
@deprecated "Use Rindle.Internal.VariantFailureLogger.log/3 instead — facade shim kept for 0.1.x compatibility only"
@doc false
@spec log_variant_processing_failure(term(), term(), term()) :: :ok
def log_variant_processing_failure(asset_id, variant_name, reason) do
```

---

### `lib/rindle/upload/broker.ex` — 6 missing `@spec`s + named-type aliases (Plans 18-02 + 18-03)

**Analog:** `lib/rindle/delivery.ex` (function-level pattern) + `lib/rindle.ex:21-22` (module-level `@type` alias pattern)

**Module-level named-type alias pattern** (`rindle.ex:21-22`):
```elixir
@typedoc "Tagged storage result shape: {:ok, result} | {:error, reason}"
@type storage_result :: {:ok, term()} | {:error, term()}
```

Plan 18-02 follows the same shape but with named multi-key result types (D-05) — see RESEARCH.md "Per-File Implementation Sketch" for the full 6-type proposal. The module-attribute placement convention: declare types after module attributes (e.g. after `@default_multipart_part_size` at `broker.ex:12`), before the first `@doc`.

**Existing `@doc` shape on broker functions is correct** (`broker.ex:14-28`):
```elixir
@doc """
Initiates a new direct upload session.

Creates a staged `MediaAsset` and an `initialized` `MediaUploadSession` in
a single DB transaction, then emits `[:rindle, :upload, :start]`
telemetry AFTER commit.

## Examples

    # Requires `config :rindle, :repo, MyApp.Repo` and a profile module.
    iex> {:ok, session} = Rindle.Upload.Broker.initiate_session(MyApp.MediaProfile, filename: "photo.png")
    iex> session.state
    "initialized"

"""
def initiate_session(profile_module, opts \\ []) do
```

Plan 18-03 inserts an `@spec` line **between** the `@doc """..."""` block and the `def` — same placement Delivery uses (`delivery.ex:23,24,25`).

---

### `lib/rindle/storage.ex` — per-callback `@doc` + named result types (Plans 18-02 + 18-03)

**Analog:** `lib/rindle/storage.ex:71-76` (the existing `capabilities/0` callback already follows the target pattern — extend it to the other 10 callbacks)

**Existing pattern (already in the file, copy 10×)** (`storage.ex:71-76`):
```elixir
@doc """
Returns the adapter's supported capability atoms.

Values must come from `t:capability/0`.
"""
@callback capabilities() :: [capability()]
```

**Existing `@typedoc` + `@type` declaration** (`storage.ex:10-24`) is the structural template for the 8 new behaviour-level result types from D-04:
```elixir
@typedoc """
Shared storage capability vocabulary exposed by adapters via `c:capabilities/0`.
...
"""
@type capability ::
        :presigned_put
        | :multipart_upload
        ...
```

Plan 18-02 inserts 8 new `@type` declarations (`put_result/0`, `delete_result/0`, `url_result/0`, `presign_result/0`, `multipart_init_result/0`, `multipart_complete_result/0`, `head_result/0`) above line 17 using the same `@typedoc` + `@type` pattern. Each `@callback` then references the named type — see RESEARCH.md "Rewritten @callbacks" section for exact shapes.

---

### `lib/rindle/authorizer.ex`, `analyzer.ex`, `scanner.ex`, `processor.ex` — single-callback behaviours (Plan 18-03)

**Analog:** `lib/rindle/storage.ex:71-76` (existing `capabilities/0`)

These four files are **structurally identical** — each has a `@moduledoc`, then a single `@callback` at line 9 with no preceding `@doc`. Plan 18-03 inserts `@doc """..."""` immediately above each `@callback`, copying the exact placement shown in `storage.ex:71-76`.

Existing posture in `lib/rindle/authorizer.ex:1-11`:
```elixir
defmodule Rindle.Authorizer do
  @moduledoc """
  Behaviour contract for delivery authorization hooks.

  Authorization decisions must be made before URL issuance, and any storage I/O
  involved in delivery should occur outside database transactions.
  """

  @callback authorize(actor :: term(), action :: atom(), subject :: term()) ::
              :ok | {:error, :unauthorized | term()}
end
```

Target posture (insert `@doc """..."""` between `@moduledoc` close and `@callback`):
```elixir
@doc """
Authorizes a delivery action for an actor against a subject.

Implementations should return `:ok` to permit the action or `{:error, :unauthorized}`
(or another term) to deny it. Authorization runs before any URL is issued and
before any storage I/O is attempted.
"""
@callback authorize(actor :: term(), action :: atom(), subject :: term()) ::
            :ok | {:error, :unauthorized | term()}
```

Same template for `analyze/1`, `scan/1`, `process/3` — see RESEARCH.md sketch.

---

### `lib/rindle/processor/image.ex` — promote to public adapter (Plan 18-03, D-27)

**Analog:** `lib/rindle/storage/local.ex` (the symmetric "bundled reference adapter" pattern)

**`@impl true` adapter posture from Local** (`local.ex:1-18`):
```elixir
defmodule Rindle.Storage.Local do
  @moduledoc """
  Local filesystem storage adapter.
  """

  @behaviour Rindle.Storage

  @impl true
  def store(key, source_path, opts) do
    destination_path = storage_path(key, opts)

    with :ok <- File.mkdir_p(Path.dirname(destination_path)),
         :ok <- File.cp(source_path, destination_path) do
      {:ok, %{key: key, path: destination_path}}
    else
      {:error, reason} -> {:error, reason}
    end
  end
```

Plan 18-03 changes for `image.ex`:
1. Expand `@moduledoc` from the current 3-line stub (`image.ex:2-4`) to document recognized `variant_spec` keys (`:width`, `:height`, `:mode`, `:format`, `:quality`) and supported modes (`:fit`, `:crop`, `:fill`).
2. Replace the existing `@doc """Processes an image..."""` (`image.ex:8-10`) — note that on `@impl` callback implementations, `@doc` is intentionally omitted (per D-11: "do not duplicate `@doc` on `@impl` callback implementations"). Instead, add `@impl Rindle.Processor` (qualified form is acceptable here for clarity) above `process/3`.
3. Add `@spec process(Path.t(), map(), Path.t()) :: {:ok, Path.t()} | {:error, term()}` (matches `Rindle.Processor` callback contract).

Target shape (mirroring Local):
```elixir
defmodule Rindle.Processor.Image do
  @moduledoc """
  Image processor adapter using the Image library (powered by libvips/Vix).

  ## Recognized variant_spec keys
  ...
  ## Supported modes
  ...
  ## Format inference
  ...
  """

  @behaviour Rindle.Processor

  @impl Rindle.Processor
  @spec process(Path.t(), map(), Path.t()) :: {:ok, Path.t()} | {:error, term()}
  def process(source_path, variant_spec, destination_path) do
```

---

### `lib/rindle/profile.ex` — `__using__/1` doc + spec (Plan 18-04, D-14)

**Analog:** Internal `@spec`s already inside the `quote do` block at `profile.ex:39,42,49,52,58,61` (the project already commits to this `@spec __using__-generated functions__` discipline).

Existing internal-spec pattern (`profile.ex:39-40`):
```elixir
@spec storage_adapter() :: module()
def storage_adapter, do: @rindle_storage
```

Plan 18-04 adds the **outer** macro `@doc` + `@spec` (currently missing at line 14-15):
```elixir
@doc """
Declares a Rindle profile.

When `use`d, this macro validates the supplied options at compile time and
generates the `storage_adapter/0`, `variants/0`, `upload_policy/0`,
`validate_upload/1`, `delivery_policy/0`, and `recipe_digest/1` functions
that the rest of Rindle dispatches through.

## Example

    defmodule MyApp.AvatarProfile do
      use Rindle.Profile,
        storage: Rindle.Storage.S3,
        ...
    end
"""
@spec __using__(keyword()) :: Macro.t()
defmacro __using__(opts) do
```

(External precedent for `@spec __using__(any) :: Macro.t()`: `thousand_island/handler.ex` per CONTEXT.md canonical refs.)

---

### `lib/rindle/html.ex` — `picture_tag/3` `@doc` (Plan 18-04, D-15)

**Analog:** `lib/rindle/delivery.ex:81-95` (function with `## Options` / `## Examples` doc structure + already-correct `@spec`)

The function already has `@spec` at `html.ex:12`; Plan 18-04 only inserts `@doc """..."""` immediately above it. Copy the doc structure (description → `## Options` → `## Example`) from Delivery's `url/3` doc block.

---

### `lib/rindle/workers/*.ex` — optional `@spec perform/1` (Plan 18-04, D-13)

**Analog:** `lib/rindle/workers/abort_incomplete_uploads.ex:71-72` itself (current shape)

Existing posture (already correct on `@moduledoc` + `@impl Oban.Worker`):
```elixir
@impl Oban.Worker
def perform(%Oban.Job{}) do
```

Plan 18-04 optionally inserts a narrowing `@spec` between `@impl` and `def`:
```elixir
@spec perform(Oban.Job.t()) :: :ok | {:error, term()}
@impl Oban.Worker
def perform(%Oban.Job{}) do
```

Per D-13 / RESEARCH R-13: do NOT add `@doc` to `perform/1` (none currently exists; the rich `@moduledoc` is the contract source). Same template applies to `cleanup_orphans.ex:65`.

---

### `lib/mix/tasks/rindle.*.ex` — verify-only (Plan 18-04, D-12)

**Analog:** `lib/mix/tasks/rindle.abort_incomplete_uploads.ex` itself (already follows the target pattern)

Existing structure (`rindle.abort_incomplete_uploads.ex:1-44`):
```elixir
defmodule Mix.Tasks.Rindle.AbortIncompleteUploads do
  @shortdoc "Transition timed-out upload sessions to expired"

  @moduledoc """
  ...
  """

  use Mix.Task

  alias Rindle.Ops.UploadMaintenance

  @requirements ["app.start"]

  @impl Mix.Task
  def run(argv) do
```

All 5 Mix tasks already match. **Do NOT add `@doc` or `@spec` to `run/1`** (per D-12 / canonical Mix task pattern; `@impl Mix.Task` is the contract pointer). The work for Plan 18-04 is verification only.

---

### `.doctor.exs` (NEW, Plan 18-01)

**Analog:** `.credo.exs` (config-as-Elixir, lives at project root, dev/test-only tooling, list-of-modules ignore shape)

**Existing `.credo.exs` shape** (lines 1-15):
```elixir
%{
  configs: [
    %{
      name: "default",
      files: %{
        included: [
          "lib/",
          "test/"
        ],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      plugins: [],
      requires: [],
      strict: true,
      ...
```

`.doctor.exs` is generated by `mix doctor.gen.config` (Plan 18-01) — keep the generator's output as the structural baseline. Hand-edits to add: (1) `ignore_modules:` regex+list shape per RESEARCH.md "ignore_modules inventory" (21-module enumeration with `~r/^Rindle\.Internal\./`, `~r/^Rindle\.Security\./`, `~r/^Rindle\.Ops\./` regex prefixes + 13 explicit modules); (2) baseline thresholds matching current state (Plan 18-01) → ratchet to D-07 target 100/100/100/95/95 (Plan 18-05).

---

### `mix.exs` — add `:doctor` dep + (optional D-27) rename adapter group (Plans 18-01 + 18-03)

**Analog:** existing `:credo` / `:dialyxir` deps (`mix.exs:89-90`)

Existing pattern:
```elixir
{:credo, "~> 1.7", only: [:dev, :test], runtime: false},
{:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
```

Plan 18-01 inserts (alongside the others around line 91):
```elixir
{:doctor, "~> 0.22.0", only: [:dev, :test], runtime: false},
```

**Existing `groups_for_modules` adapter group** (`mix.exs:148-152`):
```elixir
"Storage Adapters": [
  Rindle.Storage,
  Rindle.Storage.Local,
  Rindle.Storage.S3
],
```

Plan 18-03 / D-27 renames the group to a unified family per CONTEXT.md `<discretion>` default ("rename to a unified group"):
```elixir
"Storage and Processor Adapters": [
  Rindle.Storage,
  Rindle.Storage.Local,
  Rindle.Storage.S3,
  Rindle.Processor.Image
],
```

Note: `Rindle.Processor` (the behaviour) stays in the **"Extension Points"** group at `mix.exs:142-147` symmetric with the other behaviours; the *adapter* `Rindle.Processor.Image` joins the unified group, mirroring how `Rindle.Storage` (behaviour) currently sits in "Storage Adapters" alongside `Storage.Local` / `Storage.S3` — the group already mixes a behaviour and its adapters, so adding Processor.Image follows the existing convention exactly.

---

### `.github/workflows/ci.yml` — insert `mix doctor` step (Plan 18-01)

**Analog:** existing `mix credo --strict` step (`ci.yml:84-85`)

Existing shape:
```yaml
      - name: Credo (strict)
        run: mix credo --strict

      - name: Run tests with coverage
        run: mix coveralls
```

Plan 18-01 inserts the doctor step between them (lines 86 / 87):
```yaml
      - name: Credo (strict)
        run: mix credo --strict

      - name: Doctor (full, raise)
        run: MIX_ENV=test mix doctor --full --raise

      - name: Run tests with coverage
        run: mix coveralls
```

The job-level `MIX_ENV: test` env (line 10) already covers the env, but the explicit `MIX_ENV=test` prefix is belt-and-suspenders (matches the canonical `team-alembic/staple-actions/actions/mix-doctor` action — see CONTEXT.md D-10). The step automatically inherits the Elixir 1.15 / 1.17 matrix (lines 19-26). No `continue-on-error` — failures block merge, same as Credo and Dialyzer.

---

### `test/rindle/doctor_thresholds_test.exs` (NEW, Plan 18-01 RED → 18-05 green)

**Analog:** `test/rindle/config/config_test.exs` (small flat ExUnit file that asserts config-source values)

**`use ExUnit.Case` boilerplate from analog** (`config_test.exs:1-2`):
```elixir
defmodule Rindle.Config.ConfigTest do
  use ExUnit.Case, async: false
```

Use `async: false` (matches Config test) because `.doctor.exs` is read at module/config level — no test isolation guarantee needed. Or `async: true` if reading is a pure file-read. Recommendation: `async: true` since `Code.eval_file/1` on `.doctor.exs` is pure.

**Test shape** (~15 LOC, per D-23 narrow contract):
```elixir
defmodule Rindle.DoctorThresholdsTest do
  use ExUnit.Case, async: true

  @doctor_config_path Path.expand("../../.doctor.exs", __DIR__)

  setup_all do
    {config, _bindings} = Code.eval_file(@doctor_config_path)
    {:ok, config: config}
  end

  test "min_module_doc_coverage is at the D-07 target", %{config: config} do
    assert config.min_module_doc_coverage == 100
  end

  test "min_overall_doc_coverage is at the D-07 target", %{config: config} do
    assert config.min_overall_doc_coverage == 100
  end

  test "min_overall_moduledoc_coverage is at the D-07 target", %{config: config} do
    assert config.min_overall_moduledoc_coverage == 100
  end

  test "min_module_spec_coverage is at the D-07 target", %{config: config} do
    assert config.min_module_spec_coverage == 95
  end

  test "min_overall_spec_coverage is at the D-07 target", %{config: config} do
    assert config.min_overall_spec_coverage == 95
  end
end
```

Plan 18-01 ships RED (assertions reference 100/95 target; baseline `.doctor.exs` ships with current-state values, so 4-5 assertions fail). Plan 18-05 ratchets `.doctor.exs` to target → tests pass.

---

### `test/rindle/behaviour_docs_test.exs` (NEW, Plan 18-03)

**Analog:** `test/rindle/api_surface_boundary_test.exs` (the `fetch_docs!/1` helper at lines 173-180 + per-module iteration pattern at lines 62-89)

**Reusable `fetch_docs!/1` helper** (`api_surface_boundary_test.exs:173-180`):
```elixir
defp fetch_docs!(module) do
  assert Code.ensure_loaded?(module), "#{inspect(module)} must be loadable for boundary checks"

  case Code.fetch_docs(module) do
    {:error, reason} -> flunk("expected compiled docs for #{inspect(module)}, got #{inspect(reason)}")
    docs -> docs
  end
end
```

**Per-module iteration pattern** (`api_surface_boundary_test.exs:62-67`):
```elixir
test "D-03 reconciliation keeps storage adapters public alongside the facade allowlist" do
  for module <- @public_modules do
    assert visible_module?(module),
           "#{inspect(module)} should stay visible in compiled docs"
  end
end
```

**Doc-state extraction** — the `:callback` entries in the docs chunk live at the same depth as `:function` entries (`api_surface_boundary_test.exs:163-170`):
```elixir
defp function_doc_entry(module, name, arity) do
  {:docs_v1, _, _, _, _, _, docs} = fetch_docs!(module)

  docs
  |> Enum.find(fn
    {{:function, doc_name, doc_arity}, _, _, _, _} -> doc_name == name and doc_arity == arity
    _ -> false
  end)
end
```

For callbacks, the tuple shape is `{{:callback, name, arity}, _, _, doc, _}` — same fifth-element doc state as `:function`. The `behaviour_docs_test.exs` test asserts `doc not in [:none, :hidden]` for every `:callback` entry across the 5 behaviour modules.

**Target structure** (~20 LOC):
```elixir
defmodule Rindle.BehaviourDocsTest do
  use ExUnit.Case, async: true

  @behaviour_modules [
    Rindle.Storage,
    Rindle.Authorizer,
    Rindle.Analyzer,
    Rindle.Scanner,
    Rindle.Processor
  ]

  for module <- @behaviour_modules do
    test "every @callback in #{inspect(module)} has a non-hidden @doc" do
      module = unquote(module)
      {:docs_v1, _, _, _, _, _, docs} = fetch_docs!(module)

      callbacks =
        Enum.filter(docs, fn
          {{:callback, _name, _arity}, _, _, _, _} -> true
          _ -> false
        end)

      assert callbacks != [], "#{inspect(module)} should declare at least one @callback"

      for {{:callback, name, arity}, _, _, doc, _} <- callbacks do
        refute doc in [:none, :hidden],
               "#{inspect(module)}.#{name}/#{arity} callback should have a visible @doc"
      end
    end
  end

  defp fetch_docs!(module) do
    assert Code.ensure_loaded?(module), "#{inspect(module)} must be loadable"

    case Code.fetch_docs(module) do
      {:error, reason} -> flunk("expected compiled docs for #{inspect(module)}, got #{inspect(reason)}")
      docs -> docs
    end
  end
end
```

Lands green on Plan 18-03 (after the per-callback `@doc`s land in the same plan).

---

### `test/rindle/api_surface_boundary_test.exs` — extend allowlist for D-27 (Plan 18-03)

**Analog:** itself (extending the existing `@public_modules` list at lines 4-30)

Existing list (`api_surface_boundary_test.exs:4-30`) does **not** include `Rindle.Processor.Image`. Plan 18-03 adds it after `Rindle.Processor` (line 17):
```elixir
@public_modules [
  Rindle,
  Rindle.Profile,
  ...
  Rindle.Processor,
  Rindle.Processor.Image,    # <-- ADD (D-27)
  Mix.Tasks.Rindle.AbortIncompleteUploads,
  ...
]
```

The existing `visible_module?/1` test on line 62-67 then automatically guards it against accidental hiding.

---

## Shared Patterns

### `@doc` placement convention (Elixir-stdlib idiom — applies to all behaviour, controller, and macro files)

**Source:** `lib/rindle/storage.ex:71-76` (per-callback) + `lib/rindle/delivery.ex:14-25` (per-function)
**Apply to:** All behaviour modules, all public functions, the `__using__/1` macro

Pattern:
1. `@doc """..."""` block — multi-line, present-tense first sentence ("Returns...", "Initiates...", "Authorizes...").
2. Optional `## Examples` block with `iex>` doctests (preceded by a `# Requires ...` comment when the doctest depends on runtime config — see `delivery.ex:88-93`).
3. `@spec` immediately below the `@doc """` close.
4. `def`/`defmacro`/`@callback` immediately below.

```elixir
@doc """
<one-line summary>.

<expanded paragraph>.

## Examples

    # Requires <preconditions>.
    iex> {:ok, result} = Module.fn(...)
    iex> assertion
    expected_value

"""
@spec fn(arg_t()) :: {:ok, return_t()} | {:error, term()}
def fn(arg) do
```

### `@type t :: %__MODULE__{}` schema-struct pattern

**Source:** `lib/rindle/domain/media_asset.ex:47`
**Apply to:** Already declared on all 5 schemas — referenced by name in `Rindle` and `Broker` `@spec` tightening (Plan 18-02)

```elixir
@type t :: %__MODULE__{}

schema "media_assets" do
  ...
end

@spec changeset(t() | %__MODULE__{}, map()) :: Ecto.Changeset.t()
```

This is the named-type **target** for Plan 18-02 — `Rindle.initiate_upload/2`'s `{:ok, map()}` becomes `{:ok, MediaUploadSession.t()}` because `MediaUploadSession.t()` is already declared at `lib/rindle/domain/media_upload_session.ex` in the same idiom.

### Error branch posture (Phase 17 D-08 semver guard)

**Apply to:** Every tightened `@spec` in Plan 18-02 — Rindle facade, Broker, Storage behaviour result types

Always `{:error, term()}` on the error branch — narrowing to `{:error, atom()}` or `{:error, specific_union}` is a Dialyzer-breaking change for any adopter pattern-matching on the error term, and `0.1.x` semver posture (Phase 17 D-08) blocks that. RESEARCH.md and CONTEXT.md `<specifics>` both call this out — the planner must not narrow.

### `@impl true` for adapter implementations

**Source:** `lib/rindle/storage/local.ex:8,20,32,40,45,51,56,61,66,71,82` (every callback impl)
**Apply to:** `lib/rindle/processor/image.ex` (D-27 promotion — currently missing `@impl Rindle.Processor`)

The adapter inherits `@doc` from the behaviour-level `@callback`'s `@doc` block — adapters do NOT duplicate `@doc`. This is the convention that makes D-07's 95% (not 100%) `@spec` threshold work — `@impl` callbacks count as documented via behaviour inheritance.

### `Code.fetch_docs/1` introspection idiom

**Source:** `test/rindle/api_surface_boundary_test.exs:173-180` (`fetch_docs!/1` helper)
**Apply to:** New `test/rindle/behaviour_docs_test.exs` (Plan 18-03)

Use the public Elixir API (`Code.fetch_docs/1`) for any test that asserts on compiled docs — same idiom ExDoc itself uses. Do NOT reach into `:beam_lib` chunks directly. Copy the helper verbatim into the new test file (or extract to `test/support/docs_introspection.ex` if other tests start needing it; not required for Phase 18).

### Mix task structure (Mix-stdlib idiom — verify-only in Plan 18-04)

**Source:** `lib/mix/tasks/rindle.abort_incomplete_uploads.ex:1-44` (any of the 5 — they're all identical posture)
**Apply to:** All 5 Mix tasks

```elixir
defmodule Mix.Tasks.Rindle.<Name> do
  @shortdoc "<one-line summary>"

  @moduledoc """
  <multi-line description with `## Usage`, `## Exit codes`, `## Examples`, `## Notes`>
  """

  use Mix.Task

  alias <internal>

  @requirements ["app.start"]

  @impl Mix.Task
  def run(argv) do
    ...
  end
end
```

**Do NOT add `@doc` or `@spec` to `run/1`** — `@impl Mix.Task` is the documentation pointer to `Mix.Task.run/1`. D-07's 95% spec threshold accepts callback inheritance for these.

### Oban worker structure (Oban-stdlib idiom)

**Source:** `lib/rindle/workers/abort_incomplete_uploads.ex:1-101`
**Apply to:** Both workers

```elixir
defmodule Rindle.Workers.<Name> do
  @moduledoc """
  <rich description: what the worker does, scheduling, observability, idempotency>
  """

  use Oban.Worker, queue: :rindle_maintenance, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    ...
  end
end
```

**Do NOT add `@doc` to `perform/1`.** Optionally add `@spec perform(Oban.Job.t()) :: :ok | {:error, term()}` to narrow `Oban.Worker.result()` to the actually-returned union (Plan 18-04, D-13).

### Optional-dep conditional compile pattern

**Source:** `lib/rindle/html.ex:1` (`if Code.ensure_loaded?(Phoenix.HTML) do`)
**Apply to:** `Rindle.HTML` and `Rindle.LiveView` (already correct — verify only)

This is why the doctor CI step **MUST** run with `MIX_ENV=test` (D-10) — in `:dev` env without the optional `:phoenix_html` / `:phoenix_live_view` test deps loaded, these modules don't compile and doctor would silently skip them, producing a false-clean coverage report.

---

## No Analog Found

**None.** Every Phase 18 file change has a strong in-repo analog. The phase is unusually pattern-heavy — it documents what already exists rather than introducing new code shapes.

---

## Metadata

**Analog search scope:**
- `/Users/jon/projects/rindle/lib/` (recursive)
- `/Users/jon/projects/rindle/test/rindle/` (recursive)
- `/Users/jon/projects/rindle/mix.exs`
- `/Users/jon/projects/rindle/.credo.exs`
- `/Users/jon/projects/rindle/.github/workflows/ci.yml`

**Files scanned:** 30+ (focused on the special-anchor files called out in the prompt)

**Pattern extraction date:** 2026-04-30

**Key observation:** Phase 18 is largely a **"copy Delivery's posture across every other public module"** exercise. The single most useful artifact for the planner is `lib/rindle/delivery.ex` itself — every `@doc` + `@spec` + `## Examples` shape there is the canonical template. The second most useful is `test/rindle/api_surface_boundary_test.exs` — its `Code.fetch_docs/1` idiom is reused in Plan 18-03's behaviour-doc backstop.
