# Phase 26: Delivery Surface - Pattern Map

**Mapped:** 2026-05-05
**Files analyzed:** 8
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/rindle/delivery.ex` | service | request-response | `lib/rindle/delivery.ex` | exact |
| `lib/rindle/delivery/local_plug.ex` | middleware | file-I/O | `lib/rindle/html.ex` + `lib/rindle/live_view.ex` + `lib/rindle/storage/local.ex` | partial |
| `test/rindle/delivery_test.exs` | test | request-response | `test/rindle/delivery_test.exs` | exact |
| `test/rindle/contracts/telemetry_contract_test.exs` | test | event-driven | `test/rindle/contracts/telemetry_contract_test.exs` | exact |
| `test/rindle/delivery/local_plug_test.exs` | test | file-I/O | `test/rindle/html_test.exs` + `test/rindle/live_view_test.exs` | role-match |

## Pattern Assignments

### `lib/rindle/delivery.ex` (service, request-response)

**Analog:** `lib/rindle/delivery.ex`

**Public additive API pattern** ([lib/rindle/delivery.ex](/Users/jon/projects/rindle/lib/rindle/delivery.ex:14)):
```elixir
@doc """
Returns a deliverable URL for an asset's storage key.
"""
@spec url(module(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
def url(profile, key, opts \\ []) do
  mode = delivery_mode(profile)
  adapter = profile.storage_adapter()
  subject = %{profile: profile, key: key, mode: mode}

  with :ok <- authorize_delivery(profile, :deliver, subject, opts),
       :ok <- require_delivery_support(adapter, mode),
       {:ok, url} <- resolve_url(adapter, key, mode, opts, signed_url_ttl_seconds(profile)) do
    :telemetry.execute(...)
    {:ok, url}
  end
end
```

Copy this shape for `streaming_url/3`: keep it additive, thin, and return tuples. Do not push policy into adapters.

**Authorization + TTL + capability gate pattern** ([lib/rindle/delivery.ex](/Users/jon/projects/rindle/lib/rindle/delivery.ex:169)):
```elixir
defp authorize_delivery(profile, action, subject, opts) do
  case delivery_authorizer(profile) do
    nil -> :ok
    authorizer ->
      actor = Keyword.get(opts, :actor)
      case authorizer.authorize(actor, action, subject) do
        :ok -> :ok
        {:error, reason} -> {:error, reason}
      end
  end
end

defp require_delivery_support(_adapter, :public), do: :ok
defp require_delivery_support(adapter, :private),
  do: Capabilities.require_delivery(adapter, :signed_url)

defp resolve_url(adapter, key, :private, opts, ttl) do
  adapter.url(key, Keyword.put_new(opts, :expires_in, ttl))
end
```

Phase 26 should preserve all three behaviors for `streaming_url/3`:
- same `:actor` pass-through
- same `{:error, reason}` tuples from authorizer
- same `Keyword.put_new(opts, :expires_in, ttl)` override semantics

**Telemetry emission pattern** ([lib/rindle/delivery.ex](/Users/jon/projects/rindle/lib/rindle/delivery.ex:105)):
```elixir
:telemetry.execute(
  [:rindle, :delivery, :signed],
  %{system_time: System.system_time()},
  %{profile: profile, adapter: adapter, mode: mode}
)
```

New delivery events should follow this exact convention: event emitted only on success, numeric measurements, and metadata naming anchored on `profile`/`adapter`.

### `lib/rindle/delivery/local_plug.ex` (middleware, file-I/O)

**Analogs:** `lib/rindle/html.ex`, `lib/rindle/live_view.ex`, `lib/rindle/storage/local.ex`

There is no existing `Plug` module in `lib/`, so `LocalPlug` is a new seam. The closest repo-wide style is:
- thin public surface with explicit docs from `Rindle.HTML` ([lib/rindle/html.ex](/Users/jon/projects/rindle/lib/rindle/html.ex:3))
- thin integration wrapper around lower-level Rindle APIs from `Rindle.LiveView` ([lib/rindle/live_view.ex](/Users/jon/projects/rindle/lib/rindle/live_view.ex:47))
- local filesystem resolution through `Rindle.Storage.Local` ([lib/rindle/storage/local.ex](/Users/jon/projects/rindle/lib/rindle/storage/local.ex:71))

**Thin wrapper philosophy** ([lib/rindle/html.ex](/Users/jon/projects/rindle/lib/rindle/html.ex:3)):
```elixir
@moduledoc """
Phoenix template helpers for responsive media markup.

The helper is intentionally thin: callers choose the explicit variant order,
and the helper delegates delivery URL resolution to Rindle.Delivery.
"""
```

Mirror this in `LocalPlug`: loud `@moduledoc`, explicit dev-only caveat, and delegate path/URL policy to `Rindle.Delivery` and `Rindle.Storage.Local` instead of inventing a second delivery model.

**Init-time validation precedent** ([lib/rindle/live_view.ex](/Users/jon/projects/rindle/lib/rindle/live_view.ex:67)):
```elixir
@spec allow_upload(Phoenix.LiveView.Socket.t(), atom(), module(), keyword()) ::
        Phoenix.LiveView.Socket.t()
def allow_upload(socket, name, profile, opts \\ []) do
  external_fn = fn entry, socket ->
    do_allow_upload(entry, socket, profile)
  end

  merged_opts = Keyword.merge(opts, external: external_fn)
  Upload.allow_upload(socket, name, merged_opts)
end
```

Pattern to preserve: validate/wire dependencies up front, then keep request-time code narrow.

**Local filesystem resolution pattern** ([lib/rindle/storage/local.ex](/Users/jon/projects/rindle/lib/rindle/storage/local.ex:72)):
```elixir
def head(key, opts) do
  path = storage_path(key, opts)

  if File.exists?(path) do
    {:ok, %{size: File.stat!(path).size}}
  else
    {:error, :not_found}
  end
end

def capabilities, do: [:local, :presigned_put]

defp storage_path(key, opts) do
  Path.join(local_root(opts), key)
end
```

Phase 26 should reuse local-root resolution semantics and capability truthfulness. `LocalPlug` should fail fast unless adapter advertises/equals local semantics; do not silently degrade non-local adapters.

### `test/rindle/delivery_test.exs` (module contract test, request-response)

**Analog:** `test/rindle/delivery_test.exs`

**Per-profile nested test modules + Mox** ([test/rindle/delivery_test.exs](/Users/jon/projects/rindle/test/rindle/delivery_test.exs:1)):
```elixir
use Rindle.DataCase, async: true
import Mox

setup :set_mox_from_context
setup :verify_on_exit!

defmodule PrivateProfile do
  use Rindle.Profile,
    storage: Rindle.StorageMock,
    ...,
    delivery: [authorizer: Rindle.AuthorizerMock, signed_url_ttl_seconds: 120]
end
```

Use this exact organization for new `streaming_url/3` tests: define local/public/private profiles inline, assert exact tuple shapes, and verify adapter/authorizer calls.

**Behavior-first assertions** ([test/rindle/delivery_test.exs](/Users/jon/projects/rindle/test/rindle/delivery_test.exs:34)):
```elixir
expect(Rindle.AuthorizerMock, :authorize, fn nil, :deliver, %{profile: PrivateProfile, key: ^key, mode: :private} ->
  :ok
end)

expect(Rindle.StorageMock, :capabilities, fn -> [:signed_url] end)

expect(Rindle.StorageMock, :url, fn ^key, opts ->
  assert Keyword.get(opts, :expires_in) == 120
  {:ok, "https://signed.example/#{key}?ttl=120"}
end)
```

Preserve this style for:
- TTL inheritance and request-time override
- same `:deliver` action + subject map in authorization
- tagged capability failures like `{:delivery_unsupported, :signed_url}`

**Telemetry success-only tests** ([test/rindle/delivery_test.exs](/Users/jon/projects/rindle/test/rindle/delivery_test.exs:185)):
```elixir
ref = :telemetry_test.attach_event_handlers(self(), [[:rindle, :delivery, :signed]])
...
assert_received {[:rindle, :delivery, :signed], ^ref, measurements, metadata}
...
refute_received {[:rindle, :delivery, :signed], ^ref, _, _}
```

Copy this for `[:rindle, :delivery, :streaming, :resolved]` and for `[:rindle, :delivery, :range_request]`: attach handler, assert shape on success, assert no emission on denied/unsupported flows.

### `test/rindle/contracts/telemetry_contract_test.exs` (public contract test, event-driven)

**Analog:** `test/rindle/contracts/telemetry_contract_test.exs`

**Locked public event allowlist pattern** ([test/rindle/contracts/telemetry_contract_test.exs](/Users/jon/projects/rindle/test/rindle/contracts/telemetry_contract_test.exs:54)):
```elixir
@public_events [
  [:rindle, :upload, :start],
  [:rindle, :upload, :stop],
  [:rindle, :asset, :state_change],
  [:rindle, :variant, :state_change],
  [:rindle, :delivery, :signed],
  ...
]
```

Phase 26 should extend this list, not create a separate contract mechanism.

**Measurement/metadata contract style** ([test/rindle/contracts/telemetry_contract_test.exs](/Users/jon/projects/rindle/test/rindle/contracts/telemetry_contract_test.exs:114)):
```elixir
{:ok, _url} = Rindle.Delivery.url(LocalContractProfile, "test/key.png")

assert_received {[:rindle, :delivery, :signed], ^ref, measurements, metadata}
assert_required_metadata_keys(metadata)
assert_numeric_measurements(measurements)
assert metadata.profile == LocalContractProfile
assert metadata.adapter == Rindle.Storage.Local
```

Use the same contract lane for Phase 26 telemetry:
- exact event name
- numeric measurements only
- metadata keys stable and documented

### `test/rindle/delivery/local_plug_test.exs` (new file-I/O test)

**Analogs:** `test/rindle/html_test.exs`, `test/rindle/live_view_test.exs`

**Thin integration test style** ([test/rindle/html_test.exs](/Users/jon/projects/rindle/test/rindle/html_test.exs:28)):
```elixir
html =
  Rindle.HTML.picture_tag(PublicProfile, asset, ...)
  |> Phoenix.HTML.safe_to_string()

assert html =~ "<picture>"
refute html =~ "wide.jpg"
```

**Stateful integration fixture style** ([test/rindle/live_view_test.exs](/Users/jon/projects/rindle/test/rindle/live_view_test.exs:121)):
```elixir
expect(Rindle.StorageMock, :head, fn key, _opts -> ... end)
...
assert session.state == "completed"
assert asset.state == "validating"
```

For `LocalPlug`, prefer real temp files and conn assertions over heavy mocks:
- build temp root under `System.tmp_dir!()`
- create real file bytes
- exercise request/response and headers directly
- assert `200` full-body fallback vs `206` single-range behavior
- assert init/boot failure for non-local adapter configuration

## Shared Patterns

### Capability checks
**Source:** [lib/rindle/storage/capabilities.ex](/Users/jon/projects/rindle/lib/rindle/storage/capabilities.ex:32)
```elixir
def safe(adapter) do
  case adapter.capabilities() do
    capabilities when is_list(capabilities) -> Enum.filter(capabilities, &(&1 in @known))
    _ -> []
  end
rescue
  _ -> []
end

def require_delivery(adapter, capability) do
  if supports?(adapter, capability), do: :ok, else: {:error, {:delivery_unsupported, capability}}
end
```

Apply to `LocalPlug` boot/init validation and any future streaming provider gate. Preserve tagged unsupported tuples; do not raise generic errors from capability drift.

### Delivery policy normalization
**Source:** [lib/rindle/profile/validator.ex](/Users/jon/projects/rindle/lib/rindle/profile/validator.ex:211)
```elixir
ttl =
  case Keyword.fetch!(delivery, :signed_url_ttl_seconds) do
    nil -> Rindle.Config.signed_url_ttl_seconds()
    value -> value
  end

%{
  public: Keyword.fetch!(delivery, :public),
  signed_url_ttl_seconds: ttl,
  authorizer: Keyword.fetch!(delivery, :authorizer)
}
```

Phase 26 should preserve profile-level TTL as the source of truth. If request-time `:expires_in` still works, keep it additive and lower priority than explicit caller override semantics already in `resolve_url/5`.

### Phoenix-facing integration style
**Sources:** [lib/rindle/html.ex](/Users/jon/projects/rindle/lib/rindle/html.ex:35), [lib/rindle/live_view.ex](/Users/jon/projects/rindle/lib/rindle/live_view.ex:47)

Shared repo style:
- public wrappers are thin and explicit
- option parsing is shallow and keyword-based
- lower-level Rindle modules own policy
- docs explain the integration seam and caveats directly

Phase 26 should keep `LocalPlug` and `streaming_url/3` aligned with that style.

### Signed URL / auth / TTL posture to preserve
**Sources:** [lib/rindle/delivery.ex](/Users/jon/projects/rindle/lib/rindle/delivery.ex:97), [lib/rindle/storage/s3.ex](/Users/jon/projects/rindle/lib/rindle/storage/s3.ex:55), [lib/rindle/storage.ex](/Users/jon/projects/rindle/lib/rindle/storage.ex:101)

Preserve these invariants:
- authorization happens in `Rindle.Delivery`, not inside adapters
- private delivery requires `:signed_url` capability
- adapter `url/2` remains the actual signer/URL producer
- TTL is profile-driven by default and passed as `:expires_in`
- public/private stays a metadata/policy distinction, not separate caller APIs

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `lib/rindle/delivery/local_plug.ex` | middleware | file-I/O | No existing Plug module or range-serving code in repo |
| `test/rindle/delivery/local_plug_test.exs` | test | file-I/O | No existing conn/send_file/range test lane in repo |

## Metadata

**Analog search scope:** `lib/rindle/*.ex`, `lib/rindle/storage/*.ex`, `lib/rindle/profile/*.ex`, `test/rindle/**/*.exs`
**Files scanned:** 13
**Pattern extraction date:** 2026-05-05
