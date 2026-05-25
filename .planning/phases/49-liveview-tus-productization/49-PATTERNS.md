# Phase 49: liveview-tus-productization - Pattern Map

**Mapped:** 2026-05-25
**Files analyzed:** 5
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `guides/resumable_uploads.md` | config | request-response | `guides/resumable_uploads.md` | exact |
| `lib/rindle/live_view.ex` | utility | request-response | `lib/rindle/live_view.ex` | exact |
| `test/rindle/live_view_test.exs` | test | request-response | `test/rindle/live_view_test.exs` | exact |
| `test/install_smoke/phoenix_tus_truth_parity_test.exs` | test | request-response | `test/install_smoke/docs_parity_test.exs` | role-match |
| `test/install_smoke/generated_app_smoke_test.exs` | test | request-response | `test/install_smoke/generated_app_smoke_test.exs` | exact |

## Pattern Assignments

### `guides/resumable_uploads.md` (config, request-response)

**Analog:** `guides/resumable_uploads.md`

**Guide structure pattern** ([guides/resumable_uploads.md](/Users/jon/projects/rindle/guides/resumable_uploads.md:3), lines 3-17):
```markdown
Rindle ships a tus 1.0 upload edge via `Rindle.Upload.TusPlug`. This guide
covers the adopter-owned wiring: endpoint mount, client configuration,
capability checks, and the constraints you must keep in mind when resuming
uploads against Local or S3-backed storage.

This guide covers:

- When to use tus instead of presigned PUT or GCS-native resumable upload
- Mounting `Rindle.Upload.TusPlug` in Phoenix or plain Plug
- Required endpoint and parser setup
```

**Canonical LiveView helper seam pattern** ([guides/resumable_uploads.md](/Users/jon/projects/rindle/guides/resumable_uploads.md:123), lines 123-177):
```markdown
If your upload form already lives in LiveView, Rindle supports the supported thin helper seam rather than a full uploader abstraction. `Rindle.LiveView.allow_tus_upload/4` precreates the tus resource server-side and hands the signed `upload_url` plus `session_id` / `asset_id` back through LiveView's `:external` upload metadata.

Use a tiny client uploader keyed by `uploader: "RindleTus"`:

Uploaders.RindleTus = function (entries, onViewError) {
  entries.forEach((entry) => {
    let upload = new tus.Upload(entry.file, {
      endpoint: entry.meta.endpoint,
      uploadUrl: entry.meta.upload_url,
```

**Resume discovery pattern** ([guides/resumable_uploads.md](/Users/jon/projects/rindle/guides/resumable_uploads.md:168), lines 168-174):
```javascript
upload.findPreviousUploads().then((previousUploads) => {
  if (previousUploads.length > 0) {
    upload.resumeFromPreviousUpload(previousUploads[0])
  }

  upload.start()
})
```

**Honest UI state pattern** ([guides/resumable_uploads.md](/Users/jon/projects/rindle/guides/resumable_uploads.md:179), lines 179-196):
```markdown
Keep LiveView progress and server lifecycle states separate in your UI:

- `Uploading…` while the client is sending bytes
- `Verifying…` after the upload reaches `100%`
- `Ready` only after `consume_uploaded_entries/3` succeeds

LiveView still finishes through `consume_uploaded_entries/3` and the existing
`verify_completion/2` lane:
```

---

### `lib/rindle/live_view.ex` (utility, request-response)

**Analog:** `lib/rindle/live_view.ex`

**Moduledoc pointer pattern** ([lib/rindle/live_view.ex](/Users/jon/projects/rindle/lib/rindle/live_view.ex:49), lines 49-62):
```elixir
For resumable browser uploads against a mounted `Rindle.Upload.TusPlug`,
use `allow_tus_upload/4` and keep `consume_uploaded_entries/3` as the
completion gate. For full Phoenix / LiveView router, parser, CORS, and
client-uploader setup, see `guides/resumable_uploads.md`:

    socket =
      Rindle.LiveView.allow_tus_upload(socket, :video, MyApp.VideoProfile,
        path: "/uploads/tus",
        secret_key_base:
          Application.compile_env!(:my_app, MyAppWeb.Endpoint)[:secret_key_base],
```

**Thin helper wrapper pattern** ([lib/rindle/live_view.ex](/Users/jon/projects/rindle/lib/rindle/live_view.ex:131), lines 131-167):
```elixir
@doc """
Configures a LiveView external upload backed by Rindle's tus edge.

Requires:

  * `:path` - the mounted tus route, such as `"/uploads/tus"`
  * `:secret_key_base` - the same secret used to mount `Rindle.Upload.TusPlug`
"""
def allow_tus_upload(socket, name, profile, opts \\ []) do
  path = Keyword.fetch!(opts, :path)
  secret_key_base = Keyword.fetch!(opts, :secret_key_base)
  actor = Keyword.get(opts, :actor)

  external_fn = fn entry, socket ->
    do_allow_tus_upload(entry, socket, profile, path, secret_key_base, actor)
  end
```

**External metadata contract pattern** ([lib/rindle/live_view.ex](/Users/jon/projects/rindle/lib/rindle/live_view.ex:228), lines 228-248):
```elixir
defp do_allow_tus_upload(entry, socket, profile, path, secret_key_base, actor_opt) do
  case resolve_actor(actor_opt, socket) do
    {:ok, actor} ->
      case Rindle.initiate_tus_upload(profile,
             filename: entry.client_name,
             length: entry.client_size,
             content_type: entry.client_type,
             path: path,
             secret_key_base: secret_key_base,
             actor: actor
           ) do
        {:ok, %{session: session, upload_url: upload_url}} ->
          meta = %{
            uploader: "RindleTus",
            endpoint: path,
            upload_url: upload_url,
            session_id: session.id,
            asset_id: session.asset_id
          }
```

**Completion verification pattern** ([lib/rindle/live_view.ex](/Users/jon/projects/rindle/lib/rindle/live_view.ex:280), lines 280-323):
```elixir
@doc """
Consumes completed upload entries and verifies them through Rindle.
"""
def consume_uploaded_entries(socket, name, func) when is_function(func, 2) do
  Upload.consume_uploaded_entries(socket, name, fn meta, entry ->
    do_consume(meta, entry, func)
  end)
end

case Rindle.verify_completion(session_id) do
  {:ok, %{asset: _asset}} ->
    func.(entry, meta)

  {:error, reason} ->
    {:postpone, {:error, {:rindle_verify_failed, reason}}}
end
```

---

### `test/rindle/live_view_test.exs` (test, request-response)

**Analog:** `test/rindle/live_view_test.exs`

**Helper metadata assertion pattern** ([test/rindle/live_view_test.exs](/Users/jon/projects/rindle/test/rindle/live_view_test.exs:150), lines 150-177):
```elixir
updated_socket =
  Rindle.LiveView.allow_tus_upload(socket, :video, TusProfile,
    path: "/uploads/tus",
    secret_key_base: @tus_secret_key_base,
    actor: "user-123",
    accept: ~w(.mp4),
    max_entries: 1
  )

assert {:ok, meta, ^updated_socket} = external_fn.(entry, updated_socket)
assert meta.uploader == "RindleTus"
assert meta.endpoint == "/uploads/tus"
assert String.starts_with?(meta.upload_url, "/uploads/tus/")
```

**Facade parity assertion pattern** ([test/rindle/live_view_test.exs](/Users/jon/projects/rindle/test/rindle/live_view_test.exs:199), lines 199-215):
```elixir
assert {:ok, %{session: session, upload_url: upload_url, expires_at: %DateTime{}}} =
         Rindle.initiate_tus_upload(TusProfile,
           filename: "clip.mp4",
           length: 4_096,
           content_type: "video/mp4",
           path: "/uploads/tus",
           secret_key_base: @tus_secret_key_base,
           actor: "user-123"
         )
```

**Verification-lane test pattern** ([test/rindle/live_view_test.exs](/Users/jon/projects/rindle/test/rindle/live_view_test.exs:218), lines 218-298):
```elixir
results =
  Rindle.LiveView.consume_uploaded_entries(completed_socket, :avatar, fn uploaded_entry,
                                                                             uploaded_meta ->
    {:ok, {uploaded_entry.client_name, uploaded_meta.asset_id}}
  end)

assert results == [{"avatar.png", meta.asset_id}]
assert session.state == "completed"
assert asset.state == "validating"

assert [{:error, {:rindle_verify_failed, :storage_object_missing}}] =
         Rindle.LiveView.consume_uploaded_entries(completed_socket, :avatar, fn _, _ ->
           {:ok, :unexpected}
         end)
```

**Moduledoc freeze pattern** ([test/rindle/live_view_test.exs](/Users/jon/projects/rindle/test/rindle/live_view_test.exs:331), lines 331-353):
```elixir
{:docs_v1, _, _, _, moduledoc, _, _} = Code.fetch_docs(Rindle.LiveView)
rendered_doc = extract_doc(moduledoc)

assert rendered_doc =~ "Rindle.verify_completion/2"
assert rendered_doc =~ "{:ok, meta.asset_id}"
assert rendered_doc =~ "handle_info({:rindle_event, type, payload}, socket)"
```

---

### `test/install_smoke/phoenix_tus_truth_parity_test.exs` (test, request-response)

**Analog:** `test/install_smoke/docs_parity_test.exs`

**Shared setup/read pattern** ([test/install_smoke/docs_parity_test.exs](/Users/jon/projects/rindle/test/install_smoke/docs_parity_test.exs:7), lines 7-24):
```elixir
@readme_path Path.expand("../../README.md", __DIR__)
@guide_path Path.expand("../../guides/getting_started.md", __DIR__)

setup_all do
  {:ok,
   %{
     readme: File.read!(@readme_path),
     guide: File.read!(@guide_path),
     upgrade: File.read!(@upgrade_path)
   }}
end
```

**String-parity assertion style** ([test/install_smoke/docs_parity_test.exs](/Users/jon/projects/rindle/test/install_smoke/docs_parity_test.exs:26), lines 26-41):
```elixir
test "README and getting-started guide teach the facade-first lifecycle and handoff", %{
  readme: readme,
  guide: guide
} do
  for doc <- [readme, guide] do
    assert doc =~ "Rindle.Profile"
    assert doc =~ "Rindle.initiate_upload"
    assert doc =~ "Rindle.verify_completion"
  end
end
```

**Existing Phoenix tus truth-freeze pattern to preserve/extend** ([test/install_smoke/phoenix_tus_truth_parity_test.exs](/Users/jon/projects/rindle/test/install_smoke/phoenix_tus_truth_parity_test.exs:15), lines 15-40):
```elixir
guide = File.read!(@guide_path)
live_view = File.read!(@live_view_path)

assert guide =~ "supported thin helper seam"
assert guide =~ ~s(uploader: "RindleTus")
assert guide =~ "consume_uploaded_entries/3"
assert guide =~ "verify_completion/2"

assert live_view =~ "guides/resumable_uploads.md"
refute live_view =~ "plug Plug.Parsers"
refute live_view =~ "config :cors_plug"
```

---

### `test/install_smoke/generated_app_smoke_test.exs` (test, request-response)

**Analog:** `test/install_smoke/generated_app_smoke_test.exs`

**Embedded guide-proof helper pattern** ([test/install_smoke/generated_app_smoke_test.exs](/Users/jon/projects/rindle/test/install_smoke/generated_app_smoke_test.exs:29), lines 29-47):
```elixir
defp assert_tus_guide_parity! do
  guide = File.read!("guides/resumable_uploads.md")

  assert guide =~ "plug Plug.Parsers,"
  assert guide =~ ~s(pass: ["application/offset+octet-stream", "*/*"])
  assert guide =~ "no-silent-downgrade"
  assert guide =~ "bearer credential"
  assert guide =~ "@uppy/tus"
  assert guide =~ "tus-js-client"
  assert guide =~ "sticky-session or single-node"
end
```

**Smoke-test helper style** ([test/install_smoke/generated_app_smoke_test.exs](/Users/jon/projects/rindle/test/install_smoke/generated_app_smoke_test.exs:10), lines 10-27):
```elixir
defp assert_install_source!(report) do
  assert File.dir?(report.generated_app_root)
  assert report.profile_mode in [:image, :video, :tus, :upgrade, :mux, :gcs]
  assert report.install_mode in [:package, :network]
  assert report.install_source
  refute report.deps_rindle_present?
  assert report.compile_exit_code == 0
  assert report.boot_exit_code == 0
end
```

---

## Shared Patterns

### Signed tus facade entrypoint
**Source:** [lib/rindle.ex](/Users/jon/projects/rindle/lib/rindle.ex:96)
**Apply to:** `lib/rindle/live_view.ex`, `guides/resumable_uploads.md`, `test/rindle/live_view_test.exs`
```elixir
@doc """
Initiates a tus upload resource through the broker and returns the signed
upload URL needed by browser tus clients.
"""
@spec initiate_tus_upload(module(), keyword()) :: TusPlug.create_upload_result()
def initiate_tus_upload(profile, opts \\ []) do
  TusPlug.create_upload(profile, opts)
end
```

### Verification stays server-owned
**Source:** [lib/rindle.ex](/Users/jon/projects/rindle/lib/rindle.ex:125)
**Apply to:** `guides/resumable_uploads.md`, `lib/rindle/live_view.ex`, `test/rindle/live_view_test.exs`, `test/install_smoke/phoenix_tus_truth_parity_test.exs`
```elixir
@doc """
Verifies a direct upload completion through the broker.

Delegates to `Broker.verify_completion/2`. Promotes the
session to `completed` and the asset to `validating`.
"""
def verify_completion(session_id, opts \\ []) do
  Broker.verify_completion(session_id, opts)
end
```

### Tus URL creation contract
**Source:** [lib/rindle/upload/tus_plug.ex](/Users/jon/projects/rindle/lib/rindle/upload/tus_plug.ex:156)
**Apply to:** `lib/rindle/live_view.ex`, `guides/resumable_uploads.md`, `test/rindle/live_view_test.exs`
```elixir
def create_upload(profile, opts) when is_atom(profile) and is_list(opts) do
  with path when is_binary(path) <- Keyword.fetch!(opts, :path),
       secret_key_base when is_binary(secret_key_base) <- Keyword.fetch!(opts, :secret_key_base),
       {:ok, length} <- normalize_length(Keyword.get(opts, :length)) do
    actor = Keyword.get(opts, :actor, "anonymous")
```

**Persisted signed URL pattern** ([lib/rindle/upload/tus_plug.ex](/Users/jon/projects/rindle/lib/rindle/upload/tus_plug.ex:224), lines 224-238):
```elixir
with {:ok, %{session: session}} <-
       Broker.initiate_tus_upload(profile, filename: filename, expires_in: expires_in),
     {:ok, upload_url, signed_session} <-
       sign_and_persist(base_path, session, length, content_type, secret_key_base, actor) do
  {:ok,
   %{session: signed_session, upload_url: upload_url, expires_at: signed_session.expires_at}}
end
```

### Broker completion boundary
**Source:** [lib/rindle/upload/broker.ex](/Users/jon/projects/rindle/lib/rindle/upload/broker.ex:255)
**Apply to:** `lib/rindle/live_view.ex`, `guides/resumable_uploads.md`, `test/rindle/live_view_test.exs`
```elixir
def initiate_tus_upload(profile_module, opts \\ []) do
  with :ok <- Capabilities.require_upload(adapter, :tus_upload),
       {:ok, session} <- persist_tus_session(repo, %{...}, opts) do
    emit_upload_start(profile_name, adapter, session.id)
    {:ok, %{session: session}}
  end
end
```

**Verification/error mapping pattern** ([lib/rindle/upload/broker.ex](/Users/jon/projects/rindle/lib/rindle/upload/broker.ex:487), lines 487-505):
```elixir
def verify_completion(session_id, opts \\ []) do
  with %MediaUploadSession{} = session <- repo.get(MediaUploadSession, session_id),
       asset <- repo.preload(session, :asset).asset,
       {:ok, metadata} <- adapter.head(session.upload_key, opts),
       :ok <- UploadSessionFSM.transition(session.state, "verifying", %{session_id: session.id}),
       :ok <- AssetFSM.transition(asset.state, "validating", %{asset_id: asset.id}) do
    execute_verify_completion(repo, session, asset, profile_module, metadata)
  else
    {:error, :not_found} -> {:error, :storage_object_missing}
    {:error, reason} -> {:error, reason}
  end
end
```

### Install-smoke string-freeze style
**Source:** [test/install_smoke/docs_parity_test.exs](/Users/jon/projects/rindle/test/install_smoke/docs_parity_test.exs:26)
**Apply to:** `test/install_smoke/phoenix_tus_truth_parity_test.exs`, `test/install_smoke/generated_app_smoke_test.exs`
```elixir
for doc <- [readme, guide] do
  assert doc =~ "Rindle.Profile"
  assert doc =~ "Rindle.initiate_upload"
  assert doc =~ "Rindle.verify_completion"
end
```

## No Analog Found

None. Every likely Phase 49 touchpoint already exists and should be tightened in place rather than introducing a new pattern.

## Metadata

**Analog search scope:** `lib/`, `guides/`, `test/`
**Files scanned:** 240 (`lib`: 103, `test`: 123, `guides`: 14)
**Pattern extraction date:** 2026-05-25
