# Phase 124: Upload Path Clarity - Pattern Map

**Mapped:** 2026-08-22  
**Files analyzed:** 15 likely implementation and preservation-test surfaces  
**Analogs found:** 15 / 15

`Rindle.Upload.TusPlug` and `Rindle.Upload.Broker` remain public facades. New collaborators are internal (`@moduledoc false`, callable seams `@doc false`). Candidate names are seams, not a requirement to create every file.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/rindle/upload/tus_plug.ex` | Plug facade/controller | request-response, streaming, file-I/O | `lib/rindle/ops/runtime_checks.ex` | facade + hidden collaborator |
| `lib/rindle/upload/tus_protocol.ex` | protocol utility | request-response, transform | current private parser/token code | extraction seam |
| `lib/rindle/upload/tus_creation.ex` | creation service | request-response, CRUD | current POST/signing code | extraction seam |
| `lib/rindle/upload/tus_stream.ex` | storage service | streaming, file-I/O | current PATCH streaming code | extraction seam |
| `lib/rindle/upload/tus_termination.ex` | termination service | request-response, storage I/O | current DELETE + `UploadMaintenance` | role + flow |
| `lib/rindle/upload/broker.ex` | lifecycle facade/service | CRUD, request-response, event-driven | `lib/rindle/ops/runtime_status.ex` | facade + hidden collaborator |
| `lib/rindle/upload/broker/session_seed.ex` | utility/service | transform | repeated Broker seed construction | extraction seam |
| `lib/rindle/upload/broker/persistence.ex` | persistence service | CRUD, transaction | Broker private persistence / Phase 123 V1 split | role + flow |
| `lib/rindle/upload/broker/session_validation.ex` | validation utility | request-response, transform | Broker guards and normalizers | exact |
| `lib/rindle/upload/broker/completion.ex` | completion service | CRUD, transaction, event-driven | Broker `Ecto.Multi` builder | exact |
| `test/rindle/api_surface_boundary_test.exs` | compiled-boundary contract | transform | Phase 123 allowlist | exact |
| `test/rindle/upload/tus_plug_test.exs` | behavior contract | request-response, streaming | existing gate/order and Mox groups | exact |
| `test/rindle/upload/broker_test.exs` | behavior contract | CRUD, event-driven | compensation and telemetry groups | exact |
| `test/rindle/upload/tus_local_backing_test.exs` | integration test | file-I/O, transaction | append/rename/verify flow | exact |
| `test/rindle/upload/{tus_s3_integration_test,lifecycle_integration_test}.exs` | integration tests | streaming/CRUD/event-driven | real adapter/promotion flows | exact |

## Pattern Assignments

### `lib/rindle/upload/tus_plug.ex` (public Plug facade)

**Primary analog:** [`lib/rindle/ops/runtime_checks.ex`](../../../lib/rindle/ops/runtime_checks.ex:22), lines 22-111. Phase 123 resolves configuration once, delegates bounded mechanics, and retains ordering, telemetry, and result construction.

```elixir
{initial_core_checks, profile_check, core_facts} =
  CoreChecks.schedule(profiles, probe, local_playback_route, resolved, env)

checks =
  (initial_core_checks ++ ownership_checks ++ [profile_check] ++ integration_checks)
  |> Enum.map(&run_check/1)
  |> Enum.sort_by(& &1.id)
```

Keep `init/1`, every `call/2` method clause, and final Plug responses in `TusPlug` (lines 108-157). Collaborators receive resolved opts and do not reread config.

**PATCH boundary:** retain this strict pre-stream order in the facade ([`tus_plug.ex`](../../../lib/rindle/upload/tus_plug.ex:389), lines 389-425):

```elixir
with {:ok, claims} <- verify_token(conn, opts),
     {:ok, session} <- load_active_session(claims),
     :ok <- authorize_resume(conn, claims, session, :patch, opts),
     :ok <- require_offset_octet_stream(conn),
     {:ok, inbound_offset} <- parse_upload_offset(conn),
     :ok <- check_offset_match(inbound_offset, session.last_known_offset),
     {:ok, session, effective_len} <- resolve_patch_length(conn, session, claims, opts),
     {:ok, checksum_alg, expected_hash} <- parse_upload_checksum(conn),
     {:ok, part_state} <- stream_append(...) do
  ...
end
```

Keep offset persistence, broadcast, `ResumableTelemetry.emit_patch/5`, completion choice, and 204/5xx construction at the facade. `tus_plug_test.exs:429-487` proves 415/409 leave offset unchanged and 409 creates no part file.

### `lib/rindle/upload/tus_protocol.ex` (hidden protocol utility)

**Analog:** [`Rindle.Ops.RuntimeChecks.CoreChecks`](../../../lib/rindle/ops/runtime_checks/core_checks.ex:1), lines 1-31: hidden module, narrow `@doc false` entrypoint, no outer result ownership.

```elixir
defmodule Rindle.Ops.RuntimeChecks.CoreChecks do
  @moduledoc false
  @doc false
  def schedule(profiles, probe, local_playback_route, resolved, env), do: ...
end
```

Own parsing/pure helpers from `tus_plug.ex:738-976`: content type, offsets, lengths, checksums, token expiry, status mapping, metadata decoding, URL joining, HTTP dates. Preserve every reason atom and `status_for/1` mapping at lines 856-868, including checksum status 460. Do not create a public request object or response DSL.

### `lib/rindle/upload/tus_creation.ex` (hidden creation service)

**Analog:** [`tus_plug.ex`](../../../lib/rindle/upload/tus_plug.ex:204), lines 204-368. Return current tagged values; facade owns POST/concatenation responses.

```elixir
with {:ok, %{session: session}} <- Broker.initiate_tus_upload(profile, filename: filename, expires_in: expires_in),
     {:ok, upload_url, signed_session} <- sign_and_persist(base_path, session, length, content_type, secret_key_base, actor, is_partial) do
  {:ok, %{session: signed_session, upload_url: upload_url, expires_at: signed_session.expires_at}}
end
```

Keep 201/400/413 response headers/text in TusPlug. Preserve claims, final path token, and redacting `session_uri` persistence at lines 323-368; never log/emit/broadcast a bearer URL.

### `lib/rindle/upload/tus_stream.ex` (hidden streaming/storage service)

**Analog:** [`tus_plug.ex`](../../../lib/rindle/upload/tus_plug.ex:427), lines 427-630. Own one PATCH temp file, bounded drain, checksum verification, prior-state codec, and polymorphic adapter dispatch; return existing `{:ok, part_state}`/error values.

```elixir
try do
  dispatch_part(drain_result, temp_path, session, payload, opts)
after
  File.rm(temp_path)
end

opts[:adapter].upload_part_stream(
  session.upload_key, temp_path, session.last_known_offset,
  prior_state(session), call_opts(session, payload["content_type"], opts)
)
```

Keep `@read_length`, all bounds, `multipart_upload_id`, and `%{"parts" => parts}` compatible. Completion uses `complete_part_stream/4` then unchanged `Broker.verify_completion/2` (lines 607-625). No Local/S3 branch or full-body buffer. `tus_plug_test.exs:677-783` is the Mox behavior pattern; Local/S3 integration is at `tus_local_backing_test.exs:60-91` and `tus_s3_integration_test.exs:148-275`.

### `lib/rindle/upload/tus_termination.ex` (hidden termination service)

**Analog:** [`tus_plug.ex`](../../../lib/rindle/upload/tus_plug.ex:653), lines 653-736, composed with `UploadMaintenance.abort_tus_backing/2`.

```elixir
abort_attrs = abort_delete_backing(session, opts)

session
|> MediaUploadSession.changeset(Map.put(abort_attrs, :state, "aborted"))
|> Config.repo().update()
```

Collaborator returns only abort attrs; facade owns authenticated load, authorization, DB update, broadcast, and response. Abort is after auth/load yet before persistence. Preserve `tus_abort_failed:<bounded atom-or-transport>` exactly: backing failure + successful state update is 204 with retry marker; DB failure is 5xx. `tus_plug_test.exs:527-676` locks this.

### `lib/rindle/upload/broker.ex` (public lifecycle facade)

**Primary analog:** [`lib/rindle/ops/runtime_status.ex`](../../../lib/rindle/ops/runtime_status.ex:25), lines 25-63, with hidden [`collector.ex`](../../../lib/rindle/ops/runtime_status/collector.ex:1). Facade validates/gates once, delegates bounded mechanics, then shapes public output.

Keep all documented Broker functions/types (current exports lines 101-576). Retain public `with` ordering, capability gates, adapter/profile resolution, error translation, result maps, and post-success telemetry/broadcast.

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

This is [`broker.ex`](../../../lib/rindle/upload/broker.ex:566), lines 566-584. Keep `:not_found` storage translation to `{:error, :storage_object_missing}` at this boundary.

### `lib/rindle/upload/broker/session_seed.ex` (hidden seed utility)

**Analog:** repeated construction in [`broker.ex`](../../../lib/rindle/upload/broker.ex:101), lines 101-124, 140-160, 199-219, and 318-337. Own only profile name, extension, UUID, storage key, and expiry.

```elixir
asset_id = Ecto.UUID.generate()
storage_key = StorageKey.generate(profile_name, asset_id, extension)
expires_at = DateTime.add(DateTime.utc_now(), expires_in_seconds, :second)
```

Do not validate capabilities, persist, call storage, or broadcast.

### `lib/rindle/upload/broker/persistence.ex` (hidden persistence service)

**Analog:** [`broker.ex`](../../../lib/rindle/upload/broker.ex:657), lines 657-860, plus Phase 123 `Migration.V1` ownership split: facade controls mutation order, collaborator consumes provided inputs.

```elixir
case create_upload_session(..., session_attrs) do
  {:ok, session} -> {:ok, session}
  {:error, reason} ->
    compensate_failed_multipart_persist(adapter, session_seed.storage_key, multipart.upload_id, opts)
    {:error, reason}
end
```

Retain transactional asset/session insertion. Persist strategy values exactly: multipart `initialized`; native resumable `signed` + URI/expiry/offset; tus `signed`, `upload_strategy: "resumable"`, `resumable_protocol: "tus"`, offset 0. Compensation stays adjacent to persistence failure and returns original error. `broker_test.exs:295-~500` provides Mox/repository proof.

### `lib/rindle/upload/broker/session_validation.ex` (hidden validation utility)

**Analog:** [`broker.ex`](../../../lib/rindle/upload/broker.ex:867), lines 867-947. Own strategy guards, signed-state helper, multipart normalization/encoding, and resumable status attrs; preserve:

```elixir
defp ensure_multipart_session(_session), do: {:error, {:upload_unsupported, :multipart_upload}}
defp ensure_resumable_session(_session), do: {:error, {:upload_unsupported, :resumable_upload_session}}
defp normalize_multipart_parts(_parts), do: {:error, :invalid_multipart_parts}
```

Facade `with` sequences remain public-operation owned; validator never calls adapters or updates DB.

### `lib/rindle/upload/broker/completion.ex` (hidden completion/Multi service)

**Analog:** [`broker.ex`](../../../lib/rindle/upload/broker.ex:586), lines 586-655. It may construct/execute the existing Multi, but Broker retains post-commit events and result maps.

```elixir
Ecto.Multi.new()
|> Ecto.Multi.update(:verifying_session, MediaUploadSession.changeset(session, %{state: "verifying"}))
|> Ecto.Multi.run(:verify_fsm_complete, fn _repo, %{verifying_session: vs} -> do_fsm_transition(vs) end)
|> Ecto.Multi.update(:session, fn %{verifying_session: vs} -> ... end)
|> Ecto.Multi.update(:asset, MediaAsset.changeset(asset, %{state: "validating", ...}))
|> Oban.insert(:promote_job, PromoteAsset.new(%{asset_id: asset.id}))
|> repo.transaction()
```

Keys/order are locked. After commit, Broker alone emits raw/resumable stop telemetry, broadcasts, and returns `%{session: ..., asset: ...}`. `broker_test.exs:709-775` locks event timing/no missing-object emission; `lifecycle_integration_test.exs:167-280` locks promotion.

## Shared Patterns

### Hidden compiled-doc boundary

**Source:** [`test/rindle/api_surface_boundary_test.exs`](../../../test/rindle/api_surface_boundary_test.exs:53), lines 53-110. Phase 123 lists internal collaborators there and asserts compiled hidden docs. Add exact new collaborators to an appropriate hidden list, retain TusPlug/Broker in `@public_modules`, and add no `Rindle` delegates. Every callable collaborator seam needs `@doc false`.

### Facade-owned telemetry, broadcast, and result construction

**Sources:** `tus_plug.ex:389-425,986-1015`; `broker.ex:586-649,949-999`; [`resumable_telemetry.ex`](../../../lib/rindle/upload/resumable_telemetry.ex:1), lines 1-138. PATCH persists then broadcasts then emits telemetry; completion commits then emits/broadcasts. Reuse `ResumableTelemetry`, which removes `:session_uri`, `:upload_key`, `:headers`, `:body`, and untrusted session-id metadata. Leave broadcast duplication alone unless timing becomes clearer, not merely shorter.

### Capability and adapter polymorphism

**Sources:** `tus_plug.ex:108-138,478-486,607-625`; `broker.ex:140-243,445-470`; `tus_plug_test.exs:677-783`. Use `Capabilities.require_upload/2` and behavior callbacks. Pass resolved adapter/root; no Local/S3 branches, fallback, or registry.

### Behavior-backed tests and SAFE-01

Use existing facade-level/Mox/repository/integration proof. Add only objective hidden-doc coverage or an uncovered behavior/order/result parity case—never helper/source snapshots. [`scripts/maintainer/refactor_contract.sh`](../../../scripts/maintainer/refactor_contract.sh:1) force-compiles, rejects compile cycles, then runs API/schema/migration/telemetry/error/release contracts. Per slice run focused façade tests; final proof adds Local/lifecycle and CI-provisioned MinIO S3.

## No Analog Found

None. Each candidate has a direct extraction seam plus a Phase 123 precedent. Do not create shared `UploadBroadcast` by default: current duplication is timing-sensitive and line-count reduction alone is insufficient.

## Pitfalls

- Never read/open PATCH body before auth, authorization, content type, and offset match.
- Preserve DELETE's backing-failure/DB-failure contracts and retry-marker vocabulary.
- Never alter completion Multi keys/order, promotion insertion, or post-commit timing.
- Collaborators must not re-resolve application config, profile, adapter, or repo.
- Never leak signed URLs through logs, telemetry, return maps, or inspection.

## Metadata

**Analog search scope:** upload and operations modules, migration split, Rindle facade, focused upload/API/telemetry tests, Phase 123 artifacts, and maintainer contract runner.  
**Pattern extraction date:** 2026-08-22
