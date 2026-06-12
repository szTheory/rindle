# Phase 89: Console Read Surfaces - Pattern Map

**Mapped:** 2026-06-12  
**Files analyzed:** 24 new/modified files or file groups  
**Analogs found:** 22 / 24

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/rindle/admin/router.ex` | route/config | request-response | `lib/rindle/live_view.ex` + `guides/admin_console_architecture.md` | partial |
| `lib/rindle/admin/queries.ex` | service/query | CRUD/read-model | `lib/rindle/ops/runtime_status.ex` | exact |
| `lib/rindle/admin/components.ex` | component | transform/render | `brandbook/src/admin-css-build.mjs` + `examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex` | role-match |
| `lib/rindle/admin/live/home_live.ex` | component/LiveView | request-response + pub-sub | `examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex` | role-match |
| `lib/rindle/admin/live/assets_live.ex` | component/LiveView | request-response + pub-sub | `examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex` | role-match |
| `lib/rindle/admin/live/upload_sessions_live.ex` | component/LiveView | request-response + pub-sub | `examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex` + `lib/rindle/live_view.ex` | role-match |
| `lib/rindle/admin/live/variants_jobs_live.ex` | component/LiveView | request-response + pub-sub | `examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex` + `lib/rindle/live_view.ex` | role-match |
| `lib/rindle/admin/live/runtime_doctor_live.ex` | component/LiveView | request-response | `examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex` | role-match |
| `lib/rindle/admin/live/actions_live.ex` | component/LiveView | request-response | `examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex` | role-match |
| `priv/static/rindle_admin/rindle-admin.css` | static asset | file-I/O | `brandbook/tokens/rindle-admin.css` via `brandbook/src/admin-css-build.mjs` | exact |
| `priv/static/rindle_admin/rindle-admin.js` | static asset | event-driven | `brandbook/src/admin-gallery.mjs` | role-match |
| `priv/static/rindle_admin/logo.svg` | static asset | file-I/O | `brandbook/assets/logo/rindle-logo.svg` | exact |
| `priv/static/rindle_admin/favicon.svg` | static asset | file-I/O | `brandbook/assets/logo/favicon.svg` | exact |
| `mix.exs` | config | file-I/O/package | `mix.exs` package config | exact |
| `lib/rindle/upload/broker.ex` | service | CRUD + pub-sub | `lib/rindle/workers/process_variant.ex` | data-flow-match |
| `lib/rindle/upload/tus_plug.ex` | plug/service | request-response + pub-sub | `lib/rindle/workers/process_variant.ex` | data-flow-match |
| `examples/adoption_demo/lib/adoption_demo_web/router.ex` | route | request-response | same file | exact |
| `test/rindle/admin/router_test.exs` | test | request-response | `test/rindle/live_view_test.exs` | role-match |
| `test/rindle/admin/queries_test.exs` | test | CRUD/read-model | `test/rindle/ops/runtime_status_test.exs` | exact |
| `test/rindle/admin/live/*_test.exs` | test | request-response + pub-sub | `test/rindle/live_view_test.exs` + `test/rindle/workers/ingest_provider_webhook_test.exs` | role-match |
| `test/rindle/admin/optional_dependency_test.exs` | test | build/config | `test/rindle/streaming/provider/mux/optional_dep_test.exs` | role-match |
| `test/install_smoke/package_metadata_test.exs` | test | file-I/O/package | same file | exact |
| `test/brandbook/admin_design_system_validation_test.exs` | test | transform/file-I/O | same file | exact |
| `test/rindle/api_surface_boundary_test.exs` | test | docs/API boundary | same file | exact |

## Pattern Assignments

### `lib/rindle/admin/router.ex` (route/config, request-response)

**Analog:** `lib/rindle/live_view.ex`; architecture contract from `guides/admin_console_architecture.md`

**Optional dependency gate** (`lib/rindle/live_view.ex` lines 1-2, 64-70):
```elixir
if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Rindle.LiveView do
    require Logger

    alias Phoenix.LiveView.Upload
    alias Phoenix.PubSub
    alias Rindle.Config
    alias Rindle.Domain.MediaUploadSession
    alias Rindle.Upload.Broker
```

Apply the same top-level guard before any `Phoenix.Router`, `Phoenix.LiveView.Router`, `Phoenix.Component`, or `Phoenix.LiveView` alias/import expands.

**Mount option contract** (`guides/admin_console_architecture.md` lines 26-41, 57-66, 70-79):
```elixir
scope "/admin", MyAppWeb do
  pipe_through [:browser, :require_admin]

  rindle_admin "/rindle",
    on_mount: [MyAppWeb.AdminLiveAuth],
    as: :rindle_admin,
    home_path: "/admin",
    live_socket_path: "/live",
    transport: "websocket",
    csp_nonce_assign_key: %{
      img: :img_csp_nonce,
      style: :style_csp_nonce,
      script: :script_csp_nonce
    }
end
```

**Static asset route shape** (`guides/admin_console_architecture.md` lines 93-98):
```elixir
plug Plug.Static,
  at: "/rindle-admin/assets",
  from: {:rindle, "priv/static/rindle_admin"},
  only: ~w(rindle-admin.css rindle-admin.js logo.svg favicon.svg)
```

Router tests should assert production unsafe mounts are refused by default and the dev/test escape hatch is not a production bypass.

---

### `lib/rindle/admin/queries.ex` (service/query, CRUD/read-model)

**Analog:** `lib/rindle/ops/runtime_status.ex`

**Imports and domain aliases** (`lib/rindle/ops/runtime_status.ex` lines 1-10):
```elixir
defmodule Rindle.Ops.RuntimeStatus do
  @moduledoc false

  import Ecto.Query

  alias Oban.Job
  alias Rindle.Config
  alias Rindle.Domain.{MediaAsset, MediaProviderAsset, MediaUploadSession, MediaVariant}
  alias Rindle.Workers.ProcessVariant
```

**Read-model composition** (`lib/rindle/ops/runtime_status.ex` lines 36-58):
```elixir
def runtime_status(opts \\ []) do
  with {:ok, filters} <- normalize_filters(opts) do
    now = DateTime.utc_now()
    cutoff = older_than_cutoff(now, filters.older_than)

    runtime_checks = runtime_checks_report(filters, cutoff, now)
    variants = variant_report(filters, cutoff, now)
    upload_sessions = upload_session_report(filters, cutoff, now)
    provider_assets = provider_assets_report(filters, now)

    {:ok,
     %{
       generated_at: now,
       filters: filters,
       runtime_checks: runtime_checks,
       assets: asset_report(filters),
       variants: variants,
       upload_sessions: upload_sessions,
       provider_assets: provider_assets,
       recommendations:
         build_recommendations(runtime_checks, variants, upload_sessions, provider_assets)
     }}
```

**Ecto query pattern** (`lib/rindle/ops/runtime_status.ex` lines 119-141):
```elixir
defp upload_session_report(filters, cutoff, now) do
  findings =
    upload_session_finding_rows_query(filters, cutoff)
    |> Config.repo().all()
    |> Enum.map(&upload_session_sample(&1, now))
    |> summarize_state_findings(filters.limit)

  counts =
    from(s in MediaUploadSession,
      join: a in MediaAsset,
      on: a.id == s.asset_id,
      select: {s.state, count(s.id)}
    )
    |> maybe_filter_profile(:upload_session, filters.profile)
    |> group_by([s, _a], s.state)
    |> Config.repo().all()
    |> count_map()
```

**Redaction pattern** (`lib/rindle/ops/runtime_status.ex` lines 258-275):
```elixir
%{
  class: :provider_stuck,
  age_seconds: age,
  sample: %{
    asset_id: row.asset_id,
    provider_asset_id: MediaProviderAsset.redact_id(row.provider_asset_id),
    profile: row.profile,
    provider: row.provider_name,
    state: row.state,
    updated_at: row.updated_at,
    last_event_at: row.last_event_at,
    last_sync_error: row.last_sync_error,
    reason: "row stuck in #{row.state} for #{age}s"
  }
}
```

**Validation/error pattern** (`lib/rindle/ops/runtime_status.ex` lines 671-696, 726-750):
```elixir
defp normalize_filters(opts) when is_list(opts) do
  opts
  |> Enum.into(%{})
  |> normalize_filters()
end

defp validate_filter_keys(opts) do
  case Map.keys(opts) -- @allowed_filter_keys do
    [] -> :ok
    unknown -> {:error, {:unknown_filters, unknown}}
  end
end
```

Keep admin queries internal to `Rindle.Admin.Queries`; do not add facade helpers to `lib/rindle.ex`.

---

### `lib/rindle/admin/components.ex` and `lib/rindle/admin/live/*.ex` (components/LiveViews, request-response + pub-sub)

**Analog:** `examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex`; CSS contract from `brandbook/src/admin-css-build.mjs`

**LiveView module shape** (`examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex` lines 1-22):
```elixir
defmodule AdoptionDemoWeb.OpsLive do
  use AdoptionDemoWeb, :live_view

  alias AdoptionDemo.{Accounts, Media, RindleProfile}

  @impl true
  def mount(_params, _session, socket) do
    batch_members =
      Accounts.list_members()
      |> Enum.filter(&(&1.role == "student"))
      |> Enum.take(2)

    {:ok,
     assign(socket,
       page_title: "Ops surfaces",
       doctor_output: nil,
       runtime_output: nil,
       batch_preview: nil,
       batch_result: nil,
       batch_members: batch_members
     )}
  end
```

For shipped admin modules, replace `use AdoptionDemoWeb, :live_view` with guarded package-owned `use Phoenix.LiveView`/`use Phoenix.Component` and render through `Rindle.Admin.Components`.

**Render and event pattern** (`examples/adoption_demo/lib/adoption_demo_web/live/ops_live.ex` lines 24-41, 66-83):
```elixir
@impl true
def render(assigns) do
  ~H"""
  <Layouts.app flash={@flash} page_title={@page_title}>
    <h1 class="text-2xl font-semibold">Operator surfaces</h1>
    ...
    <pre :if={@doctor_output} id="doctor-output" ...>{@doctor_output}</pre>
    <pre :if={@runtime_output} id="runtime-status-output" ...>{@runtime_output}</pre>
  </Layouts.app>
  """
end

@impl true
def handle_event("run_doctor", _params, socket) do
  report =
    Mix.Tasks.Rindle.Doctor.run_checks([to_string(RindleProfile)], exit_on_failure?: false)

  output = "doctor_success=#{report.success?}\n" <> inspect(report, pretty: true)
  {:noreply, assign(socket, :doctor_output, output)}
end
```

Phase 89 must keep these surfaces read-only. `ActionsLive` may list future operations but must not wire destructive execution.

**PubSub topic helper and refresh trigger source** (`lib/rindle/live_view.ex` lines 169-187, 339-347):
```elixir
@spec subscribe(subscription_scope(), term()) :: String.t()
def subscribe(:variant, id), do: subscribe_topic(topic_for(:variant, id))
def subscribe(:asset, id), do: subscribe_topic(topic_for(:asset, id))
def subscribe(:provider_asset, id), do: subscribe_topic(topic_for(:provider_asset, id))
def subscribe(:upload_session, id), do: subscribe_topic(topic_for(:upload_session, id))

defp subscribe_topic(topic) do
  :ok = PubSub.subscribe(pubsub_server(), topic)
  topic
end

defp topic_for(:variant, id), do: "rindle:variant:#{id}"
defp topic_for(:asset, id), do: "rindle:asset:#{id}"
defp topic_for(:provider_asset, id), do: "rindle:provider_asset:#{id}"
defp topic_for(:upload_session, id), do: "rindle:upload_session:#{id}"
```

LiveViews should subscribe only when `connected?(socket)` and refresh via `Rindle.Admin.Queries` in `handle_info/2`; do not trust PubSub payloads as the full data source.

**Generated CSS selectors to consume** (`brandbook/src/admin-css-build.mjs` lines 35-40, 90-118):
```javascript
exact(THEMES, ['light', 'dark', 'auto'], 'THEMES');
exact(SURFACES, ['Home/Status', 'Assets', 'Upload Sessions', 'Variants/Jobs', 'Runtime/Doctor', 'Actions'], 'SURFACES');
exact(STATUS_STATES, ['ready', 'processing', 'warning', 'danger', 'quarantine', 'info'], 'STATUS_STATES');
exact(COMPONENTS, ['shell', 'nav', 'table', 'status-chip', 'button', 'theme-picker', 'confirm-dialog', 'drawer', 'toast', 'empty-state', 'skeleton'], 'COMPONENTS');

.rindle-admin-shell,
.rindle-admin-shell * {
  box-sizing: border-box;
}

.rindle-admin-shell {
  min-height: 100%;
  display: grid;
  grid-template-columns: minmax(220px, 260px) minmax(0, 1fr);
```

**UI/security rules** (`guides/ui_principles.md` lines 8-18, 67-75):
```markdown
- `brandbook/tokens/tokens.json` is the source of truth.
- The shipped console uses `rindle-admin` vanilla CSS, BEM selectors, and generated
  `--rindle-` custom properties.
- The console must not depend on host Tailwind, daisyUI, esbuild, shadcn, Radix,
  Tailwind UI, daisyUI registry components, or any third-party UI registry.
- Status indicators use labels/icons plus token color pairs; never rely on color alone.
- Host apps own auth and `:on_mount`; the console must not weaken that boundary.
- Admin reads stay in `Rindle.Admin.Queries`; do not add convenience reads to the public
  `Rindle` facade.
```

---

### `priv/static/rindle_admin/*` and `mix.exs` (static assets/config, file-I/O)

**Analogs:** `brandbook/src/admin-css-build.mjs`, `guides/admin_console_architecture.md`, existing `mix.exs`

**Generated asset source** (`brandbook/src/admin-css-build.mjs` lines 1-21, 48-49):
```javascript
// Generates rindle-admin.css from tokens.json and verifies the component contract.
// Run: node admin-css-build.mjs

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const tokensPath = join(tokensDir, 'tokens.json');
const adminCssPath = join(tokensDir, 'rindle-admin.css');
const T = JSON.parse(readFileSync(tokensPath, 'utf8'));

let css = `/* generated by brandbook/src/admin-css-build.mjs from tokens.json - do not edit by hand */
```

Do not hand-edit generated CSS. Copy/move the generated artifact into `priv/static/rindle_admin` as part of the package-serving work.

**Current package file list** (`mix.exs` lines 237-244):
```elixir
defp package do
  [
    licenses: ["MIT"],
    links: %{
      "GitHub" => @source_url
    },
    files: ~w(lib priv/repo/migrations mix.exs README.md RUNNING.md CHANGELOG.md LICENSE guides)
  ]
end
```

Planner should update this to include the admin static asset path without widening package contents unnecessarily.

---

### `lib/rindle/upload/broker.ex` and `lib/rindle/upload/tus_plug.ex` (service/plug, CRUD + pub-sub)

**Analog:** `lib/rindle/workers/process_variant.ex`; provider broadcast precedent from `lib/rindle/workers/ingest_provider_webhook.ex`

**Broadcast helper pattern** (`lib/rindle/workers/process_variant.ex` lines 516-533):
```elixir
defp broadcast_progress(asset, variant, progress, state) do
  ensure_pubsub_started()

  payload = %{
    asset_id: asset.id,
    progress: progress,
    variant_id: variant.id,
    variant_name: variant.name,
    state: state
  }

  event_type = public_event_type(progress, state)

  for topic <- ["rindle:variant:#{variant.id}", "rindle:asset:#{asset.id}"] do
    :ok = PubSub.broadcast(pubsub_server(), topic, {:rindle_event, event_type, payload})
  end

  :ok
end
```

**Provider payload redaction precedent** (`lib/rindle/workers/ingest_provider_webhook.ex` lines 389-407):
```elixir
defp broadcast(row, event_type) do
  payload = %{
    asset_id: row.asset_id,
    playback_ids: row.playback_ids || [],
    profile: row.profile,
    provider: :mux,
    state: row.state
    # NB: provider_asset_id is FORBIDDEN here (D-32).
  }

  for topic <- [
        "rindle:provider_asset:#{row.asset_id}",
        "rindle:asset:#{row.asset_id}"
      ] do
    :ok = PubSub.broadcast(pubsub_server(), topic, {:rindle_event, event_type, payload})
  end
```

Upload-session broadcasts should use `"rindle:upload_session:#{session.id}"` and `"rindle:asset:#{session.asset_id}"`, omit `session_uri`, and use event names matching lifecycle transitions.

**Sensitive upload-session field** (`lib/rindle/domain/media_upload_session.ex` lines 48-67, 102-117):
```elixir
schema "media_upload_sessions" do
  field :state, :string, default: "initialized"
  field :upload_key, :string
  field :upload_strategy, :string, default: "presigned_put"
  field :session_uri, :string
  field :session_uri_expires_at, :utc_datetime_usec
  ...
end

def redact_session_uri(nil), do: nil
def redact_session_uri(session_uri) when is_binary(session_uri), do: "[REDACTED]"
def redact_session_uri(_session_uri), do: "[REDACTED]"
```

---

### Admin tests (router/query/live/optional/package/API boundary)

**Query test analog:** `test/rindle/ops/runtime_status_test.exs`

**Read-model fixture pattern** (`test/rindle/ops/runtime_status_test.exs` lines 1-8, 25-54):
```elixir
defmodule Rindle.Ops.RuntimeStatusTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo

  alias Rindle.Domain.{MediaAsset, MediaProviderAsset, MediaUploadSession, MediaVariant}
  alias Rindle.Ops.RuntimeStatus
  alias Rindle.Workers.ProcessVariant

  test "classifies failed, cancelled, stale, missing, and queue-starved variants" do
    failed_asset = insert_asset(%{profile: to_string(StatusImageProfile)})
    ...
    assert {:ok, report} = RuntimeStatus.runtime_status(limit: 2)
    assert :failed_work in classes
  end
```

**Redaction assertion pattern** (`test/rindle/ops/runtime_status_test.exs` lines 232-251):
```elixir
test "provider_stuck filter true surfaces a row past the 7200s default threshold" do
  asset = insert_asset(%{profile: to_string(StatusVideoProfile)})

  _row =
    insert_provider_asset(asset, %{
      state: "processing",
      provider_asset_id: "test-asset-id-aaaa1111bbbb2222cccc3333dddd",
      updated_at: age_ago(7300)
    })

  assert {:ok, report} = RuntimeStatus.runtime_status(provider_stuck: true)
  [sample] = finding.samples
  assert sample.provider_asset_id == "...dddd"
end
```

**PubSub assertion pattern** (`test/rindle/workers/ingest_provider_webhook_test.exs` lines 151-183):
```elixir
PubSub.subscribe(Rindle.PubSub, "rindle:provider_asset:#{ctx.asset.id}")
PubSub.subscribe(Rindle.PubSub, "rindle:asset:#{ctx.asset.id}")

assert :ok = perform_job(IngestProviderWebhook, args)

assert_receive {:rindle_event, :provider_asset_ready, payload1}
assert_receive {:rindle_event, :provider_asset_ready, payload2}

for payload <- [payload1, payload2] do
  assert payload.asset_id == ctx.asset.id
  refute Map.has_key?(payload, :provider_asset_id)
end
```

**Optional dependency smoke-test shape** (`test/rindle/streaming/provider/mux/optional_dep_test.exs` lines 5-24):
```elixir
# ... adapter module is wrapped in
# `if Code.ensure_loaded?(Mux.Video.Assets) do ... end` so it is present in
# tests but absent for adopters who do not opt in.

test "Rindle.Streaming.Provider.Mux is loaded with all required Phase 33 callbacks (test env)" do
  assert Code.ensure_loaded?(Rindle.Streaming.Provider.Mux),
         "Rindle.Streaming.Provider.Mux module must compile when :mux is loaded"

  for {fun, arity} <- [
        {:capabilities, 0},
        {:create_asset, 3}
      ] do
    assert function_exported?(Rindle.Streaming.Provider.Mux, fun, arity)
  end
end
```

ADMIN-06 also needs a real `mix compile --no-optional-deps --warnings-as-errors` proof, not just this loaded-with-deps smoke shape.

**Package inclusion test pattern** (`test/install_smoke/package_metadata_test.exs` lines 13-20, 48-64, 254-281):
```elixir
@required_paths [
  "mix.exs",
  "README.md",
  "CHANGELOG.md",
  "LICENSE",
  "guides/getting_started.md",
  "guides/release_publish.md"
]

for rel_path <- @required_paths do
  assert metadata =~ ~s(<<"#{rel_path}">>)
  assert File.exists?(Path.join(package_root, rel_path))
end

{output, 0} =
  System.cmd("mix", ["hex.build", "--unpack", "--output", package_root],
    cd: @repo_root,
    env: [{"MIX_ENV", "dev"}],
    stderr_to_stdout: true
  )
```

Add `priv/static/rindle_admin/rindle-admin.css`, JS, logo, and favicon to this required-path assertion after package config is updated.

**Phase 88 validation assertion to revise** (`test/brandbook/admin_design_system_validation_test.exs` lines 178-212):
```elixir
for expected <- [
      "brandbook/tokens/rindle-admin.css",
      "priv/static/rindle_admin",
      "Rindle.Admin.Router.rindle_admin/2",
      "Rindle.Admin.Queries",
      "Tailwind",
      "daisyUI",
      "esbuild"
    ] do
  assert guide =~ expected
end

refute read!("mix.exs") =~ "priv/static/rindle_admin"
```

Phase 89 should replace the final `refute` with a positive package-boundary assertion.

**API/docs boundary pattern** (`test/rindle/api_surface_boundary_test.exs` lines 4-19, 61-70, 267-276):
```elixir
@public_modules [
  Rindle,
  Rindle.Error,
  ...
  Rindle.LiveView,
  Rindle.HTML,
]

@ops_hidden_modules [
  Rindle.Ops.LifecycleRepair,
  Rindle.Ops.MetadataBackfill,
  Rindle.Ops.RuntimeStatus,
  Rindle.Ops.UploadMaintenance,
]

defp fetch_docs!(module) do
  assert Code.ensure_loaded?(module), "#{inspect(module)} must be loadable for boundary checks"

  case Code.fetch_docs(module) do
    {:error, reason} -> flunk("expected compiled docs for #{inspect(module)}, got #{inspect(reason)}")
    docs -> docs
  end
end
```

Add `Rindle.Admin.Router` as the only new public admin module. Keep query/components/live modules hidden unless the implementation deliberately documents otherwise.

## Shared Patterns

### Optional Phoenix/LiveView Boundary
**Source:** `lib/rindle/live_view.ex` lines 1-2; `guides/admin_console_architecture.md` lines 113-127  
**Apply to:** `lib/rindle/admin/router.ex`, `lib/rindle/admin/components.ex`, all `lib/rindle/admin/live/*.ex`, and LiveView-specific tests.  
Every Phoenix/LiveView-specific module must be defined inside a top-level `if Code.ensure_loaded?(Phoenix.LiveView) do ... end` guard.

### Host Auth Boundary
**Source:** `guides/admin_console_architecture.md` lines 47-66  
**Apply to:** Router macro and router tests.  
Host owns browser/auth pipeline and `:on_mount`; production mounts without an explicit auth guard/acknowledgement must be refused by default.

### Query Isolation
**Source:** `guides/admin_console_architecture.md` lines 129-136; `test/rindle/api_surface_boundary_test.exs` lines 61-70  
**Apply to:** `Rindle.Admin.Queries`, LiveViews, API boundary tests.  
Read models stay under `Rindle.Admin.Queries`; do not add admin convenience reads to `lib/rindle.ex`.

### Sensitive Data Redaction
**Source:** `lib/rindle/domain/media_upload_session.ex` lines 102-117; `lib/rindle/domain/media_provider_asset.ex` lines 83-100  
**Apply to:** Queries, LiveViews, PubSub payloads, tests.  
Never expose raw `session_uri` or raw `provider_asset_id`; use redacted values or omit fields.

### PubSub Shape
**Source:** `lib/rindle/live_view.ex` lines 344-347; `lib/rindle/workers/process_variant.ex` lines 516-533; `lib/rindle/workers/ingest_provider_webhook.ex` lines 389-407  
**Apply to:** LiveViews and upload-session lifecycle updates.  
Use existing `Rindle.PubSub`, existing topic grammar, and `{:rindle_event, event_type, payload}` messages. LiveViews refresh through queries.

### Package Asset Inclusion
**Source:** `mix.exs` lines 237-244; `test/install_smoke/package_metadata_test.exs` lines 48-64 and 254-281  
**Apply to:** `priv/static/rindle_admin/*`, `mix.exs`, package tests.  
Hex package inclusion must be asserted from an unpacked package, not inferred from local file presence.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `lib/rindle/admin/router.ex` | route/config | request-response | No existing package-owned Phoenix router macro exists; use `Rindle.LiveView` guard plus architecture guide and LiveDashboard/Oban prior-art from research. |
| `priv/static/rindle_admin/rindle-admin.js` | static asset | event-driven | No shipped package admin JS exists yet; copy only minimal theme/navigation behavior from `brandbook/src/admin-gallery.mjs` if needed. |

## Metadata

**Analog search scope:** `lib/`, `test/`, `examples/adoption_demo/`, `guides/`, `brandbook/`, `mix.exs`  
**Files scanned:** 200+ via `rg --files` and targeted grep  
**Project instructions read:** `AGENTS.md`, `guides/ui_principles.md`, `.codex/skills/gsd-milestone-next-step/SKILL.md`  
**Pattern extraction date:** 2026-06-12
