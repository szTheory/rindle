# Phase 44: auth-hardening-dx-docs-telemetry-ci-proof - Pattern Map

**Mapped:** 2026-05-23
**Files analyzed:** 14
**Analogs found:** 14 / 14

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/rindle/upload/tus_plug.ex` | middleware | request-response | `lib/rindle/upload/tus_plug.ex` | exact |
| `test/rindle/upload/tus_plug_test.exs` | test | request-response | `test/rindle/upload/tus_plug_test.exs` | exact |
| `lib/rindle/error.ex` | utility | transform | `lib/rindle/error.ex` | exact |
| `test/rindle/error_test.exs` | test | transform | `test/rindle/error_test.exs` | exact |
| `lib/rindle/upload/resumable_telemetry.ex` | utility | event-driven | `lib/rindle/upload/resumable_telemetry.ex` | exact |
| `test/rindle/contracts/telemetry_contract_test.exs` | test | event-driven | `test/rindle/contracts/telemetry_contract_test.exs` | exact |
| `lib/rindle/ops/runtime_checks.ex` | service | batch | `lib/rindle/ops/runtime_checks.ex` | exact |
| `test/rindle/ops/runtime_checks_test.exs` | test | batch | `test/rindle/ops/runtime_checks_test.exs` | exact |
| `lib/mix/tasks/rindle.doctor.ex` | config | request-response | `lib/mix/tasks/rindle.doctor.ex` | exact |
| `guides/resumable_uploads.md` | utility | transform | `guides/resumable_uploads.md` | exact |
| `test/install_smoke/support/generated_app_helper.ex` | utility | file-I/O | `test/install_smoke/support/generated_app_helper.ex` | exact |
| `test/install_smoke/generated_app_smoke_test.exs` | test | request-response | `test/install_smoke/generated_app_smoke_test.exs` | exact |
| `.github/workflows/ci.yml` | config | batch | `.github/workflows/ci.yml` | exact |
| `lib/rindle/delivery/webhook_plug.ex` | middleware | request-response | `lib/rindle/delivery/webhook_plug.ex` | exact |

## Pattern Assignments

### `lib/rindle/upload/tus_plug.ex` (middleware, request-response)

**Analog:** `lib/rindle/upload/tus_plug.ex`

**Imports + init pattern** (lines 71-121):
```elixir
import Plug.Conn

require Logger

alias Rindle.Config
alias Rindle.Domain.MediaUploadSession
alias Rindle.Ops.UploadMaintenance
alias Rindle.Storage.Capabilities
alias Rindle.Upload.{Broker, ResumableTelemetry}

def init(opts) do
  profile = Keyword.fetch!(opts, :profile)
  secret_key_base = Keyword.fetch!(opts, :secret_key_base)
  max_size = Keyword.get(opts, :max_size, @default_max_size)
  identity_fn = Keyword.get(opts, :identity_fn, &__MODULE__.default_actor/1)
  resume_authorizer = validate_resume_authorizer!(Config.tus_resume_authorizer())
  adapter = profile.storage_adapter()
```

**Request dispatch pattern** (lines 125-131):
```elixir
def call(%Plug.Conn{method: "OPTIONS"} = conn, opts), do: handle_options(conn, opts)
def call(%Plug.Conn{method: "POST"} = conn, opts), do: handle_post(conn, opts)
def call(%Plug.Conn{method: "HEAD"} = conn, opts), do: handle_head(conn, opts)
def call(%Plug.Conn{method: "PATCH"} = conn, opts), do: handle_patch(conn, opts)
def call(%Plug.Conn{method: "DELETE"} = conn, opts), do: handle_delete(conn, opts)
```

**Optional resume-authorization pattern** (lines 639-667):
```elixir
defp authorize_resume(conn, payload, session, method, opts) do
  case opts[:resume_authorizer] do
    nil ->
      :ok

    authorizer ->
      actor = opts[:identity_fn].(conn)

      case authorizer.authorize(actor, :resume, %{
             token_actor: Map.get(payload, "actor"),
             session: session,
             profile: opts[:profile],
             method: method
           }) do
        :ok -> :ok
        :reject -> {:error, :resume_rejected}
        other -> raise ArgumentError, "invalid tus resume authorizer result: #{inspect(other)}"
      end
  end
end
```

**PATCH + telemetry pattern** (lines 219-243):
```elixir
with {:ok, payload} <- verify_token(conn, opts),
     {:ok, session} <- load_active_session(payload),
     :ok <- authorize_resume(conn, payload, session, :patch, opts),
     :ok <- require_offset_octet_stream(conn),
     {:ok, inbound_offset} <- parse_upload_offset(conn),
     :ok <- check_offset_match(inbound_offset, session.last_known_offset),
     {:ok, part_state} <- stream_append(conn, session, payload, opts) do
  new_offset = part_state.offset
  {:ok, advanced} = persist_offset(session, part_state)

  ResumableTelemetry.emit_patch(
    to_string(opts[:profile]),
    opts[:adapter],
    advanced,
    %{state: advanced.state, source: :patch, outcome: :ok, protocol: :tus},
    %{committed_bytes: new_offset, offset_delta: new_offset - session.last_known_offset}
  )
```

**Protocol-native error/status pattern** (lines 568-585):
```elixir
defp status_for(:invalid_token), do: 404
defp status_for(:not_found), do: 404
defp status_for(:expired_token), do: 401
defp status_for(:resume_rejected), do: 401
defp status_for(:gone), do: 410
defp status_for(:wrong_content_type), do: 415
defp status_for(:offset_mismatch), do: 409
defp status_for(:too_large), do: 413

defp tus_error(conn, status, body) do
  conn
  |> put_tus_resumable()
  |> send_resp(status, body)
  |> halt()
end
```

---

### `test/rindle/upload/tus_plug_test.exs` (test, request-response)

**Analog:** `test/rindle/upload/tus_plug_test.exs`

**Real router + forward pattern** (lines 73-89):
```elixir
defmodule TusRouter do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  forward("/uploads/tus",
    to: Rindle.Upload.TusPlug,
    init_opts: [
      profile: Rindle.Upload.TusPlugTest.TusProfile,
      secret_key_base: "tus-test-secret-key-base-0123456789abcdef",
      max_size: 1_000_000
    ]
  )
end
```

**Authorizer test pattern** (lines 357-401):
```elixir
setup do
  Application.put_env(:rindle, :tus_resume_authorizer, Rindle.TusResumeAuthorizerMock)
  :ok
end

expect(Rindle.TusResumeAuthorizerMock, :authorize, fn "anonymous", :resume, subject ->
  assert subject.token_actor == "anonymous"
  assert subject.session.id == session.id
  assert subject.profile == TusProfile
  assert subject.method == :head
  :reject
end)

conn = head(opts, token)
assert conn.status == 401
```

**Resume contract-flow pattern** (lines 740-780):
```elixir
p1 = patch(opts, token, 0, "01234567")
assert p1.status == 204
assert get_resp_header(p1, "upload-offset") == ["8"]

stale = patch(opts, token, 0, "01234567")
assert stale.status == 409

assert get_resp_header(head(opts, token), "upload-offset") == ["8"]

p2 = patch(opts, token, 8, "89abcdef")
assert p2.status == 204
assert get_resp_header(p2, "upload-offset") == ["16"]
```

---

### `lib/rindle/error.ex` (utility, transform)

**Analog:** `lib/rindle/error.ex`

**Public-reason message pattern** (lines 326-383):
```elixir
def message(%{reason: :tus_session_not_found}) do
  """
  The tus upload session could not be found.

  To fix:
    1. Confirm the client is resuming with the exact `Location` URL returned by the original tus `POST`.
    2. If the upload was deleted or expired, create a fresh tus upload instead of retrying the old URL.
    3. Keep `removeFingerprintOnSuccess: true` enabled so completed uploads do not reuse stale fingerprints.
  """
  |> String.trim()
end
```

**Fallback shape pattern** (lines 386-395):
```elixir
def message(%{action: action, reason: :not_found}) do
  "could not #{action}: not found"
end

def message(%{action: action, reason: {:quarantine, why}}) do
  "could not #{action}: upload quarantined (#{inspect(why)})"
end
```

---

### `test/rindle/error_test.exs` (test, transform)

**Analog:** `test/rindle/error_test.exs`

**Locked-reason allowlist pattern** (lines 6-37):
```elixir
@av_public_reasons [
  :processor_capability_missing,
  :ffmpeg_not_found,
  :capability_drift,
  :variant_source_not_found,
  :unsupported_codec,
  :streaming_not_configured,
  :variant_processing_cancelled,
  :range_unparseable,
  :tus_session_not_found,
  :tus_session_expired,
  :tus_offset_conflict,
  :tus_size_exceeded,
  :tus_url_signature_invalid
]
```

**Exact message contract pattern** (lines 40-155):
```elixir
for {reason, expected} <- expected_messages do
  error = struct!(Rindle.Error, action: :test_contract, reason: reason)
  assert Rindle.Error.message(error) == expected
end
```

---

### `lib/rindle/upload/resumable_telemetry.ex` (utility, event-driven)

**Analog:** `lib/rindle/upload/resumable_telemetry.ex`

**Namespace + metadata policy pattern** (lines 6-13):
```elixir
@start_event [:rindle, :upload, :resumable, :start]
@patch_event [:rindle, :upload, :resumable, :patch]
@stop_event [:rindle, :upload, :resumable, :stop]
@status_event [:rindle, :upload, :resumable, :status]
@cancel_event [:rindle, :upload, :resumable, :cancel]
@allowed_metadata_keys [:state, :outcome, :reason, :source, :protocol]
@forbidden_metadata_keys [:session_uri, :upload_key, :headers, :body, :session_id]
```

**Emit wrapper pattern** (lines 117-126):
```elixir
metadata =
  metadata_overrides
  |> normalize_map()
  |> Map.drop(@forbidden_metadata_keys)
  |> Map.take(@allowed_metadata_keys)
  |> Map.merge(%{profile: profile, adapter: adapter})
  |> maybe_put_session_id(session_or_nil)

:telemetry.execute(event, measurements, metadata)
```

---

### `test/rindle/contracts/telemetry_contract_test.exs` (test, event-driven)

**Analog:** `test/rindle/contracts/telemetry_contract_test.exs`

**Event allowlist pattern** (lines 70-92):
```elixir
@public_events [
  [:rindle, :upload, :start],
  [:rindle, :upload, :stop],
  [:rindle, :upload, :resumable, :start],
  [:rindle, :upload, :resumable, :patch],
  [:rindle, :upload, :resumable, :stop],
  [:rindle, :upload, :resumable, :status],
  [:rindle, :upload, :resumable, :cancel]
]
```

**Redaction/contract assertion pattern** (lines 238-315):
```elixir
ResumableTelemetry.emit_status(
  "TestProfile",
  Rindle.Storage.GCS,
  session,
  %{state: "resuming", source: :poll, session_uri: session.session_uri},
  %{committed_bytes: 128, offset_delta: 64}
)

refute Map.has_key?(status_metadata, :session_uri)
assert status_metadata.profile == "TestProfile"
assert status_metadata.adapter == Rindle.Storage.GCS
```

---

### `lib/rindle/ops/runtime_checks.ex` (service, batch)

**Analog:** `lib/rindle/ops/runtime_checks.ex`

**Check-runner assembly pattern** (lines 76-149):
```elixir
checks =
  ([
     fn -> check_delivery_support(profiles) end,
     fn -> check_ffmpeg_runtime(probe) end,
     fn -> check_local_playback(profiles, local_playback_route) end,
     fn -> check_migration_pending(migration_statuses) end,
     fn -> check_migration_unresolved(migration_statuses) end,
     fn -> check_resumable_session_schema(resumable_session_schema_catalog) end,
     fn -> check_oban_default_instance(oban_config) end,
     fn -> check_oban_required_queues(profiles, oban_config) end,
     fn -> check_profile_runtime_fit(resolved, env) end,
     fn -> check_streaming_credentials(profiles, env) end,
     fn -> check_streaming_signing_key(profiles, env) end,
     fn -> check_streaming_webhook_secrets(profiles, env) end,
     fn -> check_streaming_smoke_ping(profiles, env, opts) end
   ] ++ gcs_extra ++ tus_extra)
  |> Enum.map(&run_check/1)
  |> Enum.sort_by(& &1.id)
```

**Tus capability doctor pattern** (lines 270-290):
```elixir
defp check_tus_capability(profiles) do
  mismatches =
    Enum.filter(tus_profiles(profiles), fn profile ->
      adapter = safely_storage_adapter(profile)
      not is_atom(adapter) or not Rindle.Storage.Capabilities.supports?(adapter, :tus_upload)
    end)

  if mismatches == [] do
    ok_result(
      "doctor.tus_capability",
      :profiles,
      "Configured tus profiles advertise :tus_upload support.",
      "Keep `config :rindle, :tus_profiles, [...]` aligned with profiles whose adapters support tus."
    )
```

**Report-shape helpers** (lines 1536-1545):
```elixir
defp ok_result(id, component, summary, fix) do
  %{id: id, status: :ok, component: component, summary: summary, fix: fix}
end

defp warn_result(id, component, summary, fix) do
  %{id: id, status: :warn, component: component, summary: summary, fix: fix}
end
```

---

### `test/rindle/ops/runtime_checks_test.exs` (test, batch)

**Analog:** `test/rindle/ops/runtime_checks_test.exs`

**Stable-check-id contract pattern** (lines 45-99):
```elixir
assert Enum.map(report.checks, & &1.id) == [
         "doctor.delivery_support",
         "doctor.ffmpeg_runtime",
         "doctor.local_playback",
         "doctor.migrations.pending",
         "doctor.migrations.unresolved",
         "doctor.oban_default_instance",
         "doctor.oban_required_queues",
         "doctor.profile_runtime_fit",
         "doctor.resumable_session_schema",
         "doctor.streaming_credentials",
         "doctor.streaming_signing_key",
         "doctor.streaming_smoke_ping",
         "doctor.streaming_webhook_secrets",
         "doctor.tus_capability"
       ]
```

**Tus drift test pattern** (lines 296-334):
```elixir
check = fetch_check(report, "doctor.tus_capability")
assert check.status == :error
assert check.summary =~ "TusUnsupportedVideoProfile"
assert check.fix =~ ":tus_profiles"
```

---

### `lib/mix/tasks/rindle.doctor.ex` (config, request-response)

**Analog:** `lib/mix/tasks/rindle.doctor.ex`

**Option parsing + loud failure pattern** (lines 35-57):
```elixir
{parsed, rest, invalid} =
  OptionParser.parse(args, strict: [streaming: :boolean])

case invalid do
  [] ->
    :ok

  invalid_flags ->
    Mix.raise(
      "Unknown options: " <>
        Enum.map_join(invalid_flags, ", ", fn {flag, _} -> flag end)
    )
end
```

**Report emission pattern** (lines 84-109):
```elixir
Enum.each(report.checks, &emit_check(shell, &1))

shell.info("[#{String.upcase(to_string(status))}] #{id} (#{component}) #{summary}")

if status in [:warn, :error] do
  shell.info("  Fix: #{fix}")
end
```

---

### `guides/resumable_uploads.md` (utility, transform)

**Analog:** `guides/resumable_uploads.md`

**Guide structure pattern** (lines 8-17):
```md
- When to use tus instead of presigned PUT or GCS-native resumable upload
- Mounting `Rindle.Upload.TusPlug` in Phoenix or plain Plug
- Required endpoint and parser setup
- CORS headers for browser clients
- `tus-js-client` and `@uppy/tus` client settings
- Optional same-user resume authorization
- Doctor checks and capability honesty
- Security checklist and no-silent-downgrade rules
```

**Mount + doctor config pattern** (lines 37-60):
```elixir
forward "/uploads/tus", Rindle.Upload.TusPlug,
  profile: MyApp.VideoProfile,
  secret_key_base: MyAppWeb.Endpoint.config(:secret_key_base)

config :rindle, :tus_profiles, [MyApp.VideoProfile]
```

**Security wording pattern** (lines 75-76, 161-168):
```md
The signed tus `Location` URL is opaque. Treat it as a bearer credential and
reuse it byte-for-byte.

- Keep the signed `Location` URL secret; it is a bearer credential.
- For S3-backed tus uploads, keep sticky-session or single-node routing in
  place.
```

---

### `test/install_smoke/support/generated_app_helper.ex` (utility, file-I/O)

**Analog:** `test/install_smoke/support/generated_app_helper.ex`

**Generated-app patch orchestration pattern** (lines 316-336):
```elixir
defp patch_generated_app!(root, app_name, app_module, package_root, network_version, profile_mode) do
  patch_mix_exs!(root, package_root, network_version, profile_mode)
  patch_test_config!(root, app_name, profile_mode)
  patch_test_helper!(root, profile_mode)
  patch_runtime_config!(root, app_name, app_module, profile_mode)
  patch_application!(root, app_name, app_module, profile_mode)
  patch_router!(root, app_name, app_module, profile_mode)
  write_profile!(root, app_name, app_module, profile_mode)
  write_host_migration!(root)
  write_migration_runner!(root, app_name, app_module)
  write_legacy_upgrade_preparer!(root, app_module)
  write_smoke_test!(root, app_module, profile_mode)
  write_fixture!(root, profile_mode)
end
```

**Tus-specific generated-app config pattern** (lines 440-488):
```elixir
if profile_mode == :tus do
  base_updated <>
    """

    config :rindle, :tus_profiles, [#{Macro.camelize(app_name)}.VideoProfile]
    """
end

String.replace(
  "scope \"/\", #{app_module}Web do",
  """
  forward "/uploads/tus", Rindle.Upload.TusPlug,
    profile: #{app_module}.VideoProfile,
    secret_key_base: #{app_module}Web.Endpoint.config(:secret_key_base)
```

**Real-socket tus proof pattern** (lines 1328-1415):
```elixir
install_tus_js_client!()

script_path = Path.expand("../tmp/install_smoke_tus_proof.cjs", __DIR__)
write_tus_node_script!(script_path)

proof =
  run_tus_node_proof!(
    script_path,
    "http://127.0.0.1:\#{port}/uploads/tus",
    fixture_path
  )

assert proof["previous_uploads"] >= 1
assert String.contains?(proof["upload_url"], "/uploads/tus/")
```

**Pinned Node client proof-script pattern** (lines 2116-2248):
```elixir
System.cmd("npm", ["install", "--no-save", "tus-js-client@4.3.1"], stderr_to_stdout: true)

const upload = new tus.Upload(file, {
  ...baseOptions(),
  onSuccess: () => {
    resolve({
      upload_url: upload.url,
      previous_uploads: previousUploads.length,
    })
  },
})

previousUploads = await upload.findPreviousUploads()
upload.resumeFromPreviousUpload(previousUploads[0])
```

---

### `test/install_smoke/generated_app_smoke_test.exs` (test, request-response)

**Analog:** `test/install_smoke/generated_app_smoke_test.exs`

**Tus smoke assertion pattern** (lines 144-176):
```elixir
setup_all do
  report = GeneratedAppHelper.prove_package_install!(:tus)
  on_exit(fn -> GeneratedAppHelper.cleanup(report) end)
  {:ok, report: report}
end

test "generated Phoenix app proves a real-socket tus-js-client drop-and-resume flow against MinIO",
     %{report: report} do
  assert report.tus_previous_uploads >= 1
  assert report.tus_byte_size >= 200 * 1024 * 1024
  assert report.tus_content_type == "video/mp4"
  assert report.tus_ready_variants == ["poster", "web_720p"]
end
```

---

### `.github/workflows/ci.yml` (config, batch)

**Analog:** `.github/workflows/ci.yml`

**Package-consumer lane pattern** (lines 295-303):
```yaml
package-consumer:
  name: Package Consumer Proof Matrix + Release Preflight
  runs-on: ubuntu-22.04
  continue-on-error: true
  needs: quality
```

**Service-backed smoke proof pattern** (lines 341-402):
```yaml
- name: Set up Node
  uses: actions/setup-node@v4
  with:
    node-version: "20"

- name: Start MinIO for S3-compatible package-consumer proofs
  run: |
    docker run -d --name rindle-minio -p 9000:9000 ...

- name: Run built-artifact tus package-consumer proof against MinIO
  run: bash scripts/install_smoke.sh tus
```

---

### `lib/rindle/delivery/webhook_plug.ex` (middleware, request-response)

**Analog:** `lib/rindle/delivery/webhook_plug.ex`

**Init validation pattern** (lines 87-101):
```elixir
provider = Keyword.fetch!(opts, :provider)
secrets = Keyword.fetch!(opts, :secrets)

unless Code.ensure_loaded?(provider) and function_exported?(provider, :verify_webhook, 3) do
  raise ArgumentError, ...
end

unless valid_secrets_resolver?(secrets) do
  raise ArgumentError, ...
end
```

**Verify-and-dispatch pattern** (lines 126-150):
```elixir
with {:ok, raw_body, conn} <- fetch_raw_body(conn),
     headers = Enum.into(conn.req_headers, %{}),
     {:ok, event} <- safe_verify(provider, raw_body, headers, secrets) do
  dispatch_event(conn, provider, event)
else
  {:error, :body_missing} ->
    emit_rejected(:body_reader_missing, %{provider: provider_atom(provider)})
    conn |> send_resp(500, "server_misconfigured") |> halt()
```

**Fallback body-read pattern relevant to WR-01** (lines 228-240):
```elixir
case WebhookBodyReader.raw_body(conn) do
  binary when is_binary(binary) and byte_size(binary) > 0 ->
    {:ok, binary, conn}

  _ ->
    case Plug.Conn.read_body(conn) do
      {:ok, body, conn} when byte_size(body) > 0 -> {:ok, body, conn}
      _ -> {:error, :body_missing}
    end
end
```

## Shared Patterns

### Authentication / Resume Authorization
**Source:** `lib/rindle/upload/tus_plug.ex:639-667`
**Apply to:** `lib/rindle/upload/tus_plug.ex`, `guides/resumable_uploads.md`, `test/rindle/upload/tus_plug_test.exs`
```elixir
case opts[:resume_authorizer] do
  nil -> :ok
  authorizer ->
    case authorizer.authorize(actor, :resume, %{token_actor: ..., session: ..., profile: ..., method: ...}) do
      :ok -> :ok
      :reject -> {:error, :resume_rejected}
    end
end
```

### Protocol-Native Error Handling
**Source:** `lib/rindle/upload/tus_plug.ex:568-585`, `lib/rindle/delivery/webhook_plug.ex:132-150`
**Apply to:** `lib/rindle/upload/tus_plug.ex`, `lib/rindle/delivery/webhook_plug.ex`
```elixir
{:error, reason} -> tus_error(conn, status_for(reason), "")

{:error, :body_missing} ->
  conn
  |> send_resp(500, "server_misconfigured")
  |> halt()
```

### Telemetry Redaction Wrapper
**Source:** `lib/rindle/upload/resumable_telemetry.ex:117-126`
**Apply to:** `lib/rindle/upload/resumable_telemetry.ex`, `lib/rindle/upload/tus_plug.ex`, `test/rindle/contracts/telemetry_contract_test.exs`
```elixir
metadata_overrides
|> normalize_map()
|> Map.drop(@forbidden_metadata_keys)
|> Map.take(@allowed_metadata_keys)
|> Map.merge(%{profile: profile, adapter: adapter})
```

### Doctor Check Result Shape
**Source:** `lib/rindle/ops/runtime_checks.ex:1536-1545`, `lib/mix/tasks/rindle.doctor.ex:98-109`
**Apply to:** `lib/rindle/ops/runtime_checks.ex`, `lib/mix/tasks/rindle.doctor.ex`, `test/rindle/ops/runtime_checks_test.exs`
```elixir
%{id: id, status: :ok | :warn | :error, component: component, summary: summary, fix: fix}

shell.info("[#{String.upcase(to_string(status))}] #{id} (#{component}) #{summary}")
```

### Generated-App Tus Proof
**Source:** `test/install_smoke/support/generated_app_helper.ex:1328-1415`, `.github/workflows/ci.yml:398-402`
**Apply to:** `test/install_smoke/support/generated_app_helper.ex`, `test/install_smoke/generated_app_smoke_test.exs`, `.github/workflows/ci.yml`
```elixir
proof = run_tus_node_proof!(script_path, endpoint, fixture_path)
assert proof["previous_uploads"] >= 1
```

```yaml
- name: Run built-artifact tus package-consumer proof against MinIO
  run: bash scripts/install_smoke.sh tus
```

## No Analog Found

None. Every file implicated by Phase 44 already has a live in-repo analog, so the planner should extend existing surfaces rather than introduce a new pattern family.

## Metadata

**Analog search scope:** `lib/`, `test/`, `guides/`, `.github/workflows/`, `.planning/milestones/v1.6-phases/35-signed-webhook-plug-idempotent-ingest/`
**Files scanned:** 14 primary analog files plus repository-wide `rg` searches over the phase surface
**Pattern extraction date:** 2026-05-23
