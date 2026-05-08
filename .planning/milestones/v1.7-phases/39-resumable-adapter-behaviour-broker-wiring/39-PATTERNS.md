# Phase 39: Resumable Adapter Behaviour + Broker Wiring - Pattern Map

**Mapped:** 2026-05-07
**Files analyzed:** 9
**Analogs found:** 9 / 9

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/rindle/storage.ex` | behaviour | request-response | `lib/rindle/storage.ex` | exact |
| `lib/rindle/storage/capabilities.ex` | utility | request-response | `lib/rindle/storage/capabilities.ex` | exact |
| `lib/rindle/storage/gcs.ex` | adapter | request-response | `lib/rindle/storage/s3.ex` + current `lib/rindle/storage/gcs.ex` | exact + exact |
| `lib/rindle/storage/gcs/client.ex` | service | request-response | current `lib/rindle/storage/gcs/client.ex` | exact |
| `lib/rindle/upload/broker.ex` | service | request-response | current `lib/rindle/upload/broker.ex` multipart lifecycle | exact |
| `test/rindle/storage/storage_adapter_test.exs` | test | request-response | `test/rindle/storage/storage_adapter_test.exs` | exact |
| `test/rindle/storage/gcs_test.exs` | test | request-response | `test/rindle/storage/gcs_test.exs` + `test/rindle/storage/s3_test.exs` | exact + role-match |
| `test/rindle/storage/gcs/client_test.exs` | test | request-response | `test/rindle/storage/gcs/client_test.exs` | exact |
| `test/rindle/upload/broker_test.exs` | test | request-response | `test/rindle/upload/broker_test.exs` multipart lifecycle | exact |

## Pattern Assignments

### `lib/rindle/storage.ex` (behaviour, request-response)

**Analog:** [lib/rindle/storage.ex](/Users/jon/projects/rindle/lib/rindle/storage.ex:17)

**Capability/type vocabulary pattern** (lines 17-24):
```elixir
@type capability ::
        :presigned_put
        | :multipart_upload
        | :signed_url
        | :head
        | :local
        | :resumable_upload
        | :resumable_upload_session
```

**Existing callback contract pattern** (lines 122-190):
```elixir
@callback initiate_multipart_upload(
            key :: String.t(),
            part_size :: pos_integer(),
            opts :: keyword()
          ) :: {:ok, multipart_init_result()} | {:error, term()}

@callback head(key :: String.t(), opts :: keyword()) ::
            {:ok, head_result()} | {:error, term()}
```

**Copy for Phase 39**
- Add the four resumable callbacks beside the multipart family, not in a second behaviour module.
- Match the existing `@callback ... :: {:ok, ...} | {:error, term()}` style.
- Keep completion split exactly as Phase 39 locks it: adapter-level resumable completion callback exists, but broker trust still converges on `head/2`.

### `lib/rindle/storage/capabilities.ex` (utility, request-response)

**Analog:** [lib/rindle/storage/capabilities.ex](/Users/jon/projects/rindle/lib/rindle/storage/capabilities.ex:19)

**Known capability registry** (lines 19-27):
```elixir
@known [
  :presigned_put,
  :multipart_upload,
  :signed_url,
  :head,
  :local,
  :resumable_upload,
  :resumable_upload_session
]
```

**Capability gating helper** (lines 32-55):
```elixir
def safe(adapter) do
  case adapter.capabilities() do
    capabilities when is_list(capabilities) ->
      Enum.filter(capabilities, &(&1 in @known))

    _ ->
      []
  end
rescue
  _ -> []
end

def require_upload(adapter, capability) do
  if supports?(adapter, capability) do
    :ok
  else
    {:error, {:upload_unsupported, capability}}
  end
end
```

**Copy for Phase 39**
- Reuse `Capabilities.require_upload/2` for resumable broker entrypoints; do not hand-roll adapter checks.
- Preserve the malformed-capability hardening through `safe/1`; broker tests already depend on that behavior.
- Promote semantics by changing capability advertising in adapters and tests, not by changing the gating contract.

### `lib/rindle/storage/gcs.ex` (adapter, request-response)

**Analogs:** [lib/rindle/storage/gcs.ex](/Users/jon/projects/rindle/lib/rindle/storage/gcs.ex:41), [lib/rindle/storage/s3.ex](/Users/jon/projects/rindle/lib/rindle/storage/s3.ex:63)

**Adapter delegation pattern** (GCS lines 41-79):
```elixir
def store(key, source_path, opts) do
  with {:ok, bucket} <- bucket(opts),
       :ok <- ensure_goth_loaded() do
    Client.store(bucket, key, source_path, inject_credentials(opts))
  end
end

def head(key, opts) do
  with {:ok, bucket} <- bucket(opts),
       :ok <- ensure_goth_loaded() do
    Client.head(bucket, key, inject_credentials(opts))
  end
end
```

**Unsupported-operation posture** (lines 81-106):
```elixir
def initiate_multipart_upload(_key, _part_size, _opts) do
  {:error, {:upload_unsupported, :multipart_upload}}
end
```

**Shared config injection** (lines 113-145):
```elixir
defp bucket(opts) do
  case Keyword.get(opts, :bucket) || Application.get_env(:rindle, __MODULE__, [])[:bucket] do
    nil -> {:error, :missing_bucket}
    bucket -> {:ok, bucket}
  end
end

defp inject_credentials(opts) do
  app_env = Application.get_env(:rindle, __MODULE__, [])

  opts
  |> Keyword.put_new_lazy(:finch, fn -> app_env[:finch] end)
  |> Keyword.put_new_lazy(:goth, fn -> app_env[:goth] end)
  |> Keyword.put_new_lazy(:signing_key, fn -> app_env[:signing_key] end)
  |> Keyword.put_new_lazy(:base_url, fn -> app_env[:base_url] end)
end
```

**Copy for Phase 39**
- Keep resumable callbacks in `Rindle.Storage.GCS` as thin delegators into `Client`, just like `store/3`, `download/3`, `delete/2`, and `head/2`.
- Replace the Phase 37 unsupported stubs with real resumable implementations only for GCS; leave `S3` and `Local` unchanged.
- Update `capabilities/0` in place to the exact four-atom list locked by Phase 39: `[:signed_url, :head, :resumable_upload, :resumable_upload_session]`.
- Keep `bucket/1`, `ensure_goth_loaded/0`, and `inject_credentials/1` as the common preflight path for the new callbacks.

### `lib/rindle/storage/gcs/client.ex` (service, request-response)

**Analog:** [lib/rindle/storage/gcs/client.ex](/Users/jon/projects/rindle/lib/rindle/storage/gcs/client.ex:17)

**Finch request helper and HTTP mapping** (lines 24-42, 163-179, 265-269):
```elixir
case finch_request(req, opts) do
  {:ok, %Finch.Response{status: 200, body: body}} ->
    json = Jason.decode!(body)
    {:ok, %{size: parse_size(json["size"]), content_type: json["contentType"]}}

  {:ok, %Finch.Response{status: 404}} ->
    {:error, :not_found}

  {:ok, %Finch.Response{status: status, body: body}} ->
    {:error, {:gcs_http_error, %{status: status, body: body}}}

  {:error, exception} ->
    {:error, exception}
end
```

```elixir
defp finch_request(req, opts) do
  Finch.request(req, finch_name(opts))
rescue
  exception -> {:error, exception}
end
```

**GCS URL helper pattern** (lines 184-203):
```elixir
defp url_for(:metadata, bucket, key, opts) do
  "#{base_url(opts)}/storage/v1/b/#{bucket}/o/#{URI.encode(key, &URI.char_unreserved?/1)}"
end

defp url_for(:upload, bucket, _key, opts) do
  "#{base_url(opts)}/upload/storage/v1/b/#{bucket}/o?uploadType=multipart"
end
```

**Auth/header helper pattern** (lines 213-260):
```elixir
defp authed_headers(opts) do
  case Keyword.get(opts, :token) do
    token when is_binary(token) ->
      {:ok, [{"authorization", "Bearer #{token}"}]}

    nil ->
      case fetch_token(opts) do
        {:ok, %{token: token, type: type}} ->
          {:ok, [{"authorization", "#{type} #{token}"}]}

        {:error, :goth_unconfigured} ->
          {:error, :goth_unconfigured}

        {:error, _other} ->
          {:error, :goth_unconfigured}
      end
  end
end
```

**Copy for Phase 39**
- Extend `url_for/4` with new resumable endpoints instead of bypassing the client with ad hoc Finch calls from `gcs.ex`.
- Follow the existing response mapping discipline:
  `404 -> tagged tuple`, non-2xx -> `{:gcs_http_error, %{status, body}}`, network/auth failures -> propagate tagged tuple.
- Keep auth and `:base_url` threading in the client so Bypass and real-bucket tests can exercise the same request helpers.
- For status/cancel helpers, mirror the same `case finch_request(...) do` envelope and preserve secret-safe handling of session URIs.

### `lib/rindle/upload/broker.ex` (service, request-response)

**Analog:** [lib/rindle/upload/broker.ex](/Users/jon/projects/rindle/lib/rindle/upload/broker.ex:107)

**Broker initiation posture** (lines 107-149):
```elixir
with :ok <- Capabilities.require_upload(adapter, :multipart_upload),
     {:ok, multipart} <- adapter.initiate_multipart_upload(storage_key, part_size, opts),
     {:ok, session} <-
       persist_multipart_session(
         repo,
         adapter,
         %{asset_id: asset_id, profile_name: profile_name, storage_key: storage_key,
           filename: filename, expires_at: expires_at},
         multipart,
         opts
       ) do
  {:ok, %{session: session, multipart: %{upload_id: multipart.upload_id, ...}}}
end
```

**Completion convergence pattern** (lines 275-291):
```elixir
with %MediaUploadSession{} = session <- repo.get(MediaUploadSession, session_id),
     asset <- repo.preload(session, :asset).asset,
     {:ok, profile_module} <- profile_name_to_module(asset.profile),
     adapter <- profile_module.storage_adapter(),
     {:ok, metadata} <- adapter.head(session.upload_key, opts),
     :ok <- UploadSessionFSM.transition(session.state, "verifying", %{session_id: session.id}),
     :ok <- AssetFSM.transition(asset.state, "validating", %{asset_id: asset.id}) do
  execute_verify_completion(repo, session, asset, profile_module, metadata)
else
  {:error, :not_found} -> {:error, :storage_object_missing}
end
```

**Compensation helper pattern** (lines 392-440):
```elixir
defp persist_multipart_session(repo, adapter, session_seed, multipart, opts) do
  case create_upload_session(..., %{upload_strategy: "multipart", multipart_upload_id: multipart.upload_id, multipart_parts: %{}}) do
    {:ok, session} ->
      {:ok, session}

    {:error, reason} ->
      compensate_failed_multipart_persist(adapter, session_seed.storage_key, multipart.upload_id, opts)
      {:error, reason}
  end
end

defp compensate_failed_multipart_persist(adapter, storage_key, upload_id, opts) do
  case adapter.abort_multipart_upload(storage_key, upload_id, opts) do
    {:ok, _} -> :ok
    {:error, :not_found} -> :ok
    {:error, reason} ->
      Logger.warning("rindle.upload.broker.multipart_persist_compensation_failed", ...)
      :ok
  end
end
```

**Session-shape guard pattern** (lines 454-464):
```elixir
defp ensure_multipart_session(%MediaUploadSession{
       upload_strategy: "multipart",
       multipart_upload_id: upload_id
     })
     when is_binary(upload_id) and upload_id != "",
     do: :ok

defp ensure_multipart_session(_session), do: {:error, {:upload_unsupported, :multipart_upload}}
```

**Copy for Phase 39**
- Model `initiate_resumable_session/2` directly on `initiate_multipart_session/2`: capability gate first, remote storage initiation second, DB persistence third.
- Mirror the compensation shape exactly: `persist_resumable_session` plus `compensate_failed_resumable_persist`, with `cancel_resumable_upload/3` replacing `abort_multipart_upload/3`.
- Keep `verify_completion/2` untouched as the single trust gate; resumable paths should call into it after the object exists instead of consulting adapter-specific completion state.
- Add a resumable session guard mirroring `ensure_multipart_session/1` so non-resumable rows return `{:upload_unsupported, :resumable_upload_session}`.

### `test/rindle/storage/storage_adapter_test.exs` (test, request-response)

**Analog:** [test/rindle/storage/storage_adapter_test.exs](/Users/jon/projects/rindle/test/rindle/storage/storage_adapter_test.exs:42)

**Cross-adapter behaviour parity** (lines 42-63):
```elixir
callbacks = Rindle.Storage.behaviour_info(:callbacks)

for {name, arity} <- callbacks do
  assert function_exported?(Local, name, arity)
  assert function_exported?(S3, name, arity)
  assert function_exported?(GCS, name, arity)
end
```

**Capability truthfulness test** (lines 80-89):
```elixir
assert [:local, :presigned_put] == Local.capabilities()
assert [:presigned_put, :head, :signed_url, :multipart_upload] == S3.capabilities()
assert [:signed_url, :head] == GCS.capabilities()
```

**Copy for Phase 39**
- Extend the callback-presence test to cover the four new resumable callbacks via `behaviour_info(:callbacks)`.
- Rewrite the GCS capability equality assertion, not a membership assertion, so drift in advertised resumable atoms is caught exactly.
- Keep S3 and Local capability assertions unchanged to prove cross-adapter honesty.

### `test/rindle/storage/gcs_test.exs` (test, request-response)

**Analogs:** [test/rindle/storage/gcs_test.exs](/Users/jon/projects/rindle/test/rindle/storage/gcs_test.exs:62), [test/rindle/storage/s3_test.exs](/Users/jon/projects/rindle/test/rindle/storage/s3_test.exs:28)

**Real-bucket environment gating** (GCS lines 6-10, 63-65):
```elixir
@gcs_credentials System.get_env("GOOGLE_APPLICATION_CREDENTIALS_JSON")
@gcs_bucket System.get_env("RINDLE_GCS_BUCKET")
@gcs_skip_reason (if Enum.any?([@gcs_credentials, @gcs_bucket], &is_nil/1) do
                    "Skipping GCS adapter test because GOOGLE_APPLICATION_CREDENTIALS_JSON or RINDLE_GCS_BUCKET environment variable is missing"
                  end)

@tag :gcs
@tag skip: @gcs_skip_reason
```

**Live runtime bootstrap pattern** (lines 66-80):
```elixir
decoded = Jason.decode!(@gcs_credentials)
goth_name = :"rindle_gcs_test_goth_#{System.unique_integer([:positive])}"
finch_name = :"rindle_gcs_test_finch_#{System.unique_integer([:positive])}"

{:ok, _} = Goth.start_link(name: goth_name, source: {:service_account, decoded})
{:ok, _} = Finch.start_link(name: finch_name)

Application.put_env(:rindle, GCS,
  bucket: @gcs_bucket,
  goth: goth_name,
  finch: finch_name,
  signing_key: decoded
)
```

**Round-trip assertion style** (lines 91-113):
```elixir
assert {:ok, %{key: ^key}} = GCS.store(key, source, ...)
assert {:ok, %{size: 20, content_type: "image/jpeg"}} = GCS.head(key, [])
assert {:ok, signed_url} = GCS.url(key, [])
assert {:ok, ^destination} = GCS.download(key, destination, [])
assert {:ok, _} = GCS.delete(key, [])
assert {:error, :not_found} = GCS.head(key, [])
```

**Copy for Phase 39**
- Reuse this exact secret-gated live-bucket harness for resumable proof tests.
- Add a real resumable round-trip as a sibling to the current object round-trip, not a synthetic-only broker test.
- Follow the S3 multipart proof style from `test/rindle/storage/s3_test.exs:28-78`: initiate, client-upload, complete/verify, then assert final object state.

### `test/rindle/storage/gcs/client_test.exs` (test, request-response)

**Analog:** [test/rindle/storage/gcs/client_test.exs](/Users/jon/projects/rindle/test/rindle/storage/gcs/client_test.exs:26)

**Bypass + unique Finch setup** (lines 8-24):
```elixir
bypass = Bypass.open()
finch_name = Module.concat(__MODULE__, :"Finch_#{System.unique_integer([:positive])}")
{:ok, _pid} = Finch.start_link(name: finch_name)

{:ok, bypass: bypass, base_url: "http://localhost:#{bypass.port}", finch: finch_name}
```

**HTTP helper expectations** (lines 27-100, 103-205):
```elixir
Bypass.expect_once(bypass, "GET", "/storage/v1/b/#{@bucket}/o/assets%2Ffoo.jpg", fn conn -> ... end)
assert {:ok, %{size: 1_024_000, content_type: "image/jpeg"}} =
         Client.head(@bucket, "assets/foo.jpg", opts)
```

```elixir
Bypass.expect_once(bypass, "POST", "/upload/storage/v1/b/#{@bucket}/o", fn conn ->
  conn = Plug.Conn.fetch_query_params(conn)
  assert conn.query_params["uploadType"] == "multipart"
  ...
end)
```

**Copy for Phase 39**
- Add resumable-initiation/status/cancel client tests in this file; the `:base_url` seam and Bypass assertions are already the right pattern.
- Assert exact HTTP verb, path, and query string for each helper, just as the current tests assert `uploadType=multipart` and encoded object keys.
- Use these tests to lock error vocabulary mapping for `:session_uri_expired`, `:session_uri_unknown`, `{:offset_mismatch, ...}`, and `{:gcs_http_error, ...}`.

### `test/rindle/upload/broker_test.exs` (test, request-response)

**Analog:** [test/rindle/upload/broker_test.exs](/Users/jon/projects/rindle/test/rindle/upload/broker_test.exs:252)

**Initiation + compensation pattern** (lines 278-329):
```elixir
expect(Rindle.StorageMock, :initiate_multipart_upload, fn _key, _part_size, _opts ->
  {:error, :storage_unavailable}
end)

assert {:error, :storage_unavailable} =
         Broker.initiate_multipart_session(TestProfile, filename: "multipart.jpg")
```

```elixir
expect(Rindle.StorageMock, :abort_multipart_upload, fn key, upload_id, _opts ->
  assert key =~ "testprofile"
  assert upload_id == "upload-rollback"
  {:ok, :aborted}
end)

assert {:error, :session_insert_failed} =
         Broker.initiate_multipart_session(TestProfile, filename: "multipart.jpg")
```

**Capability rejection pattern** (lines 437-449):
```elixir
assert {:error, {:upload_unsupported, :multipart_upload}} =
         Broker.initiate_multipart_session(UnsupportedMultipartProfile, filename: "multipart.jpg")

assert {:error, {:upload_unsupported, :resumable_upload_session}} =
         Capabilities.require_upload(
           UnsupportedMultipartProfile.storage_adapter(),
           :resumable_upload_session
         )
```

**Completion convergence pattern** (lines 376-434):
```elixir
expect(Rindle.StorageMock, :complete_multipart_upload, fn key, upload_id, parts, _opts -> ... end)
expect(Rindle.StorageMock, :head, fn key, _opts ->
  assert key == signed_session.upload_key
  {:ok, %{size: 1234, content_type: "image/jpeg"}}
end)

assert {:ok, %{session: completed_session, asset: asset}} =
         Broker.complete_multipart_upload(session.id, parts)
```

**Copy for Phase 39**
- Add resumable broker tests as siblings to the multipart block, not as a separate test style.
- Cover three seams explicitly:
  capability gating for non-resumable adapters,
  compensation when session persistence fails,
  and the rule that broker completion still depends on `head/2` rather than `verify_resumable_completion/3`.
- Use Mox expectations to prove broker status/cancel entrypoints call only the resumable callbacks they own and preserve the locked tagged-tuple vocabulary.

## Shared Patterns

### Callback Contracts
**Source:** [lib/rindle/storage.ex](/Users/jon/projects/rindle/lib/rindle/storage.ex:122)

Apply the resumable callbacks using the same additive style as the multipart family:
- one behaviour module
- `@callback` signatures with arity and typed tagged tuples
- adapter-specific metadata maps for success payloads

### Capability Gating
**Source:** [lib/rindle/storage/capabilities.ex](/Users/jon/projects/rindle/lib/rindle/storage/capabilities.ex:32)

Use `Capabilities.require_upload/2` for:
- `:resumable_upload` when minting a resumable upload
- `:resumable_upload_session` when status/cancel requires broker-visible session control

This keeps unsupported adapters on the existing `{:error, {:upload_unsupported, capability}}` contract.

### Broker Compensation
**Source:** [lib/rindle/upload/broker.ex](/Users/jon/projects/rindle/lib/rindle/upload/broker.ex:392)

Resumable initiation should copy the multipart persist/compensate pattern:
- remote initiation before DB write
- `create_upload_session/7` for durable rows
- compensation helper swallowing `:not_found`
- warning log only when compensation itself fails

### GCS Client Request Helpers
**Source:** [lib/rindle/storage/gcs/client.ex](/Users/jon/projects/rindle/lib/rindle/storage/gcs/client.ex:184)

Keep all resumable HTTP plumbing in `Client` and reuse:
- `url_for/4`
- `authed_headers/1`
- `base_url/1`
- `finch_request/2`

This is the load-bearing seam for both Bypass tests and real GCS calls.

### Real-Bucket Tests
**Source:** [test/rindle/storage/gcs_test.exs](/Users/jon/projects/rindle/test/rindle/storage/gcs_test.exs:62)

Use the current `@tag :gcs` harness for the Phase 39 proof:
- decode `GOOGLE_APPLICATION_CREDENTIALS_JSON`
- start unique Goth + Finch names
- `Application.put_env/3` the adapter config for the test
- clean up temp files and restore app env in `after`

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `test/rindle/upload/broker_gcs_resumable_test.exs` (if Phase 39 chooses a new live-bucket broker proof file instead of extending `gcs_test.exs`) | test | request-response | No existing live broker + real GCS test combines broker lifecycle with direct provider HTTP yet; combine patterns from `test/rindle/upload/broker_test.exs` and `test/rindle/storage/gcs_test.exs`. |

## Metadata

**Analog search scope:** `lib/rindle/storage*`, `lib/rindle/upload/*`, `test/rindle/storage/*`, `test/rindle/upload/*`, `.planning/phases/37-*`, `.planning/phases/38-*`, `.planning/ROADMAP.md`

**Files scanned:** 15 primary reads + targeted line lookups

**Key patterns identified**
- All adapter/broker surfaces use tagged tuples and in-place additive extension rather than parallel APIs.
- Capability honesty is enforced through `Capabilities.safe/1` and exact list assertions in tests.
- Broker lifecycle work performs storage I/O before persistence and compensates on persist failure.
- GCS HTTP helpers are centralized in `Rindle.Storage.GCS.Client` with `:base_url` test seams and exact HTTP status mapping.
- Real-bucket proof tests use secret-gated live harnesses with unique Goth/Finch names and explicit env restoration.
