# Phase 50: Phoenix Proof + Parity Closure - Pattern Map

**Mapped:** 2026-05-25
**Files analyzed:** 6
**Analogs found:** 6 / 6

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `guides/resumable_uploads.md` | config | request-response | `guides/resumable_uploads.md` | exact |
| `lib/rindle/live_view.ex` | utility | request-response | `lib/rindle/live_view.ex` | exact |
| `test/rindle/live_view_test.exs` | test | request-response | `test/rindle/live_view_test.exs` | exact |
| `test/install_smoke/generated_app_smoke_test.exs` | test | batch | `test/install_smoke/generated_app_smoke_test.exs` | exact |
| `test/install_smoke/support/generated_app_helper.ex` | utility | batch | `test/install_smoke/support/generated_app_helper.ex` | exact |
| `test/install_smoke/phoenix_tus_truth_parity_test.exs` | test | transform | `test/install_smoke/phoenix_tus_truth_parity_test.exs` | exact |

## Pattern Assignments

### `guides/resumable_uploads.md` (config, request-response)

**Analog:** `guides/resumable_uploads.md`

**Guide structure and contract framing** (`guides/resumable_uploads.md:3-17`):
```markdown
Rindle ships a tus 1.0 upload edge via `Rindle.Upload.TusPlug`. This guide
covers the adopter-owned wiring...

- When to use tus instead of presigned PUT or GCS-native resumable upload
- Mounting `Rindle.Upload.TusPlug` in Phoenix or plain Plug
- Required endpoint and parser setup
- CORS headers for browser clients
```

**Adopter-owned Phoenix wiring** (`guides/resumable_uploads.md:34-57`):
```elixir
forward "/uploads/tus", Rindle.Upload.TusPlug,
  profile: MyApp.VideoProfile,
  secret_key_base:
    Application.compile_env!(:my_app, MyAppWeb.Endpoint)[:secret_key_base]

config :rindle, :tus_profiles, [MyApp.VideoProfile]
```

**Thin LiveView helper seam** (`guides/resumable_uploads.md:123-160`):
```elixir
Rindle.LiveView.allow_tus_upload(socket, :video, MyApp.VideoProfile,
  path: "/uploads/tus",
  secret_key_base: ...,
  accept: ~w(.mp4),
  max_entries: 1
)
```
```javascript
Uploaders.RindleTus = function (entries, onViewError) {
  let upload = new tus.Upload(entry.file, {
    endpoint: entry.meta.endpoint,
    uploadUrl: entry.meta.upload_url,
```

**Honest lifecycle wording** (`guides/resumable_uploads.md:188-206`):
```markdown
- `uploading` / `Uploading...` while the client is sending bytes
- `verifying` / `Verifying...` after the upload reaches `100%`
- `ready` / `Ready` only after `consume_uploaded_entries/3` succeeds
- `error` / `Error` if upload transport or server verification fails
```

Planning implication: keep the guide narrow and executable. Phase 50 should extend the existing helper and completion lane language, not add a second Phoenix abstraction story.

---

### `lib/rindle/live_view.ex` (utility, request-response)

**Analog:** `lib/rindle/live_view.ex`

**Imports and dependency posture** (`lib/rindle/live_view.ex:64-70`):
```elixir
require Logger

alias Phoenix.LiveView.Upload
alias Phoenix.PubSub
alias Rindle.Config
alias Rindle.Domain.MediaUploadSession
alias Rindle.Upload.Broker
```

**Public helper contract** (`lib/rindle/live_view.ex:131-167`):
```elixir
@spec allow_tus_upload(Phoenix.LiveView.Socket.t(), atom(), module(), keyword()) ::
        Phoenix.LiveView.Socket.t()
def allow_tus_upload(socket, name, profile, opts \\ []) do
  path = Keyword.fetch!(opts, :path)
  secret_key_base = Keyword.fetch!(opts, :secret_key_base)
  actor = Keyword.get(opts, :actor)
```

**Core metadata pattern** (`lib/rindle/live_view.ex:228-249`):
```elixir
{:ok, %{session: session, upload_url: upload_url}} ->
  meta = %{
    uploader: "RindleTus",
    endpoint: path,
    upload_url: upload_url,
    session_id: session.id,
    asset_id: session.asset_id
  }
```

**Error handling pattern** (`lib/rindle/live_view.ex:250-255`):
```elixir
{:error, reason} ->
  log_upload_error("tus_upload", reason)
  {:error, %{reason: "upload_unavailable", code: "upload_init_failed"}, socket}
```

**Completion-gate posture** (`lib/rindle/live_view.ex:49-62`):
```elixir
For resumable browser uploads against a mounted `Rindle.Upload.TusPlug`,
use `allow_tus_upload/4` and keep `consume_uploaded_entries/3` as the
completion gate.
```

Planning implication: any Phase 50 edits here should stay additive and thin. Preserve `Keyword.fetch!` required options, `uploader: "RindleTus"`, and LiveView-compatible `{:ok, meta, socket}` / `{:error, ..., socket}` tuples.

---

### `test/rindle/live_view_test.exs` (test, request-response)

**Analog:** `test/rindle/live_view_test.exs`

**Test module setup** (`test/rindle/live_view_test.exs:1-12`):
```elixir
use Rindle.DataCase, async: true
import Mox

Code.ensure_loaded!(Rindle.LiveView)
setup :set_mox_from_context
setup :verify_on_exit!
```

**Helper contract assertions** (`test/rindle/live_view_test.exs:148-179`):
```elixir
assert {:ok, meta, ^updated_socket} = external_fn.(entry, updated_socket)
assert meta.uploader == "RindleTus"
assert meta.endpoint == "/uploads/tus"
assert String.starts_with?(meta.upload_url, "/uploads/tus/")

session = Repo.get!(MediaUploadSession, meta.session_id)
assert session.state == "signed"
assert session.resumable_protocol == "tus"
assert session.session_uri == meta.upload_url
```

**Actor-resolution proof** (`test/rindle/live_view_test.exs:181-208`):
```elixir
actor: fn socket -> socket.assigns.current_user.id end

token = meta.upload_url |> String.split("/") |> List.last()
assert {:ok, payload} = Plug.Crypto.verify(@tus_secret_key_base, @tus_url_salt, token)
assert payload["actor"] == "user-456"
```

**Completion semantics** (`test/rindle/live_view_test.exs:249-289`):
```elixir
results =
  Rindle.LiveView.consume_uploaded_entries(completed_socket, :avatar, fn uploaded_entry,
                                                                         uploaded_meta ->
    {:ok, {uploaded_entry.client_name, uploaded_meta.asset_id}}
  end)

assert session.state == "completed"
assert session.verified_at != nil
assert asset.state == "validating"
```

**Failure posture** (`test/rindle/live_view_test.exs:311-329`):
```elixir
assert [{:error, {:rindle_verify_failed, :storage_object_missing}}] =
         Rindle.LiveView.consume_uploaded_entries(completed_socket, :avatar, fn _, _ ->
           {:ok, :unexpected}
         end)
```

Planning implication: extend this file for helper metadata, actor, and `consume_uploaded_entries/3` truth. Prefer persisted-session assertions over brittle internal-function tests.

---

### `test/install_smoke/generated_app_smoke_test.exs` (test, batch)

**Analog:** `test/install_smoke/generated_app_smoke_test.exs`

**Shared assertion template** (`test/install_smoke/generated_app_smoke_test.exs:3-27`):
```elixir
defmodule Rindle.InstallSmoke.GeneratedAppSmokeAssertions do
  use ExUnit.CaseTemplate

  defp assert_install_source!(report) do
    assert File.dir?(report.generated_app_root)
    assert report.profile_mode in [:image, :video, :tus, :upgrade, :mux, :gcs]
    assert report.install_mode in [:package, :network]
```

**Guide parity guard inside smoke lane** (`test/install_smoke/generated_app_smoke_test.exs:29-47`):
```elixir
defp assert_tus_guide_parity! do
  guide = File.read!("guides/resumable_uploads.md")

  assert guide =~ "plug Plug.Parsers,"
  assert guide =~ "tus-js-client"
  assert guide =~ "sticky-session or single-node"
```

**Generated-app tus proof pattern** (`test/install_smoke/generated_app_smoke_test.exs:177-209`):
```elixir
setup_all do
  report = GeneratedAppHelper.prove_package_install!(:tus)
  on_exit(fn -> GeneratedAppHelper.cleanup(report) end)
  {:ok, report: report}
end

assert report.smoke_exit_code == 0, tus_failure_details(report)
assert report.lifecycle_proved?, tus_failure_details(report)
assert report.tus_previous_uploads >= 1
assert report.tus_ready_variants == ["poster", "web_720p"]
assert_tus_guide_parity!()
```

**Failure diagnostics** (`test/install_smoke/generated_app_smoke_test.exs:49-60`):
```elixir
"""
tus smoke failed
workspace: #{report.generated_app_root}
report: #{report.tus_report_path}
debug_report: #{report.tus_debug_report_path}
phase: #{inspect(report.tus_failure_phase)}
"""
```

Planning implication: Phase 50 should deepen the existing `:tus` lane, not add a second generated-app lane. Keep the report-driven assertions and failure printout pattern.

---

### `test/install_smoke/support/generated_app_helper.ex` (utility, batch)

**Analog:** `test/install_smoke/support/generated_app_helper.ex`

**Top-level orchestration** (`test/install_smoke/support/generated_app_helper.ex:19-57`):
```elixir
def prove_package_install!(profile_mode \\ :image)
    when profile_mode in [:image, :video, :tus, :mux, :gcs] do
  ...
  generate_phoenix_app!(workspace_root, generated_app_root)

  patch_generated_app!(
    generated_app_root,
    app_name,
    app_module,
    package_root,
    network_version,
    profile_mode
  )
```

**Machine-readable report shape** (`test/install_smoke/support/generated_app_helper.ex:94-143`):
```elixir
report = %{
  ...
  tus_upload_url: tus_report["upload_url"],
  tus_previous_uploads: tus_report["previous_uploads"],
  tus_byte_size: tus_report["byte_size"],
  tus_content_type: tus_report["content_type"],
  tus_ready_variants: tus_report["ready_variants"] || [],
  tus_report_path: tus_report_path,
  tus_debug_report_path: tus_debug_report_path,
```

**Generated-app patch layering** (`test/install_smoke/support/generated_app_helper.ex:334-353`):
```elixir
patch_generated_app!(...) do
  patch_mix_exs!(...)
  patch_test_config!(...)
  patch_test_helper!(...)
  patch_runtime_config!(...)
  patch_application!(...)
  patch_router!(...)
  write_profile!(...)
  write_host_migration!(...)
  write_smoke_test!(...)
```

**Tus-specific router/config patch** (`test/install_smoke/support/generated_app_helper.ex:458-507`):
```elixir
config :rindle, :tus_profiles, [#{Macro.camelize(app_name)}.VideoProfile]

forward "/uploads/tus", Rindle.Upload.TusPlug,
  profile: #{app_module}.VideoProfile,
  secret_key_base:
    Application.compile_env!(:#{app_name}, #{app_module}Web.Endpoint)[:secret_key_base]
```

**Proof artifact writes inside generated app** (`test/install_smoke/support/generated_app_helper.ex:1453-1463`):
```elixir
write_tus_report!(%{
  upload_url: proof["upload_url"],
  previous_uploads: proof["previous_uploads"],
  byte_size: promoted_asset.byte_size,
  content_type: promoted_asset.content_type,
  ready_variants: Enum.map(ready_variants, & &1.name),
```

**Node proof + report merge pattern** (`test/install_smoke/support/generated_app_helper.ex:2464-2528`):
```elixir
merge_tus_report!(%{
  endpoint: endpoint,
  report_path: Path.expand("../tmp/install_smoke_tus_report.json", __DIR__),
  debug_report_path: debug_report_path
})

{output, exit_code} =
  System.cmd("node", [script_path, endpoint, fixture_path, "resume", debug_report_path],
    stderr_to_stdout: true
  )

defp merge_tus_report!(attrs) do
  attrs = Map.merge(read_tus_report!(), attrs)
  write_tus_report!(attrs)
end
```

Planning implication: preserve the helper as the single generated-app proof harness. Any Phoenix-specific proof additions should flow through report fields and patch hooks already used by `:tus`.

---

### `test/install_smoke/phoenix_tus_truth_parity_test.exs` (test, transform)

**Analog:** `test/install_smoke/phoenix_tus_truth_parity_test.exs`

**File-loading setup** (`test/install_smoke/phoenix_tus_truth_parity_test.exs:4-13`):
```elixir
@guide_path Path.expand("../../guides/resumable_uploads.md", __DIR__)
@live_view_path Path.expand("../../lib/rindle/live_view.ex", __DIR__)
@project_path Path.expand("../../.planning/PROJECT.md", __DIR__)
@requirements_path Path.expand("../../.planning/REQUIREMENTS.md", __DIR__)
@roadmap_path Path.expand("../../.planning/ROADMAP.md", __DIR__)
```

**Positive Phoenix seam assertions** (`test/install_smoke/phoenix_tus_truth_parity_test.exs:15-33`):
```elixir
assert guide =~ "supported thin helper seam"
assert guide =~ ~s(uploader: "RindleTus")
assert guide =~ "uploadUrl: entry.meta.upload_url"
assert guide =~ "findPreviousUploads()"
assert guide =~ "resumeFromPreviousUpload(previousUploads[0])"
assert guide =~ "consume_uploaded_entries/3"
assert guide =~ "verify_completion/2"
```

**Negative drift guards** (`test/install_smoke/phoenix_tus_truth_parity_test.exs:30-32, 41-46`):
```elixir
refute live_view =~ "plug Plug.Parsers"
refute live_view =~ "config :cors_plug"

refute docs =~ "LiveView tus uploader component"
assert docs =~ "standalone tus JS client package"
```

**Historical redirect pattern** (`test/install_smoke/phoenix_tus_truth_parity_test.exs:49-56`):
```elixir
assert doc =~ "> Historical v1.8 note: this file uses pre-v1.9 shorthand."
assert doc =~ ".planning/PROJECT.md"
assert doc =~ "guides/resumable_uploads.md"
```

Planning implication: keep this as a literal-string drift gate. Extend it with Phoenix proof vocabulary and report-field expectations rather than broad snapshots or regex-heavy prose tests.

## Shared Patterns

### Literal docs parity
**Source:** `test/install_smoke/docs_parity_test.exs:14-24`, `test/install_smoke/docs_parity_test.exs:26-63`
**Apply to:** `guides/resumable_uploads.md`, `test/install_smoke/phoenix_tus_truth_parity_test.exs`
```elixir
setup_all do
  {:ok,
   %{
     readme: File.read!(@readme_path),
     guide: File.read!(@guide_path)
   }}
end

for doc <- [readme, guide] do
  assert doc =~ "Rindle.verify_completion"
end
```

Use explicit `File.read!` fixtures plus literal `assert` and `refute` checks. This repo freezes public wording byte-for-byte instead of using fuzzy doc checks.

### Thin LiveView external-upload seam
**Source:** `lib/rindle/live_view.ex:116-167`, `test/rindle/live_view_direct_upload_test.exs:55-107`
**Apply to:** `lib/rindle/live_view.ex`, `test/rindle/live_view_test.exs`
```elixir
merged_opts =
  opts
  |> Keyword.delete(:cors_origin)
  |> Keyword.merge(external: external_fn)

Upload.allow_upload(socket, name, merged_opts)
```
```elixir
assert {:ok, meta, ^updated_socket} = external_fn.(entry, updated_socket)
assert meta == %{
         uploader: "UpChunk",
         endpoint: "https://mux.example/upload",
         asset_id: meta.asset_id
       }
```

The library uses tiny helper façades that feed LiveView `:external` metadata, then proves the public metadata shape in tests.

### Public completion lane
**Source:** `lib/rindle.ex:96-107`, `lib/rindle.ex:125-144`, `test/rindle/live_view_test.exs:249-289`
**Apply to:** guide, helper tests, generated-app proof
```elixir
def initiate_tus_upload(profile, opts \\ []) do
  TusPlug.create_upload(profile, opts)
end

def verify_completion(session_id, opts \\ []) do
  Broker.verify_completion(session_id, opts)
end
```

Phase 50 proof should keep tus transport initiation and completion verification separate, with `consume_uploaded_entries/3` converging into `verify_completion/2`.

### Machine-readable install-smoke artifacts
**Source:** `test/install_smoke/support/generated_app_helper.ex:94-143`, `test/install_smoke/support/generated_app_helper.ex:2464-2528`, `test/install_smoke/generated_app_smoke_test.exs:194-208`
**Apply to:** generated-app helper and smoke tests
```elixir
tus_report_path = Path.join(generated_app_root, "tmp/install_smoke_tus_report.json")
tus_debug_report_path = Path.join(generated_app_root, "tmp/install_smoke_tus_debug_report.json")

defp merge_tus_report!(attrs) do
  attrs = Map.merge(read_tus_report!(), attrs)
  write_tus_report!(attrs)
end
```

Keep report fields additive and auditable. The smoke layer should assert on report data, not on generated source snapshots.

## No Analog Found

None.

## Metadata

**Analog search scope:** `guides/`, `lib/`, `test/rindle/`, `test/install_smoke/`, `.planning/`
**Files scanned:** 215
**Pattern extraction date:** 2026-05-25
