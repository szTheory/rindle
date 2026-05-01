# Phase 19: Convenience API Additions — Research

**Researched:** 2026-05-01
**Domain:** Elixir/Ecto facade pattern — read-side helpers and bang variant idioms
**Confidence:** HIGH — all findings verified against live codebase at cited line numbers

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

D-01 through D-27 are all locked. Key decisions that constrain every task:

- D-01: `Rindle.attachment_for(owner, slot, opts \\ [])` — returns `MediaAttachment.t() | nil`
- D-02: Auto-preloads `:asset` by default
- D-03: `opts` accepts `:preload` which REPLACES the default `[:asset]`
- D-04: Reuses `get_owner_info/1` (line 284-286) and `get_asset_id/1` (line 281-282)
- D-05: Multiple rows — most recent by `inserted_at desc, limit: 1`
- D-06: `Rindle.ready_variants_for(asset_or_id)` — returns `[MediaVariant.t()]`, no tuple wrap
- D-07: State filter is `state == "ready"` only
- D-08: Accepts `%MediaAsset{}` or binary id via `get_asset_id/1`
- D-09: Order by `:name` ascending
- D-10: No sibling `variant_ready?/2` predicate in this phase
- D-11: `Rindle.Error` exception with `:action`/`:reason` fields, `message/1` with 3 branches
- D-12: `{:error, %Ecto.Changeset{}}` → `raise Ecto.InvalidChangesetError`
- D-13: `{:error, {:storage_adapter_exception, exception}}` → `raise exception` (fresh stacktrace)
- D-14: All bangs are thin wrappers (4-arm case) over non-bang twins
- D-15: Bang return shapes: `attach!` → `MediaAttachment.t()`, `detach!` → `:ok`, `upload!` → `MediaAsset.t()`, `url!` → `String.t()`, `variant_url!` → `String.t()`
- D-16: Bang arity mirrors non-bang exactly
- D-17: Bang `@doc` is one-line "Same as `foo/N` but ..." form
- D-18: Bang `@spec` returns success type only (no `no_return()`)
- D-19: All 8 new functions + `Rindle.Error` get `@doc` + `@spec`
- D-20: Use named schema types in `@spec` (not `@type storage_result`)
- D-21: Doctests on non-bangs encouraged; bangs do not need doctests
- D-22: New tests in `test/rindle/convenience_api_test.exs`, uses `Rindle.DataCase`
- D-23: Coverage targets per function (see Test Plan section)
- D-24: `Rindle.Error.message/1` branches unit-tested
- D-25: 2 plans — 19-01 RED-only test harness, 19-02 GREEN implementation + closure
- D-26: Defensive split if >6 files in 19-02
- D-27: Agent decides by default; no escalation needed

### Claude's Discretion

- Exact `mix.exs` `groups_for_modules` placement for `Rindle.Error` (default: Facade group alongside `Rindle`)
- Exact `Rindle.Error.message/1` format strings (three branch shapes locked; prose is planner's call)
- Exact `attachment_for/3` `:preload` opt semantics (replace vs merge; default: replace per Ecto convention)
- Whether to land doctests on `attachment_for/2` and `ready_variants_for/1` (default: yes)
- Whether to introduce `lib/rindle/queries.ex` private helper (default: keep inline; extract only if >700 LOC — current `lib/rindle.ex` is 523 LOC)

### Deferred Ideas (OUT OF SCOPE)

- `attachments_for/2` plural helper
- `Rindle.url_for(owner, slot, opts)` higher-level convenience
- `Rindle.attached?(owner, slot)` predicate
- `Rindle.variant_ready?(asset, name)` predicate
- Batched `attachments_for_owners/2`
- Per-operation exception types (`Rindle.AttachError`, `Rindle.UploadError`, etc.)
- 3-arity `{:storage_adapter_exception, exception, stacktrace}` shape
- Custom bang-variant doc generation via macro
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| API-09 | Adopter can call `Rindle.attachment_for(owner, slot)` to fetch an attachment without writing a raw Ecto query | Verified: `MediaAttachment` schema has all required query fields; `get_owner_info/1` reusable at line 284 |
| API-10 | Adopter can call `Rindle.ready_variants_for(asset)` to fetch ready variants without writing a raw Ecto query | Verified: `MediaVariant` schema has `:state` field with `"ready"` value; `get_asset_id/1` reusable at line 281 |
| API-11 | Adopter can use bang variants (`attach!/4`, `detach!/3`, `upload!/3`, `url!/3`, `variant_url!/4`) for happy-path callers | Verified: all non-bang twins return shapes audited; `Ecto.InvalidChangesetError` pattern confirmed in Ecto/Oban deps |
</phase_requirements>

---

## Implementation Approach

Phase 19 is concentrated in two files:

1. **`lib/rindle/error.ex`** — new file, ~30 LOC, `Rindle.Error` exception module [VERIFIED: file does not yet exist]
2. **`lib/rindle.ex`** — 523 LOC currently (well under the 700-LOC extraction threshold); all 8 new public functions land here [VERIFIED: `wc -l lib/rindle.ex` = 523]

Write order in 19-02:
1. Create `lib/rindle/error.ex` first (bangs depend on `Rindle.Error`)
2. Add `alias Rindle.Domain.MediaVariant` to `lib/rindle.ex` (currently missing — only `MediaAsset`, `MediaAttachment`, `MediaUploadSession` are aliased at lines 2-4) [VERIFIED: grep of aliases block]
3. Add `alias Rindle.Error` to `lib/rindle.ex`
4. Implement `attachment_for/2,3` and `ready_variants_for/1` (read helpers, no side effects, test first)
5. Implement the 5 bang variants (thin wrappers, implement last after read helpers compile cleanly)
6. Update `mix.exs` `groups_for_modules` Facade list to include `Rindle.Error`
7. Update `test/rindle/api_surface_boundary_test.exs` `@public_modules` list (19-01 task)
8. Write CHANGELOG entry

**No new dependencies required.** [VERIFIED: `mix.exs` deps list; `doctor ~> 0.22.0` and all test deps already present]

---

## Function-by-Function Specification

### 1. `Rindle.attachment_for/2,3`

**Requirement:** API-09

**Exact `@spec`:**

```elixir
@spec attachment_for(struct(), String.t(), keyword()) :: MediaAttachment.t() | nil
```

The default-arg form generates two specs per Elixir convention:

```elixir
@spec attachment_for(struct(), String.t()) :: MediaAttachment.t() | nil
@spec attachment_for(struct(), String.t(), keyword()) :: MediaAttachment.t() | nil
def attachment_for(owner, slot, opts \\ []) do
```

**Body sketch:**

```elixir
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

**Schema fields verified** [VERIFIED: `lib/rindle/domain/media_attachment.ex`]:
- `:owner_type` — `:string` (line 32)
- `:owner_id` — `:binary_id` (line 33)
- `:slot` — `:string` (line 34)
- `belongs_to :asset, Rindle.Domain.MediaAsset` (line 36)
- `timestamps()` provides `:inserted_at` (line 38)

**Preload semantics (D-03):** `Keyword.get(opts, :preload, [:asset])` — replaces, not merges. Caller writing `preload: [asset: :variants]` gets both asset and its variants; writing `preload: []` or `preload: false` disables all preloading. Matches `Ecto.Repo.get/3` opts behavior. [ASSUMED: `preload: false` behavior — Ecto's `repo.preload/2` accepts an empty list `[]` as "no preloads" but not the atom `false`; planner should use `preload: []` as the "no preload" opt and document accordingly]

**Key private helpers to reuse:**
- `get_owner_info/1` at line 284-286 [VERIFIED: confirmed in `lib/rindle.ex`]
- `Rindle.Config.repo()` at `lib/rindle/config.ex:9` [VERIFIED]

**`read_first` files:**
- `lib/rindle.ex` (lines 281-286: helpers; lines 173-228: `attach/4` usage pattern)
- `lib/rindle/domain/media_attachment.ex`
- `lib/rindle/config.ex`

---

### 2. `Rindle.ready_variants_for/1`

**Requirement:** API-10

**Exact `@spec`:**

```elixir
@spec ready_variants_for(MediaAsset.t() | binary()) :: [MediaVariant.t()]
```

**Body sketch:**

```elixir
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

**State vocabulary verified** [VERIFIED: `lib/rindle/domain/media_variant.ex` line 33]:

```
@states ["planned", "queued", "processing", "ready", "stale", "missing", "failed", "purged"]
```

`"ready"` is confirmed as one of the eight states.

**Schema fields verified** [VERIFIED: `lib/rindle/domain/media_variant.ex`]:
- `:name` — `:string` (line 38)
- `:state` — `:string, default: "planned"` (line 39)
- `belongs_to :asset, Rindle.Domain.MediaAsset` (line 48)
- Unique constraint on `[:asset_id, :name]` (line 78) — `order_by: :name` is deterministic because `name` is unique per `asset_id`

**`do_variant_url` confirmation** [VERIFIED: `lib/rindle/delivery.ex` lines 146-149]:

```elixir
defp do_variant_url(profile, variant_key, "ready", _original_url, opts)
     when is_binary(variant_key) do
  url(profile, variant_key, opts)
end
```

Only `"ready"` returns the variant URL directly. This confirms D-07: `ready_variants_for/1` filtering on `state == "ready"` is the correct and complete filter for "deliverable variants."

**New aliases required in `lib/rindle.ex`:**
- `alias Rindle.Domain.MediaVariant` (not currently present) [VERIFIED: alias block lines 2-9]

**Key private helpers to reuse:**
- `get_asset_id/1` at line 281-282 [VERIFIED]
- `Rindle.Config.repo()` [VERIFIED]

**`read_first` files:**
- `lib/rindle.ex` (lines 281-282: `get_asset_id/1`)
- `lib/rindle/domain/media_variant.ex`
- `lib/rindle/delivery.ex` (lines 146-149: state semantics confirmation)

---

### 3. `Rindle.attach!/4`

**Requirement:** API-11

**Exact `@spec`:**

```elixir
@spec attach!(MediaAsset.t() | binary(), struct(), String.t()) :: MediaAttachment.t()
@spec attach!(MediaAsset.t() | binary(), struct(), String.t(), keyword()) :: MediaAttachment.t()
def attach!(asset_or_id, owner, slot, opts \\ []) do
```

**Non-bang return shapes** [VERIFIED: `lib/rindle.ex` lines 170-228]:
- `{:ok, MediaAttachment.t()}` — success
- `{:error, changeset}` — changeset validation failure (from `Ecto.Multi.insert/3` step `:attachment`; `changeset.action` will be `:insert` because `Ecto.Multi` sets action via `put_action/2` at `deps/ecto/lib/ecto/multi.ex:554-555`) [VERIFIED: `deps/ecto/lib/ecto/multi.ex` line 554]
- `{:error, reason}` — any other Multi step failure (e.g., FK constraint, DB error)
- Note: `{:error, {:storage_adapter_exception, exception}}` is NOT emitted by `attach/4` — it is only emitted by `invoke_storage/3` (line 491-500) which `attach/4` does not call. The bang's four-arm case must still include the `storage_adapter_exception` arm for future-proofing and pattern completeness, but it will not fire for `attach!/4` in practice. [VERIFIED: `lib/rindle.ex` line 491]

**Body sketch:**

```elixir
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

**`action: :insert` justification** [VERIFIED: `deps/ecto/lib/ecto/repo/schema.ex` line 386]: Ecto uses `:insert` for `insert!` bang, `:update` for `update!`, `:delete` for `delete!`. The `Ecto.Multi.insert/3` step sets `changeset.action = :insert` via `put_action/2`. The `Ecto.InvalidChangesetError` action field should mirror what Ecto itself does — `:insert` for the attachment creation step.

**`read_first` files:**
- `lib/rindle.ex` (lines 157-228: `attach/4` full body)
- `lib/rindle/error.ex` (new file, must exist before implementing bang)
- `deps/ecto/lib/ecto/exceptions.ex` (lines 85-140: `Ecto.InvalidChangesetError` shape)

---

### 4. `Rindle.detach!/3`

**Requirement:** API-11

**Exact `@spec`:**

```elixir
@spec detach!(struct(), String.t()) :: :ok
@spec detach!(struct(), String.t(), keyword()) :: :ok
def detach!(owner, slot, opts \\ []) do
```

**Non-bang return shapes** [VERIFIED: `lib/rindle.ex` lines 244-278]:
- `:ok` — success (line 274)
- `:ok` — idempotent when no attachment exists (line 276, `{:error, :existing, :not_found, _} -> :ok`)
- `{:error, reason}` — genuine DB/storage failure (line 277)

**Key insight:** The `detach/3` implementation already absorbs the "not found" case and returns `:ok` (idempotent). The bang wrapper only needs to handle genuine failures. The four-arm case works correctly because the non-bang never returns `{:ok, _}` — it returns bare `:ok`. Adjust accordingly:

**Body sketch:**

```elixir
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

**`action: :delete` justification:** The `detach/3` Multi calls `Ecto.Multi.delete/3` (line 262). If a changeset error occurs on delete, Ecto sets `changeset.action = :delete`. [VERIFIED: `deps/ecto/lib/ecto/repo/schema.ex` line 412]

**Bang return type is `:ok`, not `MediaAttachment.t()`** (D-15). The non-bang returns bare `:ok` on success (not a tagged tuple), so there is no struct to unwrap. The bang passes `:ok` through.

**`read_first` files:**
- `lib/rindle.ex` (lines 231-279: `detach/3` full body)
- `lib/rindle/error.ex` (new file)

---

### 5. `Rindle.upload!/3`

**Requirement:** API-11

**Exact `@spec`:**

```elixir
@spec upload!(module(), map() | Plug.Upload.t()) :: MediaAsset.t()
@spec upload!(module(), map() | Plug.Upload.t(), keyword()) :: MediaAsset.t()
def upload!(profile_module, upload, opts \\ []) do
```

**Non-bang return shapes** [VERIFIED: `lib/rindle.ex` lines 373-419]:
- `{:ok, MediaAsset.t()}` — success (line 408)
- `{:error, {:quarantine, reason}}` — MIME/scan failure (line 412-415)
- `{:error, reason}` — validation, storage, or DB failure (line 417-418)
- `{:error, {:storage_adapter_exception, exception}}` — storage adapter raised (via `invoke_storage/3` → `store/4` called at line 391)

**Body sketch:**

```elixir
def upload!(profile_module, upload, opts \\ []) do
  case upload(profile_module, upload, opts) do
    {:ok, asset} ->
      asset

    {:error, %Ecto.Changeset{} = cs} ->
      raise Ecto.InvalidChangesetError, action: :insert, changeset: cs

    {:error, {:storage_adapter_exception, exception}} when is_exception(exception) ->
      raise exception

    {:error, reason} ->
      raise Rindle.Error, action: :upload, reason: reason
  end
end
```

**Quarantine case:** `{:error, {:quarantine, reason}}` matches the `{:error, reason}` arm (because `{:quarantine, reason}` is the whole `reason` term). `Rindle.Error.message/1` has a branch for `{:quarantine, why}` that formats it descriptively. [VERIFIED: `lib/rindle.ex` lines 412-415]

**Storage adapter exception:** `upload/3` calls `store/4` at line 391, which calls `invoke_storage/3` at line 491-500. If the storage adapter raises, `invoke_storage/3` wraps it as `{:error, {:storage_adapter_exception, exception}}`. This propagates through `upload/3`'s `with` chain (the `{:ok, _storage_meta} <- store(...)` arm fails, falls to the `else` `{:error, reason}` clause at line 417 — actually the `{:error, {:quarantine, reason}}` special case is checked first, then the generic `{:error, reason}` catchall). The `storage_adapter_exception` tuple is thus surfaced as `{:error, {:storage_adapter_exception, exception}}` from `upload/3`. [VERIFIED: `lib/rindle.ex` lines 384-419]

**`read_first` files:**
- `lib/rindle.ex` (lines 357-420: `upload/3` full body)
- `lib/rindle/error.ex` (new file)

---

### 6. `Rindle.url!/3`

**Requirement:** API-11

**Exact `@spec`:**

```elixir
@spec url!(module(), String.t()) :: String.t()
@spec url!(module(), String.t(), keyword()) :: String.t()
def url!(profile, key, opts \\ []) do
```

**Non-bang return shapes** [VERIFIED: `lib/rindle.ex` lines 333-336 and `lib/rindle/delivery.ex` lines 97-117]:
- `{:ok, String.t()}` — success
- `{:error, reason}` — authorization failure, capability check failure, or storage error
- `{:error, {:storage_adapter_exception, exception}}` — storage adapter raised (via `invoke_storage/3`)

**Body sketch:**

```elixir
def url!(profile, key, opts \\ []) do
  case url(profile, key, opts) do
    {:ok, url_string} ->
      url_string

    {:error, %Ecto.Changeset{} = cs} ->
      raise Ecto.InvalidChangesetError, action: :insert, changeset: cs

    {:error, {:storage_adapter_exception, exception}} when is_exception(exception) ->
      raise exception

    {:error, reason} ->
      raise Rindle.Error, action: :url, reason: reason
  end
end
```

Note: The `{:error, %Ecto.Changeset{}}` arm will not fire for `url!/3` in practice (URL generation does not produce changesets), but is included for pattern completeness per D-14's universal four-arm template. [ASSUMED: changeset arm is dead code for url!/3 but included for template consistency]

**`read_first` files:**
- `lib/rindle.ex` (lines 322-335: `url/3`)
- `lib/rindle/delivery.ex` (full file: `url/3` implementation)

---

### 7. `Rindle.variant_url!/4`

**Requirement:** API-11

**Exact `@spec`:**

```elixir
@spec variant_url!(module(), map(), map()) :: String.t()
@spec variant_url!(module(), map(), map(), keyword()) :: String.t()
def variant_url!(profile, asset, variant, opts \\ []) do
```

**Non-bang return shapes** [VERIFIED: `lib/rindle.ex` lines 352-355 and `lib/rindle/delivery.ex` lines 135-163]:
- `{:ok, String.t()}` — success (variant URL or fallback original URL)
- `{:error, reason}` — authorization failure, capability check failure, or storage error

**Body sketch:**

```elixir
def variant_url!(profile, asset, variant, opts \\ []) do
  case variant_url(profile, asset, variant, opts) do
    {:ok, url_string} ->
      url_string

    {:error, %Ecto.Changeset{} = cs} ->
      raise Ecto.InvalidChangesetError, action: :insert, changeset: cs

    {:error, {:storage_adapter_exception, exception}} when is_exception(exception) ->
      raise exception

    {:error, reason} ->
      raise Rindle.Error, action: :variant_url, reason: reason
  end
end
```

**`read_first` files:**
- `lib/rindle.ex` (lines 339-355: `variant_url/4`)
- `lib/rindle/delivery.ex` (lines 135-163: `variant_url/4` implementation)

---

### 8. New aliases needed in `lib/rindle.ex`

**Currently aliased** (lines 2-9) [VERIFIED]:
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

**Must add in 19-02:**
```elixir
alias Rindle.Domain.MediaVariant   # needed for ready_variants_for/1 query
alias Rindle.Error                 # needed for bang raise calls
```

---

## Rindle.Error Module

**File:** `lib/rindle/error.ex` (new file)

**Doctor compliance requirements** [VERIFIED: `.doctor.exs`]:
- `exception_moduledoc_required: true` — `Rindle.Error` needs a `@moduledoc`
- `struct_type_spec_required: true` — exception structs need a `@type t` (inherited via `defexception`, but verify doctor satisfaction)
- `min_module_doc_coverage: 100` — all public functions need `@doc`

**`Rindle.Error` is NOT in the `ignore_modules` list** [VERIFIED: `.doctor.exs` — the list covers `~r/^Rindle\.Internal\./`, `~r/^Rindle\.Security\./`, `~r/^Rindle\.Ops\./`, and explicit module names; `Rindle.Error` is not listed]. This means it MUST have full doc/spec coverage to keep the gate green.

**Exact module content sketch (~30 LOC):**

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

**Notes on doctor compliance:**
- `defexception` defines `exception/1` and `message/1` callbacks — the `@impl true` on `message/1` points doctor to the `Exception` behaviour doc, satisfying the coverage requirement. [VERIFIED: Phase 18 D-17 pattern; `Ecto.InvalidChangesetError` uses same approach at `deps/ecto/lib/ecto/exceptions.ex:92`]
- The `@type t` must be explicitly defined because `defexception` does not auto-generate it in a way that satisfies `struct_type_spec_required: true`.
- `@moduledoc` is required because `exception_moduledoc_required: true` in `.doctor.exs`.

---

## Test Plan

**File:** `test/rindle/convenience_api_test.exs` (new file in 19-01)

**Boilerplate (from `attach_detach_test.exs` pattern)** [VERIFIED: `test/rindle/attach_detach_test.exs` lines 1-36]:

```elixir
defmodule Rindle.ConvenienceApiTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo
  import Mox

  alias Rindle.Domain.{MediaAsset, MediaAttachment, MediaVariant}

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

**`Rindle.DataCase` provides** [VERIFIED: `test/support/data_case.ex`]:
- `Rindle.Repo` alias
- `import Ecto`, `import Ecto.Changeset`, `import Ecto.Query`
- Sandbox ownership via `setup_sandbox/1`
- No factory library — direct changeset insertion is the pattern

**`Rindle.StorageMock`** is defined at `test/support/mocks.ex:1` [VERIFIED]: `Mox.defmock(Rindle.StorageMock, for: Rindle.Storage)`. Bang tests for `url!/3` and `variant_url!/4` need a configured `TestProfile` with `storage: Rindle.StorageMock` and will require mock expectations.

**Test cases by function (D-23):**

### `attachment_for/2,3` tests

```
describe "attachment_for/2" do
  # nil case: no attachment at slot → returns nil
  test "returns nil when no attachment exists at slot", %{user: user}
  
  # happy path: returns MediaAttachment with :asset preloaded
  test "returns attachment with asset preloaded", %{asset: asset, user: user}
    # assert %MediaAttachment{asset: %MediaAsset{}} = result
  
  # preload opt override: preload: [] disables auto-preload
  test "with preload: [] does not preload the asset", %{asset: asset, user: user}
    # assert %MediaAttachment{asset: %Ecto.Association.NotLoaded{}} = result
  
  # multi-row tie-breaking: most recent wins
  test "returns most recent attachment when multiple rows exist for same owner+slot",
    %{asset: asset, user: user}
    # insert asset1 → attach → insert asset2 → attach (second wins by inserted_at desc)
    # result.asset_id == asset2.id
end
```

### `ready_variants_for/1` tests

```
describe "ready_variants_for/1" do
  # empty list when no variants exist
  test "returns empty list when no variants exist for asset", %{asset: asset}
  
  # only "ready" state returned (verify "processing" excluded)
  test "returns only ready variants, excluding processing state", %{asset: asset}
    # insert two variants: one "ready", one "processing"
    # assert [ready_variant] = Rindle.ready_variants_for(asset)
  
  # order by :name asc
  test "returns variants ordered by name ascending", %{asset: asset}
    # insert "thumb" and "large" variants both "ready"
    # assert ["large", "thumb"] == Enum.map(result, & &1.name)
  
  # struct input
  test "accepts a MediaAsset struct", %{asset: asset}
  
  # binary id input
  test "accepts a binary asset id", %{asset: asset}
    # Rindle.ready_variants_for(asset.id)
end
```

### Bang variant tests

For each bang, the test pattern is:

```
describe "attach!/4" do
  test "returns MediaAttachment on success", %{asset: asset, user: user}
  test "raises Rindle.Error with action :attach for non-changeset errors"
    # this requires forcing a genuine error — use a non-existent asset_id
    # to trigger FK constraint; OR mock the Multi to fail
  test "raises Ecto.InvalidChangesetError for changeset failures"
    # insert a changeset with missing required fields
end

describe "detach!/3" do
  test "returns :ok on success", %{asset: asset, user: user}
  test "returns :ok when no attachment exists (idempotent)", %{user: user}
  test "raises Rindle.Error for genuine failures"
end

describe "upload!/3" do
  test "returns MediaAsset on success"
    # requires StorageMock expectation + tmp file
  test "raises Rindle.Error for quarantine failure"
  test "raises Ecto.InvalidChangesetError for changeset failures"
end

describe "url!/3" do
  test "returns URL string on success"
    # requires StorageMock expectation
  test "raises Rindle.Error on authorization/capability failure"
end

describe "variant_url!/4" do
  test "returns URL string on success"
    # requires StorageMock expectation + ready variant
  test "raises Rindle.Error on failure"
end
```

### `Rindle.Error.message/1` unit tests (D-24)

```
describe "Rindle.Error.message/1" do
  test "formats :not_found reason"
    # assert "could not attach: not found" == Rindle.Error.message(%Rindle.Error{action: :attach, reason: :not_found})
  
  test "formats {:quarantine, why} reason"
    # assert String.contains?(msg, "quarantined")
  
  test "formats arbitrary reason via inspect"
    # assert msg =~ inspect(:some_reason)
end
```

**Forcing error states without infrastructure:**
- For `attach!/4` changeset error: insert a `MediaAttachment` directly with an invalid changeset (missing `:slot`)
- For `attach!/4` generic error: pass a non-existent `asset_id` binary — FK constraint will fail, surfacing as `{:error, reason}` after Multi extracts the changeset from the transaction result
- For `upload!/3` quarantine: no mock needed — the `UploadValidation` module handles this; test with an actual MIME mismatch file [ASSUMED: quarantine test strategy; may need to check `UploadValidation` implementation to confirm]
- For `{:error, {:storage_adapter_exception, exception}}`: use `Rindle.StorageMock` configured to raise an exception — the mock can be set up with `expect(Rindle.StorageMock, :store, fn _, _, _ -> raise "boom" end)`

---

## Validation Architecture

### Invariant: `attachment_for/2`

**What must hold:**
1. `attachment_for(user, "avatar")` immediately after `attach!(asset, user, "avatar")` returns a `%MediaAttachment{}` with `attachment.asset_id == asset.id` and `attachment.asset` is a loaded `%MediaAsset{}` (not `%Ecto.Association.NotLoaded{}`).
2. `attachment_for(user, "ghost_slot")` returns `nil` when no attach was performed.
3. `attachment_for(user, "avatar", preload: [])` returns a `%MediaAttachment{}` with `attachment.asset` equal to `%Ecto.Association.NotLoaded{}`.
4. When two attachments exist for the same `(owner_type, owner_id, slot)` (inserted at different times), the result has the `asset_id` of the most-recently inserted row.

**Fail-fast signals:**
- `mix test test/rindle/convenience_api_test.exs` — all 4 attachment_for cases
- `mix doctor --full --raise` — fails if `@doc` or `@spec` missing on the new function
- Credo strict — fails if `from` query is not using Ecto.Query import (already imported via `import Ecto.Query` in the facade)

**Test layer:** Integration (hits the test DB via `Rindle.DataCase` Sandbox)

---

### Invariant: `ready_variants_for/1`

**What must hold:**
1. Empty list when asset has no variants.
2. Empty list when asset has variants but none in `"ready"` state.
3. Returns only `"ready"` variants; a `"processing"` row with the same asset is excluded.
4. Result list is ordered by `name` ascending — `["large", "thumb"]` not `["thumb", "large"]`.
5. Both `ready_variants_for(asset)` and `ready_variants_for(asset.id)` return identical results.

**Fail-fast signals:**
- `mix test test/rindle/convenience_api_test.exs` — all 5 ready_variants_for cases
- If ordering assertion fails on `name`: check that `order_by: [asc: v.name]` is present (not `:inserted_at`)

**Test layer:** Integration

---

### Invariants: Bang variants

**What must hold:**
1. `attach!(asset, user, "avatar")` returns the same `%MediaAttachment{}` struct that `attach/4` would return inside `{:ok, _}`.
2. `detach!(user, "avatar")` returns `:ok` (not `{:ok, :ok}`).
3. Calling `detach!(user, "avatar")` when no attachment exists returns `:ok` without raising (idempotent behavior preserved).
4. `attach!(asset, user, "avatar")` with a missing asset FK raises an exception (not returns `{:error, _}`).
5. `Ecto.InvalidChangesetError` is raised (not `Rindle.Error`) when the error is `{:error, %Ecto.Changeset{}}`.
6. `Rindle.Error` is raised (not `Ecto.InvalidChangesetError`) when the error is `{:error, :some_atom}`.
7. The `:storage_adapter_exception` arm re-raises the ORIGINAL exception type (e.g., `RuntimeError`), not a `Rindle.Error`.

**Fail-fast signals:**
- `mix test test/rindle/convenience_api_test.exs` — per-bang success + each error arm
- `assert_raise Ecto.InvalidChangesetError, fn -> ... end` — confirms changeset arm
- `assert_raise Rindle.Error, fn -> ... end` — confirms generic arm
- `assert_raise RuntimeError, fn -> ... end` — confirms re-raise arm (using a mock that raises)

**Test layer:** Unit/Integration (no real storage needed for most bang tests; `Rindle.StorageMock` for storage exception arm)

---

### Invariant: `Rindle.Error` exception

**What must hold:**
1. `Rindle.Error.exception(action: :attach, reason: :not_found)` produces a struct with `action: :attach` and `reason: :not_found`.
2. `Rindle.Error.message(%Rindle.Error{action: :attach, reason: :not_found})` == `"could not attach: not found"`.
3. `Rindle.Error.message(%Rindle.Error{action: :upload, reason: {:quarantine, :mime_mismatch}})` contains `"quarantined"`.
4. `Rindle.Error.message(%Rindle.Error{action: :url, reason: :unauthorized})` contains `inspect(:unauthorized)`.
5. `raise Rindle.Error, action: :attach, reason: :not_found` produces a string message matching invariant 2 (validated via `rescue e in Rindle.Error -> e.message`).

**Fail-fast signals:**
- `mix test test/rindle/convenience_api_test.exs` — `message/1` branch tests
- `mix doctor --full --raise` — fails if `Rindle.Error` lacks `@moduledoc`, `@doc` on `message/1`, or `@type t`

**Test layer:** Unit (no DB, no mocks)

---

### Invariant: `api_surface_boundary_test.exs` contract

**What must hold:**
1. `Rindle.Error` appears in `@public_modules` — `visible_module?(Rindle.Error)` returns `true`.
2. `Rindle.attachment_for/3`, `Rindle.ready_variants_for/1`, `Rindle.attach!/4`, `Rindle.detach!/3`, `Rindle.upload!/3`, `Rindle.url!/3`, `Rindle.variant_url!/4` are all `function_exported?/3` truthy.

**Fail-fast signals:**
- `mix test test/rindle/api_surface_boundary_test.exs` — RED in 19-01, GREEN in 19-02

**Test layer:** Compiled-docs boundary (uses `Code.fetch_docs/1`)

---

### Validating `storage_adapter_exception` re-raise without a real S3 outage

**Strategy:** Use `Rindle.StorageMock` (already defined at `test/support/mocks.ex:1`) to configure the `:store` callback to raise. The `invoke_storage/3` function at line 491-500 wraps any exception in `{:error, {:storage_adapter_exception, exception}}`. The bang then re-raises.

**Concrete test pattern:**

```elixir
test "upload!/3 re-raises storage adapter exceptions" do
  expect(Rindle.StorageMock, :store, fn _key, _path, _opts ->
    raise RuntimeError, "simulated S3 timeout"
  end)

  # Create a minimal upload map
  upload = %{path: "/tmp/test.jpg", filename: "test.jpg", content_type: "image/jpeg", byte_size: 100}

  assert_raise RuntimeError, "simulated S3 timeout", fn ->
    Rindle.upload!(TestProfile, upload)
  end
end
```

[VERIFIED: `Rindle.StorageMock` for `Rindle.Storage` behaviour exists at `test/support/mocks.ex:1`; `invoke_storage/3` rescue at `lib/rindle.ex:497-499`]

---

## CI / Doctor Gate Verification

**CI status** [VERIFIED: `.github/workflows/ci.yml`]:
- `MIX_ENV=test mix doctor --full --raise` runs in the `quality` job
- No new CI step is needed for Phase 19

**Doctor thresholds** [VERIFIED: `.doctor.exs`]:
- `min_module_doc_coverage: 100`
- `min_overall_doc_coverage: 100`
- `min_overall_moduledoc_coverage: 100`
- `min_module_spec_coverage: 95`
- `min_overall_spec_coverage: 95`
- `exception_moduledoc_required: true` — `Rindle.Error` needs `@moduledoc`
- `struct_type_spec_required: true` — `Rindle.Error` needs explicit `@type t`

**What new code must have to keep CI green:**

| Item | Required |
|------|----------|
| `lib/rindle/error.ex` | `@moduledoc`, `@type t`, `@doc` on `message/1`, `@impl true` on `message/1`, `@spec message(t()) :: String.t()` |
| `Rindle.attachment_for/2,3` | `@doc` (full block with `## Examples`), `@spec` (two specs for default-arg form) |
| `Rindle.ready_variants_for/1` | `@doc` (full block with `## Examples`), `@spec` |
| All 5 bang variants | `@doc` (one-line per D-17), two `@spec` entries each (for default-arg form) |

**Doctor `ignore_modules` — no changes needed** [VERIFIED: `.doctor.exs`]: `Rindle.Error` is NOT in the ignore list and should not be added (it is a public module).

**Verify locally before commit:**

```bash
MIX_ENV=test mix doctor --full --raise
mix test
```

**ExDoc group slot for `Rindle.Error`** [VERIFIED: `mix.exs` lines 126-170]:

Current `Facade` group (line 127-129):

```elixir
Facade: [
  Rindle
],
```

After 19-02, add `Rindle.Error` to the Facade group (default per D-19):

```elixir
Facade: [
  Rindle,
  Rindle.Error
],
```

---

## Risk Inventory

### Risk 1: `detach!/3` wraps bare `:ok`, not `{:ok, _}`

**Landmine:** The standard D-14 four-arm `case` pattern assumes the non-bang returns `{:ok, value}`. `detach/3` returns bare `:ok`, not `{:ok, :ok}`. The bang's first arm MUST match `:ok -> :ok`, not `{:ok, result} -> result`. If the implementer copies the `attach!/4` body verbatim, the `{:ok, _}` arm will never match and `:ok` falls through to the `{:error, _}` arm, raising `Rindle.Error` on every successful detach.

**Prevention:** The body sketch above shows the correct `:ok -> :ok` arm. [VERIFIED: `lib/rindle.ex` line 274 — `detach/3` returns bare `:ok`]

---

### Risk 2: `Ecto.InvalidChangesetError` `action:` field must be an atom that Ecto's `message/1` uses

**Landmine:** `Ecto.InvalidChangesetError.message/1` interpolates `"could not perform #{action} because changeset is invalid."`. If the action atom is `:insert` it renders `"could not perform insert..."`. This is correct Ecto behavior. Using a non-standard action atom (e.g., `:create`) will still work (Ecto just interpolates it), but deviates from convention. For `upload!/3`, the changeset error comes from the `Ecto.Multi.insert(:asset, ...)` step, so the changeset action is `:insert`. For `attach!/4`, same. Neither `url!/3` nor `variant_url!/4` produce changesets in practice.

**Confirmed action values per bang:**
- `attach!/4` → `:insert` (from Multi.insert :attachment step)
- `upload!/3` → `:insert` (from Multi.insert :asset step)
- `detach!/3` → `:delete` (from Multi.delete :attachment step, theoretically)

[VERIFIED: `deps/ecto/lib/ecto/multi.ex:554-555` — Multi sets `changeset.action` via `put_action/2`]

---

### Risk 3: `Rindle.Config.repo()` in test mode

**Landmine:** `Rindle.Config.repo()` reads `Application.get_env(:rindle, :repo, Rindle.Repo)` [VERIFIED: `lib/rindle/config.ex:9-11`]. In the test suite, the configured value is `Rindle.Repo` (the internal test repo). `attach_detach_test.exs` already uses `Rindle.Config.repo()` successfully via `attach/4` and `detach/3`, so there is no new risk here — the pattern is established.

**Verdict:** No risk for Phase 19. New helpers use the same accessor pattern already proven in test mode.

---

### Risk 4: `preload: false` vs `preload: []` for disabling preloads

**Landmine:** `Ecto.Repo.preload/2` does not accept the atom `false` — it expects an association name, a list, or a keyword list. If the `attachment_for/3` test writes `preload: false` and the implementation passes it to `repo.preload(attachment, false)`, the call will crash with a protocol error.

**Prevention:** The `attachment_for/3` body uses `Keyword.get(opts, :preload, [:asset])`. If caller passes `preload: []`, the result is `repo.preload(attachment, [])` which is a no-op. If caller passes `preload: false`, the result is `repo.preload(attachment, false)` which crashes. The `@doc` must document `preload: []` (empty list) as the correct opt to disable preloading, NOT `preload: false`. D-23 test case "with `preload: []` disables preload" should test with `[]` not `false`. [ASSUMED: `Ecto.Repo.preload/2` does not accept `false` — based on Ecto API convention; verify at implementation time]

---

### Risk 5: Doctor `struct_type_spec_required: true` and `defexception`

**Landmine:** The `.doctor.exs` has `struct_type_spec_required: true`. Exception modules defined with `defexception` ARE structs (they `use Exception` which calls `defstruct`). Doctor may require an explicit `@type t :: %__MODULE__{}` annotation. The auto-generated `t()` type from `defexception` may or may not satisfy doctor's check.

**Prevention:** The `Rindle.Error` module sketch includes an explicit `@type t :: %__MODULE__{action: atom(), reason: term()}`. Add it to be safe — it also serves as documentation. If doctor does NOT require it, the type definition still helps Dialyzer.

[VERIFIED: `.doctor.exs:53` — `struct_type_spec_required: true` confirmed; cannot verify doctor's behavior with `defexception` without running it. Flag for implementation task: run `MIX_ENV=test mix doctor --full` after creating the file and before writing tests to catch this early]

---

## CHANGELOG Entry Draft

Append to the `## [Unreleased]` section in `CHANGELOG.md` under `### Added`:

```markdown
### Added (Phase 19 — Plan 19-02)

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

## Open Questions for Planner

1. **`preload: false` vs `preload: []` in tests and docs** — D-23 says "planner decides exact override semantics." Recommend documenting `preload: []` (empty list) as the canonical opt for disabling preloads, not `preload: false`. The implementation's `Keyword.get(opts, :preload, [:asset])` naturally handles this.

2. **Doctest placement** — D-21 says doctests are encouraged on `attachment_for/2` and `ready_variants_for/1`. Doctests in `lib/rindle.ex` run against the actual DB (requires the test repo setup). The existing `attach/4` doctest pattern uses `# Requires a configured Rindle repo...` comment rather than actually running in `iex` (they are illustrative). Recommend the same approach for Phase 19 rather than true runnable doctests, to avoid flaky test setup.

3. **`mix.exs` Facade group slot** — D-19 defers this to the planner. Default recommendation: add `Rindle.Error` to the existing `Facade` group in `mix.exs` line 127-129, after `Rindle`. This requires one line change in `mix.exs`.

4. **Whether to add `Oban.Testing` to `convenience_api_test.exs`** — `attach_detach_test.exs` uses `use Oban.Testing, repo: Rindle.Repo` to assert `assert_enqueued`. The new `attachment_for/2` and `ready_variants_for/1` tests do not enqueue jobs, but the bang tests for `attach!/4` and `detach!/3` trigger `PurgeStorage` jobs. Recommend including `use Oban.Testing, repo: Rindle.Repo` in the test module to keep parity with `attach_detach_test.exs`.

5. **`async: false` vs `async: true`** — `attach_detach_test.exs` uses `async: false` (required because Mox's `set_mox_from_context` only works with `async: false` in shared mode). The new test file will also use `Rindle.StorageMock` for bang tests, so `async: false` is required.

---

## Sources

### Primary (HIGH confidence — verified against live codebase)
- `lib/rindle.ex` — lines 2-9 (aliases), 170-228 (`attach/4` return shapes), 244-278 (`detach/3` return shapes), 373-419 (`upload/3` return shapes), 281-286 (private helpers), 491-500 (`invoke_storage/3` exception wrapping)
- `lib/rindle/domain/media_attachment.ex` — lines 29-39 (schema fields and `@type t`)
- `lib/rindle/domain/media_variant.ex` — lines 33-48 (state vocabulary, schema fields, unique constraint)
- `lib/rindle/domain/media_asset.ex` — lines 34-46 (state vocabulary), line 47 (`@type t`)
- `lib/rindle/delivery.ex` — lines 146-149 (`do_variant_url` confirms `"ready"` semantics)
- `lib/rindle/config.ex` — line 9-11 (`Rindle.Config.repo/0`)
- `test/rindle/attach_detach_test.exs` — lines 1-36 (fixture template)
- `test/rindle/api_surface_boundary_test.exs` — lines 4-31 (`@public_modules` allowlist)
- `test/support/data_case.ex` — full file (Sandbox setup pattern)
- `test/support/mocks.ex` — line 1 (`Rindle.StorageMock` definition)
- `.doctor.exs` — full file (thresholds, `exception_moduledoc_required`, `struct_type_spec_required`, `ignore_modules`)
- `mix.exs` — lines 126-170 (`groups_for_modules` layout)
- `.github/workflows/ci.yml` — `quality` job doctor step

### Primary (HIGH confidence — verified against deps)
- `deps/ecto/lib/ecto/exceptions.ex` — lines 85-140 (`Ecto.InvalidChangesetError` shape and `message/1`)
- `deps/ecto/lib/ecto/multi.ex` — lines 550-565 (`put_action/2` — Multi sets `changeset.action`)
- `deps/ecto/lib/ecto/repo/schema.ex` — lines 378-412 (`insert!/2`, `update!/2`, `delete!/2` patterns)
- `deps/oban/lib/oban.ex` — lines 681-692 (`insert!/3` bang pattern with `Ecto.InvalidChangesetError`)

---

## RESEARCH COMPLETE

**Phase:** 19 — Convenience API Additions
**Confidence:** HIGH — all implementation-critical facts verified against live codebase

### Key Findings

1. **`lib/rindle.ex` is 523 LOC** — below the 700-LOC extraction threshold; all 8 functions stay inline per D-26 default. Two new aliases are needed: `Rindle.Domain.MediaVariant` and `Rindle.Error`.

2. **Schema field names confirmed for both query helpers** — `MediaAttachment` has `:owner_type`, `:owner_id`, `:slot`, `:inserted_at`; `MediaVariant` has `:asset_id`, `:state`, `:name`. No surprises.

3. **`detach!/3` bang requires special treatment** — `detach/3` returns bare `:ok` (not `{:ok, _}`), so the bang's first arm must be `:ok -> :ok`, not `{:ok, result} -> result`. This is the #1 implementation trap.

4. **`storage_adapter_exception` does NOT fire from `attach/4` or `detach/3`** — only from functions that call `invoke_storage/3` (`store`, `download`, `delete`, `url`, `presigned_put`, `head`). The four-arm case in `attach!/4` and `detach!/3` includes the arm for completeness but it is dead code for those two bangs.

5. **Doctor gate requires `@moduledoc` + `@type t` on `Rindle.Error`** — `exception_moduledoc_required: true` and `struct_type_spec_required: true` are both set in `.doctor.exs`. The module sketch includes both.

### File to Consume
`/Users/jon/projects/rindle/.planning/phases/19-convenience-api-additions/19-RESEARCH.md`

### Confidence Assessment
| Area | Level | Reason |
|------|-------|--------|
| Schema fields for queries | HIGH | Read directly from schema source files |
| Bang return-shape audit | HIGH | Read every non-bang return path in `lib/rindle.ex` |
| Doctor compliance requirements | HIGH | Read `.doctor.exs` directly |
| `Ecto.InvalidChangesetError` action values | HIGH | Verified against `deps/ecto` source |
| `preload: false` behavior | ASSUMED | Based on Ecto API convention; verify at implementation |
| Quarantine test strategy | ASSUMED | Based on `UploadValidation` code path inference; may need to check the actual module |

### Ready for Planning
Research complete. Planner can create 19-01-PLAN.md and 19-02-PLAN.md.
