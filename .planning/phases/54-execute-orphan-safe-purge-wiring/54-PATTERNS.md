# Phase 54: Execute + Orphan-Safe Purge Wiring - Pattern Map

**Mapped:** 2026-05-26
**Files analyzed:** 6
**Analogs found:** 6 / 6

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/rindle.ex` | provider | request-response | `lib/rindle.ex` | exact |
| `lib/rindle/internal/owner_erasure.ex` | service | CRUD | `lib/rindle/ops/variant_maintenance.ex` | role-match |
| `lib/rindle/workers/purge_storage.ex` | service | event-driven | `lib/rindle/workers/purge_storage.ex` | exact |
| `test/rindle/owner_erasure_test.exs` | test | CRUD | `test/rindle/attach_detach_test.exs` | role-match |
| `test/rindle/workers/purge_storage_test.exs` | test | event-driven | `test/rindle/workers/purge_storage_test.exs` | exact |
| `test/rindle/attach_detach_test.exs` | test | request-response | `test/rindle/attach_detach_test.exs` | exact |

## Pattern Assignments

### `lib/rindle.ex` (provider, request-response)

**Analog:** `lib/rindle.ex`

**Facade import/alias pattern** ([lib/rindle.ex](/Users/jon/projects/rindle/lib/rindle.ex:1)):
```elixir
alias Rindle.Domain.MediaAsset
alias Rindle.Domain.MediaAttachment
alias Rindle.Error
alias Rindle.Workers.PurgeStorage

import Ecto.Query
```

**Public facade + owner resolution pattern** ([lib/rindle.ex](/Users/jon/projects/rindle/lib/rindle.ex:260), [lib/rindle.ex](/Users/jon/projects/rindle/lib/rindle.ex:593)):
```elixir
@spec attach(MediaAsset.t() | binary(), struct(), String.t(), keyword()) ::
        {:ok, MediaAttachment.t()} | {:error, term()}
def attach(asset_or_id, owner, slot, _opts \\ []) do
  repo = Rindle.Config.repo()
  asset_id = get_asset_id(asset_or_id)
  {owner_type, owner_id} = get_owner_info(owner)
```

```elixir
defp get_owner_info(%{__struct__: module, id: id}) do
  {to_string(module), id}
end
```

**Transactional facade pattern** ([lib/rindle.ex](/Users/jon/projects/rindle/lib/rindle.ex:267)):
```elixir
Ecto.Multi.new()
|> Ecto.Multi.run(:existing, fn repo, _ -> ... end)
|> Ecto.Multi.run(:old_asset, fn tx_repo, %{existing: existing} -> ... end)
|> Oban.insert(:purge, fn %{old_asset: old_asset} ->
  PurgeStorage.new(%{
    "asset_id" => old_asset.id,
    "profile" => old_asset.profile
  })
end)
|> repo.transaction()
|> case do
  {:ok, _} -> :ok
  {:error, :existing, :not_found, _} -> :ok
  {:error, _name, reason, _changes} -> {:error, reason}
end
```

**How to apply it**
- Add `preview_owner_erasure/2` and `erase_owner/2` on `Rindle`, not on a lower-level module.
- Keep `owner` input normalized through `get_owner_info/1`.
- Return semantic tagged tuples from the facade; do not leak `Ecto.Multi` results.

---

### `lib/rindle/internal/owner_erasure.ex` (service, CRUD)

**Analog:** `lib/rindle/ops/variant_maintenance.ex`

**Service module import/result-map pattern** ([lib/rindle/ops/variant_maintenance.ex](/Users/jon/projects/rindle/lib/rindle/ops/variant_maintenance.ex:4)):
```elixir
require Logger

import Ecto.Query

alias Rindle.Domain.{MediaAsset, MediaVariant}
alias Rindle.Repo
alias Rindle.Workers.ProcessVariant
```

```elixir
@type regenerate_result :: %{
        enqueued: non_neg_integer(),
        skipped: non_neg_integer(),
        errors: non_neg_integer()
      }
```

**Query-build + reduce/report pattern** ([lib/rindle/ops/variant_maintenance.ex](/Users/jon/projects/rindle/lib/rindle/ops/variant_maintenance.ex:69)):
```elixir
query =
  from v in MediaVariant,
    join: a in MediaAsset,
    on: a.id == v.asset_id,
    where: v.state in @regeneration_states,
    select: {v.id, v.name, a.id, v.state}

with {:ok, rows} <- safe_all(query),
     {:ok, [existing_skip_count]} <- safe_all(skipped_query) do
  {enqueued, skipped, errors} =
    Enum.reduce(rows, {0, 0, 0}, fn {_variant_id, variant_name, asset_id, _state}, acc ->
      process_enqueue_job(asset_id, variant_name, acc)
    end)
```

**Conflict-as-skip enqueue pattern** ([lib/rindle/ops/variant_maintenance.ex](/Users/jon/projects/rindle/lib/rindle/ops/variant_maintenance.ex:101), [lib/rindle/ops/variant_maintenance.ex](/Users/jon/projects/rindle/lib/rindle/ops/variant_maintenance.ex:226)):
```elixir
case enqueue_job(asset_id, variant_name) do
  {:ok, %Oban.Job{conflict?: true}} ->
    {enq, skip + 1, err}

  {:ok, _job} ->
    {enq + 1, skip, err}

  {:error, reason} ->
    Logger.error("rindle.variant_maintenance.enqueue_failed",
      asset_id: asset_id,
      variant_name: variant_name,
      reason: inspect(reason)
    )
```

```elixir
%{"asset_id" => asset_id, "variant_name" => variant_name}
|> ProcessVariant.new(
  unique: [
    fields: [:args, :worker, :queue],
    keys: [:asset_id, :variant_name],
    states: [:available, :scheduled, :executing, :retryable],
    period: :infinity
  ]
)
|> Oban.insert()
```

**Supplemental `Ecto.Multi` composition pattern** ([lib/rindle/upload/broker.ex](/Users/jon/projects/rindle/lib/rindle/upload/broker.ex:507)):
```elixir
Ecto.Multi.new()
|> Ecto.Multi.update(:verifying_session, ...)
|> Ecto.Multi.run(:verify_fsm_complete, fn _repo, %{verifying_session: vs} -> ... end)
|> Ecto.Multi.update(:asset, ...)
|> Oban.insert(:promote_job, PromoteAsset.new(%{asset_id: asset.id}))
|> repo.transaction()
```

**How to apply it**
- Model the shared planner as a service module that returns plain report maps, not schemas.
- Keep query building set-based and reduce rows into stable report buckets.
- Build execute as planner recompute + `Ecto.Multi.delete_all` + per-asset `Oban.insert`, treating `conflict?: true` as semantic success.

---

### `lib/rindle/workers/purge_storage.ex` (service, event-driven)

**Analog:** `lib/rindle/workers/purge_storage.ex`

**Worker skeleton pattern** ([lib/rindle/workers/purge_storage.ex](/Users/jon/projects/rindle/lib/rindle/workers/purge_storage.ex:1)):
```elixir
defmodule Rindle.Workers.PurgeStorage do
  @moduledoc false
  use Oban.Worker, queue: :rindle_purge, max_attempts: 3

  alias Rindle.Config
  alias Rindle.Domain.{MediaAsset, MediaVariant}
  import Ecto.Query
```

**Current destructive flow to harden** ([lib/rindle/workers/purge_storage.ex](/Users/jon/projects/rindle/lib/rindle/workers/purge_storage.ex:10)):
```elixir
def perform(%Oban.Job{args: %{"asset_id" => asset_id, "profile" => profile_name}}) do
  repo = Config.repo()
  profile_module = String.to_existing_atom(profile_name)

  variant_keys =
    repo.all(from v in MediaVariant, where: v.asset_id == ^asset_id, select: v.storage_key)

  asset = repo.get(MediaAsset, asset_id)
  source_key = if asset, do: asset.storage_key, else: nil
```

```elixir
Enum.each(variant_keys, fn key ->
  if key, do: Rindle.delete(profile_module, key)
end)

if source_key do
  Rindle.delete(profile_module, source_key)
end

if asset do
  repo.delete!(asset)
end
```

**Schema truth to consult for survivor checks**

`media_attachments` ownership shape ([lib/rindle/domain/media_attachment.ex](/Users/jon/projects/rindle/lib/rindle/domain/media_attachment.ex:31)):
```elixir
schema "media_attachments" do
  field :owner_type, :string
  field :owner_id, :binary_id
  field :slot, :string

  belongs_to :asset, Rindle.Domain.MediaAsset
end
```

`media_assets` relationship shape ([lib/rindle/domain/media_asset.ex](/Users/jon/projects/rindle/lib/rindle/domain/media_asset.ex:58)):
```elixir
schema "media_assets" do
  field :storage_key, :string
  field :profile, :string

  has_many :attachments, Rindle.Domain.MediaAttachment, foreign_key: :asset_id
  has_many :variants, Rindle.Domain.MediaVariant, foreign_key: :asset_id
```

**How to apply it**
- Keep the worker boundary and args shape unchanged.
- Insert a live attachment-count re-check before any storage delete or asset-row delete.
- If attachments still exist, return `:ok` without deleting bytes or the asset row.

---

### `test/rindle/owner_erasure_test.exs` (test, CRUD)

**Analog:** `test/rindle/attach_detach_test.exs`

**Test harness pattern** ([test/rindle/attach_detach_test.exs](/Users/jon/projects/rindle/test/rindle/attach_detach_test.exs:1)):
```elixir
use Rindle.DataCase, async: false
use Oban.Testing, repo: Rindle.Repo
import Mox

alias Rindle.Domain.{MediaAsset, MediaAttachment}

setup :set_mox_from_context
setup :verify_on_exit!
```

**Inline owner/profile fixture pattern** ([test/rindle/attach_detach_test.exs](/Users/jon/projects/rindle/test/rindle/attach_detach_test.exs:11)):
```elixir
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
```

**Semantic assertion pattern** ([test/rindle/attach_detach_test.exs](/Users/jon/projects/rindle/test/rindle/attach_detach_test.exs:78)):
```elixir
assert :ok = Rindle.detach(user, "avatar")

assert Rindle.Repo.all(MediaAttachment) == []

assert_enqueued worker: Rindle.Workers.PurgeStorage,
                args: %{"asset_id" => asset.id, "profile" => asset.profile}
```

**How to apply it**
- New owner-erasure tests should stay unit/service-level under `Rindle.DataCase`, not adopter integration scope.
- Build fixtures with multiple attachments sharing one asset so the report can prove both `assets_to_purge` and `retained_shared_assets`.
- Assert semantic report contents and counts, plus Oban enqueue side effects, not internal step names.

---

### `test/rindle/workers/purge_storage_test.exs` (test, event-driven)

**Analog:** `test/rindle/workers/purge_storage_test.exs`

**Worker test setup pattern** ([test/rindle/workers/purge_storage_test.exs](/Users/jon/projects/rindle/test/rindle/workers/purge_storage_test.exs:1)):
```elixir
use Rindle.DataCase, async: false
use Oban.Testing, repo: Rindle.Repo
import Mox

alias Rindle.Domain.{MediaAsset, MediaVariant}
alias Rindle.Workers.PurgeStorage
```

**Perform-job assertion pattern** ([test/rindle/workers/purge_storage_test.exs](/Users/jon/projects/rindle/test/rindle/workers/purge_storage_test.exs:18)):
```elixir
expect(Rindle.StorageMock, :delete, fn key, _opts ->
  assert key in [asset.storage_key, variant.storage_key]
  {:ok, :deleted}
end)

assert :ok =
         perform_job(PurgeStorage, %{
           "asset_id" => asset.id,
           "profile" => to_string(TestProfile)
         })

refute Rindle.Repo.get(MediaAsset, asset.id)
refute Rindle.Repo.get(MediaVariant, variant.id)
```

**Supplemental uniqueness-proof pattern** ([test/rindle/ops/variant_maintenance_test.exs](/Users/jon/projects/rindle/test/rindle/ops/variant_maintenance_test.exs:202)):
```elixir
{:ok, second_job} =
  ProcessVariant.new(args,
    unique: [
      fields: [:args, :worker, :queue],
      keys: [:asset_id, :variant_name],
      states: [:available, :scheduled, :executing, :retryable],
      period: :infinity
    ]
  )
  |> Oban.insert()

assert second_job.conflict?
```

**How to apply it**
- Extend this file with a shared-asset regression: an attachment still exists for the asset, so `perform_job/2` must skip deletes and keep DB rows.
- Keep tests explicit about storage mock expectations; survivor-safe cases should assert delete is not called.
- If uniqueness behavior is asserted for purge jobs, copy the `conflict?` proof style rather than testing only queue counts.

---

### `test/rindle/attach_detach_test.exs` (test, request-response)

**Analog:** `test/rindle/attach_detach_test.exs`

**Regression-lock pattern for enqueue behavior** ([test/rindle/attach_detach_test.exs](/Users/jon/projects/rindle/test/rindle/attach_detach_test.exs:48)):
```elixir
{:ok, _} = Rindle.attach(asset, user, "avatar")
{:ok, attachment} = Rindle.attach(asset2, user, "avatar")

assert attachment.asset_id == asset2.id

attachments = Rindle.Repo.all(MediaAttachment)
assert length(attachments) == 1
assert hd(attachments).asset_id == asset2.id

assert_enqueued worker: Rindle.Workers.PurgeStorage,
                args: %{"asset_id" => asset.id, "profile" => asset.profile}
```

**Idempotent no-op pattern** ([test/rindle/attach_detach_test.exs](/Users/jon/projects/rindle/test/rindle/attach_detach_test.exs:90)):
```elixir
test "is idempotent", %{user: user} do
  assert :ok = Rindle.detach(user, "avatar")
end
```

**How to apply it**
- Keep these tests as regression coverage for existing APIs after worker hardening.
- Add shared-asset scenarios only if needed to prove `attach/4` and `detach/3` still enqueue purge safely under the new worker semantics.
- Preserve the current public contract: enqueue now, destructive safety enforced later by the worker.

## Shared Patterns

### Public Facade Boundary
**Sources:** [lib/rindle.ex](/Users/jon/projects/rindle/lib/rindle.ex:260), [lib/rindle.ex](/Users/jon/projects/rindle/lib/rindle.ex:335)
**Apply to:** `lib/rindle.ex`, `lib/rindle/internal/owner_erasure.ex`
```elixir
repo = Rindle.Config.repo()
{owner_type, owner_id} = get_owner_info(owner)

...

|> repo.transaction()
|> case do
  {:ok, _} -> :ok
  {:error, _name, reason, _changes} -> {:error, reason}
end
```

### Oban Conflict-As-Skip
**Sources:** [lib/rindle/ops/variant_maintenance.ex](/Users/jon/projects/rindle/lib/rindle/ops/variant_maintenance.ex:101), [lib/rindle/ops/lifecycle_repair.ex](/Users/jon/projects/rindle/lib/rindle/ops/lifecycle_repair.ex:254)
**Apply to:** owner-erasure enqueue path, any purge-job dedupe tests
```elixir
case Oban.insert(job) do
  {:ok, %Oban.Job{conflict?: true}} -> skip_or_already_queued_result
  {:ok, _job} -> fresh_enqueue_result
  {:error, reason} -> failure_result(reason)
end
```

### Shared-Asset Truth
**Sources:** [lib/rindle/domain/media_attachment.ex](/Users/jon/projects/rindle/lib/rindle/domain/media_attachment.ex:31), [lib/rindle/domain/media_asset.ex](/Users/jon/projects/rindle/lib/rindle/domain/media_asset.ex:75)
**Apply to:** planner queries, purge-worker survivor check, shared-asset tests
```elixir
belongs_to :asset, Rindle.Domain.MediaAsset
has_many :attachments, Rindle.Domain.MediaAttachment, foreign_key: :asset_id
```

### Test Harness
**Sources:** [test/rindle/attach_detach_test.exs](/Users/jon/projects/rindle/test/rindle/attach_detach_test.exs:1), [test/rindle/workers/purge_storage_test.exs](/Users/jon/projects/rindle/test/rindle/workers/purge_storage_test.exs:1)
**Apply to:** all new phase-local tests
```elixir
use Rindle.DataCase, async: false
use Oban.Testing, repo: Rindle.Repo
import Mox
```

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `lib/rindle/internal/owner_erasure.ex` | service | CRUD | No existing owner-erasure planner/executor exists yet; closest matches cover only query/report style and enqueue semantics. |
| `test/rindle/owner_erasure_test.exs` | test | CRUD | No existing facade-level owner-erasure test exists yet; closest match is slot-scoped attach/detach coverage. |

## Metadata

**Analog search scope:** `lib/rindle.ex`, `lib/rindle/ops/*.ex`, `lib/rindle/upload/*.ex`, `lib/rindle/workers/*.ex`, `lib/rindle/domain/*.ex`, `test/rindle/**/*.exs`, `test/adopter/canonical_app/*.exs`

**Files scanned:** 10

**Pattern extraction date:** 2026-05-26
