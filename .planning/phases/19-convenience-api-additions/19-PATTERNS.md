# Phase 19: Convenience API Additions - Pattern Map

**Mapped:** 2026-05-01
**Files analyzed:** 6 (2 new, 4 modified)
**Analogs found:** 5 / 6 (1 greenfield with dep-sourced pattern)

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/rindle.ex` (8 new fns) | facade — query helpers + bang wrappers | CRUD + request-response | `lib/rindle.ex` lines 170-279 (existing `attach/4`, `detach/3`) | exact |
| `lib/rindle/error.ex` | exception module — new | N/A | `deps/ecto/lib/ecto/exceptions.ex` lines 85-140 (`Ecto.InvalidChangesetError`) | dep analog (no codebase analog exists) |
| `test/rindle/convenience_api_test.exs` | test file — new | integration + unit | `test/rindle/attach_detach_test.exs` lines 1-94 | exact |
| `test/rindle/api_surface_boundary_test.exs` | test — config list append | compiled-docs boundary | same file lines 4-31 (`@public_modules`) | exact (self-analog) |
| `mix.exs` | config — list append | N/A | `mix.exs` lines 126-170 (`groups_for_modules`) | exact (self-analog) |
| `CHANGELOG.md` | changelog — entry append | N/A | `CHANGELOG.md` lines 1-61 (`## [Unreleased]` block) | exact (self-analog) |

---

## Pattern Assignments

### `lib/rindle.ex` — new aliases (lines 2-9, insertion point)

**Analog:** `lib/rindle.ex` lines 2-9

**Existing aliases block** (lines 2-9):
```elixir
alias Rindle.Domain.MediaAsset
alias Rindle.Domain.MediaAttachment
alias Rindle.Domain.MediaUploadSession
alias Rindle.Internal.VariantFailureLogger
alias Rindle.Security.UploadValidation
alias Rindle.Upload.Broker
alias Rindle.Workers.PromoteAsset
alias Rindle.Workers.PurgeStorage
```

**Executor note:** Add two lines after line 3 (`alias Rindle.Domain.MediaAttachment`):
```elixir
alias Rindle.Domain.MediaVariant   # needed for ready_variants_for/1
alias Rindle.Error                 # needed for bang raise calls
```
`MediaVariant` is alphabetically between `MediaAttachment` and `MediaUploadSession`; `Rindle.Error` goes after all `Rindle.Domain.*` aliases.

---

### `lib/rindle.ex` — `attachment_for/2,3` (new function)

**Analog:** `lib/rindle.ex` lines 170-229 (`attach/4`)

**Pattern to mirror — @doc/@spec + repo accessor + get_owner_info + Ecto query** (lines 157-229):
```elixir
@doc """
Attaches a MediaAsset to an owner at a specific slot.
...
## Examples

    # Requires a configured Rindle repo + an existing MediaAsset and owner record.
    iex> {:ok, attachment} = Rindle.attach(asset_id, %MyApp.User{id: user_id}, "avatar")
    iex> attachment.slot
    "avatar"

"""
@spec attach(MediaAsset.t() | binary(), struct(), String.t(), keyword()) ::
        {:ok, MediaAttachment.t()} | {:error, term()}
def attach(asset_or_id, owner, slot, _opts \\ []) do
  repo = Rindle.Config.repo()
  asset_id = get_asset_id(asset_or_id)
  {owner_type, owner_id} = get_owner_info(owner)

  Ecto.Multi.new()
  |> Ecto.Multi.run(:existing, fn repo, _ ->
    existing =
      repo.one(
        from a in MediaAttachment,
          where: a.owner_type == ^owner_type and a.owner_id == ^owner_id and a.slot == ^slot
      )
    {:ok, existing}
  end)
  ...
  |> repo.transaction()
  |> case do
    {:ok, %{attachment: attachment}} -> {:ok, attachment}
    {:error, _name, reason, _changes} -> {:error, reason}
  end
end
```

**Also mirror — private helper shapes** (lines 281-286):
```elixir
defp get_asset_id(%MediaAsset{id: id}), do: id
defp get_asset_id(id) when is_binary(id), do: id

defp get_owner_info(%{__struct__: module, id: id}) do
  {to_string(module), id}
end
```

**Also mirror — `ready_variants_for/1` query shape** from `lib/rindle/workers/purge_storage.ex` line 17:
```elixir
repo.all(from v in MediaVariant, where: v.asset_id == ^asset_id, select: v.storage_key)
```

**Body sketch for `attachment_for/2,3`** (implement this pattern):
```elixir
@spec attachment_for(struct(), String.t()) :: MediaAttachment.t() | nil
@spec attachment_for(struct(), String.t(), keyword()) :: MediaAttachment.t() | nil
def attachment_for(owner, slot, opts \\ []) do
  repo = Rindle.Config.repo()
  {owner_type, owner_id} = get_owner_info(owner)
  preloads = Keyword.get(opts, :preload, [:asset])

  query =
    from a in MediaAttachment,
      where: a.owner_type == ^owner_type and a.owner_id == ^owner_id and a.slot == ^slot,
      order_by: [desc: a.inserted_at],
      limit: 1

  case repo.one(query) do
    nil -> nil
    attachment -> repo.preload(attachment, preloads)
  end
end
```

**Executor notes:**
- `from` is already imported via `import Ecto.Query` at line 20 of `lib/rindle.ex` — no new import needed.
- Use `Keyword.get(opts, :preload, [:asset])` — this replaces (not merges) the default, matching Ecto convention. The `@doc` must document `preload: []` (empty list) to disable preloading, NOT `preload: false` (`Ecto.Repo.preload/2` does not accept `false`).
- Two `@spec` lines before a single `def` with default-arg — matches `attach/4` (line 170-171) and `url/3` (line 333) conventions.
- Full `@doc` block with `## Examples` per `attach/4` shape at lines 156-169.

---

### `lib/rindle.ex` — `ready_variants_for/1` (new function)

**Analog:** `lib/rindle/workers/purge_storage.ex` line 17 (closest query pattern in codebase)

**Query pattern** (line 17):
```elixir
variant_keys =
  repo.all(from v in MediaVariant, where: v.asset_id == ^asset_id, select: v.storage_key)
```

**Also analog:** `lib/rindle/ops/variant_maintenance.ex` lines 70-75 (multi-condition variant query):
```elixir
query =
  from v in MediaVariant,
    join: a in MediaAsset,
    on: a.id == v.asset_id,
    where: v.state in @regeneration_states,
    select: {v.id, v.name, a.id, v.state}
```

**Body sketch for `ready_variants_for/1`** (implement this pattern):
```elixir
@spec ready_variants_for(MediaAsset.t() | binary()) :: [MediaVariant.t()]
def ready_variants_for(asset_or_id) do
  repo = Rindle.Config.repo()
  asset_id = get_asset_id(asset_or_id)

  repo.all(
    from v in MediaVariant,
      where: v.asset_id == ^asset_id and v.state == "ready",
      order_by: [asc: v.name]
  )
end
```

**Executor notes:**
- `"ready"` string confirmed at `lib/rindle/domain/media_variant.ex` line 33 as one of eight valid states.
- `get_asset_id/1` at lines 281-282 handles both `%MediaAsset{}` struct and binary id — reuse as-is.
- Returns plain list (no `{:ok, _}` wrapping) matching `Repo.all/1` ecosystem convention per D-06.
- Order by `:name` is deterministic because the schema has a unique constraint on `[:asset_id, :name]` (line 78 of `media_variant.ex`).
- `alias Rindle.Domain.MediaVariant` must be added to the alias block (see above) before implementing this function.

---

### `lib/rindle.ex` — `attach!/4`, `detach!/3`, `upload!/3`, `url!/3`, `variant_url!/4` (new bang functions)

**Analog:** `lib/rindle.ex` lines 170-279 (non-bang twins `attach/4` and `detach/3`)

**`attach/4` return shape** (lines 225-228):
```elixir
|> repo.transaction()
|> case do
  {:ok, %{attachment: attachment}} -> {:ok, attachment}
  {:error, _name, reason, _changes} -> {:error, reason}
end
```

**`detach/3` return shape** (lines 273-278):
```elixir
|> repo.transaction()
|> case do
  {:ok, _} -> :ok
  # Idempotent
  {:error, :existing, :not_found, _} -> :ok
  {:error, _name, reason, _changes} -> {:error, reason}
end
```

**`store_variant/4` wrapper pattern** (lines 474-481) — closest codebase analog for bang-style wrapping:
```elixir
case store(profile, key, source_path, adapter_opts) do
  {:ok, result} ->
    {:ok, result}

  {:error, reason} = error ->
    VariantFailureLogger.log(asset_id, variant_name, reason)
    error
end
```

**Bang body pattern for all five bangs** — copy this shape exactly (from D-14 locked decision):
```elixir
@doc "Same as `attach/4` but raises `Rindle.Error` on failure or `Ecto.InvalidChangesetError` for changeset failures."
@spec attach!(MediaAsset.t() | binary(), struct(), String.t()) :: MediaAttachment.t()
@spec attach!(MediaAsset.t() | binary(), struct(), String.t(), keyword()) :: MediaAttachment.t()
def attach!(asset_or_id, owner, slot, opts \\ []) do
  case attach(asset_or_id, owner, slot, opts) do
    {:ok, attachment} ->
      attachment

    {:error, %Ecto.Changeset{} = cs} ->
      raise Ecto.InvalidChangesetError, action: :insert, changeset: cs

    {:error, {:storage_adapter_exception, exception}} when is_exception(exception) ->
      raise exception

    {:error, reason} ->
      raise Rindle.Error, action: :attach, reason: reason
  end
end
```

**`detach!/3` variation** — CRITICAL: `detach/3` returns bare `:ok` (line 274), NOT `{:ok, _}`. First arm must be `:ok -> :ok`:
```elixir
@doc "Same as `detach/3` but raises `Rindle.Error` on failure."
@spec detach!(struct(), String.t()) :: :ok
@spec detach!(struct(), String.t(), keyword()) :: :ok
def detach!(owner, slot, opts \\ []) do
  case detach(owner, slot, opts) do
    :ok ->
      :ok

    {:error, %Ecto.Changeset{} = cs} ->
      raise Ecto.InvalidChangesetError, action: :delete, changeset: cs

    {:error, {:storage_adapter_exception, exception}} when is_exception(exception) ->
      raise exception

    {:error, reason} ->
      raise Rindle.Error, action: :detach, reason: reason
  end
end
```

**Executor notes for all five bangs:**
- `@doc` is exactly one line per D-17: `"Same as \`foo/N\` but raises \`Rindle.Error\` on failure..."` — no `## Examples` block on bangs.
- `@spec` success type only (no `no_return()`) per D-18 and Ecto/Oban convention.
- Two `@spec` entries per bang because of default-arg — matches `attach/4` lines 170-171.
- `action:` atoms: `attach!/4` → `:insert`, `detach!/3` → `:delete`, `upload!/3` → `:insert`, `url!/3` → `:url` (no changeset in practice), `variant_url!/4` → `:variant_url` (no changeset in practice).
- `{:error, {:storage_adapter_exception, _}}` arm is dead code for `attach!/4` and `detach!/3` (those functions never call `invoke_storage/3`) — include it anyway for pattern completeness.
- `upload!/3` quarantine: `{:error, {:quarantine, reason}}` matches the generic `{:error, reason}` arm; `Rindle.Error.message/1` handles the `{:quarantine, why}` shape in its second branch.

---

### `lib/rindle/error.ex` — new exception module

**No codebase analog exists** — no `defexception` anywhere in `lib/`. Closest analog is in deps.

**Dep analog:** `deps/ecto/lib/ecto/exceptions.ex` lines 85-140 (`Ecto.InvalidChangesetError`):
```elixir
defmodule Ecto.InvalidChangesetError do
  @moduledoc """
  Raised when we cannot perform an action because the
  changeset is invalid.
  """
  defexception [:action, :changeset]

  def message(%{action: action, changeset: changeset}) do
    changes = extract_changes(changeset)
    errors = Ecto.Changeset.traverse_errors(changeset, & &1)

    """
    could not perform #{action} because changeset is invalid.

    Errors

    #{pretty(errors)}
    ...
    """
  end
  ...
end
```

**Target implementation** (mirror this exact structure):
```elixir
defmodule Rindle.Error do
  @moduledoc """
  Exception raised by bang variants on the `Rindle` facade when an
  operation fails for a non-changeset reason.

  Fields:

    * `:action` — atom identifying the failing operation
      (`:attach`, `:detach`, `:upload`, `:url`, `:variant_url`)
    * `:reason` — the underlying error term returned by the non-bang variant

  For changeset validation failures, bangs raise `Ecto.InvalidChangesetError`
  instead. For storage adapter exceptions, bangs re-raise the original
  exception directly.
  """

  defexception [:action, :reason]

  @type t :: %__MODULE__{action: atom(), reason: term()}

  @doc """
  Returns a human-readable message describing the failure.
  """
  @impl true
  @spec message(t()) :: String.t()
  def message(%{action: action, reason: :not_found}) do
    "could not #{action}: not found"
  end

  def message(%{action: action, reason: {:quarantine, why}}) do
    "could not #{action}: upload quarantined (#{inspect(why)})"
  end

  def message(%{action: action, reason: reason}) do
    "could not #{action}: #{inspect(reason)}"
  end
end
```

**Executor notes:**
- `@moduledoc` is mandatory — `.doctor.exs` has `exception_moduledoc_required: true`.
- Explicit `@type t :: %__MODULE__{action: atom(), reason: term()}` is mandatory — `.doctor.exs` has `struct_type_spec_required: true`; do not rely on `defexception` to auto-generate a satisfying type.
- `@impl true` on `message/1` satisfies doctor's doc-presence check (points to `Exception` behaviour).
- `@spec message(t()) :: String.t()` is required to hit the 95% spec threshold.
- Three `def message/1` clauses — no `@doc` needed on the second and third clauses (only the first needs the `@doc` block; subsequent pattern-match clauses of the same function do not).
- This file is ~30 LOC. Do not add a `@doc false` or `@moduledoc false` — this is a public module.

---

### `test/rindle/convenience_api_test.exs` — new test file

**Analog:** `test/rindle/attach_detach_test.exs` lines 1-94

**Full boilerplate to copy** (lines 1-36):
```elixir
defmodule Rindle.AttachDetachTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo
  import Mox

  alias Rindle.Domain.{MediaAsset, MediaAttachment}

  setup :set_mox_from_context
  setup :verify_on_exit!

  defmodule TestProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [],
      allow_mime: ["image/jpeg"],
      max_bytes: 10_485_760
  end

  defmodule User do
    defstruct [:id]
  end

  setup do
    asset =
      %MediaAsset{}
      |> MediaAsset.changeset(%{
        state: "available",
        profile: to_string(TestProfile),
        storage_key: "user/1/avatar.jpg"
      })
      |> Rindle.Repo.insert!()

    user = %User{id: Ecto.UUID.generate()}

    {:ok, asset: asset, user: user}
  end
```

**Test describe pattern** (lines 38-76):
```elixir
describe "attach/4" do
  test "successfully attaches an asset", %{asset: asset, user: user} do
    {:ok, attachment} = Rindle.attach(asset, user, "avatar")

    assert attachment.asset_id == asset.id
    assert attachment.owner_type =~ "User"
    assert attachment.owner_id == user.id
    assert attachment.slot == "avatar"
  end
  ...
end

describe "detach/3" do
  test "removes attachment and enqueues purge", %{asset: asset, user: user} do
    {:ok, _} = Rindle.attach(asset, user, "avatar")

    assert :ok = Rindle.detach(user, "avatar")

    assert Rindle.Repo.all(MediaAttachment) == []

    assert_enqueued worker: Rindle.Workers.PurgeStorage,
                    args: %{"asset_id" => asset.id, "profile" => asset.profile}
  end

  test "is idempotent", %{user: user} do
    assert :ok = Rindle.detach(user, "avatar")
  end
end
```

**Executor notes:**
- Module name: `Rindle.ConvenienceApiTest`
- `async: false` — required because `Mox.set_mox_from_context` only works with shared-mode sandbox.
- `use Oban.Testing, repo: Rindle.Repo` — include even for tests that don't assert jobs, matching `attach_detach_test.exs` parity.
- Extend the `alias` line to include `MediaVariant`: `alias Rindle.Domain.{MediaAsset, MediaAttachment, MediaVariant}`.
- Also add `alias Rindle.Error` to the alias block.
- `setup` block inserts a single asset in `"available"` state — reuse this exact pattern.
- For `ready_variants_for/1` tests, insert `MediaVariant` rows directly via changeset in the test body (no setup change needed).
- For bang tests requiring storage mock, use `expect(Rindle.StorageMock, :store, fn _, _, _ -> {:ok, %{}} end)` — see `attach_detach_test.exs` for how `Mox` is used alongside `Rindle.StorageMock`.
- `Rindle.DataCase` provides `import Ecto.Query` via the `using` block (`test/support/data_case.ex` line 12) — no extra import needed in the test file.
- `assert_raise Rindle.Error` and `assert_raise Ecto.InvalidChangesetError` are the bang error assertions.

---

### `test/rindle/api_surface_boundary_test.exs` — `@public_modules` append

**Self-analog:** same file lines 4-31

**Existing `@public_modules` list** (lines 4-31):
```elixir
@public_modules [
  Rindle,
  Rindle.Profile,
  Rindle.Upload.Broker,
  Rindle.Delivery,
  Rindle.Storage,
  Rindle.Storage.Local,
  Rindle.Storage.S3,
  Rindle.LiveView,
  Rindle.HTML,
  Rindle.Authorizer,
  Rindle.Analyzer,
  Rindle.Scanner,
  Rindle.Processor,
  Rindle.Processor.Image,
  Mix.Tasks.Rindle.AbortIncompleteUploads,
  Mix.Tasks.Rindle.BackfillMetadata,
  Mix.Tasks.Rindle.CleanupOrphans,
  Mix.Tasks.Rindle.RegenerateVariants,
  Mix.Tasks.Rindle.VerifyStorage,
  Rindle.Workers.AbortIncompleteUploads,
  Rindle.Workers.CleanupOrphans,
  Rindle.Domain.MediaAsset,
  Rindle.Domain.MediaAttachment,
  Rindle.Domain.MediaUploadSession,
  Rindle.Domain.MediaVariant,
  Rindle.Domain.MediaProcessingRun
]
```

**Executor note:** Insert `Rindle.Error` after `Rindle` (line 5) — alphabetically it belongs after `Rindle` and before `Rindle.Profile` since `Error` sorts before `Profile`. The exact insertion point is line 6 (after `Rindle,`):
```elixir
@public_modules [
  Rindle,
  Rindle.Error,       # <-- insert here (Plan 19-01)
  Rindle.Profile,
  ...
```

The new functions (`attachment_for/2,3`, `ready_variants_for/1`, and the five bangs) land on the `Rindle` module itself — already in `@public_modules`. The existing `visible_module?/1` check covers the module; individual function export checks live in the `"facade export and shim expectations"` describe block. No new function-level assertions are strictly required by the boundary test for the new functions (the existing `function_exported?` pattern at lines 93-97 is a model if the planner wants to add assertions in 19-01).

---

### `mix.exs` — `groups_for_modules` Facade group append

**Self-analog:** `mix.exs` lines 126-130

**Existing Facade group** (lines 127-129):
```elixir
groups_for_modules: [
  Facade: [
    Rindle
  ],
```

**After 19-02 change:**
```elixir
groups_for_modules: [
  Facade: [
    Rindle,
    Rindle.Error
  ],
```

**Executor note:** One line added: `Rindle.Error` after `Rindle` in the `Facade` list. No other groups change. This is the only `mix.exs` modification for Phase 19.

---

### `CHANGELOG.md` — `## [Unreleased]` entry append

**Self-analog:** `CHANGELOG.md` lines 1-61 (existing `## [Unreleased]` block)

**Existing entry shape** (lines 8-44):
```markdown
### Added

- `@doc` annotations on every public `@callback` across ...
- Behaviour-level named result types on `Rindle.Storage` ...
```

**Executor note:** Append under `### Added` in the existing `## [Unreleased]` block. Follow the same bullet prose style — leading backtick-quoted function name, em-dash separator, terse description ending with `(API-NN)` requirement tag. Example from research draft:

```markdown
- `Rindle.attachment_for/2,3` — fetch the most-recent `MediaAttachment` for an
  `(owner, slot)` pair without writing a raw Ecto query. Auto-preloads `:asset`
  by default; pass `preload: [asset: :variants]` (or `preload: []`) to extend
  or override (API-09).
- `Rindle.ready_variants_for/1` — fetch all `MediaVariant` rows in the
  `"ready"` state for an asset (by struct or id), ordered by name. Returns an
  empty list when none are ready (API-10).
- `Rindle.attach!/4`, `Rindle.detach!/3`, `Rindle.upload!/3`, `Rindle.url!/3`,
  `Rindle.variant_url!/4` — bang variants of the corresponding non-bang
  functions. Raise `Ecto.InvalidChangesetError` for changeset failures, re-raise
  the original exception for storage adapter failures, and raise `Rindle.Error`
  for all other failures (API-11).
- `Rindle.Error` — new exception module with `:action` and `:reason` fields.
  Raised by bang variants for non-changeset, non-adapter-exception failures.
  Provides a structured `message/1` that formats the action and reason into a
  readable string.
```

---

## Shared Patterns

### Repo accessor
**Source:** `lib/rindle.ex` lines 173, 246, 376 (used in `attach/4`, `detach/3`, `upload/3`)
**Apply to:** `attachment_for/2,3` and `ready_variants_for/1`
```elixir
repo = Rindle.Config.repo()
```

### Owner identification
**Source:** `lib/rindle.ex` lines 175, 247 (used in `attach/4`, `detach/3`)
**Apply to:** `attachment_for/2,3`
```elixir
{owner_type, owner_id} = get_owner_info(owner)
```

### Asset polymorphism
**Source:** `lib/rindle.ex` lines 174, 281-282 (used in `attach/4`)
**Apply to:** `ready_variants_for/1`
```elixir
asset_id = get_asset_id(asset_or_id)

defp get_asset_id(%MediaAsset{id: id}), do: id
defp get_asset_id(id) when is_binary(id), do: id
```

### Bang error dispatch (four-arm case)
**Source:** D-14 locked decision, modeled on `deps/oban/lib/oban.ex` lines 681-692
**Apply to:** all five bang functions
```elixir
case non_bang_fn(...) do
  {:ok, result} -> result
  {:error, %Ecto.Changeset{} = cs} -> raise Ecto.InvalidChangesetError, action: :insert, changeset: cs
  {:error, {:storage_adapter_exception, exception}} when is_exception(exception) -> raise exception
  {:error, reason} -> raise Rindle.Error, action: :action_atom, reason: reason
end
```

### `@spec` two-line default-arg form
**Source:** `lib/rindle.ex` lines 170-171 (`attach/4`)
**Apply to:** all functions with `opts \\ []` default arg
```elixir
@spec attach(MediaAsset.t() | binary(), struct(), String.t(), keyword()) ::
        {:ok, MediaAttachment.t()} | {:error, term()}
```
For default-arg functions, list two `@spec` entries (one without the optional arg, one with).

---

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `lib/rindle/error.ex` | exception module | N/A | No `defexception` module exists anywhere in `lib/`. Closest analog sourced from `deps/ecto/lib/ecto/exceptions.ex` lines 85-140 (`Ecto.InvalidChangesetError`). |

---

## Metadata

**Analog search scope:** `lib/`, `test/`, `deps/ecto/lib/ecto/`, `deps/oban/lib/`
**Files scanned:** 10 (lib/rindle.ex, lib/rindle/workers/purge_storage.ex, lib/rindle/ops/variant_maintenance.ex, lib/rindle/domain/media_variant.ex, test/rindle/attach_detach_test.exs, test/rindle/api_surface_boundary_test.exs, test/support/data_case.ex, mix.exs, CHANGELOG.md, deps/ecto/lib/ecto/exceptions.ex)
**Pattern extraction date:** 2026-05-01
