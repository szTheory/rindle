# Phase 8: Storage Capability Confidence - Pattern Map

**Mapped:** 2026-04-28
**Files analyzed:** 11
**Analogs found:** 10 / 11

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/rindle/storage.ex` | config | request-response | `lib/rindle/storage.ex` | exact |
| `lib/rindle/storage/capabilities.ex` | utility | request-response | `lib/rindle/delivery.ex`, `lib/rindle/upload/broker.ex`, `lib/rindle/config.ex` | partial |
| `lib/rindle/upload/broker.ex` | service | request-response | `lib/rindle/upload/broker.ex` | exact |
| `lib/rindle/delivery.ex` | service | request-response | `lib/rindle/delivery.ex` | exact |
| `lib/rindle/storage/s3.ex` | service | request-response | `lib/rindle/storage/s3.ex` | exact |
| `lib/rindle/storage/local.ex` | service | request-response | `lib/rindle/storage/local.ex` | exact |
| `test/rindle/storage/storage_adapter_test.exs` | test | request-response | `test/rindle/storage/storage_adapter_test.exs` | exact |
| `test/rindle/upload/broker_test.exs` | test | request-response | `test/rindle/upload/broker_test.exs` | exact |
| `test/rindle/delivery_test.exs` | test | request-response | `test/rindle/delivery_test.exs` | exact |
| `test/rindle/storage/s3_test.exs` | test | file-I/O | `test/rindle/storage/s3_test.exs` | exact |
| `test/adopter/canonical_app/lifecycle_test.exs` | test | file-I/O | `test/adopter/canonical_app/lifecycle_test.exs` | exact |

## Pattern Assignments

### `lib/rindle/storage.ex` (config, request-response)

**Analog:** `lib/rindle/storage.ex`

**Behaviour contract pattern** (`lib/rindle/storage.ex:1-55`):
```elixir
defmodule Rindle.Storage do
  @moduledoc """
  Behaviour contract for all storage adapters used by Rindle.

  Storage I/O must never happen inside database transactions. Callers should
  persist domain state first, then execute storage side effects in separate
  steps.
  """

  @callback presigned_put(key :: String.t(), expires_in :: pos_integer(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}

  @callback initiate_multipart_upload(
              key :: String.t(),
              part_size :: pos_integer(),
              opts :: keyword()
            ) :: {:ok, map()} | {:error, term()}

  @callback complete_multipart_upload(
              key :: String.t(),
              upload_id :: String.t(),
              parts :: [map() | {pos_integer(), String.t()}],
              opts :: keyword()
            ) :: {:ok, map()} | {:error, term()}

  @callback abort_multipart_upload(
              key :: String.t(),
              upload_id :: String.t(),
              opts :: keyword()
            ) :: {:ok, term()} | {:error, term()}

  @callback head(key :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}

  @callback capabilities() :: [atom()]
end
```

Use this file as the contract authority. Phase 8 should centralize capability names here or immediately beside it, not scatter new atoms across broker, delivery, adapters, and docs.

---

### `lib/rindle/storage/capabilities.ex` (utility, request-response)

**Closest analogs:** `lib/rindle/config.ex`, `lib/rindle/delivery.ex`, `lib/rindle/upload/broker.ex`

There is no dedicated capability helper yet. If Phase 8 introduces one, copy these existing patterns:

**Central accessor module shape** (`lib/rindle/config.ex:1-24`):
```elixir
defmodule Rindle.Config do
  @moduledoc """
  Centralized accessors for foundational runtime configuration.
  """

  @spec repo() :: module()
  def repo do
    Application.get_env(:rindle, :repo, Rindle.Repo)
  end
end
```

**Capability gate return shape for delivery** (`lib/rindle/delivery.ex:183-210`):
```elixir
defp ensure_signed_delivery_support(_adapter, :public), do: :ok

defp ensure_signed_delivery_support(adapter, :private) do
  capabilities = safe_capabilities(adapter)

  if :signed_url in capabilities do
    :ok
  else
    {:error, {:delivery_unsupported, :signed_url}}
  end
end

defp safe_capabilities(adapter) do
  case adapter.capabilities() do
    caps when is_list(caps) -> caps
    _ -> []
  end
rescue
  _ -> []
end
```

**Capability gate return shape for upload** (`lib/rindle/upload/broker.ex:411-429`):
```elixir
defp ensure_capability(adapter, capability) do
  if capability in adapter.capabilities() do
    :ok
  else
    {:error, {:upload_unsupported, capability}}
  end
end

defp ensure_multipart_session(_session), do: {:error, {:upload_unsupported, :multipart_upload}}
```

If you add a helper, keep it dumb and declarative: exported constants/predicates plus tagged-error helpers. Do not move provider-specific branching into callers.

---

### `lib/rindle/upload/broker.ex` (service, request-response)

**Analog:** `lib/rindle/upload/broker.ex`

**Runtime seam + capability gate at entrypoint** (`lib/rindle/upload/broker.ex:67-107`):
```elixir
def initiate_multipart_session(profile_module, opts \\ []) do
  repo = Config.repo()
  profile_name = profile_module_to_name(profile_module)
  ...
  adapter = profile_module.storage_adapter()

  with :ok <- ensure_capability(adapter, :multipart_upload),
       {:ok, multipart} <- adapter.initiate_multipart_upload(storage_key, part_size, opts),
       {:ok, session} <-
         persist_multipart_session(
           repo,
           adapter,
           asset_id,
           profile_name,
           storage_key,
           filename,
           expires_at,
           multipart,
           opts
         ) do
    {:ok, %{session: session, multipart: %{upload_id: multipart.upload_id, upload_key: storage_key}}}
  end
end
```

**Multipart completion reuses the trusted verification lane** (`lib/rindle/upload/broker.ex:183-205`):
```elixir
def complete_multipart_upload(session_id, parts, opts \\ []) do
  repo = Config.repo()

  with %MediaUploadSession{} = session <- repo.get(MediaUploadSession, session_id),
       :ok <- ensure_multipart_session(session),
       {:ok, normalized_parts} <- normalize_multipart_parts(parts),
       asset <- repo.preload(session, :asset).asset,
       {:ok, profile_module} <- profile_name_to_module(asset.profile),
       adapter <- profile_module.storage_adapter(),
       :ok <- ensure_capability(adapter, :multipart_upload),
       {:ok, persisted_session} <-
         update_session(repo, session, %{
           multipart_parts: %{"parts" => encode_multipart_parts(normalized_parts)}
         }),
       {:ok, _result} <-
         adapter.complete_multipart_upload(
           persisted_session.upload_key,
           persisted_session.multipart_upload_id,
           normalized_parts,
           opts
         ) do
    verify_completion(persisted_session.id, opts)
  end
end
```

**Verification stays capability-agnostic after upload completes** (`lib/rindle/upload/broker.ex:229-245`, `248-293`):
```elixir
with %MediaUploadSession{} = session <- repo.get(MediaUploadSession, session_id),
     asset <- repo.preload(session, :asset).asset,
     {:ok, profile_module} <- profile_name_to_module(asset.profile),
     adapter <- profile_module.storage_adapter(),
     {:ok, metadata} <- adapter.head(session.upload_key, opts),
     :ok <- UploadSessionFSM.transition(session.state, "verifying", %{session_id: session.id}),
     :ok <- AssetFSM.transition(asset.state, "validating", %{asset_id: asset.id}) do
  execute_verify_completion(repo, session, asset, profile_module, metadata)
end
```

Phase 8 should preserve this split: capability checks happen before the flow is offered; once the object exists, the verification lane should stay generic and adapter-neutral.

---

### `lib/rindle/delivery.ex` (service, request-response)

**Analog:** `lib/rindle/delivery.ex`

**Delivery capability gate** (`lib/rindle/delivery.ex:95-115`, `183-210`):
```elixir
def url(profile, key, opts \\ []) do
  mode = delivery_mode(profile)
  adapter = profile.storage_adapter()
  subject = %{profile: profile, key: key, mode: mode}

  with :ok <- authorize_delivery(profile, :deliver, subject, opts),
       :ok <- ensure_signed_delivery_support(adapter, mode),
       {:ok, url} <- resolve_url(adapter, key, mode, opts, signed_url_ttl_seconds(profile)) do
    :telemetry.execute([:rindle, :delivery, :signed], %{system_time: System.system_time()}, %{
      profile: profile,
      adapter: adapter,
      mode: mode
    })

    {:ok, url}
  end
end
```

**Fallback behavior pattern** (`lib/rindle/delivery.ex:118-162`):
```elixir
def variant_url(profile, asset, variant, opts \\ []) do
  original_key = key_for(asset, :storage_key)
  variant_key = key_for(variant, :storage_key)
  variant_state = key_for(variant, :state)

  with {:ok, original_url} <- url(profile, original_key, opts) do
    do_variant_url(profile, variant_key, variant_state, original_url, opts)
  end
end

defp do_variant_url(_profile, _variant_key, _variant_state, original_url, _opts) do
  {:ok, original_url}
end
```

For R2 documentation and unsupported private-delivery behavior, copy this exact contract: explicit gate, tagged `{:delivery_unsupported, :signed_url}` error, and fallback logic only where the public API already promises fallback.

---

### `lib/rindle/storage/s3.ex` (service, request-response)

**Analog:** `lib/rindle/storage/s3.ex`

**Tagged adapter wrapper pattern** (`lib/rindle/storage/s3.ex:63-123`):
```elixir
def presigned_put(key, expires_in, opts) do
  with {:ok, bucket} <- bucket(opts),
       {:ok, url} <-
         S3.presigned_url(s3_config(opts), :put, bucket, key, expires_in: expires_in) do
    {:ok, %{url: url, method: :put, headers: %{}}}
  end
end

def initiate_multipart_upload(key, part_size, opts) do
  with {:ok, bucket} <- bucket(opts),
       {:ok, %{body: %{upload_id: upload_id}}} <-
         request(S3.initiate_multipart_upload(bucket, key, object_opts(opts)), opts) do
    {:ok, %{upload_id: upload_id, upload_key: key, bucket: bucket, part_size: part_size}}
  end
end

def complete_multipart_upload(key, upload_id, parts, opts) do
  with {:ok, bucket} <- bucket(opts),
       {:ok, %{body: body}} <-
         request(S3.complete_multipart_upload(bucket, key, upload_id, normalize_parts(parts)), opts) do
    {:ok, Map.merge(%{upload_id: upload_id, upload_key: key, bucket: bucket}, body)}
  end
end
```

**Capability truth lives on the adapter** (`lib/rindle/storage/s3.ex:126-149`):
```elixir
def head(key, opts) do
  with {:ok, bucket} <- bucket(opts) do
    handle_head_response(request(S3.head_object(bucket, key), opts))
  end
end

defp handle_head_response({:error, %{status_code: 404}}), do: {:error, :not_found}
defp handle_head_response({:error, {:http_error, 404, _response}}), do: {:error, :not_found}
defp handle_head_response({:error, reason}), do: {:error, reason}

@impl true
def capabilities, do: [:presigned_put, :head, :signed_url, :multipart_upload]
```

For MinIO and R2 work, keep provider differences isolated here or in adapter-specific config/docs. Callers should continue reading a capability list and tagged tuples, never branching on provider names.

---

### `lib/rindle/storage/local.ex` (service, request-response)

**Analog:** `lib/rindle/storage/local.ex`

**Unsupported flow pattern** (`lib/rindle/storage/local.ex:51-69`, `83`):
```elixir
def initiate_multipart_upload(_key, _part_size, _opts) do
  {:error, {:upload_unsupported, :multipart_upload}}
end

def presigned_upload_part(_key, _upload_id, _part_number, _expires_in, _opts) do
  {:error, {:upload_unsupported, :multipart_upload}}
end

def complete_multipart_upload(_key, _upload_id, _parts, _opts) do
  {:error, {:upload_unsupported, :multipart_upload}}
end

def abort_multipart_upload(_key, _upload_id, _opts) do
  {:error, {:upload_unsupported, :multipart_upload}}
end

def capabilities, do: [:local, :presigned_put]
```

This is the exact house style for “unsupported but honest.” Any R2 unsupported flow should return the same kind of tagged tuple from the adapter boundary rather than silently degrading.

---

### `test/rindle/storage/storage_adapter_test.exs` (test, request-response)

**Analog:** `test/rindle/storage/storage_adapter_test.exs`

**Behaviour and capability truth tests** (`test/rindle/storage/storage_adapter_test.exs:32-70`):
```elixir
callbacks = Rindle.Storage.behaviour_info(:callbacks)

for {name, arity} <- callbacks do
  assert function_exported?(Local, name, arity)
  assert function_exported?(S3, name, arity)
end

assert {:initiate_multipart_upload, 3} in callbacks
assert {:presigned_upload_part, 5} in callbacks
assert {:complete_multipart_upload, 4} in callbacks
assert {:abort_multipart_upload, 3} in callbacks

assert [:local, :presigned_put] == Local.capabilities()
assert [:presigned_put, :head, :signed_url, :multipart_upload] == S3.capabilities()
```

Phase 8 capability centralization should add or update contract tests here first. This file is the best place to assert “capability truth” and future-safe extensibility for resumable/GCS-facing flags.

---

### `test/rindle/upload/broker_test.exs` (test, request-response)

**Analog:** `test/rindle/upload/broker_test.exs`

**Tagged capability failure test** (`test/rindle/upload/broker_test.exs:413-418`):
```elixir
test "multipart on an unsupported adapter fails with a tagged capability error" do
  assert {:error, {:upload_unsupported, :multipart_upload}} =
           Broker.initiate_multipart_session(UnsupportedMultipartProfile,
             filename: "multipart.jpg"
           )
end
```

**Runtime seam probe pattern** (`test/rindle/upload/broker_test.exs:14-52`, `80-107`):
```elixir
defmodule TestRepoProbe do
  def transaction(fun) when is_function(fun, 0) do
    notify(:transaction)
    Rindle.Adopter.CanonicalApp.Repo.transaction(fun)
  end

  def get(schema, id) do
    notify({:get, schema, id})
    Rindle.Adopter.CanonicalApp.Repo.get(schema, id)
  end
end

Application.put_env(:rindle, :repo, TestRepoProbe)
Application.put_env(:rindle, :repo_probe_owner, self())
```

**Manifest persistence + verification reuse test** (`test/rindle/upload/broker_test.exs:352-411`):
```elixir
expect(Rindle.StorageMock, :complete_multipart_upload, fn key, upload_id, parts, _opts ->
  assert parts == [
           %{part_number: 1, etag: "\"etag-1\""},
           %{part_number: 2, etag: "\"etag-2\""}
         ]

  {:ok, %{upload_id: upload_id, upload_key: key}}
end)

expect(Rindle.StorageMock, :head, fn key, _opts ->
  assert key == signed_session.upload_key
  {:ok, %{size: 1234, content_type: "image/jpeg"}}
end)
```

Use this file for new broker-facing capability assertions. Add R2-style unsupported cases here before relying on adopter docs alone.

---

### `test/rindle/delivery_test.exs` (test, request-response)

**Analog:** `test/rindle/delivery_test.exs`

**Private-delivery unsupported test** (`test/rindle/delivery_test.exs:81-96`, `254-262`):
```elixir
test "private delivery without signed capability is rejected" do
  ...
  assert {:error, {:delivery_unsupported, :signed_url}} =
           Rindle.Delivery.url(UnsupportedProfile, key)
end
```

**Public-delivery bypass pattern** (`test/rindle/delivery_test.exs:59-79`):
```elixir
test "public delivery stays unsigned and still authorizes" do
  expect(Rindle.StorageMock, :url, fn ^key, opts ->
    refute Keyword.has_key?(opts, :expires_in)
    {:ok, "https://public.example/#{key}"}
  end)

  assert {:ok, url} = Rindle.url(PublicProfile, key)
end
```

This is the exact analog for documenting R2 delivery behavior: public delivery can proceed without signed capability, private delivery must fail explicitly.

---

### `test/rindle/storage/s3_test.exs` (test, file-I/O)

**Analog:** `test/rindle/storage/s3_test.exs`

**Real-provider multipart proof** (`test/rindle/storage/s3_test.exs:28-79`):
```elixir
@tag :minio
test "round-trips multipart initiate, upload parts, complete, and head against MinIO" do
  ...
  assert {:ok, %{upload_id: upload_id, upload_key: ^key, part_size: part_size}} =
           S3.initiate_multipart_upload(key, @multipart_min_part_size, opts)

  assert {:ok, %{url: part1_url, part_number: 1, upload_id: ^upload_id}} =
           S3.presigned_upload_part(key, upload_id, 1, 60, opts)

  etag1 = put_part_to_presigned_url(part1_url, part1)
  etag2 = put_part_to_presigned_url(part2_url, part2)

  assert {:ok, %{upload_id: ^upload_id, upload_key: ^key}} =
           S3.complete_multipart_upload(key, upload_id, [...], opts)
end
```

**Real-provider presigned PUT proof** (`test/rindle/storage/s3_test.exs:104-143`):
```elixir
@tag :minio
test "round-trips store, head, download, url, delete, and not_found against MinIO" do
  ...
  assert {:ok, %{url: put_url, method: :put, headers: %{}}} = S3.presigned_put(key, 60, opts)
  assert String.contains?(put_url, key)
end
```

Phase 8 should extend this real-provider lane, not replace it with more mocks.

---

### `test/adopter/canonical_app/lifecycle_test.exs` (test, file-I/O)

**Analog:** `test/adopter/canonical_app/lifecycle_test.exs`

**Canonical MinIO presigned PUT proof** (`test/adopter/canonical_app/lifecycle_test.exs:105-128`, `301-318`):
```elixir
{:ok, %{session: signed, presigned: presigned}} = Broker.sign_url(session.id)
assert is_binary(presigned.url)
assert String.starts_with?(presigned.url, "http")

:ok = put_to_presigned_url(presigned.url, @png_1x1)

{:ok, %{session: completed, asset: asset}} = Broker.verify_completion(session.id)
assert Repo.get!(Rindle.Domain.MediaUploadSession, session.id).state == "completed"
```

**Canonical MinIO multipart proof** (`test/adopter/canonical_app/lifecycle_test.exs:191-258`, `321-351`):
```elixir
{:ok, %{session: session, multipart: multipart}} =
  Rindle.initiate_multipart_upload(AdopterProfile, filename: "adopter-multipart.png")

{:ok, %{session: signed, presigned: presigned_part1}} =
  Rindle.sign_multipart_part(session.id, 1)

etag1 = put_part_to_presigned_url(presigned_part1.url, part1)
etag2 = put_part_to_presigned_url(presigned_part2.url, part2)

{:ok, %{session: completed, asset: asset}} =
  Rindle.complete_multipart_upload(session.id, [
    %{part_number: 1, etag: etag1},
    %{part_number: 2, etag: etag2}
  ])
```

**Cleanup-after-expiry proof** (`test/adopter/canonical_app/lifecycle_test.exs:260-284`):
```elixir
{:ok, abort_report} = UploadMaintenance.abort_incomplete_uploads([])
assert abort_report.sessions_aborted >= 1

{:ok, cleanup_report} =
  UploadMaintenance.cleanup_orphans(
    dry_run: false,
    storage: AdopterProfile.storage_adapter()
  )

assert cleanup_report.sessions_deleted >= 1
```

If Phase 8 adds R2 documentation or provider-matrix assertions, this adopter lane remains the template for “prove it with real HTTP calls and real storage behavior.”

---

### `guides/getting_started.md` or new capability guide (docs, request-response)

**Analog:** `guides/getting_started.md`

**Guide style pattern** (`guides/getting_started.md:7-12`, `79-122`):
```markdown
This guide walks you from `mix new` to a working upload → process → deliver
loop. The four-step lifecycle shown below is the **same code path** the
adopter integration test exercises end-to-end against MinIO and PostgreSQL.
```

```elixir
{:ok, session} =
  Rindle.Upload.Broker.initiate_session(MyApp.MediaProfile, filename: "photo.png")

{:ok, %{session: signed, presigned: %{url: upload_url}}} =
  Rindle.Upload.Broker.sign_url(session.id)

{:ok, %{session: completed, asset: asset}} =
  Rindle.Upload.Broker.verify_completion(session.id)

{:ok, signed_url} =
  Rindle.Delivery.url(MyApp.MediaProfile, asset.storage_key)
```

If Phase 8 adds R2 behavior documentation, keep the tone practical and test-linked: say exactly which flows are supported, which return tagged capability errors, and which future capability names are reserved for resumable/GCS-style support.

## Shared Patterns

### Capability Gating
**Sources:** `lib/rindle/upload/broker.ex:79-80`, `162-163`, `192-193`; `lib/rindle/delivery.ex:101-103`, `183-210`

Apply one gate per caller-facing flow and return tagged errors immediately:

```elixir
with :ok <- ensure_capability(adapter, :multipart_upload),
     {:ok, multipart} <- adapter.initiate_multipart_upload(storage_key, part_size, opts) do
  ...
end
```

```elixir
if :signed_url in capabilities do
  :ok
else
  {:error, {:delivery_unsupported, :signed_url}}
end
```

### Adapter Truth Owns Support Claims
**Sources:** `lib/rindle/storage/s3.ex:149`; `lib/rindle/storage/local.ex:83`

```elixir
def capabilities, do: [:presigned_put, :head, :signed_url, :multipart_upload]
def capabilities, do: [:local, :presigned_put]
```

Do not duplicate this truth in broker, delivery, guides, or tests. Those layers should consume capability truth, not redefine it.

### Runtime Repo / Broker Seam
**Sources:** `lib/rindle/upload/broker.ex:31`, `68`, `128`, `155`, `184`, `230`; `test/rindle/upload/broker_test.exs:14-52`

```elixir
repo = Config.repo()
with %MediaUploadSession{} = session <- repo.get(MediaUploadSession, session_id) do
  ...
end
```

Phase 8 should keep capability checks inside the existing broker/delivery seams instead of leaking adapter knowledge into callers.

### Real Provider Over Mock Proof
**Sources:** `test/rindle/storage/s3_test.exs:28-79`, `104-143`; `test/adopter/canonical_app/lifecycle_test.exs:105-128`, `191-258`

```elixir
etag1 = put_part_to_presigned_url(part1_url, part1)
etag2 = put_part_to_presigned_url(part2_url, part2)

{:ok, %{session: completed, asset: asset}} =
  Rindle.complete_multipart_upload(session.id, [
    %{part_number: 1, etag: etag1},
    %{part_number: 2, etag: etag2}
  ])
```

Use mocks for narrow contract failures and sequencing. Use MinIO-backed tests for end-to-end claims about presigned PUT, multipart, and cleanup behavior.

## Anti-Patterns To Avoid

- **Duplicated capability truth:** do not define capability atoms independently in adapter modules, broker guards, delivery guards, docs, and tests. Centralize names once and consume them everywhere else.
- **Provider-specific branching in callers:** avoid `if provider == :r2` logic in `Rindle.Upload.Broker` or `Rindle.Delivery`. Unsupported R2 flows should surface via `capabilities/0` and tagged tuples from the adapter boundary.
- **Mock-only confidence:** do not claim MinIO or R2 behavior based only on `Rindle.StorageMock`. Real-provider assertions belong in `test/rindle/storage/s3_test.exs` and `test/adopter/canonical_app/lifecycle_test.exs`.
- **Changing the completion trust boundary:** `complete_multipart_upload/3` must still converge into `verify_completion/2`; remote multipart completion is not itself trusted.
- **Silent fallback for unsupported private delivery:** if a backend lacks `:signed_url`, return `{:error, {:delivery_unsupported, :signed_url}}`; do not quietly serve a bare URL in private mode.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `lib/rindle/storage/capabilities.ex` | utility | request-response | No dedicated capability helper exists yet; closest patterns are split between `Rindle.Config`, `Rindle.Upload.Broker`, and `Rindle.Delivery`. |
| `guides/storage_capabilities.md` or equivalent R2 matrix doc | docs | request-response | No existing provider-capability matrix guide exists; use `guides/getting_started.md` for tone and test-linked documentation style. |

## Metadata

**Analog search scope:** `lib/rindle/`, `test/rindle/`, `test/adopter/canonical_app/`, `guides/`, `.planning/`
**Files scanned:** 18
**Pattern extraction date:** 2026-04-28
